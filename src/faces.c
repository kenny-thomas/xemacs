/* "Face" primitives
   Copyright (C) 1994 Free Software Foundation, Inc.
   Copyright (C) 1995 Board of Trustees, University of Illinois.
   Copyright (C) 1995, 1996, 2001, 2002, 2005, 2010 Ben Wing.
   Copyright (C) 1995 Sun Microsystems, Inc.
   Copyright (C) 2010 Didier Verna

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

/* Written by Chuck Thompson and Ben Wing,
   based loosely on old face code by Jamie Zawinski. */

#include <config.h>
#include "lisp.h"

#include "buffer.h"
#include "device-impl.h"
#include "elhash.h"
#include "extents-impl.h" /* for extent_face */
#include "faces.h"
#include "frame-impl.h"
#include "glyphs.h"
#include "fontcolor-impl.h"
#include "specifier.h"
#include "window.h"

Lisp_Object Qfacep;
Lisp_Object Qforeground, Qforeback, Qbackground, Qdisplay_table;
Lisp_Object Qbackground_pixmap, Qbackground_placement, Qunderline, Qdim;
Lisp_Object Qblinking, Qstrikethru, Qshrink, Q_name;

Lisp_Object Qinit_face_from_resources;
Lisp_Object Qinit_frame_faces;
Lisp_Object Qinit_device_faces;
Lisp_Object Qinit_global_faces;

/* These faces are used directly internally.  We use these variables
   to be able to reference them directly and save the overhead of
   calling Ffind_face. */
Lisp_Object Vdefault_face, Vmodeline_face, Vgui_element_face;
Lisp_Object Vleft_margin_face, Vright_margin_face, Vtext_cursor_face;
Lisp_Object Vpointer_face, Vvertical_divider_face, Vtoolbar_face, Vwidget_face;

/* Qdefault, Qhighlight, Qleft_margin, Qright_margin defined in general.c */
Lisp_Object Qmodeline, Qgui_element, Qtext_cursor, Qvertical_divider;

Lisp_Object Qface_alias, Qcyclic_face_alias;

/* In the old implementation Vface_list was a list of the face names,
   not the faces themselves.  We now distinguish between permanent and
   temporary faces.  Permanent faces are kept in a regular hash table,
   temporary faces in a weak hash table. */
Lisp_Object Vpermanent_faces_cache;
Lisp_Object Vtemporary_faces_cache;

Lisp_Object Vbuilt_in_face_specifiers;


#ifdef DEBUG_XEMACS
Fixnum debug_x_faces;
#endif

#if defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 199901)

#ifdef DEBUG_XEMACS
# define DEBUG_FACES(FORMAT, ...)  \
     do { if (debug_x_faces) stderr_out(FORMAT, __VA_ARGS__); } while (0)
#else  /* DEBUG_XEMACS */
# define DEBUG_FACES(format, ...)
#endif /* DEBUG_XEMACS */

#elif defined(__GNUC__)

#ifdef DEBUG_XEMACS
# define DEBUG_FACES(format, args...)  \
  do { if (debug_x_faces) stderr_out(format, args ); } while (0)
#else  /* DEBUG_XEMACS */
# define DEBUG_FACES(format, args...)
#endif /* DEBUG_XEMACS */

#else /* defined(__STDC_VERSION__) [...] */
# define DEBUG_FACES	(void)
#endif

static Lisp_Object
mark_face (Lisp_Object obj)
{
  Lisp_Face *face =  XFACE (obj);

  mark_object (face->name);
  mark_object (face->doc_string);

  mark_object (face->foreground);
  mark_object (face->foreback);
  mark_object (face->background);
  mark_object (face->font);
  mark_object (face->display_table);
  mark_object (face->background_pixmap);
  mark_object (face->background_placement);
  mark_object (face->underline);
  mark_object (face->strikethru);
  mark_object (face->highlight);
  mark_object (face->dim);
  mark_object (face->blinking);
  mark_object (face->reverse);
  mark_object (face->shrink);

  mark_object (face->charsets_warned_about);

  return face->plist;
}

static void
print_face (Lisp_Object obj, Lisp_Object printcharfun, int UNUSED (escapeflag))
{
  Lisp_Face *face = XFACE (obj);

  if (print_readably)
    {
      write_fmt_string_lisp (printcharfun, "#s(face :name %S)", 1, face->name);
    }
  else
    {
      write_fmt_string_lisp (printcharfun, "#<face %S", 1, face->name);
      if (!NILP (face->doc_string))
	write_fmt_string_lisp (printcharfun, " %S", 1, face->doc_string);
      write_ascstring (printcharfun, ">");
    }
}

/* Faces are equal if all of their display attributes are equal.  We
   don't compare names or doc-strings, because that would make equal
   be eq.

   This isn't concerned with "unspecified" attributes, that's what
   #'face-differs-from-default-p is for. */
static int
face_equal (Lisp_Object obj1, Lisp_Object obj2, int depth,
	    int UNUSED (foldcase))
{
  Lisp_Face *f1 = XFACE (obj1);
  Lisp_Face *f2 = XFACE (obj2);

  depth++;

  return
    (internal_equal (f1->foreground,	     f2->foreground,	    depth) &&
     internal_equal (f1->foreback,	     f2->foreback,	    depth) &&
     internal_equal (f1->background,	     f2->background,	    depth) &&
     internal_equal (f1->font,		     f2->font,		    depth) &&
     internal_equal (f1->display_table,	     f2->display_table,	    depth) &&
     internal_equal (f1->background_pixmap,  f2->background_pixmap, depth) &&
     internal_equal (f1->background_placement, 
		     f2->background_placement,
		     depth)                                                &&
     internal_equal (f1->underline,	     f2->underline,	    depth) &&
     internal_equal (f1->strikethru,	     f2->strikethru,	    depth) &&
     internal_equal (f1->highlight,	     f2->highlight,	    depth) &&
     internal_equal (f1->dim,		     f2->dim,		    depth) &&
     internal_equal (f1->blinking,	     f2->blinking,	    depth) &&
     internal_equal (f1->reverse,	     f2->reverse,	    depth) &&
     internal_equal (f1->shrink,             f2->shrink,            depth) &&

     ! plists_differ (f1->plist, f2->plist, 0, 0, depth + 1, 0));
}

static Hashcode
face_hash (Lisp_Object obj, int depth, Boolint UNUSED (equalp))
{
  Lisp_Face *f = XFACE (obj);

  depth++;

  /* No need to hash all of the elements; that would take too long.
     Just hash the most common ones. */
  return HASH3 (internal_hash (f->foreground, depth, 0),
		internal_hash (f->background, depth, 0),
		internal_hash (f->font,       depth, 0));
}

static Lisp_Object
face_getprop (Lisp_Object obj, Lisp_Object prop)
{
  Lisp_Face *f = XFACE (obj);

  return
    (EQ (prop, Qforeground)	      ? f->foreground           :
     EQ (prop, Qforeback)	      ? f->foreback             :
     EQ (prop, Qbackground)	      ? f->background           :
     EQ (prop, Qfont)		      ? f->font                 :
     EQ (prop, Qdisplay_table)	      ? f->display_table        :
     EQ (prop, Qbackground_pixmap)    ? f->background_pixmap    :
     EQ (prop, Qbackground_placement) ? f->background_placement :
     EQ (prop, Qunderline)	      ? f->underline            :
     EQ (prop, Qstrikethru)	      ? f->strikethru           :
     EQ (prop, Qhighlight)	      ? f->highlight            :
     EQ (prop, Qdim)		      ? f->dim                  :
     EQ (prop, Qblinking)	      ? f->blinking             :
     EQ (prop, Qreverse)	      ? f->reverse              :
     EQ (prop, Qshrink)	              ? f->shrink               :
     EQ (prop, Qdoc_string)	      ? f->doc_string           :
     external_plist_get (&f->plist, prop, 0, ERROR_ME));
}

static int
face_putprop (Lisp_Object obj, Lisp_Object prop, Lisp_Object value)
{
  Lisp_Face *f = XFACE (obj);

  if (EQ (prop, Qforeground)           ||
      EQ (prop, Qforeback)             ||
      EQ (prop, Qbackground)           ||
      EQ (prop, Qfont)                 ||
      EQ (prop, Qdisplay_table)        ||
      EQ (prop, Qbackground_pixmap)    ||
      EQ (prop, Qbackground_placement) ||
      EQ (prop, Qunderline)            ||
      EQ (prop, Qstrikethru)           ||
      EQ (prop, Qhighlight)            ||
      EQ (prop, Qdim)                  ||
      EQ (prop, Qblinking)             ||
      EQ (prop, Qreverse)              ||
      EQ (prop, Qshrink))
    return 0;

  if (EQ (prop, Qdoc_string))
    {
      if (!NILP (value))
	CHECK_STRING (value);
      f->doc_string = value;
      return 1;
    }

  external_plist_put (&f->plist, prop, value, 0, ERROR_ME);
  return 1;
}

static int
face_remprop (Lisp_Object obj, Lisp_Object prop)
{
  Lisp_Face *f = XFACE (obj);

  if (EQ (prop, Qforeground)           ||
      EQ (prop, Qforeback)             ||
      EQ (prop, Qbackground)           ||
      EQ (prop, Qfont)                 ||
      EQ (prop, Qdisplay_table)        ||
      EQ (prop, Qbackground_pixmap)    ||
      EQ (prop, Qbackground_placement) ||
      EQ (prop, Qunderline)            ||
      EQ (prop, Qstrikethru)           ||
      EQ (prop, Qhighlight)            ||
      EQ (prop, Qdim)                  ||
      EQ (prop, Qblinking)             ||
      EQ (prop, Qreverse)              ||
      EQ (prop, Qshrink))
    return -1;

  if (EQ (prop, Qdoc_string))
    {
      f->doc_string = Qnil;
      return 1;
    }

  return external_remprop (&f->plist, prop, 0, ERROR_ME);
}

static Lisp_Object
face_plist (Lisp_Object obj)
{
  Lisp_Face *face = XFACE (obj);
  Lisp_Object result = face->plist;

  result = cons3 (Qshrink,	         face->shrink,	               result);
  result = cons3 (Qreverse,	         face->reverse,	               result);
  result = cons3 (Qblinking,	         face->blinking,               result);
  result = cons3 (Qdim,		         face->dim,	               result);
  result = cons3 (Qhighlight,	         face->highlight,              result);
  result = cons3 (Qstrikethru,	         face->strikethru,             result);
  result = cons3 (Qunderline,	         face->underline,              result);
  result = cons3 (Qbackground_placement, face->background_placement,   result);
  result = cons3 (Qbackground_pixmap,    face->background_pixmap,      result);
  result = cons3 (Qdisplay_table,        face->display_table,          result);
  result = cons3 (Qfont,	         face->font,                   result);
  result = cons3 (Qbackground,	         face->background,             result);
  result = cons3 (Qforeback,	         face->foreback,               result);
  result = cons3 (Qforeground,	         face->foreground,             result);

  return result;
}

static const struct memory_description face_description[] = {
  { XD_LISP_OBJECT, offsetof (Lisp_Face, name) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, doc_string) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, foreground) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, foreback) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, background) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, font) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, display_table) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, background_pixmap) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, background_placement) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, underline) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, strikethru) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, highlight) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, dim) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, blinking) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, reverse) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, shrink) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, plist) },
  { XD_LISP_OBJECT, offsetof (Lisp_Face, charsets_warned_about) },
  { XD_END }
};

DEFINE_DUMPABLE_LISP_OBJECT ("face", face,
			     mark_face, print_face, 0, face_equal,
			     face_hash, face_description,
			     Lisp_Face);

/************************************************************************/
/*                             face read syntax                         */
/************************************************************************/

