;;; tm-play.el --- decoder for tm-view.el

;; Copyright (C) 1994,1995,1996,1997 Free Software Foundation, Inc.

;; Author: MORIOKA Tomohiko <morioka@jaist.ac.jp>
;; Created: 1995/9/26 (separated from tm-view.el)
;; Version: $Id: tm-play.el,v 1.5 1997/03/28 02:29:06 steve Exp $
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

(require 'tm-view)

  
;;; @ content decoder
;;;

(defvar mime-preview/after-decoded-position nil)

(defun mime-preview/decode-content ()
  (interactive)
  (let ((pc (mime-preview/point-pcinfo (point))))
    (if pc
	(let ((the-buf (current-buffer)))
	  (setq mime-preview/after-decoded-position (point))
	  (set-buffer (mime::preview-content-info/buffer pc))
	  (mime-article/decode-content
	   (mime::preview-content-info/content-info pc))
	  (if (eq (current-buffer)
		  (mime::preview-content-info/buffer pc))
	      (progn
		(set-buffer the-buf)
		(goto-char mime-preview/after-decoded-position)
		))
	  ))))

(defun mime-article/decode-content (cinfo)
  (let ((beg (mime::content-info/point-min cinfo))
	(end (mime::content-info/point-max cinfo))
	(ctype (or (mime::content-info/type cinfo) "text/plain"))
	(params (mime::content-info/parameters cinfo))
	(encoding (mime::content-info/encoding cinfo))
	)
    ;; Check for VM
    (if (< beg (point-min))
	(setq beg (point-min))
      )
    (if (< (point-max) end)
	(setq end (point-max))
      )
    (let (method cal ret)
      (setq cal (list* (cons 'type ctype)
		       (cons 'encoding encoding)
		       (cons 'major-mode major-mode)
		       params))
      (if mime-viewer/decoding-mode
	  (setq cal (cons
		     (cons 'mode mime-viewer/decoding-mode)
		     cal))
	)
      (setq ret (mime/get-content-decoding-alist cal))
      (setq method (cdr (assq 'method ret)))
      (cond ((and (symbolp method)
		  (fboundp method))
	     (funcall method beg end ret)
	     )
	    ((and (listp method)(stringp (car method)))
	     (mime-article/start-external-method-region beg end ret)
	     )
	    (t
	     (mime-article/show-output-buffer
	      "No method are specified for %s\n" ctype)
	     ))
      )
    ))

(defun field-unifier-for-mode (a b)
  (let ((va (cdr a)))
    (if (if (consp va)
	    (member (cdr b) va)
	  (equal va (cdr b))
	  )
	(list nil b nil)
      )))

(defun mime/get-content-decoding-alist (al)
  (get-unified-alist mime/content-decoding-condition al)
  )


;;; @ external decoder
;;;

(defun mime-article/start-external-method-region (beg end cal)
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char beg)
      (let ((method (cdr (assoc 'method cal)))
	    (name (mime-article/get-filename cal))
	    )
	(if method
	    (let ((file (make-temp-name
			 (expand-file-name "TM" mime/tmp-dir)))
		  b args)
	      (if (nth 1 method)
		  (setq b beg)
		(setq b
		      (if (re-search-forward "^$" nil t)
			  (1+ (match-end 0))
			(point-min)
			))
		)
	      (goto-char b)
	      (write-region b end file)
	      (message "External method is starting...")
	      (setq cal (put-alist
			 'name (replace-as-filename name) cal))
	      (setq cal (put-alist 'file file cal))
	      (setq args (nconc
			  (list (car method)
				mime/output-buffer-name (car method)
				)
			  (mime-article/make-method-args cal
							 (cdr (cdr method)))
			  ))
	      (apply (function start-process) args)
	      (mime-article/show-output-buffer)
	      ))
	))))

(defun mime-article/make-method-args (cal format)
  (mapcar (function
	   (lambda (arg)
	     (if (stringp arg)
		 arg
	       (let* ((item (eval arg))
		      (ret (cdr (assoc item cal)))
		      )
		 (if ret
		     ret
		   (if (eq item 'encoding)
		       "7bit"
		     ""))
		 ))
	     ))
	  format))

(defun mime-article/show-output-buffer (&rest forms)
  (get-buffer-create mime/output-buffer-name)
  (let ((the-win (selected-window))
	(win (get-buffer-window mime/output-buffer-name))
	)
    (or win
	(if (and mime/output-buffer-window-is-shared-with-bbdb
		 (boundp 'bbdb-buffer-name)
		 (setq win (get-buffer-window bbdb-buffer-name))
		 )
	    (set-window-buffer win mime/output-buffer-name)
	  (select-window (get-buffer-window mime::article/preview-buffer))
	  (setq win (split-window-vertically (/ (* (window-height) 3) 4)))
	  (set-window-buffer win mime/output-buffer-name)
	  ))
    (select-window win)
    (goto-char (point-max))
    (if forms
	(insert (apply (function format) forms))
      )
    (select-window the-win)
    ))


;;; @ file name
;;;

(defvar mime-viewer/file-name-char-regexp "[A-Za-z0-9+_-]")

(defvar mime-viewer/file-name-regexp-1
  (concat mime-viewer/file-name-char-regexp "+\\."
	  mime-viewer/file-name-char-regexp "+"))

(defvar mime-viewer/file-name-regexp-2
  (concat (regexp-* mime-viewer/file-name-char-regexp)
	  "\\(\\." mime-viewer/file-name-char-regexp "+\\)*"))

(defun mime-article/get-original-filename (param &optional encoding)
  (or (mime-article/get-uu-filename param encoding)
      (let (ret)
	(or (if (or (and (setq ret (mime/Content-Disposition))
			 (setq ret (assoc "filename" (cdr ret)))
			 )
		    (setq ret (assoc "name" param))
		    (setq ret (assoc "x-name" param))
		    )
		(std11-strip-quoted-string (cdr ret))
	      )
	    (if (setq ret
		      (std11-find-field-body '("Content-Description"
					       "Subject")))
		(if (or (string-match mime-viewer/file-name-regexp-1 ret)
			(string-match mime-viewer/file-name-regexp-2 ret))
		    (substring ret (match-beginning 0)(match-end 0))
		  ))
	    ))
      ))

(defun mime-article/get-filename (param)
  (replace-as-filename (mime-article/get-original-filename param))
  )


;;; @ mail/news message
;;;

(defun mime-viewer/quitting-method-for-mime/show-message-mode ()
  (let ((mother mime::preview/mother-buffer)
	(win-conf mime::preview/original-window-configuration)
	)
    (kill-buffer
     (mime::preview-content-info/buffer (car mime::preview/content-list)))
    (mime-viewer/kill-buffer)
    (set-window-configuration win-conf)
    (pop-to-buffer mother)
    ;;(goto-char (point-min))
    ;;(mime-viewer/up-content)
    ))

(defun mime-article/view-message/rfc822 (beg end cal)
  (let* ((cnum (mime-article/point-content-number beg))
	 (cur-buf (current-buffer))
	 (new-name (format "%s-%s" (buffer-name) cnum))
	 (mother mime::article/preview-buffer)
	 (code-converter
	  (or (cdr (assq major-mode mime-viewer/code-converter-alist))
	      'mime-viewer/default-code-convert-region))
	 str)
    (setq str (buffer-substring beg end))
    (switch-to-buffer new-name)
    (erase-buffer)
    (insert str)
    (goto-char (point-min))
    (if (re-search-forward "^\n" nil t)
	(delete-region (point-min) (match-end 0))
      )
    (setq major-mode 'mime/show-message-mode)
    (setq mime::article/code-converter code-converter)
    (mime/viewer-mode mother)
    ))


;;; @ message/partial
;;;

(defvar mime-article/coding-system-alist
  (list (cons 'mh-show-mode *noconv*)
	(cons t (mime-charset-to-coding-system default-mime-charset))
	))

(cond ((boundp 'MULE) ; for MULE 2.3 or older
       (defun mime-article::write-region (start end file)
	 (let ((file-coding-system
		(cdr
		 (or (assq major-mode mime-article/coding-system-alist)
		     (assq t mime-article/coding-system-alist)
		     ))))
	   (write-region start end file)
	   ))
       )
      ((featurep 'mule) ; for Emacs/mule and XEmacs/mule
       (defun mime-article::write-region (start end file)
	 (let ((coding-system-for-write
		(cdr
		 (or (assq major-mode mime-article/coding-system-alist)
		     (assq t mime-article/coding-system-alist)
		     ))))
	   (write-region start end file)
	   ))
       )
      ((boundp 'NEMACS) ; for NEmacs
       (defun mime-article::write-region (start end file)
	 (let ((kanji-fileio-code
		(cdr
		 (or (assq major-mode mime-article/kanji-code-alist)
		     (assq t mime-article/kanji-code-alist)
		     ))))
	   (write-region start end file)
	   ))
       )
      (t ; for Emacs 19 or older and XEmacs without mule
       (defalias 'mime-article::write-region 'write-region)
       ))

(defun mime-article/decode-message/partial (beg end cal)
  (goto-char beg)
  (let* ((root-dir (expand-file-name
		    (concat "m-prts-" (user-login-name)) mime/tmp-dir))
	 (id (cdr (assoc "id" cal)))
	 (number (cdr (assoc "number" cal)))
	 (total (cdr (assoc "total" cal)))
	 file
	 (mother mime::article/preview-buffer)
         )
    (or (file-exists-p root-dir)
	(make-directory root-dir)
	)
    (setq id (replace-as-filename id))
    (setq root-dir (concat root-dir "/" id))
    (or (file-exists-p root-dir)
	(make-directory root-dir)
	)
    (setq file (concat root-dir "/FULL"))
    (if (file-exists-p file)
	(let ((full-buf (get-buffer-create "FULL"))
	      (pwin (or (get-buffer-window mother)
			(get-largest-window)))
	      )
	  (save-window-excursion
	    (set-buffer full-buf)
	    (erase-buffer)
	    (as-binary-input-file (insert-file-contents file))
	    (setq major-mode 'mime/show-message-mode)
	    (mime/viewer-mode mother)
	    )
	  (set-window-buffer pwin
			     (save-excursion
			       (set-buffer full-buf)
			       mime::article/preview-buffer))
	  (select-window pwin)
	  )
      (re-search-forward "^$")
      (goto-char (1+ (match-end 0)))
      (setq file (concat root-dir "/" number))
      (mime-article::write-region (point) (point-max) file)
      (let ((total-file (concat root-dir "/CT")))
	(setq total
	      (if total
		  (progn
		    (or (file-exists-p total-file)
			(save-excursion
			  (set-buffer
			   (get-buffer-create mime/temp-buffer-name))
			  (erase-buffer)
			  (insert total)
			  (write-file total-file)
			  (kill-buffer (current-buffer))
			  ))
		    (string-to-number total)
		    )
		(and (file-exists-p total-file)
		     (save-excursion
		       (set-buffer (find-file-noselect total-file))
		       (prog1
			   (and (re-search-forward "[0-9]+" nil t)
				(string-to-number
				 (buffer-substring (match-beginning 0)
						   (match-end 0)))
				)
			 (kill-buffer (current-buffer))
			 )))
		)))
      (if (and total (> total 0))
	  (catch 'tag
	    (save-excursion
	      (set-buffer (get-buffer-create mime/temp-buffer-name))
	      (let ((full-buf (current-buffer)))
		(erase-buffer)
		(let ((i 1))
		  (while (<= i total)
		    (setq file (concat root-dir "/" (int-to-string i)))
		    (or (file-exists-p file)
			(throw 'tag nil)
			)
		    (as-binary-input-file (insert-file-contents file))
		    (goto-char (point-max))
		    (setq i (1+ i))
		    ))
		(as-binary-output-file (write-file (concat root-dir "/FULL")))
		(let ((i 1))
		  (while (<= i total)
		    (let ((file (format "%s/%d" root-dir i)))
		      (and (file-exists-p file)
			   (delete-file file)
			   ))
		    (setq i (1+ i))
		    ))
		(let ((file (expand-file-name "CT" root-dir)))
		  (and (file-exists-p file)
		       (delete-file file)
		       ))
		(save-window-excursion
		  (setq major-mode 'mime/show-message-mode)
		  (mime/viewer-mode mother)
		  )
		(let ((pwin (or (get-buffer-window mother)
				(get-largest-window)
				))
		      (pbuf (save-excursion
			      (set-buffer full-buf)
			      mime::article/preview-buffer)))
		  (set-window-buffer pwin pbuf)
		  (select-window pwin)
		  )))))
      )))


;;; @ rot13-47
;;;

(unless (boundp 'view-mode-map)
  (require 'view))

(defconst mime-view-text/plain-mode-map (copy-keymap view-mode-map))
(define-key mime-view-text/plain-mode-map
  "q" (function mime-view-text/plain-exit))

(defun mime-view-text/plain-mode ()
  "\\{mime-view-text/plain-mode-map}"
  (setq buffer-read-only t)
  (setq major-mode 'mime-view-text/plain-mode)
  (setq mode-name "MIME-View text/plain")
  (use-local-map mime-view-text/plain-mode-map)
  )

(defun mime-view-text/plain-exit ()
  (interactive)
  (kill-buffer (current-buffer))
  )

(defun mime-article/decode-caesar (beg end cal)
  (let* ((cnum (mime-article/point-content-number beg))
	 (cur-buf (current-buffer))
	 (new-name (format "%s-%s" (buffer-name) cnum))
	 (mother mime::article/preview-buffer)
	 (charset (cdr (assoc "charset" cal)))
	 (encoding (cdr (assq 'encoding cal)))
	 (mode major-mode)
	 str)
    (setq str (buffer-substring beg end))
    (let ((pwin (or (get-buffer-window mother)
		    (get-largest-window)))
	  (buf (get-buffer-create new-name))
	  )
      (set-window-buffer pwin buf)
      (set-buffer buf)
      (select-window pwin)
      )
    (setq buffer-read-only nil)
    (erase-buffer)
    (insert str)
    (goto-char (point-min))
    (if (re-search-forward "^\n" nil t)
	(delete-region (point-min) (match-end 0))
      )
    (let ((m (cdr (or (assq mode mime-viewer/code-converter-alist)
		      (assq t mime-viewer/code-converter-alist)))))
      (and (functionp m)
	   (funcall m charset encoding)
	   ))
    (save-excursion
      (set-mark (point-min))
      (goto-char (point-max))
      (tm:caesar-region)
      )
    (set-buffer-modified-p nil)
    (mime-view-text/plain-mode)
    ))


;;; @ end
;;;

(provide 'tm-play)

;;; tm-play.el ends here
