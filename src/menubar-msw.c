/* Implements an elisp-programmable menubar -- Win32
   Copyright (C) 1993, 1994 Free Software Foundation, Inc.
   Copyright (C) 1995 Tinker Systems and INS Engineering Corp.
   Copyright (C) 1997 Kirill M. Katsnelson <kkm@kis.ru>.
   Copyright (C) 2000, 2001, 2002, 2003 Ben Wing.

This file is part of XEmacs.

XEmacs is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 2, or (at your option) any
later version.

XEmacs is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with XEmacs; see the file COPYING.  If not, write to
the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.  */

/* Synched up with: Not in FSF. */

/* This function mostly Mule-ized (except perhaps some Unicode splitting).
   5-2000. */

/* Author:
   Initially written by kkm 12/24/97,
   peeking into and copying stuff from menubar-x.c
   */

/* Algorithm for handling menus is as follows. When window's menubar
 * is created, current-menubar is not traversed in depth. Rather, only
 * top level items, both items and pulldowns, are added to the
 * menubar. Each pulldown is initially empty. When a pulldown is
 * selected and about to open, corresponding element of
 * current-menubar is found, and the newly open pulldown is
 * populated. This is made again in the same non-recursive manner.
 *
 * This algorithm uses hash tables to find out element of the menu
 * descriptor list given menu handle. The key is an opaque ptr data
 * type, keeping menu handle, and the value is a list of strings
 * representing the path from the root of the menu to the item
 * descriptor. Each frame has an associated hash table.
 *
 * Leaf items are assigned a unique id based on item's hash. When an
 * item is selected, Windows sends back the id. Unfortunately, only
 * low 16 bit of the ID are sent, and there's no way to get the 32-bit
 * value. Yes, Win32 is just a different set of bugs than X! Aside
 * from this blame, another hashing mechanism is required to map menu
 * ids to commands (which are actually Lisp_Object's). This mapping is
 * performed in the same hash table, as the lifetime of both maps is
 * exactly the same. This is unambigous, as menu handles are
 * represented by lisp opaques, while command ids are by lisp
 * integers. The additional advantage for this is that command forms
 * are automatically GC-protected, which is important because these
 * may be transient forms generated by :filter functions.
 *
 * The hash table is not allowed to grow too much; it is pruned
 * whenever this is safe to do. This is done by re-creating the menu
 * bar, and clearing and refilling the hash table from scratch.
 *
 * Popup menus are handled identically to pulldowns. A static hash
 * table is used for popup menus, and lookup is made not in
 * current-menubar but in a lisp form supplied to the `popup'
 * function.
 *
 * Another Windows weirdness is that there's no way to tell that a
 * popup has been dismissed without making selection. We need to know
 * that to cleanup the popup menu hash table, but this is not honestly
 * doable using *documented* sequence of messages. Sticking to
 * particular knowledge is bad because this may break in Windows NT
 * 5.0, or Windows 98, or other future version. Instead, I allow the
 * hash tables to hang around, and not clear them, unless WM_COMMAND is
 * received. This is worth some memory but more safe. Hacks welcome,
 * anyways!
 *
 */

#include <config.h>
#include "lisp.h"

#include "buffer.h"
#include "commands.h"
#include "console-msw-impl.h"
#include "elhash.h"
#include "events.h"
#include "frame-impl.h"
#include "gui.h"
#include "lisp.h"
#include "menubar.h"
#include "opaque.h"
#include "window-impl.h"

/* #### */
#define REPLACE_ME_WITH_GLOBAL_VARIABLE_WHICH_CONTROLS_RIGHT_FLUSH 0

#define EMPTY_ITEM_ID ((UINT)LISP_TO_VOID (Qunbound))
#define EMPTY_ITEM_NAME "(empty)" /* WARNING: uses of this need XETEXT */

/* Current menu (bar or popup) descriptor. gcpro'ed */
static Lisp_Object current_menudesc;

