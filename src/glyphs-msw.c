/* mswindows-specific glyph objects.
   Copyright (C) 1998, 1999, 2000 Andy Piper.
   Copyright (C) 2001, 2002, 2003, 2004, 2005 Ben Wing.

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

/* This file apparently Mule-ized, 8-7-2000, but could stand review. */

/* written by Andy Piper <andy@xemacs.org> plagiarising bits from
   glyphs-x.c */

#define NEED_MSWINDOWS_COMMCTRL

#include <config.h>
#include "lisp.h"

#include "device-impl.h"
#include "elhash.h"
#include "faces.h"
#include "file-coding.h"
#include "frame-impl.h"
#include "gui.h"
#include "imgproc.h"
#include "insdel.h"
#include "lstream.h"
#include "opaque.h"
#include "sysdep.h"
#include "sysfile.h"
#include "window.h"

#include "console-msw-impl.h"
#include "glyphs-msw.h"
#include "fontcolor-msw-impl.h"

#define WIDGET_GLYPH_SLOT 0

DECLARE_IMAGE_INSTANTIATOR_FORMAT (nothing);
DECLARE_IMAGE_INSTANTIATOR_FORMAT (string);
DECLARE_IMAGE_INSTANTIATOR_FORMAT (formatted_string);
DECLARE_IMAGE_INSTANTIATOR_FORMAT (inherit);
#ifdef HAVE_JPEG
DECLARE_IMAGE_INSTANTIATOR_FORMAT (jpeg);
#endif
#ifdef HAVE_TIFF
DECLARE_IMAGE_INSTANTIATOR_FORMAT (tiff);
#endif
#ifdef HAVE_PNG
DECLARE_IMAGE_INSTANTIATOR_FORMAT (png);
#endif
#ifdef HAVE_GIF
DECLARE_IMAGE_INSTANTIATOR_FORMAT (gif);
#endif
#ifdef HAVE_XPM
DEFINE_DEVICE_IIFORMAT (mswindows, xpm);
DEFINE_DEVICE_IIFORMAT (msprinter, xpm);
#endif
DEFINE_DEVICE_IIFORMAT (mswindows, xbm);
DEFINE_DEVICE_IIFORMAT (msprinter, xbm);
#ifdef HAVE_XFACE
DEFINE_DEVICE_IIFORMAT (mswindows, xface);
DEFINE_DEVICE_IIFORMAT (msprinter, xface);
#endif
DECLARE_IMAGE_INSTANTIATOR_FORMAT (layout);
DEFINE_DEVICE_IIFORMAT (mswindows, native_layout);
DEFINE_DEVICE_IIFORMAT (mswindows, button);
DEFINE_DEVICE_IIFORMAT (mswindows, edit_field);
DEFINE_DEVICE_IIFORMAT (mswindows, subwindow);
DEFINE_DEVICE_IIFORMAT (mswindows, widget);
DEFINE_DEVICE_IIFORMAT (mswindows, label);
DEFINE_DEVICE_IIFORMAT (mswindows, scrollbar);
DEFINE_DEVICE_IIFORMAT (mswindows, combo_box);
DEFINE_DEVICE_IIFORMAT (mswindows, progress_gauge);
DEFINE_DEVICE_IIFORMAT (mswindows, tree_view);
DEFINE_DEVICE_IIFORMAT (mswindows, tab_control);

DEFINE_IMAGE_INSTANTIATOR_FORMAT (bmp);
Lisp_Object Qbmp;
Lisp_Object Vmswindows_bitmap_file_path;
static	COLORREF transparent_color = RGB (1,1,1);

DEFINE_IMAGE_INSTANTIATOR_FORMAT (mswindows_resource);
Lisp_Object Qmswindows_resource;

static void
mswindows_initialize_dibitmap_image_instance (Lisp_Image_Instance *ii,
					     int slices,
					     enum image_instance_type type);
static void
mswindows_initialize_image_instance_mask (Lisp_Image_Instance *image,
					  HDC hcdc);

/*
 * Given device D, retrieve compatible device context. D can be either
 * mswindows or an msprinter device.
 */
inline static HDC
get_device_compdc (struct device *d)
{
  if (DEVICE_MSWINDOWS_P (d))
    return DEVICE_MSWINDOWS_HCDC (d);
  else
    return DEVICE_MSPRINTER_HCDC (d);
}

/*
 * Initialize image instance pixel sizes in II.  For a display bitmap,
 * these will be same as real bitmap sizes.  For a printer bitmap,
 * these will be scaled up so that the bitmap is proportionally enlarged
 * when output to printer.  Redisplay code takes care of scaling, to
 * conserve memory we do not really scale bitmaps.  Set the watermark
 * only here.
 * #### Add support for unscalable bitmaps.
 */
static void init_image_instance_geometry (Lisp_Image_Instance *ii)
{
  struct device *d = DOMAIN_XDEVICE (ii->domain);

  if (/* #### Scaleable && */ DEVICE_MSPRINTER_P (d))
    {
      HDC printer_dc = DEVICE_MSPRINTER_HCDC (d);
      HDC display_dc = CreateCompatibleDC (NULL);
      IMAGE_INSTANCE_PIXMAP_WIDTH (ii) =
	MulDiv (IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (ii),
		GetDeviceCaps (printer_dc, LOGPIXELSX),
		GetDeviceCaps (display_dc, LOGPIXELSX));
      IMAGE_INSTANCE_PIXMAP_HEIGHT (ii) =
	MulDiv (IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_HEIGHT (ii),
		GetDeviceCaps (printer_dc, LOGPIXELSY),
		GetDeviceCaps (display_dc, LOGPIXELSY));
    }
  else
    {
      IMAGE_INSTANCE_PIXMAP_WIDTH (ii) =
	IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (ii);
      IMAGE_INSTANCE_PIXMAP_HEIGHT (ii) =
	IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_HEIGHT (ii);
    }
}

#define BPLINE(width) ((int)(~3UL & (unsigned long)((width) +3)))

/************************************************************************/
/* convert from a series of RGB triples to a BITMAPINFO formated for the*/
/* proper display 							*/
/************************************************************************/
static BITMAPINFO *convert_EImage_to_DIBitmap (Lisp_Object device,
					       int width, int height,
					       Binbyte *pic,
					       int *bit_count,
					       Binbyte **bmp_data)
{
  struct device *d = XDEVICE (device);
  int i, j;
  RGBQUAD *colortbl;
  int ncolors;
  BITMAPINFO *bmp_info;
  Binbyte *ip, *dp;

  if (GetDeviceCaps (get_device_compdc (d), BITSPIXEL) > 0)
    {
      int bpline = BPLINE(width * 3);
      /* FIXME: we can do this because 24bpp implies no color table, once
       * we start palettizing this is no longer true. The X versions of
       * this function quantises to 256 colors or bit masks down to a
       * long. Windows can actually handle rgb triples in the raw so I
       * don't see much point trying to optimize down to the best
       * structure - unless it has memory / color allocation implications
       * .... */
      bmp_info = xnew_and_zero (BITMAPINFO);

      if (!bmp_info)
	{
	  return NULL;
	}

      bmp_info->bmiHeader.biBitCount = 24; /* just RGB triples for now */
      bmp_info->bmiHeader.biCompression = BI_RGB; /* just RGB triples
                                                     for now */
      bmp_info->bmiHeader.biSizeImage = width * height * 3;

      /* bitmap data needs to be in blue, green, red triples - in that
	 order, eimage is in RGB format so we need to convert */
      *bmp_data = xnew_array_and_zero (Binbyte, bpline * height);
      *bit_count = bpline * height;

      if (!bmp_data)
	{
	  xfree (bmp_info);
	  return NULL;
	}

      ip = pic;
      for (i = height-1; i >= 0; i--) {
	dp = (*bmp_data) + (i * bpline);
	for (j = 0; j < width; j++) {
	  dp[2] = *ip++;
	  dp[1] = *ip++;
	  *dp   = *ip++;
	  dp += 3;
	}
      }
    }
  else				/* scale to 256 colors */
    {
      int rd,gr,bl;
      quant_table *qtable;
      int bpline = BPLINE (width * 3);
      /* Quantize the image and get a histogram while we're at it.
	 Do this first to save memory */
      qtable = build_EImage_quantable(pic, width, height, 256);
      if (qtable == NULL) return NULL;

      /* use our quantize table to allocate the colors */
      ncolors = qtable->num_active_colors;
      bmp_info = (BITMAPINFO *)xmalloc_and_zero (sizeof(BITMAPINFOHEADER) +
					     sizeof(RGBQUAD) * ncolors);
      if (!bmp_info)
	{
	  xfree (qtable);
	  return NULL;
	}

      colortbl = (RGBQUAD *) (((Binbyte *) bmp_info) +
			      sizeof (BITMAPINFOHEADER));

      bmp_info->bmiHeader.biBitCount = 8;
      bmp_info->bmiHeader.biCompression = BI_RGB;
      bmp_info->bmiHeader.biSizeImage = bpline * height;
      bmp_info->bmiHeader.biClrUsed = ncolors;
      bmp_info->bmiHeader.biClrImportant = ncolors;

      *bmp_data = xnew_array_and_zero (Binbyte, bpline * height);
      *bit_count = bpline * height;

      if (!*bmp_data)
	{
	  xfree (qtable);
	  xfree (bmp_info);
	  return NULL;
	}

      /* build up an RGBQUAD colortable */
      for (i = 0; i < qtable->num_active_colors; i++)
	{
	  colortbl[i].rgbRed = (BYTE) qtable->rm[i];
	  colortbl[i].rgbGreen = (BYTE) qtable->gm[i];
	  colortbl[i].rgbBlue = (BYTE) qtable->bm[i];
	  colortbl[i].rgbReserved = 0;
	}

      /* now build up the data. picture has to be upside-down and
         back-to-front for msw bitmaps */
      ip = pic;
      for (i = height-1; i >= 0; i--)
	{
	  dp = (*bmp_data) + (i * bpline);
	  for (j = 0; j < width; j++)
	    {
	      rd = *ip++;
	      gr = *ip++;
	      bl = *ip++;
	      *dp++ = QUANT_GET_COLOR (qtable,rd,gr,bl);
	    }
	}
      xfree (qtable);
    }
  /* fix up the standard stuff */
  bmp_info->bmiHeader.biWidth = width;
  bmp_info->bmiHeader.biHeight = height;
  bmp_info->bmiHeader.biPlanes = 1;
  bmp_info->bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmp_info->bmiHeader.biXPelsPerMeter = 0; /* unless you know better */
  bmp_info->bmiHeader.biYPelsPerMeter = 0;

  return bmp_info;
}

/* Given a pixmap filename, look through all of the "standard" places
   where the file might be located.  Return a full pathname if found;
   otherwise, return Qnil. */

static Lisp_Object
mswindows_locate_pixmap_file (Lisp_Object name)
{
  /* This function can GC if IN_REDISPLAY is false */
  Lisp_Object found;

  /* Check non-absolute pathnames with a directory component relative to
     the search path; that's the way Xt does it. */
  if (IS_DIRECTORY_SEP(string_byte (name, 0)) ||
      (string_byte (name, 0) == '.' &&
       (IS_DIRECTORY_SEP(string_byte (name, 1)) ||
	(string_byte (name, 1) == '.' &&
	 (IS_DIRECTORY_SEP(string_byte (name, 2)))))))
    {
      if (!NILP (Ffile_readable_p (name)))
	return Fexpand_file_name (name, Qnil);
      else
	return Qnil;
    }

  if (locate_file (Vmswindows_bitmap_file_path, name, Qnil, &found, R_OK) < 0)
    {
      Lisp_Object temp = list1 (Vdata_directory);
      struct gcpro gcpro1;

      GCPRO1 (temp);
      locate_file (temp, name, Qnil, &found, R_OK);
      UNGCPRO;
    }

  return found;
}


/* Initialize an image instance from a bitmap

   DEST_MASK specifies the mask of allowed image types.

   If this fails, signal an error.  INSTANTIATOR is only used
   in the error message. */

static void
init_image_instance_from_dibitmap (Lisp_Image_Instance *ii,
				   BITMAPINFO *bmp_info,
				   int dest_mask,
				   void *bmp_data,
				   int bmp_bits,
				   int slices,
				   Lisp_Object instantiator,
				   int x_hot, int y_hot,
				   int create_mask)
{
  struct device *d = XDEVICE (IMAGE_INSTANCE_DEVICE (ii));
  void *bmp_buf = 0;
  enum image_instance_type type;
  HBITMAP bitmap;
  HDC hdc;

  if (dest_mask & IMAGE_COLOR_PIXMAP_MASK)
    type = IMAGE_COLOR_PIXMAP;
  else if (dest_mask & IMAGE_POINTER_MASK)
    type = IMAGE_POINTER;
  else
    incompatible_image_types (instantiator, dest_mask,
			      IMAGE_COLOR_PIXMAP_MASK | IMAGE_POINTER_MASK);

  hdc = get_device_compdc (d);
  bitmap = CreateDIBSection (hdc,
			     bmp_info,
			     DIB_RGB_COLORS,
			     &bmp_buf,
			     0, 0);

  if (!bitmap || !bmp_buf)
    signal_image_error ("Unable to create bitmap", instantiator);

  /* copy in the actual bitmap */
  memcpy (bmp_buf, bmp_data, bmp_bits);

  mswindows_initialize_dibitmap_image_instance (ii, slices, type);

  IMAGE_INSTANCE_PIXMAP_FILENAME (ii) =
    find_keyword_in_vector (instantiator, Q_file);

  /* Fixup a set of bitmaps. */
  IMAGE_INSTANCE_MSWINDOWS_BITMAP (ii) = bitmap;

  IMAGE_INSTANCE_MSWINDOWS_MASK (ii) = NULL;
  IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (ii) =
    bmp_info->bmiHeader.biWidth;
  IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_HEIGHT (ii) =
    bmp_info->bmiHeader.biHeight;
  IMAGE_INSTANCE_PIXMAP_DEPTH (ii)   = bmp_info->bmiHeader.biBitCount;
  IMAGE_INSTANCE_PIXMAP_HOTSPOT_X (ii) = make_fixnum (x_hot);
  IMAGE_INSTANCE_PIXMAP_HOTSPOT_Y (ii) = make_fixnum (y_hot);
  init_image_instance_geometry (ii);

  if (create_mask)
    {
      mswindows_initialize_image_instance_mask (ii, hdc);
    }

  if (type == IMAGE_POINTER)
    {
      mswindows_initialize_image_instance_icon(ii, TRUE);
    }
}

