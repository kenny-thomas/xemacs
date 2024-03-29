/* Lisp parsing and input streams.
   Copyright (C) 1985-1989, 1992-1995 Free Software Foundation, Inc.
   Copyright (C) 1995 Tinker Systems.
   Copyright (C) 1996, 2001, 2002, 2003, 2010 Ben Wing.

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

/* This file has been Mule-ized. */

#include <config.h>
#include "lisp.h"

#include "buffer.h"
#include "bytecode.h"
#include "elhash.h"
#include "file-coding.h"
#include "lstream.h"
#include "opaque.h"
#include "profile.h"
#include "charset.h"	/* For Funicode_to_char. */

#include "sysfile.h"
#include "sysfloat.h"
#ifdef WIN32_NATIVE
#include "syswindows.h"
#endif

Lisp_Object Qread_char, Qstandard_input;
Lisp_Object Qvariable_documentation;
#define LISP_BACKQUOTES
#ifdef LISP_BACKQUOTES
/*
   Nonzero means inside a new-style backquote
   with no surrounding parentheses.
   Fread initializes this to zero, so we need not specbind it
   or worry about what happens to it when there is an error.

XEmacs:
   Nested backquotes are perfectly legal and fail utterly with
   this silliness. */
static int new_backquote_flag, old_backquote_flag;
Lisp_Object Qbackquote, Qbacktick, Qcomma, Qcomma_at, Qcomma_dot;
#endif
Lisp_Object Qvariable_domain;	/* I18N3 */
Lisp_Object Vvalues, Vstandard_input, Vafter_load_alist;
Lisp_Object Vload_suppress_alist;
Lisp_Object Qload, Qload_internal, Qfset;

/* Hash-table that maps directory names to hashes of their contents.  */
static Lisp_Object Vlocate_file_hash_table;

Lisp_Object Qexists, Qreadable, Qwritable, Qexecutable;

/* See read_escape() for an explanation of this.  */
#if 0
int fail_on_bucky_bit_character_escapes;
#endif

/* This symbol is also used in fns.c */
#define FEATUREP_SYNTAX

#ifdef FEATUREP_SYNTAX
Lisp_Object Qfeaturep;
#endif

/* non-zero if inside `load' */
int load_in_progress;

/* Whether Fload_internal() should check whether the .el is newer
   when loading .elc */
int load_warn_when_source_newer;
/* Whether Fload_internal() should check whether the .elc doesn't exist */
int load_warn_when_source_only;
/* Whether Fload_internal() should ignore .elc files when no suffix is given */
int load_ignore_elc_files;
/* Whether Fload_internal() should ignore out-of-date .elc files when no
   suffix is given */
int load_ignore_out_of_date_elc_files;
/* Always display messages showing when a file is loaded, regardless of
   whether the flag to `load' tries to suppress them. */
int load_always_display_messages;
/* Show the full path in loading messages. */
int load_show_full_path_in_messages;

/* Search path for files to be loaded. */
Lisp_Object Vload_path;

/* Search path for files when dumping. */
/* Lisp_Object Vdump_load_path; */

/* This is the user-visible association list that maps features to
   lists of defs in their load files. */
Lisp_Object Vload_history;

/* This is used to build the load history.  */
Lisp_Object Vcurrent_load_list;

/* Name of file actually being read by `load'.  */
Lisp_Object Vload_file_name;

/* Same as Vload_file_name but not Lisp-accessible.  This ensures that
   our #$ checks are reliable. */
Lisp_Object Vload_file_name_internal;

/* Function to use for reading, in `load' and friends.  */
Lisp_Object Vload_read_function;

/* The association list of objects read with the #n=object form.
   Each member of the list has the form (n . object), and is used to
   look up the object for the corresponding #n# construct.
   It must be set to nil before all top-level calls to read0.  */
Lisp_Object Vread_objects;

/* Nonzero means load should forcibly load all dynamic doc strings.  */
/* Note that this always happens (with some special behavior) when
   purify_flag is set. */
static int load_force_doc_strings;

/* List of descriptors now open for Fload_internal.  */
static Lisp_Object Vload_descriptor_list;

/* In order to implement "load_force_doc_strings", we keep
   a list of all the compiled-function objects and such
   that we have created in the process of loading this file.
   See the rant below.

   We specbind this just like Vload_file_name, so there's no
   problems with recursive loading. */
static Lisp_Object Vload_force_doc_string_list;

/* A resizing-buffer stream used to temporarily hold data while reading */
static Lisp_Object Vread_buffer_stream;

static int load_byte_code_version;

/* An array describing all known built-in structure types */
static structure_type_dynarr *the_structure_type_dynarr;

#if 0 /* FSF stuff */
/* For use within read-from-string (this reader is non-reentrant!!)  */
static int read_from_string_index;
static int read_from_string_limit;
#endif

#if 0 /* More FSF implementation kludges. */
/* In order to implement load-force-doc-string, FSF saves the
   #@-quoted string when it's seen, and goes back and retrieves
   it later.

   This approach is not only kludgy, but it in general won't work
   correctly because there's no stack of remembered #@-quoted-strings
   and those strings don't generally appear in the file in the same
   order as their #$ references. (Yes, that is amazingly stupid too.

   It would be trivially easy to always encode the #@ string
   [which is a comment, anyway] in the middle of the (#$ . INT) cons
   reference.  That way, it would be really easy to implement
   load-force-doc-string in a non-kludgy way by just retrieving the
   string immediately, because it's delivered on a silver platter.)

   And finally, this stupid approach doesn't work under Mule, or
   under MS-DOS or Windows NT, or under VMS, or any other place
   where you either can't do an ftell() or don't get back a byte
   count.

   Oh, and one more lossage in this approach: If you attempt to
   dump any ELC files that were compiled with `byte-compile-dynamic'
   (as opposed to just `byte-compile-dynamic-docstring'), you
   get hosed.  FMH! (as the illustrious JWZ was prone to utter)

   The approach we use is clean, solves all of these problems, and is
   probably easier to implement anyway.  We just save a list of all
   the containing objects that have (#$ . INT) conses in them (this
   will only be compiled-function objects and lists), and when the
   file is finished loading, we go through and fill in all the
   doc strings at once. --ben */

 /* This contains the last string skipped with #@.  */
static char *saved_doc_string;
/* Length of buffer allocated in saved_doc_string.  */
static int saved_doc_string_size;
/* Length of actual data in saved_doc_string.  */
static int saved_doc_string_length;
/* This is the file position that string came from.  */
static int saved_doc_string_position;
#endif

static int locate_file_open_or_access_file (Ibyte *fn, int access_mode);
EXFUN (Fread_from_string, 3);

/* When errors are signaled, the actual readcharfun should not be used
   as an argument if it is an lstream, so that lstreams don't escape
   to the Lisp level.  */
#define READCHARFUN_MAYBE(x) (LSTREAMP (x)				     \
			      ? (build_msg_string ("internal input stream")) \
			      : (x))


static DECLARE_DOESNT_RETURN (read_syntax_error (const char *));

static DOESNT_RETURN
read_syntax_error (const char *string)
{
  signal_error (Qinvalid_read_syntax, string, Qunbound);
}

static Lisp_Object
continuable_read_syntax_error (const char *string)
{
  return signal_continuable_error (Qinvalid_read_syntax, string, Qunbound);
}


/* Handle unreading and rereading of characters. */
static Ichar
readchar (Lisp_Object readcharfun)
{
  /* This function can GC */

  if (BUFFERP (readcharfun))
    {
      Ichar c;
      struct buffer *b = XBUFFER (readcharfun);

      if (!BUFFER_LIVE_P (b))
        invalid_operation ("Reading from killed buffer", Qunbound);

      if (BUF_PT (b) >= BUF_ZV (b))
        return -1;
      c = BUF_FETCH_CHAR (b, BUF_PT (b));
      BUF_SET_PT (b, BUF_PT (b) + 1);

      return c;
    }
  else if (LSTREAMP (readcharfun))
    {
      Ichar c = Lstream_get_ichar (XLSTREAM (readcharfun));
#ifdef DEBUG_XEMACS /* testing Mule */
      static int testing_mule = 0; /* Change via debugger */
      if (testing_mule)
	{
	  if (c >= 0x20 && c <= 0x7E) stderr_out ("%c", c);
	  else if (c == '\n')         stderr_out ("\\n\n");
	  else                        stderr_out ("\\%o ", c);
	}
#endif /* testing Mule */
      return c;
    }
  else if (MARKERP (readcharfun))
    {
      Ichar c;
      Charbpos mpos = marker_position (readcharfun);
      struct buffer *inbuffer = XMARKER (readcharfun)->buffer;

      if (mpos >= BUF_ZV (inbuffer))
	return -1;
      c = BUF_FETCH_CHAR (inbuffer, mpos);
      set_marker_position (readcharfun, mpos + 1);
      return c;
    }
  else
    {
      Lisp_Object tem = call0 (readcharfun);

      if (!CHAR_OR_CHAR_INTP (tem))
	return -1;
      return XCHAR_OR_CHAR_INT (tem);
    }
}

/* Unread the character C in the way appropriate for the stream READCHARFUN.
   If the stream is a user function, call it with the char as argument.  */

static void
unreadchar (Lisp_Object readcharfun, Ichar c)
{
  if (c == -1)
    /* Don't back up the pointer if we're unreading the end-of-input mark,
       since readchar didn't advance it when we read it.  */
    ;
  else if (BUFFERP (readcharfun))
    BUF_SET_PT (XBUFFER (readcharfun), BUF_PT (XBUFFER (readcharfun)) - 1);
  else if (LSTREAMP (readcharfun))
    {
      Lstream_unget_ichar (XLSTREAM (readcharfun), c);
#ifdef DEBUG_XEMACS /* testing Mule */
      {
        static int testing_mule = 0; /* Set this using debugger */
        if (testing_mule)
          fprintf (stderr,
                   (c >= 0x20 && c <= 0x7E) ? "UU%c" :
                   ((c == '\n') ? "UU\\n%c" : "UU\\%o"), c);
      }
#endif
    }
  else if (MARKERP (readcharfun))
    set_marker_position (readcharfun, marker_position (readcharfun) - 1);
  else
    call1 (readcharfun, make_char (c));
}

static Lisp_Object read0 (Lisp_Object readcharfun);
static Lisp_Object read1 (Lisp_Object readcharfun);
static Lisp_Object read_list (Lisp_Object readcharfun,
                              Ichar terminator,
                              int allow_dotted_lists,
			      int check_for_doc_references);

static void readevalloop (Lisp_Object readcharfun,
                          Lisp_Object sourcefile,
                          Lisp_Object (*evalfun) (Lisp_Object),
                          int printflag);

static Lisp_Object
load_unwind (Lisp_Object stream)  /* used as unwind-protect function in load */
{
  Lstream_close (XLSTREAM (stream));
  return Qnil;
}

/* Check if NONRELOC/RELOC (an absolute filename) is suppressed according
   to load-suppress-alist. */
static int
check_if_suppressed (Ibyte *nonreloc, Lisp_Object reloc)
{
  Bytecount len;

  if (!NILP (reloc))
    {
      nonreloc = XSTRING_DATA (reloc);
      len = XSTRING_LENGTH (reloc);
    }
  else
    len = qxestrlen (nonreloc);

  if (len >= 4 && !qxestrcmp_ascii (nonreloc + len - 4, ".elc"))
    len -= 4;
  else if (len >= 3 && !qxestrcmp_ascii (nonreloc + len - 3, ".el"))
    len -= 3;

  {
    EXTERNAL_LIST_LOOP_2 (cons, Vload_suppress_alist)
      {
	if (CONSP (cons) && STRINGP (XCAR (cons)))
	  {
	    Lisp_Object name = XCAR (cons);
	    if (XSTRING_LENGTH (name) == len &&
		!memcmp (XSTRING_DATA (name), nonreloc, len))
	      {
		struct gcpro gcpro1;
		Lisp_Object val;

		GCPRO1 (reloc);
		val = IGNORE_MULTIPLE_VALUES (Feval (XCDR (cons)));
		UNGCPRO;

		if (!NILP (val))
		  return 1;
	      }
	  }
      }
  }

  return 0;
}

/* The plague is coming.

   Ring around the rosy, pocket full of posy,
   Ashes ashes, they all fall down.
   */
void
ebolify_bytecode_constants (Lisp_Object vector)
{
  int len = XVECTOR_LENGTH (vector);
  int i;

  for (i = 0; i < len; i++)
    {
      Lisp_Object el = XVECTOR_DATA (vector)[i];

      /* We don't check for `eq', `equal', and the others that have
	 bytecode opcodes.  This might lose if someone passes #'eq or
	 something to `funcall', but who would really do that?  As
	 they say in law, we've made a "good-faith effort" to
	 unfuckify ourselves.  And doing it this way avoids screwing
	 up args to `make-hash-table' and such.  As it is, we have to
	 add an extra Ebola check in decode_weak_list_type(). --ben */
      if      (EQ (el, Qassoc))  el = Qold_assoc;
      else if (EQ (el, Qdelq))   el = Qold_delq;
#if 0
      /* I think this is a bad idea because it will probably mess
	 with keymap code. */
      else if (EQ (el, Qdelete)) el = Qold_delete;
#endif
      else if (EQ (el, Qrassq))  el = Qold_rassq;
      else if (EQ (el, Qrassoc)) el = Qold_rassoc;

      XVECTOR_DATA (vector)[i] = el;
    }
}

static Lisp_Object
pas_de_holgazan_ici (int fd, Lisp_Object victim)
{
  Lisp_Object tem;
  EMACS_INT pos;

  if (!FIXNUMP (XCDR (victim)))
    invalid_byte_code ("Bogus doc string reference", victim);
  pos = XFIXNUM (XCDR (victim));
  if (pos < 0)
    pos = -pos; /* kludge to mark a user variable */
  tem = unparesseuxify_doc_string (fd, pos, 0, Vload_file_name_internal, 0);
  if (!STRINGP (tem))
    signal_error_1 (Qinvalid_byte_code, tem);
  return tem;
}

