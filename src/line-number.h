/* Copyright (C) 1997, Free Software Foundation, Inc.

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

void mark_line_number_cache (void *, void (*)(Lisp_Object));
void narrow_line_number_cache (struct buffer *);
void insert_invalidate_line_number_cache (struct buffer *, Bufpos,
					  CONST Bufbyte *, Bytecount);
void delete_invalidate_line_number_cache (struct buffer *, Bufpos, Bufpos);

EMACS_INT buffer_line_number (struct buffer *, Bufpos, int);
