/* XEmacs routines to deal with range tables.
   Copyright (C) 1995 Sun Microsystems, Inc.
   Copyright (C) 1995, 2002, 2004, 2005, 2010 Ben Wing.

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

/* Written by Ben Wing, August 1995. */

#include <config.h>
#include "lisp.h"
#include "rangetab.h"

Lisp_Object Qrange_tablep;
Lisp_Object Qrange_table;

Lisp_Object Qstart_closed_end_open;
Lisp_Object Qstart_open_end_open;
Lisp_Object Qstart_closed_end_closed;
Lisp_Object Qstart_open_end_closed;


/************************************************************************/
/*                            Range table object                        */
/************************************************************************/

static enum range_table_type
range_table_symbol_to_type (Lisp_Object symbol)
{
  if (NILP (symbol))
    return RANGE_START_CLOSED_END_OPEN;

  CHECK_SYMBOL (symbol);
  if (EQ (symbol, Qstart_closed_end_open))
    return RANGE_START_CLOSED_END_OPEN;
  if (EQ (symbol, Qstart_closed_end_closed))
    return RANGE_START_CLOSED_END_CLOSED;
  if (EQ (symbol, Qstart_open_end_open))
    return RANGE_START_OPEN_END_OPEN;
  if (EQ (symbol, Qstart_open_end_closed))
    return RANGE_START_OPEN_END_CLOSED;

  invalid_constant ("Unknown range table type", symbol);
  RETURN_NOT_REACHED (RANGE_START_CLOSED_END_OPEN);
}

static Lisp_Object
range_table_type_to_symbol (enum range_table_type type)
{
  switch (type)
    {
    case RANGE_START_CLOSED_END_OPEN:
      return Qstart_closed_end_open;
    case RANGE_START_CLOSED_END_CLOSED:
      return Qstart_closed_end_closed;
    case RANGE_START_OPEN_END_OPEN:
      return Qstart_open_end_open;
    case RANGE_START_OPEN_END_CLOSED:
      return Qstart_open_end_closed;
    }

  ABORT ();
  return Qnil;
}

/* We use a sorted array of ranges.

   #### We should be using the gap array stuff from extents.c.  This
   is not hard but just requires moving that stuff out of that file. */

static Lisp_Object
mark_range_table (Lisp_Object obj)
{
  Lisp_Range_Table *rt = XRANGE_TABLE (obj);
  int i;

  for (i = 0; i < gap_array_length (rt->entries); i++)
    mark_object (rangetab_gap_array_at (rt->entries, i).val);
  
  return Qnil;
}

static void
print_range_table (Lisp_Object obj, Lisp_Object printcharfun,
		   int UNUSED (escapeflag))
{
  Lisp_Range_Table *rt = XRANGE_TABLE (obj);
  int i;

  if (print_readably)
    write_fmt_string_lisp (printcharfun, "#s(range-table :type %s :data (",
			   1, range_table_type_to_symbol (rt->type));
  else
    write_ascstring (printcharfun, "#<range-table ");
  for (i = 0; i < gap_array_length (rt->entries); i++)
    {
      struct range_table_entry rte = rangetab_gap_array_at (rt->entries, i);
      int so, ec;
      if (i > 0)
	write_ascstring (printcharfun, " ");
      switch (rt->type)
	{
	case RANGE_START_CLOSED_END_OPEN: so = 0, ec = 0; break;
	case RANGE_START_CLOSED_END_CLOSED: so = 0, ec = 1; break;
	case RANGE_START_OPEN_END_OPEN: so = 1, ec = 0; break;
	case RANGE_START_OPEN_END_CLOSED: so = 1; ec = 1; break;
	default: ABORT (); so = 0, ec = 0; break;
	}
      write_fmt_string (printcharfun, "%c%ld %ld%c ",
			print_readably ? '(' : so ? '(' : '[',
			(long) (rte.first - so),
			(long) (rte.last - ec),
			print_readably ? ')' : ec ? ']' : ')'
			);
      print_internal (rte.val, printcharfun, 1);
    }
  if (print_readably)
    write_ascstring (printcharfun, "))");
  else
    write_fmt_string (printcharfun, " 0x%x>", LISP_OBJECT_UID (obj));
}

static void
range_table_print_preprocess (Lisp_Object object,
                              Lisp_Object print_number_table,
                              Elemcount *seen_object_count)
{
  Lisp_Range_Table *rt = XRANGE_TABLE (object);
  Elemcount ii;

  for (ii = 0; ii < gap_array_length (rt->entries); ii++)
    {
      struct range_table_entry *entry
        = gap_array_atp (rt->entries, ii, struct range_table_entry);
      PRINT_PREPROCESS (entry->val, print_number_table, seen_object_count);
    }
}