static Lisp_Object
load_force_doc_string_unwind (Lisp_Object oldlist)
{
  struct gcpro gcpro1;
  Lisp_Object list = Vload_force_doc_string_list;
  Lisp_Object tail;
  int fd = XFIXNUM (XCAR (Vload_descriptor_list));

  GCPRO1 (list);
  /* restore the old value first just in case an error occurs. */
  Vload_force_doc_string_list = oldlist;

  LIST_LOOP (tail, list)
    {
      Lisp_Object john = Fcar (tail);
      if (CONSP (john))
	{
	  assert (CONSP (XCAR (john)));
	  assert (!purify_flag); /* should have been handled in read_list() */
	  XCAR (john) = pas_de_holgazan_ici (fd, XCAR (john));
	}
      else
	{
	  Lisp_Object doc;

	  assert (COMPILED_FUNCTIONP (john));
	  if (CONSP (XCOMPILED_FUNCTION (john)->instructions))
	    {
	      struct gcpro ngcpro1;
	      Lisp_Object juan = (pas_de_holgazan_ici
				  (fd,
				   XCOMPILED_FUNCTION (john)->instructions));
	      Lisp_Object ivan;

	      NGCPRO1 (juan);
	      ivan = Fread (juan);
	      if (!CONSP (ivan))
		invalid_byte_code ("invalid lazy-loaded byte code", ivan);
	      XCOMPILED_FUNCTION (john)->instructions = XCAR (ivan);
	      /* v18 or v19 bytecode file.  Need to Ebolify. */
	      if (XCOMPILED_FUNCTION (john)->flags.ebolified
		  && VECTORP (XCDR (ivan)))
		ebolify_bytecode_constants (XCDR (ivan));
	      XCOMPILED_FUNCTION (john)->constants = XCDR (ivan);
	      NUNGCPRO;
	    }
	  doc = compiled_function_documentation (XCOMPILED_FUNCTION (john));
	  if (CONSP (doc))
	    {
	      assert (!purify_flag); /* should have been handled in
					read_compiled_function() */
	      doc = pas_de_holgazan_ici (fd, doc);
	      set_compiled_function_documentation (XCOMPILED_FUNCTION (john),
						   doc);
	    }
	}
    }

  if (!NILP (list))
    free_list (list);

  UNGCPRO;
  return Qnil;
}

/* Close all descriptors in use for Fload_internal.
   This is used when starting a subprocess.  */

void
close_load_descs (void)
{
  Lisp_Object tail;
  LIST_LOOP (tail, Vload_descriptor_list)
    retry_close (XFIXNUM (XCAR (tail)));
}

#ifdef I18N3
Lisp_Object Vfile_domain;
#endif /* I18N3 */

DEFUN ("load-internal", Fload_internal, 1, 6, 0, /*
Execute a file of Lisp code named FILE; no coding-system frobbing.
This function is identical to `load' except for the handling of the
CODESYS and USED-CODESYS arguments under XEmacs/Mule. (When Mule
support is not present, both functions are identical and ignore the
CODESYS and USED-CODESYS arguments.)

If support for Mule exists in this Emacs, the file is decoded
according to CODESYS; if omitted, no conversion happens.  If
USED-CODESYS is non-nil, it should be a symbol, and the actual coding
system that was used for the decoding is stored into it.  It will in
general be different from CODESYS if CODESYS specifies automatic
encoding detection or end-of-line detection.
*/
       (file, noerror, nomessage, nosuffix, codesys, used_codesys))
{
  /* This function can GC */
  int fd = -1;
  int speccount = specpdl_depth ();
  int source_only = 0;
  /* NEWER is a filename without directory, used in loading messages when
     load-ignore-elc-files is non-nil. */
  Lisp_Object newer   = Qnil;
  Lisp_Object found   = Qnil;
  Lisp_Object retval;
  struct gcpro gcpro1, gcpro2, gcpro3;
  int reading_elc = 0;
  int from_require = EQ (nomessage, Qrequire);
  int message_p = NILP (nomessage) || load_always_display_messages;
  Ibyte *spaces = alloca_ibytes (load_in_progress * 2 + 10);
  int i;
  PROFILE_DECLARE ();

  CHECK_STRING (file);
  CHECK_SYMBOL (used_codesys); /* Either nil or another symbol to write to. */

  GCPRO3 (file, newer, found);

  PROFILE_RECORD_ENTERING_SECTION (Qload_internal);

  if (noninteractive)
    {
      for (i = 0; i < load_in_progress * 2; i++)
	spaces[i] = ' ';
      spaces[i] = '\0';
    }
  else
    spaces[0] = '\0';

  /* Avoid weird lossage with null string as arg,
     since it would try to load a directory as a Lisp file.
     Unix truly sucks. */
  if (XSTRING_LENGTH (file) == 0)
    {
      if (NILP (noerror))
        signal_error (Qfile_error, "Cannot open load file", file);
      else
        {
          retval = Qnil;
          goto done;
        }
    }
  else
    {
      Ibyte *foundstr;
      int foundlen;

      fd = locate_file (Vload_path, file,
                        ((!NILP (nosuffix)) ? Qnil :
			 build_ascstring (load_ignore_elc_files ? ".el:" :
				       ".elc:.el:")),
                        &found,
                        -1);

      if (fd < 0)
	{
	  if (NILP (noerror))
	    signal_error (Qfile_error, "Cannot open load file", file);
	  else
	    {
	      retval = Qnil;
	      goto done;
	    }
	}

      foundstr = alloca_ibytes (XSTRING_LENGTH (found) + 1);
      qxestrcpy (foundstr, XSTRING_DATA (found));
      foundlen = qxestrlen (foundstr);

      /* The omniscient JWZ thinks this is worthless, but I beg to
	 differ. --ben */
      if (load_ignore_elc_files)
	newer = Ffile_name_nondirectory (found);
      else if (load_warn_when_source_only &&
	       /* `found' ends in ".el" */
	       !memcmp (".el", foundstr + foundlen - 3, 3) &&
	       /* `file' does not end in ".el" */
	       memcmp (".el",
		       XSTRING_DATA (file) + XSTRING_LENGTH (file) - 3,
		       3))
	source_only = 1;

      if (!memcmp (".elc", foundstr + foundlen - 4, 4))
	reading_elc = 1;
    }

#define PRINT_LOADING_MESSAGE_1(loading, done)				\
 do {									\
  if (load_ignore_elc_files)						\
    {									\
      if (message_p)							\
	message (loading done, spaces,					\
		 XSTRING_DATA (load_show_full_path_in_messages ?	\
			       found : newer));				\
    }									\
  else if (source_only)							\
    message (loading done " (file %s.elc does not exist)", spaces,	\
	     XSTRING_DATA (load_show_full_path_in_messages ?		\
			   found : file),				\
	     XSTRING_DATA (Ffile_name_nondirectory (file)));		\
  else if (message_p)							\
    message (loading done, spaces,					\
	     XSTRING_DATA (load_show_full_path_in_messages ?		\
			   found : file));				\
  } while (0)

#define PRINT_LOADING_MESSAGE(done)				\
do {								\
  if (from_require)						\
    PRINT_LOADING_MESSAGE_1 ("%sRequiring %s...", done);	\
  else								\
    PRINT_LOADING_MESSAGE_1 ("%sLoading %s...", done);		\
} while (0)

  PRINT_LOADING_MESSAGE ("");

  LISP_READONLY (found) = 1;

  {
    /* Lisp_Object's must be malloc'ed, not stack-allocated */
    Lisp_Object lispstream = Qnil;
    const int block_size = 8192;
    struct gcpro ngcpro1;

    NGCPRO1 (lispstream);
    lispstream = make_filedesc_input_stream (fd, 0, -1, LSTR_CLOSING, NULL);
    /* 64K is used for normal files; 8K should be OK here because Lisp
       files aren't really all that big. */
    Lstream_set_buffering (XLSTREAM (lispstream), LSTREAM_BLOCKN_BUFFERED,
			   block_size);
    lispstream = make_coding_input_stream
      (XLSTREAM (lispstream), get_coding_system_for_text_file (codesys, 1),
       CODING_DECODE, 0);
    Lstream_set_buffering (XLSTREAM (lispstream), LSTREAM_BLOCKN_BUFFERED,
			   block_size);
    /* NOTE: Order of these is very important.  Don't rearrange them. */
    internal_bind_int (&load_in_progress, 1 + load_in_progress);
    record_unwind_protect (load_unwind, lispstream);
    internal_bind_lisp_object (&Vload_descriptor_list,
			       Fcons (make_fixnum (fd), Vload_descriptor_list));
    internal_bind_lisp_object (&Vload_file_name_internal, found);
    /* this is not a simple internal_bind. */
    record_unwind_protect (load_force_doc_string_unwind,
			   Vload_force_doc_string_list);
    Vload_force_doc_string_list = Qnil;
    /* load-file-name is not read-only to Lisp. */
    internal_bind_lisp_object (&Vload_file_name, Fcopy_sequence(found));
#ifdef I18N3
    /* set it to nil; a call to #'domain will set it. */
    internal_bind_lisp_object (&Vfile_domain, Qnil);
#endif

    /* Is there a #!? If so, read it, and unread ;!.

       GNU implement this by treating any #! anywhere in the source text as
       commenting out the whole line. */
    {
      char shebangp[2];
      int num_read;

      num_read = Lstream_read (XLSTREAM (lispstream), shebangp,
                               sizeof(shebangp));
      if (sizeof(shebangp) == num_read
	  && 0 == strncmp("#!", shebangp, sizeof(shebangp)))
	{
          shebangp[0] = ';';
	}

      Lstream_unread (XLSTREAM (lispstream), shebangp, num_read);
    }

    /* Now determine what sort of ELC file we're reading in. */
    internal_bind_int (&load_byte_code_version, load_byte_code_version);
    if (reading_elc)
      {
	char elc_header[8];
	int num_read;

	num_read = Lstream_read (XLSTREAM (lispstream), elc_header, 8);
	if (num_read < 8
	    || strncmp (elc_header, ";ELC", 4))
	  {
	    /* Huh?  Probably not a valid ELC file. */
	    load_byte_code_version = 100; /* no Ebolification needed */
	    Lstream_unread (XLSTREAM (lispstream), elc_header, num_read);
	  }
	else
	  load_byte_code_version = elc_header[4];
      }
    else
      load_byte_code_version = 100; /* no Ebolification needed */

    readevalloop (lispstream, file, Feval, 0);
    if (!NILP (used_codesys))
      Fset (used_codesys,
	    XCODING_SYSTEM_NAME
	    (coding_stream_detected_coding_system (XLSTREAM (lispstream))));
    unbind_to (speccount);

    NUNGCPRO;
  }

  {
    Lisp_Object tem;
    /* #### Disgusting kludge */
    /* Run any load-hooks for this file.  */
    /* #### An even more disgusting kludge.  There is horrible code */
    /* that is relying on the fact that dumped lisp files are found */
    /* via `load-path' search. */
    Lisp_Object name = file;

    if (!NILP (Ffile_name_absolute_p (file)))
	name = Ffile_name_nondirectory (file);

    tem = Fassoc (name, Vafter_load_alist);
    if (!NILP (tem))
      {
	struct gcpro ngcpro1;

	NGCPRO1 (tem);
	/* Use eval so that errors give a semi-meaningful backtrace.  --Stig */
	tem = Fcons (Qprogn, Fcdr (tem));
	Feval (tem);
	NUNGCPRO;
      }
  }

  if (!noninteractive)
    PRINT_LOADING_MESSAGE ("done");

  retval = Qt;
done:
  PROFILE_RECORD_EXITING_SECTION (Qload_internal);
  UNGCPRO;
  return retval;
}


/* ------------------------------- */
/*          locate_file            */
/* ------------------------------- */

static int
decode_mode_1 (Lisp_Object mode)
{
  if (EQ (mode, Qexists))
    return F_OK;
  else if (EQ (mode, Qexecutable))
    return X_OK;
  else if (EQ (mode, Qwritable))
    return W_OK;
  else if (EQ (mode, Qreadable))
    return R_OK;
  else if (INTEGERP (mode))
    {
      check_integer_range (mode, Qzero, make_fixnum (7));
      return XFIXNUM (mode);
    }
  else
    invalid_argument ("Invalid value", mode);
  return 0;			/* unreached */
}

static int
decode_mode (Lisp_Object mode)
{
  if (NILP (mode))
    return R_OK;
  else if (CONSP (mode))
    {
      int mask = 0;
      EXTERNAL_LIST_LOOP_2 (elt, mode)
	mask |= decode_mode_1 (elt);
      return mask;
    }
  else
    return decode_mode_1 (mode);
}

DEFUN ("locate-file", Flocate_file, 2, 4, 0, /*
Search for FILENAME through PATH-LIST.

If SUFFIXES is non-nil, it should be a list of suffixes to append to
file name when searching.

If MODE is non-nil, it should be a symbol or a list of symbol representing
requirements.  Allowed symbols are `exists', `executable', `writable', and
`readable'.  If MODE is nil, it defaults to `readable'.

Filenames are checked against `load-suppress-alist' to determine if they
should be ignored.

`locate-file' keeps hash tables of the directories it searches through,
in order to speed things up.  It tries valiantly to not get confused in
the face of a changing and unpredictable environment, but can occasionally
get tripped up.  In this case, you will have to call
`locate-file-clear-hashing' to get it back on track.  See that function
for details.
*/
       (filename, path_list, suffixes, mode))
{
  /* This function can GC */
  Lisp_Object tp;

  CHECK_STRING (filename);

  if (LISTP (suffixes))
    {
      EXTERNAL_LIST_LOOP_2 (elt, suffixes)
	CHECK_STRING (elt);
    }
  else
    CHECK_STRING (suffixes);

  locate_file (path_list, filename, suffixes, &tp, decode_mode (mode));
  return tp;
}

