/* Implements an elisp-programmable menubar -- Win32
   Copyright (C) 1993, 1994 Free Software Foundation, Inc.
   Copyright (C) 1995 Tinker Systems and INS Engineering Corp.
   Copyright (C) 1997 Kirill M. Katsnelson <kkm@kis.ru>

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

/* Autorship:
   Initially written by kkm 12/24/97,
   peeking into and copying stuff from menubar-x.c
   */

/* Algotirhm for handling menus is as follows. When window's menubar
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
 * descriptor. Each frame has an associated hashtable.
 *
 * Leaf items are assigned a unique id based on item's hash. When an
 * item is selected, Windows sends back the id. Unfortunately, only
 * low 16 bit of the ID are sent, and there's no way to get the 32-bit
 * value. Yes, Win32 is just a different set of bugs than X! Aside
 * from this blame, another hasing mechanism is required to map menu
 * ids to commands (which are actually Lisp_Object's). This mapping is
 * performed in the same hashtable, as the lifetime of both maps is
 * exactly the same. This is unabmigous, as menu handles are
 * represented by lisp opaques, while command ids are by lisp
 * integers. The additional advantage for this is that command forms
 * are automatically GC-protected, which is important because these
 * may be transient forms generated by :filter functions.
 *
 * The hashtable is not allowed to grow too much; it is pruned
 * whenever this is safe to do. This is done by re-creating the menu
 * bar, and clearing and refilling the hash table from scratch.
 *
 * Popup menus are handled identially to pulldowns. A static hash
 * table is used for popup menus, and lookup is made not in
 * current-menubar but in a lisp form supplied to the `popup'
 * function.
 *
 * Another Windows weirdness is that there's no way to tell that a
 * popup has been dismissed without making selection. We need to know
 * that to cleanup the popup menu hashtable, but this is not honestly
 * doable using *documented* sequence of messages. Sticking to
 * particular knowledge is bad because this may break in Windows NT
 * 5.0, or Windows 98, or other future version. Instead, I allow the
 * hashtables to hang around, and not clear them, unless WM_COMMAND is
 * received. This is worthy some memory but more safe. Hacks welcome,
 * anyways!
 *
 */

#include <config.h>
#include "lisp.h"

#include "buffer.h"
#include "commands.h"
#include "console-msw.h"
#include "emacsfns.h"
#include "elhash.h"
#include "event-msw.h"
#include "events.h"
#include "frame.h"
#include "gui.h"
#include "lisp.h"
#include "menubar.h"
#include "menubar-msw.h"
#include "opaque.h"
#include "window.h"

#define EMPTY_ITEM_ID ((UINT)LISP_TO_VOID (Qunbound))
#define EMPTY_ITEM_NAME "(empty)"

/* Current menu (bar or popup) descriptor. gcpro'ed */
static Lisp_Object current_menudesc;

/* Current menubar or popup hashtable. gcpro'ed */
static Lisp_Object current_hashtable;

/* Bound by menubar.el */
static Lisp_Object Qfind_menu_item;

/* This is used to allocate unique ids to menu items.
   Items ids are in MENU_ITEM_ID_MIN to MENU_ITEM_ID_MAX.
   Allocation checks that the item is not already in
   the TOP_LEVEL_MENU */
/* #### defines go to gui-msw.h */
#define MENU_ITEM_ID_MIN 0x8000
#define MENU_ITEM_ID_MAX 0xFFFF
#define MENU_ITEM_ID_BITS(x) ((x) & 0x7FFF | 0x8000)
static HMENU top_level_menu;

/* ============= THIS STUFF MIGHT GO SOMEWHERE ELSE ================= */

/* All these functions are windows sys independent, and are candidates
   to go to lisp code instead */

/*
 * DESCRIPTOR is a list in the form ({:keyword value}+ rest...).
 * This function extracts all the key-value pairs into the newly
 * created plist, and returns pointer to REST. Original list is not
 * modified (heaven save!)
 */
