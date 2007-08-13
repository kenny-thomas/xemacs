;;; skk-num.el --- $B?tCMJQ49$N$?$a$N%W%m%0%i%`(B
;; Copyright (C) 1988, 1989, 1990, 1991, 1992, 1993, 1994, 1995, 1996, 1997
;; Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>

;; Author: Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>
;; Maintainer: Mikio Nakajima <minakaji@osaka.email.ne.jp>
;; Version: $Id: skk-num.el,v 1.1 1997/12/02 08:48:38 steve Exp $
;; Keywords: japanese
;; Last Modified: $Date: 1997/12/02 08:48:38 $

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

;; Following people contributed modifications to skk.el (Alphabetical order):
;;      Hideki Sakurada <sakurada@kuis.kyoto-u.ac.jp>
;;      Manabu Kawashima <kaw@lp.nm.fujitsu.co.jp>

;;; TODO
;; (1)skk-kanji-num-str2-subr $B$N%P%0=$@5!#(Bskk-kanji-num-str2-subr $B$N%3%a%s%H;2>H(B
;;    $B$N$3$H!#(B
;;
;; (2)skk-kanji-num-str3 $B$N?7@_!#(B

;;; Code:
(require 'skk-foreword)
(require 'skk-vars)
(require 'cl)

;; user variables.
;;;###skk-autoload
(defvar skk-num-type-list
  '((?0 . identity)
    (?1 . skk-zenkaku-num-str)
    (?2 . skk-kanji-num-str)
    (?3 . skk-kanji-num-str2)
    ;;(?5 . skk-kanji-num-str3) ; $B=`HwCf(B
    (?4 . skk-recompute-numerals)
    (?9 . skk-shogi-num-str) )
  "*$B?t;z$NJQ49$N$?$a$N!"%$%s%G%/%9$HJQ49$K;HMQ$9$k4X?t$H$N%I%C%H%Z%"$N%j%9%H!#(B
