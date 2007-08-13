/* Synchronous subprocess invocation for XEmacs.
   Copyright (C) 1985, 86, 87, 88, 93, 94, 95 Free Software Foundation, Inc.

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

#include <config.h>
#include "lisp.h"

#include "buffer.h"
#include "commands.h"
#include "insdel.h"
#include "lstream.h"
#include "paths.h"
#include "process.h"
#include "sysdep.h"
#include "window.h"

#include "sysfile.h"
#include "systime.h"
#include "sysproc.h"
#include "syssignal.h" /* Always include before systty.h */
#include "systty.h"


#ifdef DOS_NT
/* When we are starting external processes we need to know whether they
   take binary input (no conversion) or text input (\n is converted to
   \r\n).  Similar for output: if newlines are written as \r\n then it's
   text process output, otherwise it's binary.  */
Lisp_Object Vbinary_process_input;
Lisp_Object Vbinary_process_output;
#endif /* DOS_NT */

Lisp_Object Vexec_path, Vexec_directory, Vdata_directory, Vdoc_directory;
Lisp_Object Vconfigure_info_directory;

/* The default base directory XEmacs is installed under. */
Lisp_Object Vprefix_directory;

Lisp_Object Vshell_file_name;

/* The environment to pass to all subprocesses when they are started.
   This is in the semi-bogus format of ("VAR=VAL" "VAR2=VAL2" ... )
 */
Lisp_Object Vprocess_environment;

/* True iff we are about to fork off a synchronous process or if we
   are waiting for it.  */
volatile int synch_process_alive;

/* Nonzero => this is a string explaining death of synchronous subprocess.  */
CONST char *synch_process_death;

/* If synch_process_death is zero,
   this is exit code of synchronous subprocess.  */
int synch_process_retcode;

/* Clean up when exiting Fcall_process_internal.
   On MSDOS, delete the temporary file on any kind of termination.
   On Unix, kill the process and any children on termination by signal.  */

/* Nonzero if this is termination due to exit.  */
static int call_process_exited;

#ifndef VMS  /* VMS version is in vmsproc.c.  */

static Lisp_Object
call_process_kill (Lisp_Object fdpid)
{
  Lisp_Object fd = Fcar (fdpid);
  Lisp_Object pid = Fcdr (fdpid);

  if (!NILP (fd))
    close (XINT (fd));

  if (!NILP (pid))
    EMACS_KILLPG (XINT (pid), SIGKILL);
  
  synch_process_alive = 0;
  return Qnil;
}

static Lisp_Object
call_process_cleanup (Lisp_Object fdpid)
{
#ifdef MSDOS
  /* for MSDOS fdpid is really (fd . tempfile)  */
  Lisp_Object file = Fcdr (fdpid);
  close (XINT (Fcar (fdpid)));
  if (strcmp (string_data (XSTRING (file)), NULL_DEVICE) != 0)
    unlink (string_data (XSTRING (file)));
#else /* not MSDOS */
  int fd = XINT (Fcar (fdpid));
  int pid = XINT (Fcdr (fdpid));

  if (!call_process_exited &&
      EMACS_KILLPG (pid, SIGINT) == 0)
  {
    int speccount = specpdl_depth ();

    record_unwind_protect (call_process_kill, fdpid);
    /* #### "c-G" -- need non-consing Single-key-description */
    message ("Waiting for process to die...(type C-g again to kill it instantly)");

    /* "Discard" the unwind protect.  */
    XCAR (fdpid) = Qnil;
    XCDR (fdpid) = Qnil;
    unbind_to (speccount, Qnil);

    message ("Waiting for process to die... done");
  }
  synch_process_alive = 0;
  close (fd);
#endif /* not MSDOS */
  return Qnil;
}

static Lisp_Object fork_error;
#if 0 /* UNUSED */
static void
report_fork_error (char *string, Lisp_Object data)
{
  Lisp_Object errstring = build_string (strerror (errno));

  /* System error messages are capitalized.  Downcase the initial. */
  set_string_char (XSTRING (errstring), 0,
		   DOWNCASE (current_buffer,
			     string_char (XSTRING (errstring), 0)));

  fork_error = Fcons (build_string (string), Fcons (errstring, data));

  /* terminate this branch of the fork, without closing stdin/out/etc. */
  _exit (1);
}
#endif /* unused */

