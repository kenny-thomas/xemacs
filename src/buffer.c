/* Buffer manipulation primitives for XEmacs.
   Copyright (C) 1985-1989, 1992-1995 Free Software Foundation, Inc.
   Copyright (C) 1995 Sun Microsystems, Inc.
   Copyright (C) 1995, 1996, 2000, 2001, 2002, 2004, 2010 Ben Wing.

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

/* Synched up with: Mule 2.0, FSF 19.30. */

/* Authorship:

   Based on code from pre-release FSF 19, c. 1991.
   Some changes by Jamie Zawinski, c. 1991-1994 (e.g. separate buffer
     list per frame, buffer slots).
   A few changes for buffer-local vars by Richard Mlynarik for
     19.8 or 19.9, c. 1993.
   Many changes by Ben Wing: changes and cleanups for Mule, esp. the
     macros in buffer.h and the initial version of the coding-system
     conversion macros (in buffer.h) and associated fns. (in this file),
     19.12 (c. 1995); synch. to FSF 19.30 c. 1994; memory usage stats
     c. 1996; generated-modeline-string c. 1996 for mousable modeline in
     19.14.
   Indirect buffer code by Hrvoje Niksic, c. 1997?
   Coding conversion code rewritten by Martin Buchholz, early 2000,
     based on design by Ben Wing.  */

/* This file contains functions that work with buffer objects.
   Functions that manipulate a buffer's text, however, are not
   in this file:

   1) The low-level functions that actually know about the
      implementation of a buffer's text are located in insdel.c.
   2) The higher-level (mostly Lisp) functions that manipulate a
      buffer's text are in editfns.c.
   3) The highest-level Lisp commands are in cmds.c.

   However:

   -- Functions that know about syntax tables (forward-word,
      scan-sexps, etc.) are in syntax.c, as are functions
      that manipulate syntax tables.
   -- Functions that know about case tables (upcase, downcase,
      etc.) are in casefiddle.c.  Functions that manipulate
      case tables (case-table-p, set-case-table, etc.) are
      in casetab.c.
   -- Functions that do searching and replacing are in
      search.c.  The low-level functions that implement
      regular expressions are in regex.c.

   Also:

   -- Some file and process functions (in fileio.c and process.c)
      copy text from or insert text into a buffer; they call
      low-level functions in insdel.c to do this.
   -- insdel.c calls low-level functions in undo.c and extents.c
      to record buffer modifications for undoing and to handle
      extent adjustment and extent-data creation and insertion.

*/

#include <config.h>
#include "lisp.h"

#include "buffer.h"
#include "chartab.h"
#include "casetab.h"
#include "commands.h"
#include "device-impl.h"
#include "elhash.h"
#include "extents.h"
#include "faces.h"
#include "file-coding.h"
#include "frame-impl.h"
#include "insdel.h"
#include "line-number.h"
#include "lstream.h"
#include "process.h"            /* for kill_buffer_processes */
#ifdef REGION_CACHE_NEEDS_WORK
#include "region-cache.h"
#endif
#include "select.h"     /* for select_notify_buffer_kill */
#include "specifier.h"
#include "syntax.h"
#include "window.h"

#include "sysfile.h"
#include "sysdir.h"

#ifdef WIN32_NATIVE
#include "syswindows.h"
#endif

struct buffer *current_buffer;	/* the current buffer */

/* This structure holds the default values of the buffer-local variables
   defined with DEFVAR_BUFFER_LOCAL, that have special slots in each buffer.
   The default value occupies the same slot in this structure
   as an individual buffer's value occupies in that buffer.
   Setting the default value also goes through the alist of buffers
   and stores into each buffer that does not say it has a local value.  */
Lisp_Object Vbuffer_defaults;
static void *buffer_defaults_saved_slots;

/* This structure marks which slots in a buffer have corresponding
   default values in Vbuffer_defaults.
   Each such slot has a nonzero value in this structure.
   The value has only one nonzero bit.

   When a buffer has its own local value for a slot,
   the bit for that slot (found in the same slot in this structure)
   is turned on in the buffer's local_var_flags slot.

   If a slot in this structure is 0, then there is a DEFVAR_BUFFER_LOCAL
   for the slot, but there is no default value for it; the corresponding
   slot in Vbuffer_defaults is not used except to initialize newly-created
   buffers.

   If a slot is -1, then there is a DEFVAR_BUFFER_LOCAL for it
   as well as a default value which is used to initialize newly-created
   buffers and as a reset-value when local-vars are killed.

   If a slot is -2, there is no DEFVAR_BUFFER_LOCAL for it.
   (The slot is always local, but there's no lisp variable for it.)
   The default value is only used to initialize newly-creation buffers.

   If a slot is -3, then there is no DEFVAR_BUFFER_LOCAL for it but
   there is a default which is used to initialize newly-creation
   buffers and as a reset-value when local-vars are killed.  */
struct buffer buffer_local_flags;

/* This is the initial (startup) directory, as used for the *scratch* buffer.
   This is no longer global.  Use get_initial_directory() to retrieve it.
 */
static Ibyte *initial_directory;

/* This structure holds the names of symbols whose values may be
   buffer-local.  It is indexed and accessed in the same way as the above. */
static Lisp_Object Vbuffer_local_symbols;
static void *buffer_local_symbols_saved_slots;

/* Alist of all buffer names vs the buffers. */
/* This used to be a variable, but is no longer,
   to prevent lossage due to user rplac'ing this alist or its elements.
   Note that there is a per-frame copy of this as well; the frame slot
   and the global variable contain the same data, but possibly in different
   orders, so that the buffer ordering can be per-frame.
  */
Lisp_Object Vbuffer_alist;

/* Functions to call before and after each text change. */
Lisp_Object Qbefore_change_functions;
Lisp_Object Qafter_change_functions;
Lisp_Object Vbefore_change_functions;
Lisp_Object Vafter_change_functions;

/* #### Obsolete, for compatibility */
Lisp_Object Qbefore_change_function;
Lisp_Object Qafter_change_function;
Lisp_Object Vbefore_change_function;
Lisp_Object Vafter_change_function;

#if 0 /* FSFmacs */
Lisp_Object Vtransient_mark_mode;
#endif

/* t means ignore all read-only text properties.
   A list means ignore such a property if its value is a member of the list.
   Any non-nil value means ignore buffer-read-only.  */
Lisp_Object Vinhibit_read_only;

/* List of functions to call that can query about killing a buffer.
   If any of these functions returns nil, we don't kill it.  */
Lisp_Object Vkill_buffer_query_functions;

/* Non-nil means delete a buffer's auto-save file when the buffer is saved. */
int delete_auto_save_files;

Lisp_Object Qbuffer_live_p;
Lisp_Object Qbuffer_or_string_p;

/* List of functions to call before changing an unmodified buffer.  */
Lisp_Object Vfirst_change_hook;
Lisp_Object Qfirst_change_hook;

Lisp_Object Qfundamental_mode;
Lisp_Object Qmode_class;
Lisp_Object Qpermanent_local;

Lisp_Object Qprotected_field;

Lisp_Object QSFundamental;	/* A string "Fundamental" */
Lisp_Object QSscratch;          /* "*scratch*" */
Lisp_Object Qdefault_directory;

Lisp_Object Qkill_buffer_hook;

Lisp_Object Qrename_auto_save_file;

Lisp_Object Qget_file_buffer;
Lisp_Object Qchange_major_mode_hook, Vchange_major_mode_hook;

Lisp_Object Qfind_file_compare_truenames;

Lisp_Object Qswitch_to_buffer;

/* Two thresholds controlling how much undo information to keep.  */
Fixnum undo_threshold;
Fixnum undo_high_threshold;

int find_file_compare_truenames;
int find_file_use_truenames;


static void reset_buffer_local_variables (struct buffer *, int first_time);
static void nuke_all_buffer_slots (struct buffer *b, Lisp_Object zap);

static const struct memory_description buffer_text_description_1 [] = {
  { XD_LISP_OBJECT, offsetof (struct buffer_text, line_number_cache) },
  { XD_END }
};

#ifdef NEW_GC
DEFINE_DUMPABLE_INTERNAL_LISP_OBJECT ("buffer-text", buffer_text,
				      0, buffer_text_description_1,
				      Lisp_Buffer_Text);
#endif /* NEW_GC */

static const struct sized_memory_description buffer_text_description = {
  sizeof (struct buffer_text),
  buffer_text_description_1
};

static const struct memory_description buffer_description [] = {
#define MARKED_SLOT(x) { XD_LISP_OBJECT, offsetof (struct buffer, x) },
#include "bufslots.h"

  { XD_LISP_OBJECT, offsetof (struct buffer, extent_info) },

#ifdef NEW_GC
  { XD_BLOCK_PTR, offsetof (struct buffer, text),
    1, { &buffer_text_description } },
  { XD_LISP_OBJECT, offsetof (struct buffer, syntax_cache) },
#else /* not NEW_GC */
  { XD_BLOCK_PTR, offsetof (struct buffer, text),
    1, { &buffer_text_description } },
  { XD_BLOCK_PTR, offsetof (struct buffer, syntax_cache),
    1, { &syntax_cache_description } },
#endif /* not NEW_GC */

  { XD_LISP_OBJECT, offsetof (struct buffer, indirect_children) },
  { XD_LISP_OBJECT, offsetof (struct buffer, base_buffer) },
  { XD_END }
};

static Lisp_Object
mark_buffer (Lisp_Object obj)
{
  struct buffer *buf = XBUFFER (obj);

#define MARKED_SLOT(x) mark_object (buf->x);
#include "bufslots.h"

  mark_object (buf->extent_info);
  if (buf->text)
    mark_object (buf->text->line_number_cache);
  mark_buffer_syntax_cache (buf);

  /* [[ Don't mark normally through the children slot.  Actually, in this
     case, it doesn't matter. ]]

     Indirect buffers, like all buffers, are permanent objects and stay
     around by themselves, so it doesn't matter whether we mark their
     children.  This used to contain a call to mark_conses_in_list(), to
     mark only the conses.  I deleted that function, since it's not used
     any more and causes problems with KKCC.  If we really needed such a
     weak list, just use a weak list object, like extents do. --ben */
  if (! EQ (buf->indirect_children, Qnull_pointer))
    mark_object (buf->indirect_children);

  return buf->base_buffer ? wrap_buffer (buf->base_buffer) : Qnil;
}

static void
print_buffer (Lisp_Object obj, Lisp_Object printcharfun, int escapeflag)
{
  struct buffer *b = XBUFFER (obj);

  if (print_readably)
    {
      if (!BUFFER_LIVE_P (b))
	printing_unreadable_object_fmt ("#<killed buffer>");
      else
	printing_unreadable_object_fmt ("#<buffer %s>", XSTRING_DATA (b->name));
    }
  else if (!BUFFER_LIVE_P (b))
    write_ascstring (printcharfun, "#<killed buffer>");
  else if (escapeflag)
    write_fmt_string_lisp (printcharfun, "#<buffer %S>", 1, b->name);
  else
    print_internal (b->name, printcharfun, 0);
}

void
cleanup_buffer_undo_lists (void)
{
  /* Truncate undo information at GC time.  Used to be in mark_object() but
     moved here for KKCC purposes. */

  ALIST_LOOP_3 (name, buf, Vbuffer_alist)
    {
      XBUFFER (buf)->undo_list = truncate_undo_list (XBUFFER (buf)->undo_list,
						     undo_threshold,
						     undo_high_threshold);
    }
}

/* We do not need a finalize method to handle a buffer's children list
   because all buffers have `kill-buffer' applied to them before
   they disappear, and the children removal happens then. */
DEFINE_NODUMP_LISP_OBJECT ("buffer", buffer, mark_buffer,
			   print_buffer, 0, 0, 0,
			   buffer_description,
			   struct buffer);

DEFUN ("bufferp", Fbufferp, 1, 1, 0, /*
Return t if OBJECT is an editor buffer.
*/
       (object))
{
  return BUFFERP (object) ? Qt : Qnil;
}

DEFUN ("buffer-live-p", Fbuffer_live_p, 1, 1, 0, /*
Return t if OBJECT is an editor buffer that has not been deleted.
*/
       (object))
{
  return BUFFERP (object) && BUFFER_LIVE_P (XBUFFER (object)) ? Qt : Qnil;
}

static DECLARE_DOESNT_RETURN (nsberror (Lisp_Object));

static DOESNT_RETURN
nsberror (Lisp_Object spec)
{
  if (STRINGP (spec))
    invalid_argument ("No buffer named", spec);
  invalid_argument ("Invalid buffer argument", spec);
}

DEFUN ("buffer-list", Fbuffer_list, 0, 1, 0, /*
Return a list of all existing live buffers.
The order is specific to the selected frame; if the optional FRAME
argument is provided, the ordering for that frame is returned instead.
If the FRAME argument is t, then the global (non-frame) ordering is
returned instead.
*/
       (frame))
{
  Lisp_Object args[2];
  args[0] = Qcdr;
  args[1] = EQ (frame, Qt) ?
    Vbuffer_alist : decode_frame (frame)->buffer_alist;
  return FmapcarX (countof (args), args);
}

Lisp_Object
get_buffer (Lisp_Object name, int error_if_deleted_or_does_not_exist)
{
  if (BUFFERP (name))
    {
      if (!BUFFER_LIVE_P (XBUFFER (name)))
        {
          if (error_if_deleted_or_does_not_exist)
            nsberror (name);
          return Qnil;
        }
      return name;
    }
  else
    {
      Lisp_Object buf;
      struct gcpro gcpro1;

      CHECK_STRING (name);
      name = LISP_GETTEXT (name);
      GCPRO1 (name);
      buf = Fcdr (Fassoc (name, Vbuffer_alist));
      UNGCPRO;
      if (NILP (buf) && error_if_deleted_or_does_not_exist)
	nsberror (name);
      return buf;
    }
}

