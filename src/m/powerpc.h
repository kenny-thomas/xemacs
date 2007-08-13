/* machine description file for Power PC
   Copyright (C) 1987, 1994 Free Software Foundation, Inc.
   Copyright (C) 1995 Board of Trustees, University of Illinois

This file is part of XEmacs.

XEmacs is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

XEmacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with XEmacs; see the file COPYING.  If not, write to
the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.  */

/* The following line tells the configuration script what sort of 
   operating system this machine is likely to run.
   USUAL-OPSYS="solaris2-5" */

#ifdef NOT_C_CODE
# define POWERPC
#else
# ifndef powerpc
#  define powerpc
# endif
#endif

#ifdef __GNUC__
# define C_OPTIMIZE_SWITCH "-O"
#else
/* XEmacs change */
# ifdef USE_LCC
#  define C_OPTIMIZE_SWITCH "-O4 -Oi"
# else
     /* This level of optimization is reported to work.  */
#  define C_OPTIMIZE_SWITCH "-O2"
# endif
#endif

/* XINT must explicitly sign-extend */

#define EXPLICIT_SIGN_EXTEND

#ifndef __linux__
/* Data type of load average, as read out of kmem.  */

#define LOAD_AVE_TYPE long

/* Convert that into an integer that is 100 for a load average of 1.0  */

#define LOAD_AVE_CVT(x) (int) (((double) (x)) * 100.0 / FSCALE)
#else /* mklinux */
#if 0
/* The following line tells the configuration script what sort of 
   operating system this machine is likely to run.
   USUAL-OPSYS="linux"  */

/* Define WORDS_BIG_ENDIAN iff lowest-numbered byte in a word
   is the most significant byte.  */

#define WORDS_BIG_ENDIAN
#endif

/* Define NO_ARG_ARRAY if you cannot take the address of the first of a
 * group of arguments and treat it as an array of the arguments.  */

#define NO_ARG_ARRAY

#if 0
/* Now define a symbol for the cpu type, if your compiler
   does not define it automatically.  */

/* #define IBMR2AIX */

/* Use type int rather than a union, to represent Lisp_Object */
/* This is desirable for most machines.	 */

/* #define NO_UNION_TYPE */

/* Define CANNOT_DUMP on machines where unexec does not work.
   Then the function dump-emacs will not be defined
   and temacs will do (load "loadup") automatically unless told otherwise.  */

/* #define CANNOT_DUMP */

#define UNEXEC unexelf.o
#endif

/* Define addresses, macros, change some setup for dump */

#define NO_REMAP

#if 0
#define TEXT_START 0x00001000
#define TEXT_END 0
#define DATA_START 0x01000000
#define DATA_END 0

/* The data segment in this machine always starts at address 0x10000000.
   An address of data cannot be stored correctly in a Lisp object;
   we always lose the high bits.  We must tell XPNTR to add them back.	*/

#define DATA_SEG_BITS 0x10000000
#endif

/* Use type int rather than a union, to represent Lisp_Object */

/* #define NO_UNION_TYPE */

#ifdef CANNOT_DUMP
/* Define shared memory segment symbols */

#define PURE_SEG_BITS 0x30000000

/* Use shared memory.  */
/* This is turned off because it does not always work.	See etc/AIX.DUMP.  */
/* #define HAVE_SHM */
#define SHMKEY 5305035		/* used for shared memory code segments */
#endif /* CANNOT_DUMP */

#define N_BADMAG(x) BADMAG(x)
#define N_TXTOFF(x) A_TEXTPOS(x)
#define N_SYMOFF(x) A_SYMPOS(x)
/* #define A_TEXT_OFFSET(HDR) sizeof(HDR) */
/* #define ADJUST_EXEC_HEADER \
    unexec_text_start += sizeof(hdr); \
    unexec_data_start = ohdr.a_dbase
*/
#undef ADDR_CORRECT
#define ADDR_CORRECT(x) ((int)(x))

/* Define C_ALLOCA if this machine does not support a true alloca
   and the one written in C should be used instead.
   Define HAVE_ALLOCA to say that the system provides a properly
   working alloca function and it should be used.
   Define neither one if an assembler-language alloca
   in the file alloca.s should be used.	 */

#define HAVE_ALLOCA   

/* Specify the font for X to use.
   This used to be Rom14.500; that's nice on the X server shipped with
   the RS/6000, but it's not available on other servers.  */
#define X_DEFAULT_FONT "fixed"

/* Here override various assumptions in ymakefile */

#define START_FILES 
/* #define HAVE_SYSVIPC */
/* #define HAVE_GETWD */

/* Don't try to include sioctl.h or ptem.h.  */
#undef NEED_SIOCTL
#undef NEED_PTEM_H

#define ORDINARY_LINK
#define LD_SWITCH_MACHINE -T ppc.ldscript
#endif