DEFUN ("call-process-internal", Fcall_process_internal,
       Scall_process_internal, 1, MANY, 0 /*
Call PROGRAM synchronously in separate process, with coding-system specified.
Arguments are
 (PROGRAM &optional INFILE BUFFER DISPLAY &rest ARGS).
The program's input comes from file INFILE (nil means `/dev/null').
Insert output in BUFFER before point; t means current buffer;
 nil for BUFFER means discard it; 0 means discard and don't wait.
BUFFER can also have the form (REAL-BUFFER STDERR-FILE); in that case,
REAL-BUFFER says what to do with standard output, as above,
while STDERR-FILE says what to do with standard error in the child.
STDERR-FILE may be nil (discard standard error output),
t (mix it with ordinary output), or a file name string.

Fourth arg DISPLAY non-nil means redisplay buffer as output is inserted.
Remaining arguments are strings passed as command arguments to PROGRAM.

If BUFFER is 0, `call-process' returns immediately with value nil.
Otherwise it waits for PROGRAM to terminate and returns a numeric exit status
 or a signal description string.
If you quit, the process is killed with SIGINT, or SIGKILL if you
 quit again.
*/ )
  (nargs, args)
     int nargs;
     Lisp_Object *args;
{
  /* This function can GC */
  Lisp_Object infile, buffer, current_dir, display, path;
  int fd[2];
  int filefd;
  int pid;
  char buf[16384];
  char *bufptr = buf;
  int bufsize = 16384;
  int speccount = specpdl_depth ();
  char **new_argv
    = (char **) alloca ((max (2, nargs - 2)) * sizeof (char *));
  
  /* File to use for stderr in the child.
     t means use same as standard output.  */
  Lisp_Object error_file;
#ifdef MSDOS
  char *outf, *tempfile;
  int outfilefd;
#endif
  
  CHECK_STRING (args[0]);

  error_file = Qt;

#if defined (NO_SUBPROCESSES)
  /* Without asynchronous processes we cannot have BUFFER == 0.  */
  if (nargs >= 3 && !INTP (args[2]))
    error ("Operating system cannot handle asynchronous subprocesses");
#endif

  /* Do this before building new_argv because GC in Lisp code
   *  called by various filename-hacking routines might relocate strings */
  locate_file (Vexec_path, args[0], EXEC_SUFFIXES, &path, X_OK);

  /* Make sure that the child will be able to chdir to the current
     buffer's current directory, or its unhandled equivalent.  We
     can't just have the child check for an error when it does the
     chdir, since it's in a vfork. */
  {
    struct gcpro gcpro1, gcpro2;
    /* Do this test before building new_argv because GC in Lisp code 
     *  called by various filename-hacking routines might relocate strings */
    /* Make sure that the child will be able to chdir to the current
       buffer's current directory.  We can't just have the child check
       for an error when it does the chdir, since it's in a vfork.  */

    GCPRO2 (current_dir, path);   /* Caller gcprotects args[] */
    current_dir = current_buffer->directory;
    current_dir = expand_and_dir_to_file
      (Funhandled_file_name_directory (current_dir), Qnil);
#if 0
  /* I don't know how RMS intends this crock of shit to work, but it
     breaks everything in the presence of ange-ftp-visited files, so
     fuck it. */
    if (NILP (Ffile_accessible_directory_p (current_dir)))
      report_file_error ("Setting current directory",
                         Fcons (current_buffer->directory, Qnil));
#endif /* 0 */
    UNGCPRO;
  }

  if (nargs >= 2 && ! NILP (args[1]))
    {
      infile = Fexpand_file_name (args[1],
				  current_buffer->directory);
      CHECK_STRING (infile);
    }
  else
    infile = build_string (NULL_DEVICE);

  if (nargs >= 3)
    {
      buffer = args[2];

      /* If BUFFER is a list, its meaning is
	 (BUFFER-FOR-STDOUT FILE-FOR-STDERR).  */
      if (CONSP (buffer))
	{
	  if (CONSP (XCDR (buffer)))
	    {
	      Lisp_Object file_for_stderr = XCAR (XCDR (buffer));

	      if (NILP (file_for_stderr) || EQ (Qt, file_for_stderr))
		error_file = file_for_stderr;
	      else
		error_file = Fexpand_file_name (file_for_stderr, Qnil);
	    }

	  buffer = XCAR (buffer);
	}

      if (!(EQ (buffer, Qnil)
	    || EQ (buffer, Qt)
	    || ZEROP (buffer)))
	{
	  Lisp_Object spec_buffer;
	  spec_buffer = buffer;
	  buffer = Fget_buffer (buffer);
	  /* Mention the buffer name for a better error message.  */
	  if (NILP (buffer))
	    CHECK_BUFFER (spec_buffer);
	  CHECK_BUFFER (buffer);
	}
    }
  else 
    buffer = Qnil;

  display = ((nargs >= 4) ? args[3] : Qnil);

  /* From here we assume we won't GC (unless an error is signalled). */
  {
    REGISTER int i;
    for (i = 4; i < nargs; i++)
      {
	CHECK_STRING (args[i]);
	new_argv[i - 3] = (char *) string_data (XSTRING (args[i]));
      }
    /* Program name is first command arg */
    new_argv[0] = (char *) string_data (XSTRING (args[0]));
    new_argv[i - 3] = 0;
  }

  filefd = open ((char *) string_data (XSTRING (infile)), O_RDONLY, 0);
  if (filefd < 0)
    {
      report_file_error ("Opening process input file",
			 Fcons (infile, Qnil));
    }

  if (NILP (path))
    {
      close (filefd);
      report_file_error ("Searching for program",
			 Fcons (args[0], Qnil));
    }
  new_argv[0] = (char *) string_data (XSTRING (path));
  
#ifdef MSDOS
  /* These vars record information from process termination.
     Clear them now before process can possibly terminate,
     to avoid timing error if process terminates soon.  */
  synch_process_death = 0;
  synch_process_retcode = 0;

  if ((outf = egetenv ("TMP")) || (outf = egetenv ("TEMP")))
    strcpy (tempfile = alloca (strlen (outf) + 20), outf);
  else
    {
      tempfile = alloca (20);
      *tempfile = '\0';
    }
  dostounix_filename (tempfile);
  if (*tempfile == '\0' || tempfile[strlen (tempfile) - 1] != '/') 
    strcat (tempfile, "/");
  strcat (tempfile, "detmp.XXX");
  mktemp (tempfile);

  outfilefd = creat (tempfile, S_IREAD | S_IWRITE);
  if (outfilefd < 0)
    {
      close (filefd);
      report_file_error ("Opening process output file",
			 Fcons (tempfile, Qnil));
    }
#endif

#ifndef MSDOS
  if (INTP (buffer))
    {
      fd[1] = open (NULL_DEVICE, O_WRONLY, 0);
      fd[0] = -1;
    }
  else
    {
#ifdef WINDOWSNT
      pipe_with_inherited_out (fd);
#else  /* not WINDOWSNT */
      pipe (fd);
#endif /* not WINDOWSNT */
#if 0
      /* Replaced by close_process_descs */
      set_exclusive_use (fd[0]);
#endif
    }
#else /* MSDOS */
  {
    char *outf;

  if (INTP (buffer))
    outf = NULL_DEVICE;
  else 
    {
	/* DOS can't create pipe for interprocess communication, 
	   so redirect child process's standard output to temporary file
	   and later read the file. */
	
      if ((outf = egetenv ("TMP")) || (outf = egetenv ("TEMP")))
	{
	  strcpy (tempfile, outf);
	  dostounix_filename (tempfile);
	}
      else
        *tempfile = '\0';
      if (strlen (tempfile) == 0 || tempfile[strlen (tempfile) - 1] != '/')
	strcat (tempfile, "/");
      strcat (tempfile, "demacs.XXX");
      mktemp (tempfile);
      outf = tempfile;
    }

    if ((fd[1] = creat (outf, S_IREAD | S_IWRITE)) < 0)
      report_file_error ("Can't open temporary file", Qnil);
    fd[0] = -1;
    }
#endif /* MSDOS */

   {
     /* child_setup must clobber environ in systems with true vfork.
	Protect it from permanent change.  */
     REGISTER char **save_environ = environ;
     REGISTER int fd1 = fd[1];
     int fd_error = fd1;
     char **env;

#ifdef EMACS_BTL
    /* when performance monitoring is on, turn it off before the vfork(),
       as the child has no handler for the signal -- when back in the
       parent process, turn it back on if it was really on when you "turned
       it off" */
    int logging_on = cadillac_stop_logging ();
#endif

    env = environ;

    /* Record that we're about to create a synchronous process.  */
    synch_process_alive = 1;

    /* These vars record information from process termination.
       Clear them now before process can possibly terminate,
       to avoid timing error if process terminates soon.  */
    synch_process_death = 0;
    synch_process_retcode = 0;

#ifdef MSDOS
    /* ??? Someone who knows MSDOG needs to check whether this properly
       closes all descriptors that it opens.  */
    pid = run_msdos_command (new_argv, current_dir, filefd, outfilefd);
    close (outfilefd);
    fd1 = -1; /* No harm in closing that one!  */
    fd[0] = open (tempfile, NILP (Vbinary_process_output) ? O_TEXT :
			O_BINARY);
    if (fd[0] < 0)
      {
	unlink (tempfile);
	close (filefd);
	report_file_error ("Cannot re-open temporary file", Qnil);
      }
#else /* not MSDOS */
    if (NILP (error_file))
      fd_error = open (NULL_DEVICE, O_WRONLY);
    else if (STRINGP (error_file))
      {
#ifdef DOS_NT
	fd_error = open (string_data (XSTRING (error_file)),
			 O_WRONLY | O_TRUNC | O_CREAT | O_TEXT,
			 S_IREAD | S_IWRITE);
#else  /* not DOS_NT */
	fd_error =
	  creat ((CONST char *) string_data (XSTRING (error_file)), 0666);
#endif /* not DOS_NT */
      }

    if (fd_error < 0)
      {
	close (filefd);
	close (fd[0]);
	if (fd1 >= 0)
	  close (fd1);
	report_file_error ("Cannot open", error_file);
      }

    fork_error = Qnil;
#ifdef WINDOWSNT
    pid = child_setup (filefd, fd1, fd_error, new_argv, current_dir);
#else  /* not WINDOWSNT */
    pid = vfork ();

    if (pid == 0)
      {
	if (fd[0] >= 0)
	  close (fd[0]);
	/* This is necessary because some shells may attempt to
	   access the current controlling terminal and will hang
	   if they are run in the background, as will be the case
	   when XEmacs is started in the background.  Martin
	   Buchholz observed this problem running a subprocess
	   that used zsh to call gzip to uncompress an info
	   file. */
	disconnect_controlling_terminal ();
	child_setup (filefd, fd1, fd_error, new_argv,
		     (char *) string_data (XSTRING (current_dir)));
      }
#ifdef EMACS_BTL
    else if (logging_on)
      cadillac_start_logging ();
#endif

#endif /* not MSDOS */
#endif /* not WINDOWSNT */

    environ = save_environ;

    /* Close most of our fd's, but not fd[0]
       since we will use that to read input from.  */
    close (filefd);
    if (fd1 >= 0)
      close (fd1);
  }

  if (!NILP (fork_error))
    signal_error (Qfile_error, fork_error);

  if (pid < 0)
    {
      if (fd[0] >= 0)
	close (fd[0]);
      report_file_error ("Doing vfork", Qnil);
    }

  if (INTP (buffer))
    {
      if (fd[0] >= 0)
	close (fd[0]);
#if defined (NO_SUBPROCESSES)
      /* If Emacs has been built with asynchronous subprocess support,
	 we don't need to do this, I think because it will then have
	 the facilities for handling SIGCHLD.  */
      wait_without_blocking ();
#endif
      return Qnil;
    }

  {
    int nread;
    int first = 1;
    int total_read = 0;
    Lisp_Object instream;
    struct gcpro gcpro1;

    /* Enable sending signal if user quits below.  */
    call_process_exited = 0;

#ifdef MSDOS
    /* MSDOS needs different cleanup information.  */
    record_unwind_protect (call_process_cleanup,
                           Fcons (make_int (fd[0]),
                                  build_string (tempfile)));
#else
    record_unwind_protect (call_process_cleanup,
                           Fcons (make_int (fd[0]), make_int (pid)));
#endif /* not MSDOS */

    /* FSFmacs calls Fset_buffer() here.  We don't have to because
       we can insert into buffers other than the current one. */
    if (EQ (buffer, Qt))
      XSETBUFFER (buffer, current_buffer);
    instream = make_filedesc_input_stream (fd[0], 0, -1, LSTR_ALLOW_QUIT);
    GCPRO1 (instream);
    while (1)
      {
	QUIT;
	/* Repeatedly read until we've filled as much as possible
	   of the buffer size we have.  But don't read
	   less than 1024--save that for the next bufferfull.  */

	nread = 0;
	while (nread < bufsize - 1024)
	  {
	    int this_read
	      = Lstream_read (XLSTREAM (instream), bufptr + nread,
			      bufsize - nread);

	    if (this_read < 0)
	      goto give_up;

	    if (this_read == 0)
	      goto give_up_1;

	    nread += this_read;
	  }

      give_up_1:

	/* Now NREAD is the total amount of data in the buffer.  */
	if (nread == 0)
	  break;

	total_read += nread;
	
	if (!NILP (buffer))
	  buffer_insert_raw_string (XBUFFER (buffer), (Bufbyte *) bufptr,
				    nread);

	/* Make the buffer bigger as we continue to read more data,
	   but not past 64k.  */
	if (bufsize < 64 * 1024 && total_read > 32 * bufsize)
	  {
	    bufsize *= 2;
	    bufptr = (char *) alloca (bufsize);
	  }

	if (!NILP (display) && INTERACTIVE)
	  {
	    first = 0;
	    redisplay ();
	  }
      }
  give_up:
    Lstream_close (XLSTREAM (instream));
    UNGCPRO;

    QUIT;
#ifndef MSDOS
    /* Wait for it to terminate, unless it already has.  */
    wait_for_termination (pid);
#endif

    /* Don't kill any children that the subprocess may have left behind
       when exiting.  */
    call_process_exited = 1;
    unbind_to (speccount, Qnil);

    if (synch_process_death)
      return build_string (synch_process_death);
    return make_int (synch_process_retcode);
  }
}

