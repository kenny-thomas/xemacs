/* TTY console functions.
   Copyright (C) 1994, 1995 Board of Trustees, University of Illinois.
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.
   Copyright (C) 1996, 2001, 2002 Ben Wing.

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

/* Authors: Ben Wing and Chuck Thompson. */

#include <config.h>
#include "lisp.h"

#include "console-tty-impl.h"
#include "console-stream.h"

#include "elhash.h"
#include "faces.h"
#include "file-coding.h"
#include "frame.h"
#include "glyphs.h"
#include "lstream.h"
#include "process.h"

#include "sysdep.h"
#include "sysfile.h"

DEFINE_CONSOLE_TYPE (tty);
DECLARE_IMAGE_INSTANTIATOR_FORMAT (nothing);
DECLARE_IMAGE_INSTANTIATOR_FORMAT (string);
DECLARE_IMAGE_INSTANTIATOR_FORMAT (formatted_string);
DECLARE_IMAGE_INSTANTIATOR_FORMAT (inherit);

Lisp_Object Qterminal_type;
Lisp_Object Qcontrolling_process;

Lisp_Object Vtty_seen_characters;

static const struct memory_description tty_console_data_description_1 [] = {
  { XD_LISP_OBJECT, offsetof (struct tty_console, terminal_type) },
  { XD_LISP_OBJECT, offsetof (struct tty_console, instream) },
  { XD_LISP_OBJECT, offsetof (struct tty_console, outstream) },
  { XD_END }
};

#ifdef NEW_GC
DEFINE_DUMPABLE_INTERNAL_LISP_OBJECT ("tty-console", tty_console,
				      0, tty_console_data_description_1,
				      Lisp_Tty_Console);
#else /* not NEW_GC */
const struct sized_memory_description tty_console_data_description = {
  sizeof (struct tty_console), tty_console_data_description_1
};
#endif /* not NEW_GC */


static void
allocate_tty_console_struct (struct console *con)
{
  /* zero out all slots except the lisp ones ... */
#ifdef NEW_GC
  CONSOLE_TTY_DATA (con) = XTTY_CONSOLE (ALLOC_NORMAL_LISP_OBJECT (tty_console));
#else /* not NEW_GC */
  CONSOLE_TTY_DATA (con) = xnew_and_zero (struct tty_console);
#endif /* not NEW_GC */
  CONSOLE_TTY_DATA (con)->terminal_type = Qnil;
  CONSOLE_TTY_DATA (con)->instream = Qnil;
  CONSOLE_TTY_DATA (con)->outstream = Qnil;
}