/* Current menubar or popup hash table. gcpro'ed */
static Lisp_Object current_hash_table;

/* This is used to allocate unique ids to menu items.
   Items ids are in MENU_ITEM_ID_MIN to MENU_ITEM_ID_MAX.
   Allocation checks that the item is not already in
   the TOP_LEVEL_MENU */

/* #### defines go to gui-msw.h, as the range is shared with toolbars
   (If only toolbars will be implemented as common controls) */
#define MENU_ITEM_ID_MIN 0x8000
#define MENU_ITEM_ID_MAX 0xFFFF
#define MENU_ITEM_ID_BITS(x) (((x) & 0x7FFF) | 0x8000)
static HMENU top_level_menu;

/*
 * This returns Windows-style menu item string:
 * "Left Flush\tRight Flush"
 */

static Lisp_Object
displayable_menu_item (Lisp_Object gui_item, int bar_p, Ichar *accel)
{
  Lisp_Object left, right = Qnil;

  /* Left flush part of the string */
  left = gui_item_display_flush_left (gui_item);

  left = mswindows_translate_menu_or_dialog_item (left, accel);

  /* Right flush part, unless we're at the top-level where it's not allowed */
  if (!bar_p)
    right = gui_item_display_flush_right (gui_item);

  if (!NILP (right))
    return concat3 (left, build_ascstring ("\t"), right);
  else
    return left;
}

/*
 * hmenu_to_lisp_object() returns an opaque ptr given menu handle.
 */
static Lisp_Object
hmenu_to_lisp_object (HMENU hmenu)
{
  return make_opaque_ptr (hmenu);
}

/*
 * Allocation tries a hash based on item's path and name first. This
 * almost guarantees that the same item will override its old value in
 * the hash table rather than abandon it.
 */
static Lisp_Object
allocate_menu_item_id (Lisp_Object path, Lisp_Object name, Lisp_Object suffix)
{
  UINT id = MENU_ITEM_ID_BITS (HASH3 (internal_hash (path, 0),
				      internal_hash (name, 0),
				      internal_hash (suffix, 0)));
  do {
      id = MENU_ITEM_ID_BITS (id + 1);
  } while (GetMenuState (top_level_menu, id, MF_BYCOMMAND) != 0xFFFFFFFF);
  return make_int (id);
}

static HMENU
create_empty_popup_menu (void)
{
  return CreatePopupMenu ();
}

static void
empty_menu (HMENU menu, int add_empty_p)
{
  while (DeleteMenu (menu, 0, MF_BYPOSITION));
  if (add_empty_p)
    qxeAppendMenu (menu, MF_STRING | MF_GRAYED, EMPTY_ITEM_ID,
		   XETEXT (EMPTY_ITEM_NAME));
}

/*
 * The idea of checksumming is that we must hash minimal object
 * which is necessarily changes when the item changes. For separator
 * this is a constant, for grey strings and submenus these are hashes
 * of names, since submenus are unpopulated until opened so always
 * equal otherwise. For items, this is a full hash value of a callback,
 * because a callback may me a form which can be changed only somewhere
 * in depth.
 */
static unsigned long
checksum_menu_item (Lisp_Object item)
{
  if (STRINGP (item))
    {
      /* Separator or unselectable text - hash as a string + 13 */
      if (separator_string_p (XSTRING_DATA (item)))
	return 13;
      else
	return internal_hash (item, 0) + 13;
    }
  else if (CONSP (item))
    {
      /* Submenu - hash by its string name + 0 */
      return internal_hash (XCAR (item), 0);
    }
  else if (VECTORP (item))
    {
      /* An ordinary item - hash its name and callback form. */
      return HASH2 (internal_hash (XVECTOR_DATA(item)[0], 0),
		    internal_hash (XVECTOR_DATA(item)[1], 0));
    }

  /* An error - will be caught later */
  return 0;
}

