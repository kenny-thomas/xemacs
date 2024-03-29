/* Primitives for word-abbrev mode.
   Copyright (C) 1985, 1986, 1992, 1993 Free Software Foundation, Inc.
   Copyright (C) 2002 Ben Wing.

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

/* Synched up with: FSF 19.30.  Note that there are many more functions in
   FSF's abbrev.c.  These have been moved into Lisp in XEmacs. */

/* Authorship:

   FSF: Original version; a long time ago.
   JWZ or Mly: Mostly moved into Lisp; maybe 1992.
   Ben Wing: Some changes for Mule for 19.12.
   Hrvoje Niksic: Largely rewritten in June 1997.
*/

/* This file has been Mule-ized. */

#include <config.h>
#include "lisp.h"

#include "buffer.h"
#include "commands.h"
#include "insdel.h"
#include "syntax.h"
#include "window.h"

/* An abbrev table is an obarray.
   Each defined abbrev is represented by a symbol in that obarray
   whose print name is the abbreviation.
   The symbol's value is a string which is the expansion.
   If its function definition is non-nil, it is called
   after the expansion is done.
   The plist slot of the abbrev symbol is its usage count. */

/* The table of global abbrevs.  These are in effect
   in any buffer in which abbrev mode is turned on. */
Lisp_Object Vglobal_abbrev_table;

int abbrev_all_caps;

/* Non-nil => use this location as the start of abbrev to expand
 (rather than taking the word before point as the abbrev) */
Lisp_Object Vabbrev_start_location;

/* Buffer that Vabbrev_start_location applies to */
Lisp_Object Vabbrev_start_location_buffer;

/* The symbol representing the abbrev most recently expanded */
Lisp_Object Vlast_abbrev;

/* A string for the actual text of the abbrev most recently expanded.
   This has more info than Vlast_abbrev since case is significant.  */
Lisp_Object Vlast_abbrev_text;

/* Character address of start of last abbrev expanded */
Fixnum last_abbrev_location;

/* Hook to run before expanding any abbrev.  */
Lisp_Object Vpre_abbrev_expand_hook, Qpre_abbrev_expand_hook;

Lisp_Object Qsystem_type;

struct abbrev_match_mapper_closure
{
  struct buffer *buf;
  Lisp_Object chartab;
  Charbpos point;
  Charcount maxlen;
  Lisp_Symbol *found;
};

/* For use by abbrev_match(): Match SYMBOL's name against buffer text
   before point, case-insensitively.  When found, return non-zero, so
   that map_obarray terminates mapping.  */
static int
abbrev_match_mapper (Lisp_Object UNUSED (key), Lisp_Object symbol, 
                     void *arg)
{
  struct abbrev_match_mapper_closure *closure =
    (struct abbrev_match_mapper_closure *)arg;
  Charcount abbrev_length;
  Lisp_Symbol *sym = XSYMBOL (symbol);
  Lisp_Object abbrev;

  /* symbol_value should be OK here, because abbrevs are not expected
     to contain any SYMBOL_MAGIC stuff.  */
  if (UNBOUNDP (symbol_value (sym)) || NILP (symbol_value (sym)))
    {
      /* The symbol value of nil means that abbrev got undefined. */
      return 0;
    }
  abbrev = symbol_name (sym);
  abbrev_length = string_char_length (abbrev);
  if (abbrev_length > closure->maxlen)
    {
      /* This abbrev is too large -- it wouldn't fit. */
      return 0;
    }
  /* If `bar' is an abbrev, and a user presses `fubar<SPC>', we don't
     normally want to expand it.  OTOH, if the abbrev begins with
     non-word syntax (e.g. `#if'), it is OK to abbreviate it anywhere.  */
  if (abbrev_length < closure->maxlen && abbrev_length > 0
      && (WORD_SYNTAX_P (closure->chartab, string_ichar (abbrev, 0)))
      && (WORD_SYNTAX_P (closure->chartab,
			 BUF_FETCH_CHAR (closure->buf,
					 closure->point -
					 (abbrev_length + 1)))))
    {
      return 0;
    }
  /* Match abbreviation string against buffer text.  */
  {
    Ibyte *ptr = XSTRING_DATA (abbrev);
    Charcount idx;

    for (idx = 0; idx < abbrev_length; idx++)
      {
	if (CANONCASE (closure->buf,
		      BUF_FETCH_CHAR (closure->buf,
				      closure->point - abbrev_length + idx))
	    != CANONCASE (closure->buf, itext_ichar (ptr)))
	  {
	    break;
	  }
	INC_IBYTEPTR (ptr);
      }
    if (idx == abbrev_length)
      {
	/* This is the one. */
	closure->found = sym;
	return 1;
      }
  }
  return 0;
}