Lisp_Object
gui_parse_menu_keywords (Lisp_Object descriptor, Lisp_Object *plist)
{
  Lisp_Object pair, key, val;
  *plist = Qnil;
  LIST_LOOP (pair, descriptor)
    {
      if (!CONSP(pair))
	signal_simple_error ("Mailformed gui entity descriptor", descriptor);
      key = XCAR(pair);
      if (!KEYWORDP (key))
	return pair;
      pair = XCDR (pair);
      if (!CONSP(pair))
	signal_simple_error ("Mailformed gui entity descriptor", descriptor);
      val = XCAR (pair);
      internal_plist_put (plist, key, val);
    }
  return pair;
}

/*
 * DESC is a vector describing a menu item. The function returns menu
 * item name in NAME, callback form in CALLBACK, and all key-values
 * pairs in PLIST. For old-style vectors, the plist is faked.
 */
void
gui_parse_button_descriptor (Lisp_Object desc, Lisp_Object *name, 
			     Lisp_Object *callback, Lisp_Object *plist)
{
  int length = XVECTOR_LENGTH (desc);
  Lisp_Object *contents = XVECTOR_DATA (desc);
  int plist_p;

  *name = Qnil;
  *callback = Qnil;
  *plist = Qnil;

  if (length < 3)
    signal_simple_error ("Button descriptors must be at least 3 long", desc);

  /* length 3:		[ "name" callback active-p ]
     length 4:		[ "name" callback active-p suffix ]
     		   or	[ "name" callback keyword  value  ]
     length 5+:		[ "name" callback [ keyword value ]+ ]
   */
  plist_p = (length >= 5 || KEYWORDP (contents [2]));

  *name = contents [0];
  *callback = contents [1];

  if (!plist_p)
    /* the old way */
    {
      internal_plist_put (plist, Q_active, contents [2]);
      if (length == 4)
	internal_plist_put (plist, Q_suffix, contents [3]);
    }
  else
    /* the new way */
    {
      int i;
      if (length & 1)
	signal_simple_error (
		"Button descriptor has an odd number of keywords and values",
			     desc);

      for (i = 2; i < length;)
	{
	  Lisp_Object key = contents [i++];
	  Lisp_Object val = contents [i++];
	  if (!KEYWORDP (key))
	    signal_simple_error_2 ("Not a keyword", key, desc);
	  internal_plist_put (plist, key, val);
	}
    }    
}

/*
 * Given PLIST of key-value pairs for a menu item or button, consult
 * :included and :config properties (the latter against
 * CONFLIST). Return value is non-zero when item should *not* appear.
 */
int
gui_plist_says_item_excluded (Lisp_Object plist, Lisp_Object conflist)
{
  Lisp_Object tem;
  /* This function can call lisp */

  /* Evaluate :included first */
  tem = internal_plist_get (plist, Q_included);
  if (!UNBOUNDP (tem))
    {
      tem = Feval (tem);
      if (NILP (tem))
	return 1;
    }

  /* Do :config if conflist is given */
  if (!NILP (conflist))
    {
      tem = internal_plist_get (plist, Q_config);
      if (!UNBOUNDP (tem))
	{
	  tem = Fmemq (tem, conflist);
	  if (NILP (tem))
	    return 1;
	}
    }

  return 0;
}
    
/*
 * Given PLIST of key-value pairs for a menu item or button, consult
 * :active property. Return non-zero if the item is *inactive*
 */
int
gui_plist_says_item_inactive (Lisp_Object plist)
{
  Lisp_Object tem;
  /* This function can call lisp */

  tem = internal_plist_get (plist, Q_active);
  if (!UNBOUNDP (tem))
    {
      tem = Feval (tem);
      if (NILP (tem))
	return 1;
    }

  return 0;
}

/*
 * Given PLIST of key-value pairs for a menu item or button, evaluate
 * the form which is the value of :filter property. Filter function
 * given DESC as argument. If there's no :filter property, DESC is
 * returned, otherwise the value returned by the filter function is
 * returned. 
 */
Lisp_Object
gui_plist_apply_filter (Lisp_Object plist, Lisp_Object desc)
{
  Lisp_Object tem;
  /* This function can call lisp */

  tem = internal_plist_get (plist, Q_filter);
  if (UNBOUNDP (tem))
    return desc;
  else
    return call1 (tem, desc);
}

