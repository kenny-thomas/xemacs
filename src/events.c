/* Events: printing them, converting them to and from characters.
   Copyright (C) 1991, 1992, 1993, 1994 Free Software Foundation, Inc.
   Copyright (C) 1994, 1995 Board of Trustees, University of Illinois.

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

/* This file has been Mule-ized. */

#include <config.h>
#include "lisp.h"
#include "buffer.h"
#include "console.h"
#include "console-tty.h" /* for stuff in character_to_event */
#include "device.h"
#include "console-x.h"	/* for x_event_name prototype */
#include "extents.h"	/* Just for the EXTENTP abort check... */
#include "events.h"
#include "frame.h"
#include "glyphs.h"
#include "keymap.h" /* for key_desc_list_to_event() */
#include "redisplay.h"
#include "window.h"

#ifdef WINDOWSNT
/* Hmm, under unix we want X modifiers, under NT we want X modifiers if
   we are running X and Windows modifiers otherwise.
   gak. This is a kludge until we support multiple native GUIs!
*/
#undef MOD_ALT
#undef MOD_CONTROL
#undef MOD_SHIFT
#endif

#include <events-mod.h>

/* Where old events go when they are explicitly deallocated.
   The event chain here is cut loose before GC, so these will be freed
   eventually.
 */
static Lisp_Object Vevent_resource;

Lisp_Object Qeventp;
Lisp_Object Qevent_live_p;
Lisp_Object Qkey_press_event_p;
Lisp_Object Qbutton_event_p;
Lisp_Object Qmouse_event_p;
Lisp_Object Qprocess_event_p;

Lisp_Object Qkey_press, Qbutton_press, Qbutton_release, Qmisc_user;
Lisp_Object Qascii_character;

/* #### Ad-hoc hack.  Should be part of define_lrecord_implementation */
void
clear_event_resource (void)
{
  Vevent_resource = Qnil;
}

static Lisp_Object mark_event (Lisp_Object, void (*) (Lisp_Object));
static void print_event (Lisp_Object, Lisp_Object, int);
static int event_equal (Lisp_Object, Lisp_Object, int);
static unsigned long event_hash (Lisp_Object obj, int depth);
DEFINE_BASIC_LRECORD_IMPLEMENTATION ("event", event,
				     mark_event, print_event, 0, event_equal,
				     event_hash, struct Lisp_Event);

/* Make sure we lose quickly if we try to use this event */
static void
deinitialize_event (Lisp_Object ev)
{
  int i;
  struct Lisp_Event *event = XEVENT (ev);

  for (i = 0; i < ((sizeof (struct Lisp_Event)) / sizeof (int)); i++)
    ((int *) event) [i] = 0xdeadbeef;
  event->event_type = dead_event;
  event->channel = Qnil;
  set_lheader_implementation (&(event->lheader), lrecord_event);
  XSET_EVENT_NEXT (ev, Qnil);
}

/* Set everything to zero or nil so that it's predictable. */
void
zero_event (struct Lisp_Event *e)
{
  memset (e, 0, sizeof (*e));
  set_lheader_implementation (&(e->lheader), lrecord_event);
  e->event_type = empty_event;
  e->next = Qnil;
  e->channel = Qnil;
}

static Lisp_Object
mark_event (Lisp_Object obj, void (*markobj) (Lisp_Object))
{
  struct Lisp_Event *event = XEVENT (obj);

  switch (event->event_type)
    {
    case key_press_event:
      ((markobj) (event->event.key.keysym));
      break;
    case process_event:
      ((markobj) (event->event.process.process));
      break;
    case timeout_event:
      ((markobj) (event->event.timeout.function));
      ((markobj) (event->event.timeout.object));
      break;
    case eval_event:
    case misc_user_event:
      ((markobj) (event->event.eval.function));
      ((markobj) (event->event.eval.object));
      break;
    case magic_eval_event:
      ((markobj) (event->event.magic_eval.object));
      break;
    case button_press_event:
    case button_release_event:
    case pointer_motion_event:
    case magic_event:
    case empty_event:
    case dead_event:
      break;
    default:
      abort ();
    }
  ((markobj) (event->channel));
  return event->next;
}

static void
print_event_1 (CONST char *str, Lisp_Object obj, Lisp_Object printcharfun)
{
  char buf[255];
  write_c_string (str, printcharfun);
  format_event_object (buf, XEVENT (obj), 0);
  write_c_string (buf, printcharfun);
}

static void
print_event (Lisp_Object obj, Lisp_Object printcharfun, int escapeflag)
{
  if (print_readably)
    error ("printing unreadable object #<event>");

  switch (XEVENT (obj)->event_type) 
    {
    case key_press_event:
      print_event_1 ("#<keypress-event ", obj, printcharfun);
      break;
    case button_press_event:
      print_event_1 ("#<buttondown-event ", obj, printcharfun);
      break;
    case button_release_event:
      print_event_1 ("#<buttonup-event ", obj, printcharfun);
      break;
    case magic_event:
    case magic_eval_event:
      print_event_1 ("#<magic-event ", obj, printcharfun);
      break;
    case pointer_motion_event:
      {
	char buf[100];
	sprintf (buf, "#<motion-event %d, %d",
		 XEVENT (obj)->event.motion.x, XEVENT (obj)->event.motion.y);
	write_c_string (buf, printcharfun);
	break;
      }
    case process_event:
      {
	write_c_string ("#<process-event ", printcharfun);
	print_internal (XEVENT (obj)->event.process.process, printcharfun, 1);
	break;
      }
    case timeout_event:
      {
	write_c_string ("#<timeout-event ", printcharfun);
	print_internal (XEVENT (obj)->event.timeout.object, printcharfun, 1);
	break;
      }
    case empty_event:
      {
	write_c_string ("#<empty-event", printcharfun);
	break;
      }
    case misc_user_event:
    case eval_event:
      {
	write_c_string ("#<", printcharfun);
	if (XEVENT (obj)->event_type == misc_user_event)
	  write_c_string ("misc-user", printcharfun);
	else
	  write_c_string ("eval", printcharfun);
	write_c_string ("-event (", printcharfun);
	print_internal (XEVENT (obj)->event.eval.function, printcharfun, 1);
	write_c_string (" ", printcharfun);
	print_internal (XEVENT (obj)->event.eval.object, printcharfun, 1);
	write_c_string (")", printcharfun);
	break;
      }
    case dead_event:
      {
	write_c_string ("#<DEALLOCATED-EVENT", printcharfun);
	break;
      }
    default:
      {
	write_c_string ("#<UNKNOWN-EVENT-TYPE", printcharfun);
	break;
      }
    }
  write_c_string (">", printcharfun);
}
  
