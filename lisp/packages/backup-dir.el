;;; BACKUP-DIR.EL:   Emacs functions to allow backup files to live in
;;;                  some other directory(s).             Version 2.1
;;;
;;; Copyright (C) 1992-97 Greg Klanderman
;;;
;;; This program is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 1, or (at your option)
;;; any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; A copy of the GNU General Public License can be obtained from
;;; the Free Software Foundation, Inc., 675 Mass Ave, Cambridge, MA
;;; 02139, USA.
;;;
;;; Send bug reports, etc. to greg@alphatech.com or gregk@ai.mit.edu.
;;;
;;;
;;; Modification History
;;; ====================
;;;
;;; 10/27/1997  Version 2.1
;;; Updated to support GNU Emacs 20.2.  The function `backup-extract-version'
;;; now uses the free variable `backup-extract-version-start' rather than
;;; `bv-length'.  Note, we continue to support older GNU Emacs and XEmacsen.
;;;
;;; 10/22/1997
;;; Customization by Karl M. Hegbloom <karlheg@inetarena.com>
;;;
;;; 12/28/1996  Version 2.0
;;; Updated for XEmacs 19.15b4, much of code reorganized & cleaned up
;;;
;;; 12/27/1996  Version 1.6
;;; explicit loading of dired replaced to use dired-load-hook
;;; (suggested by Thomas Feuster, feuster@tp4.physik.uni-giessen.de)
;;;
;;; 12/2/1996 Version 1.5
;;; Took out obsolete byte compiler options
;;;
;;; 9/24/1996 Version 1.4
;;; Fix some bugs, change to alist OPTIONS list (ok-create, full-path..) from
;;; separate fields for each option variable.  Added search-upward option.
;;; Added new function `find-file-latest-backup' to find a file's latest backup.
;;;
;;; 1/26/1996 Version 1.3
;;; Name change to backup-dir.el
;;;
;;; 3/22/1995 Version 1.2
;;; Added new definitions for functions `file-newest-backup', `latest-backup-file',
;;; and `diff-latest-backup-file' so various other emacs functions will find the
;;; right backup files.
;;;
;;; 4/23/1993 Version 1.1
;;; Reworked to allow different behavior for different files based on the
;;; alist `bkup-backup-directory-info'.
;;;
;;; Fall 1992 Version 1.0
;;; Name change and added ability to make directories absolute.  Added the
;;; full path stuff to make backup name unique for absolute directories.
;;;
;;; Spring 1992 Version 0.0
;;; Original
;;;
;;;
;;; Description:
;;; ============
;;;
;;; Allows backup files to be optionally stored in some directories, based on
;;; the value of the alist, `bkup-backup-directory-info'.  This variable is a
;;; list of lists of the form (FILE-REGEXP BACKUP-DIR OPTIONS ...).  If the
;;; filename to be backed up matches FILE-REGEXP, or FILE-REGEXP is t, then
;;; BACKUP-DIR is used as the path for its backups.  Directories may begin with
;;; "/" to specify an absolute pathname.  If BACKUP-DIR does not exist and
;;; OPTIONS contains the symbol `ok-create', then it is created if possible.
;;; Otherwise the usual behavior (backup in the same directory as the file)
;;; results.  If OPTIONS contains the symbol `full-path', then the full path of
;;; the file being backed up is prepended to the backup file name, with each "/"
;;; replaced by a "!".  This is intended for cases where an absolute backup path
;;; is used.  If OPTIONS contains the symbol `search-upward' and the backup
;;; directory BACKUP-DIR is a relative path, then a directory with that name is
;;; searched for starting at the current directory and proceeding upward (..,
;;; ../.., etc) until one is found of that name or the root is reached, and if
;;; one is found it is used as the backup directory.  Finally, if no FILE-REGEXP
;;; matches the file name being backed up, then the usual behavior results.
;;;
;;; These lines from my .emacs load this file and set the values I like:
;;;
;;; (require 'backup-dir)
;;; (setq bkup-backup-directory-info
;;;       '(("/home/greg/.*" "/~/.backups/" ok-create full-path)
;;;         ("^/[^/:]+:"     ".backups/")   ; handle EFS files specially:  we don't 
;;;         ("^/[^/:]+:"     "./")          ; want to search-upward... its very slow
;;;         (t               ".backups/"    full-path search-upward)))
;;;
;;;
;;; The package also provides a new function, `find-file-latest-backup' to find
;;; the latest backup file for the current buffer's file.
;;;
;;;
;;; This file is based on `files.el' from XEmacs 19.15b4.
;;; It has not been extensively tested on GNU Emacs past 18.58.
;;; It does not work under ms-dos.