/*
 * This is tricky because there's no menu item styles in Windows, only
 * states: Each item may be given no checkmark, radio or check
 * mark. This function returns required mark style as determined by
 * PLIST. Return value is the value of :style property if the item is
 * :seleted, or nil otherwise
 */
Lisp_Object
gui_plist_get_current_style (Lisp_Object plist)
{
  Lisp_Object style, selected;
  style = internal_plist_get (plist, Q_style);
  if (UNBOUNDP (style) || NILP(style))
    return Qnil;

  selected = internal_plist_get (plist, Q_selected);
  if (UNBOUNDP (selected) || NILP(Feval(selected)))
    return Qnil;

  return style;
}

Lisp_Object
current_frame_menubar (CONST struct frame* f)
{
  struct window *w = XWINDOW (FRAME_LAST_NONMINIBUF_WINDOW (f));
  return symbol_value_in_buffer (Qcurrent_menubar, w->buffer);
}

/* ============ END IF STUFF THAT MIGHT GO SOMEWHERE ELSE =============== */

/* Change these together */
#define MAX_MENUITEM_LENGTH 128
#define DISPLAYABLE_MAX_MENUITEM_LENGTH "128"

static void 
signal_item_too_long (Lisp_Object name)
{
    signal_simple_error ("Menu item is longer than "
			 DISPLAYABLE_MAX_MENUITEM_LENGTH
			 " characters", name);
}

/* #### If this function returned (FLUSHLEFT . FLUSHRIGHT) it also
   could be moved above that line - it becomes window system
   independant */
/*
 * This returns Windows-style menu item string:
 * "Left Flush\tRight Flush"
 */
static CONST char*
plist_get_menu_item_name (Lisp_Object name, Lisp_Object callback, Lisp_Object plist)
{
  /* We construct the name in a static buffer. That's fine, beause
     menu items longer than 128 chars are probably programming errors,
     and better be caught than displayed! */
  
  static char buf[MAX_MENUITEM_LENGTH];
  char* p = buf;
  int buf_left = MAX_MENUITEM_LENGTH - 1;
  Lisp_Object tem;

  /* Get name first */
  buf_left -= XSTRING_LENGTH (name);
  if (buf_left < 0)
    signal_item_too_long (name);
  strcpy (p, XSTRING_DATA (name));
  p += XSTRING_LENGTH (name);

  /* Have suffix? */
  tem = internal_plist_get (plist, Q_suffix);
  if (!UNBOUNDP (tem))
    {
      if (!STRINGP (tem))
	signal_simple_error (":suffix must be a string", tem);
      buf_left -= XSTRING_LENGTH (tem) + 1;
      if (buf_left < 0)
	signal_item_too_long (name);
      *p++ = ' ';
      strcpy (p, XSTRING_DATA (tem));
      p += XSTRING_LENGTH (tem);
    }

  /* Have keys? */
  if (menubar_show_keybindings)
    {
      static char buf2 [1024];
      buf2[0] = 0;

      tem = internal_plist_get (plist, Q_keys);
      if (!UNBOUNDP (tem))
	{
	  if (!STRINGP (tem))
	    signal_simple_error (":keys must be a string", tem);
	  if (XSTRING_LENGTH (tem) > sizeof (buf2) - 1)
	    signal_item_too_long (name);
	  strcpy (buf2, XSTRING_DATA (tem));
	}
      else if (SYMBOLP (callback))
	{
	  /* #### Warning, dependency here on current_buffer and point */
	  /* #### I've borrowed this warning along with this code from
	     menubar-x.c. What does that mean? -- kkm */
	  where_is_to_char (callback, buf2);
	}

      if (buf2 [0])
	{
	  int n = strlen (buf2) + 1;
	  buf_left -= n;
	  if (buf_left < 0)
	    signal_item_too_long (name);
	  *p++ = '\t';
	  strcpy (p, buf2);
	  p += n-1;
	}
    }
  
  *p = 0;
  return buf;
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
 * the hashtable rather than abandon it.
 */
static Lisp_Object
allocate_menu_item_id (Lisp_Object path, Lisp_Object name)
{
  UINT id = MENU_ITEM_ID_BITS (HASH2 (internal_hash (path, 0),
				      internal_hash (name, 0)));
  do {
      id = MENU_ITEM_ID_BITS (id + 1);
  } while (GetMenuState (top_level_menu, id, MF_BYCOMMAND) != 0xFFFFFFFF);
  return make_int (id);
}

static HMENU
create_empty_popup_menu (void)
{
  HMENU submenu = CreatePopupMenu ();
  /* #### It seems that really we do not need "(empty)" at this stage */
#if 0
  AppendMenu (submenu, MF_STRING | MF_GRAYED, EMPTY_ITEM_ID, EMPTY_ITEM_NAME);
#endif
  return submenu;
}

static void
empty_menu (HMENU menu, int add_empty_p)
{
  while (DeleteMenu (menu, 0, MF_BYPOSITION));
  if (add_empty_p)
    AppendMenu (menu, MF_STRING | MF_GRAYED, EMPTY_ITEM_ID, EMPTY_ITEM_NAME);
}

/*
 * The idea of checksumming is that we must hash minimal object
 * which is neccessarily changes when the item changes. For separator
 * this is a constant, for grey strings and submenus these are hashes
 * of names, since sumbenus are unpopulated until opened so always
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
      return internal_hash (XCAR(item), 0);
    }
  else if (VECTORP (item))
    {
      /* An ordinary item - hash its name and callback form. */
      Lisp_Object plist, name, callback;
      gui_parse_button_descriptor (item, &name, &callback, &plist);
      return HASH2 (internal_hash (name, 0),
		    internal_hash (callback, 0));
    }
 
  /* An error - will be caught later */
  return 0;
}

