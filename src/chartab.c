/* XEmacs routines to deal with char tables.
   Copyright (C) 1992, 1995 Free Software Foundation, Inc.
   Copyright (C) 1995 Sun Microsystems, Inc.
   Copyright (C) 1995, 1996 Ben Wing.

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

/* Synched up with: Mule 2.3.  Not synched with FSF.

   This file was written independently of the FSF implementation,
   and is not compatible. */

/* Authorship:

   Ben Wing: wrote, for 19.13 (Mule).  Some category table stuff
             loosely based on the original Mule.
   Jareth Hein: fixed a couple of bugs in the implementation, and
   	     added regex support for categories with check_category_at
 */

#include <config.h>
#include "lisp.h"

#include "buffer.h"
#include "chartab.h"
#include "commands.h"
#include "syntax.h"

Lisp_Object Qchar_tablep, Qchar_table;

Lisp_Object Vall_syntax_tables;

#ifdef MULE
Lisp_Object Qcategory_table_p;
Lisp_Object Qcategory_designator_p;
Lisp_Object Qcategory_table_value_p;

Lisp_Object Vstandard_category_table;
#endif


/* A char table maps from ranges of characters to values.

   Implementing a general data structure that maps from arbitrary
   ranges of numbers to values is tricky to do efficiently.  As it
   happens, it should suffice fine (and is usually more convenient,
   anyway) when dealing with characters to restrict the sorts of
   ranges that can be assigned values, as follows:

   1) All characters.
   2) All characters in a charset.
   3) All characters in a particular row of a charset, where a "row"
      means all characters with the same first byte.
   4) A particular character in a charset.


   We use char tables to generalize the 256-element vectors now
   littering the Emacs code.

   Possible uses (all should be converted at some point):

   1) category tables
   2) syntax tables
   3) display tables
   4) case tables
   5) keyboard-translate-table?

   We do the very non-Stallman-esque thing of actually providing an
   abstract type to generalize the Emacs vectors and Mule
   vectors-of-vectors goo.
   */

/************************************************************************/
/*                            Char Table object                         */
/************************************************************************/

#ifdef MULE

static Lisp_Object mark_char_table_entry (Lisp_Object, void (*) (Lisp_Object));
static int char_table_entry_equal (Lisp_Object, Lisp_Object, int depth);
static unsigned long char_table_entry_hash (Lisp_Object obj, int depth);
DEFINE_LRECORD_IMPLEMENTATION ("char-table-entry", char_table_entry,
                               mark_char_table_entry, internal_object_printer,
			       0, char_table_entry_equal,
			       char_table_entry_hash,
			       struct Lisp_Char_Table_Entry);

static Lisp_Object
mark_char_table_entry (Lisp_Object obj, void (*markobj) (Lisp_Object))
{
  struct Lisp_Char_Table_Entry *cte = XCHAR_TABLE_ENTRY (obj);
  int i;

  for (i = 0; i < 96; i++)
    {
      (markobj) (cte->level2[i]);
    }
  return Qnil;
}

static int
char_table_entry_equal (Lisp_Object obj1, Lisp_Object obj2, int depth)
{
  struct Lisp_Char_Table_Entry *cte1 = XCHAR_TABLE_ENTRY (obj1);
  struct Lisp_Char_Table_Entry *cte2 = XCHAR_TABLE_ENTRY (obj2);
  int i;

  for (i = 0; i < 96; i++)
    if (!internal_equal (cte1->level2[i], cte2->level2[i], depth + 1))
      return 0;

  return 1;
}

static unsigned long
char_table_entry_hash (Lisp_Object obj, int depth)
{
  struct Lisp_Char_Table_Entry *cte = XCHAR_TABLE_ENTRY (obj);

  return internal_array_hash (cte->level2, 96, depth);
}

#endif /* MULE */

static Lisp_Object mark_char_table (Lisp_Object, void (*) (Lisp_Object));
static void print_char_table (Lisp_Object, Lisp_Object, int);
static int char_table_equal (Lisp_Object, Lisp_Object, int depth);
static unsigned long char_table_hash (Lisp_Object obj, int depth);
DEFINE_LRECORD_IMPLEMENTATION ("char-table", char_table,
                               mark_char_table, print_char_table, 0,
			       char_table_equal, char_table_hash,
			       struct Lisp_Char_Table);

static Lisp_Object
mark_char_table (Lisp_Object obj, void (*markobj) (Lisp_Object))
{
  struct Lisp_Char_Table *ct = XCHAR_TABLE (obj);
  int i;

  for (i = 0; i < NUM_ASCII_CHARS; i++)
    (markobj) (ct->ascii[i]);
#ifdef MULE
  for (i = 0; i < NUM_LEADING_BYTES; i++)
    (markobj) (ct->level1[i]);
#endif
  return ct->mirror_table;
}

/* WARNING: All functions of this nature need to be written extremely
   carefully to avoid crashes during GC.  Cf. prune_specifiers()
   and prune_weak_hashtables(). */

void
prune_syntax_tables (int (*obj_marked_p) (Lisp_Object))
{
  Lisp_Object rest, prev = Qnil;

  for (rest = Vall_syntax_tables;
       !GC_NILP (rest);
       rest = XCHAR_TABLE (rest)->next_table)
    {
      if (! ((*obj_marked_p) (rest)))
	{
	  /* This table is garbage.  Remove it from the list. */
	  if (GC_NILP (prev))
	    Vall_syntax_tables = XCHAR_TABLE (rest)->next_table;
	  else
	    XCHAR_TABLE (prev)->next_table =
	      XCHAR_TABLE (rest)->next_table;
	}
    }
}

static Lisp_Object
char_table_type_to_symbol (enum char_table_type type)
{
  switch (type)
  {
  case CHAR_TABLE_TYPE_GENERIC:  return Qgeneric;
  case CHAR_TABLE_TYPE_SYNTAX:   return Qsyntax;
  case CHAR_TABLE_TYPE_DISPLAY:  return Qdisplay;
  case CHAR_TABLE_TYPE_CHAR:     return Qchar;
#ifdef MULE
  case CHAR_TABLE_TYPE_CATEGORY: return Qcategory;
#endif
  }
  
  abort ();
  return Qnil; /* not reached */
}

static enum char_table_type
symbol_to_char_table_type (Lisp_Object symbol)
{
  CHECK_SYMBOL (symbol);
  
  if (EQ (symbol, Qgeneric))  return CHAR_TABLE_TYPE_GENERIC;
  if (EQ (symbol, Qsyntax))   return CHAR_TABLE_TYPE_SYNTAX;
  if (EQ (symbol, Qdisplay))  return CHAR_TABLE_TYPE_DISPLAY;
  if (EQ (symbol, Qchar))     return CHAR_TABLE_TYPE_CHAR;
#ifdef MULE
  if (EQ (symbol, Qcategory)) return CHAR_TABLE_TYPE_CATEGORY;
#endif
  
  signal_simple_error ("Unrecognized char table type", symbol);
  return CHAR_TABLE_TYPE_GENERIC; /* not reached */
}