static int
face_name_validate (Lisp_Object UNUSED (keyword), Lisp_Object value,
		    Error_Behavior errb)
{
  if (ERRB_EQ (errb, ERROR_ME))
    {
      CHECK_SYMBOL (value);
      return 1;
    }

  return SYMBOLP (value);
}

static int
face_validate (Lisp_Object data, Error_Behavior errb)
{
  int name_seen = 0;
  Lisp_Object valw = Qnil;

  /* #### This syntax is very limited, given all the face properties that
     actually exist. At least implement those in reset_face()! */
  data = Fcdr (data); /* skip over Qface */
  while (!NILP (data))
    {
      Lisp_Object keyw = Fcar (data);

      data = Fcdr (data);
      valw = Fcar (data);
      data = Fcdr (data);
      if (EQ (keyw, Qname) || EQ (keyw, Q_name))
	name_seen = 1;
      else
	ABORT ();
    }

  if (!name_seen)
    {
      maybe_sferror ("No face name given", Qunbound, Qface, errb);
      return 0;
    }

  if (NILP (Ffind_face (valw)))
    {
      maybe_invalid_argument ("No such face", valw, Qface, errb);
      return 0;
    }

  return 1;
}

static Lisp_Object
face_instantiate (Lisp_Object data)
{
  return Fget_face (Fcar (Fcdr (data)));
}


/****************************************************************************
 *                             utility functions                            *
 ****************************************************************************/

static void
reset_face (Lisp_Face *f)
{
  f->name = Qnil;
  f->doc_string = Qnil;
  f->dirty = 0;
  f->foreground = Qnil;
  f->foreback = Qnil;
  f->background = Qnil;
  f->font = Qnil;
  f->display_table = Qnil;
  f->background_pixmap = Qnil;
  f->background_placement = Qnil;
  f->underline = Qnil;
  f->strikethru = Qnil;
  f->highlight = Qnil;
  f->dim = Qnil;
  f->blinking = Qnil;
  f->reverse = Qnil;
  f->shrink = Qnil;
  f->plist = Qnil;
  f->charsets_warned_about = Qnil;
}

static Lisp_Face *
allocate_face (void)
{
  Lisp_Object obj = ALLOC_NORMAL_LISP_OBJECT (face);
  Lisp_Face *result = XFACE (obj);

  reset_face (result);
  return result;
}


/* We store the faces in hash tables with the names as the key and the
   actual face object as the value.  Occasionally we need to use them
   in a list format.  These routines provide us with that. */
struct face_list_closure
{
  Lisp_Object *face_list;
};

static int
add_face_to_list_mapper (Lisp_Object UNUSED (key), Lisp_Object value,
			 void *face_list_closure)
{
  /* This function can GC */
  struct face_list_closure *fcl =
    (struct face_list_closure *) face_list_closure;

  *(fcl->face_list) = Fcons (XFACE (value)->name, (*fcl->face_list));
  return 0;
}

static Lisp_Object
faces_list_internal (Lisp_Object list)
{
  Lisp_Object face_list = Qnil;
  struct gcpro gcpro1;
  struct face_list_closure face_list_closure;

  GCPRO1 (face_list);
  face_list_closure.face_list = &face_list;
  elisp_maphash (add_face_to_list_mapper, list, &face_list_closure);
  UNGCPRO;

  return face_list;
}

static Lisp_Object
permanent_faces_list (void)
{
  return faces_list_internal (Vpermanent_faces_cache);
}

static Lisp_Object
temporary_faces_list (void)
{
  return faces_list_internal (Vtemporary_faces_cache);
}


static int
mark_face_as_clean_mapper (Lisp_Object UNUSED (key), Lisp_Object value,
			   void *flag_closure)
{
  /* This function can GC */
  int *flag = (int *) flag_closure;
  XFACE (value)->dirty = *flag;
  return 0;
}

static void
mark_all_faces_internal (int flag)
{
  elisp_maphash (mark_face_as_clean_mapper, Vpermanent_faces_cache, &flag);
  elisp_maphash (mark_face_as_clean_mapper, Vtemporary_faces_cache, &flag);
}

void
mark_all_faces_as_clean (void)
{
  mark_all_faces_internal (0);
}

/* Currently unused (see the comment in face_property_was_changed()).  */
#if 0
/* #### OBSOLETE ME, PLEASE.  Maybe.  Maybe this is just as good as
   any other solution. */
struct face_inheritance_closure
{
  Lisp_Object face;
  Lisp_Object property;
};

static void
update_inheritance_mapper_internal (Lisp_Object cur_face,
				    Lisp_Object inh_face,
				    Lisp_Object property)
{
  /* #### fix this function */
  Lisp_Object elt = Qnil;
  struct gcpro gcpro1;

  GCPRO1 (elt);

  for (elt = FACE_PROPERTY_SPEC_LIST (cur_face, property, Qall);
       !NILP (elt);
       elt = XCDR (elt))
    {
      Lisp_Object values = XCDR (XCAR (elt));

      for (; !NILP (values); values = XCDR (values))
	{
	  Lisp_Object value = XCDR (XCAR (values));
	  if (VECTORP (value) && XVECTOR_LENGTH (value))
	    {
	      if (EQ (Ffind_face (XVECTOR_DATA (value)[0]), inh_face))
		Fset_specifier_dirty_flag
		  (FACE_PROPERTY_SPECIFIER (inh_face, property));
	    }
	}
    }

  UNGCPRO;
}

static int
update_face_inheritance_mapper (const void *hash_key, void *hash_contents,
				void *face_inheritance_closure)
{
  Lisp_Object key, contents;
  struct face_inheritance_closure *fcl =
    (struct face_inheritance_closure *) face_inheritance_closure;

  key = GET_LISP_FROM_VOID (hash_key);
  contents = GET_LISP_FROM_VOID (hash_contents);

  if (EQ (fcl->property, Qfont))
    {
      update_inheritance_mapper_internal (contents, fcl->face, Qfont);
    }
  else if (EQ (fcl->property, Qforeground) ||
	   EQ (fcl->property, Qforeback)   ||
	   EQ (fcl->property, Qbackground))
    {
      update_inheritance_mapper_internal (contents, fcl->face, Qforeground);
      update_inheritance_mapper_internal (contents, fcl->face, Qforeback);
      update_inheritance_mapper_internal (contents, fcl->face, Qbackground);
    }
  else if (EQ (fcl->property, Qunderline)  ||
	   EQ (fcl->property, Qstrikethru) ||
	   EQ (fcl->property, Qhighlight)  ||
	   EQ (fcl->property, Qdim)        ||
	   EQ (fcl->property, Qblinking)   ||
	   EQ (fcl->property, Qreverse)    ||
	   EQ (fcl->property, Qshrink))
    {
      update_inheritance_mapper_internal (contents, fcl->face, Qunderline);
      update_inheritance_mapper_internal (contents, fcl->face, Qstrikethru);
      update_inheritance_mapper_internal (contents, fcl->face, Qhighlight);
      update_inheritance_mapper_internal (contents, fcl->face, Qdim);
      update_inheritance_mapper_internal (contents, fcl->face, Qblinking);
      update_inheritance_mapper_internal (contents, fcl->face, Qreverse);
      update_inheritance_mapper_internal (contents, fcl->face, Qshrink);
    }
  return 0;
}

static void
update_faces_inheritance (Lisp_Object face, Lisp_Object property)
{
  struct face_inheritance_closure face_inheritance_closure;
  struct gcpro gcpro1, gcpro2;

  GCPRO2 (face, property);
  face_inheritance_closure.face = face;
  face_inheritance_closure.property = property;

  elisp_maphash (update_face_inheritance_mapper, Vpermanent_faces_cache,
		 &face_inheritance_closure);
  elisp_maphash (update_face_inheritance_mapper, Vtemporary_faces_cache,
		 &face_inheritance_closure);

  UNGCPRO;
}
#endif /* 0 */

Lisp_Object
face_property_matching_instance (Lisp_Object face, Lisp_Object property,
				 Lisp_Object charset, Lisp_Object domain,
				 Error_Behavior errb, int no_fallback,
				 Lisp_Object depth,
				 enum font_specifier_matchspec_stages stage)
{
  Lisp_Object retval;
  Lisp_Object matchspec = Qunbound;
  struct gcpro gcpro1;

  if (!NILP (charset))
    matchspec = noseeum_cons (charset,
			      stage == STAGE_INITIAL ? Qinitial : Qfinal);

  GCPRO1 (matchspec);
  /* This call to specifier_instance_no_quit(), will end up calling
     font_instantiate() if the property in a question is a font (currently,
     this means EQ (property, Qfont), because only the face property named
     `font' contains a font object).  See the comments there. */
  retval = specifier_instance_no_quit (Fget (face, property, Qnil), matchspec,
				       domain, errb, no_fallback, depth);
  UNGCPRO;
  if (CONSP (matchspec))
    free_cons (matchspec);

  if (UNBOUNDP (retval) && !no_fallback && STAGE_FINAL == stage)
    {
      if (EQ (property, Qfont))
	{
	  if (NILP (memq_no_quit (charset,
				  XFACE (face)->charsets_warned_about)))
	    {
	      if (!UNBOUNDP (charset))
		warn_when_safe
		  (Qfont, Qnotice,
		   "Unable to instantiate font for charset %s, face %s",
		   XSTRING_DATA (symbol_name
				(XSYMBOL (XCHARSET_NAME (charset)))),
		   XSTRING_DATA (symbol_name
				(XSYMBOL (XFACE (face)->name))));
	      XFACE (face)->charsets_warned_about =
		Fcons (charset, XFACE (face)->charsets_warned_about);
	    }
	  retval = Vthe_null_font_instance;
	}
    }

  return retval;
}


DEFUN ("facep", Ffacep, 1, 1, 0, /*
Return t if OBJECT is a face.
*/
       (object))
{
  return FACEP (object) ? Qt : Qnil;
}

DEFUN ("find-face", Ffind_face, 1, 1, 0, /*
Retrieve the face of the given name.
If FACE-OR-NAME is a face object, it is simply returned.
Otherwise, FACE-OR-NAME should be a symbol.  If there is no such face,
nil is returned.  Otherwise the associated face object is returned.
*/
       (face_or_name))
{
  Lisp_Object retval;
  Lisp_Object face_name;
  Lisp_Object face_alias;
  int i;

  if (FACEP (face_or_name))
    return face_or_name;

  face_name = face_or_name;
  CHECK_SYMBOL (face_name);

# define FACE_ALIAS_MAX_DEPTH 32

  i = 0;
  while (! NILP ((face_alias = Fget (face_name, Qface_alias, Qnil)))
	 && i < FACE_ALIAS_MAX_DEPTH)
    {
      face_name = face_alias;
      CHECK_SYMBOL (face_alias);
      i += 1;
    }

  /* #### This test actually makes the aliasing max depth to 30, which is more
     #### than enough IMO. -- dvl */
  if (i == FACE_ALIAS_MAX_DEPTH)
    signal_error (Qcyclic_face_alias,
		  "Max face aliasing depth reached",
		  face_name);

# undef  FACE_ALIAS_MAX_DEPTH

  /* Check if the name represents a permanent face. */
  retval = Fgethash (face_name, Vpermanent_faces_cache, Qnil);
  if (!NILP (retval))
    return retval;

  /* Check if the name represents a temporary face. */
  return Fgethash (face_name, Vtemporary_faces_cache, Qnil);
}

DEFUN ("get-face", Fget_face, 1, 1, 0, /*
Retrieve the face of the given name.
Same as `find-face' except an error is signalled if there is no such
face instead of returning nil.
*/
       (name))
{
  Lisp_Object face = Ffind_face (name);

  if (NILP (face))
    invalid_argument ("No such face", name);
  return face;
}

DEFUN ("face-name", Fface_name, 1, 1, 0, /*
Return the name of the given face.
*/
       (face))
{
  return XFACE (Fget_face (face))->name;
}