static void
populate_menu_add_item (HMENU menu, Lisp_Object path,
			Lisp_Object hash_tab, Lisp_Object item, int flush_right)
{
  MENUITEMINFO item_info;
  struct gcpro gcpro1, gcpro2;

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
	  item_info.dwTypeData = XSTRING_DATA (item);
	}
    }
  else if (CONSP (item))
    {
      /* Submenu */
      Lisp_Object subname = XCAR (item);
      Lisp_Object plist;
      HMENU submenu;
	
      if (!STRINGP (subname))
	signal_simple_error ("Menu name (first element) must be a string", item);

      item = gui_parse_menu_keywords (XCDR (item), &plist);
      GCPRO1 (plist);

      if (gui_plist_says_item_excluded (plist, Vmenubar_configuration))
	return;

      if (gui_plist_says_item_inactive (plist))
	item_info.fState = MFS_GRAYED;
      /* Temptation is to put 'else' right here. Although, the
	 displayed item won't have an arrow indicating that it is a
	 popup.  So we go ahead a little bit more and create a popup */
      submenu = create_empty_popup_menu();

      item_info.fMask |= MIIM_SUBMENU;
      item_info.dwTypeData = plist_get_menu_item_name (subname, Qnil, plist);
      item_info.hSubMenu = submenu;

      UNGCPRO; /* plist */

      if (!(item_info.fState & MFS_GRAYED))
	{
	  /* Now add the full submenu path as a value to the hash table,
	     keyed by menu handle */
	  if (NILP(path))
	    path = list1 (subname);
	  else {
	    Lisp_Object arg[2];
	    arg[0] = path;
	    arg[1] = list1 (subname);
	    GCPRO1 (arg[1]);
	    path = Fappend (2, arg);
	    UNGCPRO; /* arg[1] */
	  }

	  GCPRO1 (path);
	  Fputhash (hmenu_to_lisp_object (submenu), path, hash_tab);
	  UNGCPRO; /* path */
	}
    } 
  else if (VECTORP (item))
    {
      /* An ordinary item */
      Lisp_Object plist, name, callback, style, id;
      
      gui_parse_button_descriptor (item, &name, &callback, &plist);
      GCPRO2 (plist, callback);

      if (gui_plist_says_item_excluded (plist, Vmenubar_configuration))
	return;

      if (gui_plist_says_item_inactive (plist))
	item_info.fState |= MFS_GRAYED;

      style = gui_plist_get_current_style (plist);
      if (EQ (style, Qradio))
	{
	  item_info.fType |= MFT_RADIOCHECK;
	  item_info.fState |= MFS_CHECKED;
	}
      else if (EQ (style, Qtoggle))
	{
	  item_info.fState |= MFS_CHECKED;
	}

      id = allocate_menu_item_id (path, name);
      Fputhash (id, callback, hash_tab);
      
      UNGCPRO; /* plist, callback */

      item_info.wID = (UINT) XINT(id);
      item_info.fType |= MFT_STRING;
      item_info.dwTypeData = plist_get_menu_item_name (name, callback, plist);
    }
  else
    {
      signal_simple_error ("Ill-constructed menu descriptor", item);
    }

  if (flush_right)
    item_info.fType |= MFT_RIGHTJUSTIFY;

  InsertMenuItem (menu, UINT_MAX, TRUE, &item_info);
}  