static void
tty_init_console (struct console *con, Lisp_Object props)
{
  Lisp_Object tty = CONSOLE_CONNECTION (con);
  Lisp_Object terminal_type = Qnil;
  Lisp_Object controlling_process = Qnil;
  struct tty_console *tty_con;
  struct gcpro gcpro1, gcpro2;

  GCPRO2 (terminal_type, controlling_process);

  terminal_type = Fplist_get (props, Qterminal_type, Qnil);
  controlling_process = Fplist_get (props, Qcontrolling_process, Qnil);

  /* Determine the terminal type */

  if (!NILP (terminal_type))
    CHECK_STRING (terminal_type);
  else
    {
      Ibyte *temp_type = egetenv ("TERM");

      if (!temp_type)
	{
	  invalid_state ("Cannot determine terminal type", Qunbound);
	}
      else
	terminal_type = build_istring (temp_type);
    }

  /* Determine the controlling process */
  if (!NILP (controlling_process))
    CHECK_FIXNUM (controlling_process);

  /* Open the specified console */

  allocate_tty_console_struct (con);
  tty_con = CONSOLE_TTY_DATA (con);

  if (internal_equal (tty, Vstdio_str, 0))
    {
      tty_con->infd  = fileno (stdin);
      tty_con->outfd = fileno (stdout);
      tty_con->is_stdio = 1;
    }
  else
    {
      tty_con->infd = tty_con->outfd =
	qxe_open (XSTRING_DATA (tty), O_RDWR);
      if (tty_con->infd < 0)
	signal_error (Qio_error, "Unable to open tty", tty);
      tty_con->is_stdio = 0;
    }

  /* set_descriptor_non_blocking (tty_con->infd); */
  tty_con->instream  = make_filedesc_input_stream  (tty_con->infd,  0, -1, 0,
						    NULL);
  Lstream_set_buffering (XLSTREAM (tty_con->instream), LSTREAM_UNBUFFERED, 0);
  tty_con->instream =
    make_coding_input_stream (XLSTREAM (tty_con->instream),
			      get_coding_system_for_text_file (Qkeyboard, 0),
			      CODING_DECODE,
			      LSTREAM_FL_READ_ONE_BYTE_AT_A_TIME);
  Lstream_set_buffering (XLSTREAM (tty_con->instream), LSTREAM_UNBUFFERED, 0);
  tty_con->outstream = make_filedesc_output_stream (tty_con->outfd, 0, -1, 0,
						    NULL);
  tty_con->outstream =
    make_coding_output_stream (XLSTREAM (tty_con->outstream),
			       get_coding_system_for_text_file (Qterminal, 0),
			       CODING_ENCODE, 0);
  tty_con->terminal_type = terminal_type;
  tty_con->controlling_process = controlling_process;

  /* Defaults to 1 with Mule, 0 without. In the latter case the attribute is
     read-only from Lisp. */
  tty_con->multiple_width = CONSOLE_TTY_SUPPORTS_MULTIPLE_WIDTH(c); 

  if (NILP (CONSOLE_NAME (con)))
    CONSOLE_NAME (con) = Ffile_name_nondirectory (tty);
  {
    pid_t tty_pg;
    pid_t controlling_tty_pg;
    int cfd;

    /* OK, the only sure-fire way I can think of to determine
       whether a particular TTY is our controlling TTY is to check
       if it has the same foreground process group as our controlling
       TTY.  This is OK because a process group can never simultaneously
       be the foreground process group of two TTY's (in that case it
       would have two controlling TTY's, which is not allowed). */

    EMACS_GET_TTY_PROCESS_GROUP (tty_con->infd, &tty_pg);
    cfd = qxe_open ((Ibyte *) "/dev/tty", O_RDWR, 0);
    EMACS_GET_TTY_PROCESS_GROUP (cfd, &controlling_tty_pg);
    retry_close (cfd);
    if (tty_pg == controlling_tty_pg)
      {
	tty_con->controlling_terminal = 1;
	Vcontrolling_terminal = wrap_console (con);
	munge_tty_process_group ();
      }
    else
      tty_con->controlling_terminal = 0;
  }

  UNGCPRO;
}

static void
tty_mark_console (struct console *con)
{
  struct tty_console *tty_con = CONSOLE_TTY_DATA (con);
  mark_object (tty_con->terminal_type);
  mark_object (tty_con->instream);
  mark_object (tty_con->outstream);
}

static int
tty_initially_selected_for_input (struct console *UNUSED (con))
{
  return 1;
}

static void
free_tty_console_struct (struct console *con)
{
  struct tty_console *tty_con = CONSOLE_TTY_DATA (con);
  if (tty_con)
    {
      if (tty_con->term_entry_buffer) /* allocated in term_init () */
	{
	  xfree (tty_con->term_entry_buffer);
	  tty_con->term_entry_buffer = NULL;
	}
#ifndef NEW_GC
      xfree (tty_con);
#endif /* not NEW_GC */
      CONSOLE_TTY_DATA (con) = NULL;
    }
}

static void
tty_delete_console (struct console *con)
{
  Lstream_close (XLSTREAM (CONSOLE_TTY_DATA (con)->instream));
  Lstream_close (XLSTREAM (CONSOLE_TTY_DATA (con)->outstream));
  if (!CONSOLE_TTY_DATA (con)->is_stdio)
    retry_close (CONSOLE_TTY_DATA (con)->infd);
  if (CONSOLE_TTY_DATA (con)->controlling_terminal)
    {
      Vcontrolling_terminal = Qnil;
      unmunge_tty_process_group ();
    }
  free_tty_console_struct (con);
}


static struct console *
decode_tty_console (Lisp_Object console)
{
  console = wrap_console (decode_console (console));
  CHECK_TTY_CONSOLE (console);
  return XCONSOLE (console);
}

DEFUN ("console-tty-terminal-type", Fconsole_tty_terminal_type,
       0, 1, 0, /*
Return the terminal type of TTY console CONSOLE.
*/
       (console))
{
  return CONSOLE_TTY_DATA (decode_tty_console (console))->terminal_type;
}

DEFUN ("console-tty-controlling-process", Fconsole_tty_controlling_process,
       0, 1, 0, /*
Return the controlling process of tty console CONSOLE.
*/
       (console))
{
  return CONSOLE_TTY_DATA (decode_tty_console (console))->controlling_process;
}


