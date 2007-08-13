/* Definitions for asynchronous process control in XEmacs.
   Copyright (C) 1985, 1992, 1993, 1994 Free Software Foundation, Inc.

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

/* Synched up with: FSF 19.30. */

#ifndef _XEMACS_PROCESS_H_
#define _XEMACS_PROCESS_H_

#if defined (NO_SUBPROCESSES)
#undef XPROCESS
#undef CHECK_PROCESS
#undef XSETPROCESS
#define PROCESSP(x) 0
#define PROCESS_LIVE_P(x) 0
#define Fprocess_status(x) Qnil
#define Fget_process(x) Qnil
#define Fget_buffer_process(x) Qnil
#define kill_buffer_processes(x) 0
#define close_process_descs() 0
#define init_xemacs_process() 0
extern void wait_without_blocking (void);

#else /* not NO_SUBPROCESSES */

/* Only process.c needs to know about the guts of this */
struct Lisp_Process;

DECLARE_LRECORD (process, struct Lisp_Process);
#define XPROCESS(x) XRECORD (x, process, struct Lisp_Process)
#define XSETPROCESS(x, p) XSETRECORD (x, p, process)
#define PROCESSP(x) RECORDP (x, process)
#define GC_PROCESSP(x) GC_RECORDP (x, process)
#define CHECK_PROCESS(x) CHECK_RECORD (x, process)
#define PROCESS_LIVE_P(x) (XPROCESS(x)->infd >= 0)

#ifdef emacs

Lisp_Object Fget_process (Lisp_Object name);
Lisp_Object Fget_buffer_process (Lisp_Object name);
Lisp_Object Fprocessp (Lisp_Object object);
Lisp_Object Fprocess_status (Lisp_Object process);
Lisp_Object Fkill_process (Lisp_Object process,
			   Lisp_Object current_group);
Lisp_Object Fdelete_process (Lisp_Object process);
Lisp_Object Fopen_network_stream_internal (Lisp_Object name,
					   Lisp_Object buffer,
					   Lisp_Object host,
					   Lisp_Object service);
Lisp_Object Fprocess_kill_without_query (Lisp_Object, Lisp_Object);

Lisp_Object connect_to_file_descriptor (Lisp_Object name,
					Lisp_Object buffer,
					Lisp_Object infd,
					Lisp_Object outfd);
int connected_via_filedesc_p (struct Lisp_Process *p);
void kill_buffer_processes (Lisp_Object buffer);
void close_process_descs (void);

void set_process_filter (Lisp_Object proc,
			 Lisp_Object filter, int filter_does_read);

/* True iff we are about to fork off a synchronous process or if we
   are waiting for it.  */
extern volatile int synch_process_alive;

/* Nonzero => this is a string explaining death of synchronous subprocess.  */
extern CONST char *synch_process_death;

/* If synch_process_death is zero,
   this is exit code of synchronous subprocess.  */
extern int synch_process_retcode;


void update_process_status (Lisp_Object p,
			    Lisp_Object status_symbol,
			    int exit_code, int core_dumped);

void get_process_file_descriptors (struct Lisp_Process *p,
				   int *infd, int *outfd);
int get_process_selected_p (struct Lisp_Process *p);
void set_process_selected_p (struct Lisp_Process *p, int selected_p);

struct Lisp_Process *get_process_from_input_descriptor (int infd);

#ifdef HAVE_SOCKETS
int network_connection_p (Lisp_Object process);
#else
#define network_connection_p(x) 0
#endif

extern Lisp_Object Qrun, Qexit, Qopen, Qclosed;

/* Report all recent events of a change in process status
   (either run the sentinel or output a message).
   This is done while Emacs is waiting for keyboard input.  */
void status_notify (void);
void kick_status_notify (void);

void deactivate_process (Lisp_Object proc);

#ifdef VMS
void create_process (Lisp_Object process, char **new_argv,
		     CONST char *current_dir);
#endif

#ifdef WINDOWSNT
int
#else
void
#endif
child_setup (int in, int out, int err,
		  char **new_argv, CONST char *current_dir);

Charcount read_process_output (Lisp_Object proc);

CONST char *signal_name (int signum);

Lisp_Object canonicalize_host_name (Lisp_Object host);

#endif /* not NO_SUBPROCESSES */

/* The name of the file open to get a null file, or a data sink.
   VMS, MS-DOS, and OS/2 redefine this.  */
#ifndef NULL_DEVICE
#define NULL_DEVICE "/dev/null"
#endif

/* A string listing the possible suffixes used for executable files,
   separated by colons.  VMS, MS-DOS, and OS/2 redefine this.  */
#ifndef EXEC_SUFFIXES
#define EXEC_SUFFIXES ""
#endif

#endif /* emacs */

#endif /* _XEMACS_PROCESS_H_ */
