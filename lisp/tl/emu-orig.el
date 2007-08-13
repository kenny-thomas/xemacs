;;;
;;; emu-orig.el --- Mule 2 emulation module for Original Emacs and XEmacs
;;;
;;; Copyright (C) 1995 Free Software Foundation, Inc.
;;; Copyright (C) 1994 .. 1996 MORIOKA Tomohiko
;;;
;;; Author: MORIOKA Tomohiko <morioka@jaist.ac.jp>
;;; Version:
;;;	$Id: emu-orig.el,v 1.1.1.1 1996/12/18 03:55:31 steve Exp $
;;; Keywords: emulation, compatibility, Mule
;;;
;;; This file is part of tl (Tiny Library).
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 2, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with This program.  If not, write to the Free Software
;;; Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
;;;
;;; Code:

;;; @ leading-char
;;;

(defconst lc-ascii 0)
(defconst lc-ltn1 129)

(defun char-leading-char (chr)
  "Return leading character of CHAR.
\[emu-orig.el; Mule emulating function]"
  (if (< chr 128)
      lc-ascii
    lc-ltn1))

(defalias 'get-lc 'char-leading-char)

(defun find-charset-string (str)
  "Return a list of leading-chars in the string.
\[emu-orig.el; Mule emulating function]"
  (if (string-match "[\200-\377]" str)
      (list lc-ltn1)
    ))

(defun find-charset-region (start end)
  "Return a list of leading-chars in the region between START and END.
\[emu-orig.el; Mule emulating function]"
  (if (save-excursion
	(save-restriction
	  (narrow-to-region start end)
	  (goto-char start)
	  (re-search-forward "[\200-\377]" nil t)
	  ))
      (list lc-ltn1)
    ))


;;; @ coding-system
;;;

(defconst *internal* nil)
(defconst *ctext* nil)
(defconst *noconv* nil)

(defun code-convert-string (str ic oc)
  "Convert code in STRING from SOURCE code to TARGET code,
On successful converion, returns the result string,
else returns nil. [emu-orig.el; Mule emulating function]"
  str)

(defun code-convert-region (beg end ic oc)
  "Convert code of the text between BEGIN and END from SOURCE
to TARGET. On successful conversion returns t,
else returns nil. [emu-orig.el; Mule emulating function]"
  t)

(defun code-detect-region (beg end)
  "Detect coding-system of the text in the region between START and END.
\[emu-orig.el; Mule emulating function]"
  )

(defun set-file-coding-system (coding-system &optional force)
  )


;;; @ character and string
;;;

(defun char-bytes (chr) 1)
(defun char-width (chr) 1)

(defalias 'string-width 'length)

(defun string-to-char-list (str)
  (mapcar (function identity) str)
  )

(defun truncate-string (str width &optional start-column)
  "Truncate STR to fit in WIDTH columns.
Optional non-nil arg START-COLUMN specifies the starting column.
\[emu-orig.el; Mule 2.3 emulating function]"
  (or start-column
      (setq start-column 0))
  (substring str start-column width)
  )


;;; @ etc
;;;

(cond (running-xemacs
       (require 'emu-xemacs))
      (running-emacs-19
       (require 'emu-19)
       ))


;;; @ end
;;;

(provide 'emu-orig)

;;; emu-orig.el ends here
