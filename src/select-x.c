/* X Selection processing for XEmacs
   Copyright (C) 1990, 1991, 1992, 1993, 1994 Free Software Foundation, Inc.
   Copyright (C) 2001, 2002, 2010 Ben Wing.

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

/* Synched up with: Not synched with FSF. */

/* Rewritten by jwz */

#include <config.h>
#include "lisp.h"

#include "charset.h"
#include "device-impl.h"
#include "frame-impl.h"
#include "opaque.h"
#include "select.h"

#include "console-x-impl.h"
#include "fontcolor-x.h"

#include "systime.h"

int lisp_to_time (Lisp_Object, time_t *);
Lisp_Object time_to_lisp (time_t);

#ifdef LWLIB_USES_MOTIF
# define MOTIF_CLIPBOARDS
#endif

#ifdef MOTIF_CLIPBOARDS
# include "xmotif.h"
/* Kludge around shadowing warnings */
# define index index_
# include <Xm/CutPaste.h>
# undef index
static void hack_motif_clipboard_selection (Atom selection_atom,
					    Lisp_Object selection_value,
					    Time thyme, Display *display,
					    Window selecting_window,
					    int owned_p);
#endif

#define CUT_BUFFER_SUPPORT

#ifdef CUT_BUFFER_SUPPORT
Lisp_Object QCUT_BUFFER0, QCUT_BUFFER1, QCUT_BUFFER2, QCUT_BUFFER3,
  QCUT_BUFFER4, QCUT_BUFFER5, QCUT_BUFFER6, QCUT_BUFFER7;
#endif

Lisp_Object Vx_sent_selection_hooks;

Lisp_Object Qx_sent_selection_hooks;

/* If this is a smaller number than the max-request-size of the display,
   emacs will use INCR selection transfer when the selection is larger
   than this.  The max-request-size is usually around 64k, so if you want
   emacs to use incremental selection transfers when the selection is
   smaller than that, set this.  I added this mostly for debugging the
   incremental transfer stuff, but it might improve server performance.
 */
#define MAX_SELECTION_QUANTUM 0xFFFFFF

#define SELECTION_QUANTUM(dpy) ((XMaxRequestSize (dpy) << 2) - 100)

/* If the selection owner takes too long to reply to a selection request,
   we give up on it.  This is in seconds (0 = no timeout).
 */
Fixnum x_selection_timeout;

/* Enable motif selection optimizations. */
int x_selection_strict_motif_ownership;


/* Utility functions */

static Lisp_Object x_get_window_property_as_lisp_data (Display *,
						       Window,
						       Atom property,
						       Lisp_Object target_type,
						       Atom selection_atom);

static int expect_property_change (Display *, Window, Atom prop, int state);
static void wait_for_property_change (long);
static void unexpect_property_change (int);
static int waiting_for_other_props_on_window (Display *, Window);

/* This converts a Lisp symbol to a server Atom, avoiding a server
   roundtrip whenever possible.
 */
static Atom
symbol_to_x_atom (struct device *d, Lisp_Object sym, int only_if_exists)
{
  Display *display = DEVICE_X_DISPLAY (d);

  if (NILP (sym))		return XA_PRIMARY;
  if (EQ (sym, Qt))		return XA_SECONDARY;
  if (EQ (sym, QPRIMARY))	return XA_PRIMARY;
  if (EQ (sym, QSECONDARY))	return XA_SECONDARY;
  if (EQ (sym, QSTRING))	return XA_STRING;
  if (EQ (sym, QINTEGER))	return XA_INTEGER;
  if (EQ (sym, QATOM))		return XA_ATOM;
  if (EQ (sym, QCLIPBOARD))	return DEVICE_XATOM_CLIPBOARD (d);
  if (EQ (sym, QTIMESTAMP))	return DEVICE_XATOM_TIMESTAMP (d);
  if (EQ (sym, QTEXT))		return DEVICE_XATOM_TEXT      (d);
  if (EQ (sym, QDELETE))	return DEVICE_XATOM_DELETE    (d);
  if (EQ (sym, QMULTIPLE))	return DEVICE_XATOM_MULTIPLE  (d);
  if (EQ (sym, QINCR))		return DEVICE_XATOM_INCR      (d);
  if (EQ (sym, QEMACS_TMP))	return DEVICE_XATOM_EMACS_TMP (d);
  if (EQ (sym, QTARGETS))	return DEVICE_XATOM_TARGETS   (d);
  if (EQ (sym, QNULL))		return DEVICE_XATOM_NULL      (d);
  if (EQ (sym, QATOM_PAIR))	return DEVICE_XATOM_ATOM_PAIR (d);
  if (EQ (sym, QCOMPOUND_TEXT)) return DEVICE_XATOM_COMPOUND_TEXT (d);

#ifdef CUT_BUFFER_SUPPORT
  if (EQ (sym, QCUT_BUFFER0))	return XA_CUT_BUFFER0;
  if (EQ (sym, QCUT_BUFFER1))	return XA_CUT_BUFFER1;
  if (EQ (sym, QCUT_BUFFER2))	return XA_CUT_BUFFER2;
  if (EQ (sym, QCUT_BUFFER3))	return XA_CUT_BUFFER3;
  if (EQ (sym, QCUT_BUFFER4))	return XA_CUT_BUFFER4;
  if (EQ (sym, QCUT_BUFFER5))	return XA_CUT_BUFFER5;
  if (EQ (sym, QCUT_BUFFER6))	return XA_CUT_BUFFER6;
  if (EQ (sym, QCUT_BUFFER7))	return XA_CUT_BUFFER7;
#endif /* CUT_BUFFER_SUPPORT */

  {
    const Extbyte *nameext;
    nameext = LISP_STRING_TO_EXTERNAL (Fsymbol_name (sym), Qctext);
    return XInternAtom (display, nameext, only_if_exists ? True : False);
  }
}


/* This converts a server Atom to a Lisp symbol, avoiding server roundtrips
   and calls to intern whenever possible.
 */
