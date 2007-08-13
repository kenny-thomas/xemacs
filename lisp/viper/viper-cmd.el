;;; viper-cmd.el --- Vi command support for Viper
;; Copyright (C) 1997 Free Software Foundation, Inc.


;; Code

(provide 'viper-cmd)
(require 'advice)

;; Compiler pacifier
(defvar vip-minibuffer-current-face)
(defvar vip-minibuffer-insert-face)
(defvar vip-minibuffer-vi-face)
(defvar vip-minibuffer-emacs-face)
(defvar viper-always)
(defvar vip-mode-string)
(defvar vip-custom-file-name)
(defvar iso-accents-mode)
(defvar zmacs-region-stays)
(defvar mark-even-if-inactive)

;; loading happens only in non-interactive compilation
;; in order to spare non-viperized emacs from being viperized
(if noninteractive
    (eval-when-compile
      (let ((load-path (cons (expand-file-name ".") load-path)))
	(or (featurep 'viper-util)
	    (load "viper-util.el" nil nil 'nosuffix))
	(or (featurep 'viper-keym)
	    (load "viper-keym.el" nil nil 'nosuffix))
	(or (featurep 'viper-mous)
	    (load "viper-mous.el" nil nil 'nosuffix))
	(or (featurep 'viper-macs)
	    (load "viper-macs.el" nil nil 'nosuffix))
	(or (featurep 'viper-ex)
	    (load "viper-ex.el" nil nil 'nosuffix))
	)))
;; end pacifier


(require 'viper-util)
(require 'viper-keym)
(require 'viper-mous)
(require 'viper-macs)
(require 'viper-ex)



;; Generic predicates

;; These test functions are shamelessly lifted from vip 4.4.2 by Aamod Sane

;; generate test functions
;; given symbol foo, foo-p is the test function, foos is the set of
;; Viper command keys
;; (macroexpand '(vip-test-com-defun foo))
;; (defun foo-p (com) (consp (memq (if (< com 0) (- com) com) foos)))

(defmacro vip-test-com-defun (name)
  (let* ((snm (symbol-name name))
	 (nm-p (intern (concat snm "-p")))
	 (nms (intern (concat snm "s"))))
    (` (defun (, nm-p) (com) 
	 (consp (memq (if (< com 0) (- com) com) (, nms)))))))
  
;; Variables for defining VI commands

;; Modifying commands that can be prefixes to movement commands
(defconst vip-prefix-commands '(?c ?d ?y ?! ?= ?# ?< ?> ?\"))
;; define vip-prefix-command-p
(vip-test-com-defun vip-prefix-command)
  
;; Commands that are pairs eg. dd. r and R here are a hack
(defconst vip-charpair-commands '(?c ?d ?y ?! ?= ?< ?> ?r ?R))
;; define vip-charpair-command-p
(vip-test-com-defun vip-charpair-command)

(defconst vip-movement-commands '(?b ?B ?e ?E ?f ?F ?G ?h ?H ?j ?k ?l
				     ?H ?M ?L ?n ?t ?T ?w ?W ?$ ?%
				     ?^ ?( ?) ?- ?+ ?| ?{ ?} ?[ ?] ?' ?`
				     ?; ?, ?0 ?? ?/ ?\C-m ?\ 
				     )
				     "Movement commands")
;; define vip-movement-command-p
(vip-test-com-defun vip-movement-command)

;; Vi digit commands
(defconst vip-digit-commands '(?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9))

;; define vip-digit-command-p
(vip-test-com-defun vip-digit-command)

;; Commands that can be repeated by . (dotted)
(defconst vip-dotable-commands '(?c ?d ?C ?s ?S ?D ?> ?<))
;; define vip-dotable-command-p
(vip-test-com-defun vip-dotable-command)

;; Commands that can follow a #
(defconst vip-hash-commands '(?c ?C ?g ?q ?s))
;; define vip-hash-command-p
(vip-test-com-defun vip-hash-command)

;; Commands that may have registers as prefix
(defconst vip-regsuffix-commands '(?d ?y ?Y ?D ?p ?P ?x ?X))
;; define vip-regsuffix-command-p
(vip-test-com-defun vip-regsuffix-command)

(defconst vip-vi-commands (append vip-movement-commands
				  vip-digit-commands
				  vip-dotable-commands
				  vip-charpair-commands
				  vip-hash-commands
				  vip-prefix-commands
				  vip-regsuffix-commands)
  "The list of all commands in Vi-state.")
;; define vip-vi-command-p
(vip-test-com-defun vip-vi-command)


;;; CODE

;; sentinels

;; Runs vip-after-change-functions inside after-change-functions
(defun vip-after-change-sentinel (beg end len)
  (let ((list vip-after-change-functions))
    (while list
      (funcall (car list) beg end len)
      (setq list (cdr list)))))
      
;; Runs vip-before-change-functions inside before-change-functions
(defun vip-before-change-sentinel (beg end)
  (let ((list vip-before-change-functions))
    (while list
      (funcall (car list) beg end)
      (setq list (cdr list)))))

(defsubst vip-post-command-sentinel ()
  (run-hooks 'vip-post-command-hooks))
  
(defsubst vip-pre-command-sentinel ()
  (run-hooks 'vip-pre-command-hooks))
  
;; Needed so that Viper will be able to figure the last inserted
;; chunk of text with reasonable accuracy.
(defsubst vip-insert-state-post-command-sentinel ()
  (if (and (memq vip-current-state '(insert-state replace-state))
	   vip-insert-point
	   (>= (point) vip-insert-point))
      (setq vip-last-posn-while-in-insert-state (point-marker)))
  (if (eq vip-current-state 'insert-state)
      (progn
	(or (stringp vip-saved-cursor-color)
	    (string= (vip-get-cursor-color) vip-insert-state-cursor-color)
	    (setq vip-saved-cursor-color (vip-get-cursor-color)))
	(if (stringp vip-saved-cursor-color)
	    (vip-change-cursor-color vip-insert-state-cursor-color))
	))
  (if (and (eq this-command 'dabbrev-expand)
	   (integerp vip-pre-command-point)
	   (> vip-insert-point vip-pre-command-point))
      (move-marker vip-insert-point vip-pre-command-point))
  )
  
(defsubst vip-insert-state-pre-command-sentinel ()
  (or (memq this-command '(self-insert-command))
      (memq (vip-event-key last-command-event)
	    '(up down left right (meta f) (meta b)
		 (control n) (control p) (control f) (control b)))
      (vip-restore-cursor-color-after-insert))
  (if (and (eq this-command 'dabbrev-expand)
	   (markerp vip-insert-point)
	   (marker-position vip-insert-point))
      (setq vip-pre-command-point (marker-position vip-insert-point))))
	
(defsubst vip-R-state-post-command-sentinel ()
  ;; Restoring cursor color is needed despite
  ;; vip-replace-state-pre-command-sentinel: When you jump to another buffer in
  ;; another frame, the pre-command hook won't change cursor color to default
  ;; in that other frame.  So, if the second frame cursor was red and we set
  ;; the point outside the replacement region, then the cursor color will
  ;; remain red. Restoring the default, below, prevents this.
  (if (and (<= (vip-replace-start) (point))
	   (<=  (point) (vip-replace-end)))
      (vip-change-cursor-color vip-replace-overlay-cursor-color)
    (vip-restore-cursor-color-after-replace)
    ))

;; to speed up, don't change cursor color before self-insert
;; and common move commands
(defsubst vip-replace-state-pre-command-sentinel ()
  (or (memq this-command '(self-insert-command))
      (memq (vip-event-key last-command-event)
	    '(up down left right (meta f) (meta b)
		 (control n) (control p) (control f) (control b)))
      (vip-restore-cursor-color-after-replace)))
  
(defun vip-replace-state-post-command-sentinel ()
  ;; Restoring cursor color is needed despite
  ;; vip-replace-state-pre-command-sentinel: When one jumps to another buffer
  ;; in another frame, the pre-command hook won't change cursor color to
  ;; default in that other frame.  So, if the second frame cursor was red and
  ;; we set the point outside the replacement region, then the cursor color
  ;; will remain red. Restoring the default, below, fixes this problem.
  ;;
  ;; We optimize for self-insert-command's here, since they either don't change
  ;; cursor color or, if they terminate replace mode, the color will be changed
  ;; in vip-finish-change
  (or (memq this-command '(self-insert-command))
      (vip-restore-cursor-color-after-replace))
  (cond 
   ((eq vip-current-state 'replace-state)
    ;; delete characters to compensate for inserted chars.
    (let ((replace-boundary (vip-replace-end)))
      (save-excursion
	(goto-char vip-last-posn-in-replace-region)
	(delete-char vip-replace-chars-to-delete)
	(setq vip-replace-chars-to-delete 0
	      vip-replace-chars-deleted 0)
	;; terminate replace mode if reached replace limit
	(if (= vip-last-posn-in-replace-region 
	       (vip-replace-end))
	    (vip-finish-change vip-last-posn-in-replace-region)))
      
      (if (and (<= (vip-replace-start) (point))
	       (<=  (point) replace-boundary))
	  (progn
	    ;; the state may have changed in vip-finish-change above
	    (if (eq vip-current-state 'replace-state)
		(vip-change-cursor-color vip-replace-overlay-cursor-color))
	    (setq vip-last-posn-in-replace-region (point-marker))))
      ))
   
   (t ;; terminate replace mode if changed Viper states.
    (vip-finish-change vip-last-posn-in-replace-region))))


;; changing mode

;; Change state to NEW-STATE---either emacs-state, vi-state, or insert-state.
(defun vip-change-state (new-state)
  ;; Keep vip-post/pre-command-hooks fresh.
  ;; We remove then add vip-post/pre-command-sentinel since it is very
  ;; desirable that vip-pre-command-sentinel is the last hook and
  ;; vip-post-command-sentinel is the first hook.
  (remove-hook 'post-command-hook 'vip-post-command-sentinel)
  (add-hook 'post-command-hook 'vip-post-command-sentinel)
  (remove-hook 'pre-command-hook 'vip-pre-command-sentinel)
  (add-hook 'pre-command-hook 'vip-pre-command-sentinel t)
  ;; These hooks will be added back if switching to insert/replace mode
  (vip-remove-hook 'vip-post-command-hooks
		   'vip-insert-state-post-command-sentinel)
  (vip-remove-hook 'vip-pre-command-hooks
		   'vip-insert-state-pre-command-sentinel)
  (cond ((eq new-state 'vi-state)
	 (cond ((member vip-current-state '(insert-state replace-state))
		    
		;; move vip-last-posn-while-in-insert-state
		;; This is a normal hook that is executed in insert/replace
		;; states after each command. In Vi/Emacs state, it does
		;; nothing. We need to execute it here to make sure that
		;; the last posn was recorded when we hit ESC.
		;; It may be left unrecorded if the last thing done in
		;; insert/repl state was dabbrev-expansion or abbrev
		;; expansion caused by hitting ESC
		(vip-insert-state-post-command-sentinel)
		
		(condition-case conds
		    (progn
		      (vip-save-last-insertion
		       vip-insert-point 
		       vip-last-posn-while-in-insert-state)
		      (if vip-began-as-replace
			  (setq vip-began-as-replace nil)
			;; repeat insert commands if numerical arg > 1
			(save-excursion
			  (vip-repeat-insert-command))))
		  (error
		   (vip-message-conditions conds)))
		     
		(if (> (length vip-last-insertion) 0)
		    (vip-push-onto-ring vip-last-insertion
					'vip-insertion-ring))
		
		(if vip-ex-style-editing-in-insert
		    (or (bolp) (backward-char 1))))
	       ))
	 
	;; insert or replace
	((memq new-state '(insert-state replace-state))
	 (if (memq vip-current-state '(emacs-state vi-state))
	     (vip-move-marker-locally 'vip-insert-point (point)))
	 (vip-move-marker-locally 'vip-last-posn-while-in-insert-state (point))
	 (vip-add-hook 'vip-post-command-hooks
		       'vip-insert-state-post-command-sentinel t)
	 (vip-add-hook 'vip-pre-command-hooks
		       'vip-insert-state-pre-command-sentinel t))
	) ; outermost cond
  
  ;; Nothing needs to be done to switch to emacs mode! Just set some
  ;; variables, which is already done in vip-change-state-to-emacs!

  (setq vip-current-state new-state)
  (vip-normalize-minor-mode-map-alist)
  (vip-adjust-keys-for new-state)
  (vip-set-mode-vars-for new-state)
  (vip-refresh-mode-line)
  )


    
(defun vip-adjust-keys-for (state)
  "Make necessary adjustments to keymaps before entering STATE."
  (cond ((memq state '(insert-state replace-state))
	 (if vip-auto-indent
	     (progn
	       (define-key vip-insert-basic-map "\C-m" 'vip-autoindent)
	       (if vip-want-emacs-keys-in-insert
		   ;; expert
		   (define-key vip-insert-basic-map "\C-j" nil)
		 ;; novice
		 (define-key vip-insert-basic-map "\C-j" 'vip-autoindent)))
	   (define-key vip-insert-basic-map "\C-m" nil)
	   (define-key vip-insert-basic-map "\C-j" nil))
		    
	 (setq vip-insert-diehard-minor-mode
	       (not vip-want-emacs-keys-in-insert))
		   
	 (if vip-want-ctl-h-help
	     (progn 
	       (define-key vip-insert-basic-map [(control h)] 'help-command)
	       (define-key vip-replace-map [(control h)] 'help-command))
	   (define-key vip-insert-basic-map 
	     [(control h)] 'vip-del-backward-char-in-insert)
	   (define-key vip-replace-map
	     [(control h)] 'vip-del-backward-char-in-replace)))
		     
	(t ; Vi state
	 (setq vip-vi-diehard-minor-mode (not vip-want-emacs-keys-in-vi))
	 (if vip-want-ctl-h-help
	     (define-key vip-vi-basic-map [(control h)] 'help-command)
	   (define-key vip-vi-basic-map [(control h)] 'vip-backward-char)))
	))
	     
    
;; Normalizes minor-mode-map-alist by putting Viper keymaps first.
;; This ensures that Viper bindings are in effect, regardless of which minor
;; modes were turned on by the user or by other packages.
(defun vip-normalize-minor-mode-map-alist ()
  (setq minor-mode-map-alist 
	(vip-append-filter-alist
	 (list
	       (cons 'vip-vi-intercept-minor-mode vip-vi-intercept-map)
	       (cons 'vip-vi-minibuffer-minor-mode vip-minibuffer-map) 
	       (cons 'vip-vi-local-user-minor-mode vip-vi-local-user-map)
	       (cons 'vip-vi-kbd-minor-mode vip-vi-kbd-map)
	       (cons 'vip-vi-global-user-minor-mode vip-vi-global-user-map)
	       (cons 'vip-vi-state-modifier-minor-mode
		     (if (keymapp
			  (cdr (assoc major-mode vip-vi-state-modifier-alist)))
			 (cdr (assoc major-mode vip-vi-state-modifier-alist))
		       vip-empty-keymap))
	       (cons 'vip-vi-diehard-minor-mode  vip-vi-diehard-map)
	       (cons 'vip-vi-basic-minor-mode     vip-vi-basic-map)
	       (cons 'vip-insert-intercept-minor-mode vip-insert-intercept-map)
	       (cons 'vip-replace-minor-mode  vip-replace-map)
	       ;; vip-insert-minibuffer-minor-mode must come after
	       ;; vip-replace-minor-mode 
	       (cons 'vip-insert-minibuffer-minor-mode
		     vip-minibuffer-map) 
	       (cons 'vip-insert-local-user-minor-mode
		     vip-insert-local-user-map)
	       (cons 'vip-insert-kbd-minor-mode vip-insert-kbd-map)
	       (cons 'vip-insert-global-user-minor-mode
		     vip-insert-global-user-map)
	       (cons 'vip-insert-state-modifier-minor-mode
		     (if (keymapp
			  (cdr
			   (assoc major-mode vip-insert-state-modifier-alist)))
			 (cdr
			  (assoc major-mode vip-insert-state-modifier-alist))
		       vip-empty-keymap))
	       (cons 'vip-insert-diehard-minor-mode vip-insert-diehard-map)
	       (cons 'vip-insert-basic-minor-mode vip-insert-basic-map)
	       (cons 'vip-emacs-intercept-minor-mode
		     vip-emacs-intercept-map)
	       (cons 'vip-emacs-local-user-minor-mode
		     vip-emacs-local-user-map)
	       (cons 'vip-emacs-kbd-minor-mode vip-emacs-kbd-map)
	       (cons 'vip-emacs-global-user-minor-mode
		     vip-emacs-global-user-map)
	       (cons 'vip-emacs-state-modifier-minor-mode
		     (if (keymapp
			  (cdr
			   (assoc major-mode vip-emacs-state-modifier-alist)))
			 (cdr
			  (assoc major-mode vip-emacs-state-modifier-alist))
		       vip-empty-keymap))
	       )
	 minor-mode-map-alist)))
	 
 



;; Viper mode-changing commands and utilities

;; Modifies mode-line-buffer-identification.
(defun vip-refresh-mode-line ()
  (setq vip-mode-string	
	(cond ((eq vip-current-state 'emacs-state) vip-emacs-state-id)
	      ((eq vip-current-state 'vi-state) vip-vi-state-id)
	      ((eq vip-current-state 'replace-state) vip-replace-state-id)
	      ((eq vip-current-state 'insert-state) vip-insert-state-id)))
    
  ;; Sets Viper mode string in global-mode-string
  (force-mode-line-update))
	

;; Switch from Insert state to Vi state.
(defun vip-exit-insert-state ()
  (interactive)
  (vip-change-state-to-vi))

(defun vip-set-mode-vars-for (state)
  "Sets Viper minor mode variables to put Viper's state STATE in effect."
  
  ;; Emacs state
  (setq vip-vi-minibuffer-minor-mode	   nil
        vip-insert-minibuffer-minor-mode   nil
	vip-vi-intercept-minor-mode	   nil
	vip-insert-intercept-minor-mode	   nil
	
	vip-vi-local-user-minor-mode       nil
	vip-vi-kbd-minor-mode        	   nil
	vip-vi-global-user-minor-mode      nil
	vip-vi-state-modifier-minor-mode   nil
	vip-vi-diehard-minor-mode     	   nil
        vip-vi-basic-minor-mode       	   nil
	
	vip-replace-minor-mode 	      	   nil
	
	vip-insert-local-user-minor-mode     nil
	vip-insert-kbd-minor-mode     	     nil
	vip-insert-global-user-minor-mode    nil
	vip-insert-state-modifier-minor-mode nil
	vip-insert-diehard-minor-mode 	     nil
	vip-insert-basic-minor-mode   	     nil
	vip-emacs-intercept-minor-mode       t
	vip-emacs-local-user-minor-mode      t
	vip-emacs-kbd-minor-mode             (not (vip-is-in-minibuffer))
	vip-emacs-global-user-minor-mode     t
	vip-emacs-state-modifier-minor-mode  t
	)
  
  ;; Vi state
  (if (eq state 'vi-state) ; adjust for vi-state
      (setq 
       vip-vi-intercept-minor-mode	   t 
       vip-vi-minibuffer-minor-mode	   (vip-is-in-minibuffer)
       vip-vi-local-user-minor-mode	   t
       vip-vi-kbd-minor-mode        	   (not (vip-is-in-minibuffer))
       vip-vi-global-user-minor-mode	   t
       vip-vi-state-modifier-minor-mode    t
       ;; don't let the diehard keymap block command completion 
       ;; and other things in the minibuffer
       vip-vi-diehard-minor-mode    	   (not
					    (or vip-want-emacs-keys-in-vi
						(vip-is-in-minibuffer)))
       vip-vi-basic-minor-mode      	    t 
       vip-emacs-intercept-minor-mode       nil
       vip-emacs-local-user-minor-mode      nil
       vip-emacs-kbd-minor-mode     	    nil
       vip-emacs-global-user-minor-mode     nil
       vip-emacs-state-modifier-minor-mode  nil
       ))
  
  ;; Insert and Replace states
  (if (member state '(insert-state replace-state))
      (setq 
       vip-insert-intercept-minor-mode	    t 
       vip-replace-minor-mode	     	    (eq state 'replace-state)
       vip-insert-minibuffer-minor-mode	    (vip-is-in-minibuffer)
       vip-insert-local-user-minor-mode     t
       vip-insert-kbd-minor-mode     	    (not (vip-is-in-minibuffer))
       vip-insert-global-user-minor-mode    t
       vip-insert-state-modifier-minor-mode  t
       ;; don't let the diehard keymap block command completion 
       ;; and other things in the minibuffer
       vip-insert-diehard-minor-mode 	    (not
					     (or vip-want-emacs-keys-in-insert
						 (vip-is-in-minibuffer)))
       vip-insert-basic-minor-mode   	    t
       vip-emacs-intercept-minor-mode       nil
       vip-emacs-local-user-minor-mode      nil
       vip-emacs-kbd-minor-mode     	    nil
       vip-emacs-global-user-minor-mode     nil
       vip-emacs-state-modifier-minor-mode  nil
       ))
       
  ;; minibuffer faces
  (if (vip-has-face-support-p)
      (setq vip-minibuffer-current-face
	    (cond ((eq state 'emacs-state) vip-minibuffer-emacs-face)
		  ((eq state 'vi-state) vip-minibuffer-vi-face)
		  ((memq state '(insert-state replace-state))
		   vip-minibuffer-insert-face))))
  
  (if (vip-is-in-minibuffer)
      (vip-set-minibuffer-overlay))
  )

;; This also takes care of the annoying incomplete lines in files.
;; Also, this fixes `undo' to work vi-style for complex commands.
(defun vip-change-state-to-vi ()
  "Change Viper state to Vi."
  (interactive)
  (if (and vip-first-time (not (vip-is-in-minibuffer)))
      (viper-mode)
    (if overwrite-mode (overwrite-mode nil))
    (if abbrev-mode (expand-abbrev))
    (if (and auto-fill-function (> (current-column) fill-column))
	(funcall auto-fill-function))
    ;; don't leave whitespace lines around
    (if (and (memq last-command
		   '(vip-autoindent
		     vip-open-line vip-Open-line
		     vip-replace-state-exit-cmd))
	     (vip-over-whitespace-line))
	(indent-to-left-margin))
    (vip-add-newline-at-eob-if-necessary)
    (if vip-undo-needs-adjustment  (vip-adjust-undo))
    (vip-change-state 'vi-state)

    ;; always turn off iso-accents-mode, or else we won't be able to use the
    ;; keys `,',^ in Vi state, as they will do accents instead of Vi actions.
    (if (and (boundp 'iso-accents-mode) iso-accents-mode)
	(iso-accents-mode -1))

    (vip-restore-cursor-color-after-insert)
    
    ;; Protection against user errors in hooks
    (condition-case conds
	(run-hooks 'vip-vi-state-hook)
      (error
       (vip-message-conditions conds)))))

(defun vip-change-state-to-insert ()
  "Change Viper state to Insert."
  (interactive)
  (vip-change-state 'insert-state)
  (if (and vip-automatic-iso-accents (fboundp 'iso-accents-mode))
      (iso-accents-mode 1)) ; turn iso accents on
  
  (or (stringp vip-saved-cursor-color)
      (string= (vip-get-cursor-color) vip-insert-state-cursor-color)
      (setq vip-saved-cursor-color (vip-get-cursor-color)))
  ;; Commented out, because if vip-change-state-to-insert is executed
  ;; non-interactively then the old cursor color may get lost. Same old Emacs
  ;; bug related to local variables?
;;;(if (stringp vip-saved-cursor-color)
;;;      (vip-change-cursor-color vip-insert-state-cursor-color))
  ;; Protection against user errors in hooks
  (condition-case conds
      (run-hooks 'vip-insert-state-hook)
    (error
     (vip-message-conditions conds))))
     
(defsubst vip-downgrade-to-insert ()
 (setq vip-current-state 'insert-state
       vip-replace-minor-mode nil)
 )

    
  
;; Change to replace state. When the end of replacement region is reached,
;; replace state changes to insert state.
(defun vip-change-state-to-replace (&optional non-R-cmd)
  (vip-change-state 'replace-state)
  (if (and vip-automatic-iso-accents (fboundp 'iso-accents-mode))
      (iso-accents-mode 1)) ; turn iso accents on
  ;; Run insert-state-hook
  (condition-case conds
      (run-hooks 'vip-insert-state-hook 'vip-replace-state-hook)
    (error
     (vip-message-conditions conds)))
  
  (if non-R-cmd
      (vip-start-replace)
    ;; 'R' is implemented using Emacs's overwrite-mode
    (vip-start-R-mode))
  )

    
(defun vip-change-state-to-emacs ()
  "Change Viper state to Emacs."
  (interactive)
  (vip-change-state 'emacs-state)
  (if (and vip-automatic-iso-accents (fboundp 'iso-accents-mode))
      (iso-accents-mode 1)) ; turn iso accents on
  
  ;; Protection agains user errors in hooks
  (condition-case conds
      (run-hooks 'vip-emacs-state-hook)
    (error
     (vip-message-conditions conds))))
  
;; escape to emacs mode termporarily
(defun vip-escape-to-emacs (arg &optional events)
  "Escape to Emacs state from Vi state for one Emacs command.
ARG is used as the prefix value for the executed command.  If
EVENTS is a list of events, which become the beginning of the command."
  (interactive "P")
  (if (= last-command-char ?\\)
      (message "Switched to EMACS state for the next command..."))
  (vip-escape-to-state arg events 'emacs-state))
  
;; escape to Vi mode termporarily
(defun vip-escape-to-vi (arg)
  "Escape from Emacs state to Vi state for one Vi 1-character command.
If the Vi command that the user types has a prefix argument, e.g., `d2w', then
Vi's prefix argument will be used. Otherwise, the prefix argument passed to
`vip-escape-to-vi' is used."
  (interactive "P")
  (message "Switched to VI state for the next command...")
  (vip-escape-to-state arg nil 'vi-state))
  
;; Escape to STATE mode for one Emacs command.
(defun vip-escape-to-state (arg events state)
  ;;(let (com key prefix-arg)
  (let (com key)
    ;; this temporarily turns off Viper's minor mode keymaps
    (vip-set-mode-vars-for state)
    (vip-normalize-minor-mode-map-alist)
    (if events (vip-set-unread-command-events events))
    
    ;; protect against keyboard quit and other errors
    (condition-case nil
	(let (vip-vi-kbd-minor-mode 
	      vip-insert-kbd-minor-mode
	      vip-emacs-kbd-minor-mode)
	  (unwind-protect
	      (progn
		(setq com (key-binding (setq key 
					     (if vip-xemacs-p
						 (read-key-sequence nil)
					       (read-key-sequence nil t)))))
		;; In case of binding indirection--chase definitions.
		;; Have to do it here because we execute this command under
		;; different keymaps, so command-execute may not do the
		;; right thing there
		(while (vectorp com) (setq com (key-binding com))))
	    nil)
	  ;; Execute command com in the original Viper state, not in state
	  ;; `state'. Otherwise, if we switch buffers while executing the
	  ;; escaped to command, Viper's mode vars will remain those of
	  ;; `state'. When we return to the orig buffer, the bindings will be
	  ;; screwed up.
	  (vip-set-mode-vars-for vip-current-state)
	  
	  ;; this-command, last-command-char, last-command-event
	  (setq this-command com)
	  (if vip-xemacs-p ; XEmacs represents key sequences as vectors
	      (setq last-command-event (vip-copy-event (vip-seq-last-elt key))
		    last-command-char (event-to-character last-command-event))
	    ;; Emacs represents them as sequences (str or vec)
	    (setq last-command-event (vip-copy-event (vip-seq-last-elt key))
		  last-command-char last-command-event))
	    
	  (if (commandp com)
	      (progn
		(setq prefix-arg (or prefix-arg arg))
		(command-execute com)))
	  )
      (quit (ding))
      (error (beep 1))))
  ;; set state in the new buffer
  (vip-set-mode-vars-for vip-current-state))
      
(defun vip-exec-form-in-vi  (form)
  "Execute FORM in Vi state, regardless of the Ccurrent Vi state."
  (let ((buff (current-buffer))
	result)
    (vip-set-mode-vars-for 'vi-state)

    (condition-case nil
	(setq result (eval form))
      (error
       (signal 'quit nil)))

    (if (not (equal buff (current-buffer))) ; cmd switched buffer
	(save-excursion
	  (set-buffer buff)
	  (vip-set-mode-vars-for vip-current-state)))
    (vip-set-mode-vars-for vip-current-state)
    result))

(defun vip-exec-form-in-emacs  (form)
  "Execute FORM in Emacs, temporarily disabling Viper's minor modes.
Similar to vip-escape-to-emacs, but accepts forms rather than keystrokes."
  (let ((buff (current-buffer))
	result)
    (vip-set-mode-vars-for 'emacs-state)
    (setq result (eval form))
    (if (not (equal buff (current-buffer))) ; cmd switched buffer
	(save-excursion
	  (set-buffer buff)
	  (vip-set-mode-vars-for vip-current-state)))
    (vip-set-mode-vars-for vip-current-state)
    result))

  
;; This is needed because minor modes sometimes override essential Viper
;; bindings. By letting Viper know which files these modes are in, it will
;; arrange to reorganize minor-mode-map-alist so that things will work right.
(defun vip-harness-minor-mode (load-file)
  "Familiarize Viper with a minor mode defined in LOAD_FILE.
Minor modes that have their own keymaps may overshadow Viper keymaps.
This function is designed to make Viper aware of the packages that define
such minor modes.
Usage:
    (vip-harness-minor-mode load-file)

LOAD-FILE is a name of the file where the specific minor mode is defined.
Suffixes such as .el or .elc should be stripped."

  (interactive "sEnter name of the load file: ")
  
  (vip-eval-after-load load-file '(vip-normalize-minor-mode-map-alist))
  
  ;; Change the default for minor-mode-map-alist each time a harnessed minor
  ;; mode adds its own keymap to the a-list.
  (vip-eval-after-load
   load-file '(setq-default minor-mode-map-alist minor-mode-map-alist))
  )


(defun vip-ESC (arg)
  "Emulate ESC key in Emacs.
Prevents multiple escape keystrokes if vip-no-multiple-ESC is true.
If vip-no-multiple-ESC is 'twice double ESC would ding in vi-state.
Other ESC sequences are emulated via the current Emacs's major mode
keymap. This is more convenient on TTYs, since this won't block
function keys such as up,down, etc. ESC will also will also work as
a Meta key in this case. When vip-no-multiple-ESC is nil, ESC functions
as a Meta key and any number of multiple escapes is allowed."
  (interactive "P")
  (let (char)
    (cond ((and (not vip-no-multiple-ESC) (eq vip-current-state 'vi-state))
	   (setq char (vip-read-char-exclusive))
	   (vip-escape-to-emacs arg (list ?\e char) ))
	  ((and (eq vip-no-multiple-ESC 'twice) 
		(eq vip-current-state 'vi-state))
	   (setq char (vip-read-char-exclusive))
	   (if (= char (string-to-char vip-ESC-key))
	       (ding)
	     (vip-escape-to-emacs arg (list ?\e char) )))
	  (t (ding)))
    ))

(defun vip-alternate-Meta-key (arg)
  "Simulate Emacs Meta key."
  (interactive "P")
  (sit-for 1) (message "ESC-")
  (vip-escape-to-emacs arg '(?\e)))

(defun vip-toggle-key-action ()
  "Action bound to `vip-toggle-key'."
  (interactive)
  (if (and (< viper-expert-level 2) (equal vip-toggle-key "\C-z"))
      (if (vip-window-display-p)
	  (vip-iconify)
	(suspend-emacs))
    (vip-change-state-to-emacs)))


;; Intercept ESC sequences on dumb terminals.
;; Based on the idea contributed by Marcelino Veiga Tuimil <mveiga@dit.upm.es>

;; Check if last key was ESC and if so try to reread it as a function key.
;; But only if there are characters to read during a very short time.
;; Returns the last event, if any.
(defun vip-envelop-ESC-key ()
  (let ((event last-input-event)
	(keyseq [nil])
	inhibit-quit)
    (if (vip-ESC-event-p event)
	(progn 
	  (if (vip-fast-keysequence-p)
	      (progn
		(let (minor-mode-map-alist)
		  (vip-set-unread-command-events event)
		  (setq keyseq
			(funcall
			 (ad-get-orig-definition 'read-key-sequence) nil))
		  ) ; let
		;; If keyseq translates into something that still has ESC
		;; at the beginning, separate ESC from the rest of the seq.
		;; In XEmacs we check for events that are keypress meta-key
		;; and convert them into [escape key]
		;;
		;; This is needed for the following reason:
		;; If ESC is the first symbol, we interpret it as if the
		;; user typed ESC and then quickly some other symbols.
		;; If ESC is not the first one, then the key sequence
		;; entered was apparently translated into a function key or
		;; something (e.g., one may have
		;; (define-key function-key-map "\e[192z" [f11])
		;; which would translate the escape-sequence generated by
		;; f11 in an xterm window into the symbolic key f11.
		;;
		;; If `first-key' is not an ESC event, we make it into the
		;; last-command-event in order to pretend that this key was
		;; pressed. This is needed to allow arrow keys to be bound to
		;; macros. Otherwise, vip-exec-mapped-kbd-macro will think that
		;; the last event was ESC and so it'll execute whatever is
		;; bound to ESC. (Viper macros can't be bound to
		;; ESC-sequences).
		(let* ((first-key (elt keyseq 0))
		       (key-mod (event-modifiers first-key)))
		  (cond ((vip-ESC-event-p first-key)
			 ;; put keys following ESC on the unread list
			 ;; and return ESC as the key-sequence
			 (vip-set-unread-command-events (subseq keyseq 1))
			 (setq last-input-event event
			       keyseq (if vip-emacs-p
					  "\e"
					(vector (character-to-event ?\e)))))
			((and vip-xemacs-p
			      (key-press-event-p first-key)
			      (equal '(meta) key-mod))
			 (vip-set-unread-command-events 
			  (vconcat (vector
				    (character-to-event (event-key first-key)))
				   (subseq keyseq 1)))
			 (setq last-input-event event
			       keyseq (vector (character-to-event ?\e))))
			((eventp first-key)
			 (setq last-command-event (vip-copy-event first-key)))
			))
		) ; end progn
		
	    ;; this is escape event with nothing after it
	    ;; put in unread-command-event and then re-read
	    (vip-set-unread-command-events event)
	    (setq keyseq
		  (funcall (ad-get-orig-definition 'read-key-sequence) nil))
	    ))
      ;; not an escape event
      (setq keyseq (vector event)))
    keyseq))

    

;; Listen to ESC key.
;; If a sequence of keys starting with ESC is issued with very short delays,
;; interpret these keys in Emacs mode, so ESC won't be interpreted as a Vi key.
(defun vip-intercept-ESC-key ()
  "Function that implements ESC key in Viper emulation of Vi."
  (interactive)
  (let ((cmd (or (key-binding (vip-envelop-ESC-key)) 
		 '(lambda () (interactive) (error "")))))
    
    ;; call the actual function to execute ESC (if no other symbols followed)
    ;; or the key bound to the ESC sequence (if the sequence was issued
    ;; with very short delay between characters.
    (if (eq cmd 'vip-intercept-ESC-key)
	(setq cmd
	      (cond ((eq vip-current-state 'vi-state)
		     'vip-ESC)
		    ((eq vip-current-state 'insert-state)
		     'vip-exit-insert-state) 
		    ((eq vip-current-state 'replace-state)
		     'vip-replace-state-exit-cmd)
		    (t 'vip-change-state-to-vi)
		    )))
    (call-interactively cmd)))

	   


;; prefix argument for Vi mode

;; In Vi mode, prefix argument is a dotted pair (NUM . COM) where NUM
;; represents the numeric value of the prefix argument and COM represents
;; command prefix such as "c", "d", "m" and "y".

;; Get value part of prefix-argument ARG.
(defsubst vip-p-val (arg)
  (cond ((null arg) 1)
	((consp arg)
	 (if (or (null (car arg)) (equal (car arg) '(nil)))
	     1 (car arg)))
	(t arg)))

;; Get raw value part of prefix-argument ARG.
(defsubst vip-P-val (arg)
  (cond ((consp arg) (car arg))
	(t arg)))

;; Get com part of prefix-argument ARG.
(defsubst vip-getcom (arg)
  (cond ((null arg) nil)
	((consp arg) (cdr arg))
	(t nil)))

;; Get com part of prefix-argument ARG and modify it.
(defun vip-getCom (arg)
  (let ((com (vip-getcom arg)))
    (cond ((equal com ?c) ?C)
	  ((equal com ?d) ?D)
	  ((equal com ?y) ?Y)
	  (t com))))


;; Compute numeric prefix arg value. 
;; Invoked by EVENT. COM is the command part obtained so far.
(defun vip-prefix-arg-value (event com)
  (let (value func)
    ;; read while number
    (while (and (vip-characterp event) (>= event ?0) (<= event ?9))
      (setq value (+ (* (if (integerp value) value 0) 10) (- event ?0)))
      (setq event (vip-read-event-convert-to-char)))
    
    (setq prefix-arg value)
    (if com (setq prefix-arg (cons prefix-arg com)))
    (while (eq event ?U)
      (vip-describe-arg prefix-arg)
      (setq event (vip-read-event-convert-to-char)))
    
    (if (or com (and (not (eq vip-current-state 'vi-state))
		     ;; make sure it is a Vi command
		     (vip-characterp event) (vip-vi-command-p event)
		     ))
	;; If appears to be one of the vi commands,
	;; then execute it with funcall and clear prefix-arg in order to not
	;; confuse subsequent commands
	(progn
	  ;; last-command-char is the char we want emacs to think was typed
	  ;; last. If com is not nil, the vip-digit-argument command was called
	  ;; from within vip-prefix-arg command, such as `d', `w', etc., i.e., 
	  ;; the user typed, say, d2. In this case, `com' would be `d', `w',
	  ;; etc.
	  ;; If vip-digit-argument was invoked by vip-escape-to-vi (which is
	  ;; indicated by the fact that the current state is not vi-state),
	  ;; then `event' represents the vi command to be executed (e.g., `d',
	  ;; `w', etc). Again, last-command-char must make emacs believe that
	  ;; this is the command we typed.
	  (setq last-command-char (or com event))
	  (setq func (vip-exec-form-in-vi 
		      (` (key-binding (char-to-string (, event))))))
	  (funcall func prefix-arg)
	  (setq prefix-arg nil))
      ;; some other command -- let emacs do it in its own way
      (vip-set-unread-command-events event))
    ))
		     

;; Vi operator as prefix argument."
(defun vip-prefix-arg-com (char value com)
  (let ((cont t)
	cmd-info mv-or-digit-cmd)
    (while (and cont
		(memq char
		      (list ?c ?d ?y ?! ?< ?> ?= ?# ?r ?R ?\"
			    vip-buffer-search-char)))
      (if com
	  ;; this means that we already have a command character, so we
	  ;; construct a com list and exit while.  however, if char is "
	  ;; it is an error.
	  (progn
	    ;; new com is (CHAR . OLDCOM)
	    (if (memq char '(?# ?\")) (error ""))
	    (setq com (cons char com))
	    (setq cont nil))
	;; If com is nil we set com as char, and read more.  Again, if char
	;; is ", we read the name of register and store it in vip-use-register.
	;; if char is !, =, or #, a complete com is formed so we exit the
	;; while loop.
	(cond ((memq char '(?! ?=))
	       (setq com char)
	       (setq char (read-char))
	       (setq cont nil))
	      ((= char ?#)
	       ;; read a char and encode it as com
	       (setq com (+ 128 (read-char)))
	       (setq char (read-char)))
	      ((= char ?\")
	       (let ((reg (read-char)))
		 (if (vip-valid-register reg)
		     (setq vip-use-register reg)
		   (error ""))
		 (setq char (read-char))))
	      (t
	       (setq com char)
	       (setq char (read-char))))))

  (if (atom com)
      ;; `com' is a single char, so we construct the command argument
      ;; and if `char' is `?', we describe the arg; otherwise 
      ;; we prepare the command that will be executed at the end.
      (progn
	(setq cmd-info (cons value com))
	(while (= char ?U)
	  (vip-describe-arg cmd-info)
	  (setq char (read-char)))
	;; `char' is a movement cmd, a digit arg cmd, or a register cmd---so we
	;; execute it at the very end 
	(or (vip-movement-command-p char)
	    (vip-digit-command-p char)
	    (vip-regsuffix-command-p char)
	    (error ""))
	(setq mv-or-digit-cmd
	      (vip-exec-form-in-vi 
	       (` (key-binding (char-to-string (, char)))))))
    
    ;; as com is non-nil, this means that we have a command to execute
    (if (memq (car com) '(?r ?R))
	;; execute apropriate region command.
	(let ((char (car com)) (com (cdr com)))
	  (setq prefix-arg (cons value com))
	  (if (= char ?r) (vip-region prefix-arg)
	    (vip-Region prefix-arg))
	  ;; reset prefix-arg
	  (setq prefix-arg nil))
      ;; otherwise, reset prefix arg and call appropriate command
      (setq value (if (null value) 1 value))
      (setq prefix-arg nil)
      (cond ((equal com '(?c . ?c)) (vip-line (cons value ?C)))
	    ((equal com '(?d . ?d)) (vip-line (cons value ?D)))
	    ((equal com '(?d . ?y)) (vip-yank-defun))
	    ((equal com '(?y . ?y)) (vip-line (cons value ?Y)))
	    ((equal com '(?< . ?<)) (vip-line (cons value ?<)))
	    ((equal com '(?> . ?>)) (vip-line (cons value ?>)))
	    ((equal com '(?! . ?!)) (vip-line (cons value ?!)))
	    ((equal com '(?= . ?=)) (vip-line (cons value ?=)))
	    (t (error "")))))
  
  (if mv-or-digit-cmd
      (progn
	(setq last-command-char char)
	(setq last-command-event 
	      (vip-copy-event
	       (if vip-xemacs-p (character-to-event char) char)))
	(condition-case nil
	    (funcall mv-or-digit-cmd cmd-info)
	  (error
	   (error "")))))
  ))

(defun vip-describe-arg (arg)
  (let (val com)
    (setq val (vip-P-val arg)
	  com (vip-getcom arg))
    (if (null val)
	(if (null com)
	    (message "Value is nil, and command is nil")
	  (message "Value is nil, and command is `%c'" com))
      (if (null com)
	  (message "Value is `%d', and command is nil" val)
	(message "Value is `%d', and command is `%c'" val com)))))

(defun vip-digit-argument (arg)
  "Begin numeric argument for the next command."
  (interactive "P")
  (vip-leave-region-active)
  (vip-prefix-arg-value
   last-command-char (if (consp arg) (cdr arg) nil)))

(defun vip-command-argument (arg)
  "Accept a motion command as an argument."
  (interactive "P")
  (let ((vip-inside-command-argument-action t))
    (condition-case nil
	(vip-prefix-arg-com
	 last-command-char   
	 (cond ((null arg) nil)
	       ((consp arg) (car arg))
	       ((integerp arg) arg)
	       (t (error vip-InvalidCommandArgument)))
	 (cond ((null arg) nil)
	       ((consp arg) (cdr arg))
	       ((integerp arg) nil)
	       (t (error vip-InvalidCommandArgument))))
      (quit (setq vip-use-register nil)
	    (signal 'quit nil)))
    (vip-deactivate-mark)))


;; repeat last destructive command

;; Append region to text in register REG.
;; START and END are buffer positions indicating what to append.
(defsubst vip-append-to-register (reg start end)
  (set-register reg (concat (if (stringp (get-register reg))
				(get-register reg) "")
			    (buffer-substring start end))))

;; Saves last inserted text for possible use by vip-repeat command.
(defun vip-save-last-insertion (beg end)
  (setq vip-last-insertion (buffer-substring beg end))
  (or (< (length vip-d-com) 5)
      (setcar (nthcdr 4 vip-d-com) vip-last-insertion))
  (or (null vip-command-ring)
      (ring-empty-p vip-command-ring)
      (progn
	(setcar (nthcdr 4 (vip-current-ring-item vip-command-ring))
		vip-last-insertion)
	;; del most recent elt, if identical to the second most-recent
	(vip-cleanup-ring vip-command-ring)))
  )
    
(defsubst vip-yank-last-insertion ()
  "Inserts the text saved by the previous vip-save-last-insertion command."
  (condition-case nil
      (insert vip-last-insertion)
    (error nil)))
  
			    
;; define functions to be executed

;; invoked by the `C' command
(defun vip-exec-change (m-com com) 
  (or (and (markerp vip-com-point) (marker-position vip-com-point))
      (set-marker vip-com-point (point) (current-buffer)))
  ;; handle C cmd at the eol and at eob.
  (if (or (and (eolp) (= vip-com-point (point)))
	  (= vip-com-point (point-max)))
      (progn
	(insert " ")(backward-char 1)))
  (if (= vip-com-point (point))
      (vip-forward-char-carefully))
  (if (= com ?c)
      (vip-change vip-com-point (point))
    (vip-change-subr vip-com-point (point))))

;; this is invoked by vip-substitute-line
(defun vip-exec-Change (m-com com)
  (save-excursion
    (set-mark vip-com-point)
    (vip-enlarge-region (mark t) (point))
    (if vip-use-register
	(progn
	  (cond ((vip-valid-register vip-use-register '(letter digit))
		 ;;(vip-valid-register vip-use-register '(letter)
		 (copy-to-register
		  vip-use-register (mark t) (point) nil))
		((vip-valid-register vip-use-register '(Letter))
		 (vip-append-to-register
		  (downcase vip-use-register) (mark t) (point)))
		(t (setq vip-use-register nil)
		   (error vip-InvalidRegister vip-use-register)))
	  (setq vip-use-register nil)))
    (delete-region (mark t) (point)))
  (open-line 1)
  (if (= com ?C) (vip-change-mode-to-insert) (vip-yank-last-insertion)))

(defun vip-exec-delete (m-com com)
  (or (and (markerp vip-com-point) (marker-position vip-com-point))
      (set-marker vip-com-point (point) (current-buffer)))
  (if vip-use-register
      (progn
	(cond ((vip-valid-register vip-use-register '(letter digit))
	       ;;(vip-valid-register vip-use-register '(letter))
	       (copy-to-register
		vip-use-register vip-com-point (point) nil))
	      ((vip-valid-register vip-use-register '(Letter))
	       (vip-append-to-register
		(downcase vip-use-register) vip-com-point (point)))
	      (t (setq vip-use-register nil)
		 (error vip-InvalidRegister vip-use-register)))
	(setq vip-use-register nil)))
  (setq last-command
	(if (eq last-command 'd-command) 'kill-region nil))
  (kill-region vip-com-point (point))
  (setq this-command 'd-command)
  (if vip-ex-style-motion
      (if (and (eolp) (not (bolp))) (backward-char 1))))

(defun vip-exec-Delete (m-com com)
  (save-excursion
    (set-mark vip-com-point)
    (vip-enlarge-region (mark t) (point))
    (if vip-use-register
	(progn
	  (cond ((vip-valid-register vip-use-register '(letter digit))
		 ;;(vip-valid-register vip-use-register '(letter))
		 (copy-to-register
		  vip-use-register (mark t) (point) nil))
		((vip-valid-register vip-use-register '(Letter))
		 (vip-append-to-register
		  (downcase vip-use-register) (mark t) (point)))
		(t (setq vip-use-register nil)
		   (error vip-InvalidRegister vip-use-register)))
	  (setq vip-use-register nil)))
    (setq last-command
	  (if (eq last-command 'D-command) 'kill-region nil))
    (kill-region (mark t) (point))
    (if (eq m-com 'vip-line) (setq this-command 'D-command)))
  (back-to-indentation))

(defun vip-exec-yank (m-com com)
  (or (and (markerp vip-com-point) (marker-position vip-com-point))
      (set-marker vip-com-point (point) (current-buffer)))
  (if vip-use-register
      (progn
	(cond ((vip-valid-register vip-use-register '(letter digit))
	       ;; (vip-valid-register vip-use-register '(letter))
	       (copy-to-register
		vip-use-register vip-com-point (point) nil))
	      ((vip-valid-register vip-use-register '(Letter))
	       (vip-append-to-register
		(downcase vip-use-register) vip-com-point (point)))
	      (t (setq vip-use-register nil)
		 (error vip-InvalidRegister vip-use-register)))
	(setq vip-use-register nil)))
  (setq last-command nil)
  (copy-region-as-kill vip-com-point (point))
  (goto-char vip-com-point))

(defun vip-exec-Yank (m-com com)
  (save-excursion
    (set-mark vip-com-point)
    (vip-enlarge-region (mark t) (point))
    (if vip-use-register
	(progn
	  (cond ((vip-valid-register vip-use-register '(letter digit))
		 (copy-to-register
		  vip-use-register (mark t) (point) nil))
		((vip-valid-register vip-use-register '(Letter))
		 (vip-append-to-register
		  (downcase vip-use-register) (mark t) (point)))
		(t (setq vip-use-register nil)
		   (error vip-InvalidRegister  vip-use-register)))
	  (setq vip-use-register nil)))
    (setq last-command nil)
    (copy-region-as-kill (mark t) (point)))
  (vip-deactivate-mark)
  (goto-char vip-com-point))

(defun vip-exec-bang (m-com com)
  (save-excursion
    (set-mark vip-com-point)
    (vip-enlarge-region (mark t) (point))
    (shell-command-on-region
     (mark t) (point)
     (if (= com ?!)
	 (setq vip-last-shell-com
	       (vip-read-string-with-history 
		"!"
		nil
		'vip-shell-history
		(car vip-shell-history)
		))
       vip-last-shell-com)
     t)))

(defun vip-exec-equals (m-com com)
  (save-excursion
    (set-mark vip-com-point)
    (vip-enlarge-region (mark t) (point))
    (if (> (mark t) (point)) (exchange-point-and-mark))
    (indent-region (mark t) (point) nil)))

(defun vip-exec-shift (m-com com)
  (save-excursion
    (set-mark vip-com-point)
    (vip-enlarge-region (mark t) (point))
    (if (> (mark t) (point)) (exchange-point-and-mark))
    (indent-rigidly (mark t) (point) 
		    (if (= com ?>)
			vip-shift-width
		      (- vip-shift-width))))
  ;; return point to where it was before shift
  (goto-char vip-com-point))

;; this is needed because some commands fake com by setting it to ?r, which
;; denotes repeated insert command.
(defsubst vip-exec-dummy (m-com com)
  nil)

(defun vip-exec-buffer-search (m-com com)
  (setq vip-s-string (buffer-substring (point) vip-com-point))
  (setq vip-s-forward t)
  (setq vip-search-history (cons vip-s-string vip-search-history))
  (vip-search vip-s-string vip-s-forward 1))

(defvar vip-exec-array (make-vector 128 nil))

;; Using a dispatch array allows adding functions like buffer search
;; without affecting other functions. Buffer search can now be bound
;; to any character.

(aset vip-exec-array ?c 'vip-exec-change)
(aset vip-exec-array ?C 'vip-exec-Change)
(aset vip-exec-array ?d 'vip-exec-delete)
(aset vip-exec-array ?D 'vip-exec-Delete)
(aset vip-exec-array ?y 'vip-exec-yank)
(aset vip-exec-array ?Y 'vip-exec-Yank)
(aset vip-exec-array ?r 'vip-exec-dummy)
(aset vip-exec-array ?! 'vip-exec-bang)
(aset vip-exec-array ?< 'vip-exec-shift)
(aset vip-exec-array ?> 'vip-exec-shift)
(aset vip-exec-array ?= 'vip-exec-equals)



;; This function is called by various movement commands to execute a
;; destructive command on the region specified by the movement command. For
;; instance, if the user types cw, then the command vip-forward-word will
;; call vip-execute-com to execute vip-exec-change, which eventually will
;; call vip-change to invoke the replace mode on the region.
;;
;; The list (M-COM VAL COM REG INSETED-TEXT COMMAND-KEYS) is set to
;; vip-d-com for later use by vip-repeat.
(defun vip-execute-com (m-com val com)
  (let ((reg vip-use-register))
    ;; this is the special command `#'
    (if (> com 128)
	(vip-special-prefix-com (- com 128))
      (let ((fn (aref vip-exec-array (if (< com 0) (- com) com))))
	(if (null fn)
	    (error "%c: %s" com vip-InvalidViCommand)
	  (funcall fn m-com com))))
    (if (vip-dotable-command-p com)
	(vip-set-destructive-command
	 (list m-com val
	       (if (memq com (list ?c ?C ?!)) (- com) com)
	       reg nil nil)))
    ))


(defun vip-repeat (arg)
  "Re-execute last destructive command.
Use the info in vip-d-com, which has the form
\(com val ch reg inserted-text command-keys\),
where `com' is the command to be re-executed, `val' is the
argument to `com', `ch' is a flag for repeat, and `reg' is optional;
if it exists, it is the name of the register for `com'.
If the prefix argument, ARG, is non-nil, it is used instead of `val'."
  (interactive "P")
  (let ((save-point (point)) ; save point before repeating prev cmd
	;; Pass along that we are repeating a destructive command
	;; This tells vip-set-destructive-command not to update
	;; vip-command-ring
	(vip-intermediate-command 'vip-repeat))
    (if (eq last-command 'vip-undo)
	;; if the last command was vip-undo, then undo-more
	(vip-undo-more)
      ;; otherwise execute the command stored in vip-d-com.  if arg is non-nil
      ;; its prefix value is used as new prefix value for the command.
      (let ((m-com (car vip-d-com))
	    (val (vip-P-val arg))
	    (com (nth 2 vip-d-com))
	    (reg (nth 3 vip-d-com)))
        (if (null val) (setq val (nth 1 vip-d-com)))
        (if (null m-com) (error "No previous command to repeat."))
        (setq vip-use-register reg)
	(if (nth 4 vip-d-com) ; text inserted by command
	    (setq vip-last-insertion (nth 4 vip-d-com)
		  vip-d-char (nth 4 vip-d-com)))
        (funcall m-com (cons val com))
        (cond ((and (< save-point (point)) vip-keep-point-on-repeat)
	       (goto-char save-point)) ; go back to before repeat.
	      ((and (< save-point (point)) vip-ex-style-editing-in-insert)
	       (or (bolp) (backward-char 1))))
	(if (and (eolp) (not (bolp)))
	    (backward-char 1))
     ))
  (if vip-undo-needs-adjustment (vip-adjust-undo)) ; take care of undo
  ;; If the prev cmd was rotating the command ring, this means that `.' has
  ;; just executed a command from that ring. So, push it on the ring again.
  ;; If we are just executing previous command , then don't push vip-d-com
  ;; because vip-d-com is not fully constructed in this case (its keys and
  ;; the inserted text may be nil). Besides, in this case, the command
  ;; executed by `.' is already on the ring.
  (if (eq last-command 'vip-display-current-destructive-command)
      (vip-push-onto-ring vip-d-com 'vip-command-ring))
  (vip-deactivate-mark)
  ))
  
(defun vip-repeat-from-history ()
  "Repeat a destructive command from history.
Doesn't change vip-command-ring in any way, so `.' will work as before
executing this command.
This command is supposed to be bound to a two-character Vi macro where
the second character is a digit 0 to 9. The digit indicates which
history command to execute. `<char>0' is equivalent to `.', `<char>1'
invokes the command before that, etc."
  (interactive)
  (let* ((vip-intermediate-command 'repeating-display-destructive-command)
	 (idx (cond (vip-this-kbd-macro
		      (string-to-number
		       (symbol-name (elt vip-this-kbd-macro 1))))
		    (t 0)))
	 (num idx)
	 (vip-d-com vip-d-com))

    (or (and (numberp num) (<= 0 num) (<= num 9))
	(progn
	  (setq idx 0
		num 0)
	  (message
	   "`vip-repeat-from-history' must be invoked as a Vi macro bound to `<key><digit>'")))
    (while (< 0 num)
      (setq vip-d-com (vip-special-ring-rotate1 vip-command-ring -1))
      (setq num (1- num)))
    (vip-repeat nil)
    (while (> idx num)
      (vip-special-ring-rotate1 vip-command-ring 1)
      (setq num (1+ num)))
    ))
      

;; The hash-command. It is invoked interactively by the key sequence #<char>.
;; The chars that can follow `#' are determined by vip-hash-command-p
(defun vip-special-prefix-com (char)
  (cond ((= char ?c)
	 (downcase-region (min vip-com-point (point))
			  (max vip-com-point (point))))
	((= char ?C)
	 (upcase-region (min vip-com-point (point))
			(max vip-com-point (point))))
	((= char ?g)
	 (push-mark vip-com-point t)
	 (vip-global-execute))
	((= char ?q)
	 (push-mark vip-com-point t)
	 (vip-quote-region))
	((= char ?s) (funcall vip-spell-function vip-com-point (point)))
	(t (error "#%c: %s" char vip-InvalidViCommand))))


;; undoing

(defun vip-undo ()
  "Undo previous change."
  (interactive)
  (message "undo!")
  (let ((modified (buffer-modified-p))
        (before-undo-pt (point-marker))
	(after-change-functions after-change-functions)
	undo-beg-posn undo-end-posn)
	
    ;; no need to remove this hook, since this var has scope inside a let.
    (add-hook 'after-change-functions
	      '(lambda (beg end len)
		 (setq undo-beg-posn beg
		       undo-end-posn (or end beg))))
  
    (undo-start)
    (undo-more 2)
    (setq undo-beg-posn (or undo-beg-posn before-undo-pt)
	  undo-end-posn (or undo-end-posn undo-beg-posn))
    
    (goto-char undo-beg-posn)
    (sit-for 0)
    (if (and vip-keep-point-on-undo
	     (pos-visible-in-window-p before-undo-pt))
	(progn
	  (push-mark (point-marker) t) 
	  (vip-sit-for-short 300)
	  (goto-char undo-end-posn)
	  (vip-sit-for-short 300)
	  (if (and (> (abs (- undo-beg-posn before-undo-pt)) 1)
		  (> (abs (- undo-end-posn before-undo-pt)) 1))
	      (goto-char before-undo-pt)
	    (goto-char undo-beg-posn)))
      (push-mark before-undo-pt t))
    (if (and (eolp) (not (bolp))) (backward-char 1))
    (if (not modified) (set-buffer-modified-p t)))
  (setq this-command 'vip-undo))

;; Continue undoing previous changes.
(defun vip-undo-more ()
  (message "undo more!")
  (condition-case nil
      (undo-more 1)
    (error (beep)
	   (message "No further undo information in this buffer")))
  (if (and (eolp) (not (bolp))) (backward-char 1))
  (setq this-command 'vip-undo))

;; The following two functions are used to set up undo properly.
;; In VI, unlike Emacs, if you open a line, say, and add a bunch of lines,
;; they are undone all at once.  
(defun vip-adjust-undo ()
  (let ((inhibit-quit t)
	tmp tmp2)
    (setq vip-undo-needs-adjustment nil)
    (if (listp buffer-undo-list)
	(if (setq tmp (memq vip-buffer-undo-list-mark buffer-undo-list))
	    (progn
	      (setq tmp2 (cdr tmp)) ; the part after mark
	      
	      ;; cut tail from buffer-undo-list temporarily by direct
	      ;; manipulation with pointers in buffer-undo-list
	      (setcdr tmp nil)
	      
	      (setq buffer-undo-list (delq nil buffer-undo-list))
	      (setq buffer-undo-list
		    (delq vip-buffer-undo-list-mark buffer-undo-list))
	      ;; restore tail of buffer-undo-list
	      (setq buffer-undo-list (nconc buffer-undo-list tmp2)))
	  (setq buffer-undo-list (delq nil buffer-undo-list))))))
  

(defun vip-set-complex-command-for-undo ()  
  (if (listp buffer-undo-list)
      (if (not vip-undo-needs-adjustment)
	  (let ((inhibit-quit t))
	    (setq buffer-undo-list 
		  (cons vip-buffer-undo-list-mark buffer-undo-list))
	    (setq vip-undo-needs-adjustment t)))))



      
(defun vip-display-current-destructive-command ()
  (let ((text (nth 4 vip-d-com))
	(keys (nth 5 vip-d-com))
	(max-text-len 30))
    
    (setq this-command 'vip-display-current-destructive-command)
	
    (message " `.' runs  %s%s"
	     (concat "`" (vip-array-to-string keys) "'")
	     (vip-abbreviate-string text max-text-len
				    "  inserting  `" "'" "    ......."))
    ))
    
    
;; don't change vip-d-com if it was vip-repeat command invoked with `.'
;; or in some other way (non-interactively).
(defun vip-set-destructive-command (list)
  (or (eq vip-intermediate-command 'vip-repeat)
      (progn
	(setq vip-d-com list)
	(setcar (nthcdr 5 vip-d-com)
		(vip-array-to-string (this-command-keys)))
	(vip-push-onto-ring vip-d-com 'vip-command-ring))))
    
(defun vip-prev-destructive-command (next)
  "Find previous destructive command in the history of destructive commands.
With prefix argument, find next destructive command."
  (interactive "P")
  (let (cmd vip-intermediate-command)
    (if (eq last-command 'vip-display-current-destructive-command)
	;; repeated search through command history
	(setq vip-intermediate-command 'repeating-display-destructive-command)
      ;; first search through command history--set temp ring
      (setq vip-temp-command-ring (copy-list vip-command-ring))) 
    (setq cmd (if next
		  (vip-special-ring-rotate1 vip-temp-command-ring 1)
		(vip-special-ring-rotate1 vip-temp-command-ring -1)))
    (if (null cmd)
	()
      (setq vip-d-com cmd))
    (vip-display-current-destructive-command)))
      
(defun vip-next-destructive-command ()
  "Find next destructive command in the history of destructive commands."
  (interactive)
  (vip-prev-destructive-command 'next))
  
(defun vip-insert-prev-from-insertion-ring (arg)
  "Cycle through insertion ring in the direction of older insertions.
Undoes previous insertion and inserts new.
With prefix argument, cycles in the direction of newer elements.
In minibuffer, this command executes whatever the invocation key is bound
to in the global map, instead of cycling through the insertion ring."
  (interactive "P")
  (let (vip-intermediate-command)
    (if (eq last-command 'vip-insert-from-insertion-ring)
	(progn  ; repeated search through insertion history
	  (setq vip-intermediate-command 'repeating-insertion-from-ring)
	  (if (eq vip-current-state 'replace-state)
	      (undo 1)
	    (if vip-last-inserted-string-from-insertion-ring
		(backward-delete-char
		 (length vip-last-inserted-string-from-insertion-ring))))
	  )
      ;;first search through insertion history
      (setq vip-temp-insertion-ring (copy-list vip-insertion-ring)))
    (setq this-command 'vip-insert-from-insertion-ring)
    ;; so that things will be undone properly
    (setq buffer-undo-list (cons nil buffer-undo-list))
    (setq vip-last-inserted-string-from-insertion-ring
	  (vip-special-ring-rotate1 vip-temp-insertion-ring (if arg 1 -1)))
    
    ;; this change of vip-intermediate-command must come after
    ;; vip-special-ring-rotate1, so that the ring will rotate, but before the
    ;; insertion.
    (setq vip-intermediate-command nil)
    (if vip-last-inserted-string-from-insertion-ring
	(insert vip-last-inserted-string-from-insertion-ring))
    ))

(defun vip-insert-next-from-insertion-ring ()
  "Cycle through insertion ring in the direction of older insertions.
Undo previous insertion and inserts new."
  (interactive)
  (vip-insert-prev-from-insertion-ring 'next))
    

;; some region utilities

;; If at the last line of buffer, add \\n before eob, if newline is missing.
(defun vip-add-newline-at-eob-if-necessary ()
  (save-excursion
      (end-of-line)
      ;; make sure all lines end with newline, unless in the minibuffer or
      ;; when requested otherwise (require-final-newline is nil)
      (if (and (eobp)
	       (not (bolp))
	       require-final-newline
	       (not (vip-is-in-minibuffer))
	       (not buffer-read-only))
	  (insert "\n"))))

(defun vip-yank-defun ()
  (mark-defun)
  (copy-region-as-kill (point) (mark t)))

;; Enlarge region between BEG and END.
(defun vip-enlarge-region (beg end)
  (or beg (setq beg end)) ; if beg is nil, set to end
  (or end (setq end beg)) ; if end is nil, set to beg
  
  (if (< beg end)
      (progn (goto-char beg) (set-mark end))
    (goto-char end)
    (set-mark beg))
  (beginning-of-line)
  (exchange-point-and-mark)
  (if (or (not (eobp)) (not (bolp))) (forward-line 1))
  (if (not (eobp)) (beginning-of-line))
  (if (> beg end) (exchange-point-and-mark)))


;; Quote region by each line with a user supplied string.
(defun vip-quote-region ()
  (setq vip-quote-string
	(vip-read-string-with-history
	 "Quote string: "
	 nil
	 'vip-quote-region-history
	 vip-quote-string))
  (vip-enlarge-region (point) (mark t))
  (if (> (point) (mark t)) (exchange-point-and-mark))
  (insert vip-quote-string)
  (beginning-of-line)
  (forward-line 1)
  (while (and (< (point) (mark t)) (bolp))
    (insert vip-quote-string)
    (beginning-of-line)
    (forward-line 1)))

;;  Tells whether BEG is on the same line as END.
;;  If one of the args is nil, it'll return nil.
(defun vip-same-line (beg end)
   (let ((selective-display nil)
	 (incr 0)
	 temp)
     (if (and beg end (> beg end))
	 (setq temp beg
	       beg end
	       end temp))
     (if (and beg end)
	 (cond ((or (> beg (point-max)) (> end (point-max))) ; out of range
		nil)
	       (t
		;; This 'if' is needed because Emacs treats the next empty line
		;; as part of the previous line.
		(if (= (vip-line-pos 'start) end)
		    (setq incr 1))
		(<= (+ incr (count-lines beg end)) 1))))
     ))
	 
	 
;; Check if the string ends with a newline.
(defun vip-end-with-a-newline-p (string)
  (or (string= string "")
      (= (vip-seq-last-elt string) ?\n)))

(defun vip-tmp-insert-at-eob (msg)
  (let ((savemax (point-max)))
      (goto-char savemax)
      (insert msg)
      (sit-for 2)
      (goto-char savemax) (delete-region (point) (point-max))
      ))  
      


;;; Minibuffer business
	    
(defsubst vip-set-minibuffer-style ()
  (add-hook 'minibuffer-setup-hook 'vip-minibuffer-setup-sentinel))
  
  
(defun vip-minibuffer-setup-sentinel ()
  (let ((hook (if vip-vi-style-in-minibuffer
		  'vip-change-state-to-insert
		'vip-change-state-to-emacs)))
    (funcall hook)
    ))
  
;; Interpret last event in the local map
(defun vip-exit-minibuffer ()
  (interactive)
  (let (command)
    (setq command (local-key-binding (char-to-string last-command-char)))
    (if command
	(command-execute command)
      (exit-minibuffer))))
  

;;; Reading string with history  
    
(defun vip-read-string-with-history (prompt &optional initial 
					    history-var default keymap)
  ;; Read string, prompting with PROMPT and inserting the INITIAL
  ;; value. Uses HISTORY-VAR. DEFAULT is the default value to accept if the
  ;; input is an empty string. Use KEYMAP, if given, or the
  ;; minibuffer-local-map.
  ;; Default value is displayed until the user types something in the
  ;; minibuffer. 
  (let ((minibuffer-setup-hook 
	 '(lambda ()
	    (if (stringp initial)
		(progn
		  ;; don't wait if we have unread events or in kbd macro
		  (or unread-command-events
		      executing-kbd-macro
		      (sit-for 840))
		  (erase-buffer)
		  (insert initial)))
	    (vip-minibuffer-setup-sentinel)))
	(val "")
	(padding "")
	temp-msg)
    
    (setq keymap (or keymap minibuffer-local-map)
	  initial (or initial "")
	  temp-msg (if default
		       (format "(default: %s) " default)
		     ""))
		   
    (setq vip-incomplete-ex-cmd nil)
    (setq val (read-from-minibuffer prompt 
				    (concat temp-msg initial val padding)
				    keymap nil history-var))
    (setq minibuffer-setup-hook nil
	  padding (vip-array-to-string (this-command-keys))
	  temp-msg "")
    ;; the following tries to be smart about what to put in history
    (if (not (string= val (car (eval history-var))))
	(set history-var (cons val (eval history-var))))
    (if (or (string= (nth 0 (eval history-var)) (nth 1 (eval history-var)))
	    (string= (nth 0 (eval history-var)) ""))
	(set history-var (cdr (eval history-var))))
    ;; If the user enters nothing but the prev cmd wasn't vip-ex,
    ;; vip-command-argument, or `! shell-command', this probably means 
    ;; that the user typed something then erased. Return "" in this case, not
    ;; the default---the default is too confusing in this case.
    (cond ((and (string= val "")
		(not (string= prompt "!")) ; was a `! shell-command'
		(not (memq last-command
			   '(vip-ex
			     vip-command-argument
			     t)
			   )))
	   "")
	  ((string= val "") (or default ""))
	  (t val))
    ))
  


;; insertion commands

;; Called when state changes from Insert Vi command mode.
;; Repeats the insertion command if Insert state was entered with prefix
;; argument > 1.
(defun vip-repeat-insert-command ()
  (let ((i-com (car vip-d-com))
	(val   (nth 1 vip-d-com))
	(char  (nth 2 vip-d-com)))
    (if (and val (> val 1)) ; first check that val is non-nil
	(progn        
	  (setq vip-d-com (list i-com (1- val) ?r nil nil nil))
	  (vip-repeat nil)
	  (setq vip-d-com (list i-com val char nil nil nil))
	  ))))

(defun vip-insert (arg)
  "Insert before point."
  (interactive "P")
  (vip-set-complex-command-for-undo)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (vip-set-destructive-command (list 'vip-insert val ?r nil nil nil))
    (if com
	(vip-loop val (vip-yank-last-insertion))
      (vip-change-state-to-insert))))

(defun vip-append (arg)
  "Append after point."
  (interactive "P")
  (vip-set-complex-command-for-undo)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (vip-set-destructive-command (list 'vip-append val ?r nil nil nil))
    (if (not (eolp)) (forward-char))
    (if (equal com ?r)
	(vip-loop val (vip-yank-last-insertion))
      (vip-change-state-to-insert))))

(defun vip-Append (arg)
  "Append at end of line."
  (interactive "P")
  (vip-set-complex-command-for-undo)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (vip-set-destructive-command (list 'vip-Append val ?r nil nil nil))
    (end-of-line)
    (if (equal com ?r)
	(vip-loop val (vip-yank-last-insertion))
      (vip-change-state-to-insert))))

(defun vip-Insert (arg)
  "Insert before first non-white."
  (interactive "P")
  (vip-set-complex-command-for-undo)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (vip-set-destructive-command (list 'vip-Insert val ?r nil nil nil))
    (back-to-indentation)
    (if (equal com ?r)
	(vip-loop val (vip-yank-last-insertion))
      (vip-change-state-to-insert))))

(defun vip-open-line (arg)
  "Open line below."
  (interactive "P")
  (vip-set-complex-command-for-undo)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (vip-set-destructive-command (list 'vip-open-line val ?r nil nil nil))
    (let ((col (current-indentation)))
      (if (equal com ?r)
	  (vip-loop val
		    (progn
		      (end-of-line)
		      (newline 1)
		      (if vip-auto-indent 
			  (progn
			    (setq vip-cted t)
			    (if vip-electric-mode
				(indent-according-to-mode)
			      (indent-to col))
			    ))
		      (vip-yank-last-insertion)))
	(end-of-line)
	(newline 1)
	(if vip-auto-indent
	    (progn
	      (setq vip-cted t)
	      (if vip-electric-mode
		  (indent-according-to-mode)
		(indent-to col))))
	(vip-change-state-to-insert)))))

(defun vip-Open-line (arg)
  "Open line above."
  (interactive "P")
  (vip-set-complex-command-for-undo)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (vip-set-destructive-command (list 'vip-Open-line val ?r nil nil nil))
    (let ((col (current-indentation)))
      (if (equal com ?r)
	  (vip-loop val
		    (progn
		      (beginning-of-line)
		      (open-line 1)
		      (if vip-auto-indent 
			  (progn
			    (setq vip-cted t)
			    (if vip-electric-mode
				(indent-according-to-mode)
			      (indent-to col))
			    ))
		      (vip-yank-last-insertion)))
	(beginning-of-line)
	(open-line 1)
	(if vip-auto-indent
	    (progn
	      (setq vip-cted t)
	      (if vip-electric-mode
		  (indent-according-to-mode)
		(indent-to col))
	      ))
	(vip-change-state-to-insert)))))

(defun vip-open-line-at-point (arg)
  "Open line at point."
  (interactive "P")
  (vip-set-complex-command-for-undo)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (vip-set-destructive-command
     (list 'vip-open-line-at-point val ?r nil nil nil))
    (if (equal com ?r)
	(vip-loop val
		  (progn
		    (open-line 1)
		    (vip-yank-last-insertion)))
      (open-line 1)
      (vip-change-state-to-insert))))

(defun vip-substitute (arg)
  "Substitute characters."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (push-mark nil t)
    (forward-char val)
    (if (equal com ?r)
	(vip-change-subr (mark t) (point))
      (vip-change (mark t) (point)))
    (vip-set-destructive-command (list 'vip-substitute val ?r nil nil nil))
    ))

(defun vip-substitute-line (arg)
  "Substitute lines."
  (interactive "p")
  (vip-set-complex-command-for-undo)
  (vip-line (cons arg ?C)))

;; Prepare for replace
(defun vip-start-replace ()
  (setq vip-began-as-replace t
	vip-sitting-in-replace t
	vip-replace-chars-to-delete 0
	vip-replace-chars-deleted 0)
  (vip-add-hook 'vip-after-change-functions 'vip-replace-mode-spy-after t)
  (vip-add-hook 'vip-before-change-functions 'vip-replace-mode-spy-before t)
  ;; this will get added repeatedly, but no harm
  (add-hook 'after-change-functions 'vip-after-change-sentinel t)
  (add-hook 'before-change-functions 'vip-before-change-sentinel t)
  (vip-move-marker-locally 'vip-last-posn-in-replace-region
			   (vip-replace-start))
  (vip-add-hook
   'vip-post-command-hooks 'vip-replace-state-post-command-sentinel t)
  (vip-add-hook
   'vip-pre-command-hooks 'vip-replace-state-pre-command-sentinel t)
  ;; guard against a smartie who switched from R-replace to normal replace
  (vip-remove-hook
   'vip-post-command-hooks 'vip-R-state-post-command-sentinel)
  (if overwrite-mode (overwrite-mode nil))
  )
  

;; checks how many chars were deleted by the last change
(defun vip-replace-mode-spy-before (beg end)
  (setq vip-replace-chars-deleted
	(- end beg
	   (max 0 (- end (vip-replace-end)))
	   (max 0 (- (vip-replace-start) beg))
	   )))

;; Invoked as an after-change-function to set up parameters of the last change
(defun vip-replace-mode-spy-after (beg end length)
  (if (memq vip-intermediate-command '(repeating-insertion-from-ring))
      (progn
	(setq vip-replace-chars-to-delete 0)
	(vip-move-marker-locally 
	 'vip-last-posn-in-replace-region (point)))
    
    (let (beg-col end-col real-end chars-to-delete)
      (setq real-end (min end (vip-replace-end)))
      (save-excursion
	(goto-char beg)
	(setq beg-col (current-column))
	(goto-char real-end)
	(setq end-col (current-column)))
      
      ;; If beg of change is outside the replacement region, then don't
      ;; delete anything in the repl region (set chars-to-delete to 0).
      ;;
      ;; This works fine except that we have to take special care of
      ;; dabbrev-expand.  The problem stems from new-dabbrev.el, which
      ;; sometimes simply shifts the repl region rightwards, without
      ;; deleting an equal amount of characters.
      ;;
      ;; The reason why new-dabbrev.el causes this are this:
      ;; if one dinamically completes a partial word that starts before the
      ;; replacement region (but ends inside) then new-dabbrev.el first
      ;; moves cursor backwards, to the beginning of the word to be
      ;; completed (say, pt A). Then it inserts the 
      ;; completed word and then deletes the old, incomplete part.
      ;; Since the complete word is inserted at position before the repl
      ;; region, the next If-statement would have set chars-to-delete to 0
      ;; unless we check for the current command, which must be
      ;; dabbrev-expand.
      ;;
      ;; In fact, it might be also useful to have overlays for insert
      ;; regions as well, since this will let us capture the situation when
      ;; dabbrev-expand goes back past the insertion point to find the
      ;; beginning of the word to be expanded.
      (if (or (and (<= (vip-replace-start) beg)
		   (<= beg (vip-replace-end)))
	      (and (= length 0) (eq this-command 'dabbrev-expand)))
	  (setq chars-to-delete
		(max (- end-col beg-col) (- real-end beg) 0))
	(setq chars-to-delete 0))
      
      ;; if beg = last change position, it means that we are within the
      ;; same command that does multiple changes. Moreover, it means
      ;; that we have two subsequent changes (insert/delete) that
      ;; complement each other.
      (if (= beg (marker-position vip-last-posn-in-replace-region))
	  (setq vip-replace-chars-to-delete 
		(- (+ chars-to-delete vip-replace-chars-to-delete)
		   vip-replace-chars-deleted)) 
	(setq vip-replace-chars-to-delete chars-to-delete))
      
      (vip-move-marker-locally 
       'vip-last-posn-in-replace-region
       (max (if (> end (vip-replace-end)) (vip-replace-start) end)
	    (or (marker-position vip-last-posn-in-replace-region)
		(vip-replace-start)) 
	    ))
      
      (setq vip-replace-chars-to-delete
	    (max 0
		 (min vip-replace-chars-to-delete
		      (- (vip-replace-end) vip-last-posn-in-replace-region)
		      (- (vip-line-pos 'end) vip-last-posn-in-replace-region)
		      )))
      )))


;; Delete stuff between posn and the end of vip-replace-overlay-marker, if
;; posn is within the overlay.
(defun vip-finish-change (posn)
  (vip-remove-hook 'vip-after-change-functions 'vip-replace-mode-spy-after)
  (vip-remove-hook 'vip-before-change-functions 'vip-replace-mode-spy-before)
  (vip-remove-hook 'vip-post-command-hooks
		   'vip-replace-state-post-command-sentinel) 
  (vip-remove-hook
   'vip-pre-command-hooks 'vip-replace-state-pre-command-sentinel) 
  (vip-restore-cursor-color-after-replace)
  (setq vip-sitting-in-replace nil) ; just in case we'll need to know it
  (save-excursion
    (if (and 
	 vip-replace-overlay
	 (>= posn (vip-replace-start))
	 (<  posn (vip-replace-end)))
	   (delete-region posn (vip-replace-end)))
    )
  
  (if (eq vip-current-state 'replace-state)
      (vip-downgrade-to-insert))
  ;; replace mode ended => nullify vip-last-posn-in-replace-region
  (vip-move-marker-locally 'vip-last-posn-in-replace-region nil)
  (vip-hide-replace-overlay)
  (vip-refresh-mode-line)
  (vip-put-string-on-kill-ring vip-last-replace-region)
  )

;; Make STRING be the first element of the kill ring.
(defun vip-put-string-on-kill-ring (string)
  (setq kill-ring (cons string kill-ring))
  (if (> (length kill-ring) kill-ring-max)
      (setcdr (nthcdr (1- kill-ring-max) kill-ring) nil))
  (setq kill-ring-yank-pointer kill-ring))

(defun vip-finish-R-mode ()
  (vip-remove-hook 'vip-post-command-hooks 'vip-R-state-post-command-sentinel)
  (vip-remove-hook
   'vip-pre-command-hooks 'vip-replace-state-pre-command-sentinel)
  (vip-downgrade-to-insert))
  
(defun vip-start-R-mode ()
  ;; Leave arg as 1, not t: XEmacs insists that it must be a pos number
  (overwrite-mode 1)
  (vip-add-hook
   'vip-post-command-hooks 'vip-R-state-post-command-sentinel t)
  (vip-add-hook
   'vip-pre-command-hooks 'vip-replace-state-pre-command-sentinel t)
  ;; guard against a smartie who switched from R-replace to normal replace
  (vip-remove-hook
   'vip-post-command-hooks 'vip-replace-state-post-command-sentinel)
  )


  
(defun vip-replace-state-exit-cmd ()
  "Binding for keys that cause Replace state to switch to Vi or to Insert.
These keys are ESC, RET, and LineFeed"
  (interactive)
  (if overwrite-mode  ;; If you are in replace mode invoked via 'R'
      (vip-finish-R-mode)
    (vip-finish-change vip-last-posn-in-replace-region))
  (let (com)
    (if (eq this-command 'vip-intercept-ESC-key)
	(setq com 'vip-exit-insert-state)
      (vip-set-unread-command-events last-input-char)
      (setq com (key-binding (read-key-sequence nil))))
      
    (condition-case conds
	(command-execute com)
      (error
       (vip-message-conditions conds)))
    )
  (vip-hide-replace-overlay))

(defun vip-replace-state-carriage-return ()
  "Implements carriage return in Viper replace state."
  (interactive)
  ;; If Emacs start supporting overlay maps, as it currently supports
  ;; text-property maps, we could do away with vip-replace-minor-mode and
  ;; just have keymap attached to replace overlay. Then the "if part" of this
  ;; statement can be deleted.
  (if (or (< (point) (vip-replace-start))
	  (> (point) (vip-replace-end)))
      (let (vip-replace-minor-mode com)
	(vip-set-unread-command-events last-input-char)
	(setq com (key-binding (read-key-sequence nil)))
	(condition-case conds
	    (command-execute com)
	  (error
	   (vip-message-conditions conds))))
    (if (not vip-allow-multiline-replace-regions)
	(vip-replace-state-exit-cmd)
      (if (vip-same-line (point) (vip-replace-end))
	  (vip-replace-state-exit-cmd)
	(vip-kill-line nil)
	(vip-next-line-at-bol nil)))))

  
;; This is the function bound to 'R'---unlimited replace.
;; Similar to Emacs's own overwrite-mode.
(defun vip-overwrite (arg) 
  "Begin overwrite mode."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)) (len))
    (vip-set-destructive-command (list 'vip-overwrite val ?r nil nil nil))
    (if com
	(progn 
	  ;; Viper saves inserted text in vip-last-insertion
	  (setq len (length vip-last-insertion))
	  (delete-char len)	
	  (vip-loop val (vip-yank-last-insertion)))
      (setq last-command 'vip-overwrite)
      (vip-set-complex-command-for-undo)
      (vip-set-replace-overlay (point) (vip-line-pos 'end))
      (vip-change-state-to-replace)
      )))


;; line commands

(defun vip-line (arg)
  (let ((val (car arg))
	(com (cdr arg)))
    (vip-move-marker-locally 'vip-com-point (point))
    (if (not (eobp))
	(vip-next-line-carefully (1- val)))
    ;; this ensures that dd, cc, D, yy will do the right thing on the last
    ;; line of buffer when this line has no \n.
    (vip-add-newline-at-eob-if-necessary)
    (vip-execute-com 'vip-line val com))
  (if (and (eobp) (not (bobp))) (forward-line -1))
  )

(defun vip-yank-line (arg)
  "Yank ARG lines (in Vi's sense)."
  (interactive "P")
  (let ((val (vip-p-val arg)))
    (vip-line (cons val ?Y))))


;; region commands

(defun vip-region (arg)
  "Execute command on a region."
  (interactive "P")
  (let ((val (vip-P-val arg))
	(com (vip-getcom arg)))
    (vip-move-marker-locally 'vip-com-point (point))
    (exchange-point-and-mark)
    (vip-execute-com 'vip-region val com)))

(defun vip-Region (arg)
  "Execute command on a Region."
  (interactive "P")
  (let ((val (vip-P-val arg))
	(com (vip-getCom arg)))
    (vip-move-marker-locally 'vip-com-point (point))
    (exchange-point-and-mark)
    (vip-execute-com 'vip-Region val com)))

(defun vip-replace-char (arg)
  "Replace the following ARG chars by the character read."
  (interactive "P")
  (if (and (eolp) (bolp)) (error "No character to replace here"))
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (vip-replace-char-subr com val)
    (if (and (eolp) (not (bolp))) (forward-char 1))
    (vip-set-destructive-command
     (list 'vip-replace-char val ?r nil vip-d-char nil))
  ))

(defun vip-replace-char-subr (com arg)
  (let ((take-care-of-iso-accents
	 (and (boundp 'iso-accents-mode) vip-automatic-iso-accents))
	char)
    (setq char (if (equal com ?r)
		   vip-d-char
		 (read-char)))
    (if (and  take-care-of-iso-accents (memq char '(?' ?\" ?^ ?~)))
	;; get European characters
	(progn
	  (iso-accents-mode 1)
	  (vip-set-unread-command-events char)
	  (setq char (aref (read-key-sequence nil) 0))
	  (iso-accents-mode -1)))
    (delete-char arg t)
    (setq vip-d-char char)
    (vip-loop (if (> arg 0) arg (- arg)) 
	    (if (eq char ?\C-m) (insert "\n") (insert char)))
    (backward-char arg)))


;; basic cursor movement.  j, k, l, h commands.

(defun vip-forward-char (arg)
  "Move point right ARG characters (left if ARG negative).
On reaching end of line, stop and signal error."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (if vip-ex-style-motion
	(progn
	  ;; the boundary condition check gets weird here because
	  ;; forward-char may be the parameter of a delete, and 'dl' works
	  ;; just like 'x' for the last char on a line, so we have to allow
	  ;; the forward motion before the 'vip-execute-com', but, of
	  ;; course, 'dl' doesn't work on an empty line, so we have to
	  ;; catch that condition before 'vip-execute-com'
	  (if (and (eolp) (bolp)) (error "") (forward-char val))
	  (if com (vip-execute-com 'vip-forward-char val com))
	  (if (eolp) (progn (backward-char 1) (error ""))))
      (forward-char val)
      (if com (vip-execute-com 'vip-forward-char val com)))))

(defun vip-backward-char (arg)
  "Move point left ARG characters (right if ARG negative). 
On reaching beginning of line, stop and signal error."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (if vip-ex-style-motion
	(progn
	  (if (bolp) (error "") (backward-char val))
	  (if com (vip-execute-com 'vip-backward-char val com)))
      (backward-char val)
      (if com (vip-execute-com 'vip-backward-char val com)))))
      
;; Like forward-char, but doesn't move at end of buffer.
(defun vip-forward-char-carefully (&optional arg)      
  (setq arg (or arg 1))
  (if (>= (point-max) (+ (point) arg))
      (forward-char arg)
    (goto-char (point-max))))
      
;; Like backward-char, but doesn't move at end of buffer.
(defun vip-backward-char-carefully (&optional arg)      
  (setq arg (or arg 1))
  (if (<= (point-min) (- (point) arg))
      (backward-char arg)
    (goto-char (point-min))))

(defun vip-next-line-carefully (arg)
  (condition-case nil
      (next-line arg)
    (error nil)))



;;; Word command

;; Words are formed from alpha's and nonalphas - <sp>,\t\n are separators
;; for word movement. When executed with a destructive command, \n is
;; usually left untouched for the last word.
;; Viper uses syntax table to determine what is a word and what is a
;; separator. However, \n is always a separator. Also, if vip-syntax-preference
;; is 'vi, then `_' is part of the word.

;; skip only one \n
(defun vip-skip-separators (forward)
  (if forward
      (progn
	(vip-skip-all-separators-forward 'within-line)
	(if (looking-at "\n")
	    (progn
	      (forward-char)
	      (vip-skip-all-separators-forward  'within-line))))
    (vip-skip-all-separators-backward 'within-line)
    (backward-char)
    (if (looking-at "\n")
	(vip-skip-all-separators-backward 'within-line)
      (forward-char))))
      
(defun vip-forward-word-kernel (val)
  (while (> val 0)
    (cond ((vip-looking-at-alpha)
	   (vip-skip-alpha-forward "_")
	   (vip-skip-separators t))
	  ((vip-looking-at-separator)
	   (vip-skip-separators t))
	  ((not (vip-looking-at-alphasep))
	   (vip-skip-nonalphasep-forward)
	   (vip-skip-separators t)))
    (setq val (1- val))))

;; first search backward for pat. Then skip chars backwards using aux-pat
(defun vip-fwd-skip (pat aux-pat lim)
  (if (and (save-excursion 
	     (re-search-backward pat lim t))
	   (= (point) (match-end 0)))
      (goto-char (match-beginning 0)))
  (skip-chars-backward aux-pat lim)
  (if (= (point) lim)
      (vip-forward-char-carefully))
  )

	  
(defun vip-forward-word (arg)
  "Forward word."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (vip-forward-word-kernel val)
    (if com (progn
	      (cond ((memq com (list ?c (- ?c)))
		     (vip-fwd-skip "\n[ \t]*" " \t" vip-com-point))
		    ;; Yank words including the whitespace, but not newline
		    ((memq com (list ?y (- ?y)))
		     (vip-fwd-skip "\n[ \t]*" "" vip-com-point))
		    ((vip-dotable-command-p com)
		     (vip-fwd-skip "\n[ \t]*" "" vip-com-point)))
	      (vip-execute-com 'vip-forward-word val com)))))
	  

(defun vip-forward-Word (arg)
  "Forward word delimited by white characters."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (vip-loop val
	      (progn
		(vip-skip-nonseparators 'forward)
		(vip-skip-separators t)))
    (if com (progn
	      (cond ((memq com (list ?c (- ?c)))
		     (vip-fwd-skip "\n[ \t]*" " \t" vip-com-point))
		    ;; Yank words including the whitespace, but not newline
		    ((memq com (list ?y (- ?y)))
		     (vip-fwd-skip "\n[ \t]*" "" vip-com-point))
		    ((vip-dotable-command-p com)
		     (vip-fwd-skip "\n[ \t]*" "" vip-com-point)))
	      (vip-execute-com 'vip-forward-Word val com)))))


;; this is a bit different from Vi, but Vi's end of word 
;; makes no sense whatsoever
(defun vip-end-of-word-kernel ()
  (if (vip-end-of-word-p) (forward-char))
  (if (vip-looking-at-separator)
      (vip-skip-all-separators-forward))
  
  (cond ((vip-looking-at-alpha) (vip-skip-alpha-forward "_"))
	((not (vip-looking-at-alphasep)) (vip-skip-nonalphasep-forward)))
  (vip-backward-char-carefully))

(defun vip-end-of-word-p ()
  (or (eobp) 
      (save-excursion
	(cond ((vip-looking-at-alpha)
	       (forward-char)
	       (not (vip-looking-at-alpha)))
	      ((not (vip-looking-at-alphasep))
	       (forward-char)
	       (vip-looking-at-alphasep))))))


(defun vip-end-of-word (arg &optional careful)
  "Move point to end of current word."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (vip-loop val (vip-end-of-word-kernel))
    (if com 
	(progn
	  (forward-char)
	  (vip-execute-com 'vip-end-of-word val com)))))

(defun vip-end-of-Word (arg)
  "Forward to end of word delimited by white character."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (vip-loop val
	      (progn
		(vip-end-of-word-kernel)
		(vip-skip-nonseparators 'forward)
		(backward-char)))
    (if com 
	(progn
	  (forward-char)
	  (vip-execute-com 'vip-end-of-Word val com)))))

(defun vip-backward-word-kernel (val)
  (while (> val 0)
    (backward-char)
    (cond ((vip-looking-at-alpha)
	   (vip-skip-alpha-backward "_"))
	  ((vip-looking-at-separator)
	   (forward-char)
	   (vip-skip-separators nil)
	   (backward-char)
	   (cond ((vip-looking-at-alpha)
		  (vip-skip-alpha-backward "_"))
		 ((not (vip-looking-at-alphasep))
		  (vip-skip-nonalphasep-backward))
		 (t (forward-char))))
	  ((not (vip-looking-at-alphasep))
	   (vip-skip-nonalphasep-backward)))
    (setq val (1- val))))

(defun vip-backward-word (arg)
  "Backward word."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com
	(let (i)
	  (if (setq i (save-excursion (backward-char) (looking-at "\n")))
	      (backward-char))
	  (vip-move-marker-locally 'vip-com-point (point))
	  (if i (forward-char))))
    (vip-backward-word-kernel val)
    (if com (vip-execute-com 'vip-backward-word val com))))

(defun vip-backward-Word (arg)
  "Backward word delimited by white character."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com
	(let (i)
	  (if (setq i (save-excursion (backward-char) (looking-at "\n")))
	      (backward-char))
	  (vip-move-marker-locally 'vip-com-point (point))
	  (if i (forward-char))))
    (vip-loop val
	      (progn 
		(vip-skip-separators nil)
		(vip-skip-nonseparators 'backward)))
    (if com (vip-execute-com 'vip-backward-Word val com))))



;; line commands

(defun vip-beginning-of-line (arg)
  "Go to beginning of line."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (beginning-of-line val)
    (if com (vip-execute-com 'vip-beginning-of-line val com))))

(defun vip-bol-and-skip-white (arg)
  "Beginning of line at first non-white character."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (forward-to-indentation (1- val))
    (if com (vip-execute-com 'vip-bol-and-skip-white val com))))

(defun vip-goto-eol (arg)
  "Go to end of line."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (end-of-line val)
    (if com (vip-execute-com 'vip-goto-eol val com))
    (if vip-ex-style-motion
	(if (and (eolp) (not (bolp)) 
		 ;; a fix for vip-change-to-eol
		 (not (equal vip-current-state 'insert-state)))
	    (backward-char 1)
    ))))


(defun vip-goto-col (arg)
  "Go to ARG's column."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg))
	line-len)
    (setq line-len (- (vip-line-pos 'end) (vip-line-pos 'start)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (beginning-of-line)
    (forward-char (1- (min line-len val)))
    (while (> (current-column) (1- val))
      (backward-char 1))
    (if com (vip-execute-com 'vip-goto-col val com))
    (save-excursion
      (end-of-line)
      (if (> val (current-column)) (error "")))
    ))
    

(defun vip-next-line (arg)
  "Go to next line."
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (next-line val)
    (if vip-ex-style-motion
	(if (and (eolp) (not (bolp))) (backward-char 1)))
    (setq this-command 'next-line)
    (if com (vip-execute-com 'vip-next-line val com))))

(defun vip-next-line-at-bol (arg)
  "Next line at beginning of line."
  (interactive "P")
  (vip-leave-region-active)
  (save-excursion
    (end-of-line)
    (if (eobp) (error "Last line in buffer")))
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (forward-line val)
    (back-to-indentation)
    (if com (vip-execute-com 'vip-next-line-at-bol val com))))

(defun vip-previous-line (arg)	 
  "Go to previous line."    	
  (interactive "P")
  (vip-leave-region-active)
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (previous-line val)
    (if vip-ex-style-motion
	(if (and (eolp) (not (bolp))) (backward-char 1)))
    (setq this-command 'previous-line)
    (if com (vip-execute-com 'vip-previous-line val com))))


(defun vip-previous-line-at-bol (arg)
  "Previous line at beginning of line."
  (interactive "P")
  (vip-leave-region-active)
  (save-excursion
    (beginning-of-line)
    (if (bobp) (error "First line in buffer")))
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (forward-line (- val))
    (back-to-indentation)
    (if com (vip-execute-com 'vip-previous-line val com))))

(defun vip-change-to-eol (arg)
  "Change to end of line."
  (interactive "P")
  (vip-goto-eol (cons arg ?c)))

(defun vip-kill-line (arg)
  "Delete line."
  (interactive "P")
  (vip-goto-eol (cons arg ?d)))

(defun vip-erase-line (arg)
  "Erase line."
  (interactive "P")
  (vip-beginning-of-line (cons arg ?d)))


;;; Moving around

(defun vip-goto-line (arg)
  "Go to ARG's line.  Without ARG go to end of buffer."
  (interactive "P")
  (let ((val (vip-P-val arg))
	(com (vip-getCom arg)))
    (vip-move-marker-locally 'vip-com-point (point))
    (vip-deactivate-mark)
    (push-mark nil t)
    (if (null val)
	(goto-char (point-max))
      (goto-char (point-min))
      (forward-line (1- val)))
    
    ;; positioning is done twice: before and after command execution
    (if (and (eobp) (bolp) (not (bobp))) (forward-line -1))
    (back-to-indentation)
    
    (if com (vip-execute-com 'vip-goto-line val com))
    
    (if (and (eobp) (bolp) (not (bobp))) (forward-line -1))
    (back-to-indentation)
    ))

;; Find ARG's occurrence of CHAR on the current line. 
;; If FORWARD then search is forward, otherwise backward.  OFFSET is used to
;; adjust point after search.
(defun vip-find-char (arg char forward offset)
  (or (char-or-string-p char) (error ""))
  (let ((arg (if forward arg (- arg)))
	(cmd (if (eq vip-intermediate-command 'vip-repeat)
		 (nth 5 vip-d-com)
	       (vip-array-to-string (this-command-keys))))
	point)
    (save-excursion
      (save-restriction
	(if (> arg 0)
	    (narrow-to-region
	     ;; forward search begins here
	     (if (eolp) (error "Command `%s':  At end of line" cmd) (point))
	     ;; forward search ends here
	     (progn (end-of-line) (point)))
	  (narrow-to-region
	   ;; backward search begins from here
	   (if (bolp)
	       (error "Command `%s':  At beginning of line" cmd) (point))
	   ;; backward search ends here
	   (progn (beginning-of-line) (point))))
	;; if arg > 0, point is forwarded before search.
	(if (> arg 0) (goto-char (1+ (point-min)))
	  (goto-char (point-max)))
	(if (let ((case-fold-search nil))
	      (search-forward (char-to-string char) nil 0 arg))
	    (setq point (point))
	  (error "Command `%s':  `%c' not found" cmd char))))
    (goto-char (+ point (if (> arg 0) (if offset -2 -1) (if offset 1 0))))))

(defun vip-find-char-forward (arg)
  "Find char on the line. 
If called interactively read the char to find from the terminal, and if
called from vip-repeat, the char last used is used.  This behaviour is
controlled by the sign of prefix numeric value."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg))
	(cmd-representation (nth 5 vip-d-com)))
    (if (> val 0)
	;; this means that the function was called interactively
	(setq vip-f-char (read-char)
	      vip-f-forward t
	      vip-f-offset nil)
      ;; vip-repeat --- set vip-F-char from command-keys
      (setq vip-F-char (if (stringp cmd-representation)
			   (vip-seq-last-elt cmd-representation)
			 vip-F-char)
	    vip-f-char vip-F-char)
      (setq val (- val)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (vip-find-char val (if (> (vip-p-val arg) 0) vip-f-char vip-F-char) t nil)
    (setq val (- val))
    (if com
	(progn
	  (setq vip-F-char vip-f-char) ; set new vip-F-char
	  (forward-char)
	  (vip-execute-com 'vip-find-char-forward val com)))))

(defun vip-goto-char-forward (arg)
  "Go up to char ARG forward on line."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg))
	(cmd-representation (nth 5 vip-d-com)))
    (if (> val 0)
	;; this means that the function was called interactively
	(setq vip-f-char (read-char)
	      vip-f-forward t
	      vip-f-offset t)
      ;; vip-repeat --- set vip-F-char from command-keys
      (setq vip-F-char (if (stringp cmd-representation)
			   (vip-seq-last-elt cmd-representation)
			 vip-F-char)
	    vip-f-char vip-F-char)
      (setq val (- val)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (vip-find-char val (if (> (vip-p-val arg) 0) vip-f-char vip-F-char) t t)
    (setq val (- val))
    (if com
	(progn
	  (setq vip-F-char vip-f-char) ; set new vip-F-char
	  (forward-char)
	  (vip-execute-com 'vip-goto-char-forward val com)))))

(defun vip-find-char-backward (arg)
  "Find char ARG on line backward."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg))
	(cmd-representation (nth 5 vip-d-com)))
    (if (> val 0)
	;; this means that the function was called interactively
	(setq vip-f-char (read-char)
	      vip-f-forward nil
	      vip-f-offset nil)
      ;; vip-repeat --- set vip-F-char from command-keys
      (setq vip-F-char (if (stringp cmd-representation)
			   (vip-seq-last-elt cmd-representation)
			 vip-F-char)
	    vip-f-char vip-F-char)
      (setq val (- val)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (vip-find-char
     val (if (> (vip-p-val arg) 0) vip-f-char vip-F-char) nil nil)
    (setq val (- val))
    (if com
	(progn
	  (setq vip-F-char vip-f-char) ; set new vip-F-char
	  (vip-execute-com 'vip-find-char-backward val com)))))

(defun vip-goto-char-backward (arg)
  "Go up to char ARG backward on line."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg))
	(cmd-representation (nth 5 vip-d-com)))
    (if (> val 0)
	;; this means that the function was called interactively
	(setq vip-f-char (read-char)
	      vip-f-forward nil
	      vip-f-offset t)
      ;; vip-repeat --- set vip-F-char from command-keys
      (setq vip-F-char (if (stringp cmd-representation)
			   (vip-seq-last-elt cmd-representation)
			 vip-F-char)
	    vip-f-char vip-F-char)
      (setq val (- val)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (vip-find-char val (if (> (vip-p-val arg) 0) vip-f-char vip-F-char) nil t)
    (setq val (- val))
    (if com
	(progn
	  (setq vip-F-char vip-f-char) ; set new vip-F-char
	  (vip-execute-com 'vip-goto-char-backward val com)))))

(defun vip-repeat-find (arg)
  "Repeat previous find command."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (vip-deactivate-mark)
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (vip-find-char val vip-f-char vip-f-forward vip-f-offset)
    (if com
	(progn
	  (if vip-f-forward (forward-char))
	  (vip-execute-com 'vip-repeat-find val com)))))

(defun vip-repeat-find-opposite (arg)
  "Repeat previous find command in the opposite direction."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (vip-deactivate-mark)
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (vip-find-char val vip-f-char (not vip-f-forward) vip-f-offset)
    (if com
	(progn
	  (if vip-f-forward (forward-char))
	  (vip-execute-com 'vip-repeat-find-opposite val com)))))


;; window scrolling etc.

(defun vip-other-window (arg)
  "Switch to other window."
  (interactive "p")
  (other-window arg)
  (or (not (eq vip-current-state 'emacs-state))
      (string= (buffer-name (current-buffer)) " *Minibuf-1*")
      (vip-change-state-to-vi)))

(defun vip-window-top (arg)
  "Go to home window line."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (push-mark nil t) 
    (move-to-window-line (1- val))

    ;; positioning is done twice: before and after command execution
    (if (and (eobp) (bolp) (not (bobp))) (forward-line -1))
    (back-to-indentation)
    
    (if com (vip-execute-com 'vip-window-top val com))
    
    (if (and (eobp) (bolp) (not (bobp))) (forward-line -1))
    (back-to-indentation)
    ))

(defun vip-window-middle (arg)
  "Go to middle window line."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg))
	lines)
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (push-mark nil t) 
    (if (not (pos-visible-in-window-p (point-max)))
	(move-to-window-line (+ (/ (1- (window-height)) 2) (1- val)))
      (setq lines (count-lines (window-start) (point-max)))
      (move-to-window-line (+ (/ lines 2) (1- val))))
      
    ;; positioning is done twice: before and after command execution
    (if (and (eobp) (bolp) (not (bobp))) (forward-line -1))
    (back-to-indentation)

    (if com (vip-execute-com 'vip-window-middle val com))
    
    (if (and (eobp) (bolp) (not (bobp))) (forward-line -1))
    (back-to-indentation)
    ))

(defun vip-window-bottom (arg)
  "Go to last window line."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (push-mark nil t) 
    (move-to-window-line (- val))
    
    ;; positioning is done twice: before and after command execution
    (if (and (eobp) (bolp) (not (bobp))) (forward-line -1))
    (back-to-indentation)

    (if com (vip-execute-com 'vip-window-bottom val com))
    
    (if (and (eobp) (bolp) (not (bobp))) (forward-line -1))
    (back-to-indentation)
    ))

(defun vip-line-to-top (arg)
  "Put current line on the home line."
  (interactive "p")
  (recenter (1- arg)))

(defun vip-line-to-middle (arg)
  "Put current line on the middle line."
  (interactive "p")
  (recenter (+ (1- arg) (/ (1- (window-height)) 2))))

(defun vip-line-to-bottom (arg)
  "Put current line on the last line."
  (interactive "p")
  (recenter (- (window-height) (1+ arg))))

;; If point is within vip-search-scroll-threshold of window top or bottom,
;; scroll up or down 1/7 of window height, depending on whether we are at the
;; bottom or at the top of the  window. This function is called by vip-search
;; (which is called from vip-search-forward/backward/next). If the value of
;; vip-search-scroll-threshold is negative - don't scroll.
(defun vip-adjust-window ()
  (let ((win-height (if vip-emacs-p
			(1- (window-height)) ; adjust for modeline
		      (window-displayed-height)))
	(pt (point))
	at-top-p at-bottom-p
	min-scroll direction)
    (save-excursion
      (move-to-window-line 0) ; top
      (setq at-top-p
	    (<= (count-lines pt (point))
		vip-search-scroll-threshold))
      (move-to-window-line -1) ; bottom
      (setq at-bottom-p
	    (<= (count-lines pt (point)) vip-search-scroll-threshold))
      )
    (cond (at-top-p (setq min-scroll (1- vip-search-scroll-threshold)
			  direction  1))
	  (at-bottom-p (setq min-scroll (1+ vip-search-scroll-threshold)
			     direction -1)))
    (if min-scroll
	(recenter
	 (* (max min-scroll (/ win-height 7)) direction)))
    ))


;; paren match
;; must correct this to only match ( to ) etc. On the other hand
;; it is good that paren match gets confused, because that way you
;; catch _all_ imbalances. 

(defun vip-paren-match (arg)
  "Go to the matching parenthesis."
  (interactive "P")
  (vip-leave-region-active)
  (let ((com (vip-getcom arg))
	(parse-sexp-ignore-comments vip-parse-sexp-ignore-comments)
	anchor-point)
    (if (integerp arg)
	(if (or (> arg 99) (< arg 1))
	    (error "Prefix must be between 1 and 99")
	  (goto-char
	   (if (> (point-max) 80000)
	       (* (/ (point-max) 100) arg)
	     (/ (* (point-max) arg) 100)))
	  (back-to-indentation))
      (let (beg-lim end-lim)
	(if (and (eolp) (not (bolp))) (forward-char -1))
	(if (not (looking-at "[][(){}]"))
	    (setq anchor-point (point)))
	(save-excursion
	  (beginning-of-line)
	  (setq beg-lim (point))
	  (end-of-line)
	  (setq end-lim (point)))
	(cond ((re-search-forward "[][(){}]" end-lim t) 
	       (backward-char) )
	      ((re-search-backward "[][(){}]" beg-lim t))
	      (t
	       (error "No matching character on line"))))
      (cond ((looking-at "[\(\[{]")
	     (if com (vip-move-marker-locally 'vip-com-point (point)))
	     (forward-sexp 1)
	     (if com
		 (vip-execute-com 'vip-paren-match nil com)
	       (backward-char)))
	    (anchor-point
	     (if com
		 (progn
		   (vip-move-marker-locally 'vip-com-point anchor-point)
		   (forward-char 1)
		   (vip-execute-com 'vip-paren-match nil com)
		   )))
	    ((looking-at "[])}]")
	     (forward-char)
	     (if com (vip-move-marker-locally 'vip-com-point (point)))
	     (backward-sexp 1)
	     (if com (vip-execute-com 'vip-paren-match nil com)))
	    (t (error ""))))))

(defun vip-toggle-parse-sexp-ignore-comments ()
  (interactive)
  (setq vip-parse-sexp-ignore-comments (not vip-parse-sexp-ignore-comments))
  (princ (format
	  "From now on, `%%' will %signore parentheses inside comment fields"
	  (if vip-parse-sexp-ignore-comments "" "NOT "))))


;; sentence ,paragraph and heading

(defun vip-forward-sentence (arg)
  "Forward sentence."
  (interactive "P")
  (push-mark nil t) 
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (forward-sentence val)
    (if com (vip-execute-com 'vip-forward-sentence nil com))))

(defun vip-backward-sentence (arg)
  "Backward sentence."
  (interactive "P")
  (push-mark nil t) 
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (backward-sentence val)
    (if com (vip-execute-com 'vip-backward-sentence nil com))))

(defun vip-forward-paragraph (arg)
  "Forward paragraph."
  (interactive "P")
  (push-mark nil t) 
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (forward-paragraph val)
    (if com
	(progn
	  (backward-char 1)
	  (vip-execute-com 'vip-forward-paragraph nil com)))))

(defun vip-backward-paragraph (arg)
  "Backward paragraph."
  (interactive "P")
  (push-mark nil t) 
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (backward-paragraph val)
    (if com
	(progn
	  (forward-char 1)
	  (vip-execute-com 'vip-backward-paragraph nil com)
	  (backward-char 1)))))

;; should be mode-specific etc.

(defun vip-prev-heading (arg)
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (re-search-backward vip-heading-start nil t val)
    (goto-char (match-beginning 0))
    (if com (vip-execute-com 'vip-prev-heading nil com))))

(defun vip-heading-end (arg)
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (re-search-forward vip-heading-end nil t val)
    (goto-char (match-beginning 0))
    (if com (vip-execute-com 'vip-heading-end nil com))))

(defun vip-next-heading (arg)
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getCom arg)))
    (if com (vip-move-marker-locally 'vip-com-point (point)))
    (end-of-line)
    (re-search-forward vip-heading-start nil t val)
    (goto-char (match-beginning 0))
    (if com (vip-execute-com 'vip-next-heading nil com))))


;; scrolling

(defun vip-scroll-screen (arg)
  "Scroll to next screen."
  (interactive "p")
  (condition-case nil
      (if (> arg 0)
	  (while (> arg 0)
	    (scroll-up)
	    (setq arg (1- arg)))
	(while (> 0 arg)
	  (scroll-down)
	  (setq arg (1+ arg))))
    (error (beep 1)
	   (if (> arg 0)
	       (progn
		 (message "End of buffer")
		 (goto-char (point-max)))
	     (message "Beginning of buffer")
	     (goto-char (point-min))))
    ))

(defun vip-scroll-screen-back (arg)
  "Scroll to previous screen."
  (interactive "p")
  (vip-scroll-screen (- arg)))

(defun vip-scroll-down (arg)
  "Pull down half screen."
  (interactive "P")
  (condition-case nil
      (if (null arg)
	  (scroll-down (/ (window-height) 2))
	(scroll-down arg))
    (error (beep 1)
	   (message "Beginning of buffer")
	   (goto-char (point-min)))))

(defun vip-scroll-down-one (arg)
  "Scroll up one line."
  (interactive "p")
  (scroll-down arg))

(defun vip-scroll-up (arg)
  "Pull up half screen."
  (interactive "P")
  (condition-case nil
      (if (null arg)
	  (scroll-up (/ (window-height) 2))
	(scroll-up arg))
    (error (beep 1)
	   (message "End of buffer")
	   (goto-char (point-max)))))

(defun vip-scroll-up-one (arg)
  "Scroll down one line."
  (interactive "p")
  (scroll-up arg))


;; searching

(defun vip-if-string (prompt)
  (let ((s (vip-read-string-with-history
	    prompt
	    nil ; no initial
	    'vip-search-history
	    (car vip-search-history))))
    (if (not (string= s ""))
	(setq vip-s-string s))))  
	
    
(defun vip-toggle-search-style (arg) 
  "Toggle the value of vip-case-fold-search/vip-re-search.
Without prefix argument, will ask which search style to toggle. With prefix
arg 1,toggles vip-case-fold-search; with arg 2 toggles vip-re-search.

Although this function is bound to \\[vip-toggle-search-style], the most
convenient way to use it is to bind `//' to the macro
`1 M-x vip-toggle-search-style' and `///' to
`2 M-x vip-toggle-search-style'. In this way, hitting `//' quickly will
toggle case-fold-search and hitting `/' three times witth toggle regexp
search. Macros are more convenient in this case because they don't affect
the Emacs binding of `/'."
  (interactive "P")
  (let (msg)
    (cond ((or (eq arg 1)
	       (and (null arg)
		    (y-or-n-p (format "Search style: '%s'. Want '%s'? "
				      (if vip-case-fold-search
					  "case-insensitive" "case-sensitive")
				      (if vip-case-fold-search
					  "case-sensitive"
					"case-insensitive")))))
	   (setq vip-case-fold-search (null vip-case-fold-search))
	   (if vip-case-fold-search
	       (setq msg "Search becomes case-insensitive")
	     (setq msg "Search becomes case-sensitive")))
	  ((or (eq arg 2)
	       (and (null arg)
		    (y-or-n-p (format "Search style: '%s'. Want '%s'? "
				      (if vip-re-search
					  "regexp-search" "vanilla-search")
				      (if vip-re-search
					  "vanilla-search"
					"regexp-search")))))
	   (setq vip-re-search (null vip-re-search))
	   (if vip-re-search
	       (setq msg "Search becomes regexp-style")
	     (setq msg "Search becomes vanilla-style")))
	  (t
	   (setq msg "Search style remains unchanged")))
    (princ msg t)))

(defun vip-set-searchstyle-toggling-macros (unset)
  "Set the macros for toggling the search style in Viper's vi-state.
The macro that toggles case sensitivity is bound to `//', and the one that
toggles regexp search is bound to `///'.
With a prefix argument, this function unsets the macros. "
  (interactive "P")
  (or noninteractive
      (if (not unset)
	  (progn
	    ;; toggle case sensitivity in search
	    (vip-record-kbd-macro
	     "//" 'vi-state
	     [1 (meta x) v i p - t o g g l e - s e a r c h - s t y l e return]
	     't)
	    ;; toggle regexp/vanila search
	    (vip-record-kbd-macro
	     "///" 'vi-state
	     [2 (meta x) v i p - t o g g l e - s e a r c h - s t y l e return]
	     't)
	    (if (interactive-p)
		(message
		 "// and /// now toggle case-sensitivity and regexp search")))
	(vip-unrecord-kbd-macro "//" 'vi-state)
	(sit-for 2)
	(vip-unrecord-kbd-macro "///" 'vi-state))))


(defun vip-set-parsing-style-toggling-macro (unset)
  "Set `%%%' to be a macro that toggles whether comment fields should be parsed for matching parentheses.
This is used in conjunction with the `%' command.

With a prefix argument, unsets the macro."
  (interactive "P")
  (or noninteractive
      (if (not unset)
	  (progn
	    ;; Make %%% toggle parsing comments for matching parentheses
	    (vip-record-kbd-macro
	     "%%%" 'vi-state
	     [(meta x) v i p - t o g g l e - p a r s e - s e x p - i g n o r e - c o m m e n t s return]
	     't)
	    (if (interactive-p)
		(message
		 "%%%%%% now toggles whether comments should be parsed for matching parentheses")))
	(vip-unrecord-kbd-macro "%%%" 'vi-state))))


(defun vip-set-emacs-state-searchstyle-macros (unset &optional arg-majormode)
  "Set the macros for toggling the search style in Viper's emacs-state.
The macro that toggles case sensitivity is bound to `//', and the one that
toggles regexp search is bound to `///'.
With a prefix argument, this function unsets the macros. 
If the optional prefix argument is non-nil and specifies a valid major mode,
this sets the macros only in the macros in that major mode. Otherwise,
the macros are set in the current major mode.
\(When unsetting the macros, the second argument has no effect.\)"
  (interactive "P")
  (or noninteractive
      (if (not unset)
	  (progn
	    ;; toggle case sensitivity in search
	    (vip-record-kbd-macro
	     "//" 'emacs-state
	     [1 (meta x) v i p - t o g g l e - s e a r c h - s t y l e return] 
	     (or arg-majormode major-mode))
	    ;; toggle regexp/vanila search
	    (vip-record-kbd-macro
	     "///" 'emacs-state
	     [2 (meta x) v i p - t o g g l e - s e a r c h - s t y l e return]
	     (or arg-majormode major-mode))
	    (if (interactive-p)
		(message
		 "// and /// now toggle case-sensitivity and regexp search.")))
	(vip-unrecord-kbd-macro "//" 'emacs-state)
	(sit-for 2)
	(vip-unrecord-kbd-macro "///" 'emacs-state))))


(defun vip-search-forward (arg)
  "Search a string forward. 
ARG is used to find the ARG's occurrence of the string.
Null string will repeat previous search."
  (interactive "P")
  (let ((val (vip-P-val arg))
	(com (vip-getcom arg))
	(old-str vip-s-string))
    (setq vip-s-forward t)
    (vip-if-string "/")
    ;; this is not used at present, but may be used later
    (if (or (not (equal old-str vip-s-string))
	    (not (markerp vip-local-search-start-marker))
	    (not (marker-buffer vip-local-search-start-marker)))
	(setq vip-local-search-start-marker (point-marker)))
    (vip-search vip-s-string t val)
    (if com
	(progn
	  (vip-move-marker-locally 'vip-com-point (mark t))
	  (vip-execute-com 'vip-search-next val com)))))

(defun vip-search-backward (arg)
  "Search a string backward. 
ARG is used to find the ARG's occurrence of the string.
Null string will repeat previous search."
  (interactive "P")
  (let ((val (vip-P-val arg))
	(com (vip-getcom arg))
	(old-str vip-s-string))
    (setq vip-s-forward nil)
    (vip-if-string "?")
    ;; this is not used at present, but may be used later
    (if (or (not (equal old-str vip-s-string))
	    (not (markerp vip-local-search-start-marker))
	    (not (marker-buffer vip-local-search-start-marker)))
	(setq vip-local-search-start-marker (point-marker)))
    (vip-search vip-s-string nil val)
    (if com
	(progn
	  (vip-move-marker-locally 'vip-com-point (mark t))
	  (vip-execute-com 'vip-search-next val com)))))
	  

;; Search for COUNT's occurrence of STRING.
;; Search is forward if FORWARD is non-nil, otherwise backward.
;; INIT-POINT is the position where search is to start.
;; Arguments:
;;   (STRING FORW COUNT &optional NO-OFFSET INIT-POINT LIMIT FAIL-IF-NOT-FOUND)
(defun vip-search (string forward arg
			  &optional no-offset init-point fail-if-not-found)
  (if (not (equal string ""))
    (let ((val (vip-p-val arg))
	  (com (vip-getcom arg))
	  (offset (not no-offset))
	  (case-fold-search vip-case-fold-search)
	  (start-point (or init-point (point))))
      (vip-deactivate-mark)
      (if forward
	  (condition-case nil
	      (progn
	        (if offset (vip-forward-char-carefully))
	        (if vip-re-search
		    (progn
		      (re-search-forward string nil nil val)
		      (re-search-backward string))
		  (search-forward string nil nil val)
		  (search-backward string))
		(if (not (equal start-point (point)))
		    (push-mark start-point t))) 
	    (search-failed
	     (if (and (not fail-if-not-found) vip-search-wrap-around-t)
	         (progn
		   (message "Search wrapped around BOTTOM of buffer")
		   (goto-char (point-min))
		   (vip-search string forward (cons 1 com) t start-point 'fail)
		   ;; don't wait in macros
		   (or executing-kbd-macro (sit-for 2))
		   ;; delete the wrap-around message
		   (message "")
		   )
	       (goto-char start-point)
	       (error "`%s': %s not found"
		      string
		      (if vip-re-search "Pattern" "String"))
	       )))
	;; backward
        (condition-case nil
	    (progn
	      (if vip-re-search
		  (re-search-backward string nil nil val)
	        (search-backward string nil nil val))
	      (if (not (equal start-point (point)))
		  (push-mark start-point t))) 
	  (search-failed
	   (if (and (not fail-if-not-found) vip-search-wrap-around-t)
	       (progn
		 (message "Search wrapped around TOP of buffer")
	         (goto-char (point-max))
	         (vip-search string forward (cons 1 com) t start-point 'fail)
		 ;; don't wait in macros
		 (or executing-kbd-macro (sit-for 2))
		 ;; delete the wrap-around message
		 (message "")
		 )
	     (goto-char start-point)
	     (error "`%s': %s not found"
		    string
		    (if vip-re-search "Pattern" "String"))
	     ))))
      ;; pull up or down if at top/bottom of window
      (vip-adjust-window)
      ;; highlight the result of search
      ;; don't wait and don't highlight in macros
      (or executing-kbd-macro
	  vip-inside-command-argument-action
	  (vip-flash-search-pattern))
      )))

(defun vip-search-next (arg)
  "Repeat previous search."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if (null vip-s-string) (error vip-NoPrevSearch))
    (vip-search vip-s-string vip-s-forward arg)
    (if com
	(progn
	  (vip-move-marker-locally 'vip-com-point (mark t))
	  (vip-execute-com 'vip-search-next val com)))))

(defun vip-search-Next (arg)
  "Repeat previous search in the reverse direction."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(com (vip-getcom arg)))
    (if (null vip-s-string) (error vip-NoPrevSearch))
    (vip-search vip-s-string (not vip-s-forward) arg)
    (if com
	(progn
	  (vip-move-marker-locally 'vip-com-point (mark t))
	  (vip-execute-com 'vip-search-Next val com)))))


;; Search contents of buffer defined by one of Viper's motion commands.
;; Repeatable via `n' and `N'.
(defun vip-buffer-search-enable (&optional c)
  (cond (c (setq vip-buffer-search-char c))
	((null vip-buffer-search-char)
	 (setq vip-buffer-search-char ?g)))
  (define-key vip-vi-basic-map
    (char-to-string vip-buffer-search-char) 'vip-command-argument)
  (aset vip-exec-array vip-buffer-search-char 'vip-exec-buffer-search)
  (setq vip-prefix-commands (cons vip-buffer-search-char vip-prefix-commands)))

;; This is a Viper wraper for isearch-forward.
(defun vip-isearch-forward (arg)
  "Do incremental search forward."
  (interactive "P")
  ;; emacs bug workaround
  (if (listp arg) (setq arg (car arg)))
  (vip-exec-form-in-emacs (list 'isearch-forward arg)))

;; This is a Viper wraper for isearch-backward."
(defun vip-isearch-backward (arg)
  "Do incremental search backward."
  (interactive "P")
  ;; emacs bug workaround
  (if (listp arg) (setq arg (car arg)))
  (vip-exec-form-in-emacs (list 'isearch-backward arg)))


;; visiting and killing files, buffers

(defun vip-switch-to-buffer ()
  "Switch to buffer in the current window."
  (interactive)
  (let (buffer)
    (setq buffer
	  (read-buffer
	   (format "Switch to buffer in this window \(%s\): "
		   (buffer-name (other-buffer (current-buffer))))))
    (switch-to-buffer buffer)
    ))

(defun vip-switch-to-buffer-other-window ()
  "Switch to buffer in another window."
  (interactive)
  (let (buffer)
    (setq buffer
	  (read-buffer
	   (format "Switch to buffer in another window \(%s\): "
		   (buffer-name (other-buffer (current-buffer))))))
    (switch-to-buffer-other-window buffer)
    ))

(defun vip-kill-buffer ()
  "Kill a buffer."
  (interactive)
  (let (buffer buffer-name)
    (setq buffer-name
	  (read-buffer
	   (format "Kill buffer \(%s\): "
		   (buffer-name (current-buffer)))))
    (setq buffer
	  (if (null buffer-name)
	      (current-buffer)
	    (get-buffer buffer-name)))
    (if (null buffer) (error "`%s': No such buffer" buffer-name))
    (if (or (not (buffer-modified-p buffer))
	    (y-or-n-p 
	     (format
	      "Buffer `%s' is modified, are you sure you want to kill it? "
	      buffer-name)))
	(kill-buffer buffer)
      (error "Buffer not killed"))))


(defcustom vip-smart-suffix-list
  '("" "tex" "c" "cc" "C" "el" "java" "html" "htm" "pl" "P" "p")
  "*List of suffixes that Viper automatically tries to append to filenames ending with a `.'.
This is useful when you the current directory contains files with the same
prefix and many different suffixes. Usually, only one of the suffixes
represents an editable file. However, file completion will stop at the `.'
The smart suffix feature lets you hit RET in such a case, and Viper will
select the appropriate suffix.

Suffixes are tried in the order given and the first suffix for which a
corresponding file exists is selected. If no file exists for any of the
suffixes, the user is asked to confirm.

To turn this feature off, set this variable to nil."
  :type '(set string)
  :group 'viper)
    
;; Try to add suffix to files ending with a `.'
;; Useful when the user hits RET on a non-completed file name.
(defun vip-file-add-suffix ()
  (let ((count 0)
	(len (length vip-smart-suffix-list))
	(file (buffer-string))
	found key cmd suff)
    (goto-char (point-max))
    (if (and vip-smart-suffix-list (string-match "\\.$" file))
	(progn
	  (while (and (not found) (< count len))
	    (setq suff (nth count vip-smart-suffix-list)
		  count (1+ count))
	    (if (file-exists-p (format "%s%s" file suff))
		(progn
		  (setq found t)
		  (insert suff))))
      
	  (if found
	      ()
	    (vip-tmp-insert-at-eob " [Please complete file name]")
	    (unwind-protect 
		(while (not (memq cmd '(exit-minibuffer vip-exit-minibuffer)))
		  (setq cmd
			(key-binding (setq key (read-key-sequence nil))))
		  (cond ((eq cmd 'self-insert-command)
			 (if vip-xemacs-p
			     (insert (events-to-keys key))
			   (insert key)))
			((memq cmd '(exit-minibuffer vip-exit-minibuffer))
			 nil)
			(t (command-execute cmd)))
		  )))
	      ))
    ))


     

;; yank and pop

(defsubst vip-yank (text)
  "Yank TEXT silently. This works correctly with Emacs's yank-pop command."
    (insert text)
    (setq this-command 'yank))

(defun vip-put-back (arg)
  "Put back after point/below line."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(text (if vip-use-register
		  (cond ((vip-valid-register vip-use-register '(digit))
			 (current-kill (- vip-use-register ?1) 'do-not-rotate))
			((vip-valid-register vip-use-register)
			 (get-register (downcase vip-use-register)))
			(t (error vip-InvalidRegister vip-use-register)))
		(current-kill 0))))
    (if (null text)
	(if vip-use-register
	    (let ((reg vip-use-register))
	      (setq vip-use-register nil)
	      (error vip-EmptyRegister reg))
	  (error "")))
    (setq vip-use-register nil)
    (if (vip-end-with-a-newline-p text)
	(progn
	  (end-of-line)
	  (if (eobp)
	      (insert "\n")
	    (forward-line 1))
	  (beginning-of-line))
      (if (not (eolp)) (vip-forward-char-carefully)))
    (set-marker (vip-mark-marker) (point) (current-buffer))
    (vip-set-destructive-command
     (list 'vip-put-back val nil vip-use-register nil nil))
    (vip-loop val (vip-yank text)))
  ;; Vi puts cursor on the last char when the yanked text doesn't contain a
  ;; newline; it leaves the cursor at the beginning when the text contains 
  ;; a newline
  (if (vip-same-line (point) (mark))
      (or (= (point) (mark)) (vip-backward-char-carefully))
    (exchange-point-and-mark)
    (if (bolp)
	(back-to-indentation)))
  (vip-deactivate-mark))

(defun vip-Put-back (arg)
  "Put back at point/above line."
  (interactive "P")
  (let ((val (vip-p-val arg))
	(text (if vip-use-register
		  (cond ((vip-valid-register vip-use-register '(digit))
			 (current-kill (- vip-use-register ?1) 'do-not-rotate))
			((vip-valid-register vip-use-register)
			 (get-register (downcase vip-use-register)))
			(t (error vip-InvalidRegister vip-use-register)))
		(current-kill 0))))
    (if (null text)
	(if vip-use-register
	    (let ((reg vip-use-register))
	      (setq vip-use-register nil)
	      (error vip-EmptyRegister reg))
	  (error "")))
    (setq vip-use-register nil)
    (if (vip-end-with-a-newline-p text) (beginning-of-line))
    (vip-set-destructive-command
     (list 'vip-Put-back val nil vip-use-register nil nil))
    (set-marker (vip-mark-marker) (point) (current-buffer))
    (vip-loop val (vip-yank text)))
  ;; Vi puts cursor on the last char when the yanked text doesn't contain a
  ;; newline; it leaves the cursor at the beginning when the text contains 
  ;; a newline
  (if (vip-same-line (point) (mark))
      (or (= (point) (mark)) (vip-backward-char-carefully))
    (exchange-point-and-mark)
    (if (bolp)
	(back-to-indentation)))
  (vip-deactivate-mark))
    

;; Copy region to kill-ring.
;; If BEG and END do not belong to the same buffer, copy empty region.
(defun vip-copy-region-as-kill (beg end)
  (condition-case nil
      (copy-region-as-kill beg end)
    (error (copy-region-as-kill beg beg))))
    

(defun vip-delete-char (arg)
  "Delete character."
  (interactive "P")
  (let ((val (vip-p-val arg)))
    (vip-set-destructive-command (list 'vip-delete-char val nil nil nil nil))
    (if (> val 1)
	(save-excursion
	  (let ((here (point)))
	    (end-of-line)
	    (if (> val (- (point) here))
		(setq val (- (point) here))))))
    (if (and (eq val 0) (not vip-ex-style-motion)) (setq val 1))
    (if (and vip-ex-style-motion (eolp))
	(if (bolp) (error "") (setq val 0))) ; not bol---simply back 1 ch
    (if vip-use-register
	(progn
	  (cond ((vip-valid-register vip-use-register '((Letter)))
		 (vip-append-to-register
		  (downcase vip-use-register) (point) (- (point) val)))
		((vip-valid-register vip-use-register)
		 (copy-to-register
		  vip-use-register (point) (- (point) val) nil))
		(t (error vip-InvalidRegister vip-use-register)))
	  (setq vip-use-register nil)))
    (if vip-ex-style-motion
	(progn
	  (delete-char val t)
	  (if (and (eolp) (not (bolp))) (backward-char 1)))
      (if (eolp)
          (delete-backward-char val t)
        (delete-char val t)))))

(defun vip-delete-backward-char (arg)
  "Delete previous character. On reaching beginning of line, stop and beep."
  (interactive "P")
  (let ((val (vip-p-val arg)))
    (vip-set-destructive-command
     (list 'vip-delete-backward-char val nil nil nil nil))
    (if (> val 1)
	(save-excursion
	  (let ((here (point)))
	    (beginning-of-line)
	    (if (> val (- here (point)))
		(setq val (- here (point)))))))
    (if vip-use-register
	(progn
	  (cond ((vip-valid-register vip-use-register '(Letter))
		 (vip-append-to-register
		  (downcase vip-use-register) (point) (+ (point) val)))
		((vip-valid-register vip-use-register)
		 (copy-to-register
		  vip-use-register (point) (+ (point) val) nil))
		(t (error vip-InvalidRegister vip-use-register)))
	  (setq vip-use-register nil)))
    (if (bolp) (ding)
      (delete-backward-char val t))))
      
(defun vip-del-backward-char-in-insert ()
  "Delete 1 char backwards while in insert mode."
  (interactive)      
  (if (and vip-ex-style-editing-in-insert (bolp))
      (beep 1)
    (delete-backward-char 1 t)))
      
(defun vip-del-backward-char-in-replace ()
  "Delete one character in replace mode.
If `vip-delete-backwards-in-replace' is t, then DEL key actually deletes
charecters. If it is nil, then the cursor just moves backwards, similarly
to Vi. The variable `vip-ex-style-editing-in-insert', if t, doesn't let the
cursor move past the beginning of line."
  (interactive)
  (cond (vip-delete-backwards-in-replace
	 (cond ((not (bolp))
		(delete-backward-char 1 t))
	       (vip-ex-style-editing-in-insert
		(beep 1))
	       ((bobp)
		(beep 1))
	       (t
		(delete-backward-char 1 t))))
	(vip-ex-style-editing-in-insert
	 (if (bolp)
	     (beep 1)
	   (backward-char 1)))
	(t 
	 (backward-char 1))))



;; join lines.

(defun vip-join-lines (arg)
  "Join this line to next, if ARG is nil.  Otherwise, join ARG lines."
  (interactive "*P")
  (let ((val (vip-P-val arg)))
    (vip-set-destructive-command (list 'vip-join-lines val nil nil nil nil))
    (vip-loop (if (null val) 1 (1- val))
	      (progn
		(end-of-line)
		(if (not (eobp))
		    (progn
		      (forward-line 1)
		      (delete-region (point) (1- (point)))
		      (fixup-whitespace)
		      ;; fixup-whitespace sometimes does not leave space
		      ;; between objects, so we insert it as in Vi
		      (or (looking-at " ")
			  (insert " ")
			  (backward-char 1))
		      ))))))


;; Replace state

(defun vip-change (beg end)
  (if (markerp beg) (setq beg (marker-position beg)))
  (if (markerp end) (setq end (marker-position end)))
  ;; beg is sometimes (mark t), which may be nil
  (or beg (setq beg end))
  
  (vip-set-complex-command-for-undo)
  (if vip-use-register
      (progn
	(copy-to-register vip-use-register beg end nil)
	(setq vip-use-register nil)))
  (vip-set-replace-overlay beg end)
  (setq last-command nil) ; separate repl text from prev kills
  
  (if (= (vip-replace-start) (point-max))
      (error "End of buffer"))
      
  (setq vip-last-replace-region
	(buffer-substring (vip-replace-start)
			  (vip-replace-end)))
  
  ;; protect against error while inserting "@" and other disasters
  ;; (e.g., read-only buff)
  (condition-case conds
      (if (or vip-allow-multiline-replace-regions
	      (vip-same-line (vip-replace-start)
			     (vip-replace-end)))
	  (progn
	    ;; tabs cause problems in replace, so untabify
	    (goto-char (vip-replace-end))
	    (insert-before-markers "@") ; put placeholder after the TAB
	    (untabify (vip-replace-start) (point))
	    ;; del @, don't put on kill ring 
	    (delete-backward-char 1)
	    
	    (vip-set-replace-overlay-glyphs
	     vip-replace-region-start-delimiter
	     vip-replace-region-end-delimiter)
	    ;; this move takes care of the last posn in the overlay, which
	    ;; has to be shifted because of insert. We can't simply insert
	    ;; "$" before-markers because then overlay-start will shift the
	    ;; beginning of the overlay in case we are replacing a single
	    ;; character. This fixes the bug with `s' and `cl' commands.
	    (vip-move-replace-overlay (vip-replace-start) (point))
	    (goto-char (vip-replace-start))
	    (vip-change-state-to-replace t))
	(kill-region (vip-replace-start)
		     (vip-replace-end))
	(vip-hide-replace-overlay)
	(vip-change-state-to-insert))
    (error ;; make sure that the overlay doesn't stay.
           ;; go back to the original point
     (goto-char (vip-replace-start))
     (vip-hide-replace-overlay)
     (vip-message-conditions conds))))


(defun vip-change-subr (beg end)
  ;; beg is sometimes (mark t), which may be nil
  (or beg (setq beg end))
  
  (if vip-use-register
      (progn
	(copy-to-register vip-use-register beg end nil)
	(setq vip-use-register nil)))
  (kill-region beg end)
  (setq this-command 'vip-change)
  (vip-yank-last-insertion))

(defun vip-toggle-case (arg)
  "Toggle character case."
  (interactive "P")
  (let ((val (vip-p-val arg)) (c))
    (vip-set-destructive-command (list 'vip-toggle-case val nil nil nil nil))
    (while (> val 0)
      (setq c (following-char))
      (delete-char 1 nil)
      (if (eq c (upcase c))
	  (insert-char (downcase c) 1)
	(insert-char (upcase c) 1))
      (if (eolp) (backward-char 1))
      (setq val (1- val)))))


;; query replace

(defun vip-query-replace ()
  "Query replace. 
If a null string is suplied as the string to be replaced,
the query replace mode will toggle between string replace
and regexp replace."
  (interactive)
  (let (str)
    (setq str (vip-read-string-with-history
	       (if vip-re-query-replace "Query replace regexp: "
		 "Query replace: ")
	       nil  ; no initial
	       'vip-replace1-history
	       (car vip-replace1-history) ; default
	       ))
    (if (string= str "")
	(progn
	  (setq vip-re-query-replace (not vip-re-query-replace))
	  (message "Query replace mode changed to %s"
		   (if vip-re-query-replace "regexp replace"
		     "string replace")))
      (if vip-re-query-replace
	  (query-replace-regexp
	   str
	   (vip-read-string-with-history
	    (format "Query replace regexp `%s' with: " str)
	    nil  ; no initial
	    'vip-replace1-history
	    (car vip-replace1-history) ; default
	    ))
	(query-replace
	 str
	 (vip-read-string-with-history
	  (format "Query replace `%s' with: " str)
	  nil  ; no initial
	  'vip-replace1-history
	  (car vip-replace1-history) ; default
	  ))))))


;; marking

(defun vip-mark-beginning-of-buffer ()
  "Mark beginning of buffer."
  (interactive)
  (push-mark (point))
  (goto-char (point-min))
  (exchange-point-and-mark)
  (message "Mark set at the beginning of buffer"))

(defun vip-mark-end-of-buffer ()
  "Mark end of buffer."
  (interactive)
  (push-mark (point))
  (goto-char (point-max))
  (exchange-point-and-mark)
  (message "Mark set at the end of buffer"))

(defun vip-mark-point ()
  "Set mark at point of buffer."
  (interactive)
  (let ((char (read-char)))
    (cond ((and (<= ?a char) (<= char ?z))
	   (point-to-register (1+ (- char ?a))))
	  ((= char ?<) (vip-mark-beginning-of-buffer))
	  ((= char ?>) (vip-mark-end-of-buffer))
	  ((= char ?.) (vip-set-mark-if-necessary))
	  ((= char ?,) (vip-cycle-through-mark-ring))
	  ((= char ?D) (mark-defun))
	  (t (error ""))
	  )))
	
;; Algorithm: If first invocation of this command save mark on ring, goto
;; mark, M0, and pop the most recent elt from the mark ring into mark,
;; making it into the new mark, M1.
;; Push this mark back and set mark to the original point position, p1.
;; So, if you hit '' or `` then you can return to p1.
;;
;; If repeated command, pop top elt from the ring into mark and
;; jump there. This forgets the position, p1, and puts M1 back into mark.
;; Then we save the current pos, which is M0, jump to M1 and pop M2 from
;; the ring into mark.  Push M2 back on the ring and set mark to M0.
;; etc.
(defun vip-cycle-through-mark-ring ()
  "Visit previous locations on the mark ring.
One can use `` and '' to temporarily jump 1 step back."
  (let* ((sv-pt (point)))
       ;; if repeated `m,' command, pop the previously saved mark.
       ;; Prev saved mark is actually prev saved point. It is used if the
       ;; user types `` or '' and is discarded 
       ;; from the mark ring by the next `m,' command. 
       ;; In any case, go to the previous or previously saved mark.
       ;; Then push the current mark (popped off the ring) and set current
       ;; point to be the mark. Current pt as mark is discarded by the next
       ;; m, command.
       (if (eq last-command 'vip-cycle-through-mark-ring)
	   ()
	 ;; save current mark if the first iteration
	 (setq mark-ring (delete (vip-mark-marker) mark-ring))
	 (if (mark t)
	     (push-mark (mark t) t)) )
       (pop-mark)
       (set-mark-command 1)
       ;; don't duplicate mark on the ring
       (setq mark-ring (delete (vip-mark-marker) mark-ring))
       (push-mark sv-pt t)
       (vip-deactivate-mark)
       (setq this-command 'vip-cycle-through-mark-ring)
       ))
       

(defun vip-goto-mark (arg)
  "Go to mark."
  (interactive "P")
  (let ((char (read-char))
	(com (vip-getcom arg)))
    (vip-goto-mark-subr char com nil)))

(defun vip-goto-mark-and-skip-white (arg)
  "Go to mark and skip to first non-white character on line."
  (interactive "P")
  (let ((char (read-char))
	(com (vip-getCom arg)))
    (vip-goto-mark-subr char com t)))

(defun vip-goto-mark-subr (char com skip-white)
  (if (eobp) 
      (if (bobp)
	  (error "Empty buffer")
	(backward-char 1)))
  (cond ((vip-valid-register char '(letter))
	 (let* ((buff (current-buffer))
	        (reg (1+ (- char ?a)))
	        (text-marker (get-register reg)))
	   (if com (vip-move-marker-locally 'vip-com-point (point)))
	   (if (not (vip-valid-marker text-marker))
	       (error vip-EmptyTextmarker char))
	   (if (and (vip-same-line (point) vip-last-jump)
		    (= (point) vip-last-jump-ignore))
	       (push-mark vip-last-jump t) 
	     (push-mark nil t)) ; no msg
	   (vip-register-to-point reg)
	   (setq vip-last-jump (point-marker))
	   (cond (skip-white 
		  (back-to-indentation)
		  (setq vip-last-jump-ignore (point))))
	   (if com
	       (if (equal buff (current-buffer))
		   (vip-execute-com (if skip-white
					'vip-goto-mark-and-skip-white
				      'vip-goto-mark)
				    nil com)
		 (switch-to-buffer buff)
		 (goto-char vip-com-point)
		 (vip-change-state-to-vi)
		 (error "")))))
	((and (not skip-white) (= char ?`))
	 (if com (vip-move-marker-locally 'vip-com-point (point)))
	 (if (and (vip-same-line (point) vip-last-jump)
		  (= (point) vip-last-jump-ignore))
	     (goto-char vip-last-jump))
	 (if (null (mark t)) (error "Mark is not set in this buffer"))
	 (if (= (point) (mark t)) (pop-mark))
	 (exchange-point-and-mark)
	 (setq vip-last-jump (point-marker)
	       vip-last-jump-ignore 0)
	 (if com (vip-execute-com 'vip-goto-mark nil com)))
	((and skip-white (= char ?'))
	 (if com (vip-move-marker-locally 'vip-com-point (point)))
	 (if (and (vip-same-line (point) vip-last-jump)
		  (= (point) vip-last-jump-ignore))
	     (goto-char vip-last-jump))
	 (if (= (point) (mark t)) (pop-mark))
	 (exchange-point-and-mark)
	 (setq vip-last-jump (point))
	 (back-to-indentation)
	 (setq vip-last-jump-ignore (point))
	 (if com (vip-execute-com 'vip-goto-mark-and-skip-white nil com)))
	(t (error vip-InvalidTextmarker char))))
	
(defun vip-insert-tab ()
  (interactive)
  (insert-tab))

(defun vip-exchange-point-and-mark ()
  (interactive)
  (exchange-point-and-mark)
  (back-to-indentation))

;; Input Mode Indentation

;; Returns t, if the string before point matches the regexp STR.
(defsubst vip-looking-back (str)
  (and (save-excursion (re-search-backward str nil t))
       (= (point) (match-end 0))))


(defun vip-forward-indent ()
  "Indent forward -- `C-t' in Vi."
  (interactive)
  (setq vip-cted t)
  (indent-to (+ (current-column) vip-shift-width)))

(defun vip-backward-indent ()
  "Backtab, C-d in VI"
  (interactive)
  (if vip-cted
      (let ((p (point)) (c (current-column)) bol (indent t))
	(if (vip-looking-back "[0^]")
	    (progn
	      (if (eq ?^ (preceding-char))
		  (setq vip-preserve-indent t))
	      (delete-backward-char 1)
	      (setq p (point))
	      (setq indent nil)))
	(save-excursion
	  (beginning-of-line)
	  (setq bol (point)))
	(if (re-search-backward "[^ \t]" bol 1) (forward-char))
	(delete-region (point) p)
	(if indent
	    (indent-to (- c vip-shift-width)))
	(if (or (bolp) (vip-looking-back "[^ \t]"))
	    (setq vip-cted nil)))))

(defun vip-autoindent ()
  "Auto Indentation, Vi-style."
  (interactive)
  (let ((col (current-indentation)))
    (if abbrev-mode (expand-abbrev))
    (if vip-preserve-indent
	(setq vip-preserve-indent nil)
      (setq vip-current-indent col))
    ;; don't leave whitespace lines around
    (if (memq last-command
	      '(vip-autoindent
		vip-open-line vip-Open-line
		vip-replace-state-exit-cmd))
	(indent-to-left-margin))
    ;; use \n instead of newline, or else <Return> will move the insert point
    ;;(newline 1)
    (insert "\n")
    (if vip-auto-indent
	(progn
	  (setq vip-cted t)
	  (if (and vip-electric-mode
		   (not (eq major-mode 'fundamental-mode)))
	      (indent-according-to-mode)
	    (indent-to vip-current-indent))
	  ))
    ))

	   
;; Viewing registers

(defun vip-ket-function (arg)
  "Function called by \], the ket. View registers and call \]\]."
  (interactive "P")
  (let ((reg (read-char)))
    (cond ((vip-valid-register reg '(letter Letter))
	   (view-register (downcase reg)))
	  ((vip-valid-register reg '(digit))
	   (let ((text (current-kill (- reg ?1) 'do-not-rotate)))
	     (save-excursion 
	       (set-buffer (get-buffer-create "*Output*"))
	       (delete-region (point-min) (point-max))
	       (insert (format "Register %c contains the string:\n" reg))
	       (insert text)
	       (goto-char (point-min)))
	     (display-buffer "*Output*")))
	  ((= ?\] reg)
	   (vip-next-heading arg))
	  (t (error
	      vip-InvalidRegister reg)))))

(defun vip-brac-function (arg)
  "Function called by \[, the brac. View textmarkers and call \[\["
  (interactive "P")
  (let ((reg (read-char)))
    (cond ((= ?\[ reg)
	   (vip-prev-heading arg))
	  ((= ?\] reg)
	   (vip-heading-end arg))
	  ((vip-valid-register reg '(letter))
	   (let* ((val (get-register (1+ (- reg ?a))))
		  (buf (if (not val) 
			   (error vip-EmptyTextmarker reg)
			 (marker-buffer val)))
		  (pos (marker-position val))
		  line-no text (s pos) (e pos))
	     (save-excursion 
	       (set-buffer (get-buffer-create "*Output*"))
	       (delete-region (point-min) (point-max))
	       (if (and buf pos)
		   (progn
		     (save-excursion 
		       (set-buffer buf)
		       (setq line-no (1+ (count-lines (point-min) val)))
		       (goto-char pos)
		       (beginning-of-line)
		       (if (re-search-backward "[^ \t]" nil t)
			   (progn
			     (beginning-of-line)
			     (setq s (point))))
		       (goto-char pos)
		       (forward-line 1)
		       (if (re-search-forward "[^ \t]" nil t)
			   (progn
			     (end-of-line)
			     (setq e (point))))
		       (setq text (buffer-substring s e))
		       (setq text (format "%s<%c>%s" 
					  (substring text 0 (- pos s)) 
					  reg (substring text (- pos s)))))
		     (insert
		      (format
		       "Textmarker `%c' is in buffer `%s' at line %d.\n"
				     reg (buffer-name buf) line-no))
		     (insert (format "Here is some text around %c:\n\n %s" 
				     reg text)))
		 (insert (format vip-EmptyTextmarker reg)))
	       (goto-char (point-min)))
	     (display-buffer "*Output*")))
	  (t (error vip-InvalidTextmarker reg)))))
  


;; commands in insertion mode

(defun vip-delete-backward-word (arg)
  "Delete previous word."
  (interactive "p")
  (save-excursion
    (push-mark nil t)
    (backward-word arg)
    (delete-region (point) (mark t))
    (pop-mark)))


(defun viper-set-expert-level (&optional dont-change-unless)
  "Sets the expert level for a Viper user.
Can be called interactively to change (temporarily or permanently) the
current expert level.

The optional argument DONT-CHANGE-UNLESS, if not nil, says that
the level should not be changed, unless its current value is
meaningless (i.e., not one of 1,2,3,4,5).

User level determines the setting of Viper variables that are most
sensitive for VI-style look-and-feel."
  
  (interactive)
  
  (if (not (natnump viper-expert-level)) (setq viper-expert-level 0))
  
  (save-window-excursion
    (delete-other-windows)
    ;; if 0 < viper-expert-level < viper-max-expert-level
    ;;    & dont-change-unless = t -- use it; else ask
    (vip-ask-level dont-change-unless))
  
  (setq viper-always          	    	t
	vip-ex-style-motion 	    	t
	vip-ex-style-editing-in-insert  t
	vip-want-ctl-h-help nil)

  (cond ((eq viper-expert-level 1) ; novice or beginner
	 (global-set-key   ; in emacs-state 
	  vip-toggle-key
	  (if (vip-window-display-p) 'vip-iconify 'suspend-emacs))
	 (setq vip-no-multiple-ESC	     t
	       vip-re-search	    	     t
	       vip-vi-style-in-minibuffer    t
	       vip-search-wrap-around-t	     t
	       vip-electric-mode	     nil
	       vip-want-emacs-keys-in-vi     nil
	       vip-want-emacs-keys-in-insert nil))
	
	((and (> viper-expert-level 1) (< viper-expert-level 5))
	 ;; intermediate to guru
	 (setq vip-no-multiple-ESC           (if (vip-window-display-p)
						 t 'twice)
	       vip-electric-mode	     t
	       vip-want-emacs-keys-in-vi     t
	       vip-want-emacs-keys-in-insert (> viper-expert-level 2))

	 (if (eq viper-expert-level 4) ; respect user's ex-style motion
	     	    	    	     ; and vip-no-multiple-ESC
	     (progn
	       (setq-default
		vip-ex-style-editing-in-insert
		(viper-standard-value 'vip-ex-style-editing-in-insert)
		vip-ex-style-motion
		(viper-standard-value 'vip-ex-style-motion))
	       (setq vip-ex-style-motion 
		     (viper-standard-value 'vip-ex-style-motion)
		     vip-ex-style-editing-in-insert
		     (viper-standard-value 'vip-ex-style-editing-in-insert)
		     vip-re-search
		     (viper-standard-value 'vip-re-search)
		     vip-no-multiple-ESC 
		     (viper-standard-value 'vip-no-multiple-ESC)))))
	
	;; A wizard!!
	;; Ideally, if 5 is selected, a buffer should pop up to let the
	;; user toggle the values of variables.
	(t (setq-default vip-ex-style-editing-in-insert
			 (viper-standard-value 'vip-ex-style-editing-in-insert)
			 vip-ex-style-motion
			 (viper-standard-value 'vip-ex-style-motion))
	   (setq  vip-want-ctl-h-help 
		  (viper-standard-value 'vip-want-ctl-h-help)
		  viper-always
		  (viper-standard-value 'viper-always)
		  vip-no-multiple-ESC 
		  (viper-standard-value 'vip-no-multiple-ESC)
		  vip-ex-style-motion 
		  (viper-standard-value 'vip-ex-style-motion)
		  vip-ex-style-editing-in-insert
		  (viper-standard-value 'vip-ex-style-editing-in-insert)
		  vip-re-search
		  (viper-standard-value 'vip-re-search)
		  vip-electric-mode 
		  (viper-standard-value 'vip-electric-mode)
		  vip-want-emacs-keys-in-vi 
		  (viper-standard-value 'vip-want-emacs-keys-in-vi)
		  vip-want-emacs-keys-in-insert
		  (viper-standard-value 'vip-want-emacs-keys-in-insert))))
  
  (vip-set-mode-vars-for vip-current-state)
  (if (or viper-always
	  (and (> viper-expert-level 0) (> 5 viper-expert-level)))
      (vip-set-hooks)))

;; Ask user expert level.
(defun vip-ask-level (dont-change-unless)
  (let ((ask-buffer " *vip-ask-level*")
	level-changed repeated)
    (save-window-excursion
      (switch-to-buffer ask-buffer)
	      
      (while (or (> viper-expert-level viper-max-expert-level)
		 (< viper-expert-level 1)
		 (null dont-change-unless))
	(erase-buffer)
	(if repeated
	    (progn
	      (message "Invalid user level")
	      (beep 1))
	  (setq repeated t))
	(setq dont-change-unless t
	      level-changed t)
	(insert "
Please specify your level of familiarity with the venomous VI PERil
(and the VI Plan for Emacs Rescue).
You can change it at any time by typing `M-x viper-set-expert-level RET'
	
 1 -- BEGINNER: Almost all Emacs features are suppressed.
          Feels almost like straight Vi. File name completion and
          command history in the minibuffer are thrown in as a bonus. 
          To use Emacs productively, you must reach level 3 or higher.
 2 -- MASTER: C-c now has its standard Emacs meaning in Vi command state,
	  so most Emacs commands can be used when Viper is in Vi state.
	  Good progress---you are well on the way to level 3!
 3 -- GRAND MASTER: Like 3, but most Emacs commands are available also
          in Viper's insert state.
 4 -- GURU: Like 3, but user settings are respected for vip-no-multiple-ESC,
	  vip-re-search, vip-ex-style-motion, & vip-ex-style-editing-in-insert
	  variables. Adjust these settings to your taste.
 5 -- WIZARD: Like 4, but user settings are also respected for viper-always,
	  vip-electric-mode, vip-want-ctl-h-help, vip-want-emacs-keys-in-vi,
	  and vip-want-emacs-keys-in-insert. Adjust these to your taste.
      
Please, specify your level now: ")
	  
	(setq viper-expert-level (- (vip-read-char-exclusive) ?0))
	) ; end while
      
      ;; tell the user if level was changed
      (and level-changed
	   (progn
	     (insert
	      (format "\n\n\n\n\n\t\tYou have selected user level %d"
		      viper-expert-level))
	     (if (y-or-n-p "Do you wish to make this change permanent? ")
		 ;; save the setting for viper-expert-level
		 (vip-save-setting
		  'viper-expert-level
		  (format "Saving user level %d ..." viper-expert-level)
		  vip-custom-file-name))
	     ))
      (bury-buffer) ; remove ask-buffer from screen
      (message "")
      )))


(defun vip-nil ()
  (interactive)
  (beep 1))
  
    
;; if ENFORCE-BUFFER is not nil, error if CHAR is a marker in another buffer
(defun vip-register-to-point (char &optional enforce-buffer)
  "Like jump-to-register, but switches to another buffer in another window."
  (interactive "cViper register to point: ")
  (let ((val (get-register char)))
    (cond
     ((and (fboundp 'frame-configuration-p)
	   (frame-configuration-p val))
      (set-frame-configuration val))
     ((window-configuration-p val)
      (set-window-configuration val))
     ((vip-valid-marker val)
      (if (and enforce-buffer
	       (not (equal (current-buffer) (marker-buffer val))))
	  (error (concat vip-EmptyTextmarker " in this buffer")
		 (1- (+ char ?a))))
      (pop-to-buffer  (marker-buffer val))
      (goto-char val))
     ((and (consp val) (eq (car val) 'file))
      (find-file (cdr val)))
     (t
      (error vip-EmptyTextmarker (1- (+ char ?a)))))))


(defun vip-save-kill-buffer ()
  "Save then kill current buffer. "
  (interactive)
  (if (< viper-expert-level 2)
      (save-buffers-kill-emacs)
    (save-buffer)
    (kill-buffer (current-buffer))))



;;; Bug Report

(defun vip-submit-report ()
  "Submit bug report on Viper."
  (interactive)
  (let ((reporter-prompt-for-summary-p t)
	(vip-device-type (vip-device-type))
	color-display-p frame-parameters
	minibuffer-emacs-face minibuffer-vi-face minibuffer-insert-face
	varlist salutation window-config)
    
    ;; If mode info is needed, add variable to `let' and then set it below,
    ;; like we did with color-display-p.
    (setq color-display-p (if (vip-window-display-p) 
			      (vip-color-display-p)
			    'non-x)
	  minibuffer-vi-face (if (vip-has-face-support-p)
				 (vip-get-face vip-minibuffer-vi-face)
			       'non-x)
	  minibuffer-insert-face (if (vip-has-face-support-p)
				     (vip-get-face vip-minibuffer-insert-face)
				   'non-x)
	  minibuffer-emacs-face (if (vip-has-face-support-p)
				    (vip-get-face vip-minibuffer-emacs-face)
				  'non-x)
	  frame-parameters (if (fboundp 'frame-parameters)
			       (frame-parameters (selected-frame))))
    
    (setq varlist (list 'vip-vi-minibuffer-minor-mode
		        'vip-insert-minibuffer-minor-mode
		        'vip-vi-intercept-minor-mode
		        'vip-vi-local-user-minor-mode     
		        'vip-vi-kbd-minor-mode        	
		        'vip-vi-global-user-minor-mode
		        'vip-vi-state-modifier-minor-mode
		        'vip-vi-diehard-minor-mode   
		        'vip-vi-basic-minor-mode    
		        'vip-replace-minor-mode 	  
		        'vip-insert-intercept-minor-mode
		        'vip-insert-local-user-minor-mode 
		        'vip-insert-kbd-minor-mode     	
		        'vip-insert-global-user-minor-mode
		        'vip-insert-state-modifier-minor-mode
		        'vip-insert-diehard-minor-mode 	
		        'vip-insert-basic-minor-mode   
		        'vip-emacs-intercept-minor-mode 
		        'vip-emacs-local-user-minor-mode 
		        'vip-emacs-kbd-minor-mode 
		        'vip-emacs-global-user-minor-mode
		        'vip-emacs-state-modifier-minor-mode
		        'vip-automatic-iso-accents
		        'vip-want-emacs-keys-in-insert
		        'vip-want-emacs-keys-in-vi
		        'vip-keep-point-on-undo
		        'vip-no-multiple-ESC
		        'vip-electric-mode
		        'vip-ESC-key
		        'vip-want-ctl-h-help
		        'vip-ex-style-editing-in-insert
		        'vip-delete-backwards-in-replace
		        'vip-vi-style-in-minibuffer
		        'vip-vi-state-hook
		        'vip-insert-state-hook
		        'vip-replace-state-hook
		        'vip-emacs-state-hook
		        'ex-cycle-other-window
		        'ex-cycle-through-non-files
		        'viper-expert-level
		        'major-mode
		        'vip-device-type
			'color-display-p
			'frame-parameters
			'minibuffer-vi-face
			'minibuffer-insert-face
			'minibuffer-emacs-face
			))
	  (setq salutation "
Congratulations! You may have unearthed a bug in Viper!
Please mail a concise, accurate summary of the problem to the address above.

-------------------------------------------------------------------")
	  (setq window-config (current-window-configuration))
	  (with-output-to-temp-buffer " *vip-info*"
	    (switch-to-buffer " *vip-info*")
	    (delete-other-windows)
	    (princ "
PLEASE FOLLOW THESE PROCEDURES
------------------------------

Before reporting a bug, please verify that it is related to Viper, and is
not cause by other packages you are using.

Don't report compilation warnings, unless you are certain that there is a
problem. These warnings are normal and unavoidable.

Please note that users should not modify variables and keymaps other than
those advertised in the manual. Such `customization' is likely to crash
Viper, as it would any other improperly customized Emacs package.

If you are reporting an error message received while executing one of the
Viper commands, type:

    M-x set-variable <Return> debug-on-error <Return> t <Return>
	
Then reproduce the error. The above command will cause Emacs to produce a
back trace of the execution that leads to the error. Please include this
trace in your bug report.

If you believe that one of Viper's commands goes into an infinite loop
\(e.g., Emacs freezes\), type:

    M-x set-variable <Return> debug-on-quit <Return> t <Return>
	
Then reproduce the problem. Wait for a few seconds, then type C-g to abort
the current command. Include the resulting back trace in the bug report.

Mail anyway (y or n)? ")
	    (if (y-or-n-p "Mail anyway? ")
		()
	      (set-window-configuration window-config)
	      (error "Bug report aborted")))

	  (require 'reporter)
	  (set-window-configuration window-config)
    
	  (reporter-submit-bug-report "kifer@cs.sunysb.edu"
				      (vip-version)
				      varlist
				      nil 'delete-other-windows
				      salutation)
	  ))
		    

    
		
;; Smoothes out the difference between Emacs' unread-command-events
;; and XEmacs unread-command-event. Arg is a character, an event, a list of
;; events or a sequence of keys.
;;
;; Due to the way unread-command-events in Emacs (not XEmacs), a non-event
;; symbol in unread-command-events list may cause Emacs to turn this symbol
;; into an event. Below, we delete nil from event lists, since nil is the most
;; common symbol that might appear in this wrong context.
(defun vip-set-unread-command-events (arg)
  (if vip-emacs-p
      (setq
       unread-command-events
       (let ((new-events
	      (cond ((eventp arg) (list arg))
		    ((listp arg) arg)
		    ((sequencep arg)
		     (listify-key-sequence arg))
		    (t (error
			"vip-set-unread-command-events: Invalid argument, %S"
			arg)))))
	 (if (not (eventp nil))
	     (setq new-events (delq nil new-events)))
	 (append new-events unread-command-events)))
    ;; XEmacs
    (setq
     unread-command-events
     (append
      (cond ((vip-characterp arg) (list (character-to-event arg)))
	    ((eventp arg)  (list arg))
	    ((stringp arg) (mapcar 'character-to-event arg))
	    ((vectorp arg) (append arg nil)) ; turn into list
	    ((listp arg) (vip-eventify-list-xemacs arg))
	    (t (error
		"vip-set-unread-command-events: Invalid argument, %S" arg)))
      unread-command-events))))

;; list is assumed to be a list of events of characters
(defun vip-eventify-list-xemacs (lis)
  (mapcar
   (function (lambda (elt)
	       (cond ((vip-characterp elt) (character-to-event elt))
		     ((eventp elt)  elt)
		     (t (error
			 "vip-eventify-list-xemacs: can't convert to event, %S"
			 elt)))))
   lis))
  
  

;;;  viper-cmd.el ends here