#endif /* VMS */

#ifndef VMS /* VMS version is in vmsproc.c.  */

/* This is the last thing run in a newly forked inferior
   either synchronous or asynchronous.
   Copy descriptors IN, OUT and ERR as descriptors 0, 1 and 2.
   Initialize inferior's priority, pgrp, connected dir and environment.
   then exec another program based on new_argv.

   This function may change environ for the superior process.
   Therefore, the superior process must save and restore the value
   of environ around the vfork and the call to this function.

   ENV is the environment for the subprocess.

   XEmacs: We've removed the SET_PGRP argument because it's already
   done by the callers of child_setup.

   CURRENT_DIR is an elisp string giving the path of the current
   directory the subprocess should have.  Since we can't really signal
   a decent error from within the child, this should be verified as an
   executable directory by the parent.  */

static int relocate_fd (int fd, int min);

void
child_setup (int in, int out, int err, char **new_argv,
	     CONST char *current_dir)
{
#ifdef MSDOS
  /* The MSDOS port of gcc cannot fork, vfork, ... so we must call system
     instead.  */
#else /* not MSDOS */
  char **env;
  char *pwd;
#ifdef WINDOWSNT
  int cpid;
  HANDLE handles[4];
#endif /* WINDOWSNT */

#ifdef SET_EMACS_PRIORITY
  if (emacs_priority != 0)
    nice (- emacs_priority);
#endif

#if !defined (NO_SUBPROCESSES)
  /* Close Emacs's descriptors that this process should not have.  */
  close_process_descs ();
#endif
  close_load_descs ();

  /* Note that use of alloca is always safe here.  It's obvious for systems
     that do not have true vfork or that have true (stack) alloca.
     If using vfork and C_ALLOCA it is safe because that changes
     the superior's static variables as if the superior had done alloca
     and will be cleaned up in the usual way.  */
  {
    REGISTER int i;

    i = strlen (current_dir);
    pwd = (char *) alloca (i + 6);
    memcpy (pwd, "PWD=", 4);
    memcpy (pwd + 4, current_dir, i);
    i += 4;
    if (!IS_DIRECTORY_SEP (pwd[i - 1]))
      pwd[i++] = DIRECTORY_SEP;
    pwd[i] = 0;

    /* We can't signal an Elisp error here; we're in a vfork.  Since
       the callers check the current directory before forking, this
       should only return an error if the directory's permissions
       are changed between the check and this chdir, but we should
       at least check.  */
    if (chdir (pwd + 4) < 0)
      {
	/* Don't report the chdir error, or ange-ftp.el doesn't work. */
	/* (FSFmacs does _exit (errno) here.) */
	pwd = 0;
      }
    else
      {
	/* Strip trailing "/".  Cretinous *[]&@$#^%@#$% Un*x */
	/* leave "//" (from FSF) */
	while (i > 6 && IS_DIRECTORY_SEP (pwd[i - 1]))
	  pwd[--i] = 0;
      }
  }

  /* Set `env' to a vector of the strings in Vprocess_environment.  */
  {
    REGISTER Lisp_Object tem;
    REGISTER char **new_env;
    REGISTER int new_length;

    new_length = 0;
    for (tem = Vprocess_environment;
	 (CONSP (tem)
	  && STRINGP (XCAR (tem)));
	 tem = XCDR (tem))
      new_length++;

    /* new_length + 2 to include PWD and terminating 0.  */
    env = new_env = (char **) alloca ((new_length + 2) * sizeof (char *));

    /* If we have a PWD envvar and we know the real current directory,
       pass one down, but with corrected value.  */
    if (pwd && getenv ("PWD"))
      *new_env++ = pwd;

    /* Copy the Vprocess_environment strings into new_env.  */
    for (tem = Vprocess_environment;
	 (CONSP (tem)
	  && STRINGP (XCAR (tem)));
	 tem = XCDR (tem))
    {
      char **ep = env;
      char *string = (char *) string_data (XSTRING (XCAR (tem)));
      /* See if this string duplicates any string already in the env.
	 If so, don't put it in.
	 When an env var has multiple definitions,
	 we keep the definition that comes first in process-environment.  */
      for (; ep != new_env; ep++)
	{
	  char *p = *ep, *q = string;
	  while (1)
	    {
	      if (*q == 0)
		/* The string is malformed; might as well drop it.  */
		goto duplicate;
	      if (*q != *p)
		break;
	      if (*q == '=')
		goto duplicate;
	      p++, q++;
	    }
	}
      if (pwd && !strncmp ("PWD=", string, 4))
	{
	  *new_env++ = pwd;
	  pwd = 0;
	}
      else
        *new_env++ = string;
    duplicate: ;
    }
    *new_env = 0;
  }
#ifdef WINDOWSNT
  prepare_standard_handles (in, out, err, handles);
#else  /* not WINDOWSNT */
  /* Make sure that in, out, and err are not actually already in
     descriptors zero, one, or two; this could happen if Emacs is
     started with its standard in, out, or error closed, as might
     happen under X.  */
  {
    int oin = in, oout = out;

    /* We have to avoid relocating the same descriptor twice!  */

    in = relocate_fd (in, 3);

    if (out == oin) out = in;
    else            out = relocate_fd (out, 3);

    if      (err == oin)  err = in;
    else if (err == oout) err = out;
    else                  err = relocate_fd (err, 3);
  }

  close (0);
  close (1);
  close (2);

  dup2 (in,  0);
  dup2 (out, 1);
  dup2 (err, 2);
  
  close (in);
  close (out);
  close (err);

  /* I can't think of any reason why child processes need any more
     than the standard 3 file descriptors.  It would be cleaner to
     close just the ones that need to be, but the following brute
     force approach is certainly effective, and not too slow. */
  {
    int fd;
    for (fd=3; fd<=64; fd++)
      {
        close(fd);
      }
  }
#endif /* not WINDOWSNT */

#ifdef vipc
  something missing here;
#endif /* vipc */

#ifdef WINDOWSNT
  /* Spawn the child.  (See ntproc.c:Spawnve).  */
  cpid = spawnve (_P_NOWAIT, new_argv[0], new_argv, env);
  if (cpid == -1)
    /* An error occurred while trying to spawn the process.  */
    report_file_error ("Spawning child process", Qnil);
  reset_standard_handles (in, out, err, handles);
  return cpid;
#else /* not WINDOWSNT */
  /* execvp does not accept an environment arg so the only way
     to pass this environment is to set environ.  Our caller
     is responsible for restoring the ambient value of environ.  */
  environ = env;
  execvp (new_argv[0], new_argv);

  stdout_out ("Cant't exec program %s\n", new_argv[0]);
  _exit (1);
#endif /* not WINDOWSNT */
#endif /* not MSDOS */
}