static void
print_chartab_range (Emchar first, Emchar last, Lisp_Object val,
		     Lisp_Object printcharfun)
{
  if (first != last)
    {
      write_c_string (" (", printcharfun);
      print_internal (make_char (first), printcharfun, 0);
      write_c_string (" ", printcharfun);
      print_internal (make_char (last), printcharfun, 0);
      write_c_string (") ", printcharfun);
    }
  else
    {
      write_c_string (" ", printcharfun);
      print_internal (make_char (first), printcharfun, 0);
      write_c_string (" ", printcharfun);
    }
  print_internal (val, printcharfun, 1);
}

#ifdef MULE

static void
print_chartab_charset_row (Lisp_Object charset,
			   int row,
			   struct Lisp_Char_Table_Entry *cte,
			   Lisp_Object printcharfun)
{
  int i;
  Lisp_Object cat = Qunbound;
  int first = -1;

  for (i = 32; i < 128; i++)
    {
      Lisp_Object pam = cte->level2[i - 32];

      if (first == -1)
	{
	  first = i;
	  cat = pam;
	  continue;
	}

      if (!EQ (cat, pam))
	{
	  if (row == -1)
	    print_chartab_range (MAKE_CHAR (charset, first, 0),
				 MAKE_CHAR (charset, i - 1, 0),
				 cat, printcharfun);
	  else
	    print_chartab_range (MAKE_CHAR (charset, row, first),
				 MAKE_CHAR (charset, row, i - 1),
				 cat, printcharfun);
	  first = -1;
	  i--;
	}
    }
  
  if (first != -1)
    {
      if (row == -1)
	print_chartab_range (MAKE_CHAR (charset, first, 0),
			     MAKE_CHAR (charset, i - 1, 0),
			     cat, printcharfun);
      else
	print_chartab_range (MAKE_CHAR (charset, row, first),
			     MAKE_CHAR (charset, row, i - 1),
			     cat, printcharfun);
    }
}

static void
print_chartab_two_byte_charset (Lisp_Object charset,
				struct Lisp_Char_Table_Entry *cte,
				Lisp_Object printcharfun)
{
  int i;

  for (i = 32; i < 128; i++)
    {
      Lisp_Object jen = cte->level2[i - 32];

      if (!CHAR_TABLE_ENTRYP (jen))
	{
	  char buf[100];

	  write_c_string (" [", printcharfun);
	  print_internal (XCHARSET_NAME (charset), printcharfun, 0);
	  sprintf (buf, " %d] ", i);
	  write_c_string (buf, printcharfun);
	  print_internal (jen, printcharfun, 0);
	}
      else
	print_chartab_charset_row (charset, i, XCHAR_TABLE_ENTRY (jen),
				   printcharfun);
    }
}

#endif /* MULE */

static void
print_char_table (Lisp_Object obj, Lisp_Object printcharfun, int escapeflag)
{
  struct Lisp_Char_Table *ct = XCHAR_TABLE (obj);
  char buf[200];
  
  sprintf (buf, "#s(char-table type %s data (",
	   string_data (symbol_name (XSYMBOL
				     (char_table_type_to_symbol (ct->type)))));
  write_c_string (buf, printcharfun);

  /* Now write out the ASCII/Control-1 stuff. */
  {
    int i;
    int first = -1;
    Lisp_Object val = Qunbound;

    for (i = 0; i < NUM_ASCII_CHARS; i++)
      {
	if (first == -1)
	  {
	    first = i;
	    val = ct->ascii[i];
	    continue;
	  }

	if (!EQ (ct->ascii[i], val))
	  {
	    print_chartab_range (first, i - 1, val, printcharfun);
	    first = -1;
	    i--;
	  }
      }

    if (first != -1)
      print_chartab_range (first, i - 1, val, printcharfun);
  }

#ifdef MULE
  {
    int i;

    for (i = MIN_LEADING_BYTE; i < MIN_LEADING_BYTE + NUM_LEADING_BYTES;
	 i++)
      {
	Lisp_Object ann = ct->level1[i - MIN_LEADING_BYTE];
	Lisp_Object charset = CHARSET_BY_LEADING_BYTE (i);

	if (!CHARSETP (charset) || i == LEADING_BYTE_ASCII
            || i == LEADING_BYTE_CONTROL_1)
	  continue;
	if (!CHAR_TABLE_ENTRYP (ann))
	  {
	    write_c_string (" ", printcharfun);
	    print_internal (XCHARSET_NAME (charset),
			    printcharfun, 0);
	    write_c_string (" ", printcharfun);
	    print_internal (ann, printcharfun, 0);
	  }
	else
	  {
	    struct Lisp_Char_Table_Entry *cte = XCHAR_TABLE_ENTRY (ann);
	    if (XCHARSET_DIMENSION (charset) == 1)
	      print_chartab_charset_row (charset, -1, cte, printcharfun);
	    else
	      print_chartab_two_byte_charset (charset, cte, printcharfun);
	  }
      }
  }
#endif /* MULE */

  write_c_string ("))", printcharfun);
}

static int
char_table_equal (Lisp_Object obj1, Lisp_Object obj2, int depth)
{
  struct Lisp_Char_Table *ct1 = XCHAR_TABLE (obj1);
  struct Lisp_Char_Table *ct2 = XCHAR_TABLE (obj2);
  int i;

  if (CHAR_TABLE_TYPE (ct1) != CHAR_TABLE_TYPE (ct2))
    return 0;

  for (i = 0; i < NUM_ASCII_CHARS; i++)
    if (!internal_equal (ct1->ascii[i], ct2->ascii[i], depth + 1))
      return 0;

#ifdef MULE
  for (i = 0; i < NUM_LEADING_BYTES; i++)
    if (!internal_equal (ct1->level1[i], ct2->level1[i], depth + 1))
      return 0;
#endif /* MULE */

  return 1;
}

static unsigned long
char_table_hash (Lisp_Object obj, int depth)
{
  struct Lisp_Char_Table *ct = XCHAR_TABLE (obj);
  unsigned long hashval = internal_array_hash (ct->ascii, NUM_ASCII_CHARS,
					       depth);
#ifdef MULE
  hashval = HASH2 (hashval,
		   internal_array_hash (ct->level1, NUM_LEADING_BYTES, depth));
#endif /* MULE */
  return hashval;
}

