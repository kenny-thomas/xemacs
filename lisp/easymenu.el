;;; easymenu.el - Easy menu support for Emacs 19 and XEmacs.

;; Copyright (C) 1992, 1993, 1994, 1995, 2005 Free Software Foundation, Inc.

;; Author: Per Abrahamsen <abraham@dina.kvl.dk>
;; Maintainer: XEmacs Development Team
;; Keywords: internal, extensions, dumped

;; This file is part of XEmacs.

;; XEmacs is free software: you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the
;; Free Software Foundation, either version 3 of the License, or (at your
;; option) any later version.

;; XEmacs is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.

;; You should have received a copy of the GNU General Public License
;; along with XEmacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Synched up with: Not synched with FSF but coordinated with the FSF
;;;                  easymenu maintainer for compatibility with FSF 20.4.
;;; Please: Coordinate changes with Inge Frick <inge@nada.kth.se>

;; Commentary:

;; This file is dumped with XEmacs.

;; Easymenu allows you to define menus for both Emacs 19 and XEmacs.

;; This file
;; The advantages of using easymenu are:

;; - Easier to use than either the Emacs 19 and XEmacs menu syntax.

;; - Common interface for Emacs 18, Emacs 19, and XEmacs.
;;   (The code does nothing when run under Emacs 18).

;; The public functions are:

;; - Function: easy-menu-define SYMBOL MAPS DOC MENU
;;     SYMBOL is both the name of the variable that holds the menu and
;;            the name of a function that will present the menu.
;;     MAPS is a list of keymaps where the menu should appear in the menubar.
;;     DOC is the documentation string for the variable.
;;     MENU is an XEmacs style menu description.

;;     See the documentation for easy-menu-define for details.

;; - Function: easy-menu-change PATH NAME ITEMS
;;     Change an existing menu.
;;     The menu must already exist and be visible on the menu bar.
;;     PATH is a list of strings used for locating the menu on the menu bar.
;;     NAME is the name of the menu.
;;     ITEMS is a list of menu items, as defined in `easy-menu-define'.

;; - Function: easy-menu-add MENU [ MAP ]
;;     Add MENU to the current menubar in MAP.

;; - Function: easy-menu-remove MENU
;;     Remove MENU from the current menubar.

;; - Function: easy-menu-add-item
;;     Add item or submenu to existing menu

;; - Function: easy-menu-item-present-p
;;     Locate item

;; - Function: easy-menu-remove-item
;;     Delete item from menu.

;; Emacs 19 never uses `easy-menu-add' or `easy-menu-remove', menus
;; automatically appear and disappear when the keymaps specified by
;; the MAPS argument to `easy-menu-define' are activated.

;; XEmacs will bind the map to button3 in each MAPS, but you must
;; explicitly call `easy-menu-add' and `easy-menu-remove' to add and
;; remove menus from the menu bar.

;;; Code:

;; ;;;###autoload
(defmacro easy-menu-define (symbol maps doc menu)
  "Define a menu bar submenu in maps MAPS, according to MENU.
The arguments SYMBOL and DOC are ignored; they are present for
compatibility only.  SYMBOL is not evaluated.  In other Emacs versions
these arguments may be used as a variable to hold the menu data, and a
doc string for that variable.

The first element of MENU must be a string.  It is the menu bar item name.
The rest of the elements are menu items.

A menu item is usually a vector of three elements:  [NAME CALLBACK ENABLE]

NAME is a string--the menu item name.

CALLBACK is a command to run when the item is chosen,
or a list to evaluate when the item is chosen.

ENABLE is an expression; the item is enabled for selection
whenever this expression's value is non-nil.

Alternatively, a menu item may have the form:

   [ NAME CALLBACK [ KEYWORD ARG ] ... ]

Where KEYWORD is one of the symbol defined below.

   :keys KEYS

KEYS is a string; a complex keyboard equivalent to this menu item.

   :active ENABLE

ENABLE is an expression; the item is enabled for selection
whenever this expression's value is non-nil.

   :suffix NAME

NAME is a string; the name of an argument to CALLBACK.

   :style STYLE

STYLE is a symbol describing the type of menu item.  The following are
defined:

toggle: A checkbox.
        Currently just prepend the name with the string \"Toggle \".
radio: A radio button.
nil: An ordinary menu item.

   :selected SELECTED

SELECTED is an expression; the checkbox or radio button is selected
whenever this expression's value is non-nil.
Currently just disable radio buttons, no effect on checkboxes.

A menu item can be a string.  Then that string appears in the menu as
unselectable text.  A string consisting solely of hyphens is displayed
as a solid horizontal line.

A menu item can be a list.  It is treated as a submenu.
The first element should be the submenu name.  That's used as the
menu item in the top-level menu.  The cdr of the submenu list
is a list of menu items, as above."
  `(progn
     (defvar ,symbol nil ,doc)
     (easy-menu-do-define (quote ,symbol) ,maps ,doc ,menu)))

(defun easy-menu-do-define (symbol maps doc menu)
  (when (featurep 'menubar)
    (set symbol menu)
    (fset symbol `(lambda (e)
		    ,doc
		    (interactive "@e")
		    (run-hooks 'activate-menubar-hook)
		    (setq zmacs-region-stays t)
		    (popup-menu ,symbol)))))