static void
range_table_nsubst_structures_descend (Lisp_Object new_, Lisp_Object old,
                                       Lisp_Object object,
                                       Lisp_Object number_table,
                                       Boolint test_not_unboundp)
{
  Lisp_Range_Table *rt = XRANGE_TABLE (object);
  Elemcount ii;

  /* We don't have to worry about the range table START and END values if
     we're limiting nsubst_descend to the Lisp reader; it's a similar case
     to the hash table test. */
  for (ii = 0; ii < gap_array_length (rt->entries); ii++)
    {
      struct range_table_entry *entry
	= gap_array_atp (rt->entries, ii, struct range_table_entry);

      if (EQ (old, entry->val) == test_not_unboundp)
	{
	  entry->val = new_;
	}
      else if (LRECORDP (entry->val) &&
               HAS_OBJECT_METH_P (entry->val, nsubst_structures_descend))
	{
	  nsubst_structures_descend (new_, old, entry->val, number_table,
				     test_not_unboundp);
	}
    }
}

static int
range_table_equal (Lisp_Object obj1, Lisp_Object obj2, int depth, int foldcase)
{
  Lisp_Range_Table *rt1 = XRANGE_TABLE (obj1);
  Lisp_Range_Table *rt2 = XRANGE_TABLE (obj2);
  int i;

  if (gap_array_length (rt1->entries) != gap_array_length (rt2->entries))
    return 0;

  for (i = 0; i < gap_array_length (rt1->entries); i++)
    {
      struct range_table_entry *rte1 =
	rangetab_gap_array_atp (rt1->entries, i);
      struct range_table_entry *rte2 =
	rangetab_gap_array_atp (rt2->entries, i);

      if (rte1->first != rte2->first
	  || rte1->last != rte2->last
	  || !internal_equal_0 (rte1->val, rte2->val, depth + 1, foldcase))
	return 0;
    }

  return 1;
}

static Hashcode
range_table_entry_hash (struct range_table_entry *rte, int depth,
                        Boolint equalp)
{
  return HASH3 (rte->first, rte->last,
                internal_hash (rte->val, depth + 1, equalp));
}

static Hashcode
range_table_hash (Lisp_Object obj, int depth, Boolint equalp)
{
  Lisp_Range_Table *rt = XRANGE_TABLE (obj);
  int i;
  int size = gap_array_length (rt->entries);
  Hashcode hash = size;

  /* approach based on internal_array_hash(). */
  if (size <= 5)
    {
      for (i = 0; i < size; i++)
	hash = HASH2 (hash,
		      range_table_entry_hash
		      (rangetab_gap_array_atp (rt->entries, i), depth, equalp));
      return hash;
    }

  /* just pick five elements scattered throughout the array.
     A slightly better approach would be to offset by some
     noise factor from the points chosen below. */
  for (i = 0; i < 5; i++)
    hash = HASH2 (hash,
		  range_table_entry_hash
		  (rangetab_gap_array_atp (rt->entries, i*size/5),
                   depth, equalp));
  return hash;
}

#ifndef NEW_GC

/* #### This leaks memory under NEW_GC.  To fix this, convert to Lisp object
   gap array. */

static void
finalize_range_table (Lisp_Object obj)
{
  Lisp_Range_Table *rt = XRANGE_TABLE (obj);
  if (rt->entries)
    {
      if (!DUMPEDP (rt->entries))
	free_gap_array (rt->entries);
      rt->entries = 0;
    }
}

#endif /* not NEW_GC */

static const struct memory_description rte_description_1[] = {
  { XD_LISP_OBJECT, offsetof (range_table_entry, val) },
  { XD_END }
};

static const struct sized_memory_description rte_description = {
  sizeof (range_table_entry),
  rte_description_1
};

static const struct memory_description rtega_description_1[] = {
  XD_GAP_ARRAY_DESC (&rte_description),
  { XD_END }
};

static const struct sized_memory_description rtega_description = {
  0, rtega_description_1
};

static const struct memory_description range_table_description[] = {
  { XD_BLOCK_PTR,  offsetof (Lisp_Range_Table, entries),  1,
    { &rtega_description } },
  { XD_END }
};

