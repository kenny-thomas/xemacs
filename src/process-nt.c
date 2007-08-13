/* Asynchronous subprocess implemenation for Win32
   Copyright (C) 1985, 1986, 1987, 1988, 1992, 1993, 1994, 1995
   Free Software Foundation, Inc.
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

/* Written by Kirill M. Katsnelson <kkm@kis.ru>, April 1998 */

#include <config.h>
#include "lisp.h"

#include "hash.h"
#include "lstream.h"
#include "process.h"
#include "procimpl.h"
#include "sysdep.h"

#include <windows.h>
#include <shellapi.h>

/* Implemenation-specific data. Pointed to by Lisp_Process->process_data */
struct nt_process_data
{
  HANDLE h_process;
};

#define NT_DATA(p) ((struct nt_process_data*)((p)->process_data))

/*-----------------------------------------------------------------------*/
/* Process helpers							 */
/*-----------------------------------------------------------------------*/

/* This one breaks process abstraction. Prototype is in console-msw.h,
   used by select_process method in event-msw.c */
HANDLE
get_nt_process_handle (struct Lisp_Process *p)
{
  return (NT_DATA (p)->h_process);
}

/*-----------------------------------------------------------------------*/
/* Process methods							 */
/*-----------------------------------------------------------------------*/

/*
 * Allocate and initialize Lisp_Process->process_data
 */

static void
nt_alloc_process_data (struct Lisp_Process *p)
{
  p->process_data = xnew (struct nt_process_data);
}

#if 0 /* #### Need this method? */
/*
 * Mark any Lisp objects in Lisp_Process->process_data
 */

static void
nt_mark_process_data (struct Lisp_Process *proc,
			void (*markobj) (Lisp_Object))
{
}
#endif

static void
nt_finalize_process_data (struct Lisp_Process *p, int for_disksave)
{
  assert (!for_disksave);
  if (NT_DATA(p)->h_process)
    CloseHandle (NT_DATA(p)->h_process);
}

#if 0 /* #### Need this method? */
/*
 * Initialize XEmacs process implemenation once
 */

static void
nt_init_process (void)
{
}
#endif

#if 0 /* #### Need this method? */
/*
 * Initialize any process local data. This is called when newly
 * created process is connected to real OS file handles. The
 * handles are generally represented by void* type, but are
 * of type HANDLE for Win32
 */

static void
nt_init_process_io_handles (struct Lisp_Process *p, void* in, void* out, int flags)
{
}
#endif

/*
 * Fork off a subprocess. P is a pointer to newly created subprocess
 * object. If this function signals, the caller is responsible for
 * deleting (and finalizing) the process object.
 *
 * The method must return PID of the new proces, a (positive??? ####) number
 * which fits into Lisp_Int. No return value indicates an error, the method
 * must signal an error instead.
 */

/* #### This function completely ignores Vprocess_environment */

static void
signal_cannot_launch (char* image_file, DWORD err)
{
  mswindows_set_errno (err);
  error ("Starting \"%s\": %s", image_file, strerror (errno));
}

