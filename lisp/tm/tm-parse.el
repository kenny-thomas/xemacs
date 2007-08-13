;;; tm-parse.el --- MIME message parser

;; Copyright (C) 1994,1995,1996 Free Software Foundation, Inc.

;; Author: MORIOKA Tomohiko <morioka@jaist.ac.jp>
;; Version: $Id: tm-parse.el,v 1.1.1.1 1996/12/18 22:43:37 steve Exp $
;; Keywords: mail, news, MIME, multimedia

;; This file is part of tm (Tools for MIME).

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

(require 'tl-822)
(require 'tl-misc)
(require 'tm-def)


;;; @ field parser
;;;

(defconst mime/content-parameter-value-regexp
  (concat "\\("
	  rfc822/quoted-string-regexp
	  "\\|[^; \t\n]*\\)"))

(defconst mime::parameter-regexp
  (concat "^[ \t]*\;[ \t]*\\(" mime/token-regexp "\\)"
	  "[ \t]*=[ \t]*\\(" mime/content-parameter-value-regexp "\\)"))

(defun mime/parse-parameter (str)
  (if (string-match mime::parameter-regexp str)
      (let ((e (match-end 2)))
	(cons
	 (cons (downcase (substring str (match-beginning 1) (match-end 1)))
	       (std11-strip-quoted-string
		(substring str (match-beginning 2) e))
	       )
	 (substring str e)
	 ))))

(defconst mime::ctype-regexp (concat "^" mime/content-type-subtype-regexp))

(defun mime/parse-Content-Type (string)
  "Parse STRING as field-body of Content-Type field. [tm-parse.el]"
  (setq string (std11-unfold-string string))
  (if (string-match mime::ctype-regexp string)
      (let* ((e (match-end 0))
	     (ctype (downcase (substring string 0 e)))
	     ret dest)
	(setq string (substring string e))
	(while (setq ret (mime/parse-parameter string))
	  (setq dest (cons (car ret) dest)
		string (cdr ret))
	  )
	(cons ctype (nreverse dest))
	)))

(defconst mime::dtype-regexp (concat "^" mime/disposition-type-regexp))

(defun mime/parse-Content-Disposition (string)
  "Parse STRING as field-body of Content-Disposition field. [tm-parse.el]"
  (setq string (std11-unfold-string string))
  (if (string-match mime::dtype-regexp string)
      (let* ((e (match-end 0))
	     (ctype (downcase (substring string 0 e)))
	     ret dest)
	(setq string (substring string e))
	(while (setq ret (mime/parse-parameter string))
	  (setq dest (cons (car ret) dest)
		string (cdr ret))
	  )
	(cons ctype (nreverse dest))
	)))


;;; @ field reader
;;;

(defun mime/Content-Type ()
  "Read field-body of Content-Type field from current-buffer,
and return parsed it. [tm-parse.el]"
  (let ((str (std11-field-body "Content-Type")))
    (if str
	(mime/parse-Content-Type str)
      )))

(defun mime/Content-Transfer-Encoding (&optional default-encoding)
  "Read field-body of Content-Transfer-Encoding field from
current-buffer, and return it.
If is is not found, return DEFAULT-ENCODING. [tm-parse.el]"
  (let ((str (std11-field-body "Content-Transfer-Encoding")))
    (if str
	(progn
	  (if (string-match "[ \t\n\r]+$" str)
	      (setq str (substring str 0 (match-beginning 0)))
	    )
	  (downcase str)
	  )
      default-encoding)
    ))

(defun mime/Content-Disposition ()
  "Read field-body of Content-Disposition field from current-buffer,
and return parsed it. [tm-parse.el]"
  (let ((str (std11-field-body "Content-Disposition")))
    (if str
	(mime/parse-Content-Disposition str)
      )))


;;; @ message parser
;;;

(define-structure mime::content-info
  rcnum point-min point-max type parameters encoding children)


(defun mime/parse-multipart (boundary ctype params encoding rcnum)
  (goto-char (point-min))
  (let* ((dash-boundary   (concat "--" boundary))
	 (delimiter       (concat "\n" (regexp-quote dash-boundary)))
	 (close-delimiter (concat delimiter "--[ \t]*$"))
	 (beg (point-min))
	 (end (progn
		(goto-char (point-max))
		(if (re-search-backward close-delimiter nil t)
		    (match-beginning 0)
		  (point-max)
		  )))
	 (rsep (concat delimiter "[ \t]*\n"))
	 (dc-ctl
	  (if (string-equal ctype "multipart/digest")
	      '("message/rfc822")
	    '("text/plain")
	    ))
	 cb ce ct ret ncb children (i 0))
    (save-restriction
      (narrow-to-region beg end)
      (goto-char beg)
      (re-search-forward rsep nil t)
      (setq cb (match-end 0))
      (while (re-search-forward rsep nil t)
	(setq ce (match-beginning 0))
	(setq ncb (match-end 0))
	(save-restriction
	  (narrow-to-region cb ce)
	  (setq ret (mime/parse-message dc-ctl "7bit" (cons i rcnum)))
	  )
	(setq children (cons ret children))
	(goto-char (mime::content-info/point-max ret))
	(goto-char (setq cb ncb))
	(setq i (1+ i))
	)
      (setq ce (point-max))
      (save-restriction
	(narrow-to-region cb ce)
	(setq ret (mime/parse-message dc-ctl "7bit" (cons i rcnum)))
	)
      (setq children (cons ret children))
      )
    (mime::content-info/create rcnum beg (point-max)
			       ctype params encoding
			       (nreverse children))
    ))

(defun mime/parse-message (&optional ctl encoding rcnum)
  "Parse current-buffer as a MIME message. [tm-parse.el]"
  (setq ctl (or (mime/Content-Type) ctl))
  (setq encoding (or (mime/Content-Transfer-Encoding) encoding))
  (let ((ctype (car ctl))
	(params (cdr ctl))
	)
    (let ((boundary (assoc "boundary" params)))
      (cond (boundary
	     (setq boundary (std11-strip-quoted-string (cdr boundary)))
	     (mime/parse-multipart boundary ctype params encoding rcnum)
	     )
	    ((or (string-equal ctype "message/rfc822")
		 (string-equal ctype "message/news")
		 )
	     (goto-char (point-min))
	     (mime::content-info/create rcnum
					(point-min) (point-max)
					ctype params encoding
					(save-restriction
					  (narrow-to-region
					   (if (re-search-forward "^$" nil t)
					       (1+ (match-end 0))
					     (point-min)
					     )
					   (point-max))
					  (list (mime/parse-message
						 nil nil (cons 0 rcnum)))
					  )
					)
	     )
	    (t 
	     (mime::content-info/create rcnum (point-min) (point-max)
					ctype params encoding nil)
	     ))
      )))


;;; @ end
;;;

(provide 'tm-parse)

;;; tm-parse.el ends here