struct buffer *
decode_buffer (Lisp_Object buffer, int allow_string)
{
  if (NILP (buffer) || (!POINTER_TYPE_P( XTYPE(buffer))))
    return current_buffer;

  if (allow_string && STRINGP (buffer))
    return XBUFFER (get_buffer (buffer, 1));

  CHECK_LIVE_BUFFER (buffer);
  return XBUFFER (buffer);
}

DEFUN ("decode-buffer", Fdecode_buffer, 1, 1, 0, /*
Validate BUFFER or if BUFFER is nil, return the current buffer.
If BUFFER is a valid buffer or a string representing a valid buffer,
the corresponding buffer object will be returned.  Otherwise an error
will be signaled.
*/
       (buffer))
{
  struct buffer *b = decode_buffer (buffer, 1);
  return wrap_buffer (b);
}

#if 0 /* FSFmacs */
/* bleagh!!! */
/* Like Fassoc, but use Fstring_equal to compare
   (which ignores text properties),
   and don't ever QUIT.  */

static Lisp_Object
assoc_ignore_text_properties (REGISTER Lisp_Object key, Lisp_Object list)
{
  REGISTER Lisp_Object tail;
  for (tail = list; !NILP (tail); tail = Fcdr (tail))
    {
      REGISTER Lisp_Object elt, tem;
      elt = Fcar (tail);
      tem = Fstring_equal (Fcar (elt), key);
      if (!NILP (tem))
	return elt;
    }
  return Qnil;
}

#endif /* FSFmacs */

DEFUN ("get-buffer", Fget_buffer, 1, 1, 0, /*
Return the buffer named BUFFER-NAME (a string), or nil if there is none.
BUFFER-NAME may also be a buffer; if so, the value is that buffer.
*/
       (buffer_name))
{
#ifdef I18N3
  /* #### Doc string should indicate that the buffer name will get
     translated. */
#endif

  /* #### This might return a dead buffer.  This is gross.  This is
     called FSF compatibility. */
  if (BUFFERP (buffer_name))
    return buffer_name;
  return get_buffer (buffer_name, 0);
  /* FSFmacs 19.29 calls assoc_ignore_text_properties() here.
     Bleagh!! */
}


DEFUN ("get-file-buffer", Fget_file_buffer, 1, 1, 0, /*
Return the buffer visiting file FILENAME (a string).
The buffer's `buffer-file-name' must match exactly the expansion of FILENAME.
If there is no such live buffer, return nil.

Normally, the comparison is done by canonicalizing FILENAME (using
`expand-file-name') and comparing that to the value of `buffer-file-name'
for each existing buffer.  However,  If `find-file-compare-truenames' is
non-nil, FILENAME will be converted to its truename and the search will be
done on each buffer's value of `buffer-file-truename' instead of
`buffer-file-name'.  Otherwise, if `find-file-use-truenames' is non-nil,
FILENAME will be converted to its truename and used for searching, but
the search will still be done on `buffer-file-name'.
*/
       (filename))
{
  /* This function can GC.  GC checked and fixed 7-11-2000 ben. */
  struct gcpro gcpro1;

#ifdef I18N3
  /* DO NOT translate the filename. */
#endif
  GCPRO1 (filename);
  CHECK_STRING (filename);
  filename = Fexpand_file_name (filename, Qnil);
  {
    /* If the file name has special constructs in it,
       call the corresponding file handler.  */
    Lisp_Object handler = Ffind_file_name_handler (filename, Qget_file_buffer);
    if (!NILP (handler))
      {
	UNGCPRO;
	return call2 (handler, Qget_file_buffer, filename);
      }
  }
  UNGCPRO;

  if (find_file_compare_truenames || find_file_use_truenames)
    {
      struct gcpro ngcpro1, ngcpro2, ngcpro3;
      Lisp_Object fn = Qnil;
      Lisp_Object dn = Qnil;

      NGCPRO3 (fn, dn, filename);
      fn = Ffile_truename (filename, Qnil);
      if (NILP (fn))
	{
	  dn = Ffile_name_directory (filename);
	  fn = Ffile_truename (dn, Qnil);
	  if (! NILP (fn)) dn = fn;
	  /* Formerly the two calls below were combined, but that is
	     not GC-safe because the first call returns unprotected
	     data and the second call can GC. --ben */
	  fn = Ffile_name_nondirectory (filename);
	  fn = Fexpand_file_name (fn, dn);
	}
      filename = fn;
      NUNGCPRO;
    }

  {
    ALIST_LOOP_3 (name, buf, Vbuffer_alist)
      {
	if (!STRINGP (XBUFFER (buf)->filename)) continue;
	if (!NILP (Fstring_equal (filename,
				  (find_file_compare_truenames
				   ? XBUFFER (buf)->file_truename
				   : XBUFFER (buf)->filename))))
	  return buf;
      }
  }
  return Qnil;
}


static void
push_buffer_alist (Lisp_Object name, Lisp_Object buf)
{
  Lisp_Object cons = Fcons (name, buf);
  Lisp_Object frmcons, devcons, concons;

  Vbuffer_alist = nconc2 (Vbuffer_alist, Fcons (cons, Qnil));
  FRAME_LOOP_NO_BREAK (frmcons, devcons, concons)
    {
      struct frame *f;
      f = XFRAME (XCAR (frmcons));
      f->buffer_alist = nconc2 (f->buffer_alist, Fcons (cons, Qnil));
    }
}

static void
delete_from_buffer_alist (Lisp_Object buf)
{
  Lisp_Object cons = Frassq (buf, Vbuffer_alist);
  Lisp_Object frmcons, devcons, concons;
  if (NILP (cons))
    return; /* ABORT() ? */
  Vbuffer_alist = delq_no_quit (cons, Vbuffer_alist);

  FRAME_LOOP_NO_BREAK (frmcons, devcons, concons)
    {
      struct frame *f;
      f = XFRAME (XCAR (frmcons));
      f->buffer_alist = delq_no_quit (cons, f->buffer_alist);
    }
}

Lisp_Object
get_truename_buffer (REGISTER Lisp_Object filename)
{
  /* This function can GC.  GC correct 7-11-00 ben */
  /* FSFmacs has its own code here and doesn't call get-file-buffer.
     That's because their equivalent of find-file-compare-truenames
     (find-file-existing-other-name) isn't looked at in get-file-buffer.
     This way is more correct. */
  int count = specpdl_depth ();

  specbind (Qfind_file_compare_truenames, Qt);
  return unbind_to_1 (count, Fget_file_buffer (filename));
}

static struct buffer *
allocate_buffer (void)
{
  Lisp_Object obj = ALLOC_NORMAL_LISP_OBJECT (buffer);

  copy_lisp_object (obj, Vbuffer_defaults);

  return XBUFFER (obj);
}

static Lisp_Object
finish_init_buffer (struct buffer *b, Lisp_Object name)
{
  Lisp_Object buf = wrap_buffer (b);

  name = Fcopy_sequence (name);
  /* #### This really does not need to be called.  We already
     initialized the buffer-local variables in allocate_buffer().
     local_var_alist is set to Qnil at the same point, in
     nuke_all_buffer_slots(). */
  reset_buffer_local_variables (b, 1);
  b->directory = current_buffer ? current_buffer->directory : Qnil;

  b->last_window_start = 1;

  b->name = name;
  if (string_byte (name, 0) != ' ')
    b->undo_list = Qnil;
  else
    b->undo_list = Qt;

  /* initialize the extent list */
  init_buffer_extents (b);

  /* Put this in the alist of all live buffers.  */
  push_buffer_alist (name, buf);
  note_object_created (buf);

  init_buffer_markers (b);
  init_buffer_syntax_cache (b);

  b->generated_modeline_string = Fmake_string (make_fixnum (84),
                                               make_char (' '));
  b->modeline_extent_table = make_lisp_hash_table (20, HASH_TABLE_KEY_WEAK,
                                                   Qeq);


  return buf;
}

DEFUN ("get-buffer-create", Fget_buffer_create, 1, 1, 0, /*
Return the buffer named NAME, or create such a buffer and return it.
A new buffer is created if there is no live buffer named NAME.
If NAME starts with a space, the new buffer does not keep undo information.
If NAME is a buffer instead of a string, then it is the value returned.
The value is never nil.
*/
       (name))
{
  /* This function can GC */
  Lisp_Object buf;
  REGISTER struct buffer *b;

#ifdef I18N3
  /* #### Doc string should indicate that the buffer name will get
     translated. */
#endif

  name = LISP_GETTEXT (name);
  buf = Fget_buffer (name);
  if (!NILP (buf))
    return buf;

  if (XSTRING_LENGTH (name) == 0)
    invalid_argument ("Empty string for buffer name is not allowed",
		      Qunbound);

  b = allocate_buffer ();

  b->text = &b->own_text;
  b->base_buffer = 0;
  b->indirect_children = Qnil;
  init_buffer_text (b);

  return finish_init_buffer (b, name);
}

DEFUN ("make-indirect-buffer", Fmake_indirect_buffer, 2, 2,
       "bMake indirect buffer (to buffer): \nBName of indirect buffer: ", /*
Create and return an indirect buffer for buffer BASE-BUFFER, named NAME.
BASE-BUFFER should be an existing buffer (or buffer name).
NAME should be a string which is not the name of an existing buffer.

If BASE-BUFFER is itself an indirect buffer, the base buffer for that buffer
 is made the base buffer for the newly created buffer. (Thus, there will
 never be indirect buffers whose base buffers are themselves indirect.)
*/
       (base_buffer, name))
{
  /* This function can GC */

  /* #### The above interactive specification is totally bogus,
     because it offers an existing buffer as default answer to the
     second question.  However, the second argument may not BE an
     existing buffer!  */
  struct buffer *b;

  base_buffer = get_buffer (base_buffer, 1);

#ifdef I18N3
  /* #### Doc string should indicate that the buffer name will get
     translated. */
#endif
  CHECK_STRING (name);
  name = LISP_GETTEXT (name);
  if (!NILP (Fget_buffer (name)))
    invalid_argument ("Buffer name already in use", name);
  if (XSTRING_LENGTH (name) == 0)
    invalid_argument ("Empty string for buffer name is not allowed", Qunbound);

  b = allocate_buffer ();

  b->base_buffer = BUFFER_BASE_BUFFER (XBUFFER (base_buffer));

  /* Use the base buffer's text object.  */
  b->text = b->base_buffer->text;
  b->indirect_children = Qnil;
  b->base_buffer->indirect_children =
    Fcons (wrap_buffer (b), b->base_buffer->indirect_children);
  init_buffer_text (b);

  return finish_init_buffer (b, name);
}



static void
reset_buffer_local_variables (struct buffer *b, int first_time)
{
  struct buffer *def = XBUFFER (Vbuffer_defaults);

  b->local_var_flags = 0;
  /* For each slot that has a default value,
     copy that into the slot.  */
#define MARKED_SLOT(slot)						\
  { int mask = XFIXNUM (buffer_local_flags.slot);				\
    if ((mask > 0 || mask == -1 || mask == -3)				\
	&& (first_time							\
	    || NILP (Fget (XBUFFER (Vbuffer_local_symbols)->slot,	\
			   Qpermanent_local, Qnil))))			\
      b->slot = def->slot;						\
  }
#include "bufslots.h"
}


/* We split this away from generate-new-buffer, because rename-buffer
   and set-visited-file-name ought to be able to use this to really
   rename the buffer properly.  */

DEFUN ("generate-new-buffer-name", Fgenerate_new_buffer_name, 1, 2, 0, /*
Return a string that is the name of no existing buffer based on NAME.
If there is no live buffer named NAME, then return NAME.
Otherwise modify name by appending `<NUMBER>', incrementing NUMBER
until an unused name is found, and then return that name.
Optional second argument IGNORE specifies a name that is okay to use
\(if it is in the sequence to be tried)
even if a buffer with that name exists.
*/
       (name, ignore))
{
  REGISTER Lisp_Object gentemp, tem;
  int count;
  Ibyte number[10];

  CHECK_STRING (name);

  name = LISP_GETTEXT (name);
#ifdef I18N3
  /* #### Doc string should indicate that the buffer name will get
     translated. */
#endif

  tem = Fget_buffer (name);
  if (NILP (tem))
    return name;

  count = 1;
  while (1)
    {
      qxesprintf (number, "<%d>", ++count);
      gentemp = concat2 (name, build_istring (number));
      if (!NILP (ignore))
        {
          tem = Fstring_equal (gentemp, ignore);
          if (!NILP (tem))
            return gentemp;
        }
      tem = Fget_buffer (gentemp);
      if (NILP (tem))
	return gentemp;
    }
}


DEFUN ("buffer-name", Fbuffer_name, 0, 1, 0, /*
Return the name of BUFFER, as a string.
With no argument or nil as argument, return the name of the current buffer.
*/
       (buffer))
{
  /* For compatibility, we allow a dead buffer here.
     Earlier versions of Emacs didn't provide buffer-live-p. */
  if (NILP (buffer))
    return current_buffer->name;
  CHECK_BUFFER (buffer);
  return XBUFFER (buffer)->name;
}

DEFUN ("buffer-file-name", Fbuffer_file_name, 0, 1, 0, /*
Return name of file BUFFER is visiting, or nil if none.
No argument or nil as argument means use the current buffer.
*/
       (buffer))
{
  /* For compatibility, we allow a dead buffer here.  Yuck! */
  if (NILP (buffer))
    return current_buffer->filename;
  CHECK_BUFFER (buffer);
  return XBUFFER (buffer)->filename;
}

DEFUN ("buffer-base-buffer", Fbuffer_base_buffer, 0, 1, 0, /*
Return the base buffer of indirect buffer BUFFER.
If BUFFER is not indirect, return nil.
*/
       (buffer))
{
  struct buffer *buf = decode_buffer (buffer, 0);

  return buf->base_buffer ? wrap_buffer (buf->base_buffer) : Qnil;
}

DEFUN ("buffer-indirect-children", Fbuffer_indirect_children, 0, 1, 0, /*
Return a list of all indirect buffers whose base buffer is BUFFER.
If BUFFER is indirect, the return value will always be nil; see
`make-indirect-buffer'.
*/
       (buffer))
{
  struct buffer *buf = decode_buffer (buffer, 0);

  return Fcopy_sequence (buf->indirect_children);
}

DEFUN ("buffer-local-variables", Fbuffer_local_variables, 0, 1, 0, /*
Return an alist of variables that are buffer-local in BUFFER.
Most elements look like (SYMBOL . VALUE), describing one variable.
For a symbol that is locally unbound, just the symbol appears in the value.
Note that storing new VALUEs in these elements doesn't change the variables.
No argument or nil as argument means use current buffer as BUFFER.
*/
       (buffer))
{
  struct buffer *buf = decode_buffer (buffer, 0);
  Lisp_Object result = Qnil;

  {
    Lisp_Object tail;
    for (tail = buf->local_var_alist; CONSP (tail); tail = XCDR (tail))
      {
        Lisp_Object elt = XCAR (tail);
	/* Reference each variable in the alist in buf.
	   If inquiring about the current buffer, this gets the current values,
	   so store them into the alist so the alist is up to date.
	   If inquiring about some other buffer, this swaps out any values
	   for that buffer, making the alist up to date automatically.  */
        Lisp_Object val = find_symbol_value (XCAR (elt));
	/* Use the current buffer value only if buf is the current buffer.  */
	if (buf != current_buffer)
	  val = XCDR (elt);

	/* If symbol is unbound, put just the symbol in the list.  */
	if (UNBOUNDP (val))
	  result = Fcons (XCAR (elt), result);
	/* Otherwise, put (symbol . value) in the list.  */
	else
	  result = Fcons (Fcons (XCAR (elt), val), result);
      }
  }

  /* Add on all the variables stored in special slots.  */
  {
    struct buffer *syms = XBUFFER (Vbuffer_local_symbols);
#define MARKED_SLOT(slot)					\
    { int mask = XFIXNUM (buffer_local_flags.slot);		\
      if (mask == 0 || mask == -1				\
	  || ((mask > 0) && (buf->local_var_flags & mask)))	\
        result = Fcons (Fcons (syms->slot, buf->slot), result);	\
    }
#include "bufslots.h"
  }
  return result;
}


DEFUN ("buffer-modified-p", Fbuffer_modified_p, 0, 1, 0, /*
Return t if BUFFER was modified since its file was last read or saved.
No argument or nil as argument means use current buffer as BUFFER.
*/
       (buffer))
{
  struct buffer *buf = decode_buffer (buffer, 0);

  return BUF_SAVE_MODIFF (buf) < BUF_MODIFF (buf) ? Qt : Qnil;
}

DEFUN ("set-buffer-modified-p", Fset_buffer_modified_p, 1, 2, 0, /*
Mark BUFFER as modified or unmodified according to FLAG.
A non-nil FLAG means mark the buffer modified.  No argument or nil
as BUFFER means use current buffer.
*/
       (flag, buffer))
{
  /* This function can GC */
  struct buffer *buf = decode_buffer (buffer, 0);

#ifdef CLASH_DETECTION
  /* If buffer becoming modified, lock the file.
     If buffer becoming unmodified, unlock the file.  */

  Lisp_Object fn = buf->file_truename;
  if (!NILP (fn))
    {
      int already = BUF_SAVE_MODIFF (buf) < BUF_MODIFF (buf);
      if (already == NILP (flag))
	{
	  int count = specpdl_depth ();
	  /* lock_file() and unlock_file() currently use current_buffer */
	  /* #### - dmoore, what if lock_file or unlock_file kill
	     the current buffer? */
	  record_unwind_protect (Fset_buffer, Fcurrent_buffer ());
	  set_buffer_internal (buf);
	  if (!already && !NILP (flag))
	    lock_file (fn);
	  else if (already && NILP (flag))
	    unlock_file (fn);
	  unbind_to (count);
	}
    }
#endif /* CLASH_DETECTION */

  /* This is often called when the buffer contents are altered but we
     don't want to treat the changes that way (e.g. selective
     display).  We still need to make sure redisplay realizes that the
     contents have potentially altered and it needs to do some
     work. */
  buf = decode_buffer (buffer, 0);
  BUF_MODIFF (buf)++;
  BUF_SAVE_MODIFF (buf) = NILP (flag) ? BUF_MODIFF (buf) : 0;
  MARK_MODELINE_CHANGED;

  return flag;
}

DEFUN ("buffer-modified-tick", Fbuffer_modified_tick, 0, 1, 0, /*
Return BUFFER's tick counter, incremented for each change in text.
Each buffer has a tick counter which is incremented each time the text in
that buffer is changed.  It wraps around occasionally.
No argument or nil as argument means use current buffer as BUFFER.
*/
       (buffer))
{
  struct buffer *buf = decode_buffer (buffer, 0);

  return make_fixnum (BUF_MODIFF (buf));
}

DEFUN ("rename-buffer", Frename_buffer, 1, 2,
       "sRename buffer (to new name): \nP", /*
Change current buffer's name to NEWNAME (a string).
If second arg UNIQUE is nil or omitted, it is an error if a
buffer named NEWNAME already exists.
If UNIQUE is non-nil, come up with a new name using
`generate-new-buffer-name'.
Interactively, one can set UNIQUE with a prefix argument.
Returns the name we actually gave the buffer.
This does not change the name of the visited file (if any).
*/
       (newname, unique))
{
  /* This function can GC */
  Lisp_Object tem, buf;

#ifdef I18N3
  /* #### Doc string should indicate that the buffer name will get
     translated. */
#endif
  CHECK_STRING (newname);
  newname = LISP_GETTEXT (newname);

  if (XSTRING_LENGTH (newname) == 0)
    invalid_argument ("Empty string is invalid as a buffer name", Qunbound);

  tem = Fget_buffer (newname);
  /* Don't short-circuit if UNIQUE is t.  That is a useful way to rename
     the buffer automatically so you can create another with the original name.
     It makes UNIQUE equivalent to
     (rename-buffer (generate-new-buffer-name NEWNAME)).  */
  /* XEmacs change: added check for nil */
  if (NILP (unique) && !NILP (tem) && XBUFFER (tem) == current_buffer)
    return current_buffer->name;
  if (!NILP (tem))
    {
      if (!NILP (unique))
	newname = Fgenerate_new_buffer_name (newname, current_buffer->name);
      else
	invalid_argument ("Buffer name is in use", newname);
    }

  current_buffer->name = newname;

  /* Catch redisplay's attention.  Unless we do this, the modelines for
     any windows displaying current_buffer will stay unchanged.  */
  MARK_MODELINE_CHANGED;

  buf = Fcurrent_buffer ();

  /* The aconses in the Vbuffer_alist are shared with frame->buffer_alist,
     so this will change it in the per-frame ordering as well. */
  Fsetcar (Frassq (buf, Vbuffer_alist), newname);

  if (NILP (current_buffer->filename)
      && !NILP (current_buffer->auto_save_file_name))
    call0 (Qrename_auto_save_file);
  /* refetch since that last call may have done GC */
  /* (hypothetical relocating GC) */
  return current_buffer->name;
}

DEFUN ("other-buffer", Fother_buffer, 0, 3, 0, /*
Return most recently selected buffer other than BUFFER.
Buffers not visible in windows are preferred to visible buffers,
unless optional third argument VISIBLE-OK is non-nil.
If no other buffer exists, the buffer `*scratch*' is returned.
If BUFFER is omitted or nil, some interesting buffer is returned.

The ordering is for this frame; If second optional argument FRAME
is provided, then the ordering is for that frame.  If the second arg
is t, then the global ordering is returned.

Note: In FSF Emacs, this function takes two arguments: BUFFER and
VISIBLE-OK.
*/
       (buffer, frame, visible_ok))
{
  /* This function can GC */
  Lisp_Object tail, buf, notsogood, tem;
  Lisp_Object alist;

  notsogood = Qnil;

  if (EQ (frame, Qt))
    alist = Vbuffer_alist;
  else
    {
      struct frame *f = decode_frame (frame);

      frame = wrap_frame (f);
      alist = f->buffer_alist;
    }

  for (tail = alist; !NILP (tail); tail = Fcdr (tail))
    {
      buf = Fcdr (Fcar (tail));
      if (EQ (buf, buffer))
	continue;
      if (string_byte (XBUFFER (buf)->name, 0) == ' ')
	continue;
      /* If FRAME has a buffer_predicate,
	 disregard buffers that don't fit the predicate.  */
      if (FRAMEP (frame))
	{
	  tem = XFRAME (frame)->buffer_predicate;
	  if (!NILP (tem))
	    {
	      tem = call1 (tem, buf);
	      if (NILP (tem))
		continue;
	    }
	}

      if (NILP (visible_ok))
	{
	  /* get-buffer-window will handle nil or t frame */
	  tem = Fget_buffer_window (buf, frame, Qnil);
	}
      else
	tem = Qnil;
      if (NILP (tem))
	return buf;
      if (NILP (notsogood))
	notsogood = buf;
    }
  if (!NILP (notsogood))
    return notsogood;
  return Fget_buffer_create (QSscratch);
}

DEFUN ("buffer-disable-undo", Fbuffer_disable_undo, 0, 1, "", /*
Stop keeping undo information for BUFFER.
Any undo records it already has are discarded.
No argument or nil as argument means do this for the current buffer.
*/
       (buffer))
{
  /* Allowing nil is an RMSism */
  struct buffer *real_buf = decode_buffer (buffer, 1);
  real_buf->undo_list = Qt;
  return Qnil;
}

DEFUN ("buffer-enable-undo", Fbuffer_enable_undo, 0, 1, "", /*
Start keeping undo information for BUFFER.
No argument or nil as argument means do this for the current buffer.
*/
       (buffer))
{
  /* Allowing nil is an RMSism */
  struct buffer *real_buf = decode_buffer (buffer, 1);
  if (EQ (real_buf->undo_list, Qt))
    real_buf->undo_list = Qnil;

  return Qnil;
}

