/* Markers: examining, setting and killing.
   Copyright (C) 1985, 1992, 1993, 1994, 1995 Free Software Foundation, Inc.

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

/* Synched up with: FSF 19.30. */

/* This file has been Mule-ized. */

/* Note that markers are currently kept in an unordered list.
   This means that marker operations may be inefficient if
   there are a bunch of markers in the buffer.  This probably
   won't have a significant impact on redisplay (which uses
   markers), but if it does, it wouldn't be too hard to change
   to an ordered gap array. (Just copy the code from extents.c.)
   */

#include <config.h>
#include "lisp.h"

#include "buffer.h"

static Lisp_Object mark_marker (Lisp_Object, void (*) (Lisp_Object));
static void print_marker (Lisp_Object, Lisp_Object, int);
static int marker_equal (Lisp_Object, Lisp_Object, int);
static unsigned long marker_hash (Lisp_Object obj, int depth);
DEFINE_BASIC_LRECORD_IMPLEMENTATION ("marker", marker,
				     mark_marker, print_marker, 0,
				     marker_equal, marker_hash,
				     struct Lisp_Marker);

static Lisp_Object
mark_marker (Lisp_Object obj, void (*markobj) (Lisp_Object))
{
  struct Lisp_Marker *marker = XMARKER (obj);
  Lisp_Object buf;
  /* DO NOT mark through the marker's chain.
     The buffer's markers chain does not preserve markers from gc;
     Instead, markers are removed from the chain when they are freed
     by gc.
   */
  if (!marker->buffer)
    return (Qnil);

  XSETBUFFER (buf, marker->buffer);
  return (buf);
}

static void
print_marker (Lisp_Object obj, Lisp_Object printcharfun, int escapeflag)
{
  if (print_readably)
    error ("printing unreadable object #<marker>");
      
  write_c_string (GETTEXT ("#<marker "), printcharfun);
  if (!(XMARKER (obj)->buffer))
    write_c_string (GETTEXT ("in no buffer"), printcharfun);
  else
    {
      char buf[200];
      sprintf (buf, "at %d", marker_position (obj));
      write_c_string (buf, printcharfun);
      write_c_string (" in ", printcharfun);
      print_internal (XMARKER (obj)->buffer->name, printcharfun, 0);
    }
  write_c_string (">", printcharfun);
}

static int
marker_equal (Lisp_Object o1, Lisp_Object o2, int depth)
{
  struct buffer *b1 = XMARKER (o1)->buffer;
  if (b1 != XMARKER (o2)->buffer)
    return (0);
  else if (!b1)
    /* All markers pointing nowhere are equal */
    return (1);
  else
    return ((XMARKER (o1)->memind == XMARKER (o2)->memind));
}

static unsigned long
marker_hash (Lisp_Object obj, int depth)
{
  unsigned long hash = (unsigned long) XMARKER (obj)->buffer;
  if (hash)
    hash = HASH2 (hash, XMARKER (obj)->memind);
  return hash;
}


/* Operations on markers. */

DEFUN ("marker-buffer", Fmarker_buffer, 1, 1, 0, /*
Return the buffer that MARKER points into, or nil if none.
Returns nil if MARKER points into a dead buffer.
*/
       (marker))
{
  Lisp_Object buf;
  CHECK_MARKER (marker);
  if (XMARKER (marker)->buffer)
    {
      XSETBUFFER (buf, XMARKER (marker)->buffer);
      /* Return marker's buffer only if it is not dead.  */
      if (BUFFER_LIVE_P (XBUFFER (buf)))
	return buf;
    }
  return Qnil;
}

DEFUN ("marker-position", Fmarker_position, 1, 1, 0, /*
Return the position MARKER points at, as a character number.
Returns `nil' if marker doesn't point anywhere.
*/
       (marker))
{
  CHECK_MARKER (marker);
  if (XMARKER (marker)->buffer)
    {
      return (make_int (marker_position (marker)));
    }
  return Qnil;
}

#if 0 /* useful debugging function */

static void
check_marker_circularities (struct buffer *buf)
{
  struct Lisp_Marker *tortoise, *hare;

  tortoise = BUF_MARKERS (buf);
  hare = tortoise;

  if (!tortoise)
    return;

  while (1)
    {
      assert (hare->buffer == buf);
      hare = hare->next;
      if (!hare)
        return;
      assert (hare->buffer == buf);
      hare = hare->next;
      if (!hare)
        return;
      tortoise = tortoise->next;
      assert (tortoise != hare);
    }
}

#endif

