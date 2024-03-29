/* Generic frame functions.
   Copyright (C) 1989, 1992, 1993, 1994, 1995 Free Software Foundation, Inc.
   Copyright (C) 1995, 1996, 2002, 2003, 2005, 2010 Ben Wing.
   Copyright (C) 1995 Sun Microsystems, Inc.

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

/* Synched up with: FSF 19.30. */

/* This file has been Mule-ized. */

/* About window and frame geometry [ben]:

   Here is an ASCII diagram:

+------------------------------------------------------------------------|
|                         window-manager decoration                      |
| +--------------------------------------------------------------------+ |
| |                               menubar                              | |
| ###################################################################### |
| #                               toolbar                              # |
| #--------------------------------------------------------------------# |
| #  |                        internal border                       |  # |
| #  | +----------------------------------------------------------+ |  # |
| #  | |                          gutter                          | |  # |
| #  | |-********************************************************-| |  # |
|w#  | | *@|        scrollbar        |v*                      |s* | |  #w|
|i#  | | *-+-------------------------|e*                      |c* | |  #i|
|n#  | | *s|                         |r*                      |r* | |  #n|
|d#  | | *c|                         |t*                      |o* | |  #d|
|o#  | | *r|                         |.*      text area       |l* | |  #o|
|w#  |i| *o|                         | *                      |l* |i|  #w|
|-#  |n| *l|        text area        |d*                      |b* |n|  #-|
|m#  |t| *l|                         |i*                      |a* |t|  #m|
|a#  |e| *b|                         |v*                      |r* |e|  #a|
|n# t|r| *a|                         |i*----------------------+-* |r|t #n|
|a# o|n|g*r|                         |d*      scrollbar       |@*g|n|o #a|
|g# o|a|u*-+-------------------------|e*----------------------+-*u|a|o #g|
|e# l|l|t*        modeline           |r*      modeline          *t|l|l #e|
|r# b| |t********************************************************t| |b #r|
| # a|b|e*   =..texttexttex....=   |s|v*                      |s*e|b|a # |
|d# r|o|r*o m=..texttexttextt..=o m|c|e*                      |c*r|o|r #d|
|e#  |r| *u a=.exttexttextte...=u a|r|r*                      |r* |r|  #e|
|c#  |d| *t r=....texttexttex..=t r|o|t*                      |o* |d|  #c|
|o#  |e| *s g=        etc.     =s g|l|.*      text area       |l* |e|  #o|
|r#  |r| *i i=                 =i i|l| *                      |l* |r|  #r|
|a#  | | *d n=                 =d n|b|d*                      |b* | |  #a|
|t#  | | *e  = inner text area =e  |a|i*                      |a* | |  #t|
|i#  | | *   =                 =   |r|v*                      |r* | |  #i|
|o#  | | *---===================---+-|i*----------------------+-* | |  #o|
|n#  | | *        scrollbar        |@|d*      scrollbar       |@* | |  #n|
| #  | | *-------------------------+-|e*----------------------+-* | |  # |
| #  | | *        modeline           |r*      modeline          * | |  # |
| #  | |-********************************************************-| |  # |
| #  | |                           gutter                         | |  # |
| #  | |-********************************************************-| |  # |
| #  | |@*                       minibuffer                     *@| |  # |
| #  | +-********************************************************-+ |  # |
| #  |                         internal border                      |  # |
| #--------------------------------------------------------------------# |
| #                                toolbar                             # |
| ###################################################################### |
|                          window manager decoration                     |
+------------------------------------------------------------------------+

   # = boundary of client area; * = window boundaries, boundary of paned area
   = = boundary of inner text area; . = inside margin area; @ = dead boxes

   Note in particular what happens at the corners, where a "corner box"
   occurs.  Top and bottom toolbars take precedence over left and right
   toolbars, extending out horizontally into the corner boxes.  Gutters
   work the same way.  The corner box where the scrollbars meet, however,
   is assigned to neither scrollbar, and is known as the "dead box"; it is
   an area that must be cleared specially.  There are similar dead boxes at
   the bottom-right and bottom-left corners where the minibuffer and
   left/right gutters meet, but there is currently a bug in that these dead
   boxes are not explicitly cleared and may contain junk.

   THE FRAME
   ---------

   The "top-level window area" is the entire area of a top-level window (or
   "frame").  The "client area" (a term from MS Windows) is the area of a
   top-level window that XEmacs draws into and manages with redisplay.
   This includes the toolbar, scrollbars, gutters, dividers, text area,
   modeline and minibuffer.  It does not include the menubar, title or
   outer borders.  The "non-client area" is the area of a top-level window
   outside of the client area and includes the menubar, title and outer
   borders.  Internally, all frame coordinates are relative to the client
   area.


   THE NON-CLIENT AREA
   -------------------

   Under X, the non-client area is split into two parts:

   (1) The outer layer is the window-manager decorations: The title and
   borders.  These are controlled by the window manager, a separate process
   that controls the desktop, the location of icons, etc.  When a process
   tries to create a window, the window manager intercepts this action and
   "reparents" the window, placing another window around it which contains
   the window decorations, including the title bar, outer borders used for
   resizing, etc.  The window manager also implements any actions involving
   the decorations, such as the ability to resize a window by dragging its
   borders, move a window by dragging its title bar, etc.  If there is no
   window manager or you kill it, windows will have no decorations (and
   will lose them if they previously had any) and you will not be able to
   move or resize them.

   (2) Inside of the window-manager decorations is the "shell", which is
   managed by the toolkit and widget libraries your program is linked with.
   The code in *-x.c uses the Xt toolkit and various possible widget
   libraries built on top of Xt, such as Motif, Athena, the "Lucid"
   widgets, etc.  Another possibility is GTK (*-gtk.c), which implements
   both the toolkit and widgets.  Under Xt, the "shell" window is an
   EmacsShell widget, containing an EmacsManager widget of the same size,
   which in turn contains a menubar widget and an EmacsFrame widget, inside
   of which is the client area. (The division into EmacsShell and
   EmacsManager is due to the complex and screwy geometry-management system
   in Xt [and X more generally].  The EmacsShell handles negotiation with
   the window manager; the place of the EmacsManager widget is normally
   assumed by a widget that manages the geometry of its child widgets, but
   the EmacsManager widget just lets the XEmacs redisplay mechanism do the
   positioning.)

   Under Windows, the non-client area is managed by the window system.
   There is no division such as under X.  Part of the window-system API
   (USER.DLL) of Win32 includes functions to control the menubars, title,
   etc. and implements the move and resize behavior.  There *is* an
   equivalent of the window manager, called the "shell", but it manages
   only the desktop, not the windows themselves.  The normal shell under
   Windows is EXPLORER.EXE; if you kill this, you will lose the bar
   containing the "Start" menu and tray and such, but the windows
   themselves will not be affected or lose their decorations.


   THE CLIENT AREA
   ---------------

   Inside of the client area is the toolbars, the gutters (where the buffer
   tabs are displayed), the minibuffer, the internal border width, and one
   or more non-overlapping "windows" (this is old Emacs terminology, from
   before the time when frames existed at all; the standard terminology for
   this would be "pane").  Each window can contain a modeline, horizontal
   and/or vertical scrollbars, and (for non-rightmost windows) a vertical
   divider, surrounding a text area.

   The dimensions of the toolbars and gutters are determined by the formula
   (THICKNESS + 2 * BORDER-THICKNESS), where "thickness" is a cover term
   for height or width, as appropriate.  The height and width come from
   `default-toolbar-height' and `default-toolbar-width' and the specific
   versions of these (`top-toolbar-height', `left-toolbar-width', etc.).
   The border thickness comes from `default-toolbar-border-height' and
   `default-toolbar-border-width', and the specific versions of these.  The
   gutter works exactly equivalently.

   Note that for any particular toolbar or gutter, it will only be
   displayed if [a] its visibility specifier (`default-toolbar-visible-p'
   etc.) is non-nil; [b] its thickness (`default-toolbar-height' etc.)  is
   greater than 0; [c] its contents (`default-toolbar' etc.) are non-nil.

   The position-specific toolbars interact with the default specifications
   as follows: If the value for a position-specific specifier is not
   defined in a particular domain (usually a window), and the position of
   that specifier is set as the default position (using
   `default-toolbar-position'), then the value from the corresponding
   default specifier in that domain will be used.  The gutters work the
   same.


   THE PANED AREA
   --------------

   The area occupied by the "windows" is called the paned area.  Unfortunately,
   because of the presence of the gutter *between* the minibuffer and other
   windows, the bottom of the paned area is not well-defined -- does it
   include the minibuffer (in which case it also includes the bottom gutter,
   but none others) or does it not include the minibuffer? (In which case
   not all windows are included.) #### GEOM! It would be cleaner to put the
   bottom gutter *below* the minibuffer instead of above it.

   Each window can include a horizontal and/or vertical scrollbar, a
   modeline and a vertical divider to its right, as well as the text area.
   Only non-rightmost windows can include a vertical divider. (The
   minibuffer normally does not include either modeline or scrollbars.)

   Note that, because the toolbars and gutters are controlled by
   specifiers, and specifiers can have window-specific and buffer-specific
   values, the size of the paned area can change depending on which window
   is selected: In other words, if the selected window or buffer changes,
   the entire paned area for the frame may change.


   TEXT AREAS, FRINGES, MARGINS
   ----------------------------

   The space occupied by a window can be divided into the text area and the
   fringes.  The fringes include the modeline, scrollbars and vertical
   divider on the right side (if any); inside of this is the text area,
   where the text actually occurs.  Note that a window may or may not
   contain any of the elements that are part of the fringe -- this is
   controlled by specifiers, e.g. `has-modeline-p',
   `horizontal-scrollbar-visible-p', `vertical-scrollbar-visible-p',
   `vertical-divider-always-visible-p', etc.

   In addition, it is possible to set margins in the text area using the
   specifiers `left-margin-width' and `right-margin-width'.  When this is
   done, only the "inner text area" (the area inside of the margins) will
   be used for normal display of text; the margins will be used for glyphs
   with a layout policy of `outside-margin' (as set on an extent containing
   the glyph by `set-extent-begin-glyph-layout' or
   `set-extent-end-glyph-layout').  However, the calculation of the text
   area size (e.g. in the function `window-text-area-width') includes the
   margins.  Which margin is used depends on whether a glyph has been set
   as the begin-glyph or end-glyph of an extent (`set-extent-begin-glyph'
   etc.), using the left and right margins, respectively.

   Technically, the margins outside of the inner text area are known as the
   "outside margins".  The "inside margins" are in the inner text area and
   constitute the whitespace between the outside margins and the first or
   last non-whitespace character in a line; their width can vary from line
   to line.  Glyphs will be placed in the inside margin if their layout
   policy is `inside-margin' or `whitespace', with `whitespace' glyphs on
   the inside and `inside-margin' glyphs on the outside.  Inside-margin
   glyphs can spill over into the outside margin if `use-left-overflow' or
   `use-right-overflow', respectively, is non-nil.

   See the Lisp Reference manual, under Annotations, for more details.


   THE DISPLAYABLE AREA
   --------------------

   The "displayable area" is not so much an actual area as a convenient
   fiction.  It is the area used to convert between pixel and character
   dimensions for frames.  The character dimensions for a frame (e.g. as
   returned by `frame-width' and `frame-height' and set by
   `set-frame-width' and `set-frame-height') are determined from the
   displayable area by dividing by the pixel size of the default font as
   instantiated in the frame. (For proportional fonts, the "average" width
   is used.  Under Windows, this is a built-in property of the fonts.
   Under X, this is based on the width of the lowercase 'n', or if this is
   zero then the width of the default character. [We prefer 'n' to the
   specified default character because many X fonts have a default
   character with a zero or otherwise non-representative width.])

   The displayable area is essentially the "theoretical" gutter area of the
   frame, excluding the rightmost and bottom-most scrollbars.  That is, it
   starts from the client (or "total") area and then excludes the
   "theoretical" toolbars and bottom-most/rightmost scrollbars, and the
   internal border width.  In this context, "theoretical" means that all
   calculations on based on frame-level values for toolbar and scrollbar
   thicknesses.  Because these thicknesses are controlled by specifiers,
   and specifiers can have window-specific and buffer-specific values,
   these calculations may or may not reflect the actual size of the paned
   area or of the scrollbars when any particular window is selected.  Note
   also that the "displayable area" may not even be contiguous!  In
   particular, the gutters are included, but the bottom-most and rightmost
   scrollbars are excluded even though they are inside of the gutters.
   Furthermore, if the frame-level value of the horizontal scrollbar height
   is non-zero, then the displayable area includes the paned area above and
   below the bottom horizontal scrollbar (i.e. the modeline and minibuffer)
   but not the scrollbar itself.

   As a further twist, the character-dimension calculations are adjusted so
   that the truncation and continuation glyphs (see `truncation-glyph' and
   `continuation-glyph') count as a single character even if they are wider
   than the default font width. (Technically, the character width is
   computed from the displayable-area width by subtracting the maximum of
   the truncation-glyph width, continuation-glyph width and default-font
   width before dividing by the default-font width, and then adding 1 to
   the result.) (The ultimate motivation for this kludge as well as the
   subtraction of the scrollbars, but not the minibuffer or bottom-most
   modeline, is to maintain compatibility with TTY's.)

   Despite all these concerns and kludges, however, the "displayable area"
   concept works well in practice and mostly ensures that by default the
   frame will actually fit 79 characters + continuation/truncation glyph.


   WHICH FUNCTIONS USE WHICH?
   --------------------------

   [1] Top-level window area:

   set-frame-position
   `left' and `top' frame properties

   [2] Client area:

   frame-pixel-*, set-frame-pixel-*

   [3] Paned area:

   window-pixel-edges
   event-x-pixel, event-y-pixel, event-properties, make-event

   [4] Displayable area:

   frame-width, frame-height and other all functions specifying frame size
     in characters
   frame-displayable-pixel-*

   --ben

*/

/*
   About different types of units:

   (1) "Total pixels" measure the pixel size of the client area of the
       frame (everything except the menubars and window-manager decorations;
       see comment at top of file).

   (2) "Displayable pixels" measure the pixel size of the "displayable area"
       of the frame, a convenient fiction that specifies which portion of
       the frame "counts" for the purposes of determining the size of the
       frame in character cells.  Approximately speaking, the difference
       between the client area and displayable area is that toolbars,
       gutters, internal border width and bottom-most/right-most scrollbars
       are inside the client area but outside the displayable area.  See
       comment at top of file for more discussion.

   (3) "Character-cell units" measure the frame size in "character cells",
       which are fixed rectangles of a size meant to correspond with the
       height and (average) width of the bounding box of a single character
       in the default font.  The size of a frame in character cells is
       determined by computing the size in "displayable pixels" and dividing
       by the pixel size of the default font as instantiated in the frame.
       See comment at top of file under "displayable area" for more info.

   (4) In window-system "frame units" -- pixels on MS Windows, character
       cells on X and GTK (on TTY's, pixels and character cells are the
       same).  Note that on MS Windows the pixels measure the size of the
       displayable area, not the entire client area.

       This bogosity exists because MS Windows always reports frame sizes
       in pixels, whereas X-Windows has a scheme whereby character-cell
       sizes and extra sizes (e.g. for toolbars, menubars, etc.) can be
       reported to the window manager, and the window manager displays
       character-cell units when resizing, only allows resizing to integral
       character-cell sizes, and reports back the size in character cells.
       As a result, someone thought it was a good idea to make the
       fundamental units for measuring frame size correspond to what the
       window system "reports" and hence vary between pixels and character
       cells, as described above.

  --ben
*/

#include <config.h>
#include "lisp.h"

#include "buffer.h"             /* for Vbuffer_alist */
#include "console.h"
#include "device-impl.h"
#include "events.h"
#include "extents.h"
#include "faces.h"
#include "frame-impl.h"
#include "glyphs.h"
#include "gutter.h"
#include "menubar.h"
#include "process.h"		/* for egetenv */
#include "redisplay.h"
#include "scrollbar.h"
#include "toolbar.h"
#include "window.h"

Lisp_Object Vselect_frame_hook, Qselect_frame_hook;
Lisp_Object Vdeselect_frame_hook, Qdeselect_frame_hook;
Lisp_Object Vcreate_frame_hook, Qcreate_frame_hook;
Lisp_Object Vdelete_frame_hook, Qdelete_frame_hook;
Lisp_Object Vmouse_enter_frame_hook, Qmouse_enter_frame_hook;
Lisp_Object Vmouse_leave_frame_hook, Qmouse_leave_frame_hook;
Lisp_Object Vmap_frame_hook, Qmap_frame_hook;
Lisp_Object Vunmap_frame_hook, Qunmap_frame_hook;
int  allow_deletion_of_last_visible_frame;
Lisp_Object Vadjust_frame_function;
Lisp_Object Vmouse_motion_handler;
Lisp_Object Vsynchronize_minibuffers;
Lisp_Object Qsynchronize_minibuffers;
Lisp_Object Qbuffer_predicate;
Lisp_Object Qmake_initial_minibuffer_frame;
Lisp_Object Qcustom_initialize_frame;

/* We declare all these frame properties here even though many of them
   are currently only used in frame-x.c, because we should generalize
   them. */

Lisp_Object Qminibuffer;
Lisp_Object Qunsplittable;
Lisp_Object Qinternal_border_width;
Lisp_Object Qtop_toolbar_shadow_color;
Lisp_Object Qbottom_toolbar_shadow_color;
Lisp_Object Qbackground_toolbar_color;
Lisp_Object Qtop_toolbar_shadow_pixmap;
Lisp_Object Qbottom_toolbar_shadow_pixmap;
Lisp_Object Qtoolbar_shadow_thickness;
Lisp_Object Qscrollbar_placement;
Lisp_Object Qinter_line_space;
Lisp_Object Qvisual_bell;
Lisp_Object Qbell_volume;
Lisp_Object Qpointer_background;
Lisp_Object Qpointer_color;
Lisp_Object Qtext_pointer;
Lisp_Object Qspace_pointer;
Lisp_Object Qmodeline_pointer;
Lisp_Object Qgc_pointer;
Lisp_Object Qinitially_unmapped;
Lisp_Object Quse_backing_store;
Lisp_Object Qborder_color;
Lisp_Object Qborder_width;

Lisp_Object Qframep, Qframe_live_p;
Lisp_Object Qdelete_frame;

Lisp_Object Qframe_title_format, Vframe_title_format;
Lisp_Object Qframe_icon_title_format, Vframe_icon_title_format;

Lisp_Object Vdefault_frame_name;
Lisp_Object Vdefault_frame_plist;

Lisp_Object Vframe_icon_glyph;

Lisp_Object Qhidden;

Lisp_Object Qvisible, Qiconic, Qinvisible, Qvisible_iconic, Qinvisible_iconic;
Lisp_Object Qnomini, Qvisible_nomini, Qiconic_nomini, Qinvisible_nomini;
Lisp_Object Qvisible_iconic_nomini, Qinvisible_iconic_nomini;

Lisp_Object Qset_specifier, Qset_face_property;
Lisp_Object Qface_property_instance;

Lisp_Object Qframe_property_alias;

/* If this is non-nil, it is the frame that make-frame is currently
   creating.  We can't set the current frame to this in case the
   debugger goes off because it would try and display to it.  However,
   there are some places which need to reference it which have no
   other way of getting it if it isn't the selected frame. */
Lisp_Object Vframe_being_created;
Lisp_Object Qframe_being_created;

static void store_minibuf_frame_prop (struct frame *f, Lisp_Object val);

typedef enum
{
  DISPLAYABLE_PIXEL_TO_CHAR,
  CHAR_TO_DISPLAYABLE_PIXEL,
  TOTAL_PIXEL_TO_CHAR,
  CHAR_TO_TOTAL_PIXEL,
  TOTAL_PIXEL_TO_DISPLAYABLE_PIXEL,
  DISPLAYABLE_PIXEL_TO_TOTAL_PIXEL,
}
pixel_to_char_mode_t;

enum frame_size_type
{
  SIZE_TOTAL_PIXEL,
  SIZE_DISPLAYABLE_PIXEL,
  SIZE_CHAR_CELL,
  SIZE_FRAME_UNIT,
};