DEFUN ("built-in-face-specifiers", Fbuilt_in_face_specifiers, 0, 0, 0, /*
Return a list of all built-in face specifier properties.

This is a copy; there is no way to modify XEmacs' idea of the built-in face
specifier properties from Lisp.
*/
       ())
{
  return Fcopy_list(Vbuilt_in_face_specifiers);
}

/* These values are retrieved so often that we make a special
   function.
*/

void
default_face_font_info (Lisp_Object domain, int *ascent, int *descent,
			int *width, int *height, int *proportional_p)
{
  Lisp_Object font_instance;
  struct face_cachel *cachel;
  struct window *w = NULL;

  if (noninteractive)
    {
      if (ascent)
	*ascent = 1;
      if (descent)
	*descent = 0;
      if (height)
	*height = 1;
      if (width)
	*width = 1;
      if (proportional_p)
	*proportional_p = 0;
      return;
    }

  /* We use ASCII here.  This is reasonable because the people calling this
     function are using the resulting values to come up with overall sizes
     for windows and frames.

     It's possible for this function to get called when the face cachels
     have not been initialized--put a call to debug-print in
     init-locale-at-early-startup to see it happen. */

  if (WINDOWP (domain) && (w = XWINDOW (domain)) && w->face_cachels)
    {
      if (!Dynarr_length (w->face_cachels))
	reset_face_cachels (w);
      cachel = WINDOW_FACE_CACHEL (w, DEFAULT_INDEX);
      font_instance = FACE_CACHEL_FONT (cachel, Vcharset_ascii);
    }
  else
    {
      font_instance = FACE_FONT (Vdefault_face, domain, Vcharset_ascii);
    }

  if (UNBOUNDP (font_instance))
    {
      return;
    }

  if (height)
    *height = XFONT_INSTANCE (font_instance)->height;
  if (width)
    *width = XFONT_INSTANCE (font_instance)->width;
  if (ascent)
    *ascent = XFONT_INSTANCE (font_instance)->ascent;
  if (descent)
    *descent = XFONT_INSTANCE (font_instance)->descent;
  if (proportional_p)
    *proportional_p = XFONT_INSTANCE (font_instance)->proportional_p;
}

void
default_face_width_and_height (Lisp_Object domain, int *width, int *height)
{
  default_face_font_info (domain, 0, 0, width, height, 0);
}

DEFUN ("face-list", Fface_list, 0, 1, 0, /*
Return a list of the names of all defined faces.
If TEMPORARY is nil, only the permanent faces are included.
If it is t, only the temporary faces are included.  If it is any
other non-nil value both permanent and temporary are included.
*/
       (temporary))
{
  Lisp_Object face_list = Qnil;

  /* Added the permanent faces, if requested. */
  if (NILP (temporary) || !EQ (Qt, temporary))
    face_list = permanent_faces_list ();

  if (!NILP (temporary))
    {
      struct gcpro gcpro1;
      GCPRO1 (face_list);
      face_list = nconc2 (face_list, temporary_faces_list ());
      UNGCPRO;
    }

  return face_list;
}

DEFUN ("make-face", Fmake_face, 1, 3, 0, /*
Define a new face with name NAME (a symbol), described by DOC-STRING.
You can modify the font, color, etc. of a face with the set-face-* functions.
If the face already exists, it is unmodified.
If TEMPORARY is non-nil, this face will cease to exist if not in use.
*/
       (name, doc_string, temporary))
{
  /* This function can GC if initialized is non-zero */
  Lisp_Face *f;
  Lisp_Object face;

  CHECK_SYMBOL (name);
  if (!NILP (doc_string))
    CHECK_STRING (doc_string);

  face = Ffind_face (name);
  if (!NILP (face))
    return face;

  f = allocate_face ();
  face = wrap_face (f);

  f->name = name;
  f->doc_string = doc_string;
  f->foreground = Fmake_specifier (Qcolor);
  set_color_attached_to (f->foreground, face, Qforeground);
  f->foreback = Fmake_specifier (Qcolor);
  set_color_attached_to (f->foreback, face, Qforeback);
  f->background = Fmake_specifier (Qcolor);
  set_color_attached_to (f->background, face, Qbackground);
  f->font = Fmake_specifier (Qfont);
  set_font_attached_to (f->font, face, Qfont);
  f->background_pixmap = Fmake_specifier (Qimage);
  set_image_attached_to (f->background_pixmap, face, Qbackground_pixmap);
  f->background_placement = Fmake_specifier (Qface_background_placement);
  set_face_background_placement_attached_to (f->background_placement, face);
  f->display_table = Fmake_specifier (Qdisplay_table);
  f->underline = Fmake_specifier (Qface_boolean);
  set_face_boolean_attached_to (f->underline, face, Qunderline);
  f->strikethru = Fmake_specifier (Qface_boolean);
  set_face_boolean_attached_to (f->strikethru, face, Qstrikethru);
  f->highlight = Fmake_specifier (Qface_boolean);
  set_face_boolean_attached_to (f->highlight, face, Qhighlight);
  f->dim = Fmake_specifier (Qface_boolean);
  set_face_boolean_attached_to (f->dim, face, Qdim);
  f->blinking = Fmake_specifier (Qface_boolean);
  set_face_boolean_attached_to (f->blinking, face, Qblinking);
  f->reverse = Fmake_specifier (Qface_boolean);
  set_face_boolean_attached_to (f->reverse, face, Qreverse);
  f->shrink = Fmake_specifier (Qface_boolean);
  set_face_boolean_attached_to (f->shrink, face, Qshrink);
  if (!NILP (Vdefault_face))
    {
      /* If the default face has already been created, set it as
	 the default fallback specifier for all the specifiers we
	 just created.  This implements the standard "all faces
	 inherit from default" behavior. */
      set_specifier_fallback (f->foreground,
			      Fget (Vdefault_face, Qforeground, Qunbound));
      set_specifier_fallback (f->foreback,
			      Fget (Vdefault_face, Qforeback, Qunbound));
      set_specifier_fallback (f->background,
			      Fget (Vdefault_face, Qbackground, Qunbound));
      set_specifier_fallback (f->font,
			      Fget (Vdefault_face, Qfont, Qunbound));
      set_specifier_fallback (f->background_pixmap,
			      Fget (Vdefault_face, Qbackground_pixmap,
				    Qunbound));
      set_specifier_fallback (f->background_placement,
			      Fget (Vdefault_face, Qbackground_placement,
				    Qunbound));
      set_specifier_fallback (f->display_table,
			      Fget (Vdefault_face, Qdisplay_table, Qunbound));
      set_specifier_fallback (f->underline,
			      Fget (Vdefault_face, Qunderline, Qunbound));
      set_specifier_fallback (f->strikethru,
			      Fget (Vdefault_face, Qstrikethru, Qunbound));
      set_specifier_fallback (f->highlight,
			      Fget (Vdefault_face, Qhighlight, Qunbound));
      set_specifier_fallback (f->dim,
			      Fget (Vdefault_face, Qdim, Qunbound));
      set_specifier_fallback (f->blinking,
			      Fget (Vdefault_face, Qblinking, Qunbound));
      set_specifier_fallback (f->reverse,
			      Fget (Vdefault_face, Qreverse, Qunbound));
      set_specifier_fallback (f->shrink,
			      Fget (Vdefault_face, Qshrink, Qunbound));
    }

  /* Add the face to the appropriate list. */
  if (NILP (temporary))
    Fputhash (name, face, Vpermanent_faces_cache);
  else
    Fputhash (name, face, Vtemporary_faces_cache);

  /* Note that it's OK if we dump faces.
     When we start up again when we're not noninteractive,
     `init-global-faces' is called and it resources all
     existing faces. */
  if (initialized && !noninteractive)
    {
      struct gcpro gcpro1, gcpro2;

      GCPRO2 (name, face);
      call1 (Qinit_face_from_resources, name);
      UNGCPRO;
    }

  return face;
}


/*****************************************************************************
 initialization code
 ****************************************************************************/

void
init_global_faces (struct device *d)
{
  /* When making the initial terminal device, there is no Lisp code
     loaded, so we can't do this. */
  if (initialized && !noninteractive)
    call_critical_lisp_code (d, Qinit_global_faces, wrap_device (d));
}

void
init_device_faces (struct device *d)
{
  /* This function can call lisp */

  /* When making the initial terminal device, there is no Lisp code
     loaded, so we can't do this. */
  if (initialized)
    call_critical_lisp_code (d, Qinit_device_faces, wrap_device (d));
}

void
init_frame_faces (struct frame *frm)
{
  /* When making the initial terminal device, there is no Lisp code
     loaded, so we can't do this. */
  if (initialized)
    {
      Lisp_Object tframe = wrap_frame (frm);


      /* DO NOT change the selected frame here.  If the debugger goes off
	 it will try and display on the frame being created, but it is not
	 ready for that yet and a horrible death will occur.  Any random
	 code depending on the selected-frame as an implicit arg should be
	 tracked down and shot.  For the benefit of the one known,
	 xpm-color-symbols, make-frame sets the variable
	 Vframe_being_created to the frame it is making and sets it to nil
	 when done.  Internal functions that this could trigger which are
	 currently depending on selected-frame should use this instead.  It
	 is not currently visible at the lisp level. */
      call_critical_lisp_code (XDEVICE (FRAME_DEVICE (frm)),
			       Qinit_frame_faces, tframe);
    }
}


/****************************************************************************
 *                        face cache element functions                      *
 ****************************************************************************/

/*

#### Here is a description of how the face cache elements ought
to be redone.  It is *NOT* how they work currently:

However, when I started to go about implementing this, I realized
that there are all sorts of subtle problems with cache coherency
that are coming up.  As it turns out, these problems don't
manifest themselves now due to the brute-force "kill 'em all"
approach to cache invalidation when faces change; but if this
is ever made smarter, these problems are going to come up, and
some of them are very non-obvious.

I'm thinking of redoing the cache code a bit to avoid these
coherency problems.  The bulk of the problems will arise because
the current display structures have simple indices into the
face cache, but the cache can be changed at various times,
which could make the current display structures incorrect.
I guess the dirty and updated flags are an attempt to fix
this, but this approach doesn't really work.

Here's an approach that should keep things clean and unconfused:

1) Imagine a "virtual face cache" that can grow arbitrarily
   big and for which the only thing allowed is to add new
   elements.  Existing elements cannot be removed or changed.
   This way, any pointers in the existing redisplay structure
   into the cache never get screwed up. (This is important
   because even if a cache element is out of date, if there's
   a pointer to it then its contents still accurately describe
   the way the text currently looks on the screen.)
2) Each element in the virtual cache either describes exactly
   one face, or describes the merger of a number of faces
   by some process.  In order to simplify things, for mergers
   we do not record which faces or ordering was used, but
   simply that this cache element is the result of merging.
   Unlike the current implementation, it's important that a
   single cache element not be used to both describe a
   single face and describe a merger, even if all the property
   values are the same.
3) Each cache element can be clean or dirty.  "Dirty" means
   that the face that the element points to has been changed;
   this gets set at the time the face is changed.  This
   way, when looking up a value in the cache, you can determine
   whether it's out of date or not.  For merged faces it
   does not matter -- we don't record the faces or priority
   used to create the merger, so it's impossible to look up
   one of these faces.  We have to recompute it each time.
   Luckily, this is fine -- doing the merge is much
   less expensive than recomputing the properties of a
   single face.
4) For each cache element, we keep a hash value. (In order
   to hash the boolean properties, we convert each of them
   into a different large prime number so that the hashing works
   well.) This allows us, when comparing runes, to properly
   determine whether the face for that rune has changed.
   This will be especially important for TTY's, where there
   aren't that many faces and minimizing redraw is very
   important.
5) We can't actually keep an infinite cache, but that doesn't
   really matter that much.  The only elements we care about
   are those that are used by either the current or desired
   display structs.  Therefore, we keep a per-window
   redisplay iteration number, and mark each element with
   that number as we use it.  Just after outputting the
   window and synching the redisplay structs, we go through
   the cache and invalidate all elements that are not clean
   elements referring to a particular face and that do not
   have an iteration number equal to the current one.  We
   keep them in a chain, and use them to allocate new
   elements when possible instead of increasing the Dynarr.

--ben (?? At least I think I wrote this!)
   */