static Lisp_Object
x_atom_to_symbol (struct device *d, Atom atom)
{
  Display *display = DEVICE_X_DISPLAY (d);

  if (! atom) return Qnil;
  if (atom == XA_PRIMARY)	return QPRIMARY;
  if (atom == XA_SECONDARY)	return QSECONDARY;
  if (atom == XA_STRING)	return QSTRING;
  if (atom == XA_INTEGER)	return QINTEGER;
  if (atom == XA_ATOM)		return QATOM;
  if (atom == DEVICE_XATOM_CLIPBOARD (d)) return QCLIPBOARD;
  if (atom == DEVICE_XATOM_TIMESTAMP (d)) return QTIMESTAMP;
  if (atom == DEVICE_XATOM_TEXT      (d)) return QTEXT;
  if (atom == DEVICE_XATOM_DELETE    (d)) return QDELETE;
  if (atom == DEVICE_XATOM_MULTIPLE  (d)) return QMULTIPLE;
  if (atom == DEVICE_XATOM_INCR      (d)) return QINCR;
  if (atom == DEVICE_XATOM_EMACS_TMP (d)) return QEMACS_TMP;
  if (atom == DEVICE_XATOM_TARGETS   (d)) return QTARGETS;
  if (atom == DEVICE_XATOM_NULL      (d)) return QNULL;
  if (atom == DEVICE_XATOM_ATOM_PAIR (d)) return QATOM_PAIR;
  if (atom == DEVICE_XATOM_COMPOUND_TEXT (d)) return QCOMPOUND_TEXT;

#ifdef CUT_BUFFER_SUPPORT
  if (atom == XA_CUT_BUFFER0)	return QCUT_BUFFER0;
  if (atom == XA_CUT_BUFFER1)	return QCUT_BUFFER1;
  if (atom == XA_CUT_BUFFER2)	return QCUT_BUFFER2;
  if (atom == XA_CUT_BUFFER3)	return QCUT_BUFFER3;
  if (atom == XA_CUT_BUFFER4)	return QCUT_BUFFER4;
  if (atom == XA_CUT_BUFFER5)	return QCUT_BUFFER5;
  if (atom == XA_CUT_BUFFER6)	return QCUT_BUFFER6;
  if (atom == XA_CUT_BUFFER7)	return QCUT_BUFFER7;
#endif

  {
    Ibyte *intstr;
    Extbyte *str = XGetAtomName (display, atom);

    if (! str) return Qnil;

    intstr = EXTERNAL_TO_ITEXT (str, Qctext);
    XFree (str);
    return intern_istring (intstr);
  }
}

#define THIS_IS_X
#include "select-xlike-inc.c"
#undef THIS_IS_X

/* Do protocol to assert ourself as a selection owner.
 */
static Lisp_Object
x_own_selection (Lisp_Object selection_name,
#ifdef MOTIF_CLIPBOARDS
		 Lisp_Object selection_value,
#else
		 Lisp_Object UNUSED (selection_value),
#endif
		 Lisp_Object UNUSED (how_to_add),
		 Lisp_Object UNUSED (selection_type),
#ifdef MOTIF_CLIPBOARDS
		 int owned_p
#else
		 int UNUSED (owned_p)
#endif
)
{
  struct device *d = decode_x_device (Qnil);
  Display *display = DEVICE_X_DISPLAY (d);
  struct frame *sel_frame = selected_frame ();
  Window selecting_window = XtWindow (FRAME_X_TEXT_WIDGET (sel_frame));
  Lisp_Object selection_time;
  /* Use the time of the last-read mouse or keyboard event.
     For selection purposes, we use this as a sleazy way of knowing what the
     current time is in server-time.  This assumes that the most recently read
     mouse or keyboard event has something to do with the assertion of the
     selection, which is probably true.
     */
  Time thyme = DEVICE_X_MOUSE_TIMESTAMP (d);
  Atom selection_atom;

  CHECK_SYMBOL (selection_name);
  selection_atom = symbol_to_x_atom (d, selection_name, 0);

  XSetSelectionOwner (display, selection_atom, selecting_window, thyme);

  /* [[ We do NOT use time_to_lisp() here any more, like we used to.
     That assumed equivalence of time_t and Time, which is not
     necessarily the case (e.g. under OSF on the Alphas, where
     Time is a 64-bit quantity and time_t is a 32-bit quantity).]]

     This is wrong--on Digital Unix, time_t is a sixty-four-bit quantity,
     and Time is, as the X protocol dictates, a thirty-two-bit quantity.

     [[ Opaque pointers are the clean way to go here. ]]

     Again, I disagree--the Lisp selection infrastructure needs to be
     able to manipulate the selection timestamps if it is, as we want
     it to, to be able to do most of the work. Though I have moved the
     conversion to lisp to get-xemacs-selection-timestamp. -- Aidan. */
	
  selection_time = make_opaque (&thyme, sizeof (thyme));

#ifdef MOTIF_CLIPBOARDS
  hack_motif_clipboard_selection (selection_atom, selection_value,
				  thyme, display, selecting_window, owned_p);
#endif
  return selection_time;
}

#ifdef MOTIF_CLIPBOARDS /* Bend over baby.  Take it and like it. */

# ifdef MOTIF_INCREMENTAL_CLIPBOARDS_WORK
static void motif_clipboard_cb ();
# endif

static void
hack_motif_clipboard_selection (Atom selection_atom,
				Lisp_Object selection_value,
				Time thyme,
				Display *display,
				Window selecting_window,
				int owned_p)
{
  struct device *d = get_device_from_display (display);
  /* Those Motif wankers can't be bothered to follow the ICCCM, and do
     their own non-Xlib non-Xt clipboard processing.  So we have to do
     this so that linked-in Motif widgets don't get themselves wedged.
   */
  if (selection_atom == DEVICE_XATOM_CLIPBOARD (d)
      && STRINGP (selection_value)

      /* If we already own the clipboard, don't own it again in the Motif
	 way.  This might lose in some subtle way, since the timestamp won't
	 be current, but owning the selection on the Motif way does a
	 SHITLOAD of X protocol, and it makes killing text be incredibly
	 slow when using an X terminal.  ARRRRGGGHHH!!!!
       */
      /* No, this is no good, because then Motif text fields don't bother
	 to look up the new value, and you can't Copy from a buffer, Paste
	 into a text field, then Copy something else from the buffer and
	 paste it into the text field -- it pastes the first thing again. */
      && (!owned_p 
	  /* Selectively re-enable this because for most users its
	     just too painful - especially over a remote link. */
	  || x_selection_strict_motif_ownership)
      )
    {
#ifdef MOTIF_INCREMENTAL_CLIPBOARDS_WORK
      Widget widget = FRAME_X_TEXT_WIDGET (selected_frame());
#endif
      long itemid;
#if XmVersion >= 1002
      long dataid;
#else
      int dataid;	/* 1.2 wants long, but 1.1.5 wants int... */
#endif
      XmString fmh;
      String encoding = "STRING";
      const Ibyte *data  = XSTRING_DATA (selection_value);
      Bytecount bytes = XSTRING_LENGTH (selection_value);

#ifdef MULE
      {
	enum { ASCII, LATIN_1, WORLD } chartypes = ASCII;
	const Ibyte *ptr = data, *end = ptr + bytes;
	/* Optimize for the common ASCII case */
	while (ptr <= end)
	  {
	    if (byte_ascii_p (*ptr))
	      {
		ptr++;
		continue;
	      }

	    if ((*ptr) == LEADING_BYTE_LATIN_ISO8859_1 ||
		(*ptr) == LEADING_BYTE_CONTROL_1)
	      {
		chartypes = LATIN_1;
		ptr += 2;
		continue;
	      }

	    chartypes = WORLD;
	    break;
	  }

	if (chartypes == LATIN_1)
	  LISP_STRING_TO_SIZED_EXTERNAL (selection_value, data, bytes,
					 Qbinary);
	else if (chartypes == WORLD)
	  {
	    LISP_STRING_TO_SIZED_EXTERNAL (selection_value, data, bytes,
					   Qctext);
	    encoding = "COMPOUND_TEXT";
	  }
      }
#endif /* MULE */

      fmh = XmStringCreateLtoR ("Clipboard", XmSTRING_DEFAULT_CHARSET);
      while (ClipboardSuccess !=
	     XmClipboardStartCopy (display, selecting_window, fmh, thyme,
#ifdef MOTIF_INCREMENTAL_CLIPBOARDS_WORK
				   widget, motif_clipboard_cb,
#else
				   0, NULL,
#endif
				   &itemid))
	;
      XmStringFree (fmh);
      while (ClipboardSuccess !=
	     XmClipboardCopy (display, selecting_window, itemid, encoding,
#ifdef MOTIF_INCREMENTAL_CLIPBOARDS_WORK
			      /* O'Reilly examples say size can be 0,
				 but this clearly is not the case. */
			      0, bytes, (int) selecting_window, /* private id */
#else /* !MOTIF_INCREMENTAL_CLIPBOARDS_WORK */
			      (XtPointer) data, bytes, 0,
#endif /* !MOTIF_INCREMENTAL_CLIPBOARDS_WORK */
			      &dataid))
	;
      while (ClipboardSuccess !=
	     XmClipboardEndCopy (display, selecting_window, itemid))
	;
    }
}