/* Move the file descriptor FD so that its number is not less than MIN.
   If the file descriptor is moved at all, the original is freed.  */
static int
relocate_fd (int fd, int min)
{
  if (fd >= min)
    return fd;
  else
    {
      int new = dup (fd);
      if (new == -1)
	{
	  stderr_out ("Error while setting up child: %s\n",
		      strerror (errno));
	  _exit (1);
	}
      /* Note that we hold the original FD open while we recurse,
	 to guarantee we'll get a new FD if we need it.  */
      new = relocate_fd (new, min);
      close (fd);
      return new;
    }
}

static int
getenv_internal (CONST Bufbyte *var,
		 Bytecount varlen,
		 Bufbyte **value,
		 Bytecount *valuelen)
{
  Lisp_Object scan;

  for (scan = Vprocess_environment; CONSP (scan); scan = XCDR (scan))
    {
      Lisp_Object entry = XCAR (scan);
      
      if (STRINGP (entry)
	  && string_length (XSTRING (entry)) > varlen
	  && string_byte (XSTRING (entry), varlen) == '='
#ifdef WINDOWSNT
	  /* NT environment variables are case insensitive.  */
	  && ! memicmp (string_data (XSTRING (entry)), var, varlen)
#else  /* not WINDOWSNT */
	  && ! memcmp (string_data (XSTRING (entry)), var, varlen)
#endif /* not WINDOWSNT */
	  )
	{
	  *value    = string_data (XSTRING (entry)) + (varlen + 1);
	  *valuelen = string_length (XSTRING (entry)) - (varlen + 1);
	  return 1;
	}
    }

  return 0;
}