DEFINE_DUMPABLE_LISP_OBJECT ("range-table", range_table,
			     mark_range_table, print_range_table,
			     IF_OLD_GC (finalize_range_table),
			     range_table_equal, range_table_hash,
			     range_table_description,
			     Lisp_Range_Table);

/************************************************************************/
/*                        Range table operations                        */
/************************************************************************/

#ifdef ERROR_CHECK_STRUCTURES

static void
verify_range_table (Lisp_Range_Table *rt)
{
  int i;

  for (i = 0; i < gap_array_length (rt->entries); i++)
    {
      struct range_table_entry *rte = rangetab_gap_array_atp (rt->entries, i);
      assert (rte->last >= rte->first);
      if (i > 0)
	assert (rangetab_gap_array_at (rt->entries, i - 1).last <= rte->first);
    }
}

#else

#define verify_range_table(rt)

#endif

/* Locate the range table entry corresponding to the value POS, and return
   it.  If found, FOUNDP is set to 1 and the return value specifies an entry
   that encloses POS.  Otherwise, FOUNDP is set to 0 and the return value
   specifies where an entry that encloses POS would be inserted. */

static Elemcount
get_range_table_pos (Elemcount pos, Elemcount nentries,
		     struct range_table_entry *tab,
		     Elemcount gappos, Elemcount gapsize,
		     int *foundp)
{
  Elemcount left = 0, right = nentries;

  /* binary search for the entry.  Based on similar code in
     extent_list_locate(). */
  while (left != right)
    {
      /* RIGHT might not point to a valid entry (i.e. it's at the end
	 of the list), so NEWPOS must round down. */
      Elemcount newpos = (left + right) >> 1;
      struct range_table_entry *entry =
	tab + GAP_ARRAY_ARRAY_TO_MEMORY_POS_1 (newpos, gappos, gapsize);
      if (pos >= entry->last)
	left = newpos + 1;
      else if (pos < entry->first)
	right = newpos;
      else
	{
	  *foundp = 1;
	  return newpos;
	}
    }

  *foundp = 0;
  return left;
}

/* Look up in a range table without the gap array wrapper.
   Used also by the unified range table format. */

static Lisp_Object
get_range_table (Elemcount pos, Elemcount nentries,
		 struct range_table_entry *tab,
		 Elemcount gappos, Elemcount gapsize,
		 Lisp_Object default_)
{
  int foundp;
  Elemcount entrypos = get_range_table_pos (pos, nentries, tab, gappos,
					    gapsize, &foundp);
  if (foundp)
    {
      struct range_table_entry *entry =
	tab + GAP_ARRAY_ARRAY_TO_MEMORY_POS_1 (entrypos, gappos, gapsize);
      return entry->val;
    }

  return default_;
}

DEFUN ("range-table-p", Frange_table_p, 1, 1, 0, /*
Return non-nil if OBJECT is a range table.
*/
       (object))
{
  return RANGE_TABLEP (object) ? Qt : Qnil;
}

DEFUN ("range-table-type", Frange_table_type, 1, 1, 0, /*
Return the type of RANGE-TABLE.

This will be a symbol describing how ranges in RANGE-TABLE function at their
ends; see `make-range-table'.
*/
       (range_table))
{
  CHECK_RANGE_TABLE (range_table);
  return range_table_type_to_symbol (XRANGE_TABLE (range_table)->type);
}

DEFUN ("make-range-table", Fmake_range_table, 0, 1, 0, /*
Return a new, empty range table.
You can manipulate it using `put-range-table', `get-range-table',
`remove-range-table', and `clear-range-table'.
Range tables allow you to efficiently set values for ranges of integers.

 TYPE is a symbol indicating how ranges are assumed to function at their
 ends.  It can be one of
 
 SYMBOL                                     RANGE-START         RANGE-END
 ------                                     -----------         ---------
 `start-closed-end-open'  (the default)     closed              open
 `start-closed-end-closed'                  closed              closed
 `start-open-end-open'                      open                open
 `start-open-end-closed'                    open                closed
 
 A `closed' endpoint of a range means that the number at that end is included
 in the range.  For an `open' endpoint, the number would not be included.
 
 For example, a closed-open range from 5 to 20 would be indicated as [5,
 20) where a bracket indicates a closed end and a parenthesis an open end,
 and would mean `all the numbers between 5 and 20', including 5 but not 20.
 This seems a little strange at first but is in fact extremely common in
 the outside world as well as in computers and makes things work sensibly.
 For example, if I say "there are seven days between today and next week
 today", I'm including today but not next week today; if I included both,
 there would be eight days.  Similarly, there are 15 (= 20 - 5) elements in
 the range [5, 20), but 16 in the range [5, 20].
*/
       (type))
{
  Lisp_Object obj = ALLOC_NORMAL_LISP_OBJECT (range_table);
  Lisp_Range_Table *rt = XRANGE_TABLE (obj);
  rt->entries = make_gap_array (sizeof (struct range_table_entry), 0);
  rt->type = range_table_symbol_to_type (type);
  return obj;
}