DEFUN ("kill-buffer", Fkill_buffer, 1, 1, "bKill buffer: ", /*
Kill the buffer BUFFER.
The argument may be a buffer or may be the name of a buffer.
An argument of nil means kill the current buffer.

Value is t if the buffer is actually killed, nil if user says no.

The value of `kill-buffer-hook' (which may be local to that buffer),
if not void, is a list of functions to be called, with no arguments,
before the buffer is actually killed.  The buffer to be killed is current
when the hook functions are called.

Any processes that have this buffer as the `process-buffer' are killed
with `delete-process'.
*/
       (buffer))
{
  /* This function can call lisp */
  Lisp_Object buf;
  REGISTER struct buffer *b;
  struct gcpro gcpro1;

  if (NILP (buffer))
    buf = Fcurrent_buffer ();
  else if (BUFFERP (buffer))
    buf = buffer;
  else
    {
      buf = get_buffer (buffer, 0);
      if (NILP (buf)) nsberror (buffer);
    }

  b = XBUFFER (buf);

  /* OK to delete an already-deleted buffer.  */
  if (!BUFFER_LIVE_P (b))
    return Qnil;

  check_allowed_operation (OPERATION_DELETE_OBJECT, buf, Qnil);

  /* Don't kill the minibuffer now current.  */
  if (EQ (buf, Vminibuffer_zero))
    return Qnil;

  /* Or the echo area.  */
  if (EQ (buf, Vecho_area_buffer))
    return Qnil;

  /* Query if the buffer is still modified.  */
  if (INTERACTIVE && !NILP (b->filename)
      && BUF_MODIFF (b) > BUF_SAVE_MODIFF (b))
    {
      Lisp_Object killp;
      GCPRO1 (buf);
      killp =
	call1 (Qyes_or_no_p,
	       (emacs_sprintf_string ("Buffer %s modified; kill anyway? ",
				      XSTRING_DATA (b->name))));
      UNGCPRO;
      if (NILP (killp))
	return Qnil;
      b = XBUFFER (buf);        /* Hypothetical relocating GC. */
    }

  /* Run hooks with the buffer to be killed temporarily selected,
     unless the buffer is already dead (could have been deleted
     in the question above).
   */
  if (BUFFER_LIVE_P (b))
    {
      int speccount = specpdl_depth ();

      GCPRO1 (buf);
      record_unwind_protect (save_excursion_restore, save_excursion_save ());
      Fset_buffer (buf);

      {
	/* First run the query functions; if any query is answered no,
	   don't kill the buffer.  */
	EXTERNAL_LIST_LOOP_2 (arg, Vkill_buffer_query_functions)
	  {
	    if (NILP (call0 (arg)))
	      {
		UNGCPRO;
		return unbind_to (speccount);
	      }
	  }
      }

      /* Then run the hooks.  */
      run_hook (Qkill_buffer_hook);

      /* Inform the selection code that a buffer just got killed.
	 We do this in C because (a) it's faster, and (b) it needs
         to access data internal to select.c that can't be seen from
         Lisp (so the Lisp code would just call into C anyway. */
      select_notify_buffer_kill (buf);

      unbind_to (speccount);
      UNGCPRO;
      b = XBUFFER (buf);        /* Hypothetical relocating GC. */
  }

  /* We have no more questions to ask.  Verify that it is valid
     to kill the buffer.  This must be done after the questions
     since anything can happen within yes-or-no-p.  */

  /* Might have been deleted during the last question above */
  if (!BUFFER_LIVE_P (b))
    return Qnil;

  /* Don't kill the minibuffer now current.  */
  if (EQ (buf, XWINDOW_BUFFER (minibuf_window)))
    return Qnil;

  /* When we kill a base buffer, kill all its indirect buffers.
     We do it at this stage so nothing terrible happens if they
     ask questions or their hooks get errors.  */
  if (! b->base_buffer)
    {
      Lisp_Object rest;

      GCPRO1 (buf);

      LIST_LOOP (rest, b->indirect_children)
	{
	  Fkill_buffer (XCAR (rest));
	  /* Keep indirect_children updated in case a
             query-function/hook throws.  */
	  b->indirect_children = XCDR (rest);
	}

      UNGCPRO;
    }

  /* Make this buffer not be current.
     In the process, notice if this is the sole visible buffer
     and give up if so.  */
  if (b == current_buffer)
    {
      Fset_buffer (Fother_buffer (buf, Qnil, Qnil));
      if (b == current_buffer)
	return Qnil;
    }

  /* Now there is no question: we can kill the buffer.  */

#ifdef CLASH_DETECTION
  /* Unlock this buffer's file, if it is locked.  unlock_buffer
     can both GC and kill the current buffer, and wreak general
     havok by running lisp code. */
  GCPRO1 (buf);
  unlock_buffer (b);
  UNGCPRO;
  b = XBUFFER (buf);

  if (!BUFFER_LIVE_P (b))
    return Qnil;

  if (b == current_buffer)
    {
      Fset_buffer (Fother_buffer (buf, Qnil, Qnil));
      if (b == current_buffer)
	return Qnil;
    }
#endif /* CLASH_DETECTION */

  {
    int speccount = specpdl_depth ();
    specbind (Qinhibit_quit, Qt);

    kill_buffer_processes (buf);

    delete_from_buffer_alist (buf);

    /* #### This is a problem if this buffer is in a dedicated window.
       Need to undedicate any windows of this buffer first (and delete them?)
       */
    GCPRO1 (buf);
    Freplace_buffer_in_windows (buf, Qnil, Qall);
    UNGCPRO;

#ifdef USE_C_FONT_LOCK
    font_lock_buffer_was_killed (b);
#endif

    /* Delete any auto-save file, if we saved it in this session.  */
    if (STRINGP (b->auto_save_file_name)
	&& b->auto_save_modified != 0
	&& BUF_SAVE_MODIFF (b) < b->auto_save_modified)
      {
	if (delete_auto_save_files != 0)
	  {
	    /* deleting the auto save file might kill b! */
	    /* #### dmoore - fix this crap, we do this same gcpro and
	       buffer liveness check multiple times.  Let's get a
	       macro or something for it. */
	    GCPRO1 (buf);
	    internal_delete_file (b->auto_save_file_name);
	    UNGCPRO;
	    b = XBUFFER (buf);

	    if (!BUFFER_LIVE_P (b))
	      return Qnil;

	    if (b == current_buffer)
	      {
		Fset_buffer (Fother_buffer (buf, Qnil, Qnil));
		if (b == current_buffer)
		  return Qnil;
	      }
	  }
      }

    uninit_buffer_markers (b);
    uninit_buffer_syntax_cache (b);

    kill_buffer_local_variables (b);

    b->name = Qnil;
    uninit_buffer_text (b);
    b->undo_list = Qnil;
    uninit_buffer_extents (b);
    if (b->base_buffer)
      {
#ifdef ERROR_CHECK_STRUCTURES
	assert (!NILP (memq_no_quit (buf, b->base_buffer->indirect_children)));
#endif
	b->base_buffer->indirect_children =
	  delq_no_quit (buf, b->base_buffer->indirect_children);
      }

  /* Clear away all Lisp objects, so that they
     won't be protected from GC. */
    nuke_all_buffer_slots (b, Qnil);

    note_object_deleted (buf);

    unbind_to (speccount);
  }
  return Qt;
}

DEFUN ("record-buffer", Frecord_buffer, 1, 1, 0, /*
Place buffer BUFFER first in the buffer order.
Call this function when a buffer is selected "visibly".

This function changes the global buffer order and the per-frame buffer
order for the selected frame.  The buffer order keeps track of recency
of selection so that `other-buffer' will return a recently selected
buffer.  See `other-buffer' for more information.
*/
       (buffer))
{
  REGISTER Lisp_Object lynk, prev;
  struct frame *f = selected_frame ();
  int buffer_found = 0;

  CHECK_BUFFER (buffer);
  if (!BUFFER_LIVE_P (XBUFFER (buffer)))
    return Qnil;
  prev = Qnil;
  for (lynk = Vbuffer_alist; CONSP (lynk); lynk = XCDR (lynk))
    {
      if (EQ (XCDR (XCAR (lynk)), buffer))
	{
	  buffer_found = 1;
	  break;
	}
      prev = lynk;
    }
  if (buffer_found)
    {
      /* Effectively do Vbuffer_alist = delq_no_quit (lynk, Vbuffer_alist) */
      if (NILP (prev))
	Vbuffer_alist = XCDR (Vbuffer_alist);
      else
	XCDR (prev) = XCDR (XCDR (prev));
      XCDR (lynk) = Vbuffer_alist;
      Vbuffer_alist = lynk;
    }
  else
    Vbuffer_alist = Fcons (Fcons (Fbuffer_name(buffer), buffer), Vbuffer_alist);

  /* That was the global one.  Now do the same thing for the
     per-frame buffer-alist. */
  buffer_found = 0;
  prev = Qnil;
  for (lynk = f->buffer_alist; CONSP (lynk); lynk = XCDR (lynk))
    {
      if (EQ (XCDR (XCAR (lynk)), buffer))
	{
	  buffer_found = 1;
	  break;
	}
      prev = lynk;
    }
  if (buffer_found)
    {
      /* Effectively do f->buffer_alist = delq_no_quit (lynk, f->buffer_alist) */
      if (NILP (prev))
	f->buffer_alist = XCDR (f->buffer_alist);
      else
	XCDR (prev) = XCDR (XCDR (prev));
      XCDR (lynk) = f->buffer_alist;
      f->buffer_alist = lynk;
    }
  else
    f->buffer_alist = Fcons (Fcons (Fbuffer_name(buffer), buffer),
			     f->buffer_alist);

  return Qnil;
}

DEFUN ("set-buffer-major-mode", Fset_buffer_major_mode, 1, 1, 0, /*
Set an appropriate major mode for BUFFER, according to `default-major-mode'.
Use this function before selecting the buffer, since it may need to inspect
the current buffer's major mode.
*/
       (buffer))
{
  int speccount = specpdl_depth ();
  Lisp_Object function = XBUFFER (Vbuffer_defaults)->major_mode;

  if (NILP (function))
    {
      Lisp_Object tem = Fget (current_buffer->major_mode, Qmode_class, Qnil);
      if (NILP (tem))
	function = current_buffer->major_mode;
    }

  if (NILP (function) || EQ (function, Qfundamental_mode))
    return Qnil;

  /* To select a nonfundamental mode,
     select the buffer temporarily and then call the mode function. */

  record_unwind_protect (Fset_buffer, Fcurrent_buffer ());

  Fset_buffer (buffer);
  call0 (function);

  return unbind_to (speccount);
}

void
switch_to_buffer (Lisp_Object bufname, Lisp_Object norecord)
{
  call2 (Qswitch_to_buffer, bufname, norecord);
}


DEFUN ("current-buffer", Fcurrent_buffer, 0, 0, 0, /*
Return the current buffer as a Lisp object.
*/
       ())
{
  return wrap_buffer (current_buffer);
}

/* Set the current buffer to B.  */

void
set_buffer_internal (struct buffer *b)
{
  REGISTER struct buffer *old_buf;
  REGISTER Lisp_Object tail;

  if (current_buffer == b)
    return;

  INVALIDATE_PIXEL_TO_GLYPH_CACHE;

  old_buf = current_buffer;
  current_buffer = b;
  invalidate_current_column ();   /* invalidate indentation cache */

  if (old_buf)
    {
      /* synchronize window point */
      Lisp_Object current_window = Fselected_window (Qnil);
      if (!NILP (current_window)
	  && EQ(Fwindow_buffer (current_window), wrap_buffer (old_buf)))
	Fset_window_point (current_window, make_fixnum (BUF_PT (old_buf)));

      /* Put the undo list back in the base buffer, so that it appears
	 that an indirect buffer shares the undo list of its base.  */
      if (old_buf->base_buffer)
	old_buf->base_buffer->undo_list = old_buf->undo_list;
    }

  /* Get the undo list from the base buffer, so that it appears
     that an indirect buffer shares the undo list of its base.  */
  if (b->base_buffer)
    b->undo_list = b->base_buffer->undo_list;

  /* Look down buffer's list of local Lisp variables
     to find and update any that forward into C variables. */

  LIST_LOOP (tail, b->local_var_alist)
    {
      Lisp_Object sym = XCAR (XCAR (tail));
      Lisp_Object valcontents = XSYMBOL (sym)->value;
      if (SYMBOL_VALUE_MAGIC_P (valcontents))
	{
	  /* Just reference the variable
	     to cause it to become set for this buffer.  */
	  /* Use find_symbol_value_quickly to avoid an unnecessary O(n)
	     lookup. */
	  (void) find_symbol_value_quickly (XCAR (tail), 1);
	}
    }

  /* Do the same with any others that were local to the previous buffer */

  if (old_buf)
    {
      LIST_LOOP (tail, old_buf->local_var_alist)
	{
	  Lisp_Object sym = XCAR (XCAR (tail));
	  Lisp_Object valcontents = XSYMBOL (sym)->value;

	  if (SYMBOL_VALUE_MAGIC_P (valcontents))
	    {
	      /* Just reference the variable
		 to cause it to become set for this buffer.  */
	      /* Use find_symbol_value_quickly with find_it_p as 0 to avoid an
		 unnecessary O(n) lookup which is guaranteed to be worst case.
		 Any symbols which are local are guaranteed to have been
		 handled in the previous loop, above. */
	      (void) find_symbol_value_quickly (sym, 0);
	    }
	}
    }
}

DEFUN ("set-buffer", Fset_buffer, 1, 1, 0, /*
Make the buffer BUFFER current for editing operations.
BUFFER may be a buffer or the name of an existing buffer.
See also `save-excursion' when you want to make a buffer current temporarily.
This function does not display the buffer, so its effect ends
when the current command terminates.
Use `switch-to-buffer' or `pop-to-buffer' to switch buffers permanently.
*/
       (buffer))
{
  buffer = get_buffer (buffer, 0);
  if (NILP (buffer))
    invalid_operation ("Selecting deleted or non-existent buffer", Qunbound);
  set_buffer_internal (XBUFFER (buffer));
  return buffer;
}


DEFUN ("barf-if-buffer-read-only", Fbarf_if_buffer_read_only, 0, 3, 0, /*
Signal a `buffer-read-only' error if BUFFER is read-only.
Optional argument BUFFER defaults to the current buffer.

If optional argument START is non-nil, all extents in the buffer
which overlap that part of the buffer are checked to ensure none has a
`read-only' property. (Extents that lie completely within the range,
however, are not checked.) END defaults to the value of START.

If START and END are equal, the range checked is [START, END] (i.e.
closed on both ends); otherwise, the range checked is (START, END)
\(open on both ends), except that extents that lie completely within
[START, END] are not checked.  See `extent-in-region-p' for a fuller
discussion.
*/
       (buffer, start, end))
{
  struct buffer *b = decode_buffer (buffer, 0);
  Charbpos s, e;

  if (NILP (start))
    s = e = -1;
  else
    {
      if (NILP (end))
	end = start;
      get_buffer_range_char (b, start, end, &s, &e, 0);
    }
  barf_if_buffer_read_only (b, s, e);

  return Qnil;
}

static void
bury_buffer_1 (Lisp_Object buffer, Lisp_Object before,
	       Lisp_Object *buffer_alist)
{
  Lisp_Object aelt = rassq_no_quit (buffer, *buffer_alist);
  Lisp_Object lynk = memq_no_quit (aelt, *buffer_alist);
  Lisp_Object iter, before_before;

  *buffer_alist = delq_no_quit (aelt, *buffer_alist);
  for (before_before = Qnil, iter = *buffer_alist;
       !NILP (iter) && !EQ (XCDR (XCAR (iter)), before);
       before_before = iter, iter = XCDR (iter))
    ;
  XCDR (lynk) = iter;
  if (!NILP (before_before))
    XCDR (before_before) = lynk;
  else
    *buffer_alist = lynk;
}