DEFUN ("getenv", Fgetenv, Sgetenv, 1, 2, "sEnvironment variable: \np" /*
Return the value of environment variable VAR, as a string.
VAR is a string, the name of the variable.
When invoked interactively, prints the value in the echo area.
*/ )
     (var, interactivep)
     Lisp_Object var, interactivep;
{
  Bufbyte *value;
  Bytecount valuelen;
  Lisp_Object v = Qnil;
  struct gcpro gcpro1;

  CHECK_STRING (var);
  GCPRO1 (v);
  if (getenv_internal (string_data (XSTRING (var)),
		       string_length (XSTRING (var)),
		       &value, &valuelen))
    v = make_string (value, valuelen);
  if (!NILP (interactivep))
    {
      if (NILP (v))
	message ("%s not defined in environment",
		 string_data (XSTRING (var)));
      else
	message ("\"%s\"", value);
    }
  RETURN_UNGCPRO (v);
}

/* A version of getenv that consults process_environment, easily
   callable from C.  */
char *
egetenv (CONST char *var)
{
  Bufbyte *value;
  Bytecount valuelen;

  if (getenv_internal ((CONST Bufbyte *) var, strlen (var), &value, &valuelen))
    return (char *) value;
  else
    return 0;
}
#endif /* not VMS */


