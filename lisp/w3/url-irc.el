;;; url-irc.el --- IRC URL interface
;; Author: wmperry
;; Created: 1996/10/09 19:00:59
;; Version: 1.4
;; Keywords: comm, data, processes

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Copyright (c) 1996 by William M. Perry (wmperry@cs.indiana.edu)
;;; Copyright (c) 1996 Free Software Foundation, Inc.
;;;
;;; This file is not part of GNU Emacs, but the same permissions apply.
;;;
;;; GNU Emacs is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.
;;;
;;; GNU Emacs is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to the
;;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;;; Boston, MA 02111-1307, USA.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'url-vars)
(require 'url-parse)

(defvar url-irc-function 'url-irc-zenirc
  "*Function to actually open an IRC connection.
Should be a function that takes several argument:
    HOST - the hostname of the IRC server to contact
    PORT - the port number of the IRC server to contact
 CHANNEL - What channel on the server to visit right away (can be nil)
    USER - What username to use
PASSWORD - What password to use")

(defun url-irc-zenirc (host port channel user password)
  (let ((zenirc-buffer-name (if (and user host port)
				(format "%s@%s:%d" user host port)
			      (format "%s:%d" host port)))
	(zenirc-server-alist
	 (list
	  (list host port password nil user))))
    (zenirc)
    (goto-char (point-max))
    (if (not channel)
	nil
      (insert "/join " channel)
      (zenirc-send-line))))

(defun url-irc (url)
  (let* ((urlobj (url-generic-parse-url url))
	 (host (url-host urlobj))
	 (port (string-to-int (url-port urlobj)))
	 (pass (url-password urlobj))
	 (user (url-user urlobj))
	 (chan (url-filename urlobj)))
    (if (url-target urlobj)
	(setq chan (concat chan "#" (url-target urlobj))))
    (and (get-buffer url-working-buffer)
	 (kill-buffer url-working-buffer))
    (if (string-match "^/" chan)
	(setq chan (substring chan 1 nil)))
    (if (= (length chan) 0)
	(setq chan nil))
    (funcall url-irc-function host port chan user pass)))
    
