/* Shared event code between X and GTK.
   Copyright (C) 1991-5, 1997 Free Software Foundation, Inc.
   Copyright (C) 1995 Sun Microsystems, Inc.
   Copyright (C) 1996, 2001, 2002, 2003 Ben Wing.

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

#include <config.h>
#include "lisp.h"

#include "charset.h"
#include "elhash.h"
#include "events.h"

#ifdef HAVE_GTK
#include "console-gtk-impl.h"
#include <gdk/gdkx.h>
#endif
/* Unfortunately GTK currently needs to use some X-specific stuff so we
   can't conditionalize the following on HAVE_X_WINDOWS, like we should.

   #### BILL!!! Fix this please! */
#include "console-x-impl.h"

#include "device-impl.h"

#include "toolbar-common.h"

Lisp_Object Qkey_mapping;
Lisp_Object Qsans_modifiers;


/************************************************************************/
/*                            keymap handling                           */
/************************************************************************/

/* X bogusly doesn't define the interpretations of any bits besides
   ModControl, ModShift, and ModLock; so the Interclient Communication
   Conventions Manual says that we have to bend over backwards to figure
   out what the other modifier bits mean.  According to ICCCM:

   - Any keycode which is assigned ModControl is a "control" key.

   - Any modifier bit which is assigned to a keycode which generates Meta_L
     or Meta_R is the modifier bit meaning "meta".  Likewise for Super, Hyper,
     etc.

   - Any keypress event which contains ModControl in its state should be
     interpreted as a "control" character.

   - Any keypress event which contains a modifier bit in its state which is
     generated by a keycode whose corresponding keysym is Meta_L or Meta_R
     should be interpreted as a "meta" character.  Likewise for Super, Hyper,
     etc.

   - It is illegal for a keysym to be associated with more than one modifier
     bit.

   This means that the only thing that emacs can reasonably interpret as a
   "meta" key is a key whose keysym is Meta_L or Meta_R, and which generates
   one of the modifier bits Mod1-Mod5.

   Unfortunately, many keyboards don't have Meta keys in their default
   configuration.  So, if there are no Meta keys, but there are "Alt" keys,
   emacs will interpret Alt as Meta.  If there are both Meta and Alt keys,
   then the Meta keys mean "Meta", and the Alt keys mean "Alt" (it used to
   mean "Symbol," but that just confused the hell out of way too many people).

   This works with the default configurations of the 19 keyboard-types I've
   checked.

   Emacs detects keyboard configurations which violate the above rules, and
   prints an error message on the standard-error-output.  (Perhaps it should
   use a pop-up-window instead.)
 */

static Display *
xlike_device_to_display (struct device *d)
{
#ifdef HAVE_GTK
  if (DEVICE_GTK_P (d))
    return GDK_DISPLAY ();
#endif /* HAVE_GTK */
#ifdef HAVE_X_WINDOWS
  if (DEVICE_GTK_P (d))
    return DEVICE_X_DISPLAY (d);
#endif /* HAVE_X_WINDOWS */
  ABORT ();
  return NULL;
}

/* For every key on the keyboard that has a known character correspondence,
   we define the ascii-character property of the keysym, and make the
   default binding for the key be self-insert-command.

   The following magic is basically intimate knowledge of X11/keysymdef.h.
   The keysym mappings defined by X11 are based on the iso8859 standards,
   except for Cyrillic and Greek.

   In a non-Mule world, a user can still have a multi-lingual editor, by doing
   (set-face-font "...-iso8859-2" (current-buffer))
   for all their Latin-2 buffers, etc.  */