# ifdef MOTIF_INCREMENTAL_CLIPBOARDS_WORK
/* I tried to treat the clipboard like a real selection, and not send
   the data until it was requested, but it looks like that just doesn't
   work at all unless the selection owner and requestor are in different
   processes.  From reading the Motif source, it looks like they never
   even considered having two widgets in the same application transfer
   data between each other using "by-name" clipboard values.  What a
   bunch of fuckups.
 */
static void
motif_clipboard_cb (Widget widget, int *data_id, int *private_id, int *reason)
{
  switch (*reason)
    {
    case XmCR_CLIPBOARD_DATA_REQUEST:
      {
	Display *dpy = XtDisplay (widget);
	Window window = (Window) *private_id;
	Lisp_Object selection = select_convert_out (QCLIPBOARD, Qnil, Qnil);

	/* Whichever lazy git wrote this originally just called ABORT()
	   when anything didn't go their way... */

	/* Try some other text types */
	if (NILP (selection))
	  selection = select_convert_out (QCLIPBOARD, QSTRING, Qnil);
	if (NILP (selection))
	  selection = select_convert_out (QCLIPBOARD, QTEXT, Qnil);
	if (NILP (selection))
	  selection = select_convert_out (QCLIPBOARD, QCOMPOUND_TEXT, Qnil);

	if (CONSP (selection) && SYMBOLP (XCAR (selection))
	    && (EQ (XCAR (selection), QSTRING)
		|| EQ (XCAR (selection), QTEXT)
		|| EQ (XCAR (selection), QCOMPOUND_TEXT)))
	  selection = XCDR (selection);

	if (NILP (selection))
	  signal_error (Qselection_conversion_error, "no selection",
			     Qunbound);

	if (!STRINGP (selection))
	  signal_error (Qselection_conversion_error,
			     "couldn't convert selection to string", Qunbound);


	XmClipboardCopyByName (dpy, window, *data_id,
			       (char *) XSTRING_DATA (selection),
			       XSTRING_LENGTH (selection) + 1,
			       0);
      }
      break;
    case XmCR_CLIPBOARD_DATA_DELETE:
    default:
      /* don't need to free anything */
      break;
    }
}
# endif /* MOTIF_INCREMENTAL_CLIPBOARDS_WORK */
#endif /* MOTIF_CLIPBOARDS */




/* Send a SelectionNotify event to the requestor with property=None, meaning
   we were unable to do what they wanted.
 */
static void
x_decline_selection_request (XSelectionRequestEvent *event)
{
  XSelectionEvent reply;
  reply.type      = SelectionNotify;
  reply.display   = event->display;
  reply.requestor = event->requestor;
  reply.selection = event->selection;
  reply.time      = event->time;
  reply.target    = event->target;
  reply.property  = None;

  XSendEvent (reply.display, reply.requestor, False, 0L, (XEvent *) &reply);
  XFlush (reply.display);
}


/* Used as an unwind-protect clause so that, if a selection-converter signals
   an error, we tell the requestor that we were unable to do what they wanted
   before we throw to top-level or go into the debugger or whatever.
 */
static Lisp_Object
x_selection_request_lisp_error (Lisp_Object closure)
{
  XSelectionRequestEvent *event = (XSelectionRequestEvent *)
    get_opaque_ptr (closure);

  free_opaque_ptr (closure);
  if (event->type == 0) /* we set this to mean "completed normally" */
    return Qnil;
  x_decline_selection_request (event);
  return Qnil;
}


/* Convert our selection to the requested type, and put that data where the
   requestor wants it.  Then tell them whether we've succeeded.
 */
static void
x_reply_selection_request (XSelectionRequestEvent *event, int format,
			   Rawbyte *data, Bytecount size, Atom type)
{
  /* This function can GC */
  XSelectionEvent reply;
  Display *display = event->display;
  struct device *d = get_device_from_display (display);
  Window window = event->requestor;
  Bytecount bytes_remaining;
  int format_bytes = format/8;
  Bytecount max_bytes = SELECTION_QUANTUM (display);
  if (max_bytes > MAX_SELECTION_QUANTUM) max_bytes = MAX_SELECTION_QUANTUM;

  reply.type      = SelectionNotify;
  reply.display   = display;
  reply.requestor = window;
  reply.selection = event->selection;
  reply.time      = event->time;
  reply.target    = event->target;
  reply.property  = (event->property == None ? event->target : event->property);

  /* #### XChangeProperty can generate BadAlloc, and we must handle it! */

  /* Store the data on the requested property.
     If the selection is large, only store the first N bytes of it.
   */
  bytes_remaining = size * format_bytes;
  if (bytes_remaining <= max_bytes)
    {
      /* Send all the data at once, with minimal handshaking. */
#if 0
      stderr_out ("\nStoring all %d\n", bytes_remaining);
#endif
      XChangeProperty (display, window, reply.property, type, format,
		       PropModeReplace, data, size);
      /* At this point, the selection was successfully stored; ack it. */
      XSendEvent (display, window, False, 0L, (XEvent *) &reply);
      XFlush (display);
    }
  else
    {
#ifndef HAVE_XTREGISTERDRAWABLE
      invalid_operation("Copying that much data requires X11R6.", Qunbound);
#else
      /* Send an INCR selection. */
      int prop_id;
      Widget widget = FRAME_X_TEXT_WIDGET (XFRAME(DEVICE_SELECTED_FRAME(d)));

      if (x_window_to_frame (d, window)) /* #### debug */
	invalid_operation ("attempt to transfer an INCR to ourself!",
			   Qunbound);
#if 0
      stderr_out ("\nINCR %d\n", bytes_remaining);
#endif

      /* Tell Xt not to drop PropertyNotify events that arrive for the
         target window, rather, pass them to us. This would be a hack, but
         the Xt selection routines are broken for our purposes--we can't
         pass them callbacks from Lisp, for example. Let's call it a
         workaround.

	 The call to wait_for_property_change means we can break out of that
	 function, switch to another frame on the same display (which will
	 be another Xt widget), select a huge amount of text, and have the
	 same (foreign) app ask for another incremental selection
	 transfer. Programming like X11 made sense, would mean that, in that
	 case, XtRegisterDrawable is called twice with different widgets.

	 Since the results of calling XtRegisterDrawable when the drawable
	 is already registered with another widget are undefined, we want to
	 avoid that--so, only call it when XtWindowToWidget returns NULL,
	 which it will only do with a valid Window if it's not already
	 registered. */
      if (NULL == XtWindowToWidget(display, window))
      {
	XtRegisterDrawable(display, (Drawable)window, widget);
      }

      prop_id = expect_property_change (display, window, reply.property,
					PropertyDelete);

      XChangeProperty (display, window, reply.property, DEVICE_XATOM_INCR (d),
		       32, PropModeReplace, (Rawbyte *)
		       &bytes_remaining, 1);
      XSelectInput (display, window, PropertyChangeMask);
      /* Tell 'em the INCR data is there... */
      XSendEvent (display, window, False, 0L, (XEvent *) &reply);
      XFlush (display);

      /* First, wait for the requestor to ack by deleting the property.
	 This can run random lisp code (process handlers) or signal.
       */
      wait_for_property_change (prop_id);

      while (bytes_remaining)
	{
	  Bytecount i = ((bytes_remaining < max_bytes)
		   ? bytes_remaining
		   : max_bytes);
	  prop_id = expect_property_change (display, window, reply.property,
					    PropertyDelete);
#if 0
	  stderr_out ("  INCR adding %d\n", i);
#endif
	  /* Append the next chunk of data to the property. */
	  XChangeProperty (display, window, reply.property, type, format,
			   PropModeAppend, data, i / format_bytes);
	  bytes_remaining -= i;
	  data += i;

	  /* Now wait for the requestor to ack this chunk by deleting the
	     property.	 This can run random lisp code or signal.
	   */
	  wait_for_property_change (prop_id);
	}
      /* Now write a zero-length chunk to the property to tell the requestor
	 that we're done. */
#if 0
      stderr_out ("  INCR done\n");
#endif
      if (! waiting_for_other_props_on_window (display, window))
      {
	XSelectInput (display, window, 0L);
	XtUnregisterDrawable(display, (Drawable)window);
      }
      XChangeProperty (display, window, reply.property, type, format,
		       PropModeReplace, data, 0);
#endif /* HAVE_XTREGISTERDRAWABLE */
    }
}