/* Match the buffer text against names of symbols in obarray.  Returns
   the matching symbol, or 0 if not found.  */
static Lisp_Symbol *
abbrev_match (struct buffer *buf, Lisp_Object obarray)
{
  struct abbrev_match_mapper_closure closure;

  /* Precalculate some stuff, so mapper function needn't to it in each
     iteration.  */
  closure.buf = buf;
  closure.point = BUF_PT (buf);
  closure.maxlen = closure.point - BUF_BEGV (buf);
  closure.chartab = buf->mirror_syntax_table;
  closure.found = 0;

  map_obarray (obarray, abbrev_match_mapper, &closure);

  return closure.found;
}

/* Take the word before point (or Vabbrev_start_location, if non-nil),
   and look it up in OBARRAY, and return the symbol (or zero).  This
   used to be the default method of searching, with the obvious
   limitation that the abbrevs may consist only of word characters.
   It is an order of magnitude faster than the proper abbrev_match(),
   but then again, vi is an order of magnitude faster than Emacs.

   This speed difference should be unnoticeable, though.  I have tested
   the degenerated cases of thousands of abbrevs being defined, and
   abbrev_match() was still fast enough for normal operation.  */
static Lisp_Symbol *
abbrev_oblookup (struct buffer *buf, Lisp_Object obarray)
{
  Charbpos wordstart, wordend;
  Ibyte *word, *p;
  Charbpos idx;
  Lisp_Object lookup;

  CHECK_VECTOR (obarray);

  if (!NILP (Vabbrev_start_location))
    {
      wordstart = get_buffer_pos_char (buf, Vabbrev_start_location,
				       GB_COERCE_RANGE);
      Vabbrev_start_location = Qnil;
#if 0
      /* Previously, abbrev-prefix-mark crockishly inserted a dash to
	 indicate the abbrev start point.  It now uses an extent with
	 a begin glyph so there's no dash to remove.  */
      if (wordstart != BUF_ZV (buf)
 	  && BUF_FETCH_CHAR (buf, wordstart) == '-')
	{
	  buffer_delete_range (buf, wordstart, wordstart + 1, 0);
	}
#endif
      wordend = BUF_PT (buf);
    }
  else
    {
      Charbpos point = BUF_PT (buf);

      wordstart = scan_words (buf, point, -1);
      if (!wordstart)
	return 0;

      wordend = scan_words (buf, wordstart, 1);
      if (!wordend)
	return 0;
      if (wordend > BUF_ZV (buf))
	wordend = BUF_ZV (buf);
      if (wordend > point)
	wordend = point;
      /* Unlike the original function, we allow expansion only after
	 the abbrev, not preceded by a number of spaces.  This is
	 because of consistency with abbrev_match. */
      if (wordend < point)
	return 0;
    }

  if (wordend <= wordstart)
    return 0;

  p = word = alloca_ibytes (MAX_ICHAR_LEN * (wordend - wordstart));
  for (idx = wordstart; idx < wordend; idx++)
    {
      Ichar c = BUF_FETCH_CHAR (buf, idx);
      if (UPPERCASEP (buf, c))
	c = DOWNCASE (buf, c);
      p += set_itext_ichar (p, c);
    }
  lookup = oblookup (obarray, word, p - word);
  if (SYMBOLP (lookup) && !NILP (symbol_value (XSYMBOL (lookup))))
    return XSYMBOL (lookup);
  else
    return NULL;
}

/* Return non-zero if OBARRAY contains an interned symbol ` '. */
static int
obarray_has_blank_p (Lisp_Object obarray)
{
  return !ZEROP (oblookup (obarray, (Ibyte *)" ", 1));
}

/* Analyze case in the buffer substring, and report it.  */
static void
abbrev_count_case (struct buffer *buf, Charbpos pos, Charcount length,
		   int *lccount, int *uccount)
{
  *lccount = *uccount = 0;
  while (length--)
    {
      Ichar c = BUF_FETCH_CHAR (buf, pos);
      if (UPPERCASEP (buf, c))
	++*uccount;
      else if (LOWERCASEP (buf, c))
	++*lccount;
      ++pos;
    }
}

