;;; vc.el --- drive a version-control system from within Emacs

;; Copyright (C) 1992, 1993, 1994 Free Software Foundation, Inc.
;; Copyright (C) 1995 Tinker Systems and INS Engineering Corp.

;; Author: Eric S. Raymond <esr@snark.thyrsus.com>
;; Maintainer: ttn@netcom.com
;; Version: 5.6

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
;; Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Synched up with: It's not clear at this point.
;;; mly synched this with FSF at version 5.4.  Stig did a whole lot
;;; of stuff to it since then, and so has the FSF.

;;; Commentary:

;; This mode is fully documented in the Emacs user's manual.
;;
;; This was designed and implemented by Eric Raymond <esr@snark.thyrsus.com>.
;; Paul Eggert <eggert@twinsun.com>, Sebastian Kremer <sk@thp.uni-koeln.de>,
;; and Richard Stallman contributed valuable criticism, support, and testing.
;; CVS support was added by Per Cederqvist <ceder@lysator.liu.se>
;; in Jan-Feb 1994.
;;
;; XEmacs fixes, CVS fixes, and general improvements
;; by Jonathan Stigelman <Stig@hackvan.com>
;;
;; Supported version-control systems presently include SCCS, RCS, and CVS.
;; The RCS lock-stealing code doesn't work right unless you use RCS 5.6.2
;; or newer.  Currently (January 1994) that is only a beta test release.
;; Even initial checkins will fail if your RCS version is so old that ci
;; doesn't understand -t-; this has been known to happen to people running
;; NExTSTEP 3.0. 
;;
;; The RCS code assumes strict locking.  You can support the RCS -x option
;; by adding pairs to the vc-master-templates list.
;;
;; Proper function of the SCCS diff commands requires the shellscript vcdiff
;; to be installed somewhere on Emacs's path for executables.
;;
;; If your site uses the ChangeLog convention supported by Emacs, the
;; function vc-comment-to-change-log should prove a useful checkin hook.
;;
;; This code depends on call-process passing back the subprocess exit
;; status.  Thus, you need Emacs 18.58 or later to run it.  For the
;; vc-directory command to work properly as documented, you need 19.
;; You also need Emacs 19's ring.el.
;;
;; The vc code maintains some internal state in order to reduce expensive
;; version-control operations to a minimum.  Some names are only computed
;; once.  If you perform version control operations with RCS/SCCS/CVS while
;; vc's back is turned, or move/rename master files while vc is running,
;; vc may get seriously confused.  Don't do these things!
;;
;; Developer's notes on some concurrency issues are included at the end of
;; the file.

;;; Code:

