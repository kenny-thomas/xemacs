;;!emacs
;;
;; FILE:         br-start.el
;; SUMMARY:      Select language and invoke OO-Browser.
;; USAGE:        GNU Emacs Lisp Library
;; KEYWORDS:     oop, tools
;;
;; AUTHOR:       Bob Weiner
;; ORG:          InfoDock Associates
;;
;; ORIG-DATE:     5-Sep-92 at 23:31:03
;; LAST-MOD:      9-Apr-97 at 00:16:58 by Bob Weiner
;;
;; Copyright (C) 1992, 1993, 1994, 1997  Free Software Foundation, Inc.
;; See the file BR-COPY for license information.
;;
;; This file is part of the OO-Browser.
;;
;; DESCRIPTION:  
;; DESCRIP-END.

;;; ************************************************************************
;;; OO-Browser directory setting
;;; ************************************************************************

;; Defines (hyperb:path-being-loaded), which is used below.
;; A Hyperbole directory, such as oobr/hypb, must either already be in
;; load-path or an explicit load of "hversion" must have been
;; done already or else the following line will fail to load hversion.
;; This is all documented in the OO-Browser installation instructions.
(require 'hversion)

;; Reinitialize br-directory on reload if initialization failed for any reason.
(and (boundp 'br-directory) (null br-directory) (makunbound 'br-directory))

(defvar br-directory (hyperb:path-being-loaded)
  "Directory where the OO-Browser executable code is kept.
It must end with a directory separator character.")
(if (stringp br-directory)
    (setq br-directory (file-name-directory br-directory))
  (error
   "(br-start.el): OO-Browser failed to set br-directory.  Try setting it manually."))

(if (fboundp 'member)
    (fset 'br-member 'member)
  (defun br-member (elt list)
    "Return non-nil if ELT is an element of LIST.  Comparison done with `equal'.
The value is actually the tail of LIST whose car is ELT."
    (while (and list (not (equal (car list) elt)))
      (setq list (cdr list)))
    list))

;;; ************************************************************************
;;; Other required Elisp libraries
;;; ************************************************************************

;; Add br-directory to load-path so other OO-Browser libraries can be found.
(or (br-member br-directory load-path)
    (setq load-path (cons br-directory load-path)))

(load "br-vers")
(mapcar 'require '(br-init br-site))

;;; ************************************************************************
;;; Public functions
;;; ************************************************************************

;;; For backwards compatibility.
;;;###autoload
(fset 'oobr 'oo-browser)

;;;###autoload
(defun oo-browser (&optional same-env-flag)
  "Prompt for an Environment and language over which to run the OO-Browser.
Optional prefix argument SAME-ENV-FLAG means browse the current Environment,
if any, without prompting.  Otherwise, if called interactively, give the user
a choice whether to re-browse the last Environment or to browse a new one."
  (interactive
   (list (prog1
	     (if (and (not current-prefix-arg) br-env-file br-lang-prefix)
		 (y-or-n-p (format "(OO-Browser): Browse %s again? " br-env-file))
	       current-prefix-arg)
	   (message ""))))
  (if (and same-env-flag br-env-file br-lang-prefix)
      (funcall (intern-soft (concat br-lang-prefix "browse")))
    (call-interactively 'br-env-browse)))

(provide 'br-start)
