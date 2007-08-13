;;;
;;; richtext.el -- read and save files in text/richtext format
;;;
;;; Copyright (C) 1995 Free Software Foundation, Inc.
;;; Copyright (C) 1995 MORIOKA Tomohiko
;;;
;;; Author: MORIOKA Tomohiko <morioka@jaist.ac.jp>
;;; Created: 1995/7/15
;;; Version:
;;;	$Id: richtext.el,v 1.1.1.1 1996/12/18 03:55:31 steve Exp $
;;; Keywords: wp, faces, MIME, multimedia
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

(require 'enriched)


;;; @ variables
;;;

(defconst richtext-initial-annotation
  (lambda ()
    (format "Content-Type: text/richtext\nText-Width: %d\n\n"
	    (enriched-text-width)))
  "What to insert at the start of a text/richtext file.
If this is a string, it is inserted.  If it is a list, it should be a lambda
expression, which is evaluated to get the string to insert.")

(defconst richtext-annotation-regexp
  "[ \t\n]*\\(<\\(/\\)?\\([-A-za-z0-9]+\\)>\\)[ \t\n]*"
  "Regular expression matching richtext annotations.")

(defconst richtext-translations
  '((face          (bold-italic "bold" "italic")
		   (bold        "bold")
		   (italic      "italic")
		   (underline   "underline")
		   (fixed       "fixed")
		   (excerpt     "excerpt")
		   (default     )
		   (nil         enriched-encode-other-face))
    (invisible     (t           "comment"))
    (left-margin   (4           "indent"))
    (right-margin  (4           "indentright"))
    (justification (right       "flushright")
		   (left        "flushleft")
		   (full        "flushboth")
		   (center      "center")) 
    ;; The following are not part of the standard:
    (FUNCTION      (enriched-decode-foreground "x-color")
		   (enriched-decode-background "x-bg-color"))
    (read-only     (t           "x-read-only"))
    (unknown       (nil         format-annotate-value))
;   (font-size     (2           "bigger")       ; unimplemented
;		   (-2          "smaller"))
)
  "List of definitions of text/richtext annotations.
See `format-annotate-region' and `format-deannotate-region' for the definition
of this structure.")


;;; @ encoder
;;;

(defun richtext-encode (from to)
  (if enriched-verbose (message "Richtext: encoding document..."))
  (save-restriction
    (narrow-to-region from to)
    (delete-to-left-margin)
    (unjustify-region)
    (goto-char from)
    (format-replace-strings '(("<" . "<lt>")))
    (format-insert-annotations 
     (format-annotate-region from (point-max) richtext-translations
			     'enriched-make-annotation enriched-ignore))
    (goto-char from)
    (insert (if (stringp enriched-initial-annotation)
		richtext-initial-annotation
	      (funcall richtext-initial-annotation)))
    (enriched-map-property-regions 'hard
      (lambda (v b e)
	(goto-char b)
	(if (eolp)
	    (while (search-forward "\n" nil t)
	      (replace-match "<nl>\n")
	      )))
      (point) nil)
    (if enriched-verbose (message nil))
    ;; Return new end.
    (point-max)))


;;; @ decoder
;;;

(defun richtext-next-annotation ()
  "Find and return next text/richtext annotation.
Return value is \(begin end name positive-p), or nil if none was found."
  (catch 'tag
    (while (re-search-forward richtext-annotation-regexp nil t)
      (let* ((beg0 (match-beginning 0))
	     (end0 (match-end 0))
	     (beg  (match-beginning 1))
	     (end  (match-end 1))
	     (name (downcase (buffer-substring 
			      (match-beginning 3) (match-end 3))))
	     (pos (not (match-beginning 2)))
	     )
	(cond ((equal name "lt")
	       (delete-region beg end)
	       (goto-char beg)
	       (insert "<")
	       )
	      ((equal name "comment")
	       (if pos
		   (throw 'tag (list beg0 end name pos))
		 (throw 'tag (list beg end0 name pos))
		 )
	       )
	      (t
	       (throw 'tag (list beg end name pos))
	       ))
	))))

(defun richtext-decode (from to)
  (if enriched-verbose (message "Richtext: decoding document..."))
  (save-excursion
    (save-restriction
      (narrow-to-region from to)
      (goto-char from)
      (let ((file-width (enriched-get-file-width))
	    (use-hard-newlines t) pc nc)
	(enriched-remove-header)
	
	(goto-char from)
	(while (re-search-forward "\n\n+" nil t)
	  (replace-match "\n")
	  )
	
	;; Deal with newlines
	(goto-char from)
	(while (re-search-forward "[ \t\n]*<nl>[ \t\n]*" nil t)
	  (replace-match "\n")
	  (put-text-property (match-beginning 0) (point) 'hard t)
	  (put-text-property (match-beginning 0) (point) 'front-sticky nil)
	  )
	
	;; Translate annotations
	(format-deannotate-region from (point-max) richtext-translations
				  'richtext-next-annotation)

	;; Fill paragraphs
	(if (or (and file-width		; possible reasons not to fill:
		     (= file-width (enriched-text-width))) ; correct wd.
		(null enriched-fill-after-visiting) ; never fill
		(and (eq 'ask enriched-fill-after-visiting) ; asked & declined
		     (not (y-or-n-p "Re-fill for current display width? "))))
	    ;; Minimally, we have to insert indentation and justification.
	    (enriched-insert-indentation)
	  (if enriched-verbose (message "Filling paragraphs..."))
	  (fill-region (point-min) (point-max))))
      (if enriched-verbose (message nil))
      (point-max))))


;;; @ end
;;;

(provide 'richtext)