/* Recalculate the hash table for the given string.  DIRECTORY should
   better have been through Fexpand_file_name() by now.  */

static Lisp_Object
locate_file_refresh_hashing (Lisp_Object directory)
{
  Lisp_Object hash = make_directory_hash_table (directory);

  if (!NILP (hash))
    Fputhash (directory, hash, Vlocate_file_hash_table);
  return hash;
}

/* find the hash table for the given directory, recalculating if necessary */

static Lisp_Object
locate_file_find_directory_hash_table (Lisp_Object directory)
{
  Lisp_Object hash = Fgethash (directory, Vlocate_file_hash_table, Qnil);
  if (NILP (hash))
    return locate_file_refresh_hashing (directory);
  else
    return hash;
}

/* The SUFFIXES argument in any of the locate_file* functions can be
   nil, a list, or a string (for backward compatibility), with the
   following semantics:

   a) nil    - no suffix, just search for file name intact
               (semantically different from "empty suffix list", which
               would be meaningless.)
   b) list   - list of suffixes to append to file name.  Each of these
               must be a string.
   c) string - colon-separated suffixes to append to file name (backward
               compatibility).

   All of this got hairy, so I decided to use a mapper.  Calling a
   function for each suffix shouldn't slow things down, since
   locate_file is rarely called with enough suffixes for funcalls to
   make any difference.  */

/* Map FUN over SUFFIXES, as described above.  FUN will be called with a
   char * containing the current file name, and ARG.  Mapping stops when
   FUN returns non-zero. */
static void
locate_file_map_suffixes (Lisp_Object filename, Lisp_Object suffixes,
			  int (*fun) (Ibyte *, void *),
			  void *arg)
{
  /* This function can GC */
  Ibyte *fn;
  int fn_len, max;

  /* Calculate maximum size of any filename made from
     this path element/specified file name and any possible suffix.  */
  if (CONSP (suffixes))
    {
      /* We must traverse the list, so why not do it right. */
      Lisp_Object tail;
      max = 0;
      LIST_LOOP (tail, suffixes)
	{
	  if (XSTRING_LENGTH (XCAR (tail)) > max)
	    max = XSTRING_LENGTH (XCAR (tail));
	}
    }
  else if (NILP (suffixes))
    max = 0;
  else
    /* Just take the easy way out */
    max = XSTRING_LENGTH (suffixes);

  fn_len = XSTRING_LENGTH (filename);
  fn = alloca_ibytes (max + fn_len + 1);
  memcpy (fn, XSTRING_DATA (filename), fn_len);

  /* Loop over suffixes.  */
  if (!STRINGP (suffixes))
    {
      if (NILP (suffixes))
	{
	  /* Case a) discussed in the comment above. */
	  fn[fn_len] = 0;
	  if ((*fun) (fn, arg))
	    return;
	}
      else
	{
	  /* Case b) */
	  Lisp_Object tail;
	  LIST_LOOP (tail, suffixes)
	    {
	      memcpy (fn + fn_len, XSTRING_DATA (XCAR (tail)),
		      XSTRING_LENGTH (XCAR (tail)));
	      fn[fn_len + XSTRING_LENGTH (XCAR (tail))] = 0;
	      if ((*fun) (fn, arg))
		return;
	    }
	}
    }
  else
    {
      /* Case c) */
      const Ibyte *nsuffix = XSTRING_DATA (suffixes);

      while (1)
	{
	  Ibyte *esuffix = qxestrchr (nsuffix, ':');
	  Bytecount lsuffix = esuffix ? esuffix - nsuffix :
	    qxestrlen (nsuffix);

	  /* Concatenate path element/specified name with the suffix.  */
	  qxestrncpy (fn + fn_len, nsuffix, lsuffix);
	  fn[fn_len + lsuffix] = 0;

	  if ((*fun) (fn, arg))
	    return;

	  /* Advance to next suffix.  */
	  if (esuffix == 0)
	    break;
	  nsuffix += lsuffix + 1;
	}
    }
}

struct locate_file_in_directory_mapper_closure
{
  int fd;
  Lisp_Object *storeptr;
  int mode;
};

/* open() or access() a file to be returned by locate_file().  if
   ACCESS_MODE >= 0, do an access() with that mode, else open().  Does
   various magic, e.g. opening the file read-only and binary and setting
   the close-on-exec flag on the file. */

static int
locate_file_open_or_access_file (Ibyte *fn, int access_mode)
{
  int val;

  /* Check that we can access or open it.  */
  if (access_mode >= 0)
    val = qxe_access (fn, access_mode);
  else
    {
      val = qxe_open (fn, O_RDONLY | OPEN_BINARY, 0);

#ifndef WIN32_NATIVE
      if (val >= 0)
	/* If we actually opened the file, set close-on-exec flag
	   on the new descriptor so that subprocesses can't whack
	   at it.  */
	(void) fcntl (val, F_SETFD, FD_CLOEXEC);
#endif
    }

  return val;
}

static int
locate_file_in_directory_mapper (Ibyte *fn, void *arg)
{
  struct locate_file_in_directory_mapper_closure *closure =
    (struct locate_file_in_directory_mapper_closure *) arg;
  struct stat st;

  /* Ignore file if it's a directory.  */
  if (qxe_stat (fn, &st) >= 0
      && (st.st_mode & S_IFMT) != S_IFDIR)
    {
      /* Check that we can access or open it.  */
      closure->fd = locate_file_open_or_access_file (fn, closure->mode);

      if (closure->fd >= 0)
	{
	  if (!check_if_suppressed (fn, Qnil))
	    {
	      /* We succeeded; return this descriptor and filename.  */
	      if (closure->storeptr)
		*closure->storeptr = build_istring (fn);

	      return 1;
	    }
	}
    }
  /* Keep mapping. */
  return 0;
}


/* look for STR in PATH, optionally adding SUFFIXES.  DIRECTORY need
   not have been expanded.  */

static int
locate_file_in_directory (Lisp_Object directory, Lisp_Object str,
			  Lisp_Object suffixes, Lisp_Object *storeptr,
			  int mode)
{
  /* This function can GC */
  struct locate_file_in_directory_mapper_closure closure;
  Lisp_Object filename = Qnil;
  struct gcpro gcpro1, gcpro2, gcpro3;

  GCPRO3 (directory, str, filename);

  filename = Fexpand_file_name (str, directory);
  if (NILP (filename) || NILP (Ffile_name_absolute_p (filename)))
    /* If there are non-absolute elts in PATH (eg ".") */
    /* Of course, this could conceivably lose if luser sets
       default-directory to be something non-absolute ... */
    {
      if (NILP (filename))
	/* NIL means current directory */
	filename = current_buffer->directory;
      else
	filename = Fexpand_file_name (filename,
				      current_buffer->directory);
      if (NILP (Ffile_name_absolute_p (filename)))
	{
	  /* Give up on this directory! */
	  UNGCPRO;
	  return -1;
	}
    }

  closure.fd = -1;
  closure.storeptr = storeptr;
  closure.mode = mode;

  locate_file_map_suffixes (filename, suffixes,
			    locate_file_in_directory_mapper,
			    &closure);

  UNGCPRO;
  return closure.fd;
}

/* do the same as locate_file() but don't use any hash tables. */

static int
locate_file_without_hash (Lisp_Object path, Lisp_Object str,
			  Lisp_Object suffixes, Lisp_Object *storeptr,
			  int mode)
{
  /* This function can GC */
  int absolute = !NILP (Ffile_name_absolute_p (str));

  EXTERNAL_LIST_LOOP_2 (elt, path)
    {
      int val = locate_file_in_directory (elt, str, suffixes, storeptr,
					  mode);
      if (val >= 0)
	return val;
      if (absolute)
	break;
    }
  return -1;
}

static int
locate_file_construct_suffixed_files_mapper (Ibyte *fn, void *arg)
{
  Lisp_Object *tail = (Lisp_Object *) arg;
  *tail = Fcons (build_istring (fn), *tail);
  return 0;
}

/* Construct a list of all files to search for.
   It makes sense to have this despite locate_file_map_suffixes()
   because we need Lisp strings to access the hash-table, and it would
   be inefficient to create them on the fly, again and again for each
   path component.  See locate_file(). */

static Lisp_Object
locate_file_construct_suffixed_files (Lisp_Object filename,
				      Lisp_Object suffixes)
{
  Lisp_Object tail = Qnil;
  struct gcpro gcpro1;
  GCPRO1 (tail);

  locate_file_map_suffixes (filename, suffixes,
			    locate_file_construct_suffixed_files_mapper,
			    &tail);

  UNGCPRO;
  return Fnreverse (tail);
}

DEFUN ("locate-file-clear-hashing", Flocate_file_clear_hashing, 1, 1, 0, /*
Clear the hash records for the specified list of directories.
`locate-file' uses a hashing scheme to speed lookup, and will correctly
track the following environmental changes:

-- changes of any sort to the list of directories to be searched.
-- addition and deletion of non-shadowing files (see below) from the
   directories in the list.
-- byte-compilation of a .el file into a .elc file.

`locate-file' will primarily get confused if you add a file that shadows
\(i.e. has the same name as) another file further down in the directory list.
In this case, you must call `locate-file-clear-hashing'.

If PATH is t, it means to fully clear all the accumulated hashes.  This
can be used if the internal tables grow too large, or when dumping.
*/
       (path))
{
  if (EQ (path, Qt))
    Fclrhash (Vlocate_file_hash_table);
  else
    {
      EXTERNAL_LIST_LOOP_2 (elt, path)
	{
	  Lisp_Object pathel = Fexpand_file_name (elt, Qnil);
	  Fremhash (pathel, Vlocate_file_hash_table);
	}
    }
  return Qnil;
}

/* Search for a file whose name is STR, looking in directories
   in the Lisp list PATH, and trying suffixes from SUFFIXES.
   SUFFIXES is a list of possible suffixes, or (for backward
   compatibility) a string containing possible suffixes separated by
   colons.
   On success, returns a file descriptor.  On failure, returns -1.

   MODE nonnegative means don't open the files,
   just look for one for which access(file,MODE) succeeds.  In this case,
   returns a nonnegative value on success.  On failure, returns -1.

   If STOREPTR is non-nil, it points to a slot where the name of
   the file actually found should be stored as a Lisp string.
   Nil is stored there on failure.

   Called openp() in FSFmacs. */

int
locate_file (Lisp_Object path, Lisp_Object str, Lisp_Object suffixes,
	     Lisp_Object *storeptr, int mode)
{
  /* This function can GC */
  Lisp_Object suffixtab = Qnil;
  Lisp_Object pathel_expanded;
  int val;
  struct gcpro gcpro1, gcpro2, gcpro3, gcpro4;

  if (storeptr)
    *storeptr = Qnil;

  /* Is it really necessary to gcpro path and str?  It shouldn't be
     unless some caller has fucked up.  There are known instances that
     call us with build_ascstring("foo:bar") as SUFFIXES, though. */
  GCPRO4 (path, str, suffixes, suffixtab);

  /* if this filename has directory components, it's too complicated
     to try and use the hash tables. */
  if (!NILP (Ffile_name_directory (str)))
    {
      val = locate_file_without_hash (path, str, suffixes, storeptr, mode);
      UNGCPRO;
      return val;
    }

  suffixtab = locate_file_construct_suffixed_files (str, suffixes);

  {
    EXTERNAL_LIST_LOOP_2 (pathel, path)
      {
	Lisp_Object hash_table;
	int found = 0;

	/* If this path element is relative, we have to look by hand. */
	if (NILP (pathel) || NILP (Ffile_name_absolute_p (pathel)))
	  {
	    val = locate_file_in_directory (pathel, str, suffixes, storeptr,
					    mode);
	    if (val >= 0)
	      {
		UNGCPRO;
		return val;
	      }
	    continue;
	  }

	pathel_expanded = Fexpand_file_name (pathel, Qnil);
	hash_table = locate_file_find_directory_hash_table (pathel_expanded);

	if (!NILP (hash_table))
	  {
	    /* Loop over suffixes.  */
	    LIST_LOOP_2 (elt, suffixtab)
	      if (!NILP (Fgethash (elt, hash_table, Qnil)))
		{
		  found = 1;
		  break;
		}
	  }

	if (found)
	  {
	    /* This is a likely candidate.  Look by hand in this directory
	       so we don't get thrown off if someone byte-compiles a file. */
	    val = locate_file_in_directory (pathel, str, suffixes, storeptr,
					    mode);
	    if (val >= 0)
	      {
		UNGCPRO;
		return val;
	      }
	    
	    /* Hmm ...  the file isn't actually there. (Or possibly it's
	       a directory ...)  So refresh our hashing. */
	    locate_file_refresh_hashing (pathel_expanded);
	  }
      }
    }

  /* File is probably not there, but check the hard way just in case. */
  val = locate_file_without_hash (path, str, suffixes, storeptr, mode);
  if (val >= 0)
    {
      /* Sneaky user added a file without telling us. */
      Flocate_file_clear_hashing (path);
    }

  UNGCPRO;
  return val;
}


#ifdef LOADHIST

/* Merge the list we've accumulated of globals from the current input source
   into the load_history variable.  The details depend on whether
   the source has an associated file name or not. */

