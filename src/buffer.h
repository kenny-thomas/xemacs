/* Header file for the buffer manipulation primitives.
   Copyright (C) 1985, 1986, 1992, 1993, 1994, 1995
   Free Software Foundation, Inc.
   Copyright (C) 1995 Sun Microsystems, Inc.

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

/* Authorship:

   FSF: long ago.
   JWZ: separated out bufslots.h, early in Lemacs.
   Ben Wing: almost completely rewritten for Mule, 19.12.
 */

#ifndef _XEMACS_BUFFER_H_
#define _XEMACS_BUFFER_H_

#ifdef MULE
#include "mule-charset.h"
#endif

/************************************************************************/
/*                                                                      */
/*                    definition of Lisp buffer object                  */
/*                                                                      */
/************************************************************************/

/* Note: we keep both Bytind and Bufpos versions of some of the
   important buffer positions because they are accessed so much.
   If we didn't do this, we would constantly be invalidating the
   bufpos<->bytind cache under Mule.

   Note that under non-Mule, both versions will always be the
   same so we don't really need to keep track of them.  But it
   simplifies the logic to go ahead and do so all the time and
   the memory loss is insignificant. */

/* Formerly, it didn't much matter what went inside the struct buffer_text
   and what went outside it.  Now it does, with the advent of "indirect
   buffers" that share text with another buffer.  An indirect buffer
   shares the same *text* as another buffer, but has its own buffer-local
   variables, its own accessible region, and its own markers and extents.
   (Due to the nature of markers, it doesn't actually matter much whether
   we stick them inside or out of the struct buffer_text -- the user won't
   notice any difference -- but we go ahead and put them outside for
   consistency and overall saneness of algorithm.)

   FSFmacs gets away with not maintaining any "children" pointers from
   a buffer to the indirect buffers that refer to it by putting the
   markers inside of the struct buffer_text, using markers to keep track
   of BEGV and ZV in indirect buffers, and relying on the fact that
   all intervals (text properties and overlays) use markers for their
   start and end points.  We don't do this for extents (markers are
   inefficient anyway and take up space), so we have to maintain
   children pointers.  This is not terribly hard, though, and the
   code to maintain this is just like the code already present in
   extent-parent and extent-children.
   */

struct buffer_text
{
  Bufbyte *beg;		/* Actual address of buffer contents. */    
  Bytind gpt;		/* Index of gap in buffer. */
  Bytind z;		/* Index of end of buffer. */
  Bufpos bufz;		/* Equivalent as a Bufpos. */
  int gap_size;		/* Size of buffer's gap */
  int end_gap_size;	/* Size of buffer's end gap */
  long modiff;		/* This counts buffer-modification events
			   for this buffer.  It is incremented for
			   each such event, and never otherwise
			   changed.  */
  long save_modiff;	/* Previous value of modiff, as of last
			   time buffer visited or saved a file.  */

#ifdef MULE
  /* We keep track of a "known" region for very fast access.
     This information is text-only so it goes here. */
  Bufpos mule_bufmin, mule_bufmax;
  Bytind mule_bytmin, mule_bytmax;
  int mule_shifter, mule_three_p;

  /* And we also cache 16 positions for fairly fast access near those
     positions. */
  Bufpos mule_bufpos_cache[16];
  Bytind mule_bytind_cache[16];
#endif

  /* Change data that goes with the text. */
  struct buffer_text_change_data *changes;

};

struct buffer
{
  struct lcrecord_header header;

  /* This structure holds the coordinates of the buffer contents
     in ordinary buffers.  In indirect buffers, this is not used.  */
  struct buffer_text own_text;

  /* This points to the `struct buffer_text' that is used for this buffer.
     In an ordinary buffer, this is the own_text field above.
     In an indirect buffer, this is the own_text field of another buffer.  */
  struct buffer_text *text;

  Bytind pt;		/* Position of point in buffer. */
  Bufpos bufpt;		/* Equivalent as a Bufpos. */
  Bytind begv;		/* Index of beginning of accessible range. */
  Bufpos bufbegv;	/* Equivalent as a Bufpos. */
  Bytind zv;		/* Index of end of accessible range. */
  Bufpos bufzv;		/* Equivalent as a Bufpos. */

  int face_change;	/* This is set when a change in how the text should
			   be displayed (e.g., font, color) is made. */

  /* change data indicating what portion of the text has changed
     since the last time this was reset.  Used by redisplay.
     Logically we should keep this with the text structure, but
     redisplay resets it for each buffer individually and we don't
     want interference between an indirect buffer and its base
     buffer. */
  struct each_buffer_change_data *changes;

#ifdef REGION_CACHE_NEEDS_WORK
  /* If the long line scan cache is enabled (i.e. the buffer-local
     variable cache-long-line-scans is non-nil), newline_cache
     points to the newline cache, and width_run_cache points to the
     width run cache.

     The newline cache records which stretches of the buffer are
     known *not* to contain newlines, so that they can be skipped
     quickly when we search for newlines.

     The width run cache records which stretches of the buffer are
     known to contain characters whose widths are all the same.  If
     the width run cache maps a character to a value > 0, that value
     is the character's width; if it maps a character to zero, we
     don't know what its width is.  This allows compute_motion to
     process such regions very quickly, using algebra instead of
     inspecting each character.  See also width_table, below.  */
  struct region_cache *newline_cache;
  struct region_cache *width_run_cache;
#endif /* REGION_CACHE_NEEDS_WORK */

  /* The markers that refer to this buffer.  This is actually a single
     marker -- successive elements in its marker `chain' are the other
     markers referring to this buffer */
  struct Lisp_Marker *markers;

  /* The buffer's extent info.  This is its own type, an extent-info
     object (done this way for ease in marking / finalizing). */
  Lisp_Object extent_info;

  /* ----------------------------------------------------------------- */
  /* All the stuff above this line is the responsibility of insdel.c,
     with some help from marker.c and extents.c.
     All the stuff below this line is the responsibility of buffer.c. */

  /* In an indirect buffer, this points to the base buffer.
     In an ordinary buffer, it is 0.
     We DO mark through this slot. */
  struct buffer *base_buffer;

  /* List of indirect buffers whose base is this buffer.
     If we are an indirect buffer, this will be nil.
     Do NOT mark through this. */
  Lisp_Object indirect_children;

  /* Flags saying which DEFVAR_PER_BUFFER variables
     are local to this buffer.  */
  int local_var_flags;

  /* Set to the modtime of the visited file when read or written.
     -1 means visited file was nonexistent.
     0  means visited file modtime unknown; in no case complain
     about any mismatch on next save attempt.  */
  int modtime;

  /* the value of text->modiff at the last auto-save.  */
  int auto_save_modified;

  /* The time at which we detected a failure to auto-save,
     Or -1 if we didn't have a failure.  */
  int auto_save_failure_time;

  /* Position in buffer at which display started
     the last time this buffer was displayed.  */
  int last_window_start;

  /* Everything from here down must be a Lisp_Object */

#define MARKED_SLOT(x) Lisp_Object x
#include "bufslots.h"
#undef MARKED_SLOT
};

DECLARE_LRECORD (buffer, struct buffer);
#define XBUFFER(x) XRECORD (x, buffer, struct buffer)
#define XSETBUFFER(x, p) XSETRECORD (x, p, buffer)
#define BUFFERP(x) RECORDP (x, buffer)
#define GC_BUFFERP(x) GC_RECORDP (x, buffer)
#define CHECK_BUFFER(x) CHECK_RECORD (x, buffer)
#define CONCHECK_BUFFER(x) CONCHECK_RECORD (x, buffer)

#define BUFFER_LIVE_P(b) (!NILP ((b)->name))
extern Lisp_Object Qbuffer_live_p;
#define CHECK_LIVE_BUFFER(x) 						\
  do { CHECK_BUFFER (x);						\
       if (!BUFFER_LIVE_P (XBUFFER (x)))				\
	 dead_wrong_type_argument (Qbuffer_live_p, (x));		\
     } while (0)
#define CONCHECK_LIVE_BUFFER(x) 					\
  do { CONCHECK_BUFFER (x);						\
       if (!BUFFER_LIVE_P (XBUFFER (x)))				\
	 x = wrong_type_argument (Qbuffer_live_p, (x));			\
     } while (0)

#define BUFFER_OR_STRING_P(x) (BUFFERP (x) || STRINGP (x))

extern Lisp_Object Qbuffer_or_string_p;
#define CHECK_BUFFER_OR_STRING(x)					\
  do { if (!BUFFER_OR_STRING_P (x))					\
	 dead_wrong_type_argument (Qbuffer_or_string_p, (x));		\
     } while (0)
#define CONCHECK_BUFFER_OR_STRING(x)					\
  do { if (!BUFFER_OR_STRING_P (x))					\
	 x = wrong_type_argument (Qbuffer_or_string_p, (x));		\
     } while (0)

#define CHECK_LIVE_BUFFER_OR_STRING(x)					\
  do { CHECK_BUFFER_OR_STRING (x);					\
       if (BUFFERP (x))							\
	 CHECK_LIVE_BUFFER (x);						\
     } while (0)
#define CONCHECK_LIVE_BUFFER_OR_STRING(x)				\
  do { CONCHECK_BUFFER_OR_STRING (x);					\
       if (BUFFERP (x))							\
	 CONCHECK_LIVE_BUFFER (x);					\
     } while (0)



/* NOTE: In all the following macros, we follow these rules concerning
   multiple evaluation of the arguments:

   1) Anything that's an lvalue can be evaluated more than once.
   2) Anything that's a Lisp Object can be evaluated more than once.
      This should probably be changed, but this follows the way
      that all the macros in lisp.h do things.
   3) 'struct buffer *' arguments can be evaluated more than once.
   4) Nothing else can be evaluated more than once.  Use MTxx
      variables to prevent multiple evaluation.
   5) An exception to (4) is that there are some macros below that
      may evaluate their arguments more than once.  They are all
      denoted with the word "unsafe" in their name and are generally
      meant to be called only by other macros that have already
      stored the calling values in temporary variables.

 */