DEFUN ("expand-abbrev", Fexpand_abbrev, 0, 0, "", /*
Expand the abbrev before point, if any.
Effective when explicitly called even when `abbrev-mode' is nil.
Returns the abbrev symbol, if expansion took place.
If no abbrev matched, but `pre-abbrev-expand-hook' changed the buffer,
 returns t.
*/
       ())
{
  /* This function can GC */
  struct buffer *buf = current_buffer;
  int oldmodiff = BUF_MODIFF (buf);
  Lisp_Object pre_modiff_p;
  Charbpos point;			/* position of point */
  Charbpos abbrev_start;		/* position of abbreviation beginning */

  Lisp_Symbol *(*fun) (struct buffer *, Lisp_Object);

  Lisp_Symbol *abbrev_symbol;
  Lisp_Object expansion, count, hook;
  Charcount abbrev_length;
  int lccount, uccount;

  run_hook (Qpre_abbrev_expand_hook);
  /* If the hook changes the buffer, treat that as having "done an
     expansion".  */
  pre_modiff_p = (BUF_MODIFF (buf) != oldmodiff ? Qt : Qnil);

  abbrev_symbol = NULL;
  if (!BUFFERP (Vabbrev_start_location_buffer) ||
      XBUFFER (Vabbrev_start_location_buffer) != buf)
    Vabbrev_start_location = Qnil;
  /* We use the more general abbrev_match() if the obarray blank flag
     is not set, and Vabbrev_start_location is nil.  Otherwise, use
     abbrev_oblookup(). */
#define MATCHFUN(tbl) ((obarray_has_blank_p (tbl)		 \
			&& NILP (Vabbrev_start_location))	 \
		       ? abbrev_match : abbrev_oblookup)
  if (!NILP (buf->abbrev_table))
    {
      fun = MATCHFUN (buf->abbrev_table);
      abbrev_symbol = fun (buf, buf->abbrev_table);
    }
  if (!abbrev_symbol && !NILP (Vglobal_abbrev_table))
    {
      fun = MATCHFUN (Vglobal_abbrev_table);
      abbrev_symbol = fun (buf, Vglobal_abbrev_table);
    }
  if (!abbrev_symbol)
    return pre_modiff_p;

  /* NOTE: we hope that `pre-abbrev-expand-hook' didn't do something
     nasty, such as changed the buffer.  Here we protect against the
     buffer getting killed.  */
  if (! BUFFER_LIVE_P (buf))
    return Qnil;
  point = BUF_PT (buf);

  /* OK, we're out of the must-be-fast part.  An abbreviation matched.
     Now find the parameters, insert the expansion, and make it all
     look pretty.  */
  abbrev_length = string_char_length (symbol_name (abbrev_symbol));
  abbrev_start = point - abbrev_length;

  expansion = symbol_value (abbrev_symbol);
  CHECK_STRING (expansion);

  count = symbol_plist (abbrev_symbol); /* Gag */
  if (NILP (count))
    count = Qzero;
  else
    CHECK_NATNUM (count);
  symbol_plist (abbrev_symbol) = Fadd1 (count);

  /* Count the case in the original text. */
  abbrev_count_case (buf, abbrev_start, abbrev_length, &lccount, &uccount);

  /* Remember the last abbrev text, location, etc. */
  Vlast_abbrev = wrap_symbol (abbrev_symbol);
  Vlast_abbrev_text =
    make_string_from_buffer (buf, abbrev_start, abbrev_length);
  last_abbrev_location = abbrev_start;

  /* Add an undo boundary, in case we are doing this for a
     self-inserting command which has avoided making one so far.  */
  if (INTERACTIVE)
    Fundo_boundary ();

  /* Remove the abbrev */
  buffer_delete_range (buf, abbrev_start, point, 0);
  /* And insert the expansion. */
  buffer_insert_lisp_string (buf, expansion);
  point = BUF_PT (buf);

  /* Now fiddle with the case. */
  if (uccount && !lccount)
    {
      /* Abbrev was all caps */
      if (!abbrev_all_caps
	  && scan_words (buf, point, -1) > scan_words (buf, abbrev_start, 1))
	{
	  Fupcase_initials_region (make_fixnum (abbrev_start), make_fixnum (point),
				   wrap_buffer (buf));
	}
      else
	{
	  /* If expansion is one word, or if user says so, upcase it all. */
	  Fupcase_region (make_fixnum (abbrev_start), make_fixnum (point),
			  wrap_buffer (buf));
	}
    }
  else if (uccount)
    {
      /* Abbrev included some caps.  Cap first initial of expansion */
      Charbpos pos = abbrev_start;
      /* Find the initial.  */
      while (pos < point
	     && !WORD_SYNTAX_P (buf->mirror_syntax_table,
				BUF_FETCH_CHAR (buf, pos)))
	pos++;
      /* Change just that.  */
      Fupcase_initials_region (make_fixnum (pos), make_fixnum (pos + 1),
			       wrap_buffer (buf));
    }

  hook = symbol_function (abbrev_symbol);
  if (!NILP (hook) && !UNBOUNDP (hook))
    call0 (hook);

  return Vlast_abbrev;
}