DEFUN ("char-table-p", Fchar_table_p, 1, 1, 0, /*
Return non-nil if OBJECT is a char table.

A char table is a table that maps characters (or ranges of characters)
to values.  Char tables are specialized for characters, only allowing
particular sorts of ranges to be assigned values.  Although this
loses in generality, it makes for extremely fast (constant-time)
lookups, and thus is feasible for applications that do an extremely
large number of lookups (e.g. scanning a buffer for a character in
a particular syntax, where a lookup in the syntax table must occur
once per character).

When Mule support exists, the types of ranges that can be assigned
values are

-- all characters
-- an entire charset
-- a single row in a two-octet charset
-- a single character

When Mule support is not present, the types of ranges that can be
assigned values are

-- all characters
-- a single character

To create a char table, use `make-char-table'.  To modify a char
table, use `put-char-table' or `remove-char-table'.  To retrieve the
value for a particular character, use `get-char-table'.  See also
`map-char-table', `clear-char-table', `copy-char-table',
`valid-char-table-type-p', `char-table-type-list', `valid-char-table-value-p',
and `check-char-table-value'.
*/
       (object))
{
  return (CHAR_TABLEP (object) ? Qt : Qnil);
}

DEFUN ("char-table-type-list", Fchar_table_type_list, 0, 0, 0, /*
Return a list of the recognized char table types.
See `valid-char-table-type-p'.
*/
       ())
{
#ifdef MULE
  return list5 (Qchar, Qcategory, Qdisplay, Qgeneric, Qsyntax);
#else
  return list4 (Qchar, Qdisplay, Qgeneric, Qsyntax);
#endif
}

DEFUN ("valid-char-table-type-p", Fvalid_char_table_type_p, 1, 1, 0, /*
Return t if TYPE if a recognized char table type.

Each char table type is used for a different purpose and allows different
sorts of values.  The different char table types are

`category'
	Used for category tables, which specify the regexp categories
	that a character is in.  The valid values are nil or a
	bit vector of 95 elements.  Higher-level Lisp functions are
	provided for working with category tables.  Currently categories
	and category tables only exist when Mule support is present.
`char'
	A generalized char table, for mapping from one character to
	another.  Used for case tables, syntax matching tables,
	`keyboard-translate-table', etc.  The valid values are characters.
`generic'
        An even more generalized char table, for mapping from a
	character to anything.
`display'
	Used for display tables, which specify how a particular character
	is to appear when displayed.  #### Not yet implemented.
`syntax'
	Used for syntax tables, which specify the syntax of a particular
	character.  Higher-level Lisp functions are provided for
	working with syntax tables.  The valid values are integers.

*/
       (type))
{
  if (EQ (type, Qchar)
#ifdef MULE
      || EQ (type, Qcategory)
#endif
      || EQ (type, Qdisplay)
      || EQ (type, Qgeneric)
      || EQ (type, Qsyntax))
    return Qt;

  return Qnil;
}

DEFUN ("char-table-type", Fchar_table_type, 1, 1, 0, /*
Return the type of char table TABLE.
See `valid-char-table-type-p'.
*/
       (table))
{
  CHECK_CHAR_TABLE (table);
  return char_table_type_to_symbol (XCHAR_TABLE (table)->type);
}

void
fill_char_table (struct Lisp_Char_Table *ct, Lisp_Object value)
{
  int i;

  for (i = 0; i < NUM_ASCII_CHARS; i++)
    ct->ascii[i] = value;
#ifdef MULE
  for (i = 0; i < NUM_LEADING_BYTES; i++)
    ct->level1[i] = value;
#endif /* MULE */

  if (ct->type == CHAR_TABLE_TYPE_SYNTAX)
    update_syntax_table (ct);
}

DEFUN ("reset-char-table", Freset_char_table, 1, 1, 0, /*
Reset a char table to its default state.
*/
       (table))
{
  struct Lisp_Char_Table *ct;

  CHECK_CHAR_TABLE (table);
  ct = XCHAR_TABLE (table);

  switch (ct->type)
    {
    case CHAR_TABLE_TYPE_CHAR:
    case CHAR_TABLE_TYPE_DISPLAY:
    case CHAR_TABLE_TYPE_GENERIC:
#ifdef MULE
    case CHAR_TABLE_TYPE_CATEGORY:
      fill_char_table (ct, Qnil);
      break;
#endif

    case CHAR_TABLE_TYPE_SYNTAX:
      fill_char_table (ct, make_int (Sinherit));
      break;

    default:
      abort ();
    }

  return Qnil;
}

DEFUN ("make-char-table", Fmake_char_table, 1, 1, 0, /*
Make a new, empty char table of type TYPE.
Currently recognized types are 'char, 'category, 'display, 'generic,
and 'syntax.  See `valid-char-table-type-p'.
*/
       (type))
{
  struct Lisp_Char_Table *ct;
  Lisp_Object obj = Qnil;
  enum char_table_type ty = symbol_to_char_table_type (type);

  ct = (struct Lisp_Char_Table *)
    alloc_lcrecord (sizeof (struct Lisp_Char_Table), lrecord_char_table);
  ct->type = ty;
  if (ty == CHAR_TABLE_TYPE_SYNTAX)
    {
      ct->mirror_table = Fmake_char_table (Qgeneric);
    }
  else
    ct->mirror_table = Qnil;
  ct->next_table = Qnil;
  XSETCHAR_TABLE (obj, ct);
  if (ty == CHAR_TABLE_TYPE_SYNTAX)
    {
      ct->next_table = Vall_syntax_tables;
      Vall_syntax_tables = obj;
    }
  Freset_char_table (obj);
  return obj;
}

#ifdef MULE

static Lisp_Object
make_char_table_entry (Lisp_Object initval)
{
  struct Lisp_Char_Table_Entry *cte;
  Lisp_Object obj = Qnil;
  int i;

  cte = (struct Lisp_Char_Table_Entry *)
    alloc_lcrecord (sizeof (struct Lisp_Char_Table_Entry),
		    lrecord_char_table_entry);
  for (i = 0; i < 96; i++)
    cte->level2[i] = initval;
  XSETCHAR_TABLE_ENTRY (obj, cte);
  return obj;
}

static Lisp_Object
copy_char_table_entry (Lisp_Object entry)
{
  struct Lisp_Char_Table_Entry *cte = XCHAR_TABLE_ENTRY (entry);
  struct Lisp_Char_Table_Entry *ctenew;
  Lisp_Object obj = Qnil;
  int i;

  ctenew = (struct Lisp_Char_Table_Entry *)
    alloc_lcrecord (sizeof (struct Lisp_Char_Table_Entry),
		    lrecord_char_table_entry);
  for (i = 0; i < 96; i++)
    {
      Lisp_Object new = cte->level2[i];
      if (CHAR_TABLE_ENTRYP (new))
	ctenew->level2[i] = copy_char_table_entry (new);
      else
	ctenew->level2[i] = new;
    }

  XSETCHAR_TABLE_ENTRY (obj, cte);
  return obj;
}

#endif /* MULE */