static int
event_equal (Lisp_Object o1, Lisp_Object o2, int depth)
{
  struct Lisp_Event *e1 = XEVENT (o1);
  struct Lisp_Event *e2 = XEVENT (o2);

  if (e1->event_type != e2->event_type) return 0;
  if (!EQ (e1->channel, e2->channel)) return 0;
/*  if (e1->timestamp != e2->timestamp) return 0; */
  switch (e1->event_type)
    {
    case process_event:
      return (EQ (e1->event.process.process,
		  e2->event.process.process));
    
    case timeout_event:
      if (NILP (Fequal (e1->event.timeout.function,
			e2->event.timeout.function)))
	return 0;
      if (NILP (Fequal (e1->event.timeout.object,
			e2->event.timeout.object)))
	return 0;
      return 1;
    
    case key_press_event:
      return ((EQ (e1->event.key.keysym,
                   e2->event.key.keysym)
               && (e1->event.key.modifiers
                   == e2->event.key.modifiers)));

    case button_press_event:
    case button_release_event:
      return (((e1->event.button.button
                == e2->event.button.button)
               && (e1->event.button.modifiers
                   == e2->event.button.modifiers)));

    case pointer_motion_event:
      return ((e1->event.motion.x == e2->event.motion.x
               && e1->event.motion.y == e2->event.motion.y));

    case misc_user_event:
    case eval_event:
      if (NILP (Fequal (e1->event.eval.function,
			e2->event.eval.function)))
	return 0;
      if (NILP (Fequal (e1->event.eval.object,
			e2->event.eval.object)))
	return 0;
      return 1;

    case magic_eval_event:
      if (e1->event.magic_eval.internal_function !=
	  e2->event.magic_eval.internal_function)
	return 0;
      if (NILP (Fequal (e1->event.magic_eval.object,
			e2->event.magic_eval.object)))
	return 0;
      return 1;

    case magic_event:
      {
	Lisp_Object console;

	console = CDFW_CONSOLE (e1->channel);

#ifdef HAVE_X_WINDOWS
	/* XEvent is actually a union which means that we can't just use == */
	if (CONSOLE_X_P (XCONSOLE (console)))
	  return (!memcmp ((XEvent *) &e1->event.magic.underlying_x_event,
			   (XEvent *) &e2->event.magic.underlying_x_event,
			   sizeof (e1->event.magic.underlying_x_event)));
#endif
	return (e1->event.magic.underlying_tty_event ==
		e2->event.magic.underlying_tty_event);
      }

    case empty_event:      /* Empty and deallocated events are equal. */
    case dead_event:
      return 1;

    default:
      abort ();
      return 0;                 /* not reached; warning suppression */
    }
}

static unsigned long
event_hash (Lisp_Object obj, int depth)
{
  struct Lisp_Event *e = XEVENT (obj);
  unsigned long hash;

  hash = HASH2 (e->event_type, LISP_HASH (e->channel));
  switch (e->event_type)
    {
    case process_event:
      return HASH2 (hash, LISP_HASH (e->event.process.process));
    
    case timeout_event:
      return HASH3 (hash, internal_hash (e->event.timeout.function, depth + 1),
		    internal_hash (e->event.timeout.object, depth + 1));
    
    case key_press_event:
      return HASH3 (hash, LISP_HASH (e->event.key.keysym),
		    e->event.key.modifiers);

    case button_press_event:
    case button_release_event:
      return HASH3 (hash, e->event.button.button, e->event.button.modifiers);

    case pointer_motion_event:
      return HASH3 (hash, e->event.motion.x, e->event.motion.y);

    case misc_user_event:
    case eval_event:
      return HASH3 (hash, internal_hash (e->event.eval.function, depth + 1),
		    internal_hash (e->event.eval.object, depth + 1));

    case magic_eval_event:
      return HASH3 (hash,
		    (unsigned long) e->event.magic_eval.internal_function,
		    internal_hash (e->event.magic_eval.object, depth + 1));

    case magic_event:
      {
	Lisp_Object console = CDFW_CONSOLE (EVENT_CHANNEL (e));
#ifdef HAVE_X_WINDOWS
	if (CONSOLE_X_P (XCONSOLE (console)))
	  return
	    HASH2 (hash,
		   memory_hash (&e->event.magic.underlying_x_event,
				sizeof (e->event.magic.underlying_x_event)));
#endif
	return
	  HASH2 (hash,
		 memory_hash (&e->event.magic.underlying_tty_event,
			      sizeof (e->event.magic.underlying_tty_event)));
      }

    case empty_event:
    case dead_event:
      return hash;

    default:
      abort ();
    }

  return 0;
}


/* #### This should accept a type and props (as returned by
   event-properties) to allow creation of any type of event.
   This is useful, for example, in Lisp code that might want
   to determine if, for a given button-down event, what the
   binding for the corresponding button-up event is. */

DEFUN ("make-event", Fmake_event, 0, 0, 0, /*
Create a new empty event.
WARNING, the event object returned may be a reused one; see the function
`deallocate-event'.
*/
       ())
{
  Lisp_Object event;

  if (!NILP (Vevent_resource))
    {
      event = Vevent_resource;
      Vevent_resource = XEVENT_NEXT (event);
    }
  else
    {
      event = allocate_event ();
    }
  zero_event (XEVENT (event));
  return event;
}

DEFUN ("deallocate-event", Fdeallocate_event, 1, 1, 0, /*
Allow the given event structure to be reused.
You MUST NOT use this event object after calling this function with it.
You will lose.  It is not necessary to call this function, as event
objects are garbage-collected like all other objects; however, it may
be more efficient to explicitly deallocate events when you are sure
that it is safe to do so.
*/
       (event))
{
  CHECK_EVENT (event);

  if (XEVENT_TYPE (event) == dead_event)
    error ("this event is already deallocated!");

  assert (XEVENT_TYPE (event) <= last_event_type);

#if 0
  {  
    int i;
    extern Lisp_Object Vlast_command_event;
    extern Lisp_Object Vlast_input_event, Vunread_command_event;
    extern Lisp_Object Vthis_command_keys, Vrecent_keys_ring;

    if (EQ (event, Vlast_command_event))
      abort ();
    if (EQ (event, Vlast_input_event))
      abort ();
    if (EQ (event, Vunread_command_event))
      abort ();
    for (i = 0; i < XVECTOR (Vthis_command_keys)->size; i++)
      if (EQ (event, vector_data (XVECTOR (Vthis_command_keys)) [i]))
	abort ();
    for (i = 0; i < XVECTOR (Vrecent_keys_ring)->size; i++)
      if (EQ (event, vector_data (XVECTOR (Vrecent_keys_ring)) [i]))
	abort ();
  }
#endif /* 0 */

  assert (!EQ (event, Vevent_resource));
  deinitialize_event (event);
#ifndef ALLOC_NO_POOLS
  XSET_EVENT_NEXT (event, Vevent_resource);
  Vevent_resource = event;
#endif
  return Qnil;
}

DEFUN ("copy-event", Fcopy_event, 1, 2, 0, /*
Make a copy of the given event object.
If a second argument is given, the first event is copied into the second
and the second is returned.  If the second argument is not supplied (or
is nil) then a new event will be made as with `allocate-event.'  See also
the function `deallocate-event'.
*/
       (event1, event2))
{
  CHECK_LIVE_EVENT (event1);
  if (NILP (event2))
    event2 = Fmake_event ();
  else CHECK_LIVE_EVENT (event2);
  if (EQ (event1, event2))
    return signal_simple_continuable_error_2
      ("copy-event called with `eq' events", event1, event2);

  assert (XEVENT_TYPE (event1) <= last_event_type);
  assert (XEVENT_TYPE (event2) <= last_event_type);

  {
    Lisp_Object save_next = XEVENT_NEXT (event2);

    *XEVENT (event2) = *XEVENT (event1);
    XSET_EVENT_NEXT (event2, save_next);
    return (event2);
  }
}



/* Given a chain of events (or possibly nil), deallocate them all. */

void
deallocate_event_chain (Lisp_Object event_chain)
{
  while (!NILP (event_chain))
    {
      Lisp_Object next = XEVENT_NEXT (event_chain);
      Fdeallocate_event (event_chain);
      event_chain = next;
    }
}

/* Return the last event in a chain.
   NOTE: You cannot pass nil as a value here!  The routine will
   abort if you do. */