static void
write_abbrev (Lisp_Object sym, Lisp_Object stream)
{
  Lisp_Object name, count, system_flag;
  /* This function can GC */
  struct buffer *buf = current_buffer;

  if (FIXNUMP (XSYMBOL (sym)->plist))
    {
      count = XSYMBOL (sym)->plist;
      system_flag = Qnil;
    }
  else
    {
      count = Fget (sym, Qcount, Qunbound);
      system_flag = Fget (sym, Qsystem_type, Qunbound);
    }

  if (NILP (XSYMBOL_VALUE (sym)) || ! NILP (system_flag))
    return;

  buffer_insert_ascstring (buf, "    (");
  name = Fsymbol_name (sym);
  Fprin1 (name, stream);
  buffer_insert_ascstring (buf, " ");
  Fprin1 (XSYMBOL_VALUE (sym), stream);
  buffer_insert_ascstring (buf, " ");
  Fprin1 (XSYMBOL (sym)->function, stream);
  buffer_insert_ascstring (buf, " ");
  Fprin1 (count, stream);
  buffer_insert_ascstring (buf, ")\n");
}

static void
describe_abbrev (Lisp_Object sym, Lisp_Object stream)
{
  Lisp_Object one, count, system_flag;
  /* This function can GC */
  struct buffer *buf = current_buffer;

  if (FIXNUMP (XSYMBOL (sym)->plist))
    {
      count = XSYMBOL (sym)->plist;
      system_flag = Qnil;
    }
  else
    {
      count = Fget (sym, Qcount, Qunbound);
      system_flag = Fget (sym, Qsystem_type, Qunbound);
    }

  if (NILP (XSYMBOL_VALUE (sym)))
    return;

  one = make_fixnum (1);
  Fprin1 (Fsymbol_name (sym), stream);

  if (!NILP (system_flag))
    {
      buffer_insert_ascstring (buf, " (sys)");
      Findent_to (make_fixnum (20), one, Qnil);
    }
  else
    Findent_to (make_fixnum (15), one, Qnil);

  Fprin1 (count, stream);
  Findent_to (make_fixnum (20), one, Qnil);
  Fprin1 (XSYMBOL_VALUE (sym), stream);
  if (!NILP (XSYMBOL (sym)->function))
    {
      Findent_to (make_fixnum (45), one, Qnil);
      Fprin1 (XSYMBOL (sym)->function, stream);
    }
  buffer_insert_ascstring (buf, "\n");
}

static int
record_symbol (Lisp_Object UNUSED (key), Lisp_Object sym, void *arg)
{
  Lisp_Object closure = * (Lisp_Object *) arg;
  XSETCDR (closure, Fcons (sym, XCDR (closure)));
  return 0; /* Never stop */
}

