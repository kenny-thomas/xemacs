/* Implementation-specific definitions for the Lucid Widget Library.
   Copyright (C) 1992 Lucid, Inc.
   Copyright (C) 2000 Ben Wing.

This file is part of the Lucid Widget Library.

The Lucid Widget Library is free software: you can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

The Lucid Widget Library is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with the Lucid Widget Library.  If not, see
<http://www.gnu.org/licenses/>. */

#ifndef INCLUDED_lwlib_internal_h_
#define INCLUDED_lwlib_internal_h_

#include "lwlib.h"

#ifdef USE_ASSERTIONS
/* Highly dubious kludge */
/*   (thanks, Jamie, I feel better now -- ben) */
EXTERN_C void assert_failed (const char *, int, const char *);
# define abort() (assert_failed (__FILE__, __LINE__, "abort()"))
# define assert(x) ((x) ? (void) 0 : assert_failed (__FILE__, __LINE__, #x))
#else
# ifdef DEBUG_XEMACS
#  define assert(x) ((x) ? (void) 0 : (void) abort ())
# else
#  define assert(x) ((void) 0)
# endif
#endif

/* This represents a single widget within a widget tree.  All the
   widgets in a widget tree are chained through the `next' field.
   `info' is a back pointer to the widget tree. */

typedef struct _widget_instance
{
  Widget		widget;
  Widget		parent;
  Boolean		pop_up_p;
  struct _widget_info*		info;
  struct _widget_instance*	next;
} widget_instance;

/* This represents a single widget tree, such as a single menubar.
   The global variable `all_widget_info' lists all widget trees,
   chained through the `next' field of this structure. */

typedef struct _widget_info
{
  char*			type;
  char*			name;
  LWLIB_ID		id;
  widget_value*		val;
  Boolean		busy;
  lw_callback		pre_activate_cb;
  lw_callback		selection_cb;
  lw_callback		post_activate_cb;
  struct _widget_instance*	instances;
  struct _widget_info*		next;
} widget_info;

typedef Widget
(*widget_creation_function) (widget_instance* instance);

typedef struct _widget_creation_entry
{
  const char*			type;
  widget_creation_function	function;
} widget_creation_entry;

/* update all other instances of a widget.  Can be used in a callback when
   a widget has been used by the user */
void
lw_internal_update_other_instances (Widget widget, XtPointer closure,
				    XtPointer call_data);

/* get the widget_value for a widget in a given instance */
widget_value*
lw_get_widget_value_for_widget (widget_instance* instance, Widget w);

widget_info *lw_get_widget_info (LWLIB_ID id);

#endif /* INCLUDED_lwlib_internal_h_ */
