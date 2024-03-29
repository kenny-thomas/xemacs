/* Define console object for XEmacs.
   Copyright (C) 1996, 2002, 2003, 2005, 2010 Ben Wing

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

/* Written by Ben Wing. */

#ifndef INCLUDED_console_impl_h_
#define INCLUDED_console_impl_h_

#include "console.h"
#include "specifier.h"

extern const struct sized_memory_description cted_description;
extern const struct sized_memory_description console_methods_description;


/*
 * Constants returned by device_implementation_flags_method
 */

/* Set when device uses pixel-based geometry */
#define XDEVIMPF_PIXEL_GEOMETRY		0x00000001L

/* Indicates that the device is a printer */
#define XDEVIMPF_IS_A_PRINTER		0x00000002L

/* Do not automatically redisplay this device */
#define XDEVIMPF_NO_AUTO_REDISPLAY	0x00000004L

/* Do not delete the device when last frame's gone */
#define XDEVIMPF_FRAMELESS_OK		0x00000008L

/* Do not preempt resiaply of frame or device once it starts */
#define XDEVIMPF_DONT_PREEMPT_REDISPLAY 0x00000010L

struct console_methods
{
  const char *name;	/* Used by print_console, print_device, print_frame */
  Lisp_Object symbol;
  Lisp_Object predicate_symbol;
  unsigned int flags;	/* Read-only implementation flags, set once upon
			   console type creation. INITIALIZE_CONSOLE_TYPE sets
			   this member to 0. */

  /* console methods */
  void (*init_console_method) (struct console *, Lisp_Object props);
  void (*mark_console_method) (struct console *);
  int (*initially_selected_for_input_method) (struct console *);
  void (*delete_console_method) (struct console *);
  Lisp_Object (*semi_canonicalize_console_connection_method)
    (Lisp_Object connection, Error_Behavior errb);
  Lisp_Object (*semi_canonicalize_device_connection_method)
    (Lisp_Object connection, Error_Behavior errb);
  Lisp_Object (*canonicalize_console_connection_method)
    (Lisp_Object connection, Error_Behavior errb);
  Lisp_Object (*canonicalize_device_connection_method)
    (Lisp_Object connection, Error_Behavior errb);
  Lisp_Object (*device_to_console_connection_method)
    (Lisp_Object connection, Error_Behavior errb);
  Lisp_Object (*perhaps_init_unseen_key_defaults_method)
    (struct console *, Lisp_Object keysym);

  /* device methods */
  void (*init_device_method) (struct device *, Lisp_Object props);
  void (*finish_init_device_method) (struct device *, Lisp_Object props);
  void (*delete_device_method) (struct device *);
  void (*mark_device_method) (struct device *);
  void (*asynch_device_change_method) (void);
  Lisp_Object (*device_system_metrics_method) (struct device *,
                                               enum device_metrics);
  Lisp_Object (*own_selection_method)(Lisp_Object selection_name,
                                      Lisp_Object selection_value,
                                      Lisp_Object how_to_add,
                                      Lisp_Object selection_type,
			  int owned_p);
  void (*disown_selection_method)(Lisp_Object selection_name,
                                  Lisp_Object timeval);
  Lisp_Object (*get_foreign_selection_method) (Lisp_Object selection_symbol,
                                               Lisp_Object target_type);
  Lisp_Object (*selection_exists_p_method)(Lisp_Object selection_name,
                                           Lisp_Object selection_type);
  Lisp_Object (*available_selection_types_method)(Lisp_Object selection_name);
  Lisp_Object (*register_selection_data_type_method)(Lisp_Object type_name);
  Lisp_Object (*selection_data_type_name_method)(Lisp_Object type);