static void
build_load_history (int loading, Lisp_Object source)
{
  REGISTER Lisp_Object tail, prev, newelt;
  REGISTER Lisp_Object tem, tem2;
  int foundit;

#if !defined(LOADHIST_DUMPED)
  /* Don't bother recording anything for preloaded files.  */
  if (purify_flag)
    return;
#endif

  tail = Vload_history;
  prev = Qnil;
  foundit = 0;
  while (!NILP (tail))
    {
      tem = Fcar (tail);

      /* Find the feature's previous assoc list... */
      if (internal_equal (source, Fcar (tem), 0))
	{
	  foundit = 1;

	  /*  If we're loading, remove it. */
	  if (loading)
	    {
	      if (NILP (prev))
		Vload_history = Fcdr (tail);
	      else
		Fsetcdr (prev, Fcdr (tail));
	    }

	  /*  Otherwise, cons on new symbols that are not already members.  */
	  else
	    {
	      tem2 = Vcurrent_load_list;

	      while (CONSP (tem2))
		{
		  newelt = XCAR (tem2);

		  if (NILP (Fmemq (newelt, tem)))
		    Fsetcar (tail, Fcons (Fcar (tem),
					  Fcons (newelt, Fcdr (tem))));

		  tem2 = XCDR (tem2);
		  QUIT;
		}
	    }
	}
      else
	prev = tail;
      tail = Fcdr (tail);
      QUIT;
    }

  /* If we're loading, cons the new assoc onto the front of load-history,
     the most-recently-loaded position.  Also do this if we didn't find
     an existing member for the current source.  */
  if (loading || !foundit)
    Vload_history = Fcons (Fnreverse (Vcurrent_load_list),
			   Vload_history);
}

#else /* !LOADHIST */
#define build_load_history(x,y)
#endif /* !LOADHIST */


static void
readevalloop (Lisp_Object readcharfun,
              Lisp_Object sourcename,
              Lisp_Object (*evalfun) (Lisp_Object),
              int printflag)
{
  /* This function can GC */
  REGISTER Ichar c;
  Lisp_Object val = Qnil;
  int speccount = specpdl_depth ();
  struct gcpro gcpro1, gcpro2;
  struct buffer *b = 0;

  if (BUFFERP (readcharfun))
    b = XBUFFER (readcharfun);
  else if (MARKERP (readcharfun))
    b = XMARKER (readcharfun)->buffer;

  /* Don't do this.  It is not necessary, and it needlessly exposes
     READCHARFUN (which can be a stream) to Lisp.  --hniksic */
  /*specbind (Qstandard_input, readcharfun);*/

  internal_bind_lisp_object (&Vcurrent_load_list, Qnil);

  GCPRO2 (val, sourcename);

  LOADHIST_ATTACH (sourcename);

  while (1)
    {
      QUIT;

      if (b != 0 && !BUFFER_LIVE_P (b))
 invalid_operation ("Reading from killed buffer", Qunbound);

      c = readchar (readcharfun);
      if (c == ';')
	{
          /* Skip comment */
	  while ((c = readchar (readcharfun)) != '\n' && c != -1)
            QUIT;
	  continue;
	}
      if (c < 0)
        break;

      /* Ignore whitespace here, so we can detect eof.  */
      if (c == ' ' || c == '\t' || c == '\n' || c == '\f' || c == '\r')
        continue;

      unreadchar (readcharfun, c);
      Vread_objects = Qnil;
      if (NILP (Vload_read_function))
	val = read0 (readcharfun);
      else
	val = call1 (Vload_read_function, readcharfun);
      val = (*evalfun) (val);
      if (printflag)
	{
	  Vvalues = Fcons (val, Vvalues);
	  if (EQ (Vstandard_output, Qt))
	    Fprin1 (val, Qnil);
	  else
	    Fprint (val, Qnil);
	}
    }

  build_load_history (LSTREAMP (readcharfun) ||
		      /* This looks weird, but it's what's in FSFmacs */
		      (b ? BUF_NARROWED (b) : BUF_NARROWED (current_buffer)),
                      sourcename);
  UNGCPRO;

  unbind_to (speccount);
}

DEFUN ("eval-buffer", Feval_buffer, 0, 2, "bBuffer: ", /*
Execute BUFFER as Lisp code.
Programs can pass two arguments, BUFFER and PRINTFLAG.
BUFFER is the buffer to evaluate (nil means use current buffer).
PRINTFLAG controls printing of output:
nil means discard it; anything else is a stream for printing.

If there is no error, point does not move.  If there is an error,
point remains at the end of the last character read from the buffer.
*/
       (buffer, printflag))
{
  /* This function can GC */
  int speccount = specpdl_depth ();
  Lisp_Object tem, buf;

  if (NILP (buffer))
    buf = Fcurrent_buffer ();
  else
    buf = Fget_buffer (buffer);
  if (NILP (buf))
    invalid_argument ("No such buffer", Qunbound);

  if (NILP (printflag))
    tem = Qsymbolp;             /* #### #@[]*&$#*[& SI:NULL-STREAM */
  else
    tem = printflag;
  specbind (Qstandard_output, tem);
  record_unwind_protect (save_excursion_restore, save_excursion_save ());
  BUF_SET_PT (XBUFFER (buf), BUF_BEGV (XBUFFER (buf)));
  readevalloop (buf, XBUFFER (buf)->filename, Feval,
		!NILP (printflag));

  return unbind_to (speccount);
}

#if 0
DEFUN ("eval-current-buffer", Feval_current_buffer, 0, 1, "", /*
Execute the current buffer as Lisp code.
Programs can pass argument PRINTFLAG which controls printing of output:
nil means discard it; anything else is stream for print.

If there is no error, point does not move.  If there is an error,
point remains at the end of the last character read from the buffer.
*/
	 (printflag))
{
  code omitted;
}
#endif /* 0 */

DEFUN ("eval-region", Feval_region, 2, 3, "r", /*
Execute the region as Lisp code.
When called from programs, expects two arguments START and END
giving starting and ending indices in the current buffer
of the text to be executed.
Programs can pass third optional argument STREAM which controls output:
nil means discard it; anything else is stream for printing it.

If there is no error, point does not move.  If there is an error,
point remains at the end of the last character read from the buffer.

Note:  Before evaling the region, this function narrows the buffer to it.
If the code being eval'd should happen to trigger a redisplay you may
see some text temporarily disappear because of this.
*/
       (start, end, stream))
{
  /* This function can GC */
  int speccount = specpdl_depth ();
  Lisp_Object tem;
  Lisp_Object cbuf = Fcurrent_buffer ();

  if (NILP (stream))
    tem = Qsymbolp;             /* #### #@[]*&$#*[& SI:NULL-STREAM */
  else
    tem = stream;
  specbind (Qstandard_output, tem);

  if (NILP (stream))
    record_unwind_protect (save_excursion_restore, save_excursion_save ());
  record_unwind_protect (save_restriction_restore,
			 save_restriction_save (current_buffer));

  /* This both uses start and checks its type.  */
  Fgoto_char (start, cbuf);
  Fnarrow_to_region (make_fixnum (BUF_BEGV (current_buffer)), end, cbuf);
  readevalloop (cbuf, XBUFFER (cbuf)->filename, Feval,
		!NILP (stream));

  return unbind_to (speccount);
}

DEFUN ("read", Fread, 0, 1, 0, /*
Read one Lisp expression as text from STREAM, return as Lisp object.
If STREAM is nil, use the value of `standard-input' (which see).
STREAM or the value of `standard-input' may be:
 a buffer (read from point and advance it)
 a marker (read from where it points and advance it)
 a function (call it with no arguments for each character,
     call it with a char as argument to push a char back)
 a string (takes text from string, starting at the beginning)
 t (read text line using minibuffer and use it).
*/
       (stream))
{
  if (NILP (stream))
    stream = Vstandard_input;
  if (EQ (stream, Qt))
    stream = Qread_char;

  Vread_objects = Qnil;

  if (EQ (stream, Qread_char))
    {
      Lisp_Object val = call1 (Qread_from_minibuffer,
			       build_msg_string ("Lisp expression: "));
      return Fcar (Fread_from_string (val, Qnil, Qnil));
    }

  if (STRINGP (stream))
    return Fcar (Fread_from_string (stream, Qnil, Qnil));

  return read0 (stream);
}

DEFUN ("read-from-string", Fread_from_string, 1, 3, 0, /*
Read one Lisp expression which is represented as text by STRING.
Returns a cons: (OBJECT-READ . FINAL-STRING-INDEX).
START and END optionally delimit a substring of STRING from which to read;
 they default to 0 and (length STRING) respectively.
*/
       (string, start, end))
{
  Bytecount startval, endval;
  Lisp_Object tem;
  Lisp_Object lispstream = Qnil;
  struct gcpro gcpro1;

  GCPRO1 (lispstream);
  CHECK_STRING (string);
  get_string_range_byte (string, start, end, &startval, &endval,
			 GB_HISTORICAL_STRING_BEHAVIOR);
  lispstream = make_lisp_string_input_stream (string, startval,
					      endval - startval);

  Vread_objects = Qnil;

  tem = read0 (lispstream);
  /* Yeah, it's ugly.  Gonna make something of it?
     At least our reader is reentrant ... */
  tem =
    (Fcons (tem, make_fixnum
	    (string_index_byte_to_char
	     (string,
	      startval + Lstream_byte_count (XLSTREAM (lispstream))))));
  Lstream_delete (XLSTREAM (lispstream));
  UNGCPRO;
  return tem;
}



/* Use this for recursive reads, in contexts where internal tokens
   are not allowed.  See also read1(). */
static Lisp_Object
read0 (Lisp_Object readcharfun)
{
  Lisp_Object val = read1 (readcharfun);

  if (CONSP (val) && UNBOUNDP (XCAR (val)))
    {
      Ichar c = XCHAR (XCDR (val));
      free_cons (val);
      return Fsignal (Qinvalid_read_syntax,
		      list1 (Fchar_to_string (make_char (c))));
    }

  return val;
}

/* A Unicode escape, as in C# (though we only permit them in strings
   and characters, not arbitrarily in the source code.) */
static Ichar
read_unicode_escape (Lisp_Object readcharfun, int unicode_hex_count)
{
  REGISTER Ichar i = 0, c;
  REGISTER int count = 0;
  Lisp_Object lisp_char;
  while (++count <= unicode_hex_count)
    {
      c = readchar (readcharfun);
      /* Remember, can't use isdigit(), isalpha() etc. on Ichars */
      if      (c >= '0' && c <= '9')  i = (i << 4) + (c - '0');
      else if (c >= 'a' && c <= 'f')  i = (i << 4) + (c - 'a') + 10;
      else if (c >= 'A' && c <= 'F')  i = (i << 4) + (c - 'A') + 10;
      else
	{
	  syntax_error ("Non-hex digit used for Unicode escape",
			make_char (c));
	  break;
	}
    }

  if (i >= 0x110000 || i < 0)
    {
      syntax_error ("Not a Unicode code point", make_fixnum(i));
    }

  lisp_char = Funicode_to_char(make_fixnum(i), Qnil);

  if (EQ(Qnil, lisp_char))
    {
      /* Will happen on non-Mule. Silent corruption is what happens
         elsewhere, and we used to do that to be consistent, but GNU error,
         so people writing portable code need to be able to handle that, and
         given a choice I prefer that behaviour.

         An undesirable aspect to this error is that the code point is shown
         as a decimal integer, which is mostly unreadable. */
      syntax_error ("Unsupported Unicode code point", make_fixnum(i));
    }

  return XCHAR(lisp_char);
}


