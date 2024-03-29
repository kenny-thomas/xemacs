;;; font.el --- New font model

;; Copyright (c) 1995, 1996 by William M. Perry (wmperry@cs.indiana.edu)
;; Copyright (c) 1996, 1997, 2013 Free Software Foundation, Inc.
;; Copyright (C) 2002, 2004 Ben Wing.

;; Author: wmperry
;; Maintainer: XEmacs Development Team
;; Created: 1997/09/05 15:44:37
;; Keywords: faces
;; Version: 1.52

;; This file is part of XEmacs.

;; XEmacs is free software: you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the
;; Free Software Foundation, either version 3 of the License, or (at your
;; option) any later version.

;; XEmacs is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.

;; You should have received a copy of the GNU General Public License
;; along with XEmacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Synched up with: Not in FSF

;;; Commentary:

;; This file is totally bogus in the context of Emacs.  Much of what it does
;; is really in the provice of faces (for example all the style parameters),
;; and that's the way it is in GNU Emacs.
;;
;; What is needed for fonts at the Lisp level is a consistent way to access
;; face properties that are actually associated with fonts for some rendering
;; engine, in other words, the kinds of facilities provided by fontconfig
;; patterns.  We just need to provide an interface to looking up, storing,
;; and manipulating font specifications with certain properties.  There will
;; be some engine-specific stuff, like the bogosity of X11's character set
;; registries.

;;; Code:

(globally-declare-fboundp
 '(internal-facep fontsetp get-font-info
   get-fontset-info mswindows-define-rgb-color cancel-function-timers
   mswindows-font-regexp mswindows-canonicalize-font-name
   mswindows-parse-font-style mswindows-construct-font-style
   fc-pattern-get-family fc-pattern-get-size fc-pattern-get-weight
   fc-font-weight-translate-from-constant make-fc-pattern
   fc-pattern-add-family fc-pattern-add-size))

(globally-declare-boundp
 '(global-face-data
   x-font-regexp x-font-regexp-foundry-and-family
   fc-font-regexp
   mswindows-font-regexp))

