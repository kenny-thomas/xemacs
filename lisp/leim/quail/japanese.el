;;; quail/japanese.el --- Quail package for inputting Japanese

;; Copyright (C) 1997 Electrotechnical Laboratory, JAPAN.
;; Licensed to the Free Software Foundation.

;; Keywords: multilingual, input method, Japanese

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
(require 'kkc)

;; Update Quail translation region while considering Japanese bizarre
;; translation rules.
(defun quail-japanese-update-translation (control-flag)
  (cond ((eq control-flag t)
	 (insert quail-current-str)
	 (quail-terminate-translation))
	((null control-flag)
	 (if (/= (aref quail-current-key 0) ?q)
	     (insert (or quail-current-str quail-current-key))))
	(t				; i.e. (numberp control-flag)
	 (cond ((= (aref quail-current-key 0) ?n)
		(insert ?$B$s(B))
	       ((= (aref quail-current-key 0) (aref quail-current-key 1))
		(insert ?$B$C(B))
	       (t
		(insert (aref quail-current-key 0))))
	 (setq unread-command-events
	       (list (aref quail-current-key control-flag)))
	 (quail-terminate-translation))))
	 
;; Flag to control the behavior of `quail-japanese-toggle-kana'.
(defvar quail-japanese-kana-state nil)
(make-variable-buffer-local 'quail-japanese-kana-state)

;; Convert Hiragana <-> Katakana in the current translation region.
(defun quail-japanese-toggle-kana ()
  (interactive)
  (let ((start (overlay-start quail-conv-overlay))
	(end (overlay-end quail-conv-overlay)))
    (setq quail-japanese-kana-state
	  (if (eq last-command this-command)
	      (not quail-japanese-kana-state)))
    (if quail-japanese-kana-state
	(japanese-hiragana-region start end)
      (japanese-katakana-region start end))
    (goto-char (overlay-end quail-conv-overlay))))

;; Convert Hiragana in the current translation region to Kanji by KKC
;; (Kana Kanji Converter) utility.
(defun quail-japanese-kanji-kkc ()
  (interactive)
  (let ((from (overlay-start quail-conv-overlay))
	(to (overlay-end quail-conv-overlay))
	newfrom)
    (quail-delete-overlays)
    (setq overriding-terminal-local-map nil)
    (kkc-region from to 'quail-japanese-kkc-mode-exit)))

;; Function to call on exiting KKC mode.  ARG is nil if KKC mode is
;; exited normally, else ARG is a cons (FROM . TO) where FROM and TO
;; specify a region not yet processed.
(defun quail-japanese-kkc-mode-exit (arg)
  (if arg
      (progn
	(setq overriding-terminal-local-map (quail-conversion-keymap))
	(move-overlay quail-conv-overlay (car arg) (cdr arg)))
    (run-hooks 'input-method-after-insert-chunk-hook)))

(defun quail-japanese-self-insert-and-switch-to-alpha (key idx)
  (quail-delete-region)
  (setq unread-command-events (list (aref key (1- idx))))
  (quail-japanese-switch-package "q" 1))

(defvar quail-japanese-switch-table
  '((?z . "japanese-zenkaku")
    (?k . "japanese-hankaku-kana")
    (?h . "japanese")
    (?q . ("japanese-ascii"))))

(defvar quail-japanese-package-saved nil)
(make-variable-buffer-local 'quail-japanese-package-saved)
(put 'quail-japanese-package-saved 'permanent-local t)

(defun quail-japanese-switch-package (key idx)
  (let ((pkg (cdr (assq (aref key (1- idx)) quail-japanese-switch-table))))
    (if (null pkg)
	(error "No package to be switched")
      (setq overriding-terminal-local-map nil)
      (quail-delete-region)
      (if (stringp pkg)
	  (activate-input-method pkg)
	(if (string= (car pkg) current-input-method)
	    (if quail-japanese-package-saved
		(activate-input-method quail-japanese-package-saved))
	  (setq quail-japanese-package-saved current-input-method)
	  (activate-input-method (car pkg))))))
  (throw 'quail-tag nil))

(quail-define-package
 "japanese" "Japanese" "A$B$"(B"
 nil
 "Romaji -> Hiragana -> Kanji&Kana
---- Special key bindings ----
qq:	toggle between input methods `japanese' and `japanese-ascii'
qz:	use `japanese-zenkaku' package, \"qh\" puts you back to `japanese'
K:	toggle converting region between Katakana and Hiragana
SPC:	convert to Kanji&Kana
z:	insert one Japanese symbol according to a key which follows
"
 nil t t nil nil nil nil nil
 'quail-japanese-update-translation
 '(("K" . quail-japanese-toggle-kana)
   (" " . quail-japanese-kanji-kkc)
   ("\C-m" . quail-no-conversion)
   ([return] . quail-no-conversion))
 )

(quail-define-rules

( "a" "$B$"(B") ( "i" "$B$$(B") ( "u" "$B$&(B") ( "e" "$B$((B") ( "o" "$B$*(B")
("ka" "$B$+(B") ("ki" "$B$-(B") ("ku" "$B$/(B") ("ke" "$B$1(B") ("ko" "$B$3(B")
("sa" "$B$5(B") ("si" "$B$7(B") ("su" "$B$9(B") ("se" "$B$;(B") ("so" "$B$=(B")
("ta" "$B$?(B") ("ti" "$B$A(B") ("tu" "$B$D(B") ("te" "$B$F(B") ("to" "$B$H(B")
("na" "$B$J(B") ("ni" "$B$K(B") ("nu" "$B$L(B") ("ne" "$B$M(B") ("no" "$B$N(B")
("ha" "$B$O(B") ("hi" "$B$R(B") ("hu" "$B$U(B") ("he" "$B$X(B") ("ho" "$B$[(B")
("ma" "$B$^(B") ("mi" "$B$_(B") ("mu" "$B$`(B") ("me" "$B$a(B") ("mo" "$B$b(B")
("ya" "$B$d(B")             ("yu" "$B$f(B")             ("yo" "$B$h(B")
("ra" "$B$i(B") ("ri" "$B$j(B") ("ru" "$B$k(B") ("re" "$B$l(B") ("ro" "$B$m(B")
("la" "$B$i(B") ("li" "$B$j(B") ("lu" "$B$k(B") ("le" "$B$l(B") ("lo" "$B$m(B")
("wa" "$B$o(B") ("wi" "$B$p(B") ("wu" "$B$&(B") ("we" "$B$q(B") ("wo" "$B$r(B")
("n'" "$B$s(B")	 			     
("ga" "$B$,(B") ("gi" "$B$.(B") ("gu" "$B$0(B") ("ge" "$B$2(B") ("go" "$B$4(B")
("za" "$B$6(B") ("zi" "$B$8(B") ("zu" "$B$:(B") ("ze" "$B$<(B") ("zo" "$B$>(B")
("da" "$B$@(B") ("di" "$B$B(B") ("du" "$B$E(B") ("de" "$B$G(B") ("do" "$B$I(B")
("ba" "$B$P(B") ("bi" "$B$S(B") ("bu" "$B$V(B") ("be" "$B$Y(B") ("bo" "$B$\(B")
("pa" "$B$Q(B") ("pi" "$B$T(B") ("pu" "$B$W(B") ("pe" "$B$Z(B") ("po" "$B$](B")

("kya" ["$B$-$c(B"]) ("kyu" ["$B$-$e(B"]) ("kye" ["$B$-$'(B"]) ("kyo" ["$B$-$g(B"])
("sya" ["$B$7$c(B"]) ("syu" ["$B$7$e(B"]) ("sye" ["$B$7$'(B"]) ("syo" ["$B$7$g(B"])
("sha" ["$B$7$c(B"]) ("shu" ["$B$7$e(B"]) ("she" ["$B$7$'(B"]) ("sho" ["$B$7$g(B"])
("cha" ["$B$A$c(B"]) ("chu" ["$B$A$e(B"]) ("che" ["$B$A$'(B"]) ("cho" ["$B$A$g(B"])
("tya" ["$B$A$c(B"]) ("tyu" ["$B$A$e(B"]) ("tye" ["$B$A$'(B"]) ("tyo" ["$B$A$g(B"])
("nya" ["$B$K$c(B"]) ("nyu" ["$B$K$e(B"]) ("nye" ["$B$K$'(B"]) ("nyo" ["$B$K$g(B"])
("hya" ["$B$R$c(B"]) ("hyu" ["$B$R$e(B"]) ("hye" ["$B$R$'(B"]) ("hyo" ["$B$R$g(B"])
("mya" ["$B$_$c(B"]) ("myu" ["$B$_$e(B"]) ("mye" ["$B$_$'(B"]) ("myo" ["$B$_$g(B"])
("rya" ["$B$j$c(B"]) ("ryu" ["$B$j$e(B"]) ("rye" ["$B$j$'(B"]) ("ryo" ["$B$j$g(B"])
("lya" ["$B$j$c(B"]) ("lyu" ["$B$j$e(B"]) ("lye" ["$B$j$'(B"]) ("lyo" ["$B$j$g(B"])
("gya" ["$B$.$c(B"]) ("gyu" ["$B$.$e(B"]) ("gye" ["$B$.$'(B"]) ("gyo" ["$B$.$g(B"])
("zya" ["$B$8$c(B"]) ("zyu" ["$B$8$e(B"]) ("zye" ["$B$8$'(B"]) ("zyo" ["$B$8$g(B"])
("jya" ["$B$8$c(B"]) ("jyu" ["$B$8$e(B"]) ("jye" ["$B$8$'(B"]) ("jyo" ["$B$8$g(B"])
( "ja" ["$B$8$c(B"]) ( "ju" ["$B$8$e(B"]) ( "je" ["$B$8$'(B"]) ( "jo" ["$B$8$g(B"])
("bya" ["$B$S$c(B"]) ("byu" ["$B$S$e(B"]) ("bye" ["$B$S$'(B"]) ("byo" ["$B$S$g(B"])
("pya" ["$B$T$c(B"]) ("pyu" ["$B$T$e(B"]) ("pye" ["$B$T$'(B"]) ("pyo" ["$B$T$g(B"])

("kwa" ["$B$/$n(B"]) ("kwi" ["$B$/$#(B"]) ("kwe" ["$B$/$'(B"]) ("kwo" ["$B$/$)(B"])
("tsa" ["$B$D$!(B"]) ("tsi" ["$B$D$#(B"]) ("tse" ["$B$D$'(B"]) ("tso" ["$B$D$)(B"])
( "fa" ["$B$U$!(B"]) ( "fi" ["$B$U$#(B"]) ( "fe" ["$B$U$'(B"]) ( "fo" ["$B$U$)(B"])
("gwa" ["$B$0$n(B"]) ("gwi" ["$B$0$#(B"]) ("gwe" ["$B$0$'(B"]) ("gwo" ["$B$0$)(B"])

("dyi" ["$B$G$#(B"]) ("dyu" ["$B$I$%(B"]) ("dye" ["$B$G$'(B"]) ("dyo" ["$B$I$)(B"])
("xwi" ["$B$&$#(B"])                  ("xwe" ["$B$&$'(B"]) ("xwo" ["$B$&$)(B"])

("shi" "$B$7(B") ("tyi" ["$B$F$#(B"]) ("chi" "$B$A(B") ("tsu" "$B$D(B") ("ji" "$B$8(B")
("fu"  "$B$U(B")
("ye" ["$B$$$'(B"])

("va" ["$B%t$!(B"]) ("vi" ["$B%t$#(B"]) ("vu" "$B%t(B") ("ve" ["$B%t$'(B"]) ("vo" ["$B%t$)(B"])

("xa"  "$B$!(B") ("xi"  "$B$#(B") ("xu"  "$B$%(B") ("xe"  "$B$'(B") ("xo"  "$B$)(B")
("xtu" "$B$C(B") ("xya" "$B$c(B") ("xyu" "$B$e(B") ("xyo" "$B$g(B") ("xwa" "$B$n(B")
("xka" "$B%u(B") ("xke" "$B%v(B")

("1" "$B#1(B") ("2" "$B#2(B") ("3" "$B#3(B") ("4" "$B#4(B") ("5" "$B#5(B")
("6" "$B#6(B") ("7" "$B#7(B") ("8" "$B#8(B") ("9" "$B#9(B") ("0" "$B#0(B")

("!" "$B!*(B") ("@" "$B!w(B") ("#" "$B!t(B") ("$" "$B!p(B") ("%" "$B!s(B")
("^" "$B!0(B") ("&" "$B!u(B") ("*" "$B!v(B") ("(" "$B!J(B") (")" "$B!K(B")
("-" "$B!<(B") ("=" "$B!a(B") ("`" "$B!.(B") ("\\" "$B!o(B") ("|" "$B!C(B")
("_" "$B!2(B") ("+" "$B!\(B") ("~" "$B!1(B") ("[" "$B!V(B") ("]" "$B!W(B")
("{" "$B!P(B") ("}" "$B!Q(B") (":" "$B!'(B") (";" "$B!((B") ("\""  "$B!I(B")
("'" "$B!G(B") ("." "$B!#(B") ("," "$B!"(B") ("<" "$B!c(B") (">" "$B!d(B")
("?" "$B!)(B") ("/" "$B!?(B")

("z1" "$B!{(B") ("z!" "$B!|(B")
("z2" "$B"&(B") ("z@" "$B"'(B")
("z3" "$B"$(B") ("z#" "$B"%(B")
("z4" "$B""(B") ("z$" "$B"#(B")
("z5" "$B!~(B") ("z%" "$B"!(B")
("z6" "$B!y(B") ("z^" "$B!z(B")
("z7" "$B!}(B") ("z&" "$B!r(B")
("z8" "$B!q(B") ("z*" "$B!_(B")
("z9" "$B!i(B") ("z(" "$B!Z(B")
("z0" "$B!j(B") ("z)" "$B![(B")
("z-" "$B!A(B") ("z_" "$B!h(B")
("z=" "$B!b(B") ("z+" "$B!^(B")
("z\\" "$B!@(B") ("z|" "$B!B(B")
("z`" "$B!-(B") ("z~" "$B!/(B")

("zq" "$B!T(B") ("zQ" "$B!R(B")
("zw" "$B!U(B") ("zW" "$B!S(B")
("zr" "$B!9(B") ("zR" "$B!8(B")
("zt" "$B!:(B") ("zT" "$B!x(B")
("zp" "$B")(B") ("zP" "$B",(B")
("z[" "$B!X(B") ("z{" "$B!L(B")
("z]" "$B!Y(B") ("z}" "$B!M(B")

("zs" "$B!3(B") ("zS" "$B!4(B")
("zd" "$B!5(B") ("zD" "$B!6(B")
("zf" "$B!7(B") ("zF" "$B"*(B")
("zg" "$B!>(B") ("zG" "$B!=(B")
("zh" "$B"+(B")
("zj" "$B"-(B")
("zk" "$B",(B")
("zl" "$B"*(B")
("z;" "$B!+(B") ("z:" "$B!,(B")
("z\'" "$B!F(B") ("z\"" "$B!H(B")

("zx" ":-") ("zX" ":-)")
("zc" "$B!;(B") ("zC" "$B!n(B")
("zv" "$B"((B") ("zV" "$B!`(B")
("zb" "$B!k(B") ("zB" "$B"+(B")
("zn" "$B!l(B") ("zN" "$B"-(B")
("zm" "$B!m(B") ("zM" "$B".(B")
("z," "$B!E(B") ("z<" "$B!e(B")
("z." "$B!D(B") ("z>" "$B!f(B")
("z/" "$B!&(B") ("z?" "$B!g(B")

("\\\\" quail-japanese-self-insert-and-switch-to-alpha)
("{{" quail-japanese-self-insert-and-switch-to-alpha)
("}}" quail-japanese-self-insert-and-switch-to-alpha)

("qq" quail-japanese-switch-package)
("qz" quail-japanese-switch-package)

)

(quail-define-package
 "japanese-ascii" "Japanese" "Aa"
 nil
 "Temporary ASCII input mode while using Quail package `japanese'
Type \"qq\" to go back to previous package."
 nil t t)

(quail-define-rules ("qq" quail-japanese-switch-package))

(quail-define-package
 "japanese-zenkaku" "Japanese" "$B#A(B"
 nil
 "Japanese zenkaku alpha numeric character input method
---- Special key bindings ----
qq:	toggle between `japanese-zenkaku' and `japanese-ascii'
qh:	use `japanese' package, \"qz\" puts you back to `japanese-zenkaku'
"
 nil t t)

(quail-define-rules

(" " "$B!!(B") ("!" "$B!*(B") ("\"" "$B!m(B") ("#" "$B!t(B")
("$" "$B!p(B") ("%" "$B!s(B") ("&" "$B!u(B") ("'" "$B!l(B")
("(" "$B!J(B") (")" "$B!K(B") ("*" "$B!v(B") ("+" "$B!\(B")
("," "$B!$(B") ("-" "$B!](B") ("." "$B!%(B") ("/" "$B!?(B")
("0" "$B#0(B") ("1" "$B#1(B") ("2" "$B#2(B") ("3" "$B#3(B")
("4" "$B#4(B") ("5" "$B#5(B") ("6" "$B#6(B") ("7" "$B#7(B")
("8" "$B#8(B") ("9" "$B#9(B") (":" "$B!'(B") (";" "$B!((B")
("<" "$B!c(B") ("=" "$B!a(B") (">" "$B!d(B") ("?" "$B!)(B")
("@" "$B!w(B") ("A" "$B#A(B") ("B" "$B#B(B") ("C" "$B#C(B")
("D" "$B#D(B") ("E" "$B#E(B") ("F" "$B#F(B") ("G" "$B#G(B")
("H" "$B#H(B") ("I" "$B#I(B") ("J" "$B#J(B") ("K" "$B#K(B")
("L" "$B#L(B") ("M" "$B#M(B") ("N" "$B#N(B") ("O" "$B#O(B")
("P" "$B#P(B") ("Q" "$B#Q(B") ("R" "$B#R(B") ("S" "$B#S(B")
("T" "$B#T(B") ("U" "$B#U(B") ("V" "$B#V(B") ("W" "$B#W(B")
("X" "$B#X(B") ("Y" "$B#Y(B") ("Z" "$B#Z(B") ("[" "$B!N(B")
("\\" "$B!o(B") ("]" "$B!O(B") ("^" "$B!0(B") ("_" "$B!2(B")
("`" "$B!F(B") ("a" "$B#a(B") ("b" "$B#b(B") ("c" "$B#c(B")
("d" "$B#d(B") ("e" "$B#e(B") ("f" "$B#f(B") ("g" "$B#g(B")
("h" "$B#h(B") ("i" "$B#i(B") ("j" "$B#j(B") ("k" "$B#k(B")
("l" "$B#l(B") ("m" "$B#m(B") ("n" "$B#n(B") ("o" "$B#o(B")
("p" "$B#p(B") ("q" "$B#q(B") ("r" "$B#r(B") ("s" "$B#s(B")
("t" "$B#t(B") ("u" "$B#u(B") ("v" "$B#v(B") ("w" "$B#w(B")
("x" "$B#x(B") ("y" "$B#y(B") ("z" "$B#z(B") ("{" "$B!P(B")
("|" "$B!C(B") ("}" "$B!Q(B") ("~" "$B!A(B") 

("qq" quail-japanese-switch-package)
("qh" quail-japanese-switch-package)
)

(defun quail-japanese-hankaku-update-translation (control-flag)
  (cond ((eq control-flag t)
	 (insert (japanese-hankaku quail-current-str))
	 (quail-terminate-translation))
	((null control-flag)
	 (insert (if quail-current-str
		     (japanese-hankaku quail-current-str)
		   quail-current-key)))
	(t				; i.e. (numberp control-flag)
	 (cond ((= (aref quail-current-key 0) ?n)
		(insert ?(I](B))
	       ((= (aref quail-current-key 0) (aref quail-current-key 1))
		(insert ?(I/(B))
	       (t
		(insert (aref quail-current-key 0))))
	 (setq unread-command-events
	       (list (aref quail-current-key control-flag)))
	 (quail-terminate-translation))))


(quail-define-package
 "japanese-hankaku-kana"
 "Japanese" "(I1(B"
 nil
 "Japanese hankaku katakana input method by Roman transliteration
---- Special key bindings ----
qq:	toggle between `japanese-hankaku-kana' and `japanese-ascii'
"
 nil t t nil nil nil nil nil
 'quail-japanese-hankaku-update-translation)

;; Use the same map as that of `japanese'.
(setcar (cdr (cdr quail-current-package))
	(nth 2 (assoc "japanese" quail-package-alist)))

(quail-define-package
 "japanese-hiragana" "Japanese" "$B$"(B"
 nil
 "Japanese hiragana input method by Roman transliteration"
 nil t t nil nil nil nil nil
 'quail-japanese-update-translation)

;; Use the same map as that of `japanese'.
(setcar (cdr (cdr quail-current-package))
	(nth 2 (assoc "japanese" quail-package-alist)))

;; Update Quail translation region while converting Hiragana to Katakana.
(defun quail-japanese-katakana-update-translation (control-flag)
  (cond ((eq control-flag t)
	 (insert (japanese-katakana quail-current-str))
	 (quail-terminate-translation))
	((null control-flag)
	 (insert (if quail-current-str
		     (japanese-katakana quail-current-str)
		   quail-current-key)))
	(t				; i.e. (numberp control-flag)
	 (cond ((= (aref quail-current-key 0) ?n)
		(insert ?$B%s(B))
	       ((= (aref quail-current-key 0) (aref quail-current-key 1))
		(insert ?$B%C(B))
	       (t
		(insert (aref quail-current-key 0))))
	 (setq unread-command-events
	       (list (aref quail-current-key control-flag)))
	 (quail-terminate-translation))))

(quail-define-package 
 "japanese-katakana" "Japanese" "$B%"(B"
 nil
 "Japanese katakana input method by Roman transliteration"
 nil t t nil nil nil nil nil
 'quail-japanese-katakana-update-translation)

;; Use the same map as that of `japanese'.
(setcar (cdr (cdr quail-current-package))
	(nth 2 (assoc "japanese" quail-package-alist)))
