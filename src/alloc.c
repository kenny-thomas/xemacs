/* Storage allocation and gc for XEmacs Lisp interpreter.
   Copyright (C) 1985-1998 Free Software Foundation, Inc.
   Copyright (C) 1995 Sun Microsystems, Inc.
   Copyright (C) 1995, 1996, 2001, 2002, 2003, 2004, 2005, 2010 Ben Wing.

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

/* Synched up with: FSF 19.28, Mule 2.0.  Substantially different from
   FSF. */

/* Authorship:

   FSF: Original version; a long time ago.
   Mly: Significantly rewritten to use new 3-bit tags and
        nicely abstracted object definitions, for 19.8.
   JWZ: Improved code to keep track of purespace usage and
        issue nice purespace and GC stats.
   Ben Wing: Cleaned up frob-block lrecord code, added error-checking
        and various changes for Mule, for 19.12.
        Added bit vectors for 19.13.
	Added lcrecord lists for 19.14.
   slb: Lots of work on the purification and dump time code.
        Synched Doug Lea malloc support from Emacs 20.2.
   og:  Killed the purespace.  Portable dumper (moved to dumper.c)
*/

#include <config.h>
#include "lisp.h"

#include "backtrace.h"
#include "buffer.h"
#include "bytecode.h"
#include "chartab.h"
#include "device.h"
#include "elhash.h"
#include "events.h"
#include "extents-impl.h"
#include "file-coding.h"
#include "frame-impl.h"
#include "gc.h"
#include "glyphs.h"
#include "opaque.h"
#include "lstream.h"
#include "process.h"
#include "profile.h"
#include "redisplay.h"
#include "specifier.h"
#include "sysfile.h"
#include "sysdep.h"
#include "window.h"
#ifdef NEW_GC
#include "vdb.h"
#endif /* NEW_GC */
#include "console-stream.h"

#ifdef DOUG_LEA_MALLOC
#include <malloc.h>
#endif
#ifdef USE_VALGRIND
#include <valgrind/memcheck.h>
#endif

EXFUN (Fgarbage_collect, 0);

#if 0 /* this is _way_ too slow to be part of the standard debug options */
#if defined(DEBUG_XEMACS) && defined(MULE)
#define VERIFY_STRING_CHARS_INTEGRITY
#endif
#endif

/* Define this to use malloc/free with no freelist for all datatypes,
   the hope being that some debugging tools may help detect
   freed memory references */
#ifdef USE_DEBUG_MALLOC	/* Taking the above comment at face value -slb */
#include <dmalloc.h>
#define ALLOC_NO_POOLS
#endif

#ifdef DEBUG_XEMACS
static Fixnum debug_allocation;
static Fixnum debug_allocation_backtrace_length;
#endif

Fixnum Varray_dimension_limit, Varray_total_size_limit, Varray_rank_limit;

int need_to_check_c_alloca;
int need_to_signal_post_gc;
int funcall_allocation_flag;
Bytecount __temp_alloca_size__;
Bytecount funcall_alloca_count;

/* All the built-in lisp object types are enumerated in `enum lrecord_type'.
   Additional ones may be defined by a module (none yet).  We leave some
   room in `lrecord_implementations_table' for such new lisp object types. */
struct lrecord_implementation *lrecord_implementations_table[(int)lrecord_type_last_built_in_type + MODULE_DEFINABLE_TYPE_COUNT];
int lrecord_type_count = lrecord_type_last_built_in_type;

/* This is just for use by the printer, to allow things to print uniquely.
   We have a separate UID space for each object. (Important because the
   UID is only 20 bits in old-GC, and 22 in NEW_GC.) */
int lrecord_uid_counter[countof (lrecord_implementations_table)];

#ifndef USE_KKCC
/* Object marker functions are in the lrecord_implementation structure.
   But copying them to a parallel array is much more cache-friendly.
   This hack speeds up (garbage-collect) by about 5%. */
Lisp_Object (*lrecord_markers[countof (lrecord_implementations_table)]) (Lisp_Object);
#endif /* not USE_KKCC */

struct gcpro *gcprolist;

/* Non-zero means we're in the process of doing the dump */
int purify_flag;

/* Non-zero means we're pdumping out or in */
#ifdef PDUMP
int in_pdump;
#endif

#ifdef ERROR_CHECK_TYPES

Error_Behavior ERROR_ME, ERROR_ME_NOT, ERROR_ME_WARN, ERROR_ME_DEBUG_WARN;

#endif

#ifdef MEMORY_USAGE_STATS
Lisp_Object Qobject_actually_requested, Qobject_malloc_overhead;
Lisp_Object Qother_memory_actually_requested, Qother_memory_malloc_overhead;
Lisp_Object Qother_memory_dynarr_overhead, Qother_memory_gap_overhead;
#endif /* MEMORY_USAGE_STATS */

#ifndef NEW_GC
static int gc_count_num_short_string_in_use;
static Bytecount gc_count_string_total_size;
static Bytecount gc_count_short_string_total_size;
static Bytecount gc_count_long_string_storage_including_overhead;
#endif /* not NEW_GC */

/* static int gc_count_total_records_used, gc_count_records_total_size; */

/* stats on objects in use */

#ifdef NEW_GC

static struct
{
  int instances_in_use;
  int bytes_in_use;
  int bytes_in_use_including_overhead;
} lrecord_stats [countof (lrecord_implementations_table)];

#else /* not NEW_GC */

static struct
{
  Elemcount instances_in_use;
  Bytecount bytes_in_use;
  Bytecount bytes_in_use_overhead;
  Elemcount instances_freed;
  Bytecount bytes_freed;
  Bytecount bytes_freed_overhead;
  Elemcount instances_on_free_list;
  Bytecount bytes_on_free_list;
  Bytecount bytes_on_free_list_overhead;
#ifdef MEMORY_USAGE_STATS
  Bytecount nonlisp_bytes_in_use;
  Bytecount lisp_ancillary_bytes_in_use;
  struct generic_usage_stats stats;
#endif
} lrecord_stats [countof (lrecord_implementations_table)];

#endif /* (not) NEW_GC */

/* Very cheesy ways of figuring out how much memory is being used for
   data. #### Need better (system-dependent) ways. */
void *minimum_address_seen;
void *maximum_address_seen;


/************************************************************************/
/*                         Low-level allocation                         */
/************************************************************************/

void
recompute_funcall_allocation_flag (void)
{
  funcall_allocation_flag =
    need_to_garbage_collect ||
    need_to_check_c_alloca ||
    need_to_signal_post_gc;
}

/* Maximum amount of C stack to save when a GC happens.  */

#ifndef MAX_SAVE_STACK
#define MAX_SAVE_STACK 0 /* 16000 */
#endif

/* Non-zero means ignore malloc warnings.  Set during initialization.  */
int ignore_malloc_warnings;


#ifndef NEW_GC
void *breathing_space;

void
release_breathing_space (void)
{
  if (breathing_space)
    {
      void *tmp = breathing_space;
      breathing_space = 0;
      xfree (tmp);
    }
}

#if !defined(HAVE_MMAP) || defined(DOUG_LEA_MALLOC)
/* If we released our reserve (due to running out of memory),
   and we have a fair amount free once again,
   try to set aside another reserve in case we run out once more.

   This is called when a relocatable block is freed in ralloc.c.  */
void refill_memory_reserve (void);
void
refill_memory_reserve (void)
{
  if (breathing_space == 0)
    breathing_space = (char *) malloc (4096 - MALLOC_OVERHEAD);
}
#endif /* !defined(HAVE_MMAP) || defined(DOUG_LEA_MALLOC) */

#endif /* not NEW_GC */

static void
set_alloc_mins_and_maxes (void *val, Bytecount size)
{
  if (!val)
    return;
  if ((char *) val + size > (char *) maximum_address_seen)
    maximum_address_seen = (char *) val + size;
  if (!minimum_address_seen)
    minimum_address_seen =
#if SIZEOF_VOID_P == 8
      (void *) 0xFFFFFFFFFFFFFFFF;
#else
      (void *) 0xFFFFFFFF;
#endif
  if ((char *) val < (char *) minimum_address_seen)
    minimum_address_seen = (char *) val;
}

#ifdef ERROR_CHECK_MALLOC
static int in_malloc;
extern int regex_malloc_disallowed;

#define MALLOC_BEGIN()				\
do						\
{						\
  assert (!in_malloc);				\
  assert (!regex_malloc_disallowed);		\
  in_malloc = 1;				\
}						\
while (0)

#ifdef NEW_GC
#define FREE_OR_REALLOC_BEGIN(block)					\
do									\
{									\
  /* Unbelievably, calling free() on 0xDEADBEEF doesn't cause an	\
     error until much later on for many system mallocs, such as		\
     the one that comes with Solaris 2.3.  FMH!! */			\
  assert (block != (void *) DEADBEEF_CONSTANT);				\
  MALLOC_BEGIN ();							\
}									\
while (0)
#else /* not NEW_GC */
#define FREE_OR_REALLOC_BEGIN(block)					\
do									\
{									\
  /* Unbelievably, calling free() on 0xDEADBEEF doesn't cause an	\
     error until much later on for many system mallocs, such as		\
     the one that comes with Solaris 2.3.  FMH!! */			\
  assert (block != (void *) DEADBEEF_CONSTANT);				\
  /* You cannot free something within dumped space, because there is	\
     no longer any sort of malloc structure associated with the block.	\
     If you are tripping this, you may need to conditionalize on	\
     DUMPEDP. */							\
  assert (!DUMPEDP (block));						\
  MALLOC_BEGIN ();							\
}									\
while (0)
#endif /* not NEW_GC */

#define MALLOC_END()				\
do						\
{						\
  in_malloc = 0;				\
}						\
while (0)

#else /* ERROR_CHECK_MALLOC */

#define MALLOC_BEGIN()
#define FREE_OR_REALLOC_BEGIN(block)
#define MALLOC_END()

#endif /* ERROR_CHECK_MALLOC */

static void
malloc_after (void *val, Bytecount size)
{
  if (!val && size != 0)
    memory_full ();
  set_alloc_mins_and_maxes (val, size);
}

/* malloc calls this if it finds we are near exhausting storage */
void
malloc_warning (const char *str)
{
  if (ignore_malloc_warnings)
    return;

  /* Remove the malloc lock here, because warn_when_safe may allocate
     again.  It is safe to remove the malloc lock here, because malloc
     is already finished (malloc_warning is called via
     after_morecore_hook -> check_memory_limits -> save_warn_fun ->
     malloc_warning). */
  MALLOC_END ();

  warn_when_safe
    (Qmemory, Qemergency,
     "%s\n"
     "Killing some buffers may delay running out of memory.\n"
     "However, certainly by the time you receive the 95%% warning,\n"
     "you should clean up, kill this Emacs, and start a new one.",
     str);
}

/* Called if malloc returns zero */
DOESNT_RETURN
memory_full (void)
{
  /* Force a GC next time eval is called.
     It's better to loop garbage-collecting (we might reclaim enough
     to win) than to loop beeping and barfing "Memory exhausted"
   */
  consing_since_gc = gc_cons_threshold + 1;
  recompute_need_to_garbage_collect ();
#ifdef NEW_GC
  /* Put mc-alloc into memory shortage mode.  This may keep XEmacs
     alive until the garbage collector can free enough memory to get
     us out of the memory exhaustion.  If already in memory shortage
     mode, we are in a loop and hopelessly lost. */
  if (memory_shortage) 
    {
      fprintf (stderr, "Memory full, cannot recover.\n");
      ABORT ();
    }
  fprintf (stderr, 
	   "Memory full, try to recover.\n"
	   "You should clean up, kill this Emacs, and start a new one.\n");
  memory_shortage++;
#else /* not NEW_GC */
  release_breathing_space ();
#endif /* not NEW_GC */

  /* Flush some histories which might conceivably contain garbalogical
     inhibitors.  */
  if (!NILP (Fboundp (Qvalues)))
    Fset (Qvalues, Qnil);
  Vcommand_history = Qnil;

  out_of_memory ("Memory exhausted", Qunbound);
}

/* like malloc, calloc, realloc, free but:

   -- check for no memory left
   -- set internal mins and maxes
   -- with error-checking on, check for reentrancy, invalid freeing, etc.
*/

#undef xmalloc
void *
xmalloc (Bytecount size)
{
  void *val;
  MALLOC_BEGIN ();
  val = malloc (size);
  MALLOC_END ();
  malloc_after (val, size);
  return val;
}

#undef xcalloc
static void *
xcalloc (Elemcount nelem, Bytecount elsize)
{
  void *val;
  MALLOC_BEGIN ();
  val= calloc (nelem, elsize);
  MALLOC_END ();
  malloc_after (val, nelem * elsize);
  return val;
}

void *
xmalloc_and_zero (Bytecount size)
{
  return xcalloc (size, sizeof (char));
}

#undef xrealloc
void *
xrealloc (void *block, Bytecount size)
{
  FREE_OR_REALLOC_BEGIN (block);
  block = realloc (block, size);
  MALLOC_END ();
  malloc_after (block, size);
  return block;
}

void
xfree_1 (void *block)
{
#ifdef ERROR_CHECK_MALLOC
  assert (block);
#endif /* ERROR_CHECK_MALLOC */
  FREE_OR_REALLOC_BEGIN (block);
  free (block);
  MALLOC_END ();
}

void
deadbeef_memory (void *ptr, Bytecount size)
{
  UINT_32_BIT *ptr4 = (UINT_32_BIT *) ptr;
  Bytecount beefs = size >> 2;

  /* In practice, size will always be a multiple of four.  */
  while (beefs--)
    (*ptr4++) = 0xDEADBEEF; /* -559038737 base 10 */
}

#undef xstrdup
char *
xstrdup (const char *str)
{
  int len = strlen (str) + 1;   /* for stupid terminating 0 */
  void *val = xmalloc (len);

  if (val == 0) return 0;
  return (char *) memcpy (val, str, len);
}

#ifdef NEED_STRDUP
char *
strdup (const char *s)
{
  return xstrdup (s);
}
#endif /* NEED_STRDUP */


/************************************************************************/
/*                        Lisp object allocation                        */
/************************************************************************/

/* Determine now whether we need to garbage collect or not, to make
   Ffuncall() faster */
#define INCREMENT_CONS_COUNTER_1(size)		\
do						\
{						\
  consing_since_gc += (size);			\
  total_consing += (size);			\
  if (profiling_active)				\
    profile_record_consing (size);		\
  recompute_need_to_garbage_collect ();		\
} while (0)

#define debug_allocation_backtrace()				\
do {								\
  if (debug_allocation_backtrace_length > 0)			\
    debug_short_backtrace (debug_allocation_backtrace_length);	\
} while (0)

#ifdef DEBUG_XEMACS
#define INCREMENT_CONS_COUNTER(foosize, type)		\
  do {							\
    if (debug_allocation)				\
      {							\
	stderr_out ("allocating %s (size %ld)\n", type,	\
		    (long) foosize);			\
	debug_allocation_backtrace ();			\
      }							\
    INCREMENT_CONS_COUNTER_1 (foosize);			\
  } while (0)
#define NOSEEUM_INCREMENT_CONS_COUNTER(foosize, type)		\
  do {								\
    if (debug_allocation > 1)					\
      {								\
	stderr_out ("allocating noseeum %s (size %ld)\n", type,	\
		    (long) foosize);				\
	debug_allocation_backtrace ();				\
      }								\
    INCREMENT_CONS_COUNTER_1 (foosize);				\
  } while (0)
#else
#define INCREMENT_CONS_COUNTER(size, type) INCREMENT_CONS_COUNTER_1 (size)
#define NOSEEUM_INCREMENT_CONS_COUNTER(size, type) \
  INCREMENT_CONS_COUNTER_1 (size)
#endif

#ifdef NEW_GC
/* [[ The call to recompute_need_to_garbage_collect is moved to
   free_normal_lisp_object, since DECREMENT_CONS_COUNTER is extensively called
   during sweep and recomputing need_to_garbage_collect all the time
   is not needed. ]] -- not accurate! */
#define DECREMENT_CONS_COUNTER(size) do {	\
  consing_since_gc -= (size);			\
  total_consing -= (size);			\
  if (profiling_active)				\
    profile_record_unconsing (size);		\
  if (consing_since_gc < 0)			\
    consing_since_gc = 0;			\
} while (0)
#else /* not NEW_GC */
#define DECREMENT_CONS_COUNTER(size) do {	\
  consing_since_gc -= (size);			\
  total_consing -= (size);			\
  if (profiling_active)				\
    profile_record_unconsing (size);		\
  if (consing_since_gc < 0)			\
    consing_since_gc = 0;			\
  recompute_need_to_garbage_collect ();		\
} while (0)
#endif /*not NEW_GC */

#ifndef NEW_GC
static void *
allocate_lisp_storage (Bytecount size)
{
  void *val = xmalloc (size);
  /* We don't increment the cons counter anymore.  Calling functions do
     that now because we have two different kinds of cons counters -- one
     for normal objects, and one for no-see-um conses (and possibly others
     similar) where the conses are used totally internally, never escape,
     and are created and then freed and shouldn't logically increment the
     cons counting. #### (Or perhaps, we should decrement it when an object
     get freed?)  */

  /* But we do now (as of 3-27-02) go and zero out the memory.  This is a
     good thing, as it will guarantee we won't get any intermittent bugs
     coming from an uninitiated field.  The speed loss is unnoticeable,
     esp. as the objects are not large -- large stuff like buffer text and
     redisplay structures are allocated separately. */
  memset (val, 0, size);

  if (need_to_check_c_alloca)
    xemacs_c_alloca (0);

  return val;
}
#endif /* not NEW_GC */

#define assert_proper_sizing(size)			\
  type_checking_assert					\
    (implementation->static_size == 0 ?			\
     implementation->size_in_bytes_method != NULL :	\
     implementation->size_in_bytes_method == NULL &&	\
     implementation->static_size == size)

#ifndef NEW_GC
/* lcrecords are chained together through their "next" field.
   After doing the mark phase, GC will walk this linked list
   and free any lcrecord which hasn't been marked. */
static struct old_lcrecord_header *all_lcrecords;
#endif /* not NEW_GC */

#ifdef NEW_GC
/* The basic lrecord allocation functions. See lrecord.h for details. */
static Lisp_Object
alloc_sized_lrecord_1 (Bytecount size,
		       const struct lrecord_implementation *implementation,
		       int noseeum)
{
  struct lrecord_header *lheader;

  assert_proper_sizing (size);

  lheader = (struct lrecord_header *) mc_alloc (size);
  gc_checking_assert (LRECORD_FREE_P (lheader));
  set_lheader_implementation (lheader, implementation);
#ifdef ALLOC_TYPE_STATS
  inc_lrecord_stats (size, lheader);
#endif /* ALLOC_TYPE_STATS */
  if (implementation->finalizer)
    add_finalizable_obj (wrap_pointer_1 (lheader));
  if (noseeum)
    NOSEEUM_INCREMENT_CONS_COUNTER (size, implementation->name);
  else
    INCREMENT_CONS_COUNTER (size, implementation->name);
  return wrap_pointer_1 (lheader);
}

Lisp_Object
alloc_sized_lrecord (Bytecount size,
		     const struct lrecord_implementation *implementation)
{
  return alloc_sized_lrecord_1 (size, implementation, 0);
}

Lisp_Object
noseeum_alloc_sized_lrecord (Bytecount size,
			     const struct lrecord_implementation *
			     implementation)
{
  return alloc_sized_lrecord_1 (size, implementation, 1);
}

Lisp_Object
alloc_lrecord (const struct lrecord_implementation *implementation)
{
  type_checking_assert (implementation->static_size > 0);
  return alloc_sized_lrecord (implementation->static_size, implementation);
}

Lisp_Object
noseeum_alloc_lrecord (const struct lrecord_implementation *implementation)
{
  type_checking_assert (implementation->static_size > 0);
  return noseeum_alloc_sized_lrecord (implementation->static_size, implementation);
}

Lisp_Object
alloc_sized_lrecord_array (Bytecount size, int elemcount,
			   const struct lrecord_implementation *implementation)
{
  struct lrecord_header *lheader;
  Rawbyte *start, *stop;

  assert_proper_sizing (size);

  lheader = (struct lrecord_header *) mc_alloc_array (size, elemcount);
  gc_checking_assert (LRECORD_FREE_P (lheader));

  for (start = (Rawbyte *) lheader, 
	 /* #### FIXME: why is this -1 present? */
	 stop = ((Rawbyte *) lheader) + (size * elemcount -1);
       start < stop; start += size)
    {
      struct lrecord_header *lh = (struct lrecord_header *) start;
      set_lheader_implementation (lh, implementation);
#ifdef ALLOC_TYPE_STATS
      inc_lrecord_stats (size, lh);
#endif /* not ALLOC_TYPE_STATS */
      if (implementation->finalizer)
	add_finalizable_obj (wrap_pointer_1 (lh));
    }

  INCREMENT_CONS_COUNTER (size * elemcount, implementation->name);
  return wrap_pointer_1 (lheader);
}

Lisp_Object
alloc_lrecord_array (int elemcount,
		     const struct lrecord_implementation *implementation)
{
  type_checking_assert (implementation->static_size > 0);
  return alloc_sized_lrecord_array (implementation->static_size, elemcount,
				    implementation);
}

#else /* not NEW_GC */

/* The most basic of the lcrecord allocation functions.  Not usually called
   directly.  Allocates an lrecord not managed by any lcrecord-list, of a
   specified size.  See lrecord.h. */

Lisp_Object
old_alloc_sized_lcrecord (Bytecount size,
			  const struct lrecord_implementation *implementation)
{
  struct old_lcrecord_header *lcheader;

  assert_proper_sizing (size);
  type_checking_assert
    (!implementation->frob_block_p
     &&
     !(implementation->hash == NULL && implementation->equal != NULL));

  lcheader = (struct old_lcrecord_header *) allocate_lisp_storage (size);
  set_lheader_implementation (&lcheader->lheader, implementation);
  lcheader->next = all_lcrecords;
  all_lcrecords = lcheader;
  INCREMENT_CONS_COUNTER (size, implementation->name);
  return wrap_pointer_1 (lcheader);
}

Lisp_Object
old_alloc_lcrecord (const struct lrecord_implementation *implementation)
{
  type_checking_assert (implementation->static_size > 0);
  return old_alloc_sized_lcrecord (implementation->static_size,
				   implementation);
}

#if 0 /* Presently unused */
/* Very, very poor man's EGC?
 * This may be slow and thrash pages all over the place.
 *  Only call it if you really feel you must (and if the
 *  lrecord was fairly recently allocated).
 * Otherwise, just let the GC do its job -- that's what it's there for
 */
void
very_old_free_lcrecord (struct old_lcrecord_header *lcrecord)
{
  if (all_lcrecords == lcrecord)
    {
      all_lcrecords = lcrecord->next;
    }
  else
    {
      struct old_lcrecord_header *header = all_lcrecords;
      for (;;)
	{
	  struct old_lcrecord_header *next = header->next;
	  if (next == lcrecord)
	    {
	      header->next = lrecord->next;
	      break;
	    }
	  else if (next == 0)
	    ABORT ();
	  else
	    header = next;
	}
    }
  if (lrecord->implementation->finalizer)
    lrecord->implementation->finalizer (wrap_pointer_1 (lrecord));
  xfree (lrecord);
  return;
}
#endif /* Unused */
#endif /* not NEW_GC */

/* Bitwise copy all parts of a Lisp object other than the header */

void
copy_lisp_object (Lisp_Object dst, Lisp_Object src)
{
  const struct lrecord_implementation *imp =
    XRECORD_LHEADER_IMPLEMENTATION (src);
  Bytecount size = lisp_object_size (src);

  assert (imp == XRECORD_LHEADER_IMPLEMENTATION (dst));
  assert (size == lisp_object_size (dst));

#ifdef NEW_GC
  memcpy ((char *) XRECORD_LHEADER (dst) + sizeof (struct lrecord_header),
	  (char *) XRECORD_LHEADER (src) + sizeof (struct lrecord_header),
	  size - sizeof (struct lrecord_header));
#else /* not NEW_GC */
  if (imp->frob_block_p)
    memcpy ((char *) XRECORD_LHEADER (dst) + sizeof (struct lrecord_header),
	    (char *) XRECORD_LHEADER (src) + sizeof (struct lrecord_header),
	    size - sizeof (struct lrecord_header));
  else
    memcpy ((char *) XRECORD_LHEADER (dst) +
	    sizeof (struct old_lcrecord_header),
	    (char *) XRECORD_LHEADER (src) +
	    sizeof (struct old_lcrecord_header),
	    size - sizeof (struct old_lcrecord_header));
#endif /* not NEW_GC */
}

/* Zero out all parts of a Lisp object other than the header, for a
   variable-sized object.  The size needs to be given explicitly because
   at the time this is called, the contents of the object may not be
   defined, or may not be set up in such a way that we can reliably
   retrieve the size, since it may depend on settings inside of the object. */

void
zero_sized_lisp_object (Lisp_Object obj, Bytecount size)
{
#ifndef NEW_GC
  const struct lrecord_implementation *imp =
    XRECORD_LHEADER_IMPLEMENTATION (obj);
#endif /* not NEW_GC */

#ifdef NEW_GC
  memset ((char *) XRECORD_LHEADER (obj) + sizeof (struct lrecord_header), 0,
	  size - sizeof (struct lrecord_header));
#else /* not NEW_GC */
  if (imp->frob_block_p)
    memset ((char *) XRECORD_LHEADER (obj) + sizeof (struct lrecord_header), 0,
	    size - sizeof (struct lrecord_header));
  else
    memset ((char *) XRECORD_LHEADER (obj) +
	    sizeof (struct old_lcrecord_header), 0,
	    size - sizeof (struct old_lcrecord_header));
#endif /* not NEW_GC */
}