Lisp_Object
event_chain_tail (Lisp_Object event_chain)
{
  while (1)
    {
      Lisp_Object next = XEVENT_NEXT (event_chain);
      if (NILP (next))
	return event_chain;
      event_chain = next;
    }
}

/* Enqueue a single event onto the end of a chain of events.
   HEAD points to the first event in the chain, TAIL to the last event.
   If the chain is empty, both values should be nil. */

void
enqueue_event (Lisp_Object event, Lisp_Object *head, Lisp_Object *tail)
{
  assert (NILP (XEVENT_NEXT (event)));
  assert (!EQ (*tail, event));

  if (!NILP (*tail))
    XSET_EVENT_NEXT (*tail, event);
  else
   *head = event;
  *tail = event;

  assert (!EQ (event, XEVENT_NEXT (event)));
}

/* Remove an event off the head of a chain of events and return it.
   HEAD points to the first event in the chain, TAIL to the last event. */
   
Lisp_Object
dequeue_event (Lisp_Object *head, Lisp_Object *tail)
{
  Lisp_Object event;

  event = *head;
  *head = XEVENT_NEXT (event);
  XSET_EVENT_NEXT (event, Qnil);
  if (NILP (*head))
    *tail = Qnil;
  return event;
}

/* Enqueue a chain of events (or possibly nil) onto the end of another
   chain of events.  HEAD points to the first event in the chain being
   queued onto, TAIL to the last event.  If the chain is empty, both values
   should be nil. */

void
enqueue_event_chain (Lisp_Object event_chain, Lisp_Object *head,
		     Lisp_Object *tail)
{
  if (NILP (event_chain))
    return;

  if (NILP (*head))
    {
      *head = event_chain;
      *tail = event_chain;
    }
  else
    {
      XSET_EVENT_NEXT (*tail, event_chain);
      *tail = event_chain_tail (event_chain);
    }
}

/* Return the number of events (possibly 0) on an event chain. */

int
event_chain_count (Lisp_Object event_chain)
{
  Lisp_Object event;
  int n = 0;

  EVENT_CHAIN_LOOP (event, event_chain)
    n++;

  return n;
}

/* Find the event before EVENT in an event chain.  This aborts
   if the event is not in the chain. */

Lisp_Object
event_chain_find_previous (Lisp_Object event_chain, Lisp_Object event)
{
  Lisp_Object previous = Qnil;

  while (!NILP (event_chain))
    {
      if (EQ (event_chain, event))
	return previous;
      previous = event_chain;
      event_chain = XEVENT_NEXT (event_chain);
    }

  abort ();
  return Qnil;
}

Lisp_Object
event_chain_nth (Lisp_Object event_chain, int n)
{
  Lisp_Object event;
  EVENT_CHAIN_LOOP (event, event_chain)
    {
      if (!n)
	return event;
      n--;
    }
  return Qnil;
}

Lisp_Object
copy_event_chain (Lisp_Object event_chain)
{
  Lisp_Object new_chain = Qnil;
  Lisp_Object new_chain_tail = Qnil;
  Lisp_Object event;

  EVENT_CHAIN_LOOP (event, event_chain)
    {
      Lisp_Object copy = Fcopy_event (event, Qnil);
      enqueue_event (copy, &new_chain, &new_chain_tail);
    }

  return new_chain;
}



Lisp_Object QKbackspace, QKtab, QKlinefeed, QKreturn, QKescape,
 QKspace, QKdelete;

int
command_event_p (Lisp_Object event)
{
  switch (XEVENT_TYPE (event))
    {
    case key_press_event:
    case button_press_event:
    case button_release_event:
    case misc_user_event:
      return (1);
    default:
      return (0);
    }
}


void
character_to_event (Emchar c, struct Lisp_Event *event, struct console *con,
		    int use_console_meta_flag)
{
  Lisp_Object k = Qnil;
  unsigned int m = 0;
  if (event->event_type == dead_event)
    error ("character-to-event called with a deallocated event!");

#ifndef MULE
  c &= 255;
#endif
  if (c > 127 && c <= 255)
    {
      int meta_flag = 1;
      if (use_console_meta_flag && CONSOLE_TTY_P (con))
	meta_flag = TTY_FLAGS (con).meta_key;
      switch (meta_flag)
	{
	case 0: /* ignore top bit; it's parity */
	  c -= 128;
	  break;
	case 1: /* top bit is meta */
	  c -= 128;
	  m = MOD_META;
	  break;
	default: /* this is a real character */
	  break;
	}
    }
  if (c < ' ') c += '@', m |= MOD_CONTROL;
  if (m & MOD_CONTROL)
    {
      switch (c)
	{
	case 'I': k = QKtab;	  m &= ~MOD_CONTROL; break;
	case 'J': k = QKlinefeed; m &= ~MOD_CONTROL; break;
	case 'M': k = QKreturn;	  m &= ~MOD_CONTROL; break;
	case '[': k = QKescape;	  m &= ~MOD_CONTROL; break;
# if 0
	  /* This is probably too controversial... */
	case 'H': k = QKbackspace; m &= ~MOD_CONTROL; break;
# endif
	}
      if (c >= 'A' && c <= 'Z') c -= 'A'-'a';
    }
  else if (c == 127)
    k = QKdelete;
  else if (c == ' ')
    k = QKspace;
  
  event->event_type	     = key_press_event;
  event->timestamp	     = 0; /* #### */
  event->channel	     = make_console (con);
  event->event.key.keysym    = (!NILP (k) ? k : make_char (c));
  event->event.key.modifiers = m;
}


/* This variable controls what character name -> character code mapping
   we are using.  Window-system-specific code sets this to some symbol,
   and we use that symbol as the plist key to convert keysyms into 8-bit
   codes.  In this way one can have several character sets predefined and
   switch them by changing this.
 */
Lisp_Object Vcharacter_set_property;

Emchar
event_to_character (struct Lisp_Event *event,
		    int allow_extra_modifiers,
		    int allow_meta,
		    int allow_non_ascii)
{
  Emchar c = 0;
  Lisp_Object code;

  if (event->event_type != key_press_event)
    {
      if (event->event_type == dead_event) abort ();
      return -1;
    }
  if (!allow_extra_modifiers &&
      event->event.key.modifiers & (MOD_SUPER|MOD_HYPER|MOD_ALT))
    return -1;
  if (CHAR_OR_CHAR_INTP (event->event.key.keysym))
    c = XCHAR_OR_CHAR_INT (event->event.key.keysym);
  else if (!SYMBOLP (event->event.key.keysym))
    abort ();
  else if (allow_non_ascii && !NILP (Vcharacter_set_property)
	   /* Allow window-system-specific extensibility of
	      keysym->code mapping */
	   && CHAR_OR_CHAR_INTP (code = Fget (event->event.key.keysym,
					      Vcharacter_set_property,
					      Qnil)))
    c = XCHAR_OR_CHAR_INT (code);
  else if (CHAR_OR_CHAR_INTP (code = Fget (event->event.key.keysym,
					   Qascii_character, Qnil)))
    c = XCHAR_OR_CHAR_INT (code);
  else
    return -1;

  if (event->event.key.modifiers & MOD_CONTROL)
    {
      if (c >= 'a' && c <= 'z')
	c -= ('a' - 'A');
      else
	/* reject Control-Shift- keys */
	if (c >= 'A' && c <= 'Z' && !allow_extra_modifiers)
	  return -1;
      
      if (c >= '@' && c <= '_')
	c -= '@';
      else if (c == ' ')  /* C-space and C-@ are the same. */
	c = 0;
      else
	/* reject keys that can't take Control- modifiers */
	if (! allow_extra_modifiers) return -1;
    }

  if (event->event.key.modifiers & MOD_META)
    {
      if (! allow_meta) return -1;
      if (c & 0200) return -1;		/* don't allow M-oslash (overlap) */
#ifdef MULE
      if (c >= 256) return -1;
#endif
      c |= 0200;
    }
  return c;
}

