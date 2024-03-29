/* Repository for inline functions
   Copyright (C) 1995 Sun Microsystems, Inc.
   Copyright (C) 2010 Ben Wing.

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

/* The purpose of this file is so that there is at least one actual
   definition of each inline function.  This is needed under GCC.  The
   reason is that under GCC we declare our inline functions `inline
   extern', which causes the inlined version to get used only for
   inlining, and in other cases to generate an external reference to
   the function.  This is more efficient than declaring our inline
   functions `inline static', which (in many cases) would cause a separate
   version of the function to get inserted into every source file that
   included the corresponding header file.  See internals.texi.

   Some compilers that recognize `inline' may not do the same
   `inline extern' business, so on those we just do `inline static'.
   */

/* Note to maintainers: This file contains a list of all header files
   that use the INLINE macro, either directly, or by using DECLARE_LISP_OBJECT.
   i.e. the output of ``grep -l -w 'DECLARE_LISP_OBJECT|INLINE_HEADER' *.h'' */

#define DONT_EXTERN_INLINE_HEADER_FUNCTIONS

#include <config.h>
#include "lisp.h"

#include "sysfile.h"

#include "buffer.h"
#include "bytecode.h"
#include "casetab.h"
#include "chartab.h"
#include "device-impl.h"
#include "elhash.h"
#include "events.h"
#include "extents-impl.h"
#include "faces.h"
#include "frame-impl.h"
#include "glyphs.h"
#include "gui.h"
#include "keymap.h"
#include "lstream.h"
#include "fontcolor-impl.h"
#include "opaque.h"
#include "process.h"
#include "rangetab.h"
#include "specifier.h"
#include "symeval.h"
#include "syntax.h"
#include "window.h"

/* If we demand !defined (HAVE_SHLIB) the INLINE_HEADERS aren't instantiated.
   This only shows up in --with-error-checking=types builds AFAIK.
   On Mac OS X 10.3.9 with the Apple toolchain (GCC 3.3) gives a buildtime
   link error (the lrecord error_check functions are undefined).
   Debian GNU/Linux `sid' with GCC 4.0.3 prerelease & binutils 2.16.91 gives
   a runtime link error (the lrecord error_check functions are undefined).
   It is possible that this can be fixed trickily by appropriately defining
   INLINE, or that it should be done in the module itself somehow.  If you
   can do it better or more elegantly, please feel free to consult me.
   --stephen 2005-11-07 */
#if defined (HAVE_LDAP)
#include "../modules/ldap/eldap.h"
#endif

/* We can't ask for !defined (HAVE_SHLIB).  See HAVE_LDAP, above. */
#if defined (HAVE_POSTGRESQL)
#include "../modules/postgresql/postgresql.h"
#endif

#ifdef HAVE_TOOLBARS
#include "toolbar.h"
#endif

#ifdef HAVE_SCROLLBARS
#include "scrollbar.h"
#endif

#ifdef HAVE_DATABASE
#include "database.h"
#endif

#include "console-stream-impl.h"

#ifdef HAVE_X_WINDOWS
#include "console-x-impl.h"
#ifdef HAVE_XFT
#include "font-mgr.h"
#endif
#endif

#ifdef HAVE_MS_WINDOWS
#include "console-msw-impl.h"
#endif

#ifdef HAVE_TTY
#include "console-tty-impl.h"
#include "fontcolor-tty-impl.h"
#endif

#ifdef HAVE_GTK
#include "console-gtk-impl.h"
#include "ui-gtk.h"
#endif

#include "file-coding.h"

#ifdef TOOLTALK
#include "tooltalk.h"
#endif