DEFUN ("console-tty-input-coding-system", Fconsole_tty_input_coding_system,
       0, 1, 0, /*
Return the input coding system of tty console CONSOLE.
*/
       (console))
{
  return coding_stream_detected_coding_system
    (XLSTREAM (CONSOLE_TTY_DATA (decode_tty_console (console))->instream));
}

DEFUN ("set-console-tty-input-coding-system", Fset_console_tty_input_coding_system,
       0, 2, 0, /*
Set the input coding system of tty console CONSOLE to CODESYS.
CONSOLE defaults to the selected console.
CODESYS defaults to the value of `keyboard-coding-system'.
*/
	(console, codesys))
{
  set_coding_stream_coding_system
    (XLSTREAM (CONSOLE_TTY_DATA (decode_tty_console (console))->instream),
     get_coding_system_for_text_file (NILP (codesys) ? Qkeyboard : codesys,
				      0));
  return Qnil;
}

DEFUN ("console-tty-output-coding-system", Fconsole_tty_output_coding_system,
       0, 1, 0, /*
Return TTY CONSOLE's output coding system.
*/
       (console))
{
  return coding_stream_coding_system
    (XLSTREAM (CONSOLE_TTY_DATA (decode_tty_console (console))->outstream));
}

DEFUN ("set-console-tty-output-coding-system", Fset_console_tty_output_coding_system,
       0, 2, 0, /*
Set the coding system of tty output of console CONSOLE to CODESYS.
CONSOLE defaults to the selected console.
CODESYS defaults to the value of `terminal-coding-system'.
*/
	(console, codesys))
{
  set_coding_stream_coding_system
    (XLSTREAM (CONSOLE_TTY_DATA (decode_tty_console (console))->outstream),
     get_coding_system_for_text_file (NILP (codesys) ? Qterminal : codesys,
				      0));
  /* Redraw tty */
  face_property_was_changed (Vdefault_face, Qfont, Qtty);
  return Qnil;
}

DEFUN ("console-tty-multiple-width", Fconsole_tty_multiple_width,
       0, 1, 0, /*
Return whether CONSOLE treats East Asian double-width chars as such. 

CONSOLE defaults to the selected console.  Without XEmacs support for
double-width characters, this always gives nil.
*/
       (console))
{
  return CONSOLE_TTY_MULTIPLE_WIDTH (decode_tty_console(console)) 
    ? Qt : Qnil;
}

DEFUN ("set-console-tty-multiple-width", Fset_console_tty_multiple_width,
       0, 2, 0, /*
Set whether CONSOLE treats East Asian double-width characters as such.

CONSOLE defaults to the selected console, and VALUE defaults to nil.
Without XEmacs support for double-width characters, this throws an error if
VALUE is non-nil.
*/
       (console, value))
{
  struct console *c = decode_tty_console (console);

  /* So people outside of East Asia can put (set-console-tty-multiple-width
     (selected-console) nil) in their init files, independent of whether
     Mule is enabled. */
  if (!CONSOLE_TTY_MULTIPLE_WIDTH (c) && NILP(value))
    {
      return Qnil;
    }

  if (!CONSOLE_TTY_SUPPORTS_MULTIPLE_WIDTH (c))
    {
      invalid_change 
	("No console support for double-width chars",
	 Fmake_symbol(CONSOLE_NAME(c)));
    }

  CONSOLE_TTY_DATA(c)->multiple_width = NILP(value) ? 0 : 1;

  return Qnil;
}

/* #### Move this function to lisp */
DEFUN ("set-console-tty-coding-system", Fset_console_tty_coding_system,
       0, 2, 0, /*
Set the input and output coding systems of tty console CONSOLE to CODESYS.
CONSOLE defaults to the selected console.
If CODESYS is nil, the values of `keyboard-coding-system' and
`terminal-coding-system' will be used for the input and
output coding systems of CONSOLE.
*/
	(console, codesys))
{
  Fset_console_tty_input_coding_system (console, codesys);
  Fset_console_tty_output_coding_system (console, codesys);
  return Qnil;
}


Lisp_Object
tty_semi_canonicalize_console_connection (Lisp_Object connection,
					  Error_Behavior errb)
{
  return stream_semi_canonicalize_console_connection (connection, errb);
}

