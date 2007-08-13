;;; skk-auto.el --- $BAw$j2>L>$N<+F0=hM}$N$?$a$N%W%m%0%i%`(B
;; Copyright (C) 1988, 1989, 1990, 1991, 1992, 1993, 1994, 1995, 1996, 1997
;; Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>

;; Author: Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>
;; Maintainer: Mikio Nakajima <minakaji@osaka.email.ne.jp>
;; Version: $Id: skk-auto.el,v 1.1 1997/12/02 08:48:37 steve Exp $
;; Keywords: japanese
;; Last Modified: $Date: 1997/12/02 08:48:37 $

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
;; Following people contributed modifications to skk-server.el (Alphabetic
;; order):
;;
;;      Mikio Nakajima <minakaji@osaka.email.ne.jp>

;;; Change log:
;; version 1.0.6 released 1997.2.18 (derived from the skk.el 8.6)

;;; Code:
(require 'skk-foreword)
(require 'skk-vars)

;;; user variables
(defvar skk-kana-rom-vector
  ["x" "a" "x" "i" "x" "u" "x" "e" "x" "o" "k" "g" "k" "g" "k" "g"
   "k" "g" "k" "g" "s" "z" "s" "j" "s" "z" "s" "z" "s" "z" "t" "d"
   "t" "d" "x" "t" "d" "t" "d" "t" "d" "n" "n" "n" "n" "n" "h" "b"
   "p" "h" "b" "p" "h" "b" "p" "h" "b" "p" "h" "b" "p" "m" "m" "m"
   "m" "m" "x" "y" "x" "y" "x" "y" "r" "r" "r" "r" "r" "x" "w" "x"
   "x" "w" "n"]
  "*skk-remove-common $B$G;HMQ$9$k$+$JJ8;z$+$i%m!<%^;z$X$NJQ49%k!<%k!#(B
$B2<5-$N3:Ev$9$k$+$JJ8;z$r$=$NJ8;z$N%m!<%^;z%W%l%U%#%C%/%9$G8=$o$7$?$b$N!#(B
    $B$!(B  $B$"(B  $B$#(B  $B$$(B  $B$%(B  $B$&(B  $B$'(B  $B$((B  $B$)(B  $B$*(B  $B$+(B  $B$,(B  $B$-(B  $B$.(B  $B$/(B  $B$0(B
    $B$1(B  $B$2(B  $B$3(B  $B$4(B  $B$5(B  $B$6(B  $B$7(B  $B$8(B  $B$9(B  $B$:(B  $B$;(B  $B$<(B  $B$=(B  $B$>(B  $B$?(B  $B$@(B
    $B$A(B  $B$B(B  $B$C(B  $B$D(B  $B$E(B  $B$F(B  $B$G(B  $B$H(B  $B$I(B  $B$J(B  $B$K(B  $B$L(B  $B$M(B  $B$N(B  $B$O(B  $B$P(B
    $B$Q(B  $B$R(B  $B$S(B  $B$T(B  $B$U(B  $B$V(B  $B$W(B  $B$X(B  $B$Y(B  $B$Z(B  $B$[(B  $B$\(B  $B$](B  $B$^(B  $B$_(B  $B$`(B
    $B$a(B  $B$b(B  $B$c(B  $B$d(B  $B$e(B  $B$f(B  $B$g(B  $B$h(B  $B$i(B  $B$j(B  $B$k(B  $B$l(B  $B$m(B  $B$n(B  $B$o(B  $B$p(B
    $B$q(B  $B$r(B  $B$s(B
$B$=$l$>$l$N$+$JJ8;z$,Aw$j2>L>$G$"$k>l9g$K$I$N%m!<%^;z%W%l%U%#%C%/%9$rBP1~$5$;$k(B
$B$N$+$r;XDj$9$k$3$H$,$G$-$k!#!V$8!W!"!V$A!W!"!V$U!W$NJ8;z$K$D$$$F!"BP1~$9$k%m!<(B
$B%^;z%W%l%U%#%C%/%9$r(B \"z\", \"c\",\"f\" $B$KJQ99$r4uK>$9$k>l9g$b$"$k$G$"$m$&!#(B
skk-auto-okuri-process $B$NCM$,(B non-nil $B$N$H$-$N$_;2>H$5$l$k!#(B" )

(defvar skk-auto-load-hook nil
  "*skk-auto.el $B$r%m!<%I$7$?8e$K%3!<%k$5$l$k%U%C%/!#(B" )

;; internal valriables
;;;###skk-autoload
(skk-deflocalvar skk-henkan-in-minibuff-flag nil
  "$B%_%K%P%C%U%!$G<-=qEPO?$r9T$C$?$H$-$K$3$N%U%i%0$,N)$D!#(B
skk-remove-common $B$G;2>H$5$l$k!#(B" )

(skk-deflocalvar skk-okuri-index-min -1
  "skk-henkan-list $B$N%$%s%G%/%9$G<+F0Aw$j=hM}$G8!:w$7$?:G=i$N8uJd$r;X$9$b$N!#(B" )

(skk-deflocalvar skk-okuri-index-max -1
  "skk-henkan-list $B$N%$%s%G%/%9$G<+F0Aw$j=hM}$G8!:w$7$?:G8e$N8uJd$r;X$9$b$N!#(B" )

(defun skk-okuri-search ()
  ;; skk-auto-okuri-process $B$,(B non-nil $B$J$i$P(B "Uresii" $B$N$h$&$KAw$j2>L>$b4^$a(B
  ;; $B$F%?%$%W$7$F$bAw$j$"$j$N(B "$B4r$7$$(B" $B$rC5$7=P$9!#(B
  (if (and skk-auto-okuri-process
           (not (or skk-abbrev-mode skk-process-okuri-early
                    skk-henkan-okurigana ))
           ;; we don't do auto-okuri-process if henkan key contains numerals.
           (not (skk-numeric-p))
           (> (length skk-henkan-key) skk-kanji-len) )
      (let (l)
        (setq skk-okuri-index-min (length skk-henkan-list)
              l (skk-okuri-search-subr)
              skk-okuri-index-max (+ skk-okuri-index-min (length l)) )
        l )))

(defun skk-okuri-search-subr ()
  ;; skk-okuri-search $B$N%5%V%k!<%A%s!#8+$D$1$?%(%s%H%j$N%j%9%H$rJV$9!#(B
  (let* ((henkan-key skk-henkan-key)
         (key (substring henkan-key 0 skk-kanji-len))
         (len (length henkan-key))
         (key1 (concat "\n" key))
         key2 len2 key3 len3 okuri3
         ;; $B8zN($,NI$$$h$&$K(B kanji-flag, mc-flag, enable-multibyte-characters
         ;; $B$r(B nil $B$K$7$F$*$/!#(B
         mc-flag
         ;; enable-multibyte-characters
         ;; case-fold-search $B$O!"<-=q%P%C%U%!$G$O>o$K(B nil$B!#(B
         ;;case-fold-search
         (inhibit-quit t)
         key-cand-alist p q r s )
    (save-match-data
      (with-current-buffer (skk-get-jisyo-buffer skk-jisyo)
        (goto-char skk-okuri-ari-min)
        (while (search-forward key1 skk-okuri-ari-max t)
          (setq p (point)
                key2 (concat key (skk-buffer-substring
                                  p (- (search-forward " ") 2) ))
                len2 (length key2) )
          (if (not (and (<= len2 len)
                        (string= key2 (substring henkan-key 0 len2)) ))
              nil
            (let ((cont t))
              (skk-save-point
               (end-of-line)
               (setq q (point)) )
              (while (and cont (search-forward "/[" q t))
                (setq r (point))
                (setq okuri3 (skk-buffer-substring r (1- (search-forward "/")))
                      key3 (concat key2 okuri3)
                      len3 (length key3) )
                (if (not (and (<= len3 len)
                              (string= key3 (substring henkan-key 0 len3)) ))
                    nil
                  ;; finally found a candidate!
                  (let ((okuri
                         (concat okuri3 (substring henkan-key len3 len)) )
                        cand )
                    (while (not (eq (following-char) ?\]))
                      (setq cand
                            (concat
                             (skk-buffer-substring
                              (point)
                              (1- (search-forward "/" skk-okuri-ari-max t)) )
                             okuri ))
                      ;; $B8+=P$78l$,0c$C$F$b8uJd$,F1$8$3$H$,$"$jF@$k!#(B
                      ;;   $B$+$s(Bz /$B46(B/[$B$8(B/$B46(B/]/
                      ;;   $B$+$s(Bj /$B46(B/[$B$8(B/$B46(B/]/
                      ;; $B$J$I!#(B
                      (if (null (rassoc cand key-cand-alist))
                          (setq key-cand-alist (cons (cons key3 cand)
                                                     key-cand-alist ))))
                    ;; it is not necessary to seach for "\[" on this line
                    ;; any more
                    (setq cont nil) ))))))
        ;; key3 $B$ND9$$$b$N=g$K%=!<%H$7$FJV$9!#(B
        (mapcar (function
                 (lambda (x) (cdr x)) )
                (sort (nreverse key-cand-alist)
                      (function (lambda (x y)
                                  (string< (car y) (car x)) ))))))))

;;;###skk-autoload
(defun skk-remove-common (word)
  ;; skk-henkan-key $B$H(B word $B$N4V$K6&DL$NAw$j2>L>$r<h$j=|$-!"Aw$j2>L>0J30$NItJ,(B
  ;; $B$NJ8;zNs$rJV$9!#(Bskk-henkan-key $B$H(B skk-henkan-okurigana $B$NCM$r%;%C%H$9$k!#(B
  ;; $BNc$($P!"(Bword == $B;}$C$F$-$?(B $B$G$"$l$P!"(Bskk-henkan-key := "$B$b(Bt",
  ;; skk-henkan-okurigana := "$B$C$F(B", word := "$B;}(B" $B$N$h$&$KJ,2r$7!"(Bword $B$rJV$9!#(B
  ;; skk-auto-okuri-process $B$NCM$,(B non-nil $B$G$"$k$H$-$K$3$N4X?t$r;HMQ$9$k!#(B
  (if (and (not (skk-numeric-p)) (not skk-abbrev-mode)
           (or skk-henkan-in-minibuff-flag
               (and (<= skk-okuri-index-min skk-henkan-count)
                    (<= skk-henkan-count skk-okuri-index-max) )))
      (let ((midasi skk-henkan-key)
            (midasi-len (length skk-henkan-key))
            (word-len (length word))
            (kanji-len2 (* 2 skk-kanji-len))
            (mc-flag t)
            (enable-multibyte-characters t)
            (cont t)
            char pos pos2 midasi-tail word-tail new-word okuri-first
            new-skk-henkan-key )
        (if (not (and (>= midasi-len kanji-len2) (>= word-len kanji-len2)))
            nil
          ;; check if both midasi and word end with the same ascii char.
          (if (and (eq (aref midasi (1- midasi-len)) (aref word (1- word-len)))
                   (skk-alpha-char-p (aref midasi (1- midasi-len))) )
              ;; if so chop off the char from midasi and word
              (setq midasi (substring midasi 0 -1)
                    midasi-len (1- midasi-len)
                    word (substring word 0 -1)
                    word-len (1- word-len) ))
          (setq midasi-tail (substring midasi (- midasi-len skk-kanji-len)
                                       midasi-len )
                word-tail (substring word (- word-len skk-kanji-len)
                                     word-len ))
          ;; $B$b$&>/$7E83+$G$-$=$&$@$,!"%P%$%H%3%s%Q%$%i!<$,%*%W%F%#%^%$%:$7$d(B
          ;; $B$9$$$h$&$K(B not $B$rIU$1$k$@$1$K$7$F$*$/!#(B
          (if (not (and (string= midasi-tail word-tail)
                        (or (and (skk-string<= "$B$!(B" midasi-tail)
                                 (skk-string<= midasi-tail "$B$s(B") )
                            (member midasi-tail '("$B!"(B" "$B!#(B" "$B!$(B" "$B!%(B")) )))
              nil
            (setq pos (- word-len skk-kanji-len)
                  new-word new-skk-henkan-key )
            (while (and cont (> pos 0))
              (setq char (substring word (- pos skk-kanji-len) pos))
              (if (and (skk-string<= "$B0!(B" char) (skk-string<= char "$Bt$(B"))
                  ;; char is the right-most Kanji
                  (setq cont nil)
                (setq pos (- pos skk-kanji-len)) ))
            (setq pos2 (- midasi-len (- word-len pos)))
            ;; check if midasi and word has the same tail of length
            (if (not (string= (substring midasi pos2 midasi-len)
                              (substring word pos word-len) ))
                nil
              (setq okuri-first (substring word pos (+ pos skk-kanji-len)))
              (setq skk-henkan-okurigana
                    (if (and (string= okuri-first "$B$C(B")
                             (<= (+ pos kanji-len2) word-len) )
                        ;; in this case okuriga consits of two
                        ;; characters, e.g., $B!V;D$C$?!W(B
                        (substring word pos (+ pos kanji-len2))
                      okuri-first ))
              (setq new-word (substring word 0 pos))
              (setq new-skk-henkan-key
                    (concat
                     (substring midasi 0 pos2)
                     (cond ((string= okuri-first "$B$s(B")
                            "n" )
                           ((string= okuri-first "$B$C(B")
                            (aref skk-kana-rom-vector
                                  (- (string-to-char
                                      (substring
                                       skk-henkan-okurigana
                                       (1- kanji-len2) kanji-len2 ))
                                     161 )))
                           (t (aref skk-kana-rom-vector
                                    (- (string-to-char
                                        (substring
                                         skk-henkan-okurigana
                                         (1- skk-kanji-len)
                                         skk-kanji-len ))
                                       161 ))))))
              (if (not skk-henkan-in-minibuff-flag)
                  (setq word new-word
                        skk-henkan-key new-skk-henkan-key )
                ;; ask if register as okuri-ari word.
                (let (inhibit-quit) ; allow keyboard quit
                  (if (y-or-n-p
                       (format
                        (if skk-japanese-message-and-error
                            "%s /%s/ $B$rAw$j$"$j%(%s%H%j$H$7$FEPO?$7$^$9$+!)(B"
                          "Shall I register this as okuri-ari entry: %s /%s/ ? " )
                        new-skk-henkan-key new-word ))
                      (setq word new-word
                            skk-henkan-key new-skk-henkan-key )
                    (setq skk-henkan-okurigana nil
                          skk-okuri-char nil )
                    (message "") ))))))))
  ;; $BJ,2r$7$?(B word ($BAw$j2>L>ItJ,$r=|$$$?$b$N(B) $B$rJV$9!#(B
  word )

;;;###skk-autoload
(defun skk-init-auto-okuri-variables ()
  ;; skk-auto.el $B$NFbItJQ?t$r=i4|2=$9$k!#(B
  (setq skk-henkan-in-minibuff-flag nil
        skk-okuri-index-min -1
        skk-okuri-index-max -1 ))

;;;###skk-autoload
(defun skk-adjust-search-prog-list-for-auto-okuri ()
  ;; skk-auto-okuri-process $B$,(B nil $B$G$"$l$P!"(Bskk-search-prog-list $B$+$i(B 
  ;; '(skk-okuri-search) $B$r>C$7!"(Bnon-nil $B$G$"$l$P2C$($k!#(B
  ;;
  ;; '(skk-okuri-search) $B$r2C$($k0LCV$K$D$$$F$O!"(Bskk-jisyo $B$N8e$,:GNI$+$I$&$+(B
  ;; $B$OJ,$i$J$$$N$G!"%*%W%7%g%s$GJQ99$G$-$k$h$&$K$9$Y$-$@$,(B...$B!#(B
  (if (not skk-auto-okuri-process)
      (setq skk-search-prog-list
            (delete '(skk-okuri-search) skk-search-prog-list) )
      (if (null (member '(skk-okuri-search) skk-search-prog-list))
          (let ((pl skk-search-prog-list)
                (n 0) dic mark )
            (while pl
              (setq dic (car pl))
              (if (eq (nth 1 dic) 'skk-jisyo)
                  (setq mark n
                        pl nil)
                (setq pl (cdr pl)
                      n (1+ n) )))
            (skk-middle-list skk-search-prog-list
                             (1+ mark) '((skk-okuri-search)) )))))

;;(add-hook 'skk-mode-hook 'skk-adjust-search-prog-list-for-auto-okuri)

(run-hooks 'skk-auto-load-hook)
(provide 'skk-auto)
;;; skk-auto.el ends here
