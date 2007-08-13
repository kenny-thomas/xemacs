/* Buffer manipulation primitives for XEmacs.
   Copyright (C) 1985-1989, 1992-1995 Free Software Foundation, Inc.
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

/* Synched up with: Mule 2.0, FSF 19.30. */

/* Authorship:

   FSF: long ago.
   JWZ: some changes for Lemacs, long ago. (e.g. separate buffer
        list per frame.)
   Mly: a few changes for buffer-local vars, 19.8 or 19.9.
   Ben Wing: some changes and cleanups for Mule, 19.12.
 */

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
#include "commands.h"
#include "elhash.h"
#include "extents.h"
#include "faces.h"
#include "frame.h"
#include "insdel.h"
#include "process.h"            /* for kill_buffer_processes */
#ifdef REGION_CACHE_NEEDS_WORK
#include "region-cache.h"
#endif
#include "symeval.h"
#include "syntax.h"
#include "sysdep.h"	/* for getwd */
#include "window.h"

#include "sysfile.h"

struct buffer *current_buffer;	/* the current buffer */

/* This structure holds the default values of the buffer-local variables
   defined with DEFVAR_BUFFER_LOCAL, that have special slots in each buffer.
   The default value occupies the same slot in this structure
   as an individual buffer's value occupies in that buffer.
   Setting the default value also goes through the alist of buffers
   and stores into each buffer that does not say it has a local value.  */
Lisp_Object Vbuffer_defaults;

/* This structure marks which slots in a buffer have corresponding
   default values in buffer_defaults.
   Each such slot has a nonzero value in this structure.
   The value has only one nonzero bit.

   When a buffer has its own local value for a slot,
   the bit for that slot (found in the same slot in this structure)
   is turned on in the buffer's local_var_flags slot.

   If a slot in this structure is 0, then there is a DEFVAR_BUFFER_LOCAL
   for the slot, but there is no default value for it; the corresponding
   slot in buffer_defaults is not used except to initialize newly-created
   buffers.

   If a slot is -1, then there is a DEFVAR_BUFFER_LOCAL for it
   as well as a default value which is used to initialize newly-created
   buffers and as a reset-value when local-vars are killed.

   If a slot is -2, there is no DEFVAR_BUFFER_LOCAL for it. 
   (The slot is always local, but there's no lisp variable for it.)
   The default value is only used to initialize newly-creation buffers. 
   
   If a slot is -3, then there is no DEFVAR_BUFFER_LOCAL for it but
   there is a default which is used to initialize newly-creation
   buffers and as a reset-value when local-vars are killed.

   
   */
struct buffer buffer_local_flags;

/* This structure holds the names of symbols whose values may be
   buffer-local.  It is indexed and accessed in the same way as the above. */
static Lisp_Object Vbuffer_local_symbols;

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
Lisp_Object Vdelete_auto_save_files;

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
Lisp_Object Qbuffer_file_name, Qbuffer_undo_list;

Lisp_Object Qrename_auto_save_file;

Lisp_Object Qget_file_buffer;
Lisp_Object Qchange_major_mode_hook, Vchange_major_mode_hook;

Lisp_Object Qfind_file_compare_truenames;

Lisp_Object Qswitch_to_buffer;

/* Two thresholds controlling how much undo information to keep.  */
int undo_threshold;
int undo_high_threshold;

int find_file_compare_truenames;
int find_file_use_truenames;


static void reset_buffer_local_variables (struct buffer *, int first_time);
static void nuke_all_buffer_slots (struct buffer *b, Lisp_Object zap);
static Lisp_Object mark_buffer (Lisp_Object, void (*) (Lisp_Object));
static void print_buffer (Lisp_Object, Lisp_Object, int);
/* We do not need a finalize method to handle a buffer's children list
   because all buffers have `kill-buffer' applied to them before
   they disappear, and the children removal happens then. */
DEFINE_LRECORD_IMPLEMENTATION ("buffer", buffer,
                               mark_buffer, print_buffer, 0, 0, 0,
			       struct buffer);

#ifdef ENERGIZE
extern void mark_energize_buffer_data (struct buffer *b,
				       void (*markobj) (Lisp_Object));
#endif

Lisp_Object
make_buffer (struct buffer *buf)
{
  Lisp_Object obj;
  XSETBUFFER (obj, buf);
  return obj;
}

static Lisp_Object
mark_buffer (Lisp_Object obj, void (*markobj) (Lisp_Object))
{
  struct buffer *buf = XBUFFER (obj);

  /* Truncate undo information. */
  buf->undo_list = truncate_undo_list (buf->undo_list,
                                       undo_threshold,
                                       undo_high_threshold);

#define MARKED_SLOT(x) ((markobj) (buf->x));
#include "bufslots.h"
#undef MARKED_SLOT

#ifdef ENERGIZE
  mark_energize_buffer_data (XBUFFER (obj), markobj);
#endif

  ((markobj) (buf->extent_info));

  /* Don't mark normally through the children slot.
     (Actually, in this case, it doesn't matter.)
   */
  mark_conses_in_list (buf->indirect_children);

  if (buf->base_buffer)
    {
      Lisp_Object base_buf_obj = Qnil;

      XSETBUFFER (base_buf_obj, buf->base_buffer);
      return base_buf_obj;
    }
  else
    return Qnil;
}

static void
print_buffer (Lisp_Object obj, Lisp_Object printcharfun, int escapeflag)
{
  struct buffer *b = XBUFFER (obj);

  if (print_readably) 
    {
      if (!BUFFER_LIVE_P (b))
	error ("printing unreadable object #<killed buffer>");
      else
	error ("printing unreadable object #<buffer %s>", 
	       XSTRING_DATA (b->name));
    }
  else if (!BUFFER_LIVE_P (b))
    write_c_string ("#<killed buffer>", printcharfun);
  else if (escapeflag)
    {
      write_c_string ("#<buffer ", printcharfun);
      print_internal (b->name, printcharfun, 1);
      write_c_string (">", printcharfun);
    }
  else
    {
      print_internal (b->name, printcharfun, 0);
    }
}
  

DEFUN ("bufferp", Fbufferp, 1, 1, 0, /*
T if OBJECT is an editor buffer.
*/
       (object))
{
  if (BUFFERP (object))
    return Qt;
  return Qnil;
}

DEFUN ("buffer-live-p", Fbuffer_live_p, 1, 1, 0, /*
T if OBJECT is an editor buffer that has not been deleted.
*/
       (object))
{
  if (BUFFERP (object) && BUFFER_LIVE_P (XBUFFER (object)))
    return Qt;
  return Qnil;
}

