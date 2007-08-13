;;; tm-def.el --- definition module for tm

;; Copyright (C) 1995,1996,1997 Free Software Foundation, Inc.

;; Author: MORIOKA Tomohiko <morioka@jaist.ac.jp>
;; Version: $Id: tm-def.el,v 1.6 1997/04/10 05:55:52 steve Exp $
;; Keywords: mail, news, MIME, multimedia, definition

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

(require 'emu)


;;; @ variables
;;;

(defvar mime/tmp-dir (or (getenv "TM_TMP_DIR") "/tmp/"))

(defvar mime/use-multi-frame
  (and (>= emacs-major-version 19) window-system))

(defvar mime/find-file-function
  (if mime/use-multi-frame
      (function find-file-other-frame)
    (function find-file)
    ))

(defvar mime/output-buffer-window-is-shared-with-bbdb t
  "*If t, mime/output-buffer window is shared with BBDB window.")


;;; @ constants
;;;

(defconst mime/output-buffer-name "*MIME-out*")
(defconst mime/temp-buffer-name " *MIME-temp*")


;;; @ charset and encoding
;;;

(defvar mime-charset-type-list
  '((us-ascii		7 nil)
    (iso-8859-1		8 "quoted-printable")
    (iso-8859-2		8 "quoted-printable")
    (iso-8859-3		8 "quoted-printable")
    (iso-8859-4		8 "quoted-printable")
    (iso-8859-5		8 "quoted-printable")
    (koi8-r		8 "quoted-printable")
    (iso-8859-7		8 "quoted-printable")
    (iso-8859-8		8 "quoted-printable")
    (iso-8859-9		8 "quoted-printable")
    (iso-2022-jp	7 "base64")
    (iso-2022-kr	7 "base64")
    (euc-kr		8 "base64")
    (gb2312		8 "quoted-printable")
    (big5		8 "base64")
    (iso-2022-jp-2	7 "base64")
    (iso-2022-int-1	7 "base64")
    ))

(defun mime/encoding-name (transfer-level &optional not-omit)
  (cond ((> transfer-level 8) "binary")
	((= transfer-level 8) "8bit")
	(not-omit "7bit")
	))

(defun mime/make-charset-default-encoding-alist (transfer-level)
  (mapcar (function
	   (lambda (charset-type)
	     (let ((charset  (upcase (symbol-name (car charset-type))))
		   (type     (nth 1 charset-type))
		   (encoding (nth 2 charset-type))
		   )
	       (if (<= type transfer-level)
		   (cons charset (mime/encoding-name type))
		 (cons charset encoding)
		 ))))
	  mime-charset-type-list))


;;; @ button
;;;