/*
 * This function is called from populate_menu and checksum_menu.
 * When called to populate, MENU is a menu handle, PATH is a
 * list of strings representing menu path from root to this submenu,
 * DESCRIPTOR is a menu descriptor, HASH_TAB is a hashtable associated
 * with root menu, BAR_P indicates whether this called for a menubar or
 * a popup, and POPULATE_P is non-zero. Return value must be ignored.
 * When called to checksum, DESCRIPTOR has the same meaning, POPULATE_P
 * is zero, PATH must be Qnil, and the rest of parameters is ignored.
 * Return value is the menu checksum.
 */
static unsigned long
populate_or_checksum_helper (HMENU menu, Lisp_Object path, Lisp_Object descriptor,
			     Lisp_Object hash_tab, int bar_p, int populate_p)
{
  Lisp_Object menu_name, plist, item_desc;
  int deep_p, flush_right;
  struct gcpro gcpro1;
  unsigned long checksum = 0;

  /* Will initially contain only "(empty)" */
  if (populate_p)
    empty_menu (menu, 1);

  /* PATH set to nil indicates top-level popup or menubar */
  deep_p = !NILP (path);

  if (!deep_p)
    top_level_menu = menu;

  if (!CONSP(descriptor))
    signal_simple_error ("Menu descriptor must be a list", descriptor);

  if (STRINGP (XCAR (descriptor)))
    {
      menu_name = XCAR (descriptor);
      descriptor = XCDR (descriptor);
    }
  else
    {
      menu_name = Qnil;
      if (deep_p) /* Not a popup or bar */
	signal_simple_error ("Menu must have a name", descriptor);
    }

  /* Fetch keywords prepending the item list */
  descriptor = gui_parse_menu_keywords (descriptor, &plist);
  GCPRO1 (plist);
  descriptor = gui_plist_apply_filter (plist, descriptor);
  UNGCPRO; /* plist */
  
  /* Loop thru the descriptor's CDR and add items for each entry */
  flush_right = 0;
  EXTERNAL_LIST_LOOP (item_desc, descriptor)
    {
      if (NILP (XCAR (item_desc)))
	{
	  if (bar_p)
	    flush_right = 1;
	  if (!populate_p)
	    checksum = HASH2 (checksum, Qnil);
	}
      else if (populate_p)
	populate_menu_add_item (menu, path, hash_tab,
				XCAR (item_desc), flush_right);
      else
	checksum = HASH2 (checksum,
			  checksum_menu_item (XCAR (item_desc)));
    }
  
  if (populate_p)
    {
      /* Remove the "(empty)" item, if there are other ones */
      if (GetMenuItemCount (menu) > 1)
	RemoveMenu (menu, EMPTY_ITEM_ID, MF_BYCOMMAND);

      /* Add the header to the popup, if told so. The same as in X - an
	 insensitive item, and a separator (Seems to me, there were
	 two separators in X... In Windows this looks ugly, anywats. */
      if (!bar_p && !deep_p && popup_menu_titles && !NILP(menu_name))
	{
	  InsertMenu (menu, 0, MF_BYPOSITION | MF_STRING | MF_DISABLED,
		      0, XSTRING_DATA(menu_name));
	  InsertMenu (menu, 1, MF_BYPOSITION | MF_SEPARATOR, 0, NULL);
	  SetMenuDefaultItem (menu, 0, MF_BYPOSITION);
	}
    }
  return checksum;
}