DEFUN ("copy-char-table", Fcopy_char_table, 1, 1, 0, /*
Make a new char table which is a copy of OLD-TABLE.
It will contain the same values for the same characters and ranges
as OLD-TABLE.  The values will not themselves be copied.
*/
       (old_table))
{
  struct Lisp_Char_Table *ct, *ctnew;
  Lisp_Object obj = Qnil;
  int i;

  CHECK_CHAR_TABLE (old_table);
  ct = XCHAR_TABLE (old_table);
  ctnew = (struct Lisp_Char_Table *)
    alloc_lcrecord (sizeof (struct Lisp_Char_Table), lrecord_char_table);
  ctnew->type = ct->type;

  for (i = 0; i < NUM_ASCII_CHARS; i++)
    {
      Lisp_Object new = ct->ascii[i];
#ifdef MULE
      assert (! (CHAR_TABLE_ENTRYP (new)));
#endif /* MULE */
      ctnew->ascii[i] = new;
    }

#ifdef MULE

  for (i = 0; i < NUM_LEADING_BYTES; i++)
    {
      Lisp_Object new = ct->level1[i];
      if (CHAR_TABLE_ENTRYP (new))
	ctnew->level1[i] = copy_char_table_entry (new);
      else
	ctnew->level1[i] = new;
    }

#endif /* MULE */

  if (CHAR_TABLEP (ct->mirror_table))
    ctnew->mirror_table = Fcopy_char_table (ct->mirror_table);
  else
    ctnew->mirror_table = ct->mirror_table;
  XSETCHAR_TABLE (obj, ctnew);
  return obj;
}

static void
decode_char_table_range (Lisp_Object range, struct chartab_range *outrange)
{
  if (EQ (range, Qt))
    outrange->type = CHARTAB_RANGE_ALL;
  else if (CHAR_OR_CHAR_INTP (range))
    {
      outrange->type = CHARTAB_RANGE_CHAR;
      outrange->ch = XCHAR_OR_CHAR_INT (range);
    }
#ifndef MULE
  else
    signal_simple_error ("Range must be t or a character", range);
#else /* MULE */
  else if (VECTORP (range))
    {
      struct Lisp_Vector *vec = XVECTOR (range);
      Lisp_Object *elts = vector_data (vec);
      if (vector_length (vec) != 2)
	signal_simple_error ("Length of charset row vector must be 2",
			     range);
      outrange->type = CHARTAB_RANGE_ROW;
      outrange->charset = Fget_charset (elts[0]);
      CHECK_INT (elts[1]);
      outrange->row = XINT (elts[1]);
      switch (XCHARSET_TYPE (outrange->charset))
	{
	case CHARSET_TYPE_94:
	case CHARSET_TYPE_96:
	  signal_simple_error ("Charset in row vector must be multi-byte",
			       outrange->charset);
	case CHARSET_TYPE_94X94:
	  check_int_range (outrange->row, 33, 126);
	  break;
	case CHARSET_TYPE_96X96:
	  check_int_range (outrange->row, 32, 127);
	  break;
	default:
	  abort ();
	}
    }
  else
    {
      if (!CHARSETP (range) && !SYMBOLP (range))
	signal_simple_error
	  ("Char table range must be t, charset, char, or vector", range);
      outrange->type = CHARTAB_RANGE_CHARSET;
      outrange->charset = Fget_charset (range);
    }
#endif /* MULE */
}

#ifdef MULE

/* called from CHAR_TABLE_VALUE(). */
Lisp_Object
get_non_ascii_char_table_value (struct Lisp_Char_Table *ct, int leading_byte,
			       Emchar c)
{
  Lisp_Object val;
  Lisp_Object charset = CHARSET_BY_LEADING_BYTE (leading_byte);
  int byte1, byte2;

  BREAKUP_CHAR_1_UNSAFE (c, charset, byte1, byte2);
  val = ct->level1[leading_byte - MIN_LEADING_BYTE];
  if (CHAR_TABLE_ENTRYP (val))
    {
      struct Lisp_Char_Table_Entry *cte = XCHAR_TABLE_ENTRY (val);
      val = cte->level2[byte1 - 32];
      if (CHAR_TABLE_ENTRYP (val))
	{
	  cte = XCHAR_TABLE_ENTRY (val);
	  assert (byte2 >= 32);
	  val = cte->level2[byte2 - 32];
	  assert (!CHAR_TABLE_ENTRYP (val));
	}
    }

  return val;
}

#endif /* MULE */

static Lisp_Object
get_char_table (Emchar ch, struct Lisp_Char_Table *ct) 
{
#ifdef MULE
  {
    Lisp_Object charset;
    int byte1, byte2;
    Lisp_Object val;
    
    BREAKUP_CHAR (ch, charset, byte1, byte2);
    
    if (EQ (charset, Vcharset_ascii))
      val = ct->ascii[byte1];
    else if (EQ (charset, Vcharset_control_1))
      val = ct->ascii[byte1 + 128];
    else
      {
	int lb = XCHARSET_LEADING_BYTE (charset) - MIN_LEADING_BYTE;
	val = ct->level1[lb];
	if (CHAR_TABLE_ENTRYP (val))
	  {
	    struct Lisp_Char_Table_Entry *cte = XCHAR_TABLE_ENTRY (val);
	    val = cte->level2[byte1 - 32];
	    if (CHAR_TABLE_ENTRYP (val))
	      {
		cte = XCHAR_TABLE_ENTRY (val);
		assert (byte2 >= 32);
		val = cte->level2[byte2 - 32];
		assert (!CHAR_TABLE_ENTRYP (val));
	      }
	  }
      }

    return val;
  }
#else /* not MULE */
  return ct->ascii[(unsigned char)ch];
#endif /* not MULE */
}


DEFUN ("get-char-table", Fget_char_table, 2, 2, 0, /*
Find value for char CH in TABLE.
*/
       (ch, table))
{
  struct Lisp_Char_Table *ct;
  Emchar chr;
  
  CHECK_CHAR_TABLE (table);
  ct = XCHAR_TABLE (table);
  CHECK_CHAR_COERCE_INT (ch);
  chr = XCHAR(ch);
  
  return (get_char_table (chr, ct));
}