static Ichar
read_escape (Lisp_Object readcharfun)
{
  /* This function can GC */
  Ichar c = readchar (readcharfun);

  if (c < 0)
    signal_error (Qend_of_file, 0, READCHARFUN_MAYBE (readcharfun));

  switch (c)
    {
    case 'a': return '\007';
    case 'b': return '\b';
    case 'd': return 0177;
    case 'e': return 033;
    case 'f': return '\f';
    case 'n': return '\n';
    case 'r': return '\r';
    case 't': return '\t';
    case 'v': return '\v';
    case '\n': return -1;

    case 'M':
      c = readchar (readcharfun);
      if (c < 0)
	signal_error (Qend_of_file, 0, READCHARFUN_MAYBE (readcharfun));
      if (c != '-')
	syntax_error ("Invalid escape character syntax", Qunbound);
      c = readchar (readcharfun);
      if (c < 0)
	signal_error (Qend_of_file, 0, READCHARFUN_MAYBE (readcharfun));
      if (c == '\\')
	c = read_escape (readcharfun);
      return c | 0200;

      /* Originally, FSF_KEYS provided a degree of FSF Emacs
	 compatibility by defining character "modifiers" alt, super,
	 hyper and shift to infest the characters (i.e. integers).

	 However, this doesn't cut it for XEmacs 20, which
	 distinguishes characters from integers.  Without Mule, ?\H-a
	 simply returns ?a because every character is clipped into
	 0-255.  Under Mule it is much worse -- ?\H-a with FSF_KEYS
	 produces an illegal character, and moves us to crash-land.

         For these reasons, FSF_KEYS hack is useless and without hope
         of ever working under XEmacs 20.  */
#ifdef FSF_KEYS
      /* Deleted */
#endif

    case 'C':
      c = readchar (readcharfun);
      if (c < 0)
	signal_error (Qend_of_file, 0, READCHARFUN_MAYBE (readcharfun));
      if (c != '-')
	syntax_error ("Invalid escape character syntax", Qunbound);
    case '^':
      c = readchar (readcharfun);
      if (c < 0)
	signal_error (Qend_of_file, 0, READCHARFUN_MAYBE (readcharfun));
      if (c == '\\')
	c = read_escape (readcharfun);
      /* FSFmacs junk for non-ASCII controls.
	 Not used here. */
      if (c == '?')
	return 0177;
      else
        return c & (0200 | 037);

    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
      /* An octal escape, as in ANSI C.  */
      {
	REGISTER Ichar i = c - '0';
	REGISTER int count = 0;
	while (++count < 3)
	  {
	    if ((c = readchar (readcharfun)) >= '0' && c <= '7')
              i = (i << 3) + (c - '0');
	    else
	      {
		unreadchar (readcharfun, c);
		break;
	      }
	  }
	if (i >= 0400)
	  {
	    read_syntax_error ((Ascbyte *) emacs_sprintf_malloc
			       (NULL,
				"Non-ISO-8859-1 octal character escape, "
				"?\\%.3o", i));
	  }
	return i;
      }

    case 'x':
      /* A hex escape, as in ANSI C, except that we only allow latin-1
	 characters to be read this way.  What is "\x4e03" supposed to
	 mean, anyways, if the internal representation is hidden?
         This is also consistent with the treatment of octal escapes.

         Note that we don't accept ?\XAB as specifying the character with
         numeric value 171; it must be ?\xAB. */
      {
#define OVERLONG_INFO "Overlong hex character escape, ?\\x"

	REGISTER Ichar i = 0;
	REGISTER int count = 0;
	Ascbyte seen[] = OVERLONG_INFO "\0\0\0\0\0";
	REGISTER Ascbyte *seenp = seen + sizeof (OVERLONG_INFO) - 1;

#undef OVERLONG_INFO

	while (++count <= 2)
	  {
	    c = readchar (readcharfun), *seenp = c, ++seenp;
	    /* Remember, can't use isdigit(), isalpha() etc. on Ichars */
	    if      (c >= '0' && c <= '9')  i = (i << 4) + (c - '0');
	    else if (c >= 'a' && c <= 'f')  i = (i << 4) + (c - 'a') + 10;
            else if (c >= 'A' && c <= 'F')  i = (i << 4) + (c - 'A') + 10;
	    else
	      {
		unreadchar (readcharfun, c);
		break;
	      }
	  }

        if (count == 3)
          {
            c = readchar (readcharfun), *seenp = c, ++seenp;
            if ((c >= '0' && c <= '9') ||
                (c >= 'a' && c <= 'f') ||
                (c >= 'A' && c <= 'F'))
              {
		read_syntax_error (seen);
              }
            unreadchar (readcharfun, c);
          }

	return i;
      }
    case 'U':
      /* Post-Unicode-2.0: Up to eight hex chars */
      return read_unicode_escape(readcharfun, 8);
    case 'u':
      /* Unicode-2.0 and before; four hex chars. */
      return read_unicode_escape(readcharfun, 4);

    default:
	return c;
    }
}



/* read symbol-constituent stuff into `Vread_buffer_stream'. */
static Bytecount
read_atom_0 (Lisp_Object readcharfun, Ichar firstchar, int *saw_a_backslash)
{
  /* This function can GC */
  Ichar c = ((firstchar) >= 0 ? firstchar : readchar (readcharfun));
  Lstream_rewind (XLSTREAM (Vread_buffer_stream));

  *saw_a_backslash = 0;

  while (c > 040	/* #### - comma should be here as should backquote */
         && !(c == '\"' || c == '\'' || c == ';'
              || c == '(' || c == ')'
              || c == '[' || c == ']' || c == '#'
              ))
    {
      if (c == '\\')
	{
	  c = readchar (readcharfun);
	  if (c < 0)
	    signal_error (Qend_of_file, 0, READCHARFUN_MAYBE (readcharfun));
	  *saw_a_backslash = 1;
	}
      Lstream_put_ichar (XLSTREAM (Vread_buffer_stream), c);
      QUIT;
      c = readchar (readcharfun);
    }

  if (c >= 0)
    unreadchar (readcharfun, c);
  /* blasted terminating 0 */
  Lstream_put_ichar (XLSTREAM (Vread_buffer_stream), 0);
  Lstream_flush (XLSTREAM (Vread_buffer_stream));

  return Lstream_byte_count (XLSTREAM (Vread_buffer_stream)) - 1;
}

static Lisp_Object
read_atom (Lisp_Object readcharfun,
           Ichar firstchar,
           int uninterned_symbol)
{
  /* This function can GC */
  int saw_a_backslash;
  Bytecount len = read_atom_0 (readcharfun, firstchar, &saw_a_backslash);
  Ibyte *read_ptr
    = (Ibyte *) resizing_buffer_stream_ptr (XLSTREAM (Vread_buffer_stream));

  /* Is it an integer?

     If a token had any backslashes in it, it is disqualified from being an
     integer or a float.  This means that 123\456 is a symbol, as is \123
     (which is the way (intern "123") prints).  Also, if token was preceded by
     #:, it's always a symbol. */

  if (!(saw_a_backslash || uninterned_symbol))
    {
      Lisp_Object got = get_char_table (firstchar, Vdigit_fixnum_map);
      Fixnum fixval = FIXNUMP (got) ? XREALFIXNUM (got) : -1;
      Boolint starts_like_an_int_p = (fixval > -1 && fixval < 10)
        || firstchar == '+' || firstchar == '-';
      Ibyte *endp = NULL;
      Lisp_Object num = Qnil;

      /* Attempt to parse as an integer, with :JUNK-ALLOWED t. Do a gross
         plausibility check (above) first, though, we'd prefer not to call
         parse_integer() on every symbol we see. */
      if (starts_like_an_int_p)
        {
          num = parse_integer (read_ptr, &endp, len, 10, 1, Qnil);
        }

      if (INTEGERP (num))
        {
          if (endp == (read_ptr + len))
            {
              /* We consumed the whole atom, it's definitely an integer. */
              return num;
            }
          else if ('.' == itext_ichar (endp))
            {
              /* Trailing decimal point is allowed in the Lisp reader, this is
                 an integer. */
              INC_IBYTEPTR (endp);
              if (endp == (read_ptr + len))
                {
                  return num;
                }
            }
          else if ('/' == itext_ichar (endp))
            {
              /* Maybe it's a ratio? */
              Lisp_Object denom = Qnil;

              INC_IBYTEPTR (endp);

              if (endp < (read_ptr + len))
                {
                  Ichar cc = itext_ichar (endp);
                  /* No leading sign allowed in the denominator, that would
                     make it a symbol (according to Common Lisp, of course).*/
                  if (cc != '+' && cc != '-')
                    {
                      denom = parse_integer (endp, &endp,
                                             len - (endp - read_ptr), 10,
                                             1, Qnil);
                    }
                }

              if (INTEGERP (denom) && endp == (read_ptr + len))
                {
                  if (ZEROP (denom))
                    {
                      Fsignal (Qinvalid_read_syntax,
                               list2 (build_msg_string
                                      ("Invalid ratio constant in reader"),
                                      make_string (read_ptr, len)));
                    }
#ifndef HAVE_RATIO
                  /* Support a couple of trivial ratios in the reader to allow
                     people to test ratio syntax: */
                  if (EQ (denom, make_fixnum (1)))
                    {
                      return num;
                    }
                  if (!NILP (Fequal (num, denom)))
                    {
                      return make_fixnum (1);
                    }

                  return Fsignal (Qunsupported_type,
                                  list3 (build_ascstring ("ratio"),
                                         num, denom));
#else
                  switch (promote_args (&num, &denom))
                    {
                    case FIXNUM_T:
                      num = make_ratio (XREALFIXNUM (num),
                                        XREALFIXNUM (denom));
                      return Fcanonicalize_number (num);
                      break;
                    case BIGNUM_T:
                      num = make_ratio_bg (XBIGNUM_DATA (num),
                                           XBIGNUM_DATA (denom));
                      return Fcanonicalize_number (num);
                      break;
                    default:
                      assert (0);
                    }
#endif /* HAVE_RATIO */
                }
              /* Otherwise, not a ratio or integer, despite that the partial
                 parse may have succeeded. The trailing junk disqualifies
                 it. */
            }
        }

      if ((starts_like_an_int_p || '.' == firstchar)
          && isfloat_string ((char *) read_ptr))
        {
          return make_float (atof ((char *) read_ptr));
        }
    }

  {
    Lisp_Object sym;
    if (uninterned_symbol)
      sym = Fmake_symbol ( make_string ((Ibyte *) read_ptr, len));
    else
      {
	Lisp_Object name = make_string ((Ibyte *) read_ptr, len);
	sym = Fintern (name, Qnil);
      }
    return sym;
  }
}

static Lisp_Object
read_rational (Lisp_Object readcharfun, Fixnum base)
{
  /* This function can GC */
  int saw_a_backslash;
  Ibyte *buf_end, *buf_ptr, *slash;
  Bytecount len = read_atom_0 (readcharfun, -1, &saw_a_backslash);
  Lisp_Object num = Qnil, denom = Qzero;

  buf_ptr = resizing_buffer_stream_ptr (XLSTREAM (Vread_buffer_stream));

  if ((slash = (Ibyte *) memchr (buf_ptr, '/', len)) == NULL)
    {
      /* Can't be a ratio, parse as as an integer. */ 
      return parse_integer (buf_ptr, &buf_end, len, base, 0, Qnil);
    }

  /* No need to call isratio_string, the detailed parsing (and erroring, as
     necessary) will be done by parse_integer. */
  num = parse_integer (buf_ptr, &buf_end, slash - buf_ptr, base, 0, Qnil);

  INC_IBYTEPTR (slash);
  if (slash < (buf_ptr + len))
    {
      Ichar cc = itext_ichar (slash);
      if (cc != '+' && cc != '-')
        {
          denom = parse_integer (slash, &buf_end, len - (slash - buf_ptr),
                                 base, 0, Qnil);
        }
    }

  if (ZEROP (denom))
    {
      /* The denominator was zero, or it had a sign specified; these are
         invalid ratios, for slightly different reasons. */
      Fsignal (Qinvalid_read_syntax,
               list2 (build_msg_string ("Invalid ratio constant in reader"),
                      make_string (buf_ptr, len)));
    }

#ifndef HAVE_RATIO
  /* Support a couple of trivial ratios in the reader to allow people to test
     ratio syntax: */
  if (EQ (denom, make_fixnum (1)))
    {
      return num;
    }
  if (!NILP (Fequal (num, denom)))
    {
      return make_fixnum (1);
    }

  return Fsignal (Qunsupported_type, list3 (build_ascstring ("ratio"),
                                            num, denom));
#else
  switch (promote_args (&num, &denom))
    {
    case FIXNUM_T:
      num = make_ratio (XREALFIXNUM (num), XREALFIXNUM (denom));
      return Fcanonicalize_number (num);
      break;
    case BIGNUM_T:
      num = make_ratio_bg (XBIGNUM_DATA (num), XBIGNUM_DATA (denom));
      return Fcanonicalize_number (num);
      break;
    default:
      assert (0); /* promote_args() with two integers won't give us anything
                     but fixnums or bignums. */
      return Qnil;
    }
#endif
}

static Lisp_Object
read_bit_vector (Lisp_Object readcharfun)
{
  unsigned_char_dynarr *dyn = Dynarr_new (unsigned_char);
  Lisp_Object val;

  while (1)
    {
      unsigned char bit;
      Ichar c = readchar (readcharfun);
      if (c == '0')
	bit = 0;
      else if (c == '1')
	bit = 1;
      else
	{
	  if (c >= 0)
	    unreadchar (readcharfun, c);
	  break;
	}
      Dynarr_add (dyn, bit);
    }

  val = make_bit_vector_from_byte_vector (Dynarr_begin (dyn),
					  Dynarr_length (dyn));
  Dynarr_free (dyn);

  return val;
}



/* structures */

struct structure_type *
define_structure_type (Lisp_Object type,
		       int (*validate) (Lisp_Object data,
					Error_Behavior errb),
		       Lisp_Object (*instantiate) (Lisp_Object data))
{
  struct structure_type st;

  st.type = type;
  st.keywords = Dynarr_new (structure_keyword_entry);
  st.validate = validate;
  st.instantiate = instantiate;
  Dynarr_add (the_structure_type_dynarr, st);

  return Dynarr_lastp (the_structure_type_dynarr);
}

void
define_structure_type_keyword (struct structure_type *st, Lisp_Object keyword,
			       int (*validate) (Lisp_Object keyword,
						Lisp_Object value,
						Error_Behavior errb))
{
  struct structure_keyword_entry en;

  en.keyword = keyword;
  en.validate = validate;
  Dynarr_add (st->keywords, en);
}

static struct structure_type *
recognized_structure_type (Lisp_Object type)
{
  int i;

  for (i = 0; i < Dynarr_length (the_structure_type_dynarr); i++)
    {
      struct structure_type *st = Dynarr_atp (the_structure_type_dynarr, i);
      if (EQ (st->type, type))
	return st;
    }

  return 0;
}