DEFUN ("bury-buffer", Fbury_buffer, 0, 2, "", /*
Put BUFFER at the end of the list of all buffers.
There it is the least likely candidate for `other-buffer' to return;
thus, the least likely buffer for \\[switch-to-buffer] to select by default.
If BUFFER is nil or omitted, bury the current buffer.
Also, if BUFFER is nil or omitted, remove the current buffer from the
selected window if it is displayed there.
Because of this, you may need to specify (current-buffer) as
BUFFER when calling from minibuffer.
If BEFORE is non-nil, it specifies a buffer before which BUFFER
will be placed, instead of being placed at the end.
*/
       (buffer, before))
{
  /* This function can GC */
  struct buffer *buf = decode_buffer (buffer, 1);
  /* If we're burying the current buffer, unshow it.  */
  /* Note that the behavior of (bury-buffer nil) and
     (bury-buffer (current-buffer)) is not the same.
     This is illogical but is historical.  Changing it
     breaks mh-e and TeX and such packages. */
  if (NILP (buffer))
    switch_to_buffer (Fother_buffer (Fcurrent_buffer (), Qnil, Qnil), Qnil);
  buffer = wrap_buffer (buf);

  if (!NILP (before))
    before = get_buffer (before, 1);

  if (EQ (before, buffer))
    invalid_operation ("Cannot place a buffer before itself", Qunbound);

  bury_buffer_1 (buffer, before, &Vbuffer_alist);
  bury_buffer_1 (buffer, before, &selected_frame ()->buffer_alist);

  return Qnil;
}


DEFUN ("erase-buffer", Ferase_buffer, 0, 1, "*", /*
Delete the entire contents of the BUFFER.
Any clipping restriction in effect (see `narrow-to-region') is removed,
so the buffer is truly empty after this.
BUFFER defaults to the current buffer if omitted.
*/
       (buffer))
{
  /* This function can GC */
  struct buffer *b = decode_buffer (buffer, 1);
  /* #### yuck yuck yuck.  This is gross.  The old echo-area code,
     however, was the only place that called erase_buffer() with a
     non-zero NO_CLIP argument.

     Someone needs to fix up the redisplay code so it is smarter
     about this, so that the NO_CLIP junk isn't necessary. */
  int no_clip = (b == XBUFFER (Vecho_area_buffer));

  INVALIDATE_PIXEL_TO_GLYPH_CACHE;

  widen_buffer (b, no_clip);
  buffer_delete_range (b, BUF_BEG (b), BUF_Z (b), 0);
  b->last_window_start = 1;

  /* Prevent warnings, or suspension of auto saving, that would happen
     if future size is less than past size.  Use of erase-buffer
     implies that the future text is not really related to the past text.  */
  b->saved_size = Qzero;

  return Qnil;
}



DEFUN ("kill-all-local-variables", Fkill_all_local_variables, 0, 0, 0, /*
Switch to Fundamental mode by killing current buffer's local variables.
Most local variable bindings are eliminated so that the default values
become effective once more.  Also, the syntax table is set from
the standard syntax table, the category table is set from the
standard category table (if support for Mule exists), local keymap is set
to nil, the abbrev table is set from `fundamental-mode-abbrev-table',
and all specifier specifications whose locale is the current buffer
are removed.  This function also forces redisplay of the modeline.

Every function to select a new major mode starts by
calling this function.

As a special exception, local variables whose names have
a non-nil `permanent-local' property are not eliminated by this function.

The first thing this function does is run
the normal hook `change-major-mode-hook'.
*/
       ())
{
  /* This function can GC */
  run_hook (Qchange_major_mode_hook);

  reset_buffer_local_variables (current_buffer, 0);

  kill_buffer_local_variables (current_buffer);

  kill_specifier_buffer_locals (Fcurrent_buffer ());

  /* Force modeline redisplay.  Useful here because all major mode
     commands call this function.  */
  MARK_MODELINE_CHANGED;

  return Qnil;
}

/* It was a shame to have the line number cache around and not used from
   Lisp, so move this here from simple.el. */

DEFUN ("line-number", Fline_number, 0, 3, 0, /*
Return the line number of POSITION within BUFFER.

POSITION defaults to point. If RESPECT-NARROWING is non-nil, then the narrowed
line number is returned; otherwise, the absolute line number is returned.  The
returned line can always be given to `goto-line' to get back to the current
line.
*/
       (position, respect_narrowing, buffer_))
{
  struct buffer *buf = decode_buffer (buffer_, 0);
  Charbpos pos = (NILP (position) ? BUF_PT (buf) :
		  get_buffer_pos_char (buf, position, GB_COERCE_RANGE));

  return make_fixnum (buffer_line_number (buf, pos, 1,
                                          !NILP (respect_narrowing)) + 1);
}

#ifdef MEMORY_USAGE_STATS

struct buffer_stats
{
  struct usage_stats u;
  Bytecount text;
  /* Ancillary Lisp */
  Bytecount markers;
  Bytecount extents;
};

static Bytecount
compute_buffer_text_usage (struct buffer *b, struct usage_stats *ustats)
{
  Bytecount was_requested, gap, malloc_use;

  /* Killed buffer? */
  if (!b->text)
    return 0;

  /* Indirect buffer shares its text with someone else, so don't double-
     count the text */
  if (b->base_buffer)
    return 0;

  was_requested = b->text->z - 1;
  gap = b->text->gap_size + b->text->end_gap_size;
  malloc_use = malloced_storage_size (b->text->beg, was_requested + gap, 0);

  ustats->gap_overhead    += gap;
  ustats->was_requested   += was_requested;
  ustats->malloc_overhead += malloc_use - (was_requested + gap);
  return malloc_use;
}

static void
compute_buffer_usage (struct buffer *b, struct buffer_stats *stats,
		      struct usage_stats *ustats)
{
  stats->text    += compute_buffer_text_usage   (b, ustats);
  stats->markers += compute_buffer_marker_usage (b);
  stats->extents += compute_buffer_extent_usage (b);
}

static void
buffer_memory_usage (Lisp_Object buffer, struct generic_usage_stats *gustats)
{
  struct buffer_stats *stats = (struct buffer_stats *) gustats;

  compute_buffer_usage (XBUFFER (buffer), stats, &stats->u);
}

#endif /* MEMORY_USAGE_STATS */

#if defined (DEBUG_XEMACS) && defined (MULE)