DEFUN ("get-range-char-table", Fget_range_char_table, 2, 3, 0, /*
Find value for a range in TABLE.
If there is more than one value, return MULTI (defaults to nil).
*/
       (range, table, multi))
{
  struct Lisp_Char_Table *ct;
  struct chartab_range rainj;

  if (CHAR_OR_CHAR_INTP (range))
    return Fget_char_table (range, table);
  CHECK_CHAR_TABLE (table);
  ct = XCHAR_TABLE (table);

  decode_char_table_range (range, &rainj);
  switch (rainj.type)
    {
    case CHARTAB_RANGE_ALL:
      {
	int i;
	Lisp_Object first = ct->ascii[0];
	
	for (i = 1; i < NUM_ASCII_CHARS; i++)
	  if (!EQ (first, ct->ascii[i]))
	    return multi;
	
#ifdef MULE
	for (i = MIN_LEADING_BYTE; i < MIN_LEADING_BYTE + NUM_LEADING_BYTES;
	     i++)
	  {
	    if (!CHARSETP (CHARSET_BY_LEADING_BYTE (i))
		|| i == LEADING_BYTE_ASCII
		|| i == LEADING_BYTE_CONTROL_1)
	      continue;
	    if (!EQ (first, ct->level1[i - MIN_LEADING_BYTE]))
	      return multi;
	  }
#endif /* MULE */

	return first;
      }

#ifdef MULE
    case CHARTAB_RANGE_CHARSET:
      if (EQ (rainj.charset, Vcharset_ascii))
	{
	  int i;
	  Lisp_Object first = ct->ascii[0];
	  
	  for (i = 1; i < 128; i++)
	    if (!EQ (first, ct->ascii[i]))
	      return multi;
	  return first;
	}
      
      if (EQ (rainj.charset, Vcharset_control_1))
	{
	  int i;
	  Lisp_Object first = ct->ascii[128];
	  
	  for (i = 129; i < 160; i++)
	    if (!EQ (first, ct->ascii[i]))
	      return multi;
	  return first;
	}
      
      {
	Lisp_Object val = ct->level1[XCHARSET_LEADING_BYTE (rainj.charset) -
				     MIN_LEADING_BYTE];
	if (CHAR_TABLE_ENTRYP (val))
	  return multi;
	return val;
      }

    case CHARTAB_RANGE_ROW:
      {
	Lisp_Object val = ct->level1[XCHARSET_LEADING_BYTE (rainj.charset) -
				     MIN_LEADING_BYTE];
	if (!CHAR_TABLE_ENTRYP (val))
	  return val;
	val = XCHAR_TABLE_ENTRY (val)->level2[rainj.row - 32];
	if (CHAR_TABLE_ENTRYP (val))
	  return multi;
	return val;
      }
#endif /* not MULE */

    default:
      abort ();
    }

  return Qnil; /* not reached */
}

static int
check_valid_char_table_value (Lisp_Object value, enum char_table_type type,
			      Error_behavior errb)
{
  switch (type)
    {
    case CHAR_TABLE_TYPE_SYNTAX:
      if (!ERRB_EQ (errb, ERROR_ME))
	return INTP (value) || (CONSP (value) && INTP (XCAR (value))
				&& CHAR_OR_CHAR_INTP (XCDR (value)));
      if (CONSP (value))
        {
	  Lisp_Object cdr = XCDR (value);
          CHECK_INT (XCAR (value));
	  CHECK_CHAR_COERCE_INT (cdr);
         }
      else
        CHECK_INT (value);
      break;

#ifdef MULE
    case CHAR_TABLE_TYPE_CATEGORY:
      if (!ERRB_EQ (errb, ERROR_ME))
	return CATEGORY_TABLE_VALUEP (value);
      CHECK_CATEGORY_TABLE_VALUE (value);
      break;
#endif

    case CHAR_TABLE_TYPE_GENERIC:
      return 1;

    case CHAR_TABLE_TYPE_DISPLAY:
      /* #### fix this */
      maybe_signal_simple_error ("Display char tables not yet implemented",
				 value, Qchar_table, errb);
      return 0;

    case CHAR_TABLE_TYPE_CHAR:
      if (!ERRB_EQ (errb, ERROR_ME))
	return CHAR_OR_CHAR_INTP (value);
      CHECK_CHAR_COERCE_INT (value);
      break;

    default:
      abort ();
    }

  return 0; /* not reached */
}

static Lisp_Object
canonicalize_char_table_value (Lisp_Object value, enum char_table_type type)
{
  switch (type)
    {
    case CHAR_TABLE_TYPE_SYNTAX:
      if (CONSP (value))
	{
	  Lisp_Object car = XCAR (value);
	  Lisp_Object cdr = XCDR (value);
	  CHECK_CHAR_COERCE_INT (cdr);
	  return Fcons (car, cdr);
	}
    default:
      break;
    }
  return value;
}

DEFUN ("valid-char-table-value-p", Fvalid_char_table_value_p, 2, 2, 0, /*
Return non-nil if VALUE is a valid value for CHAR-TABLE-TYPE.
*/
       (value, char_table_type))
{
  enum char_table_type type = symbol_to_char_table_type (char_table_type);

  return check_valid_char_table_value (value, type, ERROR_ME_NOT) ? Qt : Qnil;
}

DEFUN ("check-valid-char-table-value", Fcheck_valid_char_table_value, 2, 2, 0, /*
Signal an error if VALUE is not a valid value for CHAR-TABLE-TYPE.
*/
       (value, char_table_type))
{
  enum char_table_type type = symbol_to_char_table_type (char_table_type);

  check_valid_char_table_value (value, type, ERROR_ME);
  return Qnil;
}

/* Assign VAL to all characters in RANGE in char table CT. */

void
put_char_table (struct Lisp_Char_Table *ct, struct chartab_range *range,
		Lisp_Object val)
{
  switch (range->type)
    {
    case CHARTAB_RANGE_ALL:
      fill_char_table (ct, val);
      return; /* avoid the duplicate call to update_syntax_table() below,
		 since fill_char_table() also did that. */

#ifdef MULE
    case CHARTAB_RANGE_CHARSET:
      if (EQ (range->charset, Vcharset_ascii))
	{
	  int i;
	  for (i = 0; i < 128; i++)
	    ct->ascii[i] = val;
	}
      else if (EQ (range->charset, Vcharset_control_1))
	{
	  int i;
	  for (i = 128; i < 160; i++)
	    ct->ascii[i] = val;
	}
      else
	{
	  int lb = XCHARSET_LEADING_BYTE (range->charset) - MIN_LEADING_BYTE;
	  ct->level1[lb] = val;
	}
      break;

    case CHARTAB_RANGE_ROW:
      {
	struct Lisp_Char_Table_Entry *cte;
	int lb = XCHARSET_LEADING_BYTE (range->charset) - MIN_LEADING_BYTE;
	/* make sure that there is a separate entry for the row. */
	if (!CHAR_TABLE_ENTRYP (ct->level1[lb]))
	  ct->level1[lb] = make_char_table_entry (ct->level1[lb]);
	cte = XCHAR_TABLE_ENTRY (ct->level1[lb]);
	cte->level2[range->row - 32] = val;
      }
      break;
#endif /* MULE */

    case CHARTAB_RANGE_CHAR:
#ifdef MULE
      {
	Lisp_Object charset;
	int byte1, byte2;
	
	BREAKUP_CHAR (range->ch, charset, byte1, byte2);
	if (EQ (charset, Vcharset_ascii))
	  ct->ascii[byte1] = val;
	else if (EQ (charset, Vcharset_control_1))
	  ct->ascii[byte1 + 128] = val;
	else
	  {
	    struct Lisp_Char_Table_Entry *cte;
	    int lb = XCHARSET_LEADING_BYTE (charset) - MIN_LEADING_BYTE;
	    /* make sure that there is a separate entry for the row. */
	    if (!CHAR_TABLE_ENTRYP (ct->level1[lb]))
	      ct->level1[lb] = make_char_table_entry (ct->level1[lb]);
	    cte = XCHAR_TABLE_ENTRY (ct->level1[lb]);
	    /* now CTE is a char table entry for the charset;
	       each entry is for a single row (or character of
	       a one-octet charset). */
	    if (XCHARSET_DIMENSION (charset) == 1)
	      cte->level2[byte1 - 32] = val;
	    else
	      {
		/* assigning to one character in a two-octet charset. */
		/* make sure that the charset row contains a separate
		   entry for each character. */
		if (!CHAR_TABLE_ENTRYP (cte->level2[byte1 - 32]))
		  cte->level2[byte1 - 32] =
		    make_char_table_entry (cte->level2[byte1 - 32]);
		cte = XCHAR_TABLE_ENTRY (cte->level2[byte1 - 32]);
		cte->level2[byte2 - 32] = val;
	      }
	  }
      }
#else /* not MULE */
      ct->ascii[(unsigned char) (range->ch)] = val;
      break;
#endif /* not MULE */
    }

  if (ct->type == CHAR_TABLE_TYPE_SYNTAX)
    update_syntax_table (ct);
}