/************************************************************************/
/*                                                                      */
/*                 working with raw internal-format data                */
/*                                                                      */
/************************************************************************/

/* Use these on contiguous strings of data.  If the text you're
   operating on is known to come from a buffer, use the buffer-level
   functions below -- they know about the gap and may be more
   efficient. */

/* Functions are as follows:


   (A) For working with charptr's (pointers to internally-formatted text):
   -----------------------------------------------------------------------

   VALID_CHARPTR_P(ptr):
	Given a charptr, does it point to the beginning of a character?

   ASSERT_VALID_CHARPTR(ptr):
	If error-checking is enabled, assert that the given charptr
	points to the beginning of a character.  Otherwise, do nothing.

   INC_CHARPTR(ptr):
	Given a charptr (assumed to point at the beginning of a character),
	modify that pointer so it points to the beginning of the next
	character.

   DEC_CHARPTR(ptr):
	Given a charptr (assumed to point at the beginning of a
	character or at the very end of the text), modify that pointer
	so it points to the beginning of the previous character.

   VALIDATE_CHARPTR_BACKWARD(ptr):
	Make sure that PTR is pointing to the beginning of a character.
	If not, back up until this is the case.   Note that there are not
	too many places where it is legitimate to do this sort of thing.
	It's an error if you're passed an "invalid" char * pointer.
	NOTE: PTR *must* be pointing to a valid part of the string (i.e.
	not the very end, unless the string is zero-terminated or
	something) in order for this function to not cause crashes.

   VALIDATE_CHARPTR_FORWARD(ptr):
	Make sure that PTR is pointing to the beginning of a character.
	If not, move forward until this is the case.  Note that there
	are not too many places where it is legitimate to do this sort
	of thing.  It's an error if you're passed an "invalid" char *
	pointer.


   (B) For working with the length (in bytes and characters) of a
       section of internally-formatted text:
   --------------------------------------------------------------

   bytecount_to_charcount(ptr, nbi):
	Given a pointer to a text string and a length in bytes,
	return the equivalent length in characters.

   charcount_to_bytecount(ptr, nch):
	Given a pointer to a text string and a length in characters,
	return the equivalent length in bytes.

   charptr_n_addr(ptr, n):
	Return a pointer to the beginning of the character offset N
	(in characters) from PTR.

   charptr_length(ptr):
	Given a zero-terminated pointer to Emacs characters,
	return the number of Emacs characters contained within.


   (C) For retrieving or changing the character pointed to by a charptr:
   ---------------------------------------------------------------------

   charptr_emchar(ptr):
	Retrieve the character pointed to by PTR as an Emchar.

   charptr_emchar_n(ptr, n):
	Retrieve the character at offset N (in characters) from PTR,
	as an Emchar.

   set_charptr_emchar(ptr, ch):
	Store the character CH (an Emchar) as internally-formatted
	text starting at PTR.  Return the number of bytes stored.

   charptr_copy_char(ptr, ptr2):
	Retrieve the character pointed to by PTR and store it as
	internally-formatted text in PTR2.


   (D) For working with Emchars:
   -----------------------------

   [Note that there are other functions/macros for working with Emchars
    in mule-charset.h, for retrieving the charset of an Emchar
    and such.  These are only valid when MULE is defined.]

   valid_char_p(ch):
	Return whether the given Emchar is valid.

   CHARP(ch):
        Return whether the given Lisp_Object is a valid character.
	This is approximately the same as saying the Lisp_Object is
	an int whose value is a valid Emchar. (But not exactly
	because when MULE is not defined, we allow arbitrary values
	in all but the lowest 8 bits and mask them off, for backward
	compatibility.)

   CHECK_CHAR_COERCE_INT(ch):
	Signal an error if CH is not a valid character as per CHARP().
	Also canonicalize the value into a valid Emchar, as necessary.
	(This only means anything when MULE is not defined.)

   COERCE_CHAR(ch):
	Coerce an object that is known to satisfy CHARP() into a
	valid Emchar.

   MAX_EMCHAR_LEN:
	Maximum number of buffer bytes per Emacs character.

*/


/* ---------------------------------------------------------------------- */
/* (A) For working with charptr's (pointers to internally-formatted text) */
/* ---------------------------------------------------------------------- */

#ifdef MULE
# define VALID_CHARPTR_P(ptr) BUFBYTE_FIRST_BYTE_P (* (unsigned char *) ptr)
#else
# define VALID_CHARPTR_P(ptr) 1
#endif

#ifdef ERROR_CHECK_BUFPOS
# define ASSERT_VALID_CHARPTR(ptr) assert (VALID_CHARPTR_P (ptr))
#else
# define ASSERT_VALID_CHARPTR(ptr)
#endif

/* Note that INC_CHARPTR() and DEC_CHARPTR() have to be written in
   completely separate ways.  INC_CHARPTR() cannot use the DEC_CHARPTR()
   trick of looking for a valid first byte because it might run off
   the end of the string.  DEC_CHARPTR() can't use the INC_CHARPTR()
   method because it doesn't have easy access to the first byte of
   the character it's moving over. */

#define real_inc_charptr_fun(ptr) \
  ((ptr) += REP_BYTES_BY_FIRST_BYTE (* (unsigned char *) (ptr)))
#ifdef ERROR_CHECK_BUFPOS
#define inc_charptr_fun(ptr) (ASSERT_VALID_CHARPTR (ptr), \
			      real_inc_charptr_fun (ptr))
#else
#define inc_charptr_fun(ptr) real_inc_charptr_fun (ptr)
#endif

#define REAL_INC_CHARPTR(ptr) do		\
{						\
  real_inc_charptr_fun (ptr);			\
} while (0)

#define INC_CHARPTR(ptr) do			\
{						\
  ASSERT_VALID_CHARPTR (ptr);			\
  REAL_INC_CHARPTR (ptr);			\
} while (0)

#define REAL_DEC_CHARPTR(ptr) do		\
{						\
  (ptr)--;					\
} while (!VALID_CHARPTR_P (ptr))

#ifdef ERROR_CHECK_BUFPOS
#define DEC_CHARPTR(ptr) do			  \
{						  \
  CONST Bufbyte *__dcptr__ = (ptr);		  \
  CONST Bufbyte *__dcptr2__ = __dcptr__;	  \
  REAL_DEC_CHARPTR (__dcptr2__);		  \
  assert (__dcptr__ - __dcptr2__ ==		  \
	  REP_BYTES_BY_FIRST_BYTE (*__dcptr2__)); \
  (ptr) = __dcptr2__;				  \
} while (0)
#else
#define DEC_CHARPTR(ptr) REAL_DEC_CHARPTR (ptr)
#endif

#ifdef MULE

#define VALIDATE_CHARPTR_BACKWARD(ptr) do	\
{						\
  while (!VALID_CHARPTR_P (ptr)) ptr--;		\
} while (0)

/* This needs to be trickier to avoid the possibility of running off
   the end of the string. */

#define VALIDATE_CHARPTR_FORWARD(ptr) do	\
{						\
  Bufbyte *__vcfptr__ = (ptr);			\
  VALIDATE_CHARPTR_BACKWARD (__vcfptr__);	\
  if (__vcfptr__ != (ptr))			\
    {						\
      (ptr) = __vcfptr__;			\
      INC_CHARPTR (ptr);			\
    }						\
} while (0)

#else /* not MULE */
#define VALIDATE_CHARPTR_BACKWARD(ptr)
#define VALIDATE_CHARPTR_FORWARD(ptr)
#endif /* not MULE */

/* -------------------------------------------------------------- */
/* (B) For working with the length (in bytes and characters) of a */
/*     section of internally-formatted text 			  */
/* -------------------------------------------------------------- */

INLINE CONST Bufbyte *charptr_n_addr (CONST Bufbyte *ptr, Charcount offset);
INLINE CONST Bufbyte *
charptr_n_addr (CONST Bufbyte *ptr, Charcount offset)
{
  return ptr + charcount_to_bytecount (ptr, offset);
}

INLINE Charcount charptr_length (CONST Bufbyte *ptr);
INLINE Charcount
charptr_length (CONST Bufbyte *ptr)
{
  return bytecount_to_charcount (ptr, strlen ((CONST char *) ptr));
}


/* -------------------------------------------------------------------- */
/* (C) For retrieving or changing the character pointed to by a charptr */
/* -------------------------------------------------------------------- */

#define simple_charptr_emchar(ptr)		((Emchar) (ptr)[0])
#define simple_set_charptr_emchar(ptr, x)	((ptr)[0] = (Bufbyte) (x), 1)
#define simple_charptr_copy_char(ptr, ptr2)	((ptr2)[0] = *(ptr), 1)

#ifdef MULE

Emchar non_ascii_charptr_emchar (CONST Bufbyte *ptr);
Bytecount non_ascii_set_charptr_emchar (Bufbyte *ptr, Emchar c);
Bytecount non_ascii_charptr_copy_char (CONST Bufbyte *ptr, Bufbyte *ptr2);

INLINE Emchar charptr_emchar (CONST Bufbyte *ptr);
INLINE Emchar
charptr_emchar (CONST Bufbyte *ptr)
{
  if (BYTE_ASCII_P (*ptr))
    return simple_charptr_emchar (ptr);
  else
    return non_ascii_charptr_emchar (ptr);
}