(require 'cl)

(eval-and-compile
  (defvar device-fonts-cache)
  (condition-case ()
      (require 'custom)
    (error nil))
  (if (and (featurep 'custom) (fboundp 'custom-declare-variable))
      nil ;; We've got what we needed
    ;; We have the old custom-library, hack around it!
    (defmacro defgroup (&rest args)
      nil)
    (defmacro defcustom (var value doc &rest args)
      `(defvar ,var ,value ,doc))))

; delete alternate defn of try-font-name

(if (not (fboundp 'facep))
    (defun facep (face)
      "Return t if X is a face name or an internal face vector."
      (if (not window-system)
	  nil				; FIXME if FSF ever does TTY faces
	(and (or (internal-facep face)
		 (and (symbolp face) (assq face global-face-data)))
	     t))))

(if (not (fboundp 'set-face-property))
    (defun set-face-property (face property value &optional locale
				   tag-set how-to-add)
      "Change a property of FACE."
      (and (symbolp face)
	   (put face property value))))

(if (not (fboundp 'face-property))
    (defun face-property (face property &optional locale tag-set exact-p)
      "Return FACE's value of the given PROPERTY."
      (and (symbolp face) (get face property))))

(require 'disp-table)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Lots of variables / keywords for use later in the program
;;; Not much should need to be modified
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; #### These aren't window system mappings
(defconst font-window-system-mappings
  '((x         . (x-font-create-name x-font-create-object))
    (gtk       . (x-font-create-name x-font-create-object))
    ;; #### FIXME should this handle fontconfig font objects?
    (fc        . (fc-font-create-name fc-font-create-object))
    (mswindows . (mswindows-font-create-name mswindows-font-create-object))
    (pm        . (x-font-create-name x-font-create-object)) ; Change? FIXME
    ;; #### what is this bogosity?
    (tty       . (tty-font-create-plist tty-font-create-object)))
  "An assoc list mapping device types to a list of translations.

The first function creates a font name from a font descriptor object.
The second performs the reverse translation.")

(defconst x-font-weight-mappings
  '((:extra-light . "extralight")
    (:light       . "light")
    (:demi-light  . "demilight")
    (:demi        . "demi")
    (:book        . "book")
    (:medium      . "medium")
    (:normal      . "medium")
    (:demi-bold   . "demibold")
    (:bold        . "bold")
    (:extra-bold  . "extrabold"))
  "An assoc list mapping keywords to actual Xwindow specific strings
for use in the 'weight' field of an X font string.")

(defconst font-possible-weights
  (mapcar 'car x-font-weight-mappings))

(defvar font-rgb-file nil
  "Where the RGB file was found.")

(defvar font-maximum-slippage "1pt"
  "How much a font is allowed to vary from the desired size.")

;; Canonical (internal) sizes are in points.

;; Property keywords: :family :style :size :registry :encoding :weight
;; Weight keywords:   :extra-light :light :demi-light :medium
;;                    :normal :demi-bold :bold :extra-bold
;; See GNU Emacs 21.4 for more properties and keywords we should support

(defvar font-style-keywords nil)

(defun set-font-family (fontobj family)
  (aset fontobj 1 family))

(defun set-font-weight (fontobj weight)
  (aset fontobj 3 weight))

(defun set-font-style (fontobj style)
  (aset fontobj 5 style))

(defun set-font-size (fontobj size)
  (aset fontobj 7 size))

(defun set-font-registry (fontobj reg)
  (aset fontobj 9 reg))

(defun set-font-encoding (fontobj enc)
  (aset fontobj 11 enc))

(defun font-family (fontobj)
  (aref fontobj 1))

(defun font-weight (fontobj)
  (aref fontobj 3))

(defun font-style (fontobj)
  (aref fontobj 5))

(defun font-size (fontobj)
  (aref fontobj 7))

(defun font-registry (fontobj)
  (aref fontobj 9))

(defun font-encoding (fontobj)
  (aref fontobj 11))

(eval-when-compile
  (defmacro define-new-mask (attr mask)
    `(progn
       (setq font-style-keywords
	     (cons (cons (quote ,attr)
			 (cons
			  (quote ,(intern (format "set-font-%s-p" attr)))
			  (quote ,(intern (format "font-%s-p" attr)))))
		   font-style-keywords))
       (defconst ,(intern (format "font-%s-mask" attr)) (lsh 1 ,mask)
	 ,(format
	   "Bitmask for whether a font is to be rendered in %s or not."
	   attr))
       (defun ,(intern (format "font-%s-p" attr)) (fontobj)
	 ,(format "Whether FONTOBJ will be rendered in `%s' or not." attr)
	 (if (/= 0 (logand (font-style fontobj)
		      ,(intern (format "font-%s-mask" attr))))
	     t
	   nil))
       (defun ,(intern (format "set-font-%s-p" attr)) (fontobj val)
	 ,(format "Set whether FONTOBJ will be rendered in `%s' or not."
		  attr)
	 (cond
	  (val
	   (set-font-style fontobj (logior (font-style fontobj)
					   ,(intern
					     (format "font-%s-mask" attr)))))
	  ((,(intern (format "font-%s-p" attr)) fontobj)
	   (set-font-style fontobj (- (font-style fontobj)
				      ,(intern
					(format "font-%s-mask" attr)))))))
       )))

(define-new-mask bold        1)
(define-new-mask italic      2)
(define-new-mask oblique     3)
(define-new-mask dim         4)
(define-new-mask underline   5)
(define-new-mask overline    6)
(define-new-mask linethrough 7)
(define-new-mask strikethru  8)
(define-new-mask reverse     9)
(define-new-mask blink       10)
(define-new-mask smallcaps   11)
(define-new-mask bigcaps     12)
(define-new-mask dropcaps    13)

(defvar font-caps-display-table
  (let ((table (make-display-table))
	(i 0))
    ;; Standard ASCII characters
    (while (< i 26)
      (put-display-table (+ i ?a) (+ i ?A) table)
      (setq i (1+ i)))
    ;; Now ISO translations
    ;; #### FIXME what's this for??
    (setq i 224)
    (while (< i 247)			;; Agrave - Ouml
      (put-display-table i (- i 32) table)
      (setq i (1+ i)))
    (setq i 248)
    (while (< i 255)			;; Oslash - Thorn
      (put-display-table i (- i 32) table)
      (setq i (1+ i)))
    table))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Utility functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; #### unused?
; (defun set-font-style-by-keywords (fontobj styles)
;   (make-local-variable 'font-func)
;   (declare (special font-func))
;   (if (listp styles)
;       (while styles
;  	(setq font-func (car-safe (cdr-safe (assq (car styles)
; 						  font-style-keywords)))
; 	      styles (cdr styles))
; 	(and (fboundp font-func) (funcall font-func fontobj t)))
;     (setq font-func (car-safe (cdr-safe (assq styles font-style-keywords))))
;     (and (fboundp font-func) (funcall font-func fontobj t))))

;; #### unused?
; (defun font-properties-from-style (fontobj)
;   (let ((todo font-style-keywords)
; 	type func retval)
;     (while todo
;       (setq func (cdr (cdr (car todo)))
; 	    type (car (pop todo)))
;       (if (funcall func fontobj)
; 	  (setq retval (cons type retval))))
;     retval))

(defun font-higher-weight (w1 w2)
  (let ((index1 (length (memq w1 font-possible-weights)))
	(index2 (length (memq w2 font-possible-weights))))
    (cond
     ((<= index1 index2)
      (or w1 w2))
     ((not w2)
      w1)
     (t
      w2))))

(defun font-spatial-to-canonical (spec &optional device)
  "Convert SPEC (in inches, millimeters, points, picas, or pixels) into points.

Canonical sizes are in points.  If SPEC is null, nil is returned.  If SPEC is
a number, it is interpreted as the desired point size and returned unchanged.
Otherwise SPEC must be a string consisting of a number and an optional type.
The type may be the strings \"px\", \"pix\", or \"pixel\" (pixels), \"pt\" or
\"point\" (points), \"pa\" or \"pica\" (picas), \"in\" or \"inch\" (inches),
\"cm\" (centimeters), or \"mm\" (millimeters).

1 in = 2.54 cm = 6 pa = 25.4 mm = 72 pt.  Pixel size is device-dependent."
  (cond
   ((numberp spec)
    spec)
   ((null spec)
    nil)
   (t
    (let ((num nil)
	  (type nil)
	  ;; If for any reason we get null for any of this, default
	  ;; to 1024x768 resolution on a 17" screen
	  (pix-width (float (or (device-pixel-width device) 1024)))
	  (mm-width (float (or (device-mm-width device) 293)))
	  (retval nil))
      (cond
       ;; #### this is pretty bogus and should probably be made gone
       ;; or supported at a higher level
       ((string-match "^ *\\([-+*/]\\) *" spec) ; math!  whee!
	(let ((math-func (intern (match-string 1 spec)))
	      (other (font-spatial-to-canonical
		      (substring spec (match-end 0) nil)))
	      (default (font-spatial-to-canonical
			(font-default-size-for-device device))))
	  (if (fboundp math-func)
	      (setq type "px"
		    spec (int-to-string (funcall math-func default other)))
	    (setq type "px"
		  spec (int-to-string other)))))
       ((string-match "[^0-9.]+$" spec)
	(setq type (substring spec (match-beginning 0))
	      spec (substring spec 0 (match-beginning 0))))
       (t
	(setq type "px"
	      spec spec)))
      (setq num (string-to-number spec))
      (cond
       ((member type '("pixel" "px" "pix"))
	(setq retval (* num (/ mm-width pix-width) (/ 72.0 25.4))))
       ((member type '("point" "pt"))
	(setq retval num))
       ((member type '("pica" "pa"))
	(setq retval (* num 12.0)))
       ((member type '("inch" "in"))
	(setq retval (* num 72.0)))
       ((string= type "mm")
	(setq retval (* num (/ 72.0 25.4))))
       ((string= type "cm")
	(setq retval (* num (/ 72.0 2.54))))
       (t
	(setq retval num))
       )
      retval))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; The main interface routines - constructors and accessor functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun make-font (&rest args)
  (vector :family
	  (if (stringp (plist-get args :family))
	      (list (plist-get args :family))
	    (plist-get args :family))
	  :weight
	  (plist-get args :weight)
	  :style
	  (if (numberp (plist-get args :style))
	      (plist-get args :style)
	    0)
	  :size
	  (plist-get args :size)
	  :registry
	  (plist-get args :registry)
	  :encoding
	  (plist-get args :encoding)))

(defun font-create-name (fontobj &optional device)
  "Return a font name constructed from FONTOBJ, appropriate for DEVICE."
  (let* ((type (device-type device))
	 (func (car (cdr-safe (assq type font-window-system-mappings)))))
    (and func (fboundp func) (funcall func fontobj device))))

;;;###autoload
(defun font-create-object (fontname &optional device)
  "Return a font descriptor object for FONTNAME, appropriate for DEVICE."
  (let* ((type (device-type device))
	 (func (car (cdr (cdr-safe (assq type font-window-system-mappings))))))
    (and func (fboundp func) (funcall func fontname device))))

(defun font-combine-fonts-internal (fontobj-1 fontobj-2)
  (let ((retval (make-font))
	(size-1 (and (font-size fontobj-1)
		     (font-spatial-to-canonical (font-size fontobj-1))))
	(size-2 (and (font-size fontobj-2)
		     (font-spatial-to-canonical (font-size fontobj-2)))))
    (set-font-weight retval (font-higher-weight (font-weight fontobj-1)
						(font-weight fontobj-2)))
    (set-font-family retval
                     (delete-duplicates (append (font-family fontobj-1)
                                                (font-family fontobj-2))
					:test #'equal))
    (set-font-style retval (logior (font-style fontobj-1)
				   (font-style fontobj-2)))
    (set-font-registry retval (or (font-registry fontobj-1)
				  (font-registry fontobj-2)))
    (set-font-encoding retval (or (font-encoding fontobj-1)
				  (font-encoding fontobj-2)))
    (set-font-size retval (cond
			   ((and size-1 size-2 (>= size-2 size-1))
			    (font-size fontobj-2))
			   ((and size-1 size-2)
			    (font-size fontobj-1))
			   (size-1
			    (font-size fontobj-1))
			   (size-2
			    (font-size fontobj-2))
			   (t nil)))

    retval))

(defun font-combine-fonts (&rest args)
  (cond
   ((null args)
    (error "Wrong number of arguments to font-combine-fonts"))
   ((eql (length args) 1)
    (car args))
   (t
    (let ((retval (font-combine-fonts-internal (nth 0 args) (nth 1 args))))
      (setq args (cdr (cdr args)))
      (while args
	(setq retval (font-combine-fonts-internal retval (car args))
	      args (cdr args)))
      retval))))

(defvar font-default-cache nil)

;;;###autoload
(defun font-default-font-for-device (&optional device)
  (or device (setq device (selected-device)))
  (font-truename
   (make-font-specifier
    (face-font-name 'default device))))

;;;###autoload
(defun font-default-object-for-device (&optional device)
  (let ((font (font-default-font-for-device device)))
    (or (cdr-safe (assoc font font-default-cache))
	(let ((object (font-create-object font)))
	  (push (cons font object) font-default-cache)
	  object))))

;;;###autoload
(defun font-default-family-for-device (&optional device)
  (font-family (font-default-object-for-device (or device (selected-device)))))

;;;###autoload
(defun font-default-registry-for-device (&optional device)
  (font-registry (font-default-object-for-device (or device (selected-device)))))

;;;###autoload
(defun font-default-encoding-for-device (&optional device)
  (font-encoding (font-default-object-for-device (or device (selected-device)))))

;;;###autoload
(defun font-default-size-for-device (&optional device)
  ;; face-height isn't the right thing (always 1 pixel too high?)
  ;; (if font-running-xemacs
  ;;    (format "%dpx" (face-height 'default device))
  (font-size (font-default-object-for-device (or device (selected-device)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; The window-system dependent code (TTY-style)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun tty-font-create-object (fontname &optional device)
  "Return a font descriptor object for FONTNAME, appropriate for TTY devices."
  (make-font :size "12pt"))

(defun tty-font-create-plist (fontobj &optional device)
  "Return a font name constructed from FONTOBJ, appropriate for TTY devices."
  (list
   (cons 'underline (font-underline-p fontobj))
   (cons 'highlight (if (or (font-bold-p fontobj)
			    (memq (font-weight fontobj) '(:bold :demi-bold)))
			t))
   (cons 'dim       (font-dim-p fontobj))
   (cons 'blinking  (font-blink-p fontobj))
   (cons 'reverse   (font-reverse-p fontobj))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; The window-system dependent code (X-style)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar font-x-font-regexp (when (and (boundp 'x-font-regexp)
				      x-font-regexp)
 (let
     ((- 		"[-?]")
      (foundry		"[^-]*")
      (family 		"[^-]*")
      ;(weight		"\\(bold\\|demibold\\|medium\\|black\\)")
      (weight\?		"\\([^-]*\\)")
      ;(slant		"\\([ior]\\)")
      (slant\?		"\\([^-]?\\)")
      (swidth		"\\([^-]*\\)")
      (adstyle		"\\([^-]*\\)")
      (pixelsize	"\\(\\*\\|[0-9]+\\)")
      (pointsize	"\\(\\*\\|0\\|[0-9][0-9]+\\)")
      (resx		"\\([*0]\\|[0-9][0-9]+\\)")
      (resy		"\\([*0]\\|[0-9][0-9]+\\)")
      (spacing		"[cmp?*]")
      (avgwidth		"\\(\\*\\|[0-9]+\\)")
      (registry		"[^-]*")
      (encoding	"[^-]+")
      )
   (concat "\\`\\*?[-?*]"
	   foundry - family - weight\? - slant\? - swidth - adstyle -
	   pixelsize - pointsize - resx - resy - spacing - avgwidth -
	   registry - encoding "\\'"
	   ))))

(defvar font-x-registry-and-encoding-regexp
  (when (and (boundp 'x-font-regexp-registry-and-encoding)
	     (symbol-value 'x-font-regexp-registry-and-encoding))
    (let ((- "[-?]")
	  (registry "[^-]*")
	  (encoding "[^-]+"))
      (concat - "\\(" registry "\\)" - "\\(" encoding "\\)\\'"))))

(defvar font-x-family-mappings
  '(
    ("serif"        . ("new century schoolbook"
		       "utopia"
		       "charter"
		       "times"
		       "lucidabright"
		       "garamond"
		       "palatino"
		       "times new roman"
		       "baskerville"
		       "bookman"
		       "bodoni"
		       "computer modern"
		       "rockwell"
		       ))
    ("sans-serif"   . ("lucida"
		       "helvetica"
		       "gills-sans"
		       "avant-garde"
		       "univers"
		       "optima"))
    ("elfin"        . ("tymes"))
    ("monospace"    . ("courier"
		       "fixed"
		       "lucidatypewriter"
		       "clean"
		       "terminal"))
    ("cursive"      . ("sirene"
		       "zapf chancery"))
    )
  "A list of font family mappings on X devices.")

(defun x-font-create-object (fontname &optional device)
  "Return a font descriptor object for FONTNAME, appropriate for X devices."
  (let ((case-fold-search t))
    (if (or (not (stringp fontname))
	    (not (string-match font-x-font-regexp fontname)))
	(if (and (stringp fontname)
		 (featurep 'xft-fonts)
		 (string-match font-xft-font-regexp fontname))
	    ;; Return an XFT font. 
	    (xft-font-create-object fontname)
	  ;; It's unclear how to parse the font; return an unspecified
	  ;; one.
	  (make-font))
      (let ((family nil)
	    (size nil)
	    (weight  (match-string 1 fontname))
	    (slant   (match-string 2 fontname))
	    (swidth  (match-string 3 fontname))
	    (adstyle (match-string 4 fontname))
	    (pxsize  (match-string 5 fontname))
	    (ptsize  (match-string 6 fontname))
	    (retval nil)
	    (case-fold-search t)
	    )
	(if (not (string-match x-font-regexp-foundry-and-family fontname))
	    nil
	  (setq family (list (downcase (match-string 1 fontname)))))
	(if (string= "*" weight)  (setq weight  nil))
	(if (string= "*" slant)   (setq slant   nil))
	(if (string= "*" swidth)  (setq swidth  nil))
	(if (string= "*" adstyle) (setq adstyle nil))
	(if (string= "*" pxsize)  (setq pxsize  nil))
	(if (string= "*" ptsize)  (setq ptsize  nil))
	(if ptsize (setq size (/ (string-to-int ptsize) 10)))
	(if (and (not size) pxsize) (setq size (concat pxsize "px")))
	(if weight (setq weight (intern-soft (concat ":" (downcase weight)))))
	(if (and adstyle (not (equal adstyle "")))
	    (setq family (append family (list (downcase adstyle)))))
	(setq retval (make-font :family family
				:weight weight
				:size size))
	(set-font-bold-p retval (eq :bold weight))
	(cond
	 ((null slant) nil)
	 ((member slant '("i" "I"))
	  (set-font-italic-p retval t))
	 ((member slant '("o" "O"))
	  (set-font-oblique-p retval t)))
	(when (string-match font-x-registry-and-encoding-regexp fontname)
	  (set-font-registry retval (match-string 1 fontname))
	  (set-font-encoding retval (match-string 2 fontname)))
	retval))))

(defun x-font-families-for-device (&optional device no-resetp)
  (ignore-errors (require 'x-font-menu))
  (or device (setq device (selected-device)))
  (if (boundp 'device-fonts-cache)
      (let ((menu (or (cdr-safe (assq device device-fonts-cache)))))
	(if (and (not menu) (not no-resetp))
	    (progn
	      (reset-device-font-menus device)
	      (x-font-families-for-device device t))
	  (let ((scaled (mapcar #'(lambda (x) (if x (aref x 0)))
				(aref menu 0)))
		(normal (mapcar #'(lambda (x) (if x (aref x 0)))
				(aref menu 1))))
	    (sort (delete-duplicates (nconc scaled normal) :test 'equal)
                  'string-lessp))))
    (cons "monospace" (mapcar 'car font-x-family-mappings))))

(defun x-font-create-name (fontobj &optional device)
  "Return a font name constructed from FONTOBJ, appropriate for X devices."
  (if (and (not (or (font-family fontobj)
		    (font-weight fontobj)
		    (font-size fontobj)
		    (font-registry fontobj)
		    (font-encoding fontobj)))
	   (= (font-style fontobj) 0))
      (face-font 'default)
    (or device (setq device (selected-device)))
    (let* ((default (font-default-object-for-device device))
	   (family (or (font-family fontobj)
		       (font-family default)
		       (x-font-families-for-device device)))
	   (weight (or (font-weight fontobj) :medium))
	   (size (or (font-size fontobj)
		     (font-size default)))
	   (registry (or (font-registry fontobj)
			 (font-registry default)
			 "*"))
	   (encoding (or (font-encoding fontobj)
			 (font-encoding default)
			 "*")))
      (if (stringp family)
	  (setq family (list family)))
      (setq weight (font-higher-weight weight
				       (and (font-bold-p fontobj) :bold)))
      (if (stringp size)
	  (setq size (truncate (font-spatial-to-canonical size device))))
      (setq weight (or (cdr-safe (assq weight x-font-weight-mappings)) "*"))
      (let ((done nil)			; Did we find a good font yet?
	    (font-name nil)		; font name we are currently checking
	    (cur-family nil)		; current family we are checking
	    )
	(while (and family (not done))
	  (setq cur-family (car family)
		family (cdr family))
	  (if (assoc cur-family font-x-family-mappings)
	      ;; If the family name is an alias as defined by
	      ;; font-x-family-mappings, then append those families
	      ;; to the front of 'family' and continue in the loop.
	      (setq family (append
			    (cdr-safe (assoc cur-family
					     font-x-family-mappings))
			    family))
	    ;; Not an alias for a list of fonts, so we just check it.
	    ;; First, convert all '-' to spaces so that we don't screw up
	    ;; the oh-so wonderful X font model.  Wheee.
	    (let ((x (length cur-family)))
	      (while (> x 0)
		(if (= ?- (aref cur-family (1- x)))
		    (aset cur-family (1- x) ? ))
		(setq x (1- x))))
	    ;; We treat oblique and italic as equivalent.  Don't ask.
	    (let ((slants '("o" "i")))
	      (while (and slants (not done))
		(setq font-name (format "-*-%s-%s-%s-*-*-*-%s-*-*-*-*-%s-%s"
					cur-family weight
					(if (or (font-italic-p fontobj)
						(font-oblique-p fontobj))
					    (car slants)
					  "r")
					(if size
					    (int-to-string (* 10 size)) "*")
					registry
					encoding
					)
		      slants (cdr slants)
		      done (try-font-name font-name device))))))
	(if done font-name)))))


;;; Cache building code
;;;###autoload
(defun x-font-build-cache (&optional device)
  (let ((hash-table (make-hash-table :test 'equal :size 15))
	(fonts (mapcar 'x-font-create-object
		       (font-list "-*-*-*-*-*-*-*-*-*-*-*-*-*-*")))
	(plist nil)
	(cur nil))
    (while fonts
      (setq cur (car fonts)
	    fonts (cdr fonts)
	    plist (cl-gethash (car (font-family cur)) hash-table))
      (if (not (memq (font-weight cur) (plist-get plist 'weights)))
	  (setq plist (plist-put plist 'weights (cons (font-weight cur)
						      (plist-get plist 'weights)))))
      (if (not (member (font-size cur) (plist-get plist 'sizes)))
	  (setq plist (plist-put plist 'sizes (cons (font-size cur)
						    (plist-get plist 'sizes)))))
      (if (and (font-oblique-p cur)
	       (not (memq 'oblique (plist-get plist 'styles))))
	  (setq plist (plist-put plist 'styles (cons 'oblique (plist-get plist 'styles)))))
      (if (and (font-italic-p cur)
	       (not (memq 'italic (plist-get plist 'styles))))
	  (setq plist (plist-put plist 'styles (cons 'italic (plist-get plist 'styles)))))
      (cl-puthash (car (font-family cur)) plist hash-table))
    hash-table))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; The rendering engine-dependent code (Xft-style)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; #### FIXME actually, this section should be fc-*, right?

(defvar font-xft-font-regexp
  (concat "\\`"
	  #r"\(\\-\|\\:\|\\,\|[^:-]\)*"	        ; optional foundry and family
						; (allows for escaped colons, 
						; dashes, commas)
	  "\\(-[0-9]*\\(\\.[0-9]*\\)?\\)?"	; optional size (points)
	  "\\(:[^:]*\\)*"			; optional properties
						; not necessarily key=value!!
	    "\\'"
	    ))

(defvar font-xft-family-mappings
  ;; #### FIXME this shouldn't be needed or used for Xft
  '(("serif"        . ("new century schoolbook"
		       "utopia"
		       "charter"
		       "times"
		       "lucidabright"
		       "garamond"
		       "palatino"
		       "times new roman"
		       "baskerville"
		       "bookman"
		       "bodoni"
		       "computer modern"
		       "rockwell"
		       ))
    ("sans-serif"   . ("lucida"
		       "helvetica"
		       "gills-sans"
		       "avant-garde"
		       "univers"
		       "optima"))
    ("elfin"        . ("tymes"))
    ("monospace"    . ("courier"
		       "fixed"
		       "lucidatypewriter"
		       "clean"
		       "terminal"))
    ("cursive"      . ("sirene"
		       "zapf chancery"))
    )
  "A list of font family mappings on Xft devices.")

(defun xft-font-create-object (fontname &optional device)
  "Return a font descriptor object for FONTNAME, appropriate for Xft.

Optional DEVICE defaults to `default-x-device'."
  (let* ((name fontname)
	 (device (or device (default-x-device)))
	 ;; names generated by font-instance-truename may contain
	 ;; unparseable object specifications
	 (pattern (fc-font-match device (fc-name-parse-harder name)))
	 (font-obj (make-font))
	 (family (fc-pattern-get-family pattern 0))
	 (size (fc-pattern-get-or-compute-size pattern 0))
	 (weight (fc-pattern-get-weight pattern 0)))
    (set-font-family font-obj 
		     (and (not (equal family 'fc-result-no-match)) 
			  family))
    (set-font-size font-obj 
		   (and (not (equal size 'fc-result-no-match))
			size))
    (set-font-weight font-obj 
		     (and (not (equal weight 'fc-result-no-match))
			  (fc-font-weight-translate-from-constant weight)))
    font-obj))

;; #### FIXME Xft fonts are not defined by the device.
;; ... Does that mean the whole model here is bogus?
(defun xft-font-families-for-device (&optional device no-resetp)
  (ignore-errors (require 'x-font-menu))  ; #### FIXME xft-font-menu?
  (or device (setq device (selected-device)))
  (if (boundp 'device-fonts-cache)	; #### FIXME does this make sense?
      (let ((menu (or (cdr-safe (assq device device-fonts-cache)))))
	(if (and (not menu) (not no-resetp))
	    (progn
	      (reset-device-font-menus device)
	      (xft-font-families-for-device device t))
	  ;; #### FIXME clearly bogus for Xft
	  (let ((scaled (mapcar #'(lambda (x) (if x (aref x 0)))
				(aref menu 0)))
		(normal (mapcar #'(lambda (x) (if x (aref x 0)))
				(aref menu 1))))
	    (sort (delete-duplicates (nconc scaled normal) :test #'equal)
                  'string-lessp))))
	  ;; #### FIXME clearly bogus for Xft
    (cons "monospace" (mapcar 'car font-xft-family-mappings))))

(defun xft-font-create-name (fontobj &optional device)
  (let* ((pattern (make-fc-pattern)))
    (if (font-family fontobj)
	(fc-pattern-add-family pattern (font-family fontobj)))
    (if (font-size fontobj)
	(fc-pattern-add-size pattern (font-size fontobj)))
    (fc-name-unparse pattern)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; The window-system dependent code (mswindows-style)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst mswindows-font-weight-mappings
  '((:thin        . "Thin")
    (:extra-light . "Extra Light")
    (:light       . "Light")
    (:demi-light  . "Light")
    (:demi        . "Light")
    (:book        . "Medium")
    (:medium      . "Medium")
    (:normal      . "Normal")
    (:demi-bold   . "Demi Bold")
    (:bold        . "Bold")
    (:regular	  . "Regular")
    (:extra-bold  . "Extra Bold")
    (:heavy       . "Heavy"))
  "An assoc list mapping keywords to actual mswindows specific strings
for use in the 'weight' field of an mswindows font string.")

(defvar font-mswindows-family-mappings
  '(
    ("serif"        . ("times new roman"
		       "century schoolbook"
		       "book antiqua"
		       "bookman old style"))
    ("sans-serif"   . ("arial"
		       "verdana"
		       "lucida sans unicode"))
    ("monospace"    . ("courier new"
		       "lucida console"
		       "courier"
		       "terminal"))
    ("cursive"      . ("roman"
		       "script"))
    )
  "A list of font family mappings on mswindows devices.")

(defun mswindows-font-create-object (fontname &optional device)
  "Return a font descriptor object for FONTNAME, appropriate for MS Windows devices."
  (let ((case-fold-search t)
	(font (declare-fboundp (mswindows-canonicalize-font-name fontname))))
    (if (or (not (stringp font))
	    (not (string-match mswindows-font-regexp font)))
	(make-font)
      (let ((family	(match-string 1 font))
	    (style	(match-string 2 font))
	    (pointsize	(match-string 3 font))
	    (effects	(match-string 4 font))
	    (charset	(match-string 5 font))
	    (retval nil)
	    (size nil)
	    (case-fold-search t)
	    )
	(destructuring-bind (weight . slant)
	    (mswindows-parse-font-style style)
	  (if (equal pointsize "") (setq pointsize nil))
	  (if pointsize (setq size (concat pointsize "pt")))
	  (if weight (setq weight
			   (intern-soft
			    (concat ":" (downcase (replace-in-string
						   weight " " "-"))))))
	  (setq retval (make-font :family family
				  :weight weight
				  :size size
				  :encoding charset))
	  (set-font-bold-p retval (eq :bold weight))
	  (cond
	   ((null slant) nil)
	   ((string-match "[iI]talic" slant)
	    (set-font-italic-p retval t)))
	  (cond
	   ((null effects) nil)
	   ((string-match "^[uU]nderline [sS]trikeout" effects)
	    (set-font-underline-p retval t)
	    (set-font-strikethru-p retval t))
	   ((string-match "[uU]nderline" effects)
	    (set-font-underline-p retval t))
	   ((string-match "[sS]trikeout" effects)
	    (set-font-strikethru-p retval t)))
	  retval)))))

(defun mswindows-font-create-name (fontobj &optional device)
  "Return a font name constructed from FONTOBJ, appropriate for MS Windows devices."
  (if (and (not (or (font-family fontobj)
		    (font-weight fontobj)
		    (font-size fontobj)
		    (font-registry fontobj)
		    (font-encoding fontobj)))
	   (= (font-style fontobj) 0))
      (face-font 'default)
    (or device (setq device (selected-device)))
    (let* ((default (font-default-object-for-device device))
	   (family (or (font-family fontobj)
		       (font-family default)))
	   (weight (or (font-weight fontobj) :regular))
	   (size (or (font-size fontobj)
		     (font-size default)))
	   (underline-p (font-underline-p fontobj))
	   (strikeout-p (font-strikethru-p fontobj))
	   (encoding (font-encoding fontobj)))
      (if (stringp family)
	  (setq family (list family)))
      (setq weight (font-higher-weight weight
				       (and (font-bold-p fontobj) :bold)))
      (if (stringp size)
	  (setq size (truncate (font-spatial-to-canonical size device))))
      (setq weight (or (cdr-safe
			(assq weight mswindows-font-weight-mappings)) ""))
      (let ((done nil)			; Did we find a good font yet?
	    (font-name nil)		; font name we are currently checking
	    (cur-family nil)		; current family we are checking
	    )
	(while (and family (not done))
	  (setq cur-family (car family)
		family (cdr family))
	  (if (assoc cur-family font-mswindows-family-mappings)
	      ;; If the family name is an alias as defined by
	      ;; font-mswindows-family-mappings, then append those families
	      ;; to the front of 'family' and continue in the loop.
	      (setq family (append
			    (cdr-safe (assoc cur-family
					     font-mswindows-family-mappings))
			    family))
	    ;; We treat oblique and italic as equivalent.  Don't ask.
            ;; Courier New:Bold Italic:10:underline strikeout:western
	    (setq font-name (format "%s:%s:%s:%s:%s"
				    cur-family
				    (mswindows-construct-font-style
				     weight
				     (if (font-italic-p fontobj)
					 "Italic" ""))
				    (if size
					(int-to-string size) "10")
				    (if underline-p
					(if strikeout-p
					    "underline strikeout"
					  "underline")
				      (if strikeout-p "strikeout" ""))
				    (if encoding
					encoding ""))
		  done (try-font-name font-name device))))
	(if done font-name)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Now overwrite the original copy of set-face-font with our own copy that
;;; can deal with either syntax.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ###autoload
(defun font-set-face-font (&optional face font &rest args)
  (cond
   ((and (vectorp font) (eql (length font) 12))
    (let ((font-name (font-create-name font)))
      (set-face-property face 'font-specification font)
      (cond
       ((null font-name)		; No matching font!
	nil)
       ((listp font-name)		; For TTYs
	(let (cur)
	  (while font-name
	    (setq cur (car font-name)
		  font-name (cdr font-name))
	    (apply 'set-face-property face (car cur) (cdr cur) args))))
       (t
	(apply 'set-face-font face font-name args)
	(apply 'set-face-underline-p face (font-underline-p font) args)
	(if (and (or (font-smallcaps-p font) (font-bigcaps-p font))
		 (fboundp 'set-face-display-table))
	    (apply 'set-face-display-table
		   face font-caps-display-table args))
	(apply 'set-face-property face 'strikethru (or
						    (font-linethrough-p font)
						    (font-strikethru-p font))
	       args))
;;; this used to be default with preceding conditioned on font-running-xemacs
;        (t
; 	(condition-case nil
; 	    (apply 'set-face-font face font-name args)
; 	  (error
; 	   (let ((args (car-safe args)))
; 	     (and (or (font-bold-p font)
; 		      (memq (font-weight font) '(:bold :demi-bold)))
; 		  (make-face-bold face args t))
; 	     (and (font-italic-p font) (make-face-italic face args t)))))
; 	(apply 'set-face-underline-p face (font-underline-p font) args))
       )))
   (t
    ;; Let the original set-face-font signal any errors
    (set-face-property face 'font-specification nil)
    (apply 'set-face-font face font args))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Now for emacsen specific stuff
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun font-update-device-fonts (device)
  ;; Update all faces that were created with the 'font' package
  ;; to appear correctly on the new device.  This should be in the
  ;; create-device-hook.  This is XEmacs 19.12+ specific
  (let ((faces (face-list 2))
	(cur nil)
	(font-spec nil))
    (while faces
      (setq cur (car faces)
	    faces (cdr faces)
	    font-spec (face-property cur 'font-specification))
      (if font-spec
	  (set-face-font cur font-spec device)))))

(defun font-update-one-face (face &optional device-list)
  ;; Update FACE on all devices in DEVICE-LIST
  ;; DEVICE_LIST defaults to a list of all active devices
  (setq device-list (or device-list (device-list)))
  (if (devicep device-list)
      (setq device-list (list device-list)))
  (let* ((cur-device nil)
	 (font-spec (face-property face 'font-specification)))
    (if (not font-spec)
	;; Hey!  Don't mess with fonts we didn't create in the
	;; first place.
	nil
      (while device-list
	(setq cur-device (car device-list)
	      device-list (cdr device-list))
	(if (not (device-live-p cur-device))
	    ;; Whoah!
	    nil
	  (if font-spec
	      (set-face-font face font-spec cur-device)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Various color related things
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun font-lookup-rgb-components (color)
  "Lookup COLOR (a color name) in rgb.txt and return a list of RGB values.
The list (R G B) is returned, or an error is signaled if the lookup fails."
  (let ((lib-list (if-boundp 'x-library-search-path
		      x-library-search-path
		    (list "/usr/X11R6/lib/X11/"
			  "/usr/X11R5/lib/X11/"
			  "/usr/lib/X11R6/X11/"
			  "/usr/lib/X11R5/X11/"
			  "/usr/local/X11R6/lib/X11/"
			  "/usr/local/X11R5/lib/X11/"
			  "/usr/local/lib/X11R6/X11/"
			  "/usr/local/lib/X11R5/X11/"
			  "/usr/X11/lib/X11/"
			  "/usr/lib/X11/"
			  "/usr/share/X11/"
			  "/usr/local/lib/X11/"
			  "/usr/local/share/X11/"
			  "/usr/X386/lib/X11/"
			  "/usr/x386/lib/X11/"
			  "/usr/XFree86/lib/X11/"
			  "/usr/unsupported/lib/X11/"
			  "/usr/athena/lib/X11/"
			  "/usr/local/x11r5/lib/X11/"
			  "/usr/lpp/Xamples/lib/X11/"
			  "/usr/openwin/lib/X11/"
			  "/usr/openwin/share/lib/X11/")))
	(file font-rgb-file)
	r g b)
    (if (not file)
	(while lib-list
	  (setq file (expand-file-name "rgb.txt" (car lib-list)))
	  (if (file-readable-p file)
	      (setq lib-list nil
		    font-rgb-file file)
	    (setq lib-list (cdr lib-list)
		  file nil))))
    (if (null file)
	(list 0 0 0)
      (save-excursion
	(set-buffer (find-file-noselect file))
	(if (not (= (aref (buffer-name) 0) ? ))
	    (rename-buffer (generate-new-buffer-name " *rgb-tmp-buffer*")))
	(save-excursion
	  (save-restriction
	    (widen)
	    (goto-char (point-min))
	    (if (re-search-forward (format "\t%s$" (regexp-quote color)) nil t)
		(progn
		  (beginning-of-line)
		  (setq r (* (read (current-buffer)) 256)
			g (* (read (current-buffer)) 256)
			b (* (read (current-buffer)) 256)))
	      (display-warning 'color (format "No such color: %s" color))
	      (setq r 0
		    g 0
		    b 0))
	    (list r g b) ))))))

(defun font-parse-rgb-components (color)
  "Parse RGB color specification and return a list of integers (R G B).
#FEFEFE and rgb:fe/fe/fe style specifications are parsed."
  (let ((case-fold-search t)
	r g b str)
  (cond ((string-match "^#[0-9a-f]+$" color)
	 (cond
	  ((eql (length color) 4)
	   (setq r (string-to-number (substring color 1 2) 16)
		 g (string-to-number (substring color 2 3) 16)
		 b (string-to-number (substring color 3 4) 16)
		 r (* r 4096)
		 g (* g 4096)
		 b (* b 4096)))
	  ((eql (length color) 7)
	   (setq r (string-to-number (substring color 1 3) 16)
		 g (string-to-number (substring color 3 5) 16)
		 b (string-to-number (substring color 5 7) 16)
		 r (* r 256)
		 g (* g 256)
		 b (* b 256)))
	  ((eql (length color) 10)
	   (setq r (string-to-number (substring color 1 4) 16)
		 g (string-to-number (substring color 4 7) 16)
		 b (string-to-number (substring color 7 10) 16)
		 r (* r 16)
		 g (* g 16)
		 b (* b 16)))
	  ((eql (length color) 13)
	   (setq r (string-to-number (substring color 1 5) 16)
		 g (string-to-number (substring color 5 9) 16)
		 b (string-to-number (substring color 9 13) 16)))
	  (t
	   (display-warning 'color
	     (format "Invalid RGB color specification: %s" color))
	   (setq r 0
		 g 0
		 b 0))))
	((string-match "rgb:\\([0-9a-f]+\\)/\\([0-9a-f]+\\)/\\([0-9a-f]+\\)"
		       color)
	 (if (or (> (- (match-end 1) (match-beginning 1)) 4)
		 (> (- (match-end 2) (match-beginning 2)) 4)
		 (> (- (match-end 3) (match-beginning 3)) 4))
	     (error "Invalid RGB color specification: %s" color)
	   (setq str (match-string 1 color)
		 r (* (string-to-number str 16)
		      (expt 16 (- 4 (length str))))
		 str (match-string 2 color)
		 g (* (string-to-number str 16)
		      (expt 16 (- 4 (length str))))
		 str (match-string 3 color)
		 b (* (string-to-number str 16)
		      (expt 16 (- 4 (length str)))))))
	(t
	 (display-warning 'color (format "Invalid RGB color specification: %s"
					color))
	 (setq r 0
	       g 0
	       b 0)))
  (list r g b) ))

(defun font-rgb-color-p (obj)
  (or (and (vectorp obj)
	   (eql (length obj) 4)
	   (eq (aref obj 0) 'rgb))))

(defun font-rgb-color-red (obj) (aref obj 1))
(defun font-rgb-color-green (obj) (aref obj 2))
(defun font-rgb-color-blue (obj) (aref obj 3))

(defun font-color-rgb-components (color)
  "Return the RGB components of COLOR as a list of integers (R G B).
16-bit values are always returned.
#FEFEFE and rgb:fe/fe/fe style color specifications are parsed directly
into their components.
RGB values for color names are looked up in the rgb.txt file.
The variable x-library-search-path is use to locate the rgb.txt file."
  (let ((case-fold-search t))
    (cond
     ((and (font-rgb-color-p color) (floatp (aref color 1)))
      (list (* 65535 (aref color 0))
 	    (* 65535 (aref color 1))
 	    (* 65535 (aref color 2))))
     ((font-rgb-color-p color)
      (list (font-rgb-color-red color)
	    (font-rgb-color-green color)
	    (font-rgb-color-blue color)))
     ((and (vectorp color) (eql 3 (length color)))
      (list (aref color 0) (aref color 1) (aref color 2)))
     ((and (listp color) (eql 3 (length color)) (floatp (car color)))
      (mapcar #'(lambda (x) (* x 65535)) color))
     ((and (listp color) (eql 3 (length color)))
      color)
     ((or (string-match "^#" color)
	  (string-match "^rgb:" color))
      (font-parse-rgb-components color))
     ((string-match "\\([0-9.]+\\)[ \t]\\([0-9.]+\\)[ \t]\\([0-9.]+\\)"
		    color)
      (let ((r (string-to-number (match-string 1 color)))
	    (g (string-to-number (match-string 2 color)))
	    (b (string-to-number (match-string 3 color))))
	(if (floatp r)
	    (setq r (round (* 255 r))
		  g (round (* 255 g))
		  b (round (* 255 b))))
	(font-parse-rgb-components (format "#%02x%02x%02x" r g b))))
     (t
      (font-lookup-rgb-components color)))))

(defun font-tty-compute-color-delta (col1 col2)
  (+
   (* (- (aref col1 0) (aref col2 0))
      (- (aref col1 0) (aref col2 0)))
   (* (- (aref col1 1) (aref col2 1))
      (- (aref col1 1) (aref col2 1)))
   (* (- (aref col1 2) (aref col2 2))
      (- (aref col1 2) (aref col2 2)))))

(defun font-tty-find-closest-color (r g b)
  ;; This is basically just a lisp copy of allocate_nearest_color
  ;; from fontcolor-x.c from Emacs 19
  ;; We really should just check tty-color-list, but unfortunately
  ;; that does not include any RGB information at all.
  ;; So for now we just hardwire in the default list and call it
  ;; good for now.
  (setq r (/ r 65535.0)
	g (/ g 65535.0)
	b (/ b 65535.0))
  (let* ((color_def (vector r g b))
	 (colors [([1.0 1.0 1.0] . "white")
		  ([0.0 1.0 1.0] . "cyan")
		  ([1.0 0.0 1.0] . "magenta")
		  ([0.0 0.0 1.0] . "blue")
		  ([1.0 1.0 0.0] . "yellow")
		  ([0.0 1.0 0.0] . "green")
		  ([1.0 0.0 0.0] . "red")
		  ([0.0 0.0 0.0] . "black")])
	 (no_cells (length colors))
	 (x 1)
	 (nearest 0)
	 (nearest_delta 0)
	 (trial_delta 0))
    (setq nearest_delta (font-tty-compute-color-delta (car (aref colors 0))
						      color_def))
    (while (/= no_cells x)
      (setq trial_delta (font-tty-compute-color-delta (car (aref colors x))
						      color_def))
      (if (< trial_delta nearest_delta)
	  (setq nearest x
		nearest_delta trial_delta))
      (setq x (1+ x)))
    (cdr-safe (aref colors nearest))))

(defun font-normalize-color (color &optional device)
  "Return an RGB tuple, given any form of input.  If an error occurs, black
is returned."
  (case (device-type device)
   ((x pm)
    (apply 'format "#%02x%02x%02x" (font-color-rgb-components color)))
   (mswindows
    (let* ((rgb (font-color-rgb-components color))
	   (color (apply 'format "#%02x%02x%02x" rgb)))
      (mswindows-define-rgb-color (nth 0 rgb) (nth 1 rgb) (nth 2 rgb) color)
      color))
   (tty
    (apply 'font-tty-find-closest-color (font-color-rgb-components color)))
   (ns
    (let ((vals (mapcar #'(lambda (x) (lsh x -8))
			(font-color-rgb-components color))))
      (apply 'format "RGB%02x%02x%02xff" vals)))
   (otherwise
    color)))

(defun font-set-face-background (&optional face color &rest args)
  (interactive)
  (condition-case nil
      (cond
       ((or (font-rgb-color-p color)
	    (string-match "^#[0-9a-fA-F]+$" color))
	(apply 'set-face-background face
	       (font-normalize-color color) args))
       (t
	(apply 'set-face-background face color args)))
    (error nil)))

(defun font-set-face-foreground (&optional face color &rest args)
  (interactive)
  (condition-case nil
      (cond
       ((or (font-rgb-color-p color)
	    (string-match "^#[0-9a-fA-F]+$" color))
	(apply 'set-face-foreground face (font-normalize-color color) args))
       (t
	(apply 'set-face-foreground face color args)))
    (error nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Support for 'blinking' fonts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun font-map-windows (func &optional arg frame)
  (let* ((start (selected-window))
	 (cur start)
	 (result nil))
    (push (funcall func start arg) result)
    (while (not (eq start (setq cur (next-window cur))))
      (push (funcall func cur arg) result))
    result))

(defun font-face-visible-in-window-p (window face)
  (let ((st (window-start window))
	(nd (window-end window))
	(found nil)
	(face-at nil))
    (setq face-at (get-text-property st 'face (window-buffer window)))
    (if (or (eq face face-at) (and (listp face-at) (memq face face-at)))
	(setq found t))
    (while (and (not found)
		(/= nd
		    (setq st (next-single-property-change
			      st 'face
			      (window-buffer window) nd))))
      (setq face-at (get-text-property st 'face (window-buffer window)))
      (if (or (eq face face-at) (and (listp face-at) (memq face face-at)))
	  (setq found t)))
    found))

(defun font-blink-callback ()
  ;; Optimized to never invert the face unless one of the visible windows
  ;; is showing it.
  (let ((faces (face-list t))
	(obj nil))
    (while faces
      (if (and (setq obj (face-property (car faces) 'font-specification))
	       (font-blink-p obj)
	       (memq t
		     (font-map-windows 'font-face-visible-in-window-p
				       (car faces))))
	  (invert-face (car faces)))
      (pop faces))))

(defcustom font-blink-interval 0.5
  "How often to blink faces"
  :type 'number
  :group 'faces)

(defun font-blink-initialize ()
  (cond
   ((featurep 'itimer)
    (if (get-itimer "font-blinker")
	(delete-itimer (get-itimer "font-blinker")))
    (start-itimer "font-blinker" 'font-blink-callback
		  font-blink-interval
		  font-blink-interval))
   ((fboundp 'run-at-time)
    (cancel-function-timers 'font-blink-callback)
    (declare-fboundp (run-at-time font-blink-interval
				  font-blink-interval
				  'font-blink-callback)))
   (t nil)))

(provide 'font)