Lisp_Object
tty_canonicalize_console_connection (Lisp_Object connection,
				     Error_Behavior errb)
{
  return stream_canonicalize_console_connection (connection, errb);
}

Lisp_Object
tty_semi_canonicalize_device_connection (Lisp_Object connection,
					 Error_Behavior errb)
{
  return stream_semi_canonicalize_console_connection (connection, errb);
}

Lisp_Object
tty_canonicalize_device_connection (Lisp_Object connection,
				    Error_Behavior errb)
{
  return stream_canonicalize_console_connection (connection, errb);
}

static Lisp_Object
tty_perhaps_init_unseen_key_defaults (struct console *UNUSED(con),
				      Lisp_Object key)
{
  Ichar val;
  extern Lisp_Object Vcurrent_global_map;

  if (SYMBOLP(key))
    {
      /* We've no idea what to default an unknown symbol to on the TTY. */
      return Qnil;
    }

  CHECK_CHAR(key);

  if (!(HASH_TABLEP(Vtty_seen_characters)))
    {
      /* All the keysyms we deal with are character objects; therefore, we
	 can use eq as the test without worrying. */
      Vtty_seen_characters = make_lisp_hash_table (128, HASH_TABLE_NON_WEAK,
					       Qeq);
    }

  /* Might give the user an opaque error if make_lisp_hash_table fails,
     but it won't crash. */
  CHECK_HASH_TABLE(Vtty_seen_characters);

  val = XCHAR(key);

  /* Same logic as in x_has_keysym; I'm not convinced it's always sane. */
  if (val < 0x80) 
    {
      return Qnil; 
    }

  if (!NILP(Fgethash(key, Vtty_seen_characters, Qnil)))
    {
      return Qnil;
    }

  if (NILP (Flookup_key (Vcurrent_global_map, key, Qnil))) 
    {
      Fputhash(key, Qt, Vtty_seen_characters);
      Fdefine_key (Vcurrent_global_map, key, Qself_insert_command); 
      return Qt; 
    }

  return Qnil;
}


/************************************************************************/
/*                            initialization                            */
/************************************************************************/

void
syms_of_console_tty (void)
{
  DEFSUBR (Fconsole_tty_terminal_type);
  DEFSUBR (Fconsole_tty_controlling_process);
  DEFSYMBOL (Qterminal_type);
  DEFSYMBOL (Qcontrolling_process);
  DEFSUBR (Fconsole_tty_output_coding_system);
  DEFSUBR (Fset_console_tty_output_coding_system);
  DEFSUBR (Fconsole_tty_input_coding_system);
  DEFSUBR (Fset_console_tty_input_coding_system);
  DEFSUBR (Fset_console_tty_coding_system);
  DEFSUBR (Fconsole_tty_multiple_width);
  DEFSUBR (Fset_console_tty_multiple_width);
}

void
console_type_create_tty (void)
{
  INITIALIZE_CONSOLE_TYPE (tty, "tty", "console-tty-p");

  /* console methods */
  CONSOLE_HAS_METHOD (tty, init_console);
  CONSOLE_HAS_METHOD (tty, mark_console);
  CONSOLE_HAS_METHOD (tty, initially_selected_for_input);
  CONSOLE_HAS_METHOD (tty, delete_console);
  CONSOLE_HAS_METHOD (tty, canonicalize_console_connection);
  CONSOLE_HAS_METHOD (tty, canonicalize_device_connection);
  CONSOLE_HAS_METHOD (tty, semi_canonicalize_console_connection);
  CONSOLE_HAS_METHOD (tty, semi_canonicalize_device_connection);
  CONSOLE_HAS_METHOD (tty, perhaps_init_unseen_key_defaults);
}

void
reinit_console_type_create_tty (void)
{
  REINITIALIZE_CONSOLE_TYPE (tty);
}

void
image_instantiator_format_create_glyphs_tty (void)
{
  IIFORMAT_VALID_CONSOLE (tty, nothing);
  IIFORMAT_VALID_CONSOLE (tty, string);
  IIFORMAT_VALID_CONSOLE (tty, formatted_string);
  IIFORMAT_VALID_CONSOLE (tty, inherit);
}

void
vars_of_console_tty (void)
{
  DEFVAR_LISP ("tty-seen-characters", &Vtty_seen_characters /*
Hash table of non-ASCII characters the TTY subsystem has seen.
*/ );
  Vtty_seen_characters = Qnil;
  Fprovide (Qtty);
}