DEFUN ("copy-range-table", Fcopy_range_table, 1, 1, 0, /*
Return a new range table which is a copy of RANGE-TABLE.
It will contain the same values for the same ranges as RANGE-TABLE.
The values will not themselves be copied.
*/
       (range_table))
{
  Lisp_Range_Table *rt, *rtnew;
  Lisp_Object obj;
  Elemcount i;

  CHECK_RANGE_TABLE (range_table);
  rt = XRANGE_TABLE (range_table);

  obj = ALLOC_NORMAL_LISP_OBJECT (range_table);
  rtnew = XRANGE_TABLE (obj);
  rtnew->entries = make_gap_array (sizeof (struct range_table_entry), 0);
  rtnew->type = rt->type;

  for (i = 0; i < gap_array_length (rt->entries); i++)
    rtnew->entries =
      gap_array_insert_els (rtnew->entries, i,
			    rangetab_gap_array_atp (rt->entries, i), 1);
  return obj;
}

DEFUN ("get-range-table", Fget_range_table, 2, 3, 0, /*
Find value for position POS in RANGE-TABLE.
If there is no corresponding value, return DEFAULT (defaults to nil).
*/
       (pos, range_table, default_))
{
  Lisp_Range_Table *rt;

  CHECK_RANGE_TABLE (range_table);
  rt = XRANGE_TABLE (range_table);

  CHECK_FIXNUM_COERCE_CHAR (pos);

  return get_range_table (XFIXNUM (pos), gap_array_length (rt->entries),
			  gap_array_begin (rt->entries,
					   struct range_table_entry),
			  gap_array_gappos (rt->entries),
			  gap_array_gapsize (rt->entries),
			  default_);
}

static void
external_to_internal_adjust_ends (enum range_table_type type,
				  EMACS_INT *first, EMACS_INT *last)
{
  /* Fix up the numbers in accordance with the open/closedness to make
     them behave like default open/closed. */
  switch (type)
    {
    case RANGE_START_CLOSED_END_OPEN: break;
    case RANGE_START_CLOSED_END_CLOSED: (*last)++; break;
    case RANGE_START_OPEN_END_OPEN: (*first)++; break;
    case RANGE_START_OPEN_END_CLOSED: (*first)++, (*last)++; break;
    }
}

static void
internal_to_external_adjust_ends (enum range_table_type type,
				  EMACS_INT *first, EMACS_INT *last)
{
  /* Reverse the changes made in external_to_internal_adjust_ends().
   */
  switch (type)
    {
    case RANGE_START_CLOSED_END_OPEN: break;
    case RANGE_START_CLOSED_END_CLOSED: (*last)--; break;
    case RANGE_START_OPEN_END_OPEN: (*first)--; break;
    case RANGE_START_OPEN_END_CLOSED: (*first)--, (*last)--; break;
    }
}

