;;; tm-file.el --- tm-view internal method for file extraction

;; Copyright (C) 1995,1996 Free Software Foundation, Inc.

;; Author: MORIOKA Tomohiko <morioka@jaist.ac.jp>
;; modified by Shuhei KOBAYASHI <shuhei-k@jaist.ac.jp>
;; Version: $Id: tm-file.el,v 1.1.1.1 1996/12/18 03:55:31 steve Exp $
;; Keywords: mail, news, MIME, multimedia, file, extract

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

(require 'tm-view)

(defun mime-article/extract-file (beg end cal)
  (goto-char beg)
  (let* ((name
	  (save-restriction
	    (narrow-to-region beg end)
	    (mime-article/get-filename cal)
	    ))
	 (encoding (cdr (assq 'encoding cal)))
	 (filename
          (if (and name (not (string-equal name "")))
	      (expand-file-name name
				(call-interactively
				 (function
				  (lambda (dir)
				    (interactive "DDirectory: ")
				    dir))))
	    (call-interactively
	     (function
	      (lambda (file)
		(interactive "FFilename: ")
		(expand-file-name file))))))
	 (the-buf (current-buffer))
	 (tmp-buf (generate-new-buffer (file-name-nondirectory filename)))
	 )
    (if (file-exists-p filename)
        (or (yes-or-no-p (format "File %s exists. Save anyway? " filename))
            (error "")))
    (re-search-forward "\n\n")
    (append-to-buffer tmp-buf (match-end 0) end)
    (save-excursion
      (set-buffer tmp-buf)
      (mime-decode-region (point-min)(point-max) encoding)
      (let ((coding-system-for-write 'no-conversion)
	    (mc-flag nil)                   ; for Mule
	    (file-coding-system
	     (if (featurep 'mule) *noconv*))
	    kanji-flag                      ; for NEmacs
	    (emx-binary-mode t)             ; for OS/2
	    jka-compr-compression-info-list ; for jka-compr
	    jam-zcat-filename-list          ; for jam-zcat
	    require-final-newline)
	(write-file filename)
	)
      (kill-buffer tmp-buf)
      )))


;;; @ setup
;;;

(set-atype 'mime/content-decoding-condition
	   '((type . "application/octet-stream")
	     (method . mime-article/extract-file)
	     )
	   'ignore '(method)
	   'replacement)

(set-atype 'mime/content-decoding-condition
	   '((mode . "extract")
	     (method . mime-article/extract-file)
	     )
	   'remove
	   '((method "tm-file"  nil 'file 'type 'encoding 'mode 'name)
	     (mode . "extract"))
	   'replacement)


;;; @ end
;;;

(provide 'tm-file)

;;; end of tm-file.el