static Lisp_Object
set_marker_internal (Lisp_Object marker, Lisp_Object pos, Lisp_Object buffer,
		     int restricted_p)
{
  Bufpos charno;
  struct buffer *b;
  struct Lisp_Marker *m;
  int point_p;

  CHECK_MARKER (marker);

  point_p = POINT_MARKER_P (marker);

  /* If position is nil or a marker that points nowhere,
     make this marker point nowhere.  */
  if (NILP (pos) ||
      (MARKERP (pos) && !XMARKER (pos)->buffer))
    {
      if (point_p)
	signal_simple_error ("can't make point-marker point nowhere",
			     marker);
      if (XMARKER (marker)->buffer)
	unchain_marker (marker);
      return marker;
    }

  CHECK_INT_COERCE_MARKER (pos);
  if (NILP (buffer))
    b = current_buffer;
  else
    {
      CHECK_BUFFER (buffer);
      b = XBUFFER (buffer);
      /* If buffer is dead, set marker to point nowhere.  */
      if (!BUFFER_LIVE_P (XBUFFER (buffer)))
	{
	  if (point_p)
	    signal_simple_error
	      ("can't move point-marker in a killed buffer", marker);
	  if (XMARKER (marker)->buffer)
	    unchain_marker (marker);
	  return marker;
	}
    }

  charno = XINT (pos);
  m = XMARKER (marker);

  if (restricted_p)
    {
      if (charno < BUF_BEGV (b)) charno = BUF_BEGV (b);
      if (charno > BUF_ZV (b)) charno = BUF_ZV (b);
    }
  else
    {
      if (charno < BUF_BEG (b)) charno = BUF_BEG (b);
      if (charno > BUF_Z (b)) charno = BUF_Z (b);
    }

  if (point_p)
    {
#ifndef moving_point_by_moving_its_marker_is_a_bug
      BUF_SET_PT (b, charno);	/* this will move the marker */
#else  /* It's not a feature, so it must be a bug */
      signal_simple_error ("DEBUG: attempt to move point via point-marker",
			   marker);
#endif
    }
  else
    {
      m->memind = bufpos_to_memind (b, charno);
    }

  if (m->buffer != b)
    {
      if (point_p)
	signal_simple_error ("can't change buffer of point-marker", marker);
      if (m->buffer != 0)
	unchain_marker (marker);
      m->buffer = b;
      marker_next (m) = BUF_MARKERS (b);
      marker_prev (m) = 0;
      if (BUF_MARKERS (b))
        marker_prev (BUF_MARKERS (b)) = m;
      BUF_MARKERS (b) = m;
    }
  
  return marker;
}


DEFUN ("set-marker", Fset_marker, 2, 3, 0, /*
Position MARKER before character number NUMBER in BUFFER.
BUFFER defaults to the current buffer.
If NUMBER is nil, makes marker point nowhere.
Then it no longer slows down editing in any buffer.
If this marker was returned by (point-marker t), then changing its position
moves point.  You cannot change its buffer or make it point nowhere.
Returns MARKER.
*/
       (marker, number, buffer))
{
  return set_marker_internal (marker, number, buffer, 0);
}


/* This version of Fset_marker won't let the position
   be outside the visible part.  */
Lisp_Object 
set_marker_restricted (Lisp_Object marker, Lisp_Object pos, Lisp_Object buffer)
{
  return set_marker_internal (marker, pos, buffer, 1);
}


/* This is called during garbage collection,
   so we must be careful to ignore and preserve mark bits,
   including those in chain fields of markers.  */

void
unchain_marker (Lisp_Object m)
{
  struct Lisp_Marker *marker = XMARKER (m);
  struct buffer *b = marker->buffer;

  if (b == 0)
    return;

  assert (BUFFER_LIVE_P (b));

  if (marker_next (marker))
    marker_prev (marker_next (marker)) = marker_prev (marker);
  if (marker_prev (marker))
    marker_next (marker_prev (marker)) = marker_next (marker);
  else
    BUF_MARKERS (b) = marker_next (marker);

  assert (marker != XMARKER (b->point_marker));

  marker->buffer = 0;
}

Bytind
bi_marker_position (Lisp_Object marker)
{
  struct Lisp_Marker *m = XMARKER (marker);
  struct buffer *buf = m->buffer;
  Bytind pos;

  if (!buf)
    error ("Marker does not point anywhere");

  /* FSF claims that marker indices could end up denormalized, i.e.
     in the gap.  This is way bogus if it ever happens, and means
     something fucked up elsewhere.  Since I've overhauled all this
     shit, I don't think this can happen.  In any case, the following
     macro has an assert() in it that will catch these denormalized
     positions. */
  pos = memind_to_bytind (buf, m->memind);

  if (pos < BI_BUF_BEG (buf) || pos > BI_BUF_Z (buf))
    abort ();

  return pos;
}

Bufpos
marker_position (Lisp_Object marker)
{
  struct buffer *buf = XMARKER (marker)->buffer;

  if (!buf)
    error ("Marker does not point anywhere");

  return bytind_to_bufpos (buf, bi_marker_position (marker));
}