static void frame_conversion_internal (struct frame *f,
				       enum frame_size_type source,
				       int source_width, int source_height,
				       enum frame_size_type dest,
				       int *dest_width, int *dest_height);
static void get_frame_char_size (struct frame *f, int *out_width,
				 int *out_height);
static void get_frame_new_displayable_pixel_size (struct frame *f,
						  int *out_width,
						  int *out_height);
static void get_frame_new_total_pixel_size (struct frame *f,
					    int *out_width,
					    int *out_height);

static struct display_line title_string_display_line;
/* Used by generate_title_string. Global because they get used so much that
   the dynamic allocation time adds up. */
static Ichar_dynarr *title_string_ichar_dynarr;


/**************************************************************************/
/*                                                                        */
/*                              frame object                              */
/*                                                                        */
/**************************************************************************/

#ifndef NEW_GC
extern const struct sized_memory_description gtk_frame_data_description;
extern const struct sized_memory_description mswindows_frame_data_description;
extern const struct sized_memory_description x_frame_data_description;
#endif /* not NEW_GC */

static const struct memory_description frame_data_description_1 []= {
#ifdef NEW_GC
#ifdef HAVE_GTK
  { XD_LISP_OBJECT, gtk_console },
#endif
#ifdef HAVE_MS_WINDOWS
  { XD_LISP_OBJECT, mswindows_console },
#endif
#ifdef HAVE_X_WINDOWS
  { XD_LISP_OBJECT, x_console },
#endif
#else /* not NEW_GC */
#ifdef HAVE_GTK
  { XD_BLOCK_PTR, gtk_console, 1, { &gtk_frame_data_description} },
#endif
#ifdef HAVE_MS_WINDOWS
  { XD_BLOCK_PTR, mswindows_console, 1, { &mswindows_frame_data_description} },
#endif
#ifdef HAVE_X_WINDOWS
  { XD_BLOCK_PTR, x_console, 1, { &x_frame_data_description} },
#endif
#endif /* not NEW_GC */
  { XD_END }
};

static const struct sized_memory_description frame_data_description = {
  sizeof (void *), frame_data_description_1
};

#ifdef NEW_GC
static const struct memory_description expose_ignore_description_1 [] = {
  { XD_LISP_OBJECT, offsetof (struct expose_ignore, next) },
  { XD_END }
};

DEFINE_DUMPABLE_INTERNAL_LISP_OBJECT ("expose-ignore", expose_ignore,
				      0, expose_ignore_description_1,
				      struct expose_ignore);
#else /* not NEW_GC */
extern const struct sized_memory_description expose_ignore_description;

static const struct memory_description expose_ignore_description_1 [] = {
  { XD_BLOCK_PTR, offsetof (struct expose_ignore, next),
    1, { &expose_ignore_description } },
  { XD_END }
};

const struct sized_memory_description expose_ignore_description = {
  sizeof (struct expose_ignore),
  expose_ignore_description_1
};
#endif /* not NEW_GC */

static const struct memory_description display_line_dynarr_pointer_description_1 []= {
  { XD_BLOCK_PTR, 0, 1, { &display_line_dynarr_description} },
  { XD_END }
};

static const struct sized_memory_description display_line_dynarr_pointer_description = {
  sizeof (display_line_dynarr *), display_line_dynarr_pointer_description_1
};

static const struct memory_description frame_description [] = {
  { XD_INT, offsetof (struct frame, frametype) },
#define MARKED_SLOT(x) { XD_LISP_OBJECT, offsetof (struct frame, x) },
#define MARKED_SLOT_ARRAY(slot, size) \
  { XD_LISP_OBJECT_ARRAY, offsetof (struct frame, slot), size },
#include "frameslots.h"

#ifdef NEW_GC
  { XD_LISP_OBJECT, offsetof (struct frame, subwindow_exposures) },
  { XD_LISP_OBJECT, offsetof (struct frame, subwindow_exposures_tail) },
#else /* not NEW_GC */
  { XD_BLOCK_PTR, offsetof (struct frame, subwindow_exposures),
    1, { &expose_ignore_description } },
  { XD_BLOCK_PTR, offsetof (struct frame, subwindow_exposures_tail),
    1, { &expose_ignore_description } },
#endif /* not NEW_GC */

#ifdef HAVE_SCROLLBARS
  { XD_LISP_OBJECT, offsetof (struct frame, sb_vcache) },
  { XD_LISP_OBJECT, offsetof (struct frame, sb_hcache) },
#endif /* HAVE_SCROLLBARS */

  { XD_BLOCK_ARRAY, offsetof (struct frame, current_display_lines),
    4, { &display_line_dynarr_pointer_description } },
  { XD_BLOCK_ARRAY, offsetof (struct frame, desired_display_lines),
    4, { &display_line_dynarr_pointer_description } },

  { XD_BLOCK_PTR, offsetof (struct frame, framemeths), 1,
    { &console_methods_description } },
  { XD_UNION, offsetof (struct frame, frame_data),
    XD_INDIRECT (0, 0), { &frame_data_description } },
  { XD_END }
};

static Lisp_Object
mark_frame (Lisp_Object obj)
{
  struct frame *f = XFRAME (obj);

#define MARKED_SLOT(x) mark_object (f->x);
#include "frameslots.h"

  if (FRAME_LIVE_P (f)) /* device is nil for a dead frame */
    MAYBE_FRAMEMETH (f, mark_frame, (f));

#ifdef HAVE_SCROLLBARS
  if (f->sb_vcache)
    mark_object (wrap_scrollbar_instance (f->sb_vcache));
  if (f->sb_hcache)
    mark_object (wrap_scrollbar_instance (f->sb_hcache));
#endif

  mark_gutters (f);

  return Qnil;
}

static void
print_frame (Lisp_Object obj, Lisp_Object printcharfun,
	     int UNUSED (escapeflag))
{
  struct frame *frm = XFRAME (obj);

  if (print_readably)
    printing_unreadable_lisp_object (obj, XSTRING_DATA (frm->name));

  write_fmt_string (printcharfun, "#<%s-frame ", !FRAME_LIVE_P (frm) ? "dead" :
		    FRAME_TYPE_NAME (frm));
  print_internal (frm->name, printcharfun, 1);
  write_ascstring (printcharfun, " on ");
  print_internal (frm->device, printcharfun, 0);
  write_fmt_string (printcharfun, " 0x%x>", LISP_OBJECT_UID (obj));
}

DEFINE_NODUMP_LISP_OBJECT ("frame", frame,
			   mark_frame, print_frame, 0, 0, 0,
			   frame_description,
			   struct frame);

/**************************************************************************/
/*                                                                        */
/*                             frame creation                             */
/*                                                                        */
/**************************************************************************/

static void
nuke_all_frame_slots (struct frame *f)
{
  zero_nonsized_lisp_object (wrap_frame (f));

#define MARKED_SLOT(x)	f->x = Qnil;
#include "frameslots.h"
}

/* Allocate a new frame object and set all its fields to reasonable
   values.  The root window is created but the minibuffer will be done
   later. */

static struct frame *
allocate_frame_core (Lisp_Object device)
{
  /* This function can GC */
  Lisp_Object root_window;
  Lisp_Object frame = ALLOC_NORMAL_LISP_OBJECT (frame);
  struct frame *f = XFRAME (frame);

  nuke_all_frame_slots (f);

  f->device = device;
  f->framemeths = XDEVICE (device)->devmeths;
  f->frametype = get_console_variant (XDEVICE_TYPE (device));
  f->buffer_alist = Fcopy_sequence (Vbuffer_alist);

  root_window = allocate_window ();
  XWINDOW (root_window)->frame = frame;

  /* 10 is arbitrary,
     Just so that there is "something there."
     Correct size will be set up later with change_frame_size.  */

  f->width  = 10;
  f->height = 10;

  XWINDOW (root_window)->pixel_width = 10;
  XWINDOW (root_window)->pixel_height = 9;

  f->root_window = root_window;
  f->selected_window = root_window;
  f->last_nonminibuf_window = root_window;

  /* cache of subwindows visible on frame */
  f->subwindow_instance_cache    = make_weak_list (WEAK_LIST_SIMPLE);

  /* associated exposure ignore list */
  f->subwindow_exposures = 0;
  f->subwindow_exposures_tail = 0;

  FRAME_SET_PAGENUMBER (f, 1);

  note_object_created (root_window);

  /* Choose a buffer for the frame's root window.  */
  XWINDOW (root_window)->buffer = Qt;
  {
    Lisp_Object buf;

    buf = Fcurrent_buffer ();
    /* If buf is a 'hidden' buffer (i.e. one whose name starts with
       a space), try to find another one.  */
    if (string_ichar (Fbuffer_name (buf), 0) == ' ')
      buf = Fother_buffer (buf, Qnil, Qnil);
    Fset_window_buffer (root_window, buf, Qnil);
  }

  return f;
}

static void
setup_normal_frame (struct frame *f)
{
  Lisp_Object mini_window;
  Lisp_Object frame = wrap_frame (f);


  mini_window = allocate_window ();
  XWINDOW (f->root_window)->next = mini_window;
  XWINDOW (mini_window)->prev = f->root_window;
  XWINDOW (mini_window)->mini_p = Qt;
  XWINDOW (mini_window)->frame = frame;
  f->minibuffer_window = mini_window;
  f->has_minibuffer = 1;

  note_object_created (mini_window);

  XWINDOW (mini_window)->buffer = Qt;
  Fset_window_buffer (mini_window, Vminibuffer_zero, Qt);
}

/* Make a frame using a separate minibuffer window on another frame.
   MINI_WINDOW is the minibuffer window to use.  nil means use the
   default-minibuffer-frame.  */

static void
setup_frame_without_minibuffer (struct frame *f, Lisp_Object mini_window)
{
  /* This function can GC */
  Lisp_Object device = f->device;

  if (!NILP (mini_window))
    CHECK_LIVE_WINDOW (mini_window);

  if (!NILP (mini_window)
      && !EQ (DEVICE_CONSOLE (XDEVICE (device)),
	      FRAME_CONSOLE (XFRAME (XWINDOW (mini_window)->frame))))
    invalid_argument ("frame and minibuffer must be on the same console", Qunbound);

  /* Do not create a default minibuffer frame on printer devices.  */
  if (NILP (mini_window)
      && DEVICE_DISPLAY_P (XDEVICE (FRAME_DEVICE (f))))
    {
      struct console *con = XCONSOLE (FRAME_CONSOLE (f));
      /* Use default-minibuffer-frame if possible.  */
      if (!FRAMEP (con->default_minibuffer_frame)
	  || ! FRAME_LIVE_P (XFRAME (con->default_minibuffer_frame)))
	{
	  /* If there's no minibuffer frame to use, create one.  */
	  con->default_minibuffer_frame
	    = call1 (Qmake_initial_minibuffer_frame, device);
	}
      mini_window = XFRAME (con->default_minibuffer_frame)->minibuffer_window;
    }

  /* Install the chosen minibuffer window, with proper buffer.  */
  if (!NILP (mini_window))
    {
      store_minibuf_frame_prop (f, mini_window);
      Fset_window_buffer (mini_window, Vminibuffer_zero, Qt);
    }
  else
    f->minibuffer_window = Qnil;
}

/* Make a frame containing only a minibuffer window.
   The minibuffer window is also the root window.  */

static void
setup_minibuffer_frame (struct frame *f)
{
  /* This function can GC */
  /* First make a frame containing just a root window, no minibuffer.  */
  Lisp_Object mini_window;
  Lisp_Object frame = wrap_frame (f);


  f->no_split = 1;
  f->has_minibuffer = 1;

  /* Now label the root window as also being the minibuffer.
     Avoid infinite looping on the window chain by marking next pointer
     as nil. */

  mini_window = f->minibuffer_window = f->root_window;
  XWINDOW (mini_window)->mini_p = Qt;
  XWINDOW (mini_window)->next   = Qnil;
  XWINDOW (mini_window)->prev   = Qnil;
  XWINDOW (mini_window)->frame  = frame;

  /* Put the proper buffer in that window.  */

  Fset_window_buffer (mini_window, Vminibuffer_zero, Qt);
}

static Lisp_Object
make_sure_its_a_fresh_plist (Lisp_Object foolist)
{
  if (CONSP (Fcar (foolist)))
    {
      /* looks like an alist to me. */
      foolist = Fcopy_alist (foolist);
      foolist = Fdestructive_alist_to_plist (foolist);
    }
  else
    foolist = Fcopy_sequence (foolist);

  return foolist;
}

static Lisp_Object
restore_frame_list_to_its_unbesmirched_state (Lisp_Object kawnz)
{
  Lisp_Object lissed = XCDR (kawnz);
  if (!EQ (lissed, Qunbound))
    DEVICE_FRAME_LIST (XDEVICE (XCAR (kawnz))) = lissed;
  return Qnil;
}

DEFUN ("make-frame", Fmake_frame, 0, 2, "", /*
Create and return a new frame, displaying the current buffer.
Runs the functions listed in `create-frame-hook' after frame creation.

Optional argument PROPS is a property list (a list of alternating
keyword-value specifications) of properties for the new frame.
\(An alist is accepted for backward compatibility but should not
be passed in.)

See `set-frame-properties', `default-x-frame-plist', and
`default-tty-frame-plist' for the specially-recognized properties.
*/
       (props, device))
{
  struct frame *f;
  struct device *d;
  Lisp_Object frame = Qnil, name = Qnil, minibuf;
  struct gcpro gcpro1, gcpro2, gcpro3;
  int speccount = specpdl_depth (), speccount2;
  int first_frame_on_device = 0;
  int first_frame_on_console = 0;
  Lisp_Object besmirched_cons = Qnil;
  int frame_name_is_defaulted = 1;

  d = decode_device (device);
  device = wrap_device (d);

  /* PROPS and NAME may be freshly-created, so make sure to GCPRO. */
  GCPRO3 (frame, props, name);

  props = make_sure_its_a_fresh_plist (props);
  if (DEVICE_SPECIFIC_FRAME_PROPS (d))
    /* Put the device-specific props before the more general ones so
       that they override them. */
    props = nconc2 (props,
		    make_sure_its_a_fresh_plist
		    (*DEVICE_SPECIFIC_FRAME_PROPS (d)));
  props = nconc2 (props, make_sure_its_a_fresh_plist (Vdefault_frame_plist));
  Fcanonicalize_lax_plist (props, Qnil);

  name = Flax_plist_get (props, Qname, Qnil);
  if (!NILP (name))
    {
      CHECK_STRING (name);
      frame_name_is_defaulted = 0;
    }
  else if (!initialized)
    {
      /* We leave Vdefault_frame_name alone here so that it'll remain Qnil
	 in the dumped executable, and we can choose it at runtime. */
      name = build_ascstring ("XEmacs");
    }
  else if (NILP (Vdefault_frame_name))
    {
      if (egetenv ("USE_EMACS_AS_DEFAULT_APPLICATION_CLASS"))
	{
	  Vdefault_frame_name = build_ascstring ("emacs");
	}
      else
	{
	  Vdefault_frame_name = build_ascstring ("XEmacs");
	}
    }

  if (NILP(name) && STRINGP(Vdefault_frame_name))
    {
      name = Vdefault_frame_name;
    }

  if (!NILP (Fstring_match (make_string ((const Ibyte *) "\\.", 2), name,
			    Qnil, Qnil)))
    syntax_error (". not allowed in frame names", name);

  f = allocate_frame_core (device);
  frame = wrap_frame (f);

  specbind (Qframe_being_created, name);
  f->name = name;

  FRAMEMETH (f, init_frame_1, (f, props, frame_name_is_defaulted));

  minibuf = Flax_plist_get (props, Qminibuffer, Qunbound);
  if (UNBOUNDP (minibuf))
    {
      /* If minibuf is unspecified, then look for a minibuffer X resource. */
      /* #### Not implemented any more.  We need to fix things up so
	 that we search out all X resources and append them to the end of
	 props, above.  This is the only way in general to assure
	 coherent behavior for all frame properties/resources/etc. */
    }
  else
    props = Flax_plist_remprop (props, Qminibuffer);

  if (EQ (minibuf, Qnone) || NILP (minibuf))
    setup_frame_without_minibuffer (f, Qnil);
  else if (EQ (minibuf, Qonly))
    setup_minibuffer_frame (f);
  else if (WINDOWP (minibuf))
    setup_frame_without_minibuffer (f, minibuf);
  else if (EQ (minibuf, Qt) || UNBOUNDP (minibuf))
    setup_normal_frame (f);
  else
    invalid_argument ("Invalid value for `minibuffer'", minibuf);

  update_frame_window_mirror (f);

  /* #### Do we need to be calling reset_face_cachels here, and then again
     down below? */
  if (initialized && !DEVICE_STREAM_P (d))
    {
      if (!NILP (f->minibuffer_window))
	{
	  reset_face_cachels (XWINDOW (f->minibuffer_window));
	  reset_glyph_cachels (XWINDOW (f->minibuffer_window));
	}
      reset_face_cachels (XWINDOW (f->root_window));
      reset_glyph_cachels (XWINDOW (f->root_window));
    }

  /* If no frames on this device formerly existed, say this is the
     first frame.  It kind of assumes that frameless devices don't
     exist, but it shouldn't be too harmful.  */
  if (NILP (DEVICE_FRAME_LIST (d)))
    first_frame_on_device = 1;

  /* It's possible for one of the init methods below to signal an error;
     in that case, let's make sure the device isn't besmirched by
     having a half-initialized frame attached to it */
  speccount2 = specpdl_depth ();
  record_unwind_protect (restore_frame_list_to_its_unbesmirched_state,
			 besmirched_cons =
			 Fcons (device, DEVICE_FRAME_LIST (d)));

  /* This *must* go before the init_*() methods.  Those functions
     call Lisp code, and if any of them causes a warning to be displayed
     and the *Warnings* buffer to be created, it won't get added to
     the frame-specific version of the buffer-alist unless the frame
     is accessible from the device. */

#if 0
  DEVICE_FRAME_LIST (d) = nconc2 (DEVICE_FRAME_LIST (d), Fcons (frame, Qnil));
#endif
  DEVICE_FRAME_LIST (d) = Fcons (frame, DEVICE_FRAME_LIST (d));
  RESET_CHANGED_SET_FLAGS;

  note_object_created (frame);

  /* Now make sure that the initial cached values are set correctly.
     Do this after the init_frame method is called because that may
     do things (e.g. create widgets) that are necessary for the
     specifier value-changed methods to work OK. */
  recompute_all_cached_specifiers_in_frame (f);

  if (!DEVICE_STREAM_P (d))
    {
      init_frame_faces (f);

#ifdef HAVE_SCROLLBARS
      /* Finish up resourcing the scrollbars. */
      init_frame_scrollbars (f);
#endif

#ifdef HAVE_TOOLBARS
      /* Create the initial toolbars.  We have to do this after the frame
	 methods are called because it may potentially call some things itself
	 which depend on the normal frame methods having initialized
	 things. */
      init_frame_toolbars (f);
#endif
      /* Added this assert recently (2-1-10); seems there should be only
	 two windows, root and minibufer.  Probably we should just be
	 calling reset_*_cachels on the root window directly instead of the
	 selected window, but I want to make sure they are always the
	 same. --ben */
      assert (EQ (FRAME_SELECTED_WINDOW (f), f->root_window));
      reset_face_cachels (XWINDOW (FRAME_SELECTED_WINDOW (f)));
      reset_glyph_cachels (XWINDOW (FRAME_SELECTED_WINDOW (f)));
      if (!NILP (f->minibuffer_window))
	{
	  reset_face_cachels (XWINDOW (f->minibuffer_window));
	  reset_glyph_cachels (XWINDOW (f->minibuffer_window));
	}

      change_frame_size (f, f->width, f->height, 0);
    }

  MAYBE_FRAMEMETH (f, init_frame_2, (f, props));
  Fset_frame_properties (frame, props);
  MAYBE_FRAMEMETH (f, init_frame_3, (f));

  /* Hallelujah, praise the lord. */
  f->init_finished = 1;

  XCDR (besmirched_cons) = Qunbound;

  unbind_to (speccount2);

  /* If this is the first frame on the device, make it the selected one. */
  if (first_frame_on_device && NILP (DEVICE_SELECTED_FRAME (d)))
    set_device_selected_frame (d, frame);

  /* If at startup or if the current console is a stream console
     (usually also at startup), make this console the selected one
     so that messages show up on it. */
  if (NILP (Fselected_console ()) ||
      CONSOLE_STREAM_P (XCONSOLE (Fselected_console ())))
    Fselect_console (DEVICE_CONSOLE (d));

  first_frame_on_console =
    (first_frame_on_device &&
     XFIXNUM (Flength (CONSOLE_DEVICE_LIST (XCONSOLE (DEVICE_CONSOLE (d)))))
     == 1);

  /* #### all this calling of frame methods at various odd times
     is somewhat of a mess.  It's necessary to do it this way due
     to strange console-type-specific things that need to be done. */
  MAYBE_FRAMEMETH (f, after_init_frame, (f, first_frame_on_device,
					 first_frame_on_console));

  if (!DEVICE_STREAM_P (d))
    {
      /* Now initialise the gutters. This won't change the frame size,
	 but is needed as input to the layout that change_frame_size
	 will eventually do. Unfortunately gutter sizing code relies
	 on the frame in question being visible so we can't do this
	 earlier. */
      init_frame_gutters (f);

      change_frame_size (f, f->width, f->height, 0);
    }

  if (first_frame_on_device)
    {
      if (first_frame_on_console)
	va_run_hook_with_args (Qcreate_console_hook, 1, DEVICE_CONSOLE (d));
      va_run_hook_with_args (Qcreate_device_hook, 1, device);
    }
  va_run_hook_with_args (Qcreate_frame_hook, 1, frame);

  /* Initialize custom-specific stuff. */
  if (!UNBOUNDP (symbol_function (XSYMBOL (Qcustom_initialize_frame))))
    call1 (Qcustom_initialize_frame, frame);

  UNGCPRO;
  unbind_to (speccount);

  return frame;
}