static Lisp_Object
x_keysym_to_character (KeySym keysym)
{
#ifdef MULE
  Lisp_Object charset = Qzero;
#define USE_CHARSET(var,cs) \
  ((var) = charset_by_leading_byte (LEADING_BYTE_##cs))
#else
#define USE_CHARSET(var,lb)
#endif /* MULE */
  int code = 0;

  if ((keysym & 0xff) < 0xa0)
    return Qnil;

  switch (keysym >> 8)
    {
    case 0: /* ASCII + Latin1 */
      USE_CHARSET (charset, LATIN_ISO8859_1);
      code = keysym & 0x7f;
      break;
    case 1: /* Latin2 */
      USE_CHARSET (charset, LATIN_ISO8859_2);
      code = keysym & 0x7f;
      break;
    case 2: /* Latin3 */
      USE_CHARSET (charset, LATIN_ISO8859_3);
      code = keysym & 0x7f;
      break;
    case 3: /* Latin4 */
      USE_CHARSET (charset, LATIN_ISO8859_4);
      code = keysym & 0x7f;
      break;
    case 4: /* Katakana */
      USE_CHARSET (charset, KATAKANA_JISX0201);
      if ((keysym & 0xff) > 0xa0)
	code = keysym & 0x7f;
      break;
    case 5: /* Arabic */
      USE_CHARSET (charset, ARABIC_ISO8859_6);
      code = keysym & 0x7f;
      break;
    case 6: /* Cyrillic */
      {
	static unsigned char const cyrillic[] = /* 0x20 - 0x7f */
	{0x00, 0x72, 0x73, 0x71, 0x74, 0x75, 0x76, 0x77,
	 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x00, 0x7e, 0x7f,
	 0x70, 0x22, 0x23, 0x21, 0x24, 0x25, 0x26, 0x27,
	 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x00, 0x2e, 0x2f,
	 0x6e, 0x50, 0x51, 0x66, 0x54, 0x55, 0x64, 0x53,
	 0x65, 0x58, 0x59, 0x5a, 0x5b, 0x5c, 0x5d, 0x5e,
	 0x5f, 0x6f, 0x60, 0x61, 0x62, 0x63, 0x56, 0x52,
	 0x6c, 0x6b, 0x57, 0x68, 0x6d, 0x69, 0x67, 0x6a,
	 0x4e, 0x30, 0x31, 0x46, 0x34, 0x35, 0x44, 0x33,
	 0x45, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e,
	 0x3f, 0x4f, 0x40, 0x41, 0x42, 0x43, 0x36, 0x32,
	 0x4c, 0x4b, 0x37, 0x48, 0x4d, 0x49, 0x47, 0x4a};
	USE_CHARSET (charset, CYRILLIC_ISO8859_5);
	code = cyrillic[(keysym & 0x7f) - 0x20];
	break;
      }
    case 7: /* Greek */
      {
	static unsigned char const greek[] = /* 0x20 - 0x7f */
	{0x00, 0x36, 0x38, 0x39, 0x3a, 0x5a, 0x00, 0x3c,
	 0x3e, 0x5b, 0x00, 0x3f, 0x00, 0x00, 0x35, 0x2f,
	 0x00, 0x5c, 0x5d, 0x5e, 0x5f, 0x7a, 0x40, 0x7c,
	 0x7d, 0x7b, 0x60, 0x7e, 0x00, 0x00, 0x00, 0x00,
	 0x00, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
	 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f,
	 0x50, 0x51, 0x53, 0x00, 0x54, 0x55, 0x56, 0x57,
	 0x58, 0x59, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	 0x00, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
	 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f,
	 0x70, 0x71, 0x73, 0x72, 0x74, 0x75, 0x76, 0x77,
	 0x78, 0x79, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
	USE_CHARSET (charset, GREEK_ISO8859_7);
	code = greek[(keysym & 0x7f) - 0x20];
	break;
      }
    case 8: /* Technical */
      break;
    case 9: /* Special */
      break;
    case 10: /* Publishing */
      break;
    case 11: /* APL */
      break;
    case 12: /* Hebrew */
      USE_CHARSET (charset, HEBREW_ISO8859_8);
      code = keysym & 0x7f;
      break;
    case 13: /* Thai */
      /* #### This needs to deal with character composition. */
      USE_CHARSET (charset, THAI_TIS620);
      code = keysym & 0x7f;
      break;
    case 14: /* Korean Hangul */
      break;
    case 19: /* Latin 9 - ISO8859-15 - unsupported charset. */
      break;
    case 32: /* Currency */
      break;
    default:
      break;
    }

  if (code == 0)
    return Qnil;

#ifdef MULE
  return make_char (make_ichar (charset, code, 0));
#else
  return make_char (code + 0x80);
#endif
}

/* See comment near character_to_event().
*/
static void
maybe_define_x_key_as_self_inserting_character (KeySym keysym,
						Lisp_Object symbol)
{
  Lisp_Object character = x_keysym_to_character (keysym);

  if (CHARP (character))
    {
      extern Lisp_Object Vcurrent_global_map;
      extern Lisp_Object Qascii_character;
      if (NILP (Flookup_key (Vcurrent_global_map, symbol, Qnil))) 
        {
	  Fput (symbol, Qascii_character, character);
	  Fdefine_key (Vcurrent_global_map, symbol, Qself_insert_command); 
        }
    }
}

/* Currently, GDK keysyms are exactly like X keysyms.  If this ever
   changes, we should rewrite this, but currently there's no point. */

Lisp_Object
xlike_keysym_to_emacs_keysym (long keysym, int simple_p)
{
  Ibyte *name;
  if (keysym >= XK_exclam && keysym <= XK_asciitilde)
    /* We must assume that the X keysym numbers for the ASCII graphic
       characters are the same as their ASCII codes.  */
    return make_char (keysym);

  switch (keysym)
    {
      /* These would be handled correctly by the default case, but by
	 special-casing them here we don't garbage a string or call
	 intern().  */
    case XK_BackSpace:	return QKbackspace;
    case XK_Tab:	return QKtab;
    case XK_Linefeed:	return QKlinefeed;
    case XK_Return:	return QKreturn;
    case XK_Escape:	return QKescape;
    case XK_space:	return QKspace;
    case XK_Delete:	return QKdelete;
    case 0:		return Qnil;
    default:
      if (simple_p) return Qnil;
      name = NEW_EXTERNAL_TO_C_STRING (XKeysymToString (keysym),
				       Qx_keysym_encoding);
      if (!name || !name[0])
	/* This happens if there is a mismatch between the Xlib of
           XEmacs and the Xlib of the X server...

	   Let's hard-code in some knowledge of common keysyms introduced
	   in recent X11 releases.  Snarfed from X11/keysymdef.h

	   Probably we should add some stuff here for X11R6. */
	switch (keysym)
	  {
	  case 0xFF95: return KEYSYM ("kp-home");
	  case 0xFF96: return KEYSYM ("kp-left");
	  case 0xFF97: return KEYSYM ("kp-up");
	  case 0xFF98: return KEYSYM ("kp-right");
	  case 0xFF99: return KEYSYM ("kp-down");
	  case 0xFF9A: return KEYSYM ("kp-prior");
	  case 0xFF9B: return KEYSYM ("kp-next");
	  case 0xFF9C: return KEYSYM ("kp-end");
	  case 0xFF9D: return KEYSYM ("kp-begin");
	  case 0xFF9E: return KEYSYM ("kp-insert");
	  case 0xFF9F: return KEYSYM ("kp-delete");

	  case 0x1005FF10: return KEYSYM ("SunF36"); /* labeled F11 */
	  case 0x1005FF11: return KEYSYM ("SunF37"); /* labeled F12 */
	  default:
	    {
	      Ascbyte buf[64];
	      sprintf (buf, "unknown-keysym-0x%X", (int) keysym);
	      return KEYSYM (buf);
	    }
	  }
      /* If it's got a one-character name, that's good enough. */
      if (!* (name + itext_ichar_len (name)))
	return make_char (itext_ichar (name));

      /* If it's in the "Keyboard" character set, downcase it.
	 The case of those keysyms is too totally random for us to
	 force anyone to remember them.
	 The case of the other character sets is significant, however.
	 */
      if ((((unsigned int) keysym) & (~0x1FF)) == ((unsigned int) 0xFE00))
	{
	  Ibyte *buf, *s1;

	  IBYTE_STRING_TO_ALLOCA (name, buf);
	  for (s1 = buf; *s1; s1++)
	    if (*s1 == '_')
	      *s1 = '-';
	  return LISP_STRING_TO_KEYSYM (Fdowncase (build_intstring (buf),
						   Qnil));
	}
      return KEYSYM ((CIbyte *) name);
    }
}

static void
xlike_has_keysym (KeySym keysym, Lisp_Object hash_table, int with_modifiers)
{
  KeySym upper_lower[2];
  int j;

  if (keysym < 0x80) /* Optimize for ASCII keysyms */
    return;

  /* If you execute:
     xmodmap -e 'keysym NN = scaron'
     and then press (Shift scaron), X11 will return the different
     keysym `Scaron', but  `xmodmap -pke'  might not even mention `Scaron'.
     So we "register" both `scaron' and `Scaron'. */
#ifdef HAVE_XCONVERTCASE
  XConvertCase (keysym, &upper_lower[0], &upper_lower[1]);
#else
  upper_lower[0] = upper_lower[1] = keysym;
#endif

  for (j = 0; j < (upper_lower[0] == upper_lower[1] ? 1 : 2); j++)
    {
      Extbyte *name = XKeysymToString (keysym);
      keysym = upper_lower[j];

      if (name)
	{
	  /* X guarantees NAME to be in the Host Portable Character Encoding */
	  Lisp_Object sym = xlike_keysym_to_emacs_keysym (keysym, 0);
	  Lisp_Object new_value = with_modifiers ? Qt : Qsans_modifiers;
	  Lisp_Object old_value = Fgethash (sym, hash_table, Qnil);

	  if (! EQ (old_value, new_value)
	      && ! (EQ (old_value, Qsans_modifiers) &&
		    EQ (new_value, Qt)))
	    {
	      maybe_define_x_key_as_self_inserting_character (keysym, sym);
	      Fputhash (build_ext_string (name, Qx_keysym_encoding), new_value,
			hash_table);
	      Fputhash (sym, new_value, hash_table);
	    }
	}
    }
}

void
xlike_reset_key_mapping (struct device *d, struct xlike_event_key_data *xd)
{
  KeySym *keysym, *keysym_end;
  Lisp_Object hash_table;
  int key_code_count, keysyms_per_code;
  Display *display = xlike_device_to_display (d);

  if (xd->x_keysym_map)
    XFree ((char *) xd->x_keysym_map);
  XDisplayKeycodes (display,
		    &xd->x_keysym_map_min_code,
		    &xd->x_keysym_map_max_code);
  key_code_count = xd->x_keysym_map_max_code - xd->x_keysym_map_min_code + 1;
  xd->x_keysym_map =
    (KeySym *)
    XGetKeyboardMapping (display, xd->x_keysym_map_min_code, key_code_count,
			 &xd->x_keysym_map_keysyms_per_code);

  hash_table = xd->x_keysym_map_hash_table;
  if (HASH_TABLEP (hash_table))
    Fclrhash (hash_table);
  else
    xd->x_keysym_map_hash_table = hash_table =
      make_lisp_hash_table (128, HASH_TABLE_NON_WEAK, HASH_TABLE_EQUAL);

  for (keysym = xd->x_keysym_map,
	 keysyms_per_code = xd->x_keysym_map_keysyms_per_code,
	 keysym_end = keysym + (key_code_count * keysyms_per_code);
       keysym < keysym_end;
       keysym += keysyms_per_code)
    {
      int j;
      if (keysym[0] == NoSymbol)
	continue;

      xlike_has_keysym (keysym[0], hash_table, 0);

      for (j = 1; j < keysyms_per_code; j++)
	{
	  if (keysym[j] != keysym[0] &&
	      keysym[j] != NoSymbol)
	    xlike_has_keysym (keysym[j], hash_table, 1);
	}
    }
}

static const char *
index_to_name (int indice)
{
  switch (indice)
    {
    case ShiftMapIndex:   return "ModShift";
    case LockMapIndex:    return "ModLock";
    case ControlMapIndex: return "ModControl";
    case Mod1MapIndex:    return "Mod1";
    case Mod2MapIndex:    return "Mod2";
    case Mod3MapIndex:    return "Mod3";
    case Mod4MapIndex:    return "Mod4";
    case Mod5MapIndex:    return "Mod5";
    default:              return "???";
    }
}

/* Boy, I really wish C had local functions... */
struct c_doesnt_have_closures   /* #### not yet used */
{
  int warned_about_overlapping_modifiers;
  int warned_about_predefined_modifiers;
  int warned_about_duplicate_modifiers;
  int meta_bit;
  int hyper_bit;
  int super_bit;
  int alt_bit;
  int mode_bit;
};

void
xlike_reset_modifier_mapping (struct device *d,
			      struct xlike_event_key_data *xd)
{
  int modifier_index, modifier_key, column, mkpm;
  int warned_about_overlapping_modifiers = 0;
  int warned_about_predefined_modifiers  = 0;
  int warned_about_duplicate_modifiers   = 0;
  int meta_bit  = 0;
  int hyper_bit = 0;
  int super_bit = 0;
  int alt_bit   = 0;
  int mode_bit  = 0;
  Display *display = xlike_device_to_display (d);

  xd->lock_interpretation = 0;

  if (xd->x_modifier_keymap)
    XFreeModifiermap (xd->x_modifier_keymap);

  xlike_reset_key_mapping (d, xd);

  xd->x_modifier_keymap = (XModifierKeymap *) XGetModifierMapping (display);

  /* Boy, I really wish C had local functions...
   */

  /* The call to warn_when_safe must be on the same line as the string or
     make-msgfile won't pick it up properly (the newline doesn't confuse
     it, but the backslash does). */

#define modwarn(name,old,other)						\
  warn_when_safe (Qkey_mapping, Qwarning, "XEmacs:  %s (0x%x) generates %s, which is generated by %s.",	\
		  name, code, index_to_name (old), other),		\
  warned_about_overlapping_modifiers = 1

#define modbarf(name,other)						    \
  warn_when_safe (Qkey_mapping, Qwarning, "XEmacs:  %s (0x%x) generates %s, which is nonsensical.", \
		  name, code, other),					    \
  warned_about_predefined_modifiers = 1

#define check_modifier(name,mask)					      \
  if ((1<<modifier_index) != mask)					      \
    warn_when_safe (Qkey_mapping, Qwarning, "XEmacs:  %s (0x%x) generates %s, which is nonsensical.", \
		    name, code, index_to_name (modifier_index)),	      \
    warned_about_predefined_modifiers = 1

#define store_modifier(name,old)					   \
  if (old && old != modifier_index)					   \
    warn_when_safe (Qkey_mapping, Qwarning, "XEmacs:  %s (0x%x) generates both %s and %s, which is nonsensical.",\
		    name, code, index_to_name (old),			   \
		    index_to_name (modifier_index)),			   \
    warned_about_duplicate_modifiers = 1;				   \
  if (modifier_index == ShiftMapIndex) modbarf (name,"ModShift");	   \
  else if (modifier_index == LockMapIndex) modbarf (name,"ModLock");	   \
  else if (modifier_index == ControlMapIndex) modbarf (name,"ModControl"); \
  else if (sym == XK_Mode_switch)					   \
    mode_bit = modifier_index; /* Mode_switch is special, see below... */  \
  else if (modifier_index == meta_bit && old != meta_bit)		   \
    modwarn (name, meta_bit, "Meta");					   \
  else if (modifier_index == super_bit && old != super_bit)		   \
    modwarn (name, super_bit, "Super");					   \
  else if (modifier_index == hyper_bit && old != hyper_bit)		   \
    modwarn (name, hyper_bit, "Hyper");					   \
  else if (modifier_index == alt_bit && old != alt_bit)			   \
    modwarn (name, alt_bit, "Alt");					   \
  else									   \
    old = modifier_index;

  mkpm = (xd->x_modifier_keymap)->max_keypermod;
  for (modifier_index = 0; modifier_index < 8; modifier_index++)
    for (modifier_key = 0; modifier_key < mkpm; modifier_key++) {
      KeySym last_sym = 0;
      for (column = 0; column < 4; column += 2) {
	KeyCode code =
	  (xd->x_modifier_keymap)
	  ->modifiermap[modifier_index * mkpm + modifier_key];
	KeySym sym = (code ? XKeycodeToKeysym (display, code, column) : 0);
	if (sym == last_sym) continue;
	last_sym = sym;
	switch (sym) {
	case XK_Mode_switch:store_modifier ("Mode_switch", mode_bit); break;
	case XK_Meta_L:     store_modifier ("Meta_L", meta_bit); break;
	case XK_Meta_R:     store_modifier ("Meta_R", meta_bit); break;
	case XK_Super_L:    store_modifier ("Super_L", super_bit); break;
	case XK_Super_R:    store_modifier ("Super_R", super_bit); break;
	case XK_Hyper_L:    store_modifier ("Hyper_L", hyper_bit); break;
	case XK_Hyper_R:    store_modifier ("Hyper_R", hyper_bit); break;
	case XK_Alt_L:      store_modifier ("Alt_L", alt_bit); break;
	case XK_Alt_R:      store_modifier ("Alt_R", alt_bit); break;
	case XK_Control_L:  check_modifier ("Control_L", ControlMask); break;
	case XK_Control_R:  check_modifier ("Control_R", ControlMask); break;
	case XK_Shift_L:    check_modifier ("Shift_L", ShiftMask); break;
	case XK_Shift_R:    check_modifier ("Shift_R", ShiftMask); break;
	case XK_Shift_Lock: check_modifier ("Shift_Lock", LockMask);
	  xd->lock_interpretation = XK_Shift_Lock; break;
	case XK_Caps_Lock:  check_modifier ("Caps_Lock", LockMask);
	  xd->lock_interpretation = XK_Caps_Lock; break;

	/* It probably doesn't make any sense for a modifier bit to be
	   assigned to a key that is not one of the above, but OpenWindows
	   assigns modifier bits to a couple of random function keys for
	   no reason that I can discern, so printing a warning here would
	   be annoying. */
	}
      }
    }
#undef store_modifier
#undef check_modifier
#undef modwarn
#undef modbarf

  /* If there was no Meta key, then try using the Alt key instead.
     If there is both a Meta key and an Alt key, then the Alt key
     is not disturbed and remains an Alt key. */
  if (! meta_bit && alt_bit)
    meta_bit = alt_bit, alt_bit = 0;

  /* mode_bit overrides everything, since it's processed down inside of
     XLookupString() instead of by us.  If Meta and Mode_switch both
     generate the same modifier bit (which is an error), then we don't
     interpret that bit as Meta, because we can't make XLookupString()
     not interpret it as Mode_switch; and interpreting it as both would
     be totally wrong. */
  if (mode_bit)
    {
      const char *warn = 0;
      if      (mode_bit == meta_bit)  warn = "Meta",  meta_bit  = 0;
      else if (mode_bit == hyper_bit) warn = "Hyper", hyper_bit = 0;
      else if (mode_bit == super_bit) warn = "Super", super_bit = 0;
      else if (mode_bit == alt_bit)   warn = "Alt",   alt_bit   = 0;
      if (warn)
	{
	  warn_when_safe
	    (Qkey_mapping, Qwarning,
	     "XEmacs:  %s is being used for both Mode_switch and %s.",
	     index_to_name (mode_bit), warn),
	    warned_about_overlapping_modifiers = 1;
	}
    }
#undef index_to_name

  xd->MetaMask   = (meta_bit   ? (1 << meta_bit)  : 0);
  xd->HyperMask  = (hyper_bit  ? (1 << hyper_bit) : 0);
  xd->SuperMask  = (super_bit  ? (1 << super_bit) : 0);
  xd->AltMask    = (alt_bit    ? (1 << alt_bit)   : 0);
  xd->ModeMask   = (mode_bit   ? (1 << mode_bit)  : 0); /* unused */

  if (warned_about_overlapping_modifiers)
    warn_when_safe (Qkey_mapping, Qwarning, "\n"
"	Two distinct modifier keys (such as Meta and Hyper) cannot generate\n"
"	the same modifier bit, because Emacs won't be able to tell which\n"
"	modifier was actually held down when some other key is pressed.  It\n"
"	won't be able to tell Meta-x and Hyper-x apart, for example.  Change\n"
"	one of these keys to use some other modifier bit.  If you intend for\n"
"	these keys to have the same behavior, then change them to have the\n"
"	same keysym as well as the same modifier bit.");

  if (warned_about_predefined_modifiers)
    warn_when_safe (Qkey_mapping, Qwarning, "\n"
"	The semantics of the modifier bits ModShift, ModLock, and ModControl\n"
"	are predefined.  It does not make sense to assign ModControl to any\n"
"	keysym other than Control_L or Control_R, or to assign any modifier\n"
"	bits to the \"control\" keysyms other than ModControl.  You can't\n"
"	turn a \"control\" key into a \"meta\" key (or vice versa) by simply\n"
"	assigning the key a different modifier bit.  You must also make that\n"
"	key generate an appropriate keysym (Control_L, Meta_L, etc).");

  /* No need to say anything more for warned_about_duplicate_modifiers. */

  if (warned_about_overlapping_modifiers || warned_about_predefined_modifiers)
    warn_when_safe (Qkey_mapping, Qwarning, "\n"
"	The meanings of the modifier bits Mod1 through Mod5 are determined\n"
"	by the keysyms used to control those bits.  Mod1 does NOT always\n"
"	mean Meta, although some non-ICCCM-compliant programs assume that.");
}

void
xlike_init_modifier_mapping (struct device *d, struct xlike_event_key_data *xd)
{
  xd->x_keysym_map_hash_table = Qnil;
  xd->x_keysym_map = NULL;
  xd->x_modifier_keymap = NULL;
  xlike_reset_modifier_mapping (d, xd);
}

void
free_xlike_event_key_data (struct xlike_event_key_data *xd)
{
  if (xd->x_modifier_keymap)
    XFreeModifiermap (xd->x_modifier_keymap);
  if (xd->x_keysym_map)
    XFree ((char *) xd->x_keysym_map);
}

void
syms_of_event_xlike (void)
{
  DEFSYMBOL (Qkey_mapping);
  DEFSYMBOL (Qsans_modifiers);
}