DEFUN ("event-to-character", Fevent_to_character, 1, 4, 0, /*
Return the closest ASCII approximation to the given event object.
If the event isn't a keypress, this returns nil.
If the ALLOW-EXTRA-MODIFIERS argument is non-nil, then this is lenient in
 its translation; it will ignore modifier keys other than control and meta,
 and will ignore the shift modifier on those characters which have no
 shifted ASCII equivalent (Control-Shift-A for example, will be mapped to
 the same ASCII code as Control-A).
If the ALLOW-META argument is non-nil, then the Meta modifier will be
 represented by turning on the high bit of the byte returned; otherwise, nil
 will be returned for events containing the Meta modifier.
If the ALLOW-NON-ASCII argument is non-nil, then characters which are
 present in the prevailing character set (see the `character-set-property'
 variable) will be returned as their code in that character set, instead of
 the return value being restricted to ASCII.
Note that specifying both ALLOW-META and ALLOW-NON-ASCII is ambiguous, as
 both use the high bit; `M-x' and `oslash' will be indistinguishable.
*/
     (event, allow_extra_modifiers, allow_meta, allow_non_ascii))
{
  Emchar c;
  CHECK_LIVE_EVENT (event);
  c = event_to_character (XEVENT (event),
			  !NILP (allow_extra_modifiers),
			  !NILP (allow_meta),
			  !NILP (allow_non_ascii));
  return (c < 0 ? Qnil : make_char (c));
}

DEFUN ("character-to-event", Fcharacter_to_event, 1, 4, 0, /*
Converts a keystroke specifier into an event structure, replete with
bucky bits.  The keystroke is the first argument, and the event to fill
in is the second.  This function contains knowledge about what the codes
``mean'' -- for example, the number 9 is converted to the character ``Tab'',
not the distinct character ``Control-I''.

Note that CH (the keystroke specifier) can be an integer, a character,
a symbol such as 'clear, or a list such as '(control backspace).

If the optional second argument is an event, it is modified;
otherwise, a new event object is created.

Optional third arg CONSOLE is the console to store in the event, and
defaults to the selected console.

If CH is an integer or character, the high bit may be interpreted as the
meta key. (This is done for backward compatibility in lots of places.)
If USE-CONSOLE-META-FLAG is nil, this will always be the case.  If
USE-CONSOLE-META-FLAG is non-nil, the `meta' flag for CONSOLE affects
whether the high bit is interpreted as a meta key. (See `set-input-mode'.)
If you don't want this silly meta interpretation done, you should pass
in a list containing the character.

Beware that character-to-event and event-to-character are not strictly
inverse functions, since events contain much more information than the
ASCII character set can encode.
*/
       (ch, event, console, use_console_meta_flag))
{
  struct console *con = decode_console (console);
  if (NILP (event))
    event = Fmake_event ();
  else
    CHECK_LIVE_EVENT (event);
  if (CONSP (ch) || SYMBOLP (ch))
    key_desc_list_to_event (ch, event, 1);
  else
    {
      CHECK_CHAR_COERCE_INT (ch);
      character_to_event (XCHAR (ch), XEVENT (event), con,
			  !NILP (use_console_meta_flag));
    }
  return event;
}

void
nth_of_key_sequence_as_event (Lisp_Object seq, int n, Lisp_Object event)
{
  assert (STRINGP (seq) || VECTORP (seq));
  assert (n < XINT (Flength (seq)));

  if (STRINGP (seq))
    {
      Emchar ch = string_char (XSTRING (seq), n);
      Fcharacter_to_event (make_char (ch), event, Qnil, Qnil);
    }
  else
    {
      Lisp_Object keystroke = vector_data (XVECTOR (seq))[n];
      if (EVENTP (keystroke))
	Fcopy_event (keystroke, event);
      else
	Fcharacter_to_event (keystroke, event, Qnil, Qnil);
    }
}

Lisp_Object
key_sequence_to_event_chain (Lisp_Object seq)
{
  int len = XINT (Flength (seq));
  int i;
  Lisp_Object head = Qnil, tail = Qnil;

  for (i = 0; i < len; i++)
    {
      Lisp_Object event = Fmake_event ();
      nth_of_key_sequence_as_event (seq, i, event);
      enqueue_event (event, &head, &tail);
    }

  return head;
}

void
format_event_object (char *buf, struct Lisp_Event *event, int brief)
{
  int mouse_p = 0;
  int mod = 0;
  Lisp_Object key;

  switch (event->event_type)
    {
    case key_press_event:
      {
        mod = event->event.key.modifiers;
        key = event->event.key.keysym;
        /* Hack. */
        if (! brief && CHARP (key) &&
            mod & (MOD_CONTROL | MOD_META | MOD_SUPER | MOD_HYPER))
	{
	  int k = XCHAR (key);
	  if (k >= 'a' && k <= 'z')
	    key = make_char (k - ('a' - 'A'));
	  else if (k >= 'A' && k <= 'Z')
	    mod |= MOD_SHIFT;
	}
        break;
      }
    case button_release_event:
      mouse_p++;
      /* Fall through */
    case button_press_event:
      {
        mouse_p++;
        mod = event->event.button.modifiers;
        key = make_char (event->event.button.button + '0');
        break;
      }
    case magic_event:
      {
        CONST char *name = 0;
	Lisp_Object console = CDFW_CONSOLE (EVENT_CHANNEL (event));

#ifdef HAVE_X_WINDOWS
        if (CONSOLE_X_P (XCONSOLE (console)))
	  name =
	    x_event_name (event->event.magic.underlying_x_event.xany.type);
#endif
	if (name) strcpy (buf, name);
	else strcpy (buf, "???");
	return;
      }
    case magic_eval_event:	strcpy (buf, "magic-eval"); return;
    case pointer_motion_event:	strcpy (buf, "motion");	return;
    case misc_user_event:	strcpy (buf, "misc-user"); return;
    case eval_event:		strcpy (buf, "eval"); 	return;
    case process_event:		strcpy (buf, "process");return;
    case timeout_event:		strcpy (buf, "timeout");return;
    case empty_event:		strcpy (buf, "EMPTY-EVENT"); return;
    case dead_event:		strcpy (buf, "DEAD-EVENT");  return;
    default:
      abort ();
    }
#define modprint1(x)  { strcpy (buf, (x)); buf += sizeof (x)-1; }
#define modprint(x,y) { if (brief) modprint1 (y) else modprint1 (x) }
  if (mod & MOD_CONTROL) modprint ("control-", "C-");
  if (mod & MOD_META)    modprint ("meta-",    "M-");
  if (mod & MOD_SUPER)   modprint ("super-",   "S-");
  if (mod & MOD_HYPER)   modprint ("hyper-",   "H-");
  if (mod & MOD_ALT)	 modprint ("alt-",     "A-");
  if (mod & MOD_SHIFT)   modprint ("shift-",   "Sh-");
  if (mouse_p)
    {
      modprint1 ("button");
      --mouse_p;
    }
#undef modprint
#undef modprint1

  if (CHARP (key))
    {
      buf += set_charptr_emchar ((Bufbyte *) buf, XCHAR (key));
      *buf = 0;
    }
  else if (SYMBOLP (key))
    {
      CONST char *str = 0;
      if (brief)
	{
	  if      (EQ (key, QKlinefeed))  str = "LFD";
	  else if (EQ (key, QKtab))       str = "TAB";
	  else if (EQ (key, QKreturn))    str = "RET";
	  else if (EQ (key, QKescape))    str = "ESC";
	  else if (EQ (key, QKdelete))    str = "DEL";
	  else if (EQ (key, QKspace))     str = "SPC";
	  else if (EQ (key, QKbackspace)) str = "BS";
	}
      if (str)
	{
	  int i = strlen (str);
	  memcpy (buf, str, i+1);
	  str += i;
	}
      else
	{
	  memcpy (buf, string_data (XSYMBOL (key)->name),
                string_length (XSYMBOL (key)->name) + 1);
	  str += string_length (XSYMBOL (key)->name);
	}
    }
  else
    abort ();
  if (mouse_p)
    strncpy (buf, "up", 4);
}