/**************************************************************************/
/*                                                                        */
/*                      validating a frame argument                       */
/*                                                                        */
/**************************************************************************/

/* this function should be used in most cases when a Lisp function is passed
   a FRAME argument.  Use this unless you don't accept nil == current frame
   (in which case, do a CHECK_LIVE_FRAME() and then an XFRAME()) or you
   allow dead frames.  Note that very few functions should accept dead
   frames.  It could be argued that functions should just do nothing when
   given a dead frame, but the presence of a dead frame usually indicates
   an oversight in the Lisp code that could potentially lead to strange
   results and so it is better to catch the error early.

   If you only accept X frames, use decode_x_frame(), which does what this
   function does but also makes sure the frame is an X frame. */

struct frame *
decode_frame (Lisp_Object frame)
{
  if (NILP (frame))
    return selected_frame ();

  CHECK_LIVE_FRAME (frame);
  return XFRAME (frame);
}

struct frame *
decode_frame_or_selected (Lisp_Object cdf)
{
  if (CONSOLEP (cdf))
    cdf = CONSOLE_SELECTED_DEVICE (decode_console (cdf));
  if (DEVICEP (cdf))
    cdf = DEVICE_SELECTED_FRAME (decode_device (cdf));
  return decode_frame (cdf);
}

int
frame_live_p (struct frame *f)
{
  return FRAME_LIVE_P (f);
}

DEFUN ("framep", Fframep, 1, 1, 0, /*
Return non-nil if OBJECT is a frame.
Also see `frame-live-p'.
Note that FSF Emacs kludgily returns a value indicating what type of
frame this is.  Use the cleaner function `frame-type' for that.
*/
       (object))
{
  return FRAMEP (object) ? Qt : Qnil;
}

DEFUN ("frame-live-p", Fframe_live_p, 1, 1, 0, /*
Return non-nil if OBJECT is a frame which has not been deleted.
*/
       (object))
{
  return FRAMEP (object) && FRAME_LIVE_P (XFRAME (object)) ? Qt : Qnil;
}


/**************************************************************************/
/*                                                                        */
/*                         frame focus/selection                          */
/*                                                                        */
/**************************************************************************/

Lisp_Object
frame_device (struct frame *f)
{
  return FRAME_DEVICE (f);
}

DEFUN ("frame-device", Fframe_device, 0, 1, 0, /*
Return the device that FRAME is on.
If omitted, FRAME defaults to the currently selected frame.
*/
       (frame))
{
  return FRAME_DEVICE (decode_frame (frame));
}

DEFUN ("focus-frame", Ffocus_frame, 1, 1, 0, /*
Select FRAME and give it the window system focus.
This function is not affected by the value of `focus-follows-mouse'.
*/
       (frame))
{
  CHECK_LIVE_FRAME (frame);

  MAYBE_DEVMETH (XDEVICE (FRAME_DEVICE (XFRAME (frame))), focus_on_frame,
		 (XFRAME (frame)));
  /* FRAME will be selected by the time we receive the next event.
     However, it is better to select it explicitly now, in case the
     Lisp code depends on frame being selected.  */
  Fselect_frame (frame);
  return Qnil;
}

/* Called from Fselect_window() */
void
select_frame_1 (Lisp_Object frame)
{
  struct frame *f = XFRAME (frame);
  Lisp_Object old_selected_frame = Fselected_frame (Qnil);

  if (EQ (frame, old_selected_frame))
    return;

  /* now select the frame's device */
  set_device_selected_frame (XDEVICE (FRAME_DEVICE (f)), frame);
  select_device_1 (FRAME_DEVICE (f));

  update_frame_window_mirror (f);
}

DEFUN ("select-frame", Fselect_frame, 1, 1, 0, /*
Select the frame FRAME.
Subsequent editing commands apply to its selected window.
The selection of FRAME lasts until the next time the user does
something to select a different frame, or until the next time this
function is called.

Note that this does not actually cause the window-system focus to be
set to this frame, or the `select-frame-hook' or `deselect-frame-hook'
to be run, until the next time that XEmacs is waiting for an event.

Also note that when focus-follows-mouse is non-nil, the frame
selection is temporary and is reverted when the current command
terminates, much like the buffer selected by `set-buffer'.  In order
to effect a permanent focus change, use `focus-frame'.
*/
       (frame))
{
  CHECK_LIVE_FRAME (frame);

  /* select the frame's selected window.  This will call
     selected_frame_1(). */
  Fselect_window (FRAME_SELECTED_WINDOW (XFRAME (frame)), Qnil);

  /* Nothing should be depending on the return value of this function.
     But, of course, there is stuff out there which is. */
  return frame;
}

/* use this to retrieve the currently selected frame.  You should use
   this in preference to Fselected_frame (Qnil) unless you are prepared
   to handle the possibility of there being no selected frame (this
   happens at some points during startup). */

struct frame *
selected_frame (void)
{
  Lisp_Object device = Fselected_device (Qnil);
  Lisp_Object frame = DEVICE_SELECTED_FRAME (XDEVICE (device));
  if (NILP (frame))
    gui_error ("No frames exist on device", device);
  return XFRAME (frame);
}

/* use this instead of XFRAME (DEVICE_SELECTED_FRAME (d)) to catch
   the possibility of there being no frames on the device (just created).
   There is no point doing this inside of redisplay because errors
   cause an ABORT(), indicating a flaw in the logic, and error_check_frame()
   will catch this just as well. */

struct frame *
device_selected_frame (struct device *d)
{
  Lisp_Object frame = DEVICE_SELECTED_FRAME (d);
  if (NILP (frame))
    {
      Lisp_Object device = wrap_device (d);

      gui_error ("No frames exist on device", device);
    }
  return XFRAME (frame);
}

#if 0 /* FSFmacs */

/* Ben thinks there is no need for `redirect-frame-focus' or `frame-focus',
   crockish FSFmacs functions.  See summary on focus in event-stream.c. */

DEFUN ("handle-switch-frame", Fhandle_switch_frame, 1, 2, "e", /*
Handle a switch-frame event EVENT.
Switch-frame events are usually bound to this function.
A switch-frame event tells Emacs that the window manager has requested
that the user's events be directed to the frame mentioned in the event.
This function selects the selected window of the frame of EVENT.

If EVENT is frame object, handle it as if it were a switch-frame event
to that frame.
*/
	 (frame, no_enter))
{
  /* Preserve prefix arg that the command loop just cleared.  */
  XCONSOLE (Vselected_console)->prefix_arg = Vcurrent_prefix_arg;
#if 0 /* unclean! */
  run_hook (Qmouse_leave_buffer_hook);
#endif
  return do_switch_frame (frame, no_enter, 0);
}

/* A load of garbage. */
DEFUN ("ignore-event", Fignore_event, 0, 0, "", /*
Do nothing, but preserve any prefix argument already specified.
This is a suitable binding for iconify-frame and make-frame-visible.
*/
	 ())
{
  struct console *c = XCONSOLE (Vselected_console);

  c->prefix_arg = Vcurrent_prefix_arg;
  return Qnil;
}

#endif /* 0 */

DEFUN ("selected-frame", Fselected_frame, 0, 1, 0, /*
Return the frame that is now selected on device DEVICE.
If DEVICE is not specified, the selected device will be used.
If no frames exist on the device, nil is returned.
*/
       (device))
{
  if (NILP (device) && NILP (Fselected_device (Qnil)))
    return Qnil; /* happens early in temacs */
  return DEVICE_SELECTED_FRAME (decode_device (device));
}

Lisp_Object
frame_first_window (struct frame *f)
{
  Lisp_Object w = f->root_window;

  while (1)
    {
      if (! NILP (XWINDOW (w)->hchild))
	w = XWINDOW (w)->hchild;
      else if (! NILP (XWINDOW (w)->vchild))
	w = XWINDOW (w)->vchild;
      else
	break;
    }

  return w;
}

DEFUN ("active-minibuffer-window", Factive_minibuffer_window, 0, 0, 0, /*
Return the currently active minibuffer window, or nil if none.
*/
       ())
{
  return minibuf_level ? minibuf_window : Qnil;
}

DEFUN ("last-nonminibuf-frame", Flast_nonminibuf_frame, 0, 1, 0, /*
Return the most-recently-selected non-minibuffer-only frame on CONSOLE.
This will always be the same as (selected-frame device) unless the
selected frame is a minibuffer-only frame.
CONSOLE defaults to the selected console if omitted.
*/
       (console))
{
  Lisp_Object result;

  console = wrap_console (decode_console (console));
  /* Just in case the machinations in delete_frame_internal() resulted
     in the last-nonminibuf-frame getting out of sync, make sure and
     return the selected frame if it's acceptable. */
  result = Fselected_frame (CONSOLE_SELECTED_DEVICE (XCONSOLE (console)));
  if (!NILP (result) && !FRAME_MINIBUF_ONLY_P (XFRAME (result)))
    return result;
  return CONSOLE_LAST_NONMINIBUF_FRAME (XCONSOLE (console));
}

DEFUN ("frame-root-window", Fframe_root_window, 0, 1, 0, /*
Return the root-window of FRAME.
If omitted, FRAME defaults to the currently selected frame.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);
  return FRAME_ROOT_WINDOW (f);
}

DEFUN ("frame-selected-window", Fframe_selected_window, 0, 1, 0, /*
Return the selected window of frame object FRAME.
If omitted, FRAME defaults to the currently selected frame.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);
  return FRAME_SELECTED_WINDOW (f);
}

void
set_frame_selected_window (struct frame *f, Lisp_Object window)
{
  assert (XFRAME (WINDOW_FRAME (XWINDOW (window))) == f);
  f->selected_window = window;
  if (!MINI_WINDOW_P (XWINDOW (window)) || FRAME_MINIBUF_ONLY_P (f))
    {
      if (!EQ (f->last_nonminibuf_window, window))
	{
#ifdef HAVE_TOOLBARS
	  MARK_TOOLBAR_CHANGED;
#endif
	  MARK_GUTTER_CHANGED;
	}
      f->last_nonminibuf_window = window;
    }
}

DEFUN ("set-frame-selected-window", Fset_frame_selected_window, 2, 2, 0, /*
Set the selected window of FRAME to WINDOW.
If FRAME is nil, the selected frame is used.
If FRAME is the selected frame, this makes WINDOW the selected window.
*/
       (frame, window))
{
  frame = wrap_frame (decode_frame (frame));
  CHECK_LIVE_WINDOW (window);

  if (! EQ (frame, WINDOW_FRAME (XWINDOW (window))))
    invalid_argument ("In `set-frame-selected-window', WINDOW is not on FRAME", Qunbound);

  if (XFRAME (frame) == selected_frame ())
    return Fselect_window (window, Qnil);

  set_frame_selected_window (XFRAME (frame), window);
  return window;
}

