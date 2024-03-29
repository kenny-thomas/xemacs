/* General GUI code -- GTK-specific. (menubars, scrollbars, toolbars, dialogs)
   Copyright (C) 1995 Board of Trustees, University of Illinois.
   Copyright (C) 1995, 1996, 2002 Ben Wing.
   Copyright (C) 1995 Sun Microsystems, Inc.
   Copyright (C) 1998 Free Software Foundation, Inc.

This file is part of XEmacs.

XEmacs is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your
option) any later version.

XEmacs is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with XEmacs.  If not, see <http://www.gnu.org/licenses/>. */

/* Synched up with: Not in FSF. */

#include <config.h>
#include "lisp.h"

#include "buffer.h"
#include "device-impl.h"
#include "frame.h"
#include "gui.h"
#include "opaque.h"

#include "console-gtk-impl.h"

static GUI_ID gui_id_ctr = 0;

GUI_ID
new_gui_id (void)
{
  return (++gui_id_ctr);
}

/* This is like FRAME_MENUBAR_DATA (f), but contains an alist of
   (id . popup-data) for GCPRO'ing the callbacks of the popup menus
   and dialog boxes. */
static Lisp_Object Vpopup_callbacks;

void
gcpro_popup_callbacks (GUI_ID id, Lisp_Object data)
{
  Vpopup_callbacks = Fcons (Fcons (make_fixnum (id), data), Vpopup_callbacks);
}

void
ungcpro_popup_callbacks (GUI_ID id)
{
  Lisp_Object lid = make_fixnum (id);
  Lisp_Object this_callback = assq_no_quit (lid, Vpopup_callbacks);
  Vpopup_callbacks = delq_no_quit (this_callback, Vpopup_callbacks);
}

Lisp_Object
get_gcpro_popup_callbacks (GUI_ID id)
{
  Lisp_Object lid = make_fixnum (id);
  Lisp_Object this_callback = assq_no_quit (lid, Vpopup_callbacks);

  if (!NILP (this_callback))
    {
      return (XCDR (this_callback));
    }
  return (Qnil);
}

void
syms_of_gui_gtk (void)
{
#ifdef HAVE_POPUPS
  DEFSYMBOL (Qmenu_no_selection_hook);
#endif
}

void
vars_of_gui_gtk (void)
{
  staticpro (&Vpopup_callbacks);
  Vpopup_callbacks = Qnil;
#ifdef HAVE_POPUPS
  popup_up_p = 0;

#if 0
  /* This DEFVAR_LISP is just for the benefit of make-docfile. */
  /* #### misnamed */
  DEFVAR_LISP ("menu-no-selection-hook", &Vmenu_no_selection_hook /*
Function or functions to call when a menu or dialog box is dismissed
without a selection having been made.
*/ );
#endif

  Fset (Qmenu_no_selection_hook, Qnil);
#endif /* HAVE_POPUPS */
}
