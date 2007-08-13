;;; quail/greek.el -- Quail package for inputting Greek

;; Copyright (C) 1997 Electrotechnical Laboratory, JAPAN.
;; Licensed to the Free Software Foundation.

;; Keywords: multilingual, input method, Greek

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Code:

(require 'quail)

(quail-define-package
 "greek-jis" "Greek" "$B&8(B" nil
 "$B&%&K&K&G&M&I&J&A(B: Greek keyboard layout (JIS X0208.1983)

The layout is same as greek, but uses JIS characters.
Sorry, accents and terminal sigma are not supported in JIS."
 nil t t t t nil nil nil nil nil t)

(quail-define-rules
 ("1" ?$B#1(B)
 ("2" ?$B#2(B)
 ("3" ?$B#3(B)
 ("4" ?$B#4(B)
 ("5" ?$B#5(B)
 ("6" ?$B#6(B)
 ("7" ?$B#7(B)
 ("8" ?$B#8(B)
 ("9" ?$B#9(B)
 ("0" ?$B#0(B)
 ("-" ?$B!](B)
 ("=" ?$B!a(B)
 ("`" ?$B!F(B)
 ("q" ?$B!&(B)
 ("w" ?$B&R(B)
 ("e" ?$B&E(B)
 ("r" ?$B&Q(B)
 ("t" ?$B&S(B)
 ("y" ?$B&T(B)
 ("u" ?$B&H(B)
 ("i" ?$B&I(B)
 ("o" ?$B&O(B)
 ("p" ?$B&P(B)
 ("[" ?\$B!N(B)
 ("]" ?\$B!O(B)
 ("a" ?$B&A(B)
 ("s" ?$B&R(B)
 ("d" ?$B&D(B)
 ("f" ?$B&U(B)
 ("g" ?$B&C(B)
 ("h" ?$B&G(B)
 ("j" ?$B&N(B)
 ("k" ?$B&J(B)
 ("l" ?$B&K(B)
 (";" ?$B!G(B)
 ("'" ?$B!G(B)
 ("\\" ?$B!@(B)
 ("z" ?$B&F(B)
 ("x" ?$B&V(B)
 ("c" ?$B&W(B)
 ("v" ?$B&X(B)
 ("b" ?$B&B(B)
 ("n" ?$B&M(B)
 ("m" ?$B&L(B)
 ("," ?, )
 ("." ?. )
 ("/" ?$B!?(B)
  
 ("!" ?$B!*(B)
 ("@" ?$B!w(B)
 ("#" ?$B!t(B)
 ("$" ?$B!t(B)
 ("%" ?$B!s(B)
 ("^" ?$B!0(B)
 ("&" ?$B!u(B)
 ("*" ?$B!v(B)
 ("(" ?\$B!J(B)
 (")" ?\$B!K(B)
 ("_" ?$B!2(B)
 ("+" ?$B!\(B)
 ("~" ?$B!1(B)
 ("Q" ?$B!](B)
 ("W" ?$B&2(B)
 ("E" ?$B&%(B)
 ("R" ?$B&1(B)
 ("T" ?$B&3(B)
 ("Y" ?$B&4(B)
 ("U" ?$B&((B)
 ("I" ?$B&)(B)
 ("O" ?$B&/(B)
 ("P" ?$B&1(B)
 ("{" ?\$B!P(B)
 ("}" ?\$B!Q(B)
 ("A" ?$B&!(B)
 ("S" ?$B&2(B)
 ("D" ?$B&$(B)
 ("F" ?$B&5(B)
 ("G" ?$B&#(B)
 ("H" ?$B&'(B)
 ("J" ?$B&.(B)
 ("K" ?$B&*(B)
 ("L" ?$B&+(B)
 (":" ?$B!I(B)
 ("\"" ?$B!I(B)
 ("|" ?$B!C(B)
 ("Z" ?$B&&(B)
 ("X" ?$B&6(B)
 ("C" ?$B&7(B)
 ("V" ?$B&8(B)
 ("B" ?$B&"(B)
 ("N" ?$B&-(B)
 ("M" ?$B&,(B)
 ("<" ?$B!((B)
 (">" ?$B!'(B)
 ("?" ?$B!)(B))

;;

(quail-define-package
 "greek" "Greek" ",FY(B" nil
 ",FEkkgmij\(B: Greek keyboard layout (ISO 8859-7)
--------------

In the right of ,Fk(B key is a combination key, where
 ,F4(B acute
 ,F((B diaresis

e.g.
 ,Fa(B + ,F4(B -> ,F\(B
 ,Fi(B + ,F((B -> ,Fz(B
 ,Fi(B + ,F((B + ,F4(B -> ,F@(B"
 nil t t t t nil nil nil nil nil t)

;; 1!  2@  3#  4$  5%  6^  7&  8*  9(  0)  -_  =+  `~
;;  ,F7/(B  ,FrS(B  ,FeE(B  ,FqQ(B  ,FtT(B  ,FuU(B  ,FhH(B  ,FiI(B  ,FoO(B  ,FpP(B  [{  ]}
;;   ,FaA(B  ,FsS(B  ,FdD(B  ,FvV(B  ,FcC(B  ,FgG(B  ,FnN(B  ,FjJ(B  ,FkK(B  ,F4((B  '"  \|
;;    ,FfF(B  ,FwW(B  ,FxX(B  ,FyY(B  ,FbB(B  ,FmM(B  ,FlL(B  ,;  .:  /?  

(quail-define-rules
 ("1" ?1)
 ("2" ?2)
 ("3" ?3)
 ("4" ?4)
 ("5" ?5)
 ("6" ?6)
 ("7" ?7)
 ("8" ?8)
 ("9" ?9)
 ("0" ?0)
 ("-" ?-)
 ("=" ?=)
 ("`" ?`)
 ("q" ?,F7(B)
 ("w" ?,Fr(B)
 ("e" ?,Fe(B)
 ("r" ?,Fq(B)
 ("t" ?,Ft(B)
 ("y" ?,Fu(B)
 ("u" ?,Fh(B)
 ("i" ?,Fi(B)
 ("o" ?,Fo(B)
 ("p" ?,Fp(B)
 ("[" ?\[)
 ("]" ?\])
 ("a" ?,Fa(B)
 ("s" ?,Fs(B)
 ("d" ?,Fd(B)
 ("f" ?,Fv(B)
 ("g" ?,Fc(B)
 ("h" ?,Fg(B)
 ("j" ?,Fn(B)
 ("k" ?,Fj(B)
 ("l" ?,Fk(B)
 (";" ?,F4(B)
 ("'" ?')
 ("\\" ?\\)
 ("z" ?,Ff(B)
 ("x" ?,Fw(B)
 ("c" ?,Fx(B)
 ("v" ?,Fy(B)
 ("b" ?,Fb(B)
 ("n" ?,Fm(B)
 ("m" ?,Fl(B)
 ("," ?,)
 ("." ?.)
 ("/" ?/)
 
 ("!" ?!)
 ("@" ?@)
 ("#" ?#)
 ("$" ?$)
 ("%" ?%)
 ("^" ?^)
 ("&" ?&)
 ("*" ?*)
 ("(" ?\()
 (")" ?\))
 ("_" ?_)
 ("+" ?+)
 ("~" ?~)
 ("Q" ?,F/(B)
 ("W" ?,FS(B)
 ("E" ?,FE(B)
 ("R" ?,FQ(B)
 ("T" ?,FT(B)
 ("Y" ?,FU(B)
 ("U" ?,FH(B)
 ("I" ?,FI(B)
 ("O" ?,FO(B)
 ("P" ?,FP(B)
 ("{" ?{)
 ("}" ?})
 ("A" ?,FA(B)
 ("S" ?,FS(B)
 ("D" ?,FD(B)
 ("F" ?,FV(B)
 ("G" ?,FC(B)
 ("H" ?,FG(B)
 ("J" ?,FN(B)
 ("K" ?,FJ(B)
 ("L" ?,FK(B)
 (":" ?,F((B)
 ("\"" ?\")
 ("|" ?|)
 ("Z" ?,FF(B)
 ("X" ?,FW(B)
 ("C" ?,FX(B)
 ("V" ?,FY(B)
 ("B" ?,FB(B)
 ("N" ?,FM(B)
 ("M" ?,FL(B)
 ("<" ?\;)
 (">" ?:)
 ("?" ??)
 
 ("a;" ?,F\(B)
 ("e;" ?,F](B)
 ("h;" ?,F^(B)
 ("i;" ?,F_(B)
 ("o;" ?,F|(B)
 ("y;" ?,F}(B)
 ("v;" ?,F~(B)
 ("A;" ?,F6(B)
 ("E;" ?,F8(B)
 ("H;" ?,F9(B)
 ("I;" ?,F:(B)
 ("O;" ?,F<(B)
 ("Y;" ?,F>(B)
 ("V;" ?,F?(B)
 ("i:" ?,Fz(B)
 ("y:" ?,F{(B)
 ("I:" ?,FZ(B)
 ("Y:" ?,F[(B)
 ("i:;" ?,F@(B)
 ("y:;" ?,F`(B))
