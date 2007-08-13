;;; mel.el : a MIME encoding/decoding library

;; Copyright (C) 1995,1996,1997 Free Software Foundation, Inc.

;; Author: MORIOKA Tomohiko <morioka@jaist.ac.jp>
;; modified by Shuhei KOBAYASHI <shuhei-k@jaist.ac.jp>
;; Created: 1995/6/25
;; Version: $Id: mel.el,v 1.3 1997/03/16 03:05:15 steve Exp $
;; Keywords: MIME, Base64, Quoted-Printable, uuencode, gzip64

;; This file is part of MEL (MIME Encoding Library).

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

;;; @ variable
;;;

(defvar mime-temp-directory (or (getenv "MIME_TMP_DIR")
				(getenv "TM_TMP_DIR")
				"/tmp/")
  "*Directory for temporary files.")


;;; @ region
;;;

(autoload 'base64-encode-region
  "mel-b" "Encode current region by base64." t)
(autoload 'quoted-printable-encode-region
  "mel-q" "Encode current region by Quoted-Printable." t)
(autoload 'uuencode-encode-region
  "mel-u" "Encode current region by unofficial uuencode format." t)
(autoload 'gzip64-encode-region
  "mel-g" "Encode current region by unofficial x-gzip64 format." t)

(defvar mime-encoding-method-alist
  '(("base64"           . base64-encode-region)
    ("quoted-printable" . quoted-printable-encode-region)
    ("x-uue"            . uuencode-encode-region)
    ("x-gzip64"         . gzip64-encode-region)
    ("7bit")
    ("8bit")
    ("binary")
    )
  "Alist of encoding vs. corresponding method to encode region.
Each element looks like (STRING . FUNCTION) or (STRING . nil).
STRING is content-transfer-encoding.
FUNCTION is region encoder and nil means not to encode.")


(autoload 'base64-decode-region
  "mel-b" "Decode current region by base64." t)
(autoload 'quoted-printable-decode-region
  "mel-q" "Decode current region by Quoted-Printable." t)
(autoload 'uuencode-decode-region
  "mel-u" "Decode current region by unofficial uuencode format." t)
(autoload 'gzip64-decode-region
  "mel-g" "Decode current region by unofficial x-gzip64 format." t)

(defvar mime-decoding-method-alist
  '(("base64"           . base64-decode-region)
    ("quoted-printable" . quoted-printable-decode-region)
    ("x-uue"            . uuencode-decode-region)
    ("x-uuencode"       . uuencode-decode-region)
    ("x-gzip64"         . gzip64-decode-region)
    )
  "Alist of encoding vs. corresponding method to decode region.
Each element looks like (STRING . FUNCTION).
STRING is content-transfer-encoding.
FUNCTION is region decoder.")


(defun mime-encode-region (start end encoding)
  "Encode region START to END of current buffer using ENCODING."
  (interactive
   (list (region-beginning) (region-end)
	 (completing-read "encoding: "
			  mime-encoding-method-alist
			  nil t "base64"))
   )
  (let ((f (cdr (assoc encoding mime-encoding-method-alist))))
    (if f
	(funcall f start end)
      )))

(defun mime-decode-region (start end encoding)
  "Decode region START to END of current buffer using ENCODING."
  (interactive
   (list (region-beginning) (region-end)
	 (completing-read "encoding: "
			  mime-decoding-method-alist
			  nil t "base64"))
   )
  (let ((f (cdr (assoc encoding mime-decoding-method-alist))))
    (if f
	(funcall f start end)
      )))


;;; @ file
;;;

(autoload 'base64-insert-encoded-file
  "mel-b" "Insert file encoded by base64." t)
(autoload 'quoted-printable-insert-encoded-file
  "mel-q" "Insert file encoded by quoted-printable." t)
(autoload 'uuencode-insert-encoded-file
  "mel-u" "Insert file encoded by unofficial uuencode format." t)
(autoload 'gzip64-insert-encoded-file
  "mel-g" "Insert file encoded by unofficial gzip64 format." t)

(defvar mime-file-encoding-method-alist
  '(("base64"           . base64-insert-encoded-file)
    ("quoted-printable" . quoted-printable-insert-encoded-file)
    ("x-uue"            . uuencode-insert-encoded-file)
    ("x-gzip64"         . gzip64-insert-encoded-file)
    ("7bit"		. insert-binary-file-contents-literally)
    ("8bit"		. insert-binary-file-contents-literally)
    ("binary"		. insert-binary-file-contents-literally)
    )
  "Alist of encoding vs. corresponding method to insert encoded file.
Each element looks like (STRING . FUNCTION).
STRING is content-transfer-encoding.
FUNCTION is function to insert encoded file.")

(defun mime-insert-encoded-file (filename encoding)
  "Insert file FILENAME encoded by ENCODING format."
  (interactive
   (list (read-file-name "Insert encoded file: ")
	 (completing-read "encoding: "
			  mime-encoding-method-alist
			  nil t "base64"))
   )
  (let ((f (cdr (assoc encoding mime-file-encoding-method-alist))))
    (if f
	(funcall f filename)
      )))


;;; @ string
;;;

(autoload 'base64-encode-string "mel-b")
(autoload 'base64-decode-string "mel-b")

(autoload 'q-encoding-encode-string-for-text "mel-q")
(autoload 'q-encoding-encode-string-for-comment "mel-q")
(autoload 'q-encoding-encode-string-for-phrase "mel-q")
(autoload 'q-encoding-encode-string "mel-q")
(autoload 'q-encoding-decode-string "mel-q")

(autoload 'base64-encoded-length "mel-b")
(autoload 'q-encoding-encoded-length "mel-q")


;;; @ end
;;;

(provide 'mel)

;;; mel.el ends here.