(byte-compiler-options
 (optimize t)
 (warnings (- free-vars))              ; Don't warn about free variables
 )


;;; New variables affecting backup file behavior
;;; This is the only user-customizable variable for this package.
;;;
(defcustom bkup-backup-directory-info nil
  "*Alist of (FILE-REGEXP BACKUP-DIR OPTIONS ...))
If the filename to be backed up matches FILE-REGEXP, or FILE-REGEXP is t,
then BACKUP-DIR is used as the path for its backups.

Directories may begin with \"/\" to specify an absolute pathname.

If BACKUP-DIR does not exist and OPTIONS contains the symbol `ok-create',
then it is created if possible.  Otherwise the usual behavior (backup in the
same directory as the file) results.

If OPTIONS contains the symbol `full-path', then the full path of the file
being backed up is prepended to the backup file name, with each \"/\"
replaced by a \"!\".  This is intended for cases where an absolute backup
path is used.

If OPTIONS contains the symbol `search-upward' and the backup directory
BACKUP-DIR is a relative path, then a directory with that name is searched
for starting at the current directory and proceeding upward (.., ../.., etc)
until one is found of that name, or the root is reached, and if one is found
it is used as the backup directory.

Finally, if no FILE-REGEXP matches the file name being backed up, then the
usual behavior results.

Once you save this variable with `M-x customize-variable',
`backup-dir' will  be loaded for you each time you start XEmacs."
  :type '(repeat 
          (list (regexp :tag "File regexp")
                (string :tag "Backup Dir")
                (set :inline t
                     (const ok-create)
                     (const full-path)
                     (const search-upward))))
  :require 'backup-dir
  :group 'backup)

 
;;; New functions
;;;
(defun bkup-search-upward-for-backup-dir (base bd-name)
  "Search upward for a directory named BD-NAME, starting in the
directory BASE and continuing with its parent directories until
one is found or the root is reached."
  (let ((prev nil) (curr base) (gotit nil) (tryit nil))
    (while (and (not gotit)
                (not (equal prev curr))
                (not (equal curr "//")))
      (setq prev curr)
      (setq curr (expand-file-name (concat curr "../")))
      (setq tryit (expand-file-name bd-name curr))
      (if (and (file-directory-p tryit) (file-exists-p tryit))
          (setq gotit tryit)))
    (if (and gotit
             (eq (aref gotit (1- (length gotit))) ?/))
        (setq gotit (substring gotit 0 (1- (length gotit)))))
    gotit)) 

(defun bkup-replace-slashes-with-exclamations (s)
  "Replaces slashes in the string S with exclamations.
A new string is produced and returned."
  (let ((ns (copy-sequence s))
	(i (1- (length s))))
    (while (>= i 0)
      (if (= (aref ns i) ?/)
	  (aset ns i ?!))
      (setq i (1- i)))
    ns))

(defun bkup-try-making-directory (dir)
  "Try making directory DIR, return non-nil if successful"
  (condition-case ()
      (progn (make-directory dir t)
             t)
    (t
     nil)))
  
(defun bkup-backup-basename (file full-path)
  "Gives the base part of the backup name for FILE, according to FULL-PATH."
  (if full-path
      (bkup-replace-slashes-with-exclamations file)
    (file-name-nondirectory file)))

(defun bkup-backup-directory-and-basename (file)
  "Return the cons of the backup directory name
and backup file name base for FILE."
  (let ((file (expand-file-name file)))
    (let ((dir     (file-name-directory file))
          (alist   bkup-backup-directory-info)
          (bk-dir  nil)
          (bk-base nil))
      (if (listp alist)
          (while (and (not bk-dir) alist)
            (if (or (eq (car (car alist)) t)
                    (eq (string-match (car (car alist)) file) 0))
                (let* ((bd            (car (cdr (car alist))))
                       (bd-rel-p      (and (> (length bd) 0)
                                           (not (eq (aref bd 0) ?/))))
                       (bd-expn       (expand-file-name bd dir))
                       (bd-noslash    (if (eq (aref bd-expn (1- (length bd-expn))) ?/)
                                          (substring bd-expn 0 (1- (length bd-expn)))
                                        bd-expn))
                       (options       (cdr (cdr (car alist))))
                       (ok-create     (and (memq 'ok-create     options) t))
                       (full-path     (and (memq 'full-path     options) t))
                       (search-upward (and (memq 'search-upward options) t)))
                  (if bd-expn
                      (cond ((or (file-directory-p bd-expn)
                                 (and ok-create
                                      (not (file-exists-p bd-expn))
                                      (bkup-try-making-directory bd-noslash)))
                             (setq bk-dir  (concat bd-noslash "/")
                                   bk-base (bkup-backup-basename file full-path)))
                            ((and bd-rel-p search-upward)
                             (let ((bd-up (bkup-search-upward-for-backup-dir dir bd)))
                               (if bd-up
                                   (setq bk-dir (concat bd-up "/")
                                         bk-base (bkup-backup-basename file full-path)))))))))
            (setq alist (cdr alist))))
      (if (and bk-dir bk-base)
          (cons bk-dir bk-base)
        (cons dir (bkup-backup-basename file nil))))))


;;; This next one is based on the following from `files.el'
;;; but accepts a second optional argument

;;(defun make-backup-file-name (file)
;;  "Create the non-numeric backup file name for FILE.
;;This is a separate function so you can redefine it for customization."
;;  (if (and (eq system-type 'ms-dos)
;;	   (not (msdos-long-file-names)))
;;      (let ((fn (file-name-nondirectory file)))
;;	(concat (file-name-directory file)
;;		(if (string-match "\\([^.]*\\)\\(\\..*\\)?" fn)
;;		    (substring fn 0 (match-end 1)))
;;		".bak"))
;;    (concat file "~")))

(defun bkup-make-backup-file-name (file &optional dir-n-base)
  "Create the non-numeric backup file name for FILE.
Optionally accept a list containing the backup directory and
backup basename.  NB: we don't really handle ms-dos."
  (if (and (eq system-type 'ms-dos)
	   (not (and (fboundp 'msdos-long-file-names) (msdos-long-file-names))))
      (let ((fn (file-name-nondirectory file)))
	(concat (file-name-directory file)
		(if (string-match "\\([^.]*\\)\\(\\..*\\)?" fn)
		    (substring fn 0 (match-end 1)))
		".bak"))
    (let ((d-n-b (or dir-n-base
                     (bkup-backup-directory-and-basename file))))
      (concat (car d-n-b) (cdr d-n-b) "~"))))

(defun bkup-existing-backup-files (fn)
  "Return list of existing backup files for file"
  (let* ((efn (expand-file-name fn))
         (dir-n-base (bkup-backup-directory-and-basename efn))
         (non-num-bk-name (bkup-make-backup-file-name efn dir-n-base))
         (non-num-bk (file-exists-p non-num-bk-name))
         (backup-dir (car dir-n-base))
         (base-versions (concat (cdr dir-n-base) ".~"))
         (possibilities (file-name-all-completions base-versions backup-dir))
         (poss (mapcar #'(lambda (name) (concat backup-dir name)) possibilities)))
    (mapcar #'expand-file-name
            (if non-num-bk (cons non-num-bk-name poss) poss))))

(defun find-file-latest-backup (file)
  "Find the latest backup file for FILE"
  (interactive (list (read-file-name (format "Find latest backup of file (default %s): "
                                             (file-name-nondirectory (buffer-file-name)))
                                     nil (buffer-file-name) t)))
  (let ((backup (file-newest-backup file)))
    (if backup
        (find-file backup)
      (message "no backups found for `%s'" file))))


;;; Functions changed from `files.el' and elsewhere -- originals precede new versions
 
;;(defun make-backup-file-name (file)
;;  "Create the non-numeric backup file name for FILE.
;;This is a separate function so you can redefine it for customization."
;;  (if (and (eq system-type 'ms-dos)
;;	   (not (msdos-long-file-names)))
;;      (let ((fn (file-name-nondirectory file)))
;;	(concat (file-name-directory file)
;;		(if (string-match "\\([^.]*\\)\\(\\..*\\)?" fn)
;;		    (substring fn 0 (match-end 1)))
;;		".bak"))
;;    (concat file "~")))

(defun make-backup-file-name (file)
  "Create the non-numeric backup file name for FILE.
This is a separate function so you can redefine it for customization.
*** Changed by \"backup-dir.el\""
  (bkup-make-backup-file-name file))


;;(defun find-backup-file-name (fn)
;;  "Find a file name for a backup file, and suggestions for deletions.
;;Value is a list whose car is the name for the backup file
;; and whose cdr is a list of old versions to consider deleting now.
;;If the value is nil, don't make a backup."
;;  (let ((handler (find-file-name-handler fn 'find-backup-file-name)))
;;    ;; Run a handler for this function so that ange-ftp can refuse to do it.
;;    (if handler
;;	(funcall handler 'find-backup-file-name fn)
;;      (if (eq version-control 'never)
;;	  (list (make-backup-file-name fn))
;;	(let* ((base-versions (concat (file-name-nondirectory fn) ".~"))
;;	       ;; used by backup-extract-version:
;;	       (bv-length (length base-versions))
;;	       possibilities
;;	       (versions nil)
;;	       (high-water-mark 0)
;;	       (deserve-versions-p nil)
;;	       (number-to-delete 0))
;;	  (condition-case ()
;;	      (setq possibilities (file-name-all-completions
;;				   base-versions
;;				   (file-name-directory fn))
;;		    versions (sort (mapcar
;;				    #'backup-extract-version
;;				    possibilities)
;;				   '<)
;;		    high-water-mark (apply #'max 0 versions)
;;		    deserve-versions-p (or version-control
;;					   (> high-water-mark 0))
;;		    number-to-delete (- (length versions)
;;					kept-old-versions kept-new-versions -1))
;;	    (file-error
;;	     (setq possibilities nil)))
;;	  (if (not deserve-versions-p)
;;	      (list (make-backup-file-name fn))
;;	    (cons (concat fn ".~" (int-to-string (1+ high-water-mark)) "~")
;;		  (if (and (> number-to-delete 0)
;;			   ;; Delete nothing if there is overflow
;;			   ;; in the number of versions to keep.
;;			   (>= (+ kept-new-versions kept-old-versions -1) 0))
;;		      (mapcar #'(lambda (n)
;;				  (concat fn ".~" (int-to-string n) "~"))
;;			      (let ((v (nthcdr kept-old-versions versions)))
;;				(rplacd (nthcdr (1- number-to-delete) v) ())
;;				v))))))))))

(defun find-backup-file-name (fn)
  "Find a file name for a backup file, and suggestions for deletions.
Value is a list whose car is the name for the backup file
 and whose cdr is a list of old versions to consider deleting now.
If the value is nil, don't make a backup.
*** Changed by \"backup-dir.el\""
  (let ((handler (find-file-name-handler fn 'find-backup-file-name)))
    ;; Run a handler for this function so that ange-ftp can refuse to do it.
    (if handler
	(funcall handler 'find-backup-file-name fn)
      (if (eq version-control 'never)
	  (list (make-backup-file-name fn))
	(let* ((dir-n-base (bkup-backup-directory-and-basename fn))         ;add
               (non-num-bk-name (bkup-make-backup-file-name fn dir-n-base)) ;add
               (bk-dir  (car dir-n-base))                                   ;add
               (bk-base (cdr dir-n-base))                                   ;add
               (base-versions (concat bk-base ".~"))                        ;mod
	       ;; used by backup-extract-version:
	       (bv-length (length base-versions)) ;; older GNU Emacsen and XEmacs
	       (backup-extract-version-start (length base-versions)) ;; new GNU Emacs (20.2)
	       possibilities
	       (versions nil)
	       (high-water-mark 0)
	       (deserve-versions-p nil)
	       (number-to-delete 0))
	  (condition-case ()
	      (setq possibilities (file-name-all-completions
				   base-versions
				   bk-dir)                                  ;mod
		    versions (sort (mapcar
				    #'backup-extract-version
				    possibilities)
				   '<)
		    high-water-mark (apply #'max 0 versions)
		    deserve-versions-p (or version-control
					   (> high-water-mark 0))
		    number-to-delete (- (length versions)
					kept-old-versions kept-new-versions -1))
	    (file-error
	     (setq possibilities nil)))
	  (if (not deserve-versions-p)
	      (list (bkup-make-backup-file-name fn dir-n-base))             ;mod
	    (cons (concat bk-dir base-versions (int-to-string (1+ high-water-mark)) "~") ;mod
		  (if (and (> number-to-delete 0)
			   ;; Delete nothing if there is overflow
			   ;; in the number of versions to keep.
			   (>= (+ kept-new-versions kept-old-versions -1) 0))
		      (mapcar #'(lambda (n)
				  (concat bk-dir base-versions (int-to-string n) "~")) ;mod
			      (let ((v (nthcdr kept-old-versions versions)))
				(rplacd (nthcdr (1- number-to-delete) v) ())
				v))))))))))


;;(defun file-newest-backup (filename)
;;  "Return most recent backup file for FILENAME or nil if no backups exist."
;;  (let* ((filename (expand-file-name filename))
;;	 (file (file-name-nondirectory filename))
;;	 (dir  (file-name-directory    filename))
;;	 (comp (file-name-all-completions file dir))
;;	 newest tem)
;;    (while comp
;;      (setq tem (car comp)
;;	    comp (cdr comp))
;;      (cond ((and (backup-file-name-p tem)
;;		  (string= (file-name-sans-versions tem) file))
;;	     (setq tem (concat dir tem))
;;	     (if (or (null newest)
;;		     (file-newer-than-file-p tem newest))
;;		 (setq newest tem)))))
;;    newest))

(defun file-newest-backup (filename)
  "Return most recent backup file for FILENAME or nil if no backups exist.
*** Changed by \"backup-dir.el\""
  (let ((comp (bkup-existing-backup-files filename))
        (newest nil)
        (file nil))
    (while comp
      (setq file (car comp)
	    comp (cdr comp))
      (if (and (backup-file-name-p file)
	       (or (null newest) (file-newer-than-file-p file newest)))
	  (setq newest file)))
    newest))


;;; patch `latest-backup-file' from "dired"
;;;
;;; we use `dired-load-hook' to avoid loading dired now.  This speeds things up
;;; considerably according to Thomas Feuster, feuster@tp4.physik.uni-giessen.de
;;;
;;; one really wonders why there are 3 functions to do the same thing...
;;;
(defun bkup-patch-latest-backup-file ()
  (fset 'latest-backup-file (symbol-function 'file-newest-backup))
  (remove-hook 'dired-load-hook 'bkup-patch-latest-backup-file))

(if (featurep 'dired)
    ;; if loaded, patch it now
    (fset 'latest-backup-file (symbol-function 'file-newest-backup))
  ;; otherwise do it later
  (add-hook 'dired-load-hook 'bkup-patch-latest-backup-file))


;;; patch `diff-latest-backup-file' from "diff"
;;;
(require 'diff)
(fset 'diff-latest-backup-file (symbol-function 'file-newest-backup))


;;; finally, add to list of features
;;;
(provide 'backup-dir)

;;; backup-dir.el ends here