DEFUN ("put-char-table", Fput_char_table, 3, 3, 0, /*
Set the value for chars in RANGE to be VAL in TABLE.

RANGE specifies one or more characters to be affected and should be
one of the following:

-- t (all characters are affected)
-- A charset (only allowed when Mule support is present)
-- A vector of two elements: a two-octet charset and a row number
   (only allowed when Mule support is present)
-- A single character

VAL must be a value appropriate for the type of TABLE.
See `valid-char-table-type-p'.
*/
       (range, val, table))
{
  struct Lisp_Char_Table *ct;
  struct chartab_range rainj;

  CHECK_CHAR_TABLE (table);
  ct = XCHAR_TABLE (table);
  check_valid_char_table_value (val, ct->type, ERROR_ME);
  decode_char_table_range (range, &rainj);
  val = canonicalize_char_table_value (val, ct->type);
  put_char_table (ct, &rainj, val);
  return Qnil;
}

/* Map FN over the ASCII chars in CT. */

static int
map_over_charset_ascii (struct Lisp_Char_Table *ct,
			int (*fn) (struct chartab_range *range,
				   Lisp_Object val, void *arg),
			void *arg)
{
  int i;

#ifdef MULE
  for (i = 0; i < 128; i++)
#else
  for (i = 0; i < 256; i++)
#endif
    {
      Lisp_Object val = ct->ascii[i];
      struct chartab_range rainj;
      int retval;

      rainj.type = CHARTAB_RANGE_CHAR;
      rainj.ch = (Emchar) i;
      retval = (fn) (&rainj, val, arg);
      if (retval)
	return retval;
    }

  return 0;
}

#ifdef MULE

/* Map FN over the Control-1 chars in CT. */

static int
map_over_charset_control_1 (struct Lisp_Char_Table *ct,
			    int (*fn) (struct chartab_range *range,
				       Lisp_Object val, void *arg),
			    void *arg)
{
  int i;

  for (i = 0; i < 32; i++)
    {
      Lisp_Object val = ct->ascii[i + 128];
      struct chartab_range rainj;
      int retval;

      rainj.type = CHARTAB_RANGE_CHAR;
      rainj.ch = (Emchar) (i + 128);
      retval = (fn) (&rainj, val, arg);
      if (retval)
	return retval;
    }

  return 0;
}

/* Map FN over the row ROW of two-byte charset CHARSET.
   There must be a separate value for that row in the char table.
   CTE specifies the char table entry for CHARSET. */

static int
map_over_charset_row (struct Lisp_Char_Table_Entry *cte,
		      Lisp_Object charset, int row,
		      int (*fn) (struct chartab_range *range,
				 Lisp_Object val, void *arg),
		      void *arg)
{
  Lisp_Object val;

  val = cte->level2[row - 32];
  if (!CHAR_TABLE_ENTRYP (val))
    {
      struct chartab_range rainj;

      rainj.type = CHARTAB_RANGE_ROW;
      rainj.charset = charset;
      rainj.row = row;
      return (fn) (&rainj, val, arg);
    }
  else
    {
      int i;
      int start, stop;
      
      cte = XCHAR_TABLE_ENTRY (val);
      if (XCHARSET_CHARS (charset) == 94)
	{
	  start = 33;
	  stop = 127;
	}
      else
	{
	  start = 32;
	  stop = 128;
	}
      
      for (i = start; i < stop; i++)
	{
	  int retval;
	  struct chartab_range rainj;

	  rainj.type = CHARTAB_RANGE_CHAR;
	  rainj.ch = MAKE_CHAR (charset, row, i);

	  val = cte->level2[i - 32];
	  retval = (fn) (&rainj, val, arg);
	  if (retval)
	    return retval;
	}
    }

  return 0;
}

static int
map_over_other_charset (struct Lisp_Char_Table *ct, int lb,
			int (*fn) (struct chartab_range *range,
				   Lisp_Object val, void *arg),
			void *arg)
{
  Lisp_Object charset;
  Lisp_Object val;

  val = ct->level1[lb - MIN_LEADING_BYTE];

  charset = CHARSET_BY_LEADING_BYTE (lb);
  if (!CHARSETP (charset) || lb == LEADING_BYTE_ASCII
      || lb == LEADING_BYTE_CONTROL_1)
    return 0;
  if (!CHAR_TABLE_ENTRYP (val))
    {
      struct chartab_range rainj;

      rainj.type = CHARTAB_RANGE_CHARSET;
      rainj.charset = charset;
      return (fn) (&rainj, val, arg);
    }
  else if (XCHARSET_DIMENSION (charset) == 1)
    {
      int i;
      struct Lisp_Char_Table_Entry *cte = XCHAR_TABLE_ENTRY (val);
      int start, stop;
      
      if (XCHARSET_CHARS (charset) == 94)
	{
	  start = 33;
	  stop = 127;
	}
      else
	{
	  start = 32;
	  stop = 128;
	}

      for (i = start; i < stop; i++)
	{
	  int retval;
	  struct chartab_range rainj;

	  rainj.type = CHARTAB_RANGE_CHAR;
	  rainj.ch = MAKE_CHAR (charset, i, 0);
	  retval = (fn) (&rainj, cte->level2[i - 32], arg);
	  if (retval)
	    return retval;
	}
    }
  else
    {
      int i;
      struct Lisp_Char_Table_Entry *cte = XCHAR_TABLE_ENTRY (val);
      int start, stop;
      
      if (XCHARSET_CHARS (charset) == 94)
	{
	  start = 33;
	  stop = 127;
	}
      else
	{
	  start = 32;
	  stop = 128;
	}

      for (i = start; i < stop; i++)
	{
	  int retval =
	    map_over_charset_row (cte, charset, i, fn, arg);
	  if (retval)
	    return retval;
	}
    }

  return 0;
}

#endif /* MULE */

/* Map FN (with client data ARG) over range RANGE in char table CT.
   Mapping stops the first time FN returns non-zero, and that value
   becomes the return value of map_char_table(). */