INLINE Bytecount set_charptr_emchar (Bufbyte *ptr, Emchar x);
INLINE Bytecount
set_charptr_emchar (Bufbyte *ptr, Emchar x)
{
  if (!CHAR_MULTIBYTE_P (x))
    return simple_set_charptr_emchar (ptr, x);
  else
    return non_ascii_set_charptr_emchar (ptr, x);
}

INLINE Bytecount charptr_copy_char (CONST Bufbyte *ptr, Bufbyte *ptr2);
INLINE Bytecount
charptr_copy_char (CONST Bufbyte *ptr, Bufbyte *ptr2)
{
  if (BYTE_ASCII_P (*ptr))
    return simple_charptr_copy_char (ptr, ptr2);
  else
    return non_ascii_charptr_copy_char (ptr, ptr2);
}

#else /* not MULE */

# define charptr_emchar(ptr)		simple_charptr_emchar (ptr)
# define set_charptr_emchar(ptr, x)	simple_set_charptr_emchar (ptr, x)
# define charptr_copy_char(ptr, ptr2)	simple_charptr_copy_char (ptr, ptr2)

#endif /* not MULE */

#define charptr_emchar_n(ptr, offset) \
  charptr_emchar (charptr_n_addr (ptr, offset))


/* ---------------------------- */
/* (D) For working with Emchars */
/* ---------------------------- */

#ifdef MULE

int non_ascii_valid_char_p (Emchar ch);

INLINE int valid_char_p (Emchar ch);
INLINE int
valid_char_p (Emchar ch)
{
  if (ch >= 0 && ch < 0400)
    return 1;
  else
    return non_ascii_valid_char_p (ch);
}

#else /* not MULE */

#define valid_char_p(ch) ((unsigned int) (ch) < 0400)

#endif /* not MULE */

#define CHAR_INTP(x) (INTP (x) && valid_char_p (XINT (x)))

#define CHAR_OR_CHAR_INTP(x) (CHARP (x) || CHAR_INTP (x))

#ifdef ERROR_CHECK_TYPECHECK

INLINE Emchar XCHAR_OR_CHAR_INT (Lisp_Object obj);
INLINE Emchar
XCHAR_OR_CHAR_INT (Lisp_Object obj)
{
  assert (CHAR_OR_CHAR_INTP (obj));
  return XREALINT (obj);
}

#else

#define XCHAR_OR_CHAR_INT(obj) XREALINT (obj)

#endif

#define CHECK_CHAR_COERCE_INT(x)					\
  do { if (CHARP (x))							\
         ;								\
       else if (CHAR_INTP (x))						\
         x = make_char (XINT (x));					\
       else								\
         x = wrong_type_argument (Qcharacterp, x); } while (0)

#ifdef MULE
# define MAX_EMCHAR_LEN 4
#else
# define MAX_EMCHAR_LEN 1
#endif


/*----------------------------------------------------------------------*/
/*          Accessor macros for important positions in a buffer         */
/*----------------------------------------------------------------------*/

/* We put them here because some stuff below wants them before the
   place where we would normally put them. */

/* None of these are lvalues.  Use the settor macros below to change
   the positions. */

/* Beginning of buffer.  */ 
#define BI_BUF_BEG(buf) ((Bytind) 1)
#define BUF_BEG(buf) ((Bufpos) 1)

/* Beginning of accessible range of buffer.  */ 
#define BI_BUF_BEGV(buf) ((buf)->begv + 0)
#define BUF_BEGV(buf) ((buf)->bufbegv + 0)

/* End of accessible range of buffer.  */ 
#define BI_BUF_ZV(buf) ((buf)->zv + 0)
#define BUF_ZV(buf) ((buf)->bufzv + 0)

/* End of buffer.  */ 
#define BI_BUF_Z(buf) ((buf)->text->z + 0)
#define BUF_Z(buf) ((buf)->text->bufz + 0)

/* Point. */
#define BI_BUF_PT(buf) ((buf)->pt + 0)
#define BUF_PT(buf) ((buf)->bufpt + 0)

/*----------------------------------------------------------------------*/
/*              Converting between positions and addresses              */
/*----------------------------------------------------------------------*/

/* Convert the address of a byte in the buffer into a position.  */
INLINE Bytind BI_BUF_PTR_BYTE_POS (struct buffer *buf, Bufbyte *ptr);
INLINE Bytind
BI_BUF_PTR_BYTE_POS (struct buffer *buf, Bufbyte *ptr)
{
  return ((ptr) - (buf)->text->beg + 1
           - ((ptr - (buf)->text->beg + 1) > (buf)->text->gpt
          ? (buf)->text->gap_size : 0));
}

#define BUF_PTR_BYTE_POS(buf, ptr) \
  bytind_to_bufpos (buf, BI_BUF_PTR_BYTE_POS (buf, ptr))

/* Address of byte at position POS in buffer. */
INLINE Bufbyte * BI_BUF_BYTE_ADDRESS (struct buffer *buf, Bytind pos);
INLINE Bufbyte *
BI_BUF_BYTE_ADDRESS (struct buffer *buf, Bytind pos)
{
  return ((buf)->text->beg +
	  ((pos >= (buf)->text->gpt ? (pos + (buf)->text->gap_size) : pos)
	   - 1));
}

#define BUF_BYTE_ADDRESS(buf, pos) \
  BI_BUF_BYTE_ADDRESS (buf, bufpos_to_bytind (buf, pos))

/* Address of byte before position POS in buffer. */
INLINE Bufbyte * BI_BUF_BYTE_ADDRESS_BEFORE (struct buffer *buf, Bytind pos);
INLINE Bufbyte *
BI_BUF_BYTE_ADDRESS_BEFORE (struct buffer *buf, Bytind pos)
{
  return ((buf)->text->beg +
	  ((pos > (buf)->text->gpt ? (pos + (buf)->text->gap_size) : pos)
	   - 2));
}

#define BUF_BYTE_ADDRESS_BEFORE(buf, pos) \
  BI_BUF_BYTE_ADDRESS_BEFORE (buf, bufpos_to_bytind (buf, pos))

/*----------------------------------------------------------------------*/
/*          Converting between byte indices and memory indices          */
/*----------------------------------------------------------------------*/

INLINE int valid_memind_p (struct buffer *buf, Memind x);
INLINE int
valid_memind_p (struct buffer *buf, Memind x)
{
  if (x >= 1 && x <= (Memind) (buf)->text->gpt)
    return 1;
  if (x > (Memind) ((buf)->text->gpt + (buf)->text->gap_size)
      && x <= (Memind) ((buf)->text->z + (buf)->text->gap_size))
    return 1;
  return 0;
}

INLINE Memind bytind_to_memind (struct buffer *buf, Bytind x);
INLINE Memind
bytind_to_memind (struct buffer *buf, Bytind x)
{
  if (x > (buf)->text->gpt)
    return (Memind) (x + (buf)->text->gap_size);
  else
    return (Memind) (x);
}

#ifdef ERROR_CHECK_BUFPOS

INLINE Bytind memind_to_bytind (struct buffer *buf, Memind x);
INLINE Bytind
memind_to_bytind (struct buffer *buf, Memind x)
{
  assert (valid_memind_p (buf, x));
  if (x > (Memind) (buf)->text->gpt)
    return (Bytind) (x - (buf)->text->gap_size);
  else
    return (Bytind) (x);
}

#else

INLINE Bytind memind_to_bytind (struct buffer *buf, Memind x);
INLINE Bytind
memind_to_bytind (struct buffer *buf, Memind x)
{
  if (x > (Memind) (buf)->text->gpt)
    return (Bytind) (x - (buf)->text->gap_size);
  else
    return (Bytind) (x);
}

#endif

#define memind_to_bufpos(buf, x)					\
  bytind_to_bufpos (buf, memind_to_bytind (buf, x))
#define bufpos_to_memind(buf, x)					\
  bytind_to_memind (buf, bufpos_to_bytind (buf, x))

/* These macros generalize many standard buffer-position functions to
   either a buffer or a string. */

/* Converting between Meminds and Bytinds, for a buffer-or-string.
   For strings, this is a no-op.  For buffers, this resolves
   to the standard memind<->bytind converters. */

#define buffer_or_string_bytind_to_memind(obj, ind) \
  (BUFFERP (obj) ? bytind_to_memind (XBUFFER (obj), ind) : (Memind) ind)

#define buffer_or_string_memind_to_bytind(obj, ind) \
  (BUFFERP (obj) ? memind_to_bytind (XBUFFER (obj), ind) : (Bytind) ind)

/* Converting between Bufpos's and Bytinds, for a buffer-or-string.
   For strings, this maps to the bytecount<->charcount converters. */

#define buffer_or_string_bufpos_to_bytind(obj, pos) 			\
  (BUFFERP (obj) ? bufpos_to_bytind (XBUFFER (obj), pos) :		\
   (Bytind) charcount_to_bytecount (XSTRING_DATA (obj), pos))

#define buffer_or_string_bytind_to_bufpos(obj, ind) 			\
  (BUFFERP (obj) ? bytind_to_bufpos (XBUFFER (obj), ind) :		\
   (Bufpos) bytecount_to_charcount (XSTRING_DATA (obj), ind))

/* Similar for Bufpos's and Meminds. */

#define buffer_or_string_bufpos_to_memind(obj, pos) 			\
  (BUFFERP (obj) ? bufpos_to_memind (XBUFFER (obj), pos) :		\
   (Memind) charcount_to_bytecount (XSTRING_DATA (obj), pos))

#define buffer_or_string_memind_to_bufpos(obj, ind) 			\
  (BUFFERP (obj) ? memind_to_bufpos (XBUFFER (obj), ind) :		\
   (Bufpos) bytecount_to_charcount (XSTRING_DATA (obj), ind))

/************************************************************************/
/*                                                                      */
/*                    working with buffer-level data                    */
/*                                                                      */
/************************************************************************/

