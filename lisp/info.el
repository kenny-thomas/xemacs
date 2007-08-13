;;; info.el --- info package for Emacs.
;; Keywords: help

;; Copyright (C) 1985, 1986, 1993, 1997 Free Software Foundation, Inc.

;; Author: Dave Gillespie <daveg@synaptics.com>
;;	   Richard Stallman <rms@gnu.ai.mit.edu>
;; Maintainer: Dave Gillespie <daveg@synaptics.com>
;; Version: 1.07 of 7/22/93
;; Keywords: docs, help

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

;;; Synched up with: Not synched with FSF.

;; Commentary:

;; This is based on an early Emacs 19 info.el file.
;;
;; Note that Info-directory has been replaced by Info-directory-list,
;; a search path of directories in which to find Info files.
;; Also, Info tries adding ".info" to a file name if the name itself
;; is not found.
;;
;; See the change log below for further details.


;; LCD Archive Entry:
;; info-dg|Dave Gillespie|daveg@synaptics.com
;; |Info reader with many enhancements; replaces standard info.el.
;; |93-07-22|1.07|~/modes/info.el

;; Also available from anonymous FTP on csvax.cs.caltech.edu.


;; Change Log:

;; Modified 3/7/1991 by Dave Gillespie:
;; (Author's address: daveg@synaptics.com or daveg@csvax.cs.caltech.edu)
;;
;; Added keys:  i, t, <, >, [, ], {, }, 6, 7, 8, 9, 0.
;; Look at help for info-mode (type ? in Info) for descriptions.
;;
;; If Info-directory-list is undefined and there is no INFOPATH
;; in the environment, use value of Info-directory for compatibility
;; with Emacs 18.57.
;;
;; All files named "localdir" found in the path are appended to "dir",
;; the Info directory.  For this to work, "dir" should contain only
;; one node (Top), and each "localdir" should contain no ^_ or ^L
;; characters.  Generally they will contain only one or several
;; additional lines for the top-level menu.  Note that "dir" is
;; modified in memory each time it is loaded, but not on disk.
;;
;; If "dir" contains a line of the form:  "* Locals:"
;; then the "localdir"s are inserted there instead of at the end.


;; Modified 4/3/1991 by Dave Gillespie:
;;
;; Added Info-mode-hook (suggested by Sebastian Kremer).
;; Also added epoch-info-startup/select-hooks from Simon Spero's info.el.
;;
;; Added automatic decoding of compressed Info files.
;; See documentation for the variable Info-suffix-list.  Default is to
;; run "uncompress" on ".Z" files and "unyabba" on ".Y" files.
;; (See comp.sources.unix v24i073-076 for yabba/unyabba, a free software
;; alternative to compress/uncompress.)
;; Note: "dir" and "localdir" files should not be compressed.
;;
;; Changed variables like Info-enable-edit to be settable by M-x set-variable.
;;
;; Added Info-auto-advance variable.  If t, SPC and DEL will act like
;; } and {, i.e., they advance to the next/previous node if at the end
;; of the buffer.
;;
;; Changed `u' to restore point to most recent location in that node.
;; Added `=' to do this manually at any time.  (Suggested by David Fox).
;;
;; Changed `m' and `0-9' to try interpreting menu name as a file name
;; if not found as a node name.  This allows (dir) menus of the form,
;;     Emacs::		Cool text editor
;; as a shorthand for
;;     Emacs:(emacs).	Cool text editor
;;
;; Enhanced `i' to use line-number information in the index.
;; Added `,' to move among all matches to a previous `i' command.
;;
;; Added `a' (Info-annotate) for adding personal notes to any Info node.
;; Notes are not stored in the actual Info files, but in the user's own
;; ~/.infonotes file.
;;
;; Added Info-footnote-tag, made default be "Ref" instead of "Note".
;;
;; Got mouse-click stuff to work under Emacs version 18.  Check it out!
;; Left and right clicks scroll the Info window.
;; Middle click goes to clicked-on node, e.g., "Next:", a menu, or a note.


;; Modified 6/29/1991 by Dave Gillespie:
;;
;; Renamed epoch-info-startup/select-hooks to Info-startup/select-hook.
;;
;; Made Info-select-node into a command on the `!' key.
;;
;; Added Info-mouse-support user option.
;;
;; Cleaned up the implementation of some routines.
;;
;; Added special treatment of quoted words in annotations:  The `g'
;; command for a nonexistent node name scans for an annotation
;; (in any node of any file) containing that name in quotes:  g foo RET
;; looks for an annotation containing:  "foo"  or:  <<foo>>
;; If found, it goes to that file and node.
;;
;; Added a call to set up Info-directory-list in Info-find-node to
;; work around a bug in GNUS where it calls Info-goto-node before info.
;;
;; Added completion for `g' command (inspired by Richard Kim's infox.el).
;; Completion knows all node names for the current file, and all annotation
;; tags (see above).  It does not complete file names or node names in
;; other files.
;;
;; Added `k' (Info-emacs-key) and `*' (Info-elisp-ref) commands.  You may
;; wish to bind these to global keys outside of Info mode.
;;
;; Allowed localdir files to be full dir-like files; only the menu part
;; of each localdir is copied.  Also, redundant menu items are omitted.
;;
;; Changed Info-history to hold only one entry at a time for each node,
;; and to be circular so that multiple `l's come back again to the most
;; recent node.  Note that the format of Info-history entries has changed,
;; which may interfere with external programs that try to operate on it.
;; (Also inspired by Kim's infox.el).
;;
;; Changed `n', `]', `l', etc. to accept prefix arguments to move several
;; steps at once.  Most accept negative arguments to move oppositely.
;;
;; Changed `?' to bury *Help* buffer afterwards to keep it out of the way.
;;
;; Rearranged `?' key's display to be a little better for new users.
;;
;; Changed `a' to save whole window configuration and restore on C-c C-c.
;;
;; Fixed the bug reported by Bill Reynolds on gnu.emacs.bugs.
;;
;; Changed Info-last to restore window-start as well as cursor position.
;;
;; Changed middle mouse button in space after end of node to do Info-last
;; if we got here by following a cross reference, else do Info-global-next.
;;
;; Added some new mouse bindings: shift-left = Info-global-next,
;; shift-right = Info-global-prev, shift-middle = Info-last.
;;
;; Fixed Info-follow-reference not to make assumptions about length
;; of Info-footnote-tag [Linus Tolke].
;;
;; Changed default for Info-auto-advance mode to be press-twice-for-next-node.
;;
;; Modified x-mouse-ignore to preserve last-command variable, so that
;; press-twice Info-auto-advance mode works with the mouse.


;; Modified 3/4/1992 by Dave Gillespie:
;;
;; Added an "autoload" command to help autoload.el.
;;
;; Changed `*' command to look for file `elisp' as well as for `lispref'.
;;
;; Fixed a bug involving footnote names containing regexp special characters.
;;
;; Fixed a bug in completion during `f' (or `r') command.
;;
;; Added TAB (Info-next-reference), M-TAB, and RET keys to Info mode.
;;
;; Added new bindings, `C-h C-k' for Info-emacs-key and `C-h C-f' for
;; Info-elisp-ref.  These bindings are made when info.el is loaded, and
;; only if those key sequences were previously unbound.  These bindings
;; work at any time, not just when Info is already running.


;; Modified 3/8/1992 by Dave Gillespie:
;;
;; Fixed some long lines that were causing trouble with mailers.


;; Modified 3/9/1992 by Dave Gillespie:
;;
;; Added `C-h C-i' (Info-query).
;;
;; Added Info-novice mode, warns if the user attempts to switch to
;; a different Info file.
;;
;; Fixed a bug that caused problems using compressed Info files
;; and Info-directory-list at the same time.
;;
;; Disabled Info-mouse-support by default if Epoch or Hyperbole is in use.
;;
;; Added an expand-file-name call to Info-find-node to fix a small bug.


;; Modified 5/22/1992 by Dave Gillespie:
;;
;; Added "standalone" operation:  "emacs -f info" runs Emacs specifically
;; for use as an Info browser.  In this mode, the `q' key quits Emacs
;; itself.  Also, "emacs -f info arg" starts in Info file "arg" instead
;; of "dir".
;;
;; Changed to prefer "foo.info" over "foo".  If both exist, "foo" is
;; probably a directory or executable program!
;;
;; Made control-mouse act like regular-mouse does in other buffers.
;; (In most systems, this will be set-cursor for left-mouse, x-cut
;; for right-mouse, and x-paste, which will be an error, for
;; middle-mouse.)
;;
;; Improved prompting and searching for `,' key.
;;
;; Fixed a bug where some "* Menu:" lines disappeared when "dir"
;; contained several nodes.


;; Modified 9/10/1992 by Dave Gillespie:
;;
;; Mixed in support for XEmacs.  Mouse works the same as in
;; the other Emacs versions by default; added Info-lucid-mouse-style
;; variable, which enables mouse operation similar to XEmacs's default.
;;
;; Fixed a bug where RET couldn't understand "* Foo::" if "Foo" was a
;; file name instead of a node name.
;;
;; Added `x' (Info-bookmark), a simple interface to the annotation
;; tags feature.  Added `j' (Info-goto-bookmark), like `g' but only
;; completes bookmarks.
;;
;; Added `<<tag>>' as alternate to `"tag"' in annotations.
;;
;; Added `v' (Info-visit-file), like Info-goto-node but specialized
;; for going to a new Info file (with file name completion).
;;
;; Added recognition of gzip'd ".z" files.


;; Modified 5/9/1993 by Dave Gillespie:
;;
;; Merged in various things from FSF's latest Emacs 19 info.el.

;; Modified 6/2/1993 by Dave Gillespie:
;;
;; Changed to use new suffix ".gz" for gzip files.


;; Modified 7/22/1993 by Dave Gillespie:
;;
;; Changed Info-footnote-tag to "See" instead of "Ref".
;;
;; Extended Info-fontify-node to work with FSF version of Emacs 19.

;; Modified 7/30/1993 by Jamie Zawinski:
;;
;; Commented out the tty and fsf19 mouse support, because why bother.
;; Commented out the politically incorrect version of XEmacs mouse support.
;; Commented out mouse scrolling bindings because the party line on that
;;  is "scrollbars are coming soon."
;; Commented out munging of help-for-help's doc; put it in help.el.
;; Did Info-edit-map the modern XEmacs way.
;; Pruned extra cruft from fontification and mouse handling code.
;; Fixed ASCII-centric bogosity in unreading of events.

;; Modified 8/11/95 by Chuck Thompson:
;;
;; Removed any pretense of ever referencing Info-directory since it
;; wasn't working anyhow.

;; Modified 4/5/97 by Tomasz J. Cholewo:
;;
;; Modified Info-search to use with-caps-disable-folding

;; Modified 6/21/97 by Hrvoje Niksic
;;
;; Fixed up Info-next-reference to work sanely when n < 0.
;; Added S-tab binding.

;; Modified 1997-07-10 by Karl M. Hegbloom
;;
;; Added `Info-minibuffer-history'
;; (also added to defaults in "lisp/utils/savehist.el")
;;  Other changes in main ChangeLog.

;; Modified 1998-03-29 by Oscar Figueiredo
;;
;; Added automatic dir/localdir (re)building capability for directories that
;; contain none or when it has become older than info files in the same
;; directory.

;; Code:

