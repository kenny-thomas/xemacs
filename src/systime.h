/* systime.h - System-dependent definitions for time manipulations.
   Copyright (C) 1992, 1993, 1994 Free Software Foundation, Inc.

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

#ifndef _XEMACS_SYSTIME_H_
#define _XEMACS_SYSTIME_H_

#ifdef TIME_WITH_SYS_TIME
#include <sys/time.h>
#include <time.h>
#else
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#else
#include <time.h>
#endif
#endif

#if defined(WINDOWSNT) && defined(HAVE_X_WINDOWS)
/* Provides gettimeofday etc */
#include <X11/Xw32defs.h>
#include <X11/Xos.h>
#endif

#ifdef HAVE_UTIME_H
# include <utime.h>
#endif

#ifdef HAVE_TZNAME
#ifndef tzname		/* For SGI.  */
extern char *tzname[];	/* RS6000 and others want it this way.  */
#endif
#endif

/* On some configurations (hpux8.0, X11R4), sys/time.h and X11/Xos.h
   disagree about the name of the guard symbol.  */
#ifdef HPUX
#ifdef _STRUCT_TIMEVAL
#ifndef __TIMEVAL__
#define __TIMEVAL__
#endif
#endif
#endif

/* EMACS_TIME is the type to use to represent temporal intervals.
   At one point this was 'struct timeval' on some systems, int on others.
   But this is stupid.  Other things than select() code like to
   manipulate time values, and so microsecond precision should be
   maintained.  Separate typedefs and conversion functions are provided
   for select().

   EMACS_SECS (TIME) is an rvalue for the seconds component of TIME.
   EMACS_SET_SECS (TIME, SECONDS) sets that to SECONDS.

   EMACS_USECS (TIME) is an rvalue for the microseconds component of TIME.
   EMACS_SET_USECS (TIME, MICROSECONDS) sets that to MICROSECONDS.

   Note that all times are returned in "normalized" format (i.e. the
   usecs value is in the range 0 <= value < 1000000) and are assumed
   to be passed in in this format.

   EMACS_SET_SECS_USECS (TIME, SECS, USECS) sets both components of TIME.

   EMACS_GET_TIME (TIME) stores the current system time in TIME, which
	should be an lvalue.

   set_file_times (PATH, ATIME, MTIME) changes the last-access and
	last-modification times of the file named PATH to ATIME and
	MTIME, which are EMACS_TIMEs.

   EMACS_NORMALIZE_TIME (TIME) coerces TIME into normalized format.

   EMACS_ADD_TIME (DEST, SRC1, SRC2) adds SRC1 to SRC2 and stores the
	result in DEST.  Either or both may be negative.

   EMACS_SUB_TIME (DEST, SRC1, SRC2) subtracts SRC2 from SRC1 and
	stores the result in DEST.  Either or both may be negative.

   EMACS_TIME_NEG_P (TIME) is true iff TIME is negative.

   EMACS_TIME_EQUAL (TIME1, TIME2) is true iff TIME1 is the same as TIME2.
   EMACS_TIME_GREATER (TIME1, TIME2) is true iff TIME1 is greater than
        TIME2.
   EMACS_TIME_EQUAL_OR_GREATER (TIME1, TIME2) is true iff TIME1 is
        greater than or equal to TIME2.

*/

#ifdef HAVE_TIMEVAL

#define EMACS_SELECT_TIME struct timeval
#define EMACS_TIME_TO_SELECT_TIME(time, select_time) ((select_time) = (time))

#else /* not HAVE_TIMEVAL */

struct timeval
{
  long tv_sec;                /* seconds */
  long tv_usec;               /* microseconds */
};

#define EMACS_SELECT_TIME int
#define EMACS_TIME_TO_SELECT_TIME(time, select_time) \
  EMACS_TIME_TO_INT (time, select_time)

#endif /* not HAVE_TIMEVAL */

#define EMACS_TIME_TO_INT(time, intvar)		\
do {						\
  EMACS_TIME tmptime = time;			\
						\
  if (tmptime.tv_usec > 0)			\
    (intvar) = tmptime.tv_sec + 1;		\
  else						\
    (intvar) = tmptime.tv_sec;			\
} while (0)