DEFUN ("disable-frame", Fdisable_frame, 1, 1, 0, /*
Disable frame FRAME, so that it cannot have the focus or receive user input.
This is normally used during modal dialog boxes.
WARNING: Be very careful not to wedge XEmacs!
Use an `unwind-protect' that re-enables the frame to avoid this.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);

  f->disabled = 1;
  MAYBE_FRAMEMETH (f, disable_frame, (f));
  return Qnil;
}

DEFUN ("enable-frame", Fenable_frame, 1, 1, 0, /*
Enable frame FRAME, so that it can have the focus and receive user input.
Frames are normally enabled, unless explicitly disabled using `disable-frame'.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);
  f->disabled = 0;
  MAYBE_FRAMEMETH (f, enable_frame, (f));
  return Qnil;
}

/**************************************************************************/
/*                                                                        */
/*                     traversing the list of frames                      */
/*                                                                        */
/**************************************************************************/

int
is_surrogate_for_selected_frame (struct frame *f)
{
  struct device *d = XDEVICE (f->device);
  struct frame *dsf = device_selected_frame (d);

  /* Can't be a surrogate for ourselves. */
  if (f == dsf)
    return 0;

  if (!FRAME_HAS_MINIBUF_P (dsf) &&
      f == XFRAME (WINDOW_FRAME (XWINDOW (FRAME_MINIBUF_WINDOW (dsf)))))
    return 1;
  else
    return 0;
}

static int
frame_matches_frame_spec (Lisp_Object frame, Lisp_Object type)
{
  struct frame *f = XFRAME (frame);

  if (WINDOWP (type))
    {
      CHECK_LIVE_WINDOW (type);

      if (EQ (FRAME_MINIBUF_WINDOW (f), type)
	  /* Check that F either is, or has forwarded
	     its focus to, TYPE's frame.  */
	  && (EQ (WINDOW_FRAME (XWINDOW (type)), frame)
	      || EQ (WINDOW_FRAME (XWINDOW (type)),
		     FRAME_FOCUS_FRAME (f))))
	return 1;
      else
	return 0;
    }

#if 0 /* FSFmacs */
  if (EQ (type, Qvisible) || EQ (type, Qiconic) || EQ (type, Qvisible_iconic)
      || EQ (type, Qvisible_nomini) || EQ (type, Qiconic_nomini)
      || EQ (type, Qvisible_iconic_nomini))
    FRAME_SAMPLE_VISIBILITY (f);
#endif

  if (NILP (type))
    type = Qnomini;
  if (ZEROP (type))
    type = Qvisible_iconic;

  if (EQ (type, Qvisible))
    return FRAME_VISIBLE_P (f);
  if (EQ (type, Qiconic))
    return FRAME_ICONIFIED_P (f);
  if (EQ (type, Qinvisible))
    return !FRAME_VISIBLE_P (f) && !FRAME_ICONIFIED_P (f);
  if (EQ (type, Qvisible_iconic))
    return FRAME_VISIBLE_P (f) || FRAME_ICONIFIED_P (f);
  if (EQ (type, Qinvisible_iconic))
    return !FRAME_VISIBLE_P (f);

  if (EQ (type, Qnomini))
    return !FRAME_MINIBUF_ONLY_P (f);
  if (EQ (type, Qvisible_nomini))
    return FRAME_VISIBLE_P (f) && !FRAME_MINIBUF_ONLY_P (f);
  if (EQ (type, Qiconic_nomini))
    return FRAME_ICONIFIED_P (f) && !FRAME_MINIBUF_ONLY_P (f);
  if (EQ (type, Qinvisible_nomini))
    return !FRAME_VISIBLE_P (f) && !FRAME_ICONIFIED_P (f) &&
      !FRAME_MINIBUF_ONLY_P (f);
  if (EQ (type, Qvisible_iconic_nomini))
    return ((FRAME_VISIBLE_P (f) || FRAME_ICONIFIED_P (f))
	    && !FRAME_MINIBUF_ONLY_P (f));
  if (EQ (type, Qinvisible_iconic_nomini))
    return !FRAME_VISIBLE_P (f) && !FRAME_MINIBUF_ONLY_P (f);

  return 1;
}

int
device_matches_device_spec (Lisp_Object device, Lisp_Object device_spec)
{
  if (EQ (device_spec, Qwindow_system))
    return DEVICE_WIN_P (XDEVICE (device));
  if (DEVICEP (device_spec))
    return EQ (device, device_spec);
  if (CONSOLEP (device_spec))
    return EQ (DEVICE_CONSOLE (XDEVICE (device)), device_spec);
  if (valid_console_type_p (device_spec))
    return EQ (DEVICE_TYPE (XDEVICE (device)), device_spec);
  return 1;
}

/* Return the next frame in the frame list after FRAME.
   WHICH-FRAMES and WHICH-DEVICES control which frames and devices
   are considered; see `next-frame'. */

Lisp_Object
next_frame (Lisp_Object frame, Lisp_Object which_frames, Lisp_Object which_devices)
{
  Lisp_Object first = Qnil;
  Lisp_Object devcons, concons;
  int passed = 0;

  CHECK_LIVE_FRAME (frame);

  DEVICE_LOOP_NO_BREAK (devcons, concons)
    {
      Lisp_Object device = XCAR (devcons);
      Lisp_Object frmcons;

      if (!device_matches_device_spec (device, which_devices))
	{
	  if (EQ (device, FRAME_DEVICE (XFRAME (frame))))
	    passed = 1;
	  continue;
	}

      DEVICE_FRAME_LOOP (frmcons, XDEVICE (device))
	{
	  Lisp_Object f = XCAR (frmcons);

	  if (passed)
	    {
	      if (frame_matches_frame_spec (f, which_frames))
		return f;
	    }
	  else
	    {
	      if (EQ (frame, f))
		{
		  passed = 1;
		}
	      else
		{
		  if (NILP (first) && frame_matches_frame_spec (f, which_frames))
		    first = f;
		}
	    }
	}
    }

  if (NILP (first))
    /* We went through the whole frame list without finding a single
       acceptable frame.  Return the original frame.  */
    return frame;
  else
    /* There were no acceptable frames in the list after FRAME; otherwise,
       we would have returned directly from the loop.  Since FIRST is the last
       acceptable frame in the list, return it.  */
    return first;
}

/* Return the previous frame in the frame list before FRAME.
   WHICH-FRAMES and WHICH-DEVICES control which frames and devices
   are considered; see `next-frame'. */

Lisp_Object
previous_frame (Lisp_Object frame, Lisp_Object which_frames, Lisp_Object which_devices)
{
  Lisp_Object devcons, concons;
  Lisp_Object last = Qnil;

  CHECK_LIVE_FRAME (frame);

  DEVICE_LOOP_NO_BREAK (devcons, concons)
    {
      Lisp_Object device = XCAR (devcons);
      Lisp_Object frmcons;

      if (!device_matches_device_spec (device, which_devices))
	{
	  if (EQ (device, FRAME_DEVICE (XFRAME (frame)))
	      && !NILP (last))
	    return last;
	  continue;
	}

      DEVICE_FRAME_LOOP (frmcons, XDEVICE (device))
	{
	  Lisp_Object f = XCAR (frmcons);

	  if (EQ (frame, f))
	    {
	      if (!NILP (last))
		return last;
	    }
	  else
	    {
	      if (frame_matches_frame_spec (f, which_frames))
		last = f;
	    }
	}
    }

  if (NILP (last))
    /* We went through the whole frame list without finding a single
       acceptable frame.  Return the original frame.  */
    return frame;
  else
    /* There were no acceptable frames in the list before FRAME; otherwise,
       we would have returned directly from the loop.  Since LAST is the last
       acceptable frame in the list, return it.  */
    return last;
}

DEFUN ("next-frame", Fnext_frame, 0, 3, 0, /*
Return the next frame of the right type in the frame list after FRAME.
WHICH-FRAMES controls which frames are eligible to be returned; all
others will be skipped.  Note that if there is only one eligible
frame, then `next-frame' called repeatedly will always return
the same frame, and if there is no eligible frame, then FRAME is
returned.

Possible values for WHICH-FRAMES are

`visible'                 Consider only frames that are visible.
`iconic'                  Consider only frames that are iconic.
`invisible'               Consider only frames that are invisible
			  (this is different from iconic).
`visible-iconic'          Consider frames that are visible or iconic.
`invisible-iconic'        Consider frames that are invisible or iconic.
`nomini'                  Consider all frames except minibuffer-only ones.
`visible-nomini'          Like `visible' but omits minibuffer-only frames.
`iconic-nomini'           Like `iconic' but omits minibuffer-only frames.
`invisible-nomini'        Like `invisible' but omits minibuffer-only frames.
`visible-iconic-nomini'   Like `visible-iconic' but omits minibuffer-only
			  frames.
`invisible-iconic-nomini' Like `invisible-iconic' but omits minibuffer-only
			  frames.
any other value           Consider all frames.

If WHICH-FRAMES is omitted, `nomini' is used.  A value for WHICH-FRAMES
of 0 (a number) is treated like `iconic', for backwards compatibility.

If WHICH-FRAMES is a window, include only its own frame and any frame
now using that window as the minibuffer.

The optional third argument WHICH-DEVICES further clarifies on which
devices to search for frames as specified by WHICH-FRAMES.
If nil or omitted, search all devices on FRAME's console.
If a device, only search that device.
If a console, search all devices on that console.
If a device type, search all devices of that type.
If `window-system', search all window-system devices.
Any other non-nil value means search all devices.
*/
       (frame, which_frames, which_devices))
{
  frame = wrap_frame (decode_frame (frame));

  return next_frame (frame, which_frames, which_devices);
}

DEFUN ("previous-frame", Fprevious_frame, 0, 3, 0, /*
Return the next frame of the right type in the frame list after FRAME.
WHICH-FRAMES controls which frames are eligible to be returned; all
others will be skipped.  Note that if there is only one eligible
frame, then `previous-frame' called repeatedly will always return
the same frame, and if there is no eligible frame, then FRAME is
returned.

See `next-frame' for an explanation of the WHICH-FRAMES and WHICH-DEVICES
arguments.
*/
       (frame, which_frames, which_devices))
{
  frame = wrap_frame (decode_frame (frame));

  return previous_frame (frame, which_frames, which_devices);
}

/* Return any frame for which PREDICATE is non-zero, or return Qnil
   if there aren't any. */

Lisp_Object
find_some_frame (int (*predicate) (Lisp_Object, void *),
		 void *closure)
{
  Lisp_Object framecons, devcons, concons;

  FRAME_LOOP_NO_BREAK (framecons, devcons, concons)
    {
      Lisp_Object frame = XCAR (framecons);

      if ((predicate) (frame, closure))
	return frame;
    }

  return Qnil;
}


/**************************************************************************/
/*                                                                        */
/*                             frame deletion                             */
/*                                                                        */
/**************************************************************************/

/* extern void free_line_insertion_deletion_costs (struct frame *f); */

/* Return 1 if it is ok to delete frame F;
   0 if all frames aside from F are invisible.
   (Exception: if F is a stream frame, it's OK to delete if
   any other frames exist.) */

int
other_visible_frames (struct frame *f)
{
  Lisp_Object frame = wrap_frame (f);

  if (FRAME_STREAM_P (f))
    return !EQ (frame, next_frame (frame, Qt, Qt));
  return !EQ (frame, next_frame (frame, Qvisible_iconic_nomini, Qt));
}

/* Delete frame F.

   If FORCE is non-zero, allow deletion of the only frame.

   If CALLED_FROM_DELETE_DEVICE is non-zero, then, if
   deleting the last frame on a device, just delete it,
   instead of calling `delete-device'.

   If FROM_IO_ERROR is non-zero, then the frame is gone due
   to an I/O error.  This affects what happens if we exit
   (we do an emergency exit instead of `save-buffers-kill-emacs'.)
*/

void
delete_frame_internal (struct frame *f, int force,
		       int called_from_delete_device,
		       int from_io_error)
{
  /* This function can GC */
  int minibuffer_selected;
  struct device *d;
  struct console *con;
  Lisp_Object frame;
  Lisp_Object device;
  Lisp_Object console;
  struct gcpro gcpro1;
  int depth;

  /* OK to delete an already deleted frame. */
  if (!FRAME_LIVE_P (f))
    return;

  frame = wrap_frame (f);

  if (!force)
    check_allowed_operation (OPERATION_DELETE_OBJECT, frame, Qnil);

  GCPRO1 (frame);

  device = FRAME_DEVICE (f);
  d = XDEVICE (device);
  console = DEVICE_CONSOLE (d);
  con = XCONSOLE (console);

  if (!called_from_delete_device
      && !DEVICE_IMPL_FLAG (d, XDEVIMPF_FRAMELESS_OK))
    {
      /* If we're deleting the only non-minibuffer frame on the
	 device, delete the device. */
      if (EQ (frame, next_frame (frame, Qnomini, FRAME_DEVICE (f))))
	{
	  delete_device_internal (d, force, 0, from_io_error);
	  UNGCPRO;
	  return;
	}
    }

  /* In FSF, delete-frame will not normally allow you to delete the
     last visible frame.  This was too annoying, so we changed it to the
     only frame.  However, this would let people shoot themselves by
     deleting all frames which were either visible or iconified and thus
     losing any way of communicating with the still running XEmacs process.
     So we put it back.  */
  if (!force && !allow_deletion_of_last_visible_frame &&
      !other_visible_frames (f))
    invalid_operation ("Attempt to delete the sole visible or iconified frame", Qunbound);

  /* Does this frame have a minibuffer, and is it the surrogate
     minibuffer for any other frame?  */
  if (FRAME_HAS_MINIBUF_P (f))
    {
      Lisp_Object frmcons, devcons, concons;

      FRAME_LOOP_NO_BREAK (frmcons, devcons, concons)
	{
	  Lisp_Object this_frame = XCAR (frmcons);

	  if (! EQ (this_frame, frame)
	      && EQ (frame, (WINDOW_FRAME
			     (XWINDOW
			      (FRAME_MINIBUF_WINDOW (XFRAME (this_frame)))))))
	    {
	      /* We've found another frame whose minibuffer is on
		 this frame. */
	      gui_error
		("Attempt to delete a surrogate minibuffer frame", frame);
	    }
	}
    }

  /* Test for popup frames hanging around. */
  /* Deletion of a parent frame with popups is deadly. */
  {
    Lisp_Object frmcons, devcons, concons;

    FRAME_LOOP_NO_BREAK (frmcons, devcons, concons)
      {
	Lisp_Object this_frame = XCAR (frmcons);


	if (! EQ (this_frame, frame))
	  {
	    struct device *devcons_d = XDEVICE (XCAR (devcons));
	    if (EQ (frame, DEVMETH_OR_GIVEN (devcons_d, get_frame_parent,
					     (XFRAME (this_frame)),
					     Qnil)))
	      /* We've found a popup frame whose parent is this frame. */
	      gui_error
		("Attempt to delete a frame with live popups", frame);
	  }
      }
  }

  /* Before here, we haven't made any dangerous changes (just checked for
     error conditions).  Now run the delete-frame-hook.  Remember that
     user code there could do any number of dangerous things, including
     signalling an error. */

  va_run_hook_with_args (Qdelete_frame_hook, 1, frame);

  if (!FRAME_LIVE_P (f)) /* Make sure the delete-frame-hook didn't */
    {		         /* go ahead and delete anything. */
      UNGCPRO;
      return;
    }

  /* Call the delete-device-hook and delete-console-hook now if
     appropriate, before we do any dangerous things -- they too could
     signal an error. */
  if (XFIXNUM (Flength (DEVICE_FRAME_LIST (d))) == 1)
    {
      va_run_hook_with_args (Qdelete_device_hook, 1, device);
      if (!FRAME_LIVE_P (f)) /* Make sure the delete-device-hook didn't */
	{		     /*	go ahead and delete anything. */
	  UNGCPRO;
	  return;
	}

      if (XFIXNUM (Flength (CONSOLE_DEVICE_LIST (con))) == 1)
	{
	  va_run_hook_with_args (Qdelete_console_hook, 1, console);
	  if (!FRAME_LIVE_P (f)) /* Make sure the delete-console-hook didn't */
	    {			 /* go ahead and delete anything. */
	      UNGCPRO;
	      return;
	    }
	}
    }

  minibuffer_selected = EQ (minibuf_window, Fselected_window (Qnil));

  /* If we were focused on this frame, then we're not any more.
     Assume that we lost the focus; that way, the call to
     Fselect_frame() below won't end up making us explicitly
     focus on another frame, which is generally undesirable in
     a point-to-type world.  If our mouse ends up sitting over
     another frame, we will receive a FocusIn event and end up
     making that frame the selected frame.

     #### This may not be an ideal solution in a click-to-type
     world (in that case, we might want to explicitly choose
     another frame to have the focus, rather than relying on
     the WM, which might focus on a frame in a different app
     or focus on nothing at all).  But there's no easy way
     to detect which focus model we're running on, and the
     alternative is more heinous. */

  if (EQ (frame, DEVICE_FRAME_WITH_FOCUS_REAL (d)))
    DEVICE_FRAME_WITH_FOCUS_REAL (d) = Qnil;
  if (EQ (frame, DEVICE_FRAME_WITH_FOCUS_FOR_HOOKS (d)))
    DEVICE_FRAME_WITH_FOCUS_FOR_HOOKS (d) = Qnil;
  if (EQ (frame, DEVICE_FRAME_THAT_OUGHT_TO_HAVE_FOCUS (d)))
    DEVICE_FRAME_THAT_OUGHT_TO_HAVE_FOCUS (d) = Qnil;

  /* Don't allow the deleted frame to remain selected.
     Note that in the former scheme of things, this would
     have caused us to regain the focus.  This no longer
     applies (see above); I think the new behavior is more
     logical.  If someone disagrees, it can always be
     changed (or a new user variable can be introduced, ugh.) */
  if (EQ (frame, DEVICE_SELECTED_FRAME (d)))
    {
      Lisp_Object next;

      /* If this is a popup frame, select its parent if possible.
	 Otherwise, find another visible frame; if none, just take any frame.
	 First try the same device, then the same console. */

      next = DEVMETH_OR_GIVEN (d, get_frame_parent, (f), Qnil);
      if (NILP (next) || EQ (next, frame) || ! FRAME_LIVE_P (XFRAME (next)))
	next = next_frame (frame, Qvisible, device);
      if (NILP (next) || EQ (next, frame))
	next = next_frame (frame, Qvisible, console);
      if (NILP (next) || EQ (next, frame))
	next = next_frame (frame, Qvisible, Qt);
      if (NILP (next) || EQ (next, frame))
	next = next_frame (frame, Qt, device);
      if (NILP (next) || EQ (next, frame))
	next = next_frame (frame, Qt, console);
      if (NILP (next) || EQ (next, frame))
	next = next_frame (frame, Qt, Qt);

      /* if we haven't found another frame at this point
	 then there aren't any. */
      if (NILP (next) || EQ (next, frame))
	;
      else
	{
	  int did_select = 0;
	  /* if this is the global selected frame, select another one. */
	  if (EQ (frame, Fselected_frame (Qnil)))
	    {
		Fselect_frame (next);
		did_select = 1;
	    }
	  /*
	   * If the new frame we just selected is on a different
	   * device then we still need to change DEVICE_SELECTED_FRAME(d)
	   * to a live frame, if there are any left on this device.
	   */
	  if (!EQ (device, FRAME_DEVICE(XFRAME(next))))
	    {
		Lisp_Object next_f = next_frame (frame, Qt, device);
		if (NILP (next_f) || EQ (next_f, frame))
		  set_device_selected_frame (d, Qnil);
		else
		  set_device_selected_frame (d, next_f);
	    }
	  else if (! did_select)
	    set_device_selected_frame (d, next);

	}
    }

  /* Don't allow minibuf_window to remain on a deleted frame.  */
  if (EQ (f->minibuffer_window, minibuf_window))
    {
      struct frame *sel_frame = selected_frame ();
      Fset_window_buffer (sel_frame->minibuffer_window,
			  XWINDOW (minibuf_window)->buffer, Qt);
      minibuf_window = sel_frame->minibuffer_window;

      /* If the dying minibuffer window was selected,
	 select the new one.  */
      if (minibuffer_selected)
	Fselect_window (minibuf_window, Qnil);
    }

  /* After this point, no errors must be allowed to occur. */

  /* Checking for QUIT can run all sorts of weird code and may be deadly
     so don't let it happen. */
  depth = begin_dont_check_for_quit ();

#ifdef HAVE_MENUBARS
  free_frame_menubars (f);
#endif
#ifdef HAVE_SCROLLBARS
  free_frame_scrollbars (f);
#endif
#ifdef HAVE_TOOLBARS
  free_frame_toolbars (f);
#endif
  free_frame_gutters (f);
  /* Unfortunately deleting the frame will also delete the parent of
     all of the subwindow instances current on the frame. I think this
     can lead to bad things when trying to finalize the
     instances. Thus we loop over all instance caches calling the
     finalize method for each instance. */
  free_frame_subwindow_instances (f);

  /* This must be done before the window and window_mirror structures
     are freed.  The scrollbar information is attached to them. */
  MAYBE_FRAMEMETH (f, delete_frame, (f));

  /* Mark all the windows that used to be on FRAME as deleted, and then
     remove the reference to them.  */
  delete_all_subwindows (XWINDOW (f->root_window));
  f->root_window = Qnil;

  /* clear out the cached glyph information */
  f->subwindow_instance_cache = Qnil;

  /* Remove the frame now from the list.  This way, any events generated
     on this frame by the maneuvers below will disperse themselves. */

  /* This used to be Fdelq(), but that will cause a seg fault if the
     QUIT checker happens to get invoked, because the frame list is in
     an inconsistent state. */
  d->frame_list = delq_no_quit (frame, d->frame_list);
  RESET_CHANGED_SET_FLAGS;

  f->visible = 0;

  free_window_mirror (XWINDOW_MIRROR (f->root_mirror));

/*  free_line_insertion_deletion_costs (f); */

  /* If we've deleted the last non-minibuf frame, then try to find
     another one.  */
  if (EQ (frame, CONSOLE_LAST_NONMINIBUF_FRAME (con)))
    {
      Lisp_Object frmcons, devcons;

      set_console_last_nonminibuf_frame (con, Qnil);

      CONSOLE_FRAME_LOOP_NO_BREAK (frmcons, devcons, con)
	{
	  Lisp_Object ecran = XCAR (frmcons);
	  if (!FRAME_MINIBUF_ONLY_P (XFRAME (ecran)))
	    {
	      set_console_last_nonminibuf_frame (con, ecran);
	      goto double_break_1;
	    }
	}
    }
 double_break_1:

#if 0
  /* The following test is degenerate FALSE */
  if (called_from_delete_device < 0)
    /* then we're being called from delete-console, and we shouldn't
       try to find another default-minibuffer frame for the console.
       */
    con->default_minibuffer_frame = Qnil;
#endif

  /* If we've deleted this console's default_minibuffer_frame, try to
     find another one.  Prefer minibuffer-only frames, but also notice
     frames with other windows.  */
  if (EQ (frame, con->default_minibuffer_frame))
    {
      Lisp_Object frmcons, devcons;
      /* The last frame we saw with a minibuffer, minibuffer-only or not.  */
      Lisp_Object frame_with_minibuf;
      /* Some frame we found on the same console, or nil if there are none. */
      Lisp_Object frame_on_same_console;

      frame_on_same_console = Qnil;
      frame_with_minibuf = Qnil;

      set_console_last_nonminibuf_frame (con, Qnil);

      CONSOLE_FRAME_LOOP_NO_BREAK (frmcons, devcons, con)
	{
	  Lisp_Object this_frame;
	  struct frame *f1;

	  this_frame = XCAR (frmcons);
	  f1 = XFRAME (this_frame);

	  /* Consider only frames on the same console
	     and only those with minibuffers.  */
	  if (FRAME_HAS_MINIBUF_P (f1))
	    {
	      frame_with_minibuf = this_frame;
	      if (FRAME_MINIBUF_ONLY_P (f1))
		goto double_break_2;
	    }

	  frame_on_same_console = this_frame;
	}
    double_break_2:

      if (!NILP (frame_on_same_console))
	{
	  /* We know that there must be some frame with a minibuffer out
	     there.  If this were not true, all of the frames present
	     would have to be minibuffer-less, which implies that at some
	     point their minibuffer frames must have been deleted, but
	     that is prohibited at the top; you can't delete surrogate
	     minibuffer frames.  */
	  assert (!NILP (frame_with_minibuf));

	  con->default_minibuffer_frame = frame_with_minibuf;
	}
      else
	/* No frames left on this console--say no minibuffer either.  */
	con->default_minibuffer_frame = Qnil;
    }

  /* Nobody should be accessing anything in this object any more, and
     making all Lisp_Objects Qnil allows for better GC'ing in case a
     pointer to the dead frame continues to hang around.  Zero all
     other structs in case someone tries to access something through
     them. */

  nuke_all_frame_slots (f);
  f->framemeths = dead_console_methods;
  f->frametype = dead_console;

  note_object_deleted (frame);

  unbind_to (depth);

  UNGCPRO;
}

void
io_error_delete_frame (Lisp_Object frame)
{
  delete_frame_internal (XFRAME (frame), 1, 0, 1);
}

DEFUN ("delete-frame", Fdelete_frame, 0, 2, "", /*
Delete FRAME, permanently eliminating it from use.
If omitted, FRAME defaults to the selected frame.
A frame may not be deleted if its minibuffer is used by other frames.
Normally, you cannot delete the last non-minibuffer-only frame (you must
use `save-buffers-kill-emacs' or `kill-emacs').  However, if optional
second argument FORCE is non-nil, you can delete the last frame. (This
will automatically call `save-buffers-kill-emacs'.)
*/
       (frame, force))
{
  /* This function can GC */
  struct frame *f;

  if (NILP (frame))
    {
      f = selected_frame ();
      frame = wrap_frame (f);
    }
  else
    {
      CHECK_FRAME (frame);
      f = XFRAME (frame);
    }

  delete_frame_internal (f, !NILP (force), 0, 0);
  return Qnil;
}


/**************************************************************************/
/*                                                                        */
/*                        mouse position in frame                         */
/*                                                                        */
/**************************************************************************/

/* Return mouse position in character cell units.  */

static int
mouse_pixel_position_1 (struct device *d, Lisp_Object *frame,
			int *x, int *y)
{
  switch (DEVMETH_OR_GIVEN (d, get_mouse_position, (d, frame, x, y), -1))
    {
    case 1:
      return 1;

    case 0:
      *frame = Qnil;
      break;

    case -1:
      *frame = DEVICE_SELECTED_FRAME (d);
      break;

    default:
      ABORT (); /* method is incorrectly written */
    }

  return 0;
}

DEFUN ("mouse-pixel-position", Fmouse_pixel_position, 0, 1, 0, /*
Return a list (WINDOW X . Y) giving the current mouse window and position.
The position is given in pixel units, where (0, 0) is the upper-left corner
of the window.

When the cursor is not over a window, the return value is a list (nil nil).

DEVICE specifies the device on which to read the mouse position, and
defaults to the selected device.  If the device is a mouseless terminal
or XEmacs hasn't been programmed to read its mouse position, it returns
the device's selected window for WINDOW and nil for X and Y.
*/
       (device))
{
  struct device *d = decode_device (device);
  Lisp_Object frame;
  Lisp_Object window = Qnil;
  Lisp_Object x = Qnil;
  Lisp_Object y = Qnil;
  int intx, inty;

  if (mouse_pixel_position_1 (d, &frame, &intx, &inty) > 0)
    {
      struct window *w =
	find_window_by_pixel_pos (intx, inty, XFRAME (frame)->root_window);
      if (w)
	{
	  window = wrap_window (w);

	  /* Adjust the position to be relative to the window. */
	  intx -= w->pixel_left;
	  inty -= w->pixel_top;
	  x = make_fixnum (intx);
	  y = make_fixnum (inty);
	}
    }
  else if (FRAMEP (frame))
    window = FRAME_SELECTED_WINDOW (XFRAME (frame));

  return Fcons (window, Fcons (x, y));
}

DEFUN ("mouse-position", Fmouse_position, 0, 1, 0, /*
Return a list (WINDOW X . Y) giving the current mouse window and position.
The position is of a character under cursor, where (0, 0) is the upper-left
corner of the window.

When the cursor is not over a character, or not over a window, the return
value is a list (nil nil).

DEVICE specifies the device on which to read the mouse position, and
defaults to the selected device.  If the device is a mouseless terminal
or Emacs hasn't been programmed to read its mouse position, it returns
the device's selected window for WINDOW and nil for X and Y.
*/
       (device))
{
  struct device *d = decode_device (device);
  struct window *w;
  Lisp_Object frame, window = Qnil, lisp_x = Qnil, lisp_y = Qnil;
  int x, y, obj_x, obj_y;
  Charbpos charbpos, closest;
  Charcount modeline_closest;
  Lisp_Object obj1, obj2;

  if (mouse_pixel_position_1 (d, &frame, &x, &y) > 0)
    {
      int res = pixel_to_glyph_translation (XFRAME (frame), x, y, &x, &y,
					    &obj_x, &obj_y, &w, &charbpos,
					    &closest, &modeline_closest,
					    &obj1, &obj2);
      if (res == OVER_TEXT)
	{
	  lisp_x = make_fixnum (x);
	  lisp_y = make_fixnum (y);
	  window = wrap_window (w);
	}
    }
  else if (FRAMEP (frame))
    window = FRAME_SELECTED_WINDOW (XFRAME (frame));

  return Fcons (window, Fcons (lisp_x, lisp_y));
}

DEFUN ("mouse-position-as-motion-event", Fmouse_position_as_motion_event, 0, 1, 0, /*
Return the current mouse position as a motion event.
This allows you to call the standard event functions such as
`event-over-toolbar-p' to determine where the mouse is.

DEVICE specifies the device on which to read the mouse position, and
defaults to the selected device.  If the mouse position can't be determined
\(e.g. DEVICE is a TTY device), nil is returned instead of an event.
*/
       (device))
{
  struct device *d = decode_device (device);
  Lisp_Object frame;
  int intx, inty;

  if (mouse_pixel_position_1 (d, &frame, &intx, &inty))
    {
      Lisp_Object event = Fmake_event (Qnil, Qnil);
      XSET_EVENT_TYPE (event, pointer_motion_event);
      XSET_EVENT_CHANNEL (event, frame);
      XSET_EVENT_MOTION_X (event, intx);
      XSET_EVENT_MOTION_Y (event, inty);
      return event;
    }
  else
    return Qnil;
}

DEFUN ("set-mouse-position", Fset_mouse_position, 3, 3, 0, /*
Move the mouse pointer to the center of character cell (X,Y) in WINDOW.
Note, this is a no-op for an X frame that is not visible.
If you have just created a frame, you must wait for it to become visible
before calling this function on it, like this.
  (while (not (frame-visible-p frame)) (sleep-for .5))
Note also: Warping the mouse is contrary to the ICCCM, so be very sure
 that the behavior won't end up being obnoxious!
*/
       (window, x, y))
{
  struct window *w;
  int pix_x, pix_y;

  CHECK_LIVE_WINDOW (window);
  CHECK_FIXNUM (x);
  CHECK_FIXNUM (y);

  /* Warping the mouse will cause EnterNotify and Focus events under X. */
  w = XWINDOW (window);
  glyph_to_pixel_translation (w, XFIXNUM (x), XFIXNUM (y), &pix_x, &pix_y);

  MAYBE_FRAMEMETH (XFRAME (w->frame), set_mouse_position, (w, pix_x, pix_y));

  return Qnil;
}

DEFUN ("set-mouse-pixel-position", Fset_mouse_pixel_position, 3, 3, 0, /*
Move the mouse pointer to pixel position (X,Y) in WINDOW.
Note, this is a no-op for an X frame that is not visible.
If you have just created a frame, you must wait for it to become visible
before calling this function on it, like this.
  (while (not (frame-visible-p frame)) (sleep-for .5))
*/
       (window, x, y))
{
  struct window *w;

  CHECK_LIVE_WINDOW (window);
  CHECK_FIXNUM (x);
  CHECK_FIXNUM (y);

  /* Warping the mouse will cause EnterNotify and Focus events under X. */
  w = XWINDOW (window);
  FRAMEMETH (XFRAME (w->frame), set_mouse_position, (w, XFIXNUM (x), XFIXNUM (y)));

  return Qnil;
}

/**************************************************************************/
/*                                                                        */
/*                            frame visibility                            */
/*                                                                        */
/**************************************************************************/

DEFUN ("make-frame-visible", Fmake_frame_visible, 0, 1, 0, /*
Make the frame FRAME visible (assuming it is an X-window).
If omitted, FRAME defaults to the currently selected frame.
Also raises the frame so that nothing obscures it.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);

  MAYBE_FRAMEMETH (f, make_frame_visible, (f));
  return frame;
}

DEFUN ("make-frame-invisible", Fmake_frame_invisible, 0, 2, 0, /*
Unconditionally removes frame from the display (assuming it is an X-window).
If omitted, FRAME defaults to the currently selected frame.
If what you want to do is iconify the frame (if the window manager uses
icons) then you should call `iconify-frame' instead.
Normally you may not make FRAME invisible if all other frames are invisible
and uniconified, but if the second optional argument FORCE is non-nil,
you may do so.
*/
       (frame, force))
{
  struct frame *f, *sel_frame;
  struct device *d;

  f = decode_frame (frame);
  d = XDEVICE (FRAME_DEVICE (f));
  sel_frame = XFRAME (DEVICE_SELECTED_FRAME (d));

  if (NILP (force) && !other_visible_frames (f))
    invalid_operation ("Attempt to make invisible the sole visible or iconified frame", Qunbound);

  /* Don't allow minibuf_window to remain on a deleted frame.  */
  if (EQ (f->minibuffer_window, minibuf_window))
    {
      Fset_window_buffer (sel_frame->minibuffer_window,
			  XWINDOW (minibuf_window)->buffer, Qt);
      minibuf_window = sel_frame->minibuffer_window;
    }

  MAYBE_FRAMEMETH (f, make_frame_invisible, (f));

  return Qnil;
}

DEFUN ("iconify-frame", Ficonify_frame, 0, 1, "", /*
Make the frame FRAME into an icon, if the window manager supports icons.
If omitted, FRAME defaults to the currently selected frame.
*/
       (frame))
{
  struct frame *f, *sel_frame;
  struct device *d;

  f = decode_frame (frame);
  d = XDEVICE (FRAME_DEVICE (f));
  sel_frame = XFRAME (DEVICE_SELECTED_FRAME (d));

  /* Don't allow minibuf_window to remain on a deleted frame.  */
  if (EQ (f->minibuffer_window, minibuf_window))
    {
      Fset_window_buffer (sel_frame->minibuffer_window,
			  XWINDOW (minibuf_window)->buffer, Qt);
      minibuf_window = sel_frame->minibuffer_window;
    }

  MAYBE_FRAMEMETH (f, iconify_frame, (f));

  return Qnil;
}

DEFUN ("deiconify-frame", Fdeiconify_frame, 0, 1, 0, /*
Open (de-iconify) the iconified frame FRAME.
Under X, this is currently the same as `make-frame-visible'.
If omitted, FRAME defaults to the currently selected frame.
Also raises the frame so that nothing obscures it.
*/
       (frame))
{
  return Fmake_frame_visible (frame);
}

/* FSF returns `icon' for iconized frames.  What a crock! */

DEFUN ("frame-visible-p", Fframe_visible_p, 0, 1, 0, /*
Return non NIL if FRAME is now "visible" (actually in use for display).
A frame that is not visible is not updated, and, if it works through a
window system, may not show at all.
N.B. Under X "visible" means Mapped. It the window is mapped but not
actually visible on screen then `frame-visible-p' returns `hidden'.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);
  int visible = FRAMEMETH_OR_GIVEN (f, frame_visible_p, (f), f->visible);
  return visible ? ( visible > 0 ? Qt : Qhidden ) : Qnil;
}

DEFUN ("frame-totally-visible-p", Fframe_totally_visible_p, 0, 1, 0, /*
Return t if frame is not obscured by any other window system windows.
Always returns t for tty frames.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);
  return (FRAMEMETH_OR_GIVEN (f, frame_totally_visible_p, (f), f->visible)
	  ? Qt : Qnil);
}

DEFUN ("frame-iconified-p", Fframe_iconified_p, 0, 1, 0, /*
Return t if FRAME is iconified.
Not all window managers use icons; some merely unmap the window, so this
function is not the inverse of `frame-visible-p'.  It is possible for a
frame to not be visible and not be iconified either.  However, if the
frame is iconified, it will not be visible.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);
  if (f->visible)
    return Qnil;
  f->iconified = FRAMEMETH_OR_GIVEN (f, frame_iconified_p, (f), 0);
  return f->iconified ? Qt : Qnil;
}

DEFUN ("visible-frame-list", Fvisible_frame_list, 0, 1, 0, /*
Return a list of all frames now "visible" (being updated).
If DEVICE is specified only frames on that device will be returned.
Note that under virtual window managers not all these frames are
necessarily really updated.
*/
       (device))
{
  Lisp_Object devcons, concons;
  struct frame *f;
  Lisp_Object value;

  value = Qnil;

  DEVICE_LOOP_NO_BREAK (devcons, concons)
    {
      assert (DEVICEP (XCAR (devcons)));

      if (NILP (device) || EQ (device, XCAR (devcons)))
	{
	  Lisp_Object frmcons;

	  DEVICE_FRAME_LOOP (frmcons, XDEVICE (XCAR (devcons)))
	    {
	      Lisp_Object frame = XCAR (frmcons);
	      f = XFRAME (frame);
	      if (FRAME_VISIBLE_P(f))
		value = Fcons (frame, value);
	    }
	}
    }

  return value;
}

DEFUN ("raise-frame", Fraise_frame, 0, 1, "", /*
Bring FRAME to the front, so it occludes any frames it overlaps.
If omitted, FRAME defaults to the currently selected frame.
If FRAME is invisible, make it visible.
If Emacs is displaying on an ordinary terminal or some other device which
doesn't support multiple overlapping frames, this function does nothing.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);

  /* Do like the documentation says. */
  Fmake_frame_visible (frame);
  MAYBE_FRAMEMETH (f, raise_frame, (f));
  return Qnil;
}

DEFUN ("lower-frame", Flower_frame, 0, 1, "", /*
Send FRAME to the back, so it is occluded by any frames that overlap it.
If omitted, FRAME defaults to the currently selected frame.
If Emacs is displaying on an ordinary terminal or some other device which
doesn't support multiple overlapping frames, this function does nothing.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);

  MAYBE_FRAMEMETH (f, lower_frame, (f));
  return Qnil;
}


/***************************************************************************/
/*                                                                         */
/*                           print-related functions                       */
/*                                                                         */
/***************************************************************************/

DEFUN ("print-job-page-number", Fprint_job_page_number, 1, 1, 0, /*
Return current page number for the print job FRAME.
*/
       (frame))
{
  CHECK_PRINTER_FRAME (frame);
  return make_fixnum (FRAME_PAGENUMBER (XFRAME (frame)));
}

DEFUN ("print-job-eject-page", Fprint_job_eject_page, 1, 1, 0, /*
Eject page in the print job FRAME.
*/
       (frame))
{
  struct frame *f;

  CHECK_PRINTER_FRAME (frame);
  f = XFRAME (frame);
  FRAMEMETH (f, eject_page, (f));
  FRAME_SET_PAGENUMBER (f, 1 + FRAME_PAGENUMBER (f));
  f->clear = 1;

  return Qnil;
}


/***************************************************************************/
/*                                                                         */
/*                           frame properties                              */
/*                                                                         */
/***************************************************************************/

DEFUN ("frame-name", Fframe_name, 0, 1, 0, /*
Return the name of FRAME (defaulting to the selected frame).
This is not the same as the `title' of the frame.
*/
       (frame))
{
  return decode_frame (frame)->name;
}

DEFUN ("frame-modified-tick", Fframe_modified_tick, 0, 1, 0, /*
Return FRAME's tick counter, incremented for each change to the frame.
Each frame has a tick counter which is incremented each time the frame
is resized, a window is resized, added, or deleted, a face is changed,
`set-window-buffer' or `select-window' is called on a window in the
frame, the window-start of a window in the frame has changed, or
anything else interesting has happened.  It wraps around occasionally.
No argument or nil as argument means use selected frame as FRAME.
*/
       (frame))
{
  return make_fixnum (decode_frame (frame)->modiff);
}

static void
store_minibuf_frame_prop (struct frame *f, Lisp_Object val)
{
  /* This can call Lisp. */
  Lisp_Object frame = wrap_frame (f);

  if (WINDOWP (val))
    {
      if (! MINI_WINDOW_P (XWINDOW (val)))
	gui_error
	  ("Surrogate minibuffer windows must be minibuffer windows",
	   val);

      if (FRAME_HAS_MINIBUF_P (f) || FRAME_MINIBUF_ONLY_P (f))
	gui_error
	  ("Can't change the surrogate minibuffer of a frame with its own minibuffer", frame);

      /* Install the chosen minibuffer window, with proper buffer.  */
      f->minibuffer_window = val;
    }
  else if (EQ (val, Qt))
    {
      if (FRAME_HAS_MINIBUF_P (f) || FRAME_MINIBUF_ONLY_P (f))
	gui_error
	  ("Frame already has its own minibuffer", frame);
      else
	{
	  setup_normal_frame (f);
	  f->mirror_dirty = 1;

	  update_frame_window_mirror (f);
	  internal_set_frame_size (f, f->width, f->height, 1);
	}
    }
}

#if 0

/* possible code if you want to have symbols such as `default-background'
   map to setting the background of `default', etc. */

static int
dissect_as_face_setting (Lisp_Object sym, Lisp_Object *face_out,
			 Lisp_Object *face_prop_out)
{
  Lisp_Object list = Vbuilt_in_face_specifiers;
  Lisp_Object s;

  if (!SYMBOLP (sym))
    return 0;

  s = symbol_name (XSYMBOL (sym));

  while (!NILP (list))
    {
      Lisp_Object prop = Fcar (list);
      Lisp_Object prop_name;

      if (!SYMBOLP (prop))
	continue;
      prop_name = symbol_name (XSYMBOL (prop));
      if (XSTRING_LENGTH (s) > XSTRING_LENGTH (prop_name) + 1
	  && !memcmp (XSTRING_DATA (prop_name),
		      XSTRING_DATA (s) + XSTRING_LENGTH (s)
		      - XSTRING_LENGTH (prop_name),
		      XSTRING_LENGTH (prop_name))
	  && XSTRING_DATA (s)[XSTRING_LENGTH (s) - XSTRING_LENGTH (prop_name)
			     - 1] == '-')
	{
	  Lisp_Object face =
	    Ffind_face (make_string (XSTRING_DATA (s),
				     XSTRING_LENGTH (s)
				     - XSTRING_LENGTH (prop_name)
				     - 1));
	  if (!NILP (face))
	    {
	      *face_out = face;
	      *face_prop_out = prop;
	      return 1;
	    }
	}

      list = Fcdr (list);
    }

  return 0;
}

#endif /* 0 */

static Lisp_Object
get_property_alias (Lisp_Object prop)
{
  while (1)
    {
      Lisp_Object alias = Qnil;

      if (SYMBOLP (prop))
	alias = Fget (prop, Qframe_property_alias, Qnil);
      if (NILP (alias))
	break;
      prop = alias;
      QUIT;
    }

  return prop;
}

/* #### Using this to modify the internal border width has no effect
   because the change isn't propagated to the windows.  Are there
   other properties which this claims to handle, but doesn't?

   But of course.  This stuff needs more work, but it's a lot closer
   to sanity now than before with the horrible frame-params stuff. */

DEFUN ("set-frame-properties", Fset_frame_properties, 2, 2, 0, /*
Change some properties of a frame.
PLIST is a property list.
You can also change frame properties individually using `set-frame-property',
but it may be more efficient to change many properties at once.

Frame properties can be retrieved using `frame-property' or `frame-properties'.

The following symbols etc. have predefined meanings:

 name		Name of the frame.  Used with X resources.
		Unchangeable after creation.

 height		Height of the frame, in lines.

 width		Width of the frame, in characters.

 minibuffer	Gives the minibuffer behavior for this frame.  Either
		t (frame has its own minibuffer), `only' (frame is
		a minibuffer-only frame), `none' (frame has no minibuffer)
		or a window (frame uses that window, which is on another
		frame, as the minibuffer).

 unsplittable	If non-nil, frame cannot be split by `display-buffer'.

 current-display-table, menubar-visible-p, left-margin-width,
 right-margin-width, minimum-line-ascent, minimum-line-descent,
 use-left-overflow, use-right-overflow, scrollbar-width, scrollbar-height,
 default-toolbar, top-toolbar, bottom-toolbar, left-toolbar, right-toolbar,
 default-toolbar-height, default-toolbar-width, top-toolbar-height,
 bottom-toolbar-height, left-toolbar-width, right-toolbar-width,
 default-toolbar-visible-p, top-toolbar-visible-p, bottom-toolbar-visible-p,
 left-toolbar-visible-p, right-toolbar-visible-p, toolbar-buttons-captioned-p,
 top-toolbar-border-width, bottom-toolbar-border-width,
 left-toolbar-border-width, right-toolbar-border-width,
 modeline-shadow-thickness, has-modeline-p,
 default-gutter, top-gutter, bottom-gutter, left-gutter, right-gutter,
 default-gutter-height, default-gutter-width, top-gutter-height,
 bottom-gutter-height, left-gutter-width, right-gutter-width,
 default-gutter-visible-p, top-gutter-visible-p, bottom-gutter-visible-p,
 left-gutter-visible-p, right-gutter-visible-p, top-gutter-border-width,
 bottom-gutter-border-width, left-gutter-border-width, right-gutter-border-width,
		[Giving the name of any built-in specifier variable is
		equivalent to calling `set-specifier' on the specifier,
		with a locale of FRAME.  Giving the name to `frame-property'
		calls `specifier-instance' on the specifier.]

 text-pointer-glyph, nontext-pointer-glyph, modeline-pointer-glyph,
 selection-pointer-glyph, busy-pointer-glyph, toolbar-pointer-glyph,
 menubar-pointer-glyph, scrollbar-pointer-glyph, gc-pointer-glyph,
 octal-escape-glyph, control-arrow-glyph, invisible-text-glyph,
 hscroll-glyph, truncation-glyph, continuation-glyph
		[Giving the name of any glyph variable is equivalent to
		calling `set-glyph-image' on the glyph, with a locale
		of FRAME.  Giving the name to `frame-property' calls
		`glyph-image-instance' on the glyph.]

 [default foreground], [default background], [default font],
 [modeline foreground], [modeline background], [modeline font],
 etc.
		[Giving a vector of a face and a property is equivalent
		to calling `set-face-property' on the face and property,
		with a locale of FRAME.  Giving the vector to
		`frame-property' calls `face-property-instance' on the
		face and property.]

Finally, if a frame property symbol has the property `frame-property-alias'
on it, then the value will be used in place of that symbol when looking
up and setting frame property values.  This allows you to alias one
frame property name to another.

See the variables `default-x-frame-plist', `default-tty-frame-plist'
and `default-mswindows-frame-plist' for a description of the properties
recognized for particular types of frames.
*/
       (frame, plist))
{
  /* This can call Lisp. */
  struct frame *f = decode_frame (frame);
  Lisp_Object tail;
  Lisp_Object *tailp;
  struct gcpro gcpro1, gcpro2;

  frame = wrap_frame (f);
  GCPRO2 (frame, plist);
  Fcheck_valid_plist (plist);
  plist = Fcopy_sequence (plist);
  Fcanonicalize_lax_plist (plist, Qnil);
  for (tail = plist; !NILP (tail); tail = Fcdr (Fcdr (tail)))
    {
      Lisp_Object prop = Fcar (tail);
      Lisp_Object val = Fcar (Fcdr (tail));

      prop = get_property_alias (prop);

#if 0
      /* mly wants this, but it's not reasonable to change the name of a
	 frame after it has been created, because the old name was used
	 for resource lookup. */
      if (EQ (prop, Qname))
	{
	  CHECK_STRING (val);
	  f->name = val;
	}
#endif /* 0 */
      if (EQ (prop, Qminibuffer))
	store_minibuf_frame_prop (f, val);
      if (EQ (prop, Qunsplittable))
	f->no_split = !NILP (val);
      if (EQ (prop, Qbuffer_predicate))
	f->buffer_predicate = val;
      if (SYMBOLP (prop) && EQ (Fbuilt_in_variable_type (prop),
				Qconst_specifier))
	call3 (Qset_specifier, Fsymbol_value (prop), val, frame);
      if (SYMBOLP (prop) && !NILP (Fget (prop, Qconst_glyph_variable, Qnil)))
	call3 (Qset_glyph_image, Fsymbol_value (prop), val, frame);
      if (VECTORP (prop) && XVECTOR_LENGTH (prop) == 2)
	{
	  Lisp_Object face_prop = XVECTOR_DATA (prop)[1];
	  CHECK_SYMBOL (face_prop);
	  call4 (Qset_face_property,
		 Fget_face (XVECTOR_DATA (prop)[0]),
		 face_prop, val, frame);
	}
    }

  MAYBE_FRAMEMETH (f, set_frame_properties, (f, plist));
  for (tailp = &plist; !NILP (*tailp);)
    {
      Lisp_Object *next_tailp;
      Lisp_Object next;
      Lisp_Object prop;

      next = Fcdr (*tailp);
      CHECK_CONS (next);
      next_tailp = &XCDR (next);
      prop = Fcar (*tailp);

      prop = get_property_alias (prop);

      if (EQ (prop, Qminibuffer)
	  || EQ (prop, Qunsplittable)
	  || EQ (prop, Qbuffer_predicate)
	  || EQ (prop, Qheight)
	  || EQ (prop, Qwidth)
	  || (SYMBOLP (prop) && EQ (Fbuilt_in_variable_type (prop),
				    Qconst_specifier))
	  || (SYMBOLP (prop) && !NILP (Fget (prop, Qconst_glyph_variable,
					     Qnil)))
	  || (VECTORP (prop) && XVECTOR_LENGTH (prop) == 2)
	  || FRAMEMETH_OR_GIVEN (f, internal_frame_property_p, (f, prop), 0))
	*tailp = *next_tailp;
      tailp = next_tailp;
    }

  f->plist = nconc2 (plist, f->plist);
  Fcanonicalize_lax_plist (f->plist, Qnil);
  UNGCPRO;
  return Qnil;
}

DEFUN ("frame-property", Fframe_property, 2, 3, 0, /*
Return FRAME's value for property PROPERTY.
Return DEFAULT if there is no such property.
See `set-frame-properties' for the built-in property names.
*/
       (frame, property, default_))
{
  struct frame *f = decode_frame (frame);
  Lisp_Object value;

  frame = wrap_frame (f);

  property = get_property_alias (property);

  if (EQ (Qname, property)) return f->name;

  if (EQ (Qheight, property) || EQ (Qwidth, property))
    {
      int width, height;
      get_frame_char_size (f, &width, &height);
      return make_fixnum (EQ (Qheight, property) ? height : width);
    }

  /* NOTE: FSF returns Qnil instead of Qt for FRAME_HAS_MINIBUF_P.
     This is over-the-top bogosity, because it's inconsistent with
     the semantics of `minibuffer' when passed to `make-frame'.
     Returning Qt makes things consistent. */
  if (EQ (Qminibuffer, property))
    return (FRAME_MINIBUF_ONLY_P (f) ? Qonly :
	    FRAME_HAS_MINIBUF_P  (f) ? Qt    :
	    FRAME_MINIBUF_WINDOW (f));
  if (EQ (Qunsplittable, property))
    return FRAME_NO_SPLIT_P (f) ? Qt : Qnil;
  if (EQ (Qbuffer_predicate, property))
    return f->buffer_predicate;

  if (SYMBOLP (property))
    {
      if (EQ (Fbuilt_in_variable_type (property), Qconst_specifier))
	return Fspecifier_instance (Fsymbol_value (property),
				    frame, default_, Qnil);
      if (!NILP (Fget (property, Qconst_glyph_variable, Qnil)))
	{
	  Lisp_Object glyph = Fsymbol_value (property);
	  CHECK_GLYPH (glyph);
	  return Fspecifier_instance (XGLYPH_IMAGE (glyph),
				      frame, default_, Qnil);
	}
    }

  if (VECTORP (property) && XVECTOR_LENGTH (property) == 2)
    {
      Lisp_Object face_prop = XVECTOR_DATA (property)[1];
      CHECK_SYMBOL (face_prop);
      return call3 (Qface_property_instance,
		    Fget_face (XVECTOR_DATA (property)[0]),
		    face_prop, frame);
    }

  if (HAS_FRAMEMETH_P (f, frame_property))
    if (!UNBOUNDP (value = FRAMEMETH (f, frame_property, (f, property))))
      return value;

  if (!UNBOUNDP (value = external_plist_get (&f->plist, property, 1, ERROR_ME)))
    return value;

  return default_;
}

DEFUN ("frame-properties", Fframe_properties, 0, 1, 0, /*
Return a property list of the properties of FRAME.
Do not modify this list; use `set-frame-property' instead.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);
  Lisp_Object result = Qnil;
  struct gcpro gcpro1;

  GCPRO1 (result);

  frame = wrap_frame (f);

  /* #### for the moment (since old code uses `frame-parameters'),
     we call `copy-sequence' on f->plist.  That allows frame-parameters
     to destructively convert the plist into an alist, which is more
     efficient than doing it non-destructively.  At some point we
     should remove the call to copy-sequence. */
  result = Fcopy_sequence (f->plist);

  /* #### should we be adding all the specifiers and glyphs?
     That would entail having a list of them all. */
  if (HAS_FRAMEMETH_P (f, frame_properties))
    result = nconc2 (FRAMEMETH (f, frame_properties, (f)), result);

  if (!NILP (f->buffer_predicate))
    result = cons3 (Qbuffer_predicate, f->buffer_predicate, result);

  if (FRAME_NO_SPLIT_P (f))
    result = cons3 (Qunsplittable, Qt, result);

  /* NOTE: FSF returns Qnil instead of Qt for FRAME_HAS_MINIBUF_P.
     This is over-the-top bogosity, because it's inconsistent with
     the semantics of `minibuffer' when passed to `make-frame'.
     Returning Qt makes things consistent. */
  result = cons3 (Qminibuffer,
		  (FRAME_MINIBUF_ONLY_P (f) ? Qonly :
		   FRAME_HAS_MINIBUF_P  (f) ? Qt    :
		   FRAME_MINIBUF_WINDOW (f)),
		  result);
  {
    int width, height;
    get_frame_char_size (f, &width, &height);
    result = cons3 (Qwidth , make_fixnum (width),  result);
    result = cons3 (Qheight, make_fixnum (height), result);
  }

  result = cons3 (Qname, f->name, result);

  UNGCPRO;
  return result;
}


/**************************************************************************/
/*                                                                        */
/*                     frame sizing (user functions)                      */
/*                                                                        */
/**************************************************************************/

DEFUN ("frame-pixel-height", Fframe_pixel_height, 0, 1, 0, /*
Return the total height in pixels of FRAME.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);
  int width, height;

  get_frame_new_total_pixel_size (f, &width, &height);
  return make_fixnum (height);
}

DEFUN ("frame-displayable-pixel-height", Fframe_displayable_pixel_height, 0, 1, 0, /*
Return the height of the displayable area in pixels of FRAME.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);
  int width, height;

  get_frame_new_displayable_pixel_size (f, &width, &height);
  return make_fixnum (height);
}

DEFUN ("frame-pixel-width", Fframe_pixel_width, 0, 1, 0, /*
Return the total width in pixels of FRAME.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);
  int width, height;

  get_frame_new_total_pixel_size (f, &width, &height);
  return make_fixnum (width);
}

DEFUN ("frame-displayable-pixel-width", Fframe_displayable_pixel_width, 0, 1, 0, /*
Return the width of the displayable area in pixels of FRAME.
*/
       (frame))
{
  struct frame *f = decode_frame (frame);
  int width, height;

  get_frame_new_displayable_pixel_size (f, &width, &height);
  return make_fixnum (width);
}

DEFUN ("set-frame-height", Fset_frame_height, 2, 3, 0, /*
Specify that the frame FRAME has LINES lines.
Optional third arg non-nil means that redisplay should use LINES lines
but that the idea of the actual height of the frame should not be changed.
*/
       (frame, lines, pretend))
{
  /* This can call Lisp. */
  struct frame *f = decode_frame (frame);
  int cwidth, cheight;
  int guwidth, guheight;

  CHECK_FIXNUM (lines);
  get_frame_char_size (f, &cwidth, &cheight);
  cheight = XFIXNUM (lines);
  frame_conversion_internal (f, SIZE_CHAR_CELL, cwidth, cheight,
			     SIZE_FRAME_UNIT, &guwidth, &guheight);
  internal_set_frame_size (f, guwidth, guheight, !NILP (pretend));
  return wrap_frame (f);
}

DEFUN ("set-frame-pixel-height", Fset_frame_pixel_height, 2, 3, 0, /*
Specify that the frame FRAME is a total of HEIGHT pixels tall.
Optional third arg non-nil means that redisplay should be HEIGHT pixels tall
but that the idea of the actual height of the frame should not be changed.
*/
       (frame, height, pretend))
{
  /* This can call Lisp. */
  struct frame *f = decode_frame (frame);
  int pwidth, pheight;
  int guwidth, guheight;

  CHECK_FIXNUM (height);
  get_frame_new_total_pixel_size (f, &pwidth, &pheight);
  pheight = XFIXNUM (height);
  frame_conversion_internal (f, SIZE_TOTAL_PIXEL, pwidth, pheight,
			     SIZE_FRAME_UNIT, &guwidth, &guheight);
  internal_set_frame_size (f, guwidth, guheight, !NILP (pretend));
  return wrap_frame (f);
}

DEFUN ("set-frame-displayable-pixel-height", Fset_frame_displayable_pixel_height, 2, 3, 0, /*
Specify that the displayable area of frame FRAME is HEIGHT pixels tall.
Optional third arg non-nil means that redisplay should be HEIGHT pixels tall
but that the idea of the actual height of the frame should not be changed.
*/
       (frame, height, pretend))
{
  /* This can call Lisp. */
  struct frame *f = decode_frame (frame);
  int pwidth, pheight;
  int guwidth, guheight;

  CHECK_FIXNUM (height);
  get_frame_new_displayable_pixel_size (f, &pwidth, &pheight);
  pheight = XFIXNUM (height);
  frame_conversion_internal (f, SIZE_DISPLAYABLE_PIXEL, pwidth, pheight,
			     SIZE_FRAME_UNIT, &guwidth, &guheight);
  internal_set_frame_size (f, guwidth, guheight, !NILP (pretend));
  return wrap_frame (f);
}


DEFUN ("set-frame-width", Fset_frame_width, 2, 3, 0, /*
Specify that the frame FRAME has COLS columns.
Optional third arg non-nil means that redisplay should use COLS columns
but that the idea of the actual width of the frame should not be changed.
*/
       (frame, cols, pretend))
{
  /* This can call Lisp. */
  struct frame *f = decode_frame (frame);
  int cwidth, cheight;
  int guwidth, guheight;

  CHECK_FIXNUM (cols);
  get_frame_char_size (f, &cwidth, &cheight);
  cwidth = XFIXNUM (cols);
  frame_conversion_internal (f, SIZE_CHAR_CELL, cwidth, cheight,
			     SIZE_FRAME_UNIT, &guwidth, &guheight);
  internal_set_frame_size (f, guwidth, guheight, !NILP (pretend));
  return wrap_frame (f);
}

DEFUN ("set-frame-pixel-width", Fset_frame_pixel_width, 2, 3, 0, /*
Specify that the frame FRAME is a total of WIDTH pixels wide.
Optional third arg non-nil means that redisplay should be WIDTH wide
but that the idea of the actual height of the frame should not be changed.
*/
       (frame, width, pretend))
{
  /* This can call Lisp. */
  struct frame *f = decode_frame (frame);
  int pwidth, pheight;
  int guwidth, guheight;

  CHECK_FIXNUM (width);
  get_frame_new_total_pixel_size (f, &pwidth, &pheight);
  pwidth = XFIXNUM (width);
  frame_conversion_internal (f, SIZE_TOTAL_PIXEL, pwidth, pheight,
			     SIZE_FRAME_UNIT, &guwidth, &guheight);
  internal_set_frame_size (f, guwidth, guheight, !NILP (pretend));
  return wrap_frame (f);
}

DEFUN ("set-frame-displayable-pixel-width", Fset_frame_displayable_pixel_width, 2, 3, 0, /*
Specify that the displayable area of frame FRAME is WIDTH pixels wide.
Optional third arg non-nil means that redisplay should be WIDTH wide
but that the idea of the actual height of the frame should not be changed.
*/
       (frame, width, pretend))
{
  /* This can call Lisp. */
  struct frame *f = decode_frame (frame);
  int pwidth, pheight;
  int guwidth, guheight;

  CHECK_FIXNUM (width);
  get_frame_new_displayable_pixel_size (f, &pwidth, &pheight);
  pwidth = XFIXNUM (width);
  frame_conversion_internal (f, SIZE_DISPLAYABLE_PIXEL, pwidth, pheight,
			     SIZE_FRAME_UNIT, &guwidth, &guheight);
  internal_set_frame_size (f, guwidth, guheight, !NILP (pretend));
  return wrap_frame (f);
}

DEFUN ("set-frame-size", Fset_frame_size, 3, 4, 0, /*
Set the size of FRAME to COLS by ROWS, measured in characters.
Optional fourth arg non-nil means that redisplay should use COLS by ROWS
but that the idea of the actual size of the frame should not be changed.
*/
       (frame, cols, rows, pretend))
{
  /* This can call Lisp. */
  struct frame *f = decode_frame (frame);
  int guwidth, guheight;

  CHECK_FIXNUM (cols);
  CHECK_FIXNUM (rows);
  frame_conversion_internal (f, SIZE_CHAR_CELL, XFIXNUM (cols), XFIXNUM (rows),
			     SIZE_FRAME_UNIT, &guwidth, &guheight);
  internal_set_frame_size (f, guwidth, guheight, !NILP (pretend));
  return wrap_frame (f);
}

DEFUN ("set-frame-pixel-size", Fset_frame_pixel_size, 3, 4, 0, /*
Set the total size of FRAME to WIDTH by HEIGHT, measured in pixels.
Optional fourth arg non-nil means that redisplay should use WIDTH by HEIGHT
but that the idea of the actual size of the frame should not be changed.
*/
       (frame, width, height, pretend))
{
  /* This can call Lisp. */
  struct frame *f = decode_frame (frame);
  int guwidth, guheight;

  CHECK_FIXNUM (width);
  CHECK_FIXNUM (height);
  frame_conversion_internal (f, SIZE_TOTAL_PIXEL, XFIXNUM (width), XFIXNUM (height),
			     SIZE_FRAME_UNIT, &guwidth, &guheight);
  internal_set_frame_size (f, guwidth, guheight, !NILP (pretend));
  return wrap_frame (f);
}

DEFUN ("set-frame-displayable-pixel-size", Fset_frame_displayable_pixel_size, 3, 4, 0, /*
Set the displayable size of FRAME to WIDTH by HEIGHT, measured in pixels.
Optional fourth arg non-nil means that redisplay should use WIDTH by HEIGHT
but that the idea of the actual size of the frame should not be changed.
*/
       (frame, width, height, pretend))
{
  /* This can call Lisp. */
  struct frame *f = decode_frame (frame);
  int guwidth, guheight;

  CHECK_FIXNUM (width);
  CHECK_FIXNUM (height);
  frame_conversion_internal (f, SIZE_DISPLAYABLE_PIXEL,
			     XFIXNUM (width), XFIXNUM (height),
			     SIZE_FRAME_UNIT, &guwidth, &guheight);
  internal_set_frame_size (f, guwidth, guheight, !NILP (pretend));
  return wrap_frame (f);
}

DEFUN ("set-frame-position", Fset_frame_position, 3, 3, 0, /*
Set position of FRAME in pixels to XOFFSET by YOFFSET.
This is actually the position of the upper left corner of the frame.
Negative values for XOFFSET or YOFFSET are interpreted relative to
the rightmost or bottommost possible position (that stays within the screen).
*/
       (frame, xoffset, yoffset))
{
  struct frame *f = decode_frame (frame);
  CHECK_FIXNUM (xoffset);
  CHECK_FIXNUM (yoffset);

  MAYBE_FRAMEMETH (f, set_frame_position, (f, XFIXNUM (xoffset), XFIXNUM (yoffset)));

  return Qt;
}


/**************************************************************************/
/*                                                                        */
/*                various ways of measuring the frame size                */
/*                                                                        */
/**************************************************************************/

/* Frame size conversion functions moved here from EmacsFrame.c
   because they're generic and really don't belong in that file.
   Function get_default_char_pixel_size() removed because it's
   exactly the same as default_face_width_and_height().

   Convert between total pixel size, displayable pixel size and
   character-cell size.  Variables are either "in", "out" or unused,
   depending on the value of PIXEL_TO_CHAR, which indicates which units the
   source and destination values are measured in.

   See frame_conversion_internal() for a discussion of the different
   types of units. */

static void
frame_conversion_internal_1 (struct frame *f,
			     pixel_to_char_mode_t pixel_to_char,
			     int *total_pixel_width, int *total_pixel_height,
			     int *disp_pixel_width, int *disp_pixel_height,
			     int *char_width, int *char_height)
{
  int cpw, cph;
  int egw;
  int obw, obh, bdr;
  Lisp_Object frame, window;

  frame = wrap_frame (f);
  default_face_width_and_height (frame, &cpw, &cph);

  window = FRAME_SELECTED_WINDOW (f);

  /* #### It really seems like we should also be subtracting out the
     theoretical gutter width and height, just like we do for toolbars.
     There is currently a bug where if you call `set-frame-pixel-width'
     on MS Windows (at least, possibly also X) things get confused and
     the top of the root window overlaps the top gutter instead of being
     below it.  This gets fixed next time you resize the frame using the
     mouse.  Possibly this is caused by not handling the gutter height
     here? */
  egw = max (glyph_width (Vcontinuation_glyph, window),
	     glyph_width (Vtruncation_glyph, window));
  egw = max (egw, cpw);
  bdr = 2 * f->internal_border_width;
  obw = FRAME_SCROLLBAR_WIDTH (f) + FRAME_THEORETICAL_LEFT_TOOLBAR_WIDTH (f) +
    FRAME_THEORETICAL_RIGHT_TOOLBAR_WIDTH (f) +
    2 * FRAME_THEORETICAL_LEFT_TOOLBAR_BORDER_WIDTH (f) +
    2 * FRAME_THEORETICAL_RIGHT_TOOLBAR_BORDER_WIDTH (f);
  obh = FRAME_SCROLLBAR_HEIGHT (f) + FRAME_THEORETICAL_TOP_TOOLBAR_HEIGHT (f) +
    FRAME_THEORETICAL_BOTTOM_TOOLBAR_HEIGHT (f) +
    2 * FRAME_THEORETICAL_TOP_TOOLBAR_BORDER_WIDTH (f) +
    2 * FRAME_THEORETICAL_BOTTOM_TOOLBAR_BORDER_WIDTH (f);

  /* Convert to chars so that the displayable area is pixel_width x
     pixel_height.

     #### Consider rounding up to 0.5 characters to avoid adding too
     much space. */
  switch (pixel_to_char)
    {
    case DISPLAYABLE_PIXEL_TO_CHAR:
      if (char_width)
	*char_width = ROUND_UP (*disp_pixel_width, cpw) / cpw;
      if (char_height)
	*char_height = ROUND_UP (*disp_pixel_height, cph) / cph;
      break;
    case CHAR_TO_DISPLAYABLE_PIXEL:
      if (disp_pixel_width)
	*disp_pixel_width = *char_width * cpw;
      if (disp_pixel_height)
	*disp_pixel_height = *char_height * cph;
      break;
    case TOTAL_PIXEL_TO_CHAR:
      /* Convert to chars so that the total frame size is pixel_width x
	 pixel_height. */
      if (char_width)
	*char_width = 1 + ((*total_pixel_width - egw) - bdr - obw) / cpw;
      if (char_height)
	*char_height = (*total_pixel_height - bdr - obh) / cph;
      break;
    case CHAR_TO_TOTAL_PIXEL:
      if (total_pixel_width)
	*total_pixel_width = (*char_width - 1) * cpw + egw + bdr + obw;
      if (total_pixel_height)
	*total_pixel_height = *char_height * cph + bdr + obh;
      break;
    case TOTAL_PIXEL_TO_DISPLAYABLE_PIXEL:
      /* Convert to chars so that the total frame size is pixel_width x
	 pixel_height. */
      if (disp_pixel_width)
	*disp_pixel_width = cpw + (*total_pixel_width - egw) - bdr - obw;
      if (disp_pixel_height)
	*disp_pixel_height = *total_pixel_height - bdr - obh;
      break;
    case DISPLAYABLE_PIXEL_TO_TOTAL_PIXEL:
      if (total_pixel_width)
	*total_pixel_width = *disp_pixel_width - cpw + egw + bdr + obw;
      if (total_pixel_height)
	*total_pixel_height = *disp_pixel_height + bdr + obh;
      break;
    }
}


static enum frame_size_type
canonicalize_frame_size_type (enum frame_size_type type, int pixgeom)
{
  if (type == SIZE_FRAME_UNIT)
    {
      if (pixgeom)
	type = SIZE_DISPLAYABLE_PIXEL;
      else
	type = SIZE_CHAR_CELL;
    }
  return type;
}

/* Basic frame conversion function.  Convert source size to destination
   size, where either of them can be in total pixels, displayable pixels,
   frame units or character-cell units.

   See comment at top of file for discussion about different types of
   units. */

static void
frame_conversion_internal (struct frame *f,
			   enum frame_size_type source,
			   int source_width, int source_height,
			   enum frame_size_type dest,
			   int *dest_width, int *dest_height)
{
  int pixgeom = window_system_pixelated_geometry (wrap_frame (f));
  dest = canonicalize_frame_size_type (dest, pixgeom);
  source = canonicalize_frame_size_type (source, pixgeom);
  if (source == dest)
    {
      *dest_width = source_width;
      *dest_height = source_height;
    }
  else if (source == SIZE_TOTAL_PIXEL && dest == SIZE_CHAR_CELL)
    frame_conversion_internal_1 (f, TOTAL_PIXEL_TO_CHAR,
				 &source_width, &source_height, 0, 0,
				 dest_width, dest_height);
  else if (source == SIZE_DISPLAYABLE_PIXEL && dest == SIZE_CHAR_CELL)
    frame_conversion_internal_1 (f, DISPLAYABLE_PIXEL_TO_CHAR, 0, 0,
				 &source_width, &source_height,
				 dest_width, dest_height);
  else if (source == SIZE_TOTAL_PIXEL && dest == SIZE_DISPLAYABLE_PIXEL)
    frame_conversion_internal_1 (f, TOTAL_PIXEL_TO_DISPLAYABLE_PIXEL,
				 &source_width, &source_height,
				 dest_width, dest_height, 0, 0);
  else if (dest == SIZE_TOTAL_PIXEL && source == SIZE_CHAR_CELL)
    frame_conversion_internal_1 (f, CHAR_TO_TOTAL_PIXEL,
				 dest_width, dest_height, 0, 0,
				 &source_width, &source_height);
  else if (dest == SIZE_DISPLAYABLE_PIXEL && source == SIZE_CHAR_CELL)
    frame_conversion_internal_1 (f, CHAR_TO_DISPLAYABLE_PIXEL, 0, 0,
				 dest_width, dest_height,
				 &source_width, &source_height);
  else if (dest == SIZE_TOTAL_PIXEL && source == SIZE_DISPLAYABLE_PIXEL)
    frame_conversion_internal_1 (f, DISPLAYABLE_PIXEL_TO_TOTAL_PIXEL,
				 dest_width, dest_height,
				 &source_width, &source_height, 0, 0);
  else
    {
      ABORT ();
      if (dest_width)
	*dest_width = 0;
      if (dest_height)
	*dest_height = 0;
    }
}

/* This takes the size in pixels of the client area, and returns the number
   of characters that will fit there, taking into account the internal
   border width, and the pixel width of the line terminator glyphs (which
   always count as one "character" wide, even if they are not the same size
   as the default character size of the default font).  The frame scrollbar
   width and left and right toolbar widths are also subtracted out of the
   available width.  The frame scrollbar height and top and bottom toolbar
   heights are subtracted out of the available height.

   Therefore the result is not necessarily a multiple of anything in
   particular.  */

void
pixel_to_char_size (struct frame *f, int pixel_width, int pixel_height,
		    int *char_width, int *char_height)
{
  frame_conversion_internal (f, SIZE_TOTAL_PIXEL, pixel_width, pixel_height,
			     SIZE_CHAR_CELL, char_width, char_height);
}

/* Given a character size, this returns the minimum pixel size of the
   client area necessary to display that many characters, taking into
   account the internal border width, scrollbar height and width, toolbar
   heights and widths and the size of the line terminator glyphs (assuming
   the line terminators take up exactly one character position).

   Therefore the result is not necessarily a multiple of anything in
   particular.  */

void
char_to_pixel_size (struct frame *f, int char_width, int char_height,
		    int *pixel_width, int *pixel_height)
{
  frame_conversion_internal (f, SIZE_CHAR_CELL, char_width, char_height,
			     SIZE_TOTAL_PIXEL, pixel_width, pixel_height);
}

/* Versions of the above that operate in "frame units" instead of
   characters.  frame units are the same as characters except on
   MS Windows and MS Printer frames, where they are displayable-area
   pixels. */

void
pixel_to_frame_unit_size (struct frame *f, int pixel_width, int pixel_height,
			 int *frame_unit_width, int *frame_unit_height)
{
  frame_conversion_internal (f, SIZE_TOTAL_PIXEL, pixel_width, pixel_height,
			     SIZE_FRAME_UNIT, frame_unit_width,
			     frame_unit_height);
}

void
frame_unit_to_pixel_size (struct frame *f, int frame_unit_width,
			 int frame_unit_height,
			 int *pixel_width, int *pixel_height)
{
  frame_conversion_internal (f, SIZE_FRAME_UNIT, frame_unit_width,
			     frame_unit_height,
			     SIZE_TOTAL_PIXEL, pixel_width, pixel_height);
}

void
round_size_to_char (struct frame *f, int in_width, int in_height,
		    int *out_width, int *out_height)
{
  int char_width;
  int char_height;
  pixel_to_char_size (f, in_width, in_height, &char_width, &char_height);
  char_to_pixel_size (f, char_width, char_height, out_width, out_height);
}

static void
get_frame_char_size (struct frame *f, int *out_width, int *out_height)
{
  *out_width = FRAME_CHARWIDTH (f);
  *out_height = FRAME_CHARHEIGHT (f);
}

/* Return the "new" frame size in displayable pixels, which will be
   accurate as of next redisplay.  If we have changed the default font or
   toolbar or scrollbar specifiers, the frame pixel size will change as of
   next redisplay, but the frame character-cell size will remain the same.
   So use those dimensions to compute the displayable-pixel size. */

static void
get_frame_new_displayable_pixel_size (struct frame *f, int *out_width,
				      int *out_height)
{
  frame_conversion_internal (f, SIZE_CHAR_CELL, FRAME_CHARWIDTH (f),
			     FRAME_CHARHEIGHT (f), SIZE_DISPLAYABLE_PIXEL,
			     out_width, out_height);
}

/* Return the "new" frame size in total pixels, which will be
   accurate as of next redisplay.  See get_frame_new_displayable_pixel_size().
*/


static void
get_frame_new_total_pixel_size (struct frame *f, int *out_width,
				int *out_height)
{
  frame_conversion_internal (f, SIZE_CHAR_CELL, FRAME_CHARWIDTH (f),
			     FRAME_CHARHEIGHT (f), SIZE_TOTAL_PIXEL,
			     out_width, out_height);
}


/**************************************************************************/
/*                                                                        */
/*                    frame resizing (implementation)                     */
/*                                                                        */
/**************************************************************************/

/* Change the frame height and/or width.  Values passed in are in
   frame units (character cells on X/GTK, displayable-area pixels
   on MS Windows or generally on pixelated-geometry window systems). */
static void
change_frame_size_1 (struct frame *f, int newwidth, int newheight)
{
  int new_pixheight, new_pixwidth;
  int paned_pixheight, paned_pixwidth;
  int real_font_height, real_font_width;

  /* #### Chuck -- shouldn't we be checking to see if the frame
     is being "changed" to its existing size, and do nothing if so? */
  /* No, because it would hose toolbar updates.  The toolbar
     update code relies on this function to cause window `top' and
     `left' coordinates to be recomputed even though no frame size
     change occurs. --kyle */
  assert (!in_display && !hold_frame_size_changes);

  /* We no longer allow bogus values passed in. */
  assert (newheight && newwidth);

  default_face_width_and_height (wrap_frame (f), &real_font_width,
				 &real_font_height);

  frame_conversion_internal (f, SIZE_FRAME_UNIT, newwidth, newheight,
			     SIZE_TOTAL_PIXEL, &new_pixwidth,
			     &new_pixheight);

  /* This size-change overrides any pending one for this frame.  */
  f->size_change_pending = 0;
  FRAME_NEW_HEIGHT (f) = 0;
  FRAME_NEW_WIDTH (f) = 0;

  /* We need to remove the boundaries of the paned area (see top of file)
     from the total-area pixel size, which is what we have now.
  */
  paned_pixheight = new_pixheight -
    (FRAME_NONPANED_SIZE (f, TOP_EDGE) + FRAME_NONPANED_SIZE (f, BOTTOM_EDGE));
  paned_pixwidth = new_pixwidth -
    (FRAME_NONPANED_SIZE (f, LEFT_EDGE) + FRAME_NONPANED_SIZE (f, RIGHT_EDGE));

  XWINDOW (FRAME_ROOT_WINDOW (f))->pixel_top = FRAME_PANED_TOP_EDGE (f);

  if (FRAME_HAS_MINIBUF_P (f)
      && ! FRAME_MINIBUF_ONLY_P (f))
    /* Frame has both root and minibuffer.  */
    {
      /*
       * Leave the minibuffer height the same if the frame has
       * been initialized, and the minibuffer height is tall
       * enough to display at least one line of text in the default
       * font, and the old minibuffer height is a multiple of the
       * default font height.  This should cause the minibuffer
       * height to be recomputed on font changes but not for
       * other frame size changes, which seems reasonable.
       */
      int old_minibuf_height =
	XWINDOW (FRAME_MINIBUF_WINDOW (f))->pixel_height;
      int minibuf_height =
	f->init_finished && (old_minibuf_height % real_font_height) == 0 ?
	max (old_minibuf_height, real_font_height) :
	real_font_height;
      set_window_pixheight (FRAME_ROOT_WINDOW (f),
			    /* - font_height for minibuffer */
			    paned_pixheight - minibuf_height, 0);

      XWINDOW (FRAME_MINIBUF_WINDOW (f))->pixel_top =
	FRAME_PANED_TOP_EDGE (f) +
	FRAME_BOTTOM_GUTTER_BOUNDS (f) +
	paned_pixheight - minibuf_height;

      set_window_pixheight (FRAME_MINIBUF_WINDOW (f), minibuf_height, 0);
    }
  else
    /* Frame has just one top-level window.  */
    set_window_pixheight (FRAME_ROOT_WINDOW (f), paned_pixheight, 0);

  /* Set the value of FRAME_WIDTH/FRAME_HEIGHT and
     FRAME_CHARWIDTH/FRAME_CHARHEIGHT.

     Question: Where is FRAME_PIXWIDTH/FRAME_PIXHEIGHT set?
     Answer: In the device-specific code, as a result of a callback from
     the window system indicating that the frame has changed size.
     This happens:

     (1) in the WM_SIZE processing in event-msw.c
     (2) in update_various_frame_slots() called from EmacsFrameResize()
         (called from Xt when the frame is resized) in EmacsFrame.c for X
     (3) in resize_event_cb() in frame-gtk.c
     (4) For TTY's, there is no such callback, so we have to set it
         ourselves.
  */

  FRAME_HEIGHT (f) = newheight;
  if (FRAME_TTY_P (f))
    f->pixheight = newheight;

  XWINDOW (FRAME_ROOT_WINDOW (f))->pixel_left = FRAME_PANED_LEFT_EDGE (f);
  set_window_pixwidth (FRAME_ROOT_WINDOW (f), paned_pixwidth, 0);

  if (FRAME_HAS_MINIBUF_P (f))
    {
      XWINDOW (FRAME_MINIBUF_WINDOW (f))->pixel_left =
	FRAME_PANED_LEFT_EDGE (f);
      set_window_pixwidth (FRAME_MINIBUF_WINDOW (f), paned_pixwidth, 0);
    }

  FRAME_WIDTH (f) = newwidth;
  if (FRAME_TTY_P (f))
    f->pixwidth = newwidth;

  /* Set the frame character-cell width appropriately. */
  if (window_system_pixelated_geometry (wrap_frame (f)))
    pixel_to_char_size (f, new_pixwidth, new_pixheight,
			&FRAME_CHARWIDTH (f), &FRAME_CHARHEIGHT (f));
  else
    {
      FRAME_CHARWIDTH (f) = FRAME_WIDTH (f);
      FRAME_CHARHEIGHT (f) = FRAME_HEIGHT (f);
    }

  MARK_FRAME_TOOLBARS_CHANGED (f);
  MARK_FRAME_GUTTERS_CHANGED (f);
  MARK_FRAME_CHANGED (f);
  f->echo_area_garbaged = 1;
}

/* This function is called to change the redisplay structures of a frame
   to correspond to a new width and height.  IT DOES NOT CHANGE THE ACTUAL
   SIZE OF A FRAME.  It is meant to be called after the frame has been
   resized, either as a result of user action or a call to a function
   such as `set-frame-size'.  For example, under MS-Windows it is called
   from mswindows_wnd_proc() when a WM_SIZE message is received, indicating
   that the user resized the frame, and from mswindows_set_frame_size(),
   which is the device method that is called (from internal_set_frame_size())
   when `set-frame-size' or similar function is called.

   Values passed in are in frame units (character cells on X/GTK,
   displayable-area pixels on MS Windows or generally on pixelated-geometry
   window systems).  See discussion at top of file.

   See also internal_set_frame_size() and adjust_frame_size().
*/

void
change_frame_size (struct frame *f, int newwidth, int newheight, int delay)
{
  /* sometimes we get passed a size that's too small (esp. when a
     client widget gets resized, since we have no control over this).
     So deal. */
  check_frame_size (f, &newwidth, &newheight);

  /* Unconditionally mark that the frame has changed size. This is
     because many things need to know after the
     fact. f->size_change_pending will get reset below. The most that
     can happen is that we will cycle through redisplay once more
     --andy. */
  MARK_FRAME_SIZE_CHANGED (f);

#ifdef NEW_GC
  if (delay || hold_frame_size_changes)
#else /* not NEW_GC */
  if (delay || hold_frame_size_changes || gc_in_progress)
#endif /* not NEW_GC */
    {
      f->new_width = newwidth;
      f->new_height = newheight;
      return;
    }

  /* For TTY frames, it's like one, like all ...
     Can't have two TTY frames of different sizes on the same device. */
  if (FRAME_TTY_P (f))
    {
      Lisp_Object frmcons;

      DEVICE_FRAME_LOOP (frmcons, XDEVICE (FRAME_DEVICE (f)))
	change_frame_size_1 (XFRAME (XCAR (frmcons)), newwidth, newheight);
    }
  else
    change_frame_size_1 (f, newwidth, newheight);
}


/* This function is called from `set-frame-size' or the like, to explicitly
   change the size of a frame.  It calls the `set_frame_size' device
   method, which makes the necessary window-system-specific call to change
   the size of the frame and then calls change_frame_size() to change
   the redisplay structures appropriately.

   Values passed in are in frame units (character cells on X/GTK,
   displayable-area pixels on MS Windows or generally on pixelated-geometry
   window systems).  See discussion at top of file.
 */

void
internal_set_frame_size (struct frame *f, int cols, int rows, int pretend)
{
  /* This can call Lisp.  See mswindows_set_frame_size(). */
  /* An explicit size change cancels any pending frame size adjustment */
  CLEAR_FRAME_SIZE_SLIPPED (f);

  if (pretend || !HAS_FRAMEMETH_P (f, set_frame_size))
    change_frame_size (f, cols, rows, 0);
  else
    FRAMEMETH (f, set_frame_size, (f, cols, rows));
}

/* This function is called from redisplay_frame() as a result of the
   "frame_slipped" flag being set.  This flag is set when the default font
   changes or when a change to scrollbar or toolbar visibility or size
   is made (e.g. when a specifier such as `scrollbar-width' is changed).
   Its purpose is to resize the frame so that its size in character-cell
   units stays the same.

   #### It should also be triggered by a change the gutter visibility or
   size.

   When a scrollbar or toolbar specifier is changed, the
   frame_size_slipped() function is called (this happens because the
   specifier's value_changed_in_frame() hook has been set to
   frame_size_slipped() by a call to set_specifier_caching()).
   All this does is call MARK_FRAME_SIZE_SLIPPED(), which sets the
   frame_slipped flag, which gets noticed by redisplay_frame(), as just
   discussed.

   The way things get triggered when a change is made to the default font
   is as follows:

   (1) The specifier for the default font, which is attached to the
       face named `default', has its "face" property set to the `default'
       face.

   (2) font_after_change() (the font specifier's after_changed() method)
       is called for the font specifier.


   (3) It in turn calls face_property_was_changed(), passing in the
       default face.

   (4) face_property_was_changed() notices that the default face is having
       a property set and calls update_EmacsFrame().

   (5) This in turn notices that the default face's font is being changed
       and calls MARK_FRAME_SIZE_SLIPPED() -- see above.
 */

void
adjust_frame_size (struct frame *f)
{
  /* This can call Lisp. */
  int keep_char_size = 0;
  Lisp_Object frame = wrap_frame (f);

  if (!f->size_slipped)
    return;

  /* Don't adjust tty frames. #### May break when TTY have menubars.
     Then, write an Vadjust_frame_function which will return t for TTY
     frames. Another solution is frame_size_fixed_p method for TTYs,
     which always returned yes it's fixed.
  */
  if (!FRAME_WIN_P (f))
    {
      CLEAR_FRAME_SIZE_SLIPPED (f);
      return;
    }

  /* frame_size_fixed_p tells that frame size cannot currently
     be changed change due to external conditions */
  if (!FRAMEMETH_OR_GIVEN (f, frame_size_fixed_p, (f), 0))
    {
      if (NILP (Vadjust_frame_function))
	keep_char_size = 1;
      else if (EQ (Vadjust_frame_function, Qt))
	keep_char_size = 0;
      else
	keep_char_size =
	  NILP (call1_trapping_problems ("Error in adjust-frame-function",
					 Vadjust_frame_function, frame,
					 0));

      if (keep_char_size)
	Fset_frame_size (frame, make_fixnum (FRAME_CHARWIDTH(f)),
			 make_fixnum (FRAME_CHARHEIGHT(f)), Qnil);
    }

  if (!keep_char_size)
    {
      int height, width;
      pixel_to_frame_unit_size (f, FRAME_PIXWIDTH(f), FRAME_PIXHEIGHT(f),
			  &width, &height);
      change_frame_size (f, width, height, 0);
      CLEAR_FRAME_SIZE_SLIPPED (f);
    }
}

/* This is a "specifier changed in frame" handler for various specifiers
   changing which causes frame size adjustment.  See the discussion in
   adjust_frame_size().
 */

void
frame_size_slipped (Lisp_Object UNUSED (specifier), struct frame *f,
		    Lisp_Object UNUSED (oldval))
{
  MARK_FRAME_SIZE_SLIPPED (f);
}

void
invalidate_vertical_divider_cache_in_frame (struct frame *f)
{
  /* Invalidate cached value of needs_vertical_divider_p in
     every and all windows */
  map_windows (f, invalidate_vertical_divider_cache_in_window, 0);
}


/**************************************************************************/
/*                                                                        */
/*                       frame title, icon, pointer                       */
/*                                                                        */
/**************************************************************************/

/* The caller is responsible for freeing the returned string. */
static Ibyte *
generate_title_string (struct window *w, Lisp_Object format_str,
		       face_index findex, int type)
{
  struct display_line *dl;
  struct display_block *db;
  int elt = 0;

  dl = &title_string_display_line;
  db = get_display_block_from_line (dl, TEXT);
  Dynarr_reset (db->runes);

  generate_formatted_string_db (format_str, Qnil, w, dl, db, findex, 0,
				-1, type);

  Dynarr_reset (title_string_ichar_dynarr);
  while (elt < Dynarr_length (db->runes))
    {
      if (Dynarr_atp (db->runes, elt)->type == RUNE_CHAR)
	Dynarr_add (title_string_ichar_dynarr,
		    Dynarr_atp (db->runes, elt)->object.chr.ch);
      elt++;
    }

  return
    convert_ichar_string_into_malloced_string
    (Dynarr_begin (title_string_ichar_dynarr),
     Dynarr_length (title_string_ichar_dynarr), 0);
}

void
update_frame_title (struct frame *f)
{
  struct window *w = XWINDOW (FRAME_SELECTED_WINDOW (f));
  Lisp_Object title_format;
  Lisp_Object icon_format;
  Ibyte *title;

  /* We don't change the title for the minibuffer unless the frame
     only has a minibuffer. */
  if (MINI_WINDOW_P (w) && !FRAME_MINIBUF_ONLY_P (f))
    return;

  /* And we don't want dead buffers to blow up on us. */
  if (!BUFFER_LIVE_P (XBUFFER (w->buffer)))
    return;

  title = NULL;
  title_format = symbol_value_in_buffer (Qframe_title_format,      w->buffer);
  icon_format  = symbol_value_in_buffer (Qframe_icon_title_format, w->buffer);

  if (HAS_FRAMEMETH_P (f, set_title_from_ibyte))
    {
      title = generate_title_string (w, title_format,
				     DEFAULT_INDEX, CURRENT_DISP);
      FRAMEMETH (f, set_title_from_ibyte, (f, title));
    }

  if (HAS_FRAMEMETH_P (f, set_icon_name_from_ibyte))
    {
      if (!EQ (icon_format, title_format) || !title)
	{
	  if (title)
	    xfree (title);

	  title = generate_title_string (w, icon_format,
					 DEFAULT_INDEX, CURRENT_DISP);
	}
      FRAMEMETH (f, set_icon_name_from_ibyte, (f, title));
    }

  if (title)
    xfree (title);
}


DEFUN ("set-frame-pointer", Fset_frame_pointer, 2, 2, 0, /*
Set the mouse pointer of FRAME to the given pointer image instance.
You should not call this function directly.  Instead, set one of
the variables `text-pointer-glyph', `nontext-pointer-glyph',
`modeline-pointer-glyph', `selection-pointer-glyph',
`busy-pointer-glyph', or `toolbar-pointer-glyph'.
*/
       (frame, image_instance))
{
  struct frame *f = decode_frame (frame);
  CHECK_POINTER_IMAGE_INSTANCE (image_instance);
  if (!EQ (f->pointer, image_instance))
    {
      f->pointer = image_instance;
      MAYBE_FRAMEMETH (f, set_frame_pointer, (f));
    }
  return Qnil;
}


void
update_frame_icon (struct frame *f)
{
  if (f->icon_changed || f->windows_changed)
    {
      Lisp_Object frame;
      Lisp_Object new_icon;

      frame = wrap_frame (f);
      new_icon = glyph_image_instance (Vframe_icon_glyph, frame,
				       ERROR_ME_WARN, 0);
      if (!EQ (new_icon, f->icon))
	{
	  f->icon = new_icon;
	  MAYBE_FRAMEMETH (f, set_frame_icon, (f));
	}
    }

  f->icon_changed = 0;
}

static void
icon_glyph_changed (Lisp_Object UNUSED (glyph), Lisp_Object UNUSED (property),
		    Lisp_Object UNUSED (locale))
{
  MARK_ICON_CHANGED;
}


#ifdef MEMORY_USAGE_STATS

struct frame_stats
{
  struct usage_stats u;
  Bytecount gutter;
  Bytecount expose_ignore;
  Bytecount other;
};

static void
compute_frame_usage (struct frame *f, struct frame_stats *stats,
		     struct usage_stats *ustats)
{
  enum edge_pos edge;
  EDGE_POS_LOOP (edge)
    {
      stats->gutter +=
	compute_display_line_dynarr_usage (f->current_display_lines[edge],
					   ustats);
      stats->gutter +=
	compute_display_line_dynarr_usage (f->desired_display_lines[edge],
					   ustats);
    }
  {
    struct expose_ignore *e;

    for (e = f->subwindow_exposures; e; e = e->next)
      stats->expose_ignore += malloced_storage_size (e, sizeof (*e), ustats);
  }

#if 0
  stats->other += FRAMEMETH (f, frame_memory_usage, (f, ustats));
#endif
}

static void
frame_memory_usage (Lisp_Object frame, struct generic_usage_stats *gustats)
{
  struct frame_stats *stats = (struct frame_stats *) gustats;

  compute_frame_usage (XFRAME (frame), stats, &stats->u);
}

#endif /* MEMORY_USAGE_STATS */


/***************************************************************************/
/*									   */
/*                              initialization                             */
/*									   */
/***************************************************************************/

void
frame_objects_create (void)
{
#ifdef MEMORY_USAGE_STATS
  OBJECT_HAS_METHOD (frame, memory_usage);
#endif
}

void
init_frame (void)
{
#ifndef PDUMP
  if (!initialized)
#endif
    {
      title_string_ichar_dynarr = Dynarr_new (Ichar);
      DISPLAY_LINE_INIT (title_string_display_line);
    }
}

void
syms_of_frame (void)
{
  INIT_LISP_OBJECT (frame);
#ifdef NEW_GC
  INIT_LISP_OBJECT (expose_ignore);
#endif /* NEW_GC */

  DEFSYMBOL (Qdelete_frame_hook);
  DEFSYMBOL (Qselect_frame_hook);
  DEFSYMBOL (Qdeselect_frame_hook);
  DEFSYMBOL (Qcreate_frame_hook);
  DEFSYMBOL (Qcustom_initialize_frame);
  DEFSYMBOL (Qmouse_enter_frame_hook);
  DEFSYMBOL (Qmouse_leave_frame_hook);
  DEFSYMBOL (Qmap_frame_hook);
  DEFSYMBOL (Qunmap_frame_hook);

  DEFSYMBOL (Qframep);
  DEFSYMBOL (Qframe_live_p);
  DEFSYMBOL (Qdelete_frame);
  DEFSYMBOL (Qsynchronize_minibuffers);
  DEFSYMBOL (Qbuffer_predicate);
  DEFSYMBOL (Qframe_being_created);
  DEFSYMBOL (Qmake_initial_minibuffer_frame);

  DEFSYMBOL (Qframe_title_format);
  DEFSYMBOL (Qframe_icon_title_format);

  DEFSYMBOL (Qhidden);
  DEFSYMBOL (Qvisible);
  DEFSYMBOL (Qiconic);
  DEFSYMBOL (Qinvisible);
  DEFSYMBOL (Qvisible_iconic);
  DEFSYMBOL (Qinvisible_iconic);
  DEFSYMBOL (Qnomini);
  DEFSYMBOL (Qvisible_nomini);
  DEFSYMBOL (Qiconic_nomini);
  DEFSYMBOL (Qinvisible_nomini);
  DEFSYMBOL (Qvisible_iconic_nomini);
  DEFSYMBOL (Qinvisible_iconic_nomini);

  DEFSYMBOL (Qminibuffer);
  DEFSYMBOL (Qunsplittable);
  DEFSYMBOL (Qinternal_border_width);
  DEFSYMBOL (Qtop_toolbar_shadow_color);
  DEFSYMBOL (Qbottom_toolbar_shadow_color);
  DEFSYMBOL (Qbackground_toolbar_color);
  DEFSYMBOL (Qtop_toolbar_shadow_pixmap);
  DEFSYMBOL (Qbottom_toolbar_shadow_pixmap);
  DEFSYMBOL (Qtoolbar_shadow_thickness);
  DEFSYMBOL (Qscrollbar_placement);
  DEFSYMBOL (Qinter_line_space);
  /* Qiconic already in this function. */
  DEFSYMBOL (Qvisual_bell);
  DEFSYMBOL (Qbell_volume);
  DEFSYMBOL (Qpointer_background);
  DEFSYMBOL (Qpointer_color);
  DEFSYMBOL (Qtext_pointer);
  DEFSYMBOL (Qspace_pointer);
  DEFSYMBOL (Qmodeline_pointer);
  DEFSYMBOL (Qgc_pointer);
  DEFSYMBOL (Qinitially_unmapped);
  DEFSYMBOL (Quse_backing_store);
  DEFSYMBOL (Qborder_color);
  DEFSYMBOL (Qborder_width);
  /* Qwidth, Qheight, Qleft, Qtop in general.c */
  DEFSYMBOL (Qset_specifier);
  DEFSYMBOL (Qset_face_property);
  DEFSYMBOL (Qface_property_instance);
  DEFSYMBOL (Qframe_property_alias);

  DEFSUBR (Fmake_frame);
  DEFSUBR (Fframep);
  DEFSUBR (Fframe_live_p);
#if 0 /* FSFmacs */
  DEFSUBR (Fignore_event);
#endif
  DEFSUBR (Ffocus_frame);
  DEFSUBR (Fselect_frame);
  DEFSUBR (Fselected_frame);
  DEFSUBR (Factive_minibuffer_window);
  DEFSUBR (Flast_nonminibuf_frame);
  DEFSUBR (Fframe_root_window);
  DEFSUBR (Fframe_selected_window);
  DEFSUBR (Fset_frame_selected_window);
  DEFSUBR (Fframe_device);
  DEFSUBR (Fnext_frame);
  DEFSUBR (Fprevious_frame);
  DEFSUBR (Fdelete_frame);
  DEFSUBR (Fmouse_position);
  DEFSUBR (Fmouse_pixel_position);
  DEFSUBR (Fmouse_position_as_motion_event);
  DEFSUBR (Fset_mouse_position);
  DEFSUBR (Fset_mouse_pixel_position);
  DEFSUBR (Fmake_frame_visible);
  DEFSUBR (Fmake_frame_invisible);
  DEFSUBR (Ficonify_frame);
  DEFSUBR (Fdeiconify_frame);
  DEFSUBR (Fframe_visible_p);
  DEFSUBR (Fframe_totally_visible_p);
  DEFSUBR (Fframe_iconified_p);
  DEFSUBR (Fvisible_frame_list);
  DEFSUBR (Fraise_frame);
  DEFSUBR (Flower_frame);
  DEFSUBR (Fdisable_frame);
  DEFSUBR (Fenable_frame);
  DEFSUBR (Fframe_property);
  DEFSUBR (Fframe_properties);
  DEFSUBR (Fset_frame_properties);
  DEFSUBR (Fframe_pixel_height);
  DEFSUBR (Fframe_displayable_pixel_height);
  DEFSUBR (Fframe_pixel_width);
  DEFSUBR (Fframe_displayable_pixel_width);
  DEFSUBR (Fframe_name);
  DEFSUBR (Fframe_modified_tick);
  DEFSUBR (Fset_frame_height);
  DEFSUBR (Fset_frame_width);
  DEFSUBR (Fset_frame_size);
  DEFSUBR (Fset_frame_pixel_height);
  DEFSUBR (Fset_frame_displayable_pixel_height);
  DEFSUBR (Fset_frame_pixel_width);
  DEFSUBR (Fset_frame_displayable_pixel_width);
  DEFSUBR (Fset_frame_pixel_size);
  DEFSUBR (Fset_frame_displayable_pixel_size);
  DEFSUBR (Fset_frame_position);
  DEFSUBR (Fset_frame_pointer);
  DEFSUBR (Fprint_job_page_number);
  DEFSUBR (Fprint_job_eject_page);
}

void
vars_of_frame (void)
{
#ifdef MEMORY_USAGE_STATS
  OBJECT_HAS_PROPERTY
    (frame, memusage_stats_list, list3 (Qgutter, intern ("expose-ignore"),
					Qother));
#endif /* MEMORY_USAGE_STATS */

  /* */
  Vframe_being_created = Qnil;
  staticpro (&Vframe_being_created);

#ifdef HAVE_CDE
  Fprovide (intern ("cde"));
#endif

#if 0 /* FSFmacs stupidity */
  xxDEFVAR_LISP ("emacs-iconified", &Vemacs_iconified /*
Non-nil if all of emacs is iconified and frame updates are not needed.
*/ );
  Vemacs_iconified = Qnil;
#endif

  DEFVAR_LISP ("select-frame-hook", &Vselect_frame_hook /*
Function or functions to run just after a new frame is given the focus.
Note that calling `select-frame' does not necessarily set the focus:
The actual window-system focus will not be changed until the next time
that XEmacs is waiting for an event, and even then, the window manager
may refuse the focus-change request.
*/ );
  Vselect_frame_hook = Qnil;

  DEFVAR_LISP ("deselect-frame-hook", &Vdeselect_frame_hook /*
Function or functions to run just before a frame loses the focus.
See `select-frame-hook'.
*/ );
  Vdeselect_frame_hook = Qnil;

  DEFVAR_LISP ("delete-frame-hook", &Vdelete_frame_hook /*
Function or functions to call when a frame is deleted.
One argument, the about-to-be-deleted frame.
*/ );
  Vdelete_frame_hook = Qnil;

  DEFVAR_LISP ("create-frame-hook", &Vcreate_frame_hook /*
Function or functions to call when a frame is created.
One argument, the newly-created frame.
*/ );
  Vcreate_frame_hook = Qnil;

  DEFVAR_LISP ("mouse-enter-frame-hook", &Vmouse_enter_frame_hook /*
Function or functions to call when the mouse enters a frame.
One argument, the frame.
Be careful not to make assumptions about the window manager's focus model.
In most cases, the `deselect-frame-hook' is more appropriate.
*/ );
  Vmouse_enter_frame_hook = Qnil;

  DEFVAR_LISP ("mouse-leave-frame-hook", &Vmouse_leave_frame_hook /*
Function or functions to call when the mouse leaves a frame.
One argument, the frame.
Be careful not to make assumptions about the window manager's focus model.
In most cases, the `select-frame-hook' is more appropriate.
*/ );
  Vmouse_leave_frame_hook = Qnil;

  DEFVAR_LISP ("map-frame-hook", &Vmap_frame_hook /*
Function or functions to call when a frame is mapped.
One argument, the frame.
*/ );
  Vmap_frame_hook = Qnil;

  DEFVAR_LISP ("unmap-frame-hook", &Vunmap_frame_hook /*
Function or functions to call when a frame is unmapped.
One argument, the frame.
*/ );
  Vunmap_frame_hook = Qnil;

  DEFVAR_BOOL ("allow-deletion-of-last-visible-frame",
	       &allow_deletion_of_last_visible_frame /*
*Non-nil means to assume the force option to delete-frame.
*/ );
  allow_deletion_of_last_visible_frame = 0;

  DEFVAR_LISP ("adjust-frame-function", &Vadjust_frame_function /*
Function or constant controlling adjustment of frame.
When scrollbars, toolbars, default font etc. change in frame, the frame
needs to be adjusted. The adjustment is controlled by this variable.
Legal values are:
  nil to keep character frame size unchanged when possible (resize)
  t   to keep pixel size unchanged (never resize)
  function symbol or lambda form. This function must return boolean
      value which is treated as above. Function is passed one parameter,
      the frame being adjusted. It function should not modify or delete
      the frame.
*/ );
  Vadjust_frame_function = Qnil;

  DEFVAR_LISP ("mouse-motion-handler", &Vmouse_motion_handler /*
Handler for motion events.  Must be a function taking one argument, the event.
For most applications, you should use `mode-motion-hook' instead of this.
The default value is `default-mouse-motion-handler'.

Note that this is NOT a hook variable, so there is no standard way to remove
actions from it.  Instead, when adding a new kind of action, a hook variable
should be defined and initialized to the current value of this variable, then
this variable set to a function that runs the new hook.  To disable the new
actions, use `remove-hook' rather than setting `mouse-motion-handler'.

`mouse-motion-hook' in the balloon-help library exemplifies this pattern.
*/ );
  Vmouse_motion_handler = Qnil;

  DEFVAR_LISP ("synchronize-minibuffers",&Vsynchronize_minibuffers /*
Set to t if all minibuffer windows are to be synchronized.
This will cause echo area messages to appear in the minibuffers of all
visible frames.
*/ );
  Vsynchronize_minibuffers = Qnil;

  DEFVAR_LISP ("frame-title-format", &Vframe_title_format /*
Controls the title of the window-system window of the selected frame.
This is the same format as `modeline-format' with the exception that
%- is ignored.
*/ );
/* #### I would change this unilaterally but for the wrath of the Kyles
of the world. */
#ifdef WIN32_NATIVE
  Vframe_title_format = build_ascstring ("%b - XEmacs");
#else
  Vframe_title_format = build_ascstring ("%S: %b");
#endif

  DEFVAR_LISP ("frame-icon-title-format", &Vframe_icon_title_format /*
Controls the title of the icon corresponding to the selected frame.
See also the variable `frame-title-format'.
*/ );
  Vframe_icon_title_format = build_ascstring ("%b");

  DEFVAR_LISP ("default-frame-name", &Vdefault_frame_name /*
The default name to assign to newly-created frames.
This can be overridden by arguments to `make-frame'.  This must be a string.
This is used primarily for picking up X resources, and is *not* the title
of the frame. (See `frame-title-format'.)

Previous to 21.5.21, this defaulted to `emacs'; since that release, it has
defaulted to `XEmacs'. In the short term you can restore the old default by
setting the environment variable USE_EMACS_AS_DEFAULT_APPLICATION_CLASS
(which does affect the frame name, despite what it's called) to some value
before starting XEmacs, but this is deprecated.
*/ );
  Vdefault_frame_name = Qnil;

  DEFVAR_LISP ("default-frame-plist", &Vdefault_frame_plist /*
Plist of default values for frame creation, other than the first one.
These may be set in your init file, like this:

  \(setq default-frame-plist '(width 80 height 55))

Predefined properties are described in `set-frame-properties'.

The properties may be in alist format for backward compatibility
but you should not rely on this behavior.

These override values given in window system configuration data,
including X Windows' defaults database.

Values for the first Emacs frame are taken from `initial-frame-plist'.
Since the first X frame is created before loading your .emacs file, you
may wish use the X resource database to avoid flashing.

For values specific to the separate minibuffer frame, see
`minibuffer-frame-plist'.  See also the variables `default-x-frame-plist'
and `default-tty-frame-plist', which are like `default-frame-plist'
except that they apply only to X or tty frames, respectively \(whereas
`default-frame-plist' applies to all types of frames).
*/ );
  Vdefault_frame_plist = Qnil;

  DEFVAR_LISP ("frame-icon-glyph", &Vframe_icon_glyph /*
Icon glyph used to iconify a frame.
*/ );
}

void
complex_vars_of_frame (void)
{
  Vframe_icon_glyph = allocate_glyph (GLYPH_ICON, icon_glyph_changed);
}