$B3FMWAG$O!"(B($B?t;z$N(B char-type . $B4X?tL>(B) $B$H$$$&9=@.$K$J$C$F$$$k!#(B
car $BItJ,$O!"Nc$($P!"8+=P$78l$,(B \"$BJ?@.(B#1$BG/(B\" $B$N$H$-!"(B# $B5-9f$ND>8e$KI=<($5$l$k?t(B
$B;z(B \"1\" $B$r(B char-type $B$GI=$o$7$?$b$N$rBeF~$9$k!#(B")

(defvar skk-numeric-conversion-float-num nil
  "*Non-nil $B$G$"$l$P!"IbF0>.?tE@?t$r;H$C$?8+=P$78l$KBP1~$7$FJQ49$r9T$J$&!#(B
$B$3$NCM$r(B non-nil $B$K$9$k$3$H$G!"(B\"#.# /#1$B!%(B#1/#0$B7n(B#0$BF|(B/\" $B$J$I$N<-=q8+=P$7$,;HMQ(B
$B$G$-$J$/$J$k$N$G!"Cm0U!#(B" )

;;;###skk-autoload
(defvar skk-uniq-numerals (or (assq ?4 skk-num-type-list)
                                  (and (assq ?2 skk-num-type-list)
                                       (assq ?3 skk-num-type-list) ))
  "*Non-nil $B$G$"$l$P!"0[$J$k?tCMI=8=$G$bJQ497k2L$,F1$8?tCM$r=EJ#$7$F=PNO$7$J$$!#(B" )

(defvar skk-num-load-hook nil
  "*skk-num.el $B$r%m!<%I$7$?8e$K%3!<%k$5$l$k%U%C%/!#(B" )

;; internal constants and variables
(defconst skk-num-alist-type1
  '((?0 . "$B#0(B") (?1 . "$B#1(B") (?2 . "$B#2(B") (?3 . "$B#3(B")
    (?4 . "$B#4(B") (?5 . "$B#5(B") (?6 . "$B#6(B") (?7 . "$B#7(B")
    (?8 . "$B#8(B") (?9 . "$B#9(B")
    (?. . "$B!%(B") ; $B>.?tE@!#(B(?. . ".") $B$NJ}$,NI$$?M$b$$$k$+$b(B...$B!#(B
    (?  . "") )
  "ascii $B?t;z$N(B char type $B$HA43Q?t;z$N(B string type $B$NO"A[%j%9%H!#(B
\"1995\" -> \"$B#1#9#9#5(B\" $B$N$h$&$JJ8;zNs$NJQ49$r9T$&:]$KMxMQ$9$k!#(B" )

(defconst skk-num-alist-type2
  '((?0 . "$B!;(B") (?1 . "$B0l(B") (?2 . "$BFs(B") (?3 . "$B;0(B")
    (?4 . "$B;M(B") (?5 . "$B8^(B") (?6 . "$BO;(B") (?7 . "$B<7(B")
    (?8 . "$BH,(B") (?9 . "$B6e(B") (?  . "") )
  "ascii $B?t;z$N(B char type $B$H4A?t;z$N(B string type $B$NO"A[%j%9%H!#(B
\"1995\" -> \"$B0l6e6e8^(B\" $B$N$h$&$JJ8;zNs$NJQ49$r9T$&:]$KMxMQ$9$k!#(B" )

;;; $B=`HwCf(B
;;;(defconst skk-num-alist-type3
;;;  '((?1 . "$B0m(B") (?2 . "$BFu(B") (?3 . "$B;2(B")
;;;    (?4 . "$B;M(B") (?5 . "$B8`(B") (?6 . "$BO;(B") (?7 . "$B<7(B")
;;;    (?8 . "$BH,(B") (?9 . "$B6e(B") (?  . "") )
;;;  "ascii $B?t;z$N(B char type $B$H4A?t;z$N(B string type $B$NO"A[%j%9%H!#(B
;;;\"1995\" -> \"$B0mot6eI46e=&8`(B\" $B$N$h$&$JJ8;zNs$NJQ49$r9T$&:]$KMxMQ$9$k!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-num-list nil
  "skk-henkan-key $B$NCf$K4^$^$l$k?t;z$rI=$9J8;zNs$N%j%9%H!#(B
$BNc$($P!"(B\"$B"&$X$$$;$$(B7$B$M$s(B10$B$,$D(B\" $B$NJQ49$r9T$&$H$-!"(Bskk-henkan-key $B$O(B
\"$B$X$$$;$$(B7$B$M$s(B10$B$,$D(B\" $B$G$"$j!"(Bskk-num-list $B$O(B \(\"7\" \"10\"\) $B$H$J$k!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-recompute-numerals-key nil
  "#4 $B%?%$%W$N%-!<$K$h$j?tCM$N:F7W;;$r9T$J$C$?$H$-$N8!:w%-!<!#(B" )

;;;###skk-autoload
(defun skk-compute-numeric-henkan-key (key)
  ;; KEY $B$NCf$NO"B3$9$k?t;z$r8=$o$9J8;zNs$r(B "#" $B$KCV$-49$($?J8;zNs$rJV$9!#(B"12"
  ;; $B$d(B "$B#0#9(B" $B$J$IO"B3$9$k?t;z$r(B 1 $B$D$N(B "#" $B$KCV$-49$($k$3$H$KCm0U!#(B
  ;; $BCV$-49$($??t;z$r(B skk-num-list $B$NCf$K%j%9%H$N7A$GJ]B8$9$k!#(B
  ;; $BNc$($P!"(BKEY $B$,(B "$B$X$$$;$$(B7$BG/(B12$B$,$D(B" $B$G$"$l$P!"(B"$B$X$$$;$$(B#$B$M$s(B#$B$,$D(B"
  ;; $B$HJQ49$7!"(Bskk-num-list $B$K(B ("7" "12") $B$H$$$&%j%9%H$rBeF~$9$k!#(B
  ;; $B<-=q$N8+=P$78l$N8!:w$K;HMQ$9$k!#(B
  (let ((numberrep (if skk-numeric-conversion-float-num
                       "[.0-9]+" "[0-9]+" ))
        (enable-multibyte-characters t) )
    ;;(setq skk-noconv-henkan-key key)
    (save-match-data
      ;; $BA43Q?t;z$r(B ascii $B?t;z$KJQ49$9$k!#(B
      (while (string-match "[$B#0(B-$B#9(B]" key)
        (let ((zen-num (match-string 0 key)))
          (setq key (concat (substring key 0 (match-beginning 0))
                            (skk-jisx0208-to-ascii zen-num)
                            (substring key (match-end 0)) ))))
      ;; ascii $B?t;z$r(B "#" $B$KCV$-49$(!"$=$N?t;z$r(B skk-num-list $B$NCf$KJ]B8!#(B
      (while (string-match numberrep key)
        (setq skk-num-list (nconc skk-num-list (list (match-string 0 key)))
              key (concat (substring key 0 (match-beginning 0))
                          "#"
                          (substring key (match-end 0)) )))))
  key )

;;(defun skk-compute-noconv-henkan-key (key)
;;  ;; $BJ8;zNs(B KEY $B$NCf$K?tCMJQ49$rI=$o$9(B "#" $B$,$"$l$P!"$=$NItJ,$r:o=|$7!"(B
;;  ;; skk-num-list $B$NCf$G3:Ev$9$k?t;z$rA^F~$7!":G=i$K(B skk-start-henkan $B$KEO$5$l(B
;;  ;; $B$?J8;zNs$rJV$9!#Nc$($P!"(Bskk-num-list $B$,(B ("1" "2" "3") $B$G!"(BKEY $B$,(B
;;  ;; "#$B$,$D(B#$B$,$D(B#$B$,$D(B" $B$G$"$k$H$-$O!"J8;zNs(B "1$B$,$D(B2$B$,$D(B3$B$,$D(B" $B$rJV$9!#(B
;;  (if skk-num-list
;;      (save-match-data
;;        (let ((num-list skk-num-list)
;;              str )
;;          (while (and num-list key (string-match "#" key))
;;            (setq str (concat str (substring key 0 (match-beginning 0))
;;                              (car num-list) )
;;                  key (substring key (match-end 0))
;;                  num-list (cdr num-list) ))
;;          (setq key (concat str key)) )))
;;  key )

;;;###skk-autoload
(defun skk-numeric-convert (key)
  (if (not key)
      nil
    (let ((numexp (if skk-numeric-conversion-float-num
                      "#[.0-9]+" "#[0-9]+" ))
          (n 0)
          (workkey key)
          num convnum string convlist current )
      (save-match-data
        (while (and (setq num (nth n skk-num-list))
                    (string-match numexp workkey) )
          (setq convnum (skk-num-exp num (string-to-char
                                          (substring workkey
                                                     (1+ (match-beginning 0))
                                                     (match-end 0) )))
                string (substring workkey 0 (match-beginning 0))
                workkey (substring workkey (match-end 0))
                n (1+ n) )
          (if (not (and (stringp convnum) (string= convnum "")
                        (string= string "") ))
              (setq convlist (nconc convlist (list string convnum))) ))
        (setq convlist (nconc convlist (list workkey)))
        (cond ((null convlist) nil)
              ((and (null (cdr convlist)) (stringp (car convlist)))
               (setq current (car convlist)) )
              ;; RAW-LIST $B$NA4MWAG$,J8;zNs!#(B
              ((null (memq t (mapcar 'listp convlist)))
               (setq current (mapconcat 'identity convlist ""))
               (if (and (> skk-henkan-count -1)
                        (nth skk-henkan-count skk-henkan-list) )
                   ;; ("A" "#2" "C") -> ("A" ("$B0l(B" . "#2") "C")
                   (setf (nth skk-henkan-count skk-henkan-list)
                         (cons key current) )
                 (setq skk-henkan-list
                       (nconc skk-henkan-list (list (cons key current))) )))
              ;; #4
              (t (let ((l (mapcar (function (lambda (e) (cons key e)))
                                  (skk-flatten-list (delete "" convlist)) )))
                   (setq current (cdr (car l)))
                   (if (and (> skk-henkan-count -1)
                            (nth skk-henkan-count skk-henkan-list) )
                       (progn
                         (setf (nth skk-henkan-count skk-henkan-list) (car l))
                         (setq skk-henkan-list (skk-middle-list
                                                skk-henkan-list
                                                (1+ skk-henkan-count)
                                                (cdr l) )))
                     (setq skk-henkan-list (nconc skk-henkan-list l)) ))))
        current ))))

;;;###skk-autoload
(defun skk-numeric-convert*7 ()
  (let ((skk-henkan-count skk-henkan-count)
        (n 7) )
    (while (and (> n 0) (nth skk-henkan-count skk-henkan-list))
      (skk-numeric-convert (skk-get-current-candidate))
      (setq skk-henkan-count (1+ skk-henkan-count)
            n (1- n) ))
    (if skk-recompute-numerals-key
        (skk-uniq-numerals) )))

(defun skk-raw-number-to-skk-rep (string)
  (setq string (skk-raw-number-to-skk-rep-1
                string "[$B#0(B-$B#9(B][$B0l6e8^;0;M<7FsH,O;(B]" "#9" 0 ))
  (setq string (skk-raw-number-to-skk-rep-1
                string "\\(^\\|[^#0-9]\\)\\([0-9]+\\)" "#0" 2 ))
  (setq string (skk-raw-number-to-skk-rep-1
                string "[$B#0(B-$B#9(B]+" "#1" 0 ))
  (setq string (skk-raw-number-to-skk-rep-1
                string "\\([$B0l6e8^;0;M<7FsH,O;==(B][$B==I4@iK|2/C{5~(B]\\)+" "#3" 0 ))
  ;; (mapcar 'char-to-string
  ;;         (sort
  ;;          '(?$B0l(B ?$BFs(B ?$B;0(B ?$B;M(B ?$B8^(B ?$BO;(B ?$B<7(B ?$BH,(B ?$B6e(B ?$B!;(B) '<))
  ;;   --> ("$B!;(B" "$B0l(B" "$B6e(B" "$B8^(B" "$B;0(B" "$B;M(B" "$B<7(B" "$BFs(B" "$BH,(B" "$BO;(B")
  ;;
  ;; [$B!;(B-$B6e(B] $B$H$$$&@55,I=8=$,;H$($J$$$N$G!"@8$N$^$^$D$C$3$s$G$*$/!#(B
  (skk-raw-number-to-skk-rep-1 string "[$B!;0l6e8^;0;M<7FsH,O;(B]+" "#2" 0))

(defun skk-raw-number-to-skk-rep-1 (string key type place)
  (let ((enable-multibyte-characters t))
    (save-match-data
      (while (string-match key string)
        (setq string (concat (substring string 0 (match-beginning place))
                             type
                             (substring string (match-end place)) )))
    string )))
  
(defun skk-flatten-list (list)
  ;; $BM?$($i$l$?%j%9%H$N3FMWAG$+$iAH$_9g$;2DG=$JJ8;zNs$NO"@\$r:n$j!"%j%9%H$GJV(B
  ;; $B$9!#(B
  ;; (("A" "B") "1" ("X" "Y")) -> ("A1X" "A1Y" "B1X" "B1Y")
  (do ((result
        (if (atom (car list)) (list (car list)) (car list))
        (mapcan (function
                 (lambda (a)
                   (mapcar (function (lambda (b) (concat a b)))
                           (if (atom (car tail)) (list (car tail))
                             (car tail) ))))
                result ))
       (tail (cdr list) (cdr tail)) )
      ((null tail) result) ))

(defun skk-num-exp (num type)
  ;; ascii $B?t;z$N(B NUM $B$r(B TYPE $B$K=>$$JQ49$7!"JQ498e$NJ8;zNs$rJV$9!#(B
  ;; TYPE $B$O2<5-$NDL$j!#(B
  ;; 0 -> $BL5JQ49(B
  ;; 1 -> $BA43Q?t;z$XJQ49(B
  ;; 2 -> $B4A?t;z$XJQ49(B
  ;; 3 -> $B4A?t;z$XJQ49(B ($B0L<h$j$r$9$k(B)
  ;; 4 -> $B$=$N?t;z$=$N$b$N$r%-!<$K$7$F<-=q$r:F8!:w(B
  ;; 9 -> $B>-4}$G;HMQ$9$k?t;z(B ("$B#3;M(B" $B$J$I(B) $B$KJQ49(B
  (let ((fun (cdr (assq type skk-num-type-list))))
    (if fun (funcall fun num)) ))

(defun skk-zenkaku-num-str (num)
  ;; ascii $B?t;z$N(B NUM $B$rA43Q?t;z$NJ8;zNs$KJQ49$7!"JQ498e$NJ8;zNs$rJV$9!#(B
  ;; $BNc$($P(B "45" $B$r(B "$B#4#5(B" $B$KJQ49$9$k!#(B
  (let ((candidate
         (mapconcat (function (lambda (c) (cdr (assq c skk-num-alist-type1))))
                    num "" )))
    (if (not (string= candidate ""))
        candidate )))

(defun skk-kanji-num-str (num)
  ;; ascii $B?t;z(B NUM $B$r4A?t;z$NJ8;zNs$KJQ49$7!"JQ498e$NJ8;zNs$rJV$9!#(B
  ;; $BNc$($P!"(B"45" $B$r(B "$B;M8^(B" $B$KJQ49$9$k!#(B
  (save-match-data
    (if (not (string-match "\\.[0-9]" num))
        (let ((candidate
               (mapconcat (function (lambda (c)
                                      (cdr (assq c skk-num-alist-type2)) ))
                          num "" )))
          (if (not (string= candidate ""))
              candidate )))))

(defun skk-kanji-num-str2 (num)
  ;; ascii $B?t;z(B NUM $B$r4A?t;z$NJ8;zNs$KJQ49$7(B ($B0L<h$j$r$9$k(B)$B!"JQ498e$NJ8;zNs$r(B
  ;; $BJV$9!#Nc$($P(B "1021" $B$r(B "$B@iFs==0l(B" $B$KJQ49$9$k!#(B
  (save-match-data
    (if (not (string-match "\\.[0-9]" num))
        (let ((str (skk-kanji-num-str2-subr num)))
          (if (string= "" str) "$B!;(B" str) ))))

(defun skk-kanji-num-str2-subr (num)
  ;; skk-kanji-num-str2 $B$N%5%V%k!<%A%s!#(B
  ;;
  ;; Known Bug; $B"&(B 100000000 $B$rJQ49$9$k$H!"(B"$B0l2/K|(B" $B$K$J$C$F$7$^$&(B...$B!#$G$b$=$s(B
  ;; $B$JJQ49$r;H$&?M$O$$$J$$$+$J!"$H;W$&$HD>$95$NO$,M/$+$J$$(B...$B!#(B
  ;; --> Fixed $B$N%O%:(B...$B!#(B
  (let ((len (length num))
        prevchar modulo )
    (mapconcat
     (function
      (lambda (char)
        ;; $B0L(B:     $B0l(B   $B==(B    $BI4(B     $B@i(B  $BK|(B   $B==K|(B   $BI4K|(B   $B@iK|(B    $B2/(B
        ;; modulo: 1 --> 2 --> 3 --> 0 -> 1 --> 2 ---> 3 ---> 0 ---> 1
        (setq modulo (mod len 4))
        (prog1
            (if (eq len 1)
                ;; 1 $B7e$G(B 0 $B$G$J$$?t!#(B
                (if (not (eq char ?0))  ;?0
                    ;; $B0L$rI=$o$94A?t;z0J30$N4A?t;z!#(B
                    (cdr (assq char skk-num-alist-type2)) )
              (concat
               ;; $B0L$rI=$o$94A?t;z0J30$N4A?t;z!#(B
               (if (or
                    ;; 2 $B7e0J>e$G!"$3$N0L$N?t$O(B 0, 1 $B0J30$N?t;z!#(B
                    ;; ?0 == 48, ?1 == 49
                    (null (memq char '(?0 ?1)))
                    ;; 2 $B7e0J>e$G!"$3$N0L$N?t$O(B 1 $B$G!"0L$,$=$N0L$rI=$o$94A?t;z(B
                    ;; $B$K(B "$B0l(B" $B$rJ;5-$9$Y$-(B ($BNc$($P!"(B"$B0l2/(B" $B$J$I!#(B"$B2/(B" $B$G$O$*(B
                    ;; $B$+$7$$(B) $B$H$-!#(B
                    (and (eq char ?1) (eq modulo 1)) )
                   (cdr (assq char skk-num-alist-type2)) )
               ;; $B0L$rI=$o$94A?t;z!#(B
               (if (and (not (eq prevchar ?0))
                        (not (and (eq char ?0) (not (eq modulo 1))) ))
                   (cond ((cdr (assq modulo '((2 . "$B==(B") (3 . "$BI4(B") (0 . "$B@i(B")))))
                         ((cdr (assq len '((5 . "$BK|(B") (9 . "$B2/(B") (13 . "$BC{(B")
                                           (17 . "$B5~(B") ))))
                         (t (skk-error "$B7e$,Bg$-$9$.$^$9!*(B"
                                       "Too big number!" ))))))
          (setq len (1- len)
                prevchar char ) )))
     num "" )))

(defun skk-shogi-num-str (num)
  ;; ascii $B?t;z$N(B NUM $B$r>-4}$G;HMQ$5$l$k?t;zI=5-$KJQ49$9$k!#(B
  ;; $BNc$($P(B "34" $B$r(B "$B#3;M(B" $B$KJQ49$9$k!#(B
  (save-match-data
    (if (and (eq (length num) 2)
             (not (string-match "\\.[0-9]" num)) )
        (let ((candidate
               (concat (cdr (assq (aref num 0) skk-num-alist-type1))
                       (cdr (assq (aref num 1) skk-num-alist-type2)) )))
          (if (not (string= candidate ""))
              candidate )))))

(defun skk-recompute-numerals (num)
  ;; #4 $B$N8+=P$7$KBP$7!"(Bskk-henkan-key $B$KBeF~$5$l$??t;z$=$N$b$N$r:FEY8!:w$9$k!#(B
  (let (result)
    ;; with-temp-buffer $B$@$H2?8N>e<j$/$f$+$J$$(B...$B!)(B $B3NDj$5$l$F$7$^$&!#(B
    ;;(with-temp-buffer
    (save-excursion
      (set-buffer (get-buffer-create " *skk-work*"))
      ;; $B%+%l%s%H%P%C%U%!$N%P%C%U%!%m!<%+%kJQ?t$K1F6A$r5Z$\$5$J$$$h$&!"%o!<%-(B
      ;; $B%s%0%P%C%U%!$X0lC6F($2$k(B
      (let ((skk-current-search-prog-list skk-search-prog-list)
            (skk-henkan-key num)
            skk-henkan-okurigana skk-okuri-char skk-use-numeric-conversion )
        ;; $B%+%l%s%H$NJQ49$OAw$j$J$7(B (skk-henkan-okurigana $B$H(B skk-okuri-char $B$O(B
        ;; $B$$$:$l$b(B nil) $B$@$,!"JL%P%C%U%!(B (work $B%P%C%U%!(B) $B$KF~$C$F$$$k$N$G!"G0(B
        ;; $B$N$?$a!"(Bnil $B$rF~$l$F$*$/!#(B
        (while skk-current-search-prog-list
          (setq result (skk-nunion result (skk-search))) )))
    ;; $B$3$3$G(B with-temp-buffer $B$r=P$FJQ49$r9T$J$C$F$$$k%+%l%s%H%P%C%U%!$KLa$k(B
    ;; ($B%P%C%U%!%m!<%+%kCM$G$"$k(B skk-henkan-list $B$rA`:n$7$?$$$?$a(B)$B!#(B
    (setq skk-recompute-numerals-key num)
    (if result
        (if (null (cdr result)) ;;(eq (length result) 1)
            (car result)
          result )
      ;; $BJQ49$G$-$J$+$C$?$i85$N?t;z$r$=$N$^$^JV$7$F$*$/!#(B
      num )))

;;;###skk-autoload
(defun skk-uniq-numerals ()
  (if (or (not skk-uniq-numerals) (null skk-henkan-list))
      nil
    (save-match-data
      (let ((n1 -1) n2 e1 e2 e3
            ;; 1 $B$D$G$b(B 2 $B7e0J>e$N?t;z$,$"$l$P!"(B#2 $B$H(B #3 $B$G$O(B uniq $B$7$J$$!#(B
            (type2and3 (> 2 (apply 'max (mapcar 'length skk-num-list))))
            type2 type3 index2 index3 head2 head3 tail2 tail3
            kanji-flag mc-flag enable-multibyte-characters case-fold-search )
        (while (setq n1 (1+ n1) e1 (nth n1 skk-henkan-list))
          ;; cons cell $B$G$J$1$l$P(B skk-nunion $B$G=hM}:Q$_$J$N$G!"=EJ#$O$J$$!#(B
          (if (consp e1)
              ;; (car e1) $B$H(B equal $B$N$b$N$,>C$($k$N$@$+$i(B e1 $B<+?H$,>C$($k$3(B
              ;; $B$H$O$J$$!#(B
              (setq skk-henkan-list (delete (car e1) skk-henkan-list)
                    skk-henkan-list (delete (cdr e1) skk-henkan-list) ))
          (if (not (and skk-recompute-numerals-key (consp e1)))
              nil
            ;; ("#4" . "xxx") $B$r4^$`8uJd$,(B skk-henkan-list $B$NCf$K$"$k!#(B
            (setq n2 -1)
            (while (setq n2 (1+ n2) e2 (nth n2 skk-henkan-list))
              (if (and (not (= n1 n2)) (consp e2)
                       ;; $BNc$($P(B ("#4" . "$B0l(B") $B$H(B ("#2" . "$B0l(B") $B$,JBB8$7$F$$(B
                       ;; $B$k>l9g!#(B
                       (string= (cdr e1) (cdr e2)) )
                  (setq skk-henkan-list (delq e2 skk-henkan-list)) )))
          (if (not type2and3)
              nil
            ;; 1 $B7e$N?t;z$rJQ49$9$k:]$K!"(Bskk-henkan-list $B$K(B #2 $B%(%s%H%j$H(B #3
            ;; $B%(%s%H%j$,$"$l$P!"(B#2 $B$b$7$/$O(B #3 $B%(%s%H%j$N$&$A!"$h$j8eJ}$K$"$k(B
            ;; $B$b$N$r>C$9!#(B
            (setq e3 (if (consp e1) (car e1) e1))
            ;; e3 $B$O(B "#2" $B$N$h$&$K?tCMJQ49$r<($9J8;zNs$N$_$H$O8B$i$J$$$N$G!"(B
            ;; member $B$O;H$($J$$!#(B
            (cond ((string-match "#2" e3)
                   (setq type2 e1
                         index2 n1
                         head2 (substring e3 0 (match-beginning 0))
                         tail2 (substring e3 (match-end 0)) ))
                  ((string-match "#3" e3)
                   (setq type3 e1
                         index3 n1
                         head3 (substring e3 0 (match-beginning 0))
                         tail3 (substring e3 (match-end 0)) )))))
        (if (and type2and3 type2 type3
                 ;; $B?tCMJQ49$r<($9J8;zNs(B "#[23]" $B$NA08e$NJ8;zNs$bF10l$N$H(B
                 ;; $B$-$N$_(B uniq $B$r9T$J$&!#(B
                 (string= head2 head3) (string= tail2 tail3))
            (if (> index2 index3)
                ;; "#3" $B$NJ}$,A0$K$"$k!#(B
                (setq skk-henkan-list (delq type2 skk-henkan-list))
              ;; $BJQ?t(B type[23] $B$NCM$O!"(Bskk-henkan-list $B$+$iD>@\Cj=P$7$?$b(B
              ;; $B$N$@$+$i(B delete $B$G$J$/!"(Bdelq $B$G==J,!#(B
              (setq skk-henkan-list (delq type3 skk-henkan-list)) ))))))

;;;###skk-autoload
(defun skk-adjust-numeric-henkan-data (key)
  (let (numexp orglen val)
    (if (or (and (string-match "#[012349]" key)
                 (setq numexp key) )
            (and (setq numexp (skk-raw-number-to-skk-rep key))
                 (not (string= key numexp)) ))
        (progn
          (setq orglen (length skk-henkan-list)
                ;; skk-henkan-list $B$ND4@0$O!"(Bskk-numeric-convert $B$NCf$G9T$J$C(B
                ;; $B$F$/$l$k!#(B
                val (skk-numeric-convert numexp) )
          (if (= (length skk-henkan-list) (1+ orglen))
              ;; #4 $B$GJ#?t$N8uJd$KJQ49$G$-$?>l9g$O3NDj$7$J$$!#(B
              (setq skk-kakutei-flag t) ))
      (setq skk-henkan-list (nconc skk-henkan-list (list key))
            skk-kakutei-flag t
            val key ))
    val ))

;;;###skk-autoload
(defun skk-init-numeric-conversion-variables ()
  ;; skk-use-numeric-convert $B4XO"$NJQ?t$r=i4|2=$9$k!#(B
  (setq skk-num-list nil
        skk-recompute-numerals-key nil ))

;;;###skk-autoload
(defun skk-numeric-midasi-word ()
  ;; type4 $B$N?tCM:FJQ49$,9T$J$o$l$?$H$-$O!"?tCM<+?H$rJV$7!"$=$l0J30$N?tCMJQ49(B
  ;; $B$G$O!"(Bskk-henkan-key $B$rJV$9!#$3$s$J>.$5$J4X?t$r:n$i$J$-$c$J$i$J$$$N$O!"(B
  ;; skk-use-numeric-conversion $B$K4XO"$9$kJQ?t$r(B skk-num.el $B$K=8Ls$7$?L5M}$,=P(B
  ;; $B$?7k2L$+(B...$B!#(B
  (or skk-recompute-numerals-key skk-henkan-key) )

;;;###skk-autoload
(defun skk-update-jisyo-for-numerals (noconvword word &optional purge)
  ;; $B?t;z<+?H$r8+=P$78l$H$7$F<-=q$N%"%C%W%G!<%H$r9T$J$&!#(B
  (if (and skk-recompute-numerals-key
           (save-match-data (string-match "#4" noconvword)) )
      (let ((skk-henkan-key skk-recompute-numerals-key))
	(message "%S" skk-recompute-numerals-key)
        (skk-update-jisyo word purge) )))

;;;###skk-autoload
(defun skk-num (str)
  ;; $B?t;z$r(B skk-number-style $B$NCM$K=>$$JQ49$9$k!#(B
  ;; skk-date $B$N%5%V%k!<%A%s!#(B
  (mapconcat (function
	      (lambda (c)
		(cond ((or (not skk-number-style) (eq skk-number-style 0))
		       (char-to-string c) )
		      ((or (eq skk-number-style t) (eq skk-number-style 1))
		       (cdr (assq c skk-num-alist-type1)) )
		      (t (cdr (assq c skk-num-alist-type2))) )))
	     str "" ))

(run-hooks 'skk-num-load-hook)

(provide 'skk-num)
;;; skk-num.el ends here