/* Zero out all parts of a Lisp object other than the header, for an object
   that isn't variable-size.  Objects that are variable-size need to use
   zero_sized_lisp_object().
  */

void
zero_nonsized_lisp_object (Lisp_Object obj)
{
  const struct lrecord_implementation *imp =
    XRECORD_LHEADER_IMPLEMENTATION (obj);
  assert (!imp->size_in_bytes_method);

  zero_sized_lisp_object (obj, lisp_object_size (obj));
}

#ifdef NEW_GC
void
free_normal_lisp_object (Lisp_Object UNUSED(obj))
{
  /* Manual frees are not allowed with asynchronous finalization */
  return;
}
#else
void
free_normal_lisp_object (Lisp_Object obj)
{
  const struct lrecord_implementation *imp =
    XRECORD_LHEADER_IMPLEMENTATION (obj);

  assert (!imp->frob_block_p);
  assert (!imp->size_in_bytes_method);
  old_free_lcrecord (obj);
}
#endif

#ifndef NEW_GC
int
c_readonly (Lisp_Object obj)
{
  return POINTER_TYPE_P (XTYPE (obj)) && C_READONLY (obj);
}
#endif /* not NEW_GC */

int
lisp_readonly (Lisp_Object obj)
{
  return POINTER_TYPE_P (XTYPE (obj)) && LISP_READONLY (obj);
}

/* #### Should be made into an object method */

int
object_dead_p (Lisp_Object obj)
{
  return ((BUFFERP  (obj) && !BUFFER_LIVE_P  (XBUFFER  (obj))) ||
	  (FRAMEP   (obj) && !FRAME_LIVE_P   (XFRAME   (obj))) ||
	  (WINDOWP  (obj) && !WINDOW_LIVE_P  (XWINDOW  (obj))) ||
	  (DEVICEP  (obj) && !DEVICE_LIVE_P  (XDEVICE  (obj))) ||
	  (CONSOLEP (obj) && !CONSOLE_LIVE_P (XCONSOLE (obj))) ||
	  (EVENTP   (obj) && !EVENT_LIVE_P   (XEVENT   (obj))) ||
	  (EXTENTP  (obj) && !EXTENT_LIVE_P  (XEXTENT  (obj))));
}


/************************************************************************/
/*                           Debugger support                           */
/************************************************************************/
/* Give gdb/dbx enough information to decode Lisp Objects.  We make
   sure certain symbols are always defined, so gdb doesn't complain
   about expressions in src/.gdbinit.  See src/.gdbinit or src/.dbxrc
   to see how this is used.  */

EMACS_UINT dbg_valmask = ((1UL << VALBITS) - 1) << GCBITS;
EMACS_UINT dbg_typemask = (1UL << GCTYPEBITS) - 1;

#ifdef USE_UNION_TYPE
unsigned char dbg_USE_UNION_TYPE = 1;
#else
unsigned char dbg_USE_UNION_TYPE = 0;
#endif

unsigned char dbg_valbits = VALBITS;
unsigned char dbg_gctypebits = GCTYPEBITS;

/* On some systems, the above definitions will be optimized away by
   the compiler or linker unless they are referenced in some function. */
long dbg_inhibit_dbg_symbol_deletion (void);
long
dbg_inhibit_dbg_symbol_deletion (void)
{
  return
    (dbg_valmask +
     dbg_typemask +
     dbg_USE_UNION_TYPE +
     dbg_valbits +
     dbg_gctypebits);
}

/* Macros turned into functions for ease of debugging.
   Debuggers don't know about macros! */
int dbg_eq (Lisp_Object obj1, Lisp_Object obj2);
int
dbg_eq (Lisp_Object obj1, Lisp_Object obj2)
{
  return EQ (obj1, obj2);
}


#ifdef NEW_GC
#define DECLARE_FIXED_TYPE_ALLOC(type, structture) struct __foo__
#else
/************************************************************************/
/*                        Fixed-size type macros                        */
/************************************************************************/

/* For fixed-size types that are commonly used, we malloc() large blocks
   of memory at a time and subdivide them into chunks of the correct
   size for an object of that type.  This is more efficient than
   malloc()ing each object separately because we save on malloc() time
   and overhead due to the fewer number of malloc()ed blocks, and
   also because we don't need any extra pointers within each object
   to keep them threaded together for GC purposes.  For less common
   (and frequently large-size) types, we use lcrecords, which are
   malloc()ed individually and chained together through a pointer
   in the lcrecord header.  lcrecords do not need to be fixed-size
   (i.e. two objects of the same type need not have the same size;
   however, the size of a particular object cannot vary dynamically).
   It is also much easier to create a new lcrecord type because no
   additional code needs to be added to alloc.c.  Finally, lcrecords
   may be more efficient when there are only a small number of them.

   The types that are stored in these large blocks (or "frob blocks")
   are cons, all number types except fixnum, compiled-function, symbol,
   marker, extent, event, and string.

   Note that strings are special in that they are actually stored in
   two parts: a structure containing information about the string, and
   the actual data associated with the string.  The former structure
   (a struct Lisp_String) is a fixed-size structure and is managed the
   same way as all the other such types.  This structure contains a
   pointer to the actual string data, which is stored in structures of
   type struct string_chars_block.  Each string_chars_block consists
   of a pointer to a struct Lisp_String, followed by the data for that
   string, followed by another pointer to a Lisp_String, followed by
   the data for that string, etc.  At GC time, the data in these
   blocks is compacted by searching sequentially through all the
   blocks and compressing out any holes created by unmarked strings.
   Strings that are more than a certain size (bigger than the size of
   a string_chars_block, although something like half as big might
   make more sense) are malloc()ed separately and not stored in
   string_chars_blocks.  Furthermore, no one string stretches across
   two string_chars_blocks.

   Vectors are each malloc()ed separately as lcrecords.

   In the following discussion, we use conses, but it applies equally
   well to the other fixed-size types.

   We store cons cells inside of cons_blocks, allocating a new
   cons_block with malloc() whenever necessary.  Cons cells reclaimed
   by GC are put on a free list to be reallocated before allocating
   any new cons cells from the latest cons_block.  Each cons_block is
   just under 2^n - MALLOC_OVERHEAD bytes long, since malloc (at least
   the versions in malloc.c and gmalloc.c) really allocates in units
   of powers of two and uses 4 bytes for its own overhead.

   What GC actually does is to search through all the cons_blocks,
   from the most recently allocated to the oldest, and put all
   cons cells that are not marked (whether or not they're already
   free) on a cons_free_list.  The cons_free_list is a stack, and
   so the cons cells in the oldest-allocated cons_block end up
   at the head of the stack and are the first to be reallocated.
   If any cons_block is entirely free, it is freed with free()
   and its cons cells removed from the cons_free_list.  Because
   the cons_free_list ends up basically in memory order, we have
   a high locality of reference (assuming a reasonable turnover
   of allocating and freeing) and have a reasonable probability
   of entirely freeing up cons_blocks that have been more recently
   allocated.  This stage is called the "sweep stage" of GC, and
   is executed after the "mark stage", which involves starting
   from all places that are known to point to in-use Lisp objects
   (e.g. the obarray, where are all symbols are stored; the
   current catches and condition-cases; the backtrace list of
   currently executing functions; the gcpro list; etc.) and
   recursively marking all objects that are accessible.

   At the beginning of the sweep stage, the conses in the cons blocks
   are in one of three states: in use and marked, in use but not
   marked, and not in use (already freed).  Any conses that are marked
   have been marked in the mark stage just executed, because as part
   of the sweep stage we unmark any marked objects.  The way we tell
   whether or not a cons cell is in use is through the LRECORD_FREE_P
   macro.  This uses a special lrecord type `lrecord_type_free',
   which is never associated with any valid object.

   Conses on the free_cons_list are threaded through a pointer stored
   in the conses themselves.  Because the cons is still in a
   cons_block and needs to remain marked as not in use for the next
   time that GC happens, we need room to store both the "free"
   indicator and the chaining pointer.  So this pointer is stored
   after the lrecord header (actually where C places a pointer after
   the lrecord header; they are not necessarily contiguous).  This
   implies that all fixed-size types must be big enough to contain at
   least one pointer.  This is true for all current fixed-size types,
   with the possible exception of Lisp_Floats, for which we define the
   meat of the struct using a union of a pointer and a double to
   ensure adequate space for the free list chain pointer.

   Some types of objects need additional "finalization" done
   when an object is converted from in use to not in use;
   this is the purpose of the ADDITIONAL_FREE_type macro.
   For example, markers need to be removed from the chain
   of markers that is kept in each buffer.  This is because
   markers in a buffer automatically disappear if the marker
   is no longer referenced anywhere (the same does not
   apply to extents, however).

   WARNING: Things are in an extremely bizarre state when
   the ADDITIONAL_FREE_type macros are called, so beware!

   When ERROR_CHECK_GC is defined, we do things differently so as to
   maximize our chances of catching places where there is insufficient
   GCPROing.  The thing we want to avoid is having an object that
   we're using but didn't GCPRO get freed by GC and then reallocated
   while we're in the process of using it -- this will result in
   something seemingly unrelated getting trashed, and is extremely
   difficult to track down.  If the object gets freed but not
   reallocated, we can usually catch this because we set most of the
   bytes of a freed object to 0xDEADBEEF. (The lisp object type is set
   to the invalid type `lrecord_type_free', however, and a pointer
   used to chain freed objects together is stored after the lrecord
   header; we play some tricks with this pointer to make it more
   bogus, so crashes are more likely to occur right away.)

   We want freed objects to stay free as long as possible,
   so instead of doing what we do above, we maintain the
   free objects in a first-in first-out queue.  We also
   don't recompute the free list each GC, unlike above;
   this ensures that the queue ordering is preserved.
   [This means that we are likely to have worse locality
   of reference, and that we can never free a frob block
   once it's allocated. (Even if we know that all cells
   in it are free, there's no easy way to remove all those
   cells from the free list because the objects on the
   free list are unlikely to be in memory order.)]
   Furthermore, we never take objects off the free list
   unless there's a large number (usually 1000, but
   varies depending on type) of them already on the list.
   This way, we ensure that an object that gets freed will
   remain free for the next 1000 (or whatever) times that
   an object of that type is allocated.  */