static void
populate_menu (HMENU menu, Lisp_Object path, Lisp_Object descriptor,
			     Lisp_Object hash_tab, int bar_p)
{
  populate_or_checksum_helper (menu, path, descriptor, hash_tab, bar_p, 1);
}

static unsigned long
checksum_menu (Lisp_Object descriptor)
{
  return populate_or_checksum_helper (NULL, Qnil, descriptor, Qunbound, 0, 0);
}

static Lisp_Object
find_menu (Lisp_Object desc, Lisp_Object path)
{
  /* #### find-menu-item is not what's required here. 
     Need to write this in C, or improve lisp */
  if (!NILP (path))
    {
      desc = call2 (Qfind_menu_item, desc, path);
      /* desc is (supposed to be) (ITEM . PARENT). Supposed
         to signal but sometimes manages to return nil */
      if (!NILP(desc))
	{
	  CHECK_CONS (desc);
	  desc = XCAR (desc);
	}
    }
  return desc;
}

static void
update_frame_menubar_maybe (struct frame* f)
{
  HMENU menubar = GetMenu (FRAME_MSWINDOWS_HANDLE (f));
  struct window *w = XWINDOW (FRAME_LAST_NONMINIBUF_WINDOW (f));
  Lisp_Object desc = (!NILP (w->menubar_visible_p)
		      ? symbol_value_in_buffer (Qcurrent_menubar, w->buffer)
		      : Qnil);

  if (NILP (desc) && menubar != NULL)
    {
      /* Menubar has gone */
      FRAME_MSWINDOWS_MENU_HASHTABLE(f) = Qnil;
      SetMenu (FRAME_MSWINDOWS_HANDLE (f), NULL);
      DestroyMenu (menubar);
      DrawMenuBar (FRAME_MSWINDOWS_HANDLE (f));
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
      return;
    }

  /* Now we bail out if the menubar has not changed */
  if (FRAME_MSWINDOWS_MENU_CHECKSUM(f) == checksum_menu (desc))
    return;

populate:
  /* Come with empty hash table */
  if (NILP (FRAME_MSWINDOWS_MENU_HASHTABLE(f)))
    FRAME_MSWINDOWS_MENU_HASHTABLE(f) = Fmake_hashtable (make_int (50), Qequal);
  else
    Fclrhash (FRAME_MSWINDOWS_MENU_HASHTABLE(f));

  Fputhash (hmenu_to_lisp_object (menubar), Qnil,
	    FRAME_MSWINDOWS_MENU_HASHTABLE(f));
  populate_menu (menubar, Qnil, desc,
		 FRAME_MSWINDOWS_MENU_HASHTABLE(f), 1);
  SetMenu (FRAME_MSWINDOWS_HANDLE (f), menubar);
  DrawMenuBar (FRAME_MSWINDOWS_HANDLE (f));

  FRAME_MSWINDOWS_MENU_CHECKSUM(f) = checksum_menu (desc);
}

static void
prune_menubar (struct frame *f)
{
  HMENU menubar = GetMenu (FRAME_MSWINDOWS_HANDLE (f));
  Lisp_Object desc = current_frame_menubar (f);
  if (menubar == NULL)
    return;

  /* #### If a filter function has set desc to Qnil, this abort()
     triggers. To resolve, we must prevent filters explicitely from
     mangling with the active menu. In apply_filter probably?
     Is copy-tree on the whole menu too expensive? */
  if (NILP(desc))
    /* abort(); */
    return;

  /* We do the trick by removing all items and re-populating top level */
  empty_menu (menubar, 0);

  assert (HASHTABLEP (FRAME_MSWINDOWS_MENU_HASHTABLE(f)));
  Fclrhash (FRAME_MSWINDOWS_MENU_HASHTABLE(f));

  Fputhash (hmenu_to_lisp_object (menubar), Qnil,
	    FRAME_MSWINDOWS_MENU_HASHTABLE(f));
  populate_menu (menubar, Qnil, desc, 
		 FRAME_MSWINDOWS_MENU_HASHTABLE(f), 1);
}

/*
 * This is called when cleanup is possible. It is better not to
 * clean things up at all than do it too earaly!
 */