static void
populate_menu_add_item (HMENU menu, Lisp_Object path,
			Lisp_Object hash_tab, Lisp_Object item,
			Lisp_Object *accel_list,
			int flush_right, int bar_p)
{
  MENUITEMINFOW item_info;

  item_info.cbSize = sizeof (item_info);
  item_info.fMask = MIIM_TYPE | MIIM_STATE | MIIM_ID;
  item_info.fState = 0;
  item_info.wID = 0;
  item_info.fType = 0;

  if (STRINGP (item))
    {
      /* Separator or unselectable text */
      if (separator_string_p (XSTRING_DATA (item)))
	item_info.fType = MFT_SEPARATOR;
      else
	{
	  item_info.fType = MFT_STRING;
	  item_info.fState = MFS_DISABLED;
	  item_info.dwTypeData = (XELPTSTR) LISP_STRING_TO_TSTR (item);
	}
    }
  else if (CONSP (item))
    {
      /* Submenu */
      HMENU submenu;
      Lisp_Object gui_item = allocate_gui_item ();
      Lisp_Gui_Item *pgui_item = XGUI_ITEM (gui_item);
      struct gcpro gcpro1, gcpro2, gcpro3;
      Ichar accel;

      GCPRO3 (gui_item, path, *accel_list);

      menu_parse_submenu_keywords (item, gui_item);

      if (!STRINGP (pgui_item->name))
	invalid_argument ("Menu name (first element) must be a string",
			     item);

      if (!gui_item_included_p (gui_item, Vmenubar_configuration))
	{
	  UNGCPRO;
	  goto done;
	}

      if (!gui_item_active_p (gui_item))
	item_info.fState = MFS_GRAYED;
      /* Temptation is to put 'else' right here. Although, the
	 displayed item won't have an arrow indicating that it is a
	 popup.  So we go ahead a little bit more and create a popup */
      submenu = create_empty_popup_menu ();

      item_info.fMask |= MIIM_SUBMENU;
      item_info.dwTypeData = (XELPTSTR)
	LISP_STRING_TO_TSTR (displayable_menu_item (gui_item, bar_p, &accel));
      item_info.hSubMenu = submenu;

      if (accel && bar_p)
	*accel_list = Fcons (make_char (accel), *accel_list);

      if (!(item_info.fState & MFS_GRAYED))
	{
	  /* Now add the full submenu path as a value to the hash table,
	     keyed by menu handle */
	  if (NILP(path))
	    path = list1 (pgui_item->name);
	  else
	    {
	      Lisp_Object arg[2];
	      arg[0] = path;
	      arg[1] = list1 (pgui_item->name);
	      path = Fappend (2, arg);
	    }

	  Fputhash (hmenu_to_lisp_object (submenu), path, hash_tab);
	}
      UNGCPRO;
    }
  else if (VECTORP (item))
    {
      /* An ordinary item */
      Lisp_Object style, id;
      Lisp_Object gui_item = gui_parse_item_keywords (item);
      Lisp_Gui_Item *pgui_item = XGUI_ITEM (gui_item);
      struct gcpro gcpro1, gcpro2;
      Ichar accel;

      GCPRO2 (gui_item, *accel_list);

      if (!gui_item_included_p (gui_item, Vmenubar_configuration))
	{
	  UNGCPRO;
	  goto done;
	}

      if (!STRINGP (pgui_item->name))
        pgui_item->name = IGNORE_MULTIPLE_VALUES (Feval (pgui_item->name));

      if (!gui_item_active_p (gui_item))
	item_info.fState = MFS_GRAYED;

      style = (NILP (pgui_item->selected) || NILP (Feval (pgui_item->selected))
	       ? Qnil : pgui_item->style);

      if (EQ (style, Qradio))
	{
	  item_info.fType |= MFT_RADIOCHECK;
	  item_info.fState |= MFS_CHECKED;
	}
      else if (EQ (style, Qtoggle))
	item_info.fState |= MFS_CHECKED;

      id = allocate_menu_item_id (path, pgui_item->name,
				  pgui_item->suffix);
      Fputhash (id, pgui_item->callback, hash_tab);

      item_info.wID = (UINT) XINT (id);
      item_info.fType |= MFT_STRING;
      item_info.dwTypeData = (XELPTSTR)
	LISP_STRING_TO_TSTR (displayable_menu_item (gui_item, bar_p, &accel));

      if (accel && bar_p)
	*accel_list = Fcons (make_char (accel), *accel_list);

      UNGCPRO;
    }
  else
    sferror ("Malformed menu item descriptor", item);

  if (flush_right)
    item_info.fType |= MFT_RIGHTJUSTIFY;

  qxeInsertMenuItem (menu, UINT_MAX, TRUE, &item_info);

done:;
}