/* Called from the event-loop in response to a SelectionRequest event.
 */
void
x_handle_selection_request (XSelectionRequestEvent *event)
{
  /* This function can GC */
  struct gcpro gcpro1, gcpro2;
  Lisp_Object temp_obj;
  Lisp_Object selection_symbol;
  Lisp_Object target_symbol = Qnil;
  Lisp_Object converted_selection = Qnil;
  Time local_selection_time;
  Lisp_Object successful_p = Qnil;
  int count;
  struct device *d = get_device_from_display (event->display);

  GCPRO2 (converted_selection, target_symbol);

  selection_symbol = x_atom_to_symbol (d, event->selection);
  target_symbol = x_atom_to_symbol (d, event->target);

#if 0 /* #### MULTIPLE doesn't work yet */
  if (EQ (target_symbol, QMULTIPLE))
    target_symbol = fetch_multiple_target (event);
#endif

  temp_obj = get_selection_raw_time (selection_symbol);

  if (NILP (temp_obj))
    {
      /* We don't appear to have the selection. */
      x_decline_selection_request (event);

      goto DONE_LABEL;
    }

  local_selection_time = * (Time *) XOPAQUE_DATA (temp_obj);

  if (event->time != CurrentTime &&
      local_selection_time > event->time)
    {
      /* Someone asked for the selection, and we have one, but not the one
	 they're looking for. */
      x_decline_selection_request (event);
      goto DONE_LABEL;
    }

  converted_selection = select_convert_out (selection_symbol,
					    target_symbol, Qnil);

  /* #### Is this the right thing to do? I'm no X expert. -- ajh */
  if (NILP (converted_selection))
    {
      /* We don't appear to have a selection in that data type. */
      x_decline_selection_request (event);
      goto DONE_LABEL;
    }

  count = specpdl_depth ();
  record_unwind_protect (x_selection_request_lisp_error,
			 make_opaque_ptr (event));

  {
    Rawbyte *data;
    Bytecount size;
    int format;
    Atom type;
    lisp_data_to_selection_data (d, converted_selection,
				 &data, &type, &size, &format);

    x_reply_selection_request (event, format, data, size, type);
    successful_p = Qt;
    /* Tell x_selection_request_lisp_error() it's cool. */
    event->type = 0;
    /* Data need not have been allocated; cf. select-convert-to-delete in
       lisp/select.el . */
    if (data)
      xfree (data);
  }

  unbind_to (count);

 DONE_LABEL:

  UNGCPRO;

  /* Let random lisp code notice that the selection has been asked for. */
  va_run_hook_with_args (Qx_sent_selection_hooks, 3, selection_symbol,
                         target_symbol, successful_p);
}


/* Called from the event-loop in response to a SelectionClear event.
 */
void
x_handle_selection_clear (XSelectionClearEvent *event)
{
  Display *display = event->display;
  struct device *d = get_device_from_display (display);
  Atom selection = event->selection;
  Time changed_owner_time = event->time;

  Lisp_Object selection_symbol, local_selection_time_lisp;
  Time local_selection_time;

  selection_symbol = x_atom_to_symbol (d, selection);

  local_selection_time_lisp = get_selection_raw_time (selection_symbol);

  /* We don't own the selection, so that's fine. */
  if (NILP (local_selection_time_lisp))
    return;

  local_selection_time = * (Time *) XOPAQUE_DATA (local_selection_time_lisp);

  /* This SelectionClear is for a selection that we no longer own, so we can
     disregard it.  (That is, we have reasserted the selection since this
     request was generated.)
   */
  if (changed_owner_time != CurrentTime &&
      local_selection_time > changed_owner_time)
    return;

  handle_selection_clear (selection_symbol);
}


/* This stuff is so that INCR selections are reentrant (that is, so we can
   be servicing multiple INCR selection requests simultaneously).  I haven't
   actually tested that yet.
 */

static int prop_location_tick;

static struct prop_location {
  int tick;
  Display *display;
  Window window;
  Atom property;
  int desired_state;
  struct prop_location *next;
} *for_whom_the_bell_tolls;


static int
property_deleted_p (void *tick)
{
  struct prop_location *rest = for_whom_the_bell_tolls;
  while (rest)
    if (rest->tick == (long) tick)
      return 0;
    else
      rest = rest->next;
  return 1;
}

static int
waiting_for_other_props_on_window (Display *display, Window window)
{
  struct prop_location *rest = for_whom_the_bell_tolls;
  while (rest)
    if (rest->display == display && rest->window == window)
      return 1;
    else
      rest = rest->next;
  return 0;
}


static int
expect_property_change (Display *display, Window window,
			Atom property, int state)
{
  struct prop_location *pl = xnew (struct prop_location);
  pl->tick = ++prop_location_tick;
  pl->display = display;
  pl->window = window;
  pl->property = property;
  pl->desired_state = state;
  pl->next = for_whom_the_bell_tolls;
  for_whom_the_bell_tolls = pl;
  return pl->tick;
}