/* mark for GC a dynarr of face cachels. */

void
mark_face_cachels (face_cachel_dynarr *elements)
{
  int elt;

  if (!elements)
    return;

  for (elt = 0; elt < Dynarr_length (elements); elt++)
    {
      struct face_cachel *cachel = Dynarr_atp (elements, elt);

      {
	int i;

	for (i = 0; i < NUM_LEADING_BYTES; i++)
	  if (!NILP (cachel->font[i]) && !UNBOUNDP (cachel->font[i]))
	    mark_object (cachel->font[i]);
      }
      mark_object (cachel->face);
      mark_object (cachel->foreground);
      mark_object (cachel->foreback);
      mark_object (cachel->background);
      mark_object (cachel->display_table);
      mark_object (cachel->background_pixmap);
      mark_object (cachel->background_placement);
    }
}

/* ensure that the given cachel contains an updated font value for
   the given charset.  Return the updated font value (which can be
   Qunbound, so this value must not be passed unchecked to Lisp).

   #### Xft: This function will need to be updated for new font model. */

Lisp_Object
ensure_face_cachel_contains_charset (struct face_cachel *cachel,
				     Lisp_Object domain, Lisp_Object charset)
{
  Lisp_Object new_val;
  Lisp_Object face = cachel->face;
  int bound = 1, final_stage = 0;
  int offs = XCHARSET_LEADING_BYTE (charset) - MIN_LEADING_BYTE;

  if (!UNBOUNDP (cachel->font[offs]) &&
      bit_vector_bit(FACE_CACHEL_FONT_UPDATED (cachel), offs))
    return cachel->font[offs];

  if (UNBOUNDP (face))
    {
      /* a merged face. */
      int i;
      struct window *w = XWINDOW (domain);

      new_val = Qunbound;
      set_bit_vector_bit(FACE_CACHEL_FONT_SPECIFIED(cachel), offs, 0);

      for (i = 0; i < cachel->nfaces; i++)
	{
	  struct face_cachel *oth;

	  oth = Dynarr_atp (w->face_cachels,
			    FACE_CACHEL_FINDEX_UNSAFE (cachel, i));
	  /* Tout le monde aime la recursion */
	  ensure_face_cachel_contains_charset (oth, domain, charset);

	  if (bit_vector_bit(FACE_CACHEL_FONT_SPECIFIED(oth), offs))
	    {
	      new_val = oth->font[offs];
	      set_bit_vector_bit(FACE_CACHEL_FONT_SPECIFIED(cachel), offs, 1);
	      set_bit_vector_bit
		(FACE_CACHEL_FONT_FINAL_STAGE(cachel), offs,
		 bit_vector_bit(FACE_CACHEL_FONT_FINAL_STAGE(oth), offs));
	      break;
	    }
	}

      if (!bit_vector_bit(FACE_CACHEL_FONT_SPECIFIED(cachel), offs))
	/* need to do the default face. */
	{
	  struct face_cachel *oth =
	    Dynarr_atp (w->face_cachels, DEFAULT_INDEX);
	  ensure_face_cachel_contains_charset (oth, domain, charset);

	  new_val = oth->font[offs];
	}

      if (!UNBOUNDP (cachel->font[offs]) &&
	  !EQ (cachel->font[offs], new_val))
	cachel->dirty = 1;
      set_bit_vector_bit(FACE_CACHEL_FONT_UPDATED(cachel), offs, 1);
      cachel->font[offs] = new_val;
      DEBUG_FACES("just recursed on the unbound face, returning "
		  "something %s\n", UNBOUNDP(new_val) ? "not bound"
		  : "bound");
      return new_val;
    }

  do {

    /* Lookup the face, specifying the initial stage and that fallbacks
       shouldn't happen. */
    new_val = face_property_matching_instance (face, Qfont, charset, domain,
					       /* ERROR_ME_DEBUG_WARN is
						  fine here.  */
					       ERROR_ME_DEBUG_WARN, 1, Qzero,
					       STAGE_INITIAL);
    DEBUG_FACES("just called f_p_m_i on face %s, charset %s, initial, "
		"result was something %s\n",
		XSTRING_DATA(XSYMBOL_NAME(XFACE(cachel->face)->name)),
		XSTRING_DATA(XSYMBOL_NAME(XCHARSET_NAME(charset))),
		UNBOUNDP(new_val) ? "not bound" : "bound");

    if (!UNBOUNDP (new_val)) break;

    bound = 0;
    /* Lookup the face again, this time allowing the fallback. If this
       succeeds, it'll give a font intended for the script in question,
       which is preferable to translating to ISO10646-1 and using the
       fixed-width fallback.

       #### This is questionable.  The problem is that unusual scripts
       will typically fallback to the hard-coded values as the user is
       unlikely to have specified them herself, a common complaint. */
    new_val = face_property_matching_instance (face, Qfont,
					       charset, domain,
					       ERROR_ME_DEBUG_WARN, 0,
					       Qzero,
					       STAGE_INITIAL);

    DEBUG_FACES ("just called f_p_m_i on face %s, charset %s, initial, "
		 "allow fallback, result was something %s\n",
		 XSTRING_DATA (XSYMBOL_NAME (XFACE (cachel->face)->name)),
		 XSTRING_DATA (XSYMBOL_NAME (XCHARSET_NAME (charset))),
		 UNBOUNDP (new_val) ? "not bound" : "bound");

    if (!UNBOUNDP (new_val))
      {
	break;
      }

    bound = 1;
    /* Try the face itself with the final-stage specifiers. */
    new_val = face_property_matching_instance (face, Qfont,
					       charset, domain,
					       ERROR_ME_DEBUG_WARN, 1,
					       Qzero,
					       STAGE_FINAL);

    DEBUG_FACES("just called f_p_m_i on face %s, charset %s, final, "
		"result was something %s\n",
		XSTRING_DATA(XSYMBOL_NAME(XFACE(cachel->face)->name)),
		XSTRING_DATA(XSYMBOL_NAME(XCHARSET_NAME(charset))),
		UNBOUNDP(new_val) ? "not bound" : "bound");
    /* Tell X11 redisplay that it should translate to iso10646-1. */
    if (!UNBOUNDP (new_val))
      {
	final_stage = 1;
	break;
      }

    bound = 0;

    /* Lookup the face again, this time both allowing the fallback and
       allowing its final stage to be used.  */
    new_val = face_property_matching_instance (face, Qfont,
					       charset, domain,
					       ERROR_ME_DEBUG_WARN, 0,
					       Qzero,
					       STAGE_FINAL);

    DEBUG_FACES ("just called f_p_m_i on face %s, charset %s, initial, "
		 "allow fallback, result was something %s\n",
		 XSTRING_DATA (XSYMBOL_NAME (XFACE (cachel->face)->name)),
		 XSTRING_DATA (XSYMBOL_NAME (XCHARSET_NAME (charset))),
		 UNBOUNDP (new_val) ? "not bound" : "bound");
    if (!UNBOUNDP(new_val))
      {
	/* Tell X11 redisplay that it should translate to iso10646-1. */
	final_stage = 1;
	break;
      }
  } while (0);

  if (!UNBOUNDP (cachel->font[offs]) && !EQ (new_val, cachel->font[offs]))
    cachel->dirty = 1;

  set_bit_vector_bit(FACE_CACHEL_FONT_UPDATED(cachel), offs, 1);
  set_bit_vector_bit(FACE_CACHEL_FONT_FINAL_STAGE(cachel), offs,
		     final_stage);
  set_bit_vector_bit(FACE_CACHEL_FONT_SPECIFIED(cachel), offs,
		     (bound || EQ (face, Vdefault_face)));
  cachel->font[offs] = new_val;
  return new_val;
}

/* Ensure that the given cachel contains updated fonts for all
   the charsets specified. */

void
ensure_face_cachel_complete (struct face_cachel *cachel,
			     Lisp_Object domain, unsigned char *charsets)
{
  int i;

  for (i = 0; i < NUM_LEADING_BYTES; i++)
    if (charsets[i])
      {
	Lisp_Object charset = charset_by_leading_byte (i + MIN_LEADING_BYTE);
	assert (CHARSETP (charset));
	ensure_face_cachel_contains_charset (cachel, domain, charset);
      }
}

void
face_cachel_charset_font_metric_info (struct face_cachel *cachel,
				      unsigned char *charsets,
				      struct font_metric_info *fm)
{
  int i;

  fm->width = 1;
  fm->height = fm->ascent = 1;
  fm->descent = 0;
  fm->proportional_p = 0;

  for (i = 0; i < NUM_LEADING_BYTES; i++)
    {
      if (charsets[i])
	{
	  Lisp_Object charset = charset_by_leading_byte (i + MIN_LEADING_BYTE);
	  Lisp_Object font_instance = FACE_CACHEL_FONT (cachel, charset);
	  Lisp_Font_Instance *fi = XFONT_INSTANCE (font_instance);

	  assert (CHARSETP (charset));
	  assert (FONT_INSTANCEP (font_instance));

	  if (fm->ascent  < (int) fi->ascent)  fm->ascent  = (int) fi->ascent;
	  if (fm->descent < (int) fi->descent) fm->descent = (int) fi->descent;
	  fm->height = fm->ascent + fm->descent;
	  if (fi->proportional_p)
	    fm->proportional_p = 1;
	  if (EQ (charset, Vcharset_ascii))
	    fm->width = fi->width;
	}
    }
}