static void
nsberror (Lisp_Object spec)
{
  if (STRINGP (spec))
    error ("No buffer named %s", XSTRING_DATA (spec));
  signal_simple_error ("Invalid buffer argument", spec);
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
  Lisp_Object list;
  if (EQ (frame, Qt))
    list = Vbuffer_alist;
  else
    list = decode_frame (frame)->buffer_alist;
  return Fmapcar (Qcdr, list);
}

Lisp_Object
get_buffer (Lisp_Object name, int error_if_deleted_or_does_not_exist)
{
  Lisp_Object buf;

  if (BUFFERP (name))
    {
      if (!BUFFER_LIVE_P (XBUFFER (name)))
        {
          if (error_if_deleted_or_does_not_exist)
            nsberror (name);
          return (Qnil);
        }
      return name;
    }
  else
    {
      struct gcpro gcpro1;

      CHECK_STRING (name);
      name = LISP_GETTEXT (name); /* I18N3 */
      GCPRO1 (name);
      buf = Fcdr (Fassoc (name, Vbuffer_alist));
      UNGCPRO;
      if (NILP (buf) && error_if_deleted_or_does_not_exist)
	nsberror (name);
      return (buf);
    }
}

struct buffer *
decode_buffer (Lisp_Object buffer, int allow_string)
{
  if (NILP (buffer))
    {
      return current_buffer;
    }
  else if (STRINGP (buffer))
    {
      if (allow_string)
	return XBUFFER (get_buffer (buffer, 1));
      else
	CHECK_BUFFER (buffer);    /* This will cause a wrong-type error. */
    }

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
  XSETBUFFER (buffer, b);
  return buffer;
}

#if 0 /* FSFmacs */
/* bleagh!!! */
/* Like Fassoc, but use Fstring_equal to compare
   (which ignores text properties),
   and don't ever QUIT.  */

static Lisp_Object
assoc_ignore_text_properties (register Lisp_Object key, Lisp_Object list)
{
  register Lisp_Object tail;
  for (tail = list; !NILP (tail); tail = Fcdr (tail))
    {
      register Lisp_Object elt, tem;
      elt = Fcar (tail);
      tem = Fstring_equal (Fcar (elt), key);
      if (!NILP (tem))
	return elt;
    }
  return Qnil;
}

#endif

DEFUN ("get-buffer", Fget_buffer, 1, 1, 0, /*
Return the buffer named NAME (a string).
If there is no live buffer named NAME, return nil.
NAME may also be a buffer; if so, the value is that buffer.
*/
       (name))
{
#ifdef I18N3
  /* #### Doc string should indicate that the buffer name will get
     translated. */
#endif

  /* #### This might return a dead buffer.  This is gross.  This is
     called FSF compatibility. */
  if (BUFFERP (name))
    return name;
  return (get_buffer (name, 0));
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
  /* This function can GC */
  REGISTER Lisp_Object tail, buf, tem;
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
	  fn = Fexpand_file_name (Ffile_name_nondirectory (filename),
				  dn);
	}
      filename = fn;
      NUNGCPRO;
    }

  for (tail = Vbuffer_alist; CONSP (tail); tail = XCDR (tail))
    {
      buf = Fcdr (XCAR (tail));
      if (!BUFFERP (buf)) continue;
      if (!STRINGP (XBUFFER (buf)->filename)) continue;
      tem = Fstring_equal (filename,
			   (find_file_compare_truenames
			    ? XBUFFER (buf)->file_truename
			    : XBUFFER (buf)->filename));
      if (!NILP (tem))
	return buf;
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
    return; /* abort() ? */
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
  /* FSFmacs has its own code here and doesn't call get-file-buffer.
     That's because their equivalent of find-file-compare-truenames
     (find-file-existing-other-name) isn't looked at in get-file-buffer.
     This way is more correct. */
  int count = specpdl_depth ();

  specbind (Qfind_file_compare_truenames, Qt);
  return unbind_to (count, Fget_file_buffer (filename));
}

static struct buffer *
allocate_buffer (void)
{
  struct buffer *b = alloc_lcrecord (sizeof (struct buffer), lrecord_buffer);

  copy_lcrecord (b, XBUFFER (Vbuffer_defaults));

  return b;
}

static Lisp_Object
finish_init_buffer (struct buffer *b, Lisp_Object name)
{
  Lisp_Object buf;

  XSETBUFFER (buf, b);

  name = Fcopy_sequence (name);
  /* #### This really does not need to be called.  We already
     initialized the buffer-local variables in allocate_buffer().
     local_var_alist is set to Qnil at the same point, in
     nuke_all_buffer_slots(). */
  reset_buffer_local_variables (b, 1);
  b->directory = ((current_buffer) ? current_buffer->directory : Qnil);

  b->last_window_start = 1;

  b->name = name;
  if (string_byte (XSTRING (name), 0) != ' ')
    b->undo_list = Qnil;
  else
    b->undo_list = Qt;

  /* initialize the extent list */
  init_buffer_extents (b);

  /* Put this in the alist of all live buffers.  */
  push_buffer_alist (name, buf);

  init_buffer_markers (b);

  b->generated_modeline_string = Fmake_string (make_int (84), make_int (' '));
  b->modeline_extent_table = make_lisp_hashtable (20, HASHTABLE_KEY_WEAK,
						  HASHTABLE_EQ);

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
    error ("Empty string for buffer name is not allowed");

  b = allocate_buffer ();

  b->text = &b->own_text;
  b->base_buffer = 0;
  b->indirect_children = Qnil;
  init_buffer_text (b, 0);

  return finish_init_buffer (b, name);
}

DEFUN ("make-indirect-buffer", Fmake_indirect_buffer, 2, 2,
       "bMake indirect buffer (to buffer): \nBName of indirect buffer: ", /*
Create and return an indirect buffer for buffer BASE, named NAME.
BASE should be an existing buffer (or buffer name).
NAME should be a string which is not the name of an existing buffer.
If BASE is an indirect buffer itself, the base buffer for that buffer
 is made the base buffer for the newly created buffer. (Thus, there will
 never be indirect buffers whose base buffers are themselves indirect.)
*/
       (base_buffer, name))
{
  error ("make-indirect-buffer not yet implemented, oops");
  return Qnil;

#if 0 /* #### implement this!  Need various changes in insdel.c */
  Lisp_Object buf;
  REGISTER struct buffer *b;

  name = LISP_GETTEXT (name);
  buf = Fget_buffer (name);
  if (!NILP (buf))
    error ("Buffer name `%s' is in use", XSTRING_DATA (name));

  base_buffer = Fget_buffer (base_buffer);
  if (NILP (base_buffer))
    error ("No such buffer: `%s'", XSTRING_DATA (XBUFFER (base_buffer)->name));

  if (XSTRING_LENGTH (name) == 0)
    error ("Empty string for buffer name is not allowed");

  b = allocate_buffer ();

  if (XBUFFER (base_buffer)->base_buffer)
    b->base_buffer = XBUFFER (base_buffer)->base_buffer;
  else
    b->base_buffer = XBUFFER (base_buffer);

  /* Use the base buffer's text object.  */
  b->text = b->base_buffer->text;
  b->indirect_children = Qnil;
  XSETBUFFER (buf, b);
  b->base_buffer->indirect_children =
    Fcons (buf, b->base_buffer->indirect_children);
  init_buffer_text (b, 1);

  return finish_init_buffer (b, name);
#endif /* 0 */
}


