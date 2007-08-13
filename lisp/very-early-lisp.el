;;; very-early-lisp.el --- Lisp support always needed by temacs

;; Copyright (C) 1998 by Free Software Foundation, Inc.

;; Author: SL Baur <steve@altair.xemacs.org>
;;  Michael Sperber [Mr. Preprocessor] <sperber@Informatik.Uni-Tuebingen.De>
;; Keywords: internal, dumped

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
;; along with XEmacs; see the file COPYING.  If not, write to the Free
;; Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
;; 02111-1307, USA.

;;; Synched up with: Not in FSF

;;; Commentary:

;; This file must be loaded by temacs if temacs is to process bytecode
;; or dumped-lisp.el files.

;;; Code:

(define-function 'defalias 'define-function)

;;; Macros from Michael Sperber to replace read-time Lisp reader macros #-, #+
;;; ####fixme duplicated in make-docfile.el and update-elc.el
(defmacro assemble-list (&rest components)
  "Assemble a list from COMPONENTS.
This is a poor man's backquote:
COMPONENTS is a list, each element of which is macro-expanded.
Each macro-expanded element either has the form (SPLICE stuff),
in which case stuff must be a list which is spliced into the result.
Otherwise, the component becomes an element of the list."
  (cons
   'append
   (mapcar #'(lambda (component)
	       (let ((component (macroexpand-internal component)))
		 (if (and (consp component)
			  (eq 'splice (car component)))
		     (car (cdr component))
		   (list 'list component))))
	   components)))

(defmacro when-feature (feature stuff)
  "Insert STUFF as a list element if FEATURE is a loaded feature.
This is intended for use as a component of ASSEMBLE-LIST."
  (list 'splice
	(if (featurep feature)
	    (list 'list stuff)
	  '())))

(defmacro unless-feature (feature stuff)
  "Insert STUFF as a list element if FEATURE is NOT a loaded feature.
This is intended for use as a component of ASSEMBLE-LIST."
  (list 'splice
	(if (featurep feature)
	    '()
	  (list 'list stuff))))

(provide 'very-early-lisp)

;;; very-early-lisp.el ends here