(defun tm:set-face-region (b e face)
  (let ((overlay (make-overlay b e)))
    (overlay-put overlay 'face face)
    ))

(defvar tm:button-face 'bold
  "Face used for content-button or URL-button of MIME-Preview buffer.
\[tm-def.el]")

(defvar tm:mouse-face 'highlight
  "Face used for MIME-preview buffer mouse highlighting. [tm-def.el]")

(defvar tm:warning-face nil
  "Face used for invalid encoded-word.")

(defun tm:add-button (from to func &optional data)
  "Create a button between FROM and TO with callback FUNC and data DATA."
  (and tm:button-face
       (overlay-put (make-overlay from to) 'face tm:button-face))
  (add-text-properties from to
		       (append (and tm:mouse-face
				    (list 'mouse-face tm:mouse-face))
			       (list 'tm-callback func)
			       (and data (list 'tm-data data))
			       ))
  )

(defvar tm:mother-button-dispatcher nil)

(defun tm:button-dispatcher (event)
  "Select the button under point."
  (interactive "e")
  (let (buf point func data)
    (save-window-excursion
      (mouse-set-point event)
      (setq buf (current-buffer)
	    point (point)
	    func (get-text-property (point) 'tm-callback)
	    data (get-text-property (point) 'tm-data)
	    )
      )
    (save-excursion
      (set-buffer buf)
      (goto-char point)
      (if func
	  (apply func data)
	(if (fboundp tm:mother-button-dispatcher)
	    (funcall tm:mother-button-dispatcher event)
	  )
	))))


;;; @ for URL
;;;

(defvar tm:URL-regexp
  "\\(http\\|ftp\\|file\\|gopher\\|news\\|telnet\\|wais\\|mailto\\):\\(//[-a-zA-Z0-9_.]+:[0-9]*\\)?[-a-zA-Z0-9_=?#$@~`%&*+|\\/.,]*[-a-zA-Z0-9_=#$@~`%&*+|\\/]")

(defvar browse-url-browser-function nil)

(defun tm:browse-url (&optional url)
  (if (fboundp browse-url-browser-function)
      (if url 
        (funcall browse-url-browser-function url)
      (call-interactively browse-url-browser-function))
    (if (fboundp tm:mother-button-dispatcher)
	(call-interactively tm:mother-button-dispatcher)
      )
    ))


;;; @ PGP
;;;

(defvar pgp-function-alist
  '(
    ;; for tm-pgp
    (verify		mc-verify			"mc-toplev")
    (decrypt		mc-decrypt			"mc-toplev")
    (fetch-key		mc-pgp-fetch-key		"mc-pgp")
    (snarf-keys		mc-snarf-keys			"mc-toplev")
    ;; for tm-edit
    (mime-sign		tm:mc-pgp-sign-region		"tm-edit-mc")
    (traditional-sign	mc-pgp-sign-region		"mc-pgp")
    (encrypt		tm:mc-pgp-encrypt-region	"tm-edit-mc")
    (insert-key		mc-insert-public-key		"mc-toplev")
    )
  "Alist of service names vs. corresponding functions and its filenames.
Each element looks like (SERVICE FUNCTION FILE).

SERVICE is a symbol of PGP processing.  It allows `verify', `decrypt',
`fetch-key', `snarf-keys', `mime-sign', `traditional-sign', `encrypt'
or `insert-key'.

Function is a symbol of function to do specified SERVICE.

FILE is string of filename which has definition of corresponding
FUNCTION.")

(defmacro pgp-function (method)
  "Return function to do service METHOD."
  (` (car (cdr (assq (, method) (symbol-value 'pgp-function-alist)))))
  )

(mapcar (function
	 (lambda (method)
	   (autoload (second method)(third method))
	   ))
	pgp-function-alist)


;;; @ definitions about MIME
;;;

(defconst mime/tspecials "][\000-\040()<>@,\;:\\\"/?.=")
(defconst mime/token-regexp (concat "[^" mime/tspecials "]+"))
(defconst mime/charset-regexp mime/token-regexp)

(defconst mime/content-type-subtype-regexp
  (concat mime/token-regexp "/" mime/token-regexp))

(defconst mime/disposition-type-regexp mime/token-regexp)


;;; @@ Base64
;;;

(defconst base64-token-regexp "[A-Za-z0-9+/]")
(defconst base64-token-padding-regexp "[A-Za-z0-9+/=]")

(defconst mime/B-encoded-text-regexp
  (concat "\\(\\("
	  base64-token-regexp
	  base64-token-regexp
	  base64-token-regexp
	  base64-token-regexp
	  "\\)*"
	  base64-token-regexp
	  base64-token-regexp
	  base64-token-padding-regexp
	  base64-token-padding-regexp
          "\\)"))

(defconst mime/B-encoding-and-encoded-text-regexp
  (concat "\\(B\\)\\?" mime/B-encoded-text-regexp))


;;; @@ Quoted-Printable
;;;

(defconst quoted-printable-hex-chars "0123456789ABCDEF")
(defconst quoted-printable-octet-regexp
  (concat "=[" quoted-printable-hex-chars
	  "][" quoted-printable-hex-chars "]"))

(defconst mime/Q-encoded-text-regexp
  (concat "\\([^=?]\\|" quoted-printable-octet-regexp "\\)+"))
(defconst mime/Q-encoding-and-encoded-text-regexp
  (concat "\\(Q\\)\\?" mime/Q-encoded-text-regexp))


;;; @ rot13-47
;;;
;; caesar-region written by phr@prep.ai.mit.edu  Nov 86
;; modified by tower@prep Nov 86
;; gnus-caesar-region
;; Modified by umerin@flab.flab.Fujitsu.JUNET for ROT47.
(defun tm:caesar-region (&optional n)
  "Caesar rotation of region by N, default 13, for decrypting netnews.
ROT47 will be performed for Japanese text in any case."
  (interactive (if current-prefix-arg	; Was there a prefix arg?
		   (list (prefix-numeric-value current-prefix-arg))
		 (list nil)))
  (cond ((not (numberp n)) (setq n 13))
	(t (setq n (mod n 26))))	;canonicalize N
  (if (not (zerop n))		; no action needed for a rot of 0
      (progn
	(if (or (not (boundp 'caesar-translate-table))
		(/= (aref caesar-translate-table ?a) (+ ?a n)))
	    (let ((i 0) (lower "abcdefghijklmnopqrstuvwxyz") upper)
	      (message "Building caesar-translate-table...")
	      (setq caesar-translate-table (make-vector 256 0))
	      (while (< i 256)
		(aset caesar-translate-table i i)
		(setq i (1+ i)))
	      (setq lower (concat lower lower) upper (upcase lower) i 0)
	      (while (< i 26)
		(aset caesar-translate-table (+ ?a i) (aref lower (+ i n)))
		(aset caesar-translate-table (+ ?A i) (aref upper (+ i n)))
		(setq i (1+ i)))
	      ;; ROT47 for Japanese text.
	      ;; Thanks to ichikawa@flab.fujitsu.junet.
	      (setq i 161)
	      (let ((t1 (logior ?O 128))
		    (t2 (logior ?! 128))
		    (t3 (logior ?~ 128)))
		(while (< i 256)
		  (aset caesar-translate-table i
			(let ((v (aref caesar-translate-table i)))
			  (if (<= v t1) (if (< v t2) v (+ v 47))
			    (if (<= v t3) (- v 47) v))))
		  (setq i (1+ i))))
	      (message "Building caesar-translate-table...done")))
	(let ((from (region-beginning))
	      (to (region-end))
	      (i 0) str len)
	  (setq str (buffer-substring from to))
	  (setq len (length str))
	  (while (< i len)
	    (aset str i (aref caesar-translate-table (aref str i)))
	    (setq i (1+ i)))
	  (goto-char from)
	  (delete-region from to)
	  (insert str)))))


;;; @ field
;;;

(defun tm:set-fields (sym field-list &optional regexp-sym)
  (or regexp-sym
      (setq regexp-sym
	    (let ((name (symbol-name sym)))
	      (intern
	       (concat (if (string-match "\\(.*\\)-list" name)
			   (substring name 0 (match-end 1))
			 name)
		       "-regexp")
	       )))
      )
  (set sym field-list)
  (set regexp-sym
       (concat "^" (apply (function regexp-or) field-list) ":"))
  )

(defun tm:add-fields (sym field-list &optional regexp-sym)
  (or regexp-sym
      (setq regexp-sym
	    (let ((name (symbol-name sym)))
	      (intern
	       (concat (if (string-match "\\(.*\\)-list" name)
			   (substring name 0 (match-end 1))
			 name)
		       "-regexp")
	       )))
      )
  (let ((fields (eval sym)))
    (mapcar (function
	     (lambda (field)
	       (or (member field fields)
		   (setq fields (cons field fields))
		   )
	       ))
	    (reverse field-list)
	    )
    (set regexp-sym
	 (concat "^" (apply (function regexp-or) fields) ":"))
    (set sym fields)
    ))

(defun tm:delete-fields (sym field-list &optional regexp-sym)
  (or regexp-sym
      (setq regexp-sym
	    (let ((name (symbol-name sym)))
	      (intern
	       (concat (if (string-match "\\(.*\\)-list" name)
			   (substring name 0 (match-end 1))
			 name)
		       "-regexp")
	       )))
      )
  (let ((fields (eval sym)))
    (mapcar (function
	     (lambda (field)
	       (setq fields (delete field fields))
	       ))
	    field-list)
    (set regexp-sym
	 (concat "^" (apply (function regexp-or) fields) ":"))
    (set sym fields)
    ))


;;; @ end
;;;

(provide 'tm-def)

;;; tm-def.el ends here