/*
 * This function is called from populate_menu and checksum_menu.
 * When called to populate, MENU is a menu handle, PATH is a
 * list of strings representing menu path from root to this submenu,
 * DESCRIPTOR is a menu descriptor, HASH_TAB is a hash table associated
 * with root menu, BAR_P indicates whether this called for a menubar or
 * a popup, and POPULATE_P is non-zero. Return value must be ignored.
 * When called to checksum, DESCRIPTOR has the same meaning, POPULATE_P
 * is zero, PATH must be Qnil, and the rest of parameters is ignored.
 * Return value is the menu checksum.
 */
static unsigned long
populate_or_checksum_helper (HMENU menu, Lisp_Object path, Lisp_Object desc,
			     Lisp_Object hash_tab, int bar_p, int populate_p)
{
  int deep_p, flush_right;
  struct gcpro gcpro1, gcpro2, gcpro3;
  unsigned long checksum;
  Lisp_Object gui_item = allocate_gui_item ();
  Lisp_Object accel_list = Qnil;
  Lisp_Gui_Item *pgui_item = XGUI_ITEM (gui_item);

  GCPRO3 (gui_item, accel_list, desc);

  /* We are sometimes called with the menubar unchanged, and with changed
     right flush. We have to update the menubar in this case,
     so account for the compliance setting in the hash value */
  checksum = REPLACE_ME_WITH_GLOBAL_VARIABLE_WHICH_CONTROLS_RIGHT_FLUSH;

  /* Will initially contain only "(empty)" */
  if (populate_p)
    empty_menu (menu, 1);

  /* PATH set to nil indicates top-level popup or menubar */
  deep_p = !NILP (path);

  /* Fetch keywords prepending the item list */
  desc = menu_parse_submenu_keywords (desc, gui_item);

  /* Check that menu name is specified when expected */
  if (NILP (pgui_item->name) && deep_p)
    sferror ("Menu must have a name", desc);

  /* Apply filter if specified */
  if (!NILP (pgui_item->filter))
    desc = call1 (pgui_item->filter, desc);

  /* Loop thru the desc's CDR and add items for each entry */
  flush_right = 0;
  {
    EXTERNAL_LIST_LOOP_2 (elt, desc)
      {
	if (NILP (elt))
	  {
	    /* Do not flush right menubar items when MS style compliant */
	    if (bar_p && !REPLACE_ME_WITH_GLOBAL_VARIABLE_WHICH_CONTROLS_RIGHT_FLUSH)
	      flush_right = 1;
	    if (!populate_p)
	      checksum = HASH2 (checksum, LISP_HASH (Qnil));
	  }
	else if (populate_p)
	  populate_menu_add_item (menu, path, hash_tab,
				  elt, &accel_list,
				  flush_right, bar_p);
	else
	  checksum = HASH2 (checksum,
			    checksum_menu_item (elt));
      }
  }

  if (populate_p)
    {
      /* Remove the "(empty)" item, if there are other ones */
      if (GetMenuItemCount (menu) > 1)
	RemoveMenu (menu, EMPTY_ITEM_ID, MF_BYCOMMAND);

      /* Add the header to the popup, if told so. The same as in X - an
	 insensitive item, and a separator (Seems to me, there were
	 two separators in X... In Windows this looks ugly, anyways.) */
      if (!bar_p && !deep_p && popup_menu_titles && !NILP (pgui_item->name))
	{
	  qxeInsertMenu (menu, 0, MF_BYPOSITION | MF_STRING | MF_DISABLED,
			 0, LISP_STRING_TO_TSTR (displayable_menu_item
						 (gui_item, bar_p, NULL)));
	  qxeInsertMenu (menu, 1, MF_BYPOSITION | MF_SEPARATOR, 0, NULL);
	  SetMenuDefaultItem (menu, 0, MF_BYPOSITION);
	}
    }

  if (bar_p)
    Fputhash (Qt, accel_list, hash_tab);

  UNGCPRO;
  return checksum;
}

