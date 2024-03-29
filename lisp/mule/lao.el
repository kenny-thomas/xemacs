;;; lao.el --- support for Lao -*- coding: iso-2022-7bit; -*-

;; Copyright (C) 1997 Electrotechnical Laboratory, JAPAN.
;; Licensed to the Free Software Foundation.

;; Keywords: multilingual, Lao

;; This file is part of XEmacs.

;; XEmacs is free software: you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the
;; Free Software Foundation, either version 3 of the License, or (at your
;; option) any later version.

;; XEmacs is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.

;; You should have received a copy of the GNU General Public License
;; along with XEmacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Synched up with: Emacs 21.1 (language/lao.el).

;;; Commentary:

;;; Code:

;; Lao script.
;; ISO10646's 0x0E80..0x0EDF are mapped to 0x20..0x7F.
(make-charset 'lao "Lao characters (ISO10646 0E80..0EDF)"
	      '(dimension
		1
		registries ["MuleLao-1"]
		chars 94
		columns 1
		direction l2r
		final ?1
		graphic 0
		short-name "Lao"
		long-name "Lao"
		))

; (make-coding-system
;  'lao 2 ?L
;  "8-bit encoding for ASCII (MSB=0) and LAO (MSB=1)"
;  '(ascii lao nil nil
;    nil nil)
;  '((safe-charsets ascii lao)))

(make-coding-system
 'lao 'iso2022 "Lao"
 '(charset-g0 ascii
   charset-g1 lao
   mnemonic "Lao"
   safe-charsets (ascii lao)
   documentation "8-bit encoding for ASCII (MSB=0) and LAO (MSB=1)"))

(set-language-info-alist
 "Lao" '((charset lao)
	 (coding-system lao)
	 (coding-priority lao)
	 ;; (input-method . "lao")
	 (nonascii-translation . lao)
	 (unibyte-display . lao)
	 (features lao-util)
	 (documentation . t)))

(put-char-table ?(1;(B t use-default-ascent)
(put-char-table ?(1=(B t use-default-ascent)
(put-char-table ?(1?(B t use-default-ascent)
(put-char-table ?(1B(B t use-default-ascent)
(put-char-table ?(1\(B t ignore-relative-composition)

;; Register a function to compose Lao characters.
(put-char-table 'lao
		'(("\\c0\\c9?\\(\\(\\c2\\|\\c3\\)\\c4?\\|\\c4\\)?"
		   . lao-composition-function))
		 composition-function-table)

(provide 'lao)

;;; lao.el ends here
