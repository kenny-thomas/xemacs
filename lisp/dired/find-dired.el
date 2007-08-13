;;; find-dired.el --- run a `find' command and dired the output

;;; Copyright (C) 1992, 1994, 1995 Free Software Foundation, Inc.

;; Author: Roland McGrath <roland@gnu.ai.mit.edu>,
;;	   Sebastian Kremer <sk@thp.uni-koeln.de>
;; Keywords: unix

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
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Synched up with: FSF 19.30.

;;; Commentary:

;; To bind the following functionality to a key, put, e.g.:
;;
;;   (global-set-key "\C-cf" 'find-dired)
;;   (global-set-key "\C-cn" 'find-name-dired)
;;   (global-set-key "\C-cl" 'find-grep-dired)
;;
;; in your ~/.emacs.

;;; Code:

(require 'dired)

;; find's -ls corresponds to these switches.
;; Note -b, at least GNU find quotes spaces etc. in filenames
;;;###autoload
(defvar find-ls-option (purecopy
			;; XEmacs: add purecopy
			(if (eq system-type 'berkeley-unix) '("-ls" . "-gilsb")
			  '("-exec ls -ld {} \\;" . "-ld")))
  "*Description of the option to `find' to produce an `ls -l'-type listing.
This is a cons of two strings (FIND-OPTION . LS-SWITCHES).  FIND-OPTION
gives the option (or options) to `find' that produce the desired output.
LS-SWITCHES is a list of `ls' switches to tell dired how to parse the output.")

