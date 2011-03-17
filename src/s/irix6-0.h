/* Synched up with: FSF 19.31. */

#include "usg5-4.h"

#define IRIX6

#ifdef LIBS_SYSTEM
#undef LIBS_SYSTEM
#endif

#ifdef LIB_STANDARD
#undef LIB_STANDARD
#endif

#ifdef SYSTEM_TYPE
#undef SYSTEM_TYPE
#endif
#define SYSTEM_TYPE "irix"

#ifdef SETUP_SLAVE_PTY
#undef SETUP_SLAVE_PTY
#endif

/* jpff@maths.bath.ac.uk reports `struct exception' is not defined
 * on this system, so inhibit use of matherr.  */
#define NO_MATHERR

/* Tell process_send_signal to use VSUSP instead of VSWTCH.  */
#define PREFER_VSUSP

/* use K&R C */
/* XEmacs change -- use ANSI, not K&R */
#ifndef __GNUC__
#define C_SWITCH_SYSTEM "-xansi"
#endif

/* jackr@engr.sgi.com says that you can't mix different kinds of
 * signal-handling functions under IRIX 5.3.  I'm going to assume
 * that that was the reason this got broken.  Now that the
 * signal routines are fixed up, maybe this will work. --ben */
/* Nope, it doesn't.  I've tried lots of things; it must be
 * genuinely broken. */
/* XEmacs addition: People on IRIX 5.2 and IRIX 5.3 systems have
 * reported that they can't break out of (while t) using C-g or C-G.
 * This does not occur on other systems, so let's assume that SIGIO
 * is broken on these systems. */
#define BROKEN_SIGIO

/* #### Questionable define. */
#define IRIX

/* By Tor Arntsen <tor@spacetec.no> for XEmacs.
 * With the following kludge the above LD_SWITCH_SYSTEM will still work just 
 * fine even with USE_GCC, and additional tweaking of config.h or ymakefile 
 * is avoided. */
#ifdef NOT_C_CODE
# ifdef USE_GCC
#  undef LINKER
#  undef LIB_GCC
#  define LINKER "ld"
#  define LIB_GCC "`gcc --print`"
#  endif
#endif