(defgroup info nil
  "The info package for Emacs."
  :group 'help
  :group 'docs)

(defgroup info-faces nil
  "The faces used by info browser."
  :group 'info
  :group 'faces)


(defcustom Info-inhibit-toolbar nil
  "*Non-nil means don't use the specialized Info toolbar."
  :type 'boolean
  :group 'info)

(defcustom Info-novice nil
  "*Non-nil means to ask for confirmation before switching Info files."
  :type 'boolean
  :group 'info)

(defvar Info-history nil
  "List of info nodes user has visited.
Each element of list is a list (\"(FILENAME)NODENAME\" BUFPOS WINSTART).")

(defvar Info-keeping-history t
  "Non-nil if Info-find-node should modify Info-history.
This is for use only by certain internal Info routines.")

(defvar Info-minibuffer-history nil
  "Minibuffer history for Info.")

(defcustom Info-enable-edit nil
  "*Non-nil means the \\<Info-mode-map>\\[Info-edit] command in Info
can edit the current node.
This is convenient if you want to write info files by hand.
However, we recommend that you not do this.
It is better to write a Texinfo file and generate the Info file from that,
because that gives you a printed manual as well."
  :type 'boolean
  :group 'info)

(defcustom Info-enable-active-nodes t
  "*Non-nil allows Info to execute Lisp code associated with nodes.
The Lisp code is executed when the node is selected."
  :type 'boolean
  :group 'info)

(defcustom Info-restoring-point t
  "*Non-nil means to restore the cursor position when re-entering a node."
  :type 'boolean
  :group 'info)

(defcustom Info-auto-advance 'twice
  "*Control what SPC and DEL do when they can't scroll any further.
If nil, they beep and remain in the current node.
If t, they move to the next node (like Info-global-next/prev).
If anything else, they must be pressed twice to move to the next node."
  :type '(choice (const :tag "off" nil)
		 (const :tag "advance" t)
		 (const :tag "confirm" twice))
  :group 'info)

(defcustom Info-fontify t
  "*Non-nil enables font features in XEmacs.
This variable is ignored unless running under XEmacs."
  :type 'boolean
  :group 'info)

(defcustom Info-additional-search-directory-list nil
  "*List of additional directories to search for Info documentation
files.  These directories are not searched for merging the `dir'
file. An example might be something like:
\"/usr/local/lib/xemacs/packages/lisp/calc/\""
  :type '(repeat directory)
  :group 'info)

(defcustom Info-rebuild-outdated-dir 'conservative
  "*What to do if the `dir' or `localdir' file needs to be (re)built.
Possible values are:
`never' never (re)build the `dir' or `localdir' file
`always' automatically (re)builds when needed
`ask' asks the user before (re)building
`conservative' asks the user before overwriting existing files"
  :type '(choice (const :tag "never" never)
		 (const :tag "always" always)
		 (const :tag "ask" ask)
		 (const :tag "conservative" conservative))
  :group 'info)

(defvar Info-emacs-info-file-name "xemacs.info"
  "The filename of the XEmacs info for
`Info-goto-emacs-command-node' (`\\<help-mode-map>\\[Info-goto-emacs-command-node]')")

;;;###autoload
(defvar Info-directory-list nil
  "List of directories to search for Info documentation files.

The first directory in this list, the \"dir\" file there will become
the (dir)Top node of the Info documentation tree.  If you wish to
modify the info search path, use `M-x customize-variable,
Info-directory-list' to do so.")

(defcustom Info-localdir-heading-regexp
    "^Locally installed XEmacs Packages:?"
  "The menu part of localdir files will be inserted below this topic
heading."
  :type 'regexp
  :group 'info)

(defface info-node '((t (:bold t :italic t)))
  "Face used for node links in info."
  :group 'info-faces)

(defface info-xref '((t (:bold t)))
  "Face used for cross-references in info."
  :group 'info-faces)

;; Is this right for NT?  .zip, with -c for to stdout, right?
(defvar Info-suffix-list '( ("" . nil) 
			    (".info" . nil)
			    (".info.gz" . "gzip -dc %s")
			    (".info-z" . "gzip -dc %s")
			    (".info.Z" . "uncompress -c %s")
			    (".gz" . "gzip -dc %s")
			    (".Z" . "uncompress -c %s")
			    (".zip" . "unzip -c %s") )
  "List of file name suffixes and associated decoding commands.
Each entry should be (SUFFIX . STRING); if STRING contains %s, that is
changed to name of the file to decode, otherwise the file is given to
the command as standard input.  If STRING is nil, no decoding is done.")

(defvar Info-footnote-tag "Note"
  "*Symbol that identifies a footnote or cross-reference.
All \"*Note\" references will be changed to use this word instead.")

(defvar Info-current-file nil
  "Info file that Info is now looking at, or nil.
This is the name that was specified in Info, not the actual file name.
It doesn't contain directory names or file name extensions added by Info.")

(defvar Info-current-subfile nil
  "Info subfile that is actually in the *info* buffer now,
or nil if current info file is not split into subfiles.")

(defvar Info-current-node nil
  "Name of node that Info is now looking at, or nil.")

(defvar Info-tag-table-marker (make-marker)
  "Marker pointing at beginning of current Info file's tag table.
Marker points nowhere if file has no tag table.")

(defvar Info-current-file-completions nil
  "Cached completion list for current Info file.")

(defvar Info-current-annotation-completions nil
  "Cached completion list for current annotation files.")

(defvar Info-index-alternatives nil
  "List of possible matches for last Info-index command.")
(defvar Info-index-first-alternative nil)

(defcustom Info-annotations-path '("~/.xemacs/info.notes"
                                   "~/.infonotes"
				   "/usr/lib/info.notes")
  "*Names of files that contain annotations for different Info nodes.
By convention, the first one should reside in your personal directory.
The last should be a world-writable \"public\" annotations file."
  :type '(repeat file)
  :group 'info)

(defcustom Info-button1-follows-hyperlink nil
  "*Non-nil means mouse button1 click will follow hyperlink."
  :type 'boolean
  :group 'info)

(defvar Info-standalone nil
  "Non-nil if Emacs was started solely as an Info browser.")

(defvar Info-in-cross-reference nil)
(defvar Info-window-configuration nil)

(defvar Info-dir-prologue "-*- Text -*-
This is the file .../info/dir, which contains the topmost node of the
Info hierarchy.  The first time you invoke Info you start off
looking at that node, which is (dir)Top.

File: dir	Node: Top	This is the top of the INFO tree
  This (the Directory node) gives a menu of major topics. 

* Menu: The list of major topics begins on the next line.

")

(defvar Info-no-description-string "[No description available]"
  "Description string for info files that have none")

;;;###autoload
(defun info (&optional file)
  "Enter Info, the documentation browser.
Optional argument FILE specifies the file to examine;
the default is the top-level directory of Info.

In interactive use, a prefix argument directs this command
to read a file name from the minibuffer."
  (interactive (if current-prefix-arg
		   (list (read-file-name "Info file name: " nil nil t))))
  (let ((p command-line-args))
    (while p
      (and (string-match "^-[fe]" (car p))
	   (equal (nth 1 p) "info")
	   (not Info-standalone)
	   (setq Info-standalone t)
	   (= (length p) 3)
	   (not (string-match "^-" (nth 2 p)))
	   (setq file (nth 2 p))
	   (setq command-line-args-left nil))
      (setq p (cdr p))))
;  (Info-setup-x) ??? What was this going to be?  Can anyone tell karlheg?
  (if file
      (unwind-protect
	  (Info-goto-node (concat "(" file ")"))
	(and Info-standalone (info)))
    (if (get-buffer "*info*")
	(switch-to-buffer "*info*")
      (Info-directory))))

;;;###autoload
(defun Info-query (file)
  "Enter Info, the documentation browser.  Prompt for name of Info file."
  (interactive "sInfo topic (default = menu): ")
  (info)
  (if (equal file "")
      (Info-goto-node "(dir)")
    (Info-goto-node (concat "(" file ")"))))

(defun Info-setup-initial ()
  (let ((f Info-annotations-path))
    (while f
      (if (and (file-exists-p (car f)) (not (get-file-buffer (car f))))
	  (bury-buffer (find-file-noselect (car f))))
      (setq f (cdr f)))))

(defun Info-find-node (filename &optional nodename no-going-back tryfile line)
  "Go to an info node specified as separate FILENAME and NODENAME.
Look for a plausible filename, or if not found then look for URL's and
dispatch to the appropriate fn.  NO-GOING-BACK is non-nil if
recovering from an error in this function; it says do not attempt
further (recursive) error recovery.  TRYFILE is ??"

  (Info-setup-initial)

  (cond
   ;; empty filename is simple case
   ((null filename)
    (Info-find-file-node nil nodename no-going-back tryfile line))
   ;; Convert filename to lower case if not found as specified.
   ;; Expand it, look harder...
   ((let (temp temp-downcase found 
	       (fname (substitute-in-file-name filename)))
      (let ((dirs (cond
		   ((string-match "^\\./" fname) ; If specified name starts with `./'
		    (list default-directory)) ; then just try current directory.
		   ((file-name-absolute-p fname)
		    '(nil))		; No point in searching for an absolute file name
		   (Info-additional-search-directory-list
		    (append Info-directory-list
			    Info-additional-search-directory-list))
		   (t Info-directory-list))))
	;; Search the directory list for file FNAME.
	(while (and dirs (not found))
	  (setq temp (expand-file-name fname (car dirs)))
	  (setq temp-downcase
		(expand-file-name (downcase fname) (car dirs)))
	  (if (equal temp-downcase temp) (setq temp-downcase nil))
	  ;; Try several variants of specified name.
	  ;; Try downcasing, appending a suffix, or both.
	  (setq found (Info-suffixed-file temp temp-downcase))
	  (setq dirs (cdr dirs)))
	(if found 
	    (progn (setq filename (expand-file-name found))
		   t))))
    (Info-find-file-node filename nodename no-going-back tryfile line))
   ;; Look for a URL.  This pattern is stolen from w3.el to prevent
   ;; loading it if we won't need it.
   ((string-match  (concat "^\\(wais\\|solo\\|x-exec\\|newspost\\|www\\|"
			   "mailto\\|news\\|tn3270\\|ftp\\|http\\|file\\|"
			   "telnet\\|gopher\\):")
		   filename)
    (if (fboundp 'browse-url)
	(browse-url filename)
      (error "Cannot follow URLs in this XEmacs")))
   (t
    (error "Info file %s does not exist" filename))))

(defun Info-find-file-node (filename nodename
				     &optional no-going-back tryfile line)
  ;; This is the guts of what was Info-find-node. Whoever wrote this
  ;; should be locked up where they can't do any more harm.

  ;; Go into info buffer.
  (switch-to-buffer "*info*")
  (buffer-disable-undo (current-buffer))
  (run-hooks 'Info-startup-hook)
  (or (eq major-mode 'Info-mode)
      (Info-mode))
  (or (null filename)
      (equal Info-current-file filename)
      (not Info-novice)
      (string= "dir" (file-name-nondirectory Info-current-file))
      (if (y-or-n-p-maybe-dialog-box
	   (format "Leave Info file `%s'? "
		   (file-name-nondirectory Info-current-file)))
	  (message "")
	(keyboard-quit)))
  ;; Record the node we are leaving.
  (if (and Info-current-file (not no-going-back))
      (Info-history-add Info-current-file Info-current-node (point)))
  (widen)
  (setq Info-current-node nil
	Info-in-cross-reference nil)
  (unwind-protect
      (progn
	;; Switch files if necessary
	(or (null filename)
	    (equal Info-current-file filename)
	    (let ((buffer-read-only nil))
	      (setq Info-current-file nil
		    Info-current-subfile nil
		    Info-current-file-completions nil
		    Info-index-alternatives nil
		    buffer-file-name nil)
	      (erase-buffer)
	      (if (string= "dir" (file-name-nondirectory filename))
		  (Info-insert-dir)
		(Info-insert-file-contents filename t)
		(setq default-directory (file-name-directory filename)))
	      (set-buffer-modified-p nil)
	      ;; See whether file has a tag table.  Record the location if yes.
	      (set-marker Info-tag-table-marker nil)
	      (goto-char (point-max))
	      (forward-line -8)
	      (or (equal nodename "*")
		  (not (search-forward "\^_\nEnd tag table\n" nil t))
		  (let (pos)
		    ;; We have a tag table.  Find its beginning.
		    ;; Is this an indirect file?
		    (search-backward "\nTag table:\n")
		    (setq pos (point))
		    (if (save-excursion
			  (forward-line 2)
			  (looking-at "(Indirect)\n"))
			;; It is indirect.  Copy it to another buffer
			;; and record that the tag table is in that buffer.
			(save-excursion
			  (let ((buf (current-buffer)))
			    (set-buffer
			     (get-buffer-create " *info tag table*"))
			    (buffer-disable-undo (current-buffer))
			    (setq case-fold-search t)
			    (erase-buffer)
			    (insert-buffer-substring buf)
			    (set-marker Info-tag-table-marker
					(match-end 0))))
		     (set-marker Info-tag-table-marker pos))))
	      (setq Info-current-file
		    (file-name-sans-versions buffer-file-name))))
	(if (equal nodename "*")
	    (progn (setq Info-current-node nodename)
		   (Info-set-mode-line)
		   (goto-char (point-min)))
	  ;; Search file for a suitable node.
	  (let* ((qnode (regexp-quote nodename))
		 (regexp (concat "Node: *" qnode " *[,\t\n\177]"))
		 (guesspos (point-min))
		 (found t))
	    ;; First get advice from tag table if file has one.
	    ;; Also, if this is an indirect info file,
	    ;; read the proper subfile into this buffer.
	    (if (marker-position Info-tag-table-marker)
		(save-excursion
		  (set-buffer (marker-buffer Info-tag-table-marker))
		  (goto-char Info-tag-table-marker)
		  (if (re-search-forward regexp nil t)
		      (progn
			(setq guesspos (read (current-buffer)))
			;; If this is an indirect file,
			;; determine which file really holds this node
			;; and read it in.
			(if (not (eq (current-buffer) (get-buffer "*info*")))
			    (setq guesspos
				  (Info-read-subfile guesspos)))))))
	    (goto-char (max (point-min) (- guesspos 1000)))
	    ;; Now search from our advised position (or from beg of buffer)
	    ;; to find the actual node.
	    (catch 'foo
	      (while (search-forward "\n\^_" nil t)
		(forward-line 1)
		(let ((beg (point)))
		  (forward-line 1)
		  (if (re-search-backward regexp beg t)
		      (throw 'foo t))))
	      (setq found nil)
	      (let ((bufs (delq nil (mapcar 'get-file-buffer
					    Info-annotations-path)))
		    (pattern (if (string-match "\\`<<.*>>\\'" qnode) qnode
			       (format "\"%s\"\\|<<%s>>" qnode qnode)))
		    (pat2 (concat "------ *File: *\\([^ ].*[^ ]\\) *Node: "
				  "*\\([^ ].*[^ ]\\) *Line: *\\([0-9]+\\)"))
		    (afile nil) anode aline)
		(while (and bufs (not anode))
		  (save-excursion
		    (set-buffer (car bufs))
		    (goto-char (point-min))
		    (if (re-search-forward pattern nil t)
			(if (re-search-backward pat2 nil t)
			    (setq afile (buffer-substring (match-beginning 1)
							  (match-end 1))
				  anode (buffer-substring (match-beginning 2)
							  (match-end 2))
				  aline (string-to-int
					 (buffer-substring (match-beginning 3)
							   (match-end 3)))))))
		  (setq bufs (cdr bufs)))
		(if anode
		    (Info-find-node afile anode t nil aline)
		  (if tryfile
		      (condition-case nil
			  (Info-find-node nodename "Top" t)
			(error nil)))))
	      (or Info-current-node
		  (error "No such node: %s" nodename)))
	    (if found
		(progn
		  (Info-select-node)
		  (goto-char (point-min))
		  (if line (forward-line line)))))))
    ;; If we did not finish finding the specified node,
    ;; go back to the previous one.
    (or Info-current-node no-going-back
	(let ((hist (car Info-history)))
	  ;; The following is no longer safe with new Info-history system
	  ;; (setq Info-history (cdr Info-history))
	  (Info-goto-node (car hist) t)
	  (goto-char (+ (point-min) (nth 1 hist)))))))

;; Cache the contents of the (virtual) dir file, once we have merged
;; it for the first time, so we can save time subsequently.
(defvar Info-dir-contents nil)

;; Cache for the directory we decided to use for the default-directory
;; of the merged dir text.
(defvar Info-dir-contents-directory nil)

;; Record the file attributes of all the files from which we
;; constructed Info-dir-contents.
(defvar Info-dir-file-attributes nil)

(defun Info-insert-dir ()
  "Construct the Info directory node by merging the files named
\"dir\" or \"localdir\" from the directories in `Info-directory-list'
The \"dir\" files will take precedence in cases where both exist.  It
sets the *info* buffer's `default-directory' to the first directory we
actually get any text from."
  (if (and Info-dir-contents Info-dir-file-attributes
	   ;; Verify that none of the files we used has changed
	   ;; since we used it.
	   (eval (cons 'and
		       (mapcar '(lambda (elt)
				  (let ((curr (file-attributes (car elt))))
				    ;; Don't compare the access time.
				    (if curr (setcar (nthcdr 4 curr) 0))
				    (setcar (nthcdr 4 (cdr elt)) 0)
				    (equal (cdr elt) curr)))
			       Info-dir-file-attributes))))
      (insert Info-dir-contents)
    (let ((dirs (reverse Info-directory-list))
	  buffers lbuffers buffer others nodes dirs-done)

      (setq Info-dir-file-attributes nil)

      ;; Search the directory list for the directory file.
      (while dirs
	(let ((truename (file-truename (expand-file-name (car dirs)))))
	  (or (member truename dirs-done)
	      (member (directory-file-name truename) dirs-done)
	      ;; Try several variants of specified name.
	      ;; Try upcasing, appending `.info', or both.
	      (let* (buf
		     file
		     (attrs
		      (or
		       (progn (setq file (expand-file-name "dir" truename))
			      (file-attributes file))
		       (progn (setq file (expand-file-name "DIR" truename))
			      (file-attributes file))
		       (progn (setq file (expand-file-name "dir.info" truename))
			      (file-attributes file))
		       (progn (setq file (expand-file-name "DIR.INFO" truename))
			      (file-attributes file))
		       (progn (setq file (expand-file-name "localdir" truename))
			      (file-attributes file))
		       (progn (setq file (expand-file-name "dir" truename))
			      nil)
		       )))
		(setq dirs-done
		      (cons truename
			    (cons (directory-file-name truename)
				  dirs-done)))
		(Info-maybe-update-dir file)
		(setq attrs (file-attributes file))
		(if (or (setq buf (find-buffer-visiting file))
			attrs)
		    (save-excursion
		      (or buffers
			  (message "Composing main Info directory..."))
		      (set-buffer (or buf
				      (generate-new-buffer
				       (if (string-match "localdir" file)
					   "localdir"
					 "info dir"))))
		      (if (not buf) 
			  (insert-file-contents file))
		      (if (string-match "localdir" (buffer-name))
			  (setq lbuffers (cons (current-buffer) lbuffers))
			(setq buffers (cons (current-buffer) buffers)))
		      (if attrs
			  (setq Info-dir-file-attributes
				(cons (cons file attrs)
				      Info-dir-file-attributes)))))))
	  (or (cdr dirs) (setq Info-dir-contents-directory (car dirs)))
	  (setq dirs (cdr dirs))))
      
      ;; ensure that the localdir files are inserted last, and reverse
      ;; the list of them so that when they get pushed in, they appear
      ;; in the same order they got specified in the path, from top to
      ;; bottom.
      (nconc buffers (nreverse lbuffers))
      
      (or buffers
	  (error "Can't find the Info directory node"))
      ;; Distinguish the dir file that comes with Emacs from all the
      ;; others.  Yes, that is really what this is supposed to do.
      ;; If it doesn't work, fix it.
      (setq buffer (car buffers)
	    ;; reverse it since they are pushed down from the top. the
	    ;; `Info-directory-list can be specified in natural order
	    ;; this way.
	    others (nreverse (cdr buffers)))

      ;; Insert the entire original dir file as a start; note that we've
      ;; already saved its default directory to use as the default
      ;; directory for the whole concatenation.
      (insert-buffer buffer)

      ;; Look at each of the other buffers one by one.
      (while others
	(let ((other (car others))
	      (info-buffer (current-buffer)))
	  (if (string-match "localdir" (buffer-name other))
	      (save-excursion
		(set-buffer info-buffer)
		(goto-char (point-max))
		(cond
		 ((re-search-backward "^ *\\* *Locals *: *$" nil t)
		  (delete-region (match-beginning 0) (match-end 0)))
		 ;; look for a line like |Local XEmacs packages:
		 ;; or mismatch on some text ...
		 ((re-search-backward Info-localdir-heading-regexp nil t)
		  ;; This is for people who underline topic headings with
		  ;; equal signs or dashes.
		  (when (save-excursion
			  (forward-line 1)
			  (beginning-of-line)
			  (looking-at "^[ \t]*[-=*]+"))
		    (forward-line 1))
		  (forward-line 1)
		  (beginning-of-line))
		 (t (search-backward "\^L" nil t)))
		;; Insert menu part of the file
		(let* ((pt (point))
		       (len (length (buffer-string nil nil other))))
		  (insert (buffer-string nil nil other))
		  (goto-char (+ pt len))
		  (save-excursion
		    (goto-char pt)
		    (if (search-forward "* Menu:" (+ pt len) t)
			(progn
			  (forward-line 1)
			  (delete-region pt (point)))))))
	    ;; In each, find all the menus.
	    (save-excursion
	      (set-buffer other)
	      (goto-char (point-min))
	      ;; Find each menu, and add an elt to NODES for it.
	      (while (re-search-forward "^\\* Menu:" nil t)
		(let (beg nodename end)
		  (forward-line 1)
		  (setq beg (point))
		  (search-backward "\n\^_")
		  (search-forward "Node: ")
		  (setq nodename (Info-following-node-name))
		  (search-forward "\n\^_" nil 'move)
		  (beginning-of-line)
		  (setq end (point))
		  (setq nodes (cons (list nodename other beg end) nodes))))))
	  (setq others (cdr others))))
      
      ;; Add to the main menu a menu item for each other node.
      (re-search-forward "^\\* Menu:" nil t)
      (forward-line 1)
      (let ((menu-items '("top"))
	    (nodes nodes)
	    (case-fold-search t)
	    (end (save-excursion (search-forward "\^_" nil t) (point))))
	(while nodes
	  (let ((nodename (car (car nodes))))
	    (save-excursion
	      (or (member (downcase nodename) menu-items)
		  (re-search-forward (concat "^\\* "
					     (regexp-quote nodename)
					     "::")
				     end t)
		  (progn
		    (insert "* " nodename "::" "\n")
		    (setq menu-items (cons nodename menu-items))))))
	  (setq nodes (cdr nodes))))
      ;; Now take each node of each of the other buffers
      ;; and merge it into the main buffer.
      (while nodes
	(let ((nodename (car (car nodes))))
	  (goto-char (point-min))
	  ;; Find the like-named node in the main buffer.
	  (if (re-search-forward (concat "\n\^_.*\n.*Node: "
					 (regexp-quote nodename)
					 "[,\n\t]")
				 nil t)
	      (progn
		(search-forward "\n\^_" nil 'move)
		(beginning-of-line)
		(insert "\n"))
	    ;; If none exists, add one.
	    (goto-char (point-max))
	    (insert "\^_\nFile: dir\tNode: " nodename "\n\n* Menu:\n\n"))
	  ;; Merge the text from the other buffer's menu
	  ;; into the menu in the like-named node in the main buffer.
	  (apply 'insert-buffer-substring (cdr (car nodes))))
	(setq nodes (cdr nodes)))
      ;; Kill all the buffers we just made.
      (while buffers
	(kill-buffer (car buffers))
	(setq buffers (cdr buffers)))
      (while lbuffers
	(kill-buffer (car lbuffers))
	(setq lbuffers (cdr lbuffers)))
      (message "Composing main Info directory...done"))
    (setq Info-dir-contents (buffer-string)))
  (setq default-directory Info-dir-contents-directory)
  (setq buffer-file-name (caar Info-dir-file-attributes)))

(defun Info-maybe-update-dir (file)
  "Rebuild dir or localdir if it does not exist or is outdated."
  (unless (or (eq Info-rebuild-outdated-dir 'never)
	      (not (file-exists-p (file-name-directory file)))
	      (null (directory-files (file-name-directory file) nil "\\.info")))
    (if (not (find-buffer-visiting file))
	(if (not (file-exists-p file))
	    (if (or (eq Info-rebuild-outdated-dir 'always)
		    (and (eq Info-rebuild-outdated-dir 'conservative)
			 (not (file-writable-p file)))
		    (and (eq Info-rebuild-outdated-dir 'ask)
			 (y-or-n-p (format "No dir file in %s. Rebuild now ? " (file-name-directory file)))))
		(Info-build-dir-anew (file-name-directory file) (not (file-writable-p file))))
	  (if (Info-dir-outdated-p file)
	      (if (or (eq Info-rebuild-outdated-dir 'always)
		      (and (eq Info-rebuild-outdated-dir 'conservative)
			   (not (file-writable-p file)))
		      (and (eq Info-rebuild-outdated-dir 'ask)
			   (y-or-n-p (format "%s is outdated. Rebuild now ? " file))))
		  (Info-rebuild-dir file (not (file-writable-p file)))))))))

;; Record which *.info files are newer than the dir file
(defvar Info-dir-newer-info-files nil)

(defun Info-dir-outdated-p (file)
  "Return non-nil if dir or localdir is outdated.
dir or localdir are outdated when a *.info file in the same
directory has been modified more recently."
  (let ((dir-mod-time (nth 5 (file-attributes file)))
	f-mod-time
	newer)
    (setq Info-dir-newer-info-files nil)
    (mapcar 
     '(lambda (f)
	(prog2
	    (setq f-mod-time (nth 5 (file-attributes f)))
	    (setq newer (or (> (car f-mod-time) (car dir-mod-time))
			    (and (= (car f-mod-time) (car dir-mod-time))
				 (> (car (cdr f-mod-time)) (car (cdr dir-mod-time))))))
	  (if (and (file-readable-p f)
		   newer)
	      (setq Info-dir-newer-info-files 
		    (cons f Info-dir-newer-info-files)))))
     (directory-files (file-name-directory file)
		      'fullname
		      ".*\\.info\\(.gz\\|.Z\\|-z\\|.zip\\)?$"
		      'nosort
		      t))
    Info-dir-newer-info-files))

(defun Info-extract-dir-entry-from (file)
  "Extract the dir entry from the info FILE.
The dir entry is delimited by the markers `START-INFO-DIR-ENTRY'
and `END-INFO-DIR-ENTRY'"
  (save-excursion
    (set-buffer (get-buffer-create " *Info-tmp*"))
    (when (file-readable-p file)
      (insert-file-contents file nil nil nil t)
      (goto-char (point-min))
      (let (beg)
	(unless (null (re-search-forward "^START-INFO-DIR-ENTRY" nil t))
	  (forward-line 1)
	  (setq beg (point))
	  (unless (null (re-search-forward "^END-INFO-DIR-ENTRY" nil t))
	    (goto-char (match-beginning 0))
	    (car (Info-parse-dir-entries beg (point)))))))))

;; Parse dir entries contained between BEG and END into a list of the form
;; (filename topic node (description-line-1 description-line-2 ...))
(defun Info-parse-dir-entries (beg end)
  (let (entry entries)
    (save-excursion
      (save-restriction
	(narrow-to-region beg end)
	(goto-char beg)
	(while (re-search-forward "^\\* \\([^:]+\\):\\([ \t]*(\\(.*\\))\\w*\\.\\|:\\)" nil t)
	  (setq entry (list (match-string 2)
			    (match-string 1)
			    (downcase (or (match-string 3)
					  (match-string 1)))))
	  (setq entry (cons (nreverse 
			     (cdr 
			      (nreverse 
			       (split-string (buffer-substring (re-search-forward "[ \t]*" nil t)
							       (or (and (re-search-forward "^[^ \t]" nil t)
									(goto-char (match-beginning 0)))
								   (point-max)))
					     "[ \t]*\n[ \t]*"))))
			    entry))
	  (setq entries (cons (nreverse entry) entries)))))
    (nreverse entries)))

(defun Info-dump-dir-entries (entries)
  (let ((tab-width 8)
	(description-col 0)
	len)
    (mapcar '(lambda (e)
	       (setq e (cdr e))		; Drop filename
	       (setq len (length (concat (car e)
					 (car (cdr e)))))
	       (if (> len description-col)
		   (setq description-col len)))
	    entries)
    (setq description-col (+ 5 description-col)) 
    (mapcar '(lambda (e)
	       (setq e (cdr e))		; Drop filename
	       (insert "* " (car e) ":" (car (cdr e)))
	       (setq e (car (cdr (cdr e))))
	       (while e
		 (indent-to-column description-col)
		 (insert (car e) "\n")
		 (setq e (cdr e))))
	    entries)))


(defun Info-build-dir-anew (directory to-temp)
  "Build a new info dir file in DIRECTORY"
  (save-excursion
    (let ((dirfile (expand-file-name "dir" directory))
	  (info-files 
	   (directory-files directory
			    'fullname
			    ".*\\.info\\(.gz\\|.Z\\|-z\\|.zip\\)?$"
			    nil
			    t)))
      (if to-temp
	  (display-warning 'info (format "Missing info dir file in %s" directory) 'notice)
	(message "Creating %s..." dirfile))
      (set-buffer (find-file-noselect dirfile t))
      (setq buffer-read-only nil)
      (erase-buffer)
      (insert Info-dir-prologue
	      "Info files in " directory ":\n\n")
      (Info-dump-dir-entries 
       (mapcar 
	'(lambda (f)
	   (or (Info-extract-dir-entry-from f)
	       (list 'dummy
		     (file-name-sans-extension (file-name-nondirectory f))
		     ":"
		     (list Info-no-description-string))))
	info-files))
      (if to-temp
	  (set-buffer-modified-p nil)
	(save-buffer))
      (if to-temp
	  (message "Creating temporary dir...done")
	(message "Creating %s...done" dirfile)))))


(defun Info-rebuild-dir (file to-temp)
  "Update an existing info dir file after info files have been modified"
  (save-excursion
    (save-restriction
      (let (dir-section-contents dir-full-contents
	    dir-entry
	    file-dir-entry
	    mark next-section
	    not-first-section)
	(set-buffer (find-file-noselect file t))
	(setq buffer-read-only nil)
	(if to-temp
	    (display-warning 'info (format "Outdated info dir file: %s" file) 'notice)
	  (message "Rebuilding %s..." file))
	(catch 'done
	  (setq buffer-read-only nil)
	  (goto-char (point-min))
	  (unless (and (search-forward "\^_")
		       (re-search-forward "^\\* Menu:.*$" nil t)
		       (setq mark (and (re-search-forward "^\\* " nil t)
				       (match-beginning 0))))
	    (throw 'done nil))
	  (setq dir-full-contents (Info-parse-dir-entries mark (point-max)))
	  (setq next-section (or (and (re-search-forward "^[^* \t].*:[ \t]*$" nil t)
				      (match-beginning 0))
				 (point-max)))
	  (while next-section
	    (narrow-to-region mark next-section)
	    (setq dir-section-contents (nreverse (Info-parse-dir-entries (point-min)
									 (point-max))))
	    (mapcar '(lambda (file)
		       (setq dir-entry (assoc (downcase
					       (file-name-sans-extension
						(file-name-nondirectory file)))
					      dir-section-contents)
			     file-dir-entry (Info-extract-dir-entry-from file))
		       (if dir-entry
			   (if file-dir-entry
			       ;; A dir entry in the info file takes precedence over an
			       ;; existing entry in the dir file
			       (setcdr dir-entry (cdr file-dir-entry)))
			 (unless (or not-first-section
				     (assoc (downcase
					 (file-name-sans-extension
					  (file-name-nondirectory file)))
					dir-full-contents))
			   (if file-dir-entry
			       (setq dir-section-contents (cons file-dir-entry
								dir-section-contents))
			     (setq dir-section-contents 
				   (cons (list 'dummy
					       (capitalize (file-name-sans-extension
							    (file-name-nondirectory file)))
					       ":"
					       (list Info-no-description-string)) 
					 dir-section-contents))))))
		    Info-dir-newer-info-files)
	    (delete-region (point-min) (point-max))
	    (Info-dump-dir-entries (nreverse dir-section-contents))
	    (widen)
	    (if (= next-section (point-max))
		(setq next-section nil)
	      (or (setq mark (and (re-search-forward "^\\* " nil t)
				  (match-beginning 0)))
		  (throw 'done nil))
	      (setq next-section (or (and (re-search-forward "^[^* \t].*:[ \t]*$" nil t)
					  (match-beginning 0))
				     (point-max))))
	    (setq not-first-section t)))
	(if to-temp
	    (set-buffer-modified-p nil)
	  (save-buffer))
	(if to-temp
	    (message "Rebuilding temporary dir...done")
	  (message "Rebuilding %s...done" file))))))
      

(defun Info-history-add (file node point)
  (if Info-keeping-history
      (let* ((name (format "(%s)%s" (Info-file-name-only file) node))
	     (found (assoc name Info-history)))
	(if found
	    (setq Info-history (delq found Info-history)))
	(setq Info-history (cons (list name (- point (point-min))
				       (and (eq (window-buffer)
						(current-buffer))
					    (- (window-start) (point-min))))
				 Info-history)))))

(defun Info-file-name-only (file)
  (let ((dir (file-name-directory file))
	(p Info-directory-list))
    (while (and p (not (equal (car p) dir)))
      (setq p (cdr p)))
    (if p (file-name-nondirectory file) file)))

(defun Info-read-subfile (nodepos)
  (set-buffer (marker-buffer Info-tag-table-marker))
  (goto-char (point-min))
  (search-forward "\n\^_")
  (let (lastfilepos
	lastfilename)
    (forward-line 2)
    (catch 'foo
      (while (not (looking-at "\^_"))
	(if (not (eolp))
	    (let ((beg (point))
		  thisfilepos thisfilename)
	      (search-forward ": ")
	      (setq thisfilename  (buffer-substring beg (- (point) 2)))
	      (setq thisfilepos (read (current-buffer)))
	      ;; read in version 19 stops at the end of number.
	      ;; Advance to the next line.
	      (if (eolp)
		  (forward-line 1))
	      (if (> thisfilepos nodepos)
		  (throw 'foo t))
	      (setq lastfilename thisfilename)
	      (setq lastfilepos thisfilepos))
	  (throw 'foo t))))
    (set-buffer (get-buffer "*info*"))
    (or (equal Info-current-subfile lastfilename)
	(let ((buffer-read-only nil))
	  (setq buffer-file-name nil)
	  (widen)
	  (erase-buffer)
	  (Info-insert-file-contents (Info-suffixed-file
				      (expand-file-name lastfilename
							(file-name-directory
							 Info-current-file)))
				     t)
	  (set-buffer-modified-p nil)
	  (setq Info-current-subfile lastfilename)))
    (goto-char (point-min))
    (search-forward "\n\^_")
    (+ (- nodepos lastfilepos) (point))))

(defun Info-suffixed-file (name &optional name2)
  "Look for NAME with each of the `Info-suffix-list' extensions in
turn. Optional NAME2 is the name of a fallback info file to check
for; usually a downcased version of NAME."
  (let ((suff Info-suffix-list)
	(found nil)
	file file2)
    (while (and suff (not found))
      (setq file (concat name (caar suff))
	    file2 (and name2 (concat name2 (caar suff))))
      (cond
       ((file-exists-p file)
	(setq found file))
       ((and file2 (file-exists-p file2))
	(setq found file2))
       (t
	(setq suff (cdr suff)))))
    (or found
	(and name (when (file-exists-p name)
		    name))
	(and name2 (when (file-exists-p name2)
		     name2)))))

(defun Info-insert-file-contents (file &optional visit)
  (setq file (expand-file-name file default-directory))
  (let ((suff Info-suffix-list))
    (while (and suff (or (<= (length file) (length (car (car suff))))
			 (not (equal (substring file
						(- (length (car (car suff)))))
				     (car (car suff))))))
      (setq suff (cdr suff)))
    (if (stringp (cdr (car suff)))
	(let ((command (if (string-match "%s" (cdr (car suff)))
			   (format (cdr (car suff)) file)
			 (concat (cdr (car suff)) " < " file))))
	  (message "%s..." command)
	  (if (eq system-type 'vax-vms)
	      (call-process command nil t nil)
	    (call-process shell-file-name nil t nil "-c" command))
	  (message "")
	  (if visit
	      (progn
		(setq buffer-file-name file)
		(set-buffer-modified-p nil)
		(clear-visited-file-modtime))))
      (insert-file-contents file visit))))

(defun Info-select-node ()
  "Select the node that point is in, after using `g *' to select whole file."
  (interactive)
  (widen)
  (save-excursion
   ;; Find beginning of node.
   (search-backward "\n\^_")
   (forward-line 2)
   ;; Get nodename spelled as it is in the node.
   (re-search-forward "Node:[ \t]*")
   (setq Info-current-node
	 (buffer-substring (point)
			   (progn
			    (skip-chars-forward "^,\t\n")
			    (point))))
   (Info-set-mode-line)
   ;; Find the end of it, and narrow.
   (beginning-of-line)
   (let (active-expression)
     (narrow-to-region (point)
		       (if (re-search-forward "\n[\^_\f]" nil t)
			   (prog1
			    (1- (point))
			    (if (looking-at "[\n\^_\f]*execute: ")
				(progn
				  (goto-char (match-end 0))
				  (setq active-expression
					(read (current-buffer))))))
			 (point-max)))
     (or (equal Info-footnote-tag "Note")
	 (progn
	   (goto-char (point-min))
	   (let ((buffer-read-only nil)
		 (bufmod (buffer-modified-p))
		 (case-fold-search t))
	     (while (re-search-forward "\\*[Nn]ote\\([ \n]\\)" nil t)
	       (replace-match (concat "*" Info-footnote-tag "\ ")))
	     (set-buffer-modified-p bufmod))))
     (Info-reannotate-node)
     ;; XEmacs: remove v19 test
     (and Info-fontify
	  (Info-fontify-node))
     (run-hooks 'Info-select-hook)
     (if Info-enable-active-nodes (eval active-expression)))))

(defun Info-set-mode-line ()
  (setq modeline-buffer-identification
	(list (cons modeline-buffer-id-left-extent "Info: ")
	      (cons modeline-buffer-id-right-extent
		    (concat
		     "("
		     (if Info-current-file
			 (let ((name (file-name-nondirectory Info-current-file)))
			   (if (string-match "\\.info$" name)
			       (substring name 0 -5)
			     name))
		       "")
		     ")"
		     (or Info-current-node ""))))))

;; Go to an info node specified with a filename-and-nodename string
;; of the sort that is found in pointers in nodes.

;;;###autoload
(defun Info-goto-node (nodename &optional no-going-back tryfile)
  "Go to info node named NAME.  Give just NODENAME or (FILENAME)NODENAME.
Actually, the following interpretations of NAME are tried in order:
    (FILENAME)NODENAME
    (FILENAME)     (using Top node)
    NODENAME       (in current file)
    TAGNAME        (see below)
    FILENAME       (using Top node)
where TAGNAME is a string that appears in quotes: \"TAGNAME\", in an
annotation for any node of any file.  (See `a' and `x' commands.)"
  (interactive (list (Info-read-node-name "Goto node, file or tag: ")
		     nil t))
  (let (filename)
    (string-match "\\s *\\((\\s *\\([^\t)]*\\)\\s *)\\s *\\|\\)\\(.*\\)"
		  nodename)
    (setq filename (if (= (match-beginning 1) (match-end 1))
		       ""
		     (substring nodename (match-beginning 2) (match-end 2)))
	  nodename (substring nodename (match-beginning 3) (match-end 3)))
    (let ((trim (string-match "\\s *\\'" filename)))
      (if trim (setq filename (substring filename 0 trim))))
    (let ((trim (string-match "\\s *\\'" nodename)))
      (if trim (setq nodename (substring nodename 0 trim))))
    (Info-find-node (if (equal filename "") nil filename)
		    (if (equal nodename "") "Top" nodename)
		    no-going-back (and tryfile (equal filename "")))))

(defun Info-goto-bookmark ()
  (interactive)
  (let ((completion-ignore-case nil)
	(tag (completing-read "Goto tag: "
			      (Info-build-annotation-completions)
			      nil t nil
			      'Info-minibuffer-history)))
    (or (equal tag "") (Info-find-node nil (format "<<%s>>" tag)))))

;;;###autoload
(defun Info-visit-file ()
  "Directly visit an info file."
  (interactive)
  (let* ((insert-default-directory nil)
	 (file (read-file-name "Goto Info file: " "" "")))
    (or (equal file "") (Info-find-node (expand-file-name file) "Top"))))

(defun Info-restore-point (&optional always)
  "Restore point to same location it had last time we were in this node."
  (interactive "p")
  (if (or Info-restoring-point always)
      (let* ((name (format "(%s)%s"
			   (Info-file-name-only Info-current-file)
			   Info-current-node))
	     (p (assoc name Info-history)))
	(if p (Info-restore-history-entry p)))))

(defun Info-restore-history-entry (entry)
  (goto-char (+ (nth 1 entry) (point-min)))
  (and (nth 2 entry)
       (get-buffer-window (current-buffer))
       (set-window-start (get-buffer-window (current-buffer))
			 (+ (nth 2 entry) (point-min)))))

(defun Info-read-node-name (prompt &optional default)
  (Info-setup-initial)
  (let* ((completion-ignore-case t)
	 (nodename (completing-read prompt
				    (Info-build-node-completions)
				    nil nil nil
				    'Info-minibuffer-history)))
    (if (equal nodename "")
	(or default
	    (Info-read-node-name prompt))
      nodename)))

(defun Info-build-annotation-completions ()
  (or Info-current-annotation-completions
      (save-excursion
	(let ((bufs (delq nil (mapcar 'get-file-buffer
				      Info-annotations-path)))
	      (compl nil))
	  (while bufs
	    (set-buffer (car bufs))
	    (goto-char (point-min))
	    (while (re-search-forward "<<\\(.*\\)>>" nil t)
	      (setq compl (cons (list (buffer-substring (match-beginning 1)
							(match-end 1)))
				compl)))
	    (setq bufs (cdr bufs)))
	  (setq Info-current-annotation-completions compl)))))

(defun Info-build-node-completions ()
  (or Info-current-file-completions
      (let ((compl (Info-build-annotation-completions)))
	(save-excursion
	  (save-restriction
	    (if (marker-buffer Info-tag-table-marker)
		(progn
		  (set-buffer (marker-buffer Info-tag-table-marker))
		  (goto-char Info-tag-table-marker)
		  (while (re-search-forward "\nNode: \\(.*\\)\177" nil t)
		    (setq compl
			  (cons (list (buffer-substring (match-beginning 1)
							(match-end 1)))
				compl))))
	      (widen)
	      (goto-char (point-min))
	      (while (search-forward "\n\^_" nil t)
		(forward-line 1)
		(let ((beg (point)))
		  (forward-line 1)
		  (if (re-search-backward "Node: *\\([^,\n]*\\) *[,\n\t]"
					  beg t)
		      (setq compl 
			    (cons (list (buffer-substring (match-beginning 1)
							  (match-end 1)))
				  compl))))))))
	(setq Info-current-file-completions compl))))

(defvar Info-last-search nil
  "Default regexp for \\<Info-mode-map>\\[Info-search] command to search for.")


;;;###autoload
(defun Info-search (regexp)
  "Search for REGEXP, starting from point, and select node it's found in."
  (interactive "sSearch (regexp): ")
  (if (equal regexp "")
      (setq regexp Info-last-search)
    (setq Info-last-search regexp))
  (with-caps-disable-folding regexp
    (let ((found ())
          (onode Info-current-node)
          (ofile Info-current-file)
          (opoint (point))
          (osubfile Info-current-subfile))
      (save-excursion
        (save-restriction
          (widen)
          (if (null Info-current-subfile)
              (progn (re-search-forward regexp) (setq found (point)))
            (condition-case nil
                (progn (re-search-forward regexp) (setq found (point)))
              (search-failed nil)))))
      (if (not found)                   ;can only happen in subfile case -- else would have erred
          (unwind-protect
              (let ((list ()))
                (set-buffer (marker-buffer Info-tag-table-marker))
                (goto-char (point-min))
                (search-forward "\n\^_\nIndirect:")
                (save-restriction
                  (narrow-to-region (point)
                                    (progn (search-forward "\n\^_")
                                           (1- (point))))
                  (goto-char (point-min))
                  (search-forward (concat "\n" osubfile ": "))
                  (beginning-of-line)
                  (while (not (eobp))
                    (re-search-forward "\\(^.*\\): [0-9]+$")
                    (goto-char (+ (match-end 1) 2))
                    (setq list (cons (cons (read (current-buffer))
                                           (buffer-substring (match-beginning 1)
                                                             (match-end 1)))
                                     list))
                    (goto-char (1+ (match-end 0))))
                  (setq list (nreverse list)
                        list (cdr list)))
                (while list
                  (message "Searching subfile %s..." (cdr (car list)))
                  (Info-read-subfile (car (car list)))
                  (setq list (cdr list))
                  (goto-char (point-min))
                  (if (re-search-forward regexp nil t)
                      (setq found (point) list ())))
                (if found
                    (message "")
                  (signal 'search-failed (list regexp))))
            (if (not found)
                (progn (Info-read-subfile opoint)
                       (goto-char opoint)
                       (Info-select-node)))))
      (widen)
      (goto-char found)
      (Info-select-node)
      (or (and (equal onode Info-current-node)
               (equal ofile Info-current-file))
          (Info-history-add ofile onode opoint)))))

;; Extract the value of the node-pointer named NAME.
;; If there is none, use ERRORNAME in the error message; 
;; if ERRORNAME is nil, just return nil.
(defun Info-extract-pointer (name &optional errorname)
  (save-excursion
   (goto-char (point-min))
   (forward-line 4)
   (let ((case-fold-search t))
     (if (re-search-backward (concat name ":") nil t)
	 (progn
	   (goto-char (match-end 0))
	   (Info-following-node-name))
       (if (eq errorname t)
	   nil
	 (error (concat "Node has no " (capitalize (or errorname name)))))))))

;; Return the node name in the buffer following point.
;; ALLOWEDCHARS, if non-nil, goes within [...] to make a regexp
;; saying which chas may appear in the node name.
(defun Info-following-node-name (&optional allowedchars)
  (skip-chars-forward " \t")
  (buffer-substring
   (point)
   (progn
     (while (looking-at (concat "[" (or allowedchars "^,\t\n") "]"))
       (skip-chars-forward (concat (or allowedchars "^,\t\n") "("))
       (if (looking-at "(")
	   (skip-chars-forward "^)")))
     (skip-chars-backward " ")
     (point))))

(defun Info-next (&optional n)
  "Go to the next node of this node.
A positive or negative prefix argument moves by multiple nodes."
  (interactive "p")
  (or n (setq n 1))
  (if (< n 0)
      (Info-prev (- n))
    (while (>= (setq n (1- n)) 0)
      (Info-goto-node (Info-extract-pointer "next")))))

(defun Info-prev (&optional n)
  "Go to the previous node of this node.
A positive or negative prefix argument moves by multiple nodes."
  (interactive "p")
  (or n (setq n 1))
  (if (< n 0)
      (Info-next (- n))
    (while (>= (setq n (1- n)) 0)
      (Info-goto-node (Info-extract-pointer "prev[ious]*" "previous")))))

(defun Info-up (&optional n)
  "Go to the superior node of this node.
A positive prefix argument moves up several times."
  (interactive "p")
  (or n (setq n 1))
  (while (>= (setq n (1- n)) 0)
    (Info-goto-node (Info-extract-pointer "up")))
  (if (interactive-p) (Info-restore-point)))

(defun Info-last (&optional n)
  "Go back to the last node visited.
With a prefix argument, go to Nth most recently visited node.  History is
circular; after oldest node, history comes back around to most recent one.
Argument can be negative to go through the circle in the other direction.
\(In other words, `l' is like \"undo\" and `C-u - l' is like \"redo\".)"
  (interactive "p")
  (or n (setq n 1))
  (or Info-history
      (error "This is the first Info node you looked at"))
  (let ((len (1+ (length Info-history))))
    (setq n (% (+ n (* len 100)) len)))
  (if (> n 0)
      (let ((entry (nth (1- n) Info-history)))
	(Info-history-add Info-current-file Info-current-node (point))
	(while (>= (setq n (1- n)) 0)
	  (setq Info-history (nconc (cdr Info-history)
				    (list (car Info-history)))))
	(setq Info-history (cdr Info-history))
	(let ((Info-keeping-history nil))
	  (Info-goto-node (car entry)))
	(Info-restore-history-entry entry))))

(defun Info-directory ()
  "Go to the Info directory node."
  (interactive)
  (Info-find-node "dir" "top"))

(defun Info-follow-reference (footnotename)
  "Follow cross reference named NAME to the node it refers to.
NAME may be an abbreviation of the reference name."
  (interactive
   (let ((completion-ignore-case t)
	 completions default (start-point (point)) str i)
     (save-excursion
       (goto-char (point-min))
       (while (re-search-forward (format "\\*%s[ \n\t]*\\([^:]*\\):"
					 Info-footnote-tag)
				 nil t)
	 (setq str (buffer-substring
		    (match-beginning 1)
		    (1- (point))))
	 ;; See if this one should be the default.
	 (and (null default)
	      (< (match-beginning 0) start-point)
	      (<= start-point (point))
	      (setq default t))
	 (setq i 0)
	 (while (setq i (string-match "[ \n\t]+" str i))
	   (setq str (concat (substring str 0 i) " "
			     (substring str (match-end 0))))
	   (setq i (1+ i)))
	 ;; Record as a completion and perhaps as default.
	 (if (eq default t) (setq default str))
	 (setq completions
	       (cons (cons str nil)
		     completions))))
     (if completions
	 (let ((item (completing-read (if default
					  (concat "Follow reference named: ("
						  default ") ")
					"Follow reference named: ")
				      completions nil t nil
				      'Info-minibuffer-history)))
	   (if (and (string= item "") default)
	       (list default)
	     (list item)))
       (error "No cross-references in this node"))))
  (let (target i (str (concat "\\*" Info-footnote-tag " "
			      (regexp-quote footnotename))))
    (while (setq i (string-match " " str i))
      (setq str (concat (substring str 0 i) "\\([ \t\n]+\\)"
			(substring str (1+ i))))
      (setq i (+ i 10)))
    (save-excursion
      (goto-char (point-min))
      (or (re-search-forward str nil t)
	  (error "No cross-reference named %s" footnotename))
      (goto-char (match-end 1))
      (setq target
	    (Info-extract-menu-node-name "Bad format cross reference" t)))
    (while (setq i (string-match "[ \t\n]+" target i))
      (setq target (concat (substring target 0 i) " "
			   (substring target (match-end 0))))
      (setq i (+ i 1)))
    (Info-goto-node target)
    (setq Info-in-cross-reference t)))

(defun Info-next-reference (n)
  (interactive "p")
  (let ((pat (format "\\*%s[ \n\t]*\\([^:]*\\):\\|^\\* .*:\\|<<.*>>"
		     Info-footnote-tag))
	(old-pt (point))
	wrapped found-nomenu)
    (while (< n 0)
      (unless (re-search-backward pat nil t)
	;; Don't wrap more than once in a buffer where only the
	;; menu references are found.
	(when (and wrapped (not found-nomenu))
	  (goto-char old-pt)
	  (error "No cross references in this node"))
	(setq wrapped t)
	(goto-char (point-max))
	(unless (re-search-backward pat nil t)
	  (goto-char old-pt)
	  (error "No cross references in this node")))
      (unless (save-excursion
		(goto-char (match-beginning 0))
		(when (looking-at "\\* Menu:")
		  (decf n)))
	(setq found-nomenu t))
      (incf n))
    (while (> n 0)
      (or (eobp) (forward-char 1))
      (unless (re-search-forward pat nil t)
	(when (and wrapped (not found-nomenu))
	  (goto-char old-pt)
	  (error "No cross references in this node"))
	(setq wrapped t)
	(goto-char (point-min))
	(unless (re-search-forward pat nil t)
	  (goto-char old-pt)
	  (error "No cross references in this node")))
      (unless (save-excursion
		(goto-char (match-beginning 0))
		(when (looking-at "\\* Menu:")
		  (incf n)))
	(setq found-nomenu t))
      (decf n))
    (when (looking-at "\\* Menu:")
      (error "No cross references in this node"))
    (goto-char (match-beginning 0))))

(defun Info-prev-reference (n)
  (interactive "p")
  (Info-next-reference (- n)))

(defun Info-extract-menu-node-name (&optional errmessage multi-line)
  (skip-chars-forward " \t\n")
  (let ((beg (point))
	str i)
    (skip-chars-forward "^:")
    (forward-char 1)
    (setq str
	  (if (looking-at ":")
	      (buffer-substring beg (1- (point)))
	    (skip-chars-forward " \t\n")
	    (Info-following-node-name (if multi-line "^.,\t" "^.,\t\n"))))
    (while (setq i (string-match "\n" str i))
      (aset str i ?\ ))
    str))

(defun Info-menu (menu-item)
  "Go to node for menu item named (or abbreviated) NAME.
Completion is allowed, and the menu item point is on is the default."
  (interactive
   (let ((completions '())
	 ;; If point is within a menu item, use that item as the default
	 (default nil)
	 (p (point))
	 (last nil))
     (save-excursion
       (goto-char (point-min))
       (let ((case-fold-search t))
	 (if (not (search-forward "\n* menu:" nil t))
	     (error "No menu in this node")))
       (while (re-search-forward
		"\n\\* \\([^:\t\n]*\\):" nil t)
	 (if (and (null default)
		  (prog1 (if last (< last p) nil)
		    (setq last (match-beginning 0)))
		  (<= p last))
	     (setq default (car (car completions))))
	 (setq completions (cons (cons (buffer-substring
					 (match-beginning 1)
					 (match-end 1))
				       (match-beginning 1))
				 completions)))
       (if (and (null default) last
		(< last p)
		(<= p (progn (end-of-line) (point))))
	   (setq default (car (car completions)))))
     (let ((item nil))
       (while (null item)
	 (setq item (let ((completion-ignore-case t))
		      (completing-read (if default
					   (format "Menu item (default %s): "
						   default)
					   "Menu item: ")
				       completions nil t nil
				       'Info-minibuffer-history)))
	 ;; we rely on the fact that completing-read accepts an input
	 ;; of "" even when the require-match argument is true and ""
	 ;; is not a valid possibility
	 (if (string= item "")
	     (if default
		 (setq item default)
	         ;; ask again
	         (setq item nil))))
       (list item))))
  ;; there is a problem here in that if several menu items have the same
  ;; name you can only go to the node of the first with this command.
  (Info-goto-node (Info-extract-menu-item menu-item) nil t))
  
(defun Info-extract-menu-item (menu-item &optional noerror)
  (save-excursion
    (goto-char (point-min))
    (if (let ((case-fold-search t))
	  (search-forward "\n* menu:" nil t))
	(if (or (search-forward (concat "\n* " menu-item ":") nil t)
		(search-forward (concat "\n* " menu-item) nil t))
	    (progn
	      (beginning-of-line)
	      (forward-char 2)
	      (Info-extract-menu-node-name))
	  (and (not noerror) (error "No such item in menu")))
      (and (not noerror) (error "No menu in this node")))))

;; If COUNT is nil, use the last item in the menu.
(defun Info-extract-menu-counting (count &optional noerror noindex)
  (save-excursion
    (goto-char (point-min))
    (if (let ((case-fold-search t))
	  (and (search-forward "\n* menu:" nil t)
	       (or (not noindex)
		   (not (string-match "\\<Index\\>" Info-current-node)))))
	(if (search-forward "\n* " nil t count)
	    (progn
	      (or count
		  (while (search-forward "\n* " nil t)))
	      (Info-extract-menu-node-name))
	  (and (not noerror) (error "Too few items in menu")))
      (and (not noerror) (error "No menu in this node")))))

(defun Info-nth-menu-item (n)
  "Go to the node of the Nth menu item."
  (interactive "P")
  (or n (setq n (- last-command-char ?0)))
  (if (< n 1) (error "Index must be at least 1"))
  (Info-goto-node (Info-extract-menu-counting n) nil t))

(defun Info-last-menu-item ()
  "Go to the node of the tenth menu item."
  (interactive)
  (Info-goto-node (Info-extract-menu-counting nil) nil t))

(defun Info-top ()
  "Go to the Top node of this file."
  (interactive)
  (Info-goto-node "Top"))

(defun Info-end ()
  "Go to the final node in this file."
  (interactive)
  (Info-top)
  (let ((Info-keeping-history nil)
	node)
    (Info-last-menu-item)
    (while (setq node (or (Info-extract-pointer "next" t)
			  (Info-extract-menu-counting nil t t)))
      (Info-goto-node node))
    (or (equal (Info-extract-pointer "up" t) "Top")
	(let ((executing-kbd-macro ""))   ; suppress messages
	  (condition-case nil
	      (Info-global-next 10000)
	    (error nil))))))

(defun Info-global-next (&optional n)
  "Go to the next node in this file, traversing node structure as necessary.
This works only if the Info file is structured as a hierarchy of nodes.
A positive or negative prefix argument moves by multiple nodes."
  (interactive "p")
  (or n (setq n 1))
  (if (< n 0)
      (Info-global-prev (- n))
    (while (>= (setq n (1- n)) 0)
      (let (node)
	(cond ((and (string-match "^Top$" Info-current-node)
		    (setq node (Info-extract-pointer "next" t))
		    (Info-extract-menu-item node t))
	       (Info-goto-node node))
	      ((setq node (Info-extract-menu-counting 1 t t))
	       (message "Going down...")
	       (Info-goto-node node))
	      (t
	       (let ((Info-keeping-history Info-keeping-history)
		     (orignode Info-current-node)
		     (ups ""))
		 (while (not (Info-extract-pointer "next" t))
		   (if (and (setq node (Info-extract-pointer "up" t))
			    (not (equal node "Top")))
		       (progn
			 (message "Going%s..." (setq ups (concat ups " up")))
			 (Info-goto-node node)
			 (setq Info-keeping-history nil))
		     (if orignode
			 (let ((Info-keeping-history nil))
			   (Info-goto-node orignode)))
		     (error "Last node in file")))
		 (Info-next))))))))

(defun Info-page-next (&optional n)
  "Scroll forward one screenful, or go to next global node.
A positive or negative prefix argument moves by multiple screenfuls."
  (interactive "p")
  (or n (setq n 1))
  (if (< n 0)
      (Info-page-prev (- n))
    (while (>= (setq n (1- n)) 0)
      (if (pos-visible-in-window-p (point-max))
	  (progn
	    (Info-global-next)
	    (message "Node: %s" Info-current-node))
	(scroll-up)))))

(defun Info-scroll-next (arg)
  (interactive "P")
  (if Info-auto-advance
      (if (and (pos-visible-in-window-p (point-max))
	       (not (eq Info-auto-advance t))
	       (not (eq last-command this-command)))
	  (message "Hit %s again to go to next node"
		   (if (= last-command-char 0)
		       "mouse button"
		     (key-description (char-to-string last-command-char))))
	(Info-page-next)
	(setq this-command 'Info))
    (scroll-up arg)))

(defun Info-global-prev (&optional n)
  "Go to the previous node in this file, traversing structure as necessary.
This works only if the Info file is structured as a hierarchy of nodes.
A positive or negative prefix argument moves by multiple nodes."
  (interactive "p")
  (or n (setq n 1))
  (if (< n 0)
      (Info-global-next (- n))
    (while (>= (setq n (1- n)) 0)
      (let ((upnode (Info-extract-pointer "up" t))
	    (prevnode (Info-extract-pointer "prev[ious]*" t)))
	(if (or (not prevnode)
		(equal prevnode upnode))
	    (if (string-match "^Top$" Info-current-node)
		(error "First node in file")
	      (message "Going up...")
	      (Info-up))
	  (Info-goto-node prevnode)
	  (let ((downs "")
		(Info-keeping-history nil)
		node)
	    (while (setq node (Info-extract-menu-counting nil t t))
	      (message "Going%s..." (setq downs (concat downs " down")))
	      (Info-goto-node node))))))))

(defun Info-page-prev (&optional n)
  "Scroll backward one screenful, or go to previous global node.
A positive or negative prefix argument moves by multiple screenfuls."
  (interactive "p")
  (or n (setq n 1))
  (if (< n 0)
      (Info-page-next (- n))
    (while (>= (setq n (1- n)) 0)
      (if (pos-visible-in-window-p (point-min))
	  (progn
	    (Info-global-prev)
	    (message "Node: %s" Info-current-node)
	    (sit-for 0)
	    ;;(scroll-up 1)   ; work around bug in pos-visible-in-window-p
	    ;;(scroll-down 1)
	    (while (not (pos-visible-in-window-p (point-max)))
	      (scroll-up)))
	(scroll-down)))))

(defun Info-scroll-prev (arg)
  (interactive "P")
  (if Info-auto-advance
      (if (and (pos-visible-in-window-p (point-min))
	       (not (eq Info-auto-advance t))
	       (not (eq last-command this-command)))
	  (message "Hit %s again to go to previous node"
		   (if (= last-command-char 0)
		       "mouse button"
		     (key-description (char-to-string last-command-char))))
	(Info-page-prev)
	(setq this-command 'Info))
    (scroll-down arg)))

(defun Info-index (topic)
  "Look up a string in the index for this file.
The index is defined as the first node in the top-level menu whose
name contains the word \"Index\", plus any immediately following
nodes whose names also contain the word \"Index\".
If there are no exact matches to the specified topic, this chooses
the first match which is a case-insensitive substring of a topic.
Use the `,' command to see the other matches.
Give a blank topic name to go to the Index node itself."
  (interactive "sIndex topic: ")
  (let ((pattern (format "\n\\* \\([^\n:]*%s[^\n:]*\\):[ \t]*%s"
			 (regexp-quote topic)
			 "\\([^.\n]*\\)\\.[ t]*\\([0-9]*\\)"))
	node)
    (message "Searching index for `%s'..." topic)
    (Info-goto-node "Top")
    (let ((case-fold-search t))
      (or (search-forward "\n* menu:" nil t)
	  (error "No index"))
      (or (re-search-forward "\n\\* \\(.*\\<Index\\>\\)" nil t)
	  (error "No index")))
    (goto-char (match-beginning 1))
    (let ((Info-keeping-history nil)
	  (Info-fontify (and Info-fontify (equal topic ""))))
      (Info-goto-node (Info-extract-menu-node-name)))
    (or (equal topic "")
	(let ((matches nil)
	      (exact nil)
	      (Info-keeping-history nil)
	      found)
	  (while
	      (progn
		(goto-char (point-min))
		(while (re-search-forward pattern nil t)
		  (setq matches
			(cons (list (buffer-substring (match-beginning 1)
						      (match-end 1))
				    (buffer-substring (match-beginning 2)
						      (match-end 2))
				    Info-current-node
				    (string-to-int (concat "0"
							   (buffer-substring
							    (match-beginning 3)
							    (match-end 3)))))
			      matches)))
		(and (setq node (Info-extract-pointer "next" t))
		     (string-match "\\<Index\\>" node)))
	    (let ((Info-fontify nil))
	      (Info-goto-node node)))
	  (or matches
	      (progn
		(Info-last)
		(error "No \"%s\" in index" topic)))
	  ;; Here it is a feature that assoc is case-sensitive.
	  (while (setq found (assoc topic matches))
	    (setq exact (cons found exact)
		  matches (delq found matches)))
	  (setq Info-index-alternatives (nconc exact (nreverse matches))
		Info-index-first-alternative (car Info-index-alternatives))
	  (Info-index-next 0)))))

(defun Info-index-next (num)
  "Go to the next matching index item from the last `i' command."
  (interactive "p")
  (or Info-index-alternatives
      (error "No previous `i' command in this file"))
  (while (< num 0)
    (setq num (+ num (length Info-index-alternatives))))
  (while (> num 0)
    (setq Info-index-alternatives
	  (nconc (cdr Info-index-alternatives)
		 (list (car Info-index-alternatives)))
	  num (1- num)))
  (Info-goto-node (nth 1 (car Info-index-alternatives)))
  (if (> (nth 3 (car Info-index-alternatives)) 0)
      (forward-line (nth 3 (car Info-index-alternatives)))
    (forward-line 3)  ; don't search in headers
    (let ((name (car (car Info-index-alternatives))))
      (if (or (re-search-forward (format
				  "\\(Function\\|Command\\): %s\\( \\|$\\)"
				  (regexp-quote name)) nil t)
	      (re-search-forward (format "^`%s[ ']" (regexp-quote name)) nil t)
	      (search-forward (format "`%s'" name) nil t)
	      (and (string-match "\\`.*\\( (.*)\\)\\'" name)
		   (search-forward
		    (format "`%s'" (substring name 0 (match-beginning 1)))
		    nil t))
	      (search-forward name nil t))
	  (beginning-of-line)
	(goto-char (point-min)))))
  (message "Found \"%s\" in %s.  %s"
	   (car (car Info-index-alternatives))
	   (nth 2 (car Info-index-alternatives))
	   (if (cdr Info-index-alternatives)
	       (if (eq (car (cdr Info-index-alternatives))
		       Info-index-first-alternative)
		   "(Press `,' to repeat)"
		 (format "(Press `,' for %d more)"
			 (- (1- (length Info-index-alternatives))
			    (length (memq Info-index-first-alternative
					  (cdr Info-index-alternatives))))))
	     "(Only match)")))


;;;###autoload
(defun Info-emacs-command (command)
  "Look up an Emacs command in the Emacs manual in the Info system.
This command is designed to be used whether you are already in Info or not."
  (interactive "CLook up command in Emacs manual: ")
  (save-window-excursion
    (info)
    (Info-find-node Info-emacs-info-file-name "Top")
    (Info-index (symbol-name command)))
  (pop-to-buffer "*info*"))


;;;###autoload
(defun Info-goto-emacs-command-node (key)
  "Look up an Emacs command in the Emacs manual in the Info system.
This command is designed to be used whether you are already in Info or not."
  (interactive "CLook up command in Emacs manual: ")
  (Info-emacs-command key))

;;;###autoload
(defun Info-goto-emacs-key-command-node (key)
  "Look up an Emacs key sequence in the Emacs manual in the Info system.
This command is designed to be used whether you are already in Info or not."
  (interactive "kLook up key in Emacs manual: ")
  (let ((command (key-binding key)))
    (cond ((eq command 'keyboard-quit)
	   (keyboard-quit))
	  ((null command)
	   (error "%s is undefined" (key-description key)))
	  ((and (interactive-p) (eq command 'execute-extended-command))
	   (call-interactively 'Info-goto-emacs-command-node))
	  (t
	   (Info-goto-emacs-command-node command)))))

;;;###autoload
(defun Info-emacs-key (key)
  "Look up an Emacs key sequence in the Emacs manual in the Info system.
This command is designed to be used whether you are already in Info or not."
  (interactive "kLook up key in Emacs manual: ")
  (cond ((eq (key-binding key) 'keyboard-quit)
	 (keyboard-quit))
	((and (interactive-p) (eq (key-binding key) 'execute-extended-command))
	 (call-interactively 'Info-goto-emacs-command-node))
	(t
	 (save-window-excursion
	   (info)
	   (Info-find-node Info-emacs-info-file-name "Top")
	   (setq key (key-description key))
	   (let (p)
	     (if (setq p (string-match "[@{}]" key))
		 (setq key (concat (substring key 0 p) "@" (substring key p))))
	     (if (string-match "^ESC " key)
		 (setq key (concat "M-" (substring key 4))))
	     (if (string-match "^M-C-" key)
		 (setq key (concat "C-M-" (substring key 4)))))
	   (Info-index key))
	 (pop-to-buffer "*info*"))))

;;;###autoload
(defun Info-elisp-ref (func)
  "Look up an Emacs Lisp function in the Elisp manual in the Info system.
This command is designed to be used whether you are already in Info or not."
  (interactive (let ((fn (function-at-point))
		     (enable-recursive-minibuffers t)	     
		     val)
		 (setq val (completing-read
			    (format "Look up Emacs Lisp function%s: "
				    (if fn
					(format " (default %s)" fn)
				      ""))
			    obarray 'fboundp t))
		 (list (if (equal val "")
			   fn (intern val)))))
  (save-window-excursion
    (info)
    (condition-case nil
	(Info-find-node "lispref" "Top")
      (error (Info-find-node "elisp" "Top")))
    (Info-index (symbol-name func)))
  (pop-to-buffer "*info*"))

(defun Info-reannotate-node ()
  (let ((bufs (delq nil (mapcar 'get-file-buffer Info-annotations-path))))
    (if bufs
	(let ((ibuf (current-buffer))
	      (file (concat "\\(" (regexp-quote
			     (file-name-nondirectory Info-current-file))
			    "\\|" (regexp-quote Info-current-file) "\\)"))
	      (node (regexp-quote Info-current-node))
	      (savept (point)))
	  (goto-char (point-min))
	  (if (search-forward "\n------ NOTE:\n" nil t)
	      (let ((buffer-read-only nil)
		    (bufmod (buffer-modified-p))
		    top)
		(setq savept (copy-marker savept))
		(goto-char (point-min))
		(while (search-forward "\n------ NOTE:" nil t)
		  (setq top (1+ (match-beginning 0)))
		  (if (search-forward "\n------\n" nil t)
		      (delete-region top (point)))
		  (backward-char 1))
		(set-buffer-modified-p bufmod)))
	  (save-excursion
	    (while bufs
	      (set-buffer (car bufs))
	      (goto-char (point-min))
	      (while (re-search-forward
		      (format
		       "------ *File: *%s *Node: *%s *Line: *\\([0-9]+\\) *\n"
		       file node)
		      nil t)
		(let ((line (string-to-int
			     (buffer-substring (match-beginning 2)
					       (match-end 2))))
		      (top (point))
		      bot)
		  (search-forward "\n------\n" nil t)
		  (setq bot (point))
		  (save-excursion
		    (set-buffer ibuf)
		    (if (integerp savept) (setq savept (copy-marker savept)))
		    (if (= line 0)
			(goto-char (point-max))
		      (goto-char (point-min))
		      (forward-line line))
		    (let ((buffer-read-only nil)
			  (bufmod (buffer-modified-p)))
		      (insert "------ NOTE:\n")
		      (insert-buffer-substring (car bufs) top bot)
		      (set-buffer-modified-p bufmod)))))
	      (setq bufs (cdr bufs))))
	  (goto-char savept)))))

(defvar Info-annotate-map nil
  "Local keymap used within `a' command of Info.")
(if Info-annotate-map
    nil
  ;; (setq Info-annotate-map (nconc (make-sparse-keymap) text-mode-map))
  (setq Info-annotate-map (copy-keymap text-mode-map))
  (define-key Info-annotate-map "\C-c\C-c" 'Info-cease-annotate))

(defun Info-annotate-mode ()
  "Major mode for adding an annotation to an Info node.
Like text mode with the addition of Info-cease-annotate
which returns to Info mode for browsing.
\\{Info-annotate-map}")

(defun Info-annotate (arg)
  "Add a personal annotation to the current Info node.
 Only you will be able to see this annotation.  Annotations are stored
in the file \"~/.xemacs/info.notes\" by default.  If point is inside
an existing annotation, edit that annotation.  A prefix argument
specifies which annotations file (from `Info-annotations-path') is to
be edited; default is 1."
  (interactive "p")
  (setq arg (1- arg))
  (if (or (< arg 0) (not (nth arg Info-annotations-path)))
      (if (= arg 0)
	  (setq Info-annotations-path
		(list (read-file-name
		       "Annotations file: " "~/" "~/.infonotes")))
	(error "File number must be in the range from 1 to %d"
	       (length Info-annotations-path))))
  (let ((which nil)
	(file (file-name-nondirectory Info-current-file))
	(d Info-directory-list)
	where pt)
    (while (and d (not (equal (expand-file-name file (car d))
			      Info-current-file)))
      (setq d (cdr d)))
    (or d (setq file Info-current-file))
    (if (and (save-excursion
	       (goto-char (min (point-max) (+ (point) 13)))
	       (and (search-backward "------ NOTE:\n" nil t)
		    (setq pt (match-end 0))
		    (search-forward "\n------\n" nil t)))
	     (< (point) (match-end 0)))
	(setq which (format "File: *%s *Node: *%s *Line:.*\n%s"
			    (regexp-quote file)
			    (regexp-quote Info-current-node)
			    (regexp-quote
			     (buffer-substring pt (match-beginning 0))))
	      where (max (- (point) pt) 0)))
    (let ((node Info-current-node)
	  (line (if (looking-at "[ \n]*\\'") 0
		  (count-lines (point-min) (point)))))
      (or which
	  (let ((buffer-read-only nil)
		(bufmod (buffer-modified-p)))
	    (beginning-of-line)
	    (if (bobp) (goto-char (point-max)))
	    (insert "------ NOTE:\n------\n")
	    (backward-char 20)
	    (set-buffer-modified-p bufmod)))
      ;; (setq Info-window-start (window-start))
      (setq Info-window-configuration (current-window-configuration))
      (pop-to-buffer (find-file-noselect (nth arg Info-annotations-path)))
      (use-local-map Info-annotate-map)
      (setq major-mode 'Info-annotate-mode)
      (setq mode-name "Info Annotate")
      (if which
	  (if (save-excursion
		(goto-char (point-min))
		(re-search-forward which nil t))
	      (progn
		(goto-char (match-beginning 0))
		(forward-line 1)
		(forward-char where)))
	(let ((bufmod (buffer-modified-p)))
	  (goto-char (point-max))
	  (insert (format "\n------ File: %s  Node: %s  Line: %d\n"
			  file node line))
	  (setq pt (point))
	  (insert "\n------\n"
		  "\nPress C-c C-c to save and return to Info.\n")
	  (goto-char pt)
	  (set-buffer-modified-p bufmod))))))

(defun Info-cease-annotate ()
  (interactive)
  (let ((bufmod (buffer-modified-p)))
    (while (save-excursion
	     (goto-char (point-min))
	     (re-search-forward "\n\n?Press .* to save and return to Info.\n"
				nil t))
      (delete-region (1+ (match-beginning 0)) (match-end 0)))
    (while (save-excursion
	     (goto-char (point-min))
	     (re-search-forward "\n------ File:.*Node:.*Line:.*\n+------\n"
				nil t))
      (delete-region (match-beginning 0) (match-end 0)))
    (set-buffer-modified-p bufmod))
  (save-buffer)
  (fundamental-mode)
  (bury-buffer)
  (or (one-window-p) (delete-window))
  (info)
  (setq Info-current-annotation-completions nil)
  (set-window-configuration Info-window-configuration)
  (Info-reannotate-node))

(defun Info-bookmark (arg tag)
  (interactive "p\nsBookmark name: ")
  (Info-annotate arg)
  (if (or (string-match "^\"\\(.*\\)\"$" tag)
	  (string-match "^<<\\(.*\\)>>$" tag))
      (setq tag (substring tag (match-beginning 1) (match-end 1))))
  (let ((pt (point)))
    (search-forward "\n------\n")
    (let ((end (- (point) 8)))
      (goto-char pt)
      (if (re-search-forward "<<[^>\n]*>>" nil t)
	  (delete-region (match-beginning 0) (match-end 0))
	(goto-char end))
      (or (equal tag "")
	  (insert "<<" tag ">>"))))
  (Info-cease-annotate))

(defun Info-exit ()
  "Exit Info by selecting some other buffer."
  (interactive)
  (if Info-standalone
      (save-buffers-kill-emacs)
    (bury-buffer (current-buffer))
    (if (and (featurep 'toolbar)
	     (eq toolbar-info-frame (selected-frame)))
	(condition-case ()
	    (delete-frame toolbar-info-frame)
	  (error (bury-buffer)))
      (switch-to-buffer (other-buffer (current-buffer))))))

(defun Info-undefined ()
  "Make command be undefined in Info."
  (interactive)
  (ding))

(defun Info-help ()
  "Enter the Info tutorial."
  (interactive)
  (delete-other-windows)
  (Info-find-node "info"
		  (if (< (window-height) 23)
		      "Help-Small-Screen"
		    "Help")))

(defun Info-summary ()
  "Display a brief summary of all Info commands."
  (interactive)
  (save-window-excursion
    (switch-to-buffer "*Help*")
    (erase-buffer)
    (insert (documentation 'Info-mode))
    (goto-char (point-min))
    (let (flag)
      (while (progn (setq flag (not (pos-visible-in-window-p (point-max))))
		    (message (if flag "Type Space to see more"
			       "Type Space to return to Info"))
		    (let ((e (next-command-event)))
		      (if (/= ?\  (event-to-character e))
			  (progn (setq unread-command-event e) nil)
			flag)))
	(scroll-up)))
    (message "")
    (bury-buffer "*Help*")))

(defun Info-get-token (pos start all &optional errorstring)
  "Return the token around POS,
POS must be somewhere inside the token
START is a regular expression which will match the
    beginning of the tokens delimited string
ALL is a regular expression with a single
    parenthized subpattern which is the token to be
    returned. E.g. '{\(.*\)}' would return any string
    enclosed in braces around POS.
SIG optional fourth argument, controls action on no match
    nil: return nil
    t: beep
    a string: signal an error, using that string."
  (save-excursion
    (goto-char (point-min))
    (re-search-backward "\\`")  ; Bug fix due to Nicholas J. Foskett.
    (goto-char pos)
    (re-search-backward start (max (point-min) (- pos 200)) 'yes)
    (let (found)
      (while (and (re-search-forward all (min (point-max) (+ pos 200)) 'yes)
		  (not (setq found (and (<= (match-beginning 0) pos)
					(> (match-end 0) pos))))))
      (if (and found (<= (match-beginning 0) pos)
	       (> (match-end 0) pos))
	  (buffer-substring (match-beginning 1) (match-end 1))
	(cond ((null errorstring)
	       nil)
	      ((eq errorstring t)
	       (beep)
	       nil)
	      (t
	       (error "No %s around position %d" errorstring pos)))))))

(defun Info-follow-clicked-node (event)
  "Follow a node reference near clicked point.  Like M, F, N, P or U command.
At end of the node's text, moves to the next node."
  (interactive "@e")
  (or (and (event-point event)
	   (Info-follow-nearest-node
	    (max (progn
		   (select-window (event-window event))
		   (event-point event))
		 (1+ (point-min)))))
      (error "click on a cross-reference to follow")))

(defun Info-maybe-follow-clicked-node (event &optional click-count)
  "Follow a node reference (if any) near clicked point.
Like M, F, N, P or U command.  At end of the node's text, moves to the
next node.  No error is given if there is no node to follow."
  (interactive "@e")
  (and Info-button1-follows-hyperlink
       (event-point event)
       (Info-follow-nearest-node
	(max (progn
	       (select-window (event-window event))
	       (event-point event))
	     (1+ (point-min))))))

(defun Info-find-nearest-node (point)
  (let (node)
    (cond
     ((= point (point-min)) nil)   ; don't trigger on accidental RET.
     ((setq node (Info-get-token point
				 (format "\\*%s[ \n]" Info-footnote-tag)
				 (format "\\*%s[ \n]\\([^:]*\\):"
					 Info-footnote-tag)))
      (list "Following cross-reference %s..."
	    (list 'Info-follow-reference node)))
     ((setq node (Info-get-token point "\\* " "\\* \\([^:]*\\)::"))
      (list "Selecting menu item %s..."
	    (list 'Info-goto-node node nil t)))
     ((setq node (Info-get-token point "\\* " "\\* \\([^:]*\\):"))
      (list "Selecting menu item %s..."
	    (list 'Info-menu node)))
     ((setq node (Info-get-token point "Up: " "Up: \\([^,\n\t]*\\)"))
      (list "Going up..."
	    (list 'Info-goto-node node)))
     ((setq node (Info-get-token point "Next: " "Next: \\([^,\n\t]*\\)"))
      (list "Next node..."
	    (list 'Info-goto-node node)))
     ((setq node (Info-get-token point "File: " "File: \\([^,\n\t]*\\)"))
      (list "Top node..."
	    (list 'Info-goto-node "Top")))
     ((setq node (Info-get-token point "Prev[ious]*: "
				 "Prev[ious]*: \\([^,\n\t]*\\)"))
      (list "Previous node..."
	    (list 'Info-goto-node node)))
     ((setq node (Info-get-token point "Node: " "Node: \\([^,\n\t]*\\)"))
      (list "Reselecting %s..."
	    (list 'Info-goto-node node)))
     ((save-excursion (goto-char point) (looking-at "[ \n]*\\'"))
      (if Info-in-cross-reference
	  (list "Back to last node..."
		'(Info-last))
	(list "Next node..."
	      '(Info-global-next)))))
    ))

(defun Info-follow-nearest-node (point)
  "Follow a node reference near point.  Like M, F, N, P or U command.
At end of the node's text, moves to the next node."
  (interactive "d")
  (let ((data (Info-find-nearest-node point)))
    (if (null data)
	nil
      (let ((msg (format (car data) (nth 1 (nth 1 data)))))
	(message "%s" msg)
	(eval (nth 1 data))
	(message "%sdone" msg))
      t)))

(defun Info-indicated-node (event)
  (condition-case ()
      (save-excursion
	(cond ((eventp event)
	       (set-buffer (event-buffer event))
	       (setq event (event-point event))))
	(let* ((data (Info-find-nearest-node event))
	       (name (nth 1 (nth 1 data))))
	  (and name (nth 1 data))))
    (error nil)))

(defun Info-mouse-track-double-click-hook (event click-count)
  "Handle double-clicks by turning pages, like the `gv' ghostscript viewer"
  (if (/= click-count 2)
      ;; Return nil so any other hooks are performed.
      nil
      (let* ((x (event-x-pixel event))
	     (y (event-y-pixel event))
	     (w (window-pixel-width (event-window event)))
	     (h (window-pixel-height (event-window event)))
	     (w/3 (/ w 3))
	     (w/2 (/ w 2))
	     (h/4 (/ h 4)))
	(cond
	  ;; In the top 1/4 and inside the middle 1/3
	  ((and (<= y h/4)
		(and (>= x w/3) (<= x (+ w/3 w/3))))
	   (Info-up)
	   t)
	  ;; In the bottom 1/4 and inside the middle 1/3
	  ((and (>= y (+ h/4 h/4 h/4))
		(and (>= x w/3) (<= x (+ w/3 w/3))))
	   (Info-nth-menu-item 1)
	   t)
	  ;; In the lower 3/4 and the right 1/2
	  ;; OR in the upper 1/4 and the right 1/3
	  ((or (and (>= y h/4) (>= x w/2))
	       (and (< y h/4) (>= x (+ w/3 w/3))))
	   (Info-next)
	   t)
	  ;; In the lower 3/4 and the left 1/2
	  ;; OR in the upper 1/4 and the left 1/3
	  ((or (and (>= y h/4) (< x w/2))
	       (and (< y h/4) (<= x w/3)))
	   (Info-prev)
	   t)
	  ;; This shouldn't happen.
	  (t
	   (error "event out of bounds: %s %s" x y))))))

(defvar Info-mode-map nil
  "Keymap containing Info commands.")
(if Info-mode-map
    nil
  (setq Info-mode-map (make-sparse-keymap))
  (suppress-keymap Info-mode-map)
  (define-key Info-mode-map "." 'beginning-of-buffer)
  (define-key Info-mode-map " " 'Info-scroll-next)
  (define-key Info-mode-map "1" 'Info-nth-menu-item)
  (define-key Info-mode-map "2" 'Info-nth-menu-item)
  (define-key Info-mode-map "3" 'Info-nth-menu-item)
  (define-key Info-mode-map "4" 'Info-nth-menu-item)
  (define-key Info-mode-map "5" 'Info-nth-menu-item)
  (define-key Info-mode-map "6" 'Info-nth-menu-item)
  (define-key Info-mode-map "7" 'Info-nth-menu-item)
  (define-key Info-mode-map "8" 'Info-nth-menu-item)
  (define-key Info-mode-map "9" 'Info-nth-menu-item)
  (define-key Info-mode-map "0" 'Info-last-menu-item)
  (define-key Info-mode-map "?" 'Info-summary)
  (define-key Info-mode-map "a" 'Info-annotate)
  (define-key Info-mode-map "b" 'beginning-of-buffer)
  (define-key Info-mode-map "d" 'Info-directory)
  (define-key Info-mode-map "e" 'Info-edit)
  (define-key Info-mode-map "f" 'Info-follow-reference)
  (define-key Info-mode-map "g" 'Info-goto-node)
  (define-key Info-mode-map "h" 'Info-help)
  (define-key Info-mode-map "i" 'Info-index)
  (define-key Info-mode-map "j" 'Info-goto-bookmark)
  (define-key Info-mode-map "k" 'Info-emacs-key)
  (define-key Info-mode-map "l" 'Info-last)
  (define-key Info-mode-map "m" 'Info-menu)
  (define-key Info-mode-map "n" 'Info-next)
  (define-key Info-mode-map "p" 'Info-prev)
  (define-key Info-mode-map "q" 'Info-exit)
  (define-key Info-mode-map "r" 'Info-follow-reference)
  (define-key Info-mode-map "s" 'Info-search)
  (define-key Info-mode-map "t" 'Info-top)
  (define-key Info-mode-map "u" 'Info-up)
  (define-key Info-mode-map "v" 'Info-visit-file)
  (define-key Info-mode-map "x" 'Info-bookmark)
  (define-key Info-mode-map "<" 'Info-top)
  (define-key Info-mode-map ">" 'Info-end)
  (define-key Info-mode-map "[" 'Info-global-prev)
  (define-key Info-mode-map "]" 'Info-global-next)
  (define-key Info-mode-map "{" 'Info-page-prev)
  (define-key Info-mode-map "}" 'Info-page-next)
  (define-key Info-mode-map "=" 'Info-restore-point)
  (define-key Info-mode-map "!" 'Info-select-node)
  (define-key Info-mode-map "@" 'Info-follow-nearest-node)
  (define-key Info-mode-map "," 'Info-index-next)
  (define-key Info-mode-map "*" 'Info-elisp-ref)
  (define-key Info-mode-map [tab] 'Info-next-reference)
  (define-key Info-mode-map [(meta tab)] 'Info-prev-reference)
  (define-key Info-mode-map [(shift tab)] 'Info-prev-reference)
  (define-key Info-mode-map "\r" 'Info-follow-nearest-node)
  ;; XEmacs addition
  (define-key Info-mode-map 'backspace 'Info-scroll-prev)
  (define-key Info-mode-map 'delete 'Info-scroll-prev)
  (define-key Info-mode-map 'button2 'Info-follow-clicked-node)
  (define-key Info-mode-map 'button3 'Info-select-node-menu))


;; Info mode is suitable only for specially formatted data.
(put 'info-mode 'mode-class 'special)

(defun Info-mode ()
  "Info mode is for browsing through the Info documentation tree.
Documentation in Info is divided into \"nodes\", each of which
discusses one topic and contains references to other nodes
which discuss related topics.  Info has commands to follow
the references and show you other nodes.

h	Invoke the Info tutorial.
q	Quit Info: return to the previously selected file or buffer.

Selecting other nodes:
n	Move to the \"next\" node of this node.
p	Move to the \"previous\" node of this node.
m	Pick menu item specified by name (or abbreviation).
1-9, 0	Pick first..ninth, last item in node's menu.
	Menu items select nodes that are \"subsections\" of this node.
u	Move \"up\" from this node (i.e., from a subsection to a section).
f or r	Follow a cross reference by name (or abbrev).  Type `l' to get back.
RET     Follow cross reference or menu item indicated by cursor.
i	Look up a topic in this file's Index and move to that node.
,	(comma) Move to the next match from a previous `i' command.
l	(letter L) Move back to the last node you were in.

Moving within a node:
Space	Scroll forward a full screen.   DEL       Scroll backward.
b	Go to beginning of node.        Meta->    Go to end of node.
TAB	Go to next cross-reference.     Meta-TAB  Go to previous ref.

Mouse commands:
Left Button	Set point.
Middle Button	Click on a highlighted node reference to go to it.
Right Button	Pop up a menu of applicable Info commands.

Advanced commands:
g	Move to node, file, or annotation tag specified by name.
	Examples:  `g Rectangles' `g (Emacs)Rectangles' `g Emacs'.
v	Move to file, with filename completion.
k	Look up a key sequence in Emacs manual (also C-h C-k at any time).
*	Look up a function name in Emacs Lisp manual (also C-h C-f).
d	Go to the main directory of Info files.
< or t	Go to Top (first) node of this file.
>	Go to last node in this file.
\[	Go to previous node, treating file as one linear document.
\]	Go to next node, treating file as one linear document.
{	Scroll backward, or go to previous node if at top.
}	Scroll forward, or go to next node if at bottom.
=	Restore cursor position from last time in this node.
a	Add a private note (annotation) to the current node.
x, j	Add, jump to a bookmark (annotation tag).
s	Search this Info file for a node containing the specified regexp.
e	Edit the contents of the current node."
  (kill-all-local-variables)
  (setq major-mode 'Info-mode)
  (setq mode-name "Info")
  (use-local-map Info-mode-map)
  (set-syntax-table text-mode-syntax-table)
  (setq local-abbrev-table text-mode-abbrev-table)
  (setq case-fold-search t)
  (setq buffer-read-only t)
;  (setq buffer-mouse-map Info-mode-mouse-map)
  (make-local-variable 'Info-current-file)
  (make-local-variable 'Info-current-subfile)
  (make-local-variable 'Info-current-node)
  (make-local-variable 'Info-tag-table-marker)
  (make-local-variable 'Info-current-file-completions)
  (make-local-variable 'Info-current-annotation-completions)
  (make-local-variable 'Info-index-alternatives)
  (make-local-variable 'Info-history)
  ;; Faces are now defined by `defface'...
  (make-local-variable 'mouse-track-click-hook)
  (add-hook 'mouse-track-click-hook 'Info-maybe-follow-clicked-node)
  (add-hook 'mouse-track-click-hook 'Info-mouse-track-double-click-hook)
  ;; #### The console-on-window-system-p check is to allow this to
  ;; work on tty's.  The real problem here is that featurep really
  ;; needs to have some device/console domain knowledge added to it.
  (if (and (featurep 'toolbar)
	   (console-on-window-system-p)
	   (not Info-inhibit-toolbar))
      (set-specifier default-toolbar (cons (current-buffer) info::toolbar)))
  (if (featurep 'menubar)
      (progn
	;; make a local copy of the menubar, so our modes don't
	;; change the global menubar
	(set-buffer-menubar current-menubar)
	(add-submenu nil '("Info"
			   :filter Info-menu-filter))))
  (run-hooks 'Info-mode-hook)
  (Info-set-mode-line))

(defvar Info-edit-map nil
  "Local keymap used within `e' command of Info.")
(if Info-edit-map
    nil
  ;; XEmacs: remove FSF stuff
  (setq Info-edit-map (make-sparse-keymap))
  (set-keymap-name Info-edit-map 'Info-edit-map)
  (set-keymap-parents Info-edit-map (list text-mode-map))
  (define-key Info-edit-map "\C-c\C-c" 'Info-cease-edit))

;; Info-edit mode is suitable only for specially formatted data.
(put 'info-edit-mode 'mode-class 'special)

(defun Info-edit-mode ()
  "Major mode for editing the contents of an Info node.
Like text mode with the addition of `Info-cease-edit'
which returns to Info mode for browsing.
\\{Info-edit-map}"
  )

(defun Info-edit ()
  "Edit the contents of this Info node.
Allowed only if variable `Info-enable-edit' is non-nil."
  (interactive)
  (or Info-enable-edit
      (error "Editing info nodes is not enabled"))
  (use-local-map Info-edit-map)
  (setq major-mode 'Info-edit-mode)
  (setq mode-name "Info Edit")
  (kill-local-variable 'modeline-buffer-identification)
  (setq buffer-read-only nil)
  ;; Make mode line update.
  (set-buffer-modified-p (buffer-modified-p))
  (message (substitute-command-keys
	     "Editing: Type \\[Info-cease-edit] to return to info")))

(defun Info-cease-edit ()
  "Finish editing Info node; switch back to Info proper."
  (interactive)
  ;; Do this first, so nothing has changed if user C-g's at query.
  (and (buffer-modified-p)
       (y-or-n-p-maybe-dialog-box "Save the file? ")
       (save-buffer))
  (use-local-map Info-mode-map)
  (setq major-mode 'Info-mode)
  (setq mode-name "Info")
  (Info-set-mode-line)
  (setq buffer-read-only t)
  ;; Make mode line update.
  (set-buffer-modified-p (buffer-modified-p))
  (and (marker-position Info-tag-table-marker)
       (buffer-modified-p)
       (message "Tags may have changed.  Use Info-tagify if necessary")))

(defun Info-find-emacs-command-nodes (command)
  "Return a list of locations documenting COMMAND in the XEmacs Info manual.
The locations are of the format used in Info-history, i.e.
\(FILENAME NODENAME BUFFERPOS\)."
  (let ((where '())
	(cmd-desc (concat "^\\* " (regexp-quote (symbol-name command))
			  ":\\s *\\(.*\\)\\.$")))
    (save-excursion
      (Info-find-node "XEmacs" "Command Index")
      ;; Take the index node off the Info history.
      ;; ??? says this isn't safe someplace else... hmmm.
      (setq Info-history (cdr Info-history))
      (goto-char (point-max))
      (while (re-search-backward cmd-desc nil t)
	  (setq where (cons (list Info-current-file
				  (buffer-substring
				   (match-beginning 1)
				   (match-end 1))
				  0)
			    where)))
      where)))

;;; fontification and mousability for info

(defun Info-highlight-region (start end face)
  (let ((extent nil)
	(splitp (string-match "\n[ \t]+" (buffer-substring start end))))
    (if splitp
	(save-excursion
	  (setq extent (make-extent start (progn (goto-char start)
						 (end-of-line)
						 (point))))
	  (set-extent-face extent face)
	  (set-extent-property extent 'info t)
	  (set-extent-property extent 'highlight t)
	  (skip-chars-forward "\n\t ")
	  (setq extent (make-extent (point) end)))
      (setq extent (make-extent start end)))
    (set-extent-face extent face)
    (set-extent-property extent 'info t)
    (set-extent-property extent 'highlight t)))

(defun Info-fontify-node ()
  (save-excursion
    (let ((case-fold-search t)
	  (xref-regexp (concat "\\*"
			       (regexp-quote Info-footnote-tag)
			       "[ \n\t]*\\([^:]*\\):")))
      ;; Clear the old extents
      (map-extents #'(lambda (x y) (delete-extent x))
		   (current-buffer) (point-min) (point-max) nil)
      ;; Break the top line iff it is > 79 characters.  Some info nodes
      ;; have top lines that span 3 lines because of long node titles.
      ;; eg: (Info-find-node "lispref.info" "Window-Level Event Position Info")
      (toggle-read-only -1)
      (let ((extent nil)
	    (len 0)
	    (done nil)
	    (p (point-min)))
	(goto-char (point-min))
	(re-search-forward "Node: *[^,]+,  " nil t)
	(setq len (- (point) (point-min))
	      extent (make-extent (point-min) (point)))
	(set-extent-property extent 'invisible t)
	(while (not done)
	  (goto-char p)
	  (end-of-line)
	  (if (< (current-column) (+ 78 len))
	      (setq done t)
	    (goto-char p)
	    (forward-char (+ 79 len))
	    (re-search-backward "," nil t)
	    (forward-char 1)
	    (insert "\n")
	    (just-one-space)
	    (backward-delete-char 1)
	    (setq p (point)
		  len 0))))
      (toggle-read-only 1)
      ;; Highlight xrefs in the top few lines of the node
      (goto-char (point-min))
      (if (looking-at "^File: [^,: \t]+,?[ \t]+")
	  (progn
	    (goto-char (match-end 0))
	    (while
		(looking-at "[ \t]*[^:, \t\n]+:[ \t]+\\([^:,\t\n]+\\),?\n?")
	      (goto-char (match-end 0))
	      (Info-highlight-region (match-beginning 1) (match-end 1) 'info-xref))))
      ;; Now get the xrefs in the body
      (goto-char (point-min))
      (while (re-search-forward xref-regexp nil t)
	(if (= (char-after (1- (match-beginning 0))) ?\") ; hack
	    nil
	  (Info-highlight-region (match-beginning 1) (match-end 1) 'info-xref)))
      ;; then highlight the nodes in the menu.
      (goto-char (point-min))
      (if (and (search-forward "\n* menu:" nil t))
	  (while (re-search-forward
		  "^\\* \\([^:\t\n]*\\):?:[ \t\n]" nil t)
	    (Info-highlight-region (match-beginning 1) (match-end 1) 'info-node)))
      (set-buffer-modified-p nil))))

(defun Info-construct-menu (&optional event)
  "Construct a menu of Info commands.
Adds an entry for the node at EVENT, or under point if EVENT is omitted.
Used to construct the menubar submenu and popup menu."
  (or event (setq event (point)))
  (let ((case-fold-search t)
	(xref-regexp (concat "\\*" 
			     (regexp-quote Info-footnote-tag)
			     "[ \n\t]*\\([^:]*\\):"))
	up-p prev-p next-p menu xrefs subnodes in)
    (save-excursion
      ;; `one-space' fixes "Notes:" xrefs that are split across lines.
      (flet
	  ((one-space (text)
		      (let (i)
			(while (setq i (string-match "[ \n\t]+" text i))
			  (setq text (concat (substring text 0 i) " "
					     (substring text (match-end 0))))
			  (setq i (1+ i)))
			text)))
	(goto-char (point-min))
	(if (looking-at ".*\\bNext:") (setq next-p t))
	(if (looking-at ".*\\bPrev:") (setq prev-p t))
	(if (looking-at ".*Up:") (setq up-p t))
	(setq menu (nconc
		    (if (setq in (Info-indicated-node event))
			(list (vector (one-space (cadr in)) in t)
			      "--:shadowEtchedIn"))
		    (list
		     ["Goto Info Top-level" Info-directory]
		     (vector "Next Node" 'Info-next :active next-p)
		     (vector "Previous Node" 'Info-prev :active prev-p)
		     (vector "Parent Node (Up)" 'Info-up :active up-p)
		     ["Goto Node..." Info-goto-node]
		     ["Goto Last Visited Node " Info-last])))
	;; Find the xrefs and make a list
	(while (re-search-forward xref-regexp nil t)
	  (setq xrefs (cons (one-space (buffer-substring (match-beginning 1)
							 (match-end 1)))
			    xrefs))))
      (setq xrefs (nreverse xrefs))
      (if (> (length xrefs) 21) (setcdr (nthcdr 20 xrefs) '(more)))
      ;; Find the subnodes and make a list
      (goto-char (point-min))
      (if (search-forward "\n* menu:" nil t)
      (while (re-search-forward "^\\* \\([^:\t\n]*\\):" nil t)
	(setq subnodes (cons (buffer-substring (match-beginning 1)
					       (match-end 1))
			     subnodes))))
      (setq subnodes (nreverse subnodes))
      (if (> (length subnodes) 21) (setcdr (nthcdr 20 subnodes) '(more))))
    (if xrefs
	(nconc menu (list "--:shadowDoubleEtchedIn"
			  "    Cross-References"
			  "--:singleLine")
	       (mapcar #'(lambda (xref)
			   (if (eq xref 'more)
			       "...more..."
			     (vector xref
				     (list 'Info-follow-reference xref))))
		       xrefs)))
    (if subnodes
	(nconc menu (list "--:shadowDoubleEtchedIn"
			  "      Sub-Nodes"
			  "--:singleLine")
	       (mapcar #'(lambda (node)
			   (if (eq node 'more)
			       "...more..."
			     (vector node (list 'Info-menu node))))
		       subnodes)))
    menu))

(defun Info-menu-filter (menu)
  "This is the menu filter for the \"Info\" submenu."
  (Info-construct-menu))

(defun Info-select-node-menu (event)
  "Pops up a menu of applicable Info commands."
  (interactive "e")
  (select-window (event-window event))
  (let ((menu (Info-construct-menu event)))
    (setq menu (nconc (list "Info" ; title: not displayed
			    "     Info Commands"
			    "--:shadowDoubleEtchedOut")
		      menu))
    (let ((popup-menu-titles nil))
      (popup-menu menu))))

;;; Info toolbar support

;; exit icon taken from GNUS
(defvar info::toolbar-exit-icon
  (if (featurep 'toolbar)
      (toolbar-make-button-list
       (expand-file-name (if (featurep 'xpm) "info-exit.xpm" "info-exit.xbm")
			 toolbar-icon-directory)))
  "Exit Info icon")

(defvar info::toolbar-up-icon
  (if (featurep 'toolbar)
      (toolbar-make-button-list
       (expand-file-name (if (featurep 'xpm) "info-up.xpm" "info-up.xbm")
			 toolbar-icon-directory)))
  "Up icon")

(defvar info::toolbar-next-icon
  (if (featurep 'toolbar)
      (toolbar-make-button-list
       (expand-file-name (if (featurep 'xpm) "info-next.xpm" "info-next.xbm")
			 toolbar-icon-directory)))
  "Next icon")

(defvar info::toolbar-prev-icon
  (if (featurep 'toolbar)
      (toolbar-make-button-list
       (expand-file-name (if (featurep 'xpm) "info-prev.xpm" "info-prev.xbm")
			 toolbar-icon-directory)))
  "Prev icon")

(defvar info::toolbar
  (if (featurep 'toolbar)
; disabled until we get the next/prev-win icons working again.
;      (cons (first initial-toolbar-spec)
;       (cons (second initial-toolbar-spec)
	     '([info::toolbar-exit-icon
		 Info-exit
		 t
		 "Exit info"]
		[info::toolbar-next-icon
		 Info-next
		 t
		 "Next entry in same section"]
		[info::toolbar-prev-icon
		 Info-prev
		 t
		 "Prev entry in same section"]
		[info::toolbar-up-icon
		 Info-up
		 t
		 "Up entry to enclosing section"]
		)))
;))

(provide 'info)

(run-hooks 'Info-load-hook)

;;; info.el ends here
