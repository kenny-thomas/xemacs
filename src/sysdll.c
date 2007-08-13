/* sysdll.c --- system dependent support for dynamic linked libraries
   Copyright (C) 1998 Free Software Foundation, Inc.
   Author:  William Perry <wmperry@aventail.com>

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
along with XEmacs; see the file COPYING.  If not, write to the Free
Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
02111-1307, USA.  */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>
#include "sysdll.h"

/* This whole file is conditional upon HAVE_DLL */
#ifdef HAVE_SHLIB

/* Thankfully, most systems follow the ELFish dlopen() method.
** HAVE__DLOPEN is lame, but SCO has their dl* functions as _dl*, and
** unless you include dlfcn.h you don't get the macros to mask them, and
** autoconf fails to find them.
**
** Anybody who wants to use this on SCO needs to have their configure.in
** look for _dlopen() as well as dlopen()
*/
#if defined(HAVE_DLOPEN) || defined(HAVE__DLOPEN)
#include <dlfcn.h>

#ifndef RTLD_LAZY
# define RTLD_LAZY 1
#endif /* RTLD_LAZY isn't defined under FreeBSD - ick */

#ifndef RTLD_GLOBAL
# define RTLD_GLOBAL 0
#endif

int
dll_init (CONST char *arg)
{
  return 0;
}

dll_handle
dll_open (CONST char *fname)
{
  return (dll_handle)dlopen (fname, RTLD_LAZY | RTLD_GLOBAL);
}

int
dll_close (dll_handle h)
{
  return dlclose((void *)h);
}

dll_func
dll_function (dll_handle h, CONST char *n)
{
#ifdef DLSYM_NEEDS_UNDERSCORE
  char *buf = alloca_array (char, strlen (n) + 2);
  *buf = '_';
  (void)strcpy(buf + 1, n);
  n = buf;
#endif
  return (dll_func)dlsym ((void *)h, n);
}

dll_var
dll_variable (dll_handle h, CONST char *n)
{
  return (dll_var)dlsym ((void *)h, n);
}

CONST char *
dll_error (dll_handle h)
{
#ifdef HAVE_DLERROR
  return (CONST char *)dlerror ();
#else
  return "Shared library error";
#endif
}

#elif defined(HAVE_SHL_LOAD)
/* This is the HP/UX version */
#include <dl.h>
int
dll_init (CONST char *arg)
{
  return 0;
}

dll_handle
dll_open (CONST char *fname)
{
  shl_t h = shl_load (fname, BIND_DEFERRED,0L);
  shl_t *hp = NULL;

  if (h)
    {
      hp = (shl_t *)malloc (sizeof (shl_t));
      if (!hp)
	shl_unload(h);
      else
	*hp = h;
    }
  return (dll_handle)hp;
}

int
dll_close (dll_handle h)
{
  shl_t hp = *((shl_t *)h);
  free (hp);
  return shl_unload(h);
}

dll_func
dll_function (dll_handle h, CONST char *n)
{
  long handle = 0L;

  if (shl_findsym ((shl_t *)h, n, TYPE_PROCEDURE, &handle))
    return NULL;

  return (dll_func)handle;
}

dll_var
dll_variable (dll_handle h, CONST char *n)
{
  long handle = 0L;

  if (shl_findsym ((shl_t *)h, n, TYPE_DATA, &handle))
    return NULL;

  return (dll_var)handle;
}

CONST char *
dll_error (dll_handle h)
{
  /* #### WTF?!  Shouldn't this at least attempt to get strerror or
     something?  --hniksic */
  return "Generic shared library error";
}

#elif defined(HAVE_INIT_DLD)
#include <dld.h>
int
dll_init (CONST char *arg)
{
  char *real_exe = dld_find_executable (arg);
  int rc;

  rc = dld_init (real_exe);
  if (rc)
    {
      dld_perror (exe);
      return -1;
    }
  return 0;
}

dll_handle
dll_open (CONST char *fname)
{
  rc = dld_link (fname);
  if (rc)
    return NULL;

  return (dll_handle)1;
}

int
dll_close (dll_handle h)
{
  /* *sigh* DLD is pretty lame and doesn't return a handle that you can use
  ** later on to free the file - you have to remember the filename and
  ** use that as the unlinker.  We should eventually keep a linked list
  ** of loaded modules and then use the node pointer as the unique id
  ** for the shared library.  Wheeee.  But not now.
  */
  return 1;
}

DLL_FUNC
dll_function (dll_handle h, CONST char *n)
{
  return dld_get_func(n);
}

DLL_FUNC
dll_variable (dll_handle h, CONST char *n)
{
  return dld_get_symbol(n);
}
#elif defined(_WINDOWS) || defined(WIN32)
int
dll_init (CONST char *arg)
{
  return 0;
}

dll_handle
dll_open (CONST char *fname)
{
  return (dll_handle)LoadLibrary (fname);
}

int
dll_close (dll_handle h)
{
  return FreeLibrary (h);
}

dll_func
dll_function (dll_handle h, CONST char *n)
{
  return (dll_func)GetProcAddress (h,n);
}

dll_func
dll_variable (dll_handle h, CONST char *n)
{
  return (dll_func)GetProcAddress (h,n);
}

CONST char *
dll_error (dll_handle h)
{
  return "Windows DLL Error";
}
#else
/* Catchall if we don't know about this systems method of dynamic loading */
int
dll_init (CONST char *arg)
{
  return -1;
}

dll_handle
dll_open (CONST char *fname)
{
  return NULL;
}

int
dll_close (dll_handle h)
{
  return 0;
}

dll_func
dll_function (dll_handle h, CONST char *n)
{
  return NULL;
}

dll_func
dll_variable (dll_handle h, CONST char *n)
{
  return NULL;
}

CONST char *
dll_error (dll_handle h)
{
  return "Shared libraries not implemented on this system";
}
#endif /* System conditionals */

#endif /* HAVE_SHLIB */