static void
populate_menu (HMENU menu, Lisp_Object path, Lisp_Object desc,
	       Lisp_Object hash_tab, int bar_p)
{
  populate_or_checksum_helper (menu, path, desc, hash_tab, bar_p, 1);
}

static unsigned long
checksum_menu (Lisp_Object desc)
{
  return populate_or_checksum_helper (NULL, Qnil, desc, Qunbound, 0, 0);
}

static void
update_frame_menubar_maybe (struct frame *f)
{
  HMENU menubar = GetMenu (FRAME_MSWINDOWS_HANDLE (f));
  struct window *w = XWINDOW (FRAME_LAST_NONMINIBUF_WINDOW (f));
  Lisp_Object desc = (!NILP (w->menubar_visible_p)
		      ? symbol_value_in_buffer (Qcurrent_menubar, w->buffer)
		      : Qnil);
  struct gcpro gcpro1;

  GCPRO1 (desc); /* it's safest to do this, just in case some filter
		    or something changes the value of current-menubar */

  top_level_menu = menubar;

  if (NILP (desc) && menubar != NULL)
    {
      /* Menubar has gone */
      FRAME_MSWINDOWS_MENU_HASH_TABLE (f) = Qnil;
      SetMenu (FRAME_MSWINDOWS_HANDLE (f), NULL);
      DestroyMenu (menubar);
      DrawMenuBar (FRAME_MSWINDOWS_HANDLE (f));
      UNGCPRO;
      return;
    }

  if (!NILP (desc) && menubar == NULL)
    {
      /* Menubar has appeared */
      menubar = CreateMenu ();
      goto populate;
    }

  if (NILP (desc))
    {
      /* We did not have the bar and are not going to */
      UNGCPRO;
      return;
    }

  /* Now we bail out if the menubar has not changed */
  if (FRAME_MSWINDOWS_MENU_CHECKSUM (f) == checksum_menu (desc))
    {
      UNGCPRO;
      return;
    }

populate:
  /* Come with empty hash table */
  if (NILP (FRAME_MSWINDOWS_MENU_HASH_TABLE (f)))
    FRAME_MSWINDOWS_MENU_HASH_TABLE (f) =
      make_lisp_hash_table (50, HASH_TABLE_NON_WEAK, HASH_TABLE_EQUAL);
  else
    Fclrhash (FRAME_MSWINDOWS_MENU_HASH_TABLE (f));

  Fputhash (hmenu_to_lisp_object (menubar), Qnil,
	    FRAME_MSWINDOWS_MENU_HASH_TABLE (f));
  populate_menu (menubar, Qnil, desc,
		 FRAME_MSWINDOWS_MENU_HASH_TABLE (f), 1);
  SetMenu (FRAME_MSWINDOWS_HANDLE (f), menubar);
  DrawMenuBar (FRAME_MSWINDOWS_HANDLE (f));

  FRAME_MSWINDOWS_MENU_CHECKSUM (f) = checksum_menu (desc);

  UNGCPRO;
}