/*

   (A) Working with byte indices:
   ------------------------------

   VALID_BYTIND_P(buf, bi):
	Given a byte index, does it point to the beginning of a character?

   ASSERT_VALID_BYTIND_UNSAFE(buf, bi):
	If error-checking is enabled, assert that the given byte index
	is within range and points to the beginning of a character
	or to the end of the buffer.  Otherwise, do nothing.

   ASSERT_VALID_BYTIND_BACKWARD_UNSAFE(buf, bi):
	If error-checking is enabled, assert that the given byte index
	is within range and satisfies ASSERT_VALID_BYTIND() and also
        does not refer to the beginning of the buffer. (i.e. movement
	backwards is OK.) Otherwise, do nothing.

   ASSERT_VALID_BYTIND_FORWARD_UNSAFE(buf, bi):
	If error-checking is enabled, assert that the given byte index
	is within range and satisfies ASSERT_VALID_BYTIND() and also
        does not refer to the end of the buffer. (i.e. movement
	forwards is OK.) Otherwise, do nothing.

   VALIDATE_BYTIND_BACKWARD(buf, bi):
	Make sure that the given byte index is pointing to the beginning
	of a character.  If not, back up until this is the case.  Note
	that there are not too many places where it is legitimate to do
	this sort of thing.  It's an error if you're passed an "invalid"
	byte index.

   VALIDATE_BYTIND_FORWARD(buf, bi):
	Make sure that the given byte index is pointing to the beginning
	of a character.  If not, move forward until this is the case.
	Note that there are not too many places where it is legitimate
	to do this sort of thing.  It's an error if you're passed an
	"invalid" byte index.

   INC_BYTIND(buf, bi):
	Given a byte index (assumed to point at the beginning of a
	character), modify that value so it points to the beginning
	of the next character.

   DEC_BYTIND(buf, bi):
	Given a byte index (assumed to point at the beginning of a
	character), modify that value so it points to the beginning
	of the previous character.  Unlike for DEC_CHARPTR(), we can
	do all the assert()s because there are sentinels at the
	beginning of the gap and the end of the buffer.

   BYTIND_INVALID:
	A constant representing an invalid Bytind.  Valid Bytinds
	can never have this value.


   (B) Converting between Bufpos's and Bytinds:
   --------------------------------------------

    bufpos_to_bytind(buf, bu):
	Given a Bufpos, return the equivalent Bytind.

    bytind_to_bufpos(buf, bi):
	Given a Bytind, return the equivalent Bufpos.

    make_bufpos(buf, bi):
	Given a Bytind, return the equivalent Bufpos as a Lisp Object.
 */


/*----------------------------------------------------------------------*/
/*                       working with byte indices                      */
/*----------------------------------------------------------------------*/

#ifdef MULE
# define VALID_BYTIND_P(buf, x) \
  BUFBYTE_FIRST_BYTE_P (*BI_BUF_BYTE_ADDRESS (buf, x))
#else
# define VALID_BYTIND_P(buf, x) 1
#endif

#ifdef ERROR_CHECK_BUFPOS

# define ASSERT_VALID_BYTIND_UNSAFE(buf, x) do			\
{								\
  assert (BUFFER_LIVE_P (buf));					\
  assert ((x) >= BI_BUF_BEG (buf) && x <= BI_BUF_Z (buf));	\
  assert (VALID_BYTIND_P (buf, x));				\
} while (0)
# define ASSERT_VALID_BYTIND_BACKWARD_UNSAFE(buf, x) do		\
{								\
  assert (BUFFER_LIVE_P (buf));					\
  assert ((x) > BI_BUF_BEG (buf) && x <= BI_BUF_Z (buf));	\
  assert (VALID_BYTIND_P (buf, x));				\
} while (0)
# define ASSERT_VALID_BYTIND_FORWARD_UNSAFE(buf, x) do		\
{								\
  assert (BUFFER_LIVE_P (buf));					\
  assert ((x) >= BI_BUF_BEG (buf) && x < BI_BUF_Z (buf));	\
  assert (VALID_BYTIND_P (buf, x));				\
} while (0)

#else /* not ERROR_CHECK_BUFPOS */
# define ASSERT_VALID_BYTIND_UNSAFE(buf, x)
# define ASSERT_VALID_BYTIND_BACKWARD_UNSAFE(buf, x)
# define ASSERT_VALID_BYTIND_FORWARD_UNSAFE(buf, x)

#endif /* not ERROR_CHECK_BUFPOS */

/* Note that, although the Mule version will work fine for non-Mule
   as well (it should reduce down to nothing), we provide a separate
   version to avoid compilation warnings and possible non-optimal
   results with stupid compilers. */

#ifdef MULE
# define VALIDATE_BYTIND_BACKWARD(buf, x) do		\
{							\
  Bufbyte *__ibptr = BI_BUF_BYTE_ADDRESS (buf, x);	\
  while (!BUFBYTE_FIRST_BYTE_P (*__ibptr))		\
    __ibptr--, (x)--;					\
} while (0)
#else
# define VALIDATE_BYTIND_BACKWARD(buf, x)
#endif

/* Note that, although the Mule version will work fine for non-Mule
   as well (it should reduce down to nothing), we provide a separate
   version to avoid compilation warnings and possible non-optimal
   results with stupid compilers. */

#ifdef MULE
# define VALIDATE_BYTIND_FORWARD(buf, x) do		\
{							\
  Bufbyte *__ibptr = BI_BUF_BYTE_ADDRESS (buf, x);	\
  while (!BUFBYTE_FIRST_BYTE_P (*__ibptr))		\
    __ibptr++, (x)++;					\
} while (0)
#else
# define VALIDATE_BYTIND_FORWARD(buf, x)
#endif

/* Note that in the simplest case (no MULE, no ERROR_CHECK_BUFPOS),
   this crap reduces down to simply (x)++. */

#define INC_BYTIND(buf, x) do				\
{							\
  ASSERT_VALID_BYTIND_FORWARD_UNSAFE (buf, x);		\
  /* Note that we do the increment first to		\
     make sure that the pointer in			\
     VALIDATE_BYTIND_FORWARD() ends up on		\
     the correct side of the gap */			\
  (x)++;						\
  VALIDATE_BYTIND_FORWARD (buf, x);			\
} while (0)

/* Note that in the simplest case (no MULE, no ERROR_CHECK_BUFPOS),
   this crap reduces down to simply (x)--. */

#define DEC_BYTIND(buf, x) do				\
{							\
  ASSERT_VALID_BYTIND_BACKWARD_UNSAFE (buf, x);		\
  /* Note that we do the decrement first to		\
     make sure that the pointer in			\
     VALIDATE_BYTIND_BACKWARD() ends up on		\
     the correct side of the gap */			\
  (x)--;						\
  VALIDATE_BYTIND_BACKWARD (buf, x);			\
} while (0)

INLINE Bytind prev_bytind (struct buffer *buf, Bytind x);
INLINE Bytind
prev_bytind (struct buffer *buf, Bytind x)
{
  DEC_BYTIND (buf, x);
  return x;
}

INLINE Bytind next_bytind (struct buffer *buf, Bytind x);
INLINE Bytind
next_bytind (struct buffer *buf, Bytind x)
{
  INC_BYTIND (buf, x);
  return x;
}

#define BYTIND_INVALID ((Bytind) -1)

/*----------------------------------------------------------------------*/
/*         Converting between buffer positions and byte indices         */
/*----------------------------------------------------------------------*/

#ifdef MULE

Bytind bufpos_to_bytind_func (struct buffer *buf, Bufpos x);
Bufpos bytind_to_bufpos_func (struct buffer *buf, Bytind x);

/* The basic algorithm we use is to keep track of a known region of
   characters in each buffer, all of which are of the same width.  We
   keep track of the boundaries of the region in both Bufpos and
   Bytind coordinates and also keep track of the char width, which
   is 1 - 4 bytes.  If the position we're translating is not in
   the known region, then we invoke a function to update the known
   region to surround the position in question.  This assumes
   locality of reference, which is usually the case.

   Note that the function to update the known region can be simple
   or complicated depending on how much information we cache.
   For the moment, we don't cache any information, and just move
   linearly forward or back from the known region, with a few
   shortcuts to catch all-ASCII buffers. (Note that this will
   thrash with bad locality of reference.) A smarter method would
   be to keep some sort of pseudo-extent layer over the buffer;
   maybe keep track of the bufpos/bytind correspondence at the
   beginning of each line, which would allow us to do a binary
   search over the pseudo-extents to narrow things down to the
   correct line, at which point you could use a linear movement
   method.  This would also mesh well with efficiently
   implementing a line-numbering scheme.

   Note also that we have to multiply or divide by the char width
   in order to convert the positions.  We do some tricks to avoid
   ever actually having to do a multiply or divide, because that
   is typically an expensive operation (esp. divide).  Multiplying
   or dividing by 1, 2, or 4 can be implemented simply as a
   shift left or shift right, and we keep track of a shifter value
   (0, 1, or 2) indicating how much to shift.  Multiplying by 3
   can be implemented by doubling and then adding the original
   value.  Dividing by 3, alas, cannot be implemented in any
   simple shift/subtract method, as far as I know; so we just
   do a table lookup.  For simplicity, we use a table of size
   128K, which indexes the "divide-by-3" values for the first
   64K non-negative numbers. (Note that we can increase the
   size up to 384K, i.e. indexing the first 192K non-negative
   numbers, while still using shorts in the array.) This also
   means that the size of the known region can be at most
   64K for width-three characters.
   */
   
extern short three_to_one_table[];