static void
image_instance_add_dibitmap (Lisp_Image_Instance *ii,
			     BITMAPINFO *bmp_info,
			     void *bmp_data,
			     int bmp_bits,
			     int slice,
			     Lisp_Object instantiator)
{
  struct device *d = XDEVICE (IMAGE_INSTANCE_DEVICE (ii));
  void *bmp_buf = 0;

  HBITMAP bitmap = CreateDIBSection (get_device_compdc (d),
				     bmp_info,
				     DIB_RGB_COLORS,
				     &bmp_buf,
				     0,0);

  if (!bitmap || !bmp_buf)
    signal_image_error ("Unable to create bitmap", instantiator);

  /* copy in the actual bitmap */
  memcpy (bmp_buf, bmp_data, bmp_bits);
  IMAGE_INSTANCE_MSWINDOWS_BITMAP_SLICE (ii, slice) = bitmap;
}

static void
mswindows_init_image_instance_from_eimage (Lisp_Image_Instance *ii,
					   int width, int height,
					   int slices,
					   Binbyte *eimage,
					   int dest_mask,
					   Lisp_Object instantiator,
					   Lisp_Object UNUSED (pointer_fg),
					   Lisp_Object UNUSED (pointer_bg),
					   Lisp_Object domain)
{
  Lisp_Object device = IMAGE_INSTANCE_DEVICE (ii);
  BITMAPINFO *		bmp_info;
  Binbyte *	bmp_data;
  int			bmp_bits;
  COLORREF		bkcolor;
  int slice;

  CHECK_MSGDI_DEVICE (device);

  /* this is a hack but MaskBlt and TransparentBlt are not supported
     on most windows variants */
  bkcolor = COLOR_INSTANCE_MSWINDOWS_COLOR
    (XCOLOR_INSTANCE (FACE_BACKGROUND (Vdefault_face, domain)));

  for (slice = 0; slice < slices; slice++)
    {
      /* build a bitmap from the eimage */
      if (!(bmp_info = convert_EImage_to_DIBitmap (device, width, height,
						 eimage + (width * height * 3 * slice),
						 &bmp_bits, &bmp_data)))
	{
	  signal_image_error ("EImage to DIBitmap conversion failed",
			      instantiator);
	}

      /* Now create the pixmap and set up the image instance */
      if (slice == 0)
	init_image_instance_from_dibitmap (ii, bmp_info, dest_mask,
					   bmp_data, bmp_bits, slices, instantiator,
					   0, 0, 0);
      else
	image_instance_add_dibitmap (ii, bmp_info, bmp_data, bmp_bits, slice,
				     instantiator);

      xfree (bmp_info);
      xfree (bmp_data);
    }
}

inline static void
set_mono_pixel (Binbyte *bits,
		int bpline, int height,
		int x, int y, int white)
{
  int i;
  Binbyte bitnum;
  /* Find the byte on which this scanline begins */
  i = (height - y - 1) * bpline;
  /* Find the byte containing this pixel */
  i += (x >> 3);
  /* Which bit is it? */
  bitnum = (Binbyte) (7 - (x & 7));
  if (white)	/* Turn it on */
    bits[i] |= (1 << bitnum);
  else          /* Turn it off */
    bits[i] &= ~(1 << bitnum);
}

static void
mswindows_initialize_image_instance_mask (Lisp_Image_Instance *image,
					  HDC hcdc)
{
  HBITMAP mask;
  HGDIOBJ old = NULL;
  Binbyte *dibits, *and_bits;
  BITMAPINFO *bmp_info =
    (BITMAPINFO *) xmalloc_and_zero (sizeof (BITMAPINFO) + sizeof (RGBQUAD));
  int i, j;
  int height = IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_HEIGHT (image);

  int maskbpline = BPLINE ((IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (image) + 7) / 8);
  int bpline = BPLINE (IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (image) * 3);

  if (!bmp_info)
    return;

  bmp_info->bmiHeader.biWidth = IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (image);
  bmp_info->bmiHeader.biHeight = height;
  bmp_info->bmiHeader.biPlanes = 1;
  bmp_info->bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmp_info->bmiHeader.biBitCount = 1;
  bmp_info->bmiHeader.biCompression = BI_RGB;
  bmp_info->bmiHeader.biClrUsed = 2;
  bmp_info->bmiHeader.biClrImportant = 2;
  bmp_info->bmiHeader.biSizeImage = height * maskbpline;
  bmp_info->bmiColors[0].rgbRed = 0;
  bmp_info->bmiColors[0].rgbGreen = 0;
  bmp_info->bmiColors[0].rgbBlue = 0;
  bmp_info->bmiColors[0].rgbReserved = 0;
  bmp_info->bmiColors[1].rgbRed = 255;
  bmp_info->bmiColors[1].rgbGreen = 255;
  bmp_info->bmiColors[1].rgbBlue = 255;
  bmp_info->bmiColors[0].rgbReserved = 0;

  if (!(mask = CreateDIBSection (hcdc,
				 bmp_info,
				 DIB_RGB_COLORS,
				 /* The intermediate cast fools gcc into
				    not outputting strict-aliasing
				    complaints */
				 (void **) (void *) &and_bits,
				 0,0)))
    {
      xfree (bmp_info);
      return;
    }

  old = SelectObject (hcdc, IMAGE_INSTANCE_MSWINDOWS_BITMAP (image));
  /* build up an in-memory set of bits to mess with */
  xzero (*bmp_info);

  bmp_info->bmiHeader.biWidth = IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (image);
  bmp_info->bmiHeader.biHeight = -height;
  bmp_info->bmiHeader.biPlanes = 1;
  bmp_info->bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmp_info->bmiHeader.biBitCount = 24;
  bmp_info->bmiHeader.biCompression = BI_RGB;
  bmp_info->bmiHeader.biClrUsed = 0;
  bmp_info->bmiHeader.biClrImportant = 0;
  bmp_info->bmiHeader.biSizeImage = height * bpline;

  dibits = xnew_array_and_zero (Binbyte, bpline * height);
  if (GetDIBits (hcdc,
		 IMAGE_INSTANCE_MSWINDOWS_BITMAP (image),
		 0,
		 height,
		 dibits,
		 bmp_info,
		 DIB_RGB_COLORS) <= 0)
    {
      xfree (bmp_info);
      return;
    }

  /* now set the colored bits in the mask and transparent ones to
     black in the original */
  for (i = 0; i < IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (image); i++)
    {
      for (j = 0; j < height; j++)
	{
	  Binbyte *idx = &dibits[j * bpline + i * 3];

	  if (RGB (idx[2], idx[1], idx[0]) == transparent_color)
	    {
	      idx[0] = idx[1] = idx[2] = 0;
	      set_mono_pixel (and_bits, maskbpline, height, i, j, TRUE);
	    }
	  else
	    {
	      set_mono_pixel (and_bits, maskbpline, height, i, j, FALSE);
            }
	}
    }

  SetDIBits (hcdc,
	     IMAGE_INSTANCE_MSWINDOWS_BITMAP (image),
	     0,
	     height,
	     dibits,
	     bmp_info,
	     DIB_RGB_COLORS);

  xfree (bmp_info);
  xfree (dibits);

  SelectObject(hcdc, old);

  IMAGE_INSTANCE_MSWINDOWS_MASK (image) = mask;
}

void
mswindows_initialize_image_instance_icon (Lisp_Image_Instance *image,
					  int cursor)
{
  ICONINFO x_icon;

  /* we rely on windows to do any resizing necessary */
  x_icon.fIcon = cursor ? FALSE : TRUE;
  x_icon.xHotspot = XFIXNUM (IMAGE_INSTANCE_PIXMAP_HOTSPOT_X (image));
  x_icon.yHotspot = XFIXNUM (IMAGE_INSTANCE_PIXMAP_HOTSPOT_Y (image));
  x_icon.hbmMask = IMAGE_INSTANCE_MSWINDOWS_MASK (image);
  x_icon.hbmColor = IMAGE_INSTANCE_MSWINDOWS_BITMAP (image);

  IMAGE_INSTANCE_MSWINDOWS_ICON (image)=
    CreateIconIndirect (&x_icon);
}

static HBITMAP
create_resized_bitmap (HBITMAP curbmp, struct frame *f,
		       int curx, int cury,
		       int newx, int newy)
{
  HBITMAP newbmp;
  HGDIOBJ old1, old2;

  HDC hcdc = get_device_compdc (XDEVICE (FRAME_DEVICE (f)));
  HDC hdcDst = CreateCompatibleDC (hcdc);

  old1 = SelectObject (hcdc, curbmp);

  newbmp = CreateCompatibleBitmap (hcdc, newx, newy);

  old2 = SelectObject (hdcDst, newbmp);

  if (!StretchBlt (hdcDst, 0, 0, newx, newy,
		   hcdc, 0, 0,
		   curx,
		   cury,
		   SRCCOPY))
    {
      DeleteObject (newbmp);
      DeleteDC (hdcDst);
      return 0;
    }

  SelectObject (hdcDst, old2);
  SelectObject (hcdc, old1);
  DeleteDC (hdcDst);

  return newbmp;
}

HBITMAP
mswindows_create_resized_bitmap (Lisp_Image_Instance *ii,
				 struct frame *f,
				 int newx, int newy)
{
  return create_resized_bitmap (IMAGE_INSTANCE_MSWINDOWS_BITMAP (ii),
				f,
				IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (ii),
				IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_HEIGHT (ii),
				newx, newy);
}

HBITMAP
mswindows_create_resized_mask (Lisp_Image_Instance *ii,
			       struct frame *f,
			       int newx, int newy)
{
  if (IMAGE_INSTANCE_MSWINDOWS_MASK (ii) == NULL)
    return NULL;

  return create_resized_bitmap (IMAGE_INSTANCE_MSWINDOWS_MASK (ii),
				f,
				IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (ii),
				IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_HEIGHT (ii),
				newx, newy);
}

#if 0 /* Currently unused */
/* #### Warning: This function is not correct anymore with
   resizable printer bitmaps.  If you uncomment it, clean it. --kkm */
int
mswindows_resize_dibitmap_instance (Lisp_Image_Instance *ii,
				    struct frame *f,
				    int newx, int newy)
{
  HBITMAP newbmp = mswindows_create_resized_bitmap (ii, f, newx, newy);
  HBITMAP newmask = mswindows_create_resized_mask (ii, f, newx, newy);

  if (!newbmp)
    return FALSE;

  if (IMAGE_INSTANCE_MSWINDOWS_BITMAP (ii))
    DeleteObject (IMAGE_INSTANCE_MSWINDOWS_BITMAP (ii));
  if (IMAGE_INSTANCE_MSWINDOWS_MASK (ii))
    DeleteObject (IMAGE_INSTANCE_MSWINDOWS_MASK (ii));

  IMAGE_INSTANCE_MSWINDOWS_BITMAP (ii) = newbmp;
  IMAGE_INSTANCE_MSWINDOWS_MASK (ii) = newmask;
  IMAGE_INSTANCE_PIXMAP_WIDTH (ii) = newx;
  IMAGE_INSTANCE_PIXMAP_HEIGHT (ii) = newy;

  return TRUE;
}
#endif

/**********************************************************************
 *                               XPM                                  *
 **********************************************************************/

#ifdef HAVE_XPM

struct color_symbol
{
  Ibyte *	name;
  COLORREF	color;
};

static struct color_symbol *
extract_xpm_color_names (Lisp_Object device,
			 Lisp_Object domain,
			 Lisp_Object color_symbol_alist,
			 int *nsymbols)
{
  /* This function can GC */
  Lisp_Object rest;
  Lisp_Object results = Qnil;
  int i, j;
  struct color_symbol *colortbl;
  struct gcpro gcpro1, gcpro2;

  GCPRO2 (results, device);

  /* We built up results to be (("name" . #<color>) ...) so that if an
     error happens we don't lose any malloc()ed data, or more importantly,
     leave any pixels allocated in the server. */
  i = 0;
  LIST_LOOP (rest, color_symbol_alist)
    {
      Lisp_Object cons = XCAR (rest);
      Lisp_Object name = XCAR (cons);
      Lisp_Object value = XCDR (cons);
      if (NILP (value))
	continue;
      if (STRINGP (value))
	value =
	  Fmake_color_instance
	  (value, device, encode_error_behavior_flag (ERROR_ME_DEBUG_WARN));
      else
        {
          assert (COLOR_SPECIFIERP (value));
          value = Fspecifier_instance (value, domain, Qnil, Qnil);
        }
      if (NILP (value))
        continue;
      results = noseeum_cons (noseeum_cons (name, value), results);
      i++;
    }
  UNGCPRO;			/* no more evaluation */

  *nsymbols = i;
  if (i == 0) return 0;

  colortbl = xnew_array_and_zero (struct color_symbol, i);

  for (j = 0; j < i; j++)
    {
      Lisp_Object cons = XCAR (results);
      colortbl[j].color =
	COLOR_INSTANCE_MSWINDOWS_COLOR (XCOLOR_INSTANCE (XCDR (cons)));

      /* mustn't lose this when we return */
      colortbl[j].name = qxestrdup (XSTRING_DATA (XCAR (cons)));
      free_cons (cons);
      cons = results;
      results = XCDR (results);
      free_cons (cons);
    }
  return colortbl;
}