static Lisp_Object
read_structure (Lisp_Object readcharfun)
{
  Ichar c = readchar (readcharfun);
  Lisp_Object list = Qnil;
  Lisp_Object orig_list = Qnil;
  Lisp_Object already_seen = Qnil;
  int keyword_count;
  struct structure_type *st;
  struct gcpro gcpro1, gcpro2;

  GCPRO2 (orig_list, already_seen);
  if (c != '(')
    RETURN_UNGCPRO (continuable_read_syntax_error ("#s not followed by paren"));
  list = read_list (readcharfun, ')', 0, 0);
  orig_list = list;
  {
    int len = XFIXNUM (Flength (list));
    if (len == 0)
      RETURN_UNGCPRO (continuable_read_syntax_error
		      ("structure type not specified"));
    if (!(len & 1))
      RETURN_UNGCPRO
	(continuable_read_syntax_error
	 ("structures must have alternating keyword/value pairs"));
  }

  st = recognized_structure_type (XCAR (list));
  if (!st)
    RETURN_UNGCPRO (Fsignal (Qinvalid_read_syntax,
			     list2 (build_msg_string
				    ("unrecognized structure type"),
				    XCAR (list))));

  list = Fcdr (list);
  keyword_count = Dynarr_length (st->keywords);
  while (!NILP (list))
    {
      Lisp_Object keyword, value;
      int i;
      struct structure_keyword_entry *en = NULL;

      keyword = Fcar (list);
      list = Fcdr (list);
      value = Fcar (list);
      list = Fcdr (list);

      if (!NILP (memq_no_quit (keyword, already_seen)))
	RETURN_UNGCPRO (Fsignal (Qinvalid_read_syntax,
				 list2 (build_msg_string
					("structure keyword already seen"),
					keyword)));

      for (i = 0; i < keyword_count; i++)
	{
	  en = Dynarr_atp (st->keywords, i);
	  if (EQ (keyword, en->keyword))
	    break;
	}

      if (i == keyword_count)
	RETURN_UNGCPRO (Fsignal (Qinvalid_read_syntax,
				   list2 (build_msg_string
					  ("unrecognized structure keyword"),
					  keyword)));

      if (en->validate && ! (en->validate) (keyword, value, ERROR_ME))
	RETURN_UNGCPRO
	  (Fsignal (Qinvalid_read_syntax,
		    list3 (build_msg_string
			   ("invalid value for structure keyword"),
			   keyword, value)));

      already_seen = Fcons (keyword, already_seen);
    }

  if (st->validate && ! (st->validate) (orig_list, ERROR_ME))
    RETURN_UNGCPRO (Fsignal (Qinvalid_read_syntax,
			     list2 (build_msg_string
				    ("invalid structure initializer"),
				    orig_list)));

  RETURN_UNGCPRO ((st->instantiate) (XCDR (orig_list)));
}


static Lisp_Object read_compiled_function (Lisp_Object readcharfun,
					   int terminator);
static Lisp_Object read_vector (Lisp_Object readcharfun, int terminator);

/* Get the next character; filter out whitespace and comments */

static Ichar
reader_nextchar (Lisp_Object readcharfun)
{
  /* This function can GC */
  Ichar c;

 retry:
  QUIT;
  c = readchar (readcharfun);
  if (c < 0)
    signal_error (Qend_of_file, 0, READCHARFUN_MAYBE (readcharfun));

  switch (c)
    {
    default:
      {
	/* Ignore whitespace and control characters */
	if (c <= 040)
	  goto retry;
	return c;
      }

    case ';':
      {
        /* Comment */
        while ((c = readchar (readcharfun)) >= 0 && c != '\n')
          QUIT;
        goto retry;
      }
    }
}

#if 0
static Lisp_Object
list2_pure (int pure, Lisp_Object a, Lisp_Object b)
{
  return pure ? pure_cons (a, pure_cons (b, Qnil)) : list2 (a, b);
}
#endif

static Lisp_Object
read_string (Lisp_Object readcharfun, Ichar delim, int raw, 
	     int honor_unicode)
{
#ifdef I18N3
  /* #### If the input stream is translating, then the string
     should be marked as translatable by setting its
     `string-translatable' property to t.  .el and .elc files
     normally are translating input streams.  See Fgettext()
     and print_internal(). */
#endif
  Ichar c;
  int cancel = 0;

  Lstream_rewind(XLSTREAM(Vread_buffer_stream));
  while ((c = readchar(readcharfun)) >= 0 && c != delim)
    {
    if (c == '\\') 
      {
	if (raw) 
	  {
	    c = readchar(readcharfun);
	    if (honor_unicode && ('u' == c || 'U' == c))
	      {
		c = read_unicode_escape(readcharfun,
					'U' == c ? 8 : 4);
	      }
	    else
	      {
		/* For raw strings, insert the
		   backslash and the next char, */
		Lstream_put_ichar(XLSTREAM
				  (Vread_buffer_stream),
				  '\\');
	      }
	  } 
	else
	  /* otherwise, backslash escapes the next char. */
	  c = read_escape(readcharfun);
      }
    /* c is -1 if \ newline has just been seen */
    if (c == -1) 
      {
	if (Lstream_byte_count
	  (XLSTREAM(Vread_buffer_stream)) ==
	  0)
	  cancel = 1;
      } 
    else
      Lstream_put_ichar(XLSTREAM
			 (Vread_buffer_stream),
			 c);
    QUIT;
    }
  if (c < 0)
    return Fsignal(Qend_of_file,
		   list1(READCHARFUN_MAYBE(readcharfun)));

  /* If purifying, and string starts with \ newline,
     return zero instead.  This is for doc strings
     that we are really going to find in lib-src/DOC.nn.nn  */
  if (purify_flag && NILP(Vinternal_doc_file_name)
      && cancel)
    return Qzero;

  Lstream_flush(XLSTREAM(Vread_buffer_stream));
  return make_string(resizing_buffer_stream_ptr
		     (XLSTREAM(Vread_buffer_stream)),
		     Lstream_byte_count(XLSTREAM(Vread_buffer_stream)));
}

static Lisp_Object
read_raw_string (Lisp_Object readcharfun)
{
  Ichar c;
  Ichar permit_unicode = 0; 

  do
    {
      c = reader_nextchar (readcharfun);
      switch (c)
	{
	  /* #r:engine"my sexy raw string" -- raw string w/ flags*/
	  /* case ':': */
	  /* #ru"Hi there\u20AC \U000020AC" -- raw string, honouring Unicode. */
	case 'u':
	case 'U':
	  permit_unicode = c; 
	  continue;

	  /* #r"my raw string" -- raw string */
	case '\"':
	  return read_string (readcharfun, '\"', 1, permit_unicode);
	  /* invalid syntax */
	default:
	  {
	    if (permit_unicode)
	      {
		unreadchar (readcharfun, permit_unicode);
	      }
	    unreadchar (readcharfun, c);
	    return Fsignal (Qinvalid_read_syntax,
			    list1 (build_msg_string
				   ("unrecognized raw string syntax")));
	  }
	}
    } while (1);
}

/* Read the next Lisp object from the stream READCHARFUN and return it.
   If the return value is a cons whose car is Qunbound, then read1()
   encountered a misplaced token (e.g. a right bracket, right paren,
   or dot followed by a non-number).  To filter this stuff out,
   use read0(). */

static Lisp_Object
read1 (Lisp_Object readcharfun)
{
  Ichar c;

retry:
  c = reader_nextchar (readcharfun);

  switch (c)
    {
    case '(':
      {
#ifdef LISP_BACKQUOTES	/* old backquote compatibility in lisp reader */
	/* if this is disabled, then other code in eval.c must be enabled */
	Ichar ch = reader_nextchar (readcharfun);
	switch (ch)
	  {
	  case '`':
	    {
	      Lisp_Object tem;
	      int speccount = internal_bind_int (&old_backquote_flag,
						 1 + old_backquote_flag);
	      tem = read0 (readcharfun);
	      unbind_to (speccount);
	      ch = reader_nextchar (readcharfun);
	      if (ch != ')')
		{
		  unreadchar (readcharfun, ch);
		  return Fsignal (Qinvalid_read_syntax,
				  list1 (build_msg_string
					 ("Weird old-backquote syntax")));
		}
	      return list2 (Qbacktick, tem);
	    }
	  case ',':
	    {
	      if (old_backquote_flag)
		{
		  Lisp_Object tem, comma_type;
		  ch = readchar (readcharfun);
		  if (ch == '@')
		    comma_type = Qcomma_at;
		  else
		    {
		      if (ch >= 0)
			unreadchar (readcharfun, ch);
		      comma_type = Qcomma;
		    }
		  tem = read0 (readcharfun);
		  ch = reader_nextchar (readcharfun);
		  if (ch != ')')
		    {
		      unreadchar (readcharfun, ch);
		      return Fsignal (Qinvalid_read_syntax,
				      list1 (build_msg_string
					     ("Weird old-backquote syntax")));
		    }
		  return list2 (comma_type, tem);
		}
	      else
		{
		  unreadchar (readcharfun, ch);
#if 0
		  return Fsignal (Qinvalid_read_syntax,
		       list1 (build_msg_string ("Comma outside of backquote")));
#else
		  /* #### - yuck....but this is reverse compatible. */
		  /* mostly this is required by edebug, which does its own
		     annotated reading.  We need to have an annotated_read
		     function that records (with markers) the buffer
		     positions of the elements that make up lists, then that
		     can be used in edebug and bytecomp and the check above
		     can go back in. --Stig */
		  break;
#endif
		}
	    }
	  default:
	    unreadchar (readcharfun, ch);
	  }			/* switch(ch) */
#endif /* old backquote crap... */
	return read_list (readcharfun, ')', 1, 1);
      }
    case '[':
      return read_vector (readcharfun, ']');

    case ')':
    case ']':
      /* #### - huh? these don't do what they seem... */
      return noseeum_cons (Qunbound, make_char (c));
    case '.':
      {
	/* If a period is followed by a number, then we should read it
	   as a floating point number.  Otherwise, it denotes a dotted
	   pair.
	 */
	c = readchar (readcharfun);
	unreadchar (readcharfun, c);

	/* Can't use isdigit on Ichars */
	if (c < '0' || c > '9')
	  return noseeum_cons (Qunbound, make_char ('.'));

	/* Note that read_atom will loop
	   at least once, assuring that we will not try to UNREAD
           two characters in a row.
	   (I think this doesn't matter anymore because there should
	   be no more danger in unreading multiple characters) */
        return read_atom (readcharfun, '.', 0);
      }

    case '#':
      {
	c = readchar (readcharfun);
	switch (c)
	  {
#if 0 /* FSFmacs silly char-table syntax */
	  case '^':
#endif
#if 0 /* FSFmacs silly bool-vector syntax */
	  case '&':
#endif
            /* "#["-- byte-code constant syntax */
            /* purecons #[...] syntax */
	  case '[': return read_compiled_function (readcharfun, ']'
						   /*, purify_flag */ );
            /* "#:"-- gensym syntax */
	  case ':': return read_atom (readcharfun, -1, 1);
            /* #'x => (function x) */
	  case '\'': return list2 (Qfunction, read0 (readcharfun));
#if 0
	    /* RMS uses this syntax for fat-strings.
	       If we use it for vectors, then obscure bugs happen.
	     */
            /* "#(" -- Scheme/CL vector syntax */
	  case '(': return read_vector (readcharfun, ')');
#endif
#if 0 /* FSFmacs */
	  case '(':
	    {
	      Lisp_Object tmp;
	      struct gcpro gcpro1;

	      /* Read the string itself.  */
	      tmp = read1 (readcharfun);
	      if (!STRINGP (tmp))
		{
		  if (CONSP (tmp) && UNBOUNDP (XCAR (tmp)))
		    free_cons (tmp);
		  return Fsignal (Qinvalid_read_syntax,
				   list1 (build_ascstring ("#")));
		}
	      GCPRO1 (tmp);
	      /* Read the intervals and their properties.  */
	      while (1)
		{
		  Lisp_Object beg, end, plist;
		  Ichar ch;
		  int invalid = 0;

		  beg = read1 (readcharfun);
		  if (CONSP (beg) && UNBOUNDP (XCAR (beg)))
		    {
		      ch = XCHAR (XCDR (beg));
		      free_cons (beg);
		      if (ch == ')')
			break;
		      else
			invalid = 1;
		    }
		  if (!invalid)
		    {
		      end = read1 (readcharfun);
		      if (CONSP (end) && UNBOUNDP (XCAR (end)))
			{
			  free_cons (end);
			  invalid = 1;
			}
		    }
		  if (!invalid)
		    {
		      plist = read1 (readcharfun);
		      if (CONSP (plist) && UNBOUNDP (XCAR (plist)))
			{
			  free_cons (plist);
			  invalid = 1;
			}
		    }
		  if (invalid)
		    RETURN_UNGCPRO
		      (Fsignal (Qinvalid_read_syntax,
				list2
				(build_msg_string ("invalid string property list"),
				 XCDR (plist))));
		  Fset_text_properties (beg, end, plist, tmp);
		}
	      UNGCPRO;
	      return tmp;
	    }
#endif /* 0 */
	  case '@':
	    {
	      /* #@NUMBER is used to skip NUMBER following characters.
		 That's used in .elc files to skip over doc strings
		 and function definitions.  */
	      int i, nskip = 0;

	      /* Read a decimal integer.  */
	      while ((c = readchar (readcharfun)) >= 0
		     && c >= '0' && c <= '9')
                nskip = (10 * nskip) + (c - '0');
	      if (c >= 0)
		unreadchar (readcharfun, c);

	      /* FSF has code here that maybe caches the skipped
		 string.  See above for why this is totally
		 losing.  We handle this differently. */

	      /* Skip that many characters.  */
	      for (i = 0; i < nskip && c >= 0; i++)
		c = readchar (readcharfun);

	      goto retry;
	    }
            /* The interned symbol with the empty name. */
          case '#': return intern ("");
	  case '$': return Vload_file_name_internal;
            /* bit vectors */
	  case '*': return read_bit_vector (readcharfun);
            /* #o10 => 8 -- octal constant syntax */
	  case 'o': case 'O': return read_rational (readcharfun, 8);
            /* #xdead => 57005 -- hex constant syntax */
	  case 'x': case 'X': return read_rational (readcharfun, 16);
            /* #b010 => 2 -- binary constant syntax */
	  case 'b': case 'B': return read_rational (readcharfun, 2);
	    /* #r"raw\stringt" -- raw string syntax */
	  case 'r': return read_raw_string(readcharfun);
            /* #s(foobar key1 val1 key2 val2) -- structure syntax */
	  case 's': return read_structure (readcharfun);
	  case '<':
	    {
	      unreadchar (readcharfun, c);
	      return Fsignal (Qinvalid_read_syntax,
		    list1 (build_msg_string ("Cannot read unreadable object")));
	    }
#ifdef FEATUREP_SYNTAX
	  case '+':
	  case '-':
	    {
	      Lisp_Object feature_exp, obj, tem;
	      struct gcpro gcpro1, gcpro2;

	      feature_exp = read0(readcharfun);
	      obj = read0(readcharfun);

	      /* the call to `featurep' may GC. */
	      GCPRO2 (feature_exp, obj);
	      tem = call1 (Qfeaturep, feature_exp);
	      UNGCPRO;

	      if (c == '+' &&  NILP(tem)) goto retry;
	      if (c == '-' && !NILP(tem)) goto retry;
	      return obj;
	    }
#endif
	  case '0': case '1': case '2': case '3': case '4':
	  case '5': case '6': case '7': case '8': case '9':
          hash_digit_syntax:
	    /* Reader forms that can reuse previously read objects, or the
               Common Lisp syntax for a rational of arbitrary base.  */
	    {
              Lisp_Object got = get_char_table (c, Vdigit_fixnum_map);
              Fixnum fixval = FIXNUMP (got) ? XREALFIXNUM (got) : -1;
              Lisp_Object parsed, found;
	      Ibyte *buf_end;

	      Lstream_rewind (XLSTREAM (Vread_buffer_stream));

	      /* Using read_rational() here is impossible, because it
                 chokes on `='. */
	      while (fixval >= 0 && fixval <= 9)
		{
		  Lstream_put_ichar (XLSTREAM (Vread_buffer_stream), c);
		  QUIT;
		  c = readchar (readcharfun);
                  got = get_char_table (c, Vdigit_fixnum_map);
                  fixval = FIXNUMP (got) ? XREALFIXNUM (got) : -1;
		}

	      Lstream_flush (XLSTREAM (Vread_buffer_stream));

	      parsed
		= parse_integer (resizing_buffer_stream_ptr
				 (XLSTREAM (Vread_buffer_stream)), &buf_end,
				 Lstream_byte_count (XLSTREAM
						     (Vread_buffer_stream)),
                                 10, 0, Qnil);

              if ('r' == c || 'R' == c)
                {
                  /* Common Lisp syntax to specify an integer of arbitrary
                     base. */
                  CHECK_FIXNUM (parsed);
                  return read_rational (readcharfun, XFIXNUM (parsed));
                }

	      found = assoc_no_quit (parsed, Vread_objects);
	      if (c == '=')
		{
		  /* #n=object returns object, but associates it with
		     n for #n#.  */
		  if (CONSP (found))
                    {
                      return Fsignal (Qinvalid_read_syntax,
                                      list2 (build_msg_string
                                             ("Multiply defined object label"),
                                             parsed));
                    }
                  else
                    {
                      Lisp_Object object;

                      found = Fcons (parsed, Qnil);
                      /* Make FOUND a placeholder for the object that will
                         be read. (We've just consed it, and it's not
                         visible from Lisp, so there's no possibility of
                         confusing it with something else in the read
                         structure.)  */
                      XSETCDR (found, found);
                      Vread_objects = Fcons (found, Vread_objects);
                      object = read0 (readcharfun);
                      XSETCDR (found, object);

                      nsubst_structures (object, found, object, check_eq_nokey,
                                         1, Qeq, Qnil);
                      return object;
                    }
		}
	      else if (c == '#')
		{
		  /* #n# returns a previously read object.  */
		  if (CONSP (found))
		    return XCDR (found);
		  else
		    return Fsignal (Qinvalid_read_syntax,
				    list2 (build_msg_string
					   ("Undefined symbol label"),
					   parsed));
		}
	      return Fsignal (Qinvalid_read_syntax,
			      list1 (build_ascstring ("#")));
	    }
	  default:
	    {
              Lisp_Object got = get_char_table (c, Vdigit_fixnum_map);
              Fixnum fixval = FIXNUMP (got) ? XREALFIXNUM (got) : -1;

              if (fixval > -1 && fixval < 10)
                {
                  goto hash_digit_syntax;
                }

	      unreadchar (readcharfun, c);
	      return Fsignal (Qinvalid_read_syntax,
			      list1 (build_ascstring ("#")));
	    }
	  }
      }

      /* Quote */
    case '\'': return list2 (Qquote, read0 (readcharfun));

#ifdef LISP_BACKQUOTES
    case '`':
      {
	Lisp_Object tem;
	int speccount = internal_bind_int (&new_backquote_flag,
					   1 + new_backquote_flag);
	tem = read0 (readcharfun);
	unbind_to (speccount);
	return list2 (Qbackquote, tem);
      }

    case ',':
      {
	if (new_backquote_flag)
	  {
	    Lisp_Object comma_type = Qnil;
	    int ch = readchar (readcharfun);

	    if (ch == '@')
	      comma_type = Qcomma_at;
	    else if (ch == '.')
	      comma_type = Qcomma_dot;
	    else
	      {
		if (ch >= 0)
		  unreadchar (readcharfun, ch);
		comma_type = Qcomma;
	      }
	    return list2 (comma_type, read0 (readcharfun));
	  }
	else
	  {
	    /* YUCK.  99.999% backwards compatibility.  The Right
	       Thing(tm) is to signal an error here, because it's
	       really invalid read syntax.  Instead, this permits
	       commas to begin symbols (unless they're inside
	       backquotes).  If an error is signalled here in the
	       future, then commas should be invalid read syntax
	       outside of backquotes anywhere they're found (i.e.
	       they must be quoted in symbols) -- Stig */
	    return read_atom (readcharfun, c, 0);
	  }
      }
#endif

    case '?':
      {
	/* Evil GNU Emacs "character" (ie integer) syntax */
	c = readchar (readcharfun);
	if (c < 0)
	  return Fsignal (Qend_of_file, list1 (READCHARFUN_MAYBE (readcharfun)));

	if (c == '\\')
	  c = read_escape (readcharfun);
	if (c < 0)
	  return Fsignal (Qinvalid_read_syntax, list1 (READCHARFUN_MAYBE (readcharfun)));
	return make_char (c);
      }

    case '\"':
      /* String */
      return read_string(readcharfun, '\"', 0, 1);

    default:
      {
	/* Ignore whitespace and control characters */
	if (c <= 040)
	  goto retry;
	return read_atom (readcharfun, c, 0);
      }
    }
}