static void
menu_cleanup (struct frame *f)
{
  /* This function can GC */
  current_menudesc = Qnil;
  current_hashtable = Qnil;
  prune_menubar (f);
}
  

/*------------------------------------------------------------------------*/
/* Message handlers                                                       */
/*------------------------------------------------------------------------*/
static Lisp_Object
unsafe_handle_wm_initmenupopup_1 (HMENU menu, struct frame* f)
{
  /* This function can call lisp, beat dogs and stick chewing gum to
     everything! */

  Lisp_Object path, desc;
  struct gcpro gcpro1;

  /* Find which guy is going to explode */
  path = Fgethash (hmenu_to_lisp_object (menu), current_hashtable, Qunbound);
  assert (!UNBOUNDP (path));
#ifdef DEBUG_XEMACS
  /* Allow to continue in a debugger after assert - not so fatal */
  if (UNBOUNDP (path))
    error ("internal menu error");
#endif

  /* Now find a desc chunk for it. If none, then probably menu open
     hook has played too much games around stuff */
  desc = current_menudesc;
  if (!NILP (path))
    {
      desc = find_menu (desc, path);
      if (NILP (desc))
	signal_simple_error ("This menu does not exist any more", path);
    }

  /* Now, stuff it */
  /* DESC may be generated by filter, so we have to gcpro it */
  GCPRO1 (desc);
  populate_menu (menu, path, desc, current_hashtable, 0);
  UNGCPRO;
  return Qt;
}

static Lisp_Object
unsafe_handle_wm_initmenu_1 (struct frame* f)
{
  /* This function can call lisp */
  /* #### - this menubar update mechanism is expensively anti-social and
     the activate-menubar-hook is now mostly obsolete. */

  /* We simply ignore return value. In any case, we construct the bar
     on the fly */
  run_hook (Vactivate_menubar_hook);

  update_frame_menubar_maybe (f);

  current_menudesc = current_frame_menubar (f);
  current_hashtable = FRAME_MSWINDOWS_MENU_HASHTABLE(f);
  assert (HASHTABLEP (current_hashtable));

  return Qt;
}

#ifdef KKM_DOES_NOT_LIKE_UNDOCS_SOMETIMES

/* #### This may become wrong in future Windows */

static Lisp_Object
unsafe_handle_wm_exitmenuloop_1 (struct frame* f)
{
  if (!NILP (current_tracking_popup))
    prune_menubar (f);
  return Qt;
}

#endif

/*
 * Return value is Qt if we have dispatched the command,
 * or Qnil if id has not been mapped to a callback.
 * Window procedure may try other targets to route the
 * command if we return nil
 */
Lisp_Object
mswindows_handle_wm_command (struct frame* f, WORD id)
{
  /* Try to map the command id through the proper hash table */
  Lisp_Object command, funcsym, frame;
  struct gcpro gcpro1;

  command = Fgethash (make_int (id), current_hashtable, Qunbound);
  if (UNBOUNDP (command))
    {
      menu_cleanup (f);
      return Qnil;
    }

  /* Need to gcpro because the hashtable may get destroyed
     by menu_cleanup(), and will not gcpro the command
     any more */
  GCPRO1 (command);
  menu_cleanup (f);

  /* Ok, this is our one. Enqueue it. */
  if (SYMBOLP (command))
      funcsym = Qcall_interactively;
  else if (CONSP (command))
      funcsym = Qeval;
  else
    signal_simple_error ("Illegal callback", command);

  XSETFRAME (frame, f);
  enqueue_misc_user_event (frame, funcsym, command);

  /* Needs good bump also, for WM_COMMAND may have been dispatched from
     mswindows_need_event, which will block again despite new command
     event has arrived */
  mswindows_enqueue_magic_event (FRAME_MSWINDOWS_HANDLE(f),
				 XM_BUMPQUEUE);
  
  UNGCPRO; /* command */
  return Qt;
}


/*------------------------------------------------------------------------*/
/* Message handling proxies                                               */
/*------------------------------------------------------------------------*/

static HMENU wm_initmenu_menu;
static struct frame* wm_initmenu_frame;