static void
unexpect_property_change (int tick)
{
  struct prop_location *prev = 0, *rest = for_whom_the_bell_tolls;
  while (rest)
    {
      if (rest->tick == tick)
	{
	  if (prev)
	    prev->next = rest->next;
	  else
	    for_whom_the_bell_tolls = rest->next;
	  xfree (rest);
	  return;
	}
      prev = rest;
      rest = rest->next;
    }
}

static void
wait_for_property_change (long tick)
{
  /* This function can GC */
  wait_delaying_user_input (property_deleted_p, (void *) tick);
}


/* Called from the event-loop in response to a PropertyNotify event.
 */
void
x_handle_property_notify (XPropertyEvent *event)
{
  struct prop_location *prev = 0, *rest = for_whom_the_bell_tolls;
  while (rest)
    {
      if (rest->property == event->atom &&
	  rest->window == event->window &&
	  rest->display == event->display &&
	  rest->desired_state == event->state)
	{
#if 0
	  stderr_out ("Saw expected prop-%s on %s\n",
		      (event->state == PropertyDelete ? "delete" : "change"),
		      XSTRING_DATA
		      (XSYMBOL (x_atom_to_symbol
				(get_device_from_display (event->display),
				 event->atom))->name));
#endif
	  if (prev)
	    prev->next = rest->next;
	  else
	    for_whom_the_bell_tolls = rest->next;
	  xfree (rest);
	  return;
	}
      prev = rest;
      rest = rest->next;
    }
#if 0
  stderr_out ("Saw UNexpected prop-%s on %s\n",
	      (event->state == PropertyDelete ? "delete" : "change"),
	      XSTRING_DATA (XSYMBOL (x_atom_to_symbol
				     (get_device_from_display (event->display),
				      event->atom))->name));
#endif
}



#if 0 /* #### MULTIPLE doesn't work yet */

static Lisp_Object
fetch_multiple_target (XSelectionRequestEvent *event)
{
  /* This function can GC */
  Display *display = event->display;
  Window window = event->requestor;
  Atom target = event->target;
  Atom selection_atom = event->selection;
  int result;

  return
    Fcons (QMULTIPLE,
	   x_get_window_property_as_lisp_data (display, window, target,
					       QMULTIPLE,
					       selection_atom));
}

static Lisp_Object
copy_multiple_data (Lisp_Object obj)
{
  Lisp_Object vec;
  Elemcount i;
  Elemcount len;
  if (CONSP (obj))
    return Fcons (XCAR (obj), copy_multiple_data (XCDR (obj)));

  CHECK_VECTOR (obj);
  len = XVECTOR_LENGTH (obj);
  vec = make_vector (len, Qnil);
  for (i = 0; i < len; i++)
    {
      Lisp_Object vec2 = XVECTOR_DATA (obj) [i];
      CHECK_VECTOR (vec2);
      if (XVECTOR_LENGTH (vec2) != 2)
	sferror ("vectors must be of length 2", vec2);
      XVECTOR_DATA (vec) [i] = make_vector (2, Qnil);
      XVECTOR_DATA (XVECTOR_DATA (vec) [i]) [0] = XVECTOR_DATA (vec2) [0];
      XVECTOR_DATA (XVECTOR_DATA (vec) [i]) [1] = XVECTOR_DATA (vec2) [1];
    }
  return vec;
}

#endif /* 0 */


static Window reading_selection_reply;
static Atom reading_which_selection;
static int selection_reply_timed_out;

static int
selection_reply_done (void *UNUSED (unused))
{
  return !reading_selection_reply;
}

static Lisp_Object Qx_selection_reply_timeout_internal;

DEFUN ("x-selection-reply-timeout-internal", Fx_selection_reply_timeout_internal,
       1, 1, 0, /*
*/
       (UNUSED (arg)))
{
  selection_reply_timed_out = 1;
  reading_selection_reply = 0;
  return Qnil;
}


/* Do protocol to read selection-data from the server.
   Converts this to lisp data and returns it.
 */
static Lisp_Object
x_get_foreign_selection (Lisp_Object selection_symbol, Lisp_Object target_type)
{
  /* This function can GC */
  struct device *d = decode_x_device (Qnil);
  Display *display = DEVICE_X_DISPLAY (d);
  struct frame *sel_frame = selected_frame ();
  Window requestor_window = XtWindow (FRAME_X_TEXT_WIDGET (sel_frame));
  Time requestor_time = DEVICE_X_MOUSE_TIMESTAMP (d);
  Atom target_property = DEVICE_XATOM_EMACS_TMP (d);
  Atom selection_atom = symbol_to_x_atom (d, selection_symbol, 0);
  int speccount;
  Atom type_atom = symbol_to_x_atom (d, (CONSP (target_type) ?
					 XCAR (target_type) : target_type), 0);

  XConvertSelection (display, selection_atom, type_atom, target_property,
		     requestor_window, requestor_time);

  /* Block until the reply has been read. */
  reading_selection_reply = requestor_window;
  reading_which_selection = selection_atom;
  selection_reply_timed_out = 0;

  speccount = specpdl_depth ();

  /* add a timeout handler */
  if (x_selection_timeout > 0)
    {
      Lisp_Object id = Fadd_timeout (make_fixnum (x_selection_timeout),
				     Qx_selection_reply_timeout_internal,
				     Qnil, Qnil);
      record_unwind_protect (Fdisable_timeout, id);
    }

  /* This is ^Gable */
  wait_delaying_user_input (selection_reply_done, 0);

  if (selection_reply_timed_out)
    signal_error (Qselection_conversion_error, "timed out waiting for reply from selection owner", Qunbound);

  unbind_to (speccount);

  /* otherwise, the selection is waiting for us on the requested property. */

  return select_convert_in (selection_symbol,
			    target_type,
			    x_get_window_property_as_lisp_data(display,
							       requestor_window,
							       target_property,
							       target_type,
							       selection_atom));
}