static int xpm_to_eimage (Lisp_Object image, const Extbyte *buffer,
			  Binbyte **data,
			  int *width, int *height,
			  int *x_hot, int *y_hot,
			  int *transp,
			  struct color_symbol *color_symbols,
			  int nsymbols)
{
  XpmImage xpmimage;
  XpmInfo xpminfo;
  int result, i, j, transp_idx, maskbpline;
  Binbyte *dptr;
  unsigned int *sptr;
  COLORREF color; /* the american spelling virus hits again .. */
  COLORREF *colortbl;

  xzero (xpmimage);
  xzero (xpminfo);
  xpminfo.valuemask = XpmHotspot;
  *transp = FALSE;

  result = XpmCreateXpmImageFromBuffer ((char *)buffer,
				       &xpmimage,
				       &xpminfo);
  switch (result)
    {
    case XpmSuccess:
      break;
    case XpmFileInvalid:
      {
	signal_image_error ("Invalid XPM data", image);
      }
    case XpmNoMemory:
      {
	signal_double_image_error ("Parsing pixmap data",
				   "out of memory", image);
      }
    default:
      {
	signal_double_image_error_2 ("Parsing pixmap data",
				     "unknown error",
				     make_fixnum (result), image);
      }
    }

  *width = xpmimage.width;
  *height = xpmimage.height;
  maskbpline = BPLINE ((~7UL & (unsigned long)(*width + 7)) / 8);

  *data = xnew_array_and_zero (Binbyte, *width * *height * 3);

  if (!*data)
    {
      XpmFreeXpmImage (&xpmimage);
      XpmFreeXpmInfo (&xpminfo);
      return 0;
    }

  /* build a color table to speed things up */
  colortbl = xnew_array_and_zero (COLORREF, xpmimage.ncolors);
  if (!colortbl)
    {
      xfree (*data);
      XpmFreeXpmImage (&xpmimage);
      XpmFreeXpmInfo (&xpminfo);
      return 0;
    }

  for (i = 0; i < (int) xpmimage.ncolors; i++)
    {
      /* goto alert!!!! */
      /* pick up symbolic colors in preference */
      if (xpmimage.colorTable[i].symbolic)
	{
	  if (!strcasecmp (xpmimage.colorTable[i].symbolic, "BgColor")
	      ||
	      !strcasecmp (xpmimage.colorTable[i].symbolic, "None"))
	    {
	      *transp = TRUE;
	      colortbl[i] = transparent_color;
	      transp_idx = i;
	      goto label_found_color;
	    }
	  else if (color_symbols)
	    {
	      for (j = 0; j < nsymbols; j++)
		{
		  if (!qxestrcmp_ascii (color_symbols[j].name,
				    xpmimage.colorTable[i].symbolic))
		    {
		      colortbl[i] = color_symbols[j].color;
		      goto label_found_color;
		    }
		}
	    }
	  else if (xpmimage.colorTable[i].c_color == 0)
	    {
	      goto label_no_color;
	    }
	}
      /* pick up transparencies */
      if (!strcasecmp (xpmimage.colorTable[i].c_color, "None"))
	{
	  *transp = TRUE;
	  colortbl[i] = transparent_color;
	  transp_idx = i;
	  goto label_found_color;
	}
      /* finally pick up a normal color spec */
      if (xpmimage.colorTable[i].c_color)
	{
	  colortbl[i]=
	    mswindows_string_to_color ((Ibyte *)
				       xpmimage.colorTable[i].c_color);
	  goto label_found_color;
	}

    label_no_color:
      xfree (*data);
      xfree (colortbl);
      XpmFreeXpmImage (&xpmimage);
      XpmFreeXpmInfo (&xpminfo);
      return 0;

    label_found_color:;
    }

  /* convert the image */
  sptr = xpmimage.data;
  dptr= *data;
  for (i = 0; i< *width * *height; i++)
    {
      color = colortbl[*sptr++];

      /* split out the 0x02bbggrr colorref into an rgb triple */
      *dptr++=GetRValue (color); /* red */
      *dptr++=GetGValue (color); /* green */
      *dptr++=GetBValue (color); /* blue */
    }

  *x_hot = xpminfo.x_hotspot;
  *y_hot = xpminfo.y_hotspot;

  XpmFreeXpmImage (&xpmimage);
  XpmFreeXpmInfo (&xpminfo);
  xfree (colortbl);
  return TRUE;
}

static void
mswindows_xpm_instantiate (Lisp_Object image_instance,
			   Lisp_Object instantiator,
			   Lisp_Object UNUSED (pointer_fg),
			   Lisp_Object UNUSED (pointer_bg),
			   int dest_mask, Lisp_Object domain)
{
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  Lisp_Object device = IMAGE_INSTANCE_DEVICE (ii);
  const Extbyte		*bytes;
  Bytecount 		len;
  Binbyte		*eimage;
  int			width, height, x_hot, y_hot;
  BITMAPINFO*		bmp_info;
  Binbyte*	bmp_data;
  int			bmp_bits;
  int 			nsymbols = 0, transp;
  struct color_symbol*	color_symbols = NULL;

  Lisp_Object data = find_keyword_in_vector (instantiator, Q_data);
  Lisp_Object color_symbol_alist = find_keyword_in_vector (instantiator,
							   Q_color_symbols);

  CHECK_MSGDI_DEVICE (device);

  assert (!NILP (data));

  LISP_STRING_TO_SIZED_EXTERNAL (data, bytes, len, Qbinary);

  /* in case we have color symbols */
  color_symbols = extract_xpm_color_names (device, domain,
					   color_symbol_alist, &nsymbols);

  /* convert to an eimage to make processing easier */
  if (!xpm_to_eimage (image_instance, bytes, &eimage, &width, &height,
		      &x_hot, &y_hot, &transp, color_symbols, nsymbols))
    {
      signal_image_error ("XPM to EImage conversion failed",
			  image_instance);
    }

  if (color_symbols)
    {
      while (nsymbols--)
	{
	  xfree (color_symbols[nsymbols].name);
	}
      xfree (color_symbols);
    }

  /* build a bitmap from the eimage */
  if (!(bmp_info = convert_EImage_to_DIBitmap (device, width, height, eimage,
					     &bmp_bits, &bmp_data)))
    {
      signal_image_error ("XPM to EImage conversion failed",
			  image_instance);
    }
  xfree (eimage);

  /* Now create the pixmap and set up the image instance */
  init_image_instance_from_dibitmap (ii, bmp_info, dest_mask,
				     bmp_data, bmp_bits, 1, instantiator,
				     x_hot, y_hot, transp);

  xfree (bmp_info);
  xfree (bmp_data);
}
#endif /* HAVE_XPM */

/**********************************************************************
 *                               BMP                                  *
 **********************************************************************/

static void
bmp_validate (Lisp_Object instantiator)
{
  file_or_data_must_be_present (instantiator);
}

static Lisp_Object
bmp_normalize (Lisp_Object inst, Lisp_Object console_type,
	       Lisp_Object UNUSED (dest_mask))
{
  return simple_image_type_normalize (inst, console_type, Qbmp);
}

static int
bmp_possible_dest_types (void)
{
  return IMAGE_COLOR_PIXMAP_MASK;
}

static void
bmp_instantiate (Lisp_Object image_instance, Lisp_Object instantiator,
		 Lisp_Object UNUSED (pointer_fg),
		 Lisp_Object UNUSED (pointer_bg),
		 int dest_mask, Lisp_Object UNUSED (domain))
{
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  Lisp_Object device = IMAGE_INSTANCE_DEVICE (ii);
  const Extbyte		*bytes;
  Bytecount 		len;
  BITMAPFILEHEADER *	bmp_file_header;
  BITMAPINFO *		bmp_info;
  void *			bmp_data;
  int			bmp_bits;
  Lisp_Object data = find_keyword_in_vector (instantiator, Q_data);

  CHECK_MSGDI_DEVICE (device);

  assert (!NILP (data));

  LISP_STRING_TO_SIZED_EXTERNAL (data, bytes, len, Qbinary);

  /* Then slurp the image into memory, decoding along the way.
     The result is the image in a simple one-byte-per-pixel
     format. */

  bmp_file_header = (BITMAPFILEHEADER *)bytes;
  bmp_info = (BITMAPINFO *)(bytes + sizeof(BITMAPFILEHEADER));
  bmp_data = (Extbyte *)bytes + bmp_file_header->bfOffBits;
  bmp_bits = bmp_file_header->bfSize - bmp_file_header->bfOffBits;

  /* Now create the pixmap and set up the image instance */
  init_image_instance_from_dibitmap (ii, bmp_info, dest_mask,
				     bmp_data, bmp_bits, 1, instantiator,
				     0, 0, 0);
}


/**********************************************************************
 *                             RESOURCES                              *
 **********************************************************************/

static void
mswindows_resource_validate (Lisp_Object instantiator)
{
  shared_resource_validate (instantiator);
}

static Lisp_Object
mswindows_resource_normalize (Lisp_Object inst, Lisp_Object console_type,
			      Lisp_Object dest_mask)
{
  return shared_resource_normalize (inst, console_type, dest_mask,
				    Qmswindows_resource);
}

static int
mswindows_resource_possible_dest_types (void)
{
  return IMAGE_POINTER_MASK | IMAGE_COLOR_PIXMAP_MASK;
}

typedef struct
{
  const Ascbyte *name;
  int	resource_id;
} resource_t;

static const resource_t bitmap_table[] =
{
  /* bitmaps */
  { "close", OBM_CLOSE },
  { "uparrow", OBM_UPARROW },
  { "dnarrow", OBM_DNARROW },
  { "rgarrow", OBM_RGARROW },
  { "lfarrow", OBM_LFARROW },
  { "reduce", OBM_REDUCE },
  { "zoom", OBM_ZOOM },
  { "restore", OBM_RESTORE },
  { "reduced", OBM_REDUCED },
  { "zoomd", OBM_ZOOMD },
  { "restored", OBM_RESTORED },
  { "uparrowd", OBM_UPARROWD },
  { "dnarrowd", OBM_DNARROWD },
  { "rgarrowd", OBM_RGARROWD },
  { "lfarrowd", OBM_LFARROWD },
  { "mnarrow", OBM_MNARROW },
  { "combo", OBM_COMBO },
  { "uparrowi", OBM_UPARROWI },
  { "dnarrowi", OBM_DNARROWI },
  { "rgarrowi", OBM_RGARROWI },
  { "lfarrowi", OBM_LFARROWI },
  { "size", OBM_SIZE },
  { "btsize", OBM_BTSIZE },
  { "check", OBM_CHECK },
  { "checkboxes", OBM_CHECKBOXES },
  { "btncorners" , OBM_BTNCORNERS },
  {0}
};

static const resource_t cursor_table[] =
{
  /* cursors */
  { "normal", OCR_NORMAL },
  { "ibeam", OCR_IBEAM },
  { "wait", OCR_WAIT },
  { "cross", OCR_CROSS },
  { "up", OCR_UP },
  /* { "icon", OCR_ICON }, */
  { "sizenwse", OCR_SIZENWSE },
  { "sizenesw", OCR_SIZENESW },
  { "sizewe", OCR_SIZEWE },
  { "sizens", OCR_SIZENS },
  { "sizeall", OCR_SIZEALL },
  /* { "icour", OCR_ICOCUR }, */
  { "no", OCR_NO },
  { 0 }
};

static const resource_t icon_table[] =
{
  /* icons */
  { "sample", OIC_SAMPLE },
  { "hand", OIC_HAND },
  { "ques", OIC_QUES },
  { "bang", OIC_BANG },
  { "note", OIC_NOTE },
  { "winlogo", OIC_WINLOGO },
  {0}
};

static int
resource_name_to_resource (Lisp_Object name, int type)
{
  const resource_t *res = (type == IMAGE_CURSOR ? cursor_table
			   : type == IMAGE_ICON ? icon_table
			   : bitmap_table);

  if (FIXNUMP (name))
    return XFIXNUM (name);
  else if (!STRINGP (name))
    invalid_argument ("invalid resource identifier", name);

  do
    {
      if (!qxestrcasecmp_i18n ((Ibyte *) res->name, XSTRING_DATA (name)))
	return res->resource_id;
    }
  while ((++res)->name);
  return 0;
}

static int
resource_symbol_to_type (Lisp_Object data)
{
  if (EQ (data, Qcursor))
    return IMAGE_CURSOR;
  else if (EQ (data, Qicon))
    return IMAGE_ICON;
  else if (EQ (data, Qbitmap))
    return IMAGE_BITMAP;
  else
    return 0;
}

static void
mswindows_resource_instantiate (Lisp_Object image_instance,
				Lisp_Object instantiator,
				Lisp_Object UNUSED (pointer_fg),
				Lisp_Object UNUSED (pointer_bg),
				int dest_mask, Lisp_Object UNUSED (domain))
{
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  int type = 0;
  HANDLE himage = NULL;
  Extbyte *resid = 0;
  HINSTANCE hinst = NULL;
  ICONINFO iconinfo;
  enum image_instance_type iitype;
  Lisp_Object device = IMAGE_INSTANCE_DEVICE (ii);

  Lisp_Object file = find_keyword_in_vector (instantiator, Q_file);
  Lisp_Object resource_type = find_keyword_in_vector (instantiator,
						      Q_resource_type);
  Lisp_Object resource_id = find_keyword_in_vector (instantiator,
						    Q_resource_id);

  xzero (iconinfo);

  CHECK_MSGDI_DEVICE (device);

  type = resource_symbol_to_type (resource_type);

  if (dest_mask & IMAGE_POINTER_MASK && type == IMAGE_CURSOR)
    iitype = IMAGE_POINTER;
  else if (dest_mask & IMAGE_COLOR_PIXMAP_MASK)
    iitype = IMAGE_COLOR_PIXMAP;
  else
    incompatible_image_types (instantiator, dest_mask,
			      IMAGE_COLOR_PIXMAP_MASK | IMAGE_POINTER_MASK);

  /* mess with the keyword info we were provided with */
  if (!NILP (file))
    {
      Extbyte *fname;

      LISP_LOCAL_FILE_FORMAT_TO_TSTR (file, fname);

      if (NILP (resource_id))
	resid = fname;
      else
	{
	  hinst = qxeLoadLibraryEx (fname, NULL, LOAD_LIBRARY_AS_DATAFILE);
	  resid = MAKEINTRESOURCE (resource_name_to_resource (resource_id,
							      type));

	  if (!resid)
	    resid = LISP_STRING_TO_TSTR (resource_id);
	}
    }
  else if (!(resid = MAKEINTRESOURCE (resource_name_to_resource (resource_id,
								 type))))
    invalid_argument ("Invalid resource identifier", resource_id);

  /* load the image */
  if (!(himage = qxeLoadImage (hinst, resid, type, 0, 0,
			       LR_CREATEDIBSECTION | LR_DEFAULTSIZE |
			       LR_SHARED |
			       (!NILP (file) ? LR_LOADFROMFILE : 0))))
    signal_image_error ("Cannot load image", instantiator);

  if (hinst)
    FreeLibrary (hinst);

  mswindows_initialize_dibitmap_image_instance (ii, 1, iitype);

  IMAGE_INSTANCE_PIXMAP_FILENAME (ii) = file;
  IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (ii) =
    GetSystemMetrics (type == IMAGE_CURSOR ? SM_CXCURSOR : SM_CXICON);
  IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_HEIGHT (ii) =
    GetSystemMetrics (type == IMAGE_CURSOR ? SM_CYCURSOR : SM_CYICON);
  IMAGE_INSTANCE_PIXMAP_DEPTH (ii) = 1;
  init_image_instance_geometry (ii);

  /* hey, we've got an icon type thing so we can reverse engineer the
     bitmap and mask */
  if (type != IMAGE_BITMAP)
    {
      GetIconInfo ((HICON)himage, &iconinfo);
      IMAGE_INSTANCE_MSWINDOWS_BITMAP (ii) = iconinfo.hbmColor;
      IMAGE_INSTANCE_MSWINDOWS_MASK (ii) = iconinfo.hbmMask;
      IMAGE_INSTANCE_PIXMAP_HOTSPOT_X (ii) = make_fixnum (iconinfo.xHotspot);
      IMAGE_INSTANCE_PIXMAP_HOTSPOT_Y (ii) = make_fixnum (iconinfo.yHotspot);
      IMAGE_INSTANCE_MSWINDOWS_ICON (ii) = (HICON) himage;
    }
  else
    {
      IMAGE_INSTANCE_MSWINDOWS_ICON (ii) = NULL;
      IMAGE_INSTANCE_MSWINDOWS_BITMAP (ii) = (HBITMAP) himage;
      IMAGE_INSTANCE_MSWINDOWS_MASK (ii) = NULL;
      IMAGE_INSTANCE_PIXMAP_HOTSPOT_X (ii) = make_fixnum (0);
      IMAGE_INSTANCE_PIXMAP_HOTSPOT_Y (ii) = make_fixnum (0);
    }
}