  /* frame methods */
  Lisp_Object *device_specific_frame_props;
  void (*init_frame_1_method) (struct frame *, Lisp_Object properties,
			       int frame_name_is_defaulted);
  void (*init_frame_2_method) (struct frame *, Lisp_Object properties);
  void (*init_frame_3_method) (struct frame *);
  void (*after_init_frame_method) (struct frame *, int first_on_device,
				   int first_on_console);
  void (*mark_frame_method) (struct frame *);
  void (*delete_frame_method) (struct frame *);
  void (*focus_on_frame_method) (struct frame *);
  void (*raise_frame_method) (struct frame *);
  void (*lower_frame_method) (struct frame *);
  void (*enable_frame_method) (struct frame *);
  void (*disable_frame_method) (struct frame *);
  int (*get_mouse_position_method) (struct device *d, Lisp_Object *frame,
				    int *x, int *y);
  void (*set_mouse_position_method) (struct window *w, int x, int y);
  void (*make_frame_visible_method) (struct frame *f);
  void (*make_frame_invisible_method) (struct frame *f);
  void (*iconify_frame_method) (struct frame *f);
  Lisp_Object (*frame_property_method) (struct frame *f, Lisp_Object prop);
  int (*internal_frame_property_p_method) (struct frame *f,
					   Lisp_Object prop);
  Lisp_Object (*frame_properties_method) (struct frame *f);
  void (*set_frame_properties_method) (struct frame *f, Lisp_Object plist);
  void (*set_frame_size_method) (struct frame *f, int width, int height);
  void (*set_frame_position_method) (struct frame *f, int xoff, int yoff);
  int (*frame_visible_p_method) (struct frame *f);
  int (*frame_totally_visible_p_method) (struct frame *f);
  int (*frame_iconified_p_method) (struct frame *f);
  void (*set_title_from_ibyte_method) (struct frame *f, Ibyte *title);
  void (*set_icon_name_from_ibyte_method) (struct frame *f, Ibyte *title);
  void (*set_frame_pointer_method) (struct frame *f);
  void (*set_frame_icon_method) (struct frame *f);
  void (*popup_menu_method) (Lisp_Object menu, Lisp_Object event);
  Lisp_Object (*get_frame_parent_method) (struct frame *f);
  void (*update_frame_external_traits_method) (struct frame *f, Lisp_Object name);
  int (*frame_size_fixed_p_method) (struct frame *f);
  void (*eject_page_method) (struct frame *f);

  /* redisplay methods */
  int (*left_margin_width_method) (struct window *);
  int (*right_margin_width_method) (struct window *);
  int (*text_width_method) (struct frame *f, struct face_cachel *cachel,
			    const Ichar *str, Charcount len);
  void (*output_display_block_method) (struct window *, struct display_line *,
				       int, int, int, int, int, int, int);
  int (*divider_height_method) (void);
  int (*eol_cursor_width_method) (void);
  void (*output_vertical_divider_method) (struct window *, int);
  void (*clear_to_window_end_method) (struct window *, int, int);
  void (*clear_region_method) (Lisp_Object, struct frame*,
			       face_index, int, int, int, int,
			       Lisp_Object, Lisp_Object,
			       Lisp_Object, Lisp_Object);
  void (*clear_frame_method) (struct frame *);
  void (*window_output_begin_method) (struct window *);
  void (*frame_output_begin_method) (struct frame *);
  void (*window_output_end_method) (struct window *);
  void (*frame_output_end_method) (struct frame *);
  int (*flash_method) (struct device *);
  void (*ring_bell_method) (struct device *, int volume, int pitch,
			    int duration);
  void (*frame_redraw_cursor_method) (struct frame *f);
  void (*set_final_cursor_coords_method) (struct frame *, int, int);
  void (*bevel_area_method) (struct window *, face_index, int, int, int, int, int,
			     int, enum edge_style);
  void (*output_pixmap_method) (struct window *w, Lisp_Object image_instance,
				struct display_box *db, struct display_glyph_area *dga,
				face_index findex, int cursor_start, int cursor_width,
				int cursor_height, int offset_bitmap);
  void (*output_string_method) (struct window *w, struct display_line *dl,
				Ichar_dynarr *buf, int xpos, int xoffset,
				int start_pixpos, int width, face_index findex,
				int cursor, int cursor_start, int cursor_width,
				int cursor_height);