static int
nt_create_process (struct Lisp_Process *p,
		   char **argv, CONST char *current_dir)
{
  HANDLE hmyshove, hmyslurp, hprocin, hprocout;
  LPTSTR command_line;
  BOOL do_io, windowed;

  /* Find out whether the application is windowed or not */
  {
    /* SHGetFileInfo tends to return ERROR_FILE_NOT_FOUND on most
       errors. This leads to bogus error message. */
    DWORD image_type = SHGetFileInfo (argv[0], 0, NULL, 0, SHGFI_EXETYPE);
    if (image_type == 0)
      signal_cannot_launch (argv[0], (GetLastError () == ERROR_FILE_NOT_FOUND
				      ? ERROR_BAD_FORMAT : GetLastError ()));
    windowed = HIWORD (image_type) != 0;
  }

  /* Decide whether to do I/O on process handles, or just mark the
     process exited immediately upon successful launching. We do I/O if the
     process is a console one, or if it is windowed but windowed_process_io
     is non-zero */
  do_io = !windowed || windowed_process_io ;
  
  if (do_io)
    {
      /* Create two unidirectional named pipes */
      HANDLE htmp;
      SECURITY_ATTRIBUTES sa;

      sa.nLength = sizeof(sa);
      sa.bInheritHandle = TRUE;
      sa.lpSecurityDescriptor = NULL;

      CreatePipe (&hprocin, &hmyshove, &sa, 0);
      CreatePipe (&hmyslurp, &hprocout, &sa, 0);

      /* Stupid Win32 allows to create a pipe with *both* ends either
	 inheritable or not. We need process ends inheritable, and local
	 ends not inheritable. */
      DuplicateHandle (GetCurrentProcess(), hmyshove, GetCurrentProcess(), &htmp,
		       0, FALSE, DUPLICATE_CLOSE_SOURCE | DUPLICATE_SAME_ACCESS);
      hmyshove = htmp;
      DuplicateHandle (GetCurrentProcess(), hmyslurp, GetCurrentProcess(), &htmp,
		       0, FALSE, DUPLICATE_CLOSE_SOURCE | DUPLICATE_SAME_ACCESS);
      hmyslurp = htmp;
    }

  /* Convert an argv vector into Win32 style command line.

     #### This works only for cmd, and not for cygwin bash.  Perhaps,
     instead of ad-hoc fiddling with different methods for quoting
     process arguments in ntproc.c (disgust shudder), this must call a
     smart lisp routine. The code here will be a fallback, if the
     lisp function is not specified.
  */
  {
    char** thisarg;
    size_t size = 1;

    for (thisarg = argv; *thisarg; ++thisarg)
      size += strlen (*thisarg) + 1;

    command_line = alloca_array (char, size);
    *command_line = 0;

    for (thisarg = argv; *thisarg; ++thisarg)
      {
	if (thisarg != argv)
	  strcat (command_line, " ");
	strcat (command_line, *thisarg);
      }
  }

  /* Create process */
  {
    STARTUPINFO si;
    PROCESS_INFORMATION pi;
    DWORD err;

    xzero (si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = windowed ? SW_SHOWNORMAL : SW_HIDE;
    if (do_io)
      {
	si.hStdInput = hprocin;
	si.hStdOutput = hprocout;
	si.hStdError = hprocout;
	si.dwFlags |= STARTF_USESTDHANDLES;
      }

    err = (CreateProcess (NULL, command_line, NULL, NULL, TRUE,
			  CREATE_NEW_CONSOLE | CREATE_NEW_PROCESS_GROUP,
			  NULL, current_dir, &si, &pi)
	   ? 0 : GetLastError ());

    if (do_io)
      {
	/* These just have been inherited; we do not need a copy */
	CloseHandle (hprocin);
	CloseHandle (hprocout);
      }
    
    /* Handle process creation failure */
    if (err)
      {
	if (do_io)
	  {
	    CloseHandle (hmyshove);
	    CloseHandle (hmyslurp);
	  }
	signal_cannot_launch (argv[0], GetLastError ());
      }

    /* The process started successfully */
    if (do_io)
      {
	NT_DATA(p)->h_process = pi.hProcess;
	init_process_io_handles (p, (void*)hmyslurp, (void*)hmyshove, 0);
      }
    else
      {
	/* Indicate as if the process has exited immediately. */
	p->status_symbol = Qexit;
	CloseHandle (pi.hProcess);
      }

    CloseHandle (pi.hThread);

    /* Hack to support Windows 95 negative pids */
    return ((int)pi.dwProcessId < 0
	    ? -(int)pi.dwProcessId : (int)pi.dwProcessId);
  }
}

/* 
 * This method is called to update status fields of the process
 * structure. If the process has not existed, this method is expected
 * to do nothing.
 *
 * The method is called only for real child processes.  
 */

static void
nt_update_status_if_terminated (struct Lisp_Process* p)
{
  DWORD exit_code;
  if (GetExitCodeProcess (NT_DATA(p)->h_process, &exit_code)
      && exit_code != STILL_ACTIVE)
    {
      p->tick++;
      p->core_dumped = 0;
      /* The exit code can be a code returned by process, or an
	 NTSTATUS value. We cannot accurately handle the latter since
	 it is a full 32 bit integer */
      if (exit_code & 0xC0000000)
	{
	  p->status_symbol = Qsignal;
	  p->exit_code = exit_code & 0x1FFFFFFF;
	}
      else
	{
	  p->status_symbol = Qexit;
	  p->exit_code = exit_code;
	}
    }
}

/*
 * Stuff the entire contents of LSTREAM to the process ouptut pipe
 */

/* #### If only this function could be somehow merged with
   unix_send_process... */

static void
nt_send_process (Lisp_Object proc, struct lstream* lstream)
{
  struct Lisp_Process *p = XPROCESS (proc);

  /* use a reasonable-sized buffer (somewhere around the size of the
     stream buffer) so as to avoid inundating the stream with blocked
     data. */
  Bufbyte chunkbuf[512];
  Bytecount chunklen;

  while (1)
    {
      int writeret;

      chunklen = Lstream_read (lstream, chunkbuf, 512);
      if (chunklen <= 0)
	break; /* perhaps should abort() if < 0?
		  This should never happen. */

      /* Lstream_write() will never successfully write less than the
	 amount sent in.  In the worst case, it just buffers the
	 unwritten data. */
      writeret = Lstream_write (XLSTREAM (DATA_OUTSTREAM(p)), chunkbuf,
				chunklen);
      if (writeret < 0)
	{
	  p->status_symbol = Qexit;
	  p->exit_code = ERROR_BROKEN_PIPE;
	  p->core_dumped = 0;
	  p->tick++;
	  process_tick++;
	  deactivate_process (proc);
	  error ("Broken pipe error sending to process %s; closed it",
		 XSTRING_DATA (p->name));
	}

      while (Lstream_was_blocked_p (XLSTREAM (p->pipe_outstream)))
	{
	  /* Buffer is full.  Wait, accepting input; that may allow
	     the program to finish doing output and read more.  */
	  Faccept_process_output (Qnil, make_int (1), Qnil);
	  Lstream_flush (XLSTREAM (p->pipe_outstream));
	}
    }
  Lstream_flush (XLSTREAM (DATA_OUTSTREAM(p)));
}

/*-----------------------------------------------------------------------*/
/* Initialization							 */
/*-----------------------------------------------------------------------*/

void
process_type_create_nt (void)
{
  PROCESS_HAS_METHOD (nt, alloc_process_data);
  PROCESS_HAS_METHOD (nt, finalize_process_data);
  /*  PROCESS_HAS_METHOD (nt, mark_process_data); */
  /* PROCESS_HAS_METHOD (nt, init_process); */
  /* PROCESS_HAS_METHOD (nt, init_process_io_handles); */
  PROCESS_HAS_METHOD (nt, create_process);
  PROCESS_HAS_METHOD (nt, update_status_if_terminated);
  PROCESS_HAS_METHOD (nt, send_process);
  /* PROCESS_HAS_METHOD (nt, kill_child_process); */
  /* PROCESS_HAS_METHOD (nt, kill_process_by_pid); */
#if 0 /* Yet todo */
#ifdef HAVE_SOCKETS
  PROCESS_HAS_METHOD (nt, canonicalize_host_name);
  PROCESS_HAS_METHOD (nt, open_network_stream);
#ifdef HAVE_MULTICAST
  PROCESS_HAS_METHOD (nt, open_multicast_group);
#endif
#endif
#endif
}

void
vars_of_process_nt (void)
{
}