void
put_range_table (Lisp_Object table, EMACS_INT first,
		 EMACS_INT last, Lisp_Object val)
{
  int i;
  int insert_me_here = -1;
  Lisp_Range_Table *rt = XRANGE_TABLE (table);
  int foundp;

  external_to_internal_adjust_ends (rt->type, &first, &last);
  if (first == last)
    return;
  if (first > last)
    /* This will happen if originally first == last and both ends are
       open. #### Should we signal an error? */
    return;

  if (DUMPEDP (rt->entries))
    rt->entries = gap_array_clone (rt->entries);
  
  i = get_range_table_pos (first, gap_array_length (rt->entries),
			   gap_array_begin (rt->entries,
					    struct range_table_entry),
			   gap_array_gappos (rt->entries),
			   gap_array_gapsize (rt->entries), &foundp);

#ifdef ERROR_CHECK_TYPES
  if (foundp)
    {
      if (i < gap_array_length (rt->entries))
	{
	  struct range_table_entry *entry =
	    rangetab_gap_array_atp (rt->entries, i);
	  assert (first >= entry->first && first < entry->last);
	}
    }
  else
    {
      if (i < gap_array_length (rt->entries))
	{
	  struct range_table_entry *entry =
	    rangetab_gap_array_atp (rt->entries, i);
	  assert (first < entry->first);
	}
      if (i > 0)
	{
	  struct range_table_entry *entry =
	    rangetab_gap_array_atp (rt->entries, i - 1);
	  assert (first >= entry->last);
	}
    }
#endif /* ERROR_CHECK_TYPES */

  /* If the beginning of the new range isn't within any existing range,
     it might still be just grazing the end of an end-open range (remember,
     internally all ranges are start-close end-open); so back up one
     so we consider this range. */
  if (!foundp && i > 0)
    i--;
  
  /* Now insert in the proper place.  This gets tricky because
     we may be overlapping one or more existing ranges and need
     to fix them up. */

  /* First delete all sections of any existing ranges that overlap
     the new range. */
  for (; i < gap_array_length (rt->entries); i++)
    {
      struct range_table_entry *entry =
	rangetab_gap_array_atp (rt->entries, i);
      /* We insert before the first range that begins at or after the
	 new range. */
      if (entry->first >= first && insert_me_here < 0)
	insert_me_here = i;
      if (entry->last < first)
	/* completely before the new range. */
	continue;
      if (entry->first > last)
	/* completely after the new range.  No more possibilities of
	   finding overlapping ranges. */
	break;
      /* At this point the existing ENTRY overlaps or touches the new one. */
      if (entry->first < first && entry->last <= last)
	{
	  /* looks like:

	                 [ NEW )
                [ EXISTING )

	     or

	                 [ NEW )
              [ EXISTING )

	   */
	  /* truncate the end off of it. */
	  entry->last = first;
	}
      else if (entry->first < first && entry->last > last)
	/* looks like:

	         [ NEW )
	       [ EXISTING )

	 */
	/* need to split this one in two. */
	{
	  struct range_table_entry insert_me_too;

	  insert_me_too.first = last;
	  insert_me_too.last = entry->last;
	  insert_me_too.val = entry->val;
	  entry->last = first;
	  rt->entries =
	    gap_array_insert_els (rt->entries, i + 1, &insert_me_too, 1);
	}
      else if (entry->last >= last)
	{
	  /* looks like:

	       [ NEW )
                   [ EXISTING )

             or

	       [ NEW )
	             [ EXISTING )

	   */
	  /* truncate the start off of it. */
	  entry->first = last;
	}
      else
	{
	  /* existing is entirely within new. */
	  gap_array_delete_els (rt->entries, i, 1);
	  i--; /* back up since everything shifted one to the left. */
	}
    }

  /* Someone asked us to delete the range, not insert it. */
  if (UNBOUNDP (val))
    return;

  /* Now insert the new entry, maybe at the end. */

  if (insert_me_here < 0)
    insert_me_here = i;

  {
    struct range_table_entry insert_me;

    insert_me.first = first;
    insert_me.last = last;
    insert_me.val = val;

    rt->entries =
      gap_array_insert_els (rt->entries, insert_me_here, &insert_me, 1);
  }

  /* Now see if we can combine this entry with adjacent ones just
     before or after. */

  if (insert_me_here > 0)
    {
      struct range_table_entry *entry =
	rangetab_gap_array_atp (rt->entries, insert_me_here - 1);
      if (EQ (val, entry->val) && entry->last == first)
	{
	  entry->last = last;
	  gap_array_delete_els (rt->entries, insert_me_here, 1);
	  insert_me_here--;
	  /* We have morphed into a larger range.  Update our records
	     in case we also combine with the one after. */
	  first = entry->first;
	}
    }

  if (insert_me_here < gap_array_length (rt->entries) - 1)
    {
      struct range_table_entry *entry =
	rangetab_gap_array_atp (rt->entries, insert_me_here + 1);
      if (EQ (val, entry->val) && entry->first == last)
	{
	  entry->first = first;
	  gap_array_delete_els (rt->entries, insert_me_here, 1);
	}
    }
}

DEFUN ("put-range-table", Fput_range_table, 4, 4, 0, /*
Set the value for range START .. END to be VALUE in RANGE-TABLE.
*/
       (start, end, value, range_table))
{
  EMACS_INT first, last;

  CHECK_RANGE_TABLE (range_table);
  CHECK_FIXNUM_COERCE_CHAR (start);
  first = XFIXNUM (start);
  CHECK_FIXNUM_COERCE_CHAR (end);
  last = XFIXNUM (end);
  if (first > last)
    invalid_argument_2 ("start must be <= end", start, end);

  put_range_table (range_table, first, last, value);
  verify_range_table (XRANGE_TABLE (range_table));
  return Qnil;
}