  /* color methods */
  int (*initialize_color_instance_method) (Lisp_Color_Instance *,
					   Lisp_Object name,
					   Lisp_Object device,
					   Error_Behavior errb);
  void (*mark_color_instance_method) (Lisp_Color_Instance *);
  void (*print_color_instance_method) (Lisp_Color_Instance *,
				       Lisp_Object printcharfun,
				       int escapeflag);
  void (*finalize_color_instance_method) (Lisp_Color_Instance *);
  int (*color_instance_equal_method) (Lisp_Color_Instance *,
				      Lisp_Color_Instance *,
				      int depth);
  Hashcode (*color_instance_hash_method) (Lisp_Color_Instance *,
                                          int depth);
  Lisp_Object (*color_instance_rgb_components_method) (Lisp_Color_Instance *);
  int (*valid_color_name_p_method) (struct device *, Lisp_Object color);
  Lisp_Object (*color_list_method) (void);

  /* font methods */
  int (*initialize_font_instance_method) (Lisp_Font_Instance *,
					  Lisp_Object name,
					  Lisp_Object device,
					  Error_Behavior errb);
  void (*mark_font_instance_method) (Lisp_Font_Instance *);
  void (*print_font_instance_method) (Lisp_Font_Instance *,
				      Lisp_Object printcharfun,
				      int escapeflag);
  void (*finalize_font_instance_method) (Lisp_Font_Instance *);
  Lisp_Object (*font_instance_truename_method) (Lisp_Font_Instance *,
						Error_Behavior errb);
  Lisp_Object (*font_instance_properties_method) (Lisp_Font_Instance *);
  Lisp_Object (*font_list_method) (Lisp_Object pattern,
				    Lisp_Object device,
				    Lisp_Object maxnumber);
  Lisp_Object (*find_charset_font_method) 
    (Lisp_Object device, Lisp_Object font, Lisp_Object charset,
     enum font_specifier_matchspec_stages stage); 
  int (*font_spec_matches_charset_method)
    (struct device *d, Lisp_Object charset, const Ibyte *nonreloc,
     Lisp_Object reloc, Bytecount offset, Bytecount length,
     enum font_specifier_matchspec_stages stage);

