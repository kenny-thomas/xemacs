;;; filename.el --- file name filter

;; Copyright (C) 1996,1997 MORIOKA Tomohiko

;; Author: MORIOKA Tomohiko <morioka@jaist.ac.jp>
;; Version: $Id: filename.el,v 1.1 1997/06/03 04:18:35 steve Exp $
;; Keywords: file name, string

;; This file is part of APEL (A Portable Emacs Library).

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Code:

(require 'emu)
(require 'cl)

(defsubst poly-funcall (functions argument)
  "Apply initial ARGUMENT to sequence of FUNCTIONS.
FUNCTIONS is list of functions.

(poly-funcall '(f1 f2 .. fn) arg) is as same as
(fn .. (f2 (f1 arg)) ..).

For example, (poly-funcall '(car number-to-string) '(100)) returns
\"100\"."
  (while functions
    (setq argument (funcall (car functions) argument)
	  functions (cdr functions))
    )
  argument)


;;; @ variables
;;;

(defvar filename-limit-length 21 "Limit size of file-name.")

(defvar filename-replacement-alist
  '(((?\  ?\t) . "_")
    ((?! ?\" ?# ?$ ?% ?& ?' ?\( ?\) ?* ?/
	 ?: ?\; ?< ?> ?? ?\[ ?\\ ?\] ?` ?{ ?| ?}) . "_")
    (filename-control-p . "")
    )
  "Alist list of characters vs. string as replacement.
List of characters represents characters not allowed as file-name.")

(defvar filename-filters
  (let ((filters '(filename-special-filter
		   filename-eliminate-top-low-lines
		   filename-canonicalize-low-lines
		   filename-maybe-truncate-by-size
		   filename-eliminate-bottom-low-lines
		   )))
    (require 'file-detect)
    (if (exec-installed-p "kakasi")
	(cons 'filename-japanese-to-roman-string filters)
      filters))
  "List of functions for file-name filter.")


;;; @ filters
;;;

(defun filename-japanese-to-roman-string (str)
  (save-excursion
    (set-buffer (get-buffer-create " *temp kakasi*"))
    (erase-buffer)
    (insert str)
    (call-process-region (point-min)(point-max) "kakasi" t t t
			 "-Ha" "-Ka" "-Ja" "-Ea" "-ka")
    (buffer-string)
    ))

(defun filename-control-p (character)
  (let ((code (char-int character)))
    (or (< code 32)(= code 127))
    ))

(defun filename-special-filter (string)
  (let (dest
	(i 0)
	(len (length string))
	(b 0)
	)
    (while (< i len)
      (let* ((chr (sref string i))
	     (ret (assoc-if (function
			     (lambda (key)
			       (if (functionp key)
				   (funcall key chr)
				 (memq chr key)
				 )))
			    filename-replacement-alist))
	     )
	(if ret
	    (setq dest (concat dest (substring string b i)(cdr ret))
		  i (+ i (char-length chr))
		  b i)
	  (setq i (+ i (char-length chr)))
	  )))
    (concat dest (substring string b))
    ))

(defun filename-eliminate-top-low-lines (string)
  (if (string-match "^_+" string)
      (substring string (match-end 0))
    string))

(defun filename-canonicalize-low-lines (string)
  (let (dest)
    (while (string-match "__+" string)
      (setq dest (concat dest (substring string 0 (1+ (match-beginning 0)))))
      (setq string (substring string (match-end 0)))
      )
    (concat dest string)
    ))

(defun filename-maybe-truncate-by-size (string)
  (if (and (> (length string) filename-limit-length)
	   (string-match "_" string filename-limit-length)
	   )
      (substring string 0 (match-beginning 0))
    string))

(defun filename-eliminate-bottom-low-lines (string)
  (if (string-match "_+$" string)
      (substring string 0 (match-beginning 0))
    string))


;;; @ interface
;;;

(defun replace-as-filename (string)
  "Return safety filename from STRING.
It refers variable `filename-filters' and default filters refers
`filename-limit-length', `filename-replacement-alist'."
  (and string
       (poly-funcall filename-filters string)
       ))


;;; @ end
;;;

(provide 'filename)

;;; filename.el ends here