static void
check_valid_resource_symbol (Lisp_Object data)
{
  CHECK_SYMBOL (data);
  if (!resource_symbol_to_type (data))
    invalid_constant ("invalid resource type", data);
}

static void
check_valid_resource_id (Lisp_Object data)
{
  if (!resource_name_to_resource (data, IMAGE_CURSOR)
      &&
      !resource_name_to_resource (data, IMAGE_ICON)
      &&
      !resource_name_to_resource (data, IMAGE_BITMAP))
    invalid_constant ("invalid resource identifier", data);
}


/**********************************************************************
 *                             XBM                                    *
 **********************************************************************/

/* this table flips four bits around. */
static int flip_table[] =
{
  0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15
};

/* the bitmap data comes in the following format: Widths are padded to
   a multiple of 8.  Scan lines are stored in increasing byte order
   from left to right, little-endian within a byte.  0 = white, 1 =
   black.  It must be converted to the following format: Widths are
   padded to a multiple of 16.  Scan lines are stored in increasing
   byte order from left to right, big-endian within a byte.  0 =
   black, 1 = white.  */
static HBITMAP
xbm_create_bitmap_from_data (HDC hdc, const Binbyte *data,
			     int width, int height,
			     int mask, COLORREF fg, COLORREF bg)
{
  int old_width = (width + 7)/8;
  int new_width = BPLINE (2 * ((width + 15)/16));
  const Binbyte *offset;
  void *bmp_buf = 0;
  Binbyte *new_data, *new_offset;
  int i, j;
  BITMAPINFO *bmp_info =
    (BITMAPINFO *) xmalloc_and_zero (sizeof(BITMAPINFO) + sizeof(RGBQUAD));
  HBITMAP bitmap;

  if (!bmp_info)
    return NULL;

  new_data = xnew_array_and_zero (Binbyte, height * new_width);

  if (!new_data)
    {
      xfree (bmp_info);
      return NULL;
    }

  for (i = 0; i < height; i++)
    {
      offset = data + i * old_width;
      new_offset = new_data + i * new_width;

      for (j = 0; j < old_width; j++)
	{
	  int bite = offset[j];
	  new_offset[j] = ~ (Binbyte)
	    ((flip_table[bite & 0xf] << 4) + flip_table[bite >> 4]);
	}
    }

  /* if we want a mask invert the bits */
  if (!mask)
    {
      new_offset = &new_data[height * new_width];
      while (new_offset-- != new_data)
	{
	  *new_offset ^= 0xff;
	}
    }

  bmp_info->bmiHeader.biWidth = width;
  bmp_info->bmiHeader.biHeight=-(LONG)height;
  bmp_info->bmiHeader.biPlanes = 1;
  bmp_info->bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmp_info->bmiHeader.biBitCount = 1;
  bmp_info->bmiHeader.biCompression = BI_RGB;
  bmp_info->bmiHeader.biClrUsed = 2;
  bmp_info->bmiHeader.biClrImportant = 2;
  bmp_info->bmiHeader.biSizeImage = height * new_width;
  bmp_info->bmiColors[0].rgbRed = GetRValue (fg);
  bmp_info->bmiColors[0].rgbGreen = GetGValue (fg);
  bmp_info->bmiColors[0].rgbBlue = GetBValue (fg);
  bmp_info->bmiColors[0].rgbReserved = 0;
  bmp_info->bmiColors[1].rgbRed = GetRValue (bg);
  bmp_info->bmiColors[1].rgbGreen = GetGValue (bg);
  bmp_info->bmiColors[1].rgbBlue = GetBValue (bg);
  bmp_info->bmiColors[1].rgbReserved = 0;

  bitmap = CreateDIBSection (hdc,
			     bmp_info,
			     DIB_RGB_COLORS,
			     &bmp_buf,
			     0,0);

  xfree (bmp_info);

  if (!bitmap || !bmp_buf)
    {
      xfree (new_data);
      return NULL;
    }

  /* copy in the actual bitmap */
  memcpy (bmp_buf, new_data, height * new_width);
  xfree (new_data);

  return bitmap;
}

/* Given inline data for a mono pixmap, initialize the given
   image instance accordingly. */

static void
init_image_instance_from_xbm_inline (Lisp_Image_Instance *ii,
				     int width, int height,
				     const Binbyte *bits,
				     Lisp_Object instantiator,
				     Lisp_Object pointer_fg,
				     Lisp_Object pointer_bg,
				     int dest_mask,
				     HBITMAP mask,
				     Lisp_Object UNUSED (mask_filename))
{
  Lisp_Object device = IMAGE_INSTANCE_DEVICE (ii);
  Lisp_Object foreground = find_keyword_in_vector (instantiator, Q_foreground);
  Lisp_Object background = find_keyword_in_vector (instantiator, Q_background);
  enum image_instance_type type;
  COLORREF black = PALETTERGB (0,0,0);
  COLORREF white = PALETTERGB (255,255,255);
  HDC hdc;

  CHECK_MSGDI_DEVICE (device);

  hdc = get_device_compdc (XDEVICE (device));

  if ((dest_mask & IMAGE_MONO_PIXMAP_MASK) &&
      (dest_mask & IMAGE_COLOR_PIXMAP_MASK))
    {
      if (!NILP (foreground) || !NILP (background))
	type = IMAGE_COLOR_PIXMAP;
      else
	type = IMAGE_MONO_PIXMAP;
    }
  else if (dest_mask & IMAGE_MONO_PIXMAP_MASK)
    type = IMAGE_MONO_PIXMAP;
  else if (dest_mask & IMAGE_COLOR_PIXMAP_MASK)
    type = IMAGE_COLOR_PIXMAP;
  else if (dest_mask & IMAGE_POINTER_MASK)
    type = IMAGE_POINTER;
  else
    incompatible_image_types (instantiator, dest_mask,
			      IMAGE_MONO_PIXMAP_MASK | IMAGE_COLOR_PIXMAP_MASK
			      | IMAGE_POINTER_MASK);

  mswindows_initialize_dibitmap_image_instance (ii, 1, type);

  IMAGE_INSTANCE_PIXMAP_FILENAME (ii) =
    find_keyword_in_vector (instantiator, Q_file);
  IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_WIDTH (ii) = width;
  IMAGE_INSTANCE_MSWINDOWS_BITMAP_REAL_HEIGHT (ii) = height;
  IMAGE_INSTANCE_PIXMAP_DEPTH (ii) = 1;
  IMAGE_INSTANCE_PIXMAP_HOTSPOT_X (ii) = make_fixnum (0);
  IMAGE_INSTANCE_PIXMAP_HOTSPOT_Y (ii) = make_fixnum (0);
  init_image_instance_geometry (ii);

  IMAGE_INSTANCE_MSWINDOWS_MASK (ii) = mask ? mask :
    xbm_create_bitmap_from_data (hdc, bits, width, height, TRUE, black, white);

  switch (type)
    {
    case IMAGE_MONO_PIXMAP:
      IMAGE_INSTANCE_MSWINDOWS_BITMAP (ii) =
	xbm_create_bitmap_from_data (hdc, bits, width, height,
				     FALSE, black, black);
      break;

    case IMAGE_COLOR_PIXMAP:
      {
	COLORREF fg = black;
	COLORREF bg = white;

	if (!NILP (foreground) && !COLOR_INSTANCEP (foreground))
	  foreground =
	    Fmake_color_instance (foreground, device,
				  encode_error_behavior_flag (ERROR_ME));

	if (COLOR_INSTANCEP (foreground))
	  fg = COLOR_INSTANCE_MSWINDOWS_COLOR (XCOLOR_INSTANCE (foreground));

	if (!NILP (background) && !COLOR_INSTANCEP (background))
	  background =
	    Fmake_color_instance (background, device,
				  encode_error_behavior_flag (ERROR_ME));

	if (COLOR_INSTANCEP (background))
	  bg = COLOR_INSTANCE_MSWINDOWS_COLOR (XCOLOR_INSTANCE (background));

	IMAGE_INSTANCE_PIXMAP_FG (ii) = foreground;
	IMAGE_INSTANCE_PIXMAP_BG (ii) = background;

	IMAGE_INSTANCE_MSWINDOWS_BITMAP (ii) =
	  xbm_create_bitmap_from_data (hdc, bits, width, height,
				       FALSE, fg, black);
      }
      break;

    case IMAGE_POINTER:
      {
	COLORREF fg = black;
	COLORREF bg = white;

	if (NILP (foreground))
	  foreground = pointer_fg;
	if (NILP (background))
	  background = pointer_bg;

	IMAGE_INSTANCE_PIXMAP_HOTSPOT_X (ii) =
	  find_keyword_in_vector (instantiator, Q_hotspot_x);
	IMAGE_INSTANCE_PIXMAP_HOTSPOT_Y (ii) =
	  find_keyword_in_vector (instantiator, Q_hotspot_y);
	IMAGE_INSTANCE_PIXMAP_FG (ii) = foreground;
	IMAGE_INSTANCE_PIXMAP_BG (ii) = background;
	if (COLOR_INSTANCEP (foreground))
	  fg = COLOR_INSTANCE_MSWINDOWS_COLOR (XCOLOR_INSTANCE (foreground));
	if (COLOR_INSTANCEP (background))
	  bg = COLOR_INSTANCE_MSWINDOWS_COLOR (XCOLOR_INSTANCE (background));

	IMAGE_INSTANCE_MSWINDOWS_BITMAP (ii) =
	  xbm_create_bitmap_from_data (hdc, bits, width, height,
				       TRUE, fg, black);
	mswindows_initialize_image_instance_icon (ii, TRUE);
      }
      break;

    default:
      ABORT ();
    }
}

static void
xbm_instantiate_1 (Lisp_Object image_instance, Lisp_Object instantiator,
		   Lisp_Object pointer_fg, Lisp_Object pointer_bg,
		   int dest_mask, int width, int height,
		   const Binbyte *bits)
{
  Lisp_Object mask_data = find_keyword_in_vector (instantiator, Q_mask_data);
  Lisp_Object mask_file = find_keyword_in_vector (instantiator, Q_mask_file);
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  HDC hdc = get_device_compdc (XDEVICE (IMAGE_INSTANCE_DEVICE (ii)));
  HBITMAP mask = 0;

  if (!NILP (mask_data))
    {
      Binbyte *ext_data;

      ext_data =
	(Binbyte *) LISP_STRING_TO_EXTERNAL (XCAR (XCDR (XCDR (mask_data))),
					     Qbinary);
      mask = xbm_create_bitmap_from_data (hdc,
					  ext_data,
					  XFIXNUM (XCAR (mask_data)),
					  XFIXNUM (XCAR (XCDR (mask_data))),
					  FALSE,
					  PALETTERGB (0,0,0),
					  PALETTERGB (255,255,255));
    }

  init_image_instance_from_xbm_inline (ii, width, height, bits,
				       instantiator, pointer_fg, pointer_bg,
				       dest_mask, mask, mask_file);
}

/* Instantiate method for XBM's. */

static void
mswindows_xbm_instantiate (Lisp_Object image_instance,
			   Lisp_Object instantiator,
			   Lisp_Object pointer_fg, Lisp_Object pointer_bg,
			   int dest_mask, Lisp_Object UNUSED (domain))
{
  Lisp_Object data = find_keyword_in_vector (instantiator, Q_data);
  const Binbyte *ext_data;

  assert (!NILP (data));

  ext_data =
    (const Binbyte *) LISP_STRING_TO_EXTERNAL (XCAR (XCDR (XCDR (data))),
					       Qbinary);

  xbm_instantiate_1 (image_instance, instantiator, pointer_fg,
		     pointer_bg, dest_mask, XFIXNUM (XCAR (data)),
		     XFIXNUM (XCAR (XCDR (data))), ext_data);
}

#ifdef HAVE_XFACE
/**********************************************************************
 *                             X-Face                                 *
 **********************************************************************/
#if defined(EXTERN)
/* This is about to get redefined! */
#undef EXTERN
#endif
/* We have to define SYSV32 so that compface.h includes string.h
   instead of strings.h. */
#define SYSV32
BEGIN_C_DECLS
#ifndef __STDC__ /* Needed to avoid prototype warnings */
#define __STDC__
#endif
#include <compface.h>
END_C_DECLS

/* JMP_BUF cannot be used here because if it doesn't get defined
   to jmp_buf we end up with a conflicting type error with the
   definition in compface.h */
extern jmp_buf comp_env;
#undef SYSV32

static void
mswindows_xface_instantiate (Lisp_Object image_instance,
			     Lisp_Object instantiator,
			     Lisp_Object pointer_fg, Lisp_Object pointer_bg,
			     int dest_mask, Lisp_Object UNUSED (domain))
{
  Lisp_Object data = find_keyword_in_vector (instantiator, Q_data);
  int i, stattis;
  Binbyte *p, *bits, *bp;
  const CIbyte * volatile emsg = 0;
  const Binbyte * volatile dstring;

  assert (!NILP (data));

  dstring = (const Binbyte *) LISP_STRING_TO_EXTERNAL (data, Qbinary);

  if ((p = (Binbyte *) strchr ((char *) dstring, ':')))
    {
      dstring = p + 1;
    }

  /* Must use setjmp not SETJMP because we used jmp_buf above not JMP_BUF */
  if (!(stattis = setjmp (comp_env)))
    {
      UnCompAll ((char *) dstring);
      UnGenFace ();
    }

  switch (stattis)
    {
    case -2:
      emsg = "uncompface: internal error";
      break;
    case -1:
      emsg = "uncompface: insufficient or invalid data";
      break;
    case 1:
      emsg = "uncompface: excess data ignored";
      break;
    }

  if (emsg)
    signal_image_error_2 (emsg, data, Qimage);

  bp = bits = alloca_binbytes (PIXELS / 8);

  /* the compface library exports char F[], which uses a single byte per
     pixel to represent a 48x48 bitmap.  Yuck. */
  for (i = 0, p = (Binbyte *) F; i < (PIXELS / 8); ++i)
    {
      int n, b;
      /* reverse the bit order of each byte... */
      for (b = n = 0; b < 8; ++b)
	{
	  n |= ((*p++) << b);
	}
      *bp++ = (Binbyte) n;
    }

  xbm_instantiate_1 (image_instance, instantiator, pointer_fg,
		     pointer_bg, dest_mask, 48, 48, bits);
}
#endif /* HAVE_XFACE */