int
map_char_table (struct Lisp_Char_Table *ct,
		struct chartab_range *range,
		int (*fn) (struct chartab_range *range,
			   Lisp_Object val, void *arg),
		void *arg)
{
  switch (range->type)
    {
    case CHARTAB_RANGE_ALL:
      {
	int retval;
	
	retval = map_over_charset_ascii (ct, fn, arg);
	if (retval)
	  return retval;
#ifdef MULE
	retval = map_over_charset_control_1 (ct, fn, arg);
	if (retval)
	  return retval;
	{
	  int i;
	  for (i = MIN_LEADING_BYTE; i < MIN_LEADING_BYTE + NUM_LEADING_BYTES;
	       i++)
	    {
	      retval = map_over_other_charset (ct, i, fn, arg);
	      if (retval)
		return retval;
	    }
	}
#endif
      }
      break;

#ifdef MULE
    case CHARTAB_RANGE_CHARSET:
      return map_over_other_charset (ct,
				     XCHARSET_LEADING_BYTE (range->charset),
				     fn, arg);

    case CHARTAB_RANGE_ROW:
      {
	Lisp_Object val = ct->level1[XCHARSET_LEADING_BYTE (range->charset) - MIN_LEADING_BYTE];
	if (!CHAR_TABLE_ENTRYP (val))
	  {
	    struct chartab_range rainj;

	    rainj.type = CHARTAB_RANGE_ROW;
	    rainj.charset = range->charset;
	    rainj.row = range->row;
	    return (fn) (&rainj, val, arg);
	  }
	else
	  return map_over_charset_row (XCHAR_TABLE_ENTRY (val),
				       range->charset, range->row,
				       fn, arg);
      }
#endif /* MULE */

    case CHARTAB_RANGE_CHAR:
      {
	Emchar ch = range->ch;
	Lisp_Object val = CHAR_TABLE_VALUE_UNSAFE (ct, ch);
	struct chartab_range rainj;

	rainj.type = CHARTAB_RANGE_CHAR;
	rainj.ch = ch;
	return (fn) (&rainj, val, arg);
      }

    default:
      abort ();
    }

  return 0;
}

struct slow_map_char_table_arg
{
  Lisp_Object function;
  Lisp_Object retval;
};

static int
slow_map_char_table_fun (struct chartab_range *range,
			 Lisp_Object val, void *arg)
{
  Lisp_Object ranjarg = Qnil;
  struct slow_map_char_table_arg *closure =
    (struct slow_map_char_table_arg *) arg;

  switch (range->type)
    {
    case CHARTAB_RANGE_ALL:
      ranjarg = Qt;
      break;

#ifdef MULE
    case CHARTAB_RANGE_CHARSET:
      ranjarg = XCHARSET_NAME (range->charset);
      break;

    case CHARTAB_RANGE_ROW:
      ranjarg = vector2 (XCHARSET_NAME (range->charset),
			 make_int (range->row));
      break;
#endif
    case CHARTAB_RANGE_CHAR:
      ranjarg = make_char (range->ch);
      break;
    default:
      abort ();
    }

  closure->retval = call2 (closure->function, ranjarg, val);
  return (!NILP (closure->retval));
}

DEFUN ("map-char-table", Fmap_char_table, 2, 3, 0, /*
Map FUNCTION over entries in TABLE, calling it with two args,
each key and value in the table.

RANGE specifies a subrange to map over and is in the same format as
the RANGE argument to `put-range-table'.  If omitted or t, it defaults to
the entire table.
*/
       (function, table, range))
{
  struct Lisp_Char_Table *ct;
  struct slow_map_char_table_arg slarg;
  struct gcpro gcpro1, gcpro2;
  struct chartab_range rainj;

  CHECK_CHAR_TABLE (table);
  ct = XCHAR_TABLE (table);
  if (NILP (range))
    range = Qt;
  decode_char_table_range (range, &rainj);
  slarg.function = function;
  slarg.retval = Qnil;
  GCPRO2 (slarg.function, slarg.retval);
  map_char_table (ct, &rainj, slow_map_char_table_fun, &slarg);
  UNGCPRO;

  return slarg.retval;
}



/************************************************************************/
/*                         Char table read syntax                       */
/************************************************************************/

static int
chartab_type_validate (Lisp_Object keyword, Lisp_Object value,
		       Error_behavior errb)
{
  /* #### should deal with ERRB */
  (void) symbol_to_char_table_type (value);
  return 1;
}

static int
chartab_data_validate (Lisp_Object keyword, Lisp_Object value,
		       Error_behavior errb)
{
  Lisp_Object rest;

  /* #### should deal with ERRB */
  EXTERNAL_LIST_LOOP (rest, value)
    {
      Lisp_Object range = XCAR (rest);
      struct chartab_range dummy;

      rest = XCDR (rest);
      if (!CONSP (rest))
	signal_simple_error ("Invalid list format", value);
      if (CONSP (range))
	{
	  if (!CONSP (XCDR (range))
	      || !NILP (XCDR (XCDR (range))))
	    signal_simple_error ("Invalid range format", range);
	  decode_char_table_range (XCAR (range), &dummy);
	  decode_char_table_range (XCAR (XCDR (range)), &dummy);
	}
      else
	decode_char_table_range (range, &dummy);
    }

  return 1;
}

static Lisp_Object
chartab_instantiate (Lisp_Object data)
{
  Lisp_Object chartab;
  Lisp_Object type = Qgeneric;
  Lisp_Object dataval = Qnil;

  while (!NILP (data))
    {
      Lisp_Object keyw = Fcar (data);
      Lisp_Object valw;

      data = Fcdr (data);
      valw = Fcar (data);
      data = Fcdr (data);
      if (EQ (keyw, Qtype))
	type = valw;
      else if (EQ (keyw, Qdata))
	dataval = valw;
    }

  chartab = Fmake_char_table (type);

  data = dataval;
  while (!NILP (data))
    {
      Lisp_Object range = Fcar (data);
      Lisp_Object val = Fcar (Fcdr (data));
      
      data = Fcdr (Fcdr (data));
      if (CONSP (range))
        {
	  if (CHAR_OR_CHAR_INTP (XCAR (range)))
	    {
	      Emchar first = XCHAR_OR_CHAR_INT (Fcar (range));
	      Emchar last = XCHAR_OR_CHAR_INT (Fcar (Fcdr (range)));
	      Emchar i;

	      for (i = first; i <= last; i++)
		 Fput_char_table (make_char (i), val, chartab);
	    }
	  else
	    abort ();
	}
      else
	Fput_char_table (range, val, chartab);
    }

  return chartab;
}

#ifdef MULE


/************************************************************************/
/*                     Category Tables, specifically                    */
/************************************************************************/