DEFUN ("insert-abbrev-table-description", Finsert_abbrev_table_description,
       1, 2, 0, /*
Insert before point a full description of abbrev table named NAME.
NAME is a symbol whose value is an abbrev table.
If optional 2nd arg READABLE is non-nil, a human-readable description
is inserted.  Otherwise the description is an expression,
a call to `define-abbrev-table', which would
define the abbrev table NAME exactly as it is currently defined.

Abbrevs marked as "system abbrevs" are normally omitted.  However, if
READABLE is non-nil, they are listed.  */
       (name, readable))
{
  Lisp_Object table;
  Lisp_Object symbols;
  Lisp_Object stream;
  /* This function can GC */
  struct buffer *buf = current_buffer;

  CHECK_SYMBOL (name);
  table = Fsymbol_value (name);
  CHECK_VECTOR (table);

  /* FIXME: what's the XEmacs equivalent? APA */
  /* XSETBUFFER (stream, current_buffer); */
  /* Does not seem to work: */
  /* Fset_buffer (stream); */
  stream = wrap_buffer (current_buffer);

  symbols = Fcons (Qnil, Qnil);
  /* Lisp_Object closure = Fcons (Qnil, Qnil); */
  /* struct gcpro gcpro1; */
  /* GCPRO1 (closure); */
  /* map_obarray (table, record_symbol, symbols); */
  map_obarray (table, record_symbol, &symbols);
  /* map_obarray (table, record_symbol, &closure); */
  symbols = XCDR (symbols);
  symbols = list_sort (symbols, check_string_lessp_nokey, Qnil, Qnil);

  if (!NILP (readable))
    {
      buffer_insert_ascstring (buf, "(");
      Fprin1 (name, stream);
      buffer_insert_ascstring (buf, ")\n\n");
      while (! NILP (symbols))
	{
	  describe_abbrev (XCAR (symbols), stream);
	  symbols = XCDR (symbols);
	}

      buffer_insert_ascstring (buf, "\n\n");
    }
  else
    {
      buffer_insert_ascstring (buf, "(define-abbrev-table '");
      Fprin1 (name, stream);
      buffer_insert_ascstring (buf, " '(\n");
      while (! NILP (symbols))
	{
	  write_abbrev (XCAR (symbols), stream);
	  symbols = XCDR (symbols);
	}
      buffer_insert_ascstring (buf, "    ))\n\n");
    }

  return Qnil;
}

void
syms_of_abbrev (void)
{
  DEFSYMBOL(Qsystem_type);
  Qsystem_type = intern ("system-type");
  DEFSYMBOL (Qpre_abbrev_expand_hook);
  DEFSUBR (Fexpand_abbrev);
  DEFSUBR (Finsert_abbrev_table_description);
}

void
vars_of_abbrev (void)
{
  DEFVAR_LISP ("global-abbrev-table", &Vglobal_abbrev_table /*
The abbrev table whose abbrevs affect all buffers.
Each buffer may also have a local abbrev table.
If it does, the local table overrides the global one
for any particular abbrev defined in both.
*/ );
  Vglobal_abbrev_table = Qnil;  /* setup by Lisp code */

  DEFVAR_LISP ("last-abbrev", &Vlast_abbrev /*
The abbrev-symbol of the last abbrev expanded.
See the function `abbrev-symbol'.
*/ );

  DEFVAR_LISP ("last-abbrev-text", &Vlast_abbrev_text /*
The exact text of the last abbrev expanded.
nil if the abbrev has already been unexpanded.
*/ );

  DEFVAR_INT ("last-abbrev-location", &last_abbrev_location /*
The location of the start of the last abbrev expanded.
*/ );

  Vlast_abbrev = Qnil;
  Vlast_abbrev_text = Qnil;
  last_abbrev_location = 0;

  DEFVAR_LISP ("abbrev-start-location", &Vabbrev_start_location /*
Buffer position for `expand-abbrev' to use as the start of the abbrev.
nil means use the word before point as the abbrev.
Calling `expand-abbrev' sets this to nil.
*/ );
  Vabbrev_start_location = Qnil;

  DEFVAR_LISP ("abbrev-start-location-buffer", &Vabbrev_start_location_buffer /*
Buffer that `abbrev-start-location' has been set for.
Trying to expand an abbrev in any other buffer clears `abbrev-start-location'.
*/ );
  Vabbrev_start_location_buffer = Qnil;

  DEFVAR_BOOL ("abbrev-all-caps", &abbrev_all_caps /*
*Non-nil means expand multi-word abbrevs all caps if abbrev was so.
*/ );
  abbrev_all_caps = 0;

  DEFVAR_LISP ("pre-abbrev-expand-hook", &Vpre_abbrev_expand_hook /*
Function or functions to be called before abbrev expansion is done.
This is the first thing that `expand-abbrev' does, and so this may change
the current abbrev table before abbrev lookup happens.
*/ );
  Vpre_abbrev_expand_hook = Qnil;
}