INLINE int real_bufpos_to_bytind (struct buffer *buf, Bufpos x);
INLINE int
real_bufpos_to_bytind (struct buffer *buf, Bufpos x)
{
  if (x >= buf->text->mule_bufmin && x <= buf->text->mule_bufmax)
    return (buf->text->mule_bytmin +
	    ((x - buf->text->mule_bufmin) << buf->text->mule_shifter) +
	    (buf->text->mule_three_p ? (x - buf->text->mule_bufmin) : 0));
  else
    return bufpos_to_bytind_func (buf, x);
}

INLINE int real_bytind_to_bufpos (struct buffer *buf, Bytind x);
INLINE int
real_bytind_to_bufpos (struct buffer *buf, Bytind x)
{
  if (x >= buf->text->mule_bytmin && x <= buf->text->mule_bytmax)
    return (buf->text->mule_bufmin +
	    ((buf->text->mule_three_p
	      ? three_to_one_table[x - buf->text->mule_bytmin]
	      : (x - buf->text->mule_bytmin) >> buf->text->mule_shifter)));
  else
    return bytind_to_bufpos_func (buf, x);
}

#else /* not MULE */

# define real_bufpos_to_bytind(buf, x)	((Bytind) x)
# define real_bytind_to_bufpos(buf, x)	((Bufpos) x)

#endif /* not MULE */

#ifdef ERROR_CHECK_BUFPOS

Bytind bufpos_to_bytind (struct buffer *buf, Bufpos x);
Bufpos bytind_to_bufpos (struct buffer *buf, Bytind x);

#else /* not ERROR_CHECK_BUFPOS */

#define bufpos_to_bytind real_bufpos_to_bytind
#define bytind_to_bufpos real_bytind_to_bufpos

#endif /* not ERROR_CHECK_BUFPOS */

#define make_bufpos(buf, ind) make_int (bytind_to_bufpos (buf, ind))

/*----------------------------------------------------------------------*/
/*         Converting between buffer bytes and Emacs characters         */
/*----------------------------------------------------------------------*/

/* The character at position POS in buffer. */
#define BI_BUF_FETCH_CHAR(buf, pos) \
  charptr_emchar (BI_BUF_BYTE_ADDRESS (buf, pos))
#define BUF_FETCH_CHAR(buf, pos) \
  BI_BUF_FETCH_CHAR (buf, bufpos_to_bytind (buf, pos))

/* The character at position POS in buffer, as a string.  This is
   equivalent to set_charptr_emchar (str, BUF_FETCH_CHAR (buf, pos))
   but is faster for Mule. */

# define BI_BUF_CHARPTR_COPY_CHAR(buf, pos, str) \
  charptr_copy_char (BI_BUF_BYTE_ADDRESS (buf, pos), str)
#define BUF_CHARPTR_COPY_CHAR(buf, pos, str) \
  BI_BUF_CHARPTR_COPY_CHAR (buf, bufpos_to_bytind (buf, pos), str)






/************************************************************************/
/*                                                                      */
/*                  working with externally-formatted data              */
/*                                                                      */
/************************************************************************/

/* Sometimes strings need to be converted into one or another
   external format, for passing to a library function. (Note
   that we encapsulate and automatically convert the arguments
   of some functions, but not others.) At times this conversion
   also has to go the other way -- i.e. when we get external-
   format strings back from a library function.
*/

#ifdef MULE

/* WARNING: These use a static buffer.  This can lead to disaster if
   these functions are not used *very* carefully.  Under normal
   circumstances, do not call these functions; call the front ends
   below. */

CONST Extbyte *convert_to_external_format (CONST Bufbyte *ptr,
					   Bytecount len,
					   Extcount *len_out,
					   enum external_data_format fmt);
CONST Bufbyte *convert_from_external_format (CONST Extbyte *ptr,
					     Extcount len,
					     Bytecount *len_out,
					     enum external_data_format fmt);

#else /* ! MULE */

#define convert_to_external_format(ptr, len, len_out, fmt) \
     (*(len_out) = (int) (len), (CONST Extbyte *) (ptr))
#define convert_from_external_format(ptr, len, len_out, fmt) \
     (*(len_out) = (Bytecount) (len), (CONST Bufbyte *) (ptr))

#endif /* ! MULE */

/* In all of the following macros we use the following general principles:

   -- Functions that work with charptr's accept two sorts of charptr's:

      a) Pointers to memory with a length specified.  The pointer will be
         fundamentally of type `unsigned char *' (although labelled
	 as `Bufbyte *' for internal-format data and `Extbyte *' for
	 external-format data) and the length will be fundamentally of
	 type `int' (although labelled as `Bytecount' for internal-format
	 data and `Extcount' for external-format data).  The length is
	 always a count in bytes.
      b) Zero-terminated pointers; no length specified.  The pointer
         is of type `char *', whether the data pointed to is internal-format
	 or external-format.  These sorts of pointers are available for
	 convenience in working with C library functions and literal
	 strings.  In general you should use these sorts of pointers only
	 to interface to library routines and not for general manipulation,
	 as you are liable to lose embedded nulls and such.  This could
	 be a big problem for routines that want Unicode-formatted data,
	 which is likely to have lots of embedded nulls in it.

   -- Functions that work with Lisp strings accept strings as Lisp Objects
      (as opposed to the `struct Lisp_String *' for some of the other
      string accessors).  This is for convenience in working with the
      functions, as otherwise you will almost always have to call
      XSTRING() on the object.

   -- Functions that work with charptr's are not guaranteed to copy
      their data into alloca()ed space.  Functions that work with
      Lisp strings are, however.  The reason is that Lisp strings can
      be relocated any time a GC happens, and it could happen at some
      rather unexpected times.  The internal-external conversion is
      rarely done in time-critical functions, and so the slight
      extra time required for alloca() and copy is well-worth the
      safety of knowing your string data won't be relocated out from
      under you.
      */
   
     
/* Maybe convert charptr's data into ext-format and store the result in
   alloca()'ed space.
   
   You may wonder why this is written in this fashion and not as a
   function call.  With a little trickery it could certainly be
   written this way, but it won't work because of those DAMN GCC WANKERS
   who couldn't be bothered to handle alloca() properly on the x86
   architecture. (If you put a call to alloca() in the argument to
   a function call, the stack space gets allocated right in the
   middle of the arguments to the function call and you are unbelievably
   hosed.) */
     
#ifdef MULE

#define GET_CHARPTR_EXT_DATA_ALLOCA(ptr, len, fmt, stick_value_here, stick_len_here) \
do									\
{									\
  Bytecount __gceda_len_in__ = (len);					\
  Extcount  __gceda_len_out__;						\
  CONST Bufbyte *__gceda_ptr_in__ = (ptr);				\
  CONST Extbyte *__gceda_ptr_out__;					\
									\
  __gceda_ptr_out__ =							\
     convert_to_external_format (__gceda_ptr_in__, __gceda_len_in__,	\
				&__gceda_len_out__, fmt);		\
  /* If the new string is identical to the old (will be the case most	\
     of the time), just return the same string back.  This saves	\
     on alloca()ing, which can be useful on C alloca() machines and	\
     on stack-space-challenged environments. */				\
     									\
  if (__gceda_len_in__ == __gceda_len_out__ &&				\
      !memcmp (__gceda_ptr_in__, __gceda_ptr_out__, __gceda_len_out__))	\
    {									\
      (stick_value_here) = (CONST Extbyte *) __gceda_ptr_in__;		\
      (stick_len_here) = (Extcount) __gceda_len_in__;			\
    }									\
  else									\
    {									\
      (stick_value_here) = (CONST Extbyte *) alloca(1 + __gceda_len_out__);\
      memcpy ((Extbyte *) stick_value_here, __gceda_ptr_out__,		\
	      1 + __gceda_len_out__);					\
      (stick_len_here) = (Extcount) __gceda_len_out__;			\
    }									\
} while (0)

#else /* ! MULE */

#define GET_CHARPTR_EXT_DATA_ALLOCA(ptr, len, fmt, stick_value_here, stick_len_here)\
do								\
{								\
  (stick_value_here) = (CONST Extbyte *) (ptr);			\
  (stick_len_here) = (Extcount) (len);				\
} while (0)

#endif /* ! MULE */

#define GET_C_CHARPTR_EXT_DATA_ALLOCA(ptr, fmt, stick_value_here)	\
do									\
{									\
  Extcount __gcceda_ignored_len__;					\
  CONST char *__gcceda_ptr_in__;					\
  CONST Extbyte *__gcceda_ptr_out__;					\
									\
  __gcceda_ptr_in__ = ptr;						\
  GET_CHARPTR_EXT_DATA_ALLOCA ((CONST Extbyte *) __gcceda_ptr_in__,	\
			       strlen (__gcceda_ptr_in__), fmt,		\
			       __gcceda_ptr_out__,			\
				__gcceda_ignored_len__);		\
  (stick_value_here) = (CONST char *) __gcceda_ptr_out__;		\
} while (0)

#define GET_C_CHARPTR_EXT_BINARY_DATA_ALLOCA(ptr, stick_value_here) \
  GET_C_CHARPTR_EXT_DATA_ALLOCA (ptr, FORMAT_BINARY, stick_value_here)
#define GET_CHARPTR_EXT_BINARY_DATA_ALLOCA(ptr, len, stick_value_here, stick_len_here) \
  GET_CHARPTR_EXT_DATA_ALLOCA (ptr, len, FORMAT_BINARY, stick_value_here, \
			       stick_len_here)

#define GET_C_CHARPTR_EXT_FILENAME_DATA_ALLOCA(ptr, stick_value_here) \
  GET_C_CHARPTR_EXT_DATA_ALLOCA (ptr, FORMAT_FILENAME, stick_value_here)
#define GET_CHARPTR_EXT_FILENAME_DATA_ALLOCA(ptr, len, stick_value_here, stick_len_here) \
  GET_CHARPTR_EXT_DATA_ALLOCA (ptr, len, FORMAT_FILENAME, stick_value_here, \
			       stick_len_here)