static void
x_get_window_property (Display *display, Window window, Atom property,
		       Rawbyte **data_ret, Bytecount *bytes_ret,
		       Atom *actual_type_ret, int *actual_format_ret,
		       unsigned long *actual_size_ret, int delete_p)
{
  Bytecount total_size;
  unsigned long bytes_remaining;
  Bytecount offset = 0;
  Rawbyte *tmp_data = 0;
  int result;
  Bytecount buffer_size = SELECTION_QUANTUM (display);
  if (buffer_size > MAX_SELECTION_QUANTUM) buffer_size = MAX_SELECTION_QUANTUM;

  /* First probe the thing to find out how big it is. */
  result = XGetWindowProperty (display, window, property,
			       0, 0, False, AnyPropertyType,
			       actual_type_ret, actual_format_ret,
			       actual_size_ret,
			       &bytes_remaining, &tmp_data);
  if (result != Success)
    {
      *data_ret = 0;
      *bytes_ret = 0;
      return;
    }
  XFree ((char *) tmp_data);

  if (*actual_type_ret == None || *actual_format_ret == 0)
    {
      if (delete_p) XDeleteProperty (display, window, property);
      *data_ret = 0;
      *bytes_ret = 0;
      return;
    }

  /* The manpage for XGetWindowProperty from X.org X11.7.2 sez:
       nitems_return [[ our actual_size_ret ]]
                 Returns the actual number of 8-bit, 16-bit, or 32-bit items
                 stored in the prop_return data.
       prop_return [[ our tmp_data ]]
                 Returns the data in the specified format.  If the returned
                 format is 8, the returned data is represented as a char
                 array. If the returned format is 16, the returned data is
                 represented as a array of short int type and should be cast
                 to that type to obtain the elements. If the returned format
                 is 32, the property data will be stored as an array of longs
                 (which in a 64-bit application will be 64-bit values that are
                 padded in the upper 4 bytes).
       bytes_after_return [[ our bytes_remaining ]]
                 Returns the number of bytes remaining to be read in the prop-
                 erty if a partial read was performed.

     AFAIK XEmacs does not support any platforms where the char type is other
     than 8 bits (Cray?), or where the short type is other than 16 bits.
     There is no such agreement on the size of long, and 64-bit platforms
     generally make long be a 64-bit quantity while while it's 32 bits on
     32-bit platforms.

     This means that on all platforms the wire item is the same size as our
     buffer unit when format == 8 or format == 16 or format == wordsize == 32,
     and the buffer size can be taken as bytes_remaining plus padding.
     However, when format == 32 and wordsize == 64, the buffer unit is twice
     the size of the wire item.  Obviously this code below is not 128-bit
     safe.  (We could replace the factor 2 with (sizeof(long)*8/32.)

     We can hope it doesn't much matter on versions of X11 earlier than R7.
  */
  if (sizeof(long) == 8 && *actual_format_ret == 32)
    total_size = 2 * bytes_remaining + 1;
  else
    total_size = bytes_remaining + 1;
  *data_ret = xnew_rawbytes (total_size);

  /* Now read, until we've gotten it all. */
  while (bytes_remaining)
    {
#if 0
      Bytecount last = bytes_remaining;
#endif
      result =
	XGetWindowProperty (display, window, property,
			    offset/4, buffer_size/4,
			    (delete_p ? True : False),
			    AnyPropertyType,
			    actual_type_ret, actual_format_ret,
			    actual_size_ret, &bytes_remaining, &tmp_data);
#if 0
      stderr_out ("<< read %d\n", last-bytes_remaining);
#endif
      /* If this doesn't return Success at this point, it means that
	 some clod deleted the selection while we were in the midst of
	 reading it.  Deal with that, I guess....
       */
      if (result != Success) break;
      /* Again we need to compute the number of bytes in our buffer, not
	 the number of bytes transferred for the property. */
      if (sizeof(long) == 8 && *actual_format_ret == 32)
	*actual_size_ret *= 8;
      else
	*actual_size_ret *= *actual_format_ret / 8;
      memcpy ((*data_ret) + offset, tmp_data, *actual_size_ret);
      offset += *actual_size_ret;
      XFree ((char *) tmp_data);
    }
  *bytes_ret = offset;
}


static void
receive_incremental_selection (Display *display, Window window, Atom property,
			       /* this one is for error messages only */
			       Lisp_Object UNUSED (target_type),
			       Bytecount min_size_bytes,
			       Rawbyte **data_ret,
			       Bytecount *size_bytes_ret,
			       Atom *type_ret, int *format_ret,
			       unsigned long *size_ret)
{
  /* This function can GC */
  Bytecount offset = 0;
  int prop_id;
  *size_bytes_ret = min_size_bytes;
  *data_ret = xnew_rawbytes (*size_bytes_ret);
#if 0
  stderr_out ("\nread INCR %d\n", min_size_bytes);
#endif
  /* At this point, we have read an INCR property, and deleted it (which
     is how we ack its receipt: the sending window will be selecting
     PropertyNotify events on our window to notice this).

     Now, we must loop, waiting for the sending window to put a value on
     that property, then reading the property, then deleting it to ack.
     We are done when the sender places a property of length 0.
   */
  prop_id = expect_property_change (display, window, property,
				    PropertyNewValue);
  while (1)
    {
      Rawbyte *tmp_data;
      Bytecount tmp_size_bytes;
      wait_for_property_change (prop_id);
      /* expect it again immediately, because x_get_window_property may
	 .. no it won't, I don't get it.
	 .. Ok, I get it now, the Xt code that implements INCR is broken.
       */
      prop_id = expect_property_change (display, window, property,
					PropertyNewValue);
      x_get_window_property (display, window, property,
			     &tmp_data, &tmp_size_bytes,
			     type_ret, format_ret, size_ret, 1);

      if (tmp_size_bytes == 0) /* we're done */
	{
#if 0
	  stderr_out ("  read INCR done\n");
#endif
	  unexpect_property_change (prop_id);
	  if (tmp_data)
	    xfree (tmp_data);
	  break;
	}
#if 0
      stderr_out ("  read INCR %d\n", tmp_size_bytes);
#endif
      if (*size_bytes_ret < offset + tmp_size_bytes)
	{
#if 0
	  stderr_out ("  read INCR realloc %d -> %d\n",
		   *size_bytes_ret, offset + tmp_size_bytes);
#endif
	  *size_bytes_ret = offset + tmp_size_bytes;
	  *data_ret = (Rawbyte *) xrealloc (*data_ret, *size_bytes_ret);
	}
      memcpy ((*data_ret) + offset, tmp_data, tmp_size_bytes);
      offset += tmp_size_bytes;
      xfree (tmp_data);
    }
}


static Lisp_Object
x_get_window_property_as_lisp_data (Display *display,
				    Window window,
				    Atom property,
				    /* next two for error messages only */
				    Lisp_Object target_type,
				    Atom selection_atom)
{
  /* This function can GC */
  Atom actual_type;
  int actual_format;
  unsigned long actual_size;
  Rawbyte *data = NULL;
  Bytecount bytes = 0;
  Lisp_Object val;
  struct device *d = get_device_from_display (display);

  x_get_window_property (display, window, property, &data, &bytes,
			 &actual_type, &actual_format, &actual_size, 1);
  if (! data)
    {
      if (XGetSelectionOwner (display, selection_atom))
	/* there is a selection owner */
	signal_error (Qselection_conversion_error,
		      "selection owner couldn't convert",
		      Fcons (Qunbound,
			     Fcons (x_atom_to_symbol (d, selection_atom),
				    actual_type ?
				    list2 (target_type,
					   x_atom_to_symbol (d, actual_type)) :
				    list1 (target_type))));
      else
	signal_error (Qselection_conversion_error,
		      "no selection",
		      x_atom_to_symbol (d, selection_atom));
    }

  if (actual_type == DEVICE_XATOM_INCR (d))
    {
      /* Ok, that data wasn't *the* data, it was just the beginning. */

      Bytecount min_size_bytes =
	/* careful here. */
	(Bytecount) (* ((unsigned int *) data));
      xfree (data);
      receive_incremental_selection (display, window, property, target_type,
				     min_size_bytes, &data, &bytes,
				     &actual_type, &actual_format,
				     &actual_size);
    }

  /* It's been read.  Now convert it to a lisp object in some semi-rational
     manner. */
  val = selection_data_to_lisp_data (d, data, bytes,
				     actual_type, actual_format);

  xfree (data);
  return val;
}


/* Called from the event loop to handle SelectionNotify events.
   I don't think this needs to be reentrant.
 */