(require 'vc-hooks)
(require 'ring)
(eval-when-compile (require 'dired))    ; for dired-map-over-marks macro

(if (not (assoc 'vc-parent-buffer minor-mode-alist))
    (setq minor-mode-alist
	  (cons '(vc-parent-buffer vc-parent-buffer-name)
		minor-mode-alist)))

;; General customization

(defvar vc-default-back-end nil
  "*Back-end actually used by this interface; may be SCCS or RCS.
The value is only computed when needed to avoid an expensive search.")
(defvar vc-suppress-confirm nil
  "*If non-nil, treat user as expert; suppress yes-no prompts on some things.")
(defvar vc-keep-workfiles t
  "*If non-nil, don't delete working files after registering changes.
If the back-end is CVS, workfiles are always kept, regardless of the
value of this flag.")
(defvar vc-initial-comment nil
  "*Prompt for initial comment when a file is registered.")
(defvar vc-command-messages nil
  "*Display run messages from back-end commands.")
(defvar vc-mistrust-permissions 'file-symlink-p
  "*Don't assume that permissions and ownership track version-control status.")
(defvar vc-checkin-switches nil
  "*Extra switches passed to the checkin program by \\[vc-checkin].")
(defvar vc-checkout-switches nil
  "*Extra switches passed to the checkout program by \\[vc-checkout].")
(defvar vc-path
  (if (file-exists-p "/usr/sccs")
      '("/usr/sccs") nil)
  "*List of extra directories to search for version control commands.")
(defvar vc-directory-exclusion-list '("SCCS" "RCS")
  "*Directory names ignored by functions that recursively walk file trees.")

(defconst vc-maximum-comment-ring-size 32
  "Maximum number of saved comments in the comment ring.")

;;; XEmacs - This is dumped into loaddefs.el already.
;; (defvar diff-switches "-c"
;;   "*A string or list of strings specifying switches to be passed to diff.")

;;;###autoload
(defvar vc-checkin-hook nil
  "*List of functions called after a checkin is done.  See `run-hooks'.")

(defvar vc-make-buffer-writable-hook nil
  "*List of functions called when a buffer is made writable.  See `run-hooks.'
This hook is only used when the version control system is CVS.  It
might be useful for sites who uses locking with CVS, or who uses link
farms to gold trees.")

;; Header-insertion hair

(defvar vc-header-alist
  '((SCCS "\%W\%") (RCS "\$Id\$") (CVS "\$Id\$"))
  "*Header keywords to be inserted when `vc-insert-headers' is executed.")
(defvar vc-static-header-alist
  '(("\\.c$" .
     "\n#ifndef lint\nstatic char vcid[] = \"\%s\";\n#endif /* lint */\n"))
  "*Associate static header string templates with file types.  A \%s in the
template is replaced with the first string associated with the file's
version-control type in `vc-header-alist'.")

(defvar vc-comment-alist
  '((nroff-mode ".\\\"" ""))
  "*Special comment delimiters to be used in generating vc headers only.
Add an entry in this list if you need to override the normal comment-start
and comment-end variables.  This will only be necessary if the mode language
is sensitive to blank lines.")

;; Default is to be extra careful for super-user.
(defvar vc-checkout-carefully (= (user-uid) 0) ; #### - this prevents preloading!
  "*Non-nil means be extra-careful in checkout.
Verify that the file really is not locked
and that its contents match what the master file says.")

;; Variables the user doesn't need to know about.
(defvar vc-log-entry-mode nil)
(defvar vc-log-operation nil)
(defvar vc-log-after-operation-hook nil)
(defvar vc-checkout-writable-buffer-hook 'vc-checkout-writable-buffer)
;; In a log entry buffer, this is a local variable
;; that points to the buffer for which it was made
;; (either a file, or a VC dired buffer).
(defvar vc-parent-buffer nil)
(defvar vc-parent-buffer-name nil)

(defvar vc-log-file)
(defvar vc-log-version)

(defconst vc-name-assoc-file "VC-names")

(defvar vc-dired-mode nil)
(make-variable-buffer-local 'vc-dired-mode)

(defvar vc-comment-ring nil)
(defvar vc-comment-ring-index nil)
(defvar vc-last-comment-match nil)

;; File property caching

(defun vc-file-clearprops (file)
  ;; clear all properties of a given file
  (setplist (intern file vc-file-prop-obarray) nil))

(defun vc-clear-context ()
  "Clear all cached file properties and the comment ring."
  (interactive)
  (fillarray vc-file-prop-obarray nil)
  ;; Note: there is potential for minor lossage here if there is an open
  ;; log buffer with a nonzero local value of vc-comment-ring-index.
  (setq vc-comment-ring nil))

;; Random helper functions

(defun vc-registration-error (file)
  (if file
      (error "File %s is not under version control" file)
    (error "Buffer %s is not associated with a file" (buffer-name))))

(defvar vc-binary-assoc nil)

(defun vc-find-binary (name)
  "Look for a command anywhere on the subprocess-command search path."
  (or (cdr (assoc name vc-binary-assoc))
      ;; XEmacs - use locate-file
      (let ((full (locate-file name exec-path nil 1)))
	(if full
	    (setq vc-binary-assoc (cons (cons name full) vc-binary-assoc)))
	full)))

(defun vc-do-command (okstatus command file last &rest flags)
  "Execute a version-control command, notifying user and checking for errors.
The command is successful if its exit status does not exceed OKSTATUS.
Output from COMMAND goes to buffer *vc*.  The last argument of the command is
the master name of FILE if LAST is 'MASTER, or the workfile of FILE if LAST is
'WORKFILE; this is appended to an optional list of FLAGS."
  (setq file (expand-file-name file))
  (let ((camefrom (current-buffer))
	(pwd (file-name-directory (expand-file-name file)))
	(squeezed nil)
	(vc-file (and file (vc-name file)))
	status)
;;; #### - don't know why this code was here...to beautify the echo message?
;;;	   the version of code below doesn't break default-directory, but it
;;;	   still might mess up CVS and RCS because they like to operate on
;;;	   files in the current directory. --Stig
;;;
;;;     (if (string-match (concat "^" (regexp-quote pwd)) file)
;;;         (setq file (substring file (match-end 0)))
;;;       (setq pwd (file-name-directory file)))
    (if vc-command-messages
	(message "Running %s on %s..." command file))
    (set-buffer (get-buffer-create "*vc*"))
    (setq default-directory pwd
	  file (file-name-nondirectory file))

    (set (make-local-variable 'vc-parent-buffer) camefrom)
    (set (make-local-variable 'vc-parent-buffer-name)
	 (concat " from " (buffer-name camefrom)))
    
    (erase-buffer)

    (mapcar
     (function (lambda (s) (and s (setq squeezed (append squeezed (list s))))))
     flags)
    (if (and vc-file (eq last 'MASTER))
	(setq squeezed (append squeezed (list vc-file))))
    (if (eq last 'WORKFILE)
	(setq squeezed (append squeezed (list file))))
    (let ((exec-path (if vc-path (append vc-path exec-path) exec-path))
	  ;; Add vc-path to PATH for the execution of this command.
	  (process-environment (copy-sequence process-environment)))
      (setenv "PATH" (mapconcat 'identity exec-path ":"))
      (setq status (apply 'call-process command nil t nil squeezed)))
    (goto-char (point-max))
    (set-buffer-modified-p nil)		; XEmacs - fsf uses `not-modified'
    (forward-line -1)
    (if (or (not (integerp status)) (< okstatus status))
	(progn
	  (pop-to-buffer "*vc*")
	  (goto-char (point-min))
	  (shrink-window-if-larger-than-buffer)
	  (error "Running %s...FAILED (%s)" command
		 (if (integerp status)
		     (format "status %d" status)
		   status))
	  )
      (if vc-command-messages
	  (message "Running %s...OK" command))
      )
    (set-buffer camefrom)
    status)
  )

;;; Save a bit of the text around POSN in the current buffer, to help
;;; us find the corresponding position again later.  This works even
;;; if all markers are destroyed or corrupted.
(defun vc-position-context (posn)
  (list posn
	(buffer-size)
	(buffer-substring posn
			  (min (point-max) (+ posn 100)))))

;;; Return the position of CONTEXT in the current buffer, or nil if we
;;; couldn't find it.
(defun vc-find-position-by-context (context)
  (let ((context-string (nth 2 context)))
    (if (equal "" context-string)
	(point-max)
      (save-excursion
	(let ((diff (- (nth 1 context) (buffer-size))))
	  (if (< diff 0) (setq diff (- diff)))
	  (goto-char (nth 0 context))
	  (if (or (search-forward context-string nil t)
		  ;; Can't use search-backward since the match may continue
		  ;; after point.
		  (progn (goto-char (- (point) diff (length context-string)))
			 ;; goto-char doesn't signal an error at
			 ;; beginning of buffer like backward-char would
			 (search-forward context-string nil t)))
	      ;; to beginning of OSTRING
	      (- (point) (length context-string))))))))

(defun vc-revert-buffer1 (&optional arg no-confirm)
  ;; Most of this was shamelessly lifted from Sebastian Kremer's rcs.el mode.
  ;; Revert buffer, try to keep point and mark where user expects them in spite
  ;; of changes because of expanded version-control key words.
  ;; This is quite important since otherwise typeahead won't work as expected.
  (interactive "P")
  (widen)
  (let ((point-context (vc-position-context (point)))
	;; Use mark-marker to avoid confusion in transient-mark-mode.
	;; XEmacs - mark-marker t
	(mark-context  (if (eq (marker-buffer (mark-marker t)) (current-buffer))
			   (vc-position-context (mark-marker t))))
	;; We may want to reparse the compilation buffer after revert
	(reparse (and (boundp 'compilation-error-list) ;compile loaded
		      ;; Construct a list; each elt is nil or a buffer
		      ;; iff that buffer is a compilation output buffer
		      ;; that contains markers into the current buffer.
		      (save-excursion
			(mapcar (function
				 (lambda (buffer)
				   (set-buffer buffer)
				   (let ((errors (or
						  compilation-old-error-list
						  compilation-error-list))
					 (buffer-error-marked-p nil))
				     (while (and (consp errors)
						 (not buffer-error-marked-p))
				       (and (markerp (cdr (car errors)))
					    (eq buffer
						(marker-buffer
						 (cdr (car errors))))
					    (setq buffer-error-marked-p t))
				       (setq errors (cdr errors)))
				     (if buffer-error-marked-p buffer))))
				(buffer-list))))))

    ;; The FSF version intentionally runs font-lock here.  That
    ;; usually just leads to a correctly font-locked buffer being
    ;; redone.  #### We should detect the cases where the font-locking
    ;; may be incorrect (such as on reverts).  We know that it is fine
    ;; during regular checkin and checkouts.

    ;; the actual revisit
    (revert-buffer arg no-confirm)

    ;; Reparse affected compilation buffers.
    (while reparse
      (if (car reparse)
	  (save-excursion
	    (set-buffer (car reparse))
	    (let ((compilation-last-buffer (current-buffer)) ;select buffer
		  ;; Record the position in the compilation buffer of
		  ;; the last error next-error went to.
		  (error-pos (marker-position
			      (car (car-safe compilation-error-list)))))
	      ;; Reparse the error messages as far as they were parsed before.
	      (compile-reinitialize-errors '(4) compilation-parsing-end)
	      ;; Move the pointer up to find the error we were at before
	      ;; reparsing.  Now next-error should properly go to the next one.
	      (while (and compilation-error-list
			  (/= error-pos (car (car compilation-error-list))))
		(setq compilation-error-list (cdr compilation-error-list))))))
      (setq reparse (cdr reparse)))

    ;; Restore point and mark
    (let ((new-point (vc-find-position-by-context point-context)))
      (if new-point (goto-char new-point)))
    (if mark-context
	(let ((new-mark (vc-find-position-by-context mark-context)))
	  (if new-mark (set-mark new-mark))))))


(defun vc-buffer-sync (&optional not-urgent)
  ;; Make sure the current buffer and its working file are in sync
  ;; NOT-URGENT means it is ok to continue if the user says not to save.
  (if (buffer-modified-p)
      (if (or vc-suppress-confirm
	      (y-or-n-p (format "Buffer %s modified; save it? " (buffer-name))))
	  (save-buffer)
	(if not-urgent
	    nil
	  (error "Aborted")))))

;;;###autoload
(defun vc-file-status ()
  "Display the current status of the file being visited.
Currently, this is only defined for CVS.  The information provided in the
modeline is generally sufficient for RCS and SCCS."
  ;; by Stig@hackvan.com
  (interactive) 
  (vc-buffer-sync t)
  (let ((type (vc-backend-deduce buffer-file-name))
	(file buffer-file-name))
    (cond ((null type)
	   (if buffer-file-name
	       (message "`%s' is not registered with a version control system."
			buffer-file-name)
	     (ding)
	     (message "Buffer `%s' has no associated file."
		      (buffer-name (current-buffer)))))
	  ((eq 'CVS type)
	   (vc-do-command 0 "cvs" file 'WORKFILE "status" "-v")
	   (set-buffer "*vc*")
	   (set-buffer-modified-p nil)
	   ;; reparse the status information, since we have it handy...
	   (vc-parse-buffer '("Status: \\(.*\\)") file '(vc-cvs-status))
	   (goto-char (point-min))
	   (shrink-window-if-larger-than-buffer
	    (display-buffer (current-buffer))))
	  ((eq 'CC type)
	   (vc-do-command 0 "cleartool" file 'WORKFILE "describe")
	   (set-buffer "*vc*")
	   (set-buffer-modified-p nil)
	   (goto-char (point-min))
	   (shrink-window-if-larger-than-buffer
	    (display-buffer (current-buffer))))
	  (t
	   (ding)
	   (message "Operation not yet defined for RCS or SCCS.")))
    ))

(defun vc-workfile-unchanged-p (file &optional want-differences-if-changed)
  ;; Has the given workfile changed since last checkout?
  (cond ((and (eq 'CVS (vc-backend-deduce file))
	      (not want-differences-if-changed))

	 (let ((status (vc-file-getprop file 'vc-cvs-status)))
	   ;; #### - should this have some kind of timeout?  how often does
	   ;; this get called?  possibly the cached information should be
	   ;; flushed out of hand.  The only concern is the VC menu, which
	   ;; may indirectly call this function.
	   (or status			; #### - caching is error-prone
	       (setq status (car (vc-log-info "cvs" file 'WORKFILE '("status")
					      '("Status: \\(.*\\)")
					      '(vc-cvs-status)))))
	   (string= status "Up-to-date")))
	(t 
	 (let ((checkout-time (vc-file-getprop file 'vc-checkout-time))
	       (lastmod (nth 5 (file-attributes file)))
	       unchanged)
	   (or (equal checkout-time lastmod)
	       (and (or (not checkout-time) want-differences-if-changed)
		    (setq unchanged
			  (zerop (vc-backend-diff file nil nil
						  (not want-differences-if-changed))))
		    ;; 0 stands for an unknown time; it can't match any mod time.
		    (vc-file-setprop file 'vc-checkout-time (if unchanged lastmod 0))
		    unchanged))))))

(defun vc-next-action-on-file (file verbose &optional comment)
  ;;; If comment is specified, it will be used as an admin or checkin comment.
  (let ((vc-file (vc-name file))
	(vc-type (vc-backend-deduce file))
	owner version)
    (cond

     ;; if there is no master file corresponding, create one
     ((not vc-file)
      (vc-register verbose comment))

     ;; if there is no lock on the file, assert one and get it
     ((and (not (eq vc-type 'CVS))	;There are no locks in CVS.
	   (not (setq owner (vc-locking-user file))))
      (if (and vc-checkout-carefully
	       (not (vc-workfile-unchanged-p file t)))
	  (if (save-window-excursion
		(pop-to-buffer "*vc*")
		(goto-char (point-min))
		(insert (format "Changes to %s since last lock:\n\n" file))
		(not (beep))
		(yes-or-no-p
		 "File has unlocked changes, claim lock retaining changes? "))
	      (progn (vc-backend-steal file)
		     (vc-mode-line file))
	    (if (not (yes-or-no-p "Revert to checked-in version, instead? "))
		(error "Checkout aborted.")
	      (vc-revert-buffer1 t t)
	      (vc-checkout-writable-buffer file))
	    )
	(vc-checkout-writable-buffer file)))

     ;; a checked-out version exists, but the user may not own the lock
     ((and (not (eq vc-type 'CVS))	;There are no locks in CVS.
	   (not (string-equal owner (user-login-name))))
      (if comment
	  (error "Sorry, you can't steal the lock on %s this way" file))
      (vc-steal-lock
       file
       (and verbose (read-string "Version to steal: "))
       owner))

     ;; changes to the master file needs to be merged back into the
     ;; working file
     ((and (eq vc-type 'CVS)
	   ;; "0" means "added, but not yet committed"
	   (not (string= (vc-file-getprop file 'vc-your-latest-version) "0"))
	   (progn
	     (vc-fetch-properties file)
	     (not (string= (vc-file-getprop file 'vc-your-latest-version)
			   (vc-file-getprop file 'vc-latest-version)))))
      (vc-buffer-sync)
      (if (yes-or-no-p (format "%s is not up-to-date.  Merge in changes now? "
			       (buffer-name)))
	  (progn
	    (if (and (buffer-modified-p)
		     (not (yes-or-no-p 
			   (format 
			    "Buffer %s modified; merge file on disc anyhow? " 
			    (buffer-name)))))
		(error "Merge aborted"))
	    (if (not (zerop (vc-backend-merge-news file)))
		;; Overlaps detected - what now?  Should use some
		;; fancy RCS conflict resolving package, or maybe
		;; emerge, but for now, simply warn the user with a
		;; message.
		(message "Conflicts detected!"))
	    (vc-resynch-window file t (not (buffer-modified-p))))

	(error "%s needs update" (buffer-name))))

     ((and buffer-read-only (eq vc-type 'CVS))
      (toggle-read-only)
      ;; Sites who make link farms to a read-only gold tree (or
      ;; something similar) can use the hook below to break the
      ;; sym-link.
      (run-hooks 'vc-make-buffer-writable-hook))

     ;; OK, user owns the lock on the file (or we are running CVS)
     (t
      (find-file file)

      ;; give luser a chance to save before checking in.
      (vc-buffer-sync)

      ;; Revert if file is unchanged and buffer is too.
      ;; If buffer is modified, that means the user just said no
      ;; to saving it; in that case, don't revert,
      ;; because the user might intend to save
      ;; after finishing the log entry.
      (if (and (vc-workfile-unchanged-p file) 
	       (not (buffer-modified-p)))
	  (progn
	    (if (eq vc-type 'CVS)
		(message "No changes to %s" file)

	      (vc-backend-revert file)
	      ;; DO NOT revert the file without asking the user!
	      (vc-resynch-window file t nil)))

	;; user may want to set nonstandard parameters
	(if verbose
	    (setq version (read-string "New version level: ")))

	;; OK, let's do the checkin
	(vc-checkin file version comment)
	)))))

(defun vc-next-action-dired (file rev comment)
  ;; We've accepted a log comment, now do a vc-next-action using it on all
  ;; marked files.
  (set-buffer vc-parent-buffer)
  (dired-map-over-marks
   (save-window-excursion
     (let ((file (dired-get-filename)))
       (message "Processing %s..." file)
       (vc-next-action-on-file file nil comment)
       (message "Processing %s...done" file)))
   nil t)
  )

;; Here's the major entry point.

;;;###autoload
(defun vc-next-action (verbose)
  "Do the next logical checkin or checkout operation on the current file.

For RCS and SCCS files:
   If the file is not already registered, this registers it for version
control and then retrieves a writable, locked copy for editing.
   If the file is registered and not locked by anyone, this checks out
a writable and locked file ready for editing.
   If the file is checked out and locked by the calling user, this
first checks to see if the file has changed since checkout.  If not,
it performs a revert.
   If the file has been changed, this pops up a buffer for entry
of a log message; when the message has been entered, it checks in the
resulting changes along with the log message as change commentary.  If
the variable `vc-keep-workfiles' is non-nil (which is its default), a
read-only copy of the changed file is left in place afterwards.
   If the file is registered and locked by someone else, you are given
the option to steal the lock.

For CVS files:
   If the file is not already registered, this registers it for version
control.  This does a \"cvs add\", but no \"cvs commit\".
   If the file is added but not committed, it is committed.
   If the file has not been changed, neither in your working area or
in the repository, a message is printed and nothing is done.
   If your working file is changed, but the repository file is
unchanged, this pops up a buffer for entry of a log message; when the
message has been entered, it checks in the resulting changes along
with the logmessage as change commentary.  A writable file is retained.
   If the repository file is changed, you are asked if you want to
merge in the changes into your working copy.

The following is true regardless of which version control system you
are using:

   If you call this from within a VC dired buffer with no files marked,
it will operate on the file in the current line.
   If you call this from within a VC dired buffer, and one or more
files are marked, it will accept a log message and then operate on
each one.  The log message will be used as a comment for any register
or checkin operations, but ignored when doing checkouts.  Attempted
lock steals will raise an error.

   For checkin, a prefix argument lets you specify the version number to use."
  (interactive "P")
  (catch 'nogo
    (if vc-dired-mode
	(let ((files (dired-get-marked-files)))
	  (if (= (length files) 1)
	      (find-file-other-window (car files))
	    (vc-start-entry nil nil nil
			    "Enter a change comment for the marked files."
			    'vc-next-action-dired)
	    (throw 'nogo nil))))
    (while vc-parent-buffer
      (pop-to-buffer vc-parent-buffer))
    (if buffer-file-name
	(vc-next-action-on-file buffer-file-name verbose)
      (vc-registration-error nil))))

;;; These functions help the vc-next-action entry point

(defun vc-checkout-writable-buffer (&optional file)
  "Retrieve a writable copy of the latest version of the current buffer's file."
  (vc-checkout (or file (buffer-file-name)) t)
  )

;;;###autoload
(defun vc-register (&optional override comment)
  "Register the current file into your version-control system."
  (interactive "P")
  (let ((master (vc-name buffer-file-name)))
    (and master (file-exists-p master)
	 (error "This file is already registered"))
    (and master
	 (not (y-or-n-p "Previous master file has vanished.  Make a new one? "))
	 (error "This file is already registered")))
  ;; Watch out for new buffers of size 0: the corresponding file
  ;; does not exist yet, even though buffer-modified-p is nil.
  (if (and (not (buffer-modified-p))
	   (zerop (buffer-size))
	   (not (file-exists-p buffer-file-name)))
      (set-buffer-modified-p t))
  (vc-buffer-sync)
  (vc-admin
   buffer-file-name
   (and override
	(read-string
	 (format "Initial version level for %s: " buffer-file-name))))
  )

(defun vc-resynch-window (file &optional keep noquery)
  ;; If the given file is in the current buffer,
  ;; either revert on it so we see expanded keyworks,
  ;; or unvisit it (depending on vc-keep-workfiles)
  ;; NOQUERY if non-nil inhibits confirmation for reverting.
  ;; NOQUERY should be t *only* if it is known the only difference
  ;; between the buffer and the file is due to RCS rather than user editing!
  (and (string= buffer-file-name file)
       (if keep
	   (progn
	     (vc-revert-buffer1 t noquery)
	     (vc-mode-line buffer-file-name))
	 (progn
	   (delete-window)
	   (kill-buffer (current-buffer))))))

(defun vc-start-entry (file rev comment msg action &optional after-hook)
  ;; Accept a comment for an operation on FILE revision REV.  If COMMENT
  ;; is nil, pop up a VC-log buffer, emit MSG, and set the
  ;; action on close to ACTION; otherwise, do action immediately.
  ;; Remember the file's buffer in vc-parent-buffer (current one if no file).
  ;; AFTER-HOOK specifies the local value for vc-log-operation-hook.
  (let ((parent (if file (find-file-noselect file) (current-buffer))))
    (if comment
	(set-buffer (get-buffer-create "*VC-log*"))
      (pop-to-buffer (get-buffer-create "*VC-log*")))
    (set (make-local-variable 'vc-parent-buffer) parent)
    (set (make-local-variable 'vc-parent-buffer-name)
	 (concat " from " (buffer-name vc-parent-buffer)))
    (vc-mode-line (or file " (no file)"))
    (vc-log-mode)
    (make-local-variable 'vc-log-after-operation-hook)
    (if after-hook
	(setq vc-log-after-operation-hook after-hook))
    (setq vc-log-operation action)
    (setq vc-log-file file)
    (setq vc-log-version rev)
    (if comment
	(progn
	  (erase-buffer)
	  (if (eq comment t)
	      (vc-finish-logentry t)
	    (insert comment)
	    (vc-finish-logentry nil)))
      (message "%s  Type C-c C-c when done." msg))))

(defun vc-admin (file rev &optional comment)
  "Check a file into your version-control system.
FILE is the unmodified name of the file.  REV should be the base version
level to check it in under.  COMMENT, if specified, is the checkin comment."
  (vc-start-entry file rev
		  (or comment (not vc-initial-comment))
		  "Enter initial comment." 'vc-backend-admin
		  nil))

(defun vc-checkout (file &optional writable)
  "Retrieve a copy of the latest version of the given file."
  ;; XEmacs - ftp is suppressed by the check for a filename handler in
  ;;	      vc-registered, so this is needless surplussage
  ;; If ftp is on this system and the name matches the ange-ftp format
  ;; for a remote file, the user is trying something that won't work.
  ;;   (if (and (string-match "^/[^/:]+:" file) (vc-find-binary "ftp"))
  ;;       (error "Sorry, you can't check out files over FTP"))
  (vc-backend-checkout file writable)
  (if (string-equal file buffer-file-name)
      (vc-resynch-window file t t))
  )

(defun vc-steal-lock (file rev &optional owner)
  "Steal the lock on the current workfile."
  (let (file-description)
    (if (not owner)
	(setq owner (vc-locking-user file)))
    (if rev
	(setq file-description (format "%s:%s" file rev))
      (setq file-description file))
    (if (not (y-or-n-p (format "Take the lock on %s from %s? "
			       file-description owner)))
	(error "Steal cancelled"))
    (pop-to-buffer (get-buffer-create "*VC-mail*"))
    (setq default-directory (expand-file-name "~/"))
    (auto-save-mode auto-save-default)
    (mail-mode)
    (erase-buffer)
    (mail-setup owner (format "Stolen lock on %s" file-description) nil nil nil
		(list (list 'vc-finish-steal file rev)))
    (goto-char (point-max))
    (insert
     (format "I stole the lock on %s, " file-description)
     (current-time-string)
     ".\n")
    (message "Please explain why you stole the lock.  Type C-c C-c when done.")))

;; This is called when the notification has been sent.
(defun vc-finish-steal (file version)
  (vc-backend-steal file version)
  (if (get-file-buffer file)
      (save-excursion
	(set-buffer (get-file-buffer file))
	(vc-resynch-window file t t))))

(defun vc-checkin (file &optional rev comment)
  "Check in the file specified by FILE.
The optional argument REV may be a string specifying the new version level
\(if nil increment the current level).  The file is either retained with write
permissions zeroed, or deleted (according to the value of `vc-keep-workfiles').
If the back-end is CVS, a writable workfile is always kept.
COMMENT is a comment string; if omitted, a buffer is
popped up to accept a comment."
  (vc-start-entry file rev comment
		  "Enter a change comment." 'vc-backend-checkin
		  'vc-checkin-hook))

;;; Here is a checkin hook that may prove useful to sites using the
;;; ChangeLog facility supported by Emacs.
(defun vc-comment-to-change-log (&optional whoami file-name)
  "Enter last VC comment into change log file for current buffer's file.
Optional arg (interactive prefix) non-nil means prompt for user name and site.
Second arg is file name of change log.  \
If nil, uses `change-log-default-name'."
  (interactive (if current-prefix-arg
		   (list current-prefix-arg
			 (prompt-for-change-log-name))))
  ;; Make sure the defvar for add-log-current-defun-function has been executed
  ;; before binding it.
  (require 'add-log)
  (let (				; Extract the comment first so we get any error before doing anything.
	(comment (ring-ref vc-comment-ring 0))
	;; Don't let add-change-log-entry insert a defun name.
	(add-log-current-defun-function 'ignore)
	end)
    ;; Call add-log to do half the work.
    (add-change-log-entry whoami file-name t t)
    ;; Insert the VC comment, leaving point before it.
    (setq end (save-excursion (insert comment) (point-marker)))
    (if (looking-at "\\s *\\s(")
	;; It starts with an open-paren, as in "(foo): Frobbed."
	;; So remove the ": " add-log inserted.
	(delete-char -2))
    ;; Canonicalize the white space between the file name and comment.
    (just-one-space)
    ;; Indent rest of the text the same way add-log indented the first line.
    (let ((indentation (current-indentation)))
      (save-excursion
	(while (< (point) end)
	  (forward-line 1)
	  (indent-to indentation))
	(setq end (point))))
    ;; Fill the inserted text, preserving open-parens at bol.
    (let ((paragraph-separate (concat paragraph-separate "\\|^\\s *\\s("))
	  (paragraph-start (concat paragraph-start "\\|^\\s *\\s(")))
      (beginning-of-line)
      (fill-region (point) end))
    ;; Canonicalize the white space at the end of the entry so it is
    ;; separated from the next entry by a single blank line.
    (skip-syntax-forward " " end)
    (delete-char (- (skip-syntax-backward " ")))
    (or (eobp) (looking-at "\n\n")
	(insert "\n"))))


(defun vc-finish-logentry (&optional nocomment)
  "Complete the operation implied by the current log entry."
  (interactive)
  ;; Check and record the comment, if any.
  (if (not nocomment)
      (progn
	(goto-char (point-max))
	(if (not (bolp))
	    (newline))
	;; Comment too long?
	(vc-backend-logentry-check vc-log-file)
	;; Record the comment in the comment ring
	(if (null vc-comment-ring)
	    (setq vc-comment-ring (make-ring vc-maximum-comment-ring-size)))
	(ring-insert vc-comment-ring (buffer-string))
	))
  ;; Sync parent buffer in case the user modified it while editing the comment.
  ;; But not if it is a vc-dired buffer.
  (save-excursion
    (set-buffer vc-parent-buffer)
    (or vc-dired-mode
	(vc-buffer-sync)))
  ;; OK, do it to it
  (if vc-log-operation
      (save-excursion
	(funcall vc-log-operation 
		 vc-log-file
		 vc-log-version
		 (buffer-string)))
    (error "No log operation is pending"))
  ;; save the vc-log-after-operation-hook of log buffer
  (let ((after-hook vc-log-after-operation-hook))
    ;; Return to "parent" buffer of this checkin and remove checkin window
    (pop-to-buffer vc-parent-buffer)
    (let ((logbuf (get-buffer "*VC-log*")))
      (delete-windows-on logbuf)
      (kill-buffer logbuf))
    ;; Now make sure we see the expanded headers
    (if buffer-file-name
	(vc-resynch-window buffer-file-name vc-keep-workfiles t))
    (run-hooks after-hook)))

;; Code for access to the comment ring

(defun vc-previous-comment (arg)
  "Cycle backwards through comment history."
  (interactive "*p")
  (let ((len (ring-length vc-comment-ring)))
    (cond ((or (not len) (<= len 0))	; XEmacs change from Barry Warsaw
	   (message "Empty comment ring")
	   (ding))
	  (t
	   (erase-buffer)
	   ;; Initialize the index on the first use of this command
	   ;; so that the first M-p gets index 0, and the first M-n gets
	   ;; index -1.
	   (if (null vc-comment-ring-index)
	       (setq vc-comment-ring-index
		     (if (> arg 0) -1
		       (if (< arg 0) 1 0))))
	   (setq vc-comment-ring-index
		 (mod (+ vc-comment-ring-index arg) len))
	   (message "%d" (1+ vc-comment-ring-index))
	   (insert (ring-ref vc-comment-ring vc-comment-ring-index))))))

(defun vc-next-comment (arg)
  "Cycle forwards through comment history."
  (interactive "*p")
  (vc-previous-comment (- arg)))

(defun vc-comment-search-reverse (str)
  "Searches backwards through comment history for substring match."
  (interactive "sComment substring: ")
  (if (string= str "")
      (setq str vc-last-comment-match)
    (setq vc-last-comment-match str))
  (if (null vc-comment-ring-index)
      (setq vc-comment-ring-index -1))
  (let ((str (regexp-quote str))
	(len (ring-length vc-comment-ring))
	(n (1+ vc-comment-ring-index)))
    (while (and (< n len) (not (string-match str (ring-ref vc-comment-ring n))))
      (setq n (+ n 1)))
    (cond ((< n len)
	   (vc-previous-comment (- n vc-comment-ring-index)))
	  (t (error "Not found")))))

(defun vc-comment-search-forward (str)
  "Searches forwards through comment history for substring match."
  (interactive "sComment substring: ")
  (if (string= str "")
      (setq str vc-last-comment-match)
    (setq vc-last-comment-match str))
  (if (null vc-comment-ring-index)
      (setq vc-comment-ring-index 0))
  (let ((str (regexp-quote str))
	(n vc-comment-ring-index))
    (while (and (>= n 0) (not (string-match str (ring-ref vc-comment-ring n))))
      (setq n (- n 1)))
    (cond ((>= n 0)
	   (vc-next-comment (- n vc-comment-ring-index)))
	  (t (error "Not found")))))

;; Additional entry points for examining version histories

;;;###autoload
(defun vc-diff (historic &optional not-urgent)
  "Display diffs between file versions.
Normally this compares the current file and buffer with the most recent 
checked in version of that file.  This uses no arguments.
With a prefix argument, it reads the file name to use
and two version designators specifying which versions to compare."
  (interactive "P")
  (if vc-dired-mode
      (set-buffer (find-file-noselect (dired-get-filename))))
  (while vc-parent-buffer
    (pop-to-buffer vc-parent-buffer))
  (if historic
      (call-interactively 'vc-version-diff)
    (if (or (null buffer-file-name) (null (vc-name buffer-file-name)))
	(error
	 "There is no version-control master associated with this buffer"))
    (let ((file buffer-file-name)
	  unchanged)
      (or (and file (vc-name file))
	  (vc-registration-error file))
      (vc-buffer-sync not-urgent)
      (setq unchanged (vc-workfile-unchanged-p buffer-file-name))
      (if unchanged
	  (message "No changes to %s since latest version." file)
	(vc-backend-diff file)
	;; Ideally, we'd like at this point to parse the diff so that
	;; the buffer effectively goes into compilation mode and we
	;; can visit the old and new change locations via next-error.
	;; Unfortunately, this is just too painful to do.  The basic
	;; problem is that the `old' file doesn't exist to be
	;; visited.  This plays hell with numerous assumptions in
	;; the diff.el and compile.el machinery.
	(pop-to-buffer "*vc*")
	(setq default-directory (file-name-directory file))
	(if (= 0 (buffer-size))
	    (progn
	      (setq unchanged t)
	      (message "No changes to %s since latest version." file))
	  (goto-char (point-min))
	  (shrink-window-if-larger-than-buffer)))
      (not unchanged))))

;;;###autoload
(defun vc-version-diff (file rel1 rel2)
  "For FILE, report diffs between two stored versions REL1 and REL2 of it.
If FILE is a directory, generate diffs between versions for all registered
files in or below it."
  ;; XEmacs - better prompt  
  (interactive "FFile or directory to diff: \nsOlder version (default is repository): \nsNewer version (default is workfile): ")
  (if (string-equal rel1 "") (setq rel1 nil))
  (if (string-equal rel2 "") (setq rel2 nil))
  (if (file-directory-p file)
      (let ((camefrom (current-buffer)))
	(set-buffer (get-buffer-create "*vc-status*"))
	(set (make-local-variable 'vc-parent-buffer) camefrom)
	(set (make-local-variable 'vc-parent-buffer-name)
	     (concat " from " (buffer-name camefrom)))
	(erase-buffer)
	(insert "Diffs between "
		(or rel1 "last version checked in")
		" and "
		(or rel2 "current workfile(s)")
		":\n\n")
	(set-buffer (get-buffer-create "*vc*"))
	(cd file)
	(vc-file-tree-walk
	 (function (lambda (f)
		     (message "Looking at %s" f)
		     (and
		      (not (file-directory-p f))
		      (vc-registered f)
		      (vc-backend-diff f rel1 rel2)
		      (append-to-buffer "*vc-status*" (point-min) (point-max)))
		     )))
	(pop-to-buffer "*vc-status*")
	(insert "\nEnd of diffs.\n")
	(goto-char (point-min))
	(set-buffer-modified-p nil)
	)
    (if (zerop (vc-backend-diff file rel1 rel2))
	(message "No changes to %s between %s and %s." file rel1 rel2)
      (pop-to-buffer "*vc*"))))

;;;###autoload
(defun vc-version-other-window (rev)
  "Visit version REV of the current buffer in another window.
If the current buffer is named `F', the version is named `F.~REV~'.
If `F.~REV~' already exists, it is used instead of being re-created."
  (interactive "sVersion to visit (default is latest version): ")
  (if vc-dired-mode
      (set-buffer (find-file-noselect (dired-get-filename))))
  (while vc-parent-buffer
    (pop-to-buffer vc-parent-buffer))
  (if (and buffer-file-name (vc-name buffer-file-name))
      (let* ((version (if (string-equal rev "")
			  (vc-latest-version buffer-file-name)
			rev))
	     (filename (concat buffer-file-name ".~" version "~")))
	(or (file-exists-p filename)
	    (vc-backend-checkout buffer-file-name nil version filename))
	(find-file-other-window filename))
    (vc-registration-error buffer-file-name)))

;; Header-insertion code

;;;###autoload
(defun vc-insert-headers ()
  "Insert headers in a file for use with your version-control system.
Headers desired are inserted at the start of the buffer, and are pulled from
the variable `vc-header-alist'."
  (interactive)
  (if vc-dired-mode
      (find-file-other-window (dired-get-filename)))
  (while vc-parent-buffer
    (pop-to-buffer vc-parent-buffer))
  (save-excursion
    (save-restriction
      (widen)
      (if (or (not (vc-check-headers))
	      (y-or-n-p "Version headers already exist.  Insert another set? "))
	  (progn
	    (let* ((delims (cdr (assq major-mode vc-comment-alist)))
		   (comment-start-vc (or (car delims) comment-start "#"))
		   (comment-end-vc (or (car (cdr delims)) comment-end ""))
		   (hdstrings (cdr (assoc (vc-backend-deduce buffer-file-name)
					  vc-header-alist))))
	      (mapcar #'(lambda (s)
			  (insert comment-start-vc "\t" s "\t"
				  comment-end-vc "\n"))
		      hdstrings)
	      (if vc-static-header-alist
		  (mapcar #'(lambda (f)
			      (if (and buffer-file-name
				       (string-match (car f) buffer-file-name))
				  (insert (format (cdr f) (car hdstrings)))))
			  vc-static-header-alist))
	      )
	    )))))

;; The VC directory submode.  Coopt Dired for this.
;; All VC commands get mapped into logical equivalents.

;; XEmacs
(defvar vc-dired-prefix-map (let ((map (make-sparse-keymap)))
			      (set-keymap-name map 'vc-dired-prefix-map)
			      (define-key map "\C-xv" vc-prefix-map)
			      map))

(or (not (boundp 'minor-mode-map-alist))
    (assq 'vc-dired-mode minor-mode-map-alist)
    (setq minor-mode-map-alist
	  (cons (cons 'vc-dired-mode vc-dired-prefix-map)
		minor-mode-map-alist)))

(defun vc-dired-mode ()
  "The augmented Dired minor mode used in VC directory buffers.
All Dired commands operate normally.  Users currently locking listed files
are listed in place of the file's owner and group.
Keystrokes bound to VC commands will execute as though they had been called
on a buffer attached to the file named in the current Dired buffer line."
  (setq vc-dired-mode t)
  (setq vc-mode " under VC"))

(defun vc-dired-reformat-line (x)
  ;; Hack a directory-listing line, plugging in locking-user info in
  ;; place of the user and group info.  Should have the beneficial
  ;; side-effect of shortening the listing line.  Each call starts with
  ;; point immediately following the dired mark area on the line to be
  ;; hacked.
  ;;
  ;; Simplest possible one:
  ;; (insert (concat x "\t")))
  ;;
  ;; This code, like dired, assumes UNIX -l format.
  (forward-word 1)			; skip over any extra field due to -ibs options
  (cond ((numberp x)			; This hack is used by the CVS code.  See vc-locking-user.
	 (cond
	  ((re-search-forward "\\([0-9]+ \\)\\([^ ]+\\)\\( .*\\)" nil 0)
	   (save-excursion
	     (goto-char (match-beginning 2))
	     (insert "(")
	     (goto-char (1+ (match-end 2)))
	     (insert ")")
	     (delete-char (- 17 (- (match-end 2) (match-beginning 2))))
	     (insert (substring "      " 0
				(- 7 (- (match-end 2) (match-beginning 2)))))))))
	(t
	 (if x (setq x (concat "(" x ")")))
	 (if (re-search-forward "\\([0-9]+ \\).................\\( .*\\)" nil 0)
	     (let ((rep (substring (concat x "                 ") 0 9)))
	       (replace-match (concat "\\1" rep "\\2") t)))
	 )))

;;;###autoload
(defun vc-directory (dir verbose &optional nested)
  "Show version-control status of all files in the directory DIR.
If the second argument VERBOSE is non-nil, show all files;
otherwise show only files that current locked in the version control system.
Interactively, supply a prefix arg to make VERBOSE non-nil.

If the optional third argument NESTED is non-nil,
scan the entire tree of subdirectories of the current directory."
  (interactive "DVC status of directory: \nP")
  (let* (nonempty
	 (dl (length dir))
	 (filelist nil) (userlist nil)
	 dired-buf
	 (subfunction
	  (function (lambda (f)
		      (if (vc-registered f)
			  (let ((user (vc-locking-user f)))
			    (and (or verbose user)
				 (setq filelist (cons (substring f dl) filelist))
				 (setq userlist (cons user userlist)))))))))
    (let ((default-directory dir))
      (if nested
	  (vc-file-tree-walk subfunction)
	(vc-dir-all-files subfunction)))
    (save-excursion
      (dired (make-string-stringlist (cons dir (nreverse filelist)))
     	     dired-listing-switches) 
      (rename-buffer (generate-new-buffer-name "VC-DIRED"))
      (setq dired-buf (current-buffer))
      (setq nonempty (not (zerop (buffer-size)))))
    (if nonempty
	(progn
	  (pop-to-buffer dired-buf)
	  (vc-dired-mode)
	  (goto-char (point-min))
	  (setq buffer-read-only nil)
	  (forward-line 1)		; Skip header line
	  (mapcar
	   (function
	    (lambda (x)
	      (forward-char 2)		; skip dired's mark area
	      (vc-dired-reformat-line x)
	      (forward-line 1)))	; go to next line
	   (nreverse userlist))
	  (setq buffer-read-only t)
	  (goto-char (point-min))
	  )
      (message "No files are currently %s under %s"
	       (if verbose "registered" "locked") default-directory))
    ))

(defun make-string-stringlist (stringlist)
  "Turn a list of strings into a string of space-delimited elements."
  (save-excursion
    (let ((tlist stringlist)
     	  (buf (generate-new-buffer "*stringlist*")))
      (set-buffer buf)
      (insert (car tlist))
      (setq tlist (cdr tlist))
      (while (not (null tlist))
     	(setq s (car tlist))
     	(insert s " ")
     	(setq tlist (cdr tlist)))
      (setq string (buffer-string))
      (kill-this-buffer)
      string
      )))

;; Named-configuration support for SCCS

(defun vc-add-triple (name file rev)
  (save-excursion
    (find-file (concat (vc-backend-subdirectory-name file) "/" vc-name-assoc-file))
    (goto-char (point-max))
    (insert name "\t:\t" file "\t" rev "\n")
    (basic-save-buffer)
    (kill-buffer (current-buffer))
    ))

(defun vc-record-rename (file newname)
  (save-excursion
    (find-file (concat (vc-backend-subdirectory-name file) "/" vc-name-assoc-file))
    (goto-char (point-min))
    ;; (replace-regexp (concat ":" (regexp-quote file) "$") (concat ":" newname))
    (while (re-search-forward (concat ":" (regexp-quote file) "$") nil t)
      (replace-match (concat ":" newname) nil nil))
    (basic-save-buffer)
    (kill-buffer (current-buffer))
    ))

(defun vc-lookup-triple (file name)
  ;; Return the numeric version corresponding to a named snapshot of file
  ;; If name is nil or a version number string it's just passed through
  (cond ((null name) name)
	((let ((firstchar (aref name 0)))
	   (and (>= firstchar ?0) (<= firstchar ?9)))
	 name)
	(t
	 (car (vc-master-info
	       (concat (vc-backend-subdirectory-name file) "/" vc-name-assoc-file)
	       (list (concat name "\t:\t" file "\t\\(.+\\)"))))
	 )))

;; Named-configuration entry points

(defun vc-locked-example ()
  ;; Return an example of why the current directory is not ready to be snapshot
  ;; or nil if no such example exists.
  (catch 'vc-locked-example
    (vc-file-tree-walk
     (function (lambda (f)
		 (if (and (vc-registered f) (vc-locking-user f))
		     (throw 'vc-locked-example f)))))
    nil))

;;;###autoload
(defun vc-create-snapshot (name)
  "Make a snapshot called NAME.
The snapshot is made from all registered files at or below the current
directory.  For each file, the version level of its latest
version becomes part of the named configuration."
  (interactive "sNew snapshot name: ")
  (let ((locked (vc-locked-example)))
    (if locked
	(error "File %s is locked" locked)
      (vc-file-tree-walk
       (function (lambda (f) (and
			      (vc-name f)
			      (vc-backend-assign-name f name)))))
      )))

;;;###autoload
(defun vc-retrieve-snapshot (name)
  "Retrieve the snapshot called NAME.
This function fails if any files are locked at or below the current directory
Otherwise, all registered files are checked out (unlocked) at their version
levels in the snapshot."
  (interactive "sSnapshot name to retrieve: ")
  (let ((locked (vc-locked-example)))
    (if locked
        (error "File %s is locked" locked)
      (vc-file-tree-walk
       (function (lambda (f) (and
			      (vc-name f)
			      (vc-error-occurred
                               (vc-backend-checkout f nil name))))))
      )))

;; Miscellaneous other entry points

;;;###autoload
(defun vc-print-log ()
  "List the change log of the current buffer in a window."
  (interactive)
  (if vc-dired-mode
      (set-buffer (find-file-noselect (dired-get-filename))))
  (while vc-parent-buffer
    (pop-to-buffer vc-parent-buffer))
  (if (and buffer-file-name (vc-name buffer-file-name))
      (let ((file buffer-file-name))
        (vc-backend-print-log file)
	(pop-to-buffer (get-buffer-create "*vc*"))
	(setq default-directory (file-name-directory file))
	(while (looking-at "=*\n")
	  (delete-char (- (match-end 0) (match-beginning 0)))
	  (forward-line -1))
	(goto-char (point-min))
	(if (looking-at "[\b\t\n\v\f\r ]+")
	    (delete-char (- (match-end 0) (match-beginning 0))))
        (shrink-window-if-larger-than-buffer)
	)
    (vc-registration-error buffer-file-name)))

;;;###autoload
(defun vc-revert-buffer ()
  "Revert the current buffer's file back to the latest checked-in version.
This asks for confirmation if the buffer contents are not identical
to that version.
If the back-end is CVS, this will give you the most recent revision of
the file on the branch you are editing."
  (interactive)
  (if vc-dired-mode
      (find-file-other-window (dired-get-filename)))
  (while vc-parent-buffer
    (pop-to-buffer vc-parent-buffer))
  (let ((file buffer-file-name)
	(obuf (current-buffer)) (changed (vc-diff nil t)))
    (if (and changed (or vc-suppress-confirm
			 (not (yes-or-no-p "Discard changes? "))))
	(progn
	  (delete-window)
	  (error "Revert cancelled"))
      (set-buffer obuf))
    (if changed
	(delete-window))
    (vc-backend-revert file)
    (vc-resynch-window file t t)
    ))

;;;###autoload
(defun vc-cancel-version (norevert)
  "Get rid of most recently checked in version of this file.
A prefix argument means do not revert the buffer afterwards."
  (interactive "P")
  (if vc-dired-mode
      (find-file-other-window (dired-get-filename)))
  (while vc-parent-buffer
    (pop-to-buffer vc-parent-buffer))
  (let* ((target (concat (vc-latest-version (buffer-file-name))))
	 (yours (concat (vc-your-latest-version (buffer-file-name))))
	 (prompt (if (string-equal yours target)
		     "Remove your version %s from master? "
		   "Version %s was not your change.  Remove it anyway? ")))
    (if (null (yes-or-no-p (format prompt target)))
	nil
      (vc-backend-uncheck (buffer-file-name) target)
      (if (or norevert
	      (not (yes-or-no-p "Revert buffer to most recent remaining version? ")))
	  (vc-mode-line (buffer-file-name))
	(vc-checkout (buffer-file-name) nil)))
    ))

;;;###autoload
(defun vc-rename-file (old new)
  "Rename file OLD to NEW, and rename its master file likewise."
  (interactive "fVC rename file: \nFRename to: ")
  ;; There are several ways of renaming files under CVS 1.3, but they all
  ;; have serious disadvantages.  See the FAQ (available from think.com in
  ;; pub/cvs/).  I'd rather send the user an error, than do something he might
  ;; consider to be wrong.  When the famous, long-awaited rename database is
  ;; implemented things might change for the better.  This is unlikely to occur
  ;; until CVS 2.0 is released.  --ceder 1994-01-23 21:27:51
  (if (eq (vc-backend-deduce old) 'CVS)
      (error "Renaming files under CVS is dangerous and not supported in VC."))
  (if (eq (vc-backend-deduce old) 'CC)
      (error "VC's ClearCase support cannot rename files."))
  (let ((oldbuf (get-file-buffer old)))
    (if (and oldbuf (buffer-modified-p oldbuf))
	(error "Please save files before moving them"))
    (if (get-file-buffer new)
	(error "Already editing new file name"))
    (if (file-exists-p new)
	(error "New file already exists"))
    (let ((oldmaster (vc-name old)))
      (if oldmaster
	  (progn
            (if (vc-locking-user old)
		(error "Please check in files before moving them"))
	    (if (or (file-symlink-p oldmaster)
		    ;; This had FILE, I changed it to OLD. -- rms.
		    (file-symlink-p (vc-backend-subdirectory-name old)))
                (error "This is not a safe thing to do in the presence of symbolic links"))
	    (rename-file
             oldmaster
	     (let ((backend (vc-backend-deduce old))
		   (newdir (or (file-name-directory new) ""))
		   (newbase (file-name-nondirectory new)))
	       (catch 'found
		 (mapcar
                  (function
		   (lambda (s)
		     (if (eq backend (cdr s))
			 (let* ((newmaster (format (car s) newdir newbase))
				(newmasterdir (file-name-directory newmaster)))
			   (if (or (not newmasterdir)
				   (file-directory-p newmasterdir))
			       (throw 'found newmaster))))))
		  vc-master-templates)
		 (error "New file lacks a version control directory"))))))
      (if (or (not oldmaster) (file-exists-p old))
	  (rename-file old new)))
    ;; ?? Renaming a file might change its contents due to keyword expansion.
    ;; We should really check out a new copy if the old copy was precisely equal
    ;; to some checked in version.  However, testing for this is tricky....
    (if oldbuf
        (save-excursion
	  (set-buffer oldbuf)
	  (set-visited-file-name new)
	  (set-buffer-modified-p nil))))
  ;; This had FILE, I changed it to OLD. -- rms.
  (vc-backend-dispatch old
    (vc-record-rename old new)		;SCCS
    ;; #### - This CAN kinda be done for both rcs and
    ;; cvs.  It needs to be implemented. -- Stig
    nil					;RCS
    nil					;CVS
    nil					;CC
    )
  )

;;;###autoload
(defun vc-update-change-log (&rest args)
  "Find change log file and add entries from recent RCS logs.
The mark is left at the end of the text prepended to the change log.
With prefix arg of C-u, only find log entries for the current buffer's file.
With any numeric prefix arg, find log entries for all files currently visited.
Otherwise, find log entries for all registered files in the default directory.
From a program, any arguments are passed to the `rcs2log' script."
  (interactive
   (cond ((consp current-prefix-arg)	;C-u
	  (list buffer-file-name))
	 (current-prefix-arg            ;Numeric argument.
	  (let ((files nil)
		(buffers (buffer-list))
		file)
	    (while buffers
	      (setq file (buffer-file-name (car buffers)))
	      (and file (vc-backend-deduce file)
                   (setq files (cons file files)))
	      (setq buffers (cdr buffers)))
	    files))
	 (t
	  (let ((RCS (concat default-directory "RCS")))
	    (and (file-directory-p RCS)
		 (mapcar (function
			  (lambda (f)
			    (if (string-match "\\(.*\\),v$" f)
				(substring f 0 (match-end 1))
			      f)))
			 (directory-files RCS nil "...\\|^[^.]\\|^.[^.]")))))))
  (let ((odefault default-directory))
    (find-file-other-window (find-change-log))
    (barf-if-buffer-read-only)
    (vc-buffer-sync)
    (undo-boundary)
    (goto-char (point-min))
    (push-mark)
    (message "Computing change log entries...")
    (message "Computing change log entries... %s"
	     (if (or (null args)
                     (eq 0 (apply 'call-process "rcs2log" nil t nil
				  "-n"
				  (user-login-name)
				  (user-full-name)
				  user-mail-address
				  (mapcar (function
					   (lambda (f)
					     (file-relative-name
                                              (if (file-name-absolute-p f)
						  f
						(concat odefault f)))))
					  args))))
		 "done" "failed"))))

;; Functions for querying the master and lock files.

;; XEmacs - use match-string instead...
;; (defun vc-match-substring (bn)
;;   (buffer-substring (match-beginning bn) (match-end bn)))

(defun vc-parse-buffer (patterns &optional file properties)
  ;; Each pattern is of the form:
  ;;    regex                ; subex is 1, and date-subex is 2 (or nil)
  ;;    (regex subex date-subex)
  ;;
  ;; Use PATTERNS to parse information out of the current buffer by matching
  ;; each REGEX in the list and the returning the string matched by SUBEX.
  ;; If a DATE-SUBEX is present, then the SUBEX from the match with the
  ;; highest value for DATE-SUBEX (string comparison is used) will be
  ;; returned.
  ;;
  ;; If FILE and PROPERTIES are given, the latter must be a list of
  ;; properties of the same length as PATTERNS; each property is assigned
  ;; the corresponding value.
  ;;
  (let (pattern regex subex date-subex latest-date val values date)
    (while (setq pattern (car patterns))
      (if (stringp pattern)
	  (setq regex pattern
		subex 1
		date-subex (and (string-match "\\\\(.*\\\\(" regex) 2))
	(setq regex (car pattern)
	      subex (nth 1 pattern)
	      date-subex (nth 2 pattern)))
      (goto-char (point-min))
      (if date-subex
	  (progn
	    (setq latest-date "" val nil)
	    (while (re-search-forward regex nil t)
	      (setq date (match-string date-subex))
	      (if (string< latest-date date)
		  (setq latest-date date
			val (match-string subex))))
	    val)
	;; no date subex, so just take the first match...
	(setq val (and (re-search-forward regex nil t) (match-string subex))))
      (if file (vc-file-setprop file (car properties) val))
      (setq values (cons val values)
	    patterns (cdr patterns)
	    properties (cdr properties)))
    values
    ))

(defun vc-master-info (file fields &optional rfile properties)
  ;; Search for information in a master file.
  (if (and file (file-exists-p file))
      (save-excursion
	(let ((buf))
	  (setq buf (create-file-buffer file))
	  (set-buffer buf))
	(erase-buffer)
	(insert-file-contents file)
	(set-buffer-modified-p nil)
	(auto-save-mode nil)
	(prog1
	    (vc-parse-buffer fields rfile properties)
	  (kill-buffer (current-buffer)))
	)
    (if rfile
	(mapcar
	 (function (lambda (p) (vc-file-setprop rfile p nil)))
	 properties))
    )
  )

(defun vc-log-info (command file last flags patterns &optional properties)
  ;; Search for information in log program output
  (if (and file (file-exists-p file))
      (save-excursion
	(set-buffer (get-buffer-create "*vc*"))
	(apply 'vc-do-command 0 command file last flags)
        (set-buffer-modified-p nil)
	(prog1
	    (vc-parse-buffer patterns file properties)
	  (kill-buffer (current-buffer))
          )
	)
    (if file
	(mapcar
	 (function (lambda (p) (vc-file-setprop file p nil)))
	 properties))
    )
  )

(defun vc-locking-user (file)
  "Return the name of the person currently holding a lock on FILE.
Return nil if there is no such person.
Under CVS, a file is considered locked if it has been modified since it
was checked out...even though it may well be writable by you."
  (setq file (expand-file-name file))	; use full pathname
  (cond ((eq (vc-backend-deduce file) 'CVS)
	 (if (vc-workfile-unchanged-p file t)
	     nil
	   ;; XEmacs - ahead of the pack...
	   (user-login-name (nth 2 (file-attributes file)))))
	(t
	 ;; #### - this can probably be cleaned up as a result of the changes to
	 ;; user-login-name...  
	 (if (or (not vc-keep-workfiles)
		 (eq vc-mistrust-permissions 't)
		 (and vc-mistrust-permissions
		      (funcall vc-mistrust-permissions (vc-backend-subdirectory-name
							file))))
	     (vc-true-locking-user file)
	   ;; This implementation assumes that any file which is under version
	   ;; control and has -rw-r--r-- is locked by its owner.  This is true
	   ;; for both RCS and SCCS, which keep unlocked files at -r--r--r--.
	   ;; We have to be careful not to exclude files with execute bits on;
	   ;; scripts can be under version control too.  Also, we must ignore
	   ;; the group-read and other-read bits, since paranoid users turn them off.
	   ;; This hack wins because calls to the very expensive vc-fetch-properties
	   ;; function only have to be made if (a) the file is locked by someone
	   ;; other than the current user, or (b) some untoward manipulation
	   ;; behind vc's back has changed the owner or the `group' or `other'
	   ;; write bits.
	   (let ((attributes (file-attributes file)))
	     (cond ((string-match ".r-..-..-." (nth 8 attributes))
		    nil)
		   ((and (= (nth 2 attributes) (user-uid))
			 (string-match ".rw..-..-." (nth 8 attributes)))
		    (user-login-name))
		   (t
		    (vc-true-locking-user file)))) ; #### - this looks recursive!!!
	   ))))

(defun vc-true-locking-user (file)
  ;; The slow but reliable version
  (vc-fetch-properties file)
  (vc-file-getprop file 'vc-locking-user))

(defun vc-latest-version (file)
  ;; Return version level of the latest version of FILE
  (vc-fetch-properties file)
  (vc-file-getprop file 'vc-latest-version))

(defun vc-your-latest-version (file)
  ;; Return version level of the latest version of FILE checked in by you
  (vc-fetch-properties file)
  (vc-file-getprop file 'vc-your-latest-version))

;; Collect back-end-dependent stuff here
;;
;; Everything eventually funnels through these functions.  To implement
;; support for a new version-control system, add another branch to the
;; vc-backend-dispatch macro and fill it in in each call.  The variable
;; vc-master-templates in vc-hooks.el will also have to change.

(put 'vc-backend-dispatch 'lisp-indent-function 'defun)

(defmacro vc-backend-dispatch (f s r c a)
  "Execute FORM1, FORM2 or FORM3 depending whether we're using SCCS, RCS, CVS
or ClearCase.
If FORM3 is RCS, use FORM2 even if we are using CVS.  (CVS shares some code 
with RCS)."
  (list 'let (list (list 'type (list 'vc-backend-deduce f)))
	(list 'cond
	      (list (list 'eq 'type (quote 'SCCS)) s) ; SCCS
	      (list (list 'eq 'type (quote 'RCS)) r) ; RCS
	      (list (list 'eq 'type (quote 'CVS)) ; CVS
		    (if (eq c 'RCS) r c))
	      (list (list 'eq 'type (quote 'CC)) a) ; CC
	      )))

(defun vc-lock-file (file)
  ;; Generate lock file name corresponding to FILE
  (let ((master (vc-name file)))
    (and
     master
     (string-match "\\(.*/\\)s\\.\\(.*\\)" master)
     (concat
      (substring master (match-beginning 1) (match-end 1))
      "p."
      (substring master (match-beginning 2) (match-end 2))))))


(defun vc-fetch-properties (file)
  ;; Re-fetch all properties associated with the given file.
  ;; Currently these properties are:
  ;;   vc-locking-user
  ;;   vc-locked-version 
  ;;   vc-latest-version
  ;;   vc-your-latest-version
  ;;   vc-cvs-status (cvs only)
  ;;   vc-cc-predecessor (ClearCase only)
  (vc-backend-dispatch
    file
    ;; SCCS
    (progn
      (vc-master-info (vc-lock-file file)
		      (list
		       "^[^ ]+ [^ ]+ \\([^ ]+\\)"
		       "^\\([^ ]+\\)")
		      file
		      '(vc-locking-user vc-locked-version))
      (vc-master-info (vc-name file)
		      (list
		       "^\001d D \\([^ ]+\\)"
		       (concat "^\001d D \\([^ ]+\\) .* " 
			       (regexp-quote (user-login-name)) " ")
		       )
		      file
		      '(vc-latest-version vc-your-latest-version))
      )
    ;; RCS
    (vc-log-info "rlog" file 'MASTER nil
		 (list
		  "^locks: strict\n\t\\([^:]+\\)"
		  "^locks: strict\n\t[^:]+: \\(.+\\)"
		  "^revision[\t ]+\\([0-9.]+\\).*\ndate: \\([ /0-9:]+\\);"
		  (concat
		   "^revision[\t ]+\\([0-9.]+\\)\n.*author: "
		   (regexp-quote (user-login-name))
		   ";"))
		 '(vc-locking-user vc-locked-version
				   vc-latest-version vc-your-latest-version))
    ;; CVS
    ;; Don't fetch vc-locking-user and vc-locked-version here, since they
    ;; should always be nil anyhow.  Don't fetch vc-your-latest-version, since
    ;; that is done in vc-find-cvs-master.
    (vc-log-info
     "cvs" file 'WORKFILE '("status")
     ;; CVS 1.3 says "RCS Version:", other releases "RCS Revision:",
     ;; and CVS 1.4a1 says "Repository revision:".  The regexp below
     ;; matches much more, but because of the way vc-log-info is
     ;; implemented it is impossible to use additional groups.
     '(("\\(RCS Version\\|RCS Revision\\|Repository revision\\):[\t ]+\\([0-9.]+\\)" 2)
       "Status: \\(.*\\)")
     '(vc-latest-version
       vc-cvs-status))
    ;; CC
    (vc-log-info "cleartool" file 'WORKFILE '("describe")
		 (list 
		  "checked out .* by .* (\\([^ .]+\\)..*@.*)"
		  "from \\([^ ]+\\) (reserved)"
		  "version [^\"]*\".*@@\\([^ ]+\\)\""
		  "version [^\"]*\".*@@\\([^ ]+\\)\""
		  "predecessor version: \\([^ ]+\\)\n")
		 '(vc-locking-user vc-locked-version
				   vc-latest-version vc-your-latest-version
				   vc-cc-predecessor))
    ))

(defun vc-backend-subdirectory-name (&optional file)
  ;; Where the master and lock files for the current directory are kept
  (let ((backend
	 (or
	  (and file (vc-backend-deduce file))
	  vc-default-back-end
	  (setq vc-default-back-end (if (vc-find-binary "rcs") 'RCS 'SCCS)))))
    (cond
     ((eq backend 'SCCS) "SCCS")
     ((eq backend 'RCS)  "RCS")
     ((eq backend 'CVS)  "CVS")
     ((eq backend 'CC)   "@@"))
    ))
  
(defun vc-backend-admin (file &optional rev comment)
  ;; Register a file into the version-control system
  ;; Automatically retrieves a read-only version of the file with
  ;; keywords expanded if vc-keep-workfiles is non-nil, otherwise
  ;; it deletes the workfile.
  (vc-file-clearprops file)
  (or vc-default-back-end
      (setq vc-default-back-end (if (vc-find-binary "rcs") 'RCS 'SCCS)))
  (message "Registering %s..." file)
  (let ((backend
         (cond
	  ((file-exists-p (vc-backend-subdirectory-name)) vc-default-back-end)
	  ((file-exists-p "RCS") 'RCS)
	  ((file-exists-p "SCCS") 'SCCS)
          ((file-exists-p "CVS") 'CVS)
	  ((file-exists-p "@@") 'CC)
	  (t vc-default-back-end))))
    (cond ((eq backend 'SCCS)
	   (vc-do-command 0 "admin" file 'MASTER ; SCCS
			  (and rev (concat "-r" rev))
			  "-fb"
			  (concat "-i" file)
			  (and comment (concat "-y" comment))
			  (format
			   (car (rassq 'SCCS vc-master-templates))
			   (or (file-name-directory file) "")
			   (file-name-nondirectory file)))
	   (delete-file file)
	   (if vc-keep-workfiles
               (vc-do-command 0 "get" file 'MASTER)))
	  ((eq backend 'RCS)
	   (vc-do-command 0 "ci" file 'MASTER ; RCS
			  (concat (if vc-keep-workfiles "-u" "-r") rev)
			  (and comment (concat "-t-" comment))
			  file))
          ((eq backend 'CVS)
	   ;; #### - should maybe check to see if the master file is
	   ;; already in the repository...in which case we need to add the
	   ;; appropriate branch tag and do  an update.
	   ;; #### - note that adding a file is a 2 step process in CVS...
	   (vc-do-command 0 "cvs" file 'WORKFILE "add")
	   (vc-do-command 0 "cvs" file 'WORKFILE "commit"
			  (and comment (not (string= comment ""))
			       (concat "-m" comment)))
	   )
	  ((eq backend 'CC)
	   (vc-do-command 0 "cleartool" file 'WORKFILE ; CC
			  "mkelem"
			  (if (string-equal "" comment)
			      "-nc")
			  (if (not (string-equal "" comment))
			      "-c")
			  (if (not (string-equal "" comment))
			      comment)
			  )
	   (vc-do-command 0 "cleartool" file 'WORKFILE
			  "checkin" "-identical" "-nc"
			  )
	   )))
  (message "Registering %s...done" file)
  )

(defun vc-backend-checkout (file &optional writable rev workfile)
  ;; Retrieve a copy of a saved version into a workfile
  (let ((filename (or workfile file)))
    (message "Checking out %s..." filename)
    (save-excursion
      ;; Change buffers to get local value of vc-checkin-switches.
      (set-buffer (or (get-file-buffer file) (current-buffer)))
      (vc-backend-dispatch
	file
	;; SCCS
	(if workfile
	    ;; Some SCCS implementations allow checking out directly to a
	    ;; file using the -G option, but then some don't so use the
	    ;; least common denominator approach and use the -p option
	    ;; ala RCS.
	    (let ((vc-modes (logior (file-modes (vc-name file))
				    (if writable 128 0)))
		  (failed t))
	      (unwind-protect
		  (progn
		    (apply 'vc-do-command
			   0 "/bin/sh" file 'MASTER "-c"
			   ;; Some shells make the "" dummy argument into $0
			   ;; while others use the shell's name as $0 and
			   ;; use the "" as $1.  The if-statement
			   ;; converts the latter case to the former.
			   (format "if [ x\"$1\" = x ]; then shift; fi; \
                              umask %o; exec >\"$1\" || exit; \
                               shift; umask %o; exec get \"$@\""
				   (logand 511 (lognot vc-modes))
				   (logand 511 (lognot (default-file-modes))))
			   ""		; dummy argument for shell's $0
			   filename 
			   (if writable "-e")
			   "-p" (and rev
				     (concat "-r" (vc-lookup-triple file rev)))
			   vc-checkout-switches)
		    (setq failed nil))
		(and failed (file-exists-p filename) (delete-file filename))))
	  (apply 'vc-do-command 0 "get" file 'MASTER ; SCCS
		 (if writable "-e")
		 (and rev (concat "-r" (vc-lookup-triple file rev)))
		 vc-checkout-switches))
	;; RCS
	(if workfile
	    ;; RCS doesn't let us check out into arbitrary file names directly.
	    ;; Use `co -p' and make stdout point to the correct file.
	    (let ((vc-modes (logior (file-modes (vc-name file))
				    (if writable 128 0)))
		  (failed t))
	      (unwind-protect
		  (progn
		    (apply 'vc-do-command
			   0 "/bin/sh" file 'MASTER "-c"
			   ;; See the SCCS case, above, regarding the
			   ;; if-statement.
			   (format "if [ x\"$1\" = x ]; then shift; fi; \
                              umask %o; exec >\"$1\" || exit; \
                               shift; umask %o; exec co \"$@\""
				   (logand 511 (lognot vc-modes))
				   (logand 511 (lognot (default-file-modes))))
			   ""		; dummy argument for shell's $0
			   filename
			   (if writable "-l")
			   (concat "-p" rev)
			   vc-checkout-switches)
		    (setq failed nil))
		(and failed (file-exists-p filename) (delete-file filename))))
	  (apply 'vc-do-command 0 "co" file 'MASTER
		 (if writable "-l")
		 (and rev (concat "-r" rev))
		 vc-checkout-switches))
	;; CVS
	(if workfile
	    ;; CVS is much like RCS
	    (let ((failed t))
	      (unwind-protect
		  (progn
		    (apply 'vc-do-command
			   0 "/bin/sh" file 'WORKFILE "-c"
			   "exec >\"$1\" || exit; shift; exec cvs update \"$@\""
			   ""		; dummy argument for shell's $0
			   workfile
			   (concat "-r" rev)
			   "-p"
			   vc-checkout-switches)
		    (setq failed nil))
		(and failed (file-exists-p filename) (delete-file filename))))
	  (apply 'vc-do-command 0 "cvs" file 'WORKFILE
		 "update"
		 (and rev (concat "-r" rev))
		 file
		 vc-checkout-switches))
	;; CC
	(if (or rev workfile)
	    (error "VC's ClearCase support currently checks out /main/LATEST.")
	  (apply 'vc-do-command 0 "cleartool" file 'WORKFILE
		 "checkout" "-nc"
		 vc-checkout-switches))
	))
    (or workfile
	(vc-file-setprop file
			 'vc-checkout-time (nth 5 (file-attributes file))))
    (message "Checking out %s...done" filename))
  )

(defun vc-backend-logentry-check (file)
  (vc-backend-dispatch file
    (if (>= (buffer-size) 512)		; SCCS
	(progn
	  (goto-char 512)
	  (error
	   "Log must be less than 512 characters; point is now at pos 512")))
    nil					; RCS
    nil					; CVS
    nil)				; CC
  )

(defun vc-backend-checkin (file rev comment)
  ;; Register changes to FILE as level REV with explanatory COMMENT.
  ;; Automatically retrieves a read-only version of the file with
  ;; keywords expanded if vc-keep-workfiles is non-nil, otherwise
  ;; it deletes the workfile.
  (message "Checking in %s..." file)
  (save-excursion
    ;; Change buffers to get local value of vc-checkin-switches.
    (set-buffer (or (get-file-buffer file) (current-buffer)))
    (vc-backend-dispatch file
      (progn
	(apply 'vc-do-command 0 "delta" file 'MASTER
	       (if rev (concat "-r" rev))
	       (concat "-y" comment)
	       vc-checkin-switches)
	(if vc-keep-workfiles
	    (vc-do-command 0 "get" file 'MASTER))
	)
      (apply 'vc-do-command 0 "ci" file 'MASTER
	     (concat (if vc-keep-workfiles "-u" "-r") rev)
	     (if (not (string-equal "" comment))
		 (concat "-m" comment))
	     vc-checkin-switches)
      (progn
	(apply 'vc-do-command 0 "cvs" file 'WORKFILE 
	       "ci"
	       (if (not (string-equal "" comment))
		   (concat "-m" comment))
	       vc-checkin-switches)
	(vc-file-setprop file 'vc-checkout-time 
			 (nth 5 (file-attributes file))))
      (progn
	(apply 'vc-do-command 0 "cleartool" file 'WORKFILE
	       "checkin" "-identical"
	       (if (string-equal "" comment)
		   "-nc")
	       (if (not (string-equal "" comment))
		   "-c")
	       (if (not (string-equal "" comment))
		   comment)
	       vc-checkin-switches)
	(vc-file-setprop file 'vc-checkout-time 
			 (nth 5 (file-attributes file))))
      ))
  (vc-file-setprop file 'vc-locking-user nil)
  (message "Checking in %s...done" file)
  )

(defun vc-backend-revert (file)
  ;; Revert file to latest checked-in version.
  (message "Reverting %s..." file)
  (vc-backend-dispatch
    file
    (progn				; SCCS
      (vc-do-command 0 "unget" file 'MASTER nil)
      (vc-do-command 0 "get" file 'MASTER nil))
    (vc-do-command 0 "co" file 'MASTER	; RCS.  This deletes the work file.
		   "-f" "-u")
    (progn				; CVS
      (delete-file file)
      (vc-do-command 0 "cvs" file 'WORKFILE "update"))
    (vc-do-command 0 "cleartool" file 'WORKFILE ; CC
		   "unco" "-rm")
    )
  (vc-file-setprop file 'vc-locking-user nil)
  (message "Reverting %s...done" file)
  )

(defun vc-backend-steal (file &optional rev)
  ;; Steal the lock on the current workfile.  Needs RCS 5.6.2 or later for -M.
  (message "Stealing lock on %s..." file)
  (vc-backend-dispatch file
    (progn				; SCCS
      (vc-do-command 0 "unget" file 'MASTER "-n" (if rev (concat "-r" rev)))
      (vc-do-command 0 "get" file 'MASTER "-g" (if rev (concat "-r" rev)))
      )
    (vc-do-command 0 "rcs" file 'MASTER ; RCS
		   "-M" (concat "-u" rev) (concat "-l" rev))
    (error "You cannot steal a CVS lock; there are no CVS locks to steal.") ; CVS
    (error "VC's ClearCase support cannot steal locks.") ; CC
    )
  (vc-file-setprop file 'vc-locking-user (user-login-name))
  (message "Stealing lock on %s...done" file)
  )  

(defun vc-backend-uncheck (file target)
  ;; Undo the latest checkin.  Note: this code will have to get a lot
  ;; smarter when we support multiple branches.
  (message "Removing last change from %s..." file)
  (vc-backend-dispatch file
    (vc-do-command 0 "rmdel" file 'MASTER (concat "-r" target))
    (vc-do-command 0 "rcs" file 'MASTER (concat "-o" target))
    (error "Unchecking files under CVS is dangerous and not supported in VC.")
    (error "VC's ClearCase support cannot cancel checkins.")
    )
  (message "Removing last change from %s...done" file)
  )

(defun vc-backend-print-log (file)
  ;; Print change log associated with FILE to buffer *vc*.
  (vc-backend-dispatch 
    file
    (vc-do-command 0 "prs" file 'MASTER)
    (vc-do-command 0 "rlog" file 'MASTER)
    (vc-do-command 0 "cvs" file 'WORKFILE "rlog")
    (vc-do-command 0 "cleartool" file 'WORKFILE "lshistory")))

(defun vc-backend-assign-name (file name)
  ;; Assign to a FILE's latest version a given NAME.
  (vc-backend-dispatch file
    (vc-add-triple name file (vc-latest-version file)) ; SCCS
    (vc-do-command 0 "rcs" file 'MASTER (concat "-n" name ":")) ; RCS
    (vc-do-command 0 "cvs" file 'WORKFILE "tag" name) ; CVS
    (vc-do-command 0 "cleartool" file 'WORKFILE ; CC
		   "mklabel" "-replace" "-nc" name)
    )
  )

(defun vc-backend-diff (file &optional oldvers newvers cmp)
  ;; Get a difference report between two versions of FILE.
  ;; Get only a brief comparison report if CMP, a difference report otherwise.
  (let ((backend (vc-backend-deduce file)))
    (cond
     ((eq backend 'SCCS)
      (setq oldvers (vc-lookup-triple file oldvers))
      (setq newvers (vc-lookup-triple file newvers))))
    (cond
     ;; SCCS and RCS shares a lot of code.
     ((or (eq backend 'SCCS) (eq backend 'RCS))
      (let* ((command (if (eq backend 'SCCS)
			  "vcdiff"
			"rcsdiff"))
	     (mode (if (eq backend 'RCS) 'WORKFILE 'MASTER))
	     (options (append (list (and cmp "--brief")
				    "-q"
                                    (and oldvers (concat "-r" oldvers))
				    (and newvers (concat "-r" newvers)))
                              (and (not cmp)
				   (if (listp diff-switches)
				       diff-switches
				     (list diff-switches)))))
	     (status (apply 'vc-do-command 2 command file mode options)))
	;; Some RCS versions don't understand "--brief"; work around this.
	(if (eq status 2)
	    (apply 'vc-do-command 1 command file 'WORKFILE
		   (if cmp (cdr options) options))
	  status)))
     ;; CVS is different.  
     ;; cmp is not yet implemented -- we always do a full diff.
     ((eq backend 'CVS)
      (if (string= (vc-file-getprop file 'vc-your-latest-version) "0") ; CVS
	  ;; This file is added but not yet committed; there is no master file.
	  ;; diff it against /dev/null.
	  (if (or oldvers newvers)
	      (error "No revisions of %s exists" file)
	    (apply 'vc-do-command
		   1 "diff" file 'WORKFILE "/dev/null"
		   (if (listp diff-switches)
		       diff-switches
		     (list diff-switches))))
	(apply 'vc-do-command
	       1 "cvs" file 'WORKFILE "diff"
	       (and oldvers (concat "-r" oldvers))
	       (and newvers (concat "-r" newvers))
	       (if (listp diff-switches)
                   diff-switches
                 (list diff-switches)))))
     ;; ClearCase is completely different.
     ((eq backend 'CC)
      (apply 'vc-do-command 2 "cleardiff" file nil
	     (if cmp "-status_only")
	     (concat file "@@"
		     (or oldvers
			 (vc-file-getprop file 'vc-cc-predecessor)))
	     (if newvers
		 (concat file "@@" newvers)
	       file)
	     nil))
     (t
      (vc-registration-error file)))))

(defun vc-backend-merge-news (file)
  ;; Merge in any new changes made to FILE.
  (vc-backend-dispatch 
    file
    (error "vc-backend-merge-news not meaningful for SCCS files") ; SCCS
    (error "vc-backend-merge-news not meaningful for RCS files") ; RCS
    (vc-do-command 1 "cvs" file 'WORKFILE "update") ; CVS
    (error "vc-backend-merge-news not meaningful for ClearCase files") ; CC
    ))

(defun vc-check-headers ()
  "Check if the current file has any headers in it."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (vc-backend-dispatch buffer-file-name
      (re-search-forward  "%[MIRLBSDHTEGUYFPQCZWA]%" nil t) ; SCCS
      (re-search-forward "\\$[A-Za-z\300-\326\330-\366\370-\377]+\\(: [\t -#%-\176\240-\377]*\\)?\\$" nil t) ; RCS
      'RCS ; CVS works like RCS in this regard.
      nil ; ClearCase does not recognise headers.
      )
    ))

;; Back-end-dependent stuff ends here.

;; Set up key bindings for use while editing log messages

(defun vc-log-mode ()
  "Minor mode for driving version-control tools.
These bindings are added to the global keymap when you enter this mode:
\\[vc-next-action]          perform next logical version-control operation on current file
\\[vc-register]                   register current file
\\[vc-toggle-read-only]            like next-action, but won't register files
\\[vc-insert-headers]         insert version-control headers in current file
\\[vc-print-log]          display change history of current file
\\[vc-revert-buffer]              revert buffer to latest version
\\[vc-cancel-version]            undo latest checkin
\\[vc-diff]          show diffs between file versions
\\[vc-version-other-window]             visit old version in another window
\\[vc-directory]             show all files locked by any user in or below .
\\[vc-update-change-log]         add change log entry from recent checkins

While you are entering a change log message for a version, the following
additional bindings will be in effect.

\\[vc-finish-logentry]   proceed with check in, ending log message entry

Whenever you do a checkin, your log comment is added to a ring of
saved comments.  These can be recalled as follows:

\\[vc-next-comment]   replace region with next message in comment ring
\\[vc-previous-comment] replace region with previous message in comment ring
\\[vc-comment-search-reverse]       search backward for regexp in the comment ring
\\[vc-comment-search-forward]     search backward for regexp in the comment ring

Entry to the change-log submode calls the value of text-mode-hook, then
the value of vc-log-mode-hook.

Global user options:
 vc-initial-comment      If non-nil, require user to enter a change
			 comment upon first checkin of the file.

 vc-keep-workfiles       Non-nil value prevents workfiles from being
			 deleted when changes are checked in

 vc-suppress-confirm     Suppresses some confirmation prompts,
			 notably for reversions.

 vc-header-alist         Which keywords to insert when adding headers
			 with \\[vc-insert-headers].  Defaults to
			 '(\"\%\W\%\") under SCCS, '(\"\$Id\$\") under 
                         RCS and CVS.

 vc-static-header-alist  By default, version headers inserted in C files
                         get stuffed in a static string area so that
			 ident(RCS/CVS) or what(SCCS) can see them in
			 the compiled object code.  You can override
			 this by setting this variable to nil, or change
                         the header template by changing it.

 vc-command-messages     if non-nil, display run messages from the
			 actual version-control utilities (this is
			 intended primarily for people hacking vc
			 itself).
"
  (interactive)
  (set-syntax-table text-mode-syntax-table)
  (use-local-map vc-log-entry-mode)
  (setq local-abbrev-table text-mode-abbrev-table)
  (setq major-mode 'vc-log-mode)
  (setq mode-name "VC-Log")
  (make-local-variable 'vc-log-file)
  (make-local-variable 'vc-log-version)
  (make-local-variable 'vc-comment-ring-index)
  (set-buffer-modified-p nil)
  (setq buffer-file-name nil)
  (run-hooks 'text-mode-hook 'vc-log-mode-hook)
  )

;; Initialization code, to be done just once at load-time
(if vc-log-entry-mode
    nil
  (setq vc-log-entry-mode (make-sparse-keymap))
  (set-keymap-name vc-log-entry-mode 'vc-log-entry-mode) ; XEmacs
  (define-key vc-log-entry-mode "\M-n" 'vc-next-comment)
  (define-key vc-log-entry-mode "\M-p" 'vc-previous-comment)
  (define-key vc-log-entry-mode "\M-r" 'vc-comment-search-reverse)
  (define-key vc-log-entry-mode "\M-s" 'vc-comment-search-forward)
  (define-key vc-log-entry-mode "\C-c\C-c" 'vc-finish-logentry)
  )

;;; These things should probably be generally available

(defun vc-file-tree-walk (func &rest args)
  "Walk recursively through default directory.
Invoke FUNC f ARGS on each non-directory file f underneath it."
  (vc-file-tree-walk-internal default-directory func args)
  (message "Traversing directory %s...done" default-directory))

(defun vc-file-tree-walk-internal (file func args)
  (if (not (file-directory-p file))
      (apply func file args)
    (message "Traversing directory %s..." file)
    (let ((dir (file-name-as-directory file)))
      (mapcar
       (function
	(lambda (f) (or
		     (string-equal f ".")
		     (string-equal f "..")
		     (member f vc-directory-exclusion-list)
		     (let ((dirf (concat dir f)))
                       (or
			(file-symlink-p dirf) ; Avoid possible loops
			(vc-file-tree-walk-internal dirf func args))))))
       (directory-files dir)))))

(defun vc-dir-all-files (func &rest args)
  "Invoke FUNC f ARGS on each regular file f in default directory."
  (let ((dir default-directory))
    (message "Scanning directory %s..." dir)
    (mapcar (function (lambda (f)
			(let ((dirf (expand-file-name f dir)))
			  (if (not (file-directory-p dirf))
			      (apply func dirf args)))))
            (directory-files dir))
    (message "Scanning directory %s...done" dir)))

(provide 'vc)

;;; DEVELOPER'S NOTES ON CONCURRENCY PROBLEMS IN THIS CODE
;;;
;;; These may be useful to anyone who has to debug or extend the package.
;;; 
;;; A fundamental problem in VC is that there are time windows between
;;; vc-next-action's computations of the file's version-control state and
;;; the actions that change it.  This is a window open to lossage in a
;;; multi-user environment; someone else could nip in and change the state
;;; of the master during it.
;;; 
;;; The performance problem is that rlog/prs calls are very expensive; we want
;;; to avoid them as much as possible.
;;; 
;;; ANALYSIS:
;;; 
;;; The performance problem, it turns out, simplifies in practice to the
;;; problem of making vc-locking-user fast.  The two other functions that call
;;; prs/rlog will not be so commonly used that the slowdown is a problem; one
;;; makes snapshots, the other deletes the calling user's last change in the
;;; master.
;;; 
;;; The race condition implies that we have to either (a) lock the master
;;; during the entire execution of vc-next-action, or (b) detect and
;;; recover from errors resulting from dispatch on an out-of-date state.
;;; 
;;; Alternative (a) appears to be unfeasible.  The problem is that we can't
;;; guarantee that the lock will ever be removed.  Suppose a user starts a
;;; checkin, the change message buffer pops up, and the user, having wandered
;;; off to do something else, simply forgets about it?
;;; 
;;; Alternative (b), on the other hand, works well with a cheap way to speed up
;;; vc-locking-user.  Usually, if a file is registered, we can read its locked/
;;; unlocked state and its current owner from its permissions.
;;; 
;;; This shortcut will fail if someone has manually changed the workfile's
;;; permissions; also if developers are munging the workfile in several
;;; directories, with symlinks to a master (in this latter case, the
;;; permissions shortcut will fail to detect a lock asserted from another
;;; directory).
;;; 
;;; Note that these cases correspond exactly to the errors which could happen
;;; because of a competing checkin/checkout race in between two instances of
;;; vc-next-action.
;;; 
;;; For VC's purposes, a workfile/master pair may have the following states:
;;; 
;;; A. Unregistered.  There is a workfile, there is no master.
;;; 
;;; B. Registered and not locked by anyone.
;;; 
;;; C. Locked by calling user and unchanged.
;;; 
;;; D. Locked by the calling user and changed.
;;; 
;;; E. Locked by someone other than the calling user.
;;; 
;;; This makes for 25 states and 20 error conditions.  Here's the matrix:
;;; 
;;; VC's idea of state
;;;  |
;;;  V  Actual state   RCS action              SCCS action          Effect
;;;    A  B  C  D  E
;;;  A .  1  2  3  4   ci -u -t-          admin -fb -i<file>      initial admin
;;;  B 5  .  6  7  8   co -l              get -e                  checkout
;;;  C 9  10 .  11 12  co -u              unget; get              revert
;;;  D 13 14 15 .  16  ci -u -m<comment>  delta -y<comment>; get  checkin
;;;  E 17 18 19 20 .   rcs -u -M ; rcs -l unget -n ; get -g       steal lock
;;; 
;;; All commands take the master file name as a last argument (not shown).
;;; 
;;; In the discussion below, a "self-race" is a pathological situation in
;;; which VC operations are being attempted simultaneously by two or more
;;; Emacsen running under the same username.
;;; 
;;; The vc-next-action code has the following windows:
;;; 
;;; Window P:
;;;    Between the check for existence of a master file and the call to
;;; admin/checkin in vc-buffer-admin (apparent state A).  This window may
;;; never close if the initial-comment feature is on.
;;; 
;;; Window Q:
;;;    Between the call to vc-workfile-unchanged-p in and the immediately
;;; following revert (apparent state C).
;;; 
;;; Window R:
;;;    Between the call to vc-workfile-unchanged-p in and the following
;;; checkin (apparent state D).  This window may never close.
;;; 
;;; Window S:
;;;    Between the unlock and the immediately following checkout during a
;;; revert operation (apparent state C).  Included in window Q.
;;; 
;;; Window T:
;;;    Between vc-locking-user and the following checkout (apparent state B).
;;; 
;;; Window U:
;;;    Between vc-locking-user and the following revert (apparent state C).
;;; Includes windows Q and S.
;;; 
;;; Window V:
;;;    Between vc-locking-user and the following checkin (apparent state
;;; D).  This window may never be closed if the user fails to complete the
;;; checkin message.  Includes window R.
;;; 
;;; Window W:
;;;    Between vc-locking-user and the following steal-lock (apparent
;;; state E).  This window may never close if the user fails to complete
;;; the steal-lock message.  Includes window X.
;;; 
;;; Window X:
;;;    Between the unlock and the immediately following re-lock during a
;;; steal-lock operation (apparent state E).  This window may never cloce
;;; if the user fails to complete the steal-lock message.
;;; 
;;; Errors:
;;; 
;;; Apparent state A ---
;;;
;;; 1. File looked unregistered but is actually registered and not locked.
;;; 
;;;    Potential cause: someone else's admin during window P, with
;;; caller's admin happening before their checkout.
;;; 
;;;    RCS: ci will fail with a "no lock set by <user>" message.
;;;    SCCS: admin will fail with error (ad19).
;;; 
;;;    We can let these errors be passed up to the user.
;;; 
;;; 2. File looked unregistered but is actually locked by caller, unchanged.
;;; 
;;;    Potential cause: self-race during window P.
;;; 
;;;    RCS: will revert the file to the last saved version and unlock it.
;;;    SCCS: will fail with error (ad19).
;;; 
;;;    Either of these consequences is acceptable.
;;; 
;;; 3. File looked unregistered but is actually locked by caller, changed.
;;; 
;;;    Potential cause: self-race during window P.
;;; 
;;;    RCS: will register the caller's workfile as a delta with a
;;; null change comment (the -t- switch will be ignored).
;;;    SCCS: will fail with error (ad19).
;;; 
;;; 4. File looked unregistered but is locked by someone else.
;;; 
;;;    Potential cause: someone else's admin during window P, with
;;; caller's admin happening *after* their checkout.
;;; 
;;;    RCS: will fail with a "no lock set by <user>" message.
;;;    SCCS: will fail with error (ad19).
;;; 
;;;    We can let these errors be passed up to the user.
;;; 
;;; Apparent state B ---
;;;
;;; 5. File looked registered and not locked, but is actually unregistered.
;;; 
;;;    Potential cause: master file got nuked during window P.
;;; 
;;;    RCS: will fail with "RCS/<file>: No such file or directory"
;;;    SCCS: will fail with error ut4.
;;; 
;;;    We can let these errors be passed up to the user.
;;; 
;;; 6. File looked registered and not locked, but is actually locked by the
;;; calling user and unchanged.
;;; 
;;;    Potential cause: self-race during window T.
;;; 
;;;    RCS: in the same directory as the previous workfile, co -l will fail
;;; with "co error: writable foo exists; checkout aborted".  In any other
;;; directory, checkout will succeed.
;;;    SCCS: will fail with ge17.
;;; 
;;;    Either of these consequences is acceptable.
;;; 
;;; 7. File looked registered and not locked, but is actually locked by the
;;; calling user and changed.
;;; 
;;;    As case 6.
;;; 
;;; 8. File looked registered and not locked, but is actually locked by another
;;; user.
;;; 
;;;    Potential cause: someone else checks it out during window T.
;;; 
;;;    RCS: co error: revision 1.3 already locked by <user>
;;;    SCCS: fails with ge4 (in directory) or ut7 (outside it).
;;; 
;;;    We can let these errors be passed up to the user.
;;; 
;;; Apparent state C ---
;;;
;;; 9. File looks locked by calling user and unchanged, but is unregistered.
;;; 
;;;    As case 5.
;;; 
;;; 10. File looks locked by calling user and unchanged, but is actually not
;;; locked.
;;; 
;;;    Potential cause: a self-race in window U, or by the revert's
;;; landing during window X of some other user's steal-lock or window S
;;; of another user's revert.
;;; 
;;;    RCS: succeeds, refreshing the file from the identical version in
;;; the master.
;;;    SCCS: fails with error ut4 (p file nonexistent).
;;;
;;;    Either of these consequences is acceptable.
;;; 
;;; 11. File is locked by calling user.  It looks unchanged, but is actually
;;; changed.
;;; 
;;;    Potential cause: the file would have to be touched by a self-race
;;; during window Q.
;;; 
;;;    The revert will succeed, removing whatever changes came with
;;; the touch.  It is theoretically possible that work could be lost.
;;; 
;;; 12. File looks like it's locked by the calling user and unchanged, but
;;; it's actually locked by someone else.
;;; 
;;;    Potential cause: a steal-lock in window V.
;;; 
;;;    RCS: co error: revision <rev> locked by <user>; use co -r or rcs -u
;;;    SCCS: fails with error un2
;;; 
;;;    We can pass these errors up to the user.
;;; 
;;; Apparent state D ---
;;;
;;; 13. File looks like it's locked by the calling user and changed, but it's
;;; actually unregistered.
;;; 
;;;    Potential cause: master file got nuked during window P.
;;; 
;;;    RCS: Checks in the user's version as an initial delta.
;;;    SCCS: will fail with error ut4.
;;;
;;;    This case is kind of nasty.  It means VC may fail to detect the
;;; loss of previous version information.
;;; 
;;; 14. File looks like it's locked by the calling user and changed, but it's
;;; actually unlocked.
;;; 
;;;    Potential cause: self-race in window V, or the checkin happening
;;; during the window X of someone else's steal-lock or window S of
;;; someone else's revert.
;;; 
;;;    RCS: ci will fail with "no lock set by <user>".
;;;    SCCS: delta will fail with error ut4.
;;; 
;;; 15. File looks like it's locked by the calling user and changed, but it's
;;; actually locked by the calling user and unchanged.
;;; 
;;;    Potential cause: another self-race --- a whole checkin/checkout
;;; sequence by the calling user would have to land in window R.
;;; 
;;;    SCCS: checks in a redundant delta and leaves the file unlocked as usual.
;;;    RCS: reverts to the file state as of the second user's checkin, leaving
;;; the file unlocked.
;;;
;;;    It is theoretically possible that work could be lost under RCS.
;;; 
;;; 16. File looks like it's locked by the calling user and changed, but it's
;;; actually locked by a different user.
;;; 
;;;    RCS: ci error: no lock set by <user>
;;;    SCCS: unget will fail with error un2
;;; 
;;;    We can pass these errors up to the user.
;;; 
;;; Apparent state E ---
;;;
;;; 17. File looks like it's locked by some other user, but it's actually
;;; unregistered.
;;; 
;;;    As case 13.
;;; 
;;; 18. File looks like it's locked by some other user, but it's actually
;;; unlocked.
;;; 
;;;    Potential cause: someone released a lock during window W.
;;; 
;;;    RCS: The calling user will get the lock on the file.
;;;    SCCS: unget -n will fail with cm4.
;;; 
;;;    Either of these consequences will be OK.
;;; 
;;; 19. File looks like it's locked by some other user, but it's actually
;;; locked by the calling user and unchanged.
;;; 
;;;    Potential cause: the other user relinquishing a lock followed by
;;; a self-race, both in window W.
;;; 
;;;     Under both RCS and SCCS, both unlock and lock will succeed, making
;;; the sequence a no-op.
;;; 
;;; 20. File looks like it's locked by some other user, but it's actually
;;; locked by the calling user and changed.
;;; 
;;;     As case 19.
;;; 
;;; PROBLEM CASES:
;;; 
;;;    In order of decreasing severity:
;;; 
;;;    Cases 11 and 15 under RCS are the only one that potentially lose work.
;;; They would require a self-race for this to happen.
;;; 
;;;    Case 13 in RCS loses information about previous deltas, retaining
;;; only the information in the current workfile.  This can only happen
;;; if the master file gets nuked in window P.
;;; 
;;;    Case 3 in RCS and case 15 under SCCS insert a redundant delta with
;;; no change comment in the master.  This would require a self-race in
;;; window P or R respectively.
;;; 
;;;    Cases 2, 10, 19 and 20 do extra work, but make no changes.
;;; 
;;;    Unfortunately, it appears to me that no recovery is possible in these
;;; cases.  They don't yield error messages, so there's no way to tell that
;;; a race condition has occurred.
;;; 
;;;    All other cases don't change either the workfile or the master, and
;;; trigger command errors which the user will see.
;;; 
;;;    Thus, there is no explicit recovery code.

;;; vc.el ends here