static void
prune_menubar (struct frame *f)
{
  HMENU menubar = GetMenu (FRAME_MSWINDOWS_HANDLE (f));
  Lisp_Object desc = current_frame_menubar (f);
  struct gcpro gcpro1;

  if (menubar == NULL)
    return;

  /* #### If a filter function has set desc to Qnil, this ABORT()
     triggers. To resolve, we must prevent filters explicitly from
     mangling with the active menu. In apply_filter probably?
     Is copy-tree on the whole menu too expensive? */
  if (NILP (desc))
    /* ABORT(); */
    return;

  GCPRO1 (desc); /* just to be safe -- see above */
  /* We do the trick by removing all items and re-populating top level */
  empty_menu (menubar, 0);

  assert (HASH_TABLEP (FRAME_MSWINDOWS_MENU_HASH_TABLE (f)));
  Fclrhash (FRAME_MSWINDOWS_MENU_HASH_TABLE (f));

  Fputhash (hmenu_to_lisp_object (menubar), Qnil,
	    FRAME_MSWINDOWS_MENU_HASH_TABLE (f));
  populate_menu (menubar, Qnil, desc,
		 FRAME_MSWINDOWS_MENU_HASH_TABLE (f), 1);
  UNGCPRO;
}

/*
 * This is called when cleanup is possible. It is better not to
 * clean things up at all than do it too early!
 */
static void
menu_cleanup (struct frame *f)
{
  /* This function can GC */
  current_menudesc = Qnil;
  current_hash_table = Qnil;
  prune_menubar (f);
}

int
mswindows_char_is_accelerator (struct frame *f, Ichar ch)
{
  Lisp_Object hash = FRAME_MSWINDOWS_MENU_HASH_TABLE (f);

  if (NILP (hash))
    return 0;
  return !NILP (memq_no_quit
		(make_char
		 (DOWNCASE (WINDOW_XBUFFER (FRAME_SELECTED_XWINDOW (f)), ch)),
		 Fgethash (Qt, hash, Qnil)));
}


/*------------------------------------------------------------------------*/
/* Message handlers                                                       */
/*------------------------------------------------------------------------*/
static Lisp_Object
unsafe_handle_wm_initmenupopup_1 (HMENU menu, struct frame *UNUSED (f))
{
  /* This function can call lisp, beat dogs and stick chewing gum to
     everything! */

  Lisp_Object path, desc;
  struct gcpro gcpro1;
  
  /* Find which guy is going to explode */
  path = Fgethash (hmenu_to_lisp_object (menu), current_hash_table, Qunbound);
  assert (!UNBOUNDP (path));
#ifdef DEBUG_XEMACS
  /* Allow to continue in a debugger after assert - not so fatal */
  if (UNBOUNDP (path))
    signal_error (Qinternal_error, "internal menu error", Qunbound);
#endif

  /* Now find a desc chunk for it. If none, then probably menu open
     hook has played too much games around stuff */
  desc = Fmenu_find_real_submenu (current_menudesc, path);
  if (NILP (desc))
    invalid_state ("This menu does not exist any more", path);

  /* Now, stuff it */
  /* DESC may be generated by filter, so we have to gcpro it */
  GCPRO1 (desc);
  populate_menu (menu, path, desc, current_hash_table, 0);
  UNGCPRO;
  return Qt;
}

static Lisp_Object
unsafe_handle_wm_initmenu_1 (struct frame *f)
{
  /* This function can call lisp */

  /* NOTE: This is called for the bar only, WM_INITMENU
     for popups is filtered out */

  /* #### - this menubar update mechanism is expensively anti-social and
     the activate-menubar-hook is now mostly obsolete. */

  /* We simply ignore return value. In any case, we construct the bar
     on the fly */
  run_hook_trapping_problems
    (Qmenubar, Qactivate_menubar_hook,
     INHIBIT_EXISTING_PERMANENT_DISPLAY_OBJECT_DELETION);

  update_frame_menubar_maybe (f);

  current_menudesc = current_frame_menubar (f);
  current_hash_table = FRAME_MSWINDOWS_MENU_HASH_TABLE (f);
  assert (HASH_TABLEP (current_hash_table));

  return Qt;
}