#define GET_C_CHARPTR_EXT_CTEXT_DATA_ALLOCA(ptr, stick_value_here) \
  GET_C_CHARPTR_EXT_DATA_ALLOCA (ptr, FORMAT_CTEXT, stick_value_here)
#define GET_CHARPTR_EXT_CTEXT_DATA_ALLOCA(ptr, len, stick_value_here, stick_len_here) \
  GET_CHARPTR_EXT_DATA_ALLOCA (ptr, len, FORMAT_CTEXT, stick_value_here, \
			       stick_len_here)

/* Maybe convert external charptr's data into internal format and store
   the result in alloca()'ed space.
   
   You may wonder why this is written in this fashion and not as a
   function call.  With a little trickery it could certainly be
   written this way, but it won't work because of those DAMN GCC WANKERS
   who couldn't be bothered to handle alloca() properly on the x86
   architecture. (If you put a call to alloca() in the argument to
   a function call, the stack space gets allocated right in the
   middle of the arguments to the function call and you are unbelievably
   hosed.) */
     
#ifdef MULE

#define GET_CHARPTR_INT_DATA_ALLOCA(ptr, len, fmt, stick_value_here, stick_len_here)\
do									\
{									\
  Extcount __gcida_len_in__ = (len);					\
  Bytecount __gcida_len_out__;						\
  CONST Extbyte *__gcida_ptr_in__ = (ptr);				\
  CONST Bufbyte *__gcida_ptr_out__;					\
									\
  __gcida_ptr_out__ =							\
     convert_from_external_format (__gcida_ptr_in__, __gcida_len_in__,	\
				  &__gcida_len_out__, fmt);		\
  /* If the new string is identical to the old (will be the case most	\
     of the time), just return the same string back.  This saves	\
     on alloca()ing, which can be useful on C alloca() machines and	\
     on stack-space-challenged environments. */				\
     									\
  if (__gcida_len_in__ == __gcida_len_out__ &&				\
      !memcmp (__gcida_ptr_in__, __gcida_ptr_out__, __gcida_len_out__))	\
    {									\
      (stick_value_here) = (CONST Bufbyte *) __gcida_ptr_in__;		\
      (stick_len_here) = (Bytecount) __gcida_len_in__;			\
    }									\
  else									\
    {									\
      (stick_value_here) = (CONST Extbyte *) alloca (1 + __gcida_len_out__);		\
      memcpy ((Bufbyte *) stick_value_here, __gcida_ptr_out__,		\
	      1 + __gcida_len_out__); 					\
      (stick_len_here) = __gcida_len_out__;				\
    }									\
} while (0)

#else /* ! MULE */

#define GET_CHARPTR_INT_DATA_ALLOCA(ptr, len, fmt, stick_value_here, stick_len_here)\
do						\
{						\
  (stick_value_here) = (CONST Bufbyte *) (ptr);	\
  (stick_len_here) = (Bytecount) (len);		\
} while (0)

#endif /* ! MULE */

#define GET_C_CHARPTR_INT_DATA_ALLOCA(ptr, fmt, stick_value_here)	\
do									\
{									\
  Bytecount __gccida_ignored_len__;					\
  CONST char *__gccida_ptr_in__;					\
  CONST Bufbyte *__gccida_ptr_out__;					\
									\
  __gccida_ptr_in__ = ptr;						\
  GET_CHARPTR_INT_DATA_ALLOCA ((CONST Extbyte *) __gccida_ptr_in__,	\
			       strlen (__gccida_ptr_in__), fmt,		\
			       __gccida_ptr_out__,			\
				__gccida_ignored_len__);		\
  (stick_value_here) = (CONST char *) __gccida_ptr_out__;		\
} while (0)

#define GET_C_CHARPTR_INT_BINARY_DATA_ALLOCA(ptr, stick_value_here) \
  GET_C_CHARPTR_INT_DATA_ALLOCA (ptr, FORMAT_BINARY, stick_value_here)
#define GET_CHARPTR_INT_BINARY_DATA_ALLOCA(ptr, len, stick_value_here, stick_len_here) \
  GET_CHARPTR_INT_DATA_ALLOCA (ptr, len, FORMAT_BINARY, stick_value_here, \
			       stick_len_here)

#define GET_C_CHARPTR_INT_FILENAME_DATA_ALLOCA(ptr, stick_value_here) \
  GET_C_CHARPTR_INT_DATA_ALLOCA (ptr, FORMAT_FILENAME, stick_value_here)
#define GET_CHARPTR_INT_FILENAME_DATA_ALLOCA(ptr, len, stick_value_here, stick_len_here) \
  GET_CHARPTR_INT_DATA_ALLOCA (ptr, len, FORMAT_FILENAME, stick_value_here, \
			       stick_len_here)

#define GET_C_CHARPTR_INT_CTEXT_DATA_ALLOCA(ptr, stick_value_here) \
  GET_C_CHARPTR_INT_DATA_ALLOCA (ptr, FORMAT_CTEXT, stick_value_here)
#define GET_CHARPTR_INT_CTEXT_DATA_ALLOCA(ptr, len, stick_value_here, stick_len_here) \
  GET_CHARPTR_INT_DATA_ALLOCA (ptr, len, FORMAT_CTEXT, stick_value_here, \
			       stick_len_here)


/* Maybe convert Lisp string's data into ext-format and store the result in
   alloca()'ed space.

   You may wonder why this is written in this fashion and not as a
   function call.  With a little trickery it could certainly be
   written this way, but it won't work because of those DAMN GCC WANKERS
   who couldn't be bothered to handle alloca() properly on the x86
   architecture. (If you put a call to alloca() in the argument to
   a function call, the stack space gets allocated right in the
   middle of the arguments to the function call and you are unbelievably
   hosed.) */

#define GET_STRING_EXT_DATA_ALLOCA(s, fmt, stick_value_here, stick_len_here)\
do									   \
{									   \
  Extcount __gseda_len__;						   \
  CONST Extbyte *__gseda_ptr__;						   \
  struct Lisp_String *__gseda_s__ = XSTRING (s);			   \
									   \
  __gseda_ptr__ = convert_to_external_format (string_data (__gseda_s__),   \
					      string_length (__gseda_s__), \
					      &__gseda_len__, fmt);	   \
  (stick_value_here) = (CONST Extbyte *) alloca (1 + __gseda_len__);	   \
  memcpy ((Extbyte *) stick_value_here, __gseda_ptr__, 1 + __gseda_len__); \
  (stick_len_here) = __gseda_len__;					   \
} while (0)


#define GET_C_STRING_EXT_DATA_ALLOCA(s, fmt, stick_value_here)	\
do								\
{								\
  Extcount __gcseda_ignored_len__;				\
  CONST Extbyte *__gcseda_ptr__;				\
								\
  GET_STRING_EXT_DATA_ALLOCA (s, fmt, __gcseda_ptr__,		\
			      __gcseda_ignored_len__);		\
  (stick_value_here) = (CONST char *) __gcseda_ptr__;		\
} while (0)

#define GET_STRING_BINARY_DATA_ALLOCA(s, stick_value_here, stick_len_here) \
  GET_STRING_EXT_DATA_ALLOCA (s, FORMAT_BINARY, stick_value_here,	   \
			      stick_len_here)
#define GET_C_STRING_BINARY_DATA_ALLOCA(s, stick_value_here) \
  GET_C_STRING_EXT_DATA_ALLOCA (s, FORMAT_BINARY, stick_value_here)

#define GET_STRING_FILENAME_DATA_ALLOCA(s, stick_value_here, stick_len_here) \
  GET_STRING_EXT_DATA_ALLOCA (s, FORMAT_FILENAME, stick_value_here,	     \
			      stick_len_here)
#define GET_C_STRING_FILENAME_DATA_ALLOCA(s, stick_value_here) \
  GET_C_STRING_EXT_DATA_ALLOCA (s, FORMAT_FILENAME, stick_value_here)

#define GET_STRING_OS_DATA_ALLOCA(s, stick_value_here, stick_len_here) \
  GET_STRING_EXT_DATA_ALLOCA (s, FORMAT_OS, stick_value_here,	       \
			      stick_len_here)
#define GET_C_STRING_OS_DATA_ALLOCA(s, stick_value_here) \
  GET_C_STRING_EXT_DATA_ALLOCA (s, FORMAT_OS, stick_value_here)

#define GET_STRING_CTEXT_DATA_ALLOCA(s, stick_value_here, stick_len_here) \
  GET_STRING_EXT_DATA_ALLOCA (s, FORMAT_CTEXT, stick_value_here,	  \
			      stick_len_here)
#define GET_C_STRING_CTEXT_DATA_ALLOCA(s, stick_value_here) \
  GET_C_STRING_EXT_DATA_ALLOCA (s, FORMAT_CTEXT, stick_value_here)



/************************************************************************/
/*                                                                      */
/*                          fake charset functions                      */
/*                                                                      */
/************************************************************************/

/* used when MULE is not defined, so that Charset-type stuff can still
   be done */

#ifndef MULE

#define Vcharset_ascii Qnil

#define CHAR_CHARSET(ch) Vcharset_ascii
#define CHAR_LEADING_BYTE(ch) LEADING_BYTE_ASCII
#define LEADING_BYTE_ASCII 0x80
#define NUM_LEADING_BYTES 1
#define MIN_LEADING_BYTE 0x80
#define CHARSETP(cs) 1
#define CHARSET_BY_LEADING_BYTE(lb) Vcharset_ascii
#define XCHARSET_LEADING_BYTE(cs) LEADING_BYTE_ASCII
#define XCHARSET_GRAPHIC(cs) -1
#define XCHARSET_COLUMNS(cs) 1
#define XCHARSET_DIMENSION(cs) 1
#define REP_BYTES_BY_FIRST_BYTE(fb) 1
#define BREAKUP_CHAR(ch, charset, byte1, byte2)\
do						\
{						\
  (charset) = Vcharset_ascii;			\
  (byte1) = (ch);				\
  (byte2) = 0;					\
} while (0)
#define BYTE_ASCII_P(byte) 1