DEFUN ("eventp", Feventp, 1, 1, 0, /*
True if OBJECT is an event object.
*/
       (object))
{
  return ((EVENTP (object)) ? Qt : Qnil);
}

DEFUN ("event-live-p", Fevent_live_p, 1, 1, 0, /*
True if OBJECT is an event object that has not been deallocated.
*/
       (object))
{
  return ((EVENTP (object) && XEVENT (object)->event_type != dead_event)
	  ? Qt : Qnil);
}

#if 0 /* debugging functions */

xxDEFUN ("event-next", Fevent_next, Sevent_next, 1, 1, 0 /*
Return the event object's `next' event, or nil if it has none.
The `next-event' field is changed by calling `set-next-event'.
*/ )
     (event)
     Lisp_Object event;
{
  struct Lisp_Event *e;
  CHECK_LIVE_EVENT (event);

  return XEVENT_NEXT (event);
}

xxDEFUN ("set-event-next", Fset_event_next, Sset_event_next, 2, 2, 0 /*
Set the `next event' of EVENT to NEXT-EVENT.
NEXT-EVENT must be an event object or nil.
*/ )
     (event, next_event)
     Lisp_Object event, next_event;
{
  Lisp_Object ev;

  CHECK_LIVE_EVENT (event);
  if (NILP (next_event))
    {
      XSET_EVENT_NEXT (event, Qnil);
      return (Qnil);
    }

  CHECK_LIVE_EVENT (next_event);

  EVENT_CHAIN_LOOP (ev, XEVENT_NEXT (event))
    {
      QUIT;
      if (EQ (ev, event))
	signal_error (Qerror, 
		      list3 (build_string ("Cyclic event-next"),
			     event, 
			     next_event));
    }
  XSET_EVENT_NEXT (event, next_event);
  return (next_event);
}

#endif /* 0 */

DEFUN ("event-type", Fevent_type, 1, 1, 0, /*
Return the type of EVENT.
This will be a symbol; one of

key-press	A key was pressed.
button-press	A mouse button was pressed.
button-release	A mouse button was released.
misc-user	Some other user action happened; typically, this is
		a menu selection or scrollbar action.
motion		The mouse moved.
process		Input is available from a subprocess.
timeout		A timeout has expired.
eval		This causes a specified action to occur when dispatched.
magic		Some window-system-specific event has occurred.
empty		The event has been allocated but not assigned.

*/
       (event))
{
  CHECK_LIVE_EVENT (event);
  switch (XEVENT (event)->event_type)
    {
    case key_press_event:
      return Qkey_press;

    case button_press_event:
      return Qbutton_press;

    case button_release_event:
      return Qbutton_release;

    case misc_user_event:
      return Qmisc_user;

    case pointer_motion_event:
      return Qmotion;

    case process_event:
      return Qprocess;

    case timeout_event:
      return Qtimeout;

    case eval_event:
      return Qeval;

    case magic_event:
    case magic_eval_event:
      return Qmagic;

    case empty_event:
      return Qempty;

    default:
      abort ();
      return Qnil;
    }
}

DEFUN ("event-timestamp", Fevent_timestamp, 1, 1, 0, /*
Return the timestamp of the given event object.
*/
       (event))
{
  CHECK_LIVE_EVENT (event);
  /* This junk is so that timestamps don't get to be negative, but contain
     as many bits as this particular emacs will allow.
   */
  return make_int (((1L << (VALBITS - 1)) - 1) &
		      XEVENT (event)->timestamp);
}

#define CHECK_EVENT_TYPE(e,t1,sym)		\
{ CHECK_LIVE_EVENT (e);				\
  if (XEVENT(e)->event_type != (t1))		\
     e = wrong_type_argument ((sym),(e));	\
}

#define CHECK_EVENT_TYPE2(e,t1,t2,sym)					\
{ CHECK_LIVE_EVENT (e);							\
  if (XEVENT(e)->event_type != (t1) && XEVENT(e)->event_type != (t2))	\
     e = wrong_type_argument ((sym),(e));				\
}

DEFUN ("event-key", Fevent_key, 1, 1, 0, /*
Return the Keysym of the given key-press event.
This will be the ASCII code of a printing character, or a symbol.
*/
       (event))
{
  CHECK_EVENT_TYPE (event, key_press_event, Qkey_press_event_p);
  return (XEVENT (event)->event.key.keysym);
}

DEFUN ("event-button", Fevent_button, 1, 1, 0, /*
Return the button-number of the given mouse-button-press event.
*/
       (event))
{
  CHECK_EVENT_TYPE2 (event, button_press_event, button_release_event,
		     Qbutton_event_p);
#ifdef HAVE_WINDOW_SYSTEM
  return make_int (XEVENT (event)->event.button.button);
#else /* !HAVE_WINDOW_SYSTEM */
  return Qzero;
#endif /* !HAVE_WINDOW_SYSTEM */
}

DEFUN ("event-modifier-bits", Fevent_modifier_bits, 1, 1, 0, /*
Return a number representing the modifier keys which were down
when the given mouse or keyboard event was produced.  See also the function
event-modifiers.
*/
       (event))
{
 again:
  CHECK_LIVE_EVENT (event);
  if (XEVENT (event)->event_type == key_press_event)
    return make_int (XEVENT (event)->event.key.modifiers);
  else if (XEVENT (event)->event_type == button_press_event ||
	   XEVENT (event)->event_type == button_release_event)
    return make_int (XEVENT (event)->event.button.modifiers);
  else if (XEVENT (event)->event_type == pointer_motion_event)
    return make_int (XEVENT (event)->event.motion.modifiers);
  else
    {
      event = wrong_type_argument (intern ("key-or-mouse-event-p"), event);
      goto again;
    }
}

DEFUN ("event-modifiers", Fevent_modifiers, 1, 1, 0, /*
Return a list of symbols, the names of the modifier keys
which were down when the given mouse or keyboard event was produced.
See also the function event-modifier-bits.
*/
       (event))
{
  int mod = XINT (Fevent_modifier_bits (event));
  Lisp_Object result = Qnil;
  if (mod & MOD_SHIFT)   result = Fcons (Qshift, result);
  if (mod & MOD_ALT)	 result = Fcons (Qalt, result);
  if (mod & MOD_HYPER)   result = Fcons (Qhyper, result);
  if (mod & MOD_SUPER)   result = Fcons (Qsuper, result);
  if (mod & MOD_META)    result = Fcons (Qmeta, result);
  if (mod & MOD_CONTROL) result = Fcons (Qcontrol, result);
  return result;
}

