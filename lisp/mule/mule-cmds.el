;;; mule-cmds.el --- Commands for multilingual environment

;; Copyright (C) 1995 Free Software Foundation, Inc.
;; Copyright (C) 1995 Electrotechnical Laboratory, JAPAN.
;; Copyright (C) 1997 MORIOKA Tomohiko

;; Keywords: mule, multilingual

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
;; along with XEmacs; see the file COPYING.  If not, write to the Free
;; Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
;; 02111-1307, USA.

;;; Code:

;;; MULE related key bindings and menus.

(defvar mule-keymap (make-sparse-keymap "MULE")
  "Keymap for MULE (Multilingual environment) specific commands.")
(fset 'mule-prefix mule-keymap)

;; Keep "C-x C-m ..." for mule specific commands.
(define-key ctl-x-map "\C-m" 'mule-prefix)

;; (defvar mule-describe-language-support-map
;;   (make-sparse-keymap "Describe Language Support"))
;; (fset 'mule-describe-language-support-prefix
;;       mule-describe-language-support-map)

;; (defvar mule-set-language-environment-map
;;   (make-sparse-keymap "Set Language Environment"))
;; (fset 'mule-set-language-environment-prefix
;;       mule-set-language-environment-map)

(define-key mule-keymap "f" 'set-buffer-file-coding-system)
(define-key mule-keymap "F" 'set-default-buffer-file-coding-system) ; XEmacs
(define-key mule-keymap "t" 'set-terminal-coding-system)
(define-key mule-keymap "k" 'set-keyboard-coding-system)
(define-key mule-keymap "p" 'set-current-process-coding-system)
(define-key mule-keymap "P" 'set-default-process-coding-system) ; XEmacs
(define-key mule-keymap "i" 'select-input-method)
(define-key mule-keymap "c" 'list-coding-system-briefly) ; XEmacs
(define-key mule-keymap "C" 'list-coding-system)	 ; XEmacs
(define-key mule-keymap "r" 'toggle-display-direction)	 ; XEmacs

(define-key help-map "\C-L" 'describe-language-support)
(define-key help-map "\C-\\" 'describe-input-method)
(define-key help-map "C" 'describe-current-coding-system)
(define-key help-map "h" 'view-hello-file)

;; Menu for XEmacs were moved to x11/x-menubar.el.


;; This should be a single character key binding because users use it
;; very frequently while editing multilingual text.  Now we can use
;; only two such keys: "\C-\\" and "\C-^", but the latter is not
;; convenient because it requires shifting on most keyboards.  An
;; alternative is "\C-\]" which is now bound to `abort-recursive-edit'
;; but it won't be used that frequently.
(define-key global-map "\C-\\" 'toggle-input-method)

(defun view-hello-file ()
  "Display the HELLO file which list up many languages and characters."
  (interactive)
  ;; We have to decode the file in any environment.
  (let ((coding-system-for-read 'iso-2022-7))
    (find-file-read-only (expand-file-name "HELLO" data-directory))))


;;; Language support staffs.

(defvar primary-language "English"
  "Name of a user's primary language.
Emacs provide various language supports based on this variable.")

(defvar language-info-alist nil
  "Alist of language names vs the corresponding information of various kind.
Each element looks like:
	(LANGUAGE-NAME . ((KEY . INFO) ...))
where LANGUAGE-NAME is a string,
KEY is a symbol denoting the kind of information,
INFO is any Lisp object which contains the actual information related
to KEY.")

(defun get-language-info (language-name key)
  "Return the information for LANGUAGE-NAME of the kind KEY.
LANGUAGE-NAME is a string.
KEY is a symbol denoting the kind of required information."
  (let ((lang-slot (assoc language-name language-info-alist)))
    (if lang-slot
	(cdr (assq key (cdr lang-slot))))))

(defun set-language-info (language-name key info)
  "Set for LANGUAGE-NAME the information INFO under KEY.
LANGUAGE-NAME is a string
KEY is a symbol denoting the kind of information.
INFO is any Lisp object which contains the actual information.

Currently, the following KEYs are used by Emacs:
charset: list of symbols whose values are charsets specific to the language.
coding-system: list of coding systems specific to the langauge.
tutorial: a tutorial file name written in the language.
sample-text: one line short text containing characters of the language.
input-method: alist of input method names for the language vs information
  for activating them.  Use `register-input-method' (which see)
  to add a new input method to the alist.
documentation: a string describing how Emacs supports the langauge.
describe-function: a function to call for descriebing how Emacs supports
 the language.  The function uses information listed abobe.
setup-function: a function to call for setting up environment
 convenient for the language.

Emacs will use more KEYs in the future.  To avoid conflict, users
should use prefix \"user-\" in the name of KEY if he wants to set
different kind of information."
  (let (lang-slot key-slot)
    (setq lang-slot (assoc language-name language-info-alist))
    (if (null lang-slot)		; If no slot for the language, add it.
	(setq lang-slot (list language-name)
	      language-info-alist (cons lang-slot language-info-alist)))
    (setq key-slot (assq key lang-slot))
    (if (null key-slot)			; If no slot for the key, add it.
	(progn
	  (setq key-slot (list key))
	  (setcdr lang-slot (cons key-slot (cdr lang-slot)))))
    (setcdr key-slot info)
    ;; Setup menu.
    (cond ((eq key 'describe-function)
           ;; (define-key-after mule-describe-language-support-map
           ;;   (vector (intern language-name))
           ;;   (cons language-name info)
           ;;   t)
	   (eval-after-load "x-menubar"
	     `(add-menu-button '("Mule" "Describe Language Support")
			       (vector ,language-name ',info t)))
	   )
	  ((eq key 'setup-function)
	   ;; (define-key-after mule-set-language-environment-map
           ;;   (vector (intern language-name))
           ;;   (cons language-name info)
           ;;   t)
	   (eval-after-load "x-menubar"
	     `(add-menu-button '("Mule" "Set Language Environment")
			       (vector ,language-name ',info t)))
           ))
    ))

(defun set-language-info-alist (language-name alist)
  "Set for LANGUAGE-NAME the information in ALIST.
ALIST is an alist of KEY and INFO.  See the documentation of
`set-langauge-info' for the meanings of KEY and INFO."
  (while alist
    (set-language-info language-name (car (car alist)) (cdr (car alist)))
    (setq alist (cdr alist))))

(defun read-language-name (key prompt &optional initial-input)
  "Read language name which has information for KEY, prompting with PROMPT."
  (let* ((completion-ignore-case t)
	 (name (completing-read prompt
				language-info-alist
				(function (lambda (elm) (assq key elm)))
				t
				initial-input)))
    (and (> (length name) 0)
	 (car (assoc-ignore-case (downcase name) language-info-alist)))))

;;; Multilingual input methods.

(defvar current-input-method nil
  "The current input method for multilingual text.
The value is a cons of language name and input method name.
If nil, it means no input method is activated now.")
(make-variable-buffer-local 'current-input-method)
(put 'current-input-method 'permanent-local t)

(defvar current-input-method-title nil
  "Title string of the current input method shown in mode line.
Every input method should set this to an appropriate value when activated.")
(make-variable-buffer-local 'current-input-method-title)
(put 'current-input-method-title 'permanent-local t)

(defvar default-input-method nil
  "Default input method.
The default input method is the one activated automatically by the command
`toggle-input-method' (\\[toggle-input-method]).
The value is a cons of language name and input method name.")

(defvar default-input-method-title nil
  "Title string of the default input method.")

(defvar previous-input-method nil
  "Input method selected previously.
This is the one selected before the current input method is selected.
See also the documentation of `default-input-method'.")

(defvar inactivate-current-input-method-function nil
  "Function to call for inactivating the current input method.
Every input method should set this to an appropriate value when activated.
This function is called with no argument.")
(make-variable-buffer-local 'inactivate-current-input-method-function)
(put 'inactivate-current-input-method-function 'permanent-local t)

(defvar describe-current-input-method-function nil
  "Function to call for describing the current input method.
This function is called with no argument.")
(make-variable-buffer-local 'describe-current-input-method-function)
(put 'describe-current-input-method-function 'permanent-local t)

(defun register-input-method (language-name input-method)
  "Register INPUT-METHOD as an input method of LANGUAGE-NAME.
LANGUAGE-NAME is a string.
INPUT-METHOD is a list of the form:
	(METHOD-NAME ACTIVATE-FUNC ARG ...)
where METHOD-NAME is the name of this method,
ACTIVATE-FUNC is the function to call for activating this method.
Arguments for the function are METHOD-NAME and ARGs."
  (let ((slot (get-language-info language-name 'input-method))
	method-slot)
    (if (null slot)
	(set-language-info language-name 'input-method (list input-method))
      (setq method-slot (assoc (car input-method) slot))
      (if method-slot
	  (setcdr method-slot (cdr input-method))
	(set-language-info language-name 'input-method
			   (cons input-method slot))))))

(defun read-language-and-input-method-name ()
  "Read a language names and the corresponding input method from a minibuffer.
Return a cons of those names."
  (let ((language-name (read-language-name
			'input-method
			"Language: "
			(if previous-input-method
			    (cons (car previous-input-method) 0)))))
    (if (null language-name)
	(error "No input method for the specified language"))
    (let* ((completion-ignore-case t)
	   (key-slot (cdr (assq 'input-method
				(assoc language-name language-info-alist))))
	   (method-name
	    (completing-read "Input method: " key-slot nil t
			     (if (and previous-input-method
				      (string= language-name
					       (car previous-input-method)))
				 (cons (cdr previous-input-method) 0)))))
      (if (= (length method-name) 0)
	  (error "No input method specified"))
      (list language-name
	    (car (assoc-ignore-case (downcase method-name) key-slot))))))

(defun set-default-input-method (language-name method-name)
  "Set the default input method to METHOD-NAME for inputting LANGUAGE-NAME.
The default input method is the one activated automatically by the command
`toggle-input-method' (\\[toggle-input-method]).
This doesn't affect the currently activated input method."
  (interactive (read-language-and-input-method-name))
  (let* ((key-slot (get-language-info language-name 'input-method))
	 (method-slot (assoc method-name key-slot)))
    (if (null method-slot)
	(error "No input method `%s' for %s" method-name language-name))
    (setq default-input-method (cons language-name method-name))))

(defun select-input-method (language-name method-name)
  "Select and activate input method METHOD-NAME for inputting LANGUAGE-NAME.
The information for activating METHOD-NAME is stored
in `language-info-alist' under the key 'input-method.
The format of the information has the form:
	((METHOD-NAME ACTIVATE-FUNC ARG ...) ...)
where ACTIVATE-FUNC is a function to call for activating this method.
Arguments for the function are METHOD-NAME and ARGs."
  (interactive (read-language-and-input-method-name))
  (let* ((key-slot (get-language-info language-name 'input-method))
	 (method-slot (assoc method-name key-slot)))
    (if (null method-slot)
	(error "No input method `%s' for %s" method-name language-name))
    (if current-input-method
	(progn
	  (if (not (equal previous-input-method current-input-method))
	      (setq previous-input-method current-input-method))
	  (funcall inactivate-current-input-method-function)))
    (setq method-slot (cdr method-slot))
    (apply (car method-slot) method-name (cdr method-slot))
    (setq default-input-method
	  (setq current-input-method (cons language-name method-name)))
    (setq default-input-method-title current-input-method-title)
    (setq current-input-method default-input-method)))

(defun toggle-input-method (&optional arg)
  "Toggle whether a multilingual input method is activated in this buffer.
With arg, activate an input method specified interactively.
Without arg, the method being activated is the one selected most recently,
 but if no input method has ever been selected, select one interactively."
  (interactive "P")
  (if arg
      (call-interactively 'select-input-method)
    (if (null current-input-method)
	(if default-input-method
	    (select-input-method (car default-input-method)
				 (cdr default-input-method))
	  (call-interactively 'select-input-method))
      (funcall inactivate-current-input-method-function)
      (setq current-input-method nil))))

(defun describe-input-method ()
  "Describe the current input method."
  (interactive)
  (if current-input-method
      (if (and (symbolp describe-current-input-method-function)
	       (fboundp describe-current-input-method-function))
	  (funcall describe-current-input-method-function)
	(message "No way to describe the current input method `%s'"
		 (cdr current-input-method))
	(ding))
    (message "No input method is activated now")
    (ding)))

(defun read-multilingual-string (prompt &optional initial-input
					language-name method-name)
  "Read a multilingual string from minibuffer, prompting with string PROMPT.
The input method selected last time is activated in minibuffer.
If non-nil, second arg INITIAL-INPUT is a string to insert before reading.
Optional 3rd and 4th arguments LANGUAGE-NAME and METHOD-NAME specify
 the input method to be activated instead of the one selected last time."
  (let ((minibuffer-setup-hook '(toggle-input-method))
	(default-input-method default-input-method))
    (if (and language-name method-name)
	(set-default-input-method language-name method-name))
    (read-string prompt initial-input)))

;; Variables to control behavior of input methods.  All input methods
;; should react to these variables.

(defvar input-method-tersely-flag nil
  "*If this flag is non-nil, input method works rather tersely.

For instance, Quail input method does not show guidance buffer while
inputting at minibuffer if this flag is t.")

(defvar input-method-activate-hook nil
  "Normal hook run just after an input method is activated.")

(defvar input-method-inactivate-hook nil
  "Normal hook run just after an input method is inactivated.")

(defvar input-method-after-insert-chunk-hook nil
  "Normal hook run just after an input method insert some chunk of text.")


;;; Language specific setup functions.
;; (defun set-language-environment (language-name)
;;   "Setup a user's environment for LANGUAGE-NAME.
;; 
;; To setup, a fucntion returned by:
;;   (get-language-info LANGUAGE-NAME 'setup-function)
;; is called."
;;   (interactive (list (read-language-name 'setup-function "Language: ")))
;;   (let (func)
;;     (if (or (null language-name)
;;             (null (setq func
;;                         (get-language-info language-name 'setup-function))))
;;         (error "No way to setup environment for the specified language"))
;;     (funcall func)))

;; Print all arguments with `princ', then print "\n".
(defsubst princ-list (&rest args)
  (while args (princ (car args)) (setq args (cdr args)))
  (princ "\n"))

(defun describe-language-support (language-name)
  "Describe how Emacs supports LANGUAGE-NAME.

For that, a function returned by:
  (get-language-info LANGUAGE-NAME 'describe-function)
is called."
  (interactive (list (read-language-name 'documentation "Language: ")))
  (let (func)
    (if (or (null language-name)
	    (null (setq func
			(get-language-info language-name 'describe-function))))
	(error "No documentation for the specified language"))
    (funcall func)))

;; Print LANGUAGE-NAME specific information such as input methods,
;; charsets, and coding systems.  This function is intended to be
;; called from various describe-LANGUAGE-support functions defined in
;; lisp/language/LANGUAGE.el.
(defun describe-language-support-internal (language-name)
  (with-output-to-temp-buffer "*Help*"
    (let ((doc (get-language-info language-name 'documentation)))
      (if (stringp doc)
	  (princ-list doc)))
    (princ "-----------------------------------------------------------\n")
    (princ-list "List of items specific to "
		language-name
		" support")
    (princ "-----------------------------------------------------------\n")
    (let ((str (get-language-info language-name 'sample-text)))
      (if (stringp str)
	  (progn
	    (princ "<sample text>\n")
	    (princ-list "  " str))))
    (princ "<input methods>\n")
    (let ((l (get-language-info language-name 'input-method)))
      (while l
	(princ-list "  " (car (car l)))
	(setq l (cdr l))))
    (princ "<character sets>\n")
    (let ((l (get-language-info language-name 'charset)))
      (if (null l)
	  (princ-list "  nothing specific to " language-name)
	(while l
	  (princ-list "  " (car l) ": "
		      (charset-description (car l)))
	  (setq l (cdr l)))))
    (princ "<coding systems>\n")
    (let ((l (get-language-info language-name 'coding-system)))
      (if (null l)
	  (princ-list "  nothing specific to " language-name)
	(while l
	  (princ-list "  " (car l) ":\n\t"
		      (coding-system-docstring (car l)))
	  (setq l (cdr l)))))))

;;; Charset property

;; (defsubst get-charset-property (charset propname)
;;   "Return the value of CHARSET's PROPNAME property.
;; This is the last value stored with
;; `(put-charset-property CHARSET PROPNAME VALUE)'."
;;   (plist-get (charset-plist charset) propname))

;; (defsubst put-charset-property (charset propname value)
;;   "Store CHARSETS's PROPNAME property with value VALUE.
;; It can be retrieved with `(get-charset-property CHARSET PROPNAME)'."
;;   (set-charset-plist charset
;;                      (plist-put (charset-plist charset) propname value)))

;;; Character code property
;; (put 'char-code-property-table 'char-table-extra-slots 0)

;; (defvar char-code-property-table
;;   (make-char-table 'char-code-property-table)
;;   "Char-table containing a property list of each character code.
;; 
;; See also the documentation of `get-char-code-property' and
;; `put-char-code-property'")

;; (defun get-char-code-property (char propname)
;;   "Return the value of CHAR's PROPNAME property in `char-code-property-table'."
;;   (let ((plist (aref char-code-property-table char)))
;;     (if (listp plist)
;;         (car (cdr (memq propname plist))))))

;; (defun put-char-code-property (char propname value)
;;   "Store CHAR's PROPNAME property with VALUE in `char-code-property-table'.
;; It can be retrieved with `(get-char-code-property CHAR PROPNAME)'."
;;   (let ((plist (aref char-code-property-table char)))
;;     (if plist
;;         (let ((slot (memq propname plist)))
;;           (if slot
;;               (setcar (cdr slot) value)
;;             (nconc plist (list propname value))))
;;       (aset char-code-property-table char (list propname value)))))

;;; mule-cmds.el ends here
