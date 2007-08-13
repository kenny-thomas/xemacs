;;; help.el --- help commands for XEmacs.

;; Copyright (C) 1985, 1986, 1992-4, 1997 Free Software Foundation, Inc.

;; Maintainer: FSF
;; Keywords: help, internal, dumped

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
;; along with XEmacs; see the file COPYING.  If not, write to the 
;; Free Software Foundation, 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Synched up with: FSF 19.30.

;;; Commentary:
 
;; This file is dumped with XEmacs.

;; This code implements XEmacs's on-line help system, the one invoked by
;;`M-x help-for-help'.

;; 06/11/1997 -- Converted to use char-after instead of broken
;;  following-char. -slb

;;; Code:

;; Get the macro make-help-screen when this is compiled,
;; or run interpreted, but not when the compiled code is loaded.
(eval-when-compile (require 'help-macro))

(defgroup help nil
  "Support for on-line help systems."
  :group 'emacs)

(defgroup help-appearance nil
  "Appearance of help buffers."
  :group 'help)

(defvar help-map (let ((map (make-sparse-keymap)))
                   (set-keymap-name map 'help-map)
                   (set-keymap-prompt
                     map (purecopy (gettext "(Type ? for further options)")))
                   map)
  "Keymap for characters following the Help key.")

;; global-map definitions moved to keydefs.el
(fset 'help-command help-map)

(define-key help-map (vector help-char) 'help-for-help)
(define-key help-map "?" 'help-for-help)
(define-key help-map 'help 'help-for-help)
(define-key help-map '(f1) 'help-for-help)

(define-key help-map "\C-l" 'describe-copying) ; on \C-c in FSFmacs
(define-key help-map "\C-d" 'describe-distribution)
(define-key help-map "\C-w" 'describe-no-warranty)
(define-key help-map "a" 'hyper-apropos) ; 'command-apropos in FSFmacs
(define-key help-map "A" 'command-apropos)

(define-key help-map "b" 'describe-bindings)
(define-key help-map "B" 'describe-beta)
(define-key help-map "\C-p" 'describe-pointer)

(define-key help-map "C" 'customize)
(define-key help-map "c" 'describe-key-briefly)
(define-key help-map "k" 'describe-key)

(define-key help-map "d" 'describe-function)
(define-key help-map "e" 'describe-last-error)
(define-key help-map "f" 'describe-function)

(define-key help-map "F" 'xemacs-local-faq)

;;; Setup so Hyperbole can be autoloaded from a key.
;;; Choose a key on which to place the Hyperbole menus.
;;; For most people this key binding will work and will be equivalent
;;; to {C-h h}.
;;;
(when (featurep 'infodock) ; This isn't used in XEmacs
  ;; #### This needs fixing for InfoDock 4.0.
  (or (where-is-internal 'hyperbole)
      (where-is-internal 'hui:menu)
      (define-key help-map "h" 'hyperbole))
  (autoload 'hyperbole "hsite" "Hyperbole info manager menus." t))

(define-key help-map "i" 'info)
(define-key help-map '(control i) 'Info-query)
;; FSFmacs has Info-goto-emacs-command-node on C-f, no binding
;; for Info-elisp-ref
(define-key help-map '(control c) 'Info-goto-emacs-command-node)
(define-key help-map '(control k) 'Info-goto-emacs-key-command-node)
(define-key help-map '(control f) 'Info-elisp-ref)

(define-key help-map "l" 'view-lossage)

(define-key help-map "m" 'describe-mode)

(define-key help-map "\C-n" 'view-emacs-news)
(define-key help-map "n" 'view-emacs-news)

(define-key help-map "p" 'finder-by-keyword)

;; Do this right with an autoload cookie in finder.el.
;;(autoload 'finder-by-keyword "finder"
;;  "Find packages matching a given keyword." t)

(define-key help-map "s" 'describe-syntax)

(define-key help-map "t" 'help-with-tutorial)

(define-key help-map "w" 'where-is)

(define-key help-map "v" 'describe-variable)

(if (fboundp 'view-last-error)
    (define-key help-map "e" 'view-last-error))


(define-key help-map "q" 'help-quit)

;#### This stuff was an attempt to have font locking and hyperlinks in the
;help buffer, but it doesn't really work.  Some of this stuff comes from
;FSF Emacs; but the FSF Emacs implementation is rather broken, as usual.
;What needs to happen is this:
;
; -- we probably need a "hyperlink mode" from which help-mode is derived.
; -- this means we probably need multiple inheritance of modes!
;    Thankfully this is not hard to implement; we already have the
;    ability for a keymap to have multiple parents.  However, we'd
;    have to define any multiply-inherited-from modes using a standard
;    `define-mode' construction instead of manually doing it, because
;    we don't want each guy calling `kill-all-local-variables' and
;    messing up the previous one.
; -- we need to scan the buffer ourselves (not from font-lock, because
;    the user might not have font-lock enabled) and highlight only
;    those words that are *documented* functions and variables (and
;    probably excluding words without dashes in them unless enclosed
;    in quotes, so that common words like "list" and "point" don't
;    become hyperlinks.
; -- we should *not* use font-lock keywords like below.  Instead we
;    should add the font-lock stuff ourselves during the scanning phase,
;    if font-lock is enabled in this buffer. 

;(defun help-follow-reference (event extent user-data)
;  (let ((symbol (intern-soft (extent-string extent))))
;    (cond ((and symbol (fboundp symbol))
;	   (describe-function symbol))
;	  ((and symbol (boundp symbol))
;	   (describe-variable symbol))
;	  (t nil))))

;(defvar help-font-lock-keywords
;  (let ((name-char "[-+a-zA-Z0-9_*]") (sym-char "[-+a-zA-Z0-9_:*]"))
;    (list
;     ;;
;     ;; The symbol itself.
;     (list (concat "\\`\\(" name-char "+\\)\\(:\\)?")
;	   '(1 (if (match-beginning 2)
;		   'font-lock-function-name-face
;		 'font-lock-variable-name-face)
;	       nil t))
;     ;;
;     ;; Words inside `' which tend to be symbol names.
;     (list (concat "`\\(" sym-char sym-char "+\\)'")
;	   1 '(prog1
;		  'font-lock-reference-face
;		(add-list-mode-item (match-beginning 1)
;			       (match-end 1)
;			       nil
;			       'help-follow-reference))
;	   t)
;     ;;
;     ;; CLisp `:' keywords as references.
;     (list (concat "\\<:" sym-char "+\\>") 0 'font-lock-reference-face t)))
;  "Default expressions to highlight in Help mode.")

;(put 'help-mode 'font-lock-defaults '(help-font-lock-keywords))

(define-derived-mode help-mode view-major-mode "Help"
  "Major mode for viewing help text.
Entry to this mode runs the normal hook `help-mode-hook'.
Commands:
\\{help-mode-map}"
  )

(define-key help-mode-map "q" 'help-mode-quit)
(define-key help-mode-map "Q" 'help-mode-bury)
(define-key help-mode-map "f" 'find-function-at-point)
(define-key help-mode-map "d" 'describe-function-at-point)
(define-key help-mode-map "v" 'describe-variable-at-point)
(define-key help-mode-map "i" 'Info-elisp-ref)
(define-key help-mode-map "c" 'customize-variable)
(define-key help-mode-map [tab] 'help-next-symbol)
(define-key help-mode-map [(shift tab)] 'help-prev-symbol)
(define-key help-mode-map "n" 'help-next-section)
(define-key help-mode-map "p" 'help-prev-section)

(defun describe-function-at-point ()
  "Describe directly the function at point in the other window."
  (interactive)
  (let ((symb (function-at-point)))
    (when symb
      (describe-function symb))))

(defun describe-variable-at-point ()
  "Describe directly the variable at point in the other window."
  (interactive)
  (let ((symb (variable-at-point)))
    (when symb
      (describe-variable symb))))

(defun help-next-symbol ()
  "Move point to the next quoted symbol."
  (interactive)
  (search-forward "`" nil t))

(defun help-prev-symbol ()
  "Move point to the previous quoted symbol."
  (interactive)
  (search-backward "'" nil t))

(defun help-next-section ()
  "Move point to the next quoted symbol."
  (interactive)
  (search-forward-regexp "^\\w+:" nil t))

(defun help-prev-section ()
  "Move point to the previous quoted symbol."
  (interactive)
  (search-backward-regexp "^\\w+:" nil t))

(defun help-mode-bury ()
  "Buries the buffer, possibly restoring the previous window configuration."
  (interactive)
  (help-mode-quit t))

(defun help-mode-quit (&optional bury)
  "Exits from help mode, possibly restoring the previous window configuration.
If the optional argument BURY is non-nil, the help buffer is buried,
otherwise it is killed."
  (interactive)
  (let ((buf (current-buffer)))
    (cond ((frame-property (selected-frame) 'help-window-config)
	   (set-window-configuration
	    (frame-property (selected-frame) 'help-window-config))
	   (set-frame-property  (selected-frame) 'help-window-config nil))
	  ((not (one-window-p))
	   (delete-window)))
    (if bury
	(bury-buffer buf)
      (kill-buffer buf))))

(defun help-quit ()
  (interactive)
  nil)

;; This is a grody hack of the same genotype as `advertised-undo'; if the
;; bindings of Backspace and C-h are the same, we want the menubar to claim
;; that `info' in invoked with `C-h i', not `BS i'.

(defun deprecated-help-command ()
  (interactive)
  (if (eq 'help-command (key-binding "\C-h"))
      (setq unread-command-event (character-to-event ?\C-h))
    (help-for-help)))

;;(define-key global-map 'backspace 'deprecated-help-command)

;; This function has been moved to help-nomule.el and mule-help.el.
;; TUTORIAL arg is XEmacs addition
;(defun help-with-tutorial (&optional tutorial)
;  "Select the XEmacs learn-by-doing tutorial.
;Optional arg TUTORIAL specifies the tutorial file; default is \"TUTORIAL\"."
;  (interactive)
;  (if (null tutorial)
;      (setq tutorial "TUTORIAL"))
;  (let ((file (expand-file-name (concat "~/" tutorial))))
;    (delete-other-windows)
;    (if (get-file-buffer file)
;	(switch-to-buffer (get-file-buffer file))
;      (switch-to-buffer (create-file-buffer file))
;      (setq buffer-file-name file)
;      (setq default-directory (expand-file-name "~/"))
;      (setq buffer-auto-save-file-name nil)
;      (insert-file-contents (expand-file-name tutorial data-directory))
;      (goto-char (point-min))
;      (search-forward "\n<<")
;      (delete-region (point-at-bol) (point-at-eol))
;      (let ((n (- (window-height (selected-window))
;		  (count-lines (point-min) (point))
;		  6)))
;	(if (< n 12)
;	    (newline n)
;	  ;; Some people get confused by the large gap.
;	  (newline (/ n 2))
;	  (insert "[Middle of page left blank for didactic purposes.  "
;		  "Text continues below]")
;	  (newline (- n (/ n 2)))))
;      (goto-char (point-min))
;      (set-buffer-modified-p nil))))

;; used by describe-key, describe-key-briefly, insert-key-binding, etc.

(defun key-or-menu-binding (key &optional menu-flag)
  "Return the command invoked by KEY.
Like `key-binding', but handles menu events and toolbar presses correctly.
KEY is any value returned by `next-command-event'.
MENU-FLAG is a symbol that should be set to T if KEY is a menu event,
 or NIL otherwise"
  (let (defn)
    (and menu-flag (set menu-flag nil))
    ;; If the key typed was really a menu selection, grab the form out
    ;; of the event object and intuit the function that would be called,
    ;; and describe that instead.
    (if (and (vectorp key) (= 1 (length key))
	     (or (misc-user-event-p (aref key 0))
		 (eq (car-safe (aref key 0)) 'menu-selection)))
	(let ((event (aref key 0)))
	  (setq defn (if (eventp event)
			 (list (event-function event) (event-object event))
		       (cdr event)))
	  (and menu-flag (set menu-flag t))
	  (when (eq (car defn) 'eval)
	    (setq defn (car (cdr defn))))
	  (when (eq (car-safe defn) 'call-interactively)
	    (setq defn (car (cdr defn))))
	  (when (and (consp defn) (null (cdr defn)))
	    (setq defn (car defn))))
      ;; else
      (setq defn (key-binding key)))
    ;; kludge: if a toolbar button was pressed on, try to find the
    ;; binding of the toolbar button.
    (if (and (eq defn 'press-toolbar-button)
	     (vectorp key)
	     (button-press-event-p (aref key (1- (length key)))))
	;; wait for the button release.  We're on shaky ground here ...
	(let ((event (next-command-event))
	      button)
	  (if (and (button-release-event-p event)
		   (event-over-toolbar-p event)
		   (eq 'release-and-activate-toolbar-button
		       (key-binding (vector event)))
		   (setq button (event-toolbar-button event)))
	      (toolbar-button-callback button)
	    ;; if anything went wrong, try returning the binding of
	    ;; the button-up event, of the original binding
	    (or (key-or-menu-binding (vector event))
		defn)))
      ;; no toolbar kludge
      defn)
    ))

(defun describe-key-briefly (key)
  "Print the name of the function KEY invokes.  KEY is a string."
  (interactive "kDescribe key briefly: ")
  (let (defn menup)
    (setq defn (key-or-menu-binding key 'menup))    
    (if (or (null defn) (integerp defn))
        (message "%s is undefined" (key-description key))
      ;; If it's a keyboard macro which trivially invokes another command,
      ;; document that instead.
      (if (or (stringp defn) (vectorp defn))
	  (setq defn (or (key-binding defn)
			 defn)))
      (let ((last-event (and (vectorp key)
			     (aref key (1- (length key))))))
	(message (if (or (button-press-event-p last-event)
			 (button-release-event-p last-event))
		     (gettext "%s at that spot runs the command %s")
		   (gettext "%s runs the command %s"))
		 ;; This used to say 'This menu item' but it could also
		 ;; be a scrollbar event.  We can't distinguish at the
		 ;; moment.
		 (if menup "This item" (key-description key))
		 (format (if (symbolp defn) "`%s'" "%s") defn))))))

;; #### this is a horrible piece of shit function that should
;; not exist.  In FSF 19.30 this function has gotten three times
;; as long and has tons and tons of dumb shit checking
;; special-display-buffer-names and such crap.  I absolutely
;; refuse to insert that Ebolification here.  I wanted to delete
;; this function entirely but Mly bitched.
;;
;; If your user-land code calls this function, rewrite it to
;; call with-displaying-help-buffer.

(defun print-help-return-message (&optional function)
  "Display or return message saying how to restore windows after help command.
Computes a message and applies the optional argument FUNCTION to it.
If FUNCTION is nil, applies `message' to it, thus printing it."
  (and (not (get-buffer-window standard-output))
       (funcall
	(or function 'message)
	(concat
         (substitute-command-keys
          (if (one-window-p t)
              (if pop-up-windows
                  (gettext "Type \\[delete-other-windows] to remove help window.")
                (gettext "Type \\[switch-to-buffer] RET to remove help window."))
   (gettext "Type \\[switch-to-buffer-other-window] RET to restore the other window.")))
         (substitute-command-keys
          (gettext "  \\[scroll-other-window] to scroll the help."))))))

(defcustom help-selects-help-window t
  "*If nil, use the \"old Emacs\" behavior for Help buffers.
This just displays the buffer in another window, rather than selecting
the window."
  :type 'boolean
  :group 'help-appearance)

(defun help-buffer-name (name)
  "Return a name for a Help buffer using string NAME for context."
  (if (stringp name)
      (format "*Help: %s*" name)
    "*Help*"))

;; Use this function for displaying help when C-h something is pressed
;; or in similar situations.  Do *not* use it when you are displaying
;; a help message and then prompting for input in the minibuffer --
;; this macro usually selects the help buffer, which is not what you
;; want in those situations.
(defmacro with-displaying-help-buffer (name &rest body)
  "Form which makes a help buffer with given NAME and evaluates BODY there.
The actual name of the buffer is generated by the function `help-buffer-name'."
  `(let* ((winconfig (current-window-configuration))
	  (was-one-window (one-window-p))
	  (buffer-name (help-buffer-name ,name))
	  (help-not-visible
	   (not (and (windows-of-buffer buffer-name) ;shortcut
		     (member (selected-frame)
			     (mapcar 'window-frame
				     (windows-of-buffer buffer-name)))))))
     (if (get-buffer buffer-name)
	 (kill-buffer buffer-name))
     (prog1 (with-output-to-temp-buffer buffer-name
	      (prog1 ,@body
		(save-excursion
		  (set-buffer standard-output)
		  (help-mode))))
       (let ((helpwin (get-buffer-window buffer-name)))
	 (when helpwin
	   (with-current-buffer (window-buffer helpwin)
	     ;; If the *Help* buffer is already displayed on this
	     ;; frame, don't override the previous configuration
	     (when help-not-visible
	       (set-frame-property (selected-frame)
				   'help-window-config winconfig)))
	   (when help-selects-help-window
	     (select-window helpwin))
	   (cond ((eq helpwin (selected-window))
		  (display-message 'command
		    (substitute-command-keys "Type \\[help-mode-quit] to remove help window, \\[scroll-up] to scroll the help.")))
		 (was-one-window
		  (display-message 'command
		    (substitute-command-keys "Type \\[delete-other-windows] to remove help window, \\[scroll-other-window] to scroll the help.")))
		 (t
		  (display-message 'command
		    (substitute-command-keys "Type \\[switch-to-buffer-other-window] to restore the other window, \\[scroll-other-window] to scroll the help.")))))))))
(put 'with-displaying-help-buffer 'lisp-indent-function 1)
(put 'with-displaying-help-buffer 'edebug-form-spec '(form body))

(defun describe-key (key)
  "Display documentation of the function invoked by KEY.
KEY is a string, or vector of events.
When called interactively, KEY may also be a menu selection."
  (interactive "kDescribe key: ")
  (let ((defn (key-or-menu-binding key))
	(key-string (key-description key)))
    (if (or (null defn) (integerp defn))
        (message "%s is undefined" key-string)
      (with-displaying-help-buffer (format "key `%s'" key-string)
	(princ key-string)
	(princ " runs ")
	(if (symbolp defn)
	    (princ (format "`%s'" defn))
	  (princ defn))
	(princ "\n\n")
	(cond ((or (stringp defn) (vectorp defn))
	       (let ((cmd (key-binding defn)))
		 (if (not cmd)
		     (princ "a keyboard macro")
		   (progn
		     (princ "a keyboard macro which runs the command ")
		     (princ cmd)
		     (princ ":\n\n")
		     (if (documentation cmd) (princ (documentation cmd)))))))
	      ((and (consp defn) (not (eq 'lambda (car-safe defn))))
	       (let ((describe-function-show-arglist nil))
		 (describe-function-1 (car defn))))
	      ((symbolp defn)
	       (describe-function-1 defn))
	      ((documentation defn)
	       (princ (documentation defn)))
	      (t
	       (princ "not documented")))))))

(defun describe-mode ()
  "Display documentation of current major mode and minor modes.
For this to work correctly for a minor mode, the mode's indicator variable
\(listed in `minor-mode-alist') must also be a function whose documentation
describes the minor mode."
  (interactive)
  (with-displaying-help-buffer (format "%s mode" mode-name)
    ;; XEmacs change: print the major-mode documentation before
    ;; the minor modes.
    (princ mode-name)
    (princ " mode:\n")
    (princ (documentation major-mode))
    (princ "\n\n----\n\n")
    (let ((minor-modes minor-mode-alist))
      (while minor-modes
	(let* ((minor-mode (car (car minor-modes)))
	       (indicator (car (cdr (car minor-modes)))))
	  ;; Document a minor mode if it is listed in minor-mode-alist,
	  ;; bound locally in this buffer, non-nil, and has a function
	  ;; definition.
	  (if (and (boundp minor-mode)
		   (symbol-value minor-mode)
		   (fboundp minor-mode))
	      (let ((pretty-minor-mode minor-mode))
		(if (string-match "-mode\\'" (symbol-name minor-mode))
		    (setq pretty-minor-mode
			  (capitalize
			   (substring (symbol-name minor-mode)
				      0 (match-beginning 0)))))
		(while (and (consp indicator) (extentp (car indicator)))
		  (setq indicator (cdr indicator)))
		(while (and indicator (symbolp indicator))
		  (setq indicator (symbol-value indicator)))
		(princ (format "%s minor mode (indicator%s):\n"
			       pretty-minor-mode indicator))
		(princ (documentation minor-mode))
		(princ "\n\n----\n\n"))))
	(setq minor-modes (cdr minor-modes))))))

;; So keyboard macro definitions are documented correctly
(fset 'defining-kbd-macro (symbol-function 'start-kbd-macro))

(defun describe-distribution ()
  "Display info on how to obtain the latest version of XEmacs."
  (interactive)
  (find-file-read-only
   (locate-data-file "DISTRIB")))

(defun describe-beta ()
  "Display info on how to deal with Beta versions of XEmacs."
  (interactive)
  (find-file-read-only
   (locate-data-file "BETA"))
  (goto-char (point-min)))

(defun describe-copying ()
  "Display info on how you may redistribute copies of XEmacs."
  (interactive)
  (find-file-read-only
   (locate-data-file "COPYING"))
  (goto-char (point-min)))

(defun describe-pointer ()
  "Show a list of all defined mouse buttons, and their definitions."
  (interactive)
  (describe-bindings nil t))

(defun describe-project ()
  "Display info on the GNU project."
  (interactive)
  (find-file-read-only
   (locate-data-file "GNU"))
  (goto-char (point-min)))

(defun describe-no-warranty ()
  "Display info on all the kinds of warranty XEmacs does NOT have."
  (interactive)
  (describe-copying)
  (let (case-fold-search)
    (search-forward "NO WARRANTY")
    (recenter 0)))

(defun describe-bindings (&optional prefix mouse-only-p)
  "Show a list of all defined keys, and their definitions.
The list is put in a buffer, which is displayed.
If the optional argument PREFIX is supplied, only commands which
start with that sequence of keys are described.
If the second argument (prefix arg, interactively) is non-null
then only the mouse bindings are displayed."
  (interactive (list nil current-prefix-arg))
  (with-displaying-help-buffer (format "bindings for %s" major-mode)
    (describe-bindings-1 prefix mouse-only-p)))

(defun describe-bindings-1 (&optional prefix mouse-only-p)
  (let ((heading (if mouse-only-p
            (gettext "button          binding\n------          -------\n")
            (gettext "key             binding\n---             -------\n")))
        (buffer (current-buffer))
        (minor minor-mode-map-alist)
        (local (current-local-map))
        (shadow '()))
    (set-buffer standard-output)
    (while minor
      (let ((sym (car (car minor)))
            (map (cdr (car minor))))
        (if (symbol-value-in-buffer sym buffer nil)
            (progn
              (insert (format "Minor Mode Bindings for `%s':\n"
                              sym)
                      heading)
              (describe-bindings-internal map nil shadow prefix mouse-only-p)
              (insert "\n")
              (setq shadow (cons map shadow))))
        (setq minor (cdr minor))))
    (if local
        (progn
          (insert "Local Bindings:\n" heading)
          (describe-bindings-internal local nil shadow prefix mouse-only-p)
          (insert "\n")
          (setq shadow (cons local shadow))))
    (insert "Global Bindings:\n" heading)
    (describe-bindings-internal (current-global-map)
                                nil shadow prefix mouse-only-p)
    (when (and prefix function-key-map (not mouse-only-p))
      (insert "\nFunction key map translations:\n" heading)
      (describe-bindings-internal function-key-map nil nil
				  prefix mouse-only-p))
    (set-buffer buffer)))

(defun describe-prefix-bindings ()
  "Describe the bindings of the prefix used to reach this command.
The prefix described consists of all but the last event
of the key sequence that ran this command."
  (interactive)
  (let* ((key (this-command-keys))
	 (prefix (make-vector (1- (length key)) nil))
	 i)
    (setq i 0)
    (while (< i (length prefix))
      (aset prefix i (aref key i))
      (setq i (1+ i)))
    (with-displaying-help-buffer (format "%s prefix" (key-description prefix))
      (princ "Key bindings starting with ")
      (princ (key-description prefix))
      (princ ":\n\n")
      (describe-bindings-1 prefix nil))))

;; Make C-h after a prefix, when not specifically bound, 
;; run describe-prefix-bindings.
(setq prefix-help-command 'describe-prefix-bindings)

(defun view-emacs-news ()
  "Display info on recent changes to XEmacs."
  (interactive)
  (find-file (locate-data-file "NEWS")))

(defun xemacs-www-page ()
  "Go to the XEmacs World Wide Web page."
  (interactive)
  (if (boundp 'browse-url-browser-function)
      (funcall browse-url-browser-function "http://www.xemacs.org/")
    (error "xemacs-www-page requires browse-url")))

(defun xemacs-www-faq ()
  "View the latest and greatest XEmacs FAQ using the World Wide Web."
  (interactive)
  (if (boundp 'browse-url-browser-function)
      (funcall browse-url-browser-function
	       "http://www.xemacs.org/faq/index.html")
    (error "xemacs-www-faq requires browse-url")))

(defun xemacs-local-faq ()
  "View the local copy of the XEmacs FAQ.
If you have access to the World Wide Web, you should use `xemacs-www-faq'
instead, to ensure that you get the most up-to-date information."
  (interactive)
  (save-window-excursion
    (info)
    (Info-find-node "xemacs-faq" "Top"))
  (switch-to-buffer "*info*"))

(defcustom view-lossage-key-count 100
  "*Number of keys `view-lossage' shows.
The maximum number of available keys is governed by `recent-keys-ring-size'."
  :type 'integer
  :group 'help)

(defcustom view-lossage-message-count 100
  "*Number of minibuffer messages `view-lossage' shows."
  :type 'integer
  :group 'help)

(defun view-lossage ()
  "Display recent input keystrokes and recent minibuffer messages.
The number of keys shown is controlled by `view-lossage-key-count'.
The number of messages shown is controlled by `view-lossage-message-count'."
  (interactive)
  (with-displaying-help-buffer "lossage"
    (princ (key-description (recent-keys view-lossage-key-count)))
    (save-excursion
      (set-buffer standard-output)
      (goto-char (point-min))
      (insert "Recent keystrokes:\n\n")
      (while (progn (move-to-column 50) (not (eobp)))
	(search-forward " " nil t)
	(insert "\n")))
    ;; XEmacs addition
    (princ "\n\n\nRecent minibuffer messages (most recent first):\n\n")
    (save-excursion
      (let ((buffer (get-buffer-create " *Message-Log*"))
	    (count 0)
	    oldpoint)
	(set-buffer buffer)
	(goto-char (point-max))
	(set-buffer standard-output)
	(while (and (> (point buffer) (point-min buffer))
		    (< count view-lossage-message-count))
	  (setq oldpoint (point buffer))
	  (forward-line -1 buffer)
	  (insert-buffer-substring buffer (point buffer) oldpoint)
	  (setq count (1+ count)))))))

(define-function 'help 'help-for-help)

(make-help-screen help-for-help
  "A B C F I K L M N P S T V W C-c C-d C-f C-i C-k C-n C-w;  ? for more help:"
  "Type a Help option:
\(Use SPC or DEL to scroll through this text.  Type \\<help-map>\\[help-quit] to exit the Help command.)

\\[hyper-apropos]	Type a substring; it shows a hypertext list of
        functions and variables that contain that substring.
	See also the `apropos' command.
\\[command-apropos]	Type a substring; it shows a list of commands
        (interactively callable functions) that contain that substring.
\\[describe-bindings]	Table of all key bindings.
\\[describe-key-briefly]	Type a command key sequence;
        it displays the function name that sequence runs.
\\[customize]	Customize Emacs options.
\\[Info-goto-emacs-command-node]	Type a function name; it displays the Info node for that command.
\\[describe-function]	Type a function name; it shows its documentation.
\\[Info-elisp-ref]	Type a function name; it jumps to the full documentation
	in the XEmacs Lisp Programmer's Manual.
\\[xemacs-local-faq]	Local copy of the XEmacs FAQ.
\\[info]	Info documentation reader.
\\[Info-query]	Type an Info file name; it displays it in Info reader.
\\[describe-key]	Type a command key sequence;
        it displays the documentation for the command bound to that key.
\\[Info-goto-emacs-key-command-node]	Type a command key sequence;
        it displays the Info node for the command bound to that key.
\\[view-lossage]	Recent input keystrokes and minibuffer messages.
\\[describe-mode]	Documentation of current major and minor modes.
\\[view-emacs-news]	News of recent XEmacs changes.
\\[finder-by-keyword]	Type a topic keyword; it finds matching packages.
\\[describe-pointer]	Table of all mouse-button bindings.
\\[describe-syntax]	Contents of syntax table with explanations.
\\[help-with-tutorial]	XEmacs learn-by-doing tutorial.
\\[describe-variable]	Type a variable name; it displays its documentation and value.
\\[where-is]	Type a command name; it displays which keystrokes invoke that command.
\\[describe-distribution]	XEmacs ordering information.
\\[describe-no-warranty]	Information on absence of warranty for XEmacs.
\\[describe-copying]	XEmacs copying permission (General Public License)."
  help-map)

(defmacro with-syntax-table (syntab &rest body)
  "Evaluate BODY with the syntax-table SYNTAB"
  `(let ((stab (syntax-table)))
     (unwind-protect
	 (progn
	   (set-syntax-table (copy-syntax-table ,syntab))
	   ,@body)
       (set-syntax-table stab))))
(put 'with-syntax-table 'lisp-indent-function 1)
(put 'with-syntax-table 'edebug-form-spec '(form body))

(defun function-called-at-point ()
  "Return the function which is called by the list containing point.
If that gives no function, return the function whose name is around point.
If that doesn't give a function, return nil."
  (or (ignore-errors
	(save-excursion
	  (save-restriction
	    (narrow-to-region (max (point-min) (- (point) 1000))
			      (point-max))
	    (backward-up-list 1)
	    (forward-char 1)
	    (let (obj)
	      (setq obj (read (current-buffer)))
	      (and (symbolp obj) (fboundp obj) obj)))))
      (ignore-errors
	(with-syntax-table emacs-lisp-mode-syntax-table
	  (save-excursion
	    (or (not (zerop (skip-syntax-backward "_w")))
		(eq (char-syntax (char-after (point))) ?w)
		(eq (char-syntax (char-after (point))) ?_)
		(forward-sexp -1))
	    (skip-chars-forward "`'")
	    (let ((obj (read (current-buffer))))
	      (and (symbolp obj) (fboundp obj) obj)))))))

(defun function-at-point ()
  "Return the function whose name is around point.
If that gives no function, return the function which is called by the
list containing point.  If that doesn't give a function, return nil."
  (or (ignore-errors
	(with-syntax-table emacs-lisp-mode-syntax-table
	  (save-excursion
	    (or (not (zerop (skip-syntax-backward "_w")))
		(eq (char-syntax (char-after (point))) ?w)
		(eq (char-syntax (char-after (point))) ?_)
		(forward-sexp -1))
	    (skip-chars-forward "`'")
	    (let ((obj (read (current-buffer))))
	      (and (symbolp obj) (fboundp obj) obj)))))
      (ignore-errors
	(save-excursion
	  (save-restriction
	    (narrow-to-region (max (point-min) (- (point) 1000))
			      (point-max))
	    (backward-up-list 1)
	    (forward-char 1)
	    (let (obj)
	      (setq obj (read (current-buffer)))
	      (and (symbolp obj) (fboundp obj) obj)))))))

;; Default to nil for the non-hackers?  Not until we find a way to
;; distinguish hackers from non-hackers automatically!
(defcustom describe-function-show-arglist t
  "*If non-nil, describe-function will show its arglist,
unless the function is autoloaded."
  :type 'boolean
  :group 'help-appearance)

(defun describe-symbol-find-file (function)
  (let ((files load-history)
	file)
    (while files
      (if (memq function (cdr (car files)))
	  (setq file (car (car files))
		files nil))
      (setq files (cdr files)))
    file))
(define-obsolete-function-alias
  'describe-function-find-file
  'describe-symbol-find-file)

(defun describe-function (function)
  "Display the full documentation of FUNCTION (a symbol).
When run interactively, it defaults to any function found by
`function-at-point'."
  (interactive
    (let* ((fn (function-at-point))
           (val (let ((enable-recursive-minibuffers t))
                  (completing-read
                    (if fn
                        (format (gettext "Describe function (default %s): ")
				fn)
                        (gettext "Describe function: "))
                    obarray 'fboundp t nil 'function-history))))
      (list (if (equal val "") fn (intern val)))))
  (with-displaying-help-buffer (format "function `%s'" function)
    (describe-function-1 function)))

(defun function-obsolete-p (function)
  "Return non-nil if FUNCTION is obsolete."
  (not (null (get function 'byte-obsolete-info))))

(defun function-obsoleteness-doc (function)
  "If FUNCTION is obsolete, return a string describing this."
  (let ((obsolete (get function 'byte-obsolete-info)))
    (if obsolete
	(format "Obsolete; %s"
		(if (stringp (car obsolete))
		    (car obsolete)
		  (format "use `%s' instead." (car obsolete)))))))

(defun function-compatible-p (function)
  "Return non-nil if FUNCTION is present for Emacs compatibility."
  (not (null (get function 'byte-compatible-info))))

(defun function-compatibility-doc (function)
  "If FUNCTION is Emacs compatible, return a string describing this."
  (let ((compatible (get function 'byte-compatible-info)))
    (if compatible
	(format "Emacs Compatible; %s"
		(if (stringp (car compatible))
		    (car compatible)
		  (format "use `%s' instead." (car compatible)))))))

;Here are all the possibilities below spelled out, for the benefit
;of the I18N3 snarfer.
;
;(gettext "a built-in function")
;(gettext "an interactive built-in function")
;(gettext "a built-in macro")
;(gettext "an interactive built-in macro")
;(gettext "a compiled Lisp function")
;(gettext "an interactive compiled Lisp function")
;(gettext "a compiled Lisp macro")
;(gettext "an interactive compiled Lisp macro")
;(gettext "a Lisp function")
;(gettext "an interactive Lisp function")
;(gettext "a Lisp macro")
;(gettext "an interactive Lisp macro")
;(gettext "a mocklisp function")
;(gettext "an interactive mocklisp function")
;(gettext "a mocklisp macro")
;(gettext "an interactive mocklisp macro")
;(gettext "an autoloaded Lisp function")
;(gettext "an interactive autoloaded Lisp function")
;(gettext "an autoloaded Lisp macro")
;(gettext "an interactive autoloaded Lisp macro")

;; taken out of `describe-function-1'
(defun function-arglist (function)
  "Returns a string giving the argument list of FUNCTION.
For example:

	(function-arglist 'function-arglist)
	=> (function-arglist FUNCTION)

This function is used by `describe-function-1' to list function
arguments in the standard Lisp style."
  (let* ((fndef (indirect-function function))
	 (arglist
	 (cond ((compiled-function-p fndef)
		(compiled-function-arglist fndef))
	       ((eq (car-safe fndef) 'lambda)
		(nth 1 fndef))
	       ((subrp fndef)
		(let ((doc (documentation function)))
		  (if (string-match "[\n\t ]*\narguments: ?(\\(.*\\))\n?\\'"
				    doc)
		      (substring doc (match-beginning 1) (match-end 1)))))
	       (t t))))
    (cond ((listp arglist)
	   (prin1-to-string
	    (cons function (mapcar (lambda (arg)
				     (if (memq arg '(&optional &rest))
					 arg
				       (intern (upcase (symbol-name arg)))))
				   arglist))
	    t))
	  ((stringp arglist)
	   (format "(%s %s)" function arglist)))))

(defun function-documentation (function &optional strip-arglist)
  "Returns a string giving the documentation for FUNCTION if any.  
If the optional argument STRIP-ARGLIST is non-nil remove the arglist
part of the documentation of internal subroutines."
  (let ((doc (condition-case nil
		 (or (documentation function)
		     (gettext "not documented"))
	       (void-function ""))))
    (if (and strip-arglist
	     (string-match "[\n\t ]*\narguments: ?(\\(.*\\))\n?\\'" doc))
	(setq doc (substring doc 0 (match-beginning 0))))
    doc))

(defun describe-function-1 (function &optional nodoc)
  "This function does the work for `describe-function'."
  (princ (format "`%s' is " function))
  (let* ((def function)
	 aliases file-name autoload-file kbd-macro-p fndef macrop)
    (while (and (symbolp def) (fboundp def))
      (when (not (eq def function))
	(setq aliases
	      (if aliases
		  ;; I18N3 Need gettext due to concat
		  (concat aliases 
			  (format
			   "\n     which is an alias for `%s', "
			   (symbol-name def)))
		(format "an alias for `%s', " (symbol-name def)))))
      (setq def (symbol-function def)))
    (if (and (fboundp 'compiled-function-annotation)
	     (compiled-function-p def))
	(setq file-name (compiled-function-annotation def)))
    (if (eq 'macro (car-safe def))
	(setq fndef (cdr def)
	      file-name (and (compiled-function-p (cdr def))
			     (fboundp 'compiled-function-annotation)
			     (compiled-function-annotation (cdr def)))
	      macrop t)
      (setq fndef def))
    (if aliases (princ aliases))
    (let ((int #'(lambda (string an-p macro-p)
		   (princ (format
			   (gettext (concat
				     (cond ((commandp def)
					    "an interactive ")
					   (an-p "an ")
					   (t "a "))
				     "%s"
				     (if macro-p " macro" " function")))
			   string)))))
      (cond ((or (stringp def) (vectorp def))
             (princ "a keyboard macro.")
	     (setq kbd-macro-p t))
            ((subrp fndef)
             (funcall int "built-in" nil macrop))
            ((compiled-function-p fndef)
             (funcall int "compiled Lisp" nil macrop))
            ((eq (car-safe fndef) 'lambda)
             (funcall int "Lisp" nil macrop))
            ((eq (car-safe fndef) 'mocklisp)
             (funcall int "mocklisp" nil macrop))
            ((eq (car-safe def) 'autoload)
	     (setq autoload-file (elt def 1))
	     (funcall int "autoloaded Lisp" t (elt def 4)))
	    ((and (symbolp def) (not (fboundp def)))
	     (princ "a symbol with a void (unbound) function definition."))
            (t
             nil)))
    (princ "\n")
    (if autoload-file
	(princ (format "  -- autoloads from \"%s\"\n" autoload-file)))
    (or file-name
	(setq file-name (describe-symbol-find-file function)))
    (if file-name
	(princ (format "  -- loaded from \"%s\"\n" file-name)))
;;     (terpri)
    (if describe-function-show-arglist
	(let ((arglist (function-arglist function)))
	  (when arglist
	    (princ arglist)
	    (terpri))))
    (terpri)
    (cond (kbd-macro-p
	   (princ "These characters are executed:\n\n\t")
	   (princ (key-description def))
	   (cond ((setq def (key-binding def))
		  (princ (format "\n\nwhich executes the command `%s'.\n\n"
				 def))
		  (describe-function-1 def))))
	  (nodoc nil)
	  (t
	   ;; tell the user about obsoleteness.
	   ;; If the function is obsolete and is aliased, don't
	   ;; even bother to report the documentation, as a further
	   ;; encouragement to use the new function.
	   (let ((obsolete (function-obsoleteness-doc function))
		 (compatible (function-compatibility-doc function)))
	     (when obsolete
	       (princ obsolete)
	       (terpri)
	       (terpri))
	     (when compatible
	       (princ compatible)
	       (terpri)
	       (terpri))
	     (unless (and obsolete aliases)
	       (let ((doc (function-documentation function t)))
		 (princ "Documentation:\n")
		 (princ doc)
		 (unless (or (equal doc "")
			     (eq ?\n (aref doc (1- (length doc)))))
		   (terpri)))))))))


;;; [Obnoxious, whining people who complain very LOUDLY on Usenet
;;; are binding this to keys.]
(defun describe-function-arglist (function)
  (interactive (list (or (function-at-point)
			 (error "no function call at point"))))
  (message nil)
  (message (function-arglist function)))


(defun variable-at-point ()
  (ignore-errors
    (with-syntax-table emacs-lisp-mode-syntax-table
      (save-excursion
	(or (not (zerop (skip-syntax-backward "_w")))
	    (eq (char-syntax (char-after (point))) ?w)
	    (eq (char-syntax (char-after (point))) ?_)
	    (forward-sexp -1))
	(skip-chars-forward "'")
	(let ((obj (read (current-buffer))))
	  (and (symbolp obj) (boundp obj) obj))))))

(defun variable-obsolete-p (variable)
  "Return non-nil if VARIABLE is obsolete."
  (not (null (get variable 'byte-obsolete-variable))))

(defun variable-obsoleteness-doc (variable)
  "If VARIABLE is obsolete, return a string describing this."
  (let ((obsolete (get variable 'byte-obsolete-variable)))
    (if obsolete
	(format "Obsolete; %s"
		(if (stringp obsolete)
		    obsolete
		  (format "use `%s' instead." obsolete))))))

(defun variable-compatible-p (variable)
  "Return non-nil if VARIABLE is Emacs compatible."
  (not (null (get variable 'byte-compatible-variable))))

(defun variable-compatibility-doc (variable)
  "If VARIABLE is Emacs compatible, return a string describing this."
  (let ((compatible (get variable 'byte-compatible-variable)))
    (if compatible
	(format "Emacs Compatible; %s"
		(if (stringp compatible)
		    compatible
		  (format "use `%s' instead." compatible))))))

(defun built-in-variable-doc (variable)
  "Return a string describing whether VARIABLE is built-in."
  (let ((type (built-in-variable-type variable)))
    (case type
      (integer "a built-in integer variable")
      (const-integer "a built-in constant integer variable")
      (boolean "a built-in boolean variable")
      (const-boolean "a built-in constant boolean variable")
      (object "a simple built-in variable")
      (const-object "a simple built-in constant variable")
      (const-specifier "a built-in constant specifier variable")
      (current-buffer "a built-in buffer-local variable")
      (const-current-buffer "a built-in constant buffer-local variable")
      (default-buffer "a built-in default buffer-local variable")
      (selected-console "a built-in console-local variable")
      (const-selected-console "a built-in constant console-local variable")
      (default-console "a built-in default console-local variable")
      (t
       (if type "an unknown type of built-in variable?"
	 "a variable declared in Lisp")))))

(defcustom help-pretty-print-limit 100
  "Limit on length of lists above which pretty-printing of values is stopped.
Setting this to 0 disables pretty-printing."
  :type 'integer
  :group 'help)

(defun help-maybe-pretty-print-value (object)
  "Pretty-print OBJECT, unless it is a long list.
OBJECT is printed in the current buffer.  Unless it is a list with
more than `help-pretty-print-limit' elements, it is pretty-printed.

Uses `pp-internal' if defined, otherwise `cl-prettyprint'"
  (princ
   (if (and (or (listp object) (vectorp object))
	    (< (length object)
	       help-pretty-print-limit))
       (with-output-to-string
	 (with-syntax-table emacs-lisp-mode-syntax-table
	   ;; print `#<...>' values better
	   (modify-syntax-entry ?< "(>")
	   (modify-syntax-entry ?> ")<")
	   (let ((indent-line-function 'lisp-indent-line))
	     (if (fboundp 'pp-internal)
		 (progn
		   (pp-internal object "\n")
		   (terpri))
	       (cl-prettyprint object)))))
     (format "\n%S\n" object))))

(defun describe-variable (variable)
  "Display the full documentation of VARIABLE (a symbol)."
  (interactive 
   (let* ((v (variable-at-point))
          (val (let ((enable-recursive-minibuffers t))
                 (completing-read
                   (if v
                       (format "Describe variable (default %s): " v)
                       (gettext "Describe variable: "))
                   obarray 'boundp t nil 'variable-history))))
     (list (if (equal val "") v (intern val)))))
  (with-displaying-help-buffer (format "variable `%s'" variable)
    (let ((origvar variable)
	  aliases)
      (let ((print-escape-newlines t))
	(princ (format "`%s' is " (symbol-name variable)))
	(while (variable-alias variable)
	  (let ((newvar (variable-alias variable)))
	    (if aliases
		;; I18N3 Need gettext due to concat
		(setq aliases
		      (concat aliases 
			      (format "\n     which is an alias for `%s',"
				      (symbol-name newvar))))
	      (setq aliases
		    (format "an alias for `%s',"
			    (symbol-name newvar))))
	    (setq variable newvar)))
	(if aliases
	    (princ (format "%s" aliases)))
	(princ (built-in-variable-doc variable))
	(princ ".\n")
	(let ((file-name (describe-symbol-find-file variable)))
	     (if file-name
		 (princ (format "  -- loaded from \"%s\"\n" file-name))))
	(princ "\nValue: ")
	(if (not (boundp variable))
	    (princ "void\n")
	  (help-maybe-pretty-print-value (symbol-value variable)))
	(terpri)
	(cond ((local-variable-p variable (current-buffer))
	       (let* ((void (cons nil nil))
		      (def (condition-case nil
			       (default-value variable)
			     (error void))))
		 (princ "This value is specific to the current buffer.\n")
		 (if (local-variable-p variable nil)
		     (princ "(Its value is local to each buffer.)\n"))
		 (terpri)
		 (if (if (eq def void)
			 (boundp variable)
		       (not (eq (symbol-value variable) def)))
		     ;; #### I18N3 doesn't localize properly!
		     (progn (princ "Default-value: ")
			    (if (eq def void)
				(princ "void\n")
			      (help-maybe-pretty-print-value def))
			    (terpri)))))
	      ((local-variable-p variable (current-buffer) t)
	       (princ "Setting it would make its value buffer-local.\n\n"))))
      (princ "Documentation:")
      (terpri)
      (let ((doc (documentation-property variable 'variable-documentation))
	    (obsolete (variable-obsoleteness-doc origvar))
	    (compatible (variable-compatibility-doc origvar)))
	(when obsolete
	  (princ obsolete)
	  (terpri)
	  (terpri))
	(when compatible
	  (princ compatible)
	  (terpri)
	  (terpri))
	;; don't bother to print anything if variable is obsolete and aliased.
	(when (or (not obsolete) (not aliases))
	  (if doc
	      ;; note: documentation-property calls substitute-command-keys.
	      (princ doc)
	    (princ "not documented as a variable."))))
      (terpri))))

(defun sorted-key-descriptions (keys &optional separator)
  "Sort and separate the key descriptions for KEYS.
The sorting is done by length (shortest bindings first), and the bindings
are separated with SEPARATOR (\", \" by default)."
  (mapconcat 'key-description
	     (sort keys #'(lambda (x y)
			    (< (length x) (length y))))
	     (or separator ", ")))

(defun where-is (definition)
  "Print message listing key sequences that invoke specified command.
Argument is a command definition, usually a symbol with a function definition.
When run interactively, it defaults to any function found by
`function-at-point'."
  (interactive
   (let ((fn (function-at-point))
	 (enable-recursive-minibuffers t)	     
	 val)
     (setq val (read-command
		(if fn (format "Where is command (default %s): " fn)
		  "Where is command: ")))
     (list (if (equal (symbol-name val) "")
	       fn val))))
  (let ((keys (where-is-internal definition)))
    (if keys
	(message "%s is on %s" definition (sorted-key-descriptions keys))
      (message "%s is not on any keys" definition)))
  nil)

;; `locate-library' moved to "packages.el"


;; Functions ported from C into Lisp in XEmacs

(defun describe-syntax ()
  "Describe the syntax specifications in the syntax table.
The descriptions are inserted in a buffer, which is then displayed."
  (interactive)
  (with-displaying-help-buffer (format "syntax-table for %s" major-mode)
    ;; defined in syntax.el
    (describe-syntax-table (syntax-table) standard-output)))

(defun list-processes ()
  "Display a list of all processes.
\(Any processes listed as Exited or Signaled are actually eliminated
after the listing is made.)"
  (interactive)
  (with-output-to-temp-buffer "*Process List*"
    (set-buffer standard-output)
    (buffer-disable-undo standard-output)
    (make-local-variable 'truncate-lines)
    (setq truncate-lines t)
    ;;      00000000001111111111222222222233333333334444444444
    ;;      01234567890123456789012345678901234567890123456789
    ;; rewritten for I18N3.  This one should stay rewritten
    ;; so that the dashes will line up properly.
    (princ "Proc         Status   Buffer         Tty         Command\n----         ------   ------         ---         -------\n")
    (let ((tail (process-list)))
      (while tail
	(let* ((p (car tail))
	       (pid (process-id p))
	       (s (process-status p)))
	  (setq tail (cdr tail))
	  (princ (format "%-13s" (process-name p)))
	  ;;(if (and (eq system-type 'vax-vms)
	  ;;         (eq s 'signal)
	  ;;        (< (process-exit-status p) NSIG))
	  ;;    (princ (aref sys_errlist (process-exit-status p))))
	  (princ s)
	  (if (and (eq s 'exit) (/= (process-exit-status p) 0))
	      (princ (format " %d" (process-exit-status p))))
	  (if (memq s '(signal exit closed))
	      ;; Do delete-exited-processes' work
	      (delete-process p))
	  (indent-to 22 1)		;####
	  (let ((b (process-buffer p)))
	    (cond ((not b)
		   (princ "(none)"))
		  ((not (buffer-name b))
		   (princ "(killed)"))
		  (t
		   (princ (buffer-name b)))))
	  (indent-to 37 1)		;####
	  (let ((tn (process-tty-name p)))
	    (cond ((not tn)
		   (princ "(none)"))
		  (t
		   (princ (format "%s" tn)))))
	  (indent-to 49 1)		;####
	  (if (not (integerp pid))
	      (progn
		(princ "network stream connection ")
		(princ (car pid))
		(princ "@")
		(princ (cdr pid)))
	    (let ((cmd (process-command p)))
	      (while cmd
		(princ (car cmd))
		(setq cmd (cdr cmd))
		(if cmd (princ " ")))))
	  (terpri))))))

;;; help.el ends here