static void
reset_buffer_local_variables (struct buffer *b, int first_time)
{
  struct buffer *def = XBUFFER (Vbuffer_defaults);

  b->local_var_flags = 0;
  /* For each slot that has a default value,
     copy that into the slot.  */
#define MARKED_SLOT(slot)						\
  { int mask = XINT (buffer_local_flags.slot);				\
    if ((mask > 0 || mask == -1 || mask == -3)				\
	&& (first_time							\
	    || NILP (Fget (XBUFFER (Vbuffer_local_symbols)->slot,	\
			   Qpermanent_local, Qnil))))			\
      b->slot = def->slot;						\
  }
#include "bufslots.h"
#undef MARKED_SLOT
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
  char number[10];

  CHECK_STRING (name);

  name = LISP_GETTEXT (name);
#ifdef I18N3
  /* #### Doc string should indicate that the buffer name will get
     translated. */
#endif

  tem = Fget_buffer (name);
  if (NILP (tem))
    return (name);

  count = 1;
  while (1)
    {
      sprintf (number, "<%d>", ++count);
      gentemp = concat2 (name, build_string (number));
      if (!NILP (ignore))
        {
          tem = Fstring_equal (gentemp, ignore);
          if (!NILP (tem))
            return gentemp;
        }
      tem = Fget_buffer (gentemp);
      if (NILP (tem))
	return (gentemp);
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
  struct buffer *base = buf->base_buffer;
  Lisp_Object base_buffer = Qnil;

  if (! base)
    return Qnil;
  XSETBUFFER (base_buffer, base);
  return base_buffer;
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

/* Map MAPFUN over all buffers that share the same text as BUF
   (this includes BUF).  Pass two arguments to MAPFUN: a buffer,
   and CLOSURE.  If any invocation of MAPFUN returns non-zero,
   halt immediately and return that value.  Otherwise, continue
   the mapping to the end and return 0. */

int
map_over_sharing_buffers (struct buffer *buf,
			  int (*mapfun) (struct buffer *buf, void *closure),
			  void *closure)
{
  int result;
  Lisp_Object tail;

  if (buf->base_buffer)
    {
      buf = buf->base_buffer;
      assert (!buf->base_buffer);
    }

  result = (mapfun) (buf, closure);
  if (result)
    return result;

  LIST_LOOP (tail, buf->indirect_children)
    {
      Lisp_Object buffer = XCAR (tail);
      result = (mapfun) (XBUFFER (buffer), closure);
      if (result)
	return result;
    }

  return 0;
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
    { int mask = XINT (buffer_local_flags.slot);		\
      if (mask == 0 || mask == -1				\
	  || ((mask > 0) && (buf->local_var_flags & mask)))	\
        result = Fcons (Fcons (syms->slot, buf->slot), result);	\
    }
#include "bufslots.h"
#undef MARKED_SLOT
  }
  return (result);
}

DEFUN ("buffer-dedicated-frame", Fbuffer_dedicated_frame, 0, 1, 0, /*
Return the frame dedicated to this BUFFER, or nil if there is none.
No argument or nil as argument means use current buffer as BUFFER.
*/
       (buffer))
{
  struct buffer *buf = decode_buffer (buffer, 0);

  /* XEmacs addition: if the frame is dead, silently make it go away. */
  if (!NILP (buf->dedicated_frame) &&
      !FRAME_LIVE_P (XFRAME (buf->dedicated_frame)))
    buf->dedicated_frame = Qnil;
    
  return buf->dedicated_frame;
}

DEFUN ("set-buffer-dedicated-frame", Fset_buffer_dedicated_frame, 2, 2, 0, /*
For this BUFFER, set the FRAME dedicated to it.
FRAME must be a frame or nil.
*/
       (buffer, frame))
{
  struct buffer *buf = decode_buffer (buffer, 0);

  if (!NILP (frame))
    CHECK_LIVE_FRAME (frame); /* XEmacs change */

  return buf->dedicated_frame = frame;
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
  Lisp_Object fn;
  struct buffer *buf = decode_buffer (buffer, 0);

#ifdef ENERGIZE
  Lisp_Object starting_flag = 
    (BUF_SAVE_MODIFF (buf) < BUF_MODIFF (buf)) ? Qt : Qnil;
  Lisp_Object argument_flag = (NILP (flag)) ? Qnil : Qt;
#endif  

#ifdef CLASH_DETECTION
  /* If buffer becoming modified, lock the file.
     If buffer becoming unmodified, unlock the file.  */

  fn = buf->file_truename;
  if (!NILP (fn))
    {
      int already = BUF_SAVE_MODIFF (buf) < BUF_MODIFF (buf);
      if (already == NILP (flag))
	{
	  int count = specpdl_depth ();
	  /* lock_file() and unlock_file() currently use current_buffer */
	  record_unwind_protect (Fset_buffer, Fcurrent_buffer ());
	  set_buffer_internal (buf);
	  if (!already && !NILP (flag))
	    lock_file (fn);
	  else if (already && NILP (flag))
	    unlock_file (fn);
	  unbind_to (count, Qnil);
	}
    }
#endif                          /* CLASH_DETECTION */

  /* This is often called when the buffer contents are altered but we
     don't want to treat the changes that way (e.g. selective
     display).  We still need to make sure redisplay realizes that the
     contents have potentially altered and it needs to do some
     work. */
  BUF_MODIFF (buf)++;
  BUF_SAVE_MODIFF (buf) = NILP (flag) ? BUF_MODIFF (buf) : 0;
  MARK_MODELINE_CHANGED;

#ifdef ENERGIZE
  /* don't send any notification if we are "setting" the modification bit
     to be the same as it already was */
  if (!EQ (starting_flag, argument_flag))
    {
      extern Lisp_Object Qenergize_buffer_modified_hook;
      int count = specpdl_depth ();
      record_unwind_protect (Fset_buffer, Fcurrent_buffer ());
      set_buffer_internal (buf);
      va_run_hook_with_args (Qenergize_buffer_modified_hook, 3,
			     flag, make_int (BUF_BEG (buf)),
			     make_int (BUF_Z (buf)));
      unbind_to (count, Qnil);
    }
#endif /* ENERGIZE */

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

  return make_int (BUF_MODIFF (buf));
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
    error ("Empty string is invalid as a buffer name");

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
	error ("Buffer name \"%s\" is in use",
	       XSTRING_DATA (newname));
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

      XSETFRAME (frame, f);
      alist = f->buffer_alist;
    }

  for (tail = alist; !NILP (tail); tail = Fcdr (tail))
    {
      buf = Fcdr (Fcar (tail));
      if (EQ (buf, buffer))
	continue;
      if (string_byte (XSTRING (XBUFFER (buf)->name), 0) == ' ')
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

/* XEmacs change: Make this argument required because this is a dangerous
   function. */
DEFUN ("buffer-disable-undo", Fbuffer_disable_undo, 1, 1, "", /*
Make BUFFER stop keeping undo information.
Any undo records it already has are discarded.
*/
       (buffer))
{
  /* Allowing nil is an RMSism */
  struct buffer *real_buf = decode_buffer (buffer, 1);
  real_buf->undo_list = Qt;
  return Qnil;
}

DEFUN ("buffer-enable-undo", Fbuffer_enable_undo, 0, 1, "", /*
Start keeping undo information for buffer BUFFER.
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
Kill the buffer BUFNAME.
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
       (bufname))
{
  /* This function can GC */
  Lisp_Object buf;
  REGISTER struct buffer *b;
  struct gcpro gcpro1, gcpro2;

  if (NILP (bufname))
    buf = Fcurrent_buffer ();
  else if (BUFFERP (bufname))
    buf = bufname;
  else
    {
      buf = get_buffer (bufname, 0);
      if (NILP (buf)) nsberror (bufname);
    }

  b = XBUFFER (buf);

  /* OK to delete an already-deleted buffer.  */
  if (!BUFFER_LIVE_P (b))
    return Qnil;

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
      GCPRO2 (buf, bufname);
      killp = call1
	(Qyes_or_no_p,
	 (emacs_doprnt_string_c
	  ((CONST Bufbyte *) GETTEXT ("Buffer %s modified; kill anyway? "),
	   Qnil, -1, XSTRING_DATA (b->name))));
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
      Lisp_Object tail = Qnil;

      GCPRO2 (buf, tail);
      record_unwind_protect (save_excursion_restore, save_excursion_save ());
      Fset_buffer (buf);

      /* First run the query functions; if any query is answered no,
         don't kill the buffer.  */
      for (tail = Vkill_buffer_query_functions;
           !NILP (tail);
           tail = Fcdr (tail))
	{
	  if (NILP (call0 (Fcar (tail))))
	    {
	      UNGCPRO;
	      return unbind_to (speccount, Qnil);
	    }
	}

      /* Then run the hooks.  */
      run_hook (Qkill_buffer_hook);
#ifdef HAVE_X_WINDOWS
      /* If an X selection was in this buffer, disown it.
	 We could have done this by simply adding this function to the
	 kill-buffer-hook, but the user might mess that up.
	 */
      if (EQ (Vwindow_system, Qx))
	call0 (intern ("xselect-kill-buffer-hook"));
      /* #### generalize me! */
#endif
      unbind_to (speccount, Qnil);
      UNGCPRO;
      b = XBUFFER (buf);        /* Hypothetical relocating GC. */
  }

  /* We have no more questions to ask.  Verify that it is valid
     to kill the buffer.  This must be done after the questions
     since anything can happen within yes-or-no-p.  */

  /* Don't kill the minibuffer now current.  */
  if (EQ (buf, XWINDOW (minibuf_window)->buffer))
    return Qnil;

  /* Might have been deleted during the last question above */
  if (!BUFFER_LIVE_P (b))
    return Qnil;

  /* When we kill a base buffer, kill all its indirect buffers.
     We do it at this stage so nothing terrible happens if they
     ask questions or their hooks get errors.  */
  if (! b->base_buffer)
    {
      Lisp_Object rest;

      GCPRO1 (buf);

      LIST_LOOP (rest, b->indirect_children)
	Fkill_buffer (XCAR (rest));

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
  /* Unlock this buffer's file, if it is locked.  */
  unlock_buffer (b);
#endif /* CLASH_DETECTION */

  {
    int speccount = specpdl_depth ();
    specbind (Qinhibit_quit, Qt);

    kill_buffer_processes (buf);

    /* #### This is a problem if this buffer is in a dedicated window.
       Need to undedicate any windows of this buffer first (and delete them?)
       */
    Freplace_buffer_in_windows (buf);

    delete_from_buffer_alist (buf);

    font_lock_buffer_was_killed (b);

    /* Delete any auto-save file, if we saved it in this session.  */
    if (STRINGP (b->auto_save_file_name)
	&& b->auto_save_modified != 0
	&& BUF_SAVE_MODIFF (b) < b->auto_save_modified)
      {
	if (!NILP (Vdelete_auto_save_files))
	  internal_delete_file (b->auto_save_file_name);
      }

    uninit_buffer_markers (b);

    kill_buffer_local_variables (b);

    b->name = Qnil;
    uninit_buffer_text (b, !!b->base_buffer);
    b->undo_list = Qnil;
    uninit_buffer_extents (b);
    if (b->base_buffer)
      {
#ifdef ERROR_CHECK_BUFPOS
	assert (!NILP (memq_no_quit (buf, b->base_buffer->indirect_children)));
#endif
	b->base_buffer->indirect_children =
	  delq_no_quit (buf, b->base_buffer->indirect_children);
      }

  /* Clear away all Lisp objects, so that they
     won't be protected from GC. */
    nuke_all_buffer_slots (b, Qnil);

    unbind_to (speccount, Qnil);
  }
  return Qt;
}

DEFUN ("record-buffer", Frecord_buffer, 1, 1, 0, /*
Place buffer BUF first in the buffer order.
Call this function when a buffer is selected \"visibly\".

This function changes the global buffer order and the per-frame buffer
order for the selected frame.  The buffer order keeps track of recency
of selection so that `other-buffer' will return a recently selected
buffer.  See `other-buffer' for more information.
*/
       (buf))
{
  REGISTER Lisp_Object lynk, prev;
  struct frame *f = selected_frame ();

  prev = Qnil;
  for (lynk = Vbuffer_alist; CONSP (lynk); lynk = XCDR (lynk))
    {
      if (EQ (XCDR (XCAR (lynk)), buf))
	break;
      prev = lynk;
    }
  /* Effectively do Vbuffer_alist = delq_no_quit (lynk, Vbuffer_alist) */
  if (NILP (prev))
    Vbuffer_alist = XCDR (Vbuffer_alist);
  else
    XCDR (prev) = XCDR (XCDR (prev));
  XCDR (lynk) = Vbuffer_alist;
  Vbuffer_alist = lynk;

  /* That was the global one.  Now do the same thing for the
     per-frame buffer-alist. */
  prev = Qnil;
  for (lynk = f->buffer_alist; CONSP (lynk); lynk = XCDR (lynk))
    {
      if (EQ (XCDR (XCAR (lynk)), buf))
	break;
      prev = lynk;
    }
  /* Effectively do f->buffer_alist = delq_no_quit (lynk, f->buffer_alist) */
  if (NILP (prev))
    f->buffer_alist = XCDR (f->buffer_alist);
  else
    XCDR (prev) = XCDR (XCDR (prev));
  XCDR (lynk) = f->buffer_alist;
  f->buffer_alist = lynk;
  return Qnil;
}

DEFUN ("set-buffer-major-mode", Fset_buffer_major_mode, 1, 1, 0, /*
Set an appropriate major mode for BUFFER, according to `default-major-mode'.
Use this function before selecting the buffer, since it may need to inspect
the current buffer's major mode.
*/
       (buf))
{
  int speccount = specpdl_depth ();
  REGISTER Lisp_Object function, tem;

  function = XBUFFER (Vbuffer_defaults)->major_mode;
  if (NILP (function))
    {
      tem = Fget (current_buffer->major_mode, Qmode_class, Qnil);
      if (NILP (tem))
	function = current_buffer->major_mode;
    }

  if (NILP (function) || EQ (function, Qfundamental_mode))
    return Qnil;

  /* To select a nonfundamental mode,
     select the buffer temporarily and then call the mode function. */

  record_unwind_protect (Fset_buffer, Fcurrent_buffer ());

  Fset_buffer (buf);
  call0 (function);

  return unbind_to (speccount, Qnil);
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
  Lisp_Object buf;
  XSETBUFFER (buf, current_buffer);
  return buf;
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

#ifdef HAVE_FEP
  if (!noninteractive && initialized)
    {
      extern Lisp_Object Ffep_force_on (), Ffep_force_off (), Ffep_get_mode ();

      old_buf->fep_mode = Ffep_get_mode ();
      
      if (!NILP (current_buffer->fep_mode))
	Ffep_force_on ();
      else
	Ffep_force_off ();
  }
#endif

  if (old_buf)
    {
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
Make the buffer BUFNAME current for editing operations.
BUFNAME may be a buffer or the name of an existing buffer.
See also `save-excursion' when you want to make a buffer current temporarily.
This function does not display the buffer, so its effect ends
when the current command terminates.
Use `switch-to-buffer' or `pop-to-buffer' to switch buffers permanently.
*/
       (bufname))
{
  Lisp_Object buffer;
  buffer = get_buffer (bufname, 0);
  if (NILP (buffer))
    error ("Selecting deleted or non-existent buffer");
  set_buffer_internal (XBUFFER (buffer));
  return buffer;
}


DEFUN ("barf-if-buffer-read-only", Fbarf_if_buffer_read_only, 0, 3, 0, /*
Signal a `buffer-read-only' error if the buffer is read-only.
Optional argument BUFFER defaults to the current buffer.

If optional argument START is non-nil, all extents in the buffer
which overlap that part of the buffer are checked to ensure none has a
`read-only' property. (Extents that lie completely within the range,
however, are not checked.) END defaults to the value of START.

If START and END are equal, the range checked is [START, END] (i.e.
closed on both ends); otherwise, the range checked is (START, END)
(open on both ends), except that extents that lie completely within
[START, END] are not checked.  See `extent-in-region-p' for a fuller
discussion.
*/
       (buffer, start, end))
{
  struct buffer *b = decode_buffer (buffer, 0);
  Bufpos s, e;

  if (NILP (start))
    s = e = -1;
  else
    {
      if (NILP (end))
	end = start;
      get_buffer_range_char (b, start, end, &s, &e, 0);
    }
  barf_if_buffer_read_only (b, s, e);

  return (Qnil);
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
  XSETBUFFER (buffer, buf);

  if (!NILP (before))
    before = get_buffer (before, 1);

  if (EQ (before, buffer))
    error ("Cannot place a buffer before itself");

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
  b->save_length = Qzero;

  zmacs_region_stays = 0;
  return Qnil;
}



DEFUN ("kill-all-local-variables", Fkill_all_local_variables, 0, 0, 0, /*
Switch to Fundamental mode by killing current buffer's local variables.
Most local variable bindings are eliminated so that the default values
become effective once more.  Also, the syntax table is set from
`standard-syntax-table', local keymap is set to nil,
the abbrev table is set from `fundamental-mode-abbrev-table',
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

#ifdef MEMORY_USAGE_STATS

struct buffer_stats
{
  int text;
  int markers;
  int extents;
  int other;
};

static int
compute_buffer_text_usage (struct buffer *b, struct overhead_stats *ovstats)
{
  int malloc_use;
  int was_requested;
  int gap;

  was_requested = b->text->z - 1;
  gap = b->text->gap_size;
  malloc_use = malloced_storage_size (b->text->beg, was_requested + gap, 0);
  ovstats->gap_overhead += gap;
  ovstats->was_requested += was_requested;
  ovstats->malloc_overhead += malloc_use - (was_requested + gap);
  return malloc_use;
}

static void
compute_buffer_usage (struct buffer *b, struct buffer_stats *stats,
		      struct overhead_stats *ovstats)
{
  memset (stats, 0, sizeof (*stats));
  stats->other += malloced_storage_size (b, sizeof (struct buffer), ovstats);
  stats->text += compute_buffer_text_usage (b, ovstats);
  stats->markers += compute_buffer_marker_usage (b, ovstats);
  stats->extents += compute_buffer_extent_usage (b, ovstats);
}

DEFUN ("buffer-memory-usage", Fbuffer_memory_usage, 1, 1, 0, /*
Return stats about the memory usage of buffer BUFFER.
The values returned are in the form an alist of usage types and byte
counts.  The byte counts attempt to encompass all the memory used
by the buffer (separate from the memory logically associated with a
buffer or frame), including internal structures and any malloc()
overhead associated with them.  In practice, the byte counts are
underestimated because certain memory usage is very hard to determine
(e.g. the amount of memory used inside the Xt library or inside the
X server) and because there is other stuff that might logically
be associated with a window, buffer, or frame (e.g. window configurations,
glyphs) but should not obviously be included in the usage counts.

Multiple slices of the total memory usage may be returned, separated
by a nil.  Each slice represents a particular view of the memory, a
particular way of partitioning it into groups.  Within a slice, there
is no overlap between the groups of memory, and each slice collectively
represents all the memory concerned.
*/
       (buffer))
{
  struct buffer_stats stats;
  struct overhead_stats ovstats;

  CHECK_BUFFER (buffer); /* dead buffers should be allowed, no? */
  memset (&ovstats, 0, sizeof (ovstats));
  compute_buffer_usage (XBUFFER (buffer), &stats, &ovstats);

  return nconc2 (list4 (Fcons (Qtext, make_int (stats.text)),
			Fcons (Qmarkers, make_int (stats.markers)),
			Fcons (Qextents, make_int (stats.extents)),
			Fcons (Qother, make_int (stats.other))),
		 list5 (Qnil,
			Fcons (Qactually_requested,
			       make_int (ovstats.was_requested)),
			Fcons (Qmalloc_overhead,
			       make_int (ovstats.malloc_overhead)),
			Fcons (Qgap_overhead,
			       make_int (ovstats.malloc_overhead)),
			Fcons (Qdynarr_overhead,
			       make_int (ovstats.dynarr_overhead))));
}

#endif /* MEMORY_USAGE_STATS */

void
syms_of_buffer (void)
{
  defsymbol (&Qbuffer_live_p, "buffer-live-p");
  defsymbol (&Qbuffer_or_string_p, "buffer-or-string-p");
  defsymbol (&Qmode_class, "mode-class");
  defsymbol (&Qrename_auto_save_file, "rename-auto-save-file");
  defsymbol (&Qkill_buffer_hook, "kill-buffer-hook");
  defsymbol (&Qpermanent_local, "permanent-local");

  defsymbol (&Qfirst_change_hook, "first-change-hook");
  defsymbol (&Qbefore_change_functions, "before-change-functions");
  defsymbol (&Qafter_change_functions, "after-change-functions");

  /* #### Obsolete, for compatibility */
  defsymbol (&Qbefore_change_function, "before-change-function");
  defsymbol (&Qafter_change_function, "after-change-function");

  defsymbol (&Qbuffer_file_name, "buffer-file-name");
  defsymbol (&Qbuffer_undo_list, "buffer-undo-list");
  defsymbol (&Qdefault_directory, "default-directory");

  defsymbol (&Qget_file_buffer, "get-file-buffer");
  defsymbol (&Qchange_major_mode_hook, "change-major-mode-hook");

  defsymbol (&Qfundamental_mode, "fundamental-mode");

  defsymbol (&Qfind_file_compare_truenames, "find-file-compare-truenames");

  defsymbol (&Qswitch_to_buffer, "switch-to-buffer");

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
  DEFSUBR (Fbuffer_dedicated_frame);
  DEFSUBR (Fset_buffer_dedicated_frame);
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
#ifdef MEMORY_USAGE_STATS
  DEFSUBR (Fbuffer_memory_usage);
#endif

  deferror (&Qprotected_field, "protected-field",
	    "Attempt to modify a protected field", Qerror);
}

/* initialize the buffer routines */
void
vars_of_buffer (void)
{
  /* This function can GC */
  staticpro (&QSFundamental);
  staticpro (&QSscratch);
  staticpro (&Vbuffer_alist);

  QSFundamental = Fpurecopy (build_string ("Fundamental"));
  QSscratch = Fpurecopy (build_string (DEFER_GETTEXT ("*scratch*")));

  Vbuffer_alist = Qnil;
  current_buffer = 0;

  DEFVAR_LISP ("change-major-mode-hook", &Vchange_major_mode_hook /*
List of hooks to be run before killing local variables in a buffer.
This should be used by any mode that temporarily alters the contents or
the read-only state of the buffer.  See also `kill-all-local-variables'.
*/ );
  Vchange_major_mode_hook = Qnil;

  DEFVAR_BOOL ("find-file-compare-truenames", &find_file_compare_truenames /*
If this is true, then the find-file command will check the truenames
of all visited files when deciding whether a given file is already in
a buffer, instead of just the buffer-file-name.  This means that if you
attempt to visit another file which is a symbolic-link to a file which is
already in a buffer, the existing buffer will be found instead of a newly-
created one.  This works if any component of the pathname (including a non-
terminal component) is a symbolic link as well, but doesn't work with hard
links (nothing does).

See also the variable find-file-use-truenames.
*/ );
  find_file_compare_truenames = 0;

  DEFVAR_BOOL ("find-file-use-truenames", &find_file_use_truenames /*
If this is true, then a buffer's visited file-name will always be
chased back to the real file; it will never be a symbolic link, and there
will never be a symbolic link anywhere in its directory path.
That is, the buffer-file-name and buffer-file-truename will be equal.
This doesn't work with hard links.

See also the variable find-file-compare-truenames.
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

That's because these variables are temporarily set to nil.\n\
As a result, a hook function cannot straightforwardly alter the value of\n\
these variables.  See the Emacs Lisp manual for a way of\n\
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
#endif

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

  DEFVAR_LISP ("delete-auto-save-files", &Vdelete_auto_save_files /*
*Non-nil means delete auto-save file when a buffer is saved or killed.
*/ );
  Vdelete_auto_save_files = Qt;
}

/* DOC is ignored because it is snagged and recorded externally 
 *  by make-docfile */
/* Renamed from DEFVAR_PER_BUFFER because FSFmacs D_P_B takes
 *  a bogus extra arg, which confuses an otherwise identical make-docfile.c */
/* Declaring this stuff as const produces 'Cannot reinitialize' messages
   from SunPro C's fix-and-continue feature (a way neato feature that
   makes debugging unbelievably more bearable) */
#define DEFVAR_BUFFER_LOCAL(lname, field_name)				\
 do { static CONST_IF_NOT_DEBUG struct symbol_value_forward I_hate_C	\
       = { { { { lrecord_symbol_value_forward },			\
               (void *) &(buffer_local_flags.field_name), 69 },		\
             SYMVAL_CURRENT_BUFFER_FORWARD }, 0 };			\
      defvar_buffer_local ((lname), &I_hate_C);				\
 } while (0)

#define DEFVAR_BUFFER_LOCAL_MAGIC(lname, field_name, magicfun)		\
 do { static CONST_IF_NOT_DEBUG struct symbol_value_forward I_hate_C	\
       = { { { { lrecord_symbol_value_forward },			\
               (void *) &(buffer_local_flags.field_name), 69 },		\
             SYMVAL_CURRENT_BUFFER_FORWARD }, magicfun };		\
      defvar_buffer_local ((lname), &I_hate_C);				\
 } while (0)

#define DEFVAR_CONST_BUFFER_LOCAL(lname, field_name)			\
 do { static CONST_IF_NOT_DEBUG struct symbol_value_forward I_hate_C	\
       = { { { { lrecord_symbol_value_forward },			\
               (void *) &(buffer_local_flags.field_name), 69 },		\
             SYMVAL_CONST_CURRENT_BUFFER_FORWARD }, 0 };		\
      defvar_buffer_local ((lname), &I_hate_C);				\
 } while (0)

#define DEFVAR_CONST_BUFFER_LOCAL_MAGIC(lname, field_name, magicfun)	\
 do { static CONST_IF_NOT_DEBUG struct symbol_value_forward I_hate_C	\
       = { { { { lrecord_symbol_value_forward },			\
               (void *) &(buffer_local_flags.field_name), 69 },		\
             SYMVAL_CONST_CURRENT_BUFFER_FORWARD }, magicfun };		\
      defvar_buffer_local ((lname), &I_hate_C);				\
 } while (0)

static void
defvar_buffer_local (CONST char *namestring, 
                     CONST struct symbol_value_forward *m)
{
  int offset = ((char *)symbol_value_forward_forward (m)
                - (char *)&buffer_local_flags);

  defvar_mumble (namestring, m, sizeof (*m));

  *((Lisp_Object *)(offset + (char *)XBUFFER (Vbuffer_local_symbols))) 
    = intern (namestring);
}

/* DOC is ignored because it is snagged and recorded externally 
 *  by make-docfile */
#define DEFVAR_BUFFER_DEFAULTS(lname, field_name)			\
 do { static CONST_IF_NOT_DEBUG struct symbol_value_forward I_hate_C	\
       = { { { { lrecord_symbol_value_forward },			\
               (void *) &(buffer_local_flags.field_name), 69 },		\
             SYMVAL_DEFAULT_BUFFER_FORWARD }, 0 };			\
      defvar_mumble ((lname), &I_hate_C, sizeof (I_hate_C));		\
 } while (0)

#define DEFVAR_BUFFER_DEFAULTS_MAGIC(lname, field_name, magicfun)	\
 do { static CONST_IF_NOT_DEBUG struct symbol_value_forward I_hate_C	\
       = { { { { lrecord_symbol_value_forward },			\
               (void *) &(buffer_local_flags.field_name), 69 },		\
             SYMVAL_DEFAULT_BUFFER_FORWARD }, magicfun };		\
      defvar_mumble ((lname), &I_hate_C, sizeof (I_hate_C));		\
 } while (0)

static void
nuke_all_buffer_slots (struct buffer *b, Lisp_Object zap)
{
  zero_lcrecord (b);

#define MARKED_SLOT(x)	b->x = (zap);
#include "bufslots.h"
#undef MARKED_SLOT
}

void
complex_vars_of_buffer (void)
{
  /* Make sure all markable slots in buffer_defaults
     are initialized reasonably, so mark_buffer won't choke.
   */
  struct buffer *defs = alloc_lcrecord (sizeof (struct buffer),
					lrecord_buffer);
  struct buffer *syms = alloc_lcrecord (sizeof (struct buffer),
					lrecord_buffer);

  staticpro (&Vbuffer_defaults);
  staticpro (&Vbuffer_local_symbols);
  XSETBUFFER (Vbuffer_defaults, defs);
  XSETBUFFER (Vbuffer_local_symbols, syms);
  
  nuke_all_buffer_slots (syms, Qnil);
  nuke_all_buffer_slots (defs, Qnil);
  defs->text = &defs->own_text;
  syms->text = &syms->own_text;
  
  /* Set up the non-nil default values of various buffer slots.
     Must do these before making the first buffer.
     */
  defs->major_mode = Qfundamental_mode;
  defs->mode_name = QSFundamental;
  defs->abbrev_table = Qnil;    /* real default setup by Lisp code */
  defs->downcase_table = Vascii_downcase_table;
  defs->upcase_table = Vascii_upcase_table;
  defs->case_canon_table = Vascii_canon_table;
  defs->case_eqv_table = Vascii_eqv_table;
  defs->syntax_table = Vstandard_syntax_table;

  defs->modeline_format = build_string ("%-");  /* reset in loaddefs.el */
  defs->case_fold_search = Qt;
  defs->selective_display_ellipses = Qt;
  defs->tab_width = make_int (8);
  defs->ctl_arrow = Qt;
  defs->fill_column = make_int (70);
  defs->left_margin = Qzero;
  defs->save_length = Qzero;       /* lisp code wants int-or-nil */
  defs->modtime = 0;
  defs->auto_save_modified = 0;
  defs->auto_save_failure_time = -1;
  defs->invisibility_spec = Qt;
  
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
    Lisp_Object always_local_no_default = make_int (0);
    Lisp_Object always_local_resettable = make_int (-1);
    Lisp_Object resettable = make_int (-3);
    
    /* Assign the local-flags to the slots that have default values.
       The local flag is a bit that is used in the buffer
       to say that it has its own local value for the slot.
       The local flag bits are in the local_var_flags slot of the
       buffer.  */
    
    nuke_all_buffer_slots (&buffer_local_flags, make_int (-2));
    buffer_local_flags.filename = always_local_no_default;
    buffer_local_flags.directory = always_local_no_default;
    buffer_local_flags.backed_up = always_local_no_default;
    buffer_local_flags.save_length = always_local_no_default;
    buffer_local_flags.auto_save_file_name = always_local_no_default;
    buffer_local_flags.read_only = always_local_no_default;
    
    buffer_local_flags.major_mode = always_local_resettable;
    buffer_local_flags.mode_name = always_local_resettable;
    buffer_local_flags.undo_list = always_local_no_default;
#if 0 /* FSFmacs */
    buffer_local_flags.mark_active = always_local_resettable;
#endif
    buffer_local_flags.point_before_scroll = always_local_resettable;
    buffer_local_flags.file_truename = always_local_no_default;
    buffer_local_flags.invisibility_spec = always_local_resettable;
    buffer_local_flags.file_format = always_local_resettable;
    buffer_local_flags.generated_modeline_string = always_local_no_default;
    
    buffer_local_flags.keymap = resettable;
    buffer_local_flags.downcase_table = resettable;
    buffer_local_flags.upcase_table = resettable;
    buffer_local_flags.case_canon_table = resettable;
    buffer_local_flags.case_eqv_table = resettable;
    buffer_local_flags.syntax_table = resettable;
    
    buffer_local_flags.modeline_format = make_int (1);
    buffer_local_flags.abbrev_mode = make_int (2);
    buffer_local_flags.overwrite_mode = make_int (4);
    buffer_local_flags.case_fold_search = make_int (8);
    buffer_local_flags.auto_fill_function = make_int (0x10);
    buffer_local_flags.selective_display = make_int (0x20);
    buffer_local_flags.selective_display_ellipses = make_int (0x40);
    buffer_local_flags.tab_width = make_int (0x80);
    buffer_local_flags.truncate_lines = make_int (0x100);
    buffer_local_flags.ctl_arrow = make_int (0x200);
    buffer_local_flags.fill_column = make_int (0x400);
    buffer_local_flags.left_margin = make_int (0x800);
    buffer_local_flags.abbrev_table = make_int (0x1000);
#ifdef REGION_CACHE_NEEDS_WORK
    buffer_local_flags.cache_long_line_scans = make_int (0x2000);
#endif
    buffer_local_flags.buffer_file_type = make_int (0x4000);
    
    /* #### Warning, 0x4000000 (that's six zeroes) is the largest number
       currently allowable due to the XINT() handling of this value.
       With some rearrangement you can get 4 more bits. */
  }

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

  DEFVAR_BUFFER_DEFAULTS ("default-buffer-file-type", buffer_file_type /*
Default file type for buffers that do not override it.
This is the same as (default-value 'buffer-file-type).
The file type is nil for text, t for binary.
*/ );

  DEFVAR_BUFFER_LOCAL ("modeline-format", modeline_format /*
Template for displaying modeline for current buffer.
Each buffer has its own value of this variable.
Value may be a string, a symbol or a list or cons cell.
For a symbol, its value is used (but it is ignored if t or nil).
 A string appearing directly as the value of a symbol is processed verbatim
 in that the %-constructs below are not recognized.
For a glyph, it is inserted as is.
For a list whose car is a symbol, the symbol's value is taken,
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
 section.) See `generated-modeline-string' for more information.
For a list whose car is a face, the cdr of the list is processed
 normally but the results will be displayed using the face in the car.
For a list whose car is a keymap, the cdr of the list is processed
 normally but the keymap will apply for mouse clicks over the results,
 in addition to `modeline-map'.  Nested keymap specifications are
 handled properly.
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
  %t -- Under MS-DOS, print T if files is text, B if binary.
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
*Non-nil if searches should ignore case.
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
#endif

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

  DEFVAR_BUFFER_LOCAL ("buffer-file-type", buffer_file_type /*
    "Non-nil if the visited file is a binary file.
This variable is meaningful on MS-DOG and Windows NT.
On those systems, it is automatically local in every buffer.
On other systems, this variable is normally always nil.
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
The real name of the file visited in the current buffer, 
or nil if not visiting a file.  This is the result of passing 
buffer-file-name to the `file-truename' function.  Every buffer has 
its own value of this variable.  This variable is automatically 
maintained by the functions that change the file name associated 
with a buffer.
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

  DEFVAR_BUFFER_LOCAL ("buffer-saved-size", save_length /*
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
*/ );

#if 0 /* FSFmacs */
  /* Adds the following to the doc string for buffer-undo-list:

An entry (nil PROPERTY VALUE BEG . END) indicates that a text property
was modified between BEG and END.  PROPERTY is the property name,
and VALUE is the old value.
*/
#endif

  DEFVAR_BUFFER_LOCAL ("buffer-undo-list", undo_list /*
List of undo entries in current buffer.
Recent changes come first; older changes follow newer.

An entry (BEG . END) represents an insertion which begins at
position BEG and ends at position END.

An entry (TEXT . POSITION) represents the deletion of the string TEXT
from (abs POSITION).  If POSITION is positive, point was at the front
of the text being deleted; if negative, point was at the end.

An entry (t HIGH . LOW) indicates that the buffer previously had
\"unmodified\" status.  HIGH and LOW are the high and low 16-bit portions
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
#endif

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

  DEFVAR_BUFFER_LOCAL_MAGIC ("buffer-invisibility-spec", invisibility_spec /*
Invisibility spec of this buffer.
The default is t, which means that text is invisible
if it has (or is covered by an extent with) a non-nil `invisible' property.
If the value is a list, a text character is invisible if its `invisible'
property is an element in that list.
If an element is a cons cell of the form (PROP . ELLIPSIS),
then characters with property value PROP are invisible,
and they have an ellipsis as well if ELLIPSIS is non-nil.
Note that the actual characters used for the ellipsis are controllable
using `invisible-text-glyph', and default to \"...\".
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
  if ((XINT (buffer_local_flags.slot) != -2 &&			\
         XINT (buffer_local_flags.slot) != -3)			\
      != !(NILP (XBUFFER (Vbuffer_local_symbols)->slot)))	\
  abort ()
#include "bufslots.h"
#undef MARKED_SLOT

  Vprin1_to_string_buffer
    = Fget_buffer_create (Fpurecopy (build_string (" prin1")));
  /* Reset Vbuffer_alist again so that the above buf is magically
     invisible */
  Vbuffer_alist = Qnil;
  /* Want no undo records for prin1_to_string_buffer */
  Fbuffer_disable_undo (Vprin1_to_string_buffer);
  
  {
    Lisp_Object scratch =
      Fset_buffer (Fget_buffer_create (QSscratch));
    /* Want no undo records for *scratch* until after Emacs is dumped */
    Fbuffer_disable_undo (scratch);
  }
}

void
init_buffer (void)
{
  /* This function can GC */
  char buf[MAXPATHLEN+1];
  char *pwd;
  struct stat dotstat, pwdstat;
  int rc;

  buf[0] = 0;

  Fset_buffer (Fget_buffer_create (QSscratch));

  /* If PWD is accurate, use it instead of calling getwd.  This is faster
     when PWD is right, and may avoid a fatal error.  */
  if ((pwd = getenv ("PWD")) != 0 && IS_DIRECTORY_SEP (*pwd)
      && stat (pwd, &pwdstat) == 0
      && stat (".", &dotstat) == 0
      && dotstat.st_ino == pwdstat.st_ino
      && dotstat.st_dev == pwdstat.st_dev
      && (int) strlen (pwd) < MAXPATHLEN)
    strcpy (buf, pwd);
  else if (getwd (buf) == 0)
    fatal ("`getwd' failed: errno %d\n", errno);

#ifndef VMS
  /* Maybe this should really use some standard subroutine
     whose definition is filename syntax dependent.  */
  rc = strlen (buf);
  if (!(IS_DIRECTORY_SEP (buf[rc - 1])))
    {
      buf[rc] = DIRECTORY_SEP;
      buf[rc + 1] = '\0';
    }
#endif /* not VMS */
  current_buffer->directory = build_string (buf);

#if 0 /* FSFmacs */
  /* #### is this correct? */
  temp = get_minibuffer (0);
  XBUFFER (temp)->directory = current_buffer->directory;
#endif
}