#endif /* ! MULE */

/************************************************************************/
/*                                                                      */
/*                  higher-level buffer-position functions              */
/*                                                                      */
/************************************************************************/

/*----------------------------------------------------------------------*/
/*           Settor macros for important positions in a buffer          */
/*----------------------------------------------------------------------*/

/* Set beginning of accessible range of buffer.  */ 
#define SET_BOTH_BUF_BEGV(buf, val, bival)	\
do						\
{						\
  (buf)->begv = (bival);			\
  (buf)->bufbegv = (val);			\
} while (0)

/* Set end of accessible range of buffer.  */ 
#define SET_BOTH_BUF_ZV(buf, val, bival)	\
do						\
{						\
  (buf)->zv = (bival);				\
  (buf)->bufzv = (val);				\
} while (0)

/* Set point. */
/* Since BEGV and ZV are almost never set, it's reasonable to enforce
   the restriction that the Bufpos and Bytind values must both be
   specified.  However, point is set in lots and lots of places.  So
   we provide the ability to specify both (for efficiency) or just
   one. */
#define BOTH_BUF_SET_PT(buf, val, bival) set_buffer_point (buf, val, bival)
#define BI_BUF_SET_PT(buf, bival) \
  BOTH_BUF_SET_PT (buf, bytind_to_bufpos (buf, bival), bival)
#define BUF_SET_PT(buf, value) \
  BOTH_BUF_SET_PT (buf, value, bufpos_to_bytind (buf, value))


#if 0 /* FSFmacs */
/* These macros exist in FSFmacs because SET_PT() in FSFmacs incorrectly
   does too much stuff, such as moving out of invisible extents. */
#define TEMP_SET_PT(position) (temp_set_point ((position), current_buffer))
#define SET_BUF_PT(buf, value) ((buf)->pt = (value))
#endif

/*----------------------------------------------------------------------*/
/*                      Miscellaneous buffer values                     */
/*----------------------------------------------------------------------*/

/* Number of characters in buffer */
#define BUF_SIZE(buf) (BUF_Z (buf) - BUF_BEG (buf))

/* Is this buffer narrowed? */
#define BUF_NARROWED(buf) ((BI_BUF_BEGV (buf) != BI_BUF_BEG (buf)) \
			   || (BI_BUF_ZV (buf) != BI_BUF_Z (buf)))

/* Modification count.  */
#define BUF_MODIFF(buf) ((buf)->text->modiff)

/* Saved modification count.  */
#define BUF_SAVE_MODIFF(buf) ((buf)->text->save_modiff)

/* Face changed.  */
#define BUF_FACECHANGE(buf) ((buf)->face_change)

#define POINT_MARKER_P(marker) \
   (XMARKER (marker)->buffer != 0 && \
    EQ ((marker), XMARKER (marker)->buffer->point_marker))

#define BUF_MARKERS(buf) ((buf)->markers)

/* WARNING:

   The new definitions of CEILING_OF() and FLOOR_OF() differ semantically
   from the old ones (in FSF Emacs and XEmacs 19.11 and before).
   Conversion is as follows:

   OLD_BI_CEILING_OF(n) = NEW_BI_CEILING_OF(n) - 1
   OLD_BI_FLOOR_OF(n) = NEW_BI_FLOOR_OF(n + 1)

   The definitions were changed because the new definitions are more
   consistent with the way everything else works in Emacs.
 */

/* Properties of CEILING_OF and FLOOR_OF (also apply to BI_ variants):

   1) FLOOR_OF (CEILING_OF (n)) = n
      CEILING_OF (FLOOR_OF (n)) = n

   2) CEILING_OF (n) = n if and only if n = ZV
      FLOOR_OF (n) = n if and only if n = BEGV

   3) CEILING_OF (CEILING_OF (n)) = ZV
      FLOOR_OF (FLOOR_OF (n)) = BEGV

   4) The bytes in the regions

      [BYTE_ADDRESS (n), BYTE_ADDRESS_BEFORE (CEILING_OF (n))]

      and

      [BYTE_ADDRESS (FLOOR_OF (n)), BYTE_ADDRESS_BEFORE (n)]

      are contiguous.
   */


/*  Return the maximum index in the buffer it is safe to scan forwards
    past N to.  This is used to prevent buffer scans from running into
    the gap (e.g. search.c).  All characters between N and CEILING_OF(N)
    are located contiguous in memory.  Note that the character *at*
    CEILING_OF(N) is not contiguous in memory. */
#define BI_BUF_CEILING_OF(b, n)						\
  ((n) < (b)->text->gpt && (b)->text->gpt < BI_BUF_ZV (b) ?		\
   (b)->text->gpt : BI_BUF_ZV (b))
#define BUF_CEILING_OF(b, n)						\
  bytind_to_bufpos (b, BI_BUF_CEILING_OF (b, bufpos_to_bytind (b, n)))

/*  Return the minimum index in the buffer it is safe to scan backwards
    past N to.  All characters between FLOOR_OF(N) and N are located
    contiguous in memory.  Note that the character *at* N may not be
    contiguous in memory. */
#define BI_BUF_FLOOR_OF(b, n)						\
        (BI_BUF_BEGV (b) < (b)->text->gpt && (b)->text->gpt < (n) ?	\
	 (b)->text->gpt : BI_BUF_BEGV (b))
#define BUF_FLOOR_OF(b, n)						\
  bytind_to_bufpos (b, BI_BUF_FLOOR_OF (b, bufpos_to_bytind (b, n)))

#define BI_BUF_CEILING_OF_IGNORE_ACCESSIBLE(b, n)			\
  ((n) < (b)->text->gpt && (b)->text->gpt < BI_BUF_Z (b) ?		\
   (b)->text->gpt : BI_BUF_Z (b))
#define BUF_CEILING_OF_IGNORE_ACCESSIBLE(b, n) 				\
  bytind_to_bufpos							\
   (b, BI_BUF_CEILING_OF_IGNORE_ACCESSIBLE (b, bufpos_to_bytind (b, n)))

#define BI_BUF_FLOOR_OF_IGNORE_ACCESSIBLE(b, n)				\
        (BI_BUF_BEG (b) < (b)->text->gpt && (b)->text->gpt < (n) ?	\
	 (b)->text->gpt : BI_BUF_BEG (b))
#define BUF_FLOOR_OF_IGNORE_ACCESSIBLE(b, n) 				\
  bytind_to_bufpos							\
   (b, BI_BUF_FLOOR_OF_IGNORE_ACCESSIBLE (b, bufpos_to_bytind (b, n)))




extern struct buffer *current_buffer;

/* This structure holds the default values of the buffer-local variables
   defined with DEFVAR_BUFFER_LOCAL, that have special slots in each buffer.
   The default value occupies the same slot in this structure
   as an individual buffer's value occupies in that buffer.
   Setting the default value also goes through the alist of buffers
   and stores into each buffer that does not say it has a local value.  */

extern Lisp_Object Vbuffer_defaults;

/* This structure marks which slots in a buffer have corresponding
   default values in buffer_defaults.
   Each such slot has a nonzero value in this structure.
   The value has only one nonzero bit.

   When a buffer has its own local value for a slot,
   the bit for that slot (found in the same slot in this structure)
   is turned on in the buffer's local_var_flags slot.

   If a slot in this structure is zero, then even though there may
   be a DEFVAR_BUFFER_LOCAL for the slot, there is no default value for it;
   and the corresponding slot in buffer_defaults is not used.  */

extern struct buffer buffer_local_flags;


/* Allocation of buffer data. */

#ifdef REL_ALLOC

char *r_alloc (char **, unsigned long);
char *r_re_alloc (char **, unsigned long);
void r_alloc_free (void **);

#define BUFFER_ALLOC(data,size) \
  ((Bufbyte *) r_alloc ((char **) &data, (size) * sizeof(Bufbyte)))
#define BUFFER_REALLOC(data,size) \
  ((Bufbyte *) r_re_alloc ((char **) &data, (size) * sizeof(Bufbyte)))
#define BUFFER_FREE(data) r_alloc_free ((void **) &(data))
#define R_ALLOC_DECLARE(var,data) r_alloc_declare (&(var), data)

#else /* !REL_ALLOC */

#define BUFFER_ALLOC(data,size)\
	(data = (Bufbyte *) xmalloc ((size) * sizeof(Bufbyte)))
#define BUFFER_REALLOC(data,size)\
	((Bufbyte *) xrealloc (data, (size) * sizeof(Bufbyte)))
/* Avoid excess parentheses, or syntax errors may rear their heads. */
#define BUFFER_FREE(data) xfree (data)
#define R_ALLOC_DECLARE(var,data)

#endif /* !REL_ALLOC */

extern Lisp_Object Vbuffer_alist;
void set_buffer_internal (struct buffer *b);
struct buffer *decode_buffer (Lisp_Object buffer, int allow_string);

/* from editfns.c */
void widen_buffer (struct buffer *b, int no_clip);
int beginning_of_line_p (struct buffer *b, Bufpos pt);

/* from insdel.c */
void set_buffer_point (struct buffer *buf, Bufpos pos, Bytind bipos);
void find_charsets_in_bufbyte_string (unsigned char *charsets,
				      CONST Bufbyte *str,
				      Bytecount len);
void find_charsets_in_emchar_string (unsigned char *charsets,
				     CONST Emchar *str,
				     Charcount len);