  /* image methods */
  void (*mark_image_instance_method) (Lisp_Image_Instance *);
  void (*print_image_instance_method) (Lisp_Image_Instance *,
				       Lisp_Object printcharfun,
				       int escapeflag);
  void (*finalize_image_instance_method) (Lisp_Image_Instance *);
  void (*unmap_subwindow_method) (Lisp_Image_Instance *);
  void (*map_subwindow_method) (Lisp_Image_Instance *, int x, int y,
				struct display_glyph_area* dga);
  void (*resize_subwindow_method) (Lisp_Image_Instance *, int w, int h);
  void (*redisplay_subwindow_method) (Lisp_Image_Instance *);
  void (*redisplay_widget_method) (Lisp_Image_Instance *);
  /* Maybe this should be a specifier. Unfortunately specifiers don't
     allow us to represent things at the toolkit level, which is what
     is required here. */
  int (*widget_border_width_method) (void);
  int (*widget_spacing_method) (Lisp_Image_Instance *);
  int (*image_instance_equal_method) (Lisp_Image_Instance *,
				      Lisp_Image_Instance *,
				      int depth);
  Hashcode (*image_instance_hash_method) (Lisp_Image_Instance *,
					   int depth);
  void (*init_image_instance_from_eimage_method) (Lisp_Image_Instance *ii,
						  int width, int height,
						  int slices,
						  unsigned char *eimage,
						  int dest_mask,
						  Lisp_Object instantiator,
						  Lisp_Object pointer_fg,
						  Lisp_Object pointer_bg,
						  Lisp_Object domain);
  Lisp_Object (*locate_pixmap_file_method) (Lisp_Object file_method);
  int (*colorize_image_instance_method) (Lisp_Object image_instance,
					 Lisp_Object fg, Lisp_Object bg);
  void (*widget_query_string_geometry_method) (Lisp_Object string, 
					       Lisp_Object face,
					       int* width, int* height, 
					       Lisp_Object domain);
  Lisp_Object image_conversion_list;

#ifdef HAVE_TOOLBARS
  /* toolbar methods */
  void (*output_frame_toolbars_method) (struct frame *);
  void (*clear_frame_toolbars_method) (struct frame *);
  void (*initialize_frame_toolbars_method) (struct frame *);
  void (*free_frame_toolbars_method) (struct frame *);
  void (*output_toolbar_button_method) (struct frame *, Lisp_Object);
  void (*redraw_frame_toolbars_method) (struct frame *);
  void (*redraw_exposed_toolbars_method) (struct frame *f, int x, int y,
					  int width, int height);
#endif

#ifdef HAVE_SCROLLBARS
  /* scrollbar methods */
  int (*inhibit_scrollbar_slider_size_change_method) (void);
  void (*free_scrollbar_instance_method) (struct scrollbar_instance *);
  void (*release_scrollbar_instance_method) (struct scrollbar_instance *);
  void (*create_scrollbar_instance_method) (struct frame *, int,
					    struct scrollbar_instance *);
  void (*update_scrollbar_instance_values_method) (struct window *,
						   struct scrollbar_instance *,
						   int, int, int, int, int,
						   int, int, int, int, int);
  void (*update_scrollbar_instance_status_method) (struct window *, int, int,
						   struct
						   scrollbar_instance *);
  void (*scrollbar_pointer_changed_in_window_method) (struct window *w);
#ifdef MEMORY_USAGE_STATS
  Bytecount (*compute_scrollbar_instance_usage_method)
    (struct device *,
     struct scrollbar_instance *,
     struct usage_stats *);
#endif
  /* Paint the window's deadbox, a rectangle between window
     borders and two short edges of both scrollbars. */
  void (*redisplay_deadbox_method) (struct window *w, int x, int y, int width,
				    int height);
#endif /* HAVE_SCROLLBARS */

#ifdef HAVE_MENUBARS
  /* menubar methods */
  void (*update_frame_menubars_method) (struct frame *);
  void (*free_frame_menubars_method) (struct frame *);
#endif

#ifdef HAVE_DIALOGS
  /* dialog methods */
  Lisp_Object (*make_dialog_box_internal_method) (struct frame *,
						  Lisp_Object type,
						  Lisp_Object keys);
#endif
};

#define CONMETH_TYPE(meths) ((meths)->symbol)
#define CONMETH_IMPL_FLAG(meths, f) ((meths)->flags & (f))

#define CONSOLE_TYPE_NAME(c) ((c)->conmeths->name)
#define CONSOLE_TYPE(c) ((c)->conmeths->symbol)
#define CONSOLE_IMPL_FLAG(c, f) CONMETH_IMPL_FLAG ((c)->conmeths, (f))

/******** Accessing / calling a console method *********/

#define HAS_CONTYPE_METH_P(meth, m) ((meth)->m##_method)
#define CONTYPE_METH(meth, m, args) (((meth)->m##_method) args)

/* Call a void-returning console method, if it exists */
#define MAYBE_CONTYPE_METH(meth, m, args) do {			\
  struct console_methods *maybe_contype_meth_meth = (meth);	\
  if (HAS_CONTYPE_METH_P (maybe_contype_meth_meth, m))		\
    CONTYPE_METH (maybe_contype_meth_meth, m, args);		\
} while (0)

/* Call a console method, if it exists; otherwise return
   the specified value - meth is multiply evaluated.  */