;;;###autoload
(defvar find-grep-options (purecopy
			   ;; XEmacs: add purecopy
			   (if (eq system-type 'berkeley-unix) "-s" "-q"))
  "*Option to grep to be as silent as possible.
On Berkeley systems, this is `-s'; on Posix, and with GNU grep, `-q' does it.
On other systems, the closest you can come is to use `-l'.")

;; XEmacs additions: next two variables.

;;;###autoload
(defvar find-dired-multiple-buffers nil
  "*If non-nil, generates a new buffer for each find")

(defvar find-dired-dir-history nil
  "History of directories used by find-dired")

(defvar find-args nil
  "Last arguments given to `find' by \\[find-dired].")

(defvar find-args-history nil
  "Last arguments given to `find' by \\[find-dired].")

;; XEmacs: various changes in next function.

;;;###autoload
(defun find-dired (dir args)
  "Run `find' and go into dired-mode on a buffer of the output.
The command run (after changing into DIR) is

    find . \\( ARGS \\) -ls"
  (interactive (list (read-file-name "Run find in directory: "
				     nil "" t nil 'find-dired-dir-history)
		     (if (featurep 'gmhist)
			 (read-with-history-in 'find-args-history
					       "Run find (with args): ")
		       (read-string "Run find (with args): "
				    (or (and (fboundp 'symbol-near-point)
					     (symbol-near-point))
					(car find-args-history))
				    'find-args-history))))
  ;; Expand DIR ("" means default-directory), and make sure it has a
  ;; trailing slash.
  (setq dir (file-name-as-directory (expand-file-name dir)))
  ;; Check that it's really a directory.
  (or (file-directory-p dir)
      (error "find-dired needs a directory: %s" dir))
  (switch-to-buffer-other-window (if find-dired-multiple-buffers
                        (generate-new-buffer (concat "*Find-in-"
                                                     (file-name-nondirectory (directory-file-name dir))
                                                     "/..*"))
                      (get-buffer-create "*Find*")))
  (widen)
  (kill-all-local-variables)
  (setq buffer-read-only nil)
  (erase-buffer)
  (setq default-directory dir
	find-args args			; save for next interactive call
	args (concat "find . "
		     (if (string= args "")
			 ""
		       (concat "\\( " args " \\) "))
		     (car find-ls-option)))
  ;; The next statement will bomb in classic dired (no optional arg allowed)
  (dired-mode dir (cdr find-ls-option))
  ;; This really should rerun the find command, but I don't
  ;; have time for that.
  (let ((keymap (make-sparse-keymap)))
    (set-keymap-parents keymap (list (current-local-map)))
    (define-key keymap "g" 'undefined)
    (use-local-map keymap))
  ;; Set subdir-alist so that Tree Dired will work:
  (if (fboundp 'dired-simple-subdir-alist)
      ;; will work even with nested dired format (dired-nstd.el,v 1.15
      ;; and later)
      (dired-simple-subdir-alist)
    ;; else we have an ancient tree dired (or classic dired, where
    ;; this does no harm) 
    (set (make-local-variable 'dired-subdir-alist)
	 (list (cons default-directory (point-min-marker)))))
  (setq buffer-read-only nil)
  ;; Subdir headlerline must come first because the first marker in
  ;; subdir-alist points there.
  (insert "  " dir ":\n")
  ;; Make second line a ``find'' line in analogy to the ``total'' or
  ;; ``wildcard'' line. 
  (insert "  " args "\n")
  ;; Start the find process
  (message "Searching .... (but you can continue other work)")
  (sit-for 0)
  (let ((proc (start-process-shell-command "find" (current-buffer) args)))
    (set-process-filter proc (function find-dired-filter))
    (set-process-sentinel proc (function find-dired-sentinel))
    ;; Initialize the process marker; it is used by the filter.
    (move-marker (process-mark proc) 1 (current-buffer)))
  (setq modeline-process '(": %s")))

;;;###autoload
(defun find-name-dired (dir pattern)
  "Search DIR recursively for files matching the globbing pattern PATTERN,
and run dired on those files.
PATTERN is a shell wildcard (not an Emacs regexp) and need not be quoted.
The command run (after changing into DIR) is

    find . -name 'PATTERN' -ls"
  (interactive
   "DFind-name (directory): \nsFind-name (filename wildcard): ")
  (find-dired dir (concat "-name '" pattern "'")))

;; This functionality suggested by
;; From: oblanc@watcgl.waterloo.edu (Olivier Blanc)
;; Subject: find-dired, lookfor-dired
;; Date: 10 May 91 17:50:00 GMT
;; Organization: University of Waterloo

(defalias 'lookfor-dired 'find-grep-dired)

;; XEmacs addition
(defvar find-grep-dired-history nil
  "history for find-grep-dired input")

;;;###autoload
(defun find-grep-dired (dir args)
  "Find files in DIR containing a regexp ARG and start Dired on output.
The command run (after changing into DIR) is

    find . -type f -exec test -r {} \\\; -exec egrep -s ARG {} \\\; -ls

Thus ARG can also contain additional grep options."
  (interactive
   ;; XEmacs improvements here.
   (list (read-string "Find-grep (directory): "
		      default-directory 'find-dired-dir-history)
	 (read-string "Find-grep (grep args): " (and (fboundp 'symbol-near-point)
						     (symbol-near-point))
		      'find-grep-dired-history)))
  ;; find -exec doesn't allow shell i/o redirections in the command,
  ;; or we could use `grep -l >/dev/null'
  (find-dired dir
	      ;; XEmacs improvements here.
              (concat "-type f -exec test -r {} \\\; -exec egrep "
		      find-grep-options " " args " {} \\\; ")))

(defun find-dired-filter (proc string)
  ;; Filter for \\[find-dired] processes.
  (let ((buf (process-buffer proc)))
    (if (buffer-name buf)		; not killed?
	(save-excursion
	  (set-buffer buf)
	  (save-restriction
	    (widen)
	    (save-excursion
	      (let ((buffer-read-only nil)
		    (end (point-max)))
		(goto-char end)
		(insert string)
		(goto-char end)
		(or (looking-at "^")
		    (forward-line 1))
		(while (looking-at "^")
		  (insert "  ")
		  (forward-line 1))
		;; Convert ` ./FILE' to ` FILE'
		;; This would lose if the current chunk of output
		;; starts or ends within the ` ./', so back up a bit:
		(goto-char (- end 3))	; no error if < 0
		(while (search-forward " ./" nil t)
		  (delete-region (point) (- (point) 2)))
		;; Find all the complete lines in the unprocessed
		;; output and process it to add text properties.
		(goto-char end)
		(if (search-backward "\n" (process-mark proc) t)
		    (progn
		      (dired-insert-set-properties (process-mark proc)
						   (1+ (point)))
		      (move-marker (process-mark proc) (1+ (point)))))
		))))
      ;; The buffer has been killed.
      (delete-process proc))))

(defun find-dired-sentinel (proc state)
  ;; Sentinel for \\[find-dired] processes.
  (let ((buf (process-buffer proc)))
    (if (buffer-name buf)
	(save-excursion
	  (set-buffer buf)
	  (let ((buffer-read-only nil))
	    (save-excursion
	      (goto-char (point-max))
	      (insert "\nfind " state)
	      (forward-char -1)		;Back up before \n at end of STATE.
	      (insert " at " (substring (current-time-string) 0 19))
	      (forward-char 1)
	      (setq modeline-process ;; XEmacs: newer spelling
		    (concat ":"
			    (symbol-name (process-status proc))))
	      ;; Since the buffer and mode line will show that the
	      ;; process is dead, we can delete it now.  Otherwise it
	      ;; will stay around until M-x list-processes.
	      (delete-process proc)
	      (redraw-modeline))) ;; XEmacs function
	  (message "find-dired %s finished." (current-buffer))))))

(provide 'find-dired)

;;; find-dired.el ends here