DEFUN ("buffer-char-byte-conversion-info", Fbuffer_char_byte_converion_info,
       1, 1, 0, /*
Return the current info used for char-byte conversion in BUFFER.
The values returned are in the form of a plist of properties and values.
*/
       (buffer))
{
  struct buffer *b;
  Lisp_Object plist = Qnil;

  CHECK_BUFFER (buffer); /* dead buffers should be allowed, no? */
  b = XBUFFER (buffer);

#define ADD_INT(field) \
  plist = cons3 (make_fixnum (b->text->field), \
		 intern_massaging_name (#field), plist)
#define ADD_BOOL(field) \
  plist = cons3 (b->text->field ? Qt : Qnil, \
		 intern_massaging_name (#field), plist)
  ADD_INT (bufz);
  ADD_INT (z);
#ifdef OLD_BYTE_CHAR
  ADD_INT (mule_bufmin);
  ADD_INT (mule_bufmax);
  ADD_INT (mule_bytmin);
  ADD_INT (mule_bytmax);
  ADD_INT (mule_shifter);
  ADD_BOOL (mule_three_p);
#endif
  ADD_BOOL (entirely_one_byte_p);
  ADD_INT (num_ascii_chars);
  ADD_INT (num_8_bit_fixed_chars);
  ADD_INT (num_16_bit_fixed_chars);
  ADD_INT (cached_charpos);
  ADD_INT (cached_bytepos);
  ADD_INT (next_cache_pos);

  {
    Lisp_Object pos[NUM_CACHED_POSITIONS];
    int i;
    for (i = 0; i < b->text->next_cache_pos; i++)
      pos[i] = make_fixnum (b->text->mule_charbpos_cache[i]);
    plist = cons3 (Flist (b->text->next_cache_pos, pos),
		   intern ("mule-charbpos-cache"), plist);
    for (i = 0; i < b->text->next_cache_pos; i++)
      pos[i] = make_fixnum (b->text->mule_bytebpos_cache[i]);
    plist = cons3 (Flist (b->text->next_cache_pos, pos),
		   intern ("mule-bytebpos-cache"), plist);
  }
#undef ADD_INT
#undef ADD_BOOL

  return Fnreverse (plist);
}

DEFUN ("string-char-byte-conversion-info", Fstring_char_byte_converion_info, 1, 1, 0, /*
Return the current info used for char-byte conversion in STRING.
The values returned are in the form of a plist of properties and values.
*/
       (string))
{
  Lisp_Object plist = Qnil;
  CHECK_STRING (string);

  plist = cons3 (make_fixnum (XSTRING_LENGTH (string)),
		 intern ("byte-length"), plist);
  plist = cons3 (make_fixnum (XSTRING_ASCII_BEGIN (string)),
		 intern ("ascii-begin"), plist);

  return Fnreverse (plist);
}

#endif /* defined (DEBUG_XEMACS) && defined (MULE) */



void
buffer_objects_create (void)
{
#ifdef MEMORY_USAGE_STATS
  OBJECT_HAS_METHOD (buffer, memory_usage);
#endif
}

void
syms_of_buffer (void)
{
  INIT_LISP_OBJECT (buffer);
#ifdef NEW_GC
  INIT_LISP_OBJECT (buffer_text);
#endif /* NEW_GC */

  DEFSYMBOL (Qbuffer_live_p);
  DEFSYMBOL (Qbuffer_or_string_p);
  DEFSYMBOL (Qmode_class);
  DEFSYMBOL (Qrename_auto_save_file);
  DEFSYMBOL (Qkill_buffer_hook);
  DEFSYMBOL (Qpermanent_local);

  DEFSYMBOL (Qfirst_change_hook);
  DEFSYMBOL (Qbefore_change_functions);
  DEFSYMBOL (Qafter_change_functions);

  /* #### Obsolete, for compatibility */
  DEFSYMBOL (Qbefore_change_function);
  DEFSYMBOL (Qafter_change_function);

  DEFSYMBOL (Qdefault_directory);

  DEFSYMBOL (Qget_file_buffer);
  DEFSYMBOL (Qchange_major_mode_hook);

  DEFSYMBOL (Qfundamental_mode);

  DEFSYMBOL (Qfind_file_compare_truenames);

  DEFSYMBOL (Qswitch_to_buffer);

  DEFSUBR (Fbufferp);
  DEFSUBR (Fbuffer_live_p);
  DEFSUBR (Fbuffer_list);
  DEFSUBR (Fdecode_buffer);
  DEFSUBR (Fget_buffer);
  DEFSUBR (Fget_file_buffer);
  DEFSUBR (Fget_buffer_create);
  DEFSUBR (Fmake_indirect_buffer);

  DEFSUBR (Fgenerate_new_buffer_name);
  DEFSUBR (Fbuffer_name);
  DEFSUBR (Fbuffer_file_name);
  DEFSUBR (Fbuffer_base_buffer);
  DEFSUBR (Fbuffer_indirect_children);
  DEFSUBR (Fbuffer_local_variables);
  DEFSUBR (Fbuffer_modified_p);
  DEFSUBR (Fset_buffer_modified_p);
  DEFSUBR (Fbuffer_modified_tick);
  DEFSUBR (Frename_buffer);
  DEFSUBR (Fother_buffer);
  DEFSUBR (Fbuffer_disable_undo);
  DEFSUBR (Fbuffer_enable_undo);
  DEFSUBR (Fkill_buffer);
  DEFSUBR (Ferase_buffer);
  DEFSUBR (Frecord_buffer);
  DEFSUBR (Fset_buffer_major_mode);
  DEFSUBR (Fcurrent_buffer);
  DEFSUBR (Fset_buffer);
  DEFSUBR (Fbarf_if_buffer_read_only);
  DEFSUBR (Fbury_buffer);
  DEFSUBR (Fkill_all_local_variables);
  DEFSUBR (Fline_number);
#if defined (DEBUG_XEMACS) && defined (MULE)
  DEFSUBR (Fbuffer_char_byte_converion_info);
  DEFSUBR (Fstring_char_byte_converion_info);
#endif

  DEFERROR (Qprotected_field, "Attempt to modify a protected field",
	    Qinvalid_change);
}

void
reinit_vars_of_buffer (void)
{
  staticpro_nodump (&Vbuffer_alist);
  Vbuffer_alist = Qnil;
  current_buffer = 0;
}

/* initialize the buffer routines */
void
vars_of_buffer (void)
{
  /* This function can GC */
#ifdef MEMORY_USAGE_STATS
  OBJECT_HAS_PROPERTY
    (buffer, memusage_stats_list, list4 (Qtext, Qt, Qmarkers, Qextents));
#endif /* MEMORY_USAGE_STATS */

  staticpro (&QSFundamental);
  staticpro (&QSscratch);

  QSFundamental = build_ascstring ("Fundamental");
  QSscratch = build_ascstring ("*scratch*");

  DEFVAR_LISP ("change-major-mode-hook", &Vchange_major_mode_hook /*
List of hooks to be run before killing local variables in a buffer.
This should be used by any mode that temporarily alters the contents or
the read-only state of the buffer.  See also `kill-all-local-variables'.
*/ );
  Vchange_major_mode_hook = Qnil;

  DEFVAR_BOOL ("find-file-compare-truenames", &find_file_compare_truenames /*
If this is true, then the `find-file' command will check the truenames
of all visited files when deciding whether a given file is already in
a buffer, instead of just `buffer-file-name'.  This means that if you
attempt to visit another file which is a symbolic link to a file which
is already in a buffer, the existing buffer will be found instead of a
newly-created one.  This works if any component of the pathname
(including a non-terminal component) is a symbolic link as well, but
doesn't work with hard links (nothing does).

See also the variable `find-file-use-truenames'.
*/ );
#if defined(CYGWIN) || defined(WIN32_NATIVE)
  find_file_compare_truenames = 1;
#else
  find_file_compare_truenames = 0;
#endif

  DEFVAR_BOOL ("find-file-use-truenames", &find_file_use_truenames /*
If this is true, then a buffer's visited file-name will always be
chased back to the real file; it will never be a symbolic link, and there
will never be a symbolic link anywhere in its directory path.
That is, the buffer-file-name and buffer-file-truename will be equal.
This doesn't work with hard links.

See also the variable `find-file-compare-truenames'.
*/ );
  find_file_use_truenames = 0;

  DEFVAR_LISP ("before-change-functions", &Vbefore_change_functions /*
List of functions to call before each text change.
Two arguments are passed to each function: the positions of
the beginning and end of the range of old text to be changed.
\(For an insertion, the beginning and end are at the same place.)
No information is given about the length of the text after the change.

Buffer changes made while executing the `before-change-functions'
don't call any before-change or after-change functions.
*/ );
  Vbefore_change_functions = Qnil;

  /* FSF Emacs has the following additional doc at the end of
     before-change-functions and after-change-functions:

That's because these variables are temporarily set to nil.
As a result, a hook function cannot straightforwardly alter the value of
these variables.  See the Emacs Lisp manual for a way of
accomplishing an equivalent result by using other variables.

     But this doesn't apply under XEmacs because things are
     handled better. */

  DEFVAR_LISP ("after-change-functions", &Vafter_change_functions /*
List of functions to call after each text change.
Three arguments are passed to each function: the positions of
the beginning and end of the range of changed text,
and the length of the pre-change text replaced by that range.
\(For an insertion, the pre-change length is zero;
for a deletion, that length is the number of characters deleted,
and the post-change beginning and end are at the same place.)

Buffer changes made while executing `after-change-functions'
don't call any before-change or after-change functions.
*/ );
  Vafter_change_functions = Qnil;

  DEFVAR_LISP ("before-change-function", &Vbefore_change_function /*

*/ ); /* obsoleteness will be documented */
  Vbefore_change_function = Qnil;

  DEFVAR_LISP ("after-change-function", &Vafter_change_function /*

*/ ); /* obsoleteness will be documented */
  Vafter_change_function = Qnil;

  DEFVAR_LISP ("first-change-hook", &Vfirst_change_hook /*
A list of functions to call before changing a buffer which is unmodified.
The functions are run using the `run-hooks' function.
*/ );
  Vfirst_change_hook = Qnil;

#if 0 /* FSFmacs */
  xxDEFVAR_LISP ("transient-mark-mode", &Vtransient_mark_mode /*
*Non-nil means deactivate the mark when the buffer contents change.
*/ );
  Vtransient_mark_mode = Qnil;
#endif /* FSFmacs */

  DEFVAR_INT ("undo-threshold", &undo_threshold /*
Keep no more undo information once it exceeds this size.
This threshold is applied when garbage collection happens.
The size is counted as the number of bytes occupied,
which includes both saved text and other data.
*/ );
  undo_threshold = 20000;

  DEFVAR_INT ("undo-high-threshold", &undo_high_threshold /*
Don't keep more than this much size of undo information.
A command which pushes past this size is itself forgotten.
This threshold is applied when garbage collection happens.
The size is counted as the number of bytes occupied,
which includes both saved text and other data.
*/ );
  undo_high_threshold = 30000;

  DEFVAR_LISP ("inhibit-read-only", &Vinhibit_read_only /*
*Non-nil means disregard read-only status of buffers or characters.
If the value is t, disregard `buffer-read-only' and all `read-only'
text properties.  If the value is a list, disregard `buffer-read-only'
and disregard a `read-only' extent property or text property if the
property value is a member of the list.
*/ );
  Vinhibit_read_only = Qnil;

  DEFVAR_LISP ("kill-buffer-query-functions", &Vkill_buffer_query_functions /*
List of functions called with no args to query before killing a buffer.
*/ );
  Vkill_buffer_query_functions = Qnil;

  DEFVAR_BOOL ("delete-auto-save-files", &delete_auto_save_files /*
*Non-nil means delete auto-save file when a buffer is saved or killed.
*/ );
  delete_auto_save_files = 1;
}

/* The docstrings for DEFVAR_* are recorded externally by make-docfile.  */

#ifdef NEW_GC
#define DEFVAR_BUFFER_LOCAL_1(lname, field_name, forward_type, magic_fun) \
do									  \
{									  \
  struct symbol_value_forward *I_hate_C =				  \
    XSYMBOL_VALUE_FORWARD (ALLOC_NORMAL_LISP_OBJECT (symbol_value_forward));	  \
  /*mcpro ((Lisp_Object) I_hate_C);*/					  \
									  \
  I_hate_C->magic.value = &(buffer_local_flags.field_name);		  \
  I_hate_C->magic.type = forward_type;					  \
  I_hate_C->magicfun = magic_fun;					  \
									  \
  MARK_LRECORD_AS_LISP_READONLY (I_hate_C);				  \
									  \
  {									  \
    int offset = ((char *)symbol_value_forward_forward (I_hate_C) -	  \
		  (char *)&buffer_local_flags);				  \
    defvar_magic (lname, I_hate_C);					  \
									  \
    *((Lisp_Object *)(offset + (char *)XBUFFER (Vbuffer_local_symbols)))  \
      = intern (lname);							  \
  }									  \
} while (0)

#else /* not NEW_GC */
/* Renamed from DEFVAR_PER_BUFFER because FSFmacs D_P_B takes
   a bogus extra arg, which confuses an otherwise identical make-docfile.c */
#define DEFVAR_BUFFER_LOCAL_1(lname, field_name, forward_type, magicfun) \
do {									 \
  static const struct symbol_value_forward I_hate_C =			 \
  { /* struct symbol_value_forward */					 \
    { /* struct symbol_value_magic */					 \
      { /* struct old_lcrecord_header */				 \
	{ /* struct lrecord_header */					 \
	  lrecord_type_symbol_value_forward, /* lrecord_type_index */	 \
	  1, /* mark bit */						 \
	  1, /* c_readonly bit */					 \
	  1  /* lisp_readonly bit */					 \
	},								 \
	0, /* next */							 \
      },								 \
      &(buffer_local_flags.field_name),					 \
      forward_type							 \
    },									 \
    magicfun								 \
  };									 \
									 \
  {									 \
    int offset = ((char *)symbol_value_forward_forward (&I_hate_C) -	 \
		  (char *)&buffer_local_flags);				 \
    defvar_magic (lname, &I_hate_C);					 \
									 \
    *((Lisp_Object *)(offset + (char *)XBUFFER (Vbuffer_local_symbols))) \
      = intern (lname);							 \
  }									 \
} while (0)
#endif /* not NEW_GC */

#define DEFVAR_BUFFER_LOCAL_MAGIC(lname, field_name, magicfun)		\
	DEFVAR_BUFFER_LOCAL_1 (lname, field_name,			\
			       SYMVAL_CURRENT_BUFFER_FORWARD, magicfun)
#define DEFVAR_BUFFER_LOCAL(lname, field_name)				\
	DEFVAR_BUFFER_LOCAL_MAGIC (lname, field_name, 0)
#define DEFVAR_CONST_BUFFER_LOCAL_MAGIC(lname, field_name, magicfun)	\
	DEFVAR_BUFFER_LOCAL_1 (lname, field_name,			\
			       SYMVAL_CONST_CURRENT_BUFFER_FORWARD, magicfun)
#define DEFVAR_CONST_BUFFER_LOCAL(lname, field_name)			\
	DEFVAR_CONST_BUFFER_LOCAL_MAGIC (lname, field_name, 0)

#define DEFVAR_BUFFER_DEFAULTS_MAGIC(lname, field_name, magicfun)	\
	DEFVAR_SYMVAL_FWD (lname, &(buffer_local_flags.field_name),	\
			   SYMVAL_DEFAULT_BUFFER_FORWARD, magicfun)
#define DEFVAR_BUFFER_DEFAULTS(lname, field_name)			\
	DEFVAR_BUFFER_DEFAULTS_MAGIC (lname, field_name, 0)

static void
nuke_all_buffer_slots (struct buffer *b, Lisp_Object zap)
{
  zero_nonsized_lisp_object (wrap_buffer (b));

  b->extent_info = Qnil;
  b->indirect_children = Qnil;
  b->own_text.line_number_cache = Qnil;

#define MARKED_SLOT(x)	b->x = zap;
#include "bufslots.h"
}

static void
common_init_complex_vars_of_buffer (void)
{
  /* Make sure all markable slots in buffer_defaults
     are initialized reasonably, so mark_buffer won't choke. */
  Lisp_Object defobj = ALLOC_NORMAL_LISP_OBJECT (buffer);
  struct buffer *defs = XBUFFER (defobj);
  Lisp_Object symobj = ALLOC_NORMAL_LISP_OBJECT (buffer);
  struct buffer *syms = XBUFFER (symobj);

  staticpro_nodump (&Vbuffer_defaults);
  staticpro_nodump (&Vbuffer_local_symbols);
  Vbuffer_defaults = defobj;
  Vbuffer_local_symbols = symobj;

  nuke_all_buffer_slots (syms, Qnil);
  nuke_all_buffer_slots (defs, Qnil);
  defs->text = &defs->own_text;
  syms->text = &syms->own_text;

  /* Set up the non-nil default values of various buffer slots.
     Must do these before making the first buffer. */
  defs->major_mode = Qfundamental_mode;
  defs->mode_name = QSFundamental;
  defs->abbrev_table = Qnil;    /* real default setup by Lisp code */

  defs->case_table = Vstandard_case_table;
#ifdef MULE
  defs->category_table = Vstandard_category_table;
#endif /* MULE */
  defs->syntax_table = Vstandard_syntax_table;
  defs->mirror_syntax_table =
    XCHAR_TABLE (Vstandard_syntax_table)->mirror_table;
  defs->modeline_format = build_ascstring ("%-");  /* reset in loaddefs.el */
  defs->case_fold_search = Qt;
  defs->selective_display_ellipses = Qt;
  defs->tab_width = make_fixnum (8);
  defs->ctl_arrow = Qt;
  defs->fill_column = make_fixnum (70);
  defs->left_margin = Qzero;
  defs->saved_size = Qzero;	/* lisp code wants int-or-nil */
  defs->modtime = 0;
  defs->auto_save_modified = 0;
  defs->auto_save_failure_time = -1;
  defs->invisibility_spec = Qt;
  defs->buffer_local_face_property = 0;

  defs->indirect_children = Qnil;
  syms->indirect_children = Qnil;

  {
    /*  0 means var is always local.  Default used only at creation.
     * -1 means var is always local.  Default used only at reset and
     *    creation.
     * -2 means there's no lisp variable corresponding to this slot
     *    and the default is only used at creation.
     * -3 means no Lisp variable.  Default used only at reset and creation.
     * >0 is mask.  Var is local if ((buffer->local_var_flags & mask) != 0)
     *              Otherwise default is used.
     */
    Lisp_Object always_local_no_default = make_fixnum (0);
    Lisp_Object always_local_resettable = make_fixnum (-1);
    Lisp_Object resettable		= make_fixnum (-3);

    /* Assign the local-flags to the slots that have default values.
       The local flag is a bit that is used in the buffer
       to say that it has its own local value for the slot.
       The local flag bits are in the local_var_flags slot of the
       buffer.  */

    set_lheader_implementation ((struct lrecord_header *)
				&buffer_local_flags, &lrecord_buffer);
    nuke_all_buffer_slots (&buffer_local_flags, make_fixnum (-2));
    buffer_local_flags.filename		   = always_local_no_default;
    buffer_local_flags.directory	   = always_local_no_default;
    buffer_local_flags.backed_up	   = always_local_no_default;
    buffer_local_flags.saved_size	   = always_local_no_default;
    buffer_local_flags.auto_save_file_name = always_local_no_default;
    buffer_local_flags.read_only	   = always_local_no_default;

    buffer_local_flags.major_mode	   = always_local_resettable;
    buffer_local_flags.mode_name	   = always_local_resettable;
    buffer_local_flags.undo_list	   = always_local_no_default;
#if 0 /* FSFmacs */
    buffer_local_flags.mark_active	   = always_local_resettable;
#endif
    buffer_local_flags.point_before_scroll = always_local_resettable;
    buffer_local_flags.file_truename	   = always_local_no_default;
    buffer_local_flags.invisibility_spec   = always_local_resettable;
    buffer_local_flags.file_format	   = always_local_resettable;
    buffer_local_flags.generated_modeline_string = always_local_no_default;

    buffer_local_flags.keymap		= resettable;
    buffer_local_flags.case_table	= resettable;
    buffer_local_flags.syntax_table	= resettable;
#ifdef MULE
    buffer_local_flags.category_table	= resettable;
#endif
    buffer_local_flags.display_time     = always_local_no_default;
    buffer_local_flags.display_count    = make_fixnum (0);

    buffer_local_flags.modeline_format		  = make_fixnum (1<<0);
    buffer_local_flags.abbrev_mode		  = make_fixnum (1<<1);
    buffer_local_flags.overwrite_mode		  = make_fixnum (1<<2);
    buffer_local_flags.case_fold_search		  = make_fixnum (1<<3);
    buffer_local_flags.auto_fill_function	  = make_fixnum (1<<4);
    buffer_local_flags.selective_display	  = make_fixnum (1<<5);
    buffer_local_flags.selective_display_ellipses = make_fixnum (1<<6);
    buffer_local_flags.tab_width		  = make_fixnum (1<<7);
    buffer_local_flags.truncate_lines		  = make_fixnum (1<<8);
    buffer_local_flags.ctl_arrow		  = make_fixnum (1<<9);
    buffer_local_flags.fill_column		  = make_fixnum (1<<10);
    buffer_local_flags.left_margin		  = make_fixnum (1<<11);
    buffer_local_flags.abbrev_table		  = make_fixnum (1<<12);
#ifdef REGION_CACHE_NEEDS_WORK
    buffer_local_flags.cache_long_line_scans	  = make_fixnum (1<<13);
#endif
    buffer_local_flags.buffer_file_coding_system  = make_fixnum (1<<14);

    /* #### Warning: 1<<31 is the largest number currently allowable
       due to the XFIXNUM() handling of this value.  With some
       rearrangement you can get 3 more bits.

       #### 3 more?  34 bits???? -ben */
  }
}

#define BUFFER_SLOTS_SIZE (offsetof (struct buffer, BUFFER_SLOTS_LAST_NAME) - offsetof (struct buffer, BUFFER_SLOTS_FIRST_NAME) + sizeof (Lisp_Object))
#define BUFFER_SLOTS_COUNT (BUFFER_SLOTS_SIZE / sizeof (Lisp_Object))

void
reinit_complex_vars_of_buffer_runtime_only (void)
{
  struct buffer *defs, *syms;

  common_init_complex_vars_of_buffer ();

  defs = XBUFFER (Vbuffer_defaults);
  syms = XBUFFER (Vbuffer_local_symbols);
  memcpy (&defs->BUFFER_SLOTS_FIRST_NAME,
	  buffer_defaults_saved_slots,
	  BUFFER_SLOTS_SIZE);
  memcpy (&syms->BUFFER_SLOTS_FIRST_NAME,
	  buffer_local_symbols_saved_slots,
	  BUFFER_SLOTS_SIZE);
}


static const struct memory_description buffer_slots_description_1[] = {
  { XD_LISP_OBJECT_ARRAY, 0, BUFFER_SLOTS_COUNT },
  { XD_END }
};

static const struct sized_memory_description buffer_slots_description = {
  BUFFER_SLOTS_SIZE,
  buffer_slots_description_1
};

void
complex_vars_of_buffer (void)
{
  struct buffer *defs, *syms;

  common_init_complex_vars_of_buffer ();

  defs = XBUFFER (Vbuffer_defaults);
  syms = XBUFFER (Vbuffer_local_symbols);
  buffer_defaults_saved_slots      = &defs->BUFFER_SLOTS_FIRST_NAME;
  buffer_local_symbols_saved_slots = &syms->BUFFER_SLOTS_FIRST_NAME;
  dump_add_root_block_ptr (&buffer_defaults_saved_slots,      &buffer_slots_description);
  dump_add_root_block_ptr (&buffer_local_symbols_saved_slots, &buffer_slots_description);

  DEFVAR_BUFFER_DEFAULTS ("default-modeline-format", modeline_format /*
Default value of `modeline-format' for buffers that don't override it.
This is the same as (default-value 'modeline-format).
*/ );

  DEFVAR_BUFFER_DEFAULTS ("default-abbrev-mode", abbrev_mode /*
Default value of `abbrev-mode' for buffers that do not override it.
This is the same as (default-value 'abbrev-mode).
*/ );

  DEFVAR_BUFFER_DEFAULTS ("default-ctl-arrow", ctl_arrow /*
Default value of `ctl-arrow' for buffers that do not override it.
This is the same as (default-value 'ctl-arrow).
*/ );

#if 0 /* #### make this a specifier! */
  DEFVAR_BUFFER_DEFAULTS ("default-display-direction", display_direction /*
Default display-direction for buffers that do not override it.
This is the same as (default-value 'display-direction).
Note: This is not yet implemented.
*/ );
#endif

  DEFVAR_BUFFER_DEFAULTS ("default-truncate-lines", truncate_lines /*
Default value of `truncate-lines' for buffers that do not override it.
This is the same as (default-value 'truncate-lines).
*/ );

  DEFVAR_BUFFER_DEFAULTS ("default-fill-column", fill_column /*
Default value of `fill-column' for buffers that do not override it.
This is the same as (default-value 'fill-column).
*/ );

  DEFVAR_BUFFER_DEFAULTS ("default-left-margin", left_margin /*
Default value of `left-margin' for buffers that do not override it.
This is the same as (default-value 'left-margin).
*/ );

  DEFVAR_BUFFER_DEFAULTS ("default-tab-width", tab_width /*
Default value of `tab-width' for buffers that do not override it.
This is the same as (default-value 'tab-width).
*/ );

  DEFVAR_BUFFER_DEFAULTS ("default-case-fold-search", case_fold_search /*
Default value of `case-fold-search' for buffers that don't override it.
This is the same as (default-value 'case-fold-search).
*/ );

  DEFVAR_BUFFER_LOCAL ("modeline-format", modeline_format /*
Template for displaying modeline for current buffer.
Each buffer has its own value of this variable.
Value may be a string, symbol, glyph, generic specifier, list or cons cell.
For a symbol, its value is processed (but it is ignored if t or nil).
 A string appearing directly as the value of a symbol is processed verbatim
 in that the %-constructs below are not recognized.
For a glyph, it is inserted as is.
For a generic specifier (i.e. a specifier of type `generic'), its instance
 is computed in the current window using the equivalent of `specifier-instance'
 and the value is processed.
For a list whose car is a symbol, the symbol's value is taken,
 and if that is non-nil, the cadr of the list is processed recursively.
 Otherwise, the caddr of the list (if there is one) is processed.
For a list whose car is a boolean specifier, its instance is computed
 in the current window using the equivalent of `specifier-instance',
 and if that is non-nil, the cadr of the list is processed recursively.
 Otherwise, the caddr of the list (if there is one) is processed.
For a list whose car is a string or list, each element is processed
 recursively and the results are effectively concatenated.
For a list whose car is an integer, the cdr of the list is processed
 and padded (if the number is positive) or truncated (if negative)
 to the width specified by that number.
For a list whose car is an extent, the cdr of the list is processed
 normally but the results are displayed using the face of the
 extent, and mouse clicks over this section are processed using the
 keymap of the extent. (In addition, if the extent has a help-echo
 property, that string will be echoed when the mouse moves over this
 section.) If extents are nested, all keymaps are properly consulted
 when processing mouse clicks, but multiple faces are not correctly
 merged (only the first face is used), and lists of faces are not
 correctly handled.  See `generated-modeline-string' for more information.
A string is printed verbatim in the modeline except for %-constructs:
  (%-constructs are processed when the string is the entire modeline-format
   or when it is found in a cons-cell or a list)
  %b -- print buffer name.      %c -- print the current column number.
  %f -- print visited file name.
  %* -- print %, * or hyphen.   %+ -- print *, % or hyphen.
	% means buffer is read-only and * means it is modified.
	For a modified read-only buffer, %* gives % and %+ gives *.
  %s -- print process status.   %l -- print the current line number.
  %S -- print name of selected frame (only meaningful under X Windows).
  %p -- print percent of buffer above top of window, or Top, Bot or All.
  %P -- print percent of buffer above bottom of window, perhaps plus Top,
        or print Bottom or All.
  %n -- print Narrow if appropriate.
  %C -- print the mnemonic for `buffer-file-coding-system'.
  %[ -- print one [ for each recursive editing level.  %] similar.
  %% -- print %.                %- -- print infinitely many dashes.
Decimal digits after the % specify field width to which to pad.
*/ );

  DEFVAR_BUFFER_DEFAULTS ("default-major-mode", major_mode /*
*Major mode for new buffers.  Defaults to `fundamental-mode'.
nil here means use current buffer's major mode.
*/ );

  DEFVAR_BUFFER_DEFAULTS ("fundamental-mode-abbrev-table", abbrev_table /*
The abbrev table of mode-specific abbrevs for Fundamental Mode.
*/ );

  DEFVAR_BUFFER_LOCAL ("major-mode", major_mode /*
Symbol for current buffer's major mode.
*/ );

  DEFVAR_BUFFER_LOCAL ("mode-name", mode_name /*
Pretty name of current buffer's major mode (a string).
*/ );

  DEFVAR_BUFFER_LOCAL ("abbrev-mode", abbrev_mode /*
Non-nil turns on automatic expansion of abbrevs as they are inserted.
Automatically becomes buffer-local when set in any fashion.
*/ );

  DEFVAR_BUFFER_LOCAL ("case-fold-search", case_fold_search /*
*If non-nil, searches and matches should ignore case.
Automatically becomes buffer-local when set in any fashion.
*/ );

  DEFVAR_BUFFER_LOCAL ("fill-column", fill_column /*
*Column beyond which automatic line-wrapping should happen.
Automatically becomes buffer-local when set in any fashion.
*/ );

  DEFVAR_BUFFER_LOCAL ("left-margin", left_margin /*
*Column for the default indent-line-function to indent to.
Linefeed indents to this column in Fundamental mode.
Automatically becomes buffer-local when set in any fashion.
Do not confuse this with the specifier `left-margin-width';
that controls the size of a margin that is displayed outside
of the text area.
*/ );

  DEFVAR_BUFFER_LOCAL_MAGIC ("tab-width", tab_width /*
*Distance between tab stops (for display of tab characters), in columns.
Automatically becomes buffer-local when set in any fashion.
*/ , redisplay_variable_changed);

  DEFVAR_BUFFER_LOCAL_MAGIC ("ctl-arrow", ctl_arrow /*
*Non-nil means display control chars with uparrow.
Nil means use backslash and octal digits.
An integer means characters >= ctl-arrow are assumed to be printable, and
will be displayed as a single glyph.
Any other value is the same as 160 - the code SPC with the high bit on.

The interpretation of this variable is likely to change in the future.

Automatically becomes buffer-local when set in any fashion.
This variable does not apply to characters whose display is specified
in the current display table (if there is one).
*/ , redisplay_variable_changed);

#if 0 /* #### Make this a specifier! */
  xxDEFVAR_BUFFER_LOCAL ("display-direction", display_direction /*
*Non-nil means lines in the buffer are displayed right to left.
Nil means left to right. (Not yet implemented.)
*/ );
#endif /* Not yet implemented */

  DEFVAR_BUFFER_LOCAL_MAGIC ("truncate-lines", truncate_lines /*
*Non-nil means do not display continuation lines;
give each line of text one frame line.
Automatically becomes buffer-local when set in any fashion.

Note that this is overridden by the variable
`truncate-partial-width-windows' if that variable is non-nil
and this buffer is not full-frame width.
*/ , redisplay_variable_changed);

  DEFVAR_BUFFER_LOCAL ("default-directory", directory /*
Name of default directory of current buffer.  Should end with slash.
Each buffer has its own value of this variable.
*/ );

  /* NOTE: The default value is set in code-init.el. */
  DEFVAR_BUFFER_DEFAULTS ("default-buffer-file-coding-system", buffer_file_coding_system /*
Default value of `buffer-file-coding-system' for buffers that do not override it.
This is the same as (default-value 'buffer-file-coding-system).
This value is used both for buffers without associated files and
for buffers whose files do not have any apparent coding system.
See `buffer-file-coding-system'.
*/ );

  DEFVAR_BUFFER_LOCAL ("buffer-file-coding-system", buffer_file_coding_system /*
*Current coding system for the current buffer.
When the buffer is written out into a file, this coding system will be
used for the encoding.  Automatically buffer-local when set in any
fashion.  This is normally set automatically when a file is loaded in
based on the determined coding system of the file (assuming that
`buffer-file-coding-system-for-read' is set to `undecided', which
calls for automatic determination of the file's coding system).
Normally the modeline indicates the current file coding system using
its mnemonic abbreviation.

The default value for this variable (which is normally used for
buffers without associated files) is also used when automatic
detection of a file's encoding is called for and there was no
discernible encoding in the file (i.e. it was entirely or almost
entirely ASCII).  The default value should generally *not* be set to
nil (equivalent to `no-conversion'), because if extended characters
are ever inserted into the buffer, they will be lost when the file is
written out.  A good choice is `iso-2022-8' (the simple ISO 2022 8-bit
encoding), which will write out ASCII and Latin-1 characters in the
standard (and highly portable) fashion and use standard escape
sequences for other charsets.  Another reasonable choice is
`escape-quoted', which is equivalent to `iso-2022-8' but prefixes
certain control characters with ESC to make sure they are not
interpreted as escape sequences when read in.  This latter coding
system results in more "correct" output in the presence of control
characters in the buffer, in the sense that when read in again using
the same coding system, the result will virtually always match the
original contents of the buffer, which is not the case with
`iso-2022-8'; but the output is less portable when dealing with binary
data -- there may be stray ESC characters when the file is read by
another program.

`buffer-file-coding-system' does *not* control the coding system used when
a file is read in.  Use the variables `buffer-file-coding-system-for-read'
and `file-coding-system-alist' for that.  From a Lisp program, if
you wish to unilaterally specify the coding system used for one
particular operation, you should bind the variable
`coding-system-for-read' rather than changing the other two
variables just mentioned, which are intended to be used for
global environment specification.

See `insert-file-contents' for a full description of how a file's
coding system is determined when it is read in.
*/ );

  DEFVAR_BUFFER_LOCAL ("auto-fill-function", auto_fill_function /*
Function called (if non-nil) to perform auto-fill.
It is called after self-inserting a space at a column beyond `fill-column'.
Each buffer has its own value of this variable.
NOTE: This variable is not an ordinary hook;
It may not be a list of functions.
*/ );

  DEFVAR_BUFFER_LOCAL ("buffer-file-name", filename /*
Name of file visited in current buffer, or nil if not visiting a file.
Each buffer has its own value of this variable.
Code that changes this variable must maintain the invariant
`(equal buffer-file-truename (file-truename buffer-file-name))'.
*/ );

#if 0 /* FSFmacs */
/*
Abbreviated truename of file visited in current buffer, or nil if none.
The truename of a file is calculated by `file-truename'
and then abbreviated with `abbreviate-file-name'.
Each buffer has its own value of this variable.
*/
#endif /* FSFmacs */

  DEFVAR_BUFFER_LOCAL ("buffer-file-truename", file_truename /*
The real name of the file visited in the current buffer, or nil if not
visiting a file.  This is the result of passing `buffer-file-name' to the
`file-truename' function.  Every buffer has its own value of this variable.
Code that changes the file name associated with a buffer maintains the
invariant `(equal buffer-file-truename (file-truename buffer-file-name))'.
*/ );

  DEFVAR_BUFFER_LOCAL ("buffer-auto-save-file-name", auto_save_file_name /*
Name of file for auto-saving current buffer,
or nil if buffer should not be auto-saved.
Each buffer has its own value of this variable.
*/ );

  DEFVAR_BUFFER_LOCAL ("buffer-read-only", read_only /*
Non-nil if this buffer is read-only.
Each buffer has its own value of this variable.
*/ );

  DEFVAR_BUFFER_LOCAL ("buffer-backed-up", backed_up /*
Non-nil if this buffer's file has been backed up.
Backing up is done before the first time the file is saved.
Each buffer has its own value of this variable.
*/ );

  DEFVAR_BUFFER_LOCAL ("buffer-saved-size", saved_size /*
Length of current buffer when last read in, saved or auto-saved.
0 initially.
Each buffer has its own value of this variable.
*/ );

  DEFVAR_BUFFER_LOCAL_MAGIC ("selective-display", selective_display /*
Non-nil enables selective display:
Integer N as value means display only lines
 that start with less than n columns of space.
A value of t means, after a ^M, all the rest of the line is invisible.
 Then ^M's in the file are written into files as newlines.

Automatically becomes buffer-local when set in any fashion.
*/, redisplay_variable_changed);

#ifndef old
  DEFVAR_BUFFER_LOCAL_MAGIC ("selective-display-ellipses",
			     selective_display_ellipses /*
t means display ... on previous line when a line is invisible.
Automatically becomes buffer-local when set in any fashion.
*/, redisplay_variable_changed);
#endif

  DEFVAR_BUFFER_LOCAL ("local-abbrev-table", abbrev_table /*
Local (mode-specific) abbrev table of current buffer.
*/ );

  DEFVAR_BUFFER_LOCAL ("overwrite-mode", overwrite_mode /*
Non-nil if self-insertion should replace existing text.
The value should be one of `overwrite-mode-textual',
`overwrite-mode-binary', or nil.
If it is `overwrite-mode-textual', self-insertion still
inserts at the end of a line, and inserts when point is before a tab,
until the tab is filled in.
If `overwrite-mode-binary', self-insertion replaces newlines and tabs too.
Automatically becomes buffer-local when set in any fashion.

Normally, you shouldn't modify this variable by hand, but use the functions
`overwrite-mode' and `binary-overwrite-mode' instead. However, you can
customize the default value from the options menu.
*/ );

#if 0 /* FSFmacs */
  /* Adds the following to the doc string for buffer-undo-list:

An entry (nil PROPERTY VALUE BEG . END) indicates that a text property
was modified between BEG and END.  PROPERTY is the property name,
and VALUE is the old value.
*/
#endif /* FSFmacs */

  DEFVAR_BUFFER_LOCAL ("buffer-undo-list", undo_list /*
List of undo entries in current buffer.
Recent changes come first; older changes follow newer.

An entry (START . END) represents an insertion which begins at
position START and ends at position END.

An entry (TEXT . POSITION) represents the deletion of the string TEXT
from (abs POSITION).  If POSITION is positive, point was at the front
of the text being deleted; if negative, point was at the end.

An entry (t HIGH . LOW) indicates that the buffer previously had
"unmodified" status.  HIGH and LOW are the high and low 16-bit portions
of the visited file's modification time, as of that time.  If the
modification time of the most recent save is different, this entry is
obsolete.

An entry of the form EXTENT indicates that EXTENT was attached in
the buffer.  Undoing an entry of this form detaches EXTENT.

An entry of the form (EXTENT START END) indicates that EXTENT was
detached from the buffer.  Undoing an entry of this form attaches
EXTENT from START to END.

An entry of the form POSITION indicates that point was at the buffer
location given by the integer.  Undoing an entry of this form places
point at POSITION.

nil marks undo boundaries.  The undo command treats the changes
between two undo boundaries as a single step to be undone.

If the value of the variable is t, undo information is not recorded.
*/ );

#if 0 /* FSFmacs */
  xxDEFVAR_BUFFER_LOCAL ("mark-active", mark_active /*
Non-nil means the mark and region are currently active in this buffer.
Automatically local in all buffers.
*/ );
#endif /* FSFmacs */

#ifdef REGION_CACHE_NEEDS_WORK
  xxDEFVAR_BUFFER_LOCAL ("cache-long-line-scans", cache_long_line_scans /*
Non-nil means that Emacs should use caches to handle long lines more quickly.
This variable is buffer-local, in all buffers.

Normally, the line-motion functions work by scanning the buffer for
newlines.  Columnar operations (like move-to-column and
compute-motion) also work by scanning the buffer, summing character
widths as they go.  This works well for ordinary text, but if the
buffer's lines are very long (say, more than 500 characters), these
motion functions will take longer to execute.  Emacs may also take
longer to update the display.

If cache-long-line-scans is non-nil, these motion functions cache the
results of their scans, and consult the cache to avoid rescanning
regions of the buffer until the text is modified.  The caches are most
beneficial when they prevent the most searching---that is, when the
buffer contains long lines and large regions of characters with the
same, fixed screen width.

When cache-long-line-scans is non-nil, processing short lines will
become slightly slower (because of the overhead of consulting the
cache), and the caches will use memory roughly proportional to the
number of newlines and characters whose screen width varies.

The caches require no explicit maintenance; their accuracy is
maintained internally by the Emacs primitives.  Enabling or disabling
the cache should not affect the behavior of any of the motion
functions; it should only affect their performance.
*/ );
#endif /* REGION_CACHE_NEEDS_WORK */

  DEFVAR_BUFFER_LOCAL ("point-before-scroll", point_before_scroll /*
Value of point before the last series of scroll operations, or nil.
*/ );

  DEFVAR_BUFFER_LOCAL ("buffer-file-format", file_format /*
List of formats to use when saving this buffer.
Formats are defined by `format-alist'.  This variable is
set when a file is visited.  Automatically local in all buffers.
*/ );

  DEFVAR_BUFFER_LOCAL ("buffer-display-count", display_count /*
A number incremented each time this buffer is displayed in a window.
The function `set-window-buffer' updates it.
*/ );

  DEFVAR_BUFFER_LOCAL ("buffer-display-time", display_time /*
Time stamp updated each time this buffer is displayed in a window.
The function `set-window-buffer' updates this variable
to the value obtained by calling `current-time'.
If the buffer has never been shown in a window, the value is nil.
*/);

  DEFVAR_BUFFER_LOCAL_MAGIC ("buffer-invisibility-spec", invisibility_spec /*
Invisibility spec of this buffer.
The default is t, which means that text is invisible
if it has (or is covered by an extent with) a non-nil `invisible' property.
If the value is a list, a text character is invisible if its `invisible'
property is an element in that list.
If an element is a cons cell of the form (PROPERTY . ELLIPSIS),
then characters with property value PROPERTY are invisible,
and they have an ellipsis as well if ELLIPSIS is non-nil.
Note that the actual characters used for the ellipsis are controllable
using `invisible-text-glyph', and default to "...".
*/, redisplay_variable_changed);

  DEFVAR_CONST_BUFFER_LOCAL ("generated-modeline-string",
			     generated_modeline_string /*
String of characters in this buffer's modeline as of the last redisplay.
Each time the modeline is recomputed, the resulting characters are
stored in this string, which is resized as necessary.  You may not
set this variable, and modifying this string will not change the
modeline; you have to change `modeline-format' if you want that.

For each extent in `modeline-format' that is encountered when
processing the modeline, a corresponding extent is placed in
`generated-modeline-string' and covers the text over which the
extent in `modeline-format' applies.  The extent in
`generated-modeline-string' is made a child of the extent in
`modeline-format', which means that it inherits all properties from
that extent.  Note that the extents in `generated-modeline-string'
are managed automatically.  You should not explicitly put any extents
in `generated-modeline-string'; if you do, they will disappear the
next time the modeline is processed.

For extents in `modeline-format', the following properties are currently
handled:

`face'
	Affects the face of the modeline text.  Currently, faces do
	not merge properly; only the most recently encountered face
	is used.  This is a bug.

`keymap'
	Affects the disposition of button events over the modeline
	text.  Multiple applicable keymaps *are* handled properly,
	and `modeline-map' still applies to any events that don't
	have bindings in extent-specific keymaps.

`help-echo'
	If a string, causes the string to be displayed when the mouse
	moves over the text.
*/ );

  /* Check for DEFVAR_BUFFER_LOCAL without initializing the corresponding
     slot of buffer_local_flags and vice-versa.  Must be done after all
     DEFVAR_BUFFER_LOCAL() calls. */
#define MARKED_SLOT(slot)					\
  assert ((XFIXNUM (buffer_local_flags.slot) != -2 &&		\
           XFIXNUM (buffer_local_flags.slot) != -3)		\
	  == !(NILP (XBUFFER (Vbuffer_local_symbols)->slot)));
#include "bufslots.h"

  {
    Lisp_Object scratch = Fget_buffer_create (QSscratch);
    Fset_buffer (scratch);
    /* Want no undo records for *scratch* until after Emacs is dumped */
    Fbuffer_disable_undo (scratch);
  }
}

#ifndef WIN32_NATIVE
/* Is PWD another name for `.' ? */
static int
directory_is_current_directory (Ibyte *pwd)
{
  struct stat dotstat, pwdstat;

  return (IS_DIRECTORY_SEP (*pwd)
	  && qxe_stat (pwd, &pwdstat) == 0
	  && qxe_stat ((Ibyte *) ".", &dotstat) == 0
	  && dotstat.st_ino == pwdstat.st_ino
	  && dotstat.st_dev == pwdstat.st_dev);
}
#endif

/* A stand-in for getcwd() #### Fix not to depend on arbitrary size limits */

Ibyte *
get_initial_directory (Ibyte *pathname, Bytecount size)
{
  if (pathname)
    {
      qxestrncpy (pathname, initial_directory, size);
      pathname[size - 1] = '\0';
    }
  return initial_directory;
}

void
init_initial_directory (void)
{
  /* This function can GC */

#ifndef WIN32_NATIVE
  Ibyte *pwd;
#endif

  /* If PWD is accurate, use it instead of calling getcwd.  This is faster
     when PWD is right, and may avoid a fatal error.  */
#ifndef WIN32_NATIVE
  if ((pwd = egetenv ("PWD")) != NULL
      && directory_is_current_directory (pwd))
    initial_directory = qxestrdup (pwd);
  else
#endif
    if ((initial_directory = qxe_allocating_getcwd ()) == NULL)
      {
	Ibyte *errmess;
	GET_STRERROR (errmess, errno);
	stderr_out ("`getcwd' failed: %s: changing default directory to %s\n",
                    errmess, DEFAULT_DIRECTORY_FALLBACK);

        if (qxe_chdir ((Ibyte *) DEFAULT_DIRECTORY_FALLBACK) < 0)
          {
            GET_STRERROR (errmess, errno);

            fatal ("could not `chdir' to `%s': %s\n",
                   DEFAULT_DIRECTORY_FALLBACK, errmess);
          }

        initial_directory = qxe_allocating_getcwd();
        assert (initial_directory != NULL);
      }

  /* Make sure pwd is DIRECTORY_SEP-terminated.
     Maybe this should really use some standard subroutine
     whose definition is filename syntax dependent.  */
  {
    Bytecount len = qxestrlen (initial_directory);

    if (! IS_DIRECTORY_SEP (initial_directory[len - 1]))
      {
	XREALLOC_ARRAY (initial_directory, Ibyte, len + 2);
	initial_directory[len] = DIRECTORY_SEP;
	initial_directory[len + 1] = '\0';
      }
  }

#ifdef WIN32_NATIVE
  {
    Ibyte *newinit = mswindows_canonicalize_filename (initial_directory);
    xfree (initial_directory);
    initial_directory = newinit;
  }

  {
    /* Make the real wd be the location of xemacs.exe to avoid conflicts
       when renaming or deleting directories.  (We also don't call chdir
       when running subprocesses for the same reason.)  */

    Extbyte *p;
    Extbyte *modname = mswindows_get_module_file_name ();
      
    assert (modname);
    p = qxetcsrchr (modname, '\\');
    assert (p);
    XECOPY_TCHAR (p, '\0');
  
    qxeSetCurrentDirectory (modname);
    xfree (modname);
  }
#endif
}

void
init_buffer_1 (void)
{
  Fset_buffer (Fget_buffer_create (QSscratch));
}

void
init_buffer_2 (void)
{
  /* This function can GC */
  Fset_buffer (Fget_buffer (QSscratch));

  current_buffer->directory = build_istring (initial_directory);

#if 0 /* FSFmacs */
  /* #### is this correct? */
  temp = get_minibuffer (0);
  XBUFFER (temp)->directory = current_buffer->directory;
#endif /* FSFmacs */
}