void
x_handle_selection_notify (XSelectionEvent *event)
{
  if (! reading_selection_reply)
    message ("received an unexpected SelectionNotify event");
  else if (event->requestor != reading_selection_reply)
    message ("received a SelectionNotify event for the wrong window");
  else if (event->selection != reading_which_selection)
    message ("received the wrong selection type in SelectionNotify!");
  else
    reading_selection_reply = 0; /* we're done now. */
}

static void
x_disown_selection (Lisp_Object selection, Lisp_Object timeval)
{
  struct device *d = decode_x_device (Qnil);
  Display *display = DEVICE_X_DISPLAY (d);
  Time timestamp;
  Atom selection_atom;

  CHECK_SYMBOL (selection);
  if (NILP (timeval))
    timestamp = DEVICE_X_MOUSE_TIMESTAMP (d);
  else
    {
      /* #### This is bogus.  See the comment above about problems
	 on OSF/1 and DEC Alphas.  Yet another reason why it sucks
	 to have the implementation (i.e. cons of two 16-bit
	 integers) exposed. */
      time_t the_time;
      lisp_to_time (timeval, &the_time);
      timestamp = (Time) the_time;
    }

  selection_atom = symbol_to_x_atom (d, selection, 0);

  XSetSelectionOwner (display, selection_atom, None, timestamp);
}

static Lisp_Object
x_selection_exists_p (Lisp_Object selection,
		      Lisp_Object UNUSED (selection_type))
{
  struct device *d = decode_x_device (Qnil);
  Display *dpy = DEVICE_X_DISPLAY (d);
  return XGetSelectionOwner (dpy, symbol_to_x_atom (d, selection, 0)) != None ?
    Qt : Qnil;
}


#ifdef CUT_BUFFER_SUPPORT

static int cut_buffers_initialized; /* Whether we're sure they all exist */

/* Ensure that all 8 cut buffers exist.  ICCCM says we gotta... */
static void
initialize_cut_buffers (Display *display, Window window)
{
  static unsigned const char * const data = (unsigned const char *) "";
#define FROB(atom) XChangeProperty (display, window, atom, XA_STRING, 8, \
				    PropModeAppend, data, 0)
  FROB (XA_CUT_BUFFER0);
  FROB (XA_CUT_BUFFER1);
  FROB (XA_CUT_BUFFER2);
  FROB (XA_CUT_BUFFER3);
  FROB (XA_CUT_BUFFER4);
  FROB (XA_CUT_BUFFER5);
  FROB (XA_CUT_BUFFER6);
  FROB (XA_CUT_BUFFER7);
#undef FROB
  cut_buffers_initialized = 1;
}

#define CHECK_CUTBUFFER(symbol) do {				\
  CHECK_SYMBOL (symbol);					\
  if (! (EQ (symbol, QCUT_BUFFER0) ||				\
	 EQ (symbol, QCUT_BUFFER1) ||				\
	 EQ (symbol, QCUT_BUFFER2) ||				\
	 EQ (symbol, QCUT_BUFFER3) ||				\
	 EQ (symbol, QCUT_BUFFER4) ||				\
	 EQ (symbol, QCUT_BUFFER5) ||				\
	 EQ (symbol, QCUT_BUFFER6) ||				\
	 EQ (symbol, QCUT_BUFFER7)))				\
    invalid_constant ("Doesn't name a cutbuffer", symbol);	\
} while (0)

DEFUN ("x-get-cutbuffer-internal", Fx_get_cutbuffer_internal, 1, 1, 0, /*
Return the value of the named CUTBUFFER (typically CUT_BUFFER0).
*/
       (cutbuffer))
{
  struct device *d = decode_x_device (Qnil);
  Display *display = DEVICE_X_DISPLAY (d);
  Window window = RootWindow (display, 0); /* Cutbuffers are on frame 0 */
  Atom cut_buffer_atom;
  Rawbyte *data;
  Bytecount bytes;
  Atom type;
  int format;
  unsigned long size;
  Lisp_Object ret;

  CHECK_CUTBUFFER (cutbuffer);
  cut_buffer_atom = symbol_to_x_atom (d, cutbuffer, 0);

  x_get_window_property (display, window, cut_buffer_atom, &data, &bytes,
			 &type, &format, &size, 0);
  if (!data) return Qnil;

  if (format != 8 || type != XA_STRING)
    invalid_state_2 ("Cut buffer doesn't contain 8-bit STRING data",
		     x_atom_to_symbol (d, type),
		     make_fixnum (format));

  /* We cheat - if the string contains an ESC character, that's
     technically not allowed in a STRING, so we assume it's
     COMPOUND_TEXT that we stored there ourselves earlier,
     in x-store-cutbuffer-internal  */
  ret = (bytes ?
	 make_extstring ((Extbyte *) data, bytes,
			  memchr (data, 0x1b, bytes) ?
			  Qctext : Qbinary)
	 : Qnil);
  xfree (data);
  return ret;
}


DEFUN ("x-store-cutbuffer-internal", Fx_store_cutbuffer_internal, 2, 2, 0, /*
Set the value of the named CUTBUFFER (typically CUT_BUFFER0) to STRING.
*/
       (cutbuffer, string))
{
  struct device *d = decode_x_device (Qnil);
  Display *display = DEVICE_X_DISPLAY (d);
  Window window = RootWindow (display, 0); /* Cutbuffers are on frame 0 */
  Atom cut_buffer_atom;
  const Ibyte *data;
  Bytecount bytes, bytes_remaining;
  Bytecount max_bytes = SELECTION_QUANTUM (display);
#ifdef MULE
  const Ibyte *ptr, *end;
  enum { ASCII, LATIN_1, WORLD } chartypes = ASCII;
#endif

  if (max_bytes > MAX_SELECTION_QUANTUM)
    max_bytes = MAX_SELECTION_QUANTUM;

  CHECK_CUTBUFFER (cutbuffer);
  CHECK_STRING (string);

  cut_buffer_atom = symbol_to_x_atom (d, cutbuffer, 0);
  data = XSTRING_DATA (string);
  bytes = XSTRING_LENGTH (string);

  if (! cut_buffers_initialized)
    initialize_cut_buffers (display, window);

  /* We use the STRING encoding (Latin-1 only) if we can, else COMPOUND_TEXT.
     We cheat and use type = `STRING' even when using COMPOUND_TEXT.
     The ICCCM requires that this be so, and other clients assume it,
     as we do ourselves in initialize_cut_buffers.  */

#ifdef MULE
  /* Optimize for the common ASCII case */
  for (ptr = data, end = ptr + bytes; ptr <= end; )
    {
      if (byte_ascii_p (*ptr))
	{
	  ptr++;
	  continue;
	}

      if ((*ptr) == LEADING_BYTE_LATIN_ISO8859_1 ||
	  (*ptr) == LEADING_BYTE_CONTROL_1)
	{
	  chartypes = LATIN_1;
	  ptr += 2;
	  continue;
	}

      chartypes = WORLD;
      break;
    }

  if (chartypes == LATIN_1)
    LISP_STRING_TO_SIZED_EXTERNAL (string, data, bytes, Qbinary);
  else if (chartypes == WORLD)
    LISP_STRING_TO_SIZED_EXTERNAL (string, data, bytes, Qctext);
#endif /* MULE */

  bytes_remaining = bytes;

  while (bytes_remaining)
    {
      Bytecount chunk =
	bytes_remaining < max_bytes ? bytes_remaining : max_bytes;
      XChangeProperty (display, window, cut_buffer_atom, XA_STRING, 8,
		       (bytes_remaining == bytes
			? PropModeReplace : PropModeAppend),
		       data, chunk);
      data += chunk;
      bytes_remaining -= chunk;
    }
  return string;
}


