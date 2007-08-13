;;; mule-cne.el --- interface between input methods Canna and EGG.

;; This file is part of XEmacs.

;; XEmacs is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; XEmacs is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with XEmacs; see the file COPYING.  If not, write to the 
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.
;; Canna and Egg on Nemacs/Mule is distributed in the forms of
;; patches to Nemacs under the terms of the GNU EMACS GENERAL
;; PUBLIC LICENSE which is distributed along with GNU Emacs by
;; the Free Software Foundation.

;; Written by Akira Kon, NEC Corporation.
;; E-Mail:  kon@d1.bs2.mt.nec.co.jp.

;; -*-mode: emacs-lisp-*-

;; !Id: can-n-egg.el,v 1.7 1994/03/16 07:24:15 kon Exp !

;; $B$3$N5!G=$r;H$&$K$O!"(B
;; M-x load $B$3$N%U%!%$%k(B
;; M-x can-n-egg
;; $B$r<B9T$7$^$9!#(B

(require 'canna)

(if (featurep 'mule)
    (require 'egg)
  (require 'wnn-egg))

(provide 'can-n-egg)

;;; $B$3$N4X?t$G$O!"8=:_$N%b!<%I$,!X$+$s$J!Y$NF|K\8lF~NO%b!<%I$+(B
;;; $B$I$&$+$r%A%'%C%/$7$F!"!X$+$s$J!Y$NF|K\8lF~NO%b!<%I$G$J$$$N(B
;;; $B$G$"$l$P!"!X$?$^$4!Y$N(B egg-self-insert-command $B$r8F$V!#!X$+(B
;;; $B$s$J!Y$NF|K\8lF~NO%b!<%I$G$"$l$P!"!X$+$s$J!Y$N(B 
;;; canna-self-insert-command $B$r8F$V!#(B

(defvar canna-exec-hook nil)
(defvar canna-toggle-key nil)
(defvar egg-toggle-key nil)

(defun can-n-egg-self-insert-command (arg)
  "Self insert pressed key and use it to assemble Romaji character."
  (interactive "p")
  (if canna:*japanese-mode*
      (canna-self-insert-command arg)
    (egg-self-insert-command arg)))

;; $B$+$s$J$@$C$?$i:FJQ49!"$?$^$4$@$C$?$iIaDL$N%-!<F~NO!#(B
;;   by rtakigaw@jp.oracle.com, 1994.3.16
(defun can-n-egg-henkan-region-or-self-insert (arg)
  "Do Canna Kana-to-Kanji re-conversion in region or Egg self insert."
  (interactive "p")
  (if canna:*japanese-mode*
      (canna-henkan-region-or-self-insert arg)
    (egg-self-insert-command arg)))

(defun can-n-egg ()
  "Start to use both Canna and Egg."
  (interactive)
  (if canna-exec-hook
      (run-hooks canna-exec-hook)
    (canna))
  (let ((ch 32))
    (while (< ch 127)
      (define-key global-map (make-string 1 ch) 'can-n-egg-self-insert-command)
      (setq ch (1+ ch)) ))
  (if canna-use-space-key-as-henkan-region
      (progn
	(global-set-key "\C-@" 'canna-set-mark-command)
	(global-set-key " " 'can-n-egg-henkan-region-or-self-insert)))
  (global-set-key
   (if canna-toggle-key canna-toggle-key "\C-o") 'canna-toggle-japanese-mode)
  (global-set-key
   (if egg-toggle-key egg-toggle-key "\C-\\") 'toggle-egg-mode) )