int bufbyte_string_displayed_columns (CONST Bufbyte *str, Bytecount len);
int emchar_string_displayed_columns (CONST Emchar *str, Charcount len);
void convert_bufbyte_string_into_emchar_dynarr (CONST Bufbyte *str,
						Bytecount len,
						emchar_dynarr *dyn);
int convert_bufbyte_string_into_emchar_string (CONST Bufbyte *str,
					       Bytecount len,
					       Emchar *arr);
void convert_emchar_string_into_bufbyte_dynarr (Emchar *arr, int nels,
						bufbyte_dynarr *dyn);
Bufbyte *convert_emchar_string_into_malloced_string (Emchar *arr, int nels,
						    Bytecount *len_out);

/* flags for get_buffer_pos_char(), get_buffer_range_char(), etc. */
/* At most one of GB_COERCE_RANGE and GB_NO_ERROR_IF_BAD should be
   specified.  At most one of GB_NEGATIVE_FROM_END and GB_NO_ERROR_IF_BAD
   should be specified. */

#define GB_ALLOW_PAST_ACCESSIBLE	(1 << 0)
#define GB_ALLOW_NIL			(1 << 1)
#define GB_CHECK_ORDER			(1 << 2)
#define GB_COERCE_RANGE			(1 << 3)
#define GB_NO_ERROR_IF_BAD		(1 << 4)
#define GB_NEGATIVE_FROM_END		(1 << 5)
#define GB_HISTORICAL_STRING_BEHAVIOR	(GB_NEGATIVE_FROM_END | GB_ALLOW_NIL)

Bufpos get_buffer_pos_char (struct buffer *b, Lisp_Object pos,
			    unsigned int flags);
Bytind get_buffer_pos_byte (struct buffer *b, Lisp_Object pos,
			    unsigned int flags);
void get_buffer_range_char (struct buffer *b, Lisp_Object from, Lisp_Object to,
			    Bufpos *from_out, Bufpos *to_out,
			    unsigned int flags);
void get_buffer_range_byte (struct buffer *b, Lisp_Object from, Lisp_Object to,
			    Bytind *from_out, Bytind *to_out,
			    unsigned int flags);
Charcount get_string_pos_char (Lisp_Object string, Lisp_Object pos,
			       unsigned int flags);
Bytecount get_string_pos_byte (Lisp_Object string, Lisp_Object pos,
			       unsigned int flags);
void get_string_range_char (Lisp_Object string, Lisp_Object from,
			    Lisp_Object to, Charcount *from_out,
			    Charcount *to_out, unsigned int flags);
void get_string_range_byte (Lisp_Object string, Lisp_Object from,
			    Lisp_Object to, Bytecount *from_out,
			    Bytecount *to_out, unsigned int flags);
Bufpos get_buffer_or_string_pos_char (Lisp_Object object, Lisp_Object pos,
				      unsigned int flags);
Bytind get_buffer_or_string_pos_byte (Lisp_Object object, Lisp_Object pos,
				      unsigned int flags);
void get_buffer_or_string_range_char (Lisp_Object object, Lisp_Object from,
				      Lisp_Object to, Bufpos *from_out,
				      Bufpos *to_out, unsigned int flags);
void get_buffer_or_string_range_byte (Lisp_Object object, Lisp_Object from,
				      Lisp_Object to, Bytind *from_out,
				      Bytind *to_out, unsigned int flags);
Bufpos buffer_or_string_accessible_begin_char (Lisp_Object object);
Bufpos buffer_or_string_accessible_end_char (Lisp_Object object);
Bytind buffer_or_string_accessible_begin_byte (Lisp_Object object);
Bytind buffer_or_string_accessible_end_byte (Lisp_Object object);
Bufpos buffer_or_string_absolute_begin_char (Lisp_Object object);
Bufpos buffer_or_string_absolute_end_char (Lisp_Object object);
Bytind buffer_or_string_absolute_begin_byte (Lisp_Object object);
Bytind buffer_or_string_absolute_end_byte (Lisp_Object object);
void record_buffer (Lisp_Object buf);
Lisp_Object get_buffer (Lisp_Object name,
			int error_if_deleted_or_does_not_exist);
int map_over_sharing_buffers (struct buffer *buf,
			      int (*mapfun) (struct buffer *buf,
					     void *closure),
			      void *closure);


/************************************************************************/
/*                         Case conversion                              */
/************************************************************************/

/* A "trt" table is a mapping from characters to other characters,
   typically used to convert between uppercase and lowercase.  For
   compatibility reasons, trt tables are currently in the form of
   a Lisp string of 256 characters, specifying the conversion for each
   of the first 256 Emacs characters (i.e. the 256 extended-ASCII
   characters).  This should be generalized at some point to support
   conversions for all of the allowable Mule characters.
   */

/* The _1 macros are named as such because they assume that you have
   already guaranteed that the character values are all in the range
   0 - 255.  Bad lossage will happen otherwise. */

# define MAKE_TRT_TABLE() Fmake_string (make_int (256), make_char (0))
# define TRT_TABLE_AS_STRING(table) XSTRING_DATA (table)
# define TRT_TABLE_CHAR_1(table, ch) \
  string_char (XSTRING (table), (Charcount) ch)
# define SET_TRT_TABLE_CHAR_1(table, ch1, ch2) \
  set_string_char (XSTRING (table), (Charcount) ch1, ch2)

#ifdef MULE
# define MAKE_MIRROR_TRT_TABLE() make_opaque (256, 0)
# define MIRROR_TRT_TABLE_AS_STRING(table) ((Bufbyte *) XOPAQUE_DATA (table))
# define MIRROR_TRT_TABLE_CHAR_1(table, ch) \
  ((Emchar) (MIRROR_TRT_TABLE_AS_STRING (table)[ch]))
# define SET_MIRROR_TRT_TABLE_CHAR_1(table, ch1, ch2) \
  (MIRROR_TRT_TABLE_AS_STRING (table)[ch1] = (Bufbyte) (ch2))
#endif

# define IN_TRT_TABLE_DOMAIN(c) (((unsigned EMACS_INT) (c)) < 0400)

#ifdef MULE
#define MIRROR_DOWNCASE_TABLE_AS_STRING(buf) \
  MIRROR_TRT_TABLE_AS_STRING (buf->mirror_downcase_table)
#define MIRROR_UPCASE_TABLE_AS_STRING(buf) \
  MIRROR_TRT_TABLE_AS_STRING (buf->mirror_upcase_table)
#define MIRROR_CANON_TABLE_AS_STRING(buf) \
  MIRROR_TRT_TABLE_AS_STRING (buf->mirror_case_canon_table)
#define MIRROR_EQV_TABLE_AS_STRING(buf) \
  MIRROR_TRT_TABLE_AS_STRING (buf->mirror_case_eqv_table)
#else
#define MIRROR_DOWNCASE_TABLE_AS_STRING(buf) \
  TRT_TABLE_AS_STRING (buf->downcase_table)
#define MIRROR_UPCASE_TABLE_AS_STRING(buf) \
  TRT_TABLE_AS_STRING (buf->upcase_table)
#define MIRROR_CANON_TABLE_AS_STRING(buf) \
  TRT_TABLE_AS_STRING (buf->case_canon_table)
#define MIRROR_EQV_TABLE_AS_STRING(buf) \
  TRT_TABLE_AS_STRING (buf->case_eqv_table)
#endif

INLINE Emchar TRT_TABLE_OF (Lisp_Object trt, Emchar c);
INLINE Emchar
TRT_TABLE_OF (Lisp_Object trt, Emchar c)
{
  if (IN_TRT_TABLE_DOMAIN (c))
    return TRT_TABLE_CHAR_1 (trt, c);
  else
    return c;
}

/* Macros used below. */
#define DOWNCASE_TABLE_OF(buf, c) TRT_TABLE_OF (buf->downcase_table, c)
#define UPCASE_TABLE_OF(buf, c) TRT_TABLE_OF (buf->upcase_table, c)

/* 1 if CH is upper case.  */

INLINE int UPPERCASEP (struct buffer *buf, Emchar ch);
INLINE int
UPPERCASEP (struct buffer *buf, Emchar ch)
{
  return (DOWNCASE_TABLE_OF (buf, ch) != ch);
}

/* 1 if CH is lower case.  */

INLINE int LOWERCASEP (struct buffer *buf, Emchar ch);
INLINE int
LOWERCASEP (struct buffer *buf, Emchar ch)
{
  return (UPCASE_TABLE_OF (buf, ch) != ch &&
	  DOWNCASE_TABLE_OF (buf, ch) == ch);
}

/* 1 if CH is neither upper nor lower case.  */

INLINE int NOCASEP (struct buffer *buf, Emchar ch);
INLINE int
NOCASEP (struct buffer *buf, Emchar ch)
{
  return (UPCASE_TABLE_OF (buf, ch) == ch);
}

/* Upcase a character, or make no change if that cannot be done.  */

INLINE Emchar UPCASE (struct buffer *buf, Emchar ch);
INLINE Emchar
UPCASE (struct buffer *buf, Emchar ch)
{
  return (DOWNCASE_TABLE_OF (buf, ch) == ch) ?
    UPCASE_TABLE_OF (buf, ch) : ch;
}

/* Upcase a character known to be not upper case.  */

#define UPCASE1(buf, ch) UPCASE_TABLE_OF (buf, ch)

/* Downcase a character, or make no change if that cannot be done. */

#define DOWNCASE(buf, ch) DOWNCASE_TABLE_OF (buf, ch)


/* put it here, somewhat arbitrarily ...  it needs to be in *some*
   header file. */
DECLARE_LRECORD (range_table, struct Lisp_Range_Table);

#endif /* _XEMACS_BUFFER_H_ */