DEFUN ("remove-range-table", Fremove_range_table, 3, 3, 0, /*
Remove the value for range START .. END in RANGE-TABLE.
*/
       (start, end, range_table))
{
  return Fput_range_table (start, end, Qunbound, range_table);
}

DEFUN ("clear-range-table", Fclear_range_table, 1, 1, 0, /*
Flush RANGE-TABLE.
*/
       (range_table))
{
  CHECK_RANGE_TABLE (range_table);
  gap_array_delete_all_els (XRANGE_TABLE (range_table)->entries);
  return Qnil;
}

DEFUN ("map-range-table", Fmap_range_table, 2, 2, 0, /*
Map FUNCTION over entries in RANGE-TABLE, calling it with three args,
the beginning and end of the range and the corresponding value.

Results are guaranteed to be correct (i.e. each entry processed
exactly once) if FUNCTION modifies or deletes the current entry
\(i.e. passes the current range to `put-range-table' or
`remove-range-table').  If FUNCTION modifies or deletes any other entry,
this guarantee doesn't hold.
*/
       (function, range_table))
{
  Lisp_Range_Table *rt;
  int i;

  CHECK_RANGE_TABLE (range_table);
  CHECK_FUNCTION (function);

  rt = XRANGE_TABLE (range_table);

  /* Do not "optimize" by pulling out the length computation below!
     FUNCTION may have changed the table. */
  for (i = 0; i < gap_array_length (rt->entries); i++)
    {
      struct range_table_entry entry =
	rangetab_gap_array_at (rt->entries, i);
      EMACS_INT first, last;
      Lisp_Object args[4];
      int oldlen;

    again:
      first = entry.first;
      last = entry.last;
      oldlen = gap_array_length (rt->entries);
      args[0] = function;
      /* Fix up the numbers in accordance with the open/closedness of the
	 table. */
      {
	EMACS_INT premier = first, dernier = last;
	internal_to_external_adjust_ends (rt->type, &premier, &dernier);
	args[1] = make_fixnum (premier);
	args[2] = make_fixnum (dernier);
      }
      args[3] = entry.val;
      Ffuncall (countof (args), args);
      /* Has FUNCTION removed the entry? */
      if (oldlen > gap_array_length (rt->entries)
	  && i < gap_array_length (rt->entries)
	  && (first != entry.first || last != entry.last))
	goto again;
      }

  return Qnil;
}


/************************************************************************/
/*                         Range table read syntax                      */
/************************************************************************/

static int
rangetab_type_validate (Lisp_Object UNUSED (keyword), Lisp_Object value,
			Error_Behavior UNUSED (errb))
{
  /* #### should deal with ERRB */
  range_table_symbol_to_type (value);
  return 1;
}

static int
rangetab_data_validate (Lisp_Object UNUSED (keyword), Lisp_Object value,
			Error_Behavior UNUSED (errb))
{
  /* #### should deal with ERRB */
  EXTERNAL_PROPERTY_LIST_LOOP_3 (range, data, value)
    {
      if (!FIXNUMP (range) && !CHARP (range)
	  && !(CONSP (range) && CONSP (XCDR (range))
	       && NILP (XCDR (XCDR (range)))
	       && (FIXNUMP (XCAR (range)) || CHARP (XCAR (range)))
	       && (FIXNUMP (XCAR (XCDR (range))) || CHARP (XCAR (XCDR (range))))))
	sferror ("Invalid range format", range);
    }

  return 1;
}

static Lisp_Object
rangetab_instantiate (Lisp_Object plist)
{
  Lisp_Object data = Qnil, type = Qnil, rangetab;

  if (KEYWORDP (Fcar (plist)))
    {
      PROPERTY_LIST_LOOP_3 (key, value, plist)
	{
	  if (EQ (key, Q_type)) type = value;
	  else if (EQ (key, Q_data)) data = value;
	  else if (!KEYWORDP (key))
            signal_error
	      (Qinvalid_read_syntax, 
	       "can't mix keyword and non-keyword structure syntax",
	       key);
	  else 
	    ABORT ();
	}
    }
#ifdef NEED_TO_HANDLE_21_4_CODE
  else
    {
      PROPERTY_LIST_LOOP_3 (key, value, plist)
	{
	  if (EQ (key, Qtype)) type = value;
	  else if (EQ (key, Qdata)) data = value;
	  else if (KEYWORDP (key))
            signal_error
	      (Qinvalid_read_syntax, 
	       "can't mix keyword and non-keyword structure syntax",
	       key);
	  else 
	    ABORT ();
	}
    }
#endif /* NEED_TO_HANDLE_21_4_CODE */

  rangetab = Fmake_range_table (type);

  {
    PROPERTY_LIST_LOOP_3 (range, val, data)
      {
	if (CONSP (range))
	  Fput_range_table (Fcar (range), Fcar (Fcdr (range)), val,
			    rangetab);
	else
	  Fput_range_table (range, range, val, rangetab);
      }
  }

  return rangetab;
}


