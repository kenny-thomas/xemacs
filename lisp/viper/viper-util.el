;;; viper-util.el --- Utilities used by viper.el

;; Copyright (C) 1994, 1995, 1996, 1997 Free Software Foundation, Inc.

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.


;; Code

;; Compiler pacifier
(defvar vip-overriding-map)
(defvar pm-color-alist)
(defvar zmacs-region-stays)
(defvar vip-minibuffer-current-face)
(defvar vip-minibuffer-insert-face)
(defvar vip-minibuffer-vi-face)
(defvar vip-minibuffer-emacs-face)
(defvar vip-replace-overlay-face)
(defvar vip-fast-keyseq-timeout)
(defvar ex-unix-type-shell)
(defvar ex-unix-type-shell-options)
(defvar vip-ex-tmp-buf-name)

(require 'cl)
(require 'ring)

(if noninteractive
    (eval-when-compile
      (let ((load-path (cons (expand-file-name ".") load-path)))
	(or (featurep 'viper-init)
	    (load "viper-init.el" nil nil 'nosuffix))
	)))
;; end pacifier

(require 'viper-init)



;;; XEmacs support

;; A fix for NeXT Step
;; Should probably be eliminated in later versions.
(if (and (vip-window-display-p) (eq (vip-device-type) 'ns))
    (progn
      (fset 'x-display-color-p (symbol-function 'ns-display-color-p))
      (fset 'x-color-defined-p (symbol-function 'ns-color-defined-p))
      ))

(if vip-xemacs-p
    (progn
      (fset 'vip-read-event (symbol-function 'next-command-event))
      (fset 'vip-make-overlay (symbol-function 'make-extent))
      (fset 'vip-overlay-start (symbol-function 'extent-start-position))
      (fset 'vip-overlay-end (symbol-function 'extent-end-position))
      (fset 'vip-overlay-put (symbol-function 'set-extent-property))
      (fset 'vip-overlay-p (symbol-function 'extentp))
      (fset 'vip-overlay-get (symbol-function 'extent-property))
      (fset 'vip-move-overlay (symbol-function 'set-extent-endpoints))
      (if (vip-window-display-p)
	  (fset 'vip-iconify (symbol-function 'iconify-frame)))
      (cond ((vip-has-face-support-p)
	     (fset 'vip-get-face (symbol-function 'get-face))
	     (fset 'vip-color-defined-p
		   (symbol-function 'valid-color-name-p))
	     )))
  (fset 'vip-read-event (symbol-function 'read-event))
  (fset 'vip-make-overlay (symbol-function 'make-overlay))
  (fset 'vip-overlay-start (symbol-function 'overlay-start))
  (fset 'vip-overlay-end (symbol-function 'overlay-end))
  (fset 'vip-overlay-put (symbol-function 'overlay-put))
  (fset 'vip-overlay-p (symbol-function 'overlayp))
  (fset 'vip-overlay-get (symbol-function 'overlay-get))
  (fset 'vip-move-overlay (symbol-function 'move-overlay))
  (if (vip-window-display-p)
      (fset 'vip-iconify (symbol-function 'iconify-or-deiconify-frame)))
  (cond ((vip-has-face-support-p)
	 (fset 'vip-get-face (symbol-function 'internal-get-face))
	 (fset 'vip-color-defined-p (symbol-function 'x-color-defined-p))
	 )))


(fset 'vip-characterp
      (symbol-function
       (if vip-xemacs-p 'characterp 'integerp)))

