/* mswindows GUI code. (menubars, scrollbars, toolbars, dialogs)
   Copyright (C) 1998 Andy Piper.

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

/* This file essentially Mule-ized (except perhaps some Unicode splitting).
   5-2000. */

#include <config.h>
#include "lisp.h"
#include "console-msw-impl.h"
#include "redisplay.h"
#include "gui.h"
#include "glyphs.h"
#include "frame-impl.h"
#include "elhash.h"
#include "events.h"
#include "buffer.h"

/*
 * Return value is Qt if we have dispatched the command,
 * or Qnil if id has not been mapped to a callback.
 * Window procedure may try other targets to route the
 * command if we return nil
 */
Lisp_Object
mswindows_handle_gui_wm_command (struct frame *f, HWND ctrl, LPARAM id)
{
  /* Try to map the command id through the proper hash table */
  Lisp_Object callback, callback_ex, image_instance, frame, event;

  frame = wrap_frame (f);

  image_instance = Fgethash (make_int_verify (id), 
			     FRAME_MSWINDOWS_WIDGET_HASH_TABLE1 (f), Qnil);
  /* It is possible for a widget action to cause it to get out of sync
     with its instantiator. Thus it is necessary to signal this
     possibility. */
  if (IMAGE_INSTANCEP (image_instance))
    XIMAGE_INSTANCE_WIDGET_ACTION_OCCURRED (image_instance) = 1;
  callback = Fgethash (make_int (id), 
		       FRAME_MSWINDOWS_WIDGET_HASH_TABLE2 (f), Qnil);
  callback_ex = Fgethash (make_int (id), 
			  FRAME_MSWINDOWS_WIDGET_HASH_TABLE3 (f), Qnil);

  if (!NILP (callback_ex) && !UNBOUNDP (callback_ex))
    {
      event = Fmake_event (Qnil, Qnil);

#ifdef USE_KKCC
      XSET_EVENT_TYPE (event, misc_user_event);
      XSET_EVENT_CHANNEL (event, frame);
      XSET_EVENT_TIMESTAMP (event, GetTickCount());
      XSET_MISC_USER_DATA_FUNCTION (XEVENT_DATA (event), Qeval);
      XSET_MISC_USER_DATA_OBJECT (XEVENT_DATA (event),
			     list4 (Qfuncall, callback_ex, image_instance, event));
#else /* not USE_KKCC */
      XEVENT (event)->event_type = misc_user_event;
      XEVENT (event)->channel = frame;
      XEVENT (event)->timestamp = GetTickCount ();
      XEVENT (event)->event.eval.function = Qeval;
      XEVENT (event)->event.eval.object =
	list4 (Qfuncall, callback_ex, image_instance, event);
#endif /* not USE_KKCC */
    }
  else if (NILP (callback) || UNBOUNDP (callback))
    return Qnil;
  else
    {
      Lisp_Object fn, arg;

      event = Fmake_event (Qnil, Qnil);

      get_gui_callback (callback, &fn, &arg);
#ifdef USE_KKCC
      XSET_EVENT_TYPE (event, misc_user_event);
      XSET_EVENT_CHANNEL (event, frame);
      XSET_EVENT_TIMESTAMP (event, GetTickCount());
      XSET_MISC_USER_DATA_FUNCTION (XEVENT_DATA (event), fn);
      XSET_MISC_USER_DATA_OBJECT (XEVENT_DATA (event), arg);
#else /* not USE_KKCC */
      XEVENT (event)->event_type = misc_user_event;
      XEVENT (event)->channel = frame;
      XEVENT (event)->timestamp = GetTickCount ();
      XEVENT (event)->event.eval.function = fn;
      XEVENT (event)->event.eval.object = arg;
#endif /* not USE_KKCC */
    }

  mswindows_enqueue_dispatch_event (event);
  /* The result of this evaluation could cause other instances to change so 
     enqueue an update callback to check this. */
  enqueue_magic_eval_event (update_widget_instances, frame);
  return Qt;
}

void
syms_of_gui_mswindows (void)
{
}
