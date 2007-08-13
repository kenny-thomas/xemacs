/* mswindows-specific glyphs and related.
   Copyright (C) 1993, 1994 Free Software Foundation, Inc.
   Copyright (C) 1995 Board of Trustees, University of Illinois.
   Copyright (C) 1995, 1996 Ben Wing
   Copyright (C) 1995 Sun Microsystems, Inc.

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

/* Synched up with:  Not in FSF. */

#ifndef _XEMACS_GLYPHS_MSW_H_
#define _XEMACS_GLYPHS_MSW_H_

#ifdef HAVE_MS_WINDOWS

#include <windows.h>
#include "glyphs.h"

/****************************************************************************
 *                         Image-Instance Object                            *
 ****************************************************************************/

struct mswindows_image_instance_data
{
  HBITMAP bitmap;
  HBITMAP mask;
  HICON icon;
};

#define MSWINDOWS_IMAGE_INSTANCE_DATA(i) \
((struct mswindows_image_instance_data *) (i)->data)

#define IMAGE_INSTANCE_MSWINDOWS_BITMAP(i) \
     (MSWINDOWS_IMAGE_INSTANCE_DATA (i)->bitmap)
#define IMAGE_INSTANCE_MSWINDOWS_MASK(i) \
     (MSWINDOWS_IMAGE_INSTANCE_DATA (i)->mask)
#define IMAGE_INSTANCE_MSWINDOWS_ICON(i) \
     (MSWINDOWS_IMAGE_INSTANCE_DATA (i)->icon)

#define XIMAGE_INSTANCE_MSWINDOWS_BITMAP(i) \
  IMAGE_INSTANCE_MSWINDOWS_BITMAP (XIMAGE_INSTANCE (i))
#define XIMAGE_INSTANCE_MSWINDOWS_MASK(i) \
  IMAGE_INSTANCE_MSWINDOWS_MASK (XIMAGE_INSTANCE (i))
#define XIMAGE_INSTANCE_MSWINDOWS_ICON(i) \
  IMAGE_INSTANCE_MSWINDOWS_ICON (XIMAGE_INSTANCE (i))

int
mswindows_resize_dibitmap_instance (struct Lisp_Image_Instance* ii,
				    struct frame* f,
				    int newx, int newy);
void
mswindows_create_icon_from_image(Lisp_Object image, struct frame* f, int size);

#endif /* HAVE_MS_WINDOWS */
#endif /* _XEMACS_GLYPHS_MSW_H_ */
