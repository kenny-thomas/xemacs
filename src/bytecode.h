/* Definitions for bytecode interpretation and compiled-function objects.
   Copyright (C) 1985, 1986, 1987, 1992, 1993 Free Software Foundation, Inc.

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

/* Synched up with: Not in FSF. */

/* Authorship:

   FSF: long ago.
   Mly: rewrote for 19.8, properly abstracted.
   Jon Reid: some changes for I18N3 (domain, etc), for 19.8.
 */

#ifndef _XEMACS_BYTECODE_H_
#define _XEMACS_BYTECODE_H_

/* Meanings of slots in a Lisp_Compiled_Function. */
#define COMPILED_ARGLIST 0
#define COMPILED_BYTECODE 1
#define COMPILED_CONSTANTS 2
#define COMPILED_STACK_DEPTH 3
#define COMPILED_DOC_STRING 4
#define COMPILED_INTERACTIVE 5
#define COMPILED_DOMAIN 6

/* It doesn't make sense to have this and also have load-history */
/* #define COMPILED_FUNCTION_ANNOTATION_HACK */

struct Lisp_Compiled_Function
{
  struct lrecord_header lheader;
  unsigned short maxdepth;
  struct
  {
    unsigned int documentationp: 1;
    unsigned int interactivep: 1;
    /* Only used if I18N3, but always defined for simplicity. */
    unsigned int domainp: 1;
    /* Non-zero if this bytecode came from a v18 or v19 file.
       We need to Ebolify the `assoc', `delq', etc. functions. */
    unsigned int ebolified: 1;
  } flags;
  Lisp_Object bytecodes;
  Lisp_Object constants;
  Lisp_Object arglist;
  /* This uses the minimal number of conses; see accessors in data.c. */
  Lisp_Object doc_and_interactive;
#ifdef COMPILED_FUNCTION_ANNOTATION_HACK
  /* Something indicating where the bytecode came from */
  Lisp_Object annotated;
#endif
};

Lisp_Object compiled_function_documentation (struct Lisp_Compiled_Function *b);
Lisp_Object compiled_function_interactive (struct Lisp_Compiled_Function *b);
Lisp_Object compiled_function_domain (struct Lisp_Compiled_Function *b);
void set_compiled_function_documentation (struct Lisp_Compiled_Function *b,
					  Lisp_Object);
Lisp_Object compiled_function_annotation (struct Lisp_Compiled_Function *b);

DECLARE_LRECORD (compiled_function, struct Lisp_Compiled_Function);
#define XCOMPILED_FUNCTION(x) XRECORD (x, compiled_function, \
				       struct Lisp_Compiled_Function)
#define XSETCOMPILED_FUNCTION(x, p) XSETRECORD (x, p, compiled_function)
#define COMPILED_FUNCTIONP(x) RECORDP (x, compiled_function)
#define GC_COMPILED_FUNCTIONP(x) GC_RECORDP (x, compiled_function)
#define CHECK_COMPILED_FUNCTION(x) CHECK_RECORD (x, compiled_function)
#define CONCHECK_COMPILED_FUNCTION(x) CONCHECK_RECORD (x, compiled_function)

/* total 1765 internal 101 doc-and-int 775 doc-only 389 int-only 42 neither 559
 no doc slot, no int slot
    overhead                        : (* 1765 0) =    0
    doc-and-int (args . (doc . int)): (*  775 4) = 3100
    doc-only    (args . doc)        : (*  389 2) =  778
    int-only    (args . int)        : (*   42 2) =   84
    neither     args                : (*  559 0) =    0 = 3962
 combined
    overhead                        : (* 1765 1) = 1765
    doc-and-int (doc . int)         : (*  775 2) = 1550
    doc-only    doc                 : (*  389 0) =    0
    int-only    int                 : (*   42 0) =    0
    neither     -                   : (*  559 0) =    0 = 3315
 both
    overhead                        : (* 1765 2) = 3530
    doc-and-int -                   : (*  775 0) =    0
    doc-only    -                   : (*  389 0) =    0
    int-only    -                   : (*   42 0) =    0
    neither     -                   : (*  559 0)  =   0 = 3530
*/

#endif /* _XEMACS_BYTECODE_H_ */

