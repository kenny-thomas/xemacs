;;; w3-mule.el --- MULE 18/19 specific functions for emacs-w3
;; Author: wmperry
;; Created: 1996/06/30 18:09:59
;; Version: 1.2
;; Keywords: faces, help, i18n, mouse, hypermedia

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Copyright (c) 1993 - 1996 by William M. Perry (wmperry@cs.indiana.edu)
;;;
;;; This file is part of GNU Emacs.
;;;
;;; GNU Emacs is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.
;;;
;;; GNU Emacs is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Printing a mule buffer as postscript.  Requires m2ps
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun w3-m2ps-buffer (&optional buffer)
  "Print a buffer by passing it through m2ps and lpr."
  (or buffer (setq buffer (current-buffer)))
  (let ((x (save-excursion (set-buffer buffer) tab-width)))
    (save-excursion
      (set-buffer (get-buffer-create " *mule-print*"))
      (erase-buffer)
      (insert-buffer buffer)
      (if (/= x tab-width)
	  (progn
	    (setq tab-width x)
	    (message "Converting tabs")
	    (untabify (point-min) (point-max))))
      (setq file-coding-system *internal*)
      (shell-command-on-region (point-min) (point-max)
			       "m2ps | lpr" t))))
	    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Multi-Lingual Emacs (MULE) Specific Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar attributed-region nil
  "Bogus definition to get rid of compile-time warnings.")

(defun w3-inhibit-code-conversion (proc buf)
  "Inhibit Mule's subprocess PROC from code converting in BUF."
  (save-excursion
    (set-buffer buf)
    (setq mc-flag nil))
  (set-process-coding-system proc *noconv* *noconv*))

(defvar w3-mime-list-for-code-conversion
  '("text/plain" "text/html")
  "List of MIME types that require Mules' code conversion.")
(make-variable-buffer-local 'w3-mime-list-for-code-conversion)

(defun w3-convert-code-for-mule (mmtype)
  "Convert current data into the appropriate coding system"
  (and (or (not mmtype) (member mmtype w3-mime-list-for-code-conversion))
       (let* ((c (code-detect-region (point-min) (point-max)))
	      (code (or (and (listp c) (car c)) c)))
	 (setq mc-flag t)
	 (code-convert-region (point-min) (point-max) code *internal*)
	 (set-file-coding-system code))))

(provide 'w3-mule)