void
init_callproc (void)
{
  /* This function can GC */
  REGISTER char *sh;
  Lisp_Object tempdir;

  Vprocess_environment = Qnil;
  /* jwz: always initialize Vprocess_environment, so that egetenv() works
     in temacs. */
  {
    char **envp;
    for (envp = environ; envp && *envp; envp++)
      Vprocess_environment = Fcons (build_ext_string (*envp, FORMAT_OS),
				    Vprocess_environment);
  }

  /* jwz: don't do these things when in temacs (this used to be the case by
     virtue of egetenv() always returning 0, but that has been changed).
   */
#ifndef CANNOT_DUMP
  if (!initialized)
    {
      Vdata_directory = Qnil;
      Vdoc_directory = Qnil;
      Vexec_path = Qnil;
    }
  else
#endif
    {
      char *data_dir = egetenv ("EMACSDATA");
      char *doc_dir = egetenv ("EMACSDOC");
    
#ifdef PATH_DATA
      if (!data_dir)
	data_dir = (char *) PATH_DATA;
#endif
#ifdef PATH_DOC
      if (!doc_dir)
	doc_dir = (char *) PATH_DOC;
#endif
    
      if (data_dir)
	Vdata_directory = Ffile_name_as_directory
	  (build_string (data_dir));
      else
	Vdata_directory = Qnil;
      if (doc_dir)
	Vdoc_directory = Ffile_name_as_directory
	  (build_string (doc_dir));
      else
	Vdoc_directory = Qnil;

      /* Check the EMACSPATH environment variable, defaulting to the
	 PATH_EXEC path from paths.h.  */
      Vexec_path = decode_env_path ("EMACSPATH",
#ifdef PATH_EXEC
				    PATH_EXEC
#else
				    0
#endif
				    );
    }

  if (NILP (Vexec_path))
    Vexec_directory = Qnil;
      else
    Vexec_directory = Ffile_name_as_directory
      (Fcar (Vexec_path));

  if (initialized)
    Vexec_path = nconc2 (decode_env_path ("PATH", 0),
                         Vexec_path);

  if (!NILP (Vexec_directory))
    {
      tempdir = Fdirectory_file_name (Vexec_directory);
      if (access ((char *) string_data (XSTRING (tempdir)), 0) < 0)
	{
	  /* If the hard-coded path is bogus, fail silently.
	     This will allow the normal heuristics to make an attempt. */
#if 0
	  warn_when_safe
	    (Qpath, Qwarning,
	     "Warning: machine-dependent data dir (%s) does not exist.\n",
	     string_data (XSTRING (Vexec_directory)));
#else
	  Vexec_directory = Qnil;
#endif
	}
    }

  if (!NILP (Vdata_directory))
    {
      tempdir = Fdirectory_file_name (Vdata_directory);
      if (access ((char *) string_data (XSTRING (tempdir)), 0) < 0)
	{
	  /* If the hard-coded path is bogus, fail silently.
	     This will allow the normal heuristics to make an attempt. */
#if 0
	  warn_when_safe
	    (Qpath, Qwarning,
	     "Warning: machine-independent data dir (%s) does not exist.\n",
	     string_data (XSTRING (Vdata_directory)));
#else
	  Vdata_directory = Qnil;
#endif
	}
    }
  
#ifdef PATH_PREFIX
  Vprefix_directory = build_string ((char *) PATH_PREFIX);
#else
  Vprefix_directory = Qnil;
#endif

#ifdef VMS
  Vshell_file_name = build_string ("*dcl*");
#else /* not VMS */
  sh = (char *) egetenv ("SHELL");
#ifdef DOS_NT
  if (!sh) sh = egetenv ("COMSPEC");
  {
    char *tem;
    if (sh)
      {
	tem = (char *) alloca (strlen (sh) + 1);
	sh = dostounix_filename (strcpy (tem, sh));
      }
  }
  Vshell_file_name = build_string (sh ? sh : "/command.com");
#else /* not DOS_NT */
  Vshell_file_name = build_string (sh ? sh : "/bin/sh");
#endif /* not DOS_NT */
#endif /* not VMS */
}

