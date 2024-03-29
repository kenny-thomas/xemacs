/* TTY frame functions.
   Copyright (C) 1995, 1997  Free Software Foundation, Inc.
   Copyright (C) 1995, 1996, 2002 Ben Wing.

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

/* Written by Ben Wing.
   Multi-frame support added by Hrvoje Niksic. */

#include <config.h>
#include "lisp.h"

#include "device-impl.h"
#include "events.h"
#include "frame-impl.h"

#include "console-tty-impl.h"


/* Default properties to use when creating frames.  */
Lisp_Object Vdefault_tty_frame_plist;

Lisp_Object Qframe_number, Qmake_frame_after_init_entry_point;

static void tty_raise_frame (struct frame *);


static void
tty_init_frame_1 (struct frame *f, Lisp_Object UNUSED (props),
		  int frame_name_is_defaulted)
{
  struct device *d = XDEVICE (FRAME_DEVICE (f));
  struct console *c = XCONSOLE (DEVICE_CONSOLE (d));

  ++CONSOLE_TTY_DATA (c)->frame_count;
  f->order_count = CONSOLE_TTY_DATA (c)->frame_count;
  f->height = CONSOLE_TTY_DATA (c)->height;
  f->width = CONSOLE_TTY_DATA (c)->width;
  if (frame_name_is_defaulted)
    f->name = emacs_sprintf_string ("F%d", f->order_count);
}

static void
tty_init_frame_3 (struct frame *f)
{
  tty_raise_frame (f);
}

static void
tty_select_frame_if_unhidden (Lisp_Object frame)
{
  if (FRAME_REPAINT_P (XFRAME (frame)))
    select_frame_1 (frame);
}

static void
tty_schedule_frame_select (struct frame *f)
{
  Lisp_Object frame = wrap_frame (f);

  enqueue_magic_eval_event (tty_select_frame_if_unhidden, frame);
}

static void
tty_after_init_frame (struct frame *f, int UNUSED (first_on_device),
		      int first_on_console)
{
  if (first_on_console)
    call1 (Qmake_frame_after_init_entry_point, FRAME_CONSOLE (f));
}

/* Change from withdrawn state to mapped state. */
static void
tty_make_frame_visible (struct frame *f)
{
  if (!FRAME_VISIBLE_P (f))
    {
      f->visible = -1;
    }
}

/* Change from mapped state to withdrawn state. */
static void
tty_make_frame_invisible (struct frame *f)
{
  f->visible = 0;
}

static void
tty_make_frame_hidden (struct frame *f)
{
  f->visible = -1;
}

static void
tty_make_frame_unhidden (struct frame *f)
{
  if (!FRAME_REPAINT_P (f))
    {
      SET_FRAME_CLEAR (f);
      f->visible = 1;
    }
}

static int
tty_frame_visible_p (struct frame *f)
{
  return FRAME_VISIBLE_P (f);
}

static void
tty_raise_frame_no_select (struct frame *f)
{
  LIST_LOOP_2 (frame, DEVICE_FRAME_LIST (XDEVICE (FRAME_DEVICE (f))))
    {
      struct frame *o = XFRAME (frame);
      if (o != f && FRAME_REPAINT_P (o))
	{
	   tty_make_frame_hidden (o);
	   break;
	}
    }
  tty_make_frame_unhidden (f);
}

static void
tty_raise_frame (struct frame *f)
{
  tty_raise_frame_no_select (f);
  tty_schedule_frame_select (f);
}

static void
tty_lower_frame (struct frame *f)
{
  Lisp_Object frame_list = DEVICE_FRAME_LIST (XDEVICE (FRAME_DEVICE (f)));
  Lisp_Object tail, new_;

  if (!FRAME_REPAINT_P (f))
    return;

  LIST_LOOP (tail, frame_list)
    {
      if (f == XFRAME (XCAR (tail)))
	break;
    }

  /* To lower this frame, another frame has to be raised.  Return if
     there is no other frame. */
  if (NILP (tail) && EQ (frame_list, tail))
    return;

  tty_make_frame_hidden (f);
  if (CONSP (XCDR (tail)))
    new_ = XCAR (XCDR (tail));
  else
    new_ = XCAR (frame_list);
  tty_make_frame_unhidden (XFRAME (new_));
  tty_schedule_frame_select (XFRAME (new_));
}

static void
tty_delete_frame (struct frame *f)
{
  struct device *d = XDEVICE (FRAME_DEVICE (f));

  if (!NILP (DEVICE_SELECTED_FRAME (d)))
    tty_raise_frame (XFRAME (DEVICE_SELECTED_FRAME (d)));
}

static Lisp_Object
tty_frame_property (struct frame *f, Lisp_Object property)
{
  if (EQ (Qframe_number, property))
    return make_fixnum (f->order_count);

  return Qunbound;
}

static int
tty_internal_frame_property_p (struct frame *UNUSED (f), Lisp_Object property)
{
  return EQ (property, Qframe_number);
}

static Lisp_Object
tty_frame_properties (struct frame *f)
{
  Lisp_Object props = Qnil;

  props = cons3 (Qframe_number, make_fixnum (f->order_count), props);

  return props;
}

/************************************************************************/
/*			      initialization				*/
/************************************************************************/

void
console_type_create_frame_tty (void)
{
  CONSOLE_HAS_METHOD (tty, init_frame_1);
  CONSOLE_HAS_METHOD (tty, init_frame_3);
  CONSOLE_HAS_METHOD (tty, after_init_frame);
  CONSOLE_HAS_METHOD (tty, make_frame_visible);
  CONSOLE_HAS_METHOD (tty, make_frame_invisible);
  CONSOLE_HAS_METHOD (tty, frame_visible_p);
  CONSOLE_HAS_METHOD (tty, raise_frame);
  CONSOLE_HAS_METHOD (tty, lower_frame);
  CONSOLE_HAS_METHOD (tty, delete_frame);
  CONSOLE_HAS_METHOD (tty, frame_property);
  CONSOLE_HAS_METHOD (tty, internal_frame_property_p);
  CONSOLE_HAS_METHOD (tty, frame_properties);
}

void
syms_of_frame_tty (void)
{
  DEFSYMBOL (Qframe_number);
  DEFSYMBOL (Qmake_frame_after_init_entry_point);
}

void
vars_of_frame_tty (void)
{
  DEFVAR_LISP ("default-tty-frame-plist", &Vdefault_tty_frame_plist /*
Plist of default frame-creation properties for tty frames.
These are in addition to and override what is specified in
`default-frame-plist', but are overridden by the arguments to the
particular call to `make-frame'.
*/ );
  Vdefault_tty_frame_plist = Qnil;

  tty_console_methods->device_specific_frame_props =
    &Vdefault_tty_frame_plist;

  /* Tty frames are now supported.  Advertise a feature to indicate this. */
  Fprovide (intern ("tty-frames"));
}