#define LEAD_INT 1
#define DOT_CHAR 2
#define TRAIL_INT 4
#define E_CHAR 8
#define EXP_INT 16

int
isfloat_string (const char *cp)
{
  int state = 0;
  const Ibyte *ucp = (const Ibyte *) cp;

  if (*ucp == '+' || *ucp == '-')
    ucp++;

  if (*ucp >= '0' && *ucp <= '9')
    {
      state |= LEAD_INT;
      while (*ucp >= '0' && *ucp <= '9')
	ucp++;
    }
  if (*ucp == '.')
    {
      state |= DOT_CHAR;
      ucp++;
    }
  if (*ucp >= '0' && *ucp <= '9')
    {
      state |= TRAIL_INT;
      while (*ucp >= '0' && *ucp <= '9')
	ucp++;
    }
  if (*ucp == 'e' || *ucp == 'E')
    {
      state |= E_CHAR;
      ucp++;
      if ((*ucp == '+') || (*ucp == '-'))
	ucp++;
    }

  if (*ucp >= '0' && *ucp <= '9')
    {
      state |= EXP_INT;
      while (*ucp >= '0' && *ucp <= '9')
	ucp++;
    }
  return (((*ucp == 0) || (*ucp == ' ') || (*ucp == '\t') || (*ucp == '\n')
	   || (*ucp == '\r') || (*ucp == '\f'))
	  && (state == (LEAD_INT|DOT_CHAR|TRAIL_INT)
	      || state == (DOT_CHAR|TRAIL_INT)
	      || state == (LEAD_INT|E_CHAR|EXP_INT)
	      || state == (LEAD_INT|DOT_CHAR|TRAIL_INT|E_CHAR|EXP_INT)
	      || state == (DOT_CHAR|TRAIL_INT|E_CHAR|EXP_INT)));
}

int
isratio_string (const char *cp)
{
  /* Possible minus/plus sign */
  if (*cp == '-' || *cp == '+')
    cp++;

  /* Numerator */
  if (*cp < '0' || *cp > '9')
    return 0;

  do {
    cp++;
  } while (*cp >= '0' && *cp <= '9');

  /* Slash */
  if (*cp++ != '/')
    return 0;

  /* Denominator */
  if (*cp < '0' || *cp > '9')
    return 0;

  do {
    cp++;
  } while (*cp >= '0' && *cp <= '9');

  return *cp == '\0' || *cp == ' ' || *cp =='\t' || *cp == '\n' ||
    *cp == '\r' || *cp == '\f';
}


static void *
sequence_reader (Lisp_Object readcharfun,
                 Ichar terminator,
                 void *state,
                 void * (*conser) (Lisp_Object readcharfun,
                                   void *state, Charcount len))
{
  Charcount len;

  for (len = 0; ; len++)
    {
      Ichar ch;

      QUIT;
      ch = reader_nextchar (readcharfun);

      if (ch == terminator)
	return state;
      else
	unreadchar (readcharfun, ch);
#ifdef FEATUREP_SYNTAX
      if (ch == ']')
	read_syntax_error ("\"]\" in a list");
      else if (ch == ')')
	read_syntax_error ("\")\" in a vector");
#endif
      state = ((conser) (readcharfun, state, len));
    }
}


struct read_list_state
  {
    Lisp_Object head;
    Lisp_Object tail;
    int length;
    int allow_dotted_lists;
    Ichar terminator;
  };

static void *
read_list_conser (Lisp_Object readcharfun, void *state, Charcount UNUSED (len))
{
  struct read_list_state *s = (struct read_list_state *) state;
  Lisp_Object elt;

  elt = read1 (readcharfun);

  if (CONSP (elt) && UNBOUNDP (XCAR (elt)))
    {
      Lisp_Object tem = elt;
      Ichar ch;

      elt = XCDR (elt);
      free_cons (tem);
      tem = Qnil;
      ch = XCHAR (elt);
#ifdef FEATUREP_SYNTAX
      if (ch == s->terminator) /* deal with #+, #- reader macros */
	{
	  unreadchar (readcharfun, s->terminator);
	  goto done;
	}
      else if (ch == ']')
	read_syntax_error ("']' in a list");
      else if (ch == ')')
	read_syntax_error ("')' in a vector");
      else
#endif
      if (ch != '.')
	signal_error (Qinternal_error, "BUG! Internal reader error", elt);
      else if (!s->allow_dotted_lists)
	read_syntax_error ("\".\" in a vector");
      else
	{
	  if (!NILP (s->tail))
	    XCDR (s->tail) = read0 (readcharfun);
          else
	    s->head = read0 (readcharfun);
	  elt = read1 (readcharfun);
	  if (CONSP (elt) && UNBOUNDP (XCAR (elt)))
	    {
	      ch = XCHAR (XCDR (elt));
	      free_cons (elt);
	      if (ch == s->terminator)
		{
		  unreadchar (readcharfun, s->terminator);
		  goto done;
		}
	    }
	  read_syntax_error (". in wrong context");
	}
    }

  elt = Fcons (elt, Qnil);
  if (!NILP (s->tail))
    XCDR (s->tail) = elt;
  else
    s->head = elt;
  s->tail = elt;
 done:
  s->length++;
  return s;
}


/* allow_dotted_lists means that something like (foo bar . baz)
   is acceptable.  If -1, means check for starting with defun
   and make structure pure. (not implemented, probably for very
   good reasons)

   If check_for_doc_references, look for (#$ . INT) doc references
   in the list and record if load_force_doc_strings is non-zero.
   (Such doc references will be destroyed during the loadup phase
   by replacing with Qzero, because Snarf-documentation will fill
   them in again.)

   WARNING: If you set this, you sure as hell better not call
   free_list() on the returned list here.
   */

static Lisp_Object
read_list (Lisp_Object readcharfun,
           Ichar terminator,
           int allow_dotted_lists,
	   int check_for_doc_references)
{
  struct read_list_state s;
  struct gcpro gcpro1, gcpro2;

  s.head = Qnil;
  s.tail = Qnil;
  s.length = 0;
  s.allow_dotted_lists = allow_dotted_lists;
  s.terminator = terminator;
  GCPRO2 (s.head, s.tail);

  sequence_reader (readcharfun, terminator, &s, read_list_conser);

  if ((purify_flag || load_force_doc_strings) && check_for_doc_references)
    {
      /* check now for any doc string references and record them
	 for later. */
      Lisp_Object tail;

      /* We might be dealing with an imperfect list so don't
	 use LIST_LOOP */
      for (tail = s.head; CONSP (tail); tail = XCDR (tail))
	{
	  Lisp_Object holding_cons = Qnil;

	  {
	    Lisp_Object elem = XCAR (tail);
	    /* elem might be (#$ . INT) ... */
	    if (CONSP (elem) && EQ (XCAR (elem), Vload_file_name_internal))
	      holding_cons = tail;
	    /* or it might be (quote (#$ . INT)) i.e.
	       (quote . ((#$ . INT) . nil)) in the case of
	       `autoload' (autoload evaluates its arguments, while
	       `defvar', `defun', etc. don't). */
	    if (CONSP (elem) && EQ (XCAR (elem), Qquote)
		&& CONSP (XCDR (elem)))
	      {
		elem = XCAR (XCDR (elem));
		if (CONSP (elem) && EQ (XCAR (elem), Vload_file_name_internal))
		  holding_cons = XCDR (XCAR (tail));
	      }
	  }

	  if (CONSP (holding_cons))
	    {
	      if (purify_flag)
		{
		  if (NILP (Vinternal_doc_file_name))
		    /* We have not yet called Snarf-documentation, so
		       assume this file is described in the DOC file
		       and Snarf-documentation will fill in the right
		       value later.  For now, replace the whole list
		       with 0.  */
		    XCAR (holding_cons) = Qzero;
		  else
		    /* We have already called Snarf-documentation, so
		       make a relative file name for this file, so it
		       can be found properly in the installed Lisp
		       directory.  We don't use Fexpand_file_name
		       because that would make the directory absolute
		       now.  */
		    XCAR (XCAR (holding_cons)) =
		      concat2 (build_ascstring ("../lisp/"),
			       Ffile_name_nondirectory
			       (Vload_file_name_internal));
		}
	      else
		/* Not pure.  Just add to Vload_force_doc_string_list,
		   and the string will be filled in properly in
		   load_force_doc_string_unwind(). */
		Vload_force_doc_string_list =
		  /* We pass the cons that holds the (#$ . INT) so we
		     can modify it in-place. */
		  Fcons (holding_cons, Vload_force_doc_string_list);
	    }
	}
    }

  UNGCPRO;
  return s.head;
}