static Lisp_Object
unsafe_handle_wm_initmenupopup (Lisp_Object u_n_u_s_e_d)
{
  return unsafe_handle_wm_initmenupopup_1 (wm_initmenu_menu, wm_initmenu_frame);
}

static Lisp_Object
unsafe_handle_wm_initmenu (Lisp_Object u_n_u_s_e_d)
{
  return unsafe_handle_wm_initmenu_1 (wm_initmenu_frame);
}

#ifdef KKM_DOES_NOT_LIKE_UNDOCS_SOMETIMES
static Lisp_Object
unsafe_handle_wm_exitmenuloop (Lisp_Object u_n_u_s_e_d)
{
  return unsafe_handle_wm_exitmenuloop_1 (wm_initmenu_frame);
}
#endif

Lisp_Object
mswindows_handle_wm_initmenupopup (HMENU hmenu, struct frame* frm)
{
  /* We cannot pass hmenu as a lisp object. Use static var */
  wm_initmenu_menu = hmenu;
  wm_initmenu_frame = frm;
  return mswindows_protect_modal_loop (unsafe_handle_wm_initmenupopup, Qnil);
}

Lisp_Object
mswindows_handle_wm_initmenu (HMENU hmenu, struct frame* f)
{
  /* Handle only frame menubar, ignore if from popup or system menu */
  if (GetMenu (FRAME_MSWINDOWS_HANDLE(f)) == hmenu)
    {
      wm_initmenu_frame = f;
      return mswindows_protect_modal_loop (unsafe_handle_wm_initmenu, Qnil);
    }
  return Qt;
}

Lisp_Object
mswindows_handle_wm_exitmenuloop (struct frame* f)
{
#ifdef KKM_DOES_NOT_LIKE_UNDOCS_SOMETIMES
  wm_initmenu_frame = f;
  return mswindows_protect_modal_loop (unsafe_handle_wm_exitmenuloop, Qnil);
#else
  return Qt;
#endif
}


/*------------------------------------------------------------------------*/
/* Methods                                                                */
/*------------------------------------------------------------------------*/

static void
mswindows_update_frame_menubars (struct frame* f)
{
  update_frame_menubar_maybe (f);
}

static void
mswindows_free_frame_menubars (struct frame* f)
{
  FRAME_MSWINDOWS_MENU_HASHTABLE(f) = Qnil;
}

static void
mswindows_popup_menu (Lisp_Object menu_desc, Lisp_Object event)
{
  struct frame *f = selected_frame ();
  struct Lisp_Event *eev = NULL;
  HMENU menu;
  POINT pt;
  int ok;

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

  /* Default is to put the menu at the point (10, 10) in frame */
  if (eev)
    {
      pt.x = eev->event.button.x;
      pt.y = eev->event.button.y;
      ClientToScreen (FRAME_MSWINDOWS_HANDLE (f), &pt);
    }
  else
    pt.x = pt.y = 10;

  if (SYMBOLP (menu_desc))
    menu_desc = Fsymbol_value (menu_desc);

  current_menudesc = menu_desc;
  current_hashtable = Fmake_hashtable (make_int(10), Qequal);
  menu = create_empty_popup_menu();
  Fputhash (hmenu_to_lisp_object (menu), Qnil, current_hashtable);
  
  ok = TrackPopupMenu (menu,
		       TPM_LEFTALIGN | TPM_LEFTBUTTON | TPM_RIGHTBUTTON,
		       pt.x, pt.y, 0,
		       FRAME_MSWINDOWS_HANDLE (f), NULL);

  DestroyMenu (menu);

  /* Signal a signal if caught by Track...() modal loop */
  mswindows_unmodalize_signal_maybe ();

  /* This is probably the only real reason for failure */
  if (!ok) {
    menu_cleanup (f);
    signal_simple_error ("Cannot track popup menu while in menu",
			 menu_desc);
  }
}


/*------------------------------------------------------------------------*/
/* Initialization                                                         */
/*------------------------------------------------------------------------*/
void
syms_of_menubar_mswindows (void)
{
  defsymbol (&Qfind_menu_item, "find-menu-item");
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
  current_hashtable = Qnil;

  staticpro (&current_menudesc);
  staticpro (&current_hashtable);

  Fprovide (intern ("mswindows-menubars"));
}