(defsubst vip-color-display-p ()
  (if vip-emacs-p
      (x-display-color-p)
    (eq (device-class (selected-device)) 'color)))
   
(defsubst vip-get-cursor-color ()
  (if vip-emacs-p
      (cdr (assoc 'cursor-color (frame-parameters)))
    (color-instance-name (frame-property (selected-frame) 'cursor-color))))
  
(defun vip-set-face-pixmap (face pixmap)
  "Set face pixmap on a monochrome display."
  (if (and (vip-window-display-p) (not (vip-color-display-p)))
      (condition-case nil
	  (set-face-background-pixmap face pixmap)
	(error
	 (message "Pixmap not found for %S: %s" (face-name face) pixmap)
	 (sit-for 1)))))

  
;; OS/2
(cond ((eq (vip-device-type) 'pm)
       (fset 'vip-color-defined-p
	     (function (lambda (color) (assoc color pm-color-alist))))))
    
;; needed to smooth out the difference between Emacs and XEmacs
(defsubst vip-italicize-face (face)
  (if vip-xemacs-p
      (make-face-italic face)
    (make-face-italic face nil 'noerror)))
    
;; test if display is color and the colors are defined
(defsubst vip-can-use-colors (&rest colors)
  (if (vip-color-display-p)
      (not (memq nil (mapcar 'vip-color-defined-p colors)))
    ))

(defun vip-hide-face (face)
  (if (and (vip-has-face-support-p) vip-emacs-p)
      (add-to-list 'facemenu-unlisted-faces face)))

;; cursor colors
(defun vip-change-cursor-color (new-color)
  (if (and (vip-window-display-p)  (vip-color-display-p)
	   (stringp new-color) (vip-color-defined-p new-color)
	   (not (string= new-color (vip-get-cursor-color))))
      (modify-frame-parameters
       (selected-frame) (list (cons 'cursor-color new-color)))))
	 
(defun vip-save-cursor-color ()
  (if (and (vip-window-display-p) (vip-color-display-p))
      (let ((color (vip-get-cursor-color)))
	(if (and (stringp color) (vip-color-defined-p color)
		 (not (string= color vip-replace-overlay-cursor-color)))
	    (vip-overlay-put vip-replace-overlay 'vip-cursor-color color)))))
	
;; restore cursor color from replace overlay
(defsubst vip-restore-cursor-color-after-replace ()
  (vip-change-cursor-color
   (vip-overlay-get vip-replace-overlay 'vip-cursor-color)))
(defsubst vip-restore-cursor-color-after-insert ()
  (vip-change-cursor-color vip-saved-cursor-color))
	 

;; Face-saving tricks

(defvar vip-search-face
  (if (vip-has-face-support-p)
      (progn
	(make-face 'vip-search-face)
	(vip-hide-face 'vip-search-face)
	(or (face-differs-from-default-p 'vip-search-face)
	    ;; face wasn't set in .vip or .Xdefaults
	    (if (vip-can-use-colors "Black" "khaki")
		(progn
		  (set-face-background 'vip-search-face "khaki")
		  (set-face-foreground 'vip-search-face "Black"))
	      (set-face-underline-p 'vip-search-face t)
	      (vip-set-face-pixmap 'vip-search-face vip-search-face-pixmap)))
	'vip-search-face))
  "*Face used to flash out the search pattern.")
  
(defvar vip-replace-overlay-face
  (if (vip-has-face-support-p)
      (progn
	(make-face 'vip-replace-overlay-face)
	(vip-hide-face 'vip-replace-overlay-face)
	(or (face-differs-from-default-p 'vip-replace-overlay-face)
	    (progn
	      (if (vip-can-use-colors "darkseagreen2" "Black")
		  (progn
		    (set-face-background
		     'vip-replace-overlay-face "darkseagreen2")
		    (set-face-foreground 'vip-replace-overlay-face "Black")))
	      (set-face-underline-p 'vip-replace-overlay-face t)
	      (vip-set-face-pixmap
	       'vip-replace-overlay-face vip-replace-overlay-pixmap)))
	'vip-replace-overlay-face))
  "*Face for highlighting replace regions on a window display.")

(defvar vip-minibuffer-emacs-face
  (if (vip-has-face-support-p)
      (progn
	(make-face 'vip-minibuffer-emacs-face)
	(vip-hide-face 'vip-minibuffer-emacs-face)
	(or (face-differs-from-default-p 'vip-minibuffer-emacs-face)
	    ;; face wasn't set in .vip or .Xdefaults
	    (if vip-vi-style-in-minibuffer
		;; emacs state is an exception in the minibuffer
		(if (vip-can-use-colors "darkseagreen2" "Black")
		    (progn
		      (set-face-background
		       'vip-minibuffer-emacs-face "darkseagreen2")
		      (set-face-foreground
		       'vip-minibuffer-emacs-face "Black"))
		  (copy-face 'modeline 'vip-minibuffer-emacs-face))
	      ;; emacs state is the main state in the minibuffer
	      (if (vip-can-use-colors "Black" "pink")
		  (progn
		    (set-face-background 'vip-minibuffer-emacs-face "pink") 
		    (set-face-foreground
		     'vip-minibuffer-emacs-face "Black"))
		(copy-face 'italic 'vip-minibuffer-emacs-face))
	      ))
	'vip-minibuffer-emacs-face))
  "Face used in the Minibuffer when it is in Emacs state.")
    
(defvar vip-minibuffer-insert-face
  (if (vip-has-face-support-p)
      (progn
	(make-face 'vip-minibuffer-insert-face)
	(vip-hide-face 'vip-minibuffer-insert-face)
	(or (face-differs-from-default-p 'vip-minibuffer-insert-face)
	    (if vip-vi-style-in-minibuffer
		(if (vip-can-use-colors "Black" "pink")
		    (progn
		      (set-face-background 'vip-minibuffer-insert-face "pink") 
		      (set-face-foreground
		       'vip-minibuffer-insert-face "Black"))
		  (copy-face 'italic 'vip-minibuffer-insert-face))
	      ;; If Insert state is an exception
	      (if (vip-can-use-colors "darkseagreen2" "Black")
		  (progn
		    (set-face-background
		     'vip-minibuffer-insert-face "darkseagreen2")
		    (set-face-foreground
		     'vip-minibuffer-insert-face "Black"))
		(copy-face 'modeline 'vip-minibuffer-insert-face))
	      (vip-italicize-face 'vip-minibuffer-insert-face)))
	'vip-minibuffer-insert-face))
  "Face used in the Minibuffer when it is in Insert state.")
    
(defvar vip-minibuffer-vi-face
  (if (vip-has-face-support-p)
      (progn
	(make-face 'vip-minibuffer-vi-face)
	(vip-hide-face 'vip-minibuffer-vi-face)
	(or (face-differs-from-default-p 'vip-minibuffer-vi-face)
	    (if vip-vi-style-in-minibuffer
		(if (vip-can-use-colors "Black" "grey")
		    (progn
		      (set-face-background 'vip-minibuffer-vi-face "grey")
		      (set-face-foreground 'vip-minibuffer-vi-face "Black"))
		  (copy-face 'bold 'vip-minibuffer-vi-face))
	      (copy-face 'bold 'vip-minibuffer-vi-face)
	      (invert-face 'vip-minibuffer-vi-face)))
	'vip-minibuffer-vi-face))
  "Face used in the Minibuffer when it is in Vi state.")
    
;; the current face to be used in the minibuffer
(vip-deflocalvar vip-minibuffer-current-face vip-minibuffer-emacs-face "")
   

;; Check the current version against the major and minor version numbers
;; using op: cur-vers op major.minor If emacs-major-version or
;; emacs-minor-version are not defined, we assume that the current version
;; is hopelessly outdated.  We assume that emacs-major-version and
;; emacs-minor-version are defined.  Otherwise, for Emacs/XEmacs 19, if the
;; current minor version is < 10 (xemacs) or < 23 (emacs) the return value
;; will be nil (when op is =, >, or >=) and t (when op is <, <=), which may be
;; incorrect. However, this gives correct result in our cases, since we are
;; testing for sufficiently high Emacs versions.
(defun vip-check-version (op major minor &optional type-of-emacs)
  (if (and (boundp 'emacs-major-version) (boundp 'emacs-minor-version))
      (and (cond ((eq type-of-emacs 'xemacs) vip-xemacs-p)
		 ((eq type-of-emacs 'emacs) vip-emacs-p)
		 (t t))
	   (cond ((eq op '=) (and (= emacs-minor-version minor)
				  (= emacs-major-version major)))
		 ((memq op '(> >= < <=))
		  (and (or (funcall op emacs-major-version major)
			   (= emacs-major-version major))
		       (if (= emacs-major-version major)
			   (funcall op emacs-minor-version minor)
			 t)))
		 (t
		  (error "%S: Invalid op in vip-check-version" op))))
    (cond ((memq op '(= > >=)) nil)
	  ((memq op '(< <=)) t))))
	  
;;;; warn if it is a wrong version of emacs
;;(if (or (vip-check-version '< 19 35 'emacs)
;;	(vip-check-version '< 19 15 'xemacs))
;;    (progn
;;      (with-output-to-temp-buffer " *vip-info*"
;;	(switch-to-buffer " *vip-info*")
;;	(insert
;;	 (format "
;;
;;This version of Viper requires 
;;
;;\t Emacs 19.35 and higher
;;\t OR
;;\t XEmacs 19.15 and higher
;;
;;It is unlikely to work under Emacs version %s
;;that you are using... " emacs-version))
;;
;;	(if noninteractive
;;	    ()
;;	  (beep 1)
;;	  (beep 1)
;;	  (insert "\n\nType any key to continue... ")
;;	  (vip-read-event)))
;;      (kill-buffer " *vip-info*")))
  

(defun vip-get-visible-buffer-window (wind)
  (if vip-xemacs-p
      (get-buffer-window wind t)
    (get-buffer-window wind 'visible)))
    
    
;; Return line position.
;; If pos is 'start then returns position of line start.
;; If pos is 'end, returns line end. If pos is 'mid, returns line center.
;; Pos = 'indent returns beginning of indentation.
;; Otherwise, returns point. Current point is not moved in any case."
(defun vip-line-pos (pos)
  (let ((cur-pos (point))
        (result))
    (cond
     ((equal pos 'start)
      (beginning-of-line))
     ((equal pos 'end)
      (end-of-line))
     ((equal pos 'mid)
      (goto-char (+ (vip-line-pos 'start) (vip-line-pos 'end) 2)))
     ((equal pos 'indent)
      (back-to-indentation))
     (t   nil))
    (setq result (point))
    (goto-char cur-pos)
    result))


;; Like move-marker but creates a virgin marker if arg isn't already a marker.
;; The first argument must eval to a variable name.
;; Arguments: (var-name position &optional buffer).
;; 
;; This is useful for moving markers that are supposed to be local.
;; For this, VAR-NAME should be made buffer-local with nil as a default.
;; Then, each time this var is used in `vip-move-marker-locally' in a new
;; buffer, a new marker will be created.
(defun vip-move-marker-locally (var pos &optional buffer)
  (if (markerp (eval var))
      ()
    (set var (make-marker)))
  (move-marker (eval var) pos buffer))


;; Print CONDITIONS as a message.
(defun vip-message-conditions (conditions)
  (let ((case (car conditions)) (msg (cdr conditions)))
    (if (null msg)
	(message "%s" case)
      (message "%s: %s" case (mapconcat 'prin1-to-string msg " ")))
    (beep 1)))



;;; List/alist utilities
	
;; Convert LIST to an alist
(defun vip-list-to-alist (lst)
  (let ((alist))
    (while lst
      (setq alist (cons (list (car lst)) alist))
      (setq lst (cdr lst)))
    alist))	

;; Convert ALIST to a list.
(defun vip-alist-to-list (alst)
  (let ((lst))
    (while alst
      (setq lst (cons (car (car alst)) lst))
      (setq alst (cdr alst)))
    lst))

;; Filter ALIST using REGEXP. Return alist whose elements match the regexp.
(defun vip-filter-alist (regexp alst)
  (interactive "s x")
  (let ((outalst) (inalst alst))
    (while (car inalst)
      (if (string-match regexp (car (car inalst)))
	  (setq outalst (cons (car inalst) outalst)))
      (setq inalst (cdr inalst)))
    outalst))    
       
;; Filter LIST using REGEXP. Return list whose elements match the regexp.
(defun vip-filter-list (regexp lst)
  (interactive "s x")
  (let ((outlst) (inlst lst))
    (while (car inlst)
      (if (string-match regexp (car inlst))
	  (setq outlst (cons (car inlst) outlst)))
      (setq inlst (cdr inlst)))
    outlst))    

   
;; Append LIS2 to LIS1, both alists, by side-effect and returns LIS1
;; LIS2 is modified by filtering it: deleting its members of the form
;; \(car elt\) such that (car elt') is in LIS1.
(defun vip-append-filter-alist (lis1 lis2)
  (let ((temp lis1)
	elt)
  
    ;;filter-append the second list
    (while temp
      ;; delete all occurrences
      (while (setq elt (assoc (car (car temp)) lis2))
	(setq lis2 (delq elt lis2)))
      (setq temp (cdr temp)))
    
    (nconc lis1 lis2)))


;;; Support for :e and file globbing

(defun vip-ex-nontrivial-find-file-unix (filespec)
  "Glob the file spec and visit all files matching the spec.
This function is designed to work under Unix. It may also work under VMS.

Users who prefer other types of shells should write their own version of this
function and set the variable `ex-nontrivial-find-file-function'
appropriately." 
  (let ((gshell
	 (cond (ex-unix-type-shell shell-file-name)
	       ((memq system-type '(vax-vms axp-vms)) "*dcl*") ; VAX VMS
	       (t "sh"))) ; probably Unix anyway
	(gshell-options
	 ;; using cond in anticipation of further additions
	 (cond (ex-unix-type-shell-options)
	       ))
	(command (cond (vip-ms-style-os-p (format "\"ls -1 -d %s\"" filespec))
		       (t (format "ls -1 -d %s" filespec))))
	file-list status)
    (save-excursion 
      (set-buffer (get-buffer-create vip-ex-tmp-buf-name))
      (erase-buffer)
      (setq status
	    (if gshell-options
		(call-process gshell nil t nil
			      gshell-options
			      "-c"
			      command)
	      (call-process gshell nil t nil
			    "-c"
			    command)))
      (goto-char (point-min))
      ;; Issue an error, if no match.
      (if (> status 0)
	  (save-excursion
	    (skip-chars-forward " \t\n\j")
	    (if (looking-at "ls:")
		(vip-forward-Word 1))
	    (error "%s: %s"
		   (if (stringp  gshell)
		       gshell
		     "shell")
		   (buffer-substring (point) (vip-line-pos 'end)))
	    ))
      (goto-char (point-min))
      (setq file-list (vip-get-filenames-from-buffer 'one-per-line)))

    (mapcar 'find-file file-list)
    ))

(defun vip-ex-nontrivial-find-file-ms (filespec)
  "Glob the file spec and visit all files matching the spec.
This function is designed to work under MS type systems, such as NT, W95, and
DOS. It may also work under OS/2.

The users of Unix-type shells should be able to use
`vip-ex-nontrivial-find-file-unix', making it into the value of the variable 
`ex-nontrivial-find-file-function'. If this doesn't work, the user may have
to write a custom function, similar to `vip-ex-nontrivial-find-file-unix'."
  (save-excursion 
    (set-buffer (get-buffer-create vip-ex-tmp-buf-name))
    (erase-buffer)
    (insert filespec)
    (goto-char (point-min))
    (mapcar 'find-file
	    (vip-glob-ms-windows-files (vip-get-filenames-from-buffer)))
    ))


;; Interpret the stuff in the buffer as a list of file names
;; return a list of file names listed in the buffer beginning at point
;; If optional arg is supplied, assume each filename is listed on a separate
;; line
(defun vip-get-filenames-from-buffer (&optional one-per-line)
  (let ((skip-chars (if one-per-line "\t\n" " \t\n"))
	 result fname delim)
    (skip-chars-forward skip-chars)
    (while (not (eobp))
      (if (cond ((looking-at "\"")
		 (setq delim ?\")
		 (re-search-forward "[^\"]+" nil t)) ; noerror
		((looking-at "'")
		 (setq delim ?')
		 (re-search-forward "[^']+" nil t)) ; noerror
		(t 
		 (re-search-forward
		  (concat "[^" skip-chars "]+") nil t))) ;noerror
	  (setq fname
		(buffer-substring (match-beginning 0) (match-end 0))))
      (if delim
	  (forward-char 1))
      (skip-chars-forward " \t\n")
      (setq result (cons fname result)))
    result))

;; convert MS-DOS wildcards to regexp
(defun vip-wildcard-to-regexp (wcard)
  (save-excursion
    (set-buffer (get-buffer-create vip-ex-tmp-buf-name))
    (erase-buffer)
    (insert wcard)
    (goto-char (point-min))
    (while (not (eobp))
      (skip-chars-forward "^*?.\\\\")
      (cond ((eq (char-after (point)) ?*) (insert ".")(forward-char 1))
	    ((eq (char-after (point)) ?.) (insert "\\")(forward-char 1))
	    ((eq (char-after (point)) ?\\) (insert "\\")(forward-char 1))
	    ((eq (char-after (point)) ??) (delete-char 1)(insert ".")))
      )
    (buffer-string)
    ))


;; glob windows files
;; LIST is expected to be in reverse order
(defun vip-glob-ms-windows-files (list)
  (let ((tmp list)
	(case-fold-search t)
	tmp2)
    (while tmp
      (setq tmp2 (cons (directory-files 
			;; the directory part
			(or (file-name-directory (car tmp))
			    "")
			t  ; return full names
			;; the regexp part: globs the file names
			(concat "^"
				(vip-wildcard-to-regexp
				 (file-name-nondirectory (car tmp)))
				"$"))
		       tmp2))
      (setq tmp (cdr tmp)))
    (reverse (apply 'append tmp2))))


;;; Insertion ring

;; Rotate RING's index. DIRection can be positive or negative.
(defun vip-ring-rotate1 (ring dir)
  (if (and (ring-p ring) (> (ring-length ring) 0))
      (progn
	(setcar ring (cond ((> dir 0)
			    (ring-plus1 (car ring) (ring-length ring)))
			   ((< dir 0)
			    (ring-minus1 (car ring) (ring-length ring)))
			   ;; don't rotate if dir = 0
			   (t (car ring))))
	(vip-current-ring-item ring)
	)))
	
(defun vip-special-ring-rotate1 (ring dir)
  (if (memq vip-intermediate-command
	    '(repeating-display-destructive-command
	      repeating-insertion-from-ring))
      (vip-ring-rotate1 ring dir)
    ;; don't rotate otherwise
    (vip-ring-rotate1 ring 0)))
    
;; current ring item; if N is given, then so many items back from the
;; current
(defun vip-current-ring-item (ring &optional n)
  (setq n (or n 0))
  (if (and (ring-p ring) (> (ring-length ring) 0))
      (aref (cdr (cdr ring)) (mod (- (car ring) 1 n) (ring-length ring)))))
    
;; push item onto ring. the second argument is a ring-variable, not value.
(defun vip-push-onto-ring (item ring-var)
  (or (ring-p (eval ring-var))
      (set ring-var (make-ring (eval (intern (format "%S-size" ring-var))))))
  (or (null item) ; don't push nil
      (and (stringp item) (string= item "")) ; or empty strings
      (equal item (vip-current-ring-item (eval ring-var))) ; or old stuff
      ;; Since vip-set-destructive-command checks if we are inside vip-repeat,
      ;;    we don't check whether this-command-keys is a `.'.
      ;;    The cmd vip-repeat makes a call to the current function only if
      ;;    `.' is executing a command from the command history. It doesn't
      ;;    call the push-onto-ring function if `.' is simply repeating the
      ;;    last destructive command.
      ;; We only check for ESC (which happens when we do insert with a
      ;;    prefix argument, or if this-command-keys doesn't give anything
      ;;    meaningful (in that case we don't know what to show to the user).
      (and (eq ring-var 'vip-command-ring)
	   (string-match "\\([0-9]*\e\\|^[ \t]*$\\|escape\\)"
			 (vip-array-to-string (this-command-keys))))
      (vip-ring-insert (eval ring-var) item))
  )
  

;; removing elts from ring seems to break it
(defun vip-cleanup-ring (ring)
  (or (< (ring-length ring) 2)
      (null (vip-current-ring-item ring))
      ;; last and previous equal
      (if (equal (vip-current-ring-item ring) (vip-current-ring-item ring 1))
	  (vip-ring-pop ring))))
	  
;; ring-remove seems to be buggy, so we concocted this for our purposes.
(defun vip-ring-pop (ring)
  (let* ((ln (ring-length ring))
	 (vec (cdr (cdr ring)))
	 (veclen (length vec))
	 (hd (car ring))
	 (idx (max 0 (ring-minus1 hd ln)))
	 (top-elt (aref vec idx)))
	
	;; shift elements
	(while (< (1+ idx) veclen)
	  (aset vec idx (aref vec (1+ idx)))
	  (setq idx (1+ idx)))
	(aset vec idx nil)
	
	(setq hd (max 0 (ring-minus1 hd ln)))
	(if (= hd (1- ln)) (setq hd 0))
	(setcar ring hd) ; move head
	(setcar (cdr ring) (max 0 (1- ln))) ; adjust length
	top-elt
	))
	
(defun vip-ring-insert (ring item)
  (let* ((ln (ring-length ring))
	 (vec (cdr (cdr ring)))
	 (veclen (length vec))
	 (hd (car ring))
	 (vecpos-after-hd (if (= hd 0) ln hd))
	 (idx ln))
	 
    (if (= ln veclen)
	(progn
	  (aset vec hd item) ; hd is always 1+ the actual head index in vec
	  (setcar ring (ring-plus1 hd ln)))
      (setcar (cdr ring) (1+ ln))
      (setcar ring (ring-plus1 vecpos-after-hd (1+ ln)))
      (while (and (>= idx vecpos-after-hd) (> ln 0))
	(aset vec idx (aref vec (1- idx)))
	(setq idx (1- idx)))
      (aset vec vecpos-after-hd item))
    item))
	

;;; String utilities

;; If STRING is longer than MAX-LEN, truncate it and print ...... instead
;; PRE-STRING is a string to prepend to the abbrev string.
;; POST-STRING is a string to append to the abbrev string.
;; ABBREV_SIGN is a string to be inserted before POST-STRING
;; if the orig string was truncated. 
(defun vip-abbreviate-string (string max-len
				     pre-string post-string abbrev-sign)
  (let (truncated-str)
    (setq truncated-str
	  (if (stringp string) 
	      (substring string 0 (min max-len (length string)))))
    (cond ((null truncated-str) "")
	  ((> (length string) max-len)
	   (format "%s%s%s%s"
		   pre-string truncated-str abbrev-sign post-string))
	  (t (format "%s%s%s" pre-string truncated-str post-string)))))

;; tells if we are over a whitespace-only line
(defsubst vip-over-whitespace-line ()
  (save-excursion
    (beginning-of-line)
    (looking-at "^[ \t]*$")))
	  

;;; Saving settings in custom file

;; Save the current setting of VAR in CUSTOM-FILE.
;; If given, MESSAGE is a message to be displayed after that.
;; This message is erased after 2 secs, if erase-msg is non-nil.
;; Arguments: var message custom-file &optional erase-message
(defun vip-save-setting (var message custom-file &optional erase-msg)
  (let* ((var-name (symbol-name var))
	 (var-val (if (boundp var) (eval var)))
	 (regexp (format "^[^;]*%s[ \t\n]*[a-zA-Z---_']*[ \t\n)]" var-name))
	 (buf (find-file-noselect (substitute-in-file-name custom-file)))
	)
    (message message)
    (save-excursion
      (set-buffer buf)
      (goto-char (point-min))
      (if (re-search-forward regexp nil t)
	  (let ((reg-end (1- (match-end 0))))
	    (search-backward var-name)
	    (delete-region (match-beginning 0) reg-end)
	    (goto-char (match-beginning 0))
	    (insert (format "%s  '%S" var-name var-val)))
	(goto-char (point-max))
	(if (not (bolp)) (insert "\n"))
	(insert (format "(setq %s '%S)\n" var-name var-val)))
      (save-buffer))
      (kill-buffer buf)
      (if erase-msg
	  (progn
	    (sit-for 2)
	    (message "")))
      ))
      
;; Save STRING in CUSTOM-FILE. If PATTERN is non-nil, remove strings that
;; match this pattern.
(defun vip-save-string-in-file (string custom-file &optional pattern)
  (let ((buf (find-file-noselect (substitute-in-file-name custom-file))))
    (save-excursion
      (set-buffer buf)
      (goto-char (point-min))
      (if pattern (delete-matching-lines pattern))
      (goto-char (point-max))
      (if string (insert string))
      (save-buffer))
    (kill-buffer buf)
    ))
    

;;; Overlays

;; Search

(defun vip-flash-search-pattern ()
  (if (vip-overlay-p vip-search-overlay)
      (vip-move-overlay vip-search-overlay (match-beginning 0) (match-end 0))
    (setq vip-search-overlay
	  (vip-make-overlay
	   (match-beginning 0) (match-end 0) (current-buffer))))
  
  (vip-overlay-put vip-search-overlay 'priority vip-search-overlay-priority)
  (if (vip-has-face-support-p)
      (progn
	(vip-overlay-put vip-search-overlay 'face vip-search-face)
	(sit-for 2)
	(vip-overlay-put vip-search-overlay 'face nil))))


;; Replace state

(defsubst vip-move-replace-overlay (beg end)
  (vip-move-overlay vip-replace-overlay beg end))
  
(defun vip-set-replace-overlay (beg end)
  (if (vip-overlay-p vip-replace-overlay)
      (vip-move-replace-overlay beg end)
    (setq vip-replace-overlay (vip-make-overlay beg end (current-buffer)))
    ;; never detach
    (vip-overlay-put
     vip-replace-overlay (if vip-emacs-p 'evaporate 'detachable) nil)
    (vip-overlay-put 
     vip-replace-overlay 'priority vip-replace-overlay-priority)
    ;; If Emacs will start supporting overlay maps, as it currently supports
    ;; text-property maps, we could do away with vip-replace-minor-mode and
    ;; just have keymap attached to replace overlay.
    ;;(vip-overlay-put
    ;; vip-replace-overlay
    ;; (if vip-xemacs-p 'keymap 'local-map)
    ;; vip-replace-map)
    ) 
  (if (vip-has-face-support-p)
      (vip-overlay-put vip-replace-overlay 'face vip-replace-overlay-face))
  (vip-save-cursor-color)
  (vip-change-cursor-color vip-replace-overlay-cursor-color)
  )
  
      
(defun vip-set-replace-overlay-glyphs (before-glyph after-glyph)
  (if (or (not (vip-has-face-support-p))
	  vip-use-replace-region-delimiters)
      (let ((before-name (if vip-xemacs-p 'begin-glyph 'before-string))
	    (after-name (if vip-xemacs-p 'end-glyph 'after-string)))
	(vip-overlay-put vip-replace-overlay before-name before-glyph)
	(vip-overlay-put vip-replace-overlay after-name after-glyph))))
  
(defun vip-hide-replace-overlay ()
  (vip-set-replace-overlay-glyphs nil nil)
  (vip-restore-cursor-color-after-replace)
  (vip-restore-cursor-color-after-insert)
  (if (vip-has-face-support-p)
      (vip-overlay-put vip-replace-overlay 'face nil)))

    
(defsubst vip-replace-start ()
  (vip-overlay-start vip-replace-overlay))
(defsubst vip-replace-end ()
  (vip-overlay-end vip-replace-overlay))
 

;; Minibuffer

(defun vip-set-minibuffer-overlay ()
  (vip-check-minibuffer-overlay)
  (if (vip-has-face-support-p)
      (progn
	(vip-overlay-put
	 vip-minibuffer-overlay 'face vip-minibuffer-current-face)
	(vip-overlay-put 
	 vip-minibuffer-overlay 'priority vip-minibuffer-overlay-priority)
	;; never detach
	(vip-overlay-put
	 vip-minibuffer-overlay (if vip-emacs-p 'evaporate 'detachable) nil)
	;; make vip-minibuffer-overlay open-ended
	;; In emacs, it is made open ended at creation time
	(if vip-xemacs-p
	    (progn
	      (vip-overlay-put vip-minibuffer-overlay 'start-open nil)
	      (vip-overlay-put vip-minibuffer-overlay 'end-open nil)))
	)))
       
(defun vip-check-minibuffer-overlay ()
  (or (vip-overlay-p vip-minibuffer-overlay)
      (setq vip-minibuffer-overlay
	    (if vip-xemacs-p
		(vip-make-overlay 1 (1+ (buffer-size)) (current-buffer))
	      ;; make overlay open-ended
	      (vip-make-overlay
	       1 (1+ (buffer-size)) (current-buffer) nil 'rear-advance)))
      ))


(defsubst vip-is-in-minibuffer ()
  (string-match "\*Minibuf-" (buffer-name)))
  


;;; XEmacs compatibility

(defun vip-abbreviate-file-name (file)
  (if vip-emacs-p
      (abbreviate-file-name file)
    ;; XEmacs requires addl argument
    (abbreviate-file-name file t)))
    
;; Sit for VAL milliseconds. XEmacs doesn't support the millisecond arg 
;; in sit-for, so this function smoothes out the differences.
(defsubst vip-sit-for-short (val &optional nodisp)
  (if vip-xemacs-p
      (sit-for (/ val 1000.0) nodisp)
    (sit-for 0 val nodisp)))

;; EVENT may be a single event of a sequence of events
(defsubst vip-ESC-event-p (event)
  (let ((ESC-keys '(?\e (control \[) escape))
	(key (vip-event-key event)))
    (member key ESC-keys)))

;; checks if object is a marker, has a buffer, and points to within that buffer
(defun vip-valid-marker (marker)
  (if (and (markerp marker) (marker-buffer marker))
      (let ((buf (marker-buffer marker))
	    (pos (marker-position marker)))
	(save-excursion
	  (set-buffer buf)
	  (and (<= pos (point-max)) (<= (point-min) pos))))))
  
(defsubst vip-mark-marker ()
  (if vip-xemacs-p
      (mark-marker t)
    (mark-marker)))

;; like (set-mark-command nil) but doesn't push twice, if (car mark-ring)
;; is the same as (mark t).
(defsubst vip-set-mark-if-necessary ()
  (setq mark-ring (delete (vip-mark-marker) mark-ring))
  (set-mark-command nil))
       
;; In transient mark mode (zmacs mode), it is annoying when regions become
;; highlighted due to Viper's pushing marks. So, we deactivate marks, unless
;; the user explicitly wants highlighting, e.g., by hitting '' or ``
(defun vip-deactivate-mark ()
  (if vip-xemacs-p
      (zmacs-deactivate-region)
    (deactivate-mark)))

(defsubst vip-leave-region-active ()
  (if vip-xemacs-p
      (setq zmacs-region-stays t)))

;; Check if arg is a valid character for register
;; TYPE is a list that can contain `letter', `Letter', and `digit'.
;; Letter means lowercase letters, Letter means uppercase letters, and
;; digit means digits from 1 to 9.
;; If TYPE is nil, then down/uppercase letters and digits are allowed.
(defun vip-valid-register (reg &optional type)
  (or type (setq type '(letter Letter digit)))
  (or (if (memq 'letter type)
	  (and (<= ?a reg) (<= reg ?z)))
      (if (memq 'digit type)
	  (and (<= ?1 reg) (<= reg ?9)))
      (if (memq 'Letter type)
	  (and (<= ?A reg) (<= reg ?Z)))
      ))

    
(defsubst vip-events-to-keys (events)
  (cond (vip-xemacs-p (events-to-keys events))
	(t events)))
		  
	
(defun vip-eval-after-load (file form)
  (if vip-emacs-p
      (eval-after-load file form)
    (or (assoc file after-load-alist)
	(setq after-load-alist (cons (list file) after-load-alist)))
    (let ((elt (assoc file after-load-alist)))
      (or (member form (cdr elt))
	  (setq elt (nconc elt (list form)))))
    form
    ))

;; This is here because Emacs changed the way local hooks work.
;;
;;Add to the value of HOOK the function FUNCTION.
;;FUNCTION is not added if already present.
;;FUNCTION is added (if necessary) at the beginning of the hook list
;;unless the optional argument APPEND is non-nil, in which case
;;FUNCTION is added at the end.
;;
;;HOOK should be a symbol, and FUNCTION may be any valid function.  If
;;HOOK is void, it is first set to nil.  If HOOK's value is a single
;;function, it is changed to a list of functions."
(defun vip-add-hook (hook function &optional append)
  (if (not (boundp hook)) (set hook nil))
  ;; If the hook value is a single function, turn it into a list.
  (let ((old (symbol-value hook)))
    (if (or (not (listp old)) (eq (car old) 'lambda))
	(setq old (list old)))
    (if (member function old)
	nil
      (set hook (if append
		    (append old (list function)) ; don't nconc
		  (cons function old))))))

;; This is here because of Emacs's changes in the semantics of add/remove-hooks
;; and due to the bugs they introduced.
;;
;; Remove from the value of HOOK the function FUNCTION.
;; HOOK should be a symbol, and FUNCTION may be any valid function.  If
;; FUNCTION isn't the value of HOOK, or, if FUNCTION doesn't appear in the
;; list of hooks to run in HOOK, then nothing is done.  See `vip-add-hook'."
(defun vip-remove-hook (hook function)
  (if (or (not (boundp hook))		;unbound symbol, or
	  (null (symbol-value hook))	;value is nil, or
	  (null function))		;function is nil, then
      nil				;Do nothing.
    (let ((hook-value (symbol-value hook)))
      (if (consp hook-value)
	  ;; don't side-effect the list
	  (setq hook-value (delete function (copy-sequence hook-value)))
	(if (equal hook-value function)
	    (setq hook-value nil)))
      (set hook hook-value))))

    
;; it is suggested that an event must be copied before it is assigned to
;; last-command-event in XEmacs
(defun vip-copy-event (event)
  (if vip-xemacs-p
      (copy-event event)
    event))
    
;; like read-event, but in XEmacs also try to convert to char, if possible
(defun vip-read-event-convert-to-char ()
  (let (event)
    (if vip-emacs-p
	(read-event)
      (setq event (next-command-event))
      (or (event-to-character event)
	  event))
    ))

;; This function lets function-key-map convert key sequences into logical
;; keys. This does a better job than vip-read-event when it comes to kbd
;; macros, since it enables certain macros to be shared between X and TTY modes
;; by correctly mapping key sequences for Left/Right/... (one an ascii
;; terminal) into logical keys left, right, etc.
(defun vip-read-key () 
  (let ((overriding-local-map vip-overriding-map) 
	(inhibit-quit t)
        key) 
    (use-global-map vip-overriding-map) 
    (setq key (elt (read-key-sequence nil) 0)) 
    (use-global-map global-map) 
    key))


;; Emacs has a bug in eventp, which causes (eventp nil) to return (nil)
;; instead of nil, if '(nil) was previously inadvertently assigned to
;; unread-command-events
(defun vip-event-key (event)
  (or (and event (eventp event))
      (error "vip-event-key: Wrong type argument, eventp, %S" event))
  (when (cond (vip-xemacs-p (or (key-press-event-p event)
				(mouse-event-p event)))
	      (t t))
    (let ((mod (event-modifiers event))
	  basis)
      (setq basis
	    (cond
	     (vip-xemacs-p
	      (cond ((key-press-event-p event)
		     (event-key event))
		    ((button-event-p event)
		     (concat "mouse-" (prin1-to-string (event-button event))))
		    (t 
		     (error "vip-event-key: Unknown event, %S" event))))
	     (t 
	      ;; Emacs doesn't handle capital letters correctly, since
	      ;; \S-a isn't considered the same as A (it behaves as
	      ;; plain `a' instead). So we take care of this here
	      (cond ((and (vip-characterp event) (<= ?A event) (<= event ?Z))
		     (setq mod nil
			   event event))
		    ;; Emacs has the oddity whereby characters 128+char
		    ;; represent M-char *if* this appears inside a string.
		    ;; So, we convert them manually to (meta char).
		    ((and (vip-characterp event)
			  (< ?\C-? event) (<= event 255))
		     (setq mod '(meta)
			   event (- event ?\C-? 1)))
		    (t (event-basic-type event)))
	      )))
      (if (vip-characterp basis)
	  (setq basis
		(if (= basis ?\C-?)
		    (list 'control '\?) ; taking care of an emacs bug
		  (intern (char-to-string basis)))))
      (if mod
	  (append mod (list basis))
	basis))))
    
(defun vip-key-to-emacs-key (key)
  (let (key-name char-p modifiers mod-char-list base-key base-key-name)
    (cond (vip-xemacs-p key)

	  ((symbolp key)
	   (setq key-name (symbol-name key))
	   (cond ((= (length key-name) 1) ; character event
		  (string-to-char key-name))
		 ;; Emacs doesn't recognize `return' and `escape' as events on
		 ;; dumb terminals, so we translate them into characters
		 ((and vip-emacs-p (not (vip-window-display-p))
		       (string= key-name "return"))
		  ?\C-m)
		 ((and vip-emacs-p (not (vip-window-display-p))
		       (string= key-name "escape"))
		  ?\e)
		 ;; pass symbol-event as is
		 (t key)))

	  ((listp key)
	   (setq modifiers (subseq key 0 (1- (length key)))
		 base-key (vip-seq-last-elt key)
		 base-key-name (symbol-name base-key)
		 char-p (= (length base-key-name) 1))
	   (setq mod-char-list
		 (mapcar
		  '(lambda (elt) (upcase (substring (symbol-name elt) 0 1)))
		  modifiers))
	   (if char-p
	       (setq key-name
		     (car (read-from-string
			   (concat
			    "?\\"
			    (mapconcat 'identity mod-char-list "-\\")
			    "-"
			    base-key-name))))
	     (setq key-name
		   (intern
		    (concat
		     (mapconcat 'identity mod-char-list "-")
		     "-"
		     base-key-name))))))
    ))


;; Args can be a sequence of events, a string, or a Viper macro.  Will try to
;; convert events to keys and, if all keys are regular printable
;; characters, will return a string. Otherwise, will return a string
;; representing a vector of converted events. If the input was a Viper macro,
;; will return a string that represents this macro as a vector.
(defun vip-array-to-string (event-seq)
  (let (temp temp2)
    (cond ((stringp event-seq) event-seq)
	  ((vip-event-vector-p event-seq)
	    (setq temp (mapcar 'vip-event-key event-seq))
	    (cond ((vip-char-symbol-sequence-p temp)
		   (mapconcat 'symbol-name temp ""))
		  ((and (vip-char-array-p
			 (setq temp2 (mapcar 'vip-key-to-character temp))))
		   (mapconcat 'char-to-string temp2 ""))
		  (t (prin1-to-string (vconcat temp)))))
	  ((vip-char-symbol-sequence-p event-seq)
	   (mapconcat 'symbol-name event-seq ""))
	  ((and (vectorp event-seq) 
		(vip-char-array-p
		 (setq temp (mapcar 'vip-key-to-character event-seq))))
	   (mapconcat 'char-to-string temp ""))
	  (t (prin1-to-string event-seq)))))

(defun vip-key-press-events-to-chars (events)
  (mapconcat (if vip-emacs-p
		 'char-to-string
	       (function
		(lambda (elt) (char-to-string (event-to-character elt)))))
	     events
	     ""))
	   
    
;; Uses different timeouts for ESC-sequences and others
(defsubst vip-fast-keysequence-p ()
  (not (vip-sit-for-short 
	(if (vip-ESC-event-p last-input-event)
	    vip-ESC-keyseq-timeout
	  vip-fast-keyseq-timeout)
	t)))
    
(defun vip-read-char-exclusive ()
  (let (char
	(echo-keystrokes 1))
    (while (null char)
      (condition-case nil
	  (setq char (read-char))
	(error
	 ;; skip event if not char
	 (vip-read-event))))
    char))

;; key is supposed to be in viper's representation, e.g., (control l), a
;; character, etc.
(defun vip-key-to-character (key)
  (cond ((eq key 'space) ?\ )
	((eq key 'delete) ?\C-?)
	((eq key 'backspace) ?\C-h)
	((and (symbolp key)
	      (= 1 (length (symbol-name key))))
	 (string-to-char (symbol-name key)))
	((and (listp key)
	      (eq (car key) 'control)
	      (symbol-name (nth 1 key))
	      (= 1 (length (symbol-name (nth 1 key)))))
	 (read (format "?\\C-%s" (symbol-name (nth 1 key)))))
	(t key)))
    
      
(defun vip-setup-master-buffer (&rest other-files-or-buffers)
  "Set up the current buffer as a master buffer.
Arguments become related buffers. This function should normally be used in
the `Local variables' section of a file."
  (setq vip-related-files-and-buffers-ring 
	(make-ring (1+ (length other-files-or-buffers))))
  (mapcar '(lambda (elt)
	     (vip-ring-insert vip-related-files-and-buffers-ring elt))
	  other-files-or-buffers)
  (vip-ring-insert vip-related-files-and-buffers-ring (buffer-name))
  )

;;; Movement utilities

(defcustom vip-syntax-preference 'strict-vi
  "*Syntax type characterizing Viper's alphanumeric symbols.
`emacs' means only word constituents are considered to be alphanumeric.
Word constituents are symbols specified as word constituents by the current
syntax table.
`extended' means word and symbol constituents.
`reformed-vi' means Vi-ish behavior: word constituents and the symbol `_'.
However, word constituents are determined according to Emacs syntax tables,
which may be different from Vi in some major modes.
`strict-vi' means Viper words are exactly as in Vi."
  :type '(radio (const strict-vi) (const reformed-vi) 
		 (const extended) (const emacs))
  :group 'viper)

(vip-deflocalvar vip-ALPHA-char-class "w"
  "String of syntax classes characterizing Viper's alphanumeric symbols.
In addition, the symbol `_' may be considered alphanumeric if
`vip-syntax-preference'is `reformed-vi'.")

(vip-deflocalvar vip-strict-ALPHA-chars "a-zA-Z0-9_"
  "Regexp matching the set of alphanumeric characters acceptable to strict
Vi.")
(vip-deflocalvar vip-strict-SEP-chars " \t\n"
  "Regexp matching the set of alphanumeric characters acceptable to strict
Vi.")

(vip-deflocalvar vip-SEP-char-class " -"
  "String of syntax classes for Vi separators.
Usually contains ` ', linefeed, TAB or formfeed.")

(defun vip-update-alphanumeric-class ()
  "Set the syntax class of Viper alphanumerals according to `vip-syntax-preference'.
Must be called in order for changes to `vip-syntax-preference' to take effect."
  (interactive)
  (setq-default
   vip-ALPHA-char-class
   (cond ((eq vip-syntax-preference 'emacs) "w")     ; only word constituents
	 ((eq vip-syntax-preference 'extended) "w_") ; word & symbol chars
	 (t "w"))))     ; vi syntax: word constituents and the symbol `_'

;; addl-chars are characters to be temporarily considered as alphanumerical
(defun vip-looking-at-alpha (&optional addl-chars)
  (or (stringp addl-chars) (setq addl-chars ""))
  (if (eq vip-syntax-preference 'reformed-vi)
      (setq addl-chars (concat addl-chars "_")))
  (let ((char (char-after (point))))
    (if char
	(if (eq vip-syntax-preference 'strict-vi)
	    (looking-at (concat "[" vip-strict-ALPHA-chars addl-chars "]"))
	  (or (memq char
		    ;; convert string to list
		    (append (vconcat addl-chars) nil))
	      (memq (char-syntax char)
		    (append (vconcat vip-ALPHA-char-class) nil)))))
    ))

(defun vip-looking-at-separator ()
  (let ((char (char-after (point))))
    (if char
	(or (eq char ?\n) ; RET is always a separator in Vi
	    (memq (char-syntax char)
		  (append (vconcat vip-SEP-char-class) nil))))))

(defsubst vip-looking-at-alphasep (&optional addl-chars)
  (or (vip-looking-at-separator) (vip-looking-at-alpha addl-chars)))

(defun vip-skip-alpha-forward (&optional addl-chars)
  (or (stringp addl-chars) (setq addl-chars ""))
  (vip-skip-syntax
   'forward 
   (cond ((eq vip-syntax-preference 'strict-vi)
	  "")
	 (t vip-ALPHA-char-class ))
   (cond ((eq vip-syntax-preference 'strict-vi)
	  (concat vip-strict-ALPHA-chars addl-chars))
	 (t addl-chars))))

(defun vip-skip-alpha-backward (&optional addl-chars)
  (or (stringp addl-chars) (setq addl-chars ""))
  (vip-skip-syntax
   'backward 
   (cond ((eq vip-syntax-preference 'strict-vi)
	  "")
	 (t vip-ALPHA-char-class ))
   (cond ((eq vip-syntax-preference 'strict-vi)
	  (concat vip-strict-ALPHA-chars addl-chars))
	 (t addl-chars))))

;; weird syntax tables may confuse strict-vi style
(defsubst vip-skip-all-separators-forward (&optional within-line)
  (vip-skip-syntax 'forward
		   vip-SEP-char-class
		   (or within-line "\n")
		   (if within-line (vip-line-pos 'end))))
(defsubst vip-skip-all-separators-backward (&optional within-line)
  (vip-skip-syntax 'backward
		   vip-SEP-char-class
		   (or within-line "\n")
		   (if within-line (vip-line-pos 'start))))
(defun vip-skip-nonseparators (direction)
  (let ((func (intern (format "skip-syntax-%S" direction))))
    (funcall func (concat "^" vip-SEP-char-class)
	     (vip-line-pos (if (eq direction 'forward) 'end 'start)))))

(defun vip-skip-nonalphasep-forward ()
  (if (eq vip-syntax-preference 'strict-vi)
      (skip-chars-forward
       (concat "^" vip-strict-SEP-chars vip-strict-ALPHA-chars))
    (skip-syntax-forward
     (concat
      "^" vip-ALPHA-char-class vip-SEP-char-class) (vip-line-pos 'end))))
(defun vip-skip-nonalphasep-backward ()
  (if (eq vip-syntax-preference 'strict-vi)
      (skip-chars-backward
       (concat "^" vip-strict-SEP-chars vip-strict-ALPHA-chars))
    (skip-syntax-backward
     (concat
      "^" vip-ALPHA-char-class vip-SEP-char-class) (vip-line-pos 'start))))

;; Skip SYNTAX like skip-syntax-* and ADDL-CHARS like skip-chars-*
;; Return the number of chars traveled.
;; Either SYNTAX or ADDL-CHARS can be nil, in which case they are interpreted
;; as an empty string.
(defun vip-skip-syntax (direction syntax addl-chars &optional limit)
  (let ((total 0)
	(local 1)
	(skip-chars-func (intern (format "skip-chars-%S" direction)))
	(skip-syntax-func (intern (format "skip-syntax-%S" direction))))
    (or (stringp addl-chars) (setq addl-chars ""))
    (or (stringp syntax) (setq syntax ""))
    (while (and (not (= local 0)) (not (eobp)))
      (setq local
	    (+ (funcall skip-syntax-func syntax limit)
	       (funcall skip-chars-func addl-chars limit)))
      (setq total (+ total local)))
    total
    ))
  

  
(provide 'viper-util)
  

;;; Local Variables:
;;; eval: (put 'vip-deflocalvar 'lisp-indent-hook 'defun)
;;; End:

;;;  viper-util.el ends here