static int
event_x_y_pixel_internal (Lisp_Object event, int *x, int *y, int relative)
{
  struct window *w;
  struct frame *f;

  if (XEVENT (event)->event_type == pointer_motion_event)
    {
      *x = XEVENT (event)->event.motion.x;
      *y = XEVENT (event)->event.motion.y;
    }
  else if (XEVENT (event)->event_type == button_press_event ||
	   XEVENT (event)->event_type == button_release_event)
    {
      *x = XEVENT (event)->event.button.x;
      *y = XEVENT (event)->event.button.y;
    }
  else
    return 0;

  f = XFRAME (EVENT_CHANNEL (XEVENT (event)));

  if (relative)
    {
      w = find_window_by_pixel_pos (*x, *y, f->root_window);

      if (!w)
	return 1;	/* #### What should really happen here. */

      *x -= w->pixel_left;
      *y -= w->pixel_top;
    }
  else
    {
      *y -= FRAME_REAL_TOP_TOOLBAR_HEIGHT (f);
      *x -= FRAME_REAL_LEFT_TOOLBAR_WIDTH (f);
    }

  return 1;
}

DEFUN ("event-window-x-pixel", Fevent_window_x_pixel, 1, 1, 0, /*
Return the X position in pixels of the given mouse event.
The value returned is relative to the window the event occurred in.
This will signal an error if the event is not a mouse-motion, button-press,
or button-release event.  See also `event-x-pixel'.
*/
       (event))
{
  int x, y;

  CHECK_LIVE_EVENT (event);

  if (!event_x_y_pixel_internal (event, &x, &y, 1))
    return wrong_type_argument (Qmouse_event_p, event);
  else
    return make_int (x);
}

DEFUN ("event-window-y-pixel", Fevent_window_y_pixel, 1, 1, 0, /*
Return the Y position in pixels of the given mouse event.
The value returned is relative to the window the event occurred in.
This will signal an error if the event is not a mouse-motion, button-press,
or button-release event.  See also `event-y-pixel'.
*/
       (event))
{
  int x, y;

  CHECK_LIVE_EVENT (event);

  if (!event_x_y_pixel_internal (event, &x, &y, 1))
    return wrong_type_argument (Qmouse_event_p, event);
  else
    return make_int (y);
}

DEFUN ("event-x-pixel", Fevent_x_pixel, 1, 1, 0, /*
Return the X position in pixels of the given mouse event.
The value returned is relative to the frame the event occurred in.
This will signal an error if the event is not a mouse-motion, button-press,
or button-release event.  See also `event-window-x-pixel'.
*/
       (event))
{
  int x, y;

  CHECK_LIVE_EVENT (event);

  if (!event_x_y_pixel_internal (event, &x, &y, 0))
    return wrong_type_argument (Qmouse_event_p, event);
  else
    return make_int (x);
}

DEFUN ("event-y-pixel", Fevent_y_pixel, 1, 1, 0, /*
Return the Y position in pixels of the given mouse event.
The value returned is relative to the frame the event occurred in.
This will signal an error if the event is not a mouse-motion, button-press,
or button-release event.  See also `event-window-y-pixel'.
*/
       (event))
{
  int x, y;

  CHECK_LIVE_EVENT (event);

  if (!event_x_y_pixel_internal (event, &x, &y, 0))
    return wrong_type_argument (Qmouse_event_p, event);
  else
    return make_int (y);
}

/* Given an event, return a value:

     OVER_TOOLBAR:	over one of the 4 frame toolbars
     OVER_MODELINE:	over a modeline
     OVER_BORDER:	over an internal border
     OVER_NOTHING:	over the text area, but not over text
     OVER_OUTSIDE:	outside of the frame border
     OVER_TEXT:		over text in the text area

   and return:

   The X char position in CHAR_X, if not a null pointer.
   The Y char position in CHAR_Y, if not a null pointer.
   (These last two values are relative to the window the event is over.)
   The window it's over in W, if not a null pointer.
   The buffer position it's over in BUFP, if not a null pointer.
   The closest buffer position in CLOSEST, if not a null pointer.

   OBJ_X, OBJ_Y, OBJ1, and OBJ2 are as in pixel_to_glyph_translation().
*/
   
static int
event_pixel_translation (Lisp_Object event, int *char_x, int *char_y,
			 int *obj_x, int *obj_y,
			 struct window **w, Bufpos *bufp, Bufpos *closest,
			 Charcount *modeline_closest,
			 Lisp_Object *obj1, Lisp_Object *obj2)
{
  int pix_x = 0;
  int pix_y = 0;
  int result;
  Lisp_Object frame;

  int ret_x, ret_y, ret_obj_x, ret_obj_y;
  struct window *ret_w;
  Bufpos ret_bufp, ret_closest;
  Charcount ret_modeline_closest;
  Lisp_Object ret_obj1, ret_obj2;
  
  CHECK_LIVE_EVENT (event);
  if (XEVENT (event)->event_type == pointer_motion_event)
    {
      pix_x = XEVENT (event)->event.motion.x;
      pix_y = XEVENT (event)->event.motion.y;
      frame = XEVENT (event)->channel;
    }
  else if (XEVENT (event)->event_type == button_press_event ||
	   XEVENT (event)->event_type == button_release_event)
    {
      pix_x = XEVENT (event)->event.button.x;
      pix_y = XEVENT (event)->event.button.y;
      frame = XEVENT (event)->channel;
    }
  else
    wrong_type_argument (Qmouse_event_p, event);

  result = pixel_to_glyph_translation (XFRAME (frame), pix_x, pix_y,
				       &ret_x, &ret_y, &ret_obj_x, &ret_obj_y,
				       &ret_w, &ret_bufp, &ret_closest,
				       &ret_modeline_closest,
				       &ret_obj1, &ret_obj2);

  if (result == OVER_NOTHING || result == OVER_OUTSIDE)
    ret_bufp = 0;
  else if (ret_w && NILP (ret_w->buffer))
    /* Why does this happen?  (Does it still happen?)
       I guess the window has gotten reused as a non-leaf... */
    ret_w = 0;

  /* #### pixel_to_glyph_translation() sometimes returns garbage...
     The word has type Lisp_Record (presumably meaning `extent') but the
     pointer points to random memory, often filled with 0, sometimes not.
   */
  /* #### Chuck, do we still need this crap? */
  if (!NILP (ret_obj1) && !(GLYPHP (ret_obj1)
#ifdef HAVE_TOOLBARS
			    || TOOLBAR_BUTTONP (ret_obj1)
#endif
     ))
    abort ();
  if (!NILP (ret_obj2) && !(EXTENTP (ret_obj2)
			    || CONSP (ret_obj2)))
    abort ();

  if (char_x)
    *char_x = ret_x;
  if (char_y)
    *char_y = ret_y;
  if (obj_x)
    *obj_x = ret_obj_x;
  if (obj_y)
    *obj_y = ret_obj_y;
  if (w)
    *w = ret_w;
  if (bufp)
    *bufp = ret_bufp;
  if (closest)
    *closest = ret_closest;
  if (modeline_closest)
    *modeline_closest = ret_modeline_closest;
  if (obj1)
    *obj1 = ret_obj1;
  if (obj2)
    *obj2 = ret_obj2;

  return result;
}