/************************************************************************/
/*                         Unified range tables                         */
/************************************************************************/

/* A "unified range table" is a format for storing range tables
   as contiguous blocks of memory.  This is used by the regexp
   code, which needs to use range tables to properly handle []
   constructs in the presence of extended characters but wants to
   store an entire compiled pattern as a contiguous block of memory.

   Unified range tables are designed so that they can be placed
   at an arbitrary (possibly mis-aligned) place in memory.
   (Dealing with alignment is a pain in the ass.)

   WARNING: No provisions for garbage collection are currently made.
   This means that there must not be any Lisp objects in a unified
   range table that need to be marked for garbage collection.
   Good candidates for objects that can go into a range table are

   -- numbers and characters (do not need to be marked)
   -- nil, t (marked elsewhere)
   -- charsets and coding systems (automatically marked because
				   they are in a marked list,
				   and can't be removed)

   Good but slightly less so:

   -- symbols (could be uninterned, but that is not likely)

   Somewhat less good:

   -- buffers, frames, devices (could get deleted)


   It is expected that you work with range tables in the normal
   format and then convert to unified format when you are done
   making modifications.  As such, no functions are provided
   for modifying a unified range table.  The only operations
   you can do to unified range tables are

   -- look up a value
   -- retrieve all the ranges in an iterative fashion

*/

/* The format of a unified range table is as follows:

   -- The first byte contains the number of bytes to skip to find the
      actual start of the table.  This deals with alignment constraints,
      since the table might want to go at any arbitrary place in memory.
   -- The next three bytes contain the number of bytes to skip (from the
      *first* byte) to find the stuff after the table.  It's stored in
      little-endian format because that's how God intended things.  We don't
      necessarily start the stuff at the very end of the table because
      we want to have at least ALIGNOF (EMACS_INT) extra space in case
      we have to move the range table around. (It appears that some
      architectures don't maintain alignment when reallocing.)
   -- At the prescribed offset is a struct unified_range_table, containing
      some number of `struct range_table_entry' entries. */

struct unified_range_table
{
  int nentries;
  enum range_table_type type;
  struct range_table_entry first;
};

/* Return size in bytes needed to store the data in a range table. */

int
unified_range_table_bytes_needed (Lisp_Object rangetab)
{
  return (sizeof (struct range_table_entry) *
	  (gap_array_length (XRANGE_TABLE (rangetab)->entries) - 1) +
	  sizeof (struct unified_range_table) +
	  /* ALIGNOF a struct may be too big. */
	  /* We have four bytes for the size numbers, and an extra
	     four or eight bytes for making sure we get the alignment
	     OK. */
	  ALIGNOF (EMACS_INT) + 4);
}

/* Convert a range table into unified format and store in DEST,
   which must be able to hold the number of bytes returned by
   range_table_bytes_needed(). */

void
unified_range_table_copy_data (Lisp_Object rangetab, void *dest)
{
  /* We cast to the above structure rather than just casting to
     char * and adding sizeof(int), because that will lead to
     mis-aligned data on the Alpha machines. */
  struct unified_range_table *un;
  Gap_Array *rtega = XRANGE_TABLE (rangetab)->entries;
  int total_needed = unified_range_table_bytes_needed (rangetab);
  void *new_dest = ALIGN_PTR ((char *) dest + 4, EMACS_INT);
  Elemcount i;

  * (char *) dest = (char) ((char *) new_dest - (char *) dest);
  * ((unsigned char *) dest + 1) = total_needed & 0xFF;
  total_needed >>= 8;
  * ((unsigned char *) dest + 2) = total_needed & 0xFF;
  total_needed >>= 8;
  * ((unsigned char *) dest + 3) = total_needed & 0xFF;
  un = (struct unified_range_table *) new_dest;
  un->nentries = gap_array_length (rtega);
  un->type = XRANGE_TABLE (rangetab)->type;
  for (i = 0; i < gap_array_length (rtega); i++)
    (&un->first)[i] = rangetab_gap_array_at (rtega, i);
}