#if 0
void
set_process_environment (void)
{
  REGISTER char **envp;

  Vprocess_environment = Qnil;
#ifndef CANNOT_DUMP
  if (initialized)
#endif
    for (envp = environ; *envp; envp++)
      Vprocess_environment = Fcons (build_string (*envp),
				    Vprocess_environment);
}
#endif /* unused */

void
syms_of_callproc (void)
{
#ifndef VMS
  defsubr (&Scall_process_internal);
  defsubr (&Sgetenv);
#endif
}

void
vars_of_callproc (void)
{
  /* This function can GC */
#ifdef DOS_NT
  DEFVAR_LISP ("binary-process-input", &Vbinary_process_input /*
*If non-nil then new subprocesses are assumed to take binary input.
*/ );
  Vbinary_process_input = Qnil;

  DEFVAR_LISP ("binary-process-output", &Vbinary_process_output /*
*If non-nil then new subprocesses are assumed to produce binary output.
*/ );
  Vbinary_process_output = Qnil;
#endif /* DOS_NT */

  DEFVAR_LISP ("shell-file-name", &Vshell_file_name /*
*File name to load inferior shells from.
Initialized from the SHELL environment variable.
*/ );

  DEFVAR_LISP ("exec-path", &Vexec_path /*
*List of directories to search programs to run in subprocesses.
Each element is a string (directory name) or nil (try default directory).
*/ );

  DEFVAR_LISP ("exec-directory", &Vexec_directory /*
Directory of architecture-dependent files that come with XEmacs,
especially executable programs intended for Emacs to invoke.
*/ );

  DEFVAR_LISP ("data-directory", &Vdata_directory /*
Directory of architecture-independent files that come with XEmacs,
intended for Emacs to use.
*/ );

  /* FSF puts the DOC file into data-directory.  They do a bunch of
     contortions to attempt to put everything into the DOC file
     whether the support is there or not. */
  DEFVAR_LISP ("doc-directory", &Vdoc_directory /*
Directory containing the DOC file that comes with XEmacs.
This is usually the same as exec-directory.
*/ );

  DEFVAR_LISP ("prefix-directory", &Vprefix_directory /*
The default directory under which XEmacs is installed.
*/ );

  DEFVAR_LISP ("process-environment", &Vprocess_environment /*
List of environment variables for subprocesses to inherit.
Each element should be a string of the form ENVVARNAME=VALUE.
The environment which Emacs inherits is placed in this variable
when Emacs starts.
*/ );
}

void
complex_vars_of_callproc (void)
{
  DEFVAR_LISP ("configure-info-directory", &Vconfigure_info_directory /*
For internal use by the build procedure only.
This is the name of the directory in which the build procedure installed
Emacs's info files; the default value for Info-default-directory-list
includes this.
*/ );
#ifdef PATH_INFO
  Vconfigure_info_directory =
    Ffile_name_as_directory (build_string (PATH_INFO));
#else
  Vconfigure_info_directory = Qnil;
#endif
}