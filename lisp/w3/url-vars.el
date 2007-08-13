;;; url-vars.el --- Variables for Uniform Resource Locator tool
;; Author: wmperry
;; Created: 1997/03/07 16:46:48
;; Version: 1.31
;; Keywords: comm, data, processes, hypermedia

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Copyright (c) 1993-1996 by William M. Perry (wmperry@cs.indiana.edu)
;;; Copyright (c) 1996, 1997 Free Software Foundation, Inc.
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

(defconst url-version (let ((x "p3.0.65"))
			(if (string-match "State: \\([^ \t\n]+\\)" x)
			    (substring x (match-beginning 1) (match-end 1))
			  x))
  "Version # of URL package.")

(defvar url-current-can-be-cached t
  "*Whether the current URL can be cached.")

(defvar url-current-object nil
  "A parsed representation of the current url")

(defvar url-current-callback-func nil
  "*The callback function for the current buffer.")

(defvar url-current-callback-data nil
  "*The data to be passed to the callback function.  This should be a list,
each item in the list will be an argument to the url-current-callback-func.")

(mapcar 'make-variable-buffer-local '(
				      url-current-callback-data
				      url-current-callback-func
				      url-current-can-be-cached
				      url-current-content-length
				      url-current-isindex
				      url-current-mime-encoding
				      url-current-mime-headers
				      url-current-mime-type
				      url-current-mime-viewer
				      url-current-object
				      url-current-referer

				      ;; obsolete
				      ;; url-current-file
				      ;; url-current-port
				      ;; url-current-server
				      ;; url-current-type
				      ;; url-current-user
				      ))

(defvar url-cookie-storage nil         "Where cookies are stored.")
(defvar url-cookie-secure-storage nil  "Where secure cookies are stored.")
(defvar url-cookie-file nil            "*Where cookies are stored on disk.")

(defvar url-default-retrieval-proc 'url-default-callback
  "*The default action to take when an asynchronous retrieval completes.")

(defvar url-honor-refresh-requests t
  "*Whether to do automatic page reloads at the request of the document
author or the server via the `Refresh' header in an HTTP/1.0 response.
If nil, no refresh requests will be honored.
If t, all refresh requests will be honored.
If non-nil and not t, the user will be asked for each refresh request.")

(defvar url-inhibit-mime-parsing nil
  "Whether to parse out (and delete) the MIME headers from a message.")

(defvar url-automatic-caching nil
  "*If non-nil, all documents will be automatically cached to the local
disk.")

(defvar url-cache-expired
  (function (lambda (t1 t2) (>= (- (car t2) (car t1)) 5)))
  "*A function (`funcall'able) that takes two times as its arguments, and
returns non-nil if the second time is 'too old' when compared to the first
time.")

(defvar url-bug-address "wmperry@cs.indiana.edu"
  "Where to send bug reports.")

(defvar url-cookie-confirmation nil
  "*If non-nil, confirmation by the user is required to accept HTTP cookies.")

(defvar url-personal-mail-address nil
  "*Your full email address.
This is what is sent to HTTP/1.0 servers as the FROM field in an HTTP/1.0
request.")

(defvar url-directory-index-file "index.html"
  "*The filename to look for when indexing a directory.  If this file
exists, and is readable, then it will be viewed instead of
automatically creating the directory listing.")

(defvar url-privacy-level 'none
  "*How private you want your requests to be.
HTTP/1.0 has header fields for various information about the user, including
operating system information, email addresses, the last page you visited, etc.
This variable controls how much of this information is sent.

This should a symbol or a list.
Valid values if a symbol are:
none     -- Send all information
low      -- Don't send the last location
high     -- Don't send the email address or last location
paranoid -- Don't send anything

If a list, this should be a list of symbols of what NOT to send.
Valid symbols are:
email    -- the email address
os       -- the operating system info
lastloc  -- the last location
agent    -- Do not send the User-Agent string
cookie   -- never accept HTTP cookies

Samples:

(setq url-privacy-level 'high)
(setq url-privacy-level '(email lastloc))    ;; equivalent to 'high
(setq url-privacy-level '(os))

::NOTE::
This variable controls several other variables and is _NOT_ automatically
updated.  Call the function `url-setup-privacy-info' after modifying this
variable.
")

(defvar url-history-list nil "List of urls visited this session.")

(defvar url-inhibit-uncompression nil "Do not do decompression if non-nil.")

(defvar url-keep-history nil
  "*Controls whether to keep a list of all the URLS being visited.  If
non-nil, url will keep track of all the URLS visited.
If eq to `t', then the list is saved to disk at the end of each emacs
session.")

(defvar url-uncompressor-alist '((".z"  . "x-gzip")
				 (".gz" . "x-gzip")
				 (".uue" . "x-uuencoded")
				 (".hqx" . "x-hqx")
				 (".Z"  . "x-compress"))
  "*An assoc list of file extensions and the appropriate
content-transfer-encodings for each.")

(defvar url-mail-command 'url-mail
  "*This function will be called whenever url needs to send mail.  It should
enter a mail-mode-like buffer in the current window.
The commands mail-to and mail-subject should still work in this
buffer, and it should use mail-header-separator if possible.")

(defvar url-proxy-services nil
  "*An assoc list of access types and servers that gateway them.
Looks like ((\"http\" . \"hostname:portnumber\") ....)  This is set up
from the ACCESS_proxy environment variables in url-do-setup.")

(defvar url-global-history-file nil
  "*The global history file used by both Mosaic/X and the url package.
This file contains a list of all the URLs you have visited.  This file
is parsed at startup and used to provide URL completion.")

(defvar url-global-history-save-interval 3600
  "*The number of seconds between automatic saves of the history list.
Default is 1 hour.  Note that if you change this variable after `url-do-setup'
has been run, you need to run the `url-setup-save-timer' function manually.")

(defvar url-global-history-timer nil)

(defvar url-passwd-entry-func nil
  "*This is a symbol indicating which function to call to read in a
password.  It will be set up depending on whether you are running EFS
or ange-ftp at startup if it is nil.  This function should accept the
prompt string as its first argument, and the default value as its
second argument.")

(defvar url-gopher-labels
  '(("0" . "(TXT)")
    ("1" . "(DIR)")
    ("2" . "(CSO)")
    ("3" . "(ERR)")
    ("4" . "(MAC)")
    ("5" . "(PCB)")
    ("6" . "(UUX)")
    ("7" . "(???)")
    ("8" . "(TEL)")
    ("T" . "(TN3)")
    ("9" . "(BIN)")
    ("g" . "(GIF)")
    ("I" . "(IMG)")
    ("h" . "(WWW)")
    ("s" . "(SND)"))
  "*An assoc list of gopher types and how to describe them in the gopher
menus.  These can be any string, but HTML/HTML+ entities should be
used when necessary, or it could disrupt formatting of the document
later on.  It is also a good idea to make sure all the strings are the
same length after entity references are removed, on a strictly
stylistic level.")

(defvar url-gopher-icons
  '(
    ("0" . "&text.document;")
    ("1" . "&folder;")
    ("2" . "&index;")
    ("3" . "&stop;")
    ("4" . "&binhex.document;")
    ("5" . "&binhex.document;")
    ("6" . "&uuencoded.document;")
    ("7" . "&index;")
    ("8" . "&telnet;")
    ("T" . "&tn3270;")
    ("9" . "&binary.document;")
    ("g" . "&image;")
    ("I" . "&image;")
    ("s" . "&audio;"))
  "*An assoc list of gopher types and the graphic entity references to
show when possible.")

(defvar url-standalone-mode nil "*Rely solely on the cache?")
(defvar url-multiple-p t
  "*If non-nil, multiple queries are possible through ` *URL-<i>*' buffers")
(defvar url-default-working-buffer " *URL*" " The default buffer to do all of the processing in.")
(defvar url-working-buffer url-default-working-buffer
  "The buffer to do all of the processing in.
It defaults to `url-default-working-buffer' and is bound to *URL-<i>*
buffers when used for multiple requests, cf. `url-multiple-p'")
(defvar url-current-referer nil "Referer of this page.")
(defvar url-current-content-length nil "Current content length.")
(defvar url-current-isindex nil "Is the current document a searchable index?")
(defvar url-current-mime-encoding nil "MIME encoding of current document.")
(defvar url-current-mime-headers nil "An alist of MIME headers.")
(defvar url-current-mime-type nil "MIME type of current document.")
(defvar url-current-mime-viewer nil "How to view the current MIME doc.")
(defvar url-current-passwd-count 0 "How many times password has failed.")
(defvar url-gopher-types "0123456789+gIThws:;<"
  "A string containing character representations of all the gopher types.")
(defvar url-mime-separator-chars (mapcar 'identity
					(concat "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
						"abcdefghijklmnopqrstuvwxyz"
						"0123456789'()+_,-./=?"))
  "Characters allowable in a MIME multipart separator.")

(defvar url-bad-port-list
  '("25" "119" "19")
  "*List of ports to warn the user about connecting to.  Defaults to just
the mail, chargen, and NNTP ports so you cannot be tricked into sending
fake mail or forging messages by a malicious HTML document.")

(defvar url-be-anal-about-file-attributes nil
  "*Whether to use HTTP/1.0 to figure out file attributes
or just guess based on file extension, etc.")

(defvar url-be-asynchronous nil
  "*Controls whether document retrievals over HTTP should be done in
the background.  This allows you to keep working in other windows
while large downloads occur.")
(make-variable-buffer-local 'url-be-asynchronous)

(defvar url-request-data nil "Any data to send with the next request.")

(defvar url-request-extra-headers nil
  "A list of extra headers to send with the next request.  Should be
an assoc list of headers/contents.")

(defvar url-request-method nil "The method to use for the next request.")

(defvar url-mime-encoding-string nil
  "*String to send to the server in the Accept-encoding: field in HTTP/1.0
requests.  This is created automatically from mm-content-transfer-encodings.")

(defvar url-mime-language-string "*"
  "*String to send to the server in the Accept-language: field in
HTTP/1.0 requests.")

(defvar url-mime-accept-string nil
  "String to send to the server in the Accept: field in HTTP/1.0 requests.
This is created automatically from url-mime-viewers, after the mailcap file
has been parsed.")

(defvar url-history-changed-since-last-save nil
  "Whether the history list has changed since the last save operation.")

(defvar url-proxy-basic-authentication nil
  "Internal structure - do not modify!")
  
(defvar url-registered-protocols nil
  "Internal structure - do not modify!  See `url-register-protocol'")

(defvar url-package-version "Unknown" "Version # of package using URL.")

(defvar url-package-name "Unknown" "Version # of package using URL.")

(defvar url-system-type nil "What type of system we are on.")
(defvar url-os-type nil "What OS we are on.")

(defvar url-max-password-attempts 5
  "*Maximum number of times a password will be prompted for when a
protected document is denied by the server.")

(defvar url-temporary-directory "/tmp" "*Where temporary files go.")

(defvar url-show-status t
  "*Whether to show a running total of bytes transferred.  Can cause a
large hit if using a remote X display over a slow link, or a terminal
with a slow modem.")

(defvar url-using-proxy nil
  "Either nil or the fully qualified proxy URL in use, e.g.
http://www.domain.com/")

(defvar url-news-server nil
  "*The default news server to get newsgroups/articles from if no server
is specified in the URL.  Defaults to the environment variable NNTPSERVER
or \"news\" if NNTPSERVER is undefined.")

(defvar url-gopher-to-mime
  '((?0 . "text/plain")			; It's a file
    (?1 . "www/gopher")			; Gopher directory
    (?2 . "www/gopher-cso-search")	; CSO search
    (?3 . "text/plain")			; Error
    (?4 . "application/mac-binhex40")	; Binhexed macintosh file
    (?5 . "application/pc-binhex40")	; DOS binary archive of some sort
    (?6 . "archive/x-uuencode")		; Unix uuencoded file
    (?7 . "www/gopher-search")		; Gopher search!
    (?9 . "application/octet-stream")	; Binary file!
    (?g . "image/gif")			; Gif file
    (?I . "image/gif")			; Some sort of image
    (?h . "text/html")			; HTML source
    (?s . "audio/basic")		; Sound file
    )
  "*An assoc list of gopher types and their corresponding MIME types.")

(defvar url-use-hypertext-gopher t
  "*Controls how gopher documents are retrieved.
If non-nil, the gopher pages will be converted into HTML and parsed
just like any other page.  If nil, the requests will be passed off to
the gopher.el package by Scott Snyder.  Using the gopher.el package
will lose the gopher+ support, and inlined searching.")

(defvar url-global-history-hash-table nil
  "Hash table for global history completion.")

(defvar url-nonrelative-link
  "^\\([-a-zA-Z0-9+.]+:\\)"
  "A regular expression that will match an absolute URL.")

(defvar url-confirmation-func 'y-or-n-p
  "*What function to use for asking yes or no functions.  Possible
values are 'yes-or-no-p or 'y-or-n-p, or any function that takes a
single argument (the prompt), and returns t only if a positive answer
is gotten.")

(defvar url-gateway-method 'native
  "*The type of gateway support to use.
Should be a symbol specifying how we are to get a connection off of the
local machine.

Currently supported methods:
'telnet   	:: Run telnet in a subprocess to connect
'rlogin         :: Rlogin to another machine to connect
'socks          :: Connects through a socks server
'ssl            :: Connection should be made with SSL
'tcp            :: Use the excellent tcp.el package from gnus.
                   This simply does a (require 'tcp), then sets
                   url-gateway-method to be 'native.
'native		:: Use the native open-network-stream in emacs
")

(defvar url-running-xemacs (string-match "XEmacs" emacs-version)
  "*Got XEmacs?")

(defvar url-default-ports '(("http"   .  "80")
			    ("gopher" .  "70")
			    ("telnet" .  "23")
			    ("news"   . "119")
			    ("https"  . "443")
			    ("shttp"  .  "80"))
  "An assoc list of protocols and default port #s")

(defvar url-setup-done nil "*Has setup configuration been done?")

(defvar url-source nil
  "*Whether to force a sourcing of the next buffer.  This forces local
files to be read into a buffer, no matter what.  Gets around the
optimization that if you are passing it to a viewer, just make a
symbolic link, which looses if you want the source for inlined
images/etc.")

(defconst weekday-alist
  '(("Sunday" . 0) ("Monday" . 1) ("Tuesday" . 2) ("Wednesday" . 3)
    ("Thursday" . 4) ("Friday" . 5) ("Saturday" . 6)
    ("Tues" . 2) ("Thurs" . 4)
    ("Sun" . 0) ("Mon" . 1) ("Tue" . 2) ("Wed" . 3)
    ("Thu" . 4) ("Fri" . 5) ("Sat" . 6)))

(defconst monthabbrev-alist
  '(("Jan" . 1) ("Feb" . 2) ("Mar" . 3) ("Apr" . 4) ("May" . 5) ("Jun" . 6)
    ("Jul" . 7) ("Aug" . 8) ("Sep" . 9) ("Oct" . 10) ("Nov" . 11) ("Dec" . 12))
  )

(defvar url-lazy-message-time 0)

(defvar url-extensions-header "Security/Digest Security/SSL")

(defvar url-mailserver-syntax-table
  (copy-syntax-table emacs-lisp-mode-syntax-table)
  "*A syntax table for parsing the mailserver URL")

(modify-syntax-entry ?' "\"" url-mailserver-syntax-table)
(modify-syntax-entry ?` "\"" url-mailserver-syntax-table)
(modify-syntax-entry ?< "(>" url-mailserver-syntax-table)
(modify-syntax-entry ?> ")<" url-mailserver-syntax-table)
(modify-syntax-entry ?/ " " url-mailserver-syntax-table)

;;; Make OS/2 happy - yeeks
(defvar	tcp-binary-process-input-services nil
  "*Make OS/2 happy with our CRLF pairs...")

(provide 'url-vars)
