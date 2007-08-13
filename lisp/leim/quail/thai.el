;;; quail/thai.el --- Quail package for inputting Thai characters

;; Copyright (C) 1995 Free Software Foundation, Inc.
;; Copyright (C) 1995 Electrotechnical Laboratory, JAPAN.

;; Keywords: multilingual, input method, Thai

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Code:

(require 'quail)
(require 'language/thai-util)

(eval-and-compile

(defvar thai-keyboard-mapping
  [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0	; control codes
   0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0	; control codes
   0 "#" ",TF(B" ",Tr(B" ",Ts(B" ",Tt(B" "0,TQi1(B" ",T'(B"	; SPC .. '
   ",Tv(B" ",Tw(B" ",Tu(B" ",Ty(B" ",TA(B" ",T"(B" ",Tc(B" ",T=(B"	; ( .. /
   ",T((B" ",TE(B" "/" "_" ",T@(B" ",T6(B" ",TX(B" ",TV(B"	; 0 .. 7
   ",T$(B" ",T5(B" ",T+(B" ",TG(B" ",T2(B" ",T*(B" ",TL(B" 0	; 8 .. ?
   ",Tq(B" ",TD(B" ",TZ(B" ",T)(B" ",T/(B" ",T.(B" ",Tb(B" ",T,(B"	; @ .. G
   ",Tg(B" ",T3(B" ",Tk(B" ",TI(B" ",TH(B" ",Tn(B" ",Tl(B" ",TO(B"	; H .. O
   ",T-(B" ",Tp(B" ",T1(B" ",T&(B" ",T8(B" ",Tj(B" ",TN(B" "\""	; P .. W
   ")" ",Tm(B" "(" ",T:(B" ",T_(B" ",TE(B" ",TY(B" ",Tx(B"	; X .. _
   ",T#(B" ",T?(B" ",TT(B" ",Ta(B" ",T!(B" ",TS(B" ",T4(B" ",T`(B"	; ` .. g
   ",Ti(B" ",TC(B" ",Th(B" ",TR(B" ",TJ(B" ",T7(B" ",TW(B" ",T9(B"	; h .. o
   ",TB(B" ",Tf(B" ",T>(B" ",TK(B" ",TP(B" ",TU(B" ",TM(B" ",Td(B"	; p .. w
   ",T;(B" ",TQ(B" ",T<(B" ",T0(B" ",To(B" "," ",T%(B" 0]	; x .. DEL
  "A table which maps ASCII key codes to corresponding Thai characters."
  )

)

;; Template of a cdr part of a Quail map when a consonant is entered.
(defvar thai-consonant-alist nil)
;; Template of a cdr part of a Quail map when a vowel upper or a vowel
;; lower is entered.
(defvar thai-vowel-upper-lower-alist nil)

;; Return a Quail map corresponding to KEY of length LEN.
;; The car part of the map is a translation generated automatically.
;; The cdr part of the map is a copy of ALIST.
(defun thai-generate-quail-map (key len alist)
  (let ((str "")
	(idx 0))
    (while (< idx len)
      (setq str (concat str (aref thai-keyboard-mapping (aref key idx)))
	    idx (1+ idx)))
    (cons (string-to-char (compose-string str)) (copy-alist alist))))

;; Return a Quail map corresponding to KEY of length LEN when Thai
;; tone mark is entered.
(defun thai-tone-input (key len)
  (thai-generate-quail-map key len nil))

;; Return a Quail map corresponding to KEY of length LEN when Thai
;; vowel upper or vowel lower is entered.
(defun thai-vowel-upper-lower-input (key len)
  (thai-generate-quail-map key len thai-vowel-upper-lower-alist))

;; Return an alist which can be a cdr part of a Quail map
;; corresponding to the current key when Thai consonant is entered.
(defun thai-consonant-input (key len)
  (copy-alist thai-consonant-alist))

(quail-define-package "quail-thai" "Thai" "Thai" t
		      "Thai input method with TIS620 characters:

The difference from the ordinal Thai keyboard:
    ',T_(B' and ',To(B' are assigned to '\\' and '|' respectively,
    ',T#(B' and ',T%(B' are assigned to '`' and '~' respectively,
    Don't know where to assign characters ',Tz(B' and ',T{(B'."
		      nil t t nil t)

;; Define RULES in Quail map.  In addition, create
;; `thai-conconant-map' and `thai-vowel-upper-lower-alist'
;; The general composing rules are as follows:
;;
;;                          T
;;       V        T         V                  T
;; CV -> C, CT -> C, CVT -> C, Cv -> C, CvT -> C
;;                                   v         v
;;
;; where C: consonant, V: vowel upper, v: vowel lower, T: tone mark.

(defmacro thai-quail-define-rules (&rest rules)
  (let ((l rules)
	consonant-alist
	vowel-upper-lower-alist
	rule trans ch c-set)
    (while l
      (setq rule (car l))
      (setq trans (nth 1 rule))
      (if (consp trans)
	  (setq trans (car trans)))
      (setq c-set (char-category-set (string-to-char trans)))
      (cond ((or (aref c-set ?2)
		 (aref c-set ?3))
	     (setq consonant-alist
		   (cons (cons (string-to-char (car rule))
			       'thai-vowel-upper-lower-input)
			 consonant-alist)))
	    ((aref c-set ?4)
	     (setq consonant-alist
		   (cons (cons (string-to-char (car rule))
			       'thai-tone-input)
			 consonant-alist)
		   vowel-upper-lower-alist
		   (cons (cons (string-to-char (car rule))
			       'thai-tone-input)
			 vowel-upper-lower-alist))))
      (setq l (cdr l)))
    (list 'progn
	  (cons 'quail-define-rules rules)
	  `(setq thai-consonant-alist ',consonant-alist
		 thai-vowel-upper-lower-alist ',vowel-upper-lower-alist))))

(thai-quail-define-rules
 ("1" (",TE(B" . thai-consonant-input))
 ("!" "#")
 ("2" "/")
 ("@" (",Tq(B" . thai-consonant-input))
 ("3" "_")
 ("#" (",Tr(B" . thai-consonant-input))
 ("4" (",T@(B" . thai-consonant-input))
 ("$" (",Ts(B" . thai-consonant-input))
 ("5" (",T6(B" . thai-consonant-input))
 ("%" (",Tt(B" . thai-consonant-input))
 ("6" ",TX(B")
 ("^" ",TY(B")
 ("7" ",TV(B")
 ("&" "0,TQi1(B")
 ("8" (",T$(B" . thai-consonant-input))
 ("*" (",Tu(B" . thai-consonant-input))
 ("9" (",T5(B" . thai-consonant-input))
 ("\(" (",Tv(B" . thai-consonant-input))
 ("0" (",T((B" . thai-consonant-input))
 ("\)" (",Tw(B" . thai-consonant-input))
 ("-" (",T"(B" . thai-consonant-input))
 ("_" (",Tx(B" . thai-consonant-input))
 ("=" (",T*(B" . thai-consonant-input))
 ("+" (",Ty(B" . thai-consonant-input))
 ("\\" (",T_(B" . thai-consonant-input))
 ("|" (",To(B" . thai-consonant-input))
 ("`" (",T#(B" . thai-consonant-input))
 ("~" (",T%(B" . thai-consonant-input))
 ("q" ",Tf(B")
 ("Q" ",Tp(B")
 ("w" ",Td(B")
 ("W" "\"")
 ("e" ",TS(B")
 ("E" (",T.(B" . thai-consonant-input))
 ("r" (",T>(B" . thai-consonant-input))
 ("R" (",T1(B" . thai-consonant-input))
 ("t" ",TP(B")
 ("T" (",T8(B" . thai-consonant-input))
 ("y" ",TQ(B")
 ("Y" ",Tm(B")
 ("u" ",TU(B")
 ("U" ",Tj(B")
 ("i" (",TC(B" . thai-consonant-input))
 ("I" (",T3(B" . thai-consonant-input))
 ("o" (",T9(B" . thai-consonant-input))
 ("O" (",TO(B" . thai-consonant-input))
 ("p" (",TB(B" . thai-consonant-input))
 ("P" (",T-(B" . thai-consonant-input))
 ("\[" (",T:(B" . thai-consonant-input))
 ("{" (",T0(B" . thai-consonant-input))
 ("\]" (",TE(B" . thai-consonant-input))
 ("}" ",")

 ("a" (",T?(B" . thai-consonant-input))
 ("A" ",TD(B")
 ("s" (",TK(B" . thai-consonant-input))
 ("S" (",T&(B" . thai-consonant-input))
 ("d" (",T!(B" . thai-consonant-input))
 ("D" (",T/(B" . thai-consonant-input))
 ("f" (",T4(B" . thai-consonant-input))
 ("F" ",Tb(B")
 ("g" ",T`(B")
 ("G" (",T,(B" . thai-consonant-input))
 ("h" ",Ti(B")
 ("H" ",Tg(B")
 ("j" ",Th(B")
 ("J" ",Tk(B")
 ("k" ",TR(B")
 ("K" (",TI(B" . thai-consonant-input))
 ("l" (",TJ(B" . thai-consonant-input))
 ("L" (",TH(B" . thai-consonant-input))
 ("\;" (",TG(B" . thai-consonant-input))
 (":" (",T+(B" . thai-consonant-input))
 ("'" (",T'(B" . thai-consonant-input))
 ("\"" ".")

 ("z" (",T<(B" . thai-consonant-input))
 ("Z" "(")
 ("x" (",T;(B" . thai-consonant-input))
 ("X" ")")
 ("c" ",Ta(B")
 ("C" (",T)(B" . thai-consonant-input))
 ("v" (",TM(B" . thai-consonant-input))
 ("V" (",TN(B" . thai-consonant-input))
 ("b" ",TT(B")
 ("B" ",TZ(B")
 ("n" ",TW(B")
 ("N" ",Tl(B")
 ("m" (",T7(B" . thai-consonant-input))
 ("M" ",Tn(B")
 ("," (",TA(B" . thai-consonant-input))
 ("<" (",T2(B" . thai-consonant-input))
 ("." ",Tc(B")
 (">" (",TL(B" . thai-consonant-input))
 ("/" (",T=(B" . thai-consonant-input))
 ("\"" ",TF(B")
 )

;;; quail/thai.el ends here