/************************************************************************/
/*                      image instance methods                          */
/************************************************************************/

static void
mswindows_print_image_instance (Lisp_Image_Instance *p,
				Lisp_Object printcharfun,
				int UNUSED (escapeflag))
{
  switch (IMAGE_INSTANCE_TYPE (p))
    {
    case IMAGE_MONO_PIXMAP:
    case IMAGE_COLOR_PIXMAP:
    case IMAGE_POINTER:
      write_fmt_string (printcharfun, " (0x%lx",
			(unsigned long) IMAGE_INSTANCE_MSWINDOWS_BITMAP (p));
      if (IMAGE_INSTANCE_MSWINDOWS_MASK (p))
	{
	  write_fmt_string (printcharfun, "/0x%lx",
			    (unsigned long) IMAGE_INSTANCE_MSWINDOWS_MASK (p));
	}
      write_ascstring (printcharfun, ")");
      break;

    default:
      break;
    }
}

#ifdef DEBUG_WIDGETS
extern int debug_widget_instances;
#endif

static void
finalize_destroy_window (void *win)
{
  DestroyWindow ((HWND) win);
}

static void
mswindows_finalize_image_instance (Lisp_Image_Instance *p)
{
  if (!p->data)
    return;

  if (DEVICE_LIVE_P (XDEVICE (IMAGE_INSTANCE_DEVICE (p))))
    {
      if (image_instance_type_to_mask (IMAGE_INSTANCE_TYPE (p))
	  & (IMAGE_WIDGET_MASK | IMAGE_SUBWINDOW_MASK))
	{
#ifdef DEBUG_WIDGETS
	  debug_widget_instances--;
	  stderr_out ("widget destroyed, %d left\n", debug_widget_instances);
#endif
	  if (IMAGE_INSTANCE_SUBWINDOW_ID (p))
	    {
	      /* DestroyWindow is not safe here, as it will send messages
		 to our window proc. */
	      register_post_gc_action
		(finalize_destroy_window,
		 (void *) (WIDGET_INSTANCE_MSWINDOWS_HANDLE (p)));
	      register_post_gc_action
		(finalize_destroy_window,
		 (void *) (IMAGE_INSTANCE_MSWINDOWS_CLIPWINDOW (p)));
	      IMAGE_INSTANCE_SUBWINDOW_ID (p) = 0;
	    }
	}
      else if (p->data)
	{
	  int i;
	  if (IMAGE_INSTANCE_PIXMAP_TIMEOUT (p))
	    disable_glyph_animated_timeout (IMAGE_INSTANCE_PIXMAP_TIMEOUT (p));

	  if (IMAGE_INSTANCE_MSWINDOWS_BITMAP_SLICES (p))
	    {
	      for (i = 0; i < IMAGE_INSTANCE_PIXMAP_MAXSLICE (p); i++)
		{
		  if (IMAGE_INSTANCE_MSWINDOWS_BITMAP_SLICE (p, i))
		    DeleteObject (IMAGE_INSTANCE_MSWINDOWS_BITMAP_SLICE (p, i));
		  IMAGE_INSTANCE_MSWINDOWS_BITMAP_SLICE (p, i) = 0;
		}
	      xfree (IMAGE_INSTANCE_MSWINDOWS_BITMAP_SLICES (p));
	      IMAGE_INSTANCE_MSWINDOWS_BITMAP_SLICES (p) = 0;
	    }
	  if (IMAGE_INSTANCE_MSWINDOWS_MASK (p))
	    DeleteObject (IMAGE_INSTANCE_MSWINDOWS_MASK (p));
	  IMAGE_INSTANCE_MSWINDOWS_MASK (p) = 0;
	  if (IMAGE_INSTANCE_MSWINDOWS_ICON (p))
	    DestroyIcon (IMAGE_INSTANCE_MSWINDOWS_ICON (p));
	  IMAGE_INSTANCE_MSWINDOWS_ICON (p) = 0;
	}
    }

  if (p->data)
    {
      xfree (p->data);
      p->data = 0;
    }
}

/************************************************************************/
/*                      subwindow and widget support                    */
/************************************************************************/

static Lisp_Object
charset_of_text (Lisp_Object USED_IF_MULE (text))
{
#ifdef MULE
  Ibyte *p;

  if (NILP (text))
    return Vcharset_ascii;
  for (p = XSTRING_DATA (text); *p;)
    {
      Ichar c = itext_ichar (p);
      if (!EQ (ichar_charset (c), Vcharset_ascii))
	return ichar_charset (c);
      INC_IBYTEPTR (p);
    }
#endif /* MULE */

  return Vcharset_ascii;
}
  

static HFONT
mswindows_widget_hfont (Lisp_Object face,
			Lisp_Object domain,
			Lisp_Object text)
{
  int under = FACE_UNDERLINE_P (face, domain);
  int strike = FACE_STRIKETHRU_P (face, domain);
  Lisp_Object font;
  struct face_cachel frame_cachel;
  struct face_cachel *cachel;
  Lisp_Object charset;

  reset_face_cachel (&frame_cachel);
  update_face_cachel_data (&frame_cachel, domain, face);
  cachel = &frame_cachel;
  /* !!#### This is a big hack.  We return the first non-ASCII charset in
     the string, on the assumption that we can display ASCII characters in
     all fonts.  We really need to draw the text of the widget ourselves;
     or perhaps there are fonts supporting lots of character sets? */
  charset = charset_of_text (text);

  font = FACE_CACHEL_FONT (cachel, charset);

  if (!FONT_INSTANCEP (font))
    font = ensure_face_cachel_contains_charset (cachel, domain, charset);

  if (EQ (font, Vthe_null_font_instance))
    font = FACE_CACHEL_FONT (cachel, Vcharset_ascii);

  return mswindows_get_hfont (XFONT_INSTANCE (font), under, strike);
}

#ifdef DEFER_WINDOW_POS

static HDWP
begin_defer_window_pos (struct frame *f)
{
  if (FRAME_MSWINDOWS_DATA (f)->hdwp == 0)
    FRAME_MSWINDOWS_DATA (f)->hdwp = BeginDeferWindowPos (10);
  return FRAME_MSWINDOWS_DATA (f)->hdwp;
}

#endif

/* unmap the image if it is a widget. This is used by redisplay via
   redisplay_unmap_subwindows */
static void
mswindows_unmap_subwindow (Lisp_Image_Instance *p)
{
  if (IMAGE_INSTANCE_SUBWINDOW_ID (p))
    {
#ifdef DEFER_WINDOW_POS
      struct frame *f = XFRAME (IMAGE_INSTANCE_FRAME (p));
      HDWP hdwp = begin_defer_window_pos (f);
      HDWP new_hdwp;
      new_hdwp = DeferWindowPos (hdwp, IMAGE_INSTANCE_MSWINDOWS_CLIPWINDOW (p),
				 NULL,
				 0, 0, 0, 0,
				 SWP_HIDEWINDOW | SWP_NOACTIVATE |
				 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER
				 /* Setting this flag causes the call to
				    DeferWindowPos to fail with
				    "Invalid parameter".  I don't understand
				    why we bother to try and set this
				    anyway. -- ben */
				 /* | SWP_NOSENDCHANGING */
				 );
      if (!new_hdwp)
	mswindows_output_last_error ("unmapping");
      else
	hdwp = new_hdwp;
      FRAME_MSWINDOWS_DATA (f)->hdwp = hdwp;
#else
      SetWindowPos (IMAGE_INSTANCE_MSWINDOWS_CLIPWINDOW (p),
		    NULL,
		    0, 0, 0, 0,
		    SWP_HIDEWINDOW | SWP_NOACTIVATE |
		    SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER );
#endif
      if (GetFocus() == WIDGET_INSTANCE_MSWINDOWS_HANDLE (p))
	SetFocus (GetParent (IMAGE_INSTANCE_MSWINDOWS_CLIPWINDOW (p)));
    }
}

/* map the subwindow. This is used by redisplay via
   redisplay_output_subwindow */
static void
mswindows_map_subwindow (Lisp_Image_Instance *p, int x, int y,
			 struct display_glyph_area *dga)
{
#ifdef DEFER_WINDOW_POS
  struct frame *f = XFRAME (IMAGE_INSTANCE_FRAME (p));
  HDWP hdwp = begin_defer_window_pos (f);
  HDWP new_hdwp;
#endif
  /* move the window before mapping it ... */
  SetWindowPos (IMAGE_INSTANCE_MSWINDOWS_CLIPWINDOW (p),
		NULL,
		x, y, dga->width, dga->height,
		SWP_NOZORDER
		| SWP_NOCOPYBITS | SWP_NOSENDCHANGING);
  /* ... adjust the child ... */
  SetWindowPos (WIDGET_INSTANCE_MSWINDOWS_HANDLE (p),
		NULL,
		-dga->xoffset, -dga->yoffset, 0, 0,
		SWP_NOZORDER | SWP_NOSIZE
		| SWP_NOCOPYBITS | SWP_NOSENDCHANGING);
  /* ... now map it - we are not allowed to move it at the same time. */
  if (!IMAGE_INSTANCE_SUBWINDOW_DISPLAYEDP (p))
    {
#ifdef DEFER_WINDOW_POS
      new_hdwp = DeferWindowPos
	(hdwp,
	 IMAGE_INSTANCE_MSWINDOWS_CLIPWINDOW (p),
	 NULL, 0, 0, 0, 0,
	 SWP_NOZORDER | SWP_NOSIZE | SWP_NOMOVE
	 | SWP_SHOWWINDOW
	 /* | SWP_NOCOPYBITS */
	 /* Setting this flag causes the call to
	    DeferWindowPos to fail with
	    "Invalid parameter".  I don't understand
	    why we bother to try and set this
	    anyway. -- ben */
	 /* | SWP_NOSENDCHANGING */
	 | SWP_NOACTIVATE);
      if (!new_hdwp)
	mswindows_output_last_error ("mapping");
      else
	hdwp = new_hdwp;
      FRAME_MSWINDOWS_DATA (f)->hdwp = hdwp;
#else
      SetWindowPos (IMAGE_INSTANCE_MSWINDOWS_CLIPWINDOW (p),
		    NULL,
		    0, 0, 0, 0,
		    SWP_NOZORDER | SWP_NOSIZE | SWP_NOMOVE
		    | SWP_SHOWWINDOW | SWP_NOCOPYBITS | SWP_NOACTIVATE);

      /* Doing this once does not seem to be enough, for instance when
	 mapping the search dialog this gets called four times. If we
	 only set on the first time through then the subwindow never
	 gets focus as intended. However, doing this every time doesn't
	 seem so bad, after all we only need to redo this after the
	 focus changes - and if that happens resetting the initial
	 focus doesn't seem so bad. */
      if (IMAGE_INSTANCE_WANTS_INITIAL_FOCUS (p))
	SetFocus (WIDGET_INSTANCE_MSWINDOWS_HANDLE (p));
#endif
    }
}

/* resize the subwindow instance */
static void
mswindows_resize_subwindow (Lisp_Image_Instance *ii, int w, int h)
{
  /* Set the size of the control .... */
  if (!SetWindowPos (WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii),
		     NULL,
		     0, 0, w, h,
		     SWP_NOZORDER | SWP_NOMOVE
		     | SWP_NOCOPYBITS | SWP_NOSENDCHANGING))
    mswindows_output_last_error ("resizing");
}

/* Simply resize the window here. */
static void
mswindows_redisplay_subwindow (Lisp_Image_Instance *p)
{
  mswindows_resize_subwindow (p,
			      IMAGE_INSTANCE_WIDTH (p),
			      IMAGE_INSTANCE_HEIGHT (p));
}

/* when you click on a widget you may activate another widget this
   needs to be checked and all appropriate widgets updated */
static void
mswindows_redisplay_widget (Lisp_Image_Instance *p)
{
  /* Possibly update the face font and colors. */
  if (!NILP (IMAGE_INSTANCE_WIDGET_TEXT (p))
      && (IMAGE_INSTANCE_WIDGET_FACE_CHANGED (p)
	  || XFRAME (IMAGE_INSTANCE_FRAME (p))->faces_changed
	  || IMAGE_INSTANCE_WIDGET_ITEMS_CHANGED (p)))
    {
      /* set the widget font from the widget face */
      qxeSendMessage (WIDGET_INSTANCE_MSWINDOWS_HANDLE (p),
		      WM_SETFONT,
		      (WPARAM) mswindows_widget_hfont 
		      (IMAGE_INSTANCE_WIDGET_FACE (p),
		       IMAGE_INSTANCE_FRAME (p),
		       IMAGE_INSTANCE_WIDGET_TEXT (p)),
		      MAKELPARAM (TRUE, 0));
    }
  /* Possibly update the dimensions. */
  if (IMAGE_INSTANCE_SIZE_CHANGED (p))
    {
      mswindows_resize_subwindow (p,
				  IMAGE_INSTANCE_WIDTH (p),
				  IMAGE_INSTANCE_HEIGHT (p));
    }
  /* Possibly update the text in the widget. */
  if (IMAGE_INSTANCE_TEXT_CHANGED (p)
      && !NILP (IMAGE_INSTANCE_WIDGET_TEXT (p)))
    {
      Extbyte *lparam = 0;
      lparam = LISP_STRING_TO_TSTR (IMAGE_INSTANCE_WIDGET_TEXT (p));
      qxeSendMessage (WIDGET_INSTANCE_MSWINDOWS_HANDLE (p),
		      WM_SETTEXT, 0, (LPARAM) lparam);
    }
  /* Set active state. */
  if (IMAGE_INSTANCE_WIDGET_ITEMS_CHANGED (p))
    {
      Lisp_Object item = IMAGE_INSTANCE_WIDGET_PENDING_ITEMS (p);
      LONG style = qxeGetWindowLong 
	(WIDGET_INSTANCE_MSWINDOWS_HANDLE (p),
	 GWL_STYLE);

      if (CONSP (item))
	item = XCAR (item);

      if (gui_item_active_p (item))
	qxeSetWindowLong (WIDGET_INSTANCE_MSWINDOWS_HANDLE (p),
			  GWL_STYLE, style & ~WS_DISABLED);
      else
	qxeSetWindowLong (WIDGET_INSTANCE_MSWINDOWS_HANDLE (p),
			  GWL_STYLE, style | WS_DISABLED);
    }
}