#define EMACS_TIME struct timeval
#define EMACS_SECS(time)		    ((time).tv_sec  + 0)
#define EMACS_USECS(time)		    ((time).tv_usec + 0)
#define EMACS_SET_SECS(time, seconds)	    ((time).tv_sec  = (seconds))
#define EMACS_SET_USECS(time, microseconds) ((time).tv_usec = (microseconds))

#if !defined (HAVE_GETTIMEOFDAY)
struct timezone;
extern int gettimeofday (struct timeval *, struct timezone *);
#endif

/* On SVR4, the compiler may complain if given this extra BSD arg.  */
#ifdef GETTIMEOFDAY_ONE_ARGUMENT
# ifdef SOLARIS2
/* Solaris (at least) omits this prototype.  IRIX5 has it and chokes if we
   declare it here. */
extern int gettimeofday (struct timeval *);
# endif
/* According to the Xt sources, some NTP daemons on some systems may
   return non-normalized values. */
#define EMACS_GET_TIME(time)					\
do {								\
  gettimeofday (&(time));					\
  EMACS_NORMALIZE_TIME (time);					\
} while (0)
#else /* not GETTIMEOFDAY_ONE_ARGUMENT */
# ifdef SOLARIS2
/* Solaris doesn't provide any prototype of this unless a bunch of
   crap we don't define are defined. */
extern int gettimeofday (struct timeval *, void *dummy);
# endif
#define EMACS_GET_TIME(time)					\
do {								\
  struct timezone dummy;					\
  gettimeofday (&(time), &dummy);				\
  EMACS_NORMALIZE_TIME (time);					\
} while (0)
#endif /* not GETTIMEOFDAY_ONE_ARGUMENT */

#define EMACS_NORMALIZE_TIME(time)				\
do {								\
  while ((time).tv_usec >= 1000000)				\
    {								\
      (time).tv_usec -= 1000000;				\
      (time).tv_sec++;						\
    }								\
  while ((time).tv_usec < 0)					\
    {								\
      (time).tv_usec += 1000000;				\
      (time).tv_sec--;						\
    }								\
} while (0)

#define EMACS_ADD_TIME(dest, src1, src2)			\
do {								\
  (dest).tv_sec  = (src1).tv_sec  + (src2).tv_sec;		\
  (dest).tv_usec = (src1).tv_usec + (src2).tv_usec;		\
  EMACS_NORMALIZE_TIME (dest);					\
} while (0)

#define EMACS_SUB_TIME(dest, src1, src2)			\
do {								\
  (dest).tv_sec  = (src1).tv_sec  - (src2).tv_sec;		\
  (dest).tv_usec = (src1).tv_usec - (src2).tv_usec;		\
  EMACS_NORMALIZE_TIME (dest);					\
} while (0)

#define EMACS_TIME_NEG_P(time) ((long)(time).tv_sec < 0)

#define EMACS_TIME_EQUAL(time1, time2)				\
  ((time1).tv_sec == (time2).tv_sec &&				\
   (time1).tv_usec == (time2).tv_usec)

#define EMACS_TIME_GREATER(time1, time2)			\
  ((time1).tv_sec > (time2).tv_sec ||				\
   ((time1).tv_sec == (time2).tv_sec &&				\
    (time1).tv_usec > (time2).tv_usec))

#define EMACS_TIME_EQUAL_OR_GREATER(time1, time2)		\
  ((time1).tv_sec > (time2).tv_sec ||				\
   ((time1).tv_sec == (time2).tv_sec &&				\
    (time1).tv_usec >= (time2).tv_usec))

#define EMACS_SET_SECS_USECS(time, secs, usecs) 		\
  (EMACS_SET_SECS (time, secs), EMACS_SET_USECS (time, usecs))

extern int set_file_times (char *filename, EMACS_TIME atime, EMACS_TIME mtime);

extern void get_process_times (double *user_time, double *system_time,
			       double *real_time);

#if defined(WINDOWSNT) || defined(BROKEN_CYGWIN)

/* setitimer emulation for Win32 (see nt.c) */

struct itimerval
{
  struct timeval it_value;
  struct timeval it_interval;
};

int setitimer (int kind, const struct itimerval* itnew,
	       struct itimerval* itold);

#define ITIMER_REAL 1
#define ITIMER_PROF 2

#endif /* WINDOWSNT */

#endif /* _XEMACS_SYSTIME_H_ */