(defun easy-menu-change (&rest args)
  (when (featurep 'menubar)
    (apply 'add-menu args)))

(defvar easy-menu-all-popups nil 
  "This variable holds all the popup menus easy-menu knows about. 
This includes any menu created with `easy-menu-add' and any
non-default value for `mode-popup-menu' that existed when
`easy-menu-add' was first called.") 
(make-variable-buffer-local 'easy-menu-all-popups)

(defun easy-menu-add (menu &optional map)
  "Add MENU to the current menu bar."
  ;; If you uncomment the following, do an xemacs -vanilla, type M-x
  ;; folding-mode RET, you'll see that this code, which theoretically has
  ;; *scratch* as its buffer context, can't see *scratch*'s value for
  ;; mode-popup-menu--the default overrides it.  
  ;;
  ;; This is not specific to *scratch*--try it on ~/.xemacs/init.el--but it
  ;; does appear to be specific to the first time mode-popup-menu is
  ;; accessed as a buffer-local variable in non-interactive code (that is,
  ;; M-: mode-popup-menu RET gives the correct value).
  ;; 
  ;; My fixing this right now isn't going to happen. Aidan Kehoe, 2006-01-03
;    (message (concat "inside easy-menu-add, menu is %s, "
;  		   "mode-popup-menu is %s, current buffer is %s, "
;  		   "default-value mode-popup-menu is %s, "
;  		   "easy-menu-all-popups is %s")
;  	   menu mode-popup-menu (current-buffer) 
;  	   (default-value 'mode-popup-menu) easy-menu-all-popups)
  (when (featurep 'menubar)
    ;; Save the existing mode-popup-menu, if it's been changed.
    (when (and (eql (length easy-menu-all-popups) 0)
	       (not (equal (default-value 'mode-popup-menu) mode-popup-menu)))
      (push mode-popup-menu easy-menu-all-popups))
    ;; Add the menu to our list of all the popups for the buffer. 
    (pushnew menu easy-menu-all-popups :test 'equal)
    ;; If there are multiple popup menus available, make the popup menu
    ;; normally shown with button-3 a menu of them. If there is just one,
    ;; make that button show it, and no super-menu.
    (setq mode-popup-menu (if (eql 1 (length easy-menu-all-popups))
			      (car easy-menu-all-popups)
			    (cons (easy-menu-title)
				(reverse easy-menu-all-popups))))
    (cond ((null current-menubar)
	   ;; Don't add it to a non-existing menubar.
	   nil)
	  ((assoc (car menu) current-menubar)
	   ;; Already present.
	   nil)
	  ((equal current-menubar '(nil))
	   ;; Set at left if only contains right marker.
	   (set-buffer-menubar (list menu nil)))
	  (t
	   ;; Add at right.
	   (set-buffer-menubar (copy-sequence current-menubar))
	   (add-menu nil (car menu) (cdr menu))))))

(defun easy-menu-remove (menu)
  "Remove MENU from the current menu bar."
  (when (featurep 'menubar)
    (setq 
     ;; Remove this menu from the list of popups we know about. 
     easy-menu-all-popups (delete* menu easy-menu-all-popups)
     ;; If there are multiple popup menus available, make the popup menu
     ;; normally shown with button-3 a menu of them. If there is just one,
     ;; make that button show it, and no super-menu.
     mode-popup-menu (if (eql 1 (length easy-menu-all-popups))
			 (car easy-menu-all-popups)
		       (cons (easy-menu-title)
			     (reverse easy-menu-all-popups))))
    ;; If we've just set mode-popup-menu to an empty menu, change that menu
    ;; to its default value (without intervention from easy-menu).
    (if (eql (length easy-menu-all-popups) 0)
	(setq mode-popup-menu (default-value 'mode-popup-menu)))
    (and current-menubar
	 (assoc (car menu) current-menubar)
	 (delete-menu-item (list (car menu))))))

(defsubst easy-menu-normalize (menu)
  (if (symbolp menu)
      (symbol-value menu)
    menu))

(defun easy-menu-add-item (menu path item &optional before)
  "At the end of the submenu of MENU with path PATH, add ITEM.
If ITEM is already present in this submenu, then this item will be changed.
otherwise ITEM will be added at the end of the submenu, unless the optional
argument BEFORE is present, in which case ITEM will instead be added
before the item named BEFORE.
MENU is either a symbol, which have earlier been used as the first
argument in a call to `easy-menu-define', or the value of such a symbol
i.e. a menu, or nil, which stands for the current menubar.
PATH is a list of strings for locating the submenu where ITEM is to be
added.  If PATH is nil, MENU itself is used.  Otherwise, the first
element should be the name of a submenu directly under MENU.  This
submenu is then traversed recursively with the remaining elements of PATH.
ITEM is either defined as in `easy-menu-define', a menu defined earlier
by `easy-menu-define' or `easy-menu-create-menu' or an item returned
from `easy-menu-item-present-p' or `easy-menu-remove-item'."
  (when (featurep 'menubar)
    (add-menu-button path item before (easy-menu-normalize menu))))

(defun easy-menu-item-present-p (menu path name)
  "In submenu of MENU with path PATH, return true iff item NAME is present.
MENU and PATH are defined as in `easy-menu-add-item'.
NAME should be a string, the name of the element to be looked for.

The return value can be used as an argument to `easy-menu-add-item'."
  (if (featurep 'menubar)
      (car (find-menu-item (or (easy-menu-normalize menu) current-menubar)
			   (append path (list name))))
    nil))

(defun easy-menu-remove-item (menu path name)
  "From submenu of MENU with path PATH, remove item NAME.
MENU and PATH are defined as in `easy-menu-add-item'.
NAME should be a string, the name of the element to be removed.

The return value can be used as an argument to `easy-menu-add-item'."
  (when (featurep 'menubar)
    (delete-menu-item (append path (list name))
		      (easy-menu-normalize menu))))

;; Think up a good title for the menu.  Take the major-mode of the buffer,
;; strip the -mode part, convert hyphens to spaces, and capitalize it.
;;
;; In a more ideal world, we could use `mode-name' here, which see, but that
;; turns out to be temporarily trashed by various minor modes, and this
;; value is much more trustworthy.

(defun easy-menu-title ()
  (capitalize (replace-in-string (replace-in-string
				  (symbol-name major-mode) "-mode$" "")
				 "-" " ")))

(provide 'easymenu)

;;; easymenu.el ends here