DEFUN ("x-rotate-cutbuffers-internal", Fx_rotate_cutbuffers_internal, 1, 1, 0, /*
Rotate the values of the cutbuffers by the given number of steps;
positive means move values forward, negative means backward.
*/
       (n))
{
  struct device *d = decode_x_device (Qnil);
  Display *display = DEVICE_X_DISPLAY (d);
  Window window = RootWindow (display, 0); /* Cutbuffers are on frame 0 */
  Atom props [8];

  CHECK_FIXNUM (n);
  if (XFIXNUM (n) == 0)
    return n;
  if (! cut_buffers_initialized)
    initialize_cut_buffers (display, window);
  props[0] = XA_CUT_BUFFER0;
  props[1] = XA_CUT_BUFFER1;
  props[2] = XA_CUT_BUFFER2;
  props[3] = XA_CUT_BUFFER3;
  props[4] = XA_CUT_BUFFER4;
  props[5] = XA_CUT_BUFFER5;
  props[6] = XA_CUT_BUFFER6;
  props[7] = XA_CUT_BUFFER7;
  XRotateWindowProperties (display, window, props, 8, XFIXNUM (n));
  return n;
}

#endif /* CUT_BUFFER_SUPPORT */



/************************************************************************/
/*                            initialization                            */
/************************************************************************/

void
syms_of_select_x (void)
{

#ifdef CUT_BUFFER_SUPPORT
  DEFSUBR (Fx_get_cutbuffer_internal);
  DEFSUBR (Fx_store_cutbuffer_internal);
  DEFSUBR (Fx_rotate_cutbuffers_internal);
#endif /* CUT_BUFFER_SUPPORT */

  DEFSYMBOL (Qx_sent_selection_hooks);

  /* Unfortunately, timeout handlers must be lisp functions. */
  DEFSYMBOL (Qx_selection_reply_timeout_internal);
  DEFSUBR (Fx_selection_reply_timeout_internal);

#ifdef CUT_BUFFER_SUPPORT
  defsymbol (&QCUT_BUFFER0, "CUT_BUFFER0");
  defsymbol (&QCUT_BUFFER1, "CUT_BUFFER1");
  defsymbol (&QCUT_BUFFER2, "CUT_BUFFER2");
  defsymbol (&QCUT_BUFFER3, "CUT_BUFFER3");
  defsymbol (&QCUT_BUFFER4, "CUT_BUFFER4");
  defsymbol (&QCUT_BUFFER5, "CUT_BUFFER5");
  defsymbol (&QCUT_BUFFER6, "CUT_BUFFER6");
  defsymbol (&QCUT_BUFFER7, "CUT_BUFFER7");
#endif /* CUT_BUFFER_SUPPORT */
}

void
console_type_create_select_x (void)
{
  CONSOLE_HAS_METHOD (x, own_selection);
  CONSOLE_HAS_METHOD (x, disown_selection);
  CONSOLE_HAS_METHOD (x, get_foreign_selection);
  CONSOLE_HAS_METHOD (x, selection_exists_p);
}

void
reinit_vars_of_select_x (void)
{
  reading_selection_reply = 0;
  reading_which_selection = 0;
  selection_reply_timed_out = 0;
  for_whom_the_bell_tolls = 0;
  prop_location_tick = 0;
}

void
vars_of_select_x (void)
{
#ifdef CUT_BUFFER_SUPPORT
  cut_buffers_initialized = 0;
  Fprovide (intern ("cut-buffer"));
#endif

  DEFVAR_LISP ("x-sent-selection-hooks", &Vx_sent_selection_hooks /*
A function or functions to be called after we have responded to some
other client's request for the value of a selection that we own.  The
function(s) will be called with four arguments:
  - the name of the selection (typically PRIMARY, SECONDARY, or CLIPBOARD);
  - the name of the selection-type which we were requested to convert the
    selection into before sending (for example, STRING or LENGTH);
  - and whether we successfully transmitted the selection.
We might have failed (and declined the request) for any number of reasons,
including being asked for a selection that we no longer own, or being asked
to convert into a type that we don't know about or that is inappropriate.
This hook doesn't let you change the behavior of emacs's selection replies,
it merely informs you that they have happened.
*/ );
  Vx_sent_selection_hooks = Qnil;

  DEFVAR_INT ("x-selection-timeout", &x_selection_timeout /*
If the selection owner doesn't reply in this many seconds, we give up.
A value of 0 means wait as long as necessary.  This is initialized from the
\"*selectionTimeout\" resource (which is expressed in milliseconds).
*/ );
  x_selection_timeout = 0;

  DEFVAR_BOOL ("x-selection-strict-motif-ownership", &x_selection_strict_motif_ownership /*
*If nil and XEmacs already owns the clipboard, don't own it again in the
Motif way. Owning the selection on the Motif way does a huge amount of
X protocol, and it makes killing text incredibly slow when using an
X terminal.  However, when enabled Motif text fields don't bother to look up
the new value, and you can't Copy from a buffer, Paste into a text
field, then Copy something else from the buffer and paste it into the
text field; it pastes the first thing again.
*/ );
  x_selection_strict_motif_ownership = 1;
}

void
Xatoms_of_select_x (struct device *d)
{
  Display *D = DEVICE_X_DISPLAY (d);

  /* Non-predefined atoms that we might end up using a lot */
  DEVICE_XATOM_CLIPBOARD     (d) = XInternAtom (D, "CLIPBOARD",     False);
  DEVICE_XATOM_TIMESTAMP     (d) = XInternAtom (D, "TIMESTAMP",     False);
  DEVICE_XATOM_TEXT          (d) = XInternAtom (D, "TEXT",          False);
  DEVICE_XATOM_DELETE        (d) = XInternAtom (D, "DELETE",        False);
  DEVICE_XATOM_MULTIPLE      (d) = XInternAtom (D, "MULTIPLE",      False);
  DEVICE_XATOM_INCR          (d) = XInternAtom (D, "INCR",          False);
  DEVICE_XATOM_TARGETS       (d) = XInternAtom (D, "TARGETS",       False);
  DEVICE_XATOM_NULL          (d) = XInternAtom (D, "NULL",          False);
  DEVICE_XATOM_ATOM_PAIR     (d) = XInternAtom (D, "ATOM_PAIR",     False);
  DEVICE_XATOM_COMPOUND_TEXT (d) = XInternAtom (D, "COMPOUND_TEXT", False);

  /* #### I don't like the looks of this... what is it for? - ajh */
  DEVICE_XATOM_EMACS_TMP     (d) = XInternAtom (D, "_EMACS_TMP_",   False);
}
