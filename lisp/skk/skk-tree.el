;;; skk-tree.el --- $BLZ7A<0%G!<%?!<$r;H$C$?JQ49$N$?$a$N%W%m%0%i%`(B
;; Copyright (C) 1988, 1989, 1990, 1991, 1992, 1993, 1994, 1995, 1996
;; Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>

;; Author: Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>
;; Maintainer: Mikio Nakajima <minakaji@osaka.email.ne.jp>
;; Version: $Id: skk-tree.el,v 1.1 1997/12/02 08:48:39 steve Exp $
;; Keywords: japanese
;; Last Modified: $Date: 1997/12/02 08:48:39 $

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either versions 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with SKK, see the file COPYING.  If not, write to the Free
;; Software Foundation Inc., 59 Temple Place - Suite 330, Boston,
;; MA 02111-1307, USA.

;;; Commentary:

;;; Change log:
;; version 1.0 released 1996.10.2 (derived from the skk.el 8.6)

;;; Code:
(require 'skk-foreword)
(require 'skk-vars)

;;;###skk-autoload
(defvar skk-rom-kana-rule-tree nil
  "*skk-rom-kana-rule-list $B$NMWAG?t$,B?$/$J$C$?$H$-$K;HMQ$9$k%D%j!<!#(B
.emacs $B$K(B
        (setq skk-rom-kana-rule-tree
              (skk-compile-rule-list skk-rom-kana-rule-list))
$B$rDI2C$9$k(B.

$B$3$N$^$^$G$O(B SKK $B$r5/F0$9$k$H$-$KKh2s(B \"skk-compile-rule-list\" $B$r7W;;$9(B
$B$k$3$H$K$J$k$N$G(B, $B$&$^$/$$$/$3$H$,$o$+$l$P(B,
        (skk-compile-rule-list skk-rom-kana-rule-list)
$B$NCM$rD>@\(B .emacs $B$K=q$$$F$*$/$H$h$$!#(B" )

;;;###skk-autoload
(defvar skk-standard-rom-kana-rule-tree nil
  "*skk-standard-rom-kana-rule-list $B$NMWAG?t$,B?$/$J$C$?$H$-$K;HMQ$9$k%D%j!<!#(B
.emacs $B$K(B
        (setq skk-standard-rom-kana-rule-tree
              (skk-compile-rule-list skk-standard-rom-kana-rule-list))
$B$rDI2C$9$k(B.

$B$3$N$^$^$G$O(B SKK $B$r5/F0$9$k$H$-$KKh2s(B \"skk-compile-rule-list\" $B$r7W;;$9(B
$B$k$3$H$K$J$k$N$G(B, $B$&$^$/$$$/$3$H$,$o$+$l$P(B,
        (skk-compile-rule-list skk-standard-rom-kana-rule-list)
$B$NCM$rD>@\(B .emacs $B$K=q$$$F$*$/$H$h$$!#(B" )

(defvar skk-tree-load-hook nil
  "*skk-tree.el $B$r%m!<%I$7$?8e$K%3!<%k$5$l$k%U%C%/!#(B" )

;; $BF0E*JQ?t!#%P%$%H%3%s%Q%$%i!<$rL[$i$;$k$?$a$K$H$j$"$($:(B nil $B$rBeF~!#(B
(defvar root nil)

;; convert skk-rom-kana-rule-list to skk-rom-kana-rule-tree.
;; The rule tree follows the following syntax:
;; <tree> ::= ((<char> . <tree>) . <tree>) | nil
;; <item> ::= (<char> . <tree>)

(defun skk-compile-rule-list (l)
  ;; rom-kana-rule-list $B$rLZ$N7A$K%3%s%Q%$%k$9$k!#(B
  (let (tree rule)
    (while l
      (setq rule (car l)
            l (cdr l)
            tree (skk-add-rule rule tree) ))
    tree))

(defun skk-add-rule (rule tree)
  ;; $BGK2uE*$K(B RULE $B$r(B TREE $B$K2C$($k!#(B
  (let* ((str (car rule))
	 (char (string-to-char str))
	 (rest (substring str 1))
	 (rule-body (cdr rule))
	 (root tree))
    (skk-add-rule-main char rest rule-body tree)
    root))

(defun skk-add-rule-main (char rest body tree)
  (let ((item (skk-search-tree char tree)) (cont t))
    (if item
	(if (string= rest "")
	    (setcdr item (cons (cons 0 body) (cdr item)))
	  (skk-add-rule-main
	   (string-to-char rest) (substring rest 1) body (cdr item)))
      ;; key not found, so add rule to the end of the tree
      (if (null root)
	  (setq root (skk-make-rule-tree char rest body))
	(while (and cont tree)
	  (if (null (cdr tree))
	      (progn
		(setcdr tree (skk-make-rule-tree char rest body))
		(setq cont nil))
	    (setq tree (cdr tree))))))))

(defun skk-make-rule-tree (char rest body)
  (if (string= rest "")
      (list (cons char (list (cons 0 body))))
    (list
     (cons char
           (skk-make-rule-tree
            (string-to-char rest) (substring rest 1) body)))))

(defun skk-search-tree (char tree)
  (let ((cont t) v)
    (while (and cont tree)
      (if (= char (car (car tree)))
          (setq v (car tree)
                cont nil)
        (setq tree (cdr tree))))
    v))

;;;###skk-autoload
(defun skk-assoc-tree (key tree)
  (let ((char (string-to-char key)) (rest (substring key 1))
        (cont t) v )
    (while (and tree cont)
      (if (= char (car (car tree)))
          (if (string= rest "")
              (setq v (if (= 0 (car (car (cdr (car tree)))))
                          (cdr (car (cdr (car tree)))))
                    cont nil)
            (setq v (skk-assoc-tree rest (cdr (car tree)))
                  cont nil))
        (setq tree (cdr tree))))
    v))

(run-hooks 'skk-tree-load-hook)

(provide 'skk-tree)
;;; skk-tree.el ends here