/*
 * Return value is Qt if we have dispatched the command,
 * or Qnil if id has not been mapped to a callback.
 * Window procedure may try other targets to route the
 * command if we return nil
 */
Lisp_Object
mswindows_handle_wm_command (struct frame *f, WORD id)
{
  /* Try to map the command id through the proper hash table */
  Lisp_Object data, fn, arg, frame;
  struct gcpro gcpro1;

  if (NILP (current_hash_table))
    return Qnil;

  data = Fgethash (make_int (id), current_hash_table, Qunbound);

  if (UNBOUNDP (data))
    {
      menu_cleanup (f);
      return Qnil;
    }

  /* Need to gcpro because the hash table may get destroyed by
     menu_cleanup(), and will not gcpro the data any more */
  GCPRO1 (data);
  menu_cleanup (f);

  /* Ok, this is our one. Enqueue it. */
  get_gui_callback (data, &fn, &arg);
  frame = wrap_frame (f);
  /* this used to call mswindows_enqueue_misc_user_event but that
     breaks customize because the misc_event gets eval'ed in some
     circumstances. Don't change it back unless you can fix the
     customize problem also. */
  mswindows_enqueue_misc_user_event (frame, fn, arg);

  UNGCPRO; /* data */
  return Qt;
}


/*------------------------------------------------------------------------*/
/* Message handling proxies                                               */
/*------------------------------------------------------------------------*/

struct handle_wm_initmenu
{
  HMENU menu;
  struct frame *frame;
};

static Lisp_Object
unsafe_handle_wm_initmenupopup (void *arg)
{
  struct handle_wm_initmenu *z = (struct handle_wm_initmenu *) arg;
  return unsafe_handle_wm_initmenupopup_1 (z->menu, z->frame);
}

static Lisp_Object
unsafe_handle_wm_initmenu (void *arg)
{
  struct handle_wm_initmenu *z = (struct handle_wm_initmenu *) arg;
  return unsafe_handle_wm_initmenu_1 (z->frame);
}

Lisp_Object
mswindows_handle_wm_initmenupopup (HMENU hmenu, struct frame *frm)
{
  struct handle_wm_initmenu z;
  int depth = internal_bind_int (&in_menu_callback, 1);
  Lisp_Object retval;

  z.menu = hmenu;
  z.frame = frm;

  /* [[ Allow runaway filter code, e.g. custom, to be aborted.  We are
     usually called from next_event_internal(), which has turned off
     quit checking to read the C-g as an event.]]

     #### This is bogus because by the very act of calling
     event_stream_protect_modal_loop(), we disable event retrieval! */
  retval = event_stream_protect_modal_loop ("Error during menu handling",
					    unsafe_handle_wm_initmenupopup, &z,
					    UNINHIBIT_QUIT);
  unbind_to (depth);

  return retval;
}

Lisp_Object
mswindows_handle_wm_initmenu (HMENU hmenu, struct frame *f)
{
  /* Handle only frame menubar, ignore if from popup or system menu */
  if (GetMenu (FRAME_MSWINDOWS_HANDLE (f)) == hmenu)
    {
      struct handle_wm_initmenu z;

      z.frame = f;
      return event_stream_protect_modal_loop ("Error during menu handling",
					      unsafe_handle_wm_initmenu, &z,
					      UNINHIBIT_QUIT);
    }
  return Qt;
}


/*------------------------------------------------------------------------*/
/* Methods                                                                */
/*------------------------------------------------------------------------*/

static void
mswindows_update_frame_menubars (struct frame *f)
{
  update_frame_menubar_maybe (f);
}