#define CONTYPE_METH_OR_GIVEN(meth, m, args, given)	\
  (HAS_CONTYPE_METH_P (meth, m) ?			\
   CONTYPE_METH (meth, m, args) : (given))

/* Call an int-returning console method, if it exists; otherwise
   return 0 */
#define MAYBE_INT_CONTYPE_METH(meth, m, args) \
  CONTYPE_METH_OR_GIVEN (meth, m, args, 0)

/* Call an Lisp-Object-returning console method, if it exists;
   otherwise return Qnil */
#define MAYBE_LISP_CONTYPE_METH(meth, m, args) \
  CONTYPE_METH_OR_GIVEN (meth, m, args, Qnil)

/******** Same functions, operating on a console instead of a
          struct console_methods ********/

#define HAS_CONMETH_P(c, m) HAS_CONTYPE_METH_P ((c)->conmeths, m)
#define CONMETH(c, m, args) CONTYPE_METH ((c)->conmeths, m, args)
#define MAYBE_CONMETH(c, m, args) MAYBE_CONTYPE_METH ((c)->conmeths, m, args)
#define CONMETH_OR_GIVEN(c, m, args, given) \
  CONTYPE_METH_OR_GIVEN((c)->conmeths, m, args, given)
#define MAYBE_INT_CONMETH(c, m, args) \
  MAYBE_INT_CONTYPE_METH ((c)->conmeths, m, args)
#define MAYBE_LISP_CONMETH(c, m, args) \
  MAYBE_LISP_CONTYPE_METH ((c)->conmeths, m, args)

/******** Defining new console types ********/

typedef struct console_type_entry console_type_entry;
struct console_type_entry
{
  Lisp_Object symbol;
  struct console_methods *meths;
};

#define DECLARE_CONSOLE_TYPE(type) \
extern struct console_methods * type##_console_methods

#define DEFINE_CONSOLE_TYPE(type) \
struct console_methods * type##_console_methods

