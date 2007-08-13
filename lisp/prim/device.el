;;; device.el --- miscellaneous device functions not written in C

;;;; Copyright (C) 1994, 1995 Board of Trustees, University of Illinois
;;;; Copyright (C) 1995, 1996 Ben Wing

;; Keywords: internal

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

;;; Synched up with: Not in FSF.

(defun device-list ()
  "Return a list of all devices."
  (apply 'append (mapcar 'console-device-list (console-list))))

(defun device-type (&optional device)
  "Return the type of the specified device (e.g. `x' or `tty').
This is equivalent to the type of the device's console.
Value is `tty' for a tty device (a character-only terminal),
`x' for a device that is a screen on an X display,
`ns' for a device that is a NeXTstep connection (not yet implemeted),
`win32' for a device that is a Windows or Windows NT connection (not yet
  implemented),
`pc' for a device that is a direct-write MS-DOS screen (not yet implemented),
`stream' for a stream device (which acts like a stdio stream), and
`dead' for a deleted device."
  (or device (setq device (selected-device)))
  (if (not (device-live-p device)) 'dead
    (console-type (device-console device))))

(defun make-tty-device (&optional tty terminal-type)
  "Create a new device on TTY.
  TTY should be the name of a tty device file (e.g. \"/dev/ttyp3\" under
SunOS et al.), as returned by the `tty' command.  A value of nil means
use the stdin and stdout as passed to XEmacs from the shell.
  If TERMINAL-TYPE is non-nil, it should be a string specifying the
type of the terminal attached to the specified tty.  If it is nil,
the terminal type will be inferred from the TERM environment variable."
  (make-device 'tty tty (list 'terminal-type terminal-type)))

(defun make-x-device (&optional display)
  "Create a new device connected to DISPLAY."
  (make-device 'x display))

(defun device-on-window-system-p (&optional device)
  "Return non-nil if DEVICE is on a window system.
This generally means that there is support for the mouse, the menubar,
the toolbar, glyphs, etc."
  (or device (setq device (selected-device)))
  (console-on-window-system-p (device-console device)))

(defalias 'valid-device-type-p 'valid-console-type-p)
(defalias 'device-type-list 'console-type-list)