;;; widget.el --- a library of user interface components.
;;
;; Copyright (C) 1996, 1997 Free Software Foundation, Inc.
;;
;; Author: Per Abrahamsen <abraham@dina.kvl.dk>
;; Maintainer: Hrvoje Niksic <hniksic@srce.hr>
;; Keywords: help, extensions, faces, hypermedia
;; Version: 1.9960-x
;; X-URL: http://www.dina.kvl.dk/~abraham/custom/

;; This file is part of XEmacs.

;; XEmacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; XEmacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with XEmacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; If you want to use this code, please visit the URL above.
;;
;; This file only contain the code needed to define new widget types.
;; Everything else is autoloaded from `wid-edit.el'.
;;
;; IMPORTANT: This version of widget is for Emacs 19.34 and XEmacs
;; 19.15 - 20.2 only.  If you use Emacs 20.1, XEmacs 20.3, or anything
;; newer, please use the version of widget bundled with your emacs.
;; If you use an older emacs, please upgrade.

;;; Code:

(eval-when-compile (require 'cl))

(defun define-widget (name class doc &rest args)
  "Define a new widget type named NAME from CLASS.

NAME and CLASS should both be symbols, CLASS should be one of the
existing widget types, or nil to create the widget from scratch.

After the new widget has been defined, the following two calls will
create identical widgets:

* (widget-create NAME)

* (apply 'widget-create CLASS ARGS)

The third argument DOC is a documentation string for the widget."
  (put name 'widget-type (cons class args))
  (put name 'widget-documentation doc)
  name)

;;; The End.

(provide 'widget)

;; widget.el ends here