#define INITIALIZE_CONSOLE_TYPE(type, obj_name, pred_sym) do {		\
    type##_console_methods = xnew_and_zero (struct console_methods);	\
    type##_console_methods->name = obj_name;				\
    type##_console_methods->symbol = Q##type;				\
    defsymbol_nodump (&type##_console_methods->predicate_symbol, pred_sym);	\
    add_entry_to_console_type_list (Q##type, type##_console_methods);	\
    type##_console_methods->image_conversion_list = Qnil;		\
    staticpro_nodump (&type##_console_methods->image_conversion_list);	\
    dump_add_root_block_ptr (&type##_console_methods, &console_methods_description);	\
} while (0)

#define REINITIALIZE_CONSOLE_TYPE(type) do {	\
    staticpro_nodump (&type##_console_methods->predicate_symbol);	\
    staticpro_nodump (&type##_console_methods->image_conversion_list);	\
} while (0)


/* Declare that console-type TYPE has method M; used in
   initialization routines */
#define CONSOLE_HAS_METHOD(type, m) \
  (type##_console_methods->m##_method = type##_##m)

/* Declare that console-type TYPE inherits method M
   implementation from console-type FROMTYPE */
#define CONSOLE_INHERITS_METHOD(type, fromtype, m) \
  (type##_console_methods->m##_method = fromtype##_##m)

/* Define console type implementation flags */
#define CONSOLE_IMPLEMENTATION_FLAGS(type, flg) \
  (type##_console_methods->flags = flg)

struct console
{
  NORMAL_LISP_OBJECT_HEADER header;

  /* Description of this console's methods.  */
  struct console_methods *conmeths;

  /* Enumerated constant listing which type of console this is (TTY, X,
     MS-Windows, etc.).  This duplicates the symbol in conmeths->symbol,
     which formerly was the only way to determine the console type.
     We need this constant now for KKCC, so that it can be used in
     an XD_UNION clause to determine the Lisp objects in console_data. */
  enum console_variant contype;

  /* A structure of auxiliary data specific to the console type.
     struct x_console is used for X window frames; defined in console-x.h
     struct tty_console is used to TTY's; defined in console-tty.h */
  void *console_data;

  /* ----- begin partially-completed console localization of
           event loop ---- */

  int local_var_flags;

#define MARKED_SLOT(x) Lisp_Object x;
#include "conslots.h"

  /* Where to store the next keystroke of the macro.
     Index into con->kbd_macro_builder. */
  int kbd_macro_ptr;

  /* The finalized section of the macro starts at kbd_macro_buffer and
     ends before this.  This is not the same as kbd_macro_pointer, because
     we advance this to kbd_macro_pointer when a key's command is complete.
     This way, the keystrokes for "end-kbd-macro" are not included in the
     macro.  */
  int kbd_macro_end;

  /* ----- end partially-completed console localization of event loop ---- */

  unsigned int input_enabled :1;
};

/* Redefine basic properties more efficiently */

#undef CONSOLE_LIVE_P
/* The following is the old way, but it can lead to crashes in certain
   weird circumstances, where you might want to be printing a console via
   debug_print() */
/* #define CONSOLE_LIVE_P(con) (!EQ (CONSOLE_TYPE (con), Qdead)) */
#define CONSOLE_LIVE_P(con) ((con)->contype != dead_console)
#undef CONSOLE_DEVICE_LIST
#define CONSOLE_DEVICE_LIST(con) ((con)->device_list)

#define CONSOLE_TYPE_P(con, type) EQ (CONSOLE_TYPE (con), Q##type)

#ifdef ERROR_CHECK_TYPES
DECLARE_INLINE_HEADER (
struct console *
error_check_console_type (struct console *con, Lisp_Object sym)
)
{
  assert (EQ (CONSOLE_TYPE (con), sym));
  return con;
}
# define CONSOLE_TYPE_DATA(con, type)			\
  (*(struct type##_console **)				\
   &(error_check_console_type (con, Q##type))->console_data)
#else
# define CONSOLE_TYPE_DATA(con, type)			\
  (*(struct type##_console **) &((con)->console_data))
#endif

#define CHECK_CONSOLE_TYPE(x, type) do {		\
  CHECK_CONSOLE (x);					\
  if (! CONSOLE_TYPE_P (XCONSOLE (x), type))		\
    dead_wrong_type_argument				\
      (type##_console_methods->predicate_symbol, x);	\
} while (0)
#define CONCHECK_CONSOLE_TYPE(x, type) do {		\
  CONCHECK_CONSOLE (x);					\
  if (!(CONSOLEP (x) &&					\
	CONSOLE_TYPE_P (XCONSOLE (x), type)))		\
    x = wrong_type_argument				\
      (type##_console_methods->predicate_symbol, x);	\
} while (0)

/* #### These should be in the console-*.h files but there are
   too many places where the abstraction is broken.  Need to
   fix. */

#ifdef HAVE_GTK
#define CONSOLE_TYPESYM_GTK_P(typesym) EQ (typesym, Qgtk)
#else
#define CONSOLE_TYPESYM_GTK_P(typesym) 0
#endif

#ifdef HAVE_X_WINDOWS
#define CONSOLE_TYPESYM_X_P(typesym) EQ (typesym, Qx)
#else
#define CONSOLE_TYPESYM_X_P(typesym) 0
#endif
#ifdef HAVE_TTY
#define CONSOLE_TYPESYM_TTY_P(typesym) EQ (typesym, Qtty)
#else
#define CONSOLE_TYPESYM_TTY_P(typesym) 0
#endif
#ifdef HAVE_MS_WINDOWS
#define CONSOLE_TYPESYM_MSWINDOWS_P(typesym) EQ (typesym, Qmswindows)
#else
#define CONSOLE_TYPESYM_MSWINDOWS_P(typesym) 0
#endif
#define CONSOLE_TYPESYM_STREAM_P(typesym) EQ (typesym, Qstream)

#define CONSOLE_TYPESYM_WIN_P(typesym) \
  (CONSOLE_TYPESYM_GTK_P (typesym) || CONSOLE_TYPESYM_X_P (typesym) || CONSOLE_TYPESYM_MSWINDOWS_P (typesym))

#define CONSOLE_X_P(con) CONSOLE_TYPESYM_X_P (CONSOLE_TYPE (con))
#define CHECK_X_CONSOLE(z) CHECK_CONSOLE_TYPE (z, x)
#define CONCHECK_X_CONSOLE(z) CONCHECK_CONSOLE_TYPE (z, x)

#define CONSOLE_GTK_P(con) CONSOLE_TYPESYM_GTK_P (CONSOLE_TYPE (con))
#define CHECK_GTK_CONSOLE(z) CHECK_CONSOLE_TYPE (z, gtk)
#define CONCHECK_GTK_CONSOLE(z) CONCHECK_CONSOLE_TYPE (z, gtk)

#define CONSOLE_TTY_P(con) CONSOLE_TYPESYM_TTY_P (CONSOLE_TYPE (con))
#define CHECK_TTY_CONSOLE(z) CHECK_CONSOLE_TYPE (z, tty)
#define CONCHECK_TTY_CONSOLE(z) CONCHECK_CONSOLE_TYPE (z, tty)

#define CONSOLE_MSWINDOWS_P(con) CONSOLE_TYPESYM_MSWINDOWS_P (CONSOLE_TYPE (con))
#define CHECK_MSWINDOWS_CONSOLE(z) CHECK_CONSOLE_TYPE (z, mswindows)
#define CONCHECK_MSWINDOWS_CONSOLE(z) CONCHECK_CONSOLE_TYPE (z, mswindows)

#define CONSOLE_STREAM_P(con) CONSOLE_TYPESYM_STREAM_P (CONSOLE_TYPE (con))
#define CHECK_STREAM_CONSOLE(z) CHECK_CONSOLE_TYPE (z, stream)
#define CONCHECK_STREAM_CONSOLE(z) CONCHECK_CONSOLE_TYPE (z, stream)

#define CONSOLE_WIN_P(con) CONSOLE_TYPESYM_WIN_P (CONSOLE_TYPE (con))

/* This structure marks which slots in a console have corresponding
   default values in console_defaults.
   Each such slot has a nonzero value in this structure.
   The value has only one nonzero bit.

   When a console has its own local value for a slot,
   the bit for that slot (found in the same slot in this structure)
   is turned on in the console's local_var_flags slot.

   If a slot in this structure is zero, then even though there may
   be a DEFVAR_CONSOLE_LOCAL for the slot, there is no default value for it;
   and the corresponding slot in console_defaults is not used.  */

extern struct console console_local_flags;

#define CONSOLE_NAME(con) ((con)->name)
#define CONSOLE_CONNECTION(con) ((con)->connection)
#define CONSOLE_CANON_CONNECTION(con) ((con)->canon_connection)
#define CONSOLE_FUNCTION_KEY_MAP(con) ((con)->function_key_map)
#define CONSOLE_SELECTED_DEVICE(con) ((con)->selected_device)
#define CONSOLE_SELECTED_FRAME(con) \
  DEVICE_SELECTED_FRAME (XDEVICE ((con)->selected_device))
#define CONSOLE_LAST_NONMINIBUF_FRAME(con) NON_LVALUE ((con)->last_nonminibuf_frame)
#define CONSOLE_QUIT_CHAR(con) ((con)->quit_char)
#define CONSOLE_QUIT_EVENT(con) ((con)->quit_event)
#define CONSOLE_CRITICAL_QUIT_EVENT(con) ((con)->critical_quit_event)

DECLARE_CONSOLE_TYPE (dead);

extern console_type_entry_dynarr *the_console_type_entry_dynarr;

#endif /* INCLUDED_console_impl_h_ */