DEFUN ("event-over-text-area-p", Fevent_over_text_area_p, 1, 1, 0, /*
Return whether the given mouse event occurred over the text area of a window.
The modeline is not considered to be part of the text area.
*/
       (event))
{
  int result = event_pixel_translation (event, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

  if (result == OVER_TEXT || result == OVER_NOTHING)
    return Qt;
  else
    return Qnil;
}

DEFUN ("event-over-modeline-p", Fevent_over_modeline_p, 1, 1, 0, /*
Return whether the given mouse event occurred over the modeline of a window.
*/
       (event))
{
  int result = event_pixel_translation (event, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

  if (result == OVER_MODELINE)
    return Qt;
  else
    return Qnil;
}

DEFUN ("event-over-border-p", Fevent_over_border_p, 1, 1, 0, /*
Return whether the given mouse event occurred over an internal border.
*/
       (event))
{
  int result = event_pixel_translation (event, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

  if (result == OVER_BORDER)
    return Qt;
  else
    return Qnil;
}

DEFUN ("event-over-toolbar-p", Fevent_over_toolbar_p, 1, 1, 0, /*
Return whether the given mouse event occurred over a toolbar.
*/
       (event))
{
  int result = event_pixel_translation (event, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

  if (result == OVER_TOOLBAR)
    return Qt;
  else
    return Qnil;
}

struct console *
event_console_or_selected (Lisp_Object event)
{
  Lisp_Object channel = EVENT_CHANNEL (XEVENT (event));
  Lisp_Object console = CDFW_CONSOLE (channel);

  if (NILP (console))
    console = Vselected_console;

  return XCONSOLE (console);
}

DEFUN ("event-channel", Fevent_channel, 1, 1, 0, /*
Return the channel that the given event occurred on.
This will be a frame, device, console, or nil for some types
of events (e.g. eval events).
*/
       (event))
{
  CHECK_LIVE_EVENT (event);
  return EVENT_CHANNEL (XEVENT (event));
}

DEFUN ("event-window", Fevent_window, 1, 1, 0, /*
Return the window of the given mouse event.
This may be nil if the event occurred in the border or over a toolbar.
The modeline is considered to be in the window it represents.
*/
       (event))
{
  struct window *w;
  Lisp_Object window;

  event_pixel_translation (event, 0, 0, 0, 0, &w, 0, 0, 0, 0, 0);

  if (!w)
    return Qnil;
  else
    {
      XSETWINDOW (window, w);
      return window;
    }
}

DEFUN ("event-point", Fevent_point, 1, 1, 0, /*
Return the character position of the given mouse event.
If the event did not occur over a window, or did not occur over text,
then this returns nil.  Otherwise, it returns an index into the buffer
visible in the event's window.
*/
       (event))
{
  Bufpos bufp;
  struct window *w;

  event_pixel_translation (event, 0, 0, 0, 0, &w, &bufp, 0, 0, 0, 0);

  if (!w)
    return Qnil;
  else if (!bufp)
    return Qnil;
  else
    return make_int (bufp);
}

DEFUN ("event-closest-point", Fevent_closest_point, 1, 1, 0, /*
Return the character position of the given mouse event.
If the event did not occur over a window or over text, return the
closest point to the location of the event.  If the Y pixel position
overlaps a window and the X pixel position is to the left of that
window, the closest point is the beginning of the line containing the
Y position.  If the Y pixel position overlaps a window and the X pixel
position is to the right of that window, the closest point is the end
of the line containing the Y position.  If the Y pixel position is
above a window, return 0.  If it is below a window, return the value
of (window-end).
*/
       (event))
{
  Bufpos bufp;

  event_pixel_translation (event, 0, 0, 0, 0, 0, 0, &bufp, 0, 0, 0);

  if (!bufp)
    return Qnil;
  else
    return make_int (bufp);
}

DEFUN ("event-x", Fevent_x, 1, 1, 0, /*
Return the X position of the given mouse event in characters.
This is relative to the window the event occurred over.
*/
       (event))
{
  int char_x;

  event_pixel_translation (event, &char_x, 0, 0, 0, 0, 0, 0, 0, 0, 0);

  return make_int (char_x);
}

DEFUN ("event-y", Fevent_y, 1, 1, 0, /*
Return the Y position of the given mouse event in characters.
This is relative to the window the event occurred over.
*/
       (event))
{
  int char_y;

  event_pixel_translation (event, 0, &char_y, 0, 0, 0, 0, 0, 0, 0, 0);

  return make_int (char_y);
}

DEFUN ("event-modeline-position", Fevent_modeline_position, 1, 1, 0, /*
Return the character position in the modeline that EVENT occurred over.
EVENT should be a mouse event.  If EVENT did not occur over a modeline,
nil is returned.  You can determine the actual character that the
event occurred over by looking in `generated-modeline-string' at the
returned character position.  Note that `generated-modeline-string'
is buffer-local, and you must use EVENT's buffer when retrieving
`generated-modeline-string' in order to get accurate results.
*/
       (event))
{
  Charcount mbufp;

  event_pixel_translation (event, 0, 0, 0, 0, 0, 0, 0, &mbufp, 0, 0);

  if (mbufp < 0)
    return Qnil;
  else
    return make_int (mbufp);
}

DEFUN ("event-glyph", Fevent_glyph, 1, 1, 0, /*
Return the glyph that the given mouse event occurred over, or nil.
*/
       (event))
{
  Lisp_Object glyph;
  struct window *w;

  event_pixel_translation (event, 0, 0, 0, 0, &w, 0, 0, 0, &glyph, 0);

  if (!w)
    return Qnil;
  else if (GLYPHP (glyph))
    return glyph;
  else
    return Qnil;
}

DEFUN ("event-glyph-extent", Fevent_glyph_extent, 1, 1, 0, /*
Return the extent of the glyph that the given mouse event occurred over.
If the event did not occur over a glyph, nil is returned.
*/
       (event))
{
  Lisp_Object extent;
  struct window *w;

  event_pixel_translation (event, 0, 0, 0, 0, &w, 0, 0, 0, 0, &extent);

  if (!w)
    return Qnil;
  else if (EXTENTP (extent))
    return extent;
  else
    return Qnil;
}

DEFUN ("event-glyph-x-pixel", Fevent_glyph_x_pixel, 1, 1, 0, /*
Return the X pixel position of EVENT relative to the glyph it occurred over.
EVENT should be a mouse event.  If the event did not occur over a glyph,
nil is returned.
*/
       (event))
{
  Lisp_Object extent;
  struct window *w;
  int obj_x;

  event_pixel_translation (event, 0, 0, &obj_x, 0, &w, 0, 0, 0, 0, &extent);

  if (w && EXTENTP (extent))
    return make_int (obj_x);
  else
    return Qnil;
}

DEFUN ("event-glyph-y-pixel", Fevent_glyph_y_pixel, 1, 1, 0, /*
Return the Y pixel position of EVENT relative to the glyph it occurred over.
EVENT should be a mouse event.  If the event did not occur over a glyph,
nil is returned.
*/
       (event))
{
  Lisp_Object extent;
  struct window *w;
  int obj_y;

  event_pixel_translation (event, 0, 0, 0, &obj_y, &w, 0, 0, 0, 0, &extent);

  if (w && EXTENTP (extent))
    return make_int (obj_y);
  else
    return Qnil;
}

DEFUN ("event-toolbar-button", Fevent_toolbar_button, 1, 1, 0, /*
Return the toolbar button that the given mouse event occurred over.
If the event did not occur over a toolbar, nil is returned.
*/
       (event))
{
#ifdef HAVE_TOOLBARS
  Lisp_Object button;
  int result;

  result = event_pixel_translation (event, 0, 0, 0, 0, 0, 0, 0, 0, &button, 0);

  if (result == OVER_TOOLBAR)
    {
      if (TOOLBAR_BUTTONP (button))
	return button;
      else
	return Qnil;
    }
  else
#endif
    return Qnil;
}

DEFUN ("event-process", Fevent_process, 1, 1, 0, /*
Return the process of the given process-output event.
*/
       (event))
{
  CHECK_EVENT_TYPE (event, process_event, Qprocess_event_p);
  return (XEVENT (event)->event.process.process);
}

DEFUN ("event-function", Fevent_function, 1, 1, 0, /*
Return the callback function of EVENT.
EVENT should be a timeout, misc-user, or eval event.
*/
       (event))
{
  CHECK_LIVE_EVENT (event);
  switch (XEVENT (event)->event_type)
    {
    case timeout_event:
      return (XEVENT (event)->event.timeout.function);
    case misc_user_event:
    case eval_event:
      return (XEVENT (event)->event.eval.function);
    default:
      return wrong_type_argument (intern ("timeout-or-eval-event-p"), event);
    }
}

DEFUN ("event-object", Fevent_object, 1, 1, 0, /*
Return the callback function argument of EVENT.
EVENT should be a timeout, misc-user, or eval event.
*/
       (event))
{
 again:
  CHECK_LIVE_EVENT (event);
  switch (XEVENT (event)->event_type)
    {
    case timeout_event:
      return (XEVENT (event)->event.timeout.object);
    case misc_user_event:
    case eval_event:
      return (XEVENT (event)->event.eval.object);
    default:
      event = wrong_type_argument (intern ("timeout-or-eval-event-p"), event);
      goto again;
    }
}

DEFUN ("event-properties", Fevent_properties, 1, 1, 0, /*
Return a list of all of the properties of EVENT.
This is in the form of a property list (alternating keyword/value pairs).
*/
       (event))
{
  Lisp_Object props = Qnil;
  struct Lisp_Event *e;
  struct gcpro gcpro1;

  CHECK_LIVE_EVENT (event);
  e = XEVENT (event);
  GCPRO1 (props);

  props = Fcons (Qtimestamp, Fcons (Fevent_timestamp (event), props));

  switch (e->event_type)
    {
    case process_event:
      props = Fcons (Qprocess, Fcons (e->event.process.process, props));
      break;
    
    case timeout_event:
      props = Fcons (Qobject, Fcons (Fevent_object (event), props));
      props = Fcons (Qfunction, Fcons (Fevent_function (event), props));
      props = Fcons (Qid, Fcons (make_int (e->event.timeout.id_number),
				 props));
      break;

    case key_press_event:
      props = Fcons (Qmodifiers, Fcons (Fevent_modifiers (event), props));
      props = Fcons (Qkey, Fcons (Fevent_key (event), props));
      break;

    case button_press_event:
    case button_release_event:
      props = Fcons (Qy, Fcons (Fevent_y_pixel (event), props));
      props = Fcons (Qx, Fcons (Fevent_x_pixel (event), props));
      props = Fcons (Qmodifiers, Fcons (Fevent_modifiers (event), props));
      props = Fcons (Qbutton, Fcons (Fevent_button (event), props));
      break;

    case pointer_motion_event:
      props = Fcons (Qmodifiers, Fcons (Fevent_modifiers (event), props));
      props = Fcons (Qy, Fcons (Fevent_y_pixel (event), props));
      props = Fcons (Qx, Fcons (Fevent_x_pixel (event), props));
      break;

    case misc_user_event:
    case eval_event:
      props = Fcons (Qobject, Fcons (Fevent_object (event), props));
      props = Fcons (Qfunction, Fcons (Fevent_function (event), props));
      break;

    case magic_eval_event:
    case magic_event:
    case empty_event:
      break;

    default:
      abort ();
      break;                 /* not reached; warning suppression */
    }

  props = Fcons (Qchannel, Fcons (Fevent_channel (event), props));
  UNGCPRO;

  return props;
}


/************************************************************************/
/*                            initialization                            */
/************************************************************************/

void
syms_of_events (void)
{
  DEFSUBR (Fcharacter_to_event);
  DEFSUBR (Fevent_to_character);

  DEFSUBR (Fmake_event);
  DEFSUBR (Fdeallocate_event);
  DEFSUBR (Fcopy_event);
  DEFSUBR (Feventp);
  DEFSUBR (Fevent_live_p);
  DEFSUBR (Fevent_type);
  DEFSUBR (Fevent_properties);

  DEFSUBR (Fevent_timestamp);
  DEFSUBR (Fevent_key);
  DEFSUBR (Fevent_button);
  DEFSUBR (Fevent_modifier_bits);
  DEFSUBR (Fevent_modifiers);
  DEFSUBR (Fevent_x_pixel);
  DEFSUBR (Fevent_y_pixel);
  DEFSUBR (Fevent_window_x_pixel);
  DEFSUBR (Fevent_window_y_pixel);
  DEFSUBR (Fevent_over_text_area_p);
  DEFSUBR (Fevent_over_modeline_p);
  DEFSUBR (Fevent_over_border_p);
  DEFSUBR (Fevent_over_toolbar_p);
  DEFSUBR (Fevent_channel);
  DEFSUBR (Fevent_window);
  DEFSUBR (Fevent_point);
  DEFSUBR (Fevent_closest_point);
  DEFSUBR (Fevent_x);
  DEFSUBR (Fevent_y);
  DEFSUBR (Fevent_modeline_position);
  DEFSUBR (Fevent_glyph);
  DEFSUBR (Fevent_glyph_extent);
  DEFSUBR (Fevent_glyph_x_pixel);
  DEFSUBR (Fevent_glyph_y_pixel);
  DEFSUBR (Fevent_toolbar_button);
  DEFSUBR (Fevent_process);
  DEFSUBR (Fevent_function);
  DEFSUBR (Fevent_object);

  defsymbol (&Qeventp, "eventp");
  defsymbol (&Qevent_live_p, "event-live-p");
  defsymbol (&Qkey_press_event_p, "key-press-event-p");
  defsymbol (&Qbutton_event_p, "button-event-p");
  defsymbol (&Qmouse_event_p, "mouse-event-p");
  defsymbol (&Qprocess_event_p, "process-event-p");
  defsymbol (&Qkey_press, "key-press");
  defsymbol (&Qbutton_press, "button-press");
  defsymbol (&Qbutton_release, "button-release");
  defsymbol (&Qmisc_user, "misc-user");
  defsymbol (&Qascii_character, "ascii-character");
}

void
vars_of_events (void)
{
  DEFVAR_LISP ("character-set-property", &Vcharacter_set_property /*
A symbol used to look up the 8-bit character of a keysym.
To convert a keysym symbol to an 8-bit code, as when that key is
bound to self-insert-command, we will look up the property that this
variable names on the property list of the keysym-symbol.  The window-
system-specific code will set up appropriate properties and set this
variable.
*/ );
  Vcharacter_set_property = Qnil;

  Vevent_resource = Qnil;

  QKbackspace = KEYSYM ("backspace");
  QKtab       = KEYSYM ("tab");
  QKlinefeed  = KEYSYM ("linefeed");
  QKreturn    = KEYSYM ("return");
  QKescape    = KEYSYM ("escape");
  QKspace     = KEYSYM ("space");
  QKdelete    = KEYSYM ("delete");

  staticpro (&QKbackspace);
  staticpro (&QKtab);
  staticpro (&QKlinefeed);
  staticpro (&QKreturn);
  staticpro (&QKescape);
  staticpro (&QKspace);
  staticpro (&QKdelete);
}