#ifdef HAVE_WIDGETS

/* Account for some of the limitations with widget images. */
static int
mswindows_widget_border_width (void)
{
  return DEFAULT_WIDGET_BORDER_WIDTH;
}

/* register widgets into our hashtable so that we can cope with the
   callbacks. The hashtable is weak so deregistration is handled
   automatically */
static int
mswindows_register_gui_item (Lisp_Object image_instance,
			     Lisp_Object gui, Lisp_Object domain)
{
  Lisp_Object frame = DOMAIN_FRAME (domain);
  struct frame *f = XFRAME (frame);
  int id = gui_item_id_hash (FRAME_MSWINDOWS_WIDGET_HASH_TABLE2 (f),
			     gui,
			     WIDGET_GLYPH_SLOT);
  Fputhash (make_fixnum (id), image_instance,
	    FRAME_MSWINDOWS_WIDGET_HASH_TABLE1 (f));
  Fputhash (make_fixnum (id), XGUI_ITEM (gui)->callback,
	    FRAME_MSWINDOWS_WIDGET_HASH_TABLE2 (f));
  Fputhash (make_fixnum (id), XGUI_ITEM (gui)->callback_ex,
	    FRAME_MSWINDOWS_WIDGET_HASH_TABLE3 (f));
  return id;
}

static int
mswindows_register_widget_instance (Lisp_Object instance, Lisp_Object domain)
{
  return mswindows_register_gui_item (instance,
				      XIMAGE_INSTANCE_WIDGET_ITEM (instance),
				      domain);
}

static void
mswindows_subwindow_instantiate (Lisp_Object image_instance,
				 Lisp_Object UNUSED (instantiator),
				 Lisp_Object UNUSED (pointer_fg),
				 Lisp_Object UNUSED (pointer_bg),
				 int UNUSED (dest_mask), Lisp_Object domain)
{
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  Lisp_Object device = IMAGE_INSTANCE_DEVICE (ii);
  Lisp_Object frame = DOMAIN_FRAME (domain);
  HWND wnd;

  CHECK_MSWINDOWS_DEVICE (device);

  /* have to set the type this late in case there is no device
     instantiation for a widget */
  IMAGE_INSTANCE_TYPE (ii) = IMAGE_SUBWINDOW;
  /* Allocate space for the clip window */
  ii->data = xnew_and_zero (struct mswindows_subwindow_data);

  if ((IMAGE_INSTANCE_MSWINDOWS_CLIPWINDOW (ii)
       = qxeCreateWindowEx (
			    0,		/* EX flags */
			    XETEXT (XEMACS_CONTROL_CLASS),
			    0,		/* text */
			    WS_CLIPCHILDREN | WS_CLIPSIBLINGS | WS_CHILD,
			    0,         /* starting x position */
			    0,         /* starting y position */
			    IMAGE_INSTANCE_WIDGET_WIDTH (ii),
			    IMAGE_INSTANCE_WIDGET_HEIGHT (ii),
			    /* parent window */
			    FRAME_MSWINDOWS_HANDLE (XFRAME (frame)),
			    NULL,       /* No menu */
			    NULL, /* must be null for this class */
			    NULL)) == NULL)
    gui_error ("window creation failed with code",
	       make_fixnum (GetLastError()));

  wnd = qxeCreateWindow (XETEXT ("STATIC"), XETEXT (""),
			 WS_CHILD,
			 0,         /* starting x position */
			 0,         /* starting y position */
			 IMAGE_INSTANCE_WIDGET_WIDTH (ii),
			 IMAGE_INSTANCE_WIDGET_HEIGHT (ii),
			 IMAGE_INSTANCE_MSWINDOWS_CLIPWINDOW (ii),
			 0,
			 (HINSTANCE)
			 qxeGetWindowLong
			 (FRAME_MSWINDOWS_HANDLE (XFRAME (frame)),
			  GWL_HINSTANCE),
			 NULL);

  qxeSetWindowLong (wnd, GWL_USERDATA, (LONG)STORE_LISP_IN_VOID(image_instance));
  IMAGE_INSTANCE_SUBWINDOW_ID (ii) = wnd;
}

#endif /* HAVE_WIDGETS */

static int
mswindows_image_instance_equal (Lisp_Image_Instance *p1,
				Lisp_Image_Instance *p2, int UNUSED (depth))
{
  switch (IMAGE_INSTANCE_TYPE (p1))
    {
    case IMAGE_MONO_PIXMAP:
    case IMAGE_COLOR_PIXMAP:
    case IMAGE_POINTER:
      if (IMAGE_INSTANCE_MSWINDOWS_BITMAP (p1)
	  != IMAGE_INSTANCE_MSWINDOWS_BITMAP (p2))
	return 0;
      break;

    default:
      break;
    }

  return 1;
}

static Hashcode
mswindows_image_instance_hash (Lisp_Image_Instance *p, int UNUSED (depth))
{
  switch (IMAGE_INSTANCE_TYPE (p))
    {
    case IMAGE_MONO_PIXMAP:
    case IMAGE_COLOR_PIXMAP:
    case IMAGE_POINTER:
      return (Hashcode) IMAGE_INSTANCE_MSWINDOWS_BITMAP (p);

    default:
      return 0;
    }
}

/* Set all the slots in an image instance structure to reasonable
   default values.  This is used somewhere within an instantiate
   method.  It is assumed that the device slot within the image
   instance is already set -- this is the case when instantiate
   methods are called. */

static void
mswindows_initialize_dibitmap_image_instance (Lisp_Image_Instance *ii,
					      int slices,
					      enum image_instance_type type)
{
  ii->data = xnew_and_zero (struct mswindows_image_instance_data);
  IMAGE_INSTANCE_TYPE (ii) = type;
  IMAGE_INSTANCE_PIXMAP_FILENAME (ii) = Qnil;
  IMAGE_INSTANCE_PIXMAP_MASK_FILENAME (ii) = Qnil;
  IMAGE_INSTANCE_PIXMAP_HOTSPOT_X (ii) = Qnil;
  IMAGE_INSTANCE_PIXMAP_HOTSPOT_Y (ii) = Qnil;
  IMAGE_INSTANCE_PIXMAP_FG (ii) = Qnil;
  IMAGE_INSTANCE_PIXMAP_BG (ii) = Qnil;
  IMAGE_INSTANCE_PIXMAP_MAXSLICE (ii) = slices;
  IMAGE_INSTANCE_MSWINDOWS_BITMAP_SLICES (ii) =
    xnew_array_and_zero (HBITMAP, slices);
}


#ifdef HAVE_WIDGETS

/************************************************************************/
/*                                widgets                               */
/************************************************************************/
static void
mswindows_widget_instantiate (Lisp_Object image_instance,
			      Lisp_Object UNUSED (instantiator),
			      Lisp_Object UNUSED (pointer_fg),
			      Lisp_Object UNUSED (pointer_bg),
			      int UNUSED (dest_mask), Lisp_Object domain,
			      const CIbyte *class_, int flags, int exflags)
{
  /* this function can call lisp */
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  Lisp_Object device = IMAGE_INSTANCE_DEVICE (ii), style;
  Lisp_Object frame = DOMAIN_FRAME (domain);
  Extbyte *nm = 0;
  Extbyte *classext;
  HWND wnd;
  int id = 0xffff;
  Lisp_Object gui = IMAGE_INSTANCE_WIDGET_ITEM (ii);
  Lisp_Gui_Item *pgui = XGUI_ITEM (gui);

  CHECK_MSWINDOWS_DEVICE (device);

  if (!gui_item_active_p (gui))
    flags |= WS_DISABLED;

  style = pgui->style;

  if (!NILP (pgui->callback) || !NILP (pgui->callback_ex))
    {
      id = mswindows_register_widget_instance (image_instance, domain);
    }

  if (!NILP (IMAGE_INSTANCE_WIDGET_TEXT (ii)))
    nm = LISP_STRING_TO_TSTR (IMAGE_INSTANCE_WIDGET_TEXT (ii));

  /* allocate space for the clip window and then allocate the clip window */
  ii->data = xnew_and_zero (struct mswindows_subwindow_data);

  if ((IMAGE_INSTANCE_MSWINDOWS_CLIPWINDOW (ii)
       = qxeCreateWindowEx (WS_EX_CONTROLPARENT,	/* EX flags */
			    XETEXT (XEMACS_CONTROL_CLASS),
			    0,		/* text */
			    WS_CLIPCHILDREN | WS_CLIPSIBLINGS | WS_CHILD,
			    0,         /* starting x position */
			    0,         /* starting y position */
			    IMAGE_INSTANCE_WIDGET_WIDTH (ii),
			    IMAGE_INSTANCE_WIDGET_HEIGHT (ii),
			    /* parent window */
			    DOMAIN_MSWINDOWS_HANDLE (domain),
			    (HMENU)id,       /* No menu */
			    NULL, /* must be null for this class */
			    NULL)) == NULL)
    gui_error ("window creation failed with code",
	       make_fixnum (GetLastError()));

  classext = ITEXT_TO_TSTR (class_);

  if ((wnd = qxeCreateWindowEx (exflags /* | WS_EX_NOPARENTNOTIFY*/,
				classext,
				nm,
				flags | WS_CHILD | WS_VISIBLE,
				0,         /* starting x position */
				0,         /* starting y position */
				IMAGE_INSTANCE_WIDGET_WIDTH (ii),
				IMAGE_INSTANCE_WIDGET_HEIGHT (ii),
				/* parent window */
				IMAGE_INSTANCE_MSWINDOWS_CLIPWINDOW (ii),
				(HMENU)id,       /* No menu */
				(HINSTANCE)
				qxeGetWindowLong
				(FRAME_MSWINDOWS_HANDLE (XFRAME (frame)),
				 GWL_HINSTANCE),
				NULL)) == NULL)
    gui_error ("window creation failed with code",
	       make_fixnum (GetLastError()));

  IMAGE_INSTANCE_SUBWINDOW_ID (ii) = wnd;
  qxeSetWindowLong (wnd, GWL_USERDATA, (LONG)STORE_LISP_IN_VOID(image_instance));
  /* set the widget font from the widget face */
  if (!NILP (IMAGE_INSTANCE_WIDGET_TEXT (ii)))
    qxeSendMessage (wnd, WM_SETFONT,
		    (WPARAM) mswindows_widget_hfont 
		    (IMAGE_INSTANCE_WIDGET_FACE (ii), domain,
		     IMAGE_INSTANCE_WIDGET_TEXT (ii)),
		    MAKELPARAM (TRUE, 0));
}

/* Instantiate a native layout widget. */
static void
mswindows_native_layout_instantiate (Lisp_Object image_instance,
				     Lisp_Object instantiator,
				     Lisp_Object pointer_fg,
				     Lisp_Object pointer_bg,
				     int dest_mask, Lisp_Object domain)
{
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);

  mswindows_widget_instantiate (image_instance, instantiator, pointer_fg,
				pointer_bg, dest_mask, domain, "STATIC",
				/* Approximation to styles available with
				   an XEmacs layout. */
				(EQ (IMAGE_INSTANCE_LAYOUT_BORDER (ii),
				     Qetched_in) ||
				 EQ (IMAGE_INSTANCE_LAYOUT_BORDER (ii),
				     Qetched_out) ||
				 GLYPHP (IMAGE_INSTANCE_LAYOUT_BORDER (ii))
				 ? SS_ETCHEDFRAME : SS_SUNKEN) | DS_CONTROL,
				0);
}

/* Instantiate a button widget. Unfortunately instantiated widgets are
   particular to a frame since they need to have a parent. It's not
   like images where you just select the image into the context you
   want to display it in and BitBlt it. So image instances can have a
   many-to-one relationship with things you see, whereas widgets can
   only be one-to-one (i.e. per frame) */
static void
mswindows_button_instantiate (Lisp_Object image_instance,
			      Lisp_Object instantiator,
			      Lisp_Object pointer_fg, Lisp_Object pointer_bg,
			      int dest_mask, Lisp_Object domain)
{
  /* This function can call lisp */
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  HWND wnd;
  int flags = WS_TABSTOP | BS_NOTIFY;
  /* BS_NOTIFY #### is needed to get exotic feedback only. Since we
     seem to want nothing beyond BN_CLICK, the style is perhaps not
     necessary -- kkm */
  Lisp_Object style;
  Lisp_Object gui = IMAGE_INSTANCE_WIDGET_ITEM (ii);
  Lisp_Gui_Item *pgui = XGUI_ITEM (gui);
  Lisp_Object glyph = find_keyword_in_vector (instantiator, Q_image);

  if (!NILP (glyph))
    {
      if (!IMAGE_INSTANCEP (glyph))
	glyph = glyph_image_instance (glyph, domain, ERROR_ME, 1);

      if (IMAGE_INSTANCEP (glyph))
	flags |= XIMAGE_INSTANCE_MSWINDOWS_BITMAP (glyph) ?
	  BS_BITMAP : BS_ICON;
    }

  style = pgui->style;

  /* #### consider using the default face for radio and toggle
     buttons. */
  if (EQ (style, Qradio))
    {
      flags |= BS_RADIOBUTTON;
    }
  else if (EQ (style, Qtoggle))
    {
      flags |= BS_AUTOCHECKBOX;
    }
  else
    {
      flags |= BS_DEFPUSHBUTTON;
    }

  mswindows_widget_instantiate (image_instance, instantiator, pointer_fg,
				pointer_bg, dest_mask, domain,
				"BUTTON", flags, 0);

  wnd = WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii);
  /* set the checked state */
  if (gui_item_selected_p (gui))
    qxeSendMessage (wnd, BM_SETCHECK, (WPARAM)BST_CHECKED, 0);
  else
    qxeSendMessage (wnd, BM_SETCHECK, (WPARAM)BST_UNCHECKED, 0);
  /* add the image if one was given */
  if (!NILP (glyph) && IMAGE_INSTANCEP (glyph)
      &&
      IMAGE_INSTANCE_PIXMAP_TYPE_P (XIMAGE_INSTANCE (glyph)))
    {
      qxeSendMessage (wnd, BM_SETIMAGE,
		      (WPARAM) (XIMAGE_INSTANCE_MSWINDOWS_BITMAP (glyph) ?
				IMAGE_BITMAP : IMAGE_ICON),
		      (XIMAGE_INSTANCE_MSWINDOWS_BITMAP (glyph) ?
		       (LPARAM) XIMAGE_INSTANCE_MSWINDOWS_BITMAP (glyph) :
		       (LPARAM) XIMAGE_INSTANCE_MSWINDOWS_ICON (glyph)));
    }
}

