;; help.el --- help commands for XEmacs.

;; Copyright (C) 1985, 1986, 1992-4, 1997, 2014 Free Software Foundation, Inc.
;; Copyright (C) 2001, 2002, 2003, 2010 Ben Wing.

;; Maintainer: FSF
;; Keywords: help, internal, dumped

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

(require 'loadhist) ;; For symbol-file. 

(defgroup help nil
  "Support for on-line help systems."
  :group 'emacs)

(defgroup help-appearance nil
  "Appearance of help buffers."
  :group 'help)

(defvar help-map (let ((map (make-sparse-keymap)))
                   (set-keymap-name map 'help-map)
                   (set-keymap-prompt
		    map (gettext "(Type ? for further options)"))
                   map)
  "Keymap for characters following the Help key.")

(defvar help-mode-link-positions nil)
(make-variable-buffer-local 'help-mode-link-positions)

;; global-map definitions moved to keydefs.el
(fset 'help-command help-map)

(define-key help-map (vector help-char) 'help-for-help)
(define-key help-map "?" 'help-for-help)
(define-key help-map 'help 'help-for-help)
(define-key help-map '(f1) 'help-for-help)

(define-key help-map "a" 'hyper-apropos) ; 'command-apropos in FSFmacs
(define-key help-map "A" 'command-hyper-apropos)
;; #### should be hyper-apropos-documentation, once that's written.
(define-key help-map "\C-a" 'apropos-documentation)

(define-key help-map "b" 'describe-bindings)
(define-key help-map "B" 'describe-beta)

(define-key help-map "c" 'describe-key-briefly)
(define-key help-map "C" 'customize)
;; FSFmacs has Info-goto-emacs-command-node on C-f, no binding
;; for Info-elisp-ref
(define-key help-map "\C-c" 'Info-goto-emacs-command-node)

(define-key help-map "d" 'describe-function)
(define-key help-map "\C-d" 'describe-distribution)

(define-key help-map "e" (if (fboundp 'view-last-error) 'view-last-error
			   'describe-last-error))

(define-key help-map "f" 'describe-function)
;; #### not a good interface.  no way to specify that C-h is preferred
;; as a prefix and not BS.  should instead be specified as part of
;; `define-key'.
;; (put 'describe-function 'preferred-key-sequence "\C-hf")
(define-key help-map "F" 'xemacs-local-faq)
(define-key help-map "\C-f" 'Info-elisp-ref)

(define-key help-map "i" 'info)
(define-key help-map "I" 'Info-search-index-in-xemacs-and-lispref)
(define-key help-map "\C-i" 'Info-query)

(define-key help-map "k" 'describe-key)
(define-key help-map "\C-k" 'Info-goto-emacs-key-command-node)

(define-key help-map "l" 'view-lossage)
(define-key help-map "\C-l" 'describe-copying) ; on \C-c in FSFmacs

(define-key help-map "m" 'describe-mode)

(define-key help-map "n" 'view-emacs-news)
(define-key help-map "\C-n" 'view-emacs-news)

(define-key help-map "p" 'finder-by-keyword)
(define-key help-map "\C-p" 'describe-pointer)
(define-key help-map "P" 'view-xemacs-problems)

(define-key help-map "q" 'help-quit)

;; Do this right with an autoload cookie in finder.el.
;;(autoload 'finder-by-keyword "finder"
;;  "Find packages matching a given keyword." t)

(define-key help-map "s" 'describe-syntax)
(define-key help-map "S" 'view-sample-init-el)

(define-key help-map "t" 'help-with-tutorial)

(define-key help-map "v" 'describe-variable)

(define-key help-map "w" 'where-is)
(define-key help-map "\C-w" 'describe-no-warranty)

;; #### It would be nice if the code below to add hyperlinks was
;; generalized.  We would probably need a "hyperlink mode" from which
;; help-mode is derived.  This means we probably need multiple
;; inheritance of modes!  Thankfully this is not hard to implement; we
;; already have the ability for a keymap to have multiple parents.
;; However, we'd have to define any multiply-inherited-from modes using
;; a standard `define-mode' construction instead of manually doing it,
;; because we don't want each guy calling `kill-all-local-variables' and
;; messing up the previous one.

(define-derived-mode help-mode view-major-mode "Help"
  "Major mode for viewing help text.
Entry to this mode runs the normal hook `help-mode-hook'.
Commands:
\\{help-mode-map}"
  (help-mode-get-link-positions)
  )

(define-key help-mode-map "q" 'help-mode-quit)
(define-key help-mode-map "Q" 'help-mode-bury)
(define-key help-mode-map "f" 'find-function-at-point)
(define-key help-mode-map "d" 'describe-function-at-point)
(define-key help-mode-map "v" 'describe-variable-at-point)
(define-key help-mode-map "i" 'Info-elisp-ref)
(define-key help-mode-map "c" 'customize-variable)
(define-key help-mode-map [tab] 'help-next-symbol)
(define-key help-mode-map [iso-left-tab] 'help-prev-symbol)
(define-key help-mode-map [backtab] 'help-prev-symbol)
(define-key help-mode-map [return] 'help-activate-function-or-scroll-up)
(define-key help-mode-map "n" 'help-next-section)
(define-key help-mode-map "p" 'help-prev-section)

(define-derived-mode temp-buffer-mode view-major-mode "Temp"
  "Major mode for viewing temporary buffers.
Exit using \\<temp-buffer-mode-map>\\[help-mode-quit].

Entry to this mode runs the normal hook `temp-buffer-mode-hook'.
Commands:
\\{temp-buffer-mode-map}"
  )

(define-key temp-buffer-mode-map "q" 'help-mode-quit)
(define-key temp-buffer-mode-map "Q" 'help-mode-bury)

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
  "Move point to the next link."
  (interactive)
  (let ((p (point))
	(positions help-mode-link-positions)
	(firstpos (car help-mode-link-positions)))
    (while (and positions (>= p (car positions)))
      (setq positions (cdr positions)))
    (if (or positions firstpos)
	(goto-char (or (car positions) firstpos)))))

(defun help-prev-symbol ()
  "Move point to the previous link."
  (interactive)
  (let* ((p (point))
	(positions (reverse help-mode-link-positions))
	(lastpos (car positions)))
    (while (and positions (<= p (car positions)))
      (setq positions (cdr positions)))
    (if (or positions lastpos)
	(goto-char (or (car positions) lastpos)))))

(defun help-next-section ()
  "Move point to the next quoted symbol."
  (interactive)
  (search-forward-regexp "^\\w+:" nil t))

(defun help-prev-section ()
  "Move point to the previous quoted symbol."
  (interactive)
  (search-backward-regexp "^\\w+:" nil t))

(defun help-mode-bury ()
  "Bury the help buffer, possibly restoring the previous window configuration."
  (interactive)
  (help-mode-quit t))

(defun help-mode-quit (&optional bury)
  "Exit from help mode, possibly restoring the previous window configuration.
If the optional argument BURY is non-nil, the help buffer is buried,
otherwise it is killed."
  (interactive)
  (let ((buf (current-buffer)))
    (cond (help-window-config
	   (set-window-configuration help-window-config))
	  ((not (one-window-p))
	   (delete-window)))
    (if bury
	(bury-buffer buf)
      (kill-buffer buf))))

(defun help-quit ()
  (interactive)
  nil)

(defun help-mode-get-link-positions ()
  "Get the positions of the links in the help buffer"
  (let ((el (extent-list nil (point-min) (point-max) nil 'activate-function))
	(positions nil))
    (while el
      (setq positions (append positions (list (extent-start-position (car el)))))
      (setq el (cdr el)))
    (setq help-mode-link-positions positions)))
    

(define-obsolete-function-alias 'deprecated-help-command 'help-for-help)

;;(define-key global-map 'backspace 'deprecated-help-command)

(defconst tutorial-supported-languages
  '(
    ("Croatian" hr iso-8859-2)
    ("Czech" cs iso-8859-2)
    ("Dutch" nl iso-8859-1)
    ("English" nil raw-text)
    ("French" fr iso-8859-1)
    ("German" de iso-8859-1)
    ("Norwegian" no iso-8859-1)
    ("Polish" pl iso-8859-2)
    ("Romanian" ro iso-8859-2)
    ("Slovak" sk iso-8859-2)
    ("Slovenian" sl iso-8859-2)
    ("Spanish" es iso-8859-1)
    ("Swedish" se iso-8859-1)
    )
  "Alist of supported languages in TUTORIAL files.
Add languages here, as more are translated.")

;; TUTORIAL arg is XEmacs addition
(defun help-with-tutorial (&optional tutorial language)
  "Select the XEmacs learn-by-doing tutorial.
Optional arg TUTORIAL specifies the tutorial file; if not specified or
if this command is invoked interactively, the tutorial appropriate to
the current language environment is used.  If there is no tutorial
written in that language, or if this version of XEmacs has no
international (Mule) support, the English-language tutorial is used.
With a prefix argument, you are asked to select which language."
  (interactive "i\nP")
  (when (and language (consp language))
    (setq language
	  (if (featurep 'mule)
	      (or (declare-fboundp (read-language-name 'tutorial "Language: "))
		  (error "No tutorial file of the specified language"))
	    (let ((completion-ignore-case t))
	      (completing-read "Language: "
	       tutorial-supported-languages nil t)))))
  (or language
      (setq language
	    (if (featurep 'mule) (declare-boundp current-language-environment)
	      "English")))
  (or tutorial
      (setq tutorial
	    (cond ((featurep 'mule)
		   (or (declare-fboundp (get-language-info language 'tutorial))
		       "TUTORIAL"))
		  ((equal language "English") "TUTORIAL")
		  (t (format "TUTORIAL.%s"
			     (cadr (assoc language
					  tutorial-supported-languages)))))))
  (let ((file (expand-file-name tutorial "~")))
    (delete-other-windows)
    (let ((buffer (or (get-file-buffer file)
		      (create-file-buffer file)))
	  (window-configuration (current-window-configuration)))
      (condition-case error-data
	  (progn
	    (switch-to-buffer buffer)
	    (setq buffer-file-name file)
	    (setq default-directory (expand-file-name "~/"))
	    (setq buffer-auto-save-file-name nil)
	    ;; Because of non-Mule users, TUTORIALs are not coded
	    ;; independently, so we must guess the coding according to
	    ;; the language.
	    (let ((coding-system-for-read
		   (if (featurep 'mule)
		       (with-fboundp 'get-language-info
			 (or (get-language-info language
						'tutorial-coding-system)
			     (car (get-language-info language
						     'coding-system))))
		     (nth 2 (assoc language tutorial-supported-languages)))))
	      (insert-file-contents (locate-data-file tutorial)))
	    (goto-char (point-min))
	    ;; [The 'didactic' blank lines: possibly insert blank lines
	    ;; around <<nya nya nya>> and replace << >> with [ ].] No more
	    ;; didactic blank lines.  It was just a bad idea, anyway.  I
	    ;; rewrote the TUTORIAL so it doesn't need them.  However, some
	    ;; tutorials in other languages haven't yet been updated. ####
	    ;; Delete this code when they're all updated.
	    (if (re-search-forward "^<<.+>>" nil t)
		(let ((n (- (window-height (selected-window))
			    (count-lines (point-min) (point-at-bol))
			    6)))
		  (if (< n 12)
		      (progn (beginning-of-line) (kill-line))
		    ;; Some people get confused by the large gap
		    (delete-backward-char 2)
		    (insert "]")
		    (beginning-of-line)
		    (save-excursion
		      (delete-char 2)
		      (insert "["))
		    (newline (/ n 2))
		    (next-line 1)
		    (newline (- n (/ n 2))))))
	    (goto-char (point-min))
	    (set-buffer-modified-p nil))
	;; TUTORIAL was not found: kill the buffer and restore the
	;; window configuration.
	(file-error (kill-buffer buffer)
		    (set-window-configuration window-configuration)
		    ;; Now, signal the error
		    (signal (car error-data) (cdr error-data)))))))

;; used by describe-key, describe-key-briefly, insert-key-binding, etc.
(defun key-or-menu-binding (key &optional menu-flag)
  "Return the command invoked by KEY.
Like `key-binding', but handles menu events and toolbar presses correctly.
KEY is any value returned by `next-command-event'.
MENU-FLAG is a symbol that should be set to t if KEY is a menu event,
 or nil otherwise."
  (let (defn)
    (and menu-flag (set menu-flag nil))
    ;; If the key typed was really a menu selection, grab the form out
    ;; of the event object and intuit the function that would be called,
    ;; and describe that instead.
    (if (and (vectorp key) (eql 1 (length key))
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

(defun describe-key-briefly (key &optional insert)
  "Print the name of the function KEY invokes.  KEY is a string.
If INSERT (the prefix arg) is non-nil, insert the message in the buffer."
  (interactive "kDescribe key briefly: \nP")
  (let ((standard-output (if insert (current-buffer) t))
	defn menup)
    (setq defn (key-or-menu-binding key 'menup))
    (if (or (null defn) (integerp defn))
        (princ (format "%s is undefined" (key-description key)))
      ;; If it's a keyboard macro which trivially invokes another command,
      ;; document that instead.
      (if (or (stringp defn) (vectorp defn))
	  (setq defn (or (key-binding defn)
			 defn)))
      (let ((last-event (and (vectorp key)
			     (aref key (1- (length key))))))
	(princ (format (cond (insert
			      "%s (%s)")
			     ((or (button-press-event-p last-event)
				  (button-release-event-p last-event))
			      (gettext "%s at that spot runs the command %s"))
			     (t
			      (gettext "%s runs the command %s")))
		       ;; This used to say 'This menu item' but it
		       ;; could also be a scrollbar event.  We can't
		       ;; distinguish at the moment.
		       (if menup
			   (if insert "item" "This item")
			 (key-description key))
		       (if (symbolp defn) defn (prin1-to-string defn))))))))

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

(defcustom help-max-help-buffers 10
  "*Maximum help buffers to allow before they start getting killed.
If this is a positive integer, before a help buffer is displayed
by `with-displaying-help-buffer', any excess help buffers which
are not being displayed are first killed.  Otherwise, if it is
zero or nil, only one help buffer, \"*Help*\" is ever used."
  :type '(choice integer (const :tag "None" nil))
  :group 'help-appearance)

(defvar help-buffer-list nil
  "List of help buffers used by `help-register-and-maybe-prune-excess'")

(defun help-register-and-maybe-prune-excess (newbuf)
  "Register help buffer named NEWBUF and possibly kill excess ones."
  ;; don't let client code pass us bogus NEWBUF---if it gets in the list,
  ;; help can become unusable
  (unless (stringp newbuf)
    (error 'wrong-type-argument "help buffer name must be string" newbuf))
  ;; remove new buffer from list
  (setq help-buffer-list (remove newbuf help-buffer-list))
  ;; maybe kill excess help buffers
  (if (and (integerp help-max-help-buffers)
           (> (length help-buffer-list) help-max-help-buffers))
      (let ((keep-list nil)
            (num-kill (- (length help-buffer-list)
                         help-max-help-buffers)))
        (while help-buffer-list
          (let ((buf (car help-buffer-list)))
            (if (and (or (equal buf newbuf) (get-buffer buf))
                     (string-match "^*Help" buf)
                     (save-excursion (set-buffer buf)
                                     (eq major-mode 'help-mode)))
                (if (and (>= num-kill (length help-buffer-list))
                         (not (get-buffer-window buf t t)))
                    (kill-buffer buf)
                  (setq keep-list (cons buf keep-list)))))
          (setq help-buffer-list (cdr help-buffer-list)))
        (setq help-buffer-list (nreverse keep-list))))
  ;; push new buffer
  (setq help-buffer-list (cons newbuf help-buffer-list)))

(defvar help-buffer-prefix-string "Help"
  "Initial string to use in constructing help buffer names.
You should never set this directly, only let-bind it.")

(defun help-buffer-name (name)
  "Return a name for a Help buffer using string NAME for context."
  (if (and (integerp help-max-help-buffers)
           (> help-max-help-buffers 0)
           (stringp name))
      (if help-buffer-prefix-string
	  (format "*%s: %s*" help-buffer-prefix-string name)
	(format "*%s*" name))
    (format "*%s*" help-buffer-prefix-string)))

;; with-displaying-help-buffer

;; #### Should really be a macro to eliminate the requirement of
;; caller to code a lambda form in THUNK -- mrb

;; #### BEFORE you rush to make this a macro, think about backward
;; compatibility.  The right way would be to create a macro with
;; another name (which is a shame, because w-d-h-b is a perfect name
;; for a macro) that uses with-displaying-help-buffer internally.

(defcustom mode-for-help 'help-mode
  "*Mode that help buffers are put into.")

(defcustom mode-for-temp-buffer 'temp-buffer-mode
  "*Mode that help buffers are put into.")

(defvar help-sticky-window nil
;; Window into which help buffers will be displayed, rather than
;; always searching for a new one.  This is INTERNAL and liable to
;; change its interface and/or name at any moment.  It should be
;; bound, not set.
)

(defvar help-window-config nil)

(make-variable-buffer-local 'help-window-config)
(put 'help-window-config 'permanent-local t)

(defmacro with-displaying-temp-buffer (name &rest body)
  "Make a help buffer with given NAME and evaluate BODY, sending stdout there.

Use this function for displaying information in temporary buffers, where the
user will typically view the information and then exit using
\\<temp-buffer-mode-map>\\[help-mode-quit].

On exit from this form, the buffer is put into the mode specified in
`mode-for-temp-buffer' and displayed, typically in a popup window.  Ie,
the buffer is a scratchpad which is displayed all at once in formatted
form.

N.B. Write to this buffer with functions like `princ', not `insert'."
  `(let* ((winconfig (current-window-configuration))
	  (was-one-window (one-window-p))
	  (buffer-name ,name)
	  (help-not-visible
	   (not (and (windows-of-buffer buffer-name) ;shortcut
		     (memq (selected-frame)
			   (mapcar 'window-frame
				   (windows-of-buffer buffer-name)))))))
    (help-register-and-maybe-prune-excess buffer-name)
    ;; if help-sticky-window is bogus or deleted, get rid of it.
    (if (and help-sticky-window (or (not (windowp help-sticky-window))
				    (not (window-live-p help-sticky-window))))
	(setq help-sticky-window nil))
    (prog1
	(let ((temp-buffer-show-function
	       (if help-sticky-window
		   #'(lambda (buffer)
		       (set-window-buffer help-sticky-window buffer))
		 temp-buffer-show-function)))
	  (with-output-to-temp-buffer buffer-name
	    (prog1 (progn ,@body)
	      (save-excursion
		(set-buffer standard-output)
		(funcall mode-for-temp-buffer)))))
      (let ((helpwin (get-buffer-window buffer-name)))
	(when helpwin
	  ;; If the temp buffer is already displayed on this
	  ;; frame, don't override the previous configuration
	  (when help-not-visible
	    (with-current-buffer (window-buffer helpwin)
	      (setq help-window-config winconfig)))
	  (when help-selects-help-window
	    (select-window helpwin))
	  (cond ((eq helpwin (selected-window))
		 (display-message 'command
		   (substitute-command-keys "Type \\[help-mode-quit] to remove window, \\[scroll-up] to scroll the text.")))
		(was-one-window
		 (display-message 'command
		   (substitute-command-keys "Type \\[delete-other-windows] to remove window, \\[scroll-other-window] to scroll the text.")))
		(t
		 (display-message 'command
		   (substitute-command-keys "Type \\[switch-to-buffer-other-window] to restore the other window, \\[scroll-other-window] to scroll the text.")))))))))

(put 'with-displaying-temp-buffer 'lisp-indent-function 1)

(defun with-displaying-help-buffer (thunk &optional name)
  "Form which makes a help buffer with given NAME and evaluates BODY there.
The actual name of the buffer is generated by the function `help-buffer-name'.

Use this function for displaying help when C-h something is pressed or
in similar situations.  Do *not* use it when you are displaying a help
message and then prompting for input in the minibuffer -- this macro
usually selects the help buffer, which is not what you want in those
situations."
  (let ((mode-for-temp-buffer mode-for-help))
    (with-displaying-temp-buffer (help-buffer-name name)
      (funcall thunk))))

(defun describe-key (key)
  "Display documentation of the function invoked by KEY.
KEY is a string, or vector of events.
When called interactively, KEY may also be a menu selection."
  (interactive "kDescribe key: ")
  (let ((defn (key-or-menu-binding key))
	(key-string (key-description key)))
    (if (or (null defn) (integerp defn))
        (message "%s is undefined" key-string)
      (with-displaying-help-buffer
       (lambda ()
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
		(princ "not documented"))))
       (format "key `%s'" key-string)))))

(defun describe-mode ()
  "Display documentation of current major mode and minor modes.
For this to work correctly for a minor mode, the mode's indicator variable
\(listed in `minor-mode-alist') must also be a function whose documentation
describes the minor mode."
  (interactive)
  (with-displaying-help-buffer
   (lambda ()
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
		 (princ (format "%s minor mode (%s):\n"
				pretty-minor-mode
				(if indicator
				    (format "indicator%s" indicator)
				  "no indicator")))
		 (princ (documentation minor-mode))
		 (princ "\n\n----\n\n"))))
	 (setq minor-modes (cdr minor-modes)))))
   (format "%s mode" mode-name)))

;; So keyboard macro definitions are documented correctly
(fset 'defining-kbd-macro (symbol-function 'start-kbd-macro))

;; view a read-only file intelligently
(defun Help-find-file (file)
  (if (fboundp 'view-file)
      (view-file file)
    (find-file-read-only file)
    (goto-char (point-min))))

(defun describe-distribution ()
  "Display info on how to obtain the latest version of XEmacs."
  (interactive)
  (save-window-excursion
    (info)
    (Info-find-node "xemacs-faq" "Q1.1.1"))
  (switch-to-buffer "*info*"))

(defun describe-beta ()
  "Display info on how to deal with Beta versions of XEmacs."
  (interactive)
  (save-window-excursion
    (info "(beta)Top"))
  (switch-to-buffer "*info*"))

(defun describe-copying ()
  "Display info on how you may redistribute copies of XEmacs."
  (interactive)
  (Help-find-file (locate-data-file "COPYING")))

(defun describe-pointer ()
  "Show a list of all defined mouse buttons, and their definitions."
  (interactive)
  (describe-bindings nil t))

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
If optional first argument PREFIX is supplied, only commands
which start with that sequence of keys are described.
If optional second argument MOUSE-ONLY-P (prefix arg, interactively)
is non-nil then only the mouse bindings are displayed."
  (interactive (list nil current-prefix-arg))
  (with-displaying-help-buffer
   (lambda ()
     (describe-bindings-1 prefix mouse-only-p))
   (format "bindings for %s" major-mode)))

(defun describe-bindings-1 (&optional prefix mouse-only-p)
  (let ((heading (if mouse-only-p
            (gettext "button          binding\n------          -------\n")
            (gettext "key             binding\n---             -------\n")))
        (buffer (current-buffer))
        (minor minor-mode-map-alist)
	(extent-maps (mapcar-extents
		      'extent-keymap
		      nil (current-buffer) (point) (point) nil 'keymap))
        (local (current-local-map))
        (shadow '()))
    (set-buffer standard-output)
    (while extent-maps
      (insert "Bindings for Text Region:\n"
	      heading)
      (describe-bindings-internal
       (car extent-maps) nil shadow prefix mouse-only-p)
       (insert "\n")
       (setq shadow (cons (car extent-maps) shadow)
	     extent-maps (cdr extent-maps)))
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
    (if (console-on-window-system-p)
	(progn
	  (insert "Global Window-System-Only Bindings:\n" heading)
	  (describe-bindings-internal global-window-system-map nil
				      shadow prefix mouse-only-p)
	  (push global-window-system-map shadow))
      (insert "Global TTY-Only Bindings:\n" heading)
      (describe-bindings-internal global-tty-map nil
				  shadow prefix mouse-only-p)
      (push global-tty-map shadow))
    (insert "\nGlobal Bindings:\n" heading)
    (describe-bindings-internal (current-global-map)
                                nil shadow prefix mouse-only-p)
    (when (and prefix function-key-map (not mouse-only-p))
      (insert "\nFunction key map translations:\n" heading)
      (describe-bindings-internal function-key-map nil nil
				  prefix mouse-only-p))
    (set-buffer buffer)
    standard-output))

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
    (with-displaying-help-buffer
     (lambda ()
       (princ "Key bindings starting with ")
       (princ (key-description prefix))
       (princ ":\n\n")
       (describe-bindings-1 prefix nil))
     (format "%s prefix" (key-description prefix)))))

;; Make C-h after a prefix, when not specifically bound,
;; run describe-prefix-bindings.
(setq prefix-help-command 'describe-prefix-bindings)

(defun describe-installation ()
  "Display a buffer showing information about this XEmacs was compiled."
  (interactive)
  (if (and-boundp 'Installation-string
	(stringp Installation-string))
      (with-displaying-help-buffer
       (lambda ()
	 (princ Installation-string))
       "Installation")
    (error 'unimplemented "No Installation information available.")))

(defun view-emacs-news ()
  "Display info on recent changes to XEmacs."
  (interactive)
  (Help-find-file (expand-file-name "NEWS" data-directory)))

(defun view-xemacs-problems ()
  "Display known problems with XEmacs."
  (interactive)
  (Help-find-file (expand-file-name "PROBLEMS" data-directory)))

(defun xemacs-www-page ()
  "Go to the XEmacs World Wide Web page."
  (interactive)
  (if-fboundp 'browse-url
      (browse-url "http://www.xemacs.org/")
    (error "xemacs-www-page requires browse-url")))

(defun xemacs-www-faq ()
  "View the latest and greatest XEmacs FAQ using the World Wide Web."
  (interactive)
  (if-fboundp 'browse-url
      (browse-url "http://www.xemacs.org/faq/index.html")
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

(defun view-sample-init-el ()
  "Display the sample init.el file."
  (interactive)
  (Help-find-file (locate-data-file "sample.init.el")))

(defcustom view-lossage-key-count 100
  "*Number of keys `view-lossage' shows.
The maximum number of available keys is governed by `recent-keys-ring-size'."
  :type 'integer
  :group 'help)

(defcustom view-lossage-message-count 100
  "*Number of minibuffer messages `view-lossage' shows."
  :type 'integer
  :group 'help)

(defun print-recent-messages (n)
  "Print N most recent messages to standard-output, most recent first.
If N is nil, all messages will be printed."
  (clear-message) ;; make sure current message goes into log
  (save-excursion
    (let ((buffer (get-buffer-create " *Message-Log*"))
	  oldpoint extent)
      (goto-char (point-max buffer) buffer)
      (set-buffer standard-output)
      (while (and (not (bobp buffer))
		  (or (null n) (>= (decf n) 0)))
	(setq oldpoint (point buffer))
	(setq extent (extent-at oldpoint buffer
				'message-multiline nil 'before))
	;; If the message was multiline, move all the way to the
	;; beginning.
	(if extent
	    (goto-char (extent-start-position extent) buffer)
	  (forward-line -1 buffer))
	(insert-buffer-substring buffer (point buffer) oldpoint)))))

(defun view-warnings ()
  "Display warnings issued."
  (interactive)
  (with-displaying-help-buffer
   (lambda ()
     (let ((buf (get-buffer "*Warnings*")))
       (when buf
	 (save-excursion
	   (set-buffer standard-output)
	   (map-extents
	    #'(lambda (extent arg)
		(goto-char (point-min))
		(insert (extent-string extent)))
	    buf)))))
   "warnings"))

(defun view-lossage (&optional no-keys)
  "Display recent input keystrokes and recent minibuffer messages.
The number of keys shown is controlled by `view-lossage-key-count'.
The number of messages shown is controlled by `view-lossage-message-count'.

If optional arg NO-KEYS (prefix arg, interactively) is non-nil,
then recent input keystrokes output is omitted."
  (interactive "P")
  (with-displaying-help-buffer
   (lambda ()
     (unless no-keys
       (princ (key-description (recent-keys view-lossage-key-count)))
       (save-excursion
	 (set-buffer standard-output)
	 (goto-char (point-min))
	 (insert "Recent keystrokes:\n\n")
	 (while (progn (move-to-column 50) (not (eobp)))
	   (search-forward " " nil t)
	   (insert "\n")))
       (princ "\n\n\n"))
     ;; Copy the messages from " *Message-Log*", reversing their order and
     ;; handling multiline messages correctly.
     (princ "Recent minibuffer messages (most recent first):\n\n")
     (print-recent-messages view-lossage-message-count))
   "lossage"))

(define-function 'help 'help-for-help)

(make-help-screen help-for-help
  "A B C F I K L M N P S T V W C-c C-d C-f C-i C-k C-n C-w;  ? for more help:"
  (concat
   "Type a Help option:
\(Use SPC or DEL to scroll through this text.  Type \\<help-map>\\[help-quit] to exit the Help command.)

Help on key bindings:

\\[describe-bindings]	Table of all key bindings.
\\[describe-key-briefly]	Type a key sequence or select a menu item;
        it displays the corresponding command name.
\\[describe-key]	Type a key sequence or select a menu item;
        it displays the documentation for the command bound to that key.
	(Terser but more up-to-date than what's in the manual.)
\\[Info-goto-emacs-key-command-node]	Type a key sequence or select a menu item;
	it jumps to the full documentation in the XEmacs User's Manual
	for the corresponding command.
\\[view-lossage]	Recent input keystrokes and minibuffer messages.
\\[describe-mode]	Documentation of current major and minor modes.
\\[describe-pointer]	Table of all mouse-button bindings.
\\[where-is]	Type a command name; it displays which keystrokes invoke that command.

Help on functions and variables:

\\[hyper-apropos]	Type a substring; it shows a hypertext list of
        functions and variables that contain that substring.
\\[command-apropos]	Older version of apropos; superseded by previous command.
\\[apropos-documentation]	Type a substring; it shows a hypertext list of
        functions and variables containing that substring anywhere
        in their documentation.
\\[Info-goto-emacs-command-node]	Type a command name; it jumps to the full documentation
	in the XEmacs User's Manual.
\\[describe-function]	Type a command or function name; it shows its documentation.
	(Terser but more up-to-date than what's in the manual.)
\\[Info-elisp-ref]	Type a function name; it jumps to the full documentation
	in the XEmacs Lisp Reference Manual.
\\[Info-search-index-in-xemacs-and-lispref]	Type a substring; it looks it up in the indices of both
	the XEmacs User's Manual and the XEmacs Lisp Reference Manual.
	It jumps to the first match (preferring an exact match); you
	can use `\\<Info-mode-map>\\[Info-index-next]\\<help-map>' to successively visit other matches.
\\[describe-variable]	Type a variable name; it displays its documentation and value.

Miscellaneous:

"
   (if (string-match "beta" emacs-version)
"\\[describe-beta]	Special considerations about running a beta version of XEmacs.
"
"")
"
\\[view-xemacs-problems]	Known problems.
\\[customize]	Customize Emacs options.
\\[describe-distribution]	How to obtain XEmacs.
\\[describe-last-error]	Information about the most recent error.
\\[xemacs-local-faq]	Local copy of the XEmacs FAQ.
\\[info]	Info documentation reader.
\\[Info-query]	Type an Info file name; it displays it in Info reader.
\\[describe-copying]	XEmacs copying permission (General Public License).
\\[view-emacs-news]	News of recent XEmacs changes.
\\[finder-by-keyword]	Type a topic keyword; it finds matching packages.
\\[describe-syntax]	Contents of syntax table with explanations.
\\[view-sample-init-el]	View the sample init.el that comes with XEmacs.
\\[help-with-tutorial]	XEmacs learn-by-doing tutorial.
\\[describe-no-warranty]	Information on absence of warranty for XEmacs."
)
  help-map)

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

(defun function-at-event (event)
  "Return the function whose name is around the position of EVENT.
EVENT should be a mouse event.  When calling from a popup or context menu,
use `last-popup-menu-event' to find out where the mouse was clicked.
\(You cannot use (interactive \"e\"), unfortunately.  This returns a
misc-user event.)

If the event contains no position, or the position is not over text, or
there is no function around that point, nil is returned."
  (if (and event (event-buffer event) (event-point event))
      (save-excursion
	(set-buffer (event-buffer event))
	(goto-char (event-point event))
	(function-at-point))))

;; Default to nil for the non-hackers?  Not until we find a way to
;; distinguish hackers from non-hackers automatically!
(defcustom describe-function-show-arglist t
  "*If non-nil, describe-function will show the function's arglist."
  :type 'boolean
  :group 'help-appearance)

(define-obsolete-function-alias
  ;; Moved to using the version in loadhist.el
  'describe-function-find-symbol
  'symbol-file)

(define-obsolete-function-alias
  'describe-function-find-file
  'symbol-file)

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
                    obarray 'fboundp t nil 'function-history
		    (symbol-name fn)))))
      (list (intern val))))
  (with-displaying-help-buffer
   (lambda ()
     (describe-function-1 function)
     ;; Return the text we displayed.
     (buffer-string nil nil standard-output))
    (format "function `%s'" function)))

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
;(gettext "an autoloaded Lisp function")
;(gettext "an interactive autoloaded Lisp function")
;(gettext "an autoloaded Lisp macro")
;(gettext "an interactive autoloaded Lisp macro")

;; taken out of `describe-function-1'
(defun function-arglist (function)
  "Return a string giving the argument list of FUNCTION.
For example:

	(function-arglist 'function-arglist)
	=> \"(function-arglist FUNCTION)\"

This function is used by `describe-function-1' to list function
arguments in the standard Lisp style."
  (let* ((fnc (indirect-function function))
	 (fndef (if (eq (car-safe fnc) 'macro)
		    (cdr fnc)
		  fnc))
	 (args (cdr (function-documentation-1 function t)))
	 (arglist
	  (or args
	      (cond ((compiled-function-p fndef)
		     (compiled-function-arglist fndef))
		    ((eq (car-safe fndef) 'lambda)
		     (nth 1 fndef))
		    ((or (subrp fndef) (eq 'autoload (car-safe fndef)))
		 
		     ;; If there are no arguments documented for the
		     ;; subr, rather don't print anything.
		     (cond ((null args) t)
			   ((equal args "") nil)
			   (args)))
		    (t t))))
         (print-gensym nil))
    (cond ((listp arglist)
	   (prin1-to-string
	    (cons function (loop
                             for arg in arglist
                             collect (if (memq arg '(&optional &rest))
                                         arg
                                       (make-symbol (upcase (symbol-name
                                                             arg))))))

	    t))
	  ((stringp arglist)
	   (if (> (length arglist) 0)
	       (format "(%s %s)" function arglist)
	     (format "(%s)" function))))))

;; If STRIP-ARGLIST is true, return a cons (DOC . ARGS) of the documentation
;; with any embedded arglist stripped out, and the arglist that was stripped
;; out.  If STRIP-ARGLIST is false, the cons will be (FULL-DOC . nil),
;; where FULL-DOC is the full documentation without the embedded arglist
;; stripped out.
(defun function-documentation-1 (function &optional strip-arglist)
  (let ((doc (condition-case nil
		 (or (documentation function)
		     (gettext "not documented"))
	       (void-function "(alias for undefined function)")
	       (error "(unexpected error from `documentation')")))
	args)
    (when (and strip-arglist
               (string-match "[\n\t ]*\narguments: ?(\\(.*\\))\n?\\'" doc))
      (setq args (match-string 1 doc))
      (setq doc (substring doc 0 (match-beginning 0)))
      (and args (setq args (replace-in-string args "[ ]*\\\\\n[ \t]*" " " t)))
      (and (eql 0 (length doc)) (setq doc (gettext "not documented"))))
    (cons doc args)))

(defun function-documentation (function &optional strip-arglist)
  "Return a string giving the documentation for FUNCTION, if any.
If the optional argument STRIP-ARGLIST is non-nil, remove the arglist
part of the documentation of internal subroutines, CL lambda forms, etc."
  (car (function-documentation-1 function strip-arglist)))

;; replacement for `princ' that puts the text in the specified face,
;; if possible
(defun Help-princ-face (object face)
  (cond ((bufferp standard-output)
	 (let ((opoint (point standard-output)))
	   (princ object)
	   (put-nonduplicable-text-property opoint (point standard-output)
					    'face face standard-output)))
	((markerp standard-output)
	 (let ((buf (marker-buffer standard-output))
	       (pos (marker-position standard-output)))
	   (princ object)
	   (put-nonduplicable-text-property
	    pos (marker-position standard-output) 'face face buf)))
	(t (princ object))))

;; replacement for `prin1' that puts the text in the specified face,
;; if possible
(defun Help-prin1-face (object face)
  (cond ((bufferp standard-output)
	 (let ((opoint (point standard-output)))
	   (prin1 object)
	   (put-nonduplicable-text-property opoint (point standard-output)
					    'face face standard-output)))
	((markerp standard-output)
	 (let ((buf (marker-buffer standard-output))
	       (pos (marker-position standard-output)))
	   (prin1 object)
	   (put-nonduplicable-text-property
	    pos (marker-position standard-output) 'face face buf)))
	(t (prin1 object))))

(defvar help-symbol-regexp
  (let ((sym-char "[+a-zA-Z0-9_:*]")
	(sym-char-no-dash "[-+a-zA-Z0-9_:*]"))
    (concat "\\("
	    ;; a symbol with a - in it.
	    "\\<\\(" sym-char-no-dash "+\\(-" sym-char-no-dash "+\\)+\\)\\>"
	    "\\|"
	    "`\\(" sym-char "+\\)'"
	    "\\)")))

(defun help-symbol-run-function-1 (ev ex fun)
  (let ((help-sticky-window
	 ;; if we were called from a help buffer, make sure the new help
	 ;; goes in the same window.
	 (if (and ev 
		  (event-buffer ev)
		  (symbol-value-in-buffer 'help-window-config
					  (event-buffer ev)))
	     (event-window ev)
	   (if ev help-sticky-window
	     (get-buffer-window (current-buffer))))))
    (funcall fun (extent-property ex 'help-symbol))))

(defun help-symbol-run-function (fun)
  (let ((ex (extent-at-event last-popup-menu-event 'help-symbol)))
    (when ex
      (help-symbol-run-function-1 last-popup-menu-event ex fun))))

(defvar help-symbol-function-context-menu
  '(["View %_Documentation" (help-symbol-run-function 'describe-function)]
    ["Find %_Function Source" (help-symbol-run-function 'find-function)
     (fboundp 'find-function)]
    ["Find %_Tag" (help-symbol-run-function 'find-tag)]
    ))

(defvar help-symbol-variable-context-menu
  '(["View %_Documentation" (help-symbol-run-function 'describe-variable)]
    ["Find %_Variable Source" (help-symbol-run-function 'find-variable)
     (fboundp 'find-variable)]
    ["Find %_Tag" (help-symbol-run-function 'find-tag)]
    ))

(defvar help-symbol-function-and-variable-context-menu
  '(["View Function %_Documentation" (help-symbol-run-function
				      'describe-function)]
    ["View Variable D%_ocumentation" (help-symbol-run-function
				      'describe-variable)]
    ["Find %_Function Source" (help-symbol-run-function 'find-function)
     (fboundp 'find-function)]
    ["Find %_Variable Source" (help-symbol-run-function 'find-variable)
     (fboundp 'find-variable)]
    ["Find %_Tag" (help-symbol-run-function 'find-tag)]
    ))

(defun frob-help-extents (buffer)
  ;; Look through BUFFER, starting at the buffer's point and continuing
  ;; till end of file, and find documented functions and variables.
  ;; any such symbol found is tagged with an extent, that sets up these
  ;; properties:
  ;; 1. mouse-face is 'highlight (so the extent gets highlighted on mouse over)
  ;; 2. help-symbol is the name of the symbol.
  ;; 3. face is 'hyper-apropos-hyperlink.
  ;; 4. context-menu is a list of context menu items, specific to whether
  ;;    the symbol is a function, variable, or both.
  ;; 5. activate-function will cause the function or variable to be described,
  ;;    replacing the existing help contents.
  (save-excursion
    (set-buffer buffer)
    (let (b e name)
      (while (re-search-forward help-symbol-regexp nil t)
	(setq b (or (match-beginning 2) (match-beginning 4)))
	(setq e (or (match-end 2) (match-end 4)))
	(setq name (buffer-substring b e))
	(let* ((sym (intern-soft name))
	       (var (and sym (boundp sym)
			 (documentation-property sym
						 'variable-documentation t)))
	       (fun (and sym (fboundp sym)
			 (condition-case nil
			     (documentation sym t)
			   (void-function "(alias for undefined function)")
			   (error "(unexpected error from `documention')")))))
	  (when (or var fun)
	    (let ((ex (make-extent b e)))
	      (require 'hyper-apropos)

	      (set-extent-property ex 'mouse-face 'highlight)
	      (set-extent-property ex 'help-symbol sym)
	      (set-extent-property ex 'face 'hyper-apropos-hyperlink)
	      (set-extent-property
	       ex 'context-menu
	       (cond ((and var fun)
		      help-symbol-function-and-variable-context-menu)
		     (var help-symbol-variable-context-menu)
		     (fun help-symbol-function-context-menu)))
	      (set-extent-property
	       ex 'activate-function
	       (if fun
		   #'(lambda (ev ex)
		       (help-symbol-run-function-1 ev ex 'describe-function))
		 #'(lambda (ev ex)
		     (help-symbol-run-function-1 ev ex 'describe-variable))))
	      ))))))) ;; 11 parentheses!

(defun describe-function-1 (function &optional nodoc)
  "This function does the work for `describe-function'."
  (princ "`")
  ;; (Help-princ-face function 'font-lock-function-name-face) overkill
  (princ function)
  (princ "' is ")
  (let* ((def function)
	 aliases file-name kbd-macro-p fndef macrop)
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
    (if (eq 'macro (car-safe def))
	(setq fndef (cdr def)
	      macrop t)
      (setq fndef def))
    (if aliases (princ aliases))
    (labels
        ((int (string an-p macro-p)
           (princ (format
                   (gettext (concat
                             (cond ((commandp def)
                                    "an interactive ")
                                   (an-p "an ")
                                   (t "a "))
                             "%s"
                             (cond
                              ((eq 'neither macro-p)
                               "")
                              (macro-p " macro")
                              (t " function"))))
                   string))))
      (declare (inline int))
      (cond ((or (stringp def) (vectorp def))
             (princ "a keyboard macro.")
	     (setq kbd-macro-p t))
            ((special-operator-p fndef)
             (int "built-in special operator" nil 'neither))
            ((subrp fndef)
             (int "built-in" nil macrop))
            ((compiled-function-p fndef)
             (int (concat (if (built-in-symbol-file function 'defun)
                              "built-in "
                            "") "compiled Lisp") nil macrop))
            ((eq (car-safe fndef) 'lambda)
             (int "Lisp" nil macrop))
            ((eq (car-safe def) 'autoload)
	     (int "autoloaded Lisp" t (elt def 4)))
	    ((and (symbolp def) (not (fboundp def)))
	     (princ "a symbol with a void (unbound) function definition."))
            (t
             nil)))
    (princ "\n")
    (or file-name
	(setq file-name (symbol-file function 'defun)))
    (when file-name
	(princ "  -- loaded from \"")
	(if (not (bufferp standard-output))
	    (princ file-name)
	  (let ((opoint (point standard-output))
		e)
	    (require 'hyper-apropos)
	    (princ file-name)
	    (setq e (make-extent opoint (point standard-output)
				 standard-output))
	    (set-extent-property e 'face 'hyper-apropos-hyperlink)
	    (set-extent-property e 'mouse-face 'highlight)
	    (set-extent-property e 'help-symbol function)
	    (set-extent-property e 'activate-function  #'(lambda (ev ex) (help-symbol-run-function-1 ev ex 'find-function)))))
	(princ "\"\n"))
    (if describe-function-show-arglist
	(let ((arglist (function-arglist function)))
	  (when arglist
	    (require 'hyper-apropos)
	    (Help-princ-face arglist 'hyper-apropos-documentation)
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
		 (let ((oldp (point standard-output))
		       newp)
		   (princ doc)
		   (setq newp (point standard-output))
		   (goto-char oldp standard-output)
		   (frob-help-extents standard-output)
		   (goto-char newp standard-output))
		 (unless (or (equal doc "")
			     (eq ?\n (aref doc (1- (length doc)))))
		   (terpri)))
	       (when (commandp function)
		 (princ "\nInvoked with:\n")
		 (let ((global-binding
			(where-is-internal function global-map))
		       (global-tty-binding 
			(where-is-internal function global-tty-map))
		       (global-window-system-binding 
			(where-is-internal function global-window-system-map))
                       (command-remapping (command-remapping function))
                       (commands-remapped-to (commands-remapped-to function)))
                   (if (or global-binding global-tty-binding
                           global-window-system-binding)
                       (if (and (equal global-binding
                                       global-tty-binding)
                                (equal global-binding
                                       global-window-system-binding))
                           (princ
                            (substitute-command-keys
                             (format "\n\\[%s]" function)))
                         (when (and global-window-system-binding
                                    (not (equal global-window-system-binding
                                                global-binding)))
                           (princ 
                            (format 
                             "\n%s\n        -- under window systems\n"
                             (mapconcat #'key-description
                                        global-window-system-binding
                                        ", "))))
                         (when (and global-tty-binding
                                    (not (equal global-tty-binding
                                                global-binding)))
                           (princ 
                            (format 
                             "\n%s\n        -- under TTYs\n"
                             (mapconcat #'key-description
                                        global-tty-binding
                                        ", "))))
                         (when global-binding
                           (princ 
                            (format 
                             "\n%s\n        -- generally (that is, unless\
 overridden by TTY- or
           window-system-specific mappings)\n"
                             (mapconcat #'key-description global-binding
                                        ", ")))))
                       (if command-remapping
                           (progn
                             (princ "Its keys are remapped to `")
                             (princ (symbol-name command-remapping))
                             (princ "'.\n"))
                           (princ (substitute-command-keys
                                   (format "\n\\[%s]" function))))
                       (when commands-remapped-to
                         (if (cdr commands-remapped-to)
                             (princ (format "\n\nThe following functions are \
remapped to it:\n`%s'" (mapconcat #'prin1-to-string commands-remapped-to
                                  "', `")))
                           (princ (format "\n\n`%s' is remapped to it.\n"
                                          (car
                                           commands-remapped-to))))))))))))))

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

(defun variable-at-event (event)
  "Return the variable whose name is around the position of EVENT.
EVENT should be a mouse event.  When calling from a popup or context menu,
use `last-popup-menu-event' to find out where the mouse was clicked.
\(You cannot use (interactive \"e\"), unfortunately.  This returns a
misc-user event.)

If the event contains no position, or the position is not over text, or
there is no variable around that point, nil is returned."
  (if (and event (event-buffer event) (event-point event))
      (save-excursion
	(set-buffer (event-buffer event))
	(goto-char (event-point event))
	(variable-at-point))))

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

(defun describe-variable-custom-version-info (variable)
  (let ((custom-version (get variable 'custom-version))
	(cpv (get variable 'custom-package-version))
	(output nil))
    (if custom-version
	(setq output
	      (format "This variable was introduced, or its default value was changed, in\nversion %s of XEmacs.\n"
		      custom-version))
      (when cpv
	(let* ((package (car-safe cpv))
	       (version (if (listp (cdr-safe cpv))
			    (car (cdr-safe cpv))
			  (cdr-safe cpv)))
	       (pkg-versions (assq package customize-package-emacs-version-alist))
	       (emacsv (cdr (assoc version pkg-versions))))
	  (if (and package version)
	      (setq output
		    (format (concat "This variable was introduced, or its default value was changed, in\nversion %s of the %s package"
				    (if emacsv
					(format " that is part of XEmacs %s" emacsv))
				    ".\n")
			    version package))))))
    output))

(defun describe-variable (variable)
  "Display the full documentation of VARIABLE (a symbol)."
  (interactive
   (let* ((v (variable-at-point))
          (val (let ((enable-recursive-minibuffers t))
                 (completing-read
                   (if v
                       (format "Describe variable (default %s): " v)
                       (gettext "Describe variable: "))
                   obarray 'boundp t nil 'variable-history
		   (symbol-name v)))))
     (list (intern val))))
  (with-displaying-help-buffer
   (lambda ()
     (let ((origvar variable)
	   aliases)
       (let ((print-escape-newlines t))
	 (princ "`")
	 ;; (Help-princ-face (symbol-name variable)
	 ;;               'font-lock-variable-name-face) overkill
	 (princ (symbol-name variable))
	 (princ "' is ")
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
	 (require 'hyper-apropos)
	 (let ((file-name (symbol-file variable 'defvar))
	       opoint e)
	   (when file-name
	       (princ "  -- loaded from \"")
	       (if (not (bufferp standard-output))
		   (princ file-name)
		 (setq opoint (point standard-output))
		 (princ file-name)
		 (setq e (make-extent opoint (point standard-output)
				      standard-output))
		 (set-extent-property e 'face 'hyper-apropos-hyperlink)
		 (set-extent-property e 'mouse-face 'highlight)
		 (set-extent-property e 'help-symbol variable)
		 (set-extent-property e 'activate-function  #'(lambda (ev ex) (help-symbol-run-function-1 ev ex 'find-variable))))
	       (princ"\"\n")))
	 (princ "\nValue: ")
    	 (if (not (boundp variable))
	     (Help-princ-face "void\n" 'hyper-apropos-documentation)
	   (Help-prin1-face (symbol-value variable)
			    'hyper-apropos-documentation)
	   (terpri))
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
			       (prin1 def)
			       (terpri))
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
	       (let ((oldp (point standard-output))
		     newp)
		 (princ doc)
		 (setq newp (point standard-output))
		 (goto-char oldp standard-output)
		 (frob-help-extents standard-output)
		 (goto-char newp standard-output))
	     (princ "not documented as a variable."))))
       ;; Make a link to customize if this variable can be customized.
       (when (custom-variable-p variable)
	 (let ((customize-label "customize"))
	   (terpri)
	   (terpri)
	   (princ (concat "You can " customize-label " this variable."))
	   (with-current-buffer standard-output
	     (save-excursion
	       (re-search-backward
		(concat "\\(" customize-label "\\)") nil t)
	       (let ((opoint (point standard-output))
		     e)
		 (require 'hyper-apropos)
		 ;; (princ variable)
		 (re-search-forward (concat "\\(" customize-label "\\)") nil t)
		 (setq e (make-extent opoint (point standard-output)
				      standard-output))
		 (set-extent-property e 'face 'hyper-apropos-hyperlink)
		 (set-extent-property e 'mouse-face 'highlight)
		 (set-extent-property e 'help-symbol variable)
		 (set-extent-property e 'activate-function  #'(lambda (ev ex) (help-symbol-run-function-1 ev ex 'customize-variable)))))))
	 ;; Note variable's version or package version
	 (let ((output (describe-variable-custom-version-info variable)))
	   (when output
	     (terpri)
	     (terpri)
	     (princ output))))
       (terpri)))
   (format "variable `%s'" variable)))

(defun sorted-key-descriptions (keys &optional separator)
  "Sort and separate the key descriptions for KEYS.
The sorting is done by length (shortest bindings first), and the bindings
are separated with SEPARATOR (\", \" by default)."
  (mapconcat 'key-description
             (sort* keys #'< :key #'length)
             (or separator ", ")))

(defun where-is (definition &optional insert)
  "Print message listing key sequences that invoke specified command.
Argument is a command definition, usually a symbol with a function definition.
When run interactively, it defaults to any function found by
`function-at-point'.
If INSERT (the prefix arg) is non-nil, insert the message in the buffer."
  (interactive
   (let ((fn (function-at-point))
	 (enable-recursive-minibuffers t)
	 val)
     (setq val (read-command
		(if fn (format "Where is command (default %s): " fn)
		  "Where is command: ")
                (and fn (symbol-name fn))))
     (list (if (equal (symbol-name val) "")
	       fn val)
	   current-prefix-arg)))
  (let ((keys (where-is-internal definition)))
    (if keys
	(if insert
	    (princ (format "%s (%s)" (sorted-key-descriptions keys)
			   definition) (current-buffer))
	  (message "%s is on %s" definition (sorted-key-descriptions keys)))
      (if insert
	  (princ (format (if (commandp definition) "M-x %s RET"
			   "M-: (%s ...)") definition) (current-buffer))
	(message "%s is not on any keys" definition))))
  nil)

;; `locate-library' moved to "packages.el"


;; Functions ported from C into Lisp in XEmacs

(defun describe-syntax ()
  "Describe the syntax specifications in the syntax table.
The descriptions are inserted in a buffer, which is then displayed."
  (interactive)
  (with-displaying-help-buffer
   (lambda ()
     ;; defined in syntax.el
     (describe-syntax-table (syntax-table) standard-output))
   (format "syntax-table for %s" major-mode)))

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

;; Stop gap for 21.0 until we do help-char etc properly.
(defun help-keymap-with-help-key (keymap form)
  "Return a copy of KEYMAP with an help-key binding according to help-char
 invoking FORM like help-form.  An existing binding is not overridden.
 If FORM is nil then no binding is made."
  (let ((map (copy-keymap keymap))
	(key (if (characterp help-char)
		 (vector (character-to-event help-char))
	       help-char)))
    (when (and form key (not (lookup-key map key)))
      (define-key map key
	`(lambda () (interactive) (help-print-help-form ,form))))
    map))

(defun help-print-help-form (form)
  (let ((string (eval form)))
    (if (stringp string)
	(with-displaying-help-buffer
	 (insert string)))))

(defun help-activate-function-or-scroll-up (&optional pos)
  "Follow any cross reference to source code; if none, scroll up.  "
  (interactive "d")
  (let ((e (extent-at pos nil 'activate-function)))
    (if e
	(funcall (extent-property e 'activate-function) nil e)
      (scroll-up 1))))

(define-minor-mode temp-buffer-resize-mode
  "Toggle the mode which makes windows smaller for temporary buffers.
With prefix argument ARG, turn the resizing of windows displaying temporary
buffers on if ARG is positive or off otherwise.
This makes the window the right height for its contents, but never
less than `window-min-height' nor a higher proportion of its frame than
`temp-buffer-max-height'. (Note the differing semantics of the latter
versus GNU Emacs, where `temp-buffer-max-height' is an integer number of
lines.)
This applies to `help', `apropos' and `completion' buffers, and some others."
    :global t :group 'help
    ;; XEmacs; our implementation of this is very different. 
    (setq temp-buffer-shrink-to-fit temp-buffer-resize-mode))

;; GNU name for this function. 
(defalias 'resize-temp-buffer-window 'shrink-window-if-larger-than-buffer)

;;; help.el ends here