#define FROB(field)							     \
  do {									     \
    Lisp_Object new_val =						     \
      FACE_PROPERTY_INSTANCE (face, Q##field, domain, 1, Qzero);	     \
    int bound = 1;							     \
    if (UNBOUNDP (new_val))						     \
      {									     \
	bound = 0;							     \
	new_val = FACE_PROPERTY_INSTANCE (face, Q##field, domain, 0, Qzero); \
      }									     \
    if (!EQ (new_val, cachel->field))					     \
      {									     \
	cachel->field = new_val;					     \
	cachel->dirty = 1;						     \
      }									     \
    cachel->field##_specified = (bound || default_face);		     \
  } while (0)


/* #### FIXME:

   This is shaky and might not even be what's desired from time to time. Why
   restrict to the default face? Somebody could want to specify the background
   color of *any* face, and make it have precedence over inherited pixmaps.
   
   What's really needed is a more general background property:
   - type: color or pixmap
   - color (for the color type)
   - pixmap + fg color / bg color (in case of bitmap) for the pixmap type.
   
   And, BTW, the foreground property could also behave like this.
   
   -- dvl

   A face's background pixmap will override the face's background color. But
   the background pixmap of the default face should not override the
   background color of a face if the background color has been specified or
   inherited.
 
   To accomplish this we remove the background pixmap of the cachel and mark
   it as having been specified so that cachel merging won't override it later.
 */
#define MAYBE_UNFROB_BACKGROUND_PIXMAP          \
do                                              \
{                                               \
  if (! default_face                            \
      && cachel->background_specified           \
      && ! cachel->background_pixmap_specified) \
    {                                           \
      cachel->background_pixmap = Qunbound;     \
      cachel->background_pixmap_specified = 1;  \
    }                                           \
} while (0)


/* Add a cachel for the given face to the given window's cache. */

static void
add_face_cachel (struct window *w, Lisp_Object face)
{
  int must_finish_frobbing = ! WINDOW_FACE_CACHEL (w, DEFAULT_INDEX);
  struct face_cachel new_cachel;
  Lisp_Object domain;

  reset_face_cachel (&new_cachel);
  domain = wrap_window (w);
  update_face_cachel_data (&new_cachel, domain, face);
  Dynarr_add (w->face_cachels, new_cachel);

  /* The face's background pixmap have not yet been frobbed (see comment
     in update_face_cachel_data), so we have to do it now */
  if (must_finish_frobbing)
    {
      int default_face = EQ (face, Vdefault_face);
      struct face_cachel *cachel = Dynarr_lastp (w->face_cachels);

      FROB (background_pixmap);
      MAYBE_UNFROB_BACKGROUND_PIXMAP;
    }
}

/* Called when the updated flag has been cleared on a cachel.
   This function returns 1 if the caller must finish the update (see comment
   below), 0 otherwise.
*/

void
update_face_cachel_data (struct face_cachel *cachel,
			 Lisp_Object domain,
			 Lisp_Object face)
{
  if (XFACE (face)->dirty || UNBOUNDP (cachel->face))
    {
      int default_face = EQ (face, Vdefault_face);
      cachel->face = face;

      /* We normally only set the _specified flags if the value was
	 actually bound.  The exception is for the default face where
	 we always set it since it is the ultimate fallback. */

      FROB (foreground);
      FROB (foreback);
      FROB (background);
      FROB (display_table);

      /* #### WARNING: the background pixmap property of faces is currently
	 the only one dealing with images. The problem we have here is that
	 frobbing the background pixmap might lead to image instantiation
	 which in turn might require that the cache we're building be up to
	 date, hence a crash. Here's a typical scenario of this:

	 - a new window is created and its face cache elements are
	 initialized through a call to reset_face_cachels[1]. At that point,
	 the cache for the default and modeline faces (normaly taken care of
	 by redisplay itself) are null.
	 - the default face has a background pixmap which needs to be
	 instantiated right here, as a consequence of cache initialization.
	 - the background pixmap image happens to be instantiated as a string
	 (this happens on tty's for instance).
	 - In order to do this, we need to compute the string geometry.
	 - In order to do this, we might have to access the window's default
	 face cache. But this is the cache we're building right now, it is
	 null.
	 - BARF !!!!!

	 To sum up, this means that it is in general unsafe to instantiate
	 images before face cache updating is complete (apart from image
	 related face attributes). The solution we use below is to actually
	 detect whether we're building the window's face_cachels for the first
	 time, and simply NOT frob the background pixmap in that case. If
	 other image-related face attributes are ever implemented, they should
	 be protected the same way right here.

	 One note:
	 * See comment in `default_face_font_info' in face.c. Who wrote it ?
	 Maybe we have the beginning of an answer here ?

	 Footnotes:
	 [1] See comment at the top of `allocate_window' in window.c.

	 -- didier
      */
      if (! WINDOWP (domain)
	  || WINDOW_FACE_CACHEL (DOMAIN_XWINDOW (domain), DEFAULT_INDEX))
	{
	  FROB (background_pixmap);
	  MAYBE_UNFROB_BACKGROUND_PIXMAP;
	}

      FROB (background_placement);

#undef FROB
#undef MAYBE_UNFROB_BACKGROUND_PIXMAP

      ensure_face_cachel_contains_charset (cachel, domain, Vcharset_ascii);

#define FROB(field)							     \
  do {									     \
    Lisp_Object new_val =						     \
      FACE_PROPERTY_INSTANCE (face, Q##field, domain, 1, Qzero);	     \
    int bound = 1;							     \
    unsigned int new_val_int;						     \
    if (UNBOUNDP (new_val))						     \
      {									     \
	bound = 0;							     \
	new_val = FACE_PROPERTY_INSTANCE (face, Q##field, domain, 0, Qzero); \
      }									     \
    new_val_int = EQ (new_val, Qt);					     \
    if (cachel->field != new_val_int)					     \
      {									     \
	cachel->field = new_val_int;					     \
	cachel->dirty = 1;						     \
      }									     \
    cachel->field##_specified = bound;					     \
  } while (0)

      FROB (underline);
      FROB (strikethru);
      FROB (highlight);
      FROB (dim);
      FROB (reverse);
      FROB (shrink);
      FROB (blinking);
#undef FROB
    }

  cachel->updated = 1;
}

/* Merge the cachel identified by FINDEX in window W into the given
   cachel. */

static void
merge_face_cachel_data (struct window *w, face_index findex,
			struct face_cachel *cachel)
{
  int offs;

#define FINDEX_FIELD(field)						\
  Dynarr_atp (w->face_cachels, findex)->field

#define FROB(field)							\
  do {									\
    if (!cachel->field##_specified && FINDEX_FIELD (field##_specified))	\
      {									\
	cachel->field = FINDEX_FIELD (field);				\
	cachel->field##_specified = 1;					\
	cachel->dirty = 1;						\
      }									\
  } while (0)

  FROB (foreground);
  FROB (foreback);
  FROB (background);
  FROB (display_table);
  FROB (background_pixmap);
  FROB (background_placement);
  FROB (underline);
  FROB (strikethru);
  FROB (highlight);
  FROB (dim);
  FROB (reverse);
  FROB (shrink);
  FROB (blinking);

  for (offs = 0; offs < NUM_LEADING_BYTES; ++offs)
    {
      if (!(bit_vector_bit(FACE_CACHEL_FONT_SPECIFIED(cachel), offs))
	  && bit_vector_bit(FACE_CACHEL_FONT_SPECIFIED
			    (Dynarr_atp(w->face_cachels, findex)), offs))
	{
	  cachel->font[offs] = FINDEX_FIELD (font[offs]);
	  set_bit_vector_bit(FACE_CACHEL_FONT_SPECIFIED(cachel), offs, 1);
	  /* Also propagate whether we're translating to Unicode for the
	     given face.  */
	  set_bit_vector_bit(FACE_CACHEL_FONT_FINAL_STAGE(cachel), offs,
			     bit_vector_bit(FACE_CACHEL_FONT_FINAL_STAGE
					    (Dynarr_atp(w->face_cachels,
							findex)), offs));
	  cachel->dirty = 1;
	}
    }
#undef FROB
#undef FINDEX_FIELD

  cachel->updated = 1;
}

/* Initialize a cachel. */
/* #### Xft: this function will need to be changed for new font model. */

void
reset_face_cachel (struct face_cachel *cachel)
{
  xzero (*cachel);
  cachel->face = Qunbound;
  cachel->nfaces = 0;
  cachel->merged_faces = 0;
  cachel->foreground = Qunbound;
  cachel->foreback = Qunbound;
  cachel->background = Qunbound;
  {
    int i;

    for (i = 0; i < NUM_LEADING_BYTES; i++)
      cachel->font[i] = Qunbound;
  }
  cachel->display_table = Qunbound;
  cachel->background_pixmap = Qunbound;
  cachel->background_placement = Qunbound;
  FACE_CACHEL_FONT_SPECIFIED (cachel)->size = sizeof(cachel->font_specified);
  FACE_CACHEL_FONT_UPDATED (cachel)->size = sizeof(cachel->font_updated);
}

/* Retrieve the index to a cachel for window W that corresponds to
   the specified face.  If necessary, add a new element to the
   cache. */

face_index
get_builtin_face_cache_index (struct window *w, Lisp_Object face)
{
  int elt;

  if (noninteractive)
    return 0;

  for (elt = 0; elt < Dynarr_length (w->face_cachels); elt++)
    {
      struct face_cachel *cachel = WINDOW_FACE_CACHEL (w, elt);

      if (EQ (cachel->face, face))
	{
	  Lisp_Object window = wrap_window (w);

	  if (!cachel->updated)
	    update_face_cachel_data (cachel, window, face);
	  return elt;
	}
    }

  /* If we didn't find the face, add it and then return its index. */
  add_face_cachel (w, face);
  return elt;
}

void
reset_face_cachels (struct window *w)
{
  /* #### Not initialized in batch mode for the stream device. */
  if (w->face_cachels)
    {
      int i;
      face_index fi;

      for (i = 0; i < Dynarr_length (w->face_cachels); i++)
	{
	  struct face_cachel *cachel = Dynarr_atp (w->face_cachels, i);
	  if (cachel->merged_faces)
	    Dynarr_free (cachel->merged_faces);
	}
      Dynarr_reset (w->face_cachels);
      /* #### NOTE: be careful with the order !
	 The cpp macros DEFAULT_INDEX and MODELINE_INDEX defined in
	 redisplay.h depend on the code below. Please make sure to assert the
	 correct values if you ever add new built-in faces here.
	 -- dvl */
      fi = get_builtin_face_cache_index (w, Vdefault_face);
      assert (noninteractive || fi == DEFAULT_INDEX);
      fi = get_builtin_face_cache_index (w, Vmodeline_face);
      assert (noninteractive || fi == MODELINE_INDEX);
      XFRAME (w->frame)->window_face_cache_reset = 1;
    }
}

void
mark_face_cachels_as_clean (struct window *w)
{
  int elt;

  for (elt = 0; elt < Dynarr_length (w->face_cachels); elt++)
    Dynarr_atp (w->face_cachels, elt)->dirty = 0;
}

/* #### Xft: this function will need to be changed for new font model. */
void
mark_face_cachels_as_not_updated (struct window *w)
{
  int elt;

  for (elt = 0; elt < Dynarr_length (w->face_cachels); elt++)
    {
      struct face_cachel *cachel = Dynarr_atp (w->face_cachels, elt);

      cachel->updated = 0;
      memset(FACE_CACHEL_FONT_UPDATED(cachel)->bits, 0,
	     BIT_VECTOR_LONG_STORAGE (NUM_LEADING_BYTES));
    }
}

#ifdef MEMORY_USAGE_STATS

int
compute_face_cachel_usage (face_cachel_dynarr *face_cachels,
			   struct usage_stats *ustats)
{
  int total = 0;

  if (face_cachels)
    {
      int i;

      total += Dynarr_memory_usage (face_cachels, ustats);
      for (i = 0; i < Dynarr_length (face_cachels); i++)
	{
	  int_dynarr *merged = Dynarr_at (face_cachels, i).merged_faces;
	  if (merged)
	    total += Dynarr_memory_usage (merged, ustats);
	}
    }

  return total;
}

#endif /* MEMORY_USAGE_STATS */


/*****************************************************************************
 *                             merged face functions                         *
 *****************************************************************************/

/* Compare two merged face cachels to determine whether we have to add
   a new entry to the face cache.

   Note that we do not compare the attributes, but just the faces the
   cachels are based on.  If they are the same, then the cachels certainly
   ought to have the same attributes, except in the case where fonts
   for different charsets have been determined in the two -- and in that
   case this difference is fine. */

static int
compare_merged_face_cachels (struct face_cachel *cachel1,
			     struct face_cachel *cachel2)
{
  int i;

  if (!EQ (cachel1->face, cachel2->face)
      || cachel1->nfaces != cachel2->nfaces)
    return 0;

  for (i = 0; i < cachel1->nfaces; i++)
    if (FACE_CACHEL_FINDEX_UNSAFE (cachel1, i)
	!= FACE_CACHEL_FINDEX_UNSAFE (cachel2, i))
      return 0;

  return 1;
}

/* Retrieve the index to a cachel for window W that corresponds to
   the specified cachel.  If necessary, add a new element to the
   cache.  This is similar to get_builtin_face_cache_index() but
   is intended for merged cachels rather than for cachels representing
   just a face.

   Note that a merged cachel for just one face is not the same as
   the simple cachel for that face, because it is also merged with
   the default face. */

static face_index
get_merged_face_cache_index (struct window *w,
			     struct face_cachel *merged_cachel)
{
  int elt;
  int cache_size = Dynarr_length (w->face_cachels);

  for (elt = 0; elt < cache_size; elt++)
    {
      struct face_cachel *cachel =
	Dynarr_atp (w->face_cachels, elt);

      if (compare_merged_face_cachels (cachel, merged_cachel))
	return elt;
    }

  /* We didn't find it so add this instance to the cache. */
  merged_cachel->updated = 1;
  merged_cachel->dirty = 1;
  Dynarr_add (w->face_cachels, *merged_cachel);
  return cache_size;
}

face_index
get_extent_fragment_face_cache_index (struct window *w,
				      struct extent_fragment *ef)
{
  struct face_cachel cachel;
  int len = Dynarr_length (ef->extents);
  face_index findex = 0;

  /* Optimize the default case. */
  if (len == 0)
    return DEFAULT_INDEX;
  else
    {
      int i;

      /* Merge the faces of the extents together in order. */

      reset_face_cachel (&cachel);

      for (i = len - 1; i >= 0; i--)
	{
	  EXTENT current = Dynarr_at (ef->extents, i);
	  int has_findex = 0;
	  Lisp_Object face = extent_face (current);

	  if (FACEP (face))
	    {
	      findex = get_builtin_face_cache_index (w, face);
	      has_findex = 1;
	      merge_face_cachel_data (w, findex, &cachel);
	    }
	  /* remember, we're called from within redisplay
	     so we can't error. */
	  else while (CONSP (face))
	    {
	      Lisp_Object one_face = XCAR (face);
	      if (FACEP (one_face))
		{
		  findex = get_builtin_face_cache_index (w, one_face);
		  merge_face_cachel_data (w, findex, &cachel);

		  /* code duplication here but there's no clean
		     way to avoid it. */
		  if (cachel.nfaces >= NUM_STATIC_CACHEL_FACES)
		    {
		      if (!cachel.merged_faces)
			cachel.merged_faces = Dynarr_new (int);
		      Dynarr_add (cachel.merged_faces, findex);
		    }
		  else
		    cachel.merged_faces_static[cachel.nfaces] = findex;
		  cachel.nfaces++;
		}
	      face = XCDR (face);
	    }

	  if (has_findex)
	    {
	      if (cachel.nfaces >= NUM_STATIC_CACHEL_FACES)
		{
		  if (!cachel.merged_faces)
		    cachel.merged_faces = Dynarr_new (int);
		  Dynarr_add (cachel.merged_faces, findex);
		}
	      else
		cachel.merged_faces_static[cachel.nfaces] = findex;
	      cachel.nfaces++;
	    }
	}

      /* Now finally merge in the default face. */
      findex = get_builtin_face_cache_index (w, Vdefault_face);
      merge_face_cachel_data (w, findex, &cachel);

      findex = get_merged_face_cache_index (w, &cachel);
      if (cachel.merged_faces &&
	  /* merged_faces did not get stored and available via return value */
	  Dynarr_at (w->face_cachels, findex).merged_faces !=
	  cachel.merged_faces)
	{
	  Dynarr_free (cachel.merged_faces);
	  cachel.merged_faces = 0;
	}
      return findex;
    }
}

/* Return a cache index for window W from merging the faces in FACE_LIST.
   COUNT is the number of faces in the list.

   The default face should not be included in the list, as it is always
   implicitly merged into the cachel.

   WARNING: this interface may change. */

face_index
merge_face_list_to_cache_index (struct window *w,
				Lisp_Object *face_list, int count)
{
  int i;
  face_index findex = 0;
  struct face_cachel cachel;

  reset_face_cachel (&cachel);

  for (i = 0; i < count; i++)
    {
      Lisp_Object face = face_list[i];

      if (!NILP (face))
	{
	  CHECK_FACE(face);	/* #### presumably unnecessary */
	  findex = get_builtin_face_cache_index (w, face);
	  merge_face_cachel_data (w, findex, &cachel);
	}
    }

  /* Now finally merge in the default face. */
  findex = get_builtin_face_cache_index (w, Vdefault_face);
  merge_face_cachel_data (w, findex, &cachel);

  return get_merged_face_cache_index (w, &cachel);
}


/*****************************************************************************
 interface functions
 ****************************************************************************/

static void
update_EmacsFrame (Lisp_Object frame, Lisp_Object name)
{
  struct frame *frm = XFRAME (frame);

  if (!FRAME_LIVE_P(frm))
    return;

  if (EQ (name, Qfont))
    MARK_FRAME_SIZE_SLIPPED (frm);

  MAYBE_FRAMEMETH (frm, update_frame_external_traits, (frm, name));
}

static void
update_EmacsFrames (Lisp_Object locale, Lisp_Object name)
{
  if (FRAMEP (locale))
    {
      update_EmacsFrame (locale, name);
    }
  else if (DEVICEP (locale))
    {
      Lisp_Object frmcons;

      DEVICE_FRAME_LOOP (frmcons, XDEVICE (locale))
	update_EmacsFrame (XCAR (frmcons), name);
    }
  else if (EQ (locale, Qglobal) || EQ (locale, Qfallback))
    {
      Lisp_Object frmcons, devcons, concons;

      FRAME_LOOP_NO_BREAK (frmcons, devcons, concons)
	update_EmacsFrame (XCAR (frmcons), name);
    }
}

void
update_frame_face_values (struct frame *f)
{
  Lisp_Object frm = wrap_frame (f);

  update_EmacsFrame (frm, Qforeground);
  update_EmacsFrame (frm, Qbackground);
  update_EmacsFrame (frm, Qfont);
}

void
face_property_was_changed (Lisp_Object face, Lisp_Object property,
			   Lisp_Object locale)
{
  int default_face = EQ (face, Vdefault_face);

  /* If the locale could affect the frame value, then call
     update_EmacsFrames just in case. */
  if (default_face &&
      (EQ (property, Qforeground)	||
       EQ (property, Qbackground)	||
       EQ (property, Qfont)))
    update_EmacsFrames (locale, property);

  if (WINDOWP (locale))
    {
      MARK_FRAME_FACES_CHANGED (XFRAME (XWINDOW (locale)->frame));
    }
  else if (FRAMEP (locale))
    {
      MARK_FRAME_FACES_CHANGED (XFRAME (locale));
    }
  else if (DEVICEP (locale))
    {
      MARK_DEVICE_FRAMES_FACES_CHANGED (XDEVICE (locale));
    }
  else
    {
      Lisp_Object devcons, concons;
      DEVICE_LOOP_NO_BREAK (devcons, concons)
	MARK_DEVICE_FRAMES_FACES_CHANGED (XDEVICE (XCAR (devcons)));
    }

  /*
   * This call to update_faces_inheritance isn't needed and makes
   * creating and modifying faces _very_ slow.  The point of
   * update_face_inheritances is to find all faces that inherit
   * directly from this face property and set the specifier "dirty"
   * flag on the corresponding specifier.  This forces recaching of
   * cached specifier values in frame and window struct slots.  But
   * currently no face properties are cached in frame and window
   * struct slots, so calling this function does nothing useful!
   *
   * Further, since update_faces_inheritance maps over the whole
   * face table every time it is called, it gets terribly slow when
   * there are many faces.  Creating 500 faces on a 50Mhz 486 took
   * 433 seconds when update_faces_inheritance was called.  With the
   * call commented out, creating those same 500 faces took 0.72
   * seconds.
   */
  /* update_faces_inheritance (face, property);*/
  XFACE (face)->dirty = 1;
}

DEFUN ("copy-face", Fcopy_face, 2, 6, 0, /*
Define and return a new face which is a copy of an existing one,
or makes an already-existing face be exactly like another.
LOCALE, TAG-SET, EXACT-P, and HOW-TO-ADD are as in `copy-specifier'.
*/
       (old_face, new_name, locale, tag_set, exact_p, how_to_add))
{
  Lisp_Face *fold, *fnew;
  Lisp_Object new_face = Qnil;
  struct gcpro gcpro1, gcpro2, gcpro3, gcpro4;

  old_face = Fget_face (old_face);

  /* We GCPRO old_face because it might be temporary, and GCing could
     occur in various places below. */
  GCPRO4 (tag_set, locale, old_face, new_face);
  /* check validity of how_to_add now. */
  decode_how_to_add_specification (how_to_add);
  /* and of tag_set. */
  tag_set = decode_specifier_tag_set (tag_set);
  /* and of locale. */
  locale = decode_locale_list (locale);

  new_face = Ffind_face (new_name);
  if (NILP (new_face))
    {
      Lisp_Object temp;

      CHECK_SYMBOL (new_name);

      /* Create the new face with the same status as the old face. */
      temp = (NILP (Fgethash (old_face, Vtemporary_faces_cache, Qnil))
	      ? Qnil
	      : Qt);

      new_face = Fmake_face (new_name, Qnil, temp);
    }

  fold = XFACE (old_face);
  fnew = XFACE (new_face);

#define COPY_PROPERTY(property) \
  Fcopy_specifier (fold->property, fnew->property, \
		   locale, tag_set, exact_p, how_to_add);

  COPY_PROPERTY (foreground);
  COPY_PROPERTY (foreback);
  COPY_PROPERTY (background);
  COPY_PROPERTY (font);
  COPY_PROPERTY (display_table);
  COPY_PROPERTY (background_pixmap);
  COPY_PROPERTY (background_placement);
  COPY_PROPERTY (underline);
  COPY_PROPERTY (strikethru);
  COPY_PROPERTY (highlight);
  COPY_PROPERTY (dim);
  COPY_PROPERTY (blinking);
  COPY_PROPERTY (reverse);
  COPY_PROPERTY (shrink);
#undef COPY_PROPERTY
  /* #### should it copy the individual specifiers, if they exist? */
  fnew->plist = Fcopy_sequence (fold->plist);

  UNGCPRO;

  return new_name;
}

#ifdef MULE

Lisp_Object Qone_dimensional, Qtwo_dimensional, Qx_coverage_instantiator;

DEFUN ("specifier-tag-one-dimensional-p",
       Fspecifier_tag_one_dimensional_p,
       1, 1, 0, /*
Return non-nil if (charset-dimension CHARSET) is 1.

Used by the X11 platform font code; see `define-specifier-tag'.  You
shouldn't ever need to call this yourself.
*/
       (charset))
{
  CHECK_CHARSET (charset);
  return (1 == XCHARSET_DIMENSION (charset)) ? Qt : Qnil;
}

DEFUN ("specifier-tag-two-dimensional-p",
       Fspecifier_tag_two_dimensional_p,
       1, 1, 0, /*
Return non-nil if (charset-dimension CHARSET) is 2.

Used by the X11 platform font code; see `define-specifier-tag'.  You
shouldn't ever need to call this yourself.
*/
       (charset))
{
  CHECK_CHARSET (charset);
  return (2 == XCHARSET_DIMENSION (charset)) ? Qt : Qnil;
}

DEFUN ("specifier-tag-final-stage-p",
       Fspecifier_tag_final_stage_p,
       2, 2, 0, /*
Return non-nil if STAGE is 'final.

Used by the X11 platform font code for giving fallbacks; see
`define-specifier-tag'.  You shouldn't ever need to call this.
*/
       (UNUSED (charset), stage))
{
  return EQ (stage, Qfinal) ? Qt : Qnil;
}

DEFUN ("specifier-tag-initial-stage-p",
       Fspecifier_tag_initial_stage_p,
       2, 2, 0, /*
Return non-nil if STAGE is 'initial.

Used by the X11 platform font code for giving fallbacks; see
`define-specifier-tag'.  You shouldn't ever need to call this.
*/
       (UNUSED(charset), stage))
{
  return EQ(stage, Qinitial) ? Qt : Qnil;
}

DEFUN ("specifier-tag-encode-as-utf-8-p",
       Fspecifier_tag_encode_as_utf_8_p,
       2, 2, 0, /*
Return t if and only if (charset-property CHARSET 'encode-as-utf-8)).

Used by the X11 platform font code; see `define-specifier-tag'.  You
shouldn't ever need to call this.
*/
       (charset, UNUSED(stage)))
{
  /* Used to check that the stage was initial too. */
  CHECK_CHARSET(charset);
  return XCHARSET_ENCODE_AS_UTF_8(charset) ? Qt : Qnil;
}

#endif /* MULE */


void
face_objects_create (void)
{
  OBJECT_HAS_METHOD (face, getprop);
  OBJECT_HAS_METHOD (face, putprop);
  OBJECT_HAS_METHOD (face, remprop);
  OBJECT_HAS_METHOD (face, plist);
}

void
syms_of_faces (void)
{
  INIT_LISP_OBJECT (face);

  /* Qdefault, Qwidget, Qleft_margin, Qright_margin defined in general.c */
  DEFSYMBOL (Qmodeline);
  DEFSYMBOL (Qgui_element);
  DEFSYMBOL (Qtext_cursor);
  DEFSYMBOL (Qvertical_divider);

  DEFSUBR (Ffacep);
  DEFSUBR (Ffind_face);
  DEFSUBR (Fget_face);
  DEFSUBR (Fface_name);
  DEFSUBR (Fbuilt_in_face_specifiers);
  DEFSUBR (Fface_list);
  DEFSUBR (Fmake_face);
  DEFSUBR (Fcopy_face);

#ifdef MULE
  DEFSYMBOL (Qone_dimensional);
  DEFSYMBOL (Qtwo_dimensional);
  DEFSYMBOL (Qx_coverage_instantiator);

  /* I would much prefer these were in Lisp. */
  DEFSUBR (Fspecifier_tag_one_dimensional_p);
  DEFSUBR (Fspecifier_tag_two_dimensional_p);
  DEFSUBR (Fspecifier_tag_initial_stage_p);
  DEFSUBR (Fspecifier_tag_final_stage_p);
  DEFSUBR (Fspecifier_tag_encode_as_utf_8_p);
#endif /* MULE */

  DEFSYMBOL (Qfacep);
  DEFSYMBOL (Qforeground);
  DEFSYMBOL (Qforeback);
  DEFSYMBOL (Qbackground);
  /* Qfont defined in general.c */
  DEFSYMBOL (Qdisplay_table);
  DEFSYMBOL (Qbackground_pixmap);
  DEFSYMBOL (Qbackground_placement);
  DEFSYMBOL (Qunderline);
  DEFSYMBOL (Qstrikethru);
  /* Qhighlight, Qreverse defined in general.c */
  DEFSYMBOL (Qdim);
  DEFSYMBOL (Qblinking);
  DEFSYMBOL (Qshrink);

  DEFSYMBOL (Qface_alias);
  DEFERROR_STANDARD (Qcyclic_face_alias, Qinvalid_state);

  DEFSYMBOL (Qinit_face_from_resources);
  DEFSYMBOL (Qinit_global_faces);
  DEFSYMBOL (Qinit_device_faces);
  DEFSYMBOL (Qinit_frame_faces);

  DEFKEYWORD (Q_name);
}

void
structure_type_create_faces (void)
{
  struct structure_type *st;

  st = define_structure_type (Qface, face_validate, face_instantiate);
#ifdef NEED_TO_HANDLE_21_4_CODE
  define_structure_type_keyword (st, Qname, face_name_validate);
#endif
  define_structure_type_keyword (st, Q_name, face_name_validate);
}

void
vars_of_faces (void)
{
  staticpro (&Vpermanent_faces_cache);
  Vpermanent_faces_cache =
    make_lisp_hash_table (10, HASH_TABLE_NON_WEAK, Qeq);
  staticpro (&Vtemporary_faces_cache);
  Vtemporary_faces_cache =
    make_lisp_hash_table (0, HASH_TABLE_WEAK, Qeq);

  staticpro (&Vdefault_face);
  Vdefault_face = Qnil;
  staticpro (&Vgui_element_face);
  Vgui_element_face = Qnil;
  staticpro (&Vwidget_face);
  Vwidget_face = Qnil;
  staticpro (&Vmodeline_face);
  Vmodeline_face = Qnil;
  staticpro (&Vtoolbar_face);
  Vtoolbar_face = Qnil;

  staticpro (&Vvertical_divider_face);
  Vvertical_divider_face = Qnil;
  staticpro (&Vleft_margin_face);
  Vleft_margin_face = Qnil;
  staticpro (&Vright_margin_face);
  Vright_margin_face = Qnil;
  staticpro (&Vtext_cursor_face);
  Vtext_cursor_face = Qnil;
  staticpro (&Vpointer_face);
  Vpointer_face = Qnil;

#ifdef DEBUG_XEMACS
  DEFVAR_INT ("debug-x-faces", &debug_x_faces /*
If non-zero, display debug information about X faces
*/ );
  debug_x_faces = 0;
#endif

  Vbuilt_in_face_specifiers =
    listu (Qforeground, Qforeback, Qbackground,
	   Qfont, Qdisplay_table, Qbackground_pixmap, Qbackground_placement,
	   Qunderline, Qstrikethru, Qhighlight, Qdim,
	   Qblinking, Qreverse, Qshrink, Qunbound);
  staticpro (&Vbuilt_in_face_specifiers);
}

void
complex_vars_of_faces (void)
{
  /* Create the default face now so we know what it is immediately. */

  Vdefault_face = Qnil; /* so that Fmake_face() doesn't set up a bogus
			   default value */
  Vdefault_face = Fmake_face (Qdefault, build_defer_string ("default face"),
			      Qnil);

  /* Provide some last-resort fallbacks to avoid utter fuckage if
     someone provides invalid values for the global specifications. */

  {
    Lisp_Object fg_fb = Qnil, bg_fb = Qnil, fb_fb = Qnil;

#ifdef HAVE_GTK
    fg_fb = Facons (list1 (Qgtk), build_ascstring ("black"),  fg_fb);
    fb_fb = Facons (list1 (Qgtk), build_ascstring ("gray90"), fb_fb);
    bg_fb = Facons (list1 (Qgtk), build_ascstring ("white"),  bg_fb);
#endif
#ifdef HAVE_X_WINDOWS
    fg_fb = Facons (list1 (Qx), build_ascstring ("black"),  fg_fb);
    fb_fb = Facons (list1 (Qx), build_ascstring ("gray70"), fb_fb);
    bg_fb = Facons (list1 (Qx), build_ascstring ("gray80"), bg_fb);
#endif
#ifdef HAVE_TTY
    fg_fb = Facons (list1 (Qtty), Fvector (0, 0), fg_fb);
    fb_fb = Facons (list1 (Qtty), Fvector (0, 0), fb_fb);
    bg_fb = Facons (list1 (Qtty), Fvector (0, 0), bg_fb);
#endif
#ifdef HAVE_MS_WINDOWS
    fg_fb = Facons (list1 (Qmsprinter), build_ascstring ("black"),  fg_fb);
    fb_fb = Facons (list1 (Qmsprinter), build_ascstring ("gray90"), fb_fb);
    bg_fb = Facons (list1 (Qmsprinter), build_ascstring ("white"),  bg_fb);
    fg_fb = Facons (list1 (Qmswindows), build_ascstring ("black"),  fg_fb);
    fb_fb = Facons (list1 (Qmswindows), build_ascstring ("gray90"), fb_fb);
    bg_fb = Facons (list1 (Qmswindows), build_ascstring ("white"),  bg_fb);
#endif
    set_specifier_fallback (Fget (Vdefault_face, Qforeground, Qnil), fg_fb);
    set_specifier_fallback (Fget (Vdefault_face, Qforeback, Qnil), fb_fb);
    set_specifier_fallback (Fget (Vdefault_face, Qbackground, Qnil), bg_fb);
  }

  {
    Lisp_Object inst_list = Qnil;

#if defined (HAVE_X_WINDOWS) || defined (HAVE_GTK)

#ifdef HAVE_GTK
    Lisp_Object device_symbol = Qgtk;
#else
    Lisp_Object device_symbol = Qx;
#endif

#if defined (HAVE_XFT) || defined (MULE)
    const Ascbyte **fontptr;

    const Ascbyte *fonts[] =
    {
#ifdef HAVE_XFT
      /************** Xft fonts *************/

      /* Note that fontconfig can search for several font families in one
	 call.  We should use this facility. */
      "Monospace-12",
      /* do we need to worry about non-Latin characters for monospace?
	 No, at least in Debian's implementation of Xft.
	 We should recommend that "gothic" and "mincho" aliases be created? */
      "Sazanami Mincho-12",
      /* Japanese #### add encoding info? */
				/* Arphic for Chinese? */
				/* Korean */
#else
      /* The default Japanese fonts installed with XFree86 4.0 use this
	 point size, and the -misc-fixed fonts (which look really bad with
	 Han characters) don't. We need to prefer the former. */
      "-*-*-medium-r-*-*-*-150-*-*-c-*-*-*",
      /* And the Chinese ones, maddeningly, use this one. (But on 4.0, while
	 XListFonts returns them, XLoadQueryFont on the fully-specified XLFD
	 corresponding to one of them fails!) */
      "-*-*-medium-r-*-*-*-160-*-*-c-*-*-*",
      "-*-*-medium-r-*-*-*-170-*-*-c-*-*-*",
#endif
    };
#endif /* defined (HAVE_XFT) || defined (MULE) */

#ifdef MULE

    /* Define some specifier tags for classes of character sets. Combining
       these allows for distinct fallback fonts for distinct dimensions of
       character sets and stages.  */

    define_specifier_tag(Qtwo_dimensional, Qnil,
			 intern ("specifier-tag-two-dimensional-p"));

    define_specifier_tag(Qone_dimensional, Qnil,
			 intern ("specifier-tag-one-dimensional-p"));

    define_specifier_tag(Qinitial, Qnil,
			 intern ("specifier-tag-initial-stage-p"));

    define_specifier_tag(Qfinal, Qnil,
			 intern ("specifier-tag-final-stage-p"));

    define_specifier_tag (Qencode_as_utf_8, Qnil,
			  intern("specifier-tag-encode-as-utf-8-p"));

    /* This tag is used to group those instantiators made available in the
       fallback for the sake of coverage of obscure characters, notably
       Markus Kuhn's misc-fixed fonts. They will be copied from the fallback
       when the default face is determined from X resources at startup.  */
    define_specifier_tag (Qx_coverage_instantiator, Qnil, Qnil);

#endif /* MULE */

#ifdef HAVE_XFT
    for (fontptr = fonts + countof(fonts) - 1; fontptr >= fonts; fontptr--)
      inst_list = Fcons (Fcons (list1 (device_symbol),
				build_cistring (*fontptr)),
			 inst_list);

#else /* !HAVE_XFT */
    inst_list =
      Fcons
      (Fcons
       (list1 (device_symbol),
	/* grrr.  This really does need to be "*", not an XLFD.
	   An unspecified XLFD won't pick up stuff like 10x20. */
	build_ascstring ("*")),
       inst_list);
#ifdef MULE

    /* For Han characters and Ethiopic, we want the misc-fixed font used to
       be distinct from that for alphabetic scripts, because the font
       specified below is distractingly ugly when used for Han characters
       (this is slightly less so) and because its coverage isn't up to
       handling them (well, chiefly, it's not up to handling Ethiopic--we do
       have charset-specific fallbacks for the East Asian charsets.) */
    inst_list =
      Fcons
      (Fcons
       (list4(device_symbol, Qtwo_dimensional, Qfinal, Qx_coverage_instantiator),
	build_ascstring
	("-misc-fixed-medium-r-normal--15-140-75-75-c-90-iso10646-1")),
       inst_list);

    /* Use Markus Kuhn's version of misc-fixed as the font for the font for
       when a given charset's registries can't be found and redisplay for
       that charset falls back to iso10646-1. */

    inst_list =
      Fcons
      (Fcons
       (list4(device_symbol, Qone_dimensional, Qfinal, Qx_coverage_instantiator),
	build_ascstring
	("-misc-fixed-medium-r-semicondensed--13-120-75-75-c-60-iso10646-1")),
       inst_list);

    for (fontptr = fonts + countof(fonts) - 1; fontptr >= fonts; fontptr--)
      inst_list = Fcons (Fcons (list3 (device_symbol,
				       Qtwo_dimensional, Qinitial),
				build_cistring (*fontptr)),
			 inst_list);

    /* We need to set the font for the JIT-ucs-charsets separately from the
       final stage, since otherwise it picks up the two-dimensional
       specification (see specifier-tag-two-dimensional-initial-stage-p
       above). They also use Markus Kuhn's ISO 10646-1 fixed fonts for
       redisplay. */

    inst_list =
      Fcons
      (Fcons
       (list4(device_symbol, Qencode_as_utf_8, Qinitial, Qx_coverage_instantiator),
	build_ascstring
	("-misc-fixed-medium-r-semicondensed--13-120-75-75-c-60-iso10646-1")),
       inst_list);

#endif /* MULE */

    /* Needed to make sure that charsets with non-specified fonts don't
       use bold and oblique first if medium and regular are available. */
    inst_list =
      Fcons
      (Fcons
       (list1 (device_symbol),
	build_ascstring ("-*-*-medium-r-*-*-*-120-*-*-c-*-*-*")),
       inst_list);

    /* With a Cygwin XFree86 install, this returns the best (clearest,
       most readable) font I can find when scaling of bitmap fonts is
       turned on, as it is by default. (WHO IN THE NAME OF CHRIST THOUGHT
       THAT WAS A GOOD IDEA?!?!) The other fonts that used to be specified
       here gave horrendous results. */

    inst_list =
      Fcons
      (Fcons
       (list1 (device_symbol),
	build_ascstring ("-*-lucidatypewriter-medium-r-*-*-*-120-*-*-*-*-*-*")),
       inst_list);

#endif /* !HAVE_XFT */

#endif /* HAVE_X_WINDOWS || HAVE_GTK */

#ifdef HAVE_TTY
    inst_list = Fcons (Fcons (list1 (Qtty), build_ascstring ("normal")),
		       inst_list);
#endif /* HAVE_TTY */

#ifdef HAVE_MS_WINDOWS
    {
       const Ascbyte *mswfonts[] =
	    {
	      "Courier New:Regular:10::",
	      "Courier:Regular:10::",
	      ":Regular:10::"
	    };
       const Ascbyte **mswfontptr;

       for (mswfontptr = mswfonts + countof (mswfonts) - 1;
	    mswfontptr >= mswfonts; mswfontptr--)
	{
	  /* display device */
	  inst_list = Fcons (Fcons (list1 (Qmswindows),
				    build_ascstring (*mswfontptr)),
			     inst_list);
	  /* printer device */
	  inst_list = Fcons (Fcons (list1 (Qmsprinter),
				    build_ascstring (*mswfontptr)),
			     inst_list);
	}
       /* Use Lucida Console rather than Courier New if it exists -- the
	  line spacing is much less, so many more lines fit with the same
	  size font. (And it's specifically designed for screens.) */
       inst_list = Fcons (Fcons (list1 (Qmswindows),
				 build_ascstring ("Lucida Console:Regular:10::")),
			  inst_list);
    }
#endif /* HAVE_MS_WINDOWS */

    set_specifier_fallback (Fget (Vdefault_face, Qfont, Qnil), inst_list);
  }

  set_specifier_fallback (Fget (Vdefault_face, Qunderline, Qnil),
			 list1 (Fcons (Qnil, Qnil)));
  set_specifier_fallback (Fget (Vdefault_face, Qstrikethru, Qnil),
			 list1 (Fcons (Qnil, Qnil)));
  set_specifier_fallback (Fget (Vdefault_face, Qhighlight, Qnil),
			 list1 (Fcons (Qnil, Qnil)));
  set_specifier_fallback (Fget (Vdefault_face, Qdim, Qnil),
			 list1 (Fcons (Qnil, Qnil)));
  set_specifier_fallback (Fget (Vdefault_face, Qblinking, Qnil),
			 list1 (Fcons (Qnil, Qnil)));
  set_specifier_fallback (Fget (Vdefault_face, Qreverse, Qnil),
			 list1 (Fcons (Qnil, Qnil)));
  set_specifier_fallback (Fget (Vdefault_face, Qshrink, Qnil),
			 list1 (Fcons (Qnil, Qnil)));

  /* gui-element is the parent face of all gui elements such as
     modeline, vertical divider and toolbar. */
  Vgui_element_face = Fmake_face (Qgui_element,
				  build_defer_string ("gui element face"),
				  Qnil);

  /* Provide some last-resort fallbacks for gui-element face which
     mustn't default to default. */
  {
    Lisp_Object fg_fb = Qnil, bg_fb = Qnil, fb_fb = Qnil;

    /* #### gui-element face doesn't have a font property?
       But it gets referred to later! */
#ifdef HAVE_GTK
    /* We need to put something in there, or error checking gets
       #%!@#ed up before the styles are set, which override the
       fallbacks. */
    fg_fb = Facons (list1 (Qgtk), build_ascstring ("black"), fg_fb);
    fb_fb = Facons (list1 (Qgtk), build_ascstring ("Gray70"), fb_fb);
    bg_fb = Facons (list1 (Qgtk), build_ascstring ("Gray80"), bg_fb);
#endif
#ifdef HAVE_X_WINDOWS
    fg_fb = Facons (list1 (Qx), build_ascstring ("black"), fg_fb);
    fb_fb = Facons (list1 (Qx), build_ascstring ("Gray70"), fb_fb);
    bg_fb = Facons (list1 (Qx), build_ascstring ("Gray80"), bg_fb);
#endif
#ifdef HAVE_TTY
    fg_fb = Facons (list1 (Qtty), Fvector (0, 0), fg_fb);
    fb_fb = Facons (list1 (Qtty), Fvector (0, 0), fb_fb);
    bg_fb = Facons (list1 (Qtty), Fvector (0, 0), bg_fb);
#endif
#ifdef HAVE_MS_WINDOWS
    fg_fb = Facons (list1 (Qmsprinter), build_ascstring ("black"), fg_fb);
    fb_fb = Facons (list1 (Qmsprinter), build_ascstring ("Gray90"), fb_fb);
    bg_fb = Facons (list1 (Qmsprinter), build_ascstring ("white"), bg_fb);
    fg_fb = Facons (list1 (Qmswindows), build_ascstring ("black"), fg_fb);
    fb_fb = Facons (list1 (Qmswindows), build_ascstring ("Gray65"), fb_fb);
    bg_fb = Facons (list1 (Qmswindows), build_ascstring ("Gray75"), bg_fb);
#endif
    set_specifier_fallback (Fget (Vgui_element_face, Qforeground, Qnil),
			    fg_fb);
    set_specifier_fallback (Fget (Vgui_element_face, Qforeback, Qnil),
			    fb_fb);
    set_specifier_fallback (Fget (Vgui_element_face, Qbackground, Qnil),
			    bg_fb);
  }

  /* Now create the other faces that redisplay needs to refer to
     directly.  We could create them in Lisp but it's simpler this
     way since we need to get them anyway. */

  /* modeline is gui element. */
  Vmodeline_face = Fmake_face (Qmodeline, build_defer_string ("modeline face"),
			       Qnil);

  set_specifier_fallback (Fget (Vmodeline_face, Qforeground, Qunbound),
			  Fget (Vgui_element_face, Qforeground, Qunbound));
  set_specifier_fallback (Fget (Vmodeline_face, Qforeback, Qunbound),
			  Fget (Vgui_element_face, Qforeback, Qunbound));
  set_specifier_fallback (Fget (Vmodeline_face, Qbackground, Qunbound),
			  Fget (Vgui_element_face, Qbackground, Qunbound));
  set_specifier_fallback (Fget (Vmodeline_face, Qbackground_pixmap, Qnil),
			  Fget (Vgui_element_face, Qbackground_pixmap,
				Qunbound));
  set_specifier_fallback (Fget (Vmodeline_face, Qbackground_placement, Qnil),
			  Fget (Vgui_element_face, Qbackground_placement,
				Qunbound));

  /* toolbar is another gui element */
  Vtoolbar_face = Fmake_face (Qtoolbar,
			      build_defer_string ("toolbar face"),
			      Qnil);
  set_specifier_fallback (Fget (Vtoolbar_face, Qforeground, Qunbound),
			  Fget (Vgui_element_face, Qforeground, Qunbound));
  set_specifier_fallback (Fget (Vtoolbar_face, Qforeback, Qunbound),
			  Fget (Vgui_element_face, Qforeback, Qunbound));
  set_specifier_fallback (Fget (Vtoolbar_face, Qbackground, Qunbound),
			  Fget (Vgui_element_face, Qbackground, Qunbound));
  set_specifier_fallback (Fget (Vtoolbar_face, Qbackground_pixmap, Qnil),
			  Fget (Vgui_element_face, Qbackground_pixmap,
				Qunbound));
  set_specifier_fallback (Fget (Vtoolbar_face, Qbackground_placement, Qnil),
			  Fget (Vgui_element_face, Qbackground_placement,
				Qunbound));

  /* vertical divider is another gui element */
  Vvertical_divider_face = Fmake_face (Qvertical_divider,
				       build_defer_string ("vertical divider face"),
				       Qnil);

  set_specifier_fallback (Fget (Vvertical_divider_face, Qforeground, Qunbound),
			  Fget (Vgui_element_face, Qforeground, Qunbound));
  set_specifier_fallback (Fget (Vvertical_divider_face, Qforeback, Qunbound),
			  Fget (Vgui_element_face, Qforeback, Qunbound));
  set_specifier_fallback (Fget (Vvertical_divider_face, Qbackground, Qunbound),
			  Fget (Vgui_element_face, Qbackground, Qunbound));
  set_specifier_fallback (Fget (Vvertical_divider_face, Qbackground_pixmap,
				Qunbound),
			  Fget (Vgui_element_face, Qbackground_pixmap,
				Qunbound));
  set_specifier_fallback (Fget (Vvertical_divider_face, Qbackground_placement,
				Qnil),
			  Fget (Vgui_element_face, Qbackground_placement,
				Qunbound));

  /* widget is another gui element */
  Vwidget_face = Fmake_face (Qwidget,
			     build_defer_string ("widget face"),
			     Qnil);
  /* #### weird ... the gui-element face doesn't have its own font yet */
  set_specifier_fallback (Fget (Vwidget_face, Qfont, Qunbound),
			  Fget (Vgui_element_face, Qfont, Qunbound));
  set_specifier_fallback (Fget (Vwidget_face, Qforeground, Qunbound),
			  Fget (Vgui_element_face, Qforeground, Qunbound));
  set_specifier_fallback (Fget (Vwidget_face, Qforeback, Qunbound),
			  Fget (Vgui_element_face, Qforeback, Qunbound));
  set_specifier_fallback (Fget (Vwidget_face, Qbackground, Qunbound),
			  Fget (Vgui_element_face, Qbackground, Qunbound));
  /* We don't want widgets to have a default background pixmap. */

  Vleft_margin_face = Fmake_face (Qleft_margin,
				  build_defer_string ("left margin face"),
				  Qnil);
  Vright_margin_face = Fmake_face (Qright_margin,
				   build_defer_string ("right margin face"),
				   Qnil);
  Vtext_cursor_face = Fmake_face (Qtext_cursor,
				  build_defer_string ("face for text cursor"),
				  Qnil);
  Vpointer_face =
    Fmake_face (Qpointer,
		build_defer_string
		("face for foreground/background colors of mouse pointer"),
		Qnil);
}
