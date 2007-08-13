;;; mime-setup.el --- setup file for tm viewer and composer.

;; Copyright (C) 1995,1996 Free Software Foundation, Inc.

;; Author: MORIOKA Tomohiko <morioka@jaist.ac.jp>
;; Version:
;;	$Id: mime-setup.el,v 1.4 1997/01/30 02:22:47 steve Exp $
;; Keywords: mail, news, MIME, multimedia, multilingual, encoded-word

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

(require 'tm-setup)

(autoload 'mime/editor-mode "tm-edit"
  "Minor mode for editing MIME message." t)
(autoload 'mime/decode-message-header "tm-ew-d"
  "Decode MIME encoded-words in message header." t)

(defun mime-setup-decode-message-header ()
  (save-excursion
    (save-restriction
      (goto-char (point-min))
      (narrow-to-region
       (point-min)
       (if (re-search-forward
	    (concat "^" (regexp-quote mail-header-separator) "$")
	    nil t)
	   (match-beginning 0)
	 (point-max)
	 ))
      (mime/decode-message-header)
      (set-buffer-modified-p nil)
      )))

(add-hook 'mime/editor-mode-hook 'mime-setup-decode-message-header)


;;; @ variables
;;;

(defvar mime-setup-use-sc nil
  "If it is not nil, mime-setup requires sc-setup. [mime-setup.el]")

(defvar mime-setup-use-signature t
  "If it is not nil, mime-setup sets up to use signature.el.
\[mime-setup.el]")

(defvar mime-setup-default-signature-key "\C-c\C-s"
  "*Key to insert signature. [mime-setup.el]")

(defvar mime-setup-signature-key-alist '((mail-mode . "\C-c\C-w"))
  "Alist of major-mode vs. key to insert signature. [mime-setup.el]")


;;; @ for signature
;;;

(defun mime-setup-set-signature-key ()
  (let ((key (or (cdr (assq major-mode mime-setup-signature-key-alist))
		 mime-setup-default-signature-key)))
    (define-key (current-local-map) key (function insert-signature))
    ))

(if mime-setup-use-signature
    (progn
      (autoload 'insert-signature "signature" "Insert signature" t)
      (add-hook 'mime/editor-mode-hook 'mime-setup-set-signature-key)
      (setq gnus-signature-file nil)
      (setq mail-signature nil)
      (setq message-signature nil)
      ))


;;; @ about SuperCite
;;;

(if mime-setup-use-sc
    (require 'sc-setup)
  )


;;; @ for mu-cite
;;;

(add-hook 'mu-cite/pre-cite-hook 'mime/decode-message-header)


;;; @ for RMAIL and VM
;;;

(add-hook 'mail-setup-hook 'mime/decode-message-header)
(add-hook 'mail-setup-hook 'mime/editor-mode 'append)
(add-hook 'mail-send-hook  'mime-editor/maybe-translate)


;;; @ for mh-e
;;;

(defun mime-setup-mh-draft-setting ()
  (mime/editor-mode)
  (make-local-variable 'mail-header-separator)
  (setq mail-header-separator "--------")
  (save-excursion
    (goto-char (point-min))
    (setq buffer-read-only nil)
    (if (re-search-forward "^-*$" nil t)
	(progn
	  (replace-match mail-header-separator)
	  (set-buffer-modified-p (buffer-modified-p))
	  ))
    ))

(add-hook 'mh-letter-mode-hook 'mime-setup-mh-draft-setting t)
(add-hook 'mh-before-send-letter-hook 'mime-editor/maybe-translate)


;;; @ for GNUS
;;;

(add-hook 'news-reply-mode-hook 'mime/editor-mode)
(add-hook 'news-inews-hook      'mime-editor/maybe-translate)


;;; @ for message (September Gnus 0.58 or later)
;;;

(defun message-maybe-setup-default-charset ()
  (let ((charset
	 (and (boundp 'gnus-summary-buffer)
              (buffer-live-p gnus-summary-buffer)
	      (save-excursion
		(set-buffer gnus-summary-buffer)
		default-mime-charset))))
    (if charset
	(progn
	  (make-local-variable 'default-mime-charset)
	  (setq default-mime-charset charset)
	  ))))

(or (boundp 'epoch::version)
    (progn
      (add-hook 'message-setup-hook 'mime/editor-mode)
      (add-hook 'message-setup-hook 'message-maybe-setup-default-charset)
      (add-hook 'message-send-hook  'mime-editor/maybe-translate)
      (add-hook 'message-header-hook 'mime/encode-message-header)
      
      (call-after-loaded
       'message
       (function
	(lambda ()
	  (require 'message-mime)
	  )))
      ))


;;; @ end
;;;

(provide 'mime-setup)

(run-hooks 'mime-setup-load-hook)

;;; mime-setup.el ends here
;;;
;;; Local Variables:
;;; mode: emacs-lisp
;;; End:
