;;; console.el --- miscellaneous console functions not written in C

;;;; Copyright (C) 1994, 1995 Board of Trustees, University of Illinois
;;;; Copyright (C) 1995, 1996 Ben Wing

;; Keywords: internal

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
;; Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Synched up with: Not in FSF.

(defun quit-char (&optional console)
  "Return the character that causes a QUIT to happen.
This is normally C-g.  Optional arg CONSOLE specifies the console
that the information is returned for; nil means the current console."
  (nth 3 (current-input-mode console)))