#ifdef ALLOC_NO_POOLS
# define TYPE_ALLOC_SIZE(type, structtype) 1
#else
# define TYPE_ALLOC_SIZE(type, structtype)			\
    ((2048 - MALLOC_OVERHEAD - sizeof (struct type##_block *))	\
     / sizeof (structtype))
#endif /* ALLOC_NO_POOLS */

#define DECLARE_FIXED_TYPE_ALLOC(type, structtype)	\
							\
struct type##_block					\
{							\
  struct type##_block *prev;				\
  structtype block[TYPE_ALLOC_SIZE (type, structtype)];	\
};							\
							\
static struct type##_block *current_##type##_block;	\
static int current_##type##_block_index;		\
							\
static Lisp_Free *type##_free_list;			\
static Lisp_Free *type##_free_list_tail;		\
							\
static void						\
init_##type##_alloc (void)				\
{							\
  current_##type##_block = 0;				\
  current_##type##_block_index =			\
    countof (current_##type##_block->block);		\
  type##_free_list = 0;					\
  type##_free_list_tail = 0;				\
}							\
							\
static int gc_count_num_##type##_in_use;		\
static int gc_count_num_##type##_freelist

#define ALLOCATE_FIXED_TYPE_FROM_BLOCK(type, result) do {		\
  if (current_##type##_block_index					\
      == countof (current_##type##_block->block))			\
    {									\
      struct type##_block *AFTFB_new = (struct type##_block *)		\
	allocate_lisp_storage (sizeof (struct type##_block));		\
      AFTFB_new->prev = current_##type##_block;				\
      current_##type##_block = AFTFB_new;				\
      current_##type##_block_index = 0;					\
    }									\
  (result) =								\
    &(current_##type##_block->block[current_##type##_block_index++]);	\
} while (0)

/* Allocate an instance of a type that is stored in blocks.
   TYPE is the "name" of the type, STRUCTTYPE is the corresponding
   structure type. */

#ifdef ERROR_CHECK_GC

/* Note: if you get crashes in this function, suspect incorrect calls
   to free_cons() and friends.  This happened once because the cons
   cell was not GC-protected and was getting collected before
   free_cons() was called. */

#define ALLOCATE_FIXED_TYPE_1(type, structtype, result) do {	\
  if (gc_count_num_##type##_freelist >				\
      MINIMUM_ALLOWED_FIXED_TYPE_CELLS_##type)			\
    {								\
      result = (structtype *) type##_free_list;			\
      assert (LRECORD_FREE_P (result));				\
      /* Before actually using the chain pointer, we complement	\
	 all its bits; see PUT_FIXED_TYPE_ON_FREE_LIST(). */	\
      type##_free_list = (Lisp_Free *)				\
	(~ (EMACS_UINT) (type##_free_list->chain));		\
      gc_count_num_##type##_freelist--;				\
    }								\
  else								\
    ALLOCATE_FIXED_TYPE_FROM_BLOCK (type, result);		\
  MARK_LRECORD_AS_NOT_FREE (result);				\
} while (0)

#else /* !ERROR_CHECK_GC */

#define ALLOCATE_FIXED_TYPE_1(type, structtype, result) do {	\
  if (type##_free_list)						\
    {								\
      result = (structtype *) type##_free_list;			\
      type##_free_list = type##_free_list->chain;		\
    }								\
  else								\
    ALLOCATE_FIXED_TYPE_FROM_BLOCK (type, result);		\
  MARK_LRECORD_AS_NOT_FREE (result);				\
} while (0)

#endif /* !ERROR_CHECK_GC */


#define ALLOCATE_FIXED_TYPE(type, structtype, result)	\
do							\
{							\
  ALLOCATE_FIXED_TYPE_1 (type, structtype, result);	\
  INCREMENT_CONS_COUNTER (sizeof (structtype), #type);	\
} while (0)

#define NOSEEUM_ALLOCATE_FIXED_TYPE(type, structtype, result)	\
do								\
{								\
  ALLOCATE_FIXED_TYPE_1 (type, structtype, result);		\
  NOSEEUM_INCREMENT_CONS_COUNTER (sizeof (structtype), #type);	\
} while (0)

/* Lisp_Free is the type to represent a free list member inside a frob
   block of any lisp object type.  */
typedef struct Lisp_Free
{
  struct lrecord_header lheader;
  struct Lisp_Free *chain;
} Lisp_Free;

#define LRECORD_FREE_P(ptr) \
(((struct lrecord_header *) ptr)->type == lrecord_type_free)

#define MARK_LRECORD_AS_FREE(ptr) \
((void) (((struct lrecord_header *) ptr)->type = lrecord_type_free))

#ifdef ERROR_CHECK_GC
#define MARK_LRECORD_AS_NOT_FREE(ptr) \
((void) (((struct lrecord_header *) ptr)->type = lrecord_type_undefined))
#else
#define MARK_LRECORD_AS_NOT_FREE(ptr) DO_NOTHING
#endif

#ifdef ERROR_CHECK_GC

#define PUT_FIXED_TYPE_ON_FREE_LIST(type, structtype, ptr) do {	\
  if (type##_free_list_tail)					\
    {								\
      /* When we store the chain pointer, we complement all	\
	 its bits; this should significantly increase its	\
	 bogosity in case someone tries to use the value, and	\
	 should make us crash faster if someone overwrites the	\
	 pointer because when it gets un-complemented in	\
	 ALLOCATED_FIXED_TYPE(), the resulting pointer will be	\
	 extremely bogus. */					\
      type##_free_list_tail->chain =				\
	(Lisp_Free *) ~ (EMACS_UINT) (ptr);			\
    }								\
  else								\
    type##_free_list = (Lisp_Free *) (ptr);			\
  type##_free_list_tail = (Lisp_Free *) (ptr);			\
} while (0)

#else /* !ERROR_CHECK_GC */

#define PUT_FIXED_TYPE_ON_FREE_LIST(type, structtype, ptr) do {	\
  ((Lisp_Free *) (ptr))->chain = type##_free_list;		\
  type##_free_list = (Lisp_Free *) (ptr);			\
} while (0)							\

#endif /* !ERROR_CHECK_GC */

/* TYPE and STRUCTTYPE are the same as in ALLOCATE_FIXED_TYPE(). */

#define FREE_FIXED_TYPE(type, structtype, ptr) do {		\
  structtype *FFT_ptr = (ptr);					\
  gc_checking_assert (!LRECORD_FREE_P (FFT_ptr));		\
  gc_checking_assert (!DUMPEDP (FFT_ptr));			\
  ADDITIONAL_FREE_##type (FFT_ptr);				\
  deadbeef_memory (FFT_ptr, sizeof (structtype));		\
  PUT_FIXED_TYPE_ON_FREE_LIST (type, structtype, FFT_ptr);	\
  MARK_LRECORD_AS_FREE (FFT_ptr);				\
} while (0)
#endif /* NEW_GC */

#ifdef NEW_GC
#define FREE_FIXED_TYPE_WHEN_NOT_IN_GC(lo, type, structtype, ptr)	\
  free_normal_lisp_object (lo)
#else /* not NEW_GC */
/* Like FREE_FIXED_TYPE() but used when we are explicitly
   freeing a structure through free_cons(), free_marker(), etc.
   rather than through the normal process of sweeping.
   We attempt to undo the changes made to the allocation counters
   as a result of this structure being allocated.  This is not
   completely necessary but helps keep things saner: e.g. this way,
   repeatedly allocating and freeing a cons will not result in
   the consing-since-gc counter advancing, which would cause a GC
   and somewhat defeat the purpose of explicitly freeing.

   We also disable this mechanism entirely when ALLOC_NO_POOLS is
   set, which is used for Purify and the like. */

#ifndef ALLOC_NO_POOLS
#define FREE_FIXED_TYPE_WHEN_NOT_IN_GC(lo, type, structtype, ptr)	\
do { FREE_FIXED_TYPE (type, structtype, ptr);				\
     DECREMENT_CONS_COUNTER (sizeof (structtype));			\
     gc_count_num_##type##_freelist++;					\
   } while (0)
#else
#define FREE_FIXED_TYPE_WHEN_NOT_IN_GC(lo, type, structtype, ptr)
#endif
#endif /* (not) NEW_GC */

#ifdef NEW_GC
#define ALLOC_FROB_BLOCK_LISP_OBJECT_1(type, lisp_type, var, lrec_ptr,  \
                                       lheader)                         \
do {									\
  (var) = (lisp_type *) XPNTR (ALLOC_NORMAL_LISP_OBJECT (type));        \
} while (0)
#define NOSEEUM_ALLOC_FROB_BLOCK_LISP_OBJECT_1(type, lisp_type, var,	\
                                               lrec_ptr, lheader)       \
do {									\
  (var) = (lisp_type *) XPNTR (noseeum_alloc_lrecord (lrec_ptr));	\
} while (0)
#else /* not NEW_GC */
#define ALLOC_FROB_BLOCK_LISP_OBJECT_1(type, lisp_type, var, lrec_ptr,  \
                                       lheader)                         \
do									\
{									\
  ALLOCATE_FIXED_TYPE (type, lisp_type, var);				\
  set_lheader_implementation (&(var)->lheader, lrec_ptr);		\
} while (0)
#define NOSEEUM_ALLOC_FROB_BLOCK_LISP_OBJECT_1(type, lisp_type, var,	\
                                               lrec_ptr, lheader)       \
do									\
{									\
  NOSEEUM_ALLOCATE_FIXED_TYPE (type, lisp_type, var);			\
  set_lheader_implementation (&(var)->lheader, lrec_ptr);		\
} while (0)
#endif /* not NEW_GC */

#define ALLOC_FROB_BLOCK_LISP_OBJECT(type, lisp_type, var, lrec_ptr) \
  ALLOC_FROB_BLOCK_LISP_OBJECT_1(type, lisp_type, var, lrec_ptr, lheader) 

#define NOSEEUM_ALLOC_FROB_BLOCK_LISP_OBJECT(type, lisp_type, var, lrec_ptr) \
  NOSEEUM_ALLOC_FROB_BLOCK_LISP_OBJECT_1(type, lisp_type, var, lrec_ptr, \
                                         lheader) 

/************************************************************************/
/*			   Cons allocation				*/
/************************************************************************/

DECLARE_FIXED_TYPE_ALLOC (cons, Lisp_Cons);
/* conses are used and freed so often that we set this really high */
/* #define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_cons 20000 */
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_cons 2000

static Lisp_Object
mark_cons (Lisp_Object obj)
{
  if (NILP (XCDR (obj)))
    return XCAR (obj);

  mark_object (XCAR (obj));
  return XCDR (obj);
}

static int
cons_equal (Lisp_Object ob1, Lisp_Object ob2, int depth, int foldcase)
{
  depth++;
  while (internal_equal_0 (XCAR (ob1), XCAR (ob2), depth, foldcase))
    {
      ob1 = XCDR (ob1);
      ob2 = XCDR (ob2);
      if (! CONSP (ob1) || ! CONSP (ob2))
	return internal_equal_0 (ob1, ob2, depth, foldcase);
    }
  return 0;
}

extern Elemcount
print_preprocess_inchash_eq (Lisp_Object obj, Lisp_Object table,
                             Elemcount *seen_object_count);

static void
cons_print_preprocess (Lisp_Object object, Lisp_Object print_number_table,
                       Elemcount *seen_object_count)
{
  /* Special-case conses, don't recurse down the cdr if the cdr is a cons. */
  for (;;)
    {
      PRINT_PREPROCESS (XCAR (object), print_number_table, seen_object_count);
      object = XCDR (object);

      if (!CONSP (object))
        {
          break;
        }

      if (print_preprocess_inchash_eq (object, print_number_table,
                                       seen_object_count) > 1)
        {
          return;
        }
    }

  PRINT_PREPROCESS (object, print_number_table, seen_object_count);
}

static void
cons_nsubst_structures_descend (Lisp_Object new_, Lisp_Object old,
                                Lisp_Object object,
                                Lisp_Object number_table,
                                Boolint test_not_unboundp)
{
  /* No need for a special case, nsubst_structures_descend is called much
     less frequently than is print_preprocess. */
  if (EQ (old, XCAR (object)) == test_not_unboundp)
    {
      XSETCAR (object, new_);
    }
  else if (LRECORDP (XCAR (object)) &&
           HAS_OBJECT_METH_P (XCAR (object), nsubst_structures_descend))
    {
      nsubst_structures_descend (new_, old, XCAR (object), number_table,
                                 test_not_unboundp);
    }
        
  if (EQ (old, XCDR (object)) == test_not_unboundp)
    {
      XSETCDR (object, new_);
    }
  else if (LRECORDP (XCDR (object)) &&
           HAS_OBJECT_METH_P (XCDR (object), nsubst_structures_descend))
    {
      nsubst_structures_descend (new_, old, XCDR (object), number_table,
				 test_not_unboundp);
    }
}

static const struct memory_description cons_description[] = {
  { XD_LISP_OBJECT, offsetof (Lisp_Cons, car_) },
  { XD_LISP_OBJECT, offsetof (Lisp_Cons, cdr_) },
  { XD_END }
};

DEFINE_DUMPABLE_FROB_BLOCK_LISP_OBJECT ("cons", cons,
					mark_cons, print_cons, 0, cons_equal,
					/*
					 * No `hash' method needed.
					 * internal_hash knows how to
					 * handle conses.
					 */
					0, cons_description, Lisp_Cons);

DEFUN ("cons", Fcons, 2, 2, 0, /*
Create a new cons cell, give it CAR and CDR as components, and return it.

A cons cell is a Lisp object (an area in memory) made up of two pointers
called the CAR and the CDR.  Each of these pointers can point to any other
Lisp object.  The common Lisp data type, the list, is a specially-structured
series of cons cells.

The pointers are accessed from Lisp with `car' and `cdr', and mutated with
`setcar' and `setcdr' respectively.  For historical reasons, the aliases
`rplaca' and `rplacd' (for `setcar' and `setcdr') are supported.
*/
       (car, cdr))
{
  /* This cannot GC. */
  Lisp_Object val;
  Lisp_Cons *c;

  ALLOC_FROB_BLOCK_LISP_OBJECT (cons, Lisp_Cons, c, &lrecord_cons);
  val = wrap_cons (c);
  XSETCAR (val, car);
  XSETCDR (val, cdr);
  return val;
}

/* This is identical to Fcons() but it used for conses that we're
   going to free later, and is useful when trying to track down
   "real" consing. */
Lisp_Object
noseeum_cons (Lisp_Object car, Lisp_Object cdr)
{
  Lisp_Object val;
  Lisp_Cons *c;

  NOSEEUM_ALLOC_FROB_BLOCK_LISP_OBJECT (cons, Lisp_Cons, c, &lrecord_cons);
  val = wrap_cons (c);
  XCAR (val) = car;
  XCDR (val) = cdr;
  return val;
}

DEFUN ("list", Flist, 0, MANY, 0, /*
Return a newly created list with specified ARGS as elements.
Any number of arguments, even zero arguments, are allowed.

arguments: (&rest ARGS)
*/
       (int nargs, Lisp_Object *args))
{
  Lisp_Object val = Qnil;
  Lisp_Object *argp = args + nargs;

  while (argp > args)
    val = Fcons (*--argp, val);
  return val;
}

Lisp_Object
list1 (Lisp_Object obj0)
{
  /* This cannot GC. */
  return Fcons (obj0, Qnil);
}

Lisp_Object
list2 (Lisp_Object obj0, Lisp_Object obj1)
{
  /* This cannot GC. */
  return Fcons (obj0, Fcons (obj1, Qnil));
}

Lisp_Object
list3 (Lisp_Object obj0, Lisp_Object obj1, Lisp_Object obj2)
{
  /* This cannot GC. */
  return Fcons (obj0, Fcons (obj1, Fcons (obj2, Qnil)));
}

Lisp_Object
cons3 (Lisp_Object obj0, Lisp_Object obj1, Lisp_Object obj2)
{
  /* This cannot GC. */
  return Fcons (obj0, Fcons (obj1, obj2));
}

DEFUN ("acons", Facons, 3, 3, 0, /*
Return a new alist created by prepending (KEY . VALUE) to ALIST.
*/
       (key, value, alist))
{
  return Fcons (Fcons (key, value), alist);
}

Lisp_Object
list4 (Lisp_Object obj0, Lisp_Object obj1, Lisp_Object obj2, Lisp_Object obj3)
{
  /* This cannot GC. */
  return Fcons (obj0, Fcons (obj1, Fcons (obj2, Fcons (obj3, Qnil))));
}

Lisp_Object
list5 (Lisp_Object obj0, Lisp_Object obj1, Lisp_Object obj2, Lisp_Object obj3,
       Lisp_Object obj4)
{
  /* This cannot GC. */
  return Fcons (obj0, Fcons (obj1, Fcons (obj2, Fcons (obj3, Fcons (obj4, Qnil)))));
}

Lisp_Object
list6 (Lisp_Object obj0, Lisp_Object obj1, Lisp_Object obj2, Lisp_Object obj3,
       Lisp_Object obj4, Lisp_Object obj5)
{
  /* This cannot GC. */
  return Fcons (obj0, Fcons (obj1, Fcons (obj2, Fcons (obj3, Fcons (obj4, Fcons (obj5, Qnil))))));
}

/* Return a list of arbitrary length, terminated by Qunbound. */

Lisp_Object
listu (Lisp_Object first, ...)
{
  Lisp_Object obj = Qnil;

  if (!UNBOUNDP (first))
    {
      va_list va;
      Lisp_Object last, val;

      last = obj = Fcons (first, Qnil);
      va_start (va, first);
      val = va_arg (va, Lisp_Object);
      while (!UNBOUNDP (val))
	{
	  last = XCDR (last) = Fcons (val, Qnil);
	  val = va_arg (va, Lisp_Object);
	}
      va_end (va);
    }
  return obj;
}

/* Return a list of arbitrary length, with length specified and remaining
   args making up the list. */

Lisp_Object
listn (int num_args, ...)
{
  Lisp_Object obj = Qnil;

  if (num_args > 0)
    {
      va_list va;
      Lisp_Object last;
      int i;

      va_start (va, num_args);
      last = obj = Fcons (va_arg (va, Lisp_Object), Qnil);
      for (i = 1; i < num_args; i++)
	last = XCDR (last) = Fcons (va_arg (va, Lisp_Object), Qnil);
      va_end (va);
    }
  return obj;
}

/* Return a list of arbitrary length, with length specified and an array
   of elements. */

DEFUN ("make-list", Fmake_list, 2, 2, 0, /*
Return a new list of length LENGTH, with each element being OBJECT.
*/
       (length, object))
{
  Lisp_Object val = Qnil;
  Elemcount size;

  check_integer_range (length, Qzero, make_fixnum (MOST_POSITIVE_FIXNUM));

  size = XFIXNUM (length);

  while (size--)
    val = Fcons (object, val);

  return val;
}


/************************************************************************/
/*			  Float allocation				*/
/************************************************************************/

/*** With enhanced number support, these are short floats */

DECLARE_FIXED_TYPE_ALLOC (float, Lisp_Float);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_float 1000

Lisp_Object
make_float (double float_value)
{
  Lisp_Float *f;

  ALLOC_FROB_BLOCK_LISP_OBJECT (float, Lisp_Float, f, &lrecord_float);

  /* Avoid dump-time `uninitialized memory read' purify warnings. */
  if (sizeof (struct lrecord_header) + sizeof (double) != sizeof (*f))
    zero_nonsized_lisp_object (wrap_float (f));

  float_data (f) = float_value;
  return wrap_float (f);
}


/************************************************************************/
/*			Enhanced number allocation			*/
/************************************************************************/

/*** Bignum ***/
#ifdef HAVE_BIGNUM
DECLARE_FIXED_TYPE_ALLOC (bignum, Lisp_Bignum);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_bignum 250

/* WARNING: This function returns a bignum even if its argument fits into a
   fixnum.  See Fcanonicalize_number(). */
Lisp_Object
make_bignum (long bignum_value)
{
  Lisp_Bignum *b;

  ALLOC_FROB_BLOCK_LISP_OBJECT (bignum, Lisp_Bignum, b, &lrecord_bignum);
  bignum_init (bignum_data (b));
  bignum_set_long (bignum_data (b), bignum_value);
  return wrap_bignum (b);
}

/* WARNING: This function returns a bignum even if its argument fits into a
   fixnum.  See Fcanonicalize_number(). */
Lisp_Object
make_bignum_un (unsigned long bignum_value)
{
  Lisp_Bignum *b;

  ALLOC_FROB_BLOCK_LISP_OBJECT (bignum, Lisp_Bignum, b, &lrecord_bignum);
  bignum_init (bignum_data (b));
  bignum_set_ulong (bignum_data (b), bignum_value);
  return wrap_bignum (b);
}

/* WARNING: This function returns a bignum even if its argument fits into a
   fixnum.  See Fcanonicalize_number(). */
Lisp_Object
make_bignum_ll (long long bignum_value)
{
  Lisp_Bignum *b;

  ALLOC_FROB_BLOCK_LISP_OBJECT (bignum, Lisp_Bignum, b, &lrecord_bignum);
  bignum_init (bignum_data (b));
  bignum_set_llong (bignum_data (b), bignum_value);
  return wrap_bignum (b);
}

/* WARNING: This function returns a bignum even if its argument fits into a
   fixnum.  See Fcanonicalize_number(). */
Lisp_Object
make_bignum_ull (unsigned long long bignum_value)
{
  Lisp_Bignum *b;

  ALLOC_FROB_BLOCK_LISP_OBJECT (bignum, Lisp_Bignum, b, &lrecord_bignum);
  bignum_init (bignum_data (b));
  bignum_set_ullong (bignum_data (b), bignum_value);
  return wrap_bignum (b);
}

/* WARNING: This function returns a bignum even if its argument fits into a
   fixnum.  See Fcanonicalize_number(). */
Lisp_Object
make_bignum_bg (bignum bg)
{
  Lisp_Bignum *b;

  ALLOC_FROB_BLOCK_LISP_OBJECT (bignum, Lisp_Bignum, b, &lrecord_bignum);
  bignum_init (bignum_data (b));
  bignum_set (bignum_data (b), bg);
  return wrap_bignum (b);
}
#endif /* HAVE_BIGNUM */

/*** Ratio ***/
#ifdef HAVE_RATIO
DECLARE_FIXED_TYPE_ALLOC (ratio, Lisp_Ratio);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_ratio 250

Lisp_Object
make_ratio (long numerator, unsigned long denominator)
{
  Lisp_Ratio *r;

  ALLOC_FROB_BLOCK_LISP_OBJECT (ratio, Lisp_Ratio, r, &lrecord_ratio);
  ratio_init (ratio_data (r));
  ratio_set_long_ulong (ratio_data (r), numerator, denominator);
  ratio_canonicalize (ratio_data (r));
  return wrap_ratio (r);
}

Lisp_Object
make_ratio_bg (bignum numerator, bignum denominator)
{
  Lisp_Ratio *r;

  ALLOC_FROB_BLOCK_LISP_OBJECT (ratio, Lisp_Ratio, r, &lrecord_ratio);
  ratio_init (ratio_data (r));
  ratio_set_bignum_bignum (ratio_data (r), numerator, denominator);
  ratio_canonicalize (ratio_data (r));
  return wrap_ratio (r);
}

Lisp_Object
make_ratio_rt (ratio rat)
{
  Lisp_Ratio *r;

  ALLOC_FROB_BLOCK_LISP_OBJECT (ratio, Lisp_Ratio, r, &lrecord_ratio);
  ratio_init (ratio_data (r));
  ratio_set (ratio_data (r), rat);
  return wrap_ratio (r);
}
#endif /* HAVE_RATIO */

/*** Bigfloat ***/
#ifdef HAVE_BIGFLOAT
DECLARE_FIXED_TYPE_ALLOC (bigfloat, Lisp_Bigfloat);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_bigfloat 250

/* This function creates a bigfloat with the default precision if the
   PRECISION argument is zero. */
Lisp_Object
make_bigfloat (double float_value, unsigned long precision)
{
  Lisp_Bigfloat *f;

  ALLOC_FROB_BLOCK_LISP_OBJECT (bigfloat, Lisp_Bigfloat, f, &lrecord_bigfloat);
  if (precision == 0UL)
    bigfloat_init (bigfloat_data (f));
  else
    bigfloat_init_prec (bigfloat_data (f), precision);
  bigfloat_set_double (bigfloat_data (f), float_value);
  return wrap_bigfloat (f);
}

/* This function creates a bigfloat with the precision of its argument */
Lisp_Object
make_bigfloat_bf (bigfloat float_value)
{
  Lisp_Bigfloat *f;

  ALLOC_FROB_BLOCK_LISP_OBJECT (bigfloat, Lisp_Bigfloat, f, &lrecord_bigfloat);
  bigfloat_init_prec (bigfloat_data (f), bigfloat_get_prec (float_value));
  bigfloat_set (bigfloat_data (f), float_value);
  return wrap_bigfloat (f);
}
#endif /* HAVE_BIGFLOAT */

/************************************************************************/
/*			   Vector allocation				*/
/************************************************************************/

static Lisp_Object
mark_vector (Lisp_Object obj)
{
  Lisp_Vector *ptr = XVECTOR (obj);
  int len = vector_length (ptr);
  int i;

  for (i = 0; i < len - 1; i++)
    mark_object (ptr->contents[i]);
  return (len > 0) ? ptr->contents[len - 1] : Qnil;
}

static Bytecount
size_vector (Lisp_Object obj)
{
  
  return FLEXIBLE_ARRAY_STRUCT_SIZEOF (Lisp_Vector, Lisp_Object, contents,
				       XVECTOR (obj)->size);
}

static int
vector_equal (Lisp_Object obj1, Lisp_Object obj2, int depth, int foldcase)
{
  int len = XVECTOR_LENGTH (obj1);
  if (len != XVECTOR_LENGTH (obj2))
    return 0;

  {
    Lisp_Object *ptr1 = XVECTOR_DATA (obj1);
    Lisp_Object *ptr2 = XVECTOR_DATA (obj2);
    while (len--)
      if (!internal_equal_0 (*ptr1++, *ptr2++, depth + 1, foldcase))
	return 0;
  }
  return 1;
}

static Hashcode
vector_hash (Lisp_Object obj, int depth, Boolint equalp)
{
  return HASH2 (XVECTOR_LENGTH (obj),
		internal_array_hash (XVECTOR_DATA (obj),
				     XVECTOR_LENGTH (obj),
				     depth + 1, equalp));
}

static void
vector_print_preprocess (Lisp_Object object, Lisp_Object print_number_table,
                         Elemcount *seen_object_count)
{
  Elemcount ii, len;

  for (ii = 0, len = XVECTOR_LENGTH (object); ii < len; ii++)
    {
      PRINT_PREPROCESS (XVECTOR_DATA (object)[ii], print_number_table,
                        seen_object_count);
    }
}

static void
vector_nsubst_structures_descend (Lisp_Object new_, Lisp_Object old,
                                  Lisp_Object object, Lisp_Object number_table,
                                  Boolint test_not_unboundp)
{
  Elemcount ii = XVECTOR_LENGTH (object);
  Lisp_Object *vdata = XVECTOR_DATA (object);

  while (ii > 0)
    {
      --ii;

      if (EQ (vdata[ii], old) == test_not_unboundp)
	{
	  vdata[ii] = new_;
	}
      else if (LRECORDP (vdata[ii]) &&
               HAS_OBJECT_METH_P (vdata[ii], nsubst_structures_descend))
	{
	  nsubst_structures_descend (new_, old, vdata[ii], number_table,
				     test_not_unboundp);
	}
    }
}

static const struct memory_description vector_description[] = {
  { XD_LONG,              offsetof (Lisp_Vector, size) },
  { XD_LISP_OBJECT_ARRAY, offsetof (Lisp_Vector, contents), XD_INDIRECT(0, 0) },
  { XD_END }
};

DEFINE_DUMPABLE_SIZABLE_LISP_OBJECT ("vector", vector,
				     mark_vector, print_vector, 0,
				     vector_equal,
				     vector_hash,
				     vector_description,
				     size_vector, Lisp_Vector);
/* #### should allocate `small' vectors from a frob-block */
static Lisp_Vector *
make_vector_internal (Elemcount sizei)
{
  /* no `next' field; we use lcrecords */
  Bytecount sizem = FLEXIBLE_ARRAY_STRUCT_SIZEOF (Lisp_Vector, Lisp_Object,
						  contents, sizei);
  Lisp_Object obj = ALLOC_SIZED_LISP_OBJECT (sizem, vector);
  Lisp_Vector *p = XVECTOR (obj);

  p->size = sizei;
  return p;
}

Lisp_Object
make_vector (Elemcount length, Lisp_Object object)
{
  Lisp_Vector *vecp = make_vector_internal (length);
  Lisp_Object *p = vector_data (vecp);

  while (length--)
    *p++ = object;

  return wrap_vector (vecp);
}

DEFUN ("make-vector", Fmake_vector, 2, 2, 0, /*
Return a new vector of length LENGTH, with each element being OBJECT.
See also the function `vector'.
*/
       (length, object))
{
  check_integer_range (length, Qzero, make_fixnum (ARRAY_DIMENSION_LIMIT));
  return make_vector (XFIXNUM (length), object);
}

DEFUN ("vector", Fvector, 0, MANY, 0, /*
Return a newly created vector with specified ARGS as elements.
Any number of arguments, even zero arguments, are allowed.

arguments: (&rest ARGS)
*/
       (int nargs, Lisp_Object *args))
{
  Lisp_Vector *vecp = make_vector_internal (nargs);
  Lisp_Object *p = vector_data (vecp);

  while (nargs--)
    *p++ = *args++;

  return wrap_vector (vecp);
}

Lisp_Object
vector1 (Lisp_Object obj0)
{
  return Fvector (1, &obj0);
}

Lisp_Object
vector2 (Lisp_Object obj0, Lisp_Object obj1)
{
  Lisp_Object args[2];
  args[0] = obj0;
  args[1] = obj1;
  return Fvector (2, args);
}

Lisp_Object
vector3 (Lisp_Object obj0, Lisp_Object obj1, Lisp_Object obj2)
{
  Lisp_Object args[3];
  args[0] = obj0;
  args[1] = obj1;
  args[2] = obj2;
  return Fvector (3, args);
}

#if 0 /* currently unused */

Lisp_Object
vector4 (Lisp_Object obj0, Lisp_Object obj1, Lisp_Object obj2,
	 Lisp_Object obj3)
{
  Lisp_Object args[4];
  args[0] = obj0;
  args[1] = obj1;
  args[2] = obj2;
  args[3] = obj3;
  return Fvector (4, args);
}

Lisp_Object
vector5 (Lisp_Object obj0, Lisp_Object obj1, Lisp_Object obj2,
	 Lisp_Object obj3, Lisp_Object obj4)
{
  Lisp_Object args[5];
  args[0] = obj0;
  args[1] = obj1;
  args[2] = obj2;
  args[3] = obj3;
  args[4] = obj4;
  return Fvector (5, args);
}

Lisp_Object
vector6 (Lisp_Object obj0, Lisp_Object obj1, Lisp_Object obj2,
	 Lisp_Object obj3, Lisp_Object obj4, Lisp_Object obj5)
{
  Lisp_Object args[6];
  args[0] = obj0;
  args[1] = obj1;
  args[2] = obj2;
  args[3] = obj3;
  args[4] = obj4;
  args[5] = obj5;
  return Fvector (6, args);
}

Lisp_Object
vector7 (Lisp_Object obj0, Lisp_Object obj1, Lisp_Object obj2,
	 Lisp_Object obj3, Lisp_Object obj4, Lisp_Object obj5,
	 Lisp_Object obj6)
{
  Lisp_Object args[7];
  args[0] = obj0;
  args[1] = obj1;
  args[2] = obj2;
  args[3] = obj3;
  args[4] = obj4;
  args[5] = obj5;
  args[6] = obj6;
  return Fvector (7, args);
}

Lisp_Object
vector8 (Lisp_Object obj0, Lisp_Object obj1, Lisp_Object obj2,
	 Lisp_Object obj3, Lisp_Object obj4, Lisp_Object obj5,
	 Lisp_Object obj6, Lisp_Object obj7)
{
  Lisp_Object args[8];
  args[0] = obj0;
  args[1] = obj1;
  args[2] = obj2;
  args[3] = obj3;
  args[4] = obj4;
  args[5] = obj5;
  args[6] = obj6;
  args[7] = obj7;
  return Fvector (8, args);
}
#endif /* unused */

/************************************************************************/
/*			 Bit Vector allocation				*/
/************************************************************************/

static Lisp_Object
mark_bit_vector (Lisp_Object UNUSED (obj))
{
  return Qnil;
}

static void
print_bit_vector (Lisp_Object obj, Lisp_Object printcharfun,
		  int UNUSED (escapeflag))
{
  Elemcount i;
  Lisp_Bit_Vector *v = XBIT_VECTOR (obj);
  Elemcount len = bit_vector_length (v);
  Elemcount last = len;

  if (FIXNUMP (Vprint_length))
    last = min (len, XFIXNUM (Vprint_length));
  write_ascstring (printcharfun, "#*");
  for (i = 0; i < last; i++)
    {
      if (bit_vector_bit (v, i))
	write_ascstring (printcharfun, "1");
      else
	write_ascstring (printcharfun, "0");
    }

  if (last != len)
    write_ascstring (printcharfun, "...");
}

static int
bit_vector_equal (Lisp_Object obj1, Lisp_Object obj2, int UNUSED (depth),
		  int UNUSED (foldcase))
{
  Lisp_Bit_Vector *v1 = XBIT_VECTOR (obj1);
  Lisp_Bit_Vector *v2 = XBIT_VECTOR (obj2);

  return ((bit_vector_length (v1) == bit_vector_length (v2)) &&
	  !memcmp (v1->bits, v2->bits,
		   BIT_VECTOR_LONG_STORAGE (bit_vector_length (v1)) *
		   sizeof (long)));
}

/* This needs to be algorithmically identical to internal_array_hash in
   elhash.c when equalp is one, so arrays and bit vectors with the same
   contents hash the same. It would be possible to enforce this by giving
   internal_ARRAYLIKE_hash its own file and including it twice, but right
   now that doesn't seem worth it. */
static Hashcode
internal_bit_vector_equalp_hash (Lisp_Bit_Vector *v)
{
  int ii, size = bit_vector_length (v);
  Hashcode hash = 0;

  if (size <= 5)
    {
      for (ii = 0; ii < size; ii++)
        {
          hash = HASH2
            (hash,
             FLOAT_HASHCODE_FROM_DOUBLE ((double) (bit_vector_bit (v, ii))));
        }
      return hash;
    }

  /* just pick five elements scattered throughout the array.
     A slightly better approach would be to offset by some
     noise factor from the points chosen below. */
  for (ii = 0; ii < 5; ii++)
    hash = HASH2 (hash,
                  FLOAT_HASHCODE_FROM_DOUBLE
                  ((double) (bit_vector_bit (v, ii * size / 5))));

  return hash;
}

static Hashcode
bit_vector_hash (Lisp_Object obj, int UNUSED (depth), Boolint equalp)
{
  Lisp_Bit_Vector *v = XBIT_VECTOR (obj);
  if (equalp)
    {
      return HASH2 (bit_vector_length (v),
                    internal_bit_vector_equalp_hash (v));
    }

  return HASH2 (bit_vector_length (v),
		memory_hash (v->bits,
			     BIT_VECTOR_LONG_STORAGE (bit_vector_length (v)) *
			     sizeof (long)));
}

static Bytecount
size_bit_vector (Lisp_Object obj)
{
  Lisp_Bit_Vector *v = XBIT_VECTOR (obj);
  return FLEXIBLE_ARRAY_STRUCT_SIZEOF (Lisp_Bit_Vector, unsigned long, bits,
				       BIT_VECTOR_LONG_STORAGE (bit_vector_length (v)));
}

static const struct memory_description bit_vector_description[] = {
  { XD_END }
};


DEFINE_DUMPABLE_SIZABLE_LISP_OBJECT ("bit-vector", bit_vector,
				     mark_bit_vector,
				     print_bit_vector, 0,
				     bit_vector_equal,
				     bit_vector_hash,
				     bit_vector_description,
				     size_bit_vector,
				     Lisp_Bit_Vector);

/* #### should allocate `small' bit vectors from a frob-block */
static Lisp_Bit_Vector *
make_bit_vector_internal (Elemcount sizei)
{
  /* no `next' field; we use lcrecords */
  Elemcount num_longs = BIT_VECTOR_LONG_STORAGE (sizei);
  Bytecount sizem = FLEXIBLE_ARRAY_STRUCT_SIZEOF (Lisp_Bit_Vector,
						  unsigned long,
						  bits, num_longs);
  Lisp_Object obj = ALLOC_SIZED_LISP_OBJECT (sizem, bit_vector);
  Lisp_Bit_Vector *p = XBIT_VECTOR (obj);

  bit_vector_length (p) = sizei;
  return p;
}

Lisp_Object
make_bit_vector (Elemcount length, Lisp_Object bit)
{
  Lisp_Bit_Vector *p = make_bit_vector_internal (length);
  Elemcount num_longs = BIT_VECTOR_LONG_STORAGE (length);

  CHECK_BIT (bit);

  if (ZEROP (bit))
    memset (p->bits, 0, num_longs * sizeof (long));
  else
    {
      Elemcount bits_in_last = length & (LONGBITS_POWER_OF_2 - 1);
      memset (p->bits, ~0, num_longs * sizeof (long));
      /* But we have to make sure that the unused bits in the
	 last long are 0, so that equal/hash is easy. */
      if (bits_in_last)
	p->bits[num_longs - 1] &= (1 << bits_in_last) - 1;
    }

  return wrap_bit_vector (p);
}

Lisp_Object
make_bit_vector_from_byte_vector (unsigned char *bytevec, Elemcount length)
{
  Elemcount i;
  Lisp_Bit_Vector *p = make_bit_vector_internal (length);

  for (i = 0; i < length; i++)
    set_bit_vector_bit (p, i, bytevec[i]);

  return wrap_bit_vector (p);
}

DEFUN ("make-bit-vector", Fmake_bit_vector, 2, 2, 0, /*
Return a new bit vector of length LENGTH. with each bit set to BIT.
BIT must be one of the integers 0 or 1.  See also the function `bit-vector'.
*/
       (length, bit))
{
  check_integer_range (length, Qzero, make_fixnum (ARRAY_DIMENSION_LIMIT));
  return make_bit_vector (XFIXNUM (length), bit);
}

DEFUN ("bit-vector", Fbit_vector, 0, MANY, 0, /*
Return a newly created bit vector with specified ARGS as elements.
Any number of arguments, even zero arguments, are allowed.
Each argument must be one of the integers 0 or 1.

arguments: (&rest ARGS)
*/
       (int nargs, Lisp_Object *args))
{
  int i;
  Lisp_Bit_Vector *p = make_bit_vector_internal (nargs);

  for (i = 0; i < nargs; i++)
    {
      CHECK_BIT (args[i]);
      set_bit_vector_bit (p, i, !ZEROP (args[i]));
    }

  return wrap_bit_vector (p);
}


/************************************************************************/
/*		     Compiled-function allocation			*/
/************************************************************************/

DECLARE_FIXED_TYPE_ALLOC (compiled_function, Lisp_Compiled_Function);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_compiled_function 1000

static Lisp_Object
make_compiled_function (void)
{
  Lisp_Compiled_Function *f;

  ALLOC_FROB_BLOCK_LISP_OBJECT (compiled_function, Lisp_Compiled_Function,
				f, &lrecord_compiled_function);

  f->stack_depth = 0;
  f->specpdl_depth = 0;
  f->flags.documentationp = 0;
  f->flags.interactivep = 0;
  f->flags.domainp = 0; /* I18N3 */
  f->instructions = Qzero;
  f->constants = Qzero;
  f->arglist = Qnil;
#ifdef NEW_GC
  f->arguments = Qnil;
#else /* not NEW_GC */
  f->args = NULL;
#endif /* not NEW_GC */
  f->max_args = f->min_args = f->args_in_array = 0;
  f->doc_and_interactive = Qnil;
#ifdef COMPILED_FUNCTION_ANNOTATION_HACK
  f->annotated = Qnil;
#endif
  return wrap_compiled_function (f);
}

DEFUN ("make-byte-code", Fmake_byte_code, 4, MANY, 0, /*
Return a new compiled-function object.
Note that, unlike all other emacs-lisp functions, calling this with five
arguments is NOT the same as calling it with six arguments, the last of
which is nil.  If the INTERACTIVE arg is specified as nil, then that means
that this function was defined with `(interactive)'.  If the arg is not
specified, then that means the function is not interactive.
This is terrible behavior which is retained for compatibility with old
`.elc' files which expect these semantics.

arguments: (ARGLIST INSTRUCTIONS CONSTANTS STACK-DEPTH &optional DOC-STRING INTERACTIVE)
*/
       (int nargs, Lisp_Object *args))
{
/* In a non-insane world this function would have this arglist...
   (arglist instructions constants stack_depth &optional doc_string interactive)
 */
  Lisp_Object fun = make_compiled_function ();
  Lisp_Compiled_Function *f = XCOMPILED_FUNCTION (fun);

  Lisp_Object arglist      = args[0];
  Lisp_Object instructions = args[1];
  Lisp_Object constants    = args[2];
  Lisp_Object stack_depth  = args[3];
  Lisp_Object doc_string   = (nargs > 4) ? args[4] : Qnil;
  Lisp_Object interactive  = (nargs > 5) ? args[5] : Qunbound;

  if (nargs < 4 || nargs > 6)
    return Fsignal (Qwrong_number_of_arguments,
		    list2 (intern ("make-byte-code"), make_fixnum (nargs)));

  /* Check for valid formal parameter list now, to allow us to use
     SPECBIND_FAST_UNSAFE() later in funcall_compiled_function(). */
  {
    EXTERNAL_LIST_LOOP_2 (symbol, arglist)
      {
	CHECK_SYMBOL (symbol);
	if (EQ (symbol, Qt)   ||
	    EQ (symbol, Qnil) ||
	    SYMBOL_IS_KEYWORD (symbol))
	  invalid_constant_2
	    ("Invalid constant symbol in formal parameter list",
	     symbol, arglist);
      }
  }
  f->arglist = arglist;

  /* `instructions' is a string or a cons (string . int) for a
     lazy-loaded function. */
  if (CONSP (instructions))
    {
      CHECK_STRING (XCAR (instructions));
      CHECK_FIXNUM (XCDR (instructions));
    }
  else
    {
      CHECK_STRING (instructions);
    }
  f->instructions = instructions;

  if (!NILP (constants))
    CHECK_VECTOR (constants);
  f->constants = constants;

  check_integer_range (stack_depth, Qzero, make_fixnum (USHRT_MAX));
  f->stack_depth = (unsigned short) XFIXNUM (stack_depth);

#ifdef COMPILED_FUNCTION_ANNOTATION_HACK
  f->annotated = Vload_file_name_internal;
#endif /* COMPILED_FUNCTION_ANNOTATION_HACK */

  /* doc_string may be nil, string, int, or a cons (string . int).
     interactive may be list or string (or unbound). */
  f->doc_and_interactive = Qunbound;
#ifdef I18N3
  if ((f->flags.domainp = !NILP (Vfile_domain)) != 0)
    f->doc_and_interactive = Vfile_domain;
#endif
  if ((f->flags.interactivep = !UNBOUNDP (interactive)) != 0)
    {
      f->doc_and_interactive
	= (UNBOUNDP (f->doc_and_interactive) ? interactive :
	   Fcons (interactive, f->doc_and_interactive));
    }
  if ((f->flags.documentationp = !NILP (doc_string)) != 0)
    {
      f->doc_and_interactive
	= (UNBOUNDP (f->doc_and_interactive) ? doc_string :
	   Fcons (doc_string, f->doc_and_interactive));
    }
  if (UNBOUNDP (f->doc_and_interactive))
    f->doc_and_interactive = Qnil;

  return fun;
}


/************************************************************************/
/*			    Symbol allocation				*/
/************************************************************************/

DECLARE_FIXED_TYPE_ALLOC (symbol, Lisp_Symbol);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_symbol 1000

DEFUN ("make-symbol", Fmake_symbol, 1, 1, 0, /*
Return a newly allocated uninterned symbol whose name is NAME.
Its value and function definition are void, and its property list is nil.
*/
       (name))
{
  Lisp_Symbol *p;

  CHECK_STRING (name);

  ALLOC_FROB_BLOCK_LISP_OBJECT_1 (symbol, Lisp_Symbol, p, &lrecord_symbol,
                                  u.lheader);
  p->u.v.package_count = 0;
  p->u.v.first_package_id = 0;

  p->name     = name;
  p->plist    = Qnil;
  p->value    = Qunbound;
  p->function = Qunbound;
  symbol_next (p) = 0;
  return wrap_symbol (p);
}


/************************************************************************/
/*			   Extent allocation				*/
/************************************************************************/

DECLARE_FIXED_TYPE_ALLOC (extent, struct extent);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_extent 1000

struct extent *
allocate_extent (void)
{
  struct extent *e;

  ALLOC_FROB_BLOCK_LISP_OBJECT (extent, struct extent, e, &lrecord_extent);
  extent_object (e) = Qnil;
  set_extent_start (e, -1);
  set_extent_end (e, -1);
  e->plist = Qnil;

  xzero (e->flags);

  extent_face (e) = Qnil;
  e->flags.end_open = 1;  /* default is for endpoints to behave like markers */
  e->flags.detachable = 1;

  return e;
}


/************************************************************************/
/*			   Event allocation				*/
/************************************************************************/

DECLARE_FIXED_TYPE_ALLOC (event, Lisp_Event);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_event 1000

Lisp_Object
allocate_event (void)
{
  Lisp_Event *e;

  ALLOC_FROB_BLOCK_LISP_OBJECT (event, Lisp_Event, e, &lrecord_event);

  return wrap_event (e);
}

#ifdef EVENT_DATA_AS_OBJECTS
DECLARE_FIXED_TYPE_ALLOC (key_data, Lisp_Key_Data);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_key_data 1000

Lisp_Object
make_key_data (void)
{
  Lisp_Key_Data *d;

  ALLOC_FROB_BLOCK_LISP_OBJECT (key_data, Lisp_Key_Data, d,
				    &lrecord_key_data);
  zero_nonsized_lisp_object (wrap_key_data (d));
  d->keysym = Qnil;

  return wrap_key_data (d);
}

DECLARE_FIXED_TYPE_ALLOC (button_data, Lisp_Button_Data);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_button_data 1000

Lisp_Object
make_button_data (void)
{
  Lisp_Button_Data *d;

  ALLOC_FROB_BLOCK_LISP_OBJECT (button_data, Lisp_Button_Data, d,
				&lrecord_button_data);
  zero_nonsized_lisp_object (wrap_button_data (d));
  return wrap_button_data (d);
}

DECLARE_FIXED_TYPE_ALLOC (motion_data, Lisp_Motion_Data);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_motion_data 1000

Lisp_Object
make_motion_data (void)
{
  Lisp_Motion_Data *d;

  ALLOC_FROB_BLOCK_LISP_OBJECT (motion_data, Lisp_Motion_Data, d,
				&lrecord_motion_data);
  zero_nonsized_lisp_object (wrap_motion_data (d));

  return wrap_motion_data (d);
}

DECLARE_FIXED_TYPE_ALLOC (process_data, Lisp_Process_Data);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_process_data 1000

Lisp_Object
make_process_data (void)
{
  Lisp_Process_Data *d;

  ALLOC_FROB_BLOCK_LISP_OBJECT (process_data, Lisp_Process_Data, d,
				&lrecord_process_data);
  zero_nonsized_lisp_object (wrap_process_data (d));
  d->process = Qnil;

  return wrap_process_data (d);
}

DECLARE_FIXED_TYPE_ALLOC (timeout_data, Lisp_Timeout_Data);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_timeout_data 1000

Lisp_Object
make_timeout_data (void)
{
  Lisp_Timeout_Data *d;

  ALLOC_FROB_BLOCK_LISP_OBJECT (timeout_data, Lisp_Timeout_Data, d,
				&lrecord_timeout_data);
  zero_nonsized_lisp_object (wrap_timeout_data (d));
  d->function = Qnil;
  d->object = Qnil;

  return wrap_timeout_data (d);
}

DECLARE_FIXED_TYPE_ALLOC (magic_data, Lisp_Magic_Data);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_magic_data 1000

Lisp_Object
make_magic_data (void)
{
  Lisp_Magic_Data *d;

  ALLOC_FROB_BLOCK_LISP_OBJECT (magic_data, Lisp_Magic_Data, d,
				&lrecord_magic_data);
  zero_nonsized_lisp_object (wrap_magic_data (d));

  return wrap_magic_data (d);
}

DECLARE_FIXED_TYPE_ALLOC (magic_eval_data, Lisp_Magic_Eval_Data);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_magic_eval_data 1000

Lisp_Object
make_magic_eval_data (void)
{
  Lisp_Magic_Eval_Data *d;

  ALLOC_FROB_BLOCK_LISP_OBJECT (magic_eval_data, Lisp_Magic_Eval_Data, d,
				&lrecord_magic_eval_data);
  zero_nonsized_lisp_object (wrap_magic_eval_data (d));
  d->object = Qnil;

  return wrap_magic_eval_data (d);
}

DECLARE_FIXED_TYPE_ALLOC (eval_data, Lisp_Eval_Data);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_eval_data 1000

Lisp_Object
make_eval_data (void)
{
  Lisp_Eval_Data *d;

  ALLOC_FROB_BLOCK_LISP_OBJECT (eval_data, Lisp_Eval_Data, d,
				&lrecord_eval_data);
  zero_nonsized_lisp_object (wrap_eval_data (d));
  d->function = Qnil;
  d->object = Qnil;

  return wrap_eval_data (d);
}

DECLARE_FIXED_TYPE_ALLOC (misc_user_data, Lisp_Misc_User_Data);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_misc_user_data 1000

Lisp_Object
make_misc_user_data (void)
{
  Lisp_Misc_User_Data *d;

  ALLOC_FROB_BLOCK_LISP_OBJECT (misc_user_data, Lisp_Misc_User_Data, d,
				&lrecord_misc_user_data);
  zero_nonsized_lisp_object (wrap_misc_user_data (d));
  d->function = Qnil;
  d->object = Qnil;

  return wrap_misc_user_data (d);
}

#endif /* EVENT_DATA_AS_OBJECTS */

/************************************************************************/
/*			 Marker allocation				*/
/************************************************************************/

DECLARE_FIXED_TYPE_ALLOC (marker, Lisp_Marker);
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_marker 1000

DEFUN ("make-marker", Fmake_marker, 0, 0, 0, /*
Return a new marker which does not point at any place.
*/
       ())
{
  Lisp_Marker *p;

  ALLOC_FROB_BLOCK_LISP_OBJECT (marker, Lisp_Marker, p, &lrecord_marker);
  p->buffer = 0;
  p->membpos = 0;
  marker_next (p) = 0;
  marker_prev (p) = 0;
  p->insertion_type = 0;
  return wrap_marker (p);
}

Lisp_Object
noseeum_make_marker (void)
{
  Lisp_Marker *p;

  NOSEEUM_ALLOC_FROB_BLOCK_LISP_OBJECT (marker, Lisp_Marker, p,
					&lrecord_marker);
  p->buffer = 0;
  p->membpos = 0;
  marker_next (p) = 0;
  marker_prev (p) = 0;
  p->insertion_type = 0;
  return wrap_marker (p);
}


/************************************************************************/
/*			  String allocation				*/
/************************************************************************/

/* The data for "short" strings generally resides inside of structs of type
   string_chars_block. The Lisp_String structure is allocated just like any
   other frob-block lrecord, and these are freelisted when they get garbage
   collected. The data for short strings get compacted, but the data for
   large strings do not.

   Previously Lisp_String structures were relocated, but this caused a lot
   of bus-errors because the C code didn't include enough GCPRO's for
   strings (since EVERY REFERENCE to a short string needed to be GCPRO'd so
   that the reference would get relocated).

   This new method makes things somewhat bigger, but it is MUCH safer.  */

DECLARE_FIXED_TYPE_ALLOC (string, Lisp_String);
/* strings are used and freed quite often */
/* #define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_string 10000 */
#define MINIMUM_ALLOWED_FIXED_TYPE_CELLS_string 1000

static Lisp_Object
mark_string (Lisp_Object obj)
{
  if (CONSP (XSTRING_PLIST (obj)) && EXTENT_INFOP (XCAR (XSTRING_PLIST (obj))))
    flush_cached_extent_info (XCAR (XSTRING_PLIST (obj)));
  return XSTRING_PLIST (obj);
}

static int
string_equal (Lisp_Object obj1, Lisp_Object obj2, int UNUSED (depth),
	      int foldcase)
{
  Bytecount len;
  if (foldcase)
    return !lisp_strcasecmp_i18n (obj1, obj2);
  else
    return (((len = XSTRING_LENGTH (obj1)) == XSTRING_LENGTH (obj2)) &&
	    !memcmp (XSTRING_DATA (obj1), XSTRING_DATA (obj2), len));
}

static const struct memory_description string_description[] = {
#ifdef NEW_GC
  { XD_LISP_OBJECT,     offsetof (Lisp_String, data_object) },
#else /* not NEW_GC */
  { XD_BYTECOUNT,       offsetof (Lisp_String, size_) },
  { XD_OPAQUE_DATA_PTR, offsetof (Lisp_String, data_), XD_INDIRECT(0, 1) },
#endif /* not NEW_GC */
  { XD_LISP_OBJECT,     offsetof (Lisp_String, plist) },
  { XD_END }
};

/* The vast majority of strings have no associated extent info and will never
   be modified. In the interest of conserving memory, we do not keep extent
   info or the modified counter directly in the string object. Instead, we
   abuse the string plist attribute.

   If the first element of the plist is EXTENT_INFOP (a type of object not
   visible to Lisp and which consequently will never end up in the plist in
   the normal course of events), then that is the string's extent info.

   If the next element of the plist is a fixnum and we have flipped a bit in
   the header to document that this string has ever been modified, then that
   fixnum is the string's modified counter.

   The string's true plist starts after any extent info and any modified
   tick. */

static Lisp_Object *
string_plist_ptr (Lisp_Object string)
{
  Lisp_Object *ptr = &XSTRING_PLIST (string);

  if (CONSP (*ptr) && EXTENT_INFOP (XCAR (*ptr)))
    ptr = &XCDR (*ptr);
  if (CONSP (*ptr) && XSTRING_MODIFFP (string))
    {
      structure_checking_assert (FIXNUMP (XCAR (*ptr)));
      ptr = &XCDR (*ptr);
    }
  return ptr;
}

static Lisp_Object
string_getprop (Lisp_Object string, Lisp_Object property)
{
  return external_plist_get (string_plist_ptr (string), property, 0, ERROR_ME);
}

static int
string_putprop (Lisp_Object string, Lisp_Object property, Lisp_Object value)
{
  external_plist_put (string_plist_ptr (string), property, value, 0, ERROR_ME);
  return 1;
}

static int
string_remprop (Lisp_Object string, Lisp_Object property)
{
  return external_remprop (string_plist_ptr (string), property, 0, ERROR_ME);
}

static Lisp_Object
string_plist (Lisp_Object string)
{
  return *string_plist_ptr (string);
}

struct extent_info *
string_extent_info (Lisp_Object string)
{
  Lisp_Object plist = XSTRING_PLIST (string);

  if (CONSP (plist) && EXTENT_INFOP (XCAR (plist)))
    return XEXTENT_INFO (XCAR (plist));

  return NULL;
}

void
bump_string_modiff (Lisp_Object str)
{
  Lisp_Object *ptr = &XSTRING_PLIST (str);

#ifdef I18N3
  /* #### remove the `string-translatable' property from the string,
     if there is one. */
#endif

  /* skip over extent info if it's there */
  if (CONSP (*ptr) && EXTENT_INFOP (XCAR (*ptr)))
    ptr = &XCDR (*ptr);
  if (CONSP (*ptr) && XSTRING_MODIFFP (str))
    {
      structure_checking_assert (FIXNUMP (XCAR (*ptr)));
      XCAR (*ptr) = make_fixnum (1 + XFIXNUM (XCAR (*ptr)));
    }
  else
    {
      XSET_STRING_MODIFFP (str);
      *ptr = Fcons (make_fixnum (1), *ptr);
    }
}

#ifndef NEW_GC
/* No `finalize', or `hash' methods.
   internal_hash() already knows how to hash strings and finalization
   is done with the ADDITIONAL_FREE_string macro, which is the
   standard way to do finalization when using
   SWEEP_FIXED_TYPE_BLOCK(). */

DEFINE_DUMPABLE_FROB_BLOCK_LISP_OBJECT ("string", string,
					mark_string, print_string,
					0, string_equal, 0,
					string_description,
					Lisp_String);
#endif /* not NEW_GC */

#ifdef NEW_GC
#define STRING_FULLSIZE(size) \
  ALIGN_SIZE (FLEXIBLE_ARRAY_STRUCT_SIZEOF (Lisp_String_Direct_Data, Lisp_Object, data, (size) + 1), sizeof (Lisp_Object *));
#else /* not NEW_GC */
/* String blocks contain this many useful bytes. */
#define STRING_CHARS_BLOCK_SIZE					\
  ((Bytecount) (8192 - MALLOC_OVERHEAD -			\
	        ((2 * sizeof (struct string_chars_block *))	\
	         + sizeof (EMACS_INT))))
/* Block header for small strings. */
struct string_chars_block
{
  EMACS_INT pos;
  struct string_chars_block *next;
  struct string_chars_block *prev;
  /* Contents of string_chars_block->string_chars are interleaved
     string_chars structures (see below) and the actual string data */
  unsigned char string_chars[STRING_CHARS_BLOCK_SIZE];
};

static struct string_chars_block *first_string_chars_block;
static struct string_chars_block *current_string_chars_block;

/* If SIZE is the length of a string, this returns how many bytes
 *  the string occupies in string_chars_block->string_chars
 *  (including alignment padding).
 */
#define STRING_FULLSIZE(size) \
   ALIGN_FOR_TYPE (((size) + 1 + sizeof (Lisp_String *)), Lisp_String *)

#define BIG_STRING_FULLSIZE_P(fullsize) ((fullsize) >= STRING_CHARS_BLOCK_SIZE)
#define BIG_STRING_SIZE_P(size) (BIG_STRING_FULLSIZE_P (STRING_FULLSIZE(size)))

#define STRING_CHARS_FREE_P(ptr) ((ptr)->string == NULL)
#define MARK_STRING_CHARS_AS_FREE(ptr) ((void) ((ptr)->string = NULL))
#endif /* not NEW_GC */

#ifdef NEW_GC
DEFINE_DUMPABLE_LISP_OBJECT ("string", string, mark_string, print_string,
			     0, string_equal, 0,
			     string_description, Lisp_String);


static const struct memory_description string_direct_data_description[] = {
  { XD_BYTECOUNT,       offsetof (Lisp_String_Direct_Data, size) },
  { XD_END }
};

static Bytecount
size_string_direct_data (Lisp_Object obj)
{
  return STRING_FULLSIZE (XSTRING_DIRECT_DATA (obj)->size);
}


DEFINE_DUMPABLE_SIZABLE_INTERNAL_LISP_OBJECT ("string-direct-data",
					      string_direct_data,
					      0,
					      string_direct_data_description,
					      size_string_direct_data,
					      Lisp_String_Direct_Data);


static const struct memory_description string_indirect_data_description[] = {
  { XD_BYTECOUNT,       offsetof (Lisp_String_Indirect_Data, size) },
  { XD_OPAQUE_DATA_PTR, offsetof (Lisp_String_Indirect_Data, data), 
    XD_INDIRECT(0, 1) },
  { XD_END }
};

DEFINE_DUMPABLE_INTERNAL_LISP_OBJECT ("string-indirect-data", 
				      string_indirect_data,
				      0,
				      string_indirect_data_description,
				      Lisp_String_Indirect_Data);
#endif /* NEW_GC */

#ifndef NEW_GC
struct string_chars
{
  Lisp_String *string;
  unsigned char chars[1];
};

struct unused_string_chars
{
  Lisp_String *string;
  EMACS_INT fullsize;
};

static void
init_string_chars_alloc (void)
{
  first_string_chars_block = xnew (struct string_chars_block);
  first_string_chars_block->prev = 0;
  first_string_chars_block->next = 0;
  first_string_chars_block->pos = 0;
  current_string_chars_block = first_string_chars_block;
}

static Ibyte *
allocate_big_string_chars (Bytecount length)
{
  Ibyte *p = xnew_array (Ibyte, length);
  INCREMENT_CONS_COUNTER (length, "string chars");
  return p;
}

static struct string_chars *
allocate_string_chars_struct (Lisp_Object string_it_goes_with,
			      Bytecount fullsize)
{
  struct string_chars *s_chars;

  if (fullsize <=
      (countof (current_string_chars_block->string_chars)
       - current_string_chars_block->pos))
    {
      /* This string can fit in the current string chars block */
      s_chars = (struct string_chars *)
	(current_string_chars_block->string_chars
	 + current_string_chars_block->pos);
      current_string_chars_block->pos += fullsize;
    }
  else
    {
      /* Make a new current string chars block */
      struct string_chars_block *new_scb = xnew (struct string_chars_block);

      current_string_chars_block->next = new_scb;
      new_scb->prev = current_string_chars_block;
      new_scb->next = 0;
      current_string_chars_block = new_scb;
      new_scb->pos = fullsize;
      s_chars = (struct string_chars *)
	current_string_chars_block->string_chars;
    }

  s_chars->string = XSTRING (string_it_goes_with);

  INCREMENT_CONS_COUNTER (fullsize, "string chars");

  return s_chars;
}
#endif /* not NEW_GC */

#ifdef SLEDGEHAMMER_CHECK_ASCII_BEGIN
void
sledgehammer_check_ascii_begin (Lisp_Object str)
{
  Bytecount i;

  for (i = 0; i < XSTRING_LENGTH (str); i++)
    {
      if (!byte_ascii_p (string_byte (str, i)))
	break;
    }

  assert (i == (Bytecount) XSTRING_ASCII_BEGIN (str) ||
	  (i > MAX_STRING_ASCII_BEGIN &&
	   (Bytecount) XSTRING_ASCII_BEGIN (str) ==
	   (Bytecount) MAX_STRING_ASCII_BEGIN));
}
#endif

/* You do NOT want to be calling this! (And if you do, you must call
   XSET_STRING_ASCII_BEGIN() after modifying the string.) Use ALLOCA ()
   instead and then call make_string() like the rest of the world. */

Lisp_Object
make_uninit_string (Bytecount length)
{
  Lisp_String *s;
  Bytecount fullsize = STRING_FULLSIZE (length);

  assert (length >= 0 && fullsize > 0);

#ifdef NEW_GC
  s = XSTRING (ALLOC_NORMAL_LISP_OBJECT (string));
#else /* not NEW_GC */
  /* Allocate the string header */
  ALLOCATE_FIXED_TYPE (string, Lisp_String, s);
  xzero (*s);
  set_lheader_implementation (&s->u.lheader, &lrecord_string);
#endif /* not NEW_GC */

  /* The above allocations set the UID field, which overlaps with the
     ascii-length field, to some non-zero value.  We need to zero it. */
  XSET_STRING_ASCII_BEGIN (wrap_string (s), 0);

  /* They also override the MODIFFP flag. */
  XCLEAR_STRING_MODIFFP (wrap_string (s));

#ifdef NEW_GC
  set_lispstringp_direct (s);
  STRING_DATA_OBJECT (s) = 
    alloc_sized_lrecord (fullsize, &lrecord_string_direct_data);
#else /* not NEW_GC */
  set_lispstringp_data (s, BIG_STRING_FULLSIZE_P (fullsize)
			? allocate_big_string_chars (length + 1)
			: allocate_string_chars_struct (wrap_string (s),
							fullsize)->chars);
#endif /* not NEW_GC */

  set_lispstringp_length (s, length);
  s->plist = Qnil;
  set_string_byte (wrap_string (s), length, 0);

  return wrap_string (s);
}

#ifdef VERIFY_STRING_CHARS_INTEGRITY
static void verify_string_chars_integrity (void);
#endif

/* Resize the string S so that DELTA bytes can be inserted starting
   at POS.  If DELTA < 0, it means deletion starting at POS.  If
   POS < 0, resize the string but don't copy any characters.  Use
   this if you're planning on completely overwriting the string.
*/

void
resize_string (Lisp_Object s, Bytecount pos, Bytecount delta)
{
#ifdef NEW_GC
  Bytecount newfullsize, len;
#else /* not NEW_GC */
  Bytecount oldfullsize, newfullsize;
#endif /* not NEW_GC */
#ifdef VERIFY_STRING_CHARS_INTEGRITY
  verify_string_chars_integrity ();
#endif
#ifdef ERROR_CHECK_TEXT
  if (pos >= 0)
    {
      assert (pos <= XSTRING_LENGTH (s));
      if (delta < 0)
	assert (pos + (-delta) <= XSTRING_LENGTH (s));
    }
  else
    {
      if (delta < 0)
	assert ((-delta) <= XSTRING_LENGTH (s));
    }
#endif /* ERROR_CHECK_TEXT */

  if (delta == 0)
    /* simplest case: no size change. */
    return;

  if (pos >= 0 && delta < 0)
    /* If DELTA < 0, the functions below will delete the characters
       before POS.  We want to delete characters *after* POS, however,
       so convert this to the appropriate form. */
    pos += -delta;

#ifdef NEW_GC
  newfullsize = STRING_FULLSIZE (XSTRING_LENGTH (s) + delta);

  len = XSTRING_LENGTH (s) + 1 - pos;
  
  if (delta < 0 && pos >= 0)
    memmove (XSTRING_DATA (s) + pos + delta,
	     XSTRING_DATA (s) + pos, len);
  
  XSTRING_DATA_OBJECT (s) = 
    wrap_string_direct_data (mc_realloc (XPNTR (XSTRING_DATA_OBJECT (s)),
					 newfullsize));
  if (delta > 0 && pos >= 0)
    memmove (XSTRING_DATA (s) + pos + delta, XSTRING_DATA (s) + pos,
	     len);
  
#else /* not NEW_GC */
  oldfullsize = STRING_FULLSIZE (XSTRING_LENGTH (s));
  newfullsize = STRING_FULLSIZE (XSTRING_LENGTH (s) + delta);

  if (BIG_STRING_FULLSIZE_P (oldfullsize))
    {
      if (BIG_STRING_FULLSIZE_P (newfullsize))
	{
	  /* Both strings are big.  We can just realloc().
	     But careful!  If the string is shrinking, we have to
	     memmove() _before_ realloc(), and if growing, we have to
	     memmove() _after_ realloc() - otherwise the access is
	     illegal, and we might crash. */
	  Bytecount len = XSTRING_LENGTH (s) + 1 - pos;

	  if (delta < 0 && pos >= 0)
	    memmove (XSTRING_DATA (s) + pos + delta,
		     XSTRING_DATA (s) + pos, len);
	  XSET_STRING_DATA
	    (s, (Ibyte *) xrealloc (XSTRING_DATA (s),
				      XSTRING_LENGTH (s) + delta + 1));
	  if (delta > 0 && pos >= 0)
	    memmove (XSTRING_DATA (s) + pos + delta, XSTRING_DATA (s) + pos,
		     len);
	  /* Bump the cons counter.
	     Conservative; Martin let the increment be delta. */
	  INCREMENT_CONS_COUNTER (newfullsize, "string chars");
	}
      else /* String has been demoted from BIG_STRING. */
	{
	  Ibyte *new_data =
	    allocate_string_chars_struct (s, newfullsize)->chars;
	  Ibyte *old_data = XSTRING_DATA (s);

	  if (pos >= 0)
	    {
	      memcpy (new_data, old_data, pos);
	      memcpy (new_data + pos + delta, old_data + pos,
		      XSTRING_LENGTH (s) + 1 - pos);
	    }
	  XSET_STRING_DATA (s, new_data);
	  xfree (old_data);
	}
    }
  else /* old string is small */
    {
      if (oldfullsize == newfullsize)
	{
	  /* special case; size change but the necessary
	     allocation size won't change (up or down; code
	     somewhere depends on there not being any unused
	     allocation space, modulo any alignment
	     constraints). */
	  if (pos >= 0)
	    {
	      Ibyte *addroff = pos + XSTRING_DATA (s);

	      memmove (addroff + delta, addroff,
		       /* +1 due to zero-termination. */
		       XSTRING_LENGTH (s) + 1 - pos);
	    }
	}
      else
	{
	  Ibyte *old_data = XSTRING_DATA (s);
	  Ibyte *new_data =
	    BIG_STRING_FULLSIZE_P (newfullsize)
	    ? allocate_big_string_chars (XSTRING_LENGTH (s) + delta + 1)
	    : allocate_string_chars_struct (s, newfullsize)->chars;

	  if (pos >= 0)
	    {
	      memcpy (new_data, old_data, pos);
	      memcpy (new_data + pos + delta, old_data + pos,
		      XSTRING_LENGTH (s) + 1 - pos);
	    }
	  XSET_STRING_DATA (s, new_data);

	  if (!DUMPEDP (old_data)) /* Can't free dumped data. */
	    {
	      /* We need to mark this chunk of the string_chars_block
		 as unused so that compact_string_chars() doesn't
		 freak. */
	      struct string_chars *old_s_chars = (struct string_chars *)
		((char *) old_data - offsetof (struct string_chars, chars));
	      /* Sanity check to make sure we aren't hosed by strange
		 alignment/padding. */
	      assert (old_s_chars->string == XSTRING (s));
	      MARK_STRING_CHARS_AS_FREE (old_s_chars);
	      ((struct unused_string_chars *) old_s_chars)->fullsize =
                  oldfullsize;
	    }
	}
    }
#endif /* not NEW_GC */

  XSET_STRING_LENGTH (s, XSTRING_LENGTH (s) + delta);
  /* If pos < 0, the string won't be zero-terminated.
     Terminate now just to make sure. */
  XSTRING_DATA (s)[XSTRING_LENGTH (s)] = '\0';

  if (pos >= 0)
    /* We also have to adjust all of the extent indices after the
       place we did the change.  We say "pos - 1" because
       adjust_extents() is exclusive of the starting position
       passed to it. */
    adjust_extents (s, pos - 1, XSTRING_LENGTH (s), delta);

#ifdef VERIFY_STRING_CHARS_INTEGRITY
  verify_string_chars_integrity ();
#endif
}

#ifdef MULE

/* WARNING: If you modify an existing string, you must call
   CHECK_LISP_WRITEABLE() before and bump_string_modiff() afterwards. */
void
set_string_char (Lisp_Object s, Charcount i, Ichar c)
{
  Ibyte newstr[MAX_ICHAR_LEN];
  Bytecount bytoff = string_index_char_to_byte (s, i);
  Bytecount oldlen = itext_ichar_len (XSTRING_DATA (s) + bytoff);
  Bytecount newlen = set_itext_ichar (newstr, c);

  sledgehammer_check_ascii_begin (s);
  if (oldlen != newlen)
    resize_string (s, bytoff, newlen - oldlen);
  /* Remember, XSTRING_DATA (s) might have changed so we can't cache it. */
  memcpy (XSTRING_DATA (s) + bytoff, newstr, newlen);
  if (oldlen != newlen) 
    {
      if (newlen > 1 && i <= (Charcount) XSTRING_ASCII_BEGIN (s))
      /* Everything starting with the new char is no longer part of
	 ascii_begin */
	XSET_STRING_ASCII_BEGIN (s, i);
      else if (newlen == 1 && i == (Charcount) XSTRING_ASCII_BEGIN (s))
	/* We've extended ascii_begin, and we have to figure out how much by */
	{
	  Bytecount j;
	  for (j = (Bytecount) i + 1; j < XSTRING_LENGTH (s); j++)
	    {
	      if (!byte_ascii_p (XSTRING_DATA (s)[j]))
		break;
	    }
	  XSET_STRING_ASCII_BEGIN (s, min (j, (Bytecount) MAX_STRING_ASCII_BEGIN));
	}
    }
  sledgehammer_check_ascii_begin (s);
}

#endif /* MULE */

DEFUN ("make-string", Fmake_string, 2, 2, 0, /*
Return a new string consisting of LENGTH copies of CHARACTER.
LENGTH must be a non-negative integer.
*/
       (length, character))
{
  check_integer_range (length, Qzero, make_fixnum (ARRAY_DIMENSION_LIMIT));
  CHECK_CHAR_COERCE_INT (character);
  {
    Ibyte init_str[MAX_ICHAR_LEN];
    int len = set_itext_ichar (init_str, XCHAR (character));
    Lisp_Object val = make_uninit_string (len * XFIXNUM (length));

    if (len == 1)
      {
	/* Optimize the single-byte case */
	memset (XSTRING_DATA (val), XCHAR (character), XSTRING_LENGTH (val));
	XSET_STRING_ASCII_BEGIN (val, min (MAX_STRING_ASCII_BEGIN,
					   len * XFIXNUM (length)));
      }
    else
      {
	EMACS_INT i;
	Ibyte *ptr = XSTRING_DATA (val);

	for (i = XFIXNUM (length); i; i--)
	  {
	    Ibyte *init_ptr = init_str;
	    switch (len)
	      {
	      case 4: *ptr++ = *init_ptr++;
	      case 3: *ptr++ = *init_ptr++;
	      case 2: *ptr++ = *init_ptr++;
	      case 1: *ptr++ = *init_ptr++;
	      }
	  }
      }
    sledgehammer_check_ascii_begin (val);
    return val;
  }
}

DEFUN ("string", Fstring, 0, MANY, 0, /*
Concatenate all the argument characters and make the result a string.

arguments: (&rest ARGS)
*/
       (int nargs, Lisp_Object *args))
{
  Ibyte *storage = alloca_ibytes (nargs * MAX_ICHAR_LEN);
  Ibyte *p = storage;

  for (; nargs; nargs--, args++)
    {
      Lisp_Object lisp_char = *args;
      CHECK_CHAR_COERCE_INT (lisp_char);
      p += set_itext_ichar (p, XCHAR (lisp_char));
    }
  return make_string (storage, p - storage);
}

DEFUN ("string-modified-tick", Fstring_modified_tick, 1, 1, 0, /*
Return STRING's tick counter, incremented for each change to the string.
Each string has a tick counter which is incremented each time the contents
of the string are changed (e.g. with `aset').  It wraps around occasionally.
*/
       (string))
{
  Lisp_Object plist;
  CHECK_STRING (string);

  plist = XSTRING_PLIST (string);
  if (CONSP (plist) && EXTENT_INFOP (XCAR (plist)))
    {
      plist = XCDR (plist);
    }

  if (CONSP (plist) && XSTRING_MODIFFP (string))
    {
      return XCAR (plist);
    }

  return Qzero;
}

/* Initialize the ascii_begin member of a string to the correct value. */

void
init_string_ascii_begin (Lisp_Object string)
{
#ifdef MULE
  int i;
  Bytecount length = XSTRING_LENGTH (string);
  Ibyte *contents = XSTRING_DATA (string);

  for (i = 0; i < length; i++)
    {
      if (!byte_ascii_p (contents[i]))
	break;
    }
  XSET_STRING_ASCII_BEGIN (string, min (i, MAX_STRING_ASCII_BEGIN));
#else
  XSET_STRING_ASCII_BEGIN (string, min (XSTRING_LENGTH (string),
					MAX_STRING_ASCII_BEGIN));
#endif
  sledgehammer_check_ascii_begin (string);
}

/* Take some raw memory, which MUST already be in internal format,
   and package it up into a Lisp string. */
Lisp_Object
make_string (const Ibyte *contents, Bytecount length)
{
  Lisp_Object val;

  /* Make sure we find out about bad make_string's when they happen */
#if defined (ERROR_CHECK_TEXT) && defined (MULE)
  bytecount_to_charcount (contents, length); /* Just for the assertions */
#endif

  val = make_uninit_string (length);
  memcpy (XSTRING_DATA (val), contents, length);
  init_string_ascii_begin (val);
  sledgehammer_check_ascii_begin (val);  
  return val;
}

/* Take some raw memory, encoded in some external data format,
   and convert it into a Lisp string. */
Lisp_Object
make_extstring (const Extbyte *contents, EMACS_INT length,
		 Lisp_Object coding_system)
{
  Lisp_Object string;
  TO_INTERNAL_FORMAT (DATA, (contents, length),
		      LISP_STRING, string,
		      coding_system);
  return string;
}

Lisp_Object
build_istring (const Ibyte *str)
{
  /* Some strlen's crash and burn if passed null. */
  return make_string (str, (str ? qxestrlen (str) : (Bytecount) 0));
}

Lisp_Object
build_cistring (const CIbyte *str)
{
  return build_istring ((const Ibyte *) str);
}

Lisp_Object
build_ascstring (const Ascbyte *str)
{
  ASSERT_ASCTEXT_ASCII (str);
  return build_istring ((const Ibyte *) str);
}

Lisp_Object
build_extstring (const Extbyte *str, Lisp_Object coding_system)
{
  /* Some strlen's crash and burn if passed null. */
  return make_extstring ((const Extbyte *) str,
			  (str ? dfc_external_data_len (str, coding_system) :
			   0),
			  coding_system);
}

/* Build a string whose content is a translatable message, and translate
   the message according to the current language environment. */

Lisp_Object
build_msg_istring (const Ibyte *str)
{
  return build_istring (IGETTEXT (str));
}

/* Build a string whose content is a translatable message, and translate
   the message according to the current language environment. */

Lisp_Object
build_msg_cistring (const CIbyte *str)
{
  return build_msg_istring ((const Ibyte *) str);
}

/* Build a string whose content is a translatable message, and translate
   the message according to the current language environment.
   String must be pure-ASCII, and when compiled with error-checking,
   an abort will have if not pure-ASCII. */

Lisp_Object
build_msg_ascstring (const Ascbyte *str)
{
  ASSERT_ASCTEXT_ASCII (str);
  return build_msg_istring ((const Ibyte *) str);
}

/* Build a string whose content is a translatable message, but don't
   translate the message immediately.  Perhaps do something else instead,
   such as put a property on the string indicating that it needs to be
   translated.

   This is useful for strings that are built at dump time or init time,
   rather than on-the-fly when the current language environment is set
   properly. */

Lisp_Object
build_defer_istring (const Ibyte *str)
{
  Lisp_Object retval = build_istring ((Ibyte *) str);
  /* Possibly do something to the return value */
  return retval;
}

Lisp_Object
build_defer_cistring (const CIbyte *str)
{
  return build_defer_istring ((Ibyte *) str);
}

Lisp_Object
build_defer_ascstring (const Ascbyte *str)
{
  ASSERT_ASCTEXT_ASCII (str);
  return build_defer_istring ((Ibyte *) str);
}

Lisp_Object
make_string_nocopy (const Ibyte *contents, Bytecount length)
{
  Lisp_String *s;
  Lisp_Object val;

  /* Make sure we find out about bad make_string_nocopy's when they happen */
#if defined (ERROR_CHECK_TEXT) && defined (MULE)
  bytecount_to_charcount (contents, length); /* Just for the assertions */
#endif

#ifdef NEW_GC
  s = XSTRING (ALLOC_NORMAL_LISP_OBJECT (string));
  mcpro (wrap_pointer_1 (s)); /* otherwise nocopy_strings get
				 collected and static data is tried to
				 be freed. */
#else /* not NEW_GC */
  /* Allocate the string header */
  ALLOCATE_FIXED_TYPE (string, Lisp_String, s);
  set_lheader_implementation (&s->u.lheader, &lrecord_string);
  SET_C_READONLY_RECORD_HEADER (&s->u.lheader);
#endif /* not NEW_GC */
  /* Don't need to XSET_STRING_ASCII_BEGIN() here because it happens in
     init_string_ascii_begin(). */
  s->plist = Qnil;
#ifdef NEW_GC
  set_lispstringp_indirect (s);
  STRING_DATA_OBJECT (s) = ALLOC_NORMAL_LISP_OBJECT (string_indirect_data);
  XSTRING_INDIRECT_DATA_DATA (STRING_DATA_OBJECT (s)) = (Ibyte *) contents;
  XSTRING_INDIRECT_DATA_SIZE (STRING_DATA_OBJECT (s)) = length;
#else /* not NEW_GC */
  set_lispstringp_data (s, (Ibyte *) contents);
  set_lispstringp_length (s, length);
#endif /* not NEW_GC */
  val = wrap_string (s);
  init_string_ascii_begin (val);
  sledgehammer_check_ascii_begin (val);

  return val;
}


#ifndef NEW_GC
/************************************************************************/
/*                           lcrecord lists                             */
/************************************************************************/

/* Lcrecord lists are used to manage the allocation of particular
   sorts of lcrecords, to avoid calling ALLOC_NORMAL_LISP_OBJECT() (and thus
   malloc() and garbage-collection junk) as much as possible.
   It is similar to the Blocktype class.

   See detailed comment in lcrecord.h.
*/

const struct memory_description free_description[] = {
  { XD_LISP_OBJECT, offsetof (struct free_lcrecord_header, chain), 0, { 0 },
    XD_FLAG_FREE_LISP_OBJECT },
  { XD_END }
};

DEFINE_NODUMP_INTERNAL_LISP_OBJECT ("free", free, 0, free_description,
				    struct free_lcrecord_header);

const struct memory_description lcrecord_list_description[] = {
  { XD_LISP_OBJECT, offsetof (struct lcrecord_list, free), 0, { 0 },
    XD_FLAG_FREE_LISP_OBJECT },
  { XD_END }
};

static Lisp_Object
mark_lcrecord_list (Lisp_Object obj)
{
  struct lcrecord_list *list = XLCRECORD_LIST (obj);
  Lisp_Object chain = list->free;

  while (!NILP (chain))
    {
      struct lrecord_header *lheader = XRECORD_LHEADER (chain);
      struct free_lcrecord_header *free_header =
	(struct free_lcrecord_header *) lheader;

      gc_checking_assert
	(/* There should be no other pointers to the free list. */
	 ! MARKED_RECORD_HEADER_P (lheader)
	 &&
	 /* Only lcrecords should be here. */
	 ! list->implementation->frob_block_p
	 &&
	 /* Only free lcrecords should be here. */
	 lheader->free
	 &&
	 /* The type of the lcrecord must be right. */
	 lheader->type == lrecord_type_free
	 &&
	 /* So must the size. */
	 (list->implementation->static_size == 0 ||
	  list->implementation->static_size == list->size)
	 );

      MARK_RECORD_HEADER (lheader);
      chain = free_header->chain;
    }

  return Qnil;
}

DEFINE_NODUMP_INTERNAL_LISP_OBJECT ("lcrecord-list", lcrecord_list,
				    mark_lcrecord_list,
				    lcrecord_list_description,
				    struct lcrecord_list);

Lisp_Object
make_lcrecord_list (Elemcount size,
		    const struct lrecord_implementation *implementation)
{
  /* Don't use alloc_automanaged_lcrecord() avoid infinite recursion
     allocating this. */
  struct lcrecord_list *p =
    XLCRECORD_LIST (old_alloc_lcrecord (&lrecord_lcrecord_list));

  p->implementation = implementation;
  p->size = size;
  p->free = Qnil;
  return wrap_lcrecord_list (p);
}

Lisp_Object
alloc_managed_lcrecord (Lisp_Object lcrecord_list)
{
  struct lcrecord_list *list = XLCRECORD_LIST (lcrecord_list);
  if (!NILP (list->free))
    {
      Lisp_Object val = list->free;
      struct free_lcrecord_header *free_header =
	(struct free_lcrecord_header *) XPNTR (val);
      struct lrecord_header *lheader = &free_header->lcheader.lheader;

#ifdef ERROR_CHECK_GC
      /* Major overkill here. */
      /* There should be no other pointers to the free list. */
      assert (! MARKED_RECORD_HEADER_P (lheader));
      /* Only free lcrecords should be here. */
      assert (lheader->free);
      assert (lheader->type == lrecord_type_free);
      /* Only lcrecords should be here. */
      assert (! (list->implementation->frob_block_p));
#if 0 /* Not used anymore, now that we set the type of the header to
	 lrecord_type_free. */
      /* The type of the lcrecord must be right. */
      assert (LHEADER_IMPLEMENTATION (lheader) == list->implementation);
#endif /* 0 */
      /* So must the size. */
      assert (list->implementation->static_size == 0 ||
	      list->implementation->static_size == list->size);
#endif /* ERROR_CHECK_GC */

      list->free = free_header->chain;
      lheader->free = 0;
      /* Put back the correct type, as we set it to lrecord_type_free. */
      lheader->type = list->implementation->lrecord_type_index;
      zero_sized_lisp_object (val, list->size);
      return val;
    }
  else
    return old_alloc_sized_lcrecord (list->size, list->implementation);
}

/* "Free" a Lisp object LCRECORD by placing it on its associated free list
   LCRECORD_LIST; next time alloc_managed_lcrecord() is called with the
   same LCRECORD_LIST as its parameter, it will return an object from the
   free list, which may be this one.  Be VERY VERY SURE there are no
   pointers to this object hanging around anywhere where they might be
   used!

   The first thing this does before making any global state change is to
   call the finalize method of the object, if it exists. */

void
free_managed_lcrecord (Lisp_Object lcrecord_list, Lisp_Object lcrecord)
{
  struct lcrecord_list *list = XLCRECORD_LIST (lcrecord_list);
  struct free_lcrecord_header *free_header =
    (struct free_lcrecord_header *) XPNTR (lcrecord);
  struct lrecord_header *lheader = &free_header->lcheader.lheader;
  const struct lrecord_implementation *implementation
    = LHEADER_IMPLEMENTATION (lheader);

  /* If we try to debug-print during GC, we'll likely get a crash on the
     following assert (called from Lstream_delete(), from prin1_to_string()).
     Instead, just don't do anything.  Worst comes to worst, we have a
     small memory leak -- and programs being debugged usually won't be
     super long-lived afterwards, anyway. */
  if (gc_in_progress && in_debug_print)
    return;

  /* Finalizer methods may try to free objects within them, which typically
     won't be marked and thus are scheduled for demolition.  Putting them
     on the free list would be very bad, as we'd have xfree()d memory in
     the list.  Even if for some reason the objects are still live
     (generally a logic error!), we still will have problems putting such
     an object on the free list right now (e.g. we'd have to avoid calling
     the finalizer twice, etc.).  So basically, those finalizers should not
     be freeing any objects if during GC.  Abort now to catch those
     problems. */
  gc_checking_assert (!gc_in_progress);
  
  /* Make sure the size is correct.  This will catch, for example,
     putting a window configuration on the wrong free list. */
  gc_checking_assert (lisp_object_size (lcrecord) == list->size);
  /* Make sure the object isn't already freed. */
  gc_checking_assert (!lheader->free);
  /* Freeing stuff in dumped memory is bad.  If you trip this, you
     may need to check for this before freeing. */
  gc_checking_assert (!OBJECT_DUMPED_P (lcrecord));
  
  if (implementation->finalizer)
    implementation->finalizer (lcrecord);
  /* Yes, there are two ways to indicate freeness -- the type is
     lrecord_type_free or the ->free flag is set.  We used to do only the
     latter; now we do the former as well for KKCC purposes.  Probably
     safer in any case, as we will lose quicker this way than keeping
     around an lrecord of apparently correct type but bogus junk in it. */
  MARK_LRECORD_AS_FREE (lheader);
  free_header->chain = list->free;
  lheader->free = 1;
  list->free = lcrecord;
}

static Lisp_Object all_lcrecord_lists[countof (lrecord_implementations_table)];

Lisp_Object
alloc_automanaged_sized_lcrecord (Bytecount size,
				  const struct lrecord_implementation *imp)
{
  if (EQ (all_lcrecord_lists[imp->lrecord_type_index], Qzero))
    all_lcrecord_lists[imp->lrecord_type_index] =
      make_lcrecord_list (size, imp);

  return alloc_managed_lcrecord (all_lcrecord_lists[imp->lrecord_type_index]);
}

Lisp_Object
alloc_automanaged_lcrecord (const struct lrecord_implementation *imp)
{
  type_checking_assert (imp->static_size > 0);
  return alloc_automanaged_sized_lcrecord (imp->static_size, imp);
}

void
old_free_lcrecord (Lisp_Object rec)
{
  int type = XRECORD_LHEADER (rec)->type;

  assert (!EQ (all_lcrecord_lists[type], Qzero));

  free_managed_lcrecord (all_lcrecord_lists[type], rec);
}
#endif /* not NEW_GC */


/************************************************************************/
/*                           Staticpro, MCpro                           */
/************************************************************************/

/* We want the staticpro list relocated, but not the pointers found
   therein, because they refer to locations in the global data segment, not
   in the heap; we only dump heap objects.  Hence we use a trivial
   description, as for pointerless objects. (Note that the data segment
   objects, which are global variables like Qfoo or Vbar, themselves are
   pointers to heap objects.  Each needs to be described to pdump as a
   "root pointer"; this happens in the call to staticpro(). */
static const struct memory_description staticpro_description_1[] = {
  { XD_END }
};

static const struct sized_memory_description staticpro_description = {
  sizeof (Lisp_Object *),
  staticpro_description_1
};

static const struct memory_description staticpros_description_1[] = {
  XD_DYNARR_DESC (Lisp_Object_ptr_dynarr, &staticpro_description),
  { XD_END }
};

static const struct sized_memory_description staticpros_description = {
  sizeof (Lisp_Object_ptr_dynarr),
  staticpros_description_1
};

#ifdef DEBUG_XEMACS

/* Help debug crashes gc-marking a staticpro'ed object. */

Lisp_Object_ptr_dynarr *staticpros;
const_Ascbyte_ptr_dynarr *staticpro_names;

/* Mark the Lisp_Object at non-heap VARADDRESS as a root object for
   garbage collection, and for dumping. */
void
staticpro_1 (Lisp_Object *varaddress, const Ascbyte *varname)
{
  Dynarr_add (staticpros, varaddress);
  Dynarr_add (staticpro_names, varname);
  dump_add_root_lisp_object (varaddress);
}

const Ascbyte *staticpro_name (int count);

/* External debugging function: Return the name of the variable at offset
   COUNT. */
const Ascbyte *
staticpro_name (int count)
{
  return Dynarr_at (staticpro_names, count);
}

Lisp_Object_ptr_dynarr *staticpros_nodump;
const_Ascbyte_ptr_dynarr *staticpro_nodump_names;

/* Mark the Lisp_Object at heap VARADDRESS as a root object for
   garbage collection, but not for dumping. (See below.) */
void
staticpro_nodump_1 (Lisp_Object *varaddress, const Ascbyte *varname)
{
  Dynarr_add (staticpros_nodump, varaddress);
  Dynarr_add (staticpro_nodump_names, varname);
}

const Ascbyte *staticpro_nodump_name (int count);

/* External debugging function: Return the name of the variable at offset
   COUNT. */
const Ascbyte *
staticpro_nodump_name (int count)
{
  return Dynarr_at (staticpro_nodump_names, count);
}

#ifdef HAVE_SHLIB
/* Stop treating the Lisp_Object at non-heap VARADDRESS as a root object
   for garbage collection, but not for dumping. */
void
unstaticpro_nodump_1 (Lisp_Object *varaddress, const Ascbyte *varname)
{
  Dynarr_delete_object (staticpros, varaddress);
  Dynarr_delete_object (staticpro_names, varname);
}
#endif

#else /* not DEBUG_XEMACS */

Lisp_Object_ptr_dynarr *staticpros;

/* Mark the Lisp_Object at non-heap VARADDRESS as a root object for
   garbage collection, and for dumping. */
void
staticpro (Lisp_Object *varaddress)
{
  Dynarr_add (staticpros, varaddress);
  dump_add_root_lisp_object (varaddress);
}


Lisp_Object_ptr_dynarr *staticpros_nodump;

/* Mark the Lisp_Object at heap VARADDRESS as a root object for garbage
   collection, but not for dumping.  This is used for objects where the
   only sure pointer is in the heap (rather than in the global data
   segment, as must be the case for pdump root pointers), but not inside of
   another Lisp object (where it will be marked as a result of that Lisp
   object's mark method).  The call to staticpro_nodump() must occur *BOTH*
   at initialization time and at "reinitialization" time (startup, after
   pdump load.) (For example, this is the case with the predicate symbols
   for specifier and coding system types.  The pointer to this symbol is
   inside of a methods structure, which is allocated on the heap.  The
   methods structure will be written out to the pdump data file, and may be
   reloaded at a different address.)

   #### The necessity for reinitialization is a bug in pdump.  Pdump should
   automatically regenerate the staticpro()s for these symbols when it
   loads the data in. */

void
staticpro_nodump (Lisp_Object *varaddress)
{
  Dynarr_add (staticpros_nodump, varaddress);
}

#ifdef HAVE_SHLIB
/* Unmark the Lisp_Object at non-heap VARADDRESS as a root object for
   garbage collection, but not for dumping. */
void
unstaticpro_nodump (Lisp_Object *varaddress)
{
  Dynarr_delete_object (staticpros, varaddress);
}
#endif

#endif /* not DEBUG_XEMACS */

#ifdef NEW_GC
static const struct memory_description mcpro_description_1[] = {
  { XD_END }
};

static const struct sized_memory_description mcpro_description = {
  sizeof (Lisp_Object *),
  mcpro_description_1
};

static const struct memory_description mcpros_description_1[] = {
  XD_DYNARR_DESC (Lisp_Object_dynarr, &mcpro_description),
  { XD_END }
};

static const struct sized_memory_description mcpros_description = {
  sizeof (Lisp_Object_dynarr),
  mcpros_description_1
};

#ifdef DEBUG_XEMACS

/* Help debug crashes gc-marking a mcpro'ed object. */

Lisp_Object_dynarr *mcpros;
const_Ascbyte_ptr_dynarr *mcpro_names;

/* Mark the Lisp_Object at non-heap VARADDRESS as a root object for
   garbage collection, and for dumping. */
void
mcpro_1 (Lisp_Object varaddress, const Ascbyte *varname)
{
  Dynarr_add (mcpros, varaddress);
  Dynarr_add (mcpro_names, varname);
}

const Ascbyte *mcpro_name (int count);

/* External debugging function: Return the name of the variable at offset
   COUNT. */
const Ascbyte *
mcpro_name (int count)
{
  return Dynarr_at (mcpro_names, count);
}

#else /* not DEBUG_XEMACS */

Lisp_Object_dynarr *mcpros;

/* Mark the Lisp_Object at non-heap VARADDRESS as a root object for
   garbage collection, and for dumping. */
void
mcpro (Lisp_Object varaddress)
{
  Dynarr_add (mcpros, varaddress);
}

#endif /* not DEBUG_XEMACS */
#endif /* NEW_GC */

#ifdef ALLOC_TYPE_STATS


/************************************************************************/
/*                   Determining allocation overhead                    */
/************************************************************************/

/* Attempt to determine the actual amount of space that is used for
   the block allocated starting at PTR, supposedly of size "CLAIMED_SIZE".

   It seems that the following holds:

   1. When using the old allocator (malloc.c):

      -- blocks are always allocated in chunks of powers of two.  For
	 each block, there is an overhead of 8 bytes if rcheck is not
	 defined, 20 bytes if it is defined.  In other words, a
	 one-byte allocation needs 8 bytes of overhead for a total of
	 9 bytes, and needs to have 16 bytes of memory chunked out for
	 it.

   2. When using the new allocator (gmalloc.c):

      -- blocks are always allocated in chunks of powers of two up
         to 4096 bytes.  Larger blocks are allocated in chunks of
	 an integral multiple of 4096 bytes.  The minimum block
         size is 2*sizeof (void *), or 16 bytes if SUNOS_LOCALTIME_BUG
	 is defined.  There is no per-block overhead, but there
	 is an overhead of 3*sizeof (size_t) for each 4096 bytes
	 allocated.

    3. When using the system malloc, anything goes, but they are
       generally slower and more space-efficient than the GNU
       allocators.  One possibly reasonable assumption to make
       for want of better data is that sizeof (void *), or maybe
       2 * sizeof (void *), is required as overhead and that
       blocks are allocated in the minimum required size except
       that some minimum block size is imposed (e.g. 16 bytes). */

Bytecount
malloced_storage_size (void * UNUSED (ptr), Bytecount claimed_size,
		       struct usage_stats *stats)
{
  Bytecount orig_claimed_size = claimed_size;

#ifndef SYSTEM_MALLOC
  if (claimed_size < (Bytecount) (2 * sizeof (void *)))
    claimed_size = 2 * sizeof (void *);
# ifdef SUNOS_LOCALTIME_BUG
  if (claimed_size < 16)
    claimed_size = 16;
# endif
  if (claimed_size < 4096)
    {
      /* fxg: rename log->log2 to suppress gcc3 shadow warning */
      int log2 = 1;

      /* compute the log base two, more or less, then use it to compute
	 the block size needed. */
      claimed_size--;
      /* It's big, it's heavy, it's wood! */
      while ((claimed_size /= 2) != 0)
	++log2;
      claimed_size = 1;
      /* It's better than bad, it's good! */
      while (log2 > 0)
        {
	  claimed_size *= 2;
          log2--;
        }
      /* We have to come up with some average about the amount of
	 blocks used. */
      if ((Bytecount) (rand () & 4095) < claimed_size)
	claimed_size += 3 * sizeof (void *);
    }
  else
    {
      claimed_size += 4095;
      claimed_size &= ~4095;
      claimed_size += (claimed_size / 4096) * 3 * sizeof (size_t);
    }

#else

  if (claimed_size < 16)
    claimed_size = 16;
  claimed_size += 2 * sizeof (void *);

#endif /* system allocator */

  if (stats)
    {
      stats->was_requested += orig_claimed_size;
      stats->malloc_overhead += claimed_size - orig_claimed_size;
    }
  return claimed_size;
}

#ifndef NEW_GC
static Bytecount
fixed_type_block_overhead (Bytecount size, Bytecount per_block)
{
  Bytecount overhead = 0;
  Bytecount storage_size = malloced_storage_size (0, per_block, 0);
  while (size >= per_block)
    {
      size -= per_block;
      overhead += storage_size - per_block;
    }
  if (rand () % per_block < size)
    overhead += storage_size - per_block;
  return overhead;
}
#endif /* not NEW_GC */

Bytecount
lisp_object_storage_size (Lisp_Object obj, struct usage_stats *ustats)
{
#ifndef NEW_GC
  const struct lrecord_implementation *imp;
#endif /* not NEW_GC */
  Bytecount size;

  if (!LRECORDP (obj))
    return 0;

  size = lisp_object_size (obj);

#ifdef NEW_GC
  return mc_alloced_storage_size (size, ustats);
#else
  imp = XRECORD_LHEADER_IMPLEMENTATION (obj);
  if (imp->frob_block_p)
    {
      Bytecount overhead =
	/* #### Always using cons_block is incorrect but close; only
	   string_chars_block is significantly different in size, and
	   it won't ever be seen in this function */
	fixed_type_block_overhead (size, sizeof (struct cons_block));
      if (ustats)
	{
	  ustats->was_requested += size;
	  ustats->malloc_overhead += overhead;
	}
      return size + overhead;
    }
  else
    return malloced_storage_size (XPNTR (obj), size, ustats);
#endif
}


/************************************************************************/
/*                  Allocation Statistics: Accumulate                   */
/************************************************************************/

#ifdef NEW_GC

void
init_lrecord_stats (void)
{
  xzero (lrecord_stats);
}

void
inc_lrecord_stats (Bytecount size, const struct lrecord_header *h)
{
  int type_index = h->type;
  if (!size)
    size = detagged_lisp_object_size (h);

  lrecord_stats[type_index].instances_in_use++;
  lrecord_stats[type_index].bytes_in_use += size;
  lrecord_stats[type_index].bytes_in_use_including_overhead
#ifdef MEMORY_USAGE_STATS
    += mc_alloced_storage_size (size, 0);
#else /* not MEMORY_USAGE_STATS */
    += size;
#endif /* not MEMORY_USAGE_STATS */
}

void
dec_lrecord_stats (Bytecount size_including_overhead, 
		   const struct lrecord_header *h)
{
  int type_index = h->type;
  int size = detagged_lisp_object_size (h);

  lrecord_stats[type_index].instances_in_use--;
  lrecord_stats[type_index].bytes_in_use -= size;
  lrecord_stats[type_index].bytes_in_use_including_overhead
    -= size_including_overhead;

  DECREMENT_CONS_COUNTER (size);
}

int
lrecord_stats_heap_size (void)
{
  int i;
  int size = 0;
  for (i = 0; i < countof (lrecord_implementations_table); i++)
    size += lrecord_stats[i].bytes_in_use;
  return size;
}

#else /* not NEW_GC */

static void
clear_lrecord_stats (void)
{
  xzero (lrecord_stats);
  gc_count_num_short_string_in_use = 0;
  gc_count_string_total_size = 0;
  gc_count_short_string_total_size = 0;
  gc_count_long_string_storage_including_overhead = 0;
}

/* Keep track of extra statistics for strings -- length of the string
   characters for short and long strings, number of short and long strings. */
static void
tick_string_stats (Lisp_String *p, int from_sweep)
{
  Bytecount size = p->size_;
  gc_count_string_total_size += size;
  if (!BIG_STRING_SIZE_P (size))
    {
      gc_count_short_string_total_size += size;
      gc_count_num_short_string_in_use++;
    }
  else
    gc_count_long_string_storage_including_overhead +=
      malloced_storage_size (p->data_, p->size_, NULL);
  /* During the sweep stage, we count the total number of strings in use.
     This gets those not stored in pdump storage.  For pdump storage, we
     need to bump the number of strings in use so as to get an accurate
     count of all strings in use (pdump or not).  But don't do this when
     called from the sweep stage, or we will double-count. */
  if (!from_sweep)
    gc_count_num_string_in_use++;
}

/* As objects are sweeped, we record statistics about their memory usage.
   Currently, all lcrecords are processed this way as well as any frob-block
   objects that were saved and restored as a result of the pdump process.
   (See pdump_objects_unmark().) Other frob-block objects do NOT get their
   statistics noted this way -- instead, as the frob blocks are swept,
   COPY_INTO_LRECORD_STATS() is called, and notes statistics about the
   frob blocks. */

void
tick_lrecord_stats (const struct lrecord_header *h,
		    enum lrecord_alloc_status status)
{
  int type_index = h->type;
  Lisp_Object obj = wrap_pointer_1 (h);
  Bytecount sz = lisp_object_size (obj);
  Bytecount sz_with_overhead = lisp_object_storage_size (obj, NULL);
  Bytecount overhead = sz_with_overhead - sz;

  switch (status)
    {
    case ALLOC_IN_USE:
      lrecord_stats[type_index].instances_in_use++;
      lrecord_stats[type_index].bytes_in_use += sz;
      lrecord_stats[type_index].bytes_in_use_overhead += overhead;
      if (STRINGP (obj))
	tick_string_stats (XSTRING (obj), 0);
#ifdef MEMORY_USAGE_STATS
      {
	struct generic_usage_stats stats;
	if (HAS_OBJECT_METH_P (obj, memory_usage))
	  {
	    int i;
	    int total_stats = OBJECT_PROPERTY (obj, num_extra_memusage_stats);
	    xzero (stats);
	    OBJECT_METH (obj, memory_usage, (obj, &stats));
	    for (i = 0; i < total_stats; i++)
	      lrecord_stats[type_index].stats.othervals[i] +=
		stats.othervals[i];
	  }
      }
#endif
      break;
    case ALLOC_FREE:
      lrecord_stats[type_index].instances_freed++;
      lrecord_stats[type_index].bytes_freed += sz;
      lrecord_stats[type_index].bytes_freed_overhead += overhead;
      break;
    case ALLOC_ON_FREE_LIST:
      lrecord_stats[type_index].instances_on_free_list++;
      lrecord_stats[type_index].bytes_on_free_list += sz;
      lrecord_stats[type_index].bytes_on_free_list_overhead += overhead;
      break;
    default:
      ABORT ();
    }
}

inline static void
tick_lcrecord_stats (const struct lrecord_header *h, int free_p)
{
  if (h->free)
    {
      gc_checking_assert (!free_p);
      tick_lrecord_stats (h, ALLOC_ON_FREE_LIST);
    }
  else
    tick_lrecord_stats (h, free_p ? ALLOC_FREE : ALLOC_IN_USE);
}

#endif /* (not) NEW_GC */

void
finish_object_memory_usage_stats (void)
{
  /* Here we add up the aggregate values for each statistic, previously
     computed during tick_lrecord_stats(), to get a single combined value
     of non-Lisp memory usage for all objects of each type.  We can't
     do this if NEW_GC because nothing like tick_lrecord_stats() gets
     called -- instead, statistics are computed when objects are allocated,
     which is too early to be calling the memory_usage() method. */
#if defined (MEMORY_USAGE_STATS) && !defined (NEW_GC)
  int i;
  for (i = 0; i < countof (lrecord_implementations_table); i++)
    {
      struct lrecord_implementation *imp = lrecord_implementations_table[i];
      if (imp && imp->num_extra_nonlisp_memusage_stats)
	{
	  int j;
	  for (j = 0; j < imp->num_extra_nonlisp_memusage_stats; j++)
	    lrecord_stats[i].nonlisp_bytes_in_use +=
	      lrecord_stats[i].stats.othervals[j];
	}
      if (imp && imp->num_extra_lisp_ancillary_memusage_stats)
	{
	  int j;
	  for (j = 0; j < imp->num_extra_lisp_ancillary_memusage_stats; j++)
	    lrecord_stats[i].lisp_ancillary_bytes_in_use +=
	      lrecord_stats[i].stats.othervals
	      [j + imp->offset_lisp_ancillary_memusage_stats];
	}
    }
#endif /* defined (MEMORY_USAGE_STATS) && !defined (NEW_GC) */
}

#define COUNT_FROB_BLOCK_USAGE(type)					\
  EMACS_INT s = 0;							\
  EMACS_INT s_overhead = 0;						\
  struct type##_block *x = current_##type##_block;			\
  while (x) { s += sizeof (*x) + MALLOC_OVERHEAD; x = x->prev; }	\
  s_overhead = fixed_type_block_overhead (s, sizeof (struct type##_block)); \
  DO_NOTHING

#define COPY_INTO_LRECORD_STATS(type)				\
do {								\
  COUNT_FROB_BLOCK_USAGE (type);				\
  lrecord_stats[lrecord_type_##type].bytes_in_use += s;		\
  lrecord_stats[lrecord_type_##type].bytes_in_use_overhead +=	\
    s_overhead;							\
  lrecord_stats[lrecord_type_##type].instances_on_free_list +=	\
    gc_count_num_##type##_freelist;				\
  lrecord_stats[lrecord_type_##type].instances_in_use +=	\
    gc_count_num_##type##_in_use;				\
} while (0)


/************************************************************************/
/*                 Allocation statistics: format nicely                 */
/************************************************************************/

static Lisp_Object
gc_plist_hack (const Ascbyte *name, EMACS_INT value, Lisp_Object tail)
{
  /* C doesn't have local functions (or closures, or GC, or readable syntax,
     or portable numeric datatypes, or bit-vectors, or characters, or
     arrays, or exceptions, or ...) */
  return cons3 (intern (name), make_fixnum (value), tail);
}

/* Pluralize a lowercase English word stored in BUF, assuming BUF has
   enough space to hold the extra letters (at most 2). */
static void
pluralize_word (Ascbyte *buf)
{
  Bytecount len = strlen (buf);
  int upper = 0;
  Ascbyte d, e;

  if (len == 0 || len == 1)
    goto pluralize_apostrophe_s;
  e = buf[len - 1];
  d = buf[len - 2];
  upper = isupper (e);
  e = tolower (e);
  d = tolower (d);
  if (e == 'y')
    {
      switch (d)
	{
	case 'a':
	case 'e':
	case 'i':
	case 'o':
	case 'u':
	  goto pluralize_s;
	default:
	  buf[len - 1] = (upper ? 'I' : 'i');
	  goto pluralize_es;
	}
    }
  else if (e == 's' || e == 'x' || (e == 'h' && (d == 's' || d == 'c')))
    {
      pluralize_es:
      buf[len++] = (upper ? 'E' : 'e');
    }
  pluralize_s:
  buf[len++] = (upper ? 'S' : 's');
  buf[len] = '\0';
  return;

  pluralize_apostrophe_s:
  buf[len++] = '\'';
  goto pluralize_s;
}

static void
pluralize_and_append (Ascbyte *buf, const Ascbyte *name, const Ascbyte *suffix)
{
  strcpy (buf, name);
  pluralize_word (buf);
  strcat (buf, suffix);
}

static Lisp_Object
object_memory_usage_stats (int set_total_gc_usage)
{
  Lisp_Object pl = Qnil;
  int i;
  EMACS_INT tgu_val = 0;

#ifdef NEW_GC
  for (i = 0; i < countof (lrecord_implementations_table); i++)
    {
      if (lrecord_stats[i].instances_in_use != 0)
        {
          Ascbyte buf[255];
          const Ascbyte *name = lrecord_implementations_table[i]->name;

	  if (lrecord_stats[i].bytes_in_use_including_overhead != 
	      lrecord_stats[i].bytes_in_use)
	    {
	      sprintf (buf, "%s-storage-including-overhead", name);
	      pl = gc_plist_hack (buf, 
				  lrecord_stats[i]
				  .bytes_in_use_including_overhead,
				  pl);
	    }
	  
	  sprintf (buf, "%s-storage", name);
	  pl = gc_plist_hack (buf, 
			      lrecord_stats[i].bytes_in_use,
			      pl);
	  tgu_val += lrecord_stats[i].bytes_in_use_including_overhead;

	  pluralize_and_append (buf, name, "-used");
	  pl = gc_plist_hack (buf, lrecord_stats[i].instances_in_use, pl);
        }
    }

#else /* not NEW_GC */

  for (i = 0; i < lrecord_type_count; i++)
    {
      if (lrecord_stats[i].bytes_in_use != 0
          || lrecord_stats[i].bytes_freed != 0
	  || lrecord_stats[i].instances_on_free_list != 0)
        {
          Ascbyte buf[255];
          const Ascbyte *name = lrecord_implementations_table[i]->name;

          sprintf (buf, "%s-storage-overhead", name);
          pl = gc_plist_hack (buf, lrecord_stats[i].bytes_in_use_overhead, pl);
	  tgu_val += lrecord_stats[i].bytes_in_use_overhead;
          sprintf (buf, "%s-storage", name);
          pl = gc_plist_hack (buf, lrecord_stats[i].bytes_in_use, pl);
	  tgu_val += lrecord_stats[i].bytes_in_use;
#ifdef MEMORY_USAGE_STATS
	  if (lrecord_stats[i].nonlisp_bytes_in_use)
	    {
	      sprintf (buf, "%s-non-lisp-storage", name);
	      pl = gc_plist_hack (buf, lrecord_stats[i].nonlisp_bytes_in_use,
				  pl);
	      tgu_val += lrecord_stats[i].nonlisp_bytes_in_use;
	    }
	  if (lrecord_stats[i].lisp_ancillary_bytes_in_use)
	    {
	      sprintf (buf, "%s-lisp-ancillary-storage", name);
	      pl = gc_plist_hack (buf, lrecord_stats[i].
				  lisp_ancillary_bytes_in_use,
				  pl);
	      tgu_val += lrecord_stats[i].lisp_ancillary_bytes_in_use;
	    }
#endif /* MEMORY_USAGE_STATS */
	  pluralize_and_append (buf, name, "-freed");
          if (lrecord_stats[i].instances_freed != 0)
            pl = gc_plist_hack (buf, lrecord_stats[i].instances_freed, pl);
	  pluralize_and_append (buf, name, "-on-free-list");
          if (lrecord_stats[i].instances_on_free_list != 0)
            pl = gc_plist_hack (buf, lrecord_stats[i].instances_on_free_list,
				pl);
	  pluralize_and_append (buf, name, "-used");
          pl = gc_plist_hack (buf, lrecord_stats[i].instances_in_use, pl);
        }
    }

  pl = gc_plist_hack ("long-string-chars-storage-overhead",
                      gc_count_long_string_storage_including_overhead -
		      (gc_count_string_total_size
		       - gc_count_short_string_total_size), pl);
  pl = gc_plist_hack ("long-string-chars-storage",
                      gc_count_string_total_size
		      - gc_count_short_string_total_size, pl);
  do
    {
      COUNT_FROB_BLOCK_USAGE (string_chars);
      tgu_val += s + s_overhead;
      pl = gc_plist_hack ("short-string-chars-storage-overhead", s_overhead, pl);
      pl = gc_plist_hack ("short-string-chars-storage", s, pl);
    }
  while (0);

  pl = gc_plist_hack ("long-strings-total-length",
                      gc_count_string_total_size
		      - gc_count_short_string_total_size, pl);
  pl = gc_plist_hack ("short-strings-total-length",
                      gc_count_short_string_total_size, pl);
  pl = gc_plist_hack ("long-strings-used",
                      gc_count_num_string_in_use
		      - gc_count_num_short_string_in_use, pl);
  pl = gc_plist_hack ("short-strings-used",
                      gc_count_num_short_string_in_use, pl);

#endif /* NEW_GC */

  if (set_total_gc_usage)
    {
      total_gc_usage = tgu_val;
      total_gc_usage_set = 1;
    }

  return pl;
}

static Lisp_Object
garbage_collection_statistics (void)
{
  /* The things we do for backwards-compatibility */
#ifdef NEW_GC
  return
    list6 
    (Fcons (make_fixnum (lrecord_stats[lrecord_type_cons].instances_in_use),
	    make_fixnum (lrecord_stats[lrecord_type_cons]
		      .bytes_in_use_including_overhead)),
     Fcons (make_fixnum (lrecord_stats[lrecord_type_symbol].instances_in_use),
	    make_fixnum (lrecord_stats[lrecord_type_symbol]
		      .bytes_in_use_including_overhead)),
     Fcons (make_fixnum (lrecord_stats[lrecord_type_marker].instances_in_use),
	    make_fixnum (lrecord_stats[lrecord_type_marker]
		      .bytes_in_use_including_overhead)),
     make_fixnum (lrecord_stats[lrecord_type_string]
	       .bytes_in_use_including_overhead),
     make_fixnum (lrecord_stats[lrecord_type_vector]
	       .bytes_in_use_including_overhead),
     object_memory_usage_stats (1));
#else /* not NEW_GC */
  return
    list6 (Fcons (make_fixnum (gc_count_num_cons_in_use),
		  make_fixnum (gc_count_num_cons_freelist)),
	   Fcons (make_fixnum (gc_count_num_symbol_in_use),
		  make_fixnum (gc_count_num_symbol_freelist)),
	   Fcons (make_fixnum (gc_count_num_marker_in_use),
		  make_fixnum (gc_count_num_marker_freelist)),
	   make_fixnum (gc_count_string_total_size),
	   make_fixnum (lrecord_stats[lrecord_type_vector].bytes_in_use +
		     lrecord_stats[lrecord_type_vector].bytes_freed +
		     lrecord_stats[lrecord_type_vector].bytes_on_free_list),
	   object_memory_usage_stats (1));
#endif /* not NEW_GC */
}

DEFUN ("object-memory-usage-stats", Fobject_memory_usage_stats, 0, 0, 0, /*
Return statistics about memory usage of Lisp objects.
*/
       ())
{
  return object_memory_usage_stats (0);
}

#endif /* ALLOC_TYPE_STATS */

#ifdef MEMORY_USAGE_STATS

DEFUN ("object-memory-usage", Fobject_memory_usage, 1, 1, 0, /*
Return stats about the memory usage of OBJECT.
The values returned are in the form of an alist of usage types and byte
counts.  The byte counts attempt to encompass all the memory used
by the object (separate from the memory logically associated with any
other object), including internal structures and any malloc()
overhead associated with them.  In practice, the byte counts are
underestimated because certain memory usage is very hard to determine
\(e.g. the amount of memory used inside the Xt library or inside the
X server).

Multiple slices of the total memory usage may be returned, separated
by a nil.  Each slice represents a particular view of the memory, a
particular way of partitioning it into groups.  Within a slice, there
is no overlap between the groups of memory, and each slice collectively
represents all the memory concerned.  The rightmost slice typically
represents the total memory used plus malloc and dynarr overhead.

Slices describing other Lisp objects logically associated with the
object may be included, separated from other slices by `t' and from
each other by nil if there is more than one.

#### We have to figure out how to handle the memory used by the object
itself vs. the memory used by substructures.  Probably the memory_usage
method should return info only about substructures and related Lisp
objects, since the caller can always find and all info about the object
itself.
*/
       (object))
{
  struct generic_usage_stats gustats;
  struct usage_stats object_stats;
  int i;
  Lisp_Object val = Qnil;
  Lisp_Object stats_list;

  if (!LRECORDP (object))
    invalid_argument
      ("No memory associated with immediate objects (int or char)", object);

  stats_list = OBJECT_PROPERTY (object, memusage_stats_list);

  xzero (object_stats);
  lisp_object_storage_size (object, &object_stats);

  val = Facons (Qobject_actually_requested,
		make_fixnum (object_stats.was_requested), val);
  val = Facons (Qobject_malloc_overhead,
		make_fixnum (object_stats.malloc_overhead), val);
  assert (!object_stats.dynarr_overhead);
  assert (!object_stats.gap_overhead);

  if (!NILP (stats_list))
    {
      xzero (gustats);
      MAYBE_OBJECT_METH (object, memory_usage, (object, &gustats));

      val = Fcons (Qt, val);
      val = Facons (Qother_memory_actually_requested,
		    make_fixnum (gustats.u.was_requested), val);
      val = Facons (Qother_memory_malloc_overhead,
		    make_fixnum (gustats.u.malloc_overhead), val);
      if (gustats.u.dynarr_overhead)
	val = Facons (Qother_memory_dynarr_overhead,
		      make_fixnum (gustats.u.dynarr_overhead), val);
      if (gustats.u.gap_overhead)
	val = Facons (Qother_memory_gap_overhead,
		      make_fixnum (gustats.u.gap_overhead), val);
      val = Fcons (Qnil, val);

      i = 0;
      {
	LIST_LOOP_2 (item, stats_list)
	  {
	    if (NILP (item) || EQ (item, Qt))
	      val = Fcons (item, val);
	    else
	      {
		val = Facons (item, make_fixnum (gustats.othervals[i]), val);
		i++;
	      }
	  }
      }
    }

  return Fnreverse (val);
}

/* Compute total memory usage associated with an object, including

   (a) Storage (including overhead) allocated to the object itself
   (b) Storage (including overhead) for ancillary non-Lisp structures attached
       to the object
   (c) Storage (including overhead) for ancillary Lisp objects attached
       to the object

   Store the three types of memory into the return values provided they
   aren't NULL, and return a sum of the three values.  Also store the
   structure of individual statistics into STATS if non-zero.

   Note that the value for type (c) is the sum of all three types of
   memory associated with the ancillary Lisp objects.
*/

Bytecount
lisp_object_memory_usage_full (Lisp_Object object, Bytecount *storage_size,
			       Bytecount *extra_nonlisp_storage,
			       Bytecount *extra_lisp_ancillary_storage,
			       struct generic_usage_stats *stats)
{
  Bytecount total;

  total = lisp_object_storage_size (object, NULL);
  if (storage_size)
    *storage_size = total;

  if (LRECORDP (object) && HAS_OBJECT_METH_P (object, memory_usage))
    {
      int i;
      struct generic_usage_stats gustats;
      Bytecount sum;
      struct lrecord_implementation *imp =
	XRECORD_LHEADER_IMPLEMENTATION (object);

      xzero (gustats);
      OBJECT_METH (object, memory_usage, (object, &gustats));

      if (stats)
	*stats = gustats;

      sum = 0;
      for (i = 0; i < imp->num_extra_nonlisp_memusage_stats; i++)
	sum += gustats.othervals[i];
      total += sum;
      if (extra_nonlisp_storage)
	*extra_nonlisp_storage = sum;

      sum = 0;
      for (i = 0; i < imp->num_extra_lisp_ancillary_memusage_stats; i++)
	sum += gustats.othervals[imp->offset_lisp_ancillary_memusage_stats +
				 i];
      total += sum;
      if (extra_lisp_ancillary_storage)
	*extra_lisp_ancillary_storage = sum;
    }
  else
    {
      if (extra_nonlisp_storage)
	*extra_nonlisp_storage = 0;
      if (extra_lisp_ancillary_storage)
	*extra_lisp_ancillary_storage = 0;
    }

  return total;
}


Bytecount
lisp_object_memory_usage (Lisp_Object object)
{
  return lisp_object_memory_usage_full (object, NULL, NULL, NULL, NULL);
}

static Bytecount
tree_memory_usage_1 (Lisp_Object arg, int vectorp, int depth)
{
  Bytecount total = 0;

  if (depth > 200)
    return total;
    
  if (CONSP (arg))
    {
      SAFE_LIST_LOOP_3 (elt, arg, tail)
	{
	  total += lisp_object_memory_usage (tail);
	  if (CONSP (elt) || VECTORP (elt))
	    total += tree_memory_usage_1 (elt, vectorp, depth + 1);
	  if (VECTORP (XCDR (tail))) /* hack for (a b . [c d]) */
	    total += tree_memory_usage_1 (XCDR (tail), vectorp, depth +1);
	}
    }
  else if (VECTORP (arg) && vectorp)
    {
      int i = XVECTOR_LENGTH (arg);
      int j;
      total += lisp_object_memory_usage (arg);
      for (j = 0; j < i; j++)
	{
	  Lisp_Object elt = XVECTOR_DATA (arg) [j];
	  if (CONSP (elt) || VECTORP (elt))
	    total += tree_memory_usage_1 (elt, vectorp, depth + 1);
	}
    }
  return total;
}

Bytecount
tree_memory_usage (Lisp_Object arg, int vectorp)
{
  return tree_memory_usage_1 (arg, vectorp, 0);
}

#endif /* MEMORY_USAGE_STATS */

#ifdef ALLOC_TYPE_STATS

DEFUN ("total-object-memory-usage", Ftotal_object_memory_usage, 0, 0, 0, /*
Return total number of bytes used for object storage in XEmacs.
This may be helpful in debugging XEmacs's memory usage.
See also `consing-since-gc' and `object-memory-usage-stats'.
*/
       ())
{
  return make_fixnum (total_gc_usage + consing_since_gc);
}

#endif /* ALLOC_TYPE_STATS */


/************************************************************************/
/*                Allocation statistics: Initialization                 */
/************************************************************************/
#ifdef MEMORY_USAGE_STATS

/* Compute the number of extra memory-usage statistics associated with an
   object.  We can't compute this at the time INIT_LISP_OBJECT() is called
   because the value of the `memusage_stats_list' property is generally
   set afterwards.  So we compute the values for all types of objects
   after all objects have been initialized. */

static void
compute_memusage_stats_length (void)
{
  int i;

  for (i = 0; i < countof (lrecord_implementations_table); i++)
    {
      struct lrecord_implementation *imp = lrecord_implementations_table[i];

      if (!imp)
	continue;
      /* For some of the early objects, Qnil was not yet initialized at
	 the time of object initialization, so it came up as Qnull_pointer.
	 Fix that now. */
      if (EQ (imp->memusage_stats_list, Qnull_pointer))
	imp->memusage_stats_list = Qnil;
      {
	Elemcount len = 0;
	Elemcount nonlisp_len = 0;
	Elemcount lisp_len = 0;
	Elemcount lisp_offset = 0;
	int group_num = 0;
	int slice_num = 0;

	LIST_LOOP_2 (item, imp->memusage_stats_list)
	  {
	    if (EQ (item, Qt))
	      {
		group_num++;
		if (group_num == 1)
		  lisp_offset = len;
		slice_num = 0;
	      }
	    else if (EQ (item, Qnil))
	      {
		slice_num++;
	      }
	    else
	      {
		if (slice_num == 0)
		  {
		    if (group_num == 0)
		      nonlisp_len++;
		    else if (group_num == 1)
		      lisp_len++;
		  }
		len++;
	      }
	  }

	imp->num_extra_memusage_stats = len;
	imp->num_extra_nonlisp_memusage_stats = nonlisp_len;
	imp->num_extra_lisp_ancillary_memusage_stats = lisp_len;
	imp->offset_lisp_ancillary_memusage_stats = lisp_offset;
      }
    }
}

#endif /* MEMORY_USAGE_STATS */


/************************************************************************/
/*                 Garbage Collection -- Sweep/Compact                  */
/************************************************************************/

#ifndef NEW_GC
/* Free all unmarked records */
static void
sweep_lcrecords_1 (struct old_lcrecord_header **prev, int *used)
{
  struct old_lcrecord_header *header;
  int num_used = 0;
  /* int total_size = 0; */

  /* First go through and call all the finalize methods.
     Then go through and free the objects.  There used to
     be only one loop here, with the call to the finalizer
     occurring directly before the xfree() below.  That
     is marginally faster but much less safe -- if the
     finalize method for an object needs to reference any
     other objects contained within it (and many do),
     we could easily be screwed by having already freed that
     other object. */

  for (header = *prev; header; header = header->next)
    {
      struct lrecord_header *h = &(header->lheader);

      GC_CHECK_LHEADER_INVARIANTS (h);

      if (! MARKED_RECORD_HEADER_P (h) && !h->free)
	{
	  if (LHEADER_IMPLEMENTATION (h)->finalizer)
	    LHEADER_IMPLEMENTATION (h)->finalizer (wrap_pointer_1 (h));
	}
    }

  for (header = *prev; header; )
    {
      struct lrecord_header *h = &(header->lheader);
      if (MARKED_RECORD_HEADER_P (h))
	{
	  if (! C_READONLY_RECORD_HEADER_P (h))
	    UNMARK_RECORD_HEADER (h);
	  num_used++;
	  /* total_size += n->implementation->size_in_bytes (h);*/
	  /* #### May modify header->next on a C_READONLY lcrecord */
	  prev = &(header->next);
	  header = *prev;
	  tick_lcrecord_stats (h, 0);
	}
      else
	{
	  struct old_lcrecord_header *next = header->next;
          *prev = next;
	  tick_lcrecord_stats (h, 1);
	  /* used to call finalizer right here. */
	  xfree (header);
	  header = next;
	}
    }
  *used = num_used;
  /* *total = total_size; */
}

/* And the Lord said: Thou shalt use the `c-backslash-region' command
   to make macros prettier. */

#ifdef ERROR_CHECK_GC

#define SWEEP_FIXED_TYPE_BLOCK_1(typename, obj_type, lheader)		\
do {									\
  struct typename##_block *SFTB_current;				\
  int SFTB_limit;							\
  int num_free = 0, num_used = 0;					\
									\
  for (SFTB_current = current_##typename##_block,			\
       SFTB_limit = current_##typename##_block_index;			\
       SFTB_current;							\
       )								\
    {									\
      int SFTB_iii;							\
									\
      for (SFTB_iii = 0; SFTB_iii < SFTB_limit; SFTB_iii++)		\
	{								\
	  obj_type *SFTB_victim = &(SFTB_current->block[SFTB_iii]);	\
									\
	  if (LRECORD_FREE_P (SFTB_victim))				\
	    {								\
	      num_free++;						\
	    }								\
	  else if (C_READONLY_RECORD_HEADER_P (&SFTB_victim->lheader))	\
	    {								\
	      num_used++;						\
	    }								\
	  else if (! MARKED_RECORD_HEADER_P (&SFTB_victim->lheader))	\
	    {								\
	      num_free++;						\
	      FREE_FIXED_TYPE (typename, obj_type, SFTB_victim);	\
	    }								\
	  else								\
	    {								\
	      num_used++;						\
	      UNMARK_##typename (SFTB_victim);				\
	    }								\
	}								\
      SFTB_current = SFTB_current->prev;				\
      SFTB_limit = countof (current_##typename##_block->block);		\
    }									\
									\
  gc_count_num_##typename##_in_use = num_used;				\
  gc_count_num_##typename##_freelist = num_free;			\
  COPY_INTO_LRECORD_STATS (typename);					\
} while (0)

#else /* !ERROR_CHECK_GC */

#define SWEEP_FIXED_TYPE_BLOCK_1(typename, obj_type, lheader)		\
do {									\
  struct typename##_block *SFTB_current;				\
  struct typename##_block **SFTB_prev;					\
  int SFTB_limit;							\
  int num_free = 0, num_used = 0;					\
									\
  typename##_free_list = 0;						\
									\
  for (SFTB_prev = &current_##typename##_block,				\
       SFTB_current = current_##typename##_block,			\
       SFTB_limit = current_##typename##_block_index;			\
       SFTB_current;							\
       )								\
    {									\
      int SFTB_iii;							\
      int SFTB_empty = 1;						\
      Lisp_Free *SFTB_old_free_list = typename##_free_list;		\
									\
      for (SFTB_iii = 0; SFTB_iii < SFTB_limit; SFTB_iii++)		\
	{								\
	  obj_type *SFTB_victim = &(SFTB_current->block[SFTB_iii]);	\
									\
	  if (LRECORD_FREE_P (SFTB_victim))				\
	    {								\
	      num_free++;						\
	      PUT_FIXED_TYPE_ON_FREE_LIST (typename, obj_type, SFTB_victim); \
	    }								\
	  else if (C_READONLY_RECORD_HEADER_P (&SFTB_victim->lheader))	\
	    {								\
	      SFTB_empty = 0;						\
	      num_used++;						\
	    }								\
	  else if (! MARKED_RECORD_HEADER_P (&SFTB_victim->lheader))	\
	    {								\
	      num_free++;						\
	      FREE_FIXED_TYPE (typename, obj_type, SFTB_victim);	\
	    }								\
	  else								\
	    {								\
	      SFTB_empty = 0;						\
	      num_used++;						\
	      UNMARK_##typename (SFTB_victim);				\
	    }								\
	}								\
      if (!SFTB_empty)							\
	{								\
	  SFTB_prev = &(SFTB_current->prev);				\
	  SFTB_current = SFTB_current->prev;				\
	}								\
      else if (SFTB_current == current_##typename##_block		\
	       && !SFTB_current->prev)					\
	{								\
	  /* No real point in freeing sole allocation block */		\
	  break;							\
	}								\
      else								\
	{								\
	  struct typename##_block *SFTB_victim_block = SFTB_current;	\
	  if (SFTB_victim_block == current_##typename##_block)		\
	    current_##typename##_block_index				\
	      = countof (current_##typename##_block->block);		\
	  SFTB_current = SFTB_current->prev;				\
	  {								\
	    *SFTB_prev = SFTB_current;					\
	    xfree (SFTB_victim_block);					\
	    /* Restore free list to what it was before victim was swept */ \
	    typename##_free_list = SFTB_old_free_list;			\
	    num_free -= SFTB_limit;					\
	  }								\
	}								\
      SFTB_limit = countof (current_##typename##_block->block);		\
    }									\
									\
  gc_count_num_##typename##_in_use = num_used;				\
  gc_count_num_##typename##_freelist = num_free;			\
  COPY_INTO_LRECORD_STATS (typename);					\
} while (0)

#endif /* !ERROR_CHECK_GC */

#define SWEEP_FIXED_TYPE_BLOCK(typename, obj_type) \
  SWEEP_FIXED_TYPE_BLOCK_1 (typename, obj_type, lheader)

#endif /* not NEW_GC */


#ifndef NEW_GC
static void
sweep_conses (void)
{
#define UNMARK_cons(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_cons(ptr)

  SWEEP_FIXED_TYPE_BLOCK (cons, Lisp_Cons);
}
#endif /* not NEW_GC */

/* Explicitly free a cons cell.  */
void
free_cons (Lisp_Object cons)
{
#ifndef NEW_GC /* to avoid compiler warning */
  Lisp_Cons *ptr = XCONS (cons);
#endif /* not NEW_GC */

#ifdef ERROR_CHECK_GC
#ifdef NEW_GC
  Lisp_Cons *ptr = XCONS (cons);
#endif /* NEW_GC */
  /* If the CAR is not an int, then it will be a pointer, which will
     always be four-byte aligned.  If this cons cell has already been
     placed on the free list, however, its car will probably contain
     a chain pointer to the next cons on the list, which has cleverly
     had all its 0's and 1's inverted.  This allows for a quick
     check to make sure we're not freeing something already freed.

     NOTE: This check may not be necessary.  Freeing an object sets its
     type to lrecord_type_free, which will trip up the XCONS() above -- as
     well as a check in FREE_FIXED_TYPE(). */
  if (POINTER_TYPE_P (XTYPE (cons_car (ptr))))
    ASSERT_VALID_POINTER (XPNTR (cons_car (ptr)));
#endif /* ERROR_CHECK_GC */

  FREE_FIXED_TYPE_WHEN_NOT_IN_GC (cons, cons, Lisp_Cons, ptr);
}

/* explicitly free a list.  You **must make sure** that you have
   created all the cons cells that make up this list and that there
   are no pointers to any of these cons cells anywhere else.  If there
   are, you will lose. */

void
free_list (Lisp_Object list)
{
  Lisp_Object rest, next;

  for (rest = list; !NILP (rest); rest = next)
    {
      next = XCDR (rest);
      free_cons (rest);
    }
}

/* explicitly free an alist.  You **must make sure** that you have
   created all the cons cells that make up this alist and that there
   are no pointers to any of these cons cells anywhere else.  If there
   are, you will lose. */

void
free_alist (Lisp_Object alist)
{
  Lisp_Object rest, next;

  for (rest = alist; !NILP (rest); rest = next)
    {
      next = XCDR (rest);
      free_cons (XCAR (rest));
      free_cons (rest);
    }
}

#ifndef NEW_GC
static void
sweep_compiled_functions (void)
{
#define UNMARK_compiled_function(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_compiled_function(ptr) \
  if (ptr->args_in_array) xfree (ptr->args)

  SWEEP_FIXED_TYPE_BLOCK (compiled_function, Lisp_Compiled_Function);
}

static void
sweep_floats (void)
{
#define UNMARK_float(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_float(ptr)

  SWEEP_FIXED_TYPE_BLOCK (float, Lisp_Float);
}

#ifdef HAVE_BIGNUM
static void
sweep_bignums (void)
{
#define UNMARK_bignum(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_bignum(ptr) bignum_fini (ptr->data)

  SWEEP_FIXED_TYPE_BLOCK (bignum, Lisp_Bignum);
}
#endif /* HAVE_BIGNUM */

#ifdef HAVE_RATIO
static void
sweep_ratios (void)
{
#define UNMARK_ratio(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_ratio(ptr) ratio_fini (ptr->data)

  SWEEP_FIXED_TYPE_BLOCK (ratio, Lisp_Ratio);
}
#endif /* HAVE_RATIO */

#ifdef HAVE_BIGFLOAT
static void
sweep_bigfloats (void)
{
#define UNMARK_bigfloat(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_bigfloat(ptr) bigfloat_fini (ptr->bf)

  SWEEP_FIXED_TYPE_BLOCK (bigfloat, Lisp_Bigfloat);
}
#endif

static void
sweep_symbols (void)
{
#define UNMARK_symbol(ptr) UNMARK_RECORD_HEADER (&(((ptr)->u.lheader)))
#define ADDITIONAL_FREE_symbol(ptr)

  SWEEP_FIXED_TYPE_BLOCK_1 (symbol, Lisp_Symbol, u.lheader);
}

static void
sweep_extents (void)
{
#define UNMARK_extent(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_extent(ptr)

  SWEEP_FIXED_TYPE_BLOCK (extent, struct extent);
}

static void
sweep_events (void)
{
#define UNMARK_event(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_event(ptr)

  SWEEP_FIXED_TYPE_BLOCK (event, Lisp_Event);
}
#endif /* not NEW_GC */

#ifdef EVENT_DATA_AS_OBJECTS

#ifndef NEW_GC
static void
sweep_key_data (void)
{
#define UNMARK_key_data(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_key_data(ptr)

  SWEEP_FIXED_TYPE_BLOCK (key_data, Lisp_Key_Data);
}
#endif /* not NEW_GC */

void
free_key_data (Lisp_Object ptr)
{
  FREE_FIXED_TYPE_WHEN_NOT_IN_GC (ptr, key_data, Lisp_Key_Data,
				  XKEY_DATA (ptr));
}

#ifndef NEW_GC
static void
sweep_button_data (void)
{
#define UNMARK_button_data(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_button_data(ptr)

  SWEEP_FIXED_TYPE_BLOCK (button_data, Lisp_Button_Data);
}
#endif /* not NEW_GC */

void
free_button_data (Lisp_Object ptr)
{
  FREE_FIXED_TYPE_WHEN_NOT_IN_GC (ptr, button_data, Lisp_Button_Data,
				  XBUTTON_DATA (ptr));
}

#ifndef NEW_GC
static void
sweep_motion_data (void)
{
#define UNMARK_motion_data(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_motion_data(ptr)

  SWEEP_FIXED_TYPE_BLOCK (motion_data, Lisp_Motion_Data);
}
#endif /* not NEW_GC */

void
free_motion_data (Lisp_Object ptr)
{
  FREE_FIXED_TYPE_WHEN_NOT_IN_GC (ptr, motion_data, Lisp_Motion_Data,
				  XMOTION_DATA (ptr));
}

#ifndef NEW_GC
static void
sweep_process_data (void)
{
#define UNMARK_process_data(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_process_data(ptr)

  SWEEP_FIXED_TYPE_BLOCK (process_data, Lisp_Process_Data);
}
#endif /* not NEW_GC */

void
free_process_data (Lisp_Object ptr)
{
  FREE_FIXED_TYPE_WHEN_NOT_IN_GC (ptr, process_data, Lisp_Process_Data,
				  XPROCESS_DATA (ptr));
}

#ifndef NEW_GC
static void
sweep_timeout_data (void)
{
#define UNMARK_timeout_data(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_timeout_data(ptr)

  SWEEP_FIXED_TYPE_BLOCK (timeout_data, Lisp_Timeout_Data);
}
#endif /* not NEW_GC */

void
free_timeout_data (Lisp_Object ptr)
{
  FREE_FIXED_TYPE_WHEN_NOT_IN_GC (ptr, timeout_data, Lisp_Timeout_Data,
				  XTIMEOUT_DATA (ptr));
}

#ifndef NEW_GC
static void
sweep_magic_data (void)
{
#define UNMARK_magic_data(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_magic_data(ptr)

  SWEEP_FIXED_TYPE_BLOCK (magic_data, Lisp_Magic_Data);
}
#endif /* not NEW_GC */

void
free_magic_data (Lisp_Object ptr)
{
  FREE_FIXED_TYPE_WHEN_NOT_IN_GC (ptr, magic_data, Lisp_Magic_Data,
				  XMAGIC_DATA (ptr));
}

#ifndef NEW_GC
static void
sweep_magic_eval_data (void)
{
#define UNMARK_magic_eval_data(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_magic_eval_data(ptr)

  SWEEP_FIXED_TYPE_BLOCK (magic_eval_data, Lisp_Magic_Eval_Data);
}
#endif /* not NEW_GC */

void
free_magic_eval_data (Lisp_Object ptr)
{
  FREE_FIXED_TYPE_WHEN_NOT_IN_GC (ptr, magic_eval_data, Lisp_Magic_Eval_Data,
				  XMAGIC_EVAL_DATA (ptr));
}

#ifndef NEW_GC
static void
sweep_eval_data (void)
{
#define UNMARK_eval_data(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_eval_data(ptr)

  SWEEP_FIXED_TYPE_BLOCK (eval_data, Lisp_Eval_Data);
}
#endif /* not NEW_GC */

void
free_eval_data (Lisp_Object ptr)
{
  FREE_FIXED_TYPE_WHEN_NOT_IN_GC (ptr, eval_data, Lisp_Eval_Data,
				  XEVAL_DATA (ptr));
}

#ifndef NEW_GC
static void
sweep_misc_user_data (void)
{
#define UNMARK_misc_user_data(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_misc_user_data(ptr)

  SWEEP_FIXED_TYPE_BLOCK (misc_user_data, Lisp_Misc_User_Data);
}
#endif /* not NEW_GC */

void
free_misc_user_data (Lisp_Object ptr)
{
  FREE_FIXED_TYPE_WHEN_NOT_IN_GC (ptr, misc_user_data, Lisp_Misc_User_Data,
				  XMISC_USER_DATA (ptr));
}

#endif /* EVENT_DATA_AS_OBJECTS */

#ifndef NEW_GC
static void
sweep_markers (void)
{
#define UNMARK_marker(ptr) UNMARK_RECORD_HEADER (&((ptr)->lheader))
#define ADDITIONAL_FREE_marker(ptr)					\
  do { Lisp_Object tem;							\
       tem = wrap_marker (ptr);						\
       unchain_marker (tem);						\
     } while (0)

  SWEEP_FIXED_TYPE_BLOCK (marker, Lisp_Marker);
}
#endif /* not NEW_GC */

/* Explicitly free a marker.  */
void
free_marker (Lisp_Object ptr)
{
  FREE_FIXED_TYPE_WHEN_NOT_IN_GC (ptr, marker, Lisp_Marker, XMARKER (ptr));
}


#if defined (MULE) && defined (VERIFY_STRING_CHARS_INTEGRITY)

static void
verify_string_chars_integrity (void)
{
  struct string_chars_block *sb;

  /* Scan each existing string block sequentially, string by string.  */
  for (sb = first_string_chars_block; sb; sb = sb->next)
    {
      int pos = 0;
      /* POS is the index of the next string in the block.  */
      while (pos < sb->pos)
        {
          struct string_chars *s_chars =
            (struct string_chars *) &(sb->string_chars[pos]);
          Lisp_String *string;
	  int size;
	  int fullsize;

	  /* If the string_chars struct is marked as free (i.e. the
	     STRING pointer is NULL) then this is an unused chunk of
	     string storage. (See below.) */

	  if (STRING_CHARS_FREE_P (s_chars))
	    {
	      fullsize = ((struct unused_string_chars *) s_chars)->fullsize;
	      pos += fullsize;
	      continue;
            }

          string = s_chars->string;
	  /* Must be 32-bit aligned. */
	  assert ((((int) string) & 3) == 0);

          size = string->size_;
          fullsize = STRING_FULLSIZE (size);

          assert (!BIG_STRING_FULLSIZE_P (fullsize));
	  assert (XSTRING_DATA (string) == s_chars->chars);
	  pos += fullsize;
        }
      assert (pos == sb->pos);
    }
}

#endif /* defined (MULE) && defined (VERIFY_STRING_CHARS_INTEGRITY) */

#ifndef NEW_GC
/* Compactify string chars, relocating the reference to each --
   free any empty string_chars_block we see. */
static void
compact_string_chars (void)
{
  struct string_chars_block *to_sb = first_string_chars_block;
  int to_pos = 0;
  struct string_chars_block *from_sb;

  /* Scan each existing string block sequentially, string by string.  */
  for (from_sb = first_string_chars_block; from_sb; from_sb = from_sb->next)
    {
      int from_pos = 0;
      /* FROM_POS is the index of the next string in the block.  */
      while (from_pos < from_sb->pos)
        {
          struct string_chars *from_s_chars =
            (struct string_chars *) &(from_sb->string_chars[from_pos]);
          struct string_chars *to_s_chars;
          Lisp_String *string;
	  int size;
	  int fullsize;

	  /* If the string_chars struct is marked as free (i.e. the
	     STRING pointer is NULL) then this is an unused chunk of
	     string storage.  This happens under Mule when a string's
	     size changes in such a way that its fullsize changes.
	     (Strings can change size because a different-length
	     character can be substituted for another character.)
	     In this case, after the bogus string pointer is the
	     "fullsize" of this entry, i.e. how many bytes to skip. */

	  if (STRING_CHARS_FREE_P (from_s_chars))
	    {
	      fullsize = ((struct unused_string_chars *) from_s_chars)->fullsize;
	      from_pos += fullsize;
	      continue;
            }

          string = from_s_chars->string;
	  gc_checking_assert (!(LRECORD_FREE_P (string)));

          size = string->size_;
          fullsize = STRING_FULLSIZE (size);

          gc_checking_assert (! BIG_STRING_FULLSIZE_P (fullsize));

          /* Just skip it if it isn't marked.  */
	  if (! MARKED_RECORD_HEADER_P (&(string->u.lheader)))
            {
              from_pos += fullsize;
              continue;
            }

          /* If it won't fit in what's left of TO_SB, close TO_SB out
             and go on to the next string_chars_block.  We know that TO_SB
             cannot advance past FROM_SB here since FROM_SB is large enough
             to currently contain this string. */
          if ((to_pos + fullsize) > countof (to_sb->string_chars))
            {
              to_sb->pos = to_pos;
              to_sb = to_sb->next;
              to_pos = 0;
            }

          /* Compute new address of this string
             and update TO_POS for the space being used.  */
          to_s_chars = (struct string_chars *) &(to_sb->string_chars[to_pos]);

          /* Copy the string_chars to the new place.  */
          if (from_s_chars != to_s_chars)
            memmove (to_s_chars, from_s_chars, fullsize);

          /* Relocate FROM_S_CHARS's reference */
          set_lispstringp_data (string, &(to_s_chars->chars[0]));

          from_pos += fullsize;
          to_pos += fullsize;
        }
    }

  /* Set current to the last string chars block still used and
     free any that follow. */
  {
    struct string_chars_block *victim;

    for (victim = to_sb->next; victim; )
      {
	struct string_chars_block *next = victim->next;
	xfree (victim);
	victim = next;
      }

    current_string_chars_block = to_sb;
    current_string_chars_block->pos = to_pos;
    current_string_chars_block->next = 0;
  }
}
#endif /* not NEW_GC */

#ifndef NEW_GC
#if 1 /* Hack to debug missing purecopy's */
static int debug_string_purity;

static void
debug_string_purity_print (Lisp_Object p)
{
  Charcount i;
  Charcount s = string_char_length (p);
  stderr_out ("\"");
  for (i = 0; i < s; i++)
  {
    Ichar ch = string_ichar (p, i);
    if (ch < 32 || ch >= 126)
      stderr_out ("\\%03o", ch);
    else if (ch == '\\' || ch == '\"')
      stderr_out ("\\%c", ch);
    else
      stderr_out ("%c", ch);
  }
  stderr_out ("\"\n");
}
#endif /* 1 */
#endif /* not NEW_GC */

#ifndef NEW_GC
static void
sweep_strings (void)
{
  int debug = debug_string_purity;

#define UNMARK_string(ptr) do {				\
    Lisp_String *p = (ptr);				\
    UNMARK_RECORD_HEADER (&(p->u.lheader));		\
    tick_string_stats (p, 1);				\
    if (debug)						\
      debug_string_purity_print (wrap_string (p));	\
  } while (0)
#define ADDITIONAL_FREE_string(ptr) do {	\
    Bytecount size = ptr->size_;		\
    if (BIG_STRING_SIZE_P (size))		\
      xfree (ptr->data_);			\
  } while (0)

  SWEEP_FIXED_TYPE_BLOCK_1 (string, Lisp_String, u.lheader);
}
#endif /* not NEW_GC */

#ifndef NEW_GC
void
gc_sweep_1 (void)
{
  /* Reset all statistics to 0.  They will be incremented when
     sweeping lcrecords, frob-block lrecords and dumped objects. */
  clear_lrecord_stats ();

  /* Free all unmarked records.  Do this at the very beginning,
     before anything else, so that the finalize methods can safely
     examine items in the objects.  sweep_lcrecords_1() makes
     sure to call all the finalize methods *before* freeing anything,
     to complete the safety. */
  {
    int ignored;
    sweep_lcrecords_1 (&all_lcrecords, &ignored);
  }

  compact_string_chars ();

  /* Finalize methods below (called through the ADDITIONAL_FREE_foo
     macros) must be *extremely* careful to make sure they're not
     referencing freed objects.  The only two existing finalize
     methods (for strings and markers) pass muster -- the string
     finalizer doesn't look at anything but its own specially-
     created block, and the marker finalizer only looks at live
     buffers (which will never be freed) and at the markers before
     and after it in the chain (which, by induction, will never be
     freed because if so, they would have already removed themselves
     from the chain). */

  /* Put all unmarked strings on free list, free'ing the string chars
     of large unmarked strings */
  sweep_strings ();

  /* Put all unmarked conses on free list */
  sweep_conses ();

  /* Free all unmarked compiled-function objects */
  sweep_compiled_functions ();

  /* Put all unmarked floats on free list */
  sweep_floats ();

#ifdef HAVE_BIGNUM
  /* Put all unmarked bignums on free list */
  sweep_bignums ();
#endif

#ifdef HAVE_RATIO
  /* Put all unmarked ratios on free list */
  sweep_ratios ();
#endif

#ifdef HAVE_BIGFLOAT
  /* Put all unmarked bigfloats on free list */
  sweep_bigfloats ();
#endif

  /* Put all unmarked symbols on free list */
  sweep_symbols ();

  /* Put all unmarked extents on free list */
  sweep_extents ();

  /* Put all unmarked markers on free list.
     Dechain each one first from the buffer into which it points. */
  sweep_markers ();

  sweep_events ();

#ifdef EVENT_DATA_AS_OBJECTS
  sweep_key_data ();
  sweep_button_data ();
  sweep_motion_data ();
  sweep_process_data ();
  sweep_timeout_data ();
  sweep_magic_data ();
  sweep_magic_eval_data ();
  sweep_eval_data ();
  sweep_misc_user_data ();
#endif /* EVENT_DATA_AS_OBJECTS */

#ifdef PDUMP
  pdump_objects_unmark ();
#endif
}
#endif /* not NEW_GC */


/************************************************************************/
/*           "Disksave Finalization" -- Preparing for Dumping           */
/************************************************************************/

static void
disksave_object_finalization_1 (void)
{
#ifdef NEW_GC
  mc_finalize_for_disksave ();
#else /* not NEW_GC */
  struct old_lcrecord_header *header;

  for (header = all_lcrecords; header; header = header->next)
    {
      struct lrecord_header *objh = &header->lheader;
      const struct lrecord_implementation *imp = LHEADER_IMPLEMENTATION (objh);
#if 0 /* possibly useful for debugging */
      if (!RECORD_DUMPABLE (objh) && !objh->free)
	{
	  stderr_out ("Disksaving a non-dumpable object: ");
	  debug_print (wrap_pointer_1 (header));
	}
#endif
      if (imp->disksave && !objh->free)
	(imp->disksave) (wrap_pointer_1 (header));
    }
#endif /* not NEW_GC */
}

void
disksave_object_finalization (void)
{
  /* It's important that certain information from the environment not get
     dumped with the executable (pathnames, environment variables, etc.).
     To make it easier to tell when this has happened with strings(1) we
     clear some known-to-be-garbage blocks of memory, so that leftover
     results of old evaluation don't look like potential problems.
     But first we set some notable variables to nil and do one more GC,
     to turn those strings into garbage.
  */

  /* Yeah, this list is pretty ad-hoc... */
  Vprocess_environment = Qnil;
  env_initted = 0;
  Vexec_directory = Qnil;
  Vdata_directory = Qnil;
  Vsite_directory = Qnil;
  Vdoc_directory = Qnil;
  Vexec_path = Qnil;
  Vload_path = Qnil;
  /* Vdump_load_path = Qnil; */
  /* Release hash tables for locate_file */
  Flocate_file_clear_hashing (Qt);
  uncache_home_directory ();
  zero_out_command_line_status_vars ();
  clear_default_devices ();

#if defined(LOADHIST) && !(defined(LOADHIST_DUMPED) || \
			   defined(LOADHIST_BUILTIN))
  Vload_history = Qnil;
#endif
  Vshell_file_name = Qnil;

#ifdef NEW_GC
  gc_full ();
#else /* not NEW_GC */
  garbage_collect_1 ();
#endif /* not NEW_GC */

  /* Run the disksave finalization methods of all live objects. */
  disksave_object_finalization_1 ();

#ifndef NEW_GC
  /* Zero out the uninitialized (really, unused) part of the containers
     for the live strings. */
  {
    struct string_chars_block *scb;
    for (scb = first_string_chars_block; scb; scb = scb->next)
      {
	int count = sizeof (scb->string_chars) - scb->pos;

	assert (count >= 0 && count < STRING_CHARS_BLOCK_SIZE);
	if (count != 0)
	  {
	    /* from the block's fill ptr to the end */
	    memset ((scb->string_chars + scb->pos), 0, count);
	  }
      }
  }
#endif /* not NEW_GC */

  /* There, that ought to be enough... */

}


/************************************************************************/
/*                Lisp interface onto garbage collection                */
/************************************************************************/

/* Debugging aids.  */

DEFUN ("garbage-collect", Fgarbage_collect, 0, 0, "", /*
Reclaim storage for Lisp objects no longer needed.
Return info on amount of space in use:
 ((USED-CONSES . FREE-CONSES) (USED-SYMS . FREE-SYMS)
  (USED-MARKERS . FREE-MARKERS) USED-STRING-CHARS USED-VECTOR-SLOTS
  PLIST)
  where `PLIST' is a list of alternating keyword/value pairs providing
  more detailed information.
Garbage collection happens automatically if you cons more than
`gc-cons-threshold' bytes of Lisp data since previous garbage collection.
*/
       ())
{
  /* Record total usage for purposes of determining next GC */
#ifdef NEW_GC
  gc_full ();
#else /* not NEW_GC */
  garbage_collect_1 ();
#endif /* not NEW_GC */

  /* This will get set to 1, and total_gc_usage computed, as part of the
     call to object_memory_usage_stats() -- if ALLOC_TYPE_STATS is enabled. */
  total_gc_usage_set = 0;
#ifdef ALLOC_TYPE_STATS
  return garbage_collection_statistics ();
#else
  return Qnil;
#endif
}

DEFUN ("consing-since-gc", Fconsing_since_gc, 0, 0, "", /*
Return the number of bytes consed since the last garbage collection.
\"Consed\" is a misnomer in that this actually counts allocation
of all different kinds of objects, not just conses.

If this value exceeds `gc-cons-threshold', a garbage collection happens.
*/
       ())
{
  return make_fixnum (consing_since_gc);
}

#if 0
DEFUN ("memory-limit", Fmemory_limit, 0, 0, 0, /*
Return the address of the last byte XEmacs has allocated, divided by 1024.
This may be helpful in debugging XEmacs's memory usage.
The value is divided by 1024 to make sure it will fit in a lisp integer.
*/
       ())
{
  return make_fixnum ((EMACS_INT) sbrk (0) / 1024);
}
#endif

DEFUN ("total-memory-usage", Ftotal_memory_usage, 0, 0, 0, /*
Return the total number of bytes used by the data segment in XEmacs.
This may be helpful in debugging XEmacs's memory usage.
NOTE: This may or may not be accurate!  It is hard to determine this
value in a system-independent fashion.  On Windows, for example, the
returned number tends to be much greater than reality.
*/
       ())
{
  return make_fixnum (total_data_usage ());
}

#ifdef USE_VALGRIND
DEFUN ("valgrind-leak-check", Fvalgrind_leak_check, 0, 0, "", /*
Ask valgrind to perform a memory leak check.
The results of the leak check are sent to stderr.
*/
       ())
{
  VALGRIND_DO_LEAK_CHECK;
  return Qnil;
}

DEFUN ("valgrind-quick-leak-check", Fvalgrind_quick_leak_check, 0, 0, "", /*
Ask valgrind to perform a quick memory leak check.
This just prints a summary of leaked memory, rather than all the details.
The results of the leak check are sent to stderr.
*/
       ())
{
  VALGRIND_DO_QUICK_LEAK_CHECK;
  return Qnil;
}
#endif /* USE_VALGRIND */


/************************************************************************/
/*                            Initialization                            */
/************************************************************************/

/* Initialization */
static void
common_init_alloc_early (void)
{
#ifndef Qzero
  Qzero = make_fixnum (0);	/* Only used if Lisp_Object is a union type */
#endif

#ifndef Qnull_pointer
  /* C guarantees that Qnull_pointer will be initialized to all 0 bits,
     so the following is actually a no-op.  */
  Qnull_pointer = wrap_pointer_1 (0);
#endif

#ifndef NEW_GC
  breathing_space = 0;
  all_lcrecords = 0;
#endif /* not NEW_GC */
  ignore_malloc_warnings = 1;
#ifdef DOUG_LEA_MALLOC
  mallopt (M_TRIM_THRESHOLD, 128*1024); /* trim threshold */
  mallopt (M_MMAP_THRESHOLD, 64*1024); /* mmap threshold */
#if 0 /* Moved to emacs.c */
  mallopt (M_MMAP_MAX, 64); /* max. number of mmap'ed areas */
#endif
#endif
#ifndef NEW_GC
  init_string_chars_alloc ();
  init_string_alloc ();
  /* #### Is it intentional that this is called twice? --ben */
  init_string_chars_alloc ();
  init_cons_alloc ();
  init_symbol_alloc ();
  init_compiled_function_alloc ();
  init_float_alloc ();
#ifdef HAVE_BIGNUM
  init_bignum_alloc ();
#endif
#ifdef HAVE_RATIO
  init_ratio_alloc ();
#endif
#ifdef HAVE_BIGFLOAT
  init_bigfloat_alloc ();
#endif
  init_marker_alloc ();
  init_extent_alloc ();
  init_event_alloc ();
#ifdef EVENT_DATA_AS_OBJECTS
  init_key_data_alloc ();
  init_button_data_alloc ();
  init_motion_data_alloc ();
  init_process_data_alloc ();
  init_timeout_data_alloc ();
  init_magic_data_alloc ();
  init_magic_eval_data_alloc ();
  init_eval_data_alloc ();
  init_misc_user_data_alloc ();
#endif /* EVENT_DATA_AS_OBJECTS */
#endif /* not NEW_GC */

  ignore_malloc_warnings = 0;

  if (staticpros_nodump)
    Dynarr_free (staticpros_nodump);
  staticpros_nodump = Dynarr_new2 (Lisp_Object_ptr_dynarr, Lisp_Object *);
  Dynarr_resize (staticpros_nodump, 100); /* merely a small optimization */
#ifdef DEBUG_XEMACS
  if (staticpro_nodump_names)
    Dynarr_free (staticpro_nodump_names);
  staticpro_nodump_names = Dynarr_new2 (const_Ascbyte_ptr_dynarr,
					const Ascbyte *);
  Dynarr_resize (staticpro_nodump_names, 100); /* ditto */
#endif

#ifdef NEW_GC
  mcpros = Dynarr_new2 (Lisp_Object_dynarr, Lisp_Object);
  Dynarr_resize (mcpros, 1410); /* merely a small optimization */
  dump_add_root_block_ptr (&mcpros, &mcpros_description);
#ifdef DEBUG_XEMACS
  mcpro_names = Dynarr_new2 (const_Ascbyte_ptr_dynarr, const Ascbyte *);
  Dynarr_resize (mcpro_names, 1410); /* merely a small optimization */
  dump_add_root_block_ptr (&mcpro_names,
			   &const_Ascbyte_ptr_dynarr_description);
#endif
#endif /* NEW_GC */

  consing_since_gc = 0;
  need_to_check_c_alloca = 0;
  funcall_allocation_flag = 0;
  funcall_alloca_count = 0;

#ifndef NEW_GC
  debug_string_purity = 0;
#endif /* not NEW_GC */

#ifdef ERROR_CHECK_TYPES
  ERROR_ME.really_unlikely_name_to_have_accidentally_in_a_non_errb_structure =
    666;
  ERROR_ME_NOT.
    really_unlikely_name_to_have_accidentally_in_a_non_errb_structure = 42;
  ERROR_ME_WARN.
    really_unlikely_name_to_have_accidentally_in_a_non_errb_structure =
      3333632;
  ERROR_ME_DEBUG_WARN.
    really_unlikely_name_to_have_accidentally_in_a_non_errb_structure =
      8675309;
#endif /* ERROR_CHECK_TYPES */
}

#ifndef NEW_GC
static void
init_lcrecord_lists (void)
{
  int i;

  for (i = 0; i < countof (lrecord_implementations_table); i++)
    {
      all_lcrecord_lists[i] = Qzero; /* Qnil not yet set */
      staticpro_nodump (&all_lcrecord_lists[i]);
    }
}
#endif /* not NEW_GC */

void
init_alloc_early (void)
{
#if defined (__cplusplus) && defined (ERROR_CHECK_GC)
  static struct gcpro initial_gcpro;

  initial_gcpro.next = 0;
  initial_gcpro.var = &Qnil;
  initial_gcpro.nvars = 1;
  gcprolist = &initial_gcpro;
#else
  gcprolist = 0;
#endif /* defined (__cplusplus) && defined (ERROR_CHECK_GC) */
}

static void
reinit_alloc_objects_early (void)
{
  OBJECT_HAS_METHOD (string, getprop);
  OBJECT_HAS_METHOD (string, putprop);
  OBJECT_HAS_METHOD (string, remprop);
  OBJECT_HAS_METHOD (string, plist);

  OBJECT_HAS_METHOD (cons, print_preprocess);
  OBJECT_HAS_METHOD (cons, nsubst_structures_descend);
  OBJECT_HAS_METHOD (vector, print_preprocess);
  OBJECT_HAS_METHOD (vector, nsubst_structures_descend);
}

void
reinit_alloc_early (void)
{
  common_init_alloc_early ();
#ifndef NEW_GC
  init_lcrecord_lists ();
#endif /* not NEW_GC */
  reinit_alloc_objects_early ();
}

void
init_alloc_once_early (void)
{
  common_init_alloc_early ();

  {
    int i;
    for (i = 0; i < countof (lrecord_implementations_table); i++)
      lrecord_implementations_table[i] = 0;
  }

  dump_add_opaque (lrecord_uid_counter, sizeof (lrecord_uid_counter));

  staticpros = Dynarr_new2 (Lisp_Object_ptr_dynarr, Lisp_Object *);
  Dynarr_resize (staticpros, 1410); /* merely a small optimization */
  dump_add_root_block_ptr (&staticpros, &staticpros_description);
#ifdef DEBUG_XEMACS
  staticpro_names = Dynarr_new2 (const_Ascbyte_ptr_dynarr, const Ascbyte *);
  Dynarr_resize (staticpro_names, 1410); /* merely a small optimization */
  dump_add_root_block_ptr (&staticpro_names,
			   &const_Ascbyte_ptr_dynarr_description);
#endif

#ifdef NEW_GC
  mcpros = Dynarr_new2 (Lisp_Object_dynarr, Lisp_Object);
  Dynarr_resize (mcpros, 1410); /* merely a small optimization */
  dump_add_root_block_ptr (&mcpros, &mcpros_description);
#ifdef DEBUG_XEMACS
  mcpro_names = Dynarr_new2 (const_Ascbyte_ptr_dynarr, const Ascbyte *);
  Dynarr_resize (mcpro_names, 1410); /* merely a small optimization */
  dump_add_root_block_ptr (&mcpro_names,
			   &const_Ascbyte_ptr_dynarr_description);
#endif
#else /* not NEW_GC */
  init_lcrecord_lists ();
#endif /* not NEW_GC */

  INIT_LISP_OBJECT (cons);
  INIT_LISP_OBJECT (vector);
  INIT_LISP_OBJECT (bit_vector);
  INIT_LISP_OBJECT (string);

#ifdef NEW_GC
  INIT_LISP_OBJECT (string_indirect_data);
  INIT_LISP_OBJECT (string_direct_data);
#endif /* NEW_GC */
#ifndef NEW_GC
  INIT_LISP_OBJECT (lcrecord_list);
  INIT_LISP_OBJECT (free);
#endif /* not NEW_GC */

  reinit_alloc_objects_early ();
}

void
syms_of_alloc (void)
{
  DEFSYMBOL (Qgarbage_collecting);

#ifdef MEMORY_USAGE_STATS
  DEFSYMBOL (Qobject_actually_requested);
  DEFSYMBOL (Qobject_malloc_overhead);
  DEFSYMBOL (Qother_memory_actually_requested);
  DEFSYMBOL (Qother_memory_malloc_overhead);
  DEFSYMBOL (Qother_memory_dynarr_overhead);
  DEFSYMBOL (Qother_memory_gap_overhead);
#endif /* MEMORY_USAGE_STATS */

  DEFSUBR (Fcons);
  DEFSUBR (Flist);
  DEFSUBR (Facons);
  DEFSUBR (Fvector);
  DEFSUBR (Fbit_vector);
  DEFSUBR (Fmake_byte_code);
  DEFSUBR (Fmake_list);
  DEFSUBR (Fmake_vector);
  DEFSUBR (Fmake_bit_vector);
  DEFSUBR (Fmake_string);
  DEFSUBR (Fstring);
  DEFSUBR (Fstring_modified_tick);
  DEFSUBR (Fmake_symbol);
  DEFSUBR (Fmake_marker);
#ifdef ALLOC_TYPE_STATS
  DEFSUBR (Fobject_memory_usage_stats);
  DEFSUBR (Ftotal_object_memory_usage);
#endif /* ALLOC_TYPE_STATS */
#ifdef MEMORY_USAGE_STATS
  DEFSUBR (Fobject_memory_usage);
#endif /* MEMORY_USAGE_STATS */
  DEFSUBR (Fgarbage_collect);
#if 0
  DEFSUBR (Fmemory_limit);
#endif
  DEFSUBR (Ftotal_memory_usage);
  DEFSUBR (Fconsing_since_gc);
#ifdef USE_VALGRIND
  DEFSUBR (Fvalgrind_leak_check);
  DEFSUBR (Fvalgrind_quick_leak_check);
#endif
}

void
reinit_vars_of_alloc (void)
{
#ifdef MEMORY_USAGE_STATS
  compute_memusage_stats_length ();
#endif /* MEMORY_USAGE_STATS */
}

void
vars_of_alloc (void)
{
  DEFVAR_CONST_INT ("array-rank-limit", &Varray_rank_limit /*
The exclusive upper bound on the number of dimensions an array may have.

XEmacs does not support multidimensional arrays, meaning this constant is,
for the moment, 2.
*/);
  Varray_rank_limit = 2;

  DEFVAR_CONST_INT ("array-dimension-limit", &Varray_dimension_limit /*
The exclusive upper bound of an array's dimension.
Note that XEmacs may not have enough memory available to create an array
with this dimension.
*/);
  Varray_dimension_limit = ARRAY_DIMENSION_LIMIT;

  DEFVAR_CONST_INT ("array-total-size-limit", &Varray_total_size_limit /*
The exclusive upper bound on the number of elements an array may contain.

In Common Lisp, this is distinct from `array-dimension-limit', because
arrays can have more than one dimension.  In XEmacs this is not the case,
and multi-dimensional arrays need to be implemented by the user with arrays
of arrays.

Note that XEmacs may not have enough memory available to create an array
with this dimension.
*/);
  Varray_total_size_limit = ARRAY_DIMENSION_LIMIT;

#ifdef DEBUG_XEMACS
  DEFVAR_INT ("debug-allocation", &debug_allocation /*
If non-zero, print out information to stderr about all objects allocated.
See also `debug-allocation-backtrace-length'.
*/ );
  debug_allocation = 0;

  DEFVAR_INT ("debug-allocation-backtrace-length",
	      &debug_allocation_backtrace_length /*
Length (in stack frames) of short backtrace printed out by `debug-allocation'.
*/ );
  debug_allocation_backtrace_length = 2;
#endif

  DEFVAR_BOOL ("purify-flag", &purify_flag /*
Non-nil means loading Lisp code in order to dump an executable.
This means that certain objects should be allocated in readonly space.
*/ );
}