/* Update the state of a button. */
static void
mswindows_button_redisplay (Lisp_Object image_instance)
{
  /* This function can GC if IN_REDISPLAY is false. */
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);

  /* buttons checked or otherwise */
  if (gui_item_selected_p (IMAGE_INSTANCE_WIDGET_ITEM (ii)))
    qxeSendMessage (WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii),
		    BM_SETCHECK, (WPARAM)BST_CHECKED, 0);
  else
    qxeSendMessage (WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii),
		    BM_SETCHECK, (WPARAM)BST_UNCHECKED, 0);
}

/* instantiate an edit control */
static void
mswindows_edit_field_instantiate (Lisp_Object image_instance,
				  Lisp_Object instantiator,
				  Lisp_Object pointer_fg,
				  Lisp_Object pointer_bg,
				  int dest_mask, Lisp_Object domain)
{
  mswindows_widget_instantiate (image_instance, instantiator, pointer_fg,
				pointer_bg, dest_mask, domain, "EDIT",
				ES_LEFT | ES_AUTOHSCROLL | WS_TABSTOP
				| WS_BORDER, WS_EX_CLIENTEDGE);
}

/* instantiate a progress gauge */
static void
mswindows_progress_gauge_instantiate (Lisp_Object image_instance,
				      Lisp_Object instantiator,
				      Lisp_Object pointer_fg,
				      Lisp_Object pointer_bg,
				      int dest_mask, Lisp_Object domain)
{
  HWND wnd;
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  Lisp_Object val;
  mswindows_widget_instantiate (image_instance, instantiator, pointer_fg,
				pointer_bg, dest_mask, domain, PROGRESS_CLASS,
				WS_BORDER | PBS_SMOOTH, WS_EX_CLIENTEDGE);
  wnd = WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii);
  /* set the colors */
#if 0 /* #### fix this */
  qxeSendMessage (wnd, PBM_SETBKCOLOR, 0,
		  (LPARAM) (COLOR_INSTANCE_MSWINDOWS_COLOR
			    (XCOLOR_INSTANCE
			     (FACE_BACKGROUND
			      (XIMAGE_INSTANCE_WIDGET_FACE (ii),
			       XIMAGE_INSTANCE_FRAME (ii))))));
  qxeSendMessage (wnd, PBM_SETBARCOLOR, 0,
		  (LPARAM) (COLOR_INSTANCE_MSWINDOWS_COLOR
			    (XCOLOR_INSTANCE
			     (FACE_FOREGROUND
			      (XIMAGE_INSTANCE_WIDGET_FACE (ii),
			       XIMAGE_INSTANCE_FRAME (ii))))));
#endif
  val = XGUI_ITEM (IMAGE_INSTANCE_WIDGET_ITEMS (ii))->value;
  CHECK_FIXNUM (val);
  qxeSendMessage (WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii),
		  PBM_SETPOS, (WPARAM)XFIXNUM (val), 0);
}

/* instantiate a tree view widget */
static HTREEITEM add_tree_item (Lisp_Object image_instance,
				HWND wnd, HTREEITEM parent, Lisp_Object item,
				int children, Lisp_Object domain)
{
  HTREEITEM ret;
  TV_INSERTSTRUCTW tvitem;

  tvitem.hParent = parent;
  tvitem.hInsertAfter = TVI_LAST;
  tvitem.item.mask = TVIF_TEXT | TVIF_CHILDREN;
  tvitem.item.cChildren = children;
  
  if (GUI_ITEMP (item))
    {
      tvitem.item.lParam =
	mswindows_register_gui_item (image_instance, item, domain);
      tvitem.item.mask |= TVIF_PARAM;
      tvitem.item.pszText =
	(LPWSTR) LISP_STRING_TO_TSTR (XGUI_ITEM (item)->name);
    }
  else
    tvitem.item.pszText = (LPWSTR) LISP_STRING_TO_TSTR (item);
      
  tvitem.item.cchTextMax = qxetcslen ((Extbyte *) tvitem.item.pszText);
      
  if ((ret = (HTREEITEM) qxeSendMessage (wnd, TVM_INSERTITEM,
					 0, (LPARAM) &tvitem)) == 0)
    gui_error ("error adding tree view entry", item);

  return ret;
}

static void add_tree_item_list (Lisp_Object image_instance,
				HWND wnd, HTREEITEM parent, Lisp_Object list,
				Lisp_Object domain)
{
  Lisp_Object rest;

  /* get the first item */
  parent = add_tree_item (image_instance, wnd, parent, XCAR (list), TRUE, domain);
  /* recursively add items to the tree view */
  LIST_LOOP (rest, XCDR (list))
    {
      if (LISTP (XCAR (rest)))
	add_tree_item_list (image_instance, wnd, parent, XCAR (rest), domain);
      else
	add_tree_item (image_instance, wnd, parent, XCAR (rest), FALSE, domain);
    }
}

static void
mswindows_tree_view_instantiate (Lisp_Object image_instance,
				 Lisp_Object instantiator,
				 Lisp_Object pointer_fg,
				 Lisp_Object pointer_bg,
				 int dest_mask, Lisp_Object domain)
{
  Lisp_Object rest;
  HWND wnd;
  HTREEITEM parent;
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  mswindows_widget_instantiate (image_instance, instantiator, pointer_fg,
				pointer_bg, dest_mask, domain, WC_TREEVIEW,
				WS_TABSTOP | WS_BORDER | PBS_SMOOTH
				| TVS_HASLINES | TVS_HASBUTTONS,
				WS_EX_CLIENTEDGE);

  wnd = WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii);

  /* define a root */
  parent = add_tree_item (image_instance, wnd, NULL,
			  XCAR (IMAGE_INSTANCE_WIDGET_ITEMS (ii)),
			  TRUE, domain);

  /* recursively add items to the tree view */
  /* add items to the tab */
  LIST_LOOP (rest, XCDR (IMAGE_INSTANCE_WIDGET_ITEMS (ii)))
    {
      if (LISTP (XCAR (rest)))
	add_tree_item_list (image_instance, wnd, parent, XCAR (rest), domain);
      else
	add_tree_item (image_instance, wnd, parent, XCAR (rest), FALSE, domain);
    }
}

/* Set the properties of a tree view. */
static void
mswindows_tree_view_redisplay (Lisp_Object image_instance)
{
  /* This function can GC if IN_REDISPLAY is false. */
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);

  if (IMAGE_INSTANCE_WIDGET_ITEMS_CHANGED (ii))
    {
      HWND wnd = WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii);
      Lisp_Object rest;
      HTREEITEM parent;
      /* Delete previous items. */
      qxeSendMessage (wnd, TVM_DELETEITEM, 0, (LPARAM)TVI_ROOT);
      /* define a root */
      parent = add_tree_item (image_instance, wnd, NULL,
			      XCAR (IMAGE_INSTANCE_WIDGET_PENDING_ITEMS (ii)),
			      TRUE, IMAGE_INSTANCE_DOMAIN (ii));

      /* recursively add items to the tree view */
      /* add items to the tab */
      LIST_LOOP (rest, XCDR (IMAGE_INSTANCE_WIDGET_PENDING_ITEMS (ii)))
	{
	  if (LISTP (XCAR (rest)))
	    add_tree_item_list (image_instance, wnd, parent, XCAR (rest),
				IMAGE_INSTANCE_DOMAIN (ii));
	  else
	    add_tree_item (image_instance, wnd, parent, XCAR (rest), FALSE,
			   IMAGE_INSTANCE_DOMAIN (ii));
	}
    }
}

/* instantiate a tab control */
static int
add_tab_item (Lisp_Object image_instance,
	      HWND wnd, Lisp_Object item,
	      Lisp_Object domain, int i)
{
  TC_ITEMW tcitem;
  int ret = 0;

  tcitem.mask = TCIF_TEXT;

  if (GUI_ITEMP (item))
    {
      tcitem.lParam =
	mswindows_register_gui_item (image_instance, item, domain);
      tcitem.mask |= TCIF_PARAM;
      tcitem.pszText = (XELPTSTR) LISP_STRING_TO_TSTR (XGUI_ITEM (item)->name);
    }
  else
    {
      CHECK_STRING (item);
      tcitem.pszText = (XELPTSTR) LISP_STRING_TO_TSTR (item);
    }

  tcitem.cchTextMax = qxetcslen ((Extbyte *) tcitem.pszText);

  if ((ret = qxeSendMessage (wnd, TCM_INSERTITEM, i, (LPARAM) &tcitem)) < 0)
    gui_error ("error adding tab entry", item);

  return ret;
}

static void
mswindows_tab_control_instantiate (Lisp_Object image_instance,
				   Lisp_Object instantiator,
				   Lisp_Object pointer_fg,
				   Lisp_Object pointer_bg,
				   int dest_mask, Lisp_Object domain)
{
  /* This function can call lisp */
  Lisp_Object rest;
  HWND wnd;
  int i = 0, selected = 0;
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  Lisp_Object orient = find_keyword_in_vector (instantiator, Q_orientation);
  unsigned int flags = WS_TABSTOP;

  if (EQ (orient, Qleft) || EQ (orient, Qright))
    {
      flags |= TCS_VERTICAL | TCS_MULTILINE;
    }
  if (EQ (orient, Qright) || EQ (orient, Qbottom))
    {
      flags |= TCS_BOTTOM;
    }

  mswindows_widget_instantiate (image_instance, instantiator, pointer_fg,
				pointer_bg, dest_mask, domain, WC_TABCONTROL,
				/* borders don't suit tabs so well */
				flags, 0);
  wnd = WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii);
  /* add items to the tab */
  LIST_LOOP (rest, XCDR (IMAGE_INSTANCE_WIDGET_ITEMS (ii)))
    {
      int idx = add_tab_item (image_instance, wnd, XCAR (rest), domain, i);
      assert (idx == i);
      if (gui_item_selected_p (XCAR (rest)))
	selected = i;
      i++;
    }
  qxeSendMessage (wnd, TCM_SETCURSEL, selected, 0);
}

/* Set the properties of a tab control. */
static void
mswindows_tab_control_redisplay (Lisp_Object image_instance)
{
  /* This function can GC if IN_REDISPLAY is false. */
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
#ifdef DEBUG_WIDGET_OUTPUT
  stderr_out ("tab control %p redisplayed\n",
	      IMAGE_INSTANCE_SUBWINDOW_ID (ii));
#endif
  if (IMAGE_INSTANCE_WIDGET_ITEMS_CHANGED (ii)
      ||
      IMAGE_INSTANCE_WIDGET_ACTION_OCCURRED (ii))
    {
      HWND wnd = WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii);
      int i = 0, selected_idx = 0;
      Lisp_Object rest;

      assert (!NILP (IMAGE_INSTANCE_WIDGET_ITEMS (ii)));

      /* If only the order has changed then simply select the first
	 one. This stops horrendous rebuilding of the tabs each time
	 you click on one. */
      if (tab_control_order_only_changed (image_instance))
	{
	  Lisp_Object selected =
	    gui_item_list_find_selected
	    (NILP (IMAGE_INSTANCE_WIDGET_PENDING_ITEMS (ii)) ?
	     XCDR (IMAGE_INSTANCE_WIDGET_ITEMS (ii)) :
	     XCDR (IMAGE_INSTANCE_WIDGET_PENDING_ITEMS (ii)));

	  LIST_LOOP (rest, XCDR (IMAGE_INSTANCE_WIDGET_ITEMS (ii)))
	    {
	      if (gui_item_equal_sans_selected (XCAR (rest), selected, 0))
		{
		  Lisp_Object old_selected =
		    gui_item_list_find_selected
		    (XCDR (IMAGE_INSTANCE_WIDGET_ITEMS (ii)));

		  /* Pick up the new selected item. */
		  XGUI_ITEM (old_selected)->selected =
		    XGUI_ITEM (XCAR (rest))->selected;
		  XGUI_ITEM (XCAR (rest))->selected =
		    XGUI_ITEM (selected)->selected;
		  /* We're not actually changing the items. */
		  IMAGE_INSTANCE_WIDGET_ITEMS_CHANGED (ii) = 0;
		  IMAGE_INSTANCE_WIDGET_PENDING_ITEMS (ii) = Qnil;

		  qxeSendMessage (wnd, TCM_SETCURSEL, i, 0);
#ifdef DEBUG_WIDGET_OUTPUT
		  stderr_out ("tab control %p selected item %d\n",
			      IMAGE_INSTANCE_SUBWINDOW_ID (ii), i);
#endif
		  break;
		}
	      i++;
	    }
	}
      else
	{
	  /* delete the pre-existing items */
	  qxeSendMessage (wnd, TCM_DELETEALLITEMS, 0, 0);

	  /* add items to the tab */
	  LIST_LOOP (rest, XCDR (IMAGE_INSTANCE_WIDGET_PENDING_ITEMS (ii)))
	    {
	      add_tab_item (image_instance, wnd, XCAR (rest),
			    IMAGE_INSTANCE_FRAME (ii), i);
	      if (gui_item_selected_p (XCAR (rest)))
		selected_idx = i;
	      i++;
	    }
	  qxeSendMessage (wnd, TCM_SETCURSEL, selected_idx, 0);
	}
    }
}

/* instantiate a static control possible for putting other things in */
static void
mswindows_label_instantiate (Lisp_Object image_instance,
			     Lisp_Object instantiator,
			     Lisp_Object pointer_fg, Lisp_Object pointer_bg,
			     int dest_mask, Lisp_Object domain)
{
  mswindows_widget_instantiate (image_instance, instantiator, pointer_fg,
				pointer_bg, dest_mask, domain,
				"STATIC", 0, WS_EX_STATICEDGE);
}

/* instantiate a scrollbar control */
static void
mswindows_scrollbar_instantiate (Lisp_Object image_instance,
				 Lisp_Object instantiator,
				 Lisp_Object pointer_fg,
				 Lisp_Object pointer_bg,
				 int dest_mask, Lisp_Object domain)
{
  mswindows_widget_instantiate (image_instance, instantiator, pointer_fg,
				pointer_bg, dest_mask, domain,
				"SCROLLBAR", WS_TABSTOP, WS_EX_CLIENTEDGE);
}

