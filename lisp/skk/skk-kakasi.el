;;; skk-kakasi.el --- KAKASI $B4XO"%W%m%0%i%`(B
;; Copyright (C) 1996 Mikio Nakajima <minakaji@osaka.email.ne.jp>

;; Author: Mikio Nakajima <minakaji@osaka.email.ne.jp>
;; Version: $Id: skk-kakasi.el,v 1.1 1997/12/02 08:48:37 steve Exp $
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

;; skk-kakasi.el $B$O(B KAKASI $B$r(B SKK $B$NCf$+$i;H$&%$%s%?!<%U%'%$%9$G$9!#(BKAKASI $B$O!"(B
;; $B9b66M5?.$5$s(B <takahasi@tiny.or.jp> $B$K$h$k!"!V4A;z$+$J$^$8$jJ8$r$R$i$,$JJ8$d(B
;; $B%m!<%^;zJ8$KJQ49$9$k$3$H$rL\E*$H$7$F:n@.$7$?%W%m%0%i%`$H<-=q$NAm>N!W$G$9!#(B
;; $B;d<+?H$,%K%e!<%9$d%a!<%k$rFI$s$G$$$F!"F|>oFI$_$,J,$i$J$/$FCQ$:$+$7$$;W$$$r(B
;; $B$9$k$3$H$,B?$$$N$G!"5U0z$-$r$7$?$/$F:n$j$^$7$?!#(B
;;
;; $B!L$3$N$N%$%s%9%H!<%kJ}K!!M(B
;;  skk.el 9.4 $B$+$i$O@_DjITMW$K$J$kM=Dj$G$9$,!"$=$l0JA0$N%P!<%8%g%s$N(B skk.el
;; $B$r$*;H$$$N>l9g$O!"2<5-$N%U%)!<%`$rI>2A$9$l$P(B OK $B$G$9!#(BEmacs $B$N5/F0Kh$K$3$N(B
;; $B@_Dj$,M-8z$K$J$k$h$&$K$9$k$?$a$K$O!"(B~/.emacs $B$K2<5-%U%)!<%`$rA^F~$7$F$7$^$&(B
;; $B$N$,$*<j7Z$G$9!#(B
;;
;;    (autoload 'skk-gyakubiki-katakana-message "skk-kakasi" nil t)
;;    (autoload 'skk-gyakubiki-katakana-region "skk-kakasi" nil t)
;;    (autoload 'skk-gyakubiki-message "skk-kakasi" nil t)
;;    (autoload 'skk-gyakubiki-region "skk-kakasi" nil t)
;;    (autoload 'skk-hurigana-katakana-message "skk-kakasi" nil t)
;;    (autoload 'skk-hurigana-katakana-region "skk-kakasi" nil t)
;;    (autoload 'skk-hurigana-message "skk-kakasi" nil t)
;;    (autoload 'skk-hurigana-region "skk-kakasi" nil t)
;;    (autoload 'skk-romaji-message "skk-kakasi" nil t)
;;    (autoload 'skk-romaji-region "skk-kakasi" nil t)
;;
;; KAKASI $B$O!"(B1996 $BG/(B 4 $B7n(B 25 $BF|8=:_!"(B
;; sunsite.sut.ac.jp:/pub/asia-info/japanese-src/packages/kakasi-2.2.5.tar.gz
;; sunsite.sut.ac.jp:/pub/asia-info/japanese-src/packages/kakasidict.940620.gz
;; $B$K$"$j(B anonymous ftp $B$GF~<j$G$-$^$9!#(B
;;
;; $BAG@2$7$$%W%m%0%i%`(B KAKASI $B$r$*:n$j$K$J$C$?9b66$5$s$H!"(BKAKASI $B$r(B anonymous
;; ftp $B$GF~<j2DG=$H$7$F$$$k(B sunsite.sut.ac.jp $B$K46<U$$$?$7$^$9!#(B

;;; Change log:

;;; Code:
(require 'skk-foreword)
(require 'skk-vars)

;;;;  VARIABLES

;; --- user variable

(defvar skk-use-kakasi
  (or (and (file-exists-p "/usr/local/bin/kakasi")
           (file-executable-p "/usr/local/bin/kakasi") )
      (eq (call-process "which" nil nil nil "kakasi") 0) )
  ;; tcsh $B$O(B built-in $B%3%^%s%I$H$7$F(B which $B$r;}$C$F$$$k!#(BLinux $B$@$H(B sh ($B<B$O<B(B
  ;; $BBN$O(B bash) $B$G$b(B /usr/bin/which $B$,;H$($k!#B>$N%7%9%F%`$G$O$I$&$9$Y$-!)(B
  "*Non-nil $B$G$"$l$P(B KAKASI $B$r;H$C$?JQ49$r9T$J$&!#(B" )

(defvar skk-romaji-*-by-hepburn t
  "*Non-nil $B$G$"$l$P(B KAKASI $B$r;H$C$?%m!<%^;z$X$NJQ49MM<0$K%X%\%s<0$rMQ$$$k!#(B
$BNc$($P!"(B
  \"$B$7(B\" -> \"shi\"

nil $B$G$"$l$P!"71Na<0(B \"($B!VF|K\<0!W$H$b8@$&$h$&$@(B)\" $B$rMQ$$$k!#(B
$BNc$($P!"(B
   \"$B$7(B\" -> \"si\"

$B><OB(B 29 $BG/(B 12 $B7n(B 9 $BF|IUFb3U9p<(Bh0l9f$K$h$l$P!"86B'E*$K71Na<0(B \"($BF|K\<0(B)\" $B$r(B
$BMQ$$$k$+$N$h$&$K5-:\$5$l$F$$$k$,!":#F|0lHLE*$J5-:\J}K!$O!"$`$7$m!"%X%\%s<0$G$"(B
$B$k$h$&$K;W$&!#(B" )

(defvar skk-kakasi-load-hook nil
  "*skk-kakasi.el $B$,%m!<%I$5$l$?$H$-$N%U%C%/!#(B" )

(if skk-mule3
    (modify-coding-system-alist 'process "kakasi"
                             '(undecided . euc-japan) ))

;;;; FUNCTIONS
;;;###skk-autoload
(defun skk-gyakubiki-region (start end &optional all)
  "$B%j!<%8%g%s$N4A;z!"Aw$j2>L>$rA4$F$R$i$,$J$KJQ49$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B$J$+$7$^(B|$B$J$+$8$^(B}"
  (interactive "*r\nP")
  (let ((str (skk-gyakubiki-1 start end all)))
    (combine-after-change-calls
      (delete-region start end)
      (goto-char start)
      (insert str) )
    (skk-set-cursor-properly) ))

;;;###skk-autoload
(defun skk-gyakubiki-message (start end &optional all)
  "$B%j!<%8%g%s$N4A;z!"Aw$j2>L>$rA4$F$R$i$,$J$KJQ498e!"%(%3!<$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B$J$+$7$^(B|$B$J$+$8$^(B}"
  (interactive "r\nP")
  (let ((str (skk-gyakubiki-1 start end all)))
    (save-match-data
      (if (string-match "^[ $B!!(B\t]+" str)
          ;; $B@hF,$N6uGr$r<h$j=|$/!#(B
          (setq str (substring str (match-end 0))) ))
    (message str)
    (skk-set-cursor-properly) ))
        

;;;###skk-autoload
(defun skk-gyakubiki-katakana-region (start end &optional all)
  "$B%j!<%8%g%s$N4A;z!"Aw$j2>L>$rA4$F%+%?%+%J$KJQ49$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B%J%+%7%^(B|$B%J%+%8%^(B}"
  (interactive "*r\P")
  (let ((str (skk-gyakubiki-1 start end all 'katakana)))
    (combine-after-change-calls
      (delete-region start end)
      (goto-char start)
      (insert str) )
    (skk-set-cursor-properly) ))

;;;###skk-autoload
(defun skk-gyakubiki-katakana-message (start end &optional all)
  "$B%j!<%8%g%s$N4A;z!"Aw$j2>L>$rA4$F%+%?%+%J$KJQ498e!"%(%3!<$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B%J%+%7%^(B|$B%J%+%8%^(B}"
  (interactive "r\nP")
  (let ((str (skk-gyakubiki-1 start end all 'katakana)))
    (save-match-data
      (if (string-match "^[ $B!!(B\t]+" str)
          ;; $B@hF,$N6uGr$r<h$j=|$/!#(B
          (setq str (substring str (match-end 0))) ))
    (message str)
    (skk-set-cursor-properly) ))

(defun skk-gyakubiki-1 (start end all &optional katakana)
  ;; skk-gyakubiki-* $B$N%5%V%k!<%A%s!#(B
  ;; $B%*%W%7%g%J%k0z?t$N(B KATAKANA $B$,(B non-nil $B$G$"$l$P!"%+%?%+%J$XJQ49$9$k!#(B
  (let ((arg (if katakana '("-JK") '("-JH"))))
    (if skk-allow-spaces-newlines-and-tabs
        (setq arg (cons "-c" arg)) )
    (if all
        (setq arg (cons "-p" arg)) )
    (skk-kakasi-region start end arg)) )

;;;###skk-autoload
(defun skk-hurigana-region (start end &optional all)
  "$B%j!<%8%g%s$N4A;z$KA4$F$U$j$,$J$rIU$1$k!#(B
$BNc$($P!"(B
   \"$BJQ49A0$N4A;z$NOF$K(B\" -> \"$BJQ49A0(B[$B$X$s$+$s$^$((B]$B$N4A;z(B[$B$+$s$8(B]$B$NOF(B[$B$o$-(B]$B$K(B\"

$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B$J$+$7$^(B|$B$J$+$8$^(B}"
  (interactive "*r\nP")
  (let ((str (skk-hurigana-1 start end all)))
    (combine-after-change-calls
      (delete-region start end)
      (goto-char start)
      (insert str) )
    (skk-set-cursor-properly) ))

;;;###skk-autoload
(defun skk-hurigana-message (start end &optional all)
  "$B%j!<%8%g%s$N4A;z$KA4$F$U$j$,$J$rIU$1!"%(%3!<$9$k!#(B
$BNc$($P!"(B
   \"$BJQ49A0$N4A;z$NOF$K(B\" -> \"$BJQ49A0(B[$B$X$s$+$s$^$((B]$B$N4A;z(B[$B$+$s$8(B]$B$NOF(B[$B$o$-(B]$B$K(B\"

$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B$J$+$7$^(B|$B$J$+$8$^(B}"
  (interactive "r\nP")
  (message (skk-hurigana-1 start end all))
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-hurigana-katakana-region (start end &optional all)
  "$B%j!<%8%g%s$N4A;z$KA4$F%U%j%,%J$rIU$1$k!#(B
$BNc$($P!"(B
   \"$BJQ49A0$N4A;z$NOF$K(B\" -> \"$BJQ49A0(B[$B%X%s%+%s%^%((B]$B$N4A;z(B[$B%+%s%8(B]$B$NOF(B[$B%o%-(B]$B$K(B\"

$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B%J%+%7%^(B|$B%J%+%8%^(B}"
  (interactive "*r\nP")
  (let ((str (skk-hurigana-1 start end all 'katakana)))
    (combine-after-change-calls
      (delete-region start end)
      (goto-char start)
      (insert str) )
    (skk-set-cursor-properly) ))

;;;###skk-autoload
(defun skk-hurigana-katakana-message (start end &optional all)
  "$B%j!<%8%g%s$N4A;z$KA4$F%U%j%,%J$rIU$1!"%(%3!<$9$k!#(B
$BNc$($P!"(B
   \"$BJQ49A0$N4A;z$NOF$K(B\" -> \"$BJQ49A0(B[$B%X%s%+%s%^%((B]$B$N4A;z(B[$B%+%s%8(B]$B$NOF(B[$B%o%-(B]$B$K(B\"

$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B%J%+%7%^(B|$B%J%+%8%^(B}"
  (interactive "r\nP")
  (message (skk-hurigana-1 start end all 'katakana))
  (skk-set-cursor-properly) )

(defun skk-hurigana-1 (start end all &optional katakana)
  ;; skk-hurigana-* $B$N%5%V%k!<%A%s!#(B
  ;; $B%*%W%7%g%J%k0z?t$N(B KATAKANA $B$,(B non-nil $B$G$"$l$P!"%+%?%+%J$XJQ49$9$k!#(B
  (let ((arg (if katakana '("-JK" "-f") '("-JH" "-f")))
        str )
    (if skk-allow-spaces-newlines-and-tabs
        (setq arg (cons "-c" arg)) )
    (if all
        (setq arg (cons "-p" arg)) )
    (skk-kakasi-region start end arg)) )

;;;###skk-autoload
(defun skk-romaji-region (start end)
  "$B%j!<%8%g%s$N4A;z!"$R$i$,$J!"%+%?%+%J!"A41QJ8;z$rA4$F%m!<%^;z$KJQ49$9$k!#(B
$BJQ49$K$O!"%X%\%s<0$rMQ$$$k!#(B
$BNc$($P!"(B
   \"$B4A;z$+$J:.$8$jJ8$r%m!<%^;z$KJQ49(B\"
    -> \"  kan'zi  kana  ma  ziri  bun'  woro-ma  zi ni hen'kan' \"

skk-romaji-*-by-hepburn $B$,(B nil $B$G$"$l$P!"%m!<%^;z$X$NJQ49MM<0$r71Na<0$KJQ99$9(B
$B$k!#Nc$($P!"(B\"$B$7(B\" $B$O%X%\%s<0$G$O(B \"shi\" $B$@$,!"71Na<0$G$O(B \"si\" $B$H$J$k!#(B"
  (interactive "*r")
  (let ((arg '("-Ha" "-Ka" "-Ja" "-Ea" "-ka" "-s"))
        str )
    (if skk-allow-spaces-newlines-and-tabs
        (setq arg (cons "-c" arg)) )
    (if (not skk-romaji-*-by-hepburn)
        (setq arg (cons "-rk" arg)) )
    (setq str (skk-kakasi-region start end arg))
    (combine-after-change-calls
      (delete-region start end)
      (goto-char start)
      (insert str) )
    (skk-set-cursor-properly) ))

;;;###skk-autoload
(defun skk-romaji-message (start end)
  "$B%j!<%8%g%s$N4A;z!"$R$i$,$J!"%+%?%+%J!"A41QJ8;z$rA4$F%m!<%^;z$KJQ49$7!"%(%3!<$9$k!#(B
$BJQ49$K$O!"%X%\%s<0$rMQ$$$k!#(B
$BNc$($P!"(B
   \"$B4A;z$+$J:.$8$jJ8$r%m!<%^;z$KJQ49(B\"
    -> \"  kan'zi  kana  ma  ziri  bun'  woro-ma  zi ni hen'kan' \"

skk-romaji-*-by-hepburn $B$,(B nil $B$G$"$l$P!"%m!<%^;z$X$NJQ49MM<0$r71Na<0$KJQ99$9(B
$B$k!#Nc$($P!"(B\"$B$7(B\" $B$O%X%\%s<0$G$O(B \"shi\" $B$@$,!"71Na<0$G$O(B \"si\" $B$H$J$k!#(B"
  (interactive "r")
  (let ((arg '("-Ha" "-Ka" "-Ja" "-Ea" "-ka" "-s")))
    (if skk-allow-spaces-newlines-and-tabs
        (setq arg (cons "-c" arg)) )
    (if (not skk-romaji-*-by-hepburn)
        (setq arg (cons "-rk" arg)) )
    (message (skk-kakasi-region start end arg))
    (skk-set-cursor-properly) ))

(defun skk-kakasi-region (start end arglist)
  ;; START $B$H(B END $B4V$N%j!<%8%g%s$KBP$7(B kakasi $B%3%^%s%I$rE,MQ$9$k!#(BARGLIST $B$r(B
  ;; kakasi $B$N0z?t$H$7$FEO$9!#(Bkakasi $B$N=PNO$rJV$9!#(B
  (if (not skk-use-kakasi)
      (skk-error "KAKASI $B$,%$%s%9%H!<%k$5$l$F$$$J$$$+!";HMQ$7$J$$@_Dj$K$J$C$F$$$^$9!#(B"
                 "KAKASI was not installed, or skk-use-kakasi is nil" ) )
  (let ((str (skk-buffer-substring start end)))
        ;; $BIQEY>pJs$r;H$C$F2?$+$*$b$7$m$$;H$$J}$,$G$-$k$+$J!)(B  $B8=>u$G$O;H$C$F(B
        ;; $B$$$J$$!#(B
        ;;(hindo-file (skk-make-temp-file "skkKKS"))
    (with-temp-buffer
      ;; current buffer $B$,(B read-only $B$N$H$-$K(B current buffer $B$G(B call-process
      ;; $B$r8F$V$H(B destination buffer $B$rJL$K;XDj$7$F$$$F$b%(%i!<$K$J$k$N$G!"%j!<(B
      ;; $B%8%g%s$NJ8;zNs$r%o!<%/%P%C%U%!$KB`Hr$9$k!#(B
      (insert str)
      (if (and (eq (apply 'call-process-region (point-min) (point) "kakasi"
                          ;; kakasi-2.2.5.hindo.diff $B$,Ev$C$F$$$k$HI8=`%(%i!<(B
                          ;; $B=PNO$KIQEY>pJs$,=PNO$5$l$k!#(B
                          'delete-original-text
                          ;;(list t hindo-file)
                          '(t nil)
                          nil arglist )
                   0 )
               (> (buffer-size) 0) )
          (buffer-string)
        (skk-error "$BJQ49$G$-$^$;$s(B" "Cannot convert!") ))))

(run-hooks 'skk-kakasi-load-hook)
(provide 'skk-kakasi)
;;; skk-kakasi.el ends here