static Lisp_Object
read_vector (Lisp_Object readcharfun,
             Ichar terminator)
{
  Lisp_Object tem;
  Lisp_Object *p;
  int len;
  int i;
  struct read_list_state s;
  struct gcpro gcpro1, gcpro2;

  s.head = Qnil;
  s.tail = Qnil;
  s.length = 0;
  s.allow_dotted_lists = 0;
  GCPRO2 (s.head, s.tail);

  sequence_reader (readcharfun, terminator, &s, read_list_conser);

  UNGCPRO;
  tem = s.head;
  len = XFIXNUM (Flength (tem));

  s.head = make_vector (len, Qnil);

  for (i = 0, p = &(XVECTOR_DATA (s.head)[0]);
       i < len;
       i++, p++)
  {
    Lisp_Object otem = tem;
    tem = Fcar (tem);
    *p = tem;
    tem = XCDR (otem);
    free_cons (otem);
  }
  return s.head;
}

static Lisp_Object
read_compiled_function (Lisp_Object readcharfun, Ichar terminator)
{
  /* Accept compiled functions at read-time so that we don't
     have to build them at load-time. */
  Lisp_Object stuff;
  Lisp_Object make_byte_code_args[COMPILED_DOMAIN + 1];
  struct gcpro gcpro1;
  int len;
  int iii;
  int saw_a_doc_ref = 0;

  /* Note: we tell read_list not to search for doc references
     because we need to handle the "doc reference" for the
     instructions and constants differently. */
  stuff = read_list (readcharfun, terminator, 0, 0);
  len = XFIXNUM (Flength (stuff));
  if (len < COMPILED_STACK_DEPTH + 1 || len > COMPILED_DOMAIN + 1)
    return
      continuable_read_syntax_error ("#[...] used with wrong number of elements");

  for (iii = 0; CONSP (stuff); iii++)
    {
      Lisp_Object victim = stuff;
      make_byte_code_args[iii] = Fcar (stuff);
      if ((purify_flag || load_force_doc_strings)
	   && CONSP (make_byte_code_args[iii])
	  && EQ (XCAR (make_byte_code_args[iii]), Vload_file_name_internal))
	{
	  if (purify_flag && iii == COMPILED_DOC_STRING)
	    {
	      /* same as in read_list(). */
	      if (NILP (Vinternal_doc_file_name))
		make_byte_code_args[iii] = Qzero;
	      else
		XCAR (make_byte_code_args[iii]) =
		  concat2 (build_ascstring ("../lisp/"),
			   Ffile_name_nondirectory
			   (Vload_file_name_internal));
	    }
	  else
	    saw_a_doc_ref = 1;
	}
      stuff = Fcdr (stuff);
      free_cons (victim);
    }
  GCPRO1 (make_byte_code_args[0]);
  gcpro1.nvars = len;

  /* v18 or v19 bytecode file.  Need to Ebolify. */
  if (load_byte_code_version < 20 && VECTORP (make_byte_code_args[2]))
    ebolify_bytecode_constants (make_byte_code_args[2]);

  /* make-byte-code looks at purify_flag, which should have the same
   *  value as our "read-pure" argument */
  stuff = Fmake_byte_code (len, make_byte_code_args);
  XCOMPILED_FUNCTION (stuff)->flags.ebolified = (load_byte_code_version < 20);
  if (saw_a_doc_ref)
    Vload_force_doc_string_list = Fcons (stuff, Vload_force_doc_string_list);
  UNGCPRO;
  return stuff;
}



void
init_lread (void)
{
  Vvalues = Qnil;

  load_in_progress = 0;

  Vload_descriptor_list = Qnil;

  /* kludge: locate-file does not work for a null load-path, even if
     the file name is absolute. */

  Vload_path = Fcons (build_ascstring (""), Qnil);

  /* This used to get initialized in init_lread because all streams
     got closed when dumping occurs.  This is no longer true --
     Vread_buffer_stream is a resizing output stream, and there is no
     reason to close it at dump-time.

     Vread_buffer_stream is set to Qnil in vars_of_lread, and this
     will initialize it only once, at dump-time.  */
  if (NILP (Vread_buffer_stream))
    Vread_buffer_stream = make_resizing_buffer_output_stream ();

  Vload_force_doc_string_list = Qnil;

  Vload_file_name_internal = Qnil;
  Vload_file_name = Qnil;
}

void
syms_of_lread (void)
{
  DEFSUBR (Fread);
  DEFSUBR (Fread_from_string);
  DEFSUBR (Fload_internal);
  DEFSUBR (Flocate_file);
  DEFSUBR (Flocate_file_clear_hashing);
  DEFSUBR (Feval_buffer);
  DEFSUBR (Feval_region);

  DEFSYMBOL (Qstandard_input);
  DEFSYMBOL (Qread_char);
  DEFSYMBOL (Qload);
  DEFSYMBOL (Qload_internal);
  DEFSYMBOL (Qfset);

#ifdef LISP_BACKQUOTES
  DEFSYMBOL (Qbackquote);
  defsymbol (&Qbacktick, "`");
  defsymbol (&Qcomma, ",");
  defsymbol (&Qcomma_at, ",@");
  defsymbol (&Qcomma_dot, ",.");
#endif

  DEFSYMBOL (Qexists);
  DEFSYMBOL (Qreadable);
  DEFSYMBOL (Qwritable);
  DEFSYMBOL (Qexecutable);
}

void
structure_type_create (void)
{
  the_structure_type_dynarr = Dynarr_new (structure_type);
}

void
reinit_vars_of_lread (void)
{
  Vread_buffer_stream = Qnil;
  staticpro_nodump (&Vread_buffer_stream);
}

void
vars_of_lread (void)
{
  DEFVAR_LISP ("values", &Vvalues /*
List of values of all expressions which were read, evaluated and printed.
Order is reverse chronological.
*/ );

  DEFVAR_LISP ("standard-input", &Vstandard_input /*
Stream for read to get input from.
See documentation of `read' for possible values.
*/ );
  Vstandard_input = Qt;

  DEFVAR_LISP ("load-path", &Vload_path /*
*List of directories to search for files to load.
Each element is a string (directory name) or nil (try default directory).

Note that the elements of this list *may not* begin with "~", so you must
call `expand-file-name' on them before adding them to this list.

Initialized based on EMACSLOADPATH environment variable, if any,
otherwise to default specified in by file `paths.h' when XEmacs was built.
If there were no paths specified in `paths.h', then XEmacs chooses a default
value for this variable by looking around in the file-system near the
directory in which the XEmacs executable resides.
*/ );
  Vload_path = Qnil;

/*  xxxDEFVAR_LISP ("dump-load-path", &Vdump_load_path,
    "*Location of lisp files to be used when dumping ONLY."); */

  DEFVAR_BOOL ("load-in-progress", &load_in_progress /*
Non-nil iff inside of `load'.
*/ );

  DEFVAR_LISP ("load-suppress-alist", &Vload_suppress_alist /*
An alist of expressions controlling whether particular files can be loaded.
Each element looks like (FILENAME EXPR).
FILENAME should be a full pathname, but without the .el suffix.
When `load' is run and is about to load the specified file, it evaluates
the form to determine if the file can be loaded.
This variable is normally initialized automatically.
*/ );
  Vload_suppress_alist = Qnil;

  DEFVAR_LISP ("after-load-alist", &Vafter_load_alist /*
An alist of expressions to be evalled when particular files are loaded.
Each element looks like (FILENAME FORMS...).
When `load' is run and the file-name argument is FILENAME,
the FORMS in the corresponding element are executed at the end of loading.

FILENAME must match exactly!  Normally FILENAME is the name of a library,
with no directory specified, since that is how `load' is normally called.
An error in FORMS does not undo the load,
but does prevent execution of the rest of the FORMS.
*/ );
  Vafter_load_alist = Qnil;

  DEFVAR_BOOL ("load-warn-when-source-newer", &load_warn_when_source_newer /*
*Whether `load' should check whether the source is newer than the binary.
If this variable is true, then when a `.elc' file is being loaded and the
corresponding `.el' is newer, a warning message will be printed.
*/ );
  load_warn_when_source_newer = 1;

  DEFVAR_BOOL ("load-warn-when-source-only", &load_warn_when_source_only /*
*Whether `load' should warn when loading a `.el' file instead of an `.elc'.
If this variable is true, then when `load' is called with a filename without
an extension, and the `.elc' version doesn't exist but the `.el' version does,
then a message will be printed.  If an explicit extension is passed to `load',
no warning will be printed.
*/ );
  load_warn_when_source_only = 0;

  DEFVAR_BOOL ("load-ignore-elc-files", &load_ignore_elc_files /*
*Whether `load' should ignore `.elc' files when a suffix is not given.
This is normally used only to bootstrap the `.elc' files when building XEmacs.
*/ );
  load_ignore_elc_files = 0;

  DEFVAR_BOOL ("load-ignore-out-of-date-elc-files",
	       &load_ignore_out_of_date_elc_files /*
*Whether `load' should ignore out-of-date `.elc' files when no suffix is given.
This is normally used when compiling packages of elisp files that may have
complex dependencies.  Ignoring all elc files with `load-ignore-elc-files'
would also be safe, but much slower.
*/ );
  load_ignore_out_of_date_elc_files = 1;

  DEFVAR_BOOL ("load-always-display-messages",
	       &load_always_display_messages /*
*Whether `load' should always display loading messages.
If this is true, every file loaded will be shown, regardless of the setting
of the NOMESSAGE parameter, and even when files are loaded indirectly, e.g.
due to `require'.
*/ );
  load_always_display_messages = 0;

  DEFVAR_BOOL ("load-show-full-path-in-messages",
	       &load_show_full_path_in_messages /*
*Whether `load' should show the full path in all loading messages.
*/ );
  load_show_full_path_in_messages = 0;

#ifdef LOADHIST
  DEFVAR_LISP ("load-history", &Vload_history /*
Alist mapping source file names to symbols and features.
Each alist element is a list that starts with a file name,
except for one element (optional) that starts with nil and describes
definitions evaluated from buffers not visiting files.
The remaining elements of each list are symbols defined as functions
or variables, and cons cells `(provide . FEATURE)' and `(require . FEATURE)'.
*/ );
  Vload_history = Qnil;

  DEFVAR_LISP ("current-load-list", &Vcurrent_load_list /*
Used for internal purposes by `load'.
*/ );
  Vcurrent_load_list = Qnil;
#endif

  DEFVAR_LISP ("load-file-name", &Vload_file_name /*
Full name of file being loaded by `load'.
*/ );
  Vload_file_name = Qnil;

  DEFVAR_LISP ("load-read-function", &Vload_read_function /*
Function used by `load' and `eval-region' for reading expressions.
The default is nil, which means use the function `read'.
*/ );
  Vload_read_function = Qnil;

  DEFVAR_BOOL ("load-force-doc-strings", &load_force_doc_strings /*
Non-nil means `load' should force-load all dynamic doc strings.
This is useful when the file being loaded is a temporary copy.
*/ );
  load_force_doc_strings = 0;

  /* See read_escape().  */
#if 0
  /* Used to be named `puke-on-fsf-keys' */
  DEFVAR_BOOL ("fail-on-bucky-bit-character-escapes",
	       &fail_on_bucky_bit_character_escapes /*
Whether `read' should signal an error when it encounters unsupported
character escape syntaxes or just read them incorrectly.
*/ );
  fail_on_bucky_bit_character_escapes = 0;
#endif

  /* This must be initialized in init_lread otherwise it may start out
     with values saved when the image is dumped. */
  staticpro (&Vload_descriptor_list);

  /* Initialized in init_lread. */
  staticpro (&Vload_force_doc_string_list);

  Vload_file_name_internal = Qnil;
  staticpro (&Vload_file_name_internal);

  /* So that early-early stuff will work */
  Ffset (Qload,	Qload_internal);

#ifdef FEATUREP_SYNTAX
  DEFSYMBOL (Qfeaturep);
  Fprovide (intern ("xemacs"));
#endif /* FEATUREP_SYNTAX */

#ifdef LISP_BACKQUOTES
  old_backquote_flag = new_backquote_flag = 0;
#endif

#ifdef I18N3
  Vfile_domain = Qnil;
  staticpro (&Vfile_domain);
#endif

  Vread_objects = Qnil;
  staticpro (&Vread_objects);

  Vlocate_file_hash_table = make_lisp_hash_table (200,
						  HASH_TABLE_NON_WEAK,
#ifdef DEFAULT_FILE_SYSTEM_IGNORE_CASE
						  Qequalp
#else
						  Qequal
#endif
						  );
  staticpro (&Vlocate_file_hash_table);
#ifdef DEBUG_XEMACS
  symbol_value (XSYMBOL (intern ("Vlocate-file-hash-table")))
    = Vlocate_file_hash_table;
#endif
}