/* instantiate a combo control */
static void
mswindows_combo_box_instantiate (Lisp_Object image_instance,
				 Lisp_Object instantiator,
				 Lisp_Object pointer_fg,
				 Lisp_Object pointer_bg,
				 int dest_mask, Lisp_Object domain)
{
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  HWND wnd;
  Lisp_Object rest;
  Lisp_Object items = find_keyword_in_vector (instantiator, Q_items);
  int len, height;

  /* Maybe ought to generalise this more but it may be very windows
     specific. In windows the window height of a combo box is the
     height when the combo box is open. Thus we need to set the height
     before creating the window and then reset it to a single line
     after the window is created so that redisplay does the right
     thing. */
  widget_instantiate (image_instance, instantiator, pointer_fg,
		      pointer_bg, dest_mask, domain);

  /* We now have everything right apart from the height. */
  default_face_font_info (domain, 0, 0, 0, &height, 0);
  GET_LIST_LENGTH (items, len);

  height = (height + DEFAULT_WIDGET_BORDER_WIDTH * 2 ) * len;
  IMAGE_INSTANCE_HEIGHT (ii) = height;

  /* Now create the widget. */
  mswindows_widget_instantiate (image_instance, instantiator, pointer_fg,
				pointer_bg, dest_mask, domain,
				"COMBOBOX",
				WS_BORDER | WS_TABSTOP | CBS_DROPDOWN
				| CBS_AUTOHSCROLL
				| CBS_HASSTRINGS | WS_VSCROLL,
				WS_EX_CLIENTEDGE);
  /* Reset the height. layout will probably do this safely, but better make sure. */
  image_instance_layout (image_instance,
			 IMAGE_UNSPECIFIED_GEOMETRY,
			 IMAGE_UNSPECIFIED_GEOMETRY,
			 IMAGE_UNCHANGED_GEOMETRY,
			 IMAGE_UNCHANGED_GEOMETRY,
			 domain);

  wnd = WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii);
  /* add items to the combo box */
  qxeSendMessage (wnd, CB_RESETCONTENT, 0, 0);
  LIST_LOOP (rest, items)
    {
      Extbyte *lparam;
      lparam = LISP_STRING_TO_TSTR (XCAR (rest));
      if (qxeSendMessage (wnd, CB_ADDSTRING, 0, (LPARAM)lparam) == CB_ERR)
	gui_error ("error adding combo entries", instantiator);
    }
}

/* get properties of a control */
static Lisp_Object
mswindows_widget_property (Lisp_Object image_instance, Lisp_Object prop)
{
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  HWND wnd = WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii);
  /* get the text from a control */
  if (EQ (prop, Q_text))
    {
      Charcount tchar_len = qxeSendMessage (wnd, WM_GETTEXTLENGTH, 0, 0);
      Extbyte *buf = alloca_extbytes (XETCHAR_SIZE * (tchar_len + 1));

      qxeSendMessage (wnd, WM_GETTEXT, (WPARAM)tchar_len + 1, (LPARAM) buf);
      return build_tstr_string (buf);
    }
  return Qunbound;
}

/* get properties of a button */
static Lisp_Object
mswindows_button_property (Lisp_Object image_instance, Lisp_Object prop)
{
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  HWND wnd = WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii);
  /* check the state of a button */
  if (EQ (prop, Q_selected))
    {
      if (qxeSendMessage (wnd, BM_GETSTATE, 0, 0) & BST_CHECKED)
	return Qt;
      else
	return Qnil;
    }
  return Qunbound;
}

/* get properties of a combo box */
static Lisp_Object
mswindows_combo_box_property (Lisp_Object image_instance, Lisp_Object prop)
{
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);
  HWND wnd = WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii);
  /* get the text from a control */
  if (EQ (prop, Q_text))
    {
      long item = qxeSendMessage (wnd, CB_GETCURSEL, 0, 0);
      Charcount tchar_len = qxeSendMessage (wnd, CB_GETLBTEXTLEN,
					    (WPARAM)item, 0);
      Extbyte *buf = alloca_extbytes (XETCHAR_SIZE * (tchar_len + 1));
      qxeSendMessage (wnd, CB_GETLBTEXT, (WPARAM)item, (LPARAM) buf);
      return build_tstr_string (buf);
    }
  return Qunbound;
}

/* set the properties of a progress gauge */
static void
mswindows_progress_gauge_redisplay (Lisp_Object image_instance)
{
  Lisp_Image_Instance *ii = XIMAGE_INSTANCE (image_instance);

  if (IMAGE_INSTANCE_WIDGET_ITEMS_CHANGED (ii))
    {
      Lisp_Object val;
      val = XGUI_ITEM (IMAGE_INSTANCE_WIDGET_PENDING_ITEMS (ii))->value;
#ifdef DEBUG_WIDGET_OUTPUT
      stderr_out ("progress gauge displayed value on %p updated to %ld\n",
		  WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii),
		  XFIXNUM(val));
#endif
      CHECK_FIXNUM (val);
      qxeSendMessage (WIDGET_INSTANCE_MSWINDOWS_HANDLE (ii),
		      PBM_SETPOS, (WPARAM)XFIXNUM (val), 0);
    }
}

LRESULT WINAPI
mswindows_control_wnd_proc (HWND hwnd, UINT msg,
			    WPARAM wParam, LPARAM lParam)
{
  switch (msg)
    {
    case WM_NOTIFY:
    case WM_COMMAND:
    case WM_CTLCOLORBTN:
    case WM_CTLCOLORLISTBOX:
    case WM_CTLCOLOREDIT:
    case WM_CTLCOLORSTATIC:
    case WM_CTLCOLORSCROLLBAR:

      return mswindows_wnd_proc (GetParent (hwnd), msg, wParam, lParam);
    default:
      return qxeDefWindowProc (hwnd, msg, wParam, lParam);
    }
}

static void
mswindows_widget_query_string_geometry (Lisp_Object string, Lisp_Object face,
					int *width, int *height, 
					Lisp_Object domain)
{
  if (height)
    query_string_geometry (string, face, 0, height, 0, domain);

  if (width)
    {
      HDC hdc = FRAME_MSWINDOWS_DC (DOMAIN_XFRAME (domain));
      Extbyte *str;
      Bytecount len;
      SIZE size;

      SelectObject (hdc, mswindows_widget_hfont (face, domain, string));
      LISP_STRING_TO_SIZED_EXTERNAL (string, str, len, Qmswindows_tstr);
      qxeGetTextExtentPoint32 (hdc, str, len / XETCHAR_SIZE, &size);
      *width = size.cx;
    }
}

#endif /* HAVE_WIDGETS */


/************************************************************************/
/*                            initialization                            */
/************************************************************************/

void
syms_of_glyphs_mswindows (void)
{
}

void
console_type_create_glyphs_mswindows (void)
{
  /* image methods - display */
  CONSOLE_HAS_METHOD (mswindows, print_image_instance);
  CONSOLE_HAS_METHOD (mswindows, finalize_image_instance);
  CONSOLE_HAS_METHOD (mswindows, unmap_subwindow);
  CONSOLE_HAS_METHOD (mswindows, map_subwindow);
  CONSOLE_HAS_METHOD (mswindows, redisplay_subwindow);
  CONSOLE_HAS_METHOD (mswindows, resize_subwindow);
  CONSOLE_HAS_METHOD (mswindows, redisplay_widget);
  CONSOLE_HAS_METHOD (mswindows, image_instance_equal);
  CONSOLE_HAS_METHOD (mswindows, image_instance_hash);
  CONSOLE_HAS_METHOD (mswindows, init_image_instance_from_eimage);
  CONSOLE_HAS_METHOD (mswindows, locate_pixmap_file);
#ifdef HAVE_WIDGETS
  CONSOLE_HAS_METHOD (mswindows, widget_query_string_geometry);
  CONSOLE_HAS_METHOD (mswindows, widget_border_width);
#endif

  /* image methods - printer */
  CONSOLE_INHERITS_METHOD (msprinter, mswindows, print_image_instance);
  CONSOLE_INHERITS_METHOD (msprinter, mswindows, finalize_image_instance);
  CONSOLE_INHERITS_METHOD (msprinter, mswindows, image_instance_equal);
  CONSOLE_INHERITS_METHOD (msprinter, mswindows, image_instance_hash);
  CONSOLE_INHERITS_METHOD (msprinter, mswindows,
			   init_image_instance_from_eimage);
  CONSOLE_INHERITS_METHOD (msprinter, mswindows, locate_pixmap_file);
}

void
image_instantiator_format_create_glyphs_mswindows (void)
{
  IIFORMAT_VALID_CONSOLE2 (mswindows, msprinter, nothing);
  IIFORMAT_VALID_CONSOLE2 (mswindows, msprinter, string);
  IIFORMAT_VALID_CONSOLE2 (mswindows, msprinter, formatted_string);
  IIFORMAT_VALID_CONSOLE2 (mswindows, msprinter, inherit);
  /* image-instantiator types */
  INITIALIZE_DEVICE_IIFORMAT (mswindows, xbm);
  INITIALIZE_DEVICE_IIFORMAT (msprinter, xbm);
  IIFORMAT_HAS_DEVMETHOD (mswindows, xbm, instantiate);
  IIFORMAT_INHERITS_DEVMETHOD (msprinter, mswindows, xbm, instantiate);
#ifdef HAVE_XPM
  INITIALIZE_DEVICE_IIFORMAT (mswindows, xpm);
  INITIALIZE_DEVICE_IIFORMAT (msprinter, xpm);
  IIFORMAT_HAS_DEVMETHOD (mswindows, xpm, instantiate);
  IIFORMAT_INHERITS_DEVMETHOD (msprinter, mswindows, xpm, instantiate);
#endif
#ifdef HAVE_XFACE
  INITIALIZE_DEVICE_IIFORMAT (mswindows, xface);
  INITIALIZE_DEVICE_IIFORMAT (msprinter, xface);
  IIFORMAT_HAS_DEVMETHOD (mswindows, xface, instantiate);
  IIFORMAT_INHERITS_DEVMETHOD (msprinter, mswindows, xface, instantiate);
#endif
#ifdef HAVE_JPEG
  IIFORMAT_VALID_CONSOLE2 (mswindows, msprinter, jpeg);
#endif
#ifdef HAVE_TIFF
  IIFORMAT_VALID_CONSOLE2 (mswindows, msprinter, tiff);
#endif
#ifdef HAVE_PNG
  IIFORMAT_VALID_CONSOLE2 (mswindows, msprinter, png);
#endif
#ifdef HAVE_GIF
  IIFORMAT_VALID_CONSOLE2 (mswindows, msprinter, gif);
#endif
#ifdef HAVE_WIDGETS
  INITIALIZE_DEVICE_IIFORMAT (mswindows, widget);
  IIFORMAT_HAS_DEVMETHOD (mswindows, widget, property);
  /* layout widget */
  IIFORMAT_VALID_CONSOLE (mswindows, layout);
  INITIALIZE_DEVICE_IIFORMAT (mswindows, native_layout);
  IIFORMAT_HAS_DEVMETHOD (mswindows, native_layout, instantiate);
  /* button widget */
  INITIALIZE_DEVICE_IIFORMAT (mswindows, button);
  IIFORMAT_HAS_DEVMETHOD (mswindows, button, property);
  IIFORMAT_HAS_DEVMETHOD (mswindows, button, instantiate);
  IIFORMAT_HAS_DEVMETHOD (mswindows, button, redisplay);
  /* edit-field widget */
  INITIALIZE_DEVICE_IIFORMAT (mswindows, edit_field);
  IIFORMAT_HAS_DEVMETHOD (mswindows, edit_field, instantiate);
  /* subwindow */
  INITIALIZE_DEVICE_IIFORMAT (mswindows, subwindow);
  IIFORMAT_HAS_DEVMETHOD (mswindows, subwindow, instantiate);
  /* label */
  INITIALIZE_DEVICE_IIFORMAT (mswindows, label);
  IIFORMAT_HAS_DEVMETHOD (mswindows, label, instantiate);
  /* combo box */
  INITIALIZE_DEVICE_IIFORMAT (mswindows, combo_box);
  IIFORMAT_HAS_DEVMETHOD (mswindows, combo_box, property);
  IIFORMAT_HAS_DEVMETHOD (mswindows, combo_box, instantiate);
  /* scrollbar */
  INITIALIZE_DEVICE_IIFORMAT (mswindows, scrollbar);
  IIFORMAT_HAS_DEVMETHOD (mswindows, scrollbar, instantiate);
  /* progress gauge */
  INITIALIZE_DEVICE_IIFORMAT (mswindows, progress_gauge);
  IIFORMAT_HAS_DEVMETHOD (mswindows, progress_gauge, redisplay);
  IIFORMAT_HAS_DEVMETHOD (mswindows, progress_gauge, instantiate);
  /* tree view widget */
  INITIALIZE_DEVICE_IIFORMAT (mswindows, tree_view);
  IIFORMAT_HAS_DEVMETHOD (mswindows, tree_view, instantiate);
  IIFORMAT_HAS_DEVMETHOD (mswindows, tree_view, redisplay);
  /* tab control widget */
  INITIALIZE_DEVICE_IIFORMAT (mswindows, tab_control);
  IIFORMAT_HAS_DEVMETHOD (mswindows, tab_control, instantiate);
  IIFORMAT_HAS_DEVMETHOD (mswindows, tab_control, redisplay);
#endif
  /* windows bitmap format */
  INITIALIZE_IMAGE_INSTANTIATOR_FORMAT (bmp, "bmp");
  IIFORMAT_HAS_METHOD (bmp, validate);
  IIFORMAT_HAS_METHOD (bmp, normalize);
  IIFORMAT_HAS_METHOD (bmp, possible_dest_types);
  IIFORMAT_HAS_METHOD (bmp, instantiate);

  IIFORMAT_VALID_KEYWORD (bmp, Q_data, check_valid_string);
  IIFORMAT_VALID_KEYWORD (bmp, Q_file, check_valid_string);
  IIFORMAT_VALID_CONSOLE2 (mswindows, msprinter, bmp);

  /* mswindows resources */
  INITIALIZE_IMAGE_INSTANTIATOR_FORMAT (mswindows_resource,
					"mswindows-resource");

  IIFORMAT_HAS_METHOD (mswindows_resource, validate);
  IIFORMAT_HAS_METHOD (mswindows_resource, normalize);
  IIFORMAT_HAS_METHOD (mswindows_resource, possible_dest_types);
  IIFORMAT_HAS_METHOD (mswindows_resource, instantiate);

  IIFORMAT_VALID_KEYWORD (mswindows_resource, Q_resource_type,
			  check_valid_resource_symbol);
  IIFORMAT_VALID_KEYWORD (mswindows_resource, Q_resource_id, check_valid_resource_id);
  IIFORMAT_VALID_KEYWORD (mswindows_resource, Q_file, check_valid_string);
  IIFORMAT_VALID_CONSOLE2 (mswindows, msprinter, mswindows_resource);
}

void
vars_of_glyphs_mswindows (void)
{
  DEFVAR_LISP ("mswindows-bitmap-file-path", &Vmswindows_bitmap_file_path /*
A list of the directories in which mswindows bitmap files may be found.
This is used by the `make-image-instance' function.
*/ );
  Vmswindows_bitmap_file_path = Qnil;
}

void
complex_vars_of_glyphs_mswindows (void)
{
}