/* Return number of bytes actually used by a unified range table. */

int
unified_range_table_bytes_used (void *unrangetab)
{
  return ((* ((unsigned char *) unrangetab + 1))
	  + ((* ((unsigned char *) unrangetab + 2)) << 8)
	  + ((* ((unsigned char *) unrangetab + 3)) << 16));
}

/* Make sure the table is aligned, and move it around if it's not. */
static void
align_the_damn_table (void *unrangetab)
{
  void *cur_dest = (char *) unrangetab + * (char *) unrangetab;
  if (cur_dest != ALIGN_PTR (cur_dest, EMACS_INT))
    {
      int count = (unified_range_table_bytes_used (unrangetab) - 4
		   - ALIGNOF (EMACS_INT));
      /* Find the proper location, just like above. */
      void *new_dest = ALIGN_PTR ((char *) unrangetab + 4, EMACS_INT);
      /* memmove() works in the presence of overlapping data. */
      memmove (new_dest, cur_dest, count);
      * (char *) unrangetab = (char) ((char *) new_dest - (char *) unrangetab);
    }
}

/* Look up a value in a unified range table. */

Lisp_Object
unified_range_table_lookup (void *unrangetab, EMACS_INT pos,
			    Lisp_Object default_)
{
  void *new_dest;
  struct unified_range_table *un;

  align_the_damn_table (unrangetab);
  new_dest = (char *) unrangetab + * (char *) unrangetab;
  un = (struct unified_range_table *) new_dest;

  return get_range_table (pos, un->nentries, &un->first, 0, 0, default_);
}

/* Return number of entries in a unified range table. */

int
unified_range_table_nentries (void *unrangetab)
{
  void *new_dest;
  struct unified_range_table *un;

  align_the_damn_table (unrangetab);
  new_dest = (char *) unrangetab + * (char *) unrangetab;
  un = (struct unified_range_table *) new_dest;
  return un->nentries;
}

/* Return the OFFSETth range (counting from 0) in UNRANGETAB. */
void
unified_range_table_get_range (void *unrangetab, int offset,
			       EMACS_INT *min, EMACS_INT *max,
			       Lisp_Object *val)
{
  void *new_dest;
  struct unified_range_table *un;
  struct range_table_entry *tab;

  align_the_damn_table (unrangetab);
  new_dest = (char *) unrangetab + * (char *) unrangetab;
  un = (struct unified_range_table *) new_dest;

  assert (offset >= 0 && offset < un->nentries);
  tab = (&un->first) + offset;
  *min = tab->first;
  *max = tab->last;
  *val = tab->val;

  internal_to_external_adjust_ends (un->type, min, max);
}


/************************************************************************/
/*                            Initialization                            */
/************************************************************************/
void
rangetab_objects_create (void)
{
  OBJECT_HAS_METHOD (range_table, print_preprocess);
  OBJECT_HAS_METHOD (range_table, nsubst_structures_descend);
}

void
syms_of_rangetab (void)
{
  INIT_LISP_OBJECT (range_table);

  DEFSYMBOL_MULTIWORD_PREDICATE (Qrange_tablep);
  DEFSYMBOL (Qrange_table);

  DEFSYMBOL (Qstart_closed_end_open);
  DEFSYMBOL (Qstart_open_end_open);
  DEFSYMBOL (Qstart_closed_end_closed);
  DEFSYMBOL (Qstart_open_end_closed);

  DEFSUBR (Frange_table_p);
  DEFSUBR (Frange_table_type);
  DEFSUBR (Fmake_range_table);
  DEFSUBR (Fcopy_range_table);
  DEFSUBR (Fget_range_table);
  DEFSUBR (Fput_range_table);
  DEFSUBR (Fremove_range_table);
  DEFSUBR (Fclear_range_table);
  DEFSUBR (Fmap_range_table);
}

void
structure_type_create_rangetab (void)
{
  struct structure_type *st;

  st = define_structure_type (Qrange_table, 0, rangetab_instantiate);

  define_structure_type_keyword (st, Q_data, rangetab_data_validate);
  define_structure_type_keyword (st, Q_type, rangetab_type_validate);
#ifdef NEED_TO_HANDLE_21_4_CODE
  define_structure_type_keyword (st, Qdata, rangetab_data_validate);
  define_structure_type_keyword (st, Qtype, rangetab_type_validate);
#endif /* NEED_TO_HANDLE_21_4_CODE */
}
