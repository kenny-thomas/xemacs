/* Debugging aids -- togglable assertions.
   Copyright (C) 1994 Free Software Foundation, Inc.

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

/* This file has been Mule-ized. */

/* Written by Chuck Thompson */

#include <config.h>
#include "lisp.h"
#include "debug.h"
#include "bytecode.h"

/*
 * To add a new debug class:
 * 1.  Add a symbol definition for it here or in general-slots.h, if one
 *     doesn't exist elsewhere.  If you add it here, make sure to add a
 *     defsymbol line for it in syms_of_debug.
 * 2.  Add an extern definition for the symbol to debug.h.
 * 3.  Add entries for the class to struct debug_classes in debug.h.
 * 4.  Add a FROB line for it in xemacs_debug_loop.
 */

struct debug_classes active_debug_classes;

enum debug_loop
{
  X_ADD,
  X_DELETE,
  X_LIST,
  X_ACTIVE,
  X_INIT,
  X_VALIDATE,
  X_TYPE,
  X_SETTYPE
};

static Lisp_Object
xemacs_debug_loop (enum debug_loop op, Lisp_Object class_, Lisp_Object type)
{
  int flag = (op == X_ADD) ? 1 : 0;
  Lisp_Object retval = Qnil;

#define FROB(item)							      \
  if (op == X_LIST || op == X_ACTIVE || op == X_INIT || EQ (class_, Q##item)) \
    {									      \
      if (op == X_ADD || op == X_DELETE || op == X_INIT)		      \
	active_debug_classes.item = flag;				      \
      else if (op == X_LIST						      \
	       || (op == X_ACTIVE && active_debug_classes.item))	      \
	retval = Fcons (Q##item, retval);				      \
      else if (op == X_VALIDATE)					      \
	return Qt;							      \
      else if (op == X_SETTYPE)						      \
        active_debug_classes.types_of_##item = XFIXNUM (type);		      \
      else if (op == X_TYPE)						      \
        retval = make_fixnum (active_debug_classes.types_of_##item);	      \
      if (op == X_INIT) active_debug_classes.types_of_##item = VALBITS;	      \
    }

  FROB (redisplay);
  FROB (buffers);
  FROB (extents);
  FROB (faces);
  FROB (windows);
  FROB (frames);
  FROB (devices);
  FROB (byte_code);

  return retval;
#undef FROB
}

DEFUN ("add-debug-class-to-check", Fadd_debug_class_to_check, 1, 1, 0, /*
Add a debug class to the list of active classes.
*/
       (class_))
{
  if (NILP (xemacs_debug_loop (X_VALIDATE, class_, Qnil)))
    invalid_argument ("No such debug class exists", Qunbound);
  else
    xemacs_debug_loop (X_ADD, class_, Qnil);

  return (xemacs_debug_loop (X_ACTIVE, Qnil, Qnil));
}

DEFUN ("delete-debug-class-to-check", Fdelete_debug_class_to_check, 1, 1, 0, /*
Delete a debug class from the list of active classes.
*/
       (class_))
{
  if (NILP (xemacs_debug_loop (X_VALIDATE, class_, Qnil)))
    invalid_argument ("No such debug class exists", Qunbound);
  else
    xemacs_debug_loop (X_DELETE, class_, Qnil);

  return (xemacs_debug_loop (X_ACTIVE, Qnil, Qnil));
}

DEFUN ("debug-classes-being-checked", Fdebug_classes_being_checked, 0, 0, 0, /*
Return a list of active debug classes.
*/
       ())
{
  return (xemacs_debug_loop (X_ACTIVE, Qnil, Qnil));
}

DEFUN ("debug-classes-list", Fdebug_classes_list, 0, 0, 0, /*
Return a list of all defined debug classes.
*/
       ())
{
  return (xemacs_debug_loop (X_LIST, Qnil, Qnil));
}

DEFUN ("set-debug-classes-to-check", Fset_debug_classes_to_check, 1, 1, 0, /*
Set which classes of debug statements should be active.
CLASSES should be a list of debug classes.
*/
       (classes))
{
  Lisp_Object rest;

  CHECK_LIST (classes);

  /* Make sure all objects in the list are valid.  If anyone is not
     valid, reject the entire list without doing anything. */
  LIST_LOOP (rest, classes)
    {
      if (NILP (xemacs_debug_loop (X_VALIDATE, XCAR (rest), Qnil)))
	sferror ("Invalid object in class list", Qunbound);
    }

  LIST_LOOP (rest, classes)
    Fadd_debug_class_to_check (XCAR (rest));

  return (xemacs_debug_loop (X_ACTIVE, Qnil, Qnil));
}

DEFUN ("set-debug-class-types-to-check", Fset_debug_class_types_to_check, 2, 2, 0, /*
For the given debug CLASS, set which TYPES are actually interesting.
TYPES should be an integer representing the or'd value of all desired types.
Lists of defined types and their values are located in the source code.
*/
       (class_, type))
{
  CHECK_FIXNUM (type);
  if (NILP (xemacs_debug_loop (X_VALIDATE, class_, Qnil)))
    invalid_argument ("Invalid debug class", Qunbound);

  xemacs_debug_loop (X_SETTYPE, class_, type);

  return (xemacs_debug_loop (X_TYPE, class_, Qnil));
}

DEFUN ("debug-types-being-checked", Fdebug_types_being_checked, 1, 1, 0, /*
For the given CLASS, return the associated type value.
*/
       (class_))
{
  if (NILP (xemacs_debug_loop (X_VALIDATE, class_, Qnil)))
    invalid_argument ("Invalid debug class", Qunbound);

  return (xemacs_debug_loop (X_TYPE, class_, Qnil));
}

void
syms_of_debug (void)
{
  DEFSUBR (Fadd_debug_class_to_check);
  DEFSUBR (Fdelete_debug_class_to_check);
  DEFSUBR (Fdebug_classes_being_checked);
  DEFSUBR (Fdebug_classes_list);
  DEFSUBR (Fset_debug_classes_to_check);
  DEFSUBR (Fset_debug_class_types_to_check);
  DEFSUBR (Fdebug_types_being_checked);
}

void
reinit_vars_of_debug (void)
{
  /* If you need to have any classes active early on in startup, then
     the flags should be set here.
     All functions called by this function are "allowed" according
     to emacs.c. */
  xemacs_debug_loop (X_INIT, Qnil, Qnil);
}

void
vars_of_debug (void)
{
  Fprovide (intern ("debug-xemacs"));
}