void
set_bi_marker_position (Lisp_Object marker, Bytind pos)
{
  struct Lisp_Marker *m = XMARKER (marker);
  struct buffer *buf = m->buffer;

  if (!buf)
    error ("Marker does not point anywhere");

  if (pos < BI_BUF_BEG (buf) || pos > BI_BUF_Z (buf))
    abort ();

  m->memind = bytind_to_memind (buf, pos);
}

void
set_marker_position (Lisp_Object marker, Bufpos pos)
{
  struct buffer *buf = XMARKER (marker)->buffer;

  if (!buf)
    error ("Marker does not point anywhere");

  set_bi_marker_position (marker, bufpos_to_bytind (buf, pos));
}

static Lisp_Object
copy_marker_1 (Lisp_Object marker, Lisp_Object type, int noseeum)
{
  REGISTER Lisp_Object new;

  while (1)
    {
      if (INTP (marker) || MARKERP (marker))
	{
	  if (noseeum)
	    new = noseeum_make_marker ();
	  else
	    new = Fmake_marker ();
	  Fset_marker (new, marker,
		       (MARKERP (marker) ? Fmarker_buffer (marker) : Qnil));
	  XMARKER (new)->insertion_type = !NILP (type);
	  return new;
	}
      else
	marker = wrong_type_argument (Qinteger_or_marker_p, marker);
    }

  RETURN_NOT_REACHED (Qnil) /* not reached */
}

DEFUN ("copy-marker", Fcopy_marker, 1, 2, 0, /*
Return a new marker pointing at the same place as MARKER.
If argument is a number, makes a new marker pointing
at that position in the current buffer.
The optional argument TYPE specifies the insertion type of the new marker;
see `marker-insertion-type'.
*/
       (marker, type))
{
  return copy_marker_1 (marker, type, 0);
}

Lisp_Object
noseeum_copy_marker (Lisp_Object marker, Lisp_Object type)
{
  return copy_marker_1 (marker, type, 1);
}

DEFUN ("marker-insertion-type", Fmarker_insertion_type, 1, 1, 0, /*
Return insertion type of MARKER: t if it stays after inserted text.
nil means the marker stays before text inserted there.
*/
       (marker))
{
  CHECK_MARKER (marker);
  return XMARKER (marker)->insertion_type ? Qt : Qnil;
}

DEFUN ("set-marker-insertion-type", Fset_marker_insertion_type, 2, 2, 0, /*
Set the insertion-type of MARKER to TYPE.
If TYPE is t, it means the marker advances when you insert text at it.
If TYPE is nil, it means the marker stays behind when you insert text at it.
*/
       (marker, type))
{
  CHECK_MARKER (marker);

  XMARKER (marker)->insertion_type = ! NILP (type);
  return type;
}

#ifdef MEMORY_USAGE_STATS

int
compute_buffer_marker_usage (struct buffer *b, struct overhead_stats *ovstats)
{
  struct Lisp_Marker *m;
  int total = 0;
  int overhead;

  for (m = BUF_MARKERS (b); m; m = m->next)
    total += sizeof (struct Lisp_Marker);
  ovstats->was_requested += total;
  overhead = fixed_type_block_overhead (total);
  /* #### claiming this is all malloc overhead is not really right,
     but it has to go somewhere. */
  ovstats->malloc_overhead += overhead;
  return total + overhead;
}

#endif /* MEMORY_USAGE_STATS */


void
syms_of_marker (void)
{
  DEFSUBR (Fmarker_position);
  DEFSUBR (Fmarker_buffer);
  DEFSUBR (Fset_marker);
  DEFSUBR (Fcopy_marker);
  DEFSUBR (Fmarker_insertion_type);
  DEFSUBR (Fset_marker_insertion_type);
}

void init_buffer_markers (struct buffer *b);
void
init_buffer_markers (struct buffer *b)
{
  Lisp_Object buf = Qnil;

  XSETBUFFER (buf, b);
  b->mark = Fmake_marker ();
  BUF_MARKERS (b) = 0;
  b->point_marker = Fmake_marker ();
  Fset_marker (b->point_marker, make_int (1), buf);
}

void uninit_buffer_markers (struct buffer *b);
void
uninit_buffer_markers (struct buffer *b)
{
  /* Unchain all markers of this buffer
     and leave them pointing nowhere.  */
  REGISTER struct Lisp_Marker *m, *next;
  for (m = BUF_MARKERS (b); m; m = next)
    {
      m->buffer = 0;
      next = marker_next (m);
      marker_next (m) = 0;
      marker_prev (m) = 0;
    }
  BUF_MARKERS (b) = 0;
}
