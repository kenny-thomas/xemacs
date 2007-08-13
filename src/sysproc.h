/*
   Copyright (C) 1995 Free Software Foundation, Inc.

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

/* Synched up with: Not really in FSF. */

#ifndef INCLUDED_sysproc_h_
#define INCLUDED_sysproc_h_

#ifdef HAVE_VFORK_H
# include <vfork.h>
#endif

#include "systime.h" /* necessary for sys/resource.h; also gets the
			FD_* defines on some systems. */
#ifndef WINDOWSNT
#include <sys/resource.h>
#endif

#if !defined (NO_SUBPROCESSES)

#ifdef HAVE_SOCKETS	/* TCP connection support, if kernel can do it */
# include <sys/types.h>  /* AJK */
# include <sys/socket.h>
# include <netdb.h>
# include <netinet/in.h>
# include <arpa/inet.h>
#ifdef NEED_NET_ERRNO_H
#include <net/errno.h>
#endif /* NEED_NET_ERRNO_H */
#elif defined (SKTPAIR)
# include <sys/socket.h>
#endif /* HAVE_SOCKETS */

/* On some systems, e.g. DGUX, inet_addr returns a 'struct in_addr'. */
#ifdef HAVE_BROKEN_INET_ADDR
# define IN_ADDR struct in_addr
# define NUMERIC_ADDR_ERROR (numeric_addr.s_addr == -1)
#else
# if (LONGBITS > 32)
#  define IN_ADDR unsigned int
# else
#  define IN_ADDR unsigned long
# endif
# define NUMERIC_ADDR_ERROR (numeric_addr == (IN_ADDR) -1)
#endif

/* Define first descriptor number available for subprocesses.  */
#define FIRST_PROC_DESC 3

#ifdef IRIS
# include <sys/sysmacros.h>	/* for "minor" */
#endif /* not IRIS */

#endif /* !NO_SUBPROCESSES */

#ifdef AIX
#include <sys/select.h>
#endif

#ifdef FD_SET

/* We could get this from param.h, but better not to depend on finding that.
   And better not to risk that it might define other symbols used in this
   file.  */
# ifdef FD_SETSIZE
#  define MAXDESC FD_SETSIZE
# else
#  define MAXDESC 64
# endif /* FD_SETSIZE */
# define SELECT_TYPE fd_set

#else /* no FD_SET */

# define MAXDESC 32
# define SELECT_TYPE int

/* Define the macros to access a single-int bitmap of descriptors.  */
# define FD_SET(n, p) (*(p) |= (1 << (n)))
# define FD_CLR(n, p) (*(p) &= ~(1 << (n)))
# define FD_ISSET(n, p) (*(p) & (1 << (n)))
# define FD_ZERO(p) (*(p) = 0)

#endif /* no FD_SET */

int poll_fds_for_input (SELECT_TYPE mask);

#ifdef MSDOS
/* #include <process.h> */
/* Damn that local process.h!  Instead we can define P_WAIT ourselves.  */
#define P_WAIT 1
#endif

#endif /* INCLUDED_sysproc_h_ */