DEFUN ("category-table-p", Fcategory_table_p, 1, 1, 0, /*
Return t if ARG is a category table.
A category table is a type of char table used for keeping track of
categories.  Categories are used for classifying characters for use
in regexps -- you can refer to a category rather than having to use
a complicated [] expression (and category lookups are significantly
faster).

There are 95 different categories available, one for each printable
character (including space) in the ASCII charset.  Each category
is designated by one such character, called a \"category designator\".
They are specified in a regexp using the syntax \"\\cX\", where X is
a category designator.

A category table specifies, for each character, the categories that
the character is in.  Note that a character can be in more than one
category.  More specifically, a category table maps from a character
to either the value nil (meaning the character is in no categories)
or a 95-element bit vector, specifying for each of the 95 categories
whether the character is in that category.

Special Lisp functions are provided that abstract this, so you do not
have to directly manipulate bit vectors.
*/
       (obj))
{
  if (CHAR_TABLEP (obj) && XCHAR_TABLE_TYPE (obj) == CHAR_TABLE_TYPE_CATEGORY)
    return Qt;
  return Qnil;
}

static Lisp_Object
check_category_table (Lisp_Object obj, Lisp_Object def)
{
  if (NILP (obj))
    obj = def;
  while (NILP (Fcategory_table_p (obj)))
    obj = wrong_type_argument (Qcategory_table_p, obj);
  return (obj);
}   

int
check_category_at(Emchar ch, Lisp_Object table,
		  unsigned int designator, unsigned int not)
{
  register Lisp_Object temp;
  struct Lisp_Char_Table *ctbl;  
#if 1 /* ifdef ERROR_CHECK_TYPECHECK */
  if (NILP (Fcategory_table_p (table)))
    signal_simple_error("Expected category table", table);
#endif
  ctbl = XCHAR_TABLE(table);
  temp = get_char_table(ch, ctbl);
  if (EQ (temp, Qnil)) return not;
  
  designator -= ' ';
  return (bit_vector_bit(XBIT_VECTOR (temp), designator) ? !not : not);
}

DEFUN ("check-category-at", Fcheck_category_at, 2, 4, 0, /*
Return t if category of a character at POS includes DESIGNATIOR,
else return nil. Optional third arg specifies which buffer
(defaulting to current), and fourth specifies the CATEGORY-TABLE,
(defaulting to the buffer's category table).
*/
       (pos, designator, buffer, category_table))
{
  Lisp_Object ctbl;
  Emchar ch;
  unsigned int des;
  struct buffer *buf = decode_buffer(buffer, 0);

  CHECK_INT (pos);
  CHECK_CATEGORY_DESIGNATOR (designator);
  des = XREALINT(designator);
  ctbl = check_category_table (category_table, Vstandard_category_table);
  ch = BUF_FETCH_CHAR (buf, XINT(pos));
  return (check_category_at(ch, ctbl, des, 0)
	  ? Qt : Qnil);
}

DEFUN ("category-table", Fcategory_table, 0, 1, 0, /*
Return the current category table.
This is the one specified by the current buffer, or by BUFFER if it
is non-nil.
*/
       (buffer))
{
  return decode_buffer (buffer, 0)->category_table;
}

DEFUN ("standard-category-table", Fstandard_category_table, 0, 0, 0, /*
Return the standard category table.
This is the one used for new buffers.
*/
       ())
{
  return Vstandard_category_table;
}

DEFUN ("copy-category-table", Fcopy_category_table, 0, 1, 0, /*
Construct a new category table and return it.
It is a copy of the TABLE, which defaults to the standard category table.
*/
       (table))
{
  if (NILP (Vstandard_category_table))
    return Fmake_char_table (Qcategory);

  table = check_category_table (table, Vstandard_category_table);
  return Fcopy_char_table (table);
}

DEFUN ("set-category-table", Fset_category_table, 1, 2, 0, /*
Select a new category table for BUFFER.
One argument, a category table.
BUFFER defaults to the current buffer if omitted.
*/
       (table, buffer))
{
  struct buffer *buf = decode_buffer (buffer, 0);
  table = check_category_table (table, Qnil);
  buf->category_table = table;
  /* Indicate that this buffer now has a specified category table.  */
  buf->local_var_flags |= XINT (buffer_local_flags.category_table);
  return table;
}

DEFUN ("category-designator-p", Fcategory_designator_p, 1, 1, 0, /*
Return t if ARG is a category designator (a char in the range ' ' to '~').
*/
       (obj))
{
  if (CATEGORY_DESIGNATORP (obj))
    return Qt;
  return Qnil;
}

DEFUN ("category-table-value-p", Fcategory_table_value_p, 1, 1, 0, /*
Return t if ARG is a category table value.
Valid values are nil or a bit vector of size 95.
*/
       (obj))
{
  if (CATEGORY_TABLE_VALUEP (obj))
    return Qt;
  return Qnil;
}

#endif /* MULE */


void
syms_of_chartab (void)
{
#ifdef MULE
  defsymbol (&Qcategory_table_p, "category-table-p");
  defsymbol (&Qcategory_designator_p, "category-designator-p");
  defsymbol (&Qcategory_table_value_p, "category-table-value-p");
#endif /* MULE */

  defsymbol (&Qchar_table, "char-table");
  defsymbol (&Qchar_tablep, "char-table-p");

  DEFSUBR (Fchar_table_p);
  DEFSUBR (Fchar_table_type_list);
  DEFSUBR (Fvalid_char_table_type_p);
  DEFSUBR (Fchar_table_type);
  DEFSUBR (Freset_char_table);
  DEFSUBR (Fmake_char_table);
  DEFSUBR (Fcopy_char_table);
  DEFSUBR (Fget_char_table);
  DEFSUBR (Fget_range_char_table);
  DEFSUBR (Fvalid_char_table_value_p);
  DEFSUBR (Fcheck_valid_char_table_value);
  DEFSUBR (Fput_char_table);
  DEFSUBR (Fmap_char_table);

#ifdef MULE
  DEFSUBR (Fcategory_table_p);
  DEFSUBR (Fcategory_table);
  DEFSUBR (Fstandard_category_table);
  DEFSUBR (Fcopy_category_table);
  DEFSUBR (Fset_category_table);
  DEFSUBR (Fcheck_category_at);
  DEFSUBR (Fcategory_designator_p);
  DEFSUBR (Fcategory_table_value_p);
#endif /* MULE */

  /* DO NOT staticpro this.  It works just like Vweak_hash_tables. */
  Vall_syntax_tables = Qnil;
}

void
structure_type_create_chartab (void)
{
  struct structure_type *st;

  st = define_structure_type (Qchar_table, 0, chartab_instantiate);

  define_structure_type_keyword (st, Qtype, chartab_type_validate);
  define_structure_type_keyword (st, Qdata, chartab_data_validate);
}

void
complex_vars_of_chartab (void)
{
#ifdef MULE
  /* Set this now, so first buffer creation can refer to it. */
  /* Make it nil before calling copy-category-table
     so that copy-category-table will know not to try to copy from garbage */
  Vstandard_category_table = Qnil;
  Vstandard_category_table = Fcopy_category_table (Qnil);
  staticpro (&Vstandard_category_table);
#endif /* MULE */
}