static void
mswindows_free_frame_menubars (struct frame *f)
{
  FRAME_MSWINDOWS_MENU_HASH_TABLE (f) = Qnil;
}

static void
mswindows_popup_menu (Lisp_Object menu_desc, Lisp_Object event)
{
  struct frame *f = selected_frame ();
  Lisp_Event *eev = NULL;
  HMENU menu;
  POINT pt;
  int ok;
  struct gcpro gcpro1;

  GCPRO1 (menu_desc); /* to be safe -- see above */

  if (!NILP (event))
    {
      CHECK_LIVE_EVENT (event);
      eev = XEVENT (event);
      if (eev->event_type != button_press_event
	  && eev->event_type != button_release_event)
	wrong_type_argument (Qmouse_event_p, event);
    }
  else if (!NILP (Vthis_command_keys))
    {
      /* if an event wasn't passed, use the last event of the event sequence
	 currently being executed, if that event is a mouse event */
      eev = XEVENT (Vthis_command_keys); /* last event first */
      if (eev->event_type != button_press_event
	  && eev->event_type != button_release_event)
	eev = NULL;
    }

  popup_up_p++;

  /* Default is to put the menu at the point (10, 10) in frame */
  if (eev)
    {
      pt.x = EVENT_BUTTON_X (eev);
      pt.y = EVENT_BUTTON_Y (eev);
      ClientToScreen (FRAME_MSWINDOWS_HANDLE (f), &pt);
    }
  else
    pt.x = pt.y = 10;

  if (SYMBOLP (menu_desc))
    menu_desc = Fsymbol_value (menu_desc);
  CHECK_CONS (menu_desc);
  CHECK_STRING (XCAR (menu_desc));

  menu_cleanup (f);

  current_menudesc = menu_desc;
  current_hash_table =
    make_lisp_hash_table (10, HASH_TABLE_NON_WEAK, HASH_TABLE_EQUAL);
  menu = create_empty_popup_menu ();
  Fputhash (hmenu_to_lisp_object (menu), Qnil, current_hash_table);
  top_level_menu = menu;

  /* see comments in menubar-x.c */
  if (zmacs_regions)
    zmacs_region_stays = 1;

  ok = TrackPopupMenu (menu,
		       TPM_LEFTALIGN | TPM_LEFTBUTTON | TPM_RIGHTBUTTON,
		       pt.x, pt.y, 0,
		       FRAME_MSWINDOWS_HANDLE (f), NULL);

  DestroyMenu (menu);

  /* A WM_COMMAND is not issued until TrackPopupMenu returns. This
     makes setting popup_up_p fairly pointless since we cannot keep
     the menu up and dispatch events. Furthermore, we seem to have
     little control over what happens to the menu when we click. */
  popup_up_p--;

  /* Signal a signal if caught by Track...() modal loop. */
  /* I think this is pointless, the code hasn't actually put us in a
     modal loop at this time -- andyp. */
  mswindows_unmodalize_signal_maybe ();

  /* This is probably the only real reason for failure */
  if (!ok)
    {
      menu_cleanup (f);
      invalid_operation ("Cannot track popup menu while in menu",
			 menu_desc);
    }
  UNGCPRO;
}


/*------------------------------------------------------------------------*/
/* Initialization                                                         */
/*------------------------------------------------------------------------*/
void
syms_of_menubar_mswindows (void)
{
}

void
console_type_create_menubar_mswindows (void)
{
  CONSOLE_HAS_METHOD (mswindows, update_frame_menubars);
  CONSOLE_HAS_METHOD (mswindows, free_frame_menubars);
  CONSOLE_HAS_METHOD (mswindows, popup_menu);
}

void
vars_of_menubar_mswindows (void)
{
  current_menudesc = Qnil;
  current_hash_table = Qnil;

  staticpro (&current_menudesc);
  staticpro (&current_hash_table);
}
