;; -*-byte-compile-dynamic: t;-*-
;;; skk.el --- SKK (Simple Kana to Kanji conversion program)
;; Copyright (C) 1988, 1989, 1990, 1991, 1992, 1993, 1994, 1995, 1996, 1997
;; Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>

;; Author: Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>
;; Maintainer: Murata Shuuichirou  <mrt@mickey.ai.kyutech.ac.jp>
;;             Mikio Nakajima <minakaji@osaka.email.ne.jp>
;; Version: $Id: skk.el,v 1.1 1997/12/02 08:48:40 steve Exp $
;; Keywords: japanese
;; Last Modified: $Date: 1997/12/02 08:48:40 $

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

;; Following people contributed modifications to skk.el (Alphabetical order):
;;      Chikanobu Toyofuku <unbound@papaya.juice.or.jp>
;;      FURUE Hideyuki <furue@kke.co.jp>
;;      GUNJI Takao <gunji@lisa.lang.osaka-u.ac.jp>
;;      Haru Mizuno <mizu@cs3.cs.oki.co.jp>
;;      Hideki Sakurada <sakurada@kuis.kyoto-u.ac.jp>
;;      Hisao Kuroda <kuroda@msi.co.jp>
;;      Hitoshi SUZUKI <h-suzuki@ael.fujitsu.co.jp>
;;      IIDA Yosiaki <iida@secom-sis.co.jp>
;;      Jun-ichi Nakamura <nakamura@pluto.ai.kyutech.ac.jp>
;;      Katuya Tomioka <tomioka@culle.l.chiba-u.ac.jp>
;;      Kazuo Hirokawa <hirokawa@rics.co.jp>
;;      Kazushi Marukawa <kazushi@kubota.co.jp>
;;      Kimura Chikahiro <kimura@oa1.kb.nec.co.jp>
;;      Kiyotaka Sakai <ksakai@netwk.ntt-at.co.jp>
;;      Koichi MORI <kmori@onsei2.rilp.m.u-tokyo.ac.jp>
;;      MINOURA Itsushi <minoura@uni.zool.s.u-tokyo.ac.jp>
;;      MIYOSHI Tsutomu <minkov@fuzzy.or.jp>
;;      Makoto MATSUSHITA <matusita@ics.es.osaka-u.ac.jp>
;;      Masahiko Suzuki <suzmasa@sm.sony.co.jp>
;;      Masahiro Doteguchi <xdote@rp.open.cs.fujitsu.co.jp>
;;      Masakazu Takahashi <masaka-t@ascii.co.jp>
;;      Masatake YAMATO <jet@airlab.cs.ritsumei.ac.jp>
;;      Mikio Nakajima <minakaji@osaka.email.ne.jp>
;;      Motohiko Mouri <mouri@jaist.ac.jp>
;;      Murata Shuuichirou <mrt@mickey.ai.kyutech.ac.jp>
;;      $BCfDE;3(B $B91(B <hisashi@rst.fujixerox.co.jp>
;;      NAMBA Seiich <pi9s-nnb@asahi-net.or.jp>
;;      Naoki HAMADA <nao@mimo.jaist-east.ac.jp>
;;      Ryoichi Hashimoto <gnu@ipri.go.jp>
;;      Sekita Daigo <sekita@mri.co.jp>
;;      $B?JF#M5;V(B <shindo@super.ees.saitama-u.ac.jp>
;;      Shuji Ashizawa <ashizawa@zuken.co.jp>
;;      Takeshi OHTANI <ohtani@iias.flab.fujitsu.co.jp>
;;      Tomoyuki Hiro <hiro@momo.it.okayama-u.ac.jp>
;       $BDS?"(B $B@5Bg(B (ma-tsuge@kdd.co.jp)
;;      Tsugutomo Enami <enami@ptgd.sony.co.jp>
;;      Wataru Matsui <matsui@atr-rd.atr.co.jp>
;;      Yoshida Toyonobu <toyono-y@is.aist-nara.ac.jp>

;;; Change log:

;;; Code:
(require 'advice)
;; Elib 1.0 is required
;; queue-m.el and string.el are now distributed with SKK; this seems
;; to be the primary source for XEmacs
(require 'queue-m)
(require 'string)
(require 'skk-foreword)
(require 'skk-vars)

(defconst skk-version "10.38")

;;;###skk-autoload
(defconst skk-month-alist
  '(("Jan" . "1") ("Feb" . "2") ("Mar" . "3") ("Apr" . "4") ("May" . "5")
    ("Jun" . "6") ("Jul" . "7") ("Aug" . "8") ("Sep" . "9") ("Oct" . "10")
    ("Nov" . "11") ("Dec" . "12") )
  "$B1Q8l$N7nL>$H;;MQ?t;z$NO"A[%j%9%H!#(B

$B;;MQ?t;z$+$i1Q8l$N7nL>$N$_$r=PNO$9$k$N$G$"$l$P!"%Y%/%?!<$r;H$C$?J}$,9bB.$@$,!"(B
$B1Q8l$N7nL>$+$i;;MQ?t;z$r=PNO$9$k$N$G$"$l$PO"A[%j%9%H$G$J$1$l$PL5M}$J$N$G!"B?(B
$BL\E*$K;HMQ$G$-$k$h$&O"A[%j%9%H$N7ABV$r<h$k!#(B

Alist of English month abbreviations and numerical values.

Although it is faster to use a vector if we only want to output
month abbreviations given the ordinal, without the alist it's
unreasonable [sic] to output the ordinal given the abbreviation,
so for multi-purpose utility we use the alist form."
)

;;;###skk-autoload
(defun skk-version ()
  (interactive)
  (if (not (interactive-p))
      skk-version
    (save-match-data
      (let* ((raw-date "$Date: 1997/12/02 08:48:40 $")
             (year (substring raw-date 7 11))
             (month (substring raw-date 12 14))
             (date (substring raw-date 15 17)) )
        (if (string-match "^0" month)
            (setq month (substring month (match-end 0))) )
        (if (string-match "^0" date)
            (setq date (substring date (match-end 0))) )
        (message "SKK version %s of %s"
                 skk-version
                 (concat (car (rassoc month skk-month-alist))
                         " " date ", " year ))))))

;;;; variables declaration
;;; user variables
(defvar skk-debug nil)

;;;###skk-autoload
(defvar skk-init-file (if (eq system-type 'ms-dos) "~/_skk" "~/.skk")
  "*SKK $B$N=i4|@_Dj%U%!%$%kL>!#(B
skk.el 9.x $B$h$j(B ~/.emacs $B$G$N%+%9%?%^%$%:$,2DG=$H$J$C$?!#(B

Name of the SKK initialization file.
From skk.el 9.x on all customization may be done in ~/.emacs."
)

;;;###skk-autoload
(defvar skk-special-midashi-char-list '(?> ?< ??)
  "*$B@\F,<-!"@\Hx<-$NF~NO$N$?$a$N%W%l%U%#%C%/%9%-!<!"%5%U%#%C%/%9%-!<$N%j%9%H!#(B

List of prefix and suffix keys for entering `setsutoji' and `setsuoji'."
;#SJT# What are `setsutoji' and `setsuoji'?
)

;#SJT# Is this hook also run in skk-auto-fill-mode?  Before or after?
;;;###skk-autoload
(defvar skk-mode-hook nil
  "*SKK $B$r5/F0$7$?$H$-$N%U%C%/!#(B
$BB>$K!"(Bskk-auto-fill-mode-hook$B!"(Bskk-load-hook, skk-init-file $B$G$b%+%9%?(B
$B%^%$%:$,2DG=!#(B

Hook run at SKK startup.

`skk-auto-fill-mode-hook', `skk-load-hook', and skk-init-file may also
be used for customization."
)

;;;###skk-autoload
(defvar skk-auto-fill-mode-hook nil
  "*skk-auto-fill-mode $B$r5/F0$7$?$H$-$N%U%C%/!#(B
$BB>$K!"(Bskk-mode-hook, skk-load-hook, skk-init-file $B$G$b%+%9%?%^%$%:$,2D(B
$BG=!#(B

Hook run at startup of skk-auto-fill-mode.

`skk-mode-hook', `skk-load-hook', and `skk-init-file' may also be
used for customization."
)

;;;###skk-autoload
(defvar skk-load-hook nil
  "*skk.el $B$r%m!<%I$7$?$H$-$N%U%C%/!#(B
$BB>$K!"(Bskk-mode-hook, skk-auto-fill-mode-hook, skk-init-file $B$G$b%+%9%?(B
$B%^%$%:$,2DG=!#(B

Hook run when SKK is loaded.

`skk-auto-fill-mode-hook', `skk-mode-hook', and `skk-init-file' may
also be used for customization."
)

;;;###skk-autoload
(defvar skk-kakutei-jisyo nil
  "*$B:G=i$K8!:w$9$k<-=q!#(B
Non-nil $B$G!"$+$D(B skk-search-prog-list $B$NMWAG$NCf$K$3$NJQ?t$,;HMQ$5$l$F$$$l$P!"(B
$B;XDj$5$l$?<-=q$r8!:w$N$?$a%P%C%U%!$KFI$_9~$_!"8!:w$r9T$J$&!#(B
$B8+=P$78l$O!"%=!<%H$5$l$F$$$J$1$l$P$J$i$J$$!#(B
$B3F8+=P$78l$N:G=i$N%(%s%H%j$7$+8!:w$7$J$$(B ($BJ#?t$N%(%s%H%j$,$"$C$F$b(B 2 $BHVL\0J9_$N(B
$B%(%s%H%j$OL5;k$5$l$k(B)$B!#(B
skk-search-prog-list $B$NCM$r@_Dj$9$k$3$H$K$h$j!"8!:wBP>]$N<-=q$NJQ99!"8!:w$N=g(B
$B=x$NJQ99$,2DG=!#(B

The first dictionary to be searched.
If non-nil, and this variable is used as a component of
`skk-search-prog-list', the indicated dictionary is read into a
buffer and searched.
The keys must be sorted.
Only the first entry in each key is checked; if several entries are
present the second and following entries are ignored.
By setting the value of `skk-search-prog-list' the dictionaries
searched and the order of search can be changed."
)

;;;###skk-autoload
(defvar skk-initial-search-jisyo nil
  "*$B%f!<%6!<<-=q$N8!:w$NA0$K8!:w$9$k<-=q!#(B
$B8+=P$78l$O!"%=!<%H$5$l$F$$$J$1$l$P$J$i$J$$!#(B
Non-nil $B$G!"$+$D(B skk-search-prog-list $B$NMWAG$NCf$K$3$NJQ?t$,;HMQ$5$l$F$$$l$P!"(B
$B;XDj$5$l$?<-=q$r8!:w$N$?$a%P%C%U%!$KFI$_9~$_!"8!:w$r9T$J$&!#(B
skk-search-prog-list $B$NCM$r@_Dj$9$k$3$H$K$h$j!"8!:wBP>]$N<-=q$NJQ99!"8!:w$N=g(B
$B=x$NJQ99$,2DG=!#(B

This dictionary is searched before the user's personal dictionary.
The keys must be sorted.
If non-nil, and this variable is used as a component of
`skk-search-prog-list', the indicated dictionary is read into a
buffer and searched.
By setting the value of `skk-search-prog-list' the dictionaries
searched and the order of search can be changed."
)

;;;###skk-autoload
(defvar skk-large-jisyo nil
  "*$B%f!<%6!<<-=q$N8!:w$N8e$K8!:w$9$k<-=q!#(B
$B8+=P$78l$O!"%=!<%H$5$l$F$$$J$1$l$P$J$i$J$$!#(B
Non-nil $B$G!"$+$D(B skk-search-prog-list $B$NMWAG$NCf$K$3$NJQ?t$,;HMQ$5$l$F$$$l$P!"(B
$B;XDj$5$l$?<-=q$r8!:w$N$?$a%P%C%U%!$KFI$_9~$_!"8!:w$r9T$J$&!#(B
skk-search-prog-list $B$NCM$r@_Dj$9$k$3$H$K$h$j!"8!:wBP>]$N<-=q$NJQ99!"8!:w$N=g(B
$B=x$NJQ99$,2DG=!#(B

Dictionary searched after the user dictionary.
Keys must be sorted.
If non-nil and this variable is used as a component of
`skk-search-prog-list', the indicated dictionary is read into a buffer 
for search, and the search is executed.
By setting the value of `skk-search-prog-list' the dictionaries
searched and the order of search can be changed."
)

;;;###skk-autoload
(defvar skk-aux-large-jisyo nil
  "*SKK $B%5!<%P!<$G:G8e$K8!:w$9$k<-=q!#(B
$B8+=P$78l$O!"%=!<%H$5$l$F$$$J$1$l$P$J$i$J$$!#(B
Non-nil $B$G!"$+$D(B skk-search-prog-list $B$NMWAG$NCf$K$3$NJQ?t$,;HMQ$5$l$F$$$l$P!"(B
SKK $B%5!<%P!<$r;H$$8!:w$r9T$&!#(B
SKK $B%5!<%P!<$,(B active $B$G$J$1$l$P!";XDj$5$l$?<-=q$r%P%C%U%!$KFI$_9~$`!#(B
skk-search-prog-list $B$NCM$r@_Dj$9$k$3$H$K$h$j!"8!:wBP>]$N<-=q$NJQ99!"8!:w$N=g(B
$B=x$NJQ99$,2DG=!#(B
$B$3$NCM$r@_Dj$9$k$3$H$K$h$j!"(Bskk-server.el $B$,(B autoload $B$5$l$k!#(B

Last dictionary to be searched by the SKK server.
Keys must be sorted.

If non-nil and this variable is used as a component of
`skk-search-prog-list', the SKK server is used to execute the search.
If the server is not active, the indicated dictionary is read into a
buffer for search, and the search is executed.
By setting the value of `skk-search-prog-list' the dictionaries
searched and the order of search can be changed.
According to the value of this variable the skkserv.el will be
autoloaded."
)

;;;###skk-autoload
(defvar skk-search-prog-list
  '((skk-search-kakutei-jisyo-file skk-kakutei-jisyo 10000 t)
    (skk-search-jisyo-file skk-initial-search-jisyo 10000 t)
    (skk-search-jisyo-file skk-jisyo 0 t)
    ;; skk-auto.el $B$r%m!<%I$9$k$H2<5-$NMWAG$,%W%i%9$5$l$k!#(B
    ;;(skk-okuri-search)
    (skk-search-jisyo-file skk-large-jisyo 10000)
    ;; skk-server.el $B$r%m!<%I$9$k$H2<5-$NMWAG$,%W%i%9$5$l$k!#(B
    ;;(skk-search-server skk-aux-large-jisyo 10000)
    ;; skk-server-host $B$b$7$/$O(B skk-servers-list $B$r;XDj$9$k$H!"(Bskk-server.el 
    ;; $B$,(B autoload $B$5$l$k!#(B
    )
  "*$B8!:w4X?t!"8!:wBP>]$N<-=q$r7hDj$9$k$?$a$N%j%9%H!#(B
$BJQ49$7$?8uJd$rJV$9(B S $B<0$r%j%9%H$N7A$KI=5-$7$?$b$N!#(B
skk-search $B4X?t$,(B skk-search-prog-list $B$N(B car $B$+$i8eJ}8~$X=gHV$K(B S $B<0$NI>2A$r(B
$B9T$$JQ49$r9T$J$&!#(B

This list determines the search functions used and the dictionaries
searched.
A list of S-expressions returning conversion candidates.
The function `skk-search' performs conversions by evaluating each S-
expression in order, starting with the car of `skk-search-prog-list'."
)

;;;###skk-autoload
(defvar skk-jisyo (if (eq system-type 'ms-dos) "~/_skk-jisyo" "~/.skk-jisyo")
  "*SKK $B$N%f!<%6!<<-=q!#(B

SKK's dictionary of user-specified conversions." )

;;;###skk-autoload
(defvar skk-backup-jisyo
  (if (eq system-type 'ms-dos) "~/_skk-jisyo.BAK" "~/.skk-jisyo.BAK")
  "*SKK $B$N%f!<%6!<<-=q$N%P%C%/%"%C%W%U%!%$%k!#(B

Name of user dictionary backup (a file name as a string)."
)

;;;###skk-autoload
(defvar skk-jisyo-code nil
  "*Non-nil $B$G$"$l$P!"$=$NCM$G<-=q%P%C%U%!$N4A;z%3!<%I$r@_Dj$9$k!#(B
Mule $B$G$O!"(B*euc-japan*, *sjis*, *junet*$B!#(B
$B$^$?!"(B\"euc\", \"ujis\", \"sjis\", \"jis\" $B$J$I$NJ8;zNs$K$h$C$F$b;XDj$,(B
$B2DG=!#(B

If non-nil, the value sets the kanji code used in dictionary buffers.
In Mule, the symbols *euc-japan*, *sjis*, or *junet*.  Can also be
specified as a string such as \"euc\", \"ujis\", \"sjis\", or \"jis\"."
)

;;;###skk-autoload
(defvar skk-keep-record t
  "*Non-nil $B$G$"$l$P!"JQ49$K4X$9$k5-O?$r(B skk-record-file $B$K<h$k!#(B

If non-nil, a record of conversions is kept in `skk-record-file'.")

;;;###skk-autoload
(defvar skk-record-file
  (if (eq system-type 'ms-dos) "~/_skk-record" "~/.skk-record")
  "*$B%f!<%6!<<-=q$NE}7W$r<h$k%U%!%$%k!#(B
$B<-=q%;!<%V$N;~9o!"C18l$NEPO??t!"3NDj$r9T$C$?2s?t!"3NDjN(!"A4BN$N8l?t$N(B
$B>pJs$r<}$a$k!#(B

File containing statistics about the user dictionary.

At the time the dictionary is saved, the number of words registered,
number of conversions accepted, rate of acceptance, and the total
number of words are collected." )

;;;###skk-autoload
(defvar skk-kakutei-key "\C-j"
  "*$B3NDjF0:n(B (\"skk-kakutei\") $B$r9T$&%-!<!#(B

The key that executes conversion confirmation (\"skk-kakutei\").")

;;;###skk-autoload
(defvar skk-use-vip nil
  "*Non-nil $B$G$"$l$P!"(BVIP $B$KBP1~$9$k!#(B

If non-nil, VIP compatibility mode." )

;;;###skk-autoload
(defvar skk-use-viper nil
  "*Non-nil $B$G$"$l$P!"(BVIPER $B$KBP1~$9$k!#!#(B

If non-nil, VIPER compatibility mode." )

;;;###skk-autoload
(defvar skk-henkan-okuri-strictly nil
  "*Non-nil $B$G$"$l$P!"8+=P$78l$HAw$j2>L>$,0lCW$7$?$H$-$@$18uJd$H$7$F=PNO$9$k!#(B
$BNc$($P!"2<5-$N$h$&$J<-=q%(%s%H%j$,!"(Bskk-jisyo \($B%W%i%$%Y!<%H<-=q(B\) $B$K$"$C$?>l9g$K(B

  \"$B$*$*(Bk /$BBg(B/$BB?(B/[$B$/(B/$BB?(B/]/[$B$-(B/$BBg(B/]/\"

\"$B"&$*$*(B*$B$/(B\" $B$rJQ49$7$?$H$-!"(B\"$BB?$/(B\" $B$N$_$r=PNO$7!"(B\"$BBg$/(B\" $B$r=PNO$7$J$$!#(B

SKK-JISYO.[SML] $B$NAw$j2>L>%(%s%H%j$O>e5-$N7A<0$K$J$C$F$$$J$$$N$G!"(Bskk-jisyo $B$N(B
$BAw$j$"$j$N<-=q%(%s%H%j$,$3$N7A<0$N$b$N$r$"$^$j4^$s$G$$$J$$>l9g$O!"$3$N%*%W%7%g(B
$B%s$r(B on $B$K$9$k$3$H$G!"$9$0$KC18lEPO?$KF~$C$F$7$^$&$N$GCm0U$9$k$3$H!#(B

skk-process-okuri-early $B$NCM$,(B nil $B$J$i$P>e5-$N7A<0$G(B skk-jisyo $B$,:n$i$l$k!#(B

Emacs 19 $B%Y!<%9$N(B Mule $B$J$i$P!"2<5-$N%U%)!<%`$rI>2A$9$k$3$H$G!"C18lEPO?$KF~$C(B
$B$?$H$-$@$10l;~E*$K$3$N%*%W%7%g%s$r(B nil $B$K$9$k$3$H$,$G$-$k!#(B

    \(add-hook 'minibuffer-setup-hook
              \(function
               \(lambda \(\)
                 \(if \(and \(boundp 'skk-henkan-okuri-strictly\)
                          skk-henkan-okuri-strictly
                          \(not \(eq last-command 'skk-purge-from-jisyo\)\) \)
                     \(progn
                       \(setq skk-henkan-okuri-strictly nil\)
                       \(put 'skk-henkan-okuri-strictly 'temporary-nil t\) \)\)\)\)\)

    \(add-hook 'minibuffer-exit-hook
              \(function
               \(lambda \(\)
                 \(if \(get 'skk-henkan-okuri-strictly 'temporary-nil\)
                     \(progn
                       \(put 'skk-henkan-okuri-strictly 'temporary-nil nil\)
                       \(setq skk-henkan-okuri-strictly t\) \)\)\)\)\)

$B$3$N%*%W%7%g%sMxMQ;~$O!"(Bskk-process-okuri-early $B$NCM$O(B nil $B$G$J$1$l$P$J$i$J$$(B
\($B%a%K%e!<%P!<(B $B$rMxMQ$7$F%+%9%?%^%$%:$7$?>l9g$O<+F0E*$KD4@0$5$l$k(B\)$B!#(B

If non-nil, only when the key and its inflected suffix are given
together in the dictionary will they be output as a candidate.  For
example, if the following entry is in `skk-jisyo' (the provate
dictionary),

  \"$B$*$*(Bk /$BBg(B/$BB?(B/[$B$/(B/$BB?(B/]/[$B$-(B/$BBg(B/]/\"

then when converting \"$B"&$*$*(B*$B$/(B\", only \"$BB?$/(B\" wil be output; \"$BBg$/(B
\" will not be offered as a candidate.

The inflected suffixes in SKK-JISYO.[SML] are not given in the above
way, so if very few of the entries in skk-jisyo are given in that
form, then when this option is set `on', \"word registration mode\" will 
be entered extremely often.

If the value of `skk-process-okuri-early' is `nil', new entries in
`skk-jisyo' will be created in the form above.

If using a Mule based on Emacs 19 or later, you can arrange for this
option to be temporarily set to `nil' by evaluating the following
form:

    \(add-hook 'minibuffer-setup-hook
              \(function
               \(lambda \(\)
                 \(if \(and \(boundp 'skk-henkan-okuri-strictly\)
                          skk-henkan-okuri-strictly
                          \(not \(eq last-command 'skk-purge-from-jisyo\)\) \)
                     \(progn
                       \(setq skk-henkan-okuri-strictly nil\)
                       \(put 'skk-henkan-okuri-strictly 'temporary-nil t\) \)\)\)\)\)

    \(add-hook 'minibuffer-exit-hook
              \(function
               \(lambda \(\)
                 \(if \(get 'skk-henkan-okuri-strictly 'temporary-nil\)
                     \(progn
                       \(put 'skk-henkan-okuri-strictly 'temporary-nil nil\)
                       \(setq skk-henkan-okuri-strictly t\) \)\)\)\)\)

When using this option, `skk-process-okuri-early' must be `nil'.
(When using customize from the menubar this will automatically
temporarily be set to `nil'.)" )

;;;###skk-autoload
(defvar skk-henkan-strict-okuri-precedence nil
  "*Non-nil $B$G$"$l$P!"8+=P$78l$HAw$j2>L>$,0lCW$7$?8uJd$rM%@h$7$FI=<($9$k!#(B
$BNc$($P!"2<5-$N$h$&$J<-=q%(%s%H%j$,!"(Bskk-jisyo \($B%W%i%$%Y!<%H<-=q(B\) $B$K$"$C$?>l9g$K(B

  \"$B$*$*(Bk /$BBg(B/$BB?(B/[$B$/(B/$BB?(B/]/[$B$-(B/$BBg(B/]/\"

\"$B"&$*$*(B*$B$/(B\" $B$rJQ49$7$?$H$-!"$^$:(B\"$BB?$/(B\" $B$r=PNO$7!"(B
$B<!$K(B \"$BBg$/(B\" $B$r=PNO$9$k!#(B

\"$BBg$/(B\"$B$J$I$N8uJd$O$&$C$H$&$7$$$,!"$9$0$KC18lEPO?$K$O$$$C$F$7$^$&$N$b(B
$B7y$J$R$H$K$*$9$9$a!#(B

$B$3$N%*%W%7%g%sMxMQ;~$O!"(Bskk-process-okuri-early $B$NCM$O(B nil $B$G$J$i$J$$!#(B
$B$^$?(B skk-henkan-okuri-strictly $B$,(B non-nil $B$N$H$-$O!"$3$NJQ?t$OL5;k$5$l$k!#(B
\($B%a%K%e!<%P!<(B $B$rMxMQ$7$F%+%9%?%^%$%:$7$?>l9g$O<+F0E*$KD4@0$5$l$k(B\)$B!#(B")
 
;;;###skk-autoload
(defvar skk-auto-okuri-process nil
  "*Non-nil $B$G$"$l$P!"Aw$j2>L>ItJ,$r<+F0G'<1$7$FJQ49$r9T$&!#(B
$BNc$($P!"(B

    \"Uresii (\"UreSii\" $B$G$O$J$/(B) -> $B4r$7$$(B\"

$B$N$h$&$KJQ49$5$l$k!#C"$7!"(Bskk-jisyo $B<-=q(B \($B%W%i%$%Y!<%H<-=q(B\) $B$,!"(B

    \"$B$&$l(Bs /$B4r(B/[$B$7(B/$B4r(B/]/\"

$B$N$h$&$J7A<0$K$J$C$F$$$k$3$H$,I,MW$G$"$k(B \(SKK-JISYO.[SML] $B$O$3$N7A<0$KBP1~$7(B
$B$F$$$J$$$N$G!"(Bskk-jisyo $B$K$3$N%(%s%H%j$,$J$1$l$P$J$i$J$$(B\)$B!#(B

$B$3$N%*%W%7%g%sMxMQ;~$O!"(Bskk-process-okuri-early $B$NCM$O(B nil $B$G$J$1$l$P$J$i$J$$(B
\($B%a%K%e!<%P!<(B $B$rMxMQ$7$F%+%9%?%^%$%:$7$?>l9g$O<+F0E*$KD4@0$5$l$k(B\)$B!#(B" )

;;;###skk-autoload
(defvar skk-process-okuri-early nil
  "*Non-nil $B$G$"$l$P!"Aw$j2>L>$N%m!<%^;z%W%l%U%#%C%/%9$NF~NO;~E@$GJQ49$r3+;O$9$k!#(B
$BNc$($P!"(B

    \"UgoK -> $B"'F0(Bk\"$B!#(B

$BAw$j2>L>$,J,$i$J$$$^$^JQ49$7$F$$$k$3$H$K$J$k$N$G!"(Bskk-jisyo $B$,Aw$j2>L>$KBP1~$7(B
$B$?7A$K@.D9$7$J$$!#$D$^$j(B

    \"$B$&$4(Bk /$BF0(B/\"

$B$N$h$&$J7ABV$N$^$^$H$J$k!#$?$@$7!"4{$K(B

    \"$B$&$4(Bk /$BF0(B/[$B$/(B/$BF0(B/]/[$B$+(B/$BF0(B/]/[$B$1(B/$BF0(B/]/[$B$-(B/$BF0(B/]/[$B$3(B/$BF0(B/]/\"

$B$N$h$&$J%(%s%H%j$,(B skk-jisyo $B$K$"$l$P!"$=$l$rGK2u$7$J$$!#(B

nil $B$G$"$l$P!"Aw$j2>L>$NF~NO$,40N;$7$?;~E@$GJQ49$,3+;O$9$k!#Nc$($P!"(B

    \"UgoK -> $B"&$&$4(B*k\", \"UgoKu -> $B"'F0$/(B\"

$B$3$N%*%W%7%g%s$r(B on $B$K$7$F(B skk-mode $B$r5/F0$9$k$H!"N>N)$G$-$J$$%*%W%7%g%s$G$"$k(B
skk-kakutei-early, skk-auto-okuri-process, skk-henkan-okuri-strictly $B$O(B nil $B$K(B
$B%;%C%H$5$l$k!#(B" )

;;;###skk-autoload
(defvar skk-egg-like-newline nil
  "*Non-nil $B$G$"$l$P!""'%b!<%I$G2~9T$r%?%$%W$7$F$b3NDj$9$k$N$_$G2~9T$7$J$$!#(B" )

;;;###skk-autoload
(defvar skk-kakutei-early t
  "*Non-nil $B$G$"$l$P(B skk-kana-input $B$,8F$P$l$?$H$-$K8=:_$N8uJd$r3NDj$9$k!#(B
$BNc$($P!"(B

    \"$B"&$+$/$F$$(B -> $B"'3NDj(B -> $B3NDj(Bs -> $B3NDj$9(B\"

$B$N$h$&$KJQ498e!"!V$9!W$N(B prefix $B$G$"$k(B \"s\" $B$rF~NO$7$?;~E@$G3NDj$9$k!#(B
nil $B$G$"$l$P!"Nc$($P(B

    \"$B"&$+$/$F$$(B -> $B"'3NDj(B -> $B"'3NDj(Bs -> $B"'3NDj$9$k(B -> $B3NDj$9$k!#(B\"

$B$N$h$&$K(B skk-kakutei $B$rD>@\!"4V@\$K%3!<%k$9$k$^$G(B \($B6gFIE@$rF~NO$7$?$j!"?7$?$J(B
$B"&%b!<%I$KF~$C$?$j$9$k$H4V@\E*$K(B skk-kakutei $B$r%3!<%k$9$k(B\) $B$O!"3NDj$7$J$$$N$G!"(B
$B$=$N4V$O!"JQ498uJd$rA*$S$J$*$9$3$H$J$I$,2DG=!#(B

$B$3$N%*%W%7%g%sMxMQ;~$O!"(Bskk-process-okuri-early $B$NCM$O(B nil $B$G$J$1$l$P$J$i$J$$(B
\($B%a%K%e!<%P!<(B $B$rMxMQ$7$F%+%9%?%^%$%:$7$?>l9g$O<+F0E*$KD4@0$5$l$k(B\)$B!#(B" )

;;;###skk-autoload
(defvar skk-delete-implies-kakutei t
  "*Non-nil $B$G$"$l$P!""'%b!<%I$G(B BS $B$r2!$9$H!"A0$N0lJ8;z$r:o=|$73NDj$9$k!#(B
nil $B$G$"$l$P!"0l$DA0$N8uJd$rI=<($9$k!#(B")

;;;###skk-autoload
(defvar skk-allow-spaces-newlines-and-tabs t
  "*Non-nil $B$G$"$l$P!"(Bskk-henkan-key $B$K%9%Z!<%9!"%?%V!"2~9T$,$"$C$F$bJQ492DG=!#(B
$BNc$($P!"2<5-$N$h$&$K(B skk-henkan-key $B$NCf$K2~9T$,F~$C$F$$$F$bJQ49$,2DG=$G$"$k!#(B

     \"$B"&$+(B
  $B$J(B\"
   -> \"$B2>L>(B\"

$B$3$NCM$,(B nil $B$G$"$l$P!":G=i$N%9%Z!<%9$G(B skk-henkan-key $B$r@Z$j5M$a$F$7$^$$!"(B
$B0J9_$N%9%Z!<%9!"%?%V!"2~9T$OL5;k$5$l$k!#(B
$B$3$NCM$O!"(Bskk-start-henkan, skk-ascii-henkan, skk-katakana-henkan,
skk-hiragana-henkan, skk-zenkaku-henkan $B5Z$S(B skk-backward-and-set-henkan-point
$B$NF0:n$K1F6A$9$k!#(B")

;;;###skk-autoload
(defvar skk-convert-okurigana-into-katakana nil
  "*Non-nil $B$G$"$l$P!"%+%?%+%J%b!<%I$GJQ49$7$?$H$-$KAw$j2>L>$b%+%?%+%J$KJQ49$9$k!#(B" )

;;;###skk-autoload
(defvar skk-delete-okuri-when-quit nil
  "*Non-nil $B$G$"$l$P!"Aw$j$"$j$NJQ49Cf$K(B \"C-g\" $B$r2!$9$HAw$j2>L>$r>C$7"&%b!<%I$KF~$k!#(B
$BNc$($P!"(B

    \"$B"&$J(B*$B$/(B -> $B"'5c$/(B -> \"C-g\" ->$B"&$J(B\"

nil $B$G$"$l$P!"Aw$j2>L>$r4^$a$?8+=P$78l$r$=$N$^$^;D$7!""#%b!<%I$KF~$k!#Nc$($P!"(B

    \"$B"&$J(B*$B$/(B -> $B"'5c$/(B -> \"C-g\" -> $B$J$/(B\"" )

;;;###skk-autoload
(defvar skk-henkan-show-candidates-keys '(?a ?s ?d ?f ?j ?k ?l)
  "*$B%a%K%e!<7A<0$G8uJd$rA*Br$9$k$H$-$NA*Br%-!<$N%j%9%H!#(B
\"x\", \" \" $B5Z$S(B \"C-g\" $B0J30$N(B 7 $B$D$N%-!<(B (char type) $B$r4^$`I,MW$,$"(B
$B$k!#(B\"x\", \" \" $B5Z$S(B \"C-g\" $B$O8uJdA*Br;~$K$=$l$>$lFCJL$J;E;v$K3d$jEv(B
$B$F$i$l$F$$$k$N$G!"$3$N%j%9%H$NCf$K$O4^$a$J$$$3$H!#(B")

;;;###skk-autoload
(defvar skk-ascii-mode-string " SKK"
  "*SKK $B$,(B ascii $B%b!<%I$G$"$k$H$-$K%b!<%I%i%$%s$KI=<($5$l$kJ8;zNs!#(B" )

;;;###skk-autoload
(defvar skk-hirakana-mode-string " $B$+$J(B"
  "*$B$R$i$,$J%b!<%I$G$"$k$H$-$K%b!<%I%i%$%s$KI=<($5$l$kJ8;zNs!#(B")

;;;###skk-autoload
(defvar skk-katakana-mode-string " $B%+%J(B"
  "*$B%+%?%+%J%b!<%I$G$"$k$H$-$K%b!<%I%i%$%s$KI=<($5$l$kJ8;zNs!#(B")

;;;###skk-autoload
(defvar skk-zenkaku-mode-string " $BA41Q(B"
  "*$BA41Q%b!<%I$G$"$k$H$-$K%b!<%I%i%$%s$KI=<($5$l$kJ8;zNs!#(B")

;;;###skk-autoload
(defvar skk-abbrev-mode-string " a$B$"(B"
  "*SKK abbrev $B%b!<%I$G$"$k$H$-$K%b!<%I%i%$%s$KI=<($5$l$kJ8;zNs!#(B")

;;;###skk-autoload
(defvar skk-echo t
  "*Non-nil $B$G$"$l$P!"2>L>J8;z$N%W%l%U%#%C%/%9$rI=<($9$k!#(B" )

;;;###skk-autoload
(defvar skk-use-numeric-conversion t
  "*Non-nil $B$G$"$l$P!"?tCMJQ49$r9T$&!#(B" )

;;;###skk-autoload
(defvar skk-char-type-vector
  [0 0 0 0 0 0 0 0
   5 0 0 0 0 0 0 0
   0 0 0 0 0 0 0 0
   0 0 0 0 0 0 0 0
   0 0 0 0 0 0 0 0
   0 0 0 0 0 0 0 0
   0 0 0 0 0 0 0 0
   0 0 0 0 0 0 0 0
   0 4 4 4 4 4 4 4
   4 4 4 4 0 4 4 4
   4 0 4 4 4 4 4 4
   0 4 4 0 0 0 0 0
   0 3 1 1 1 3 1 1
   1 3 1 1 0 1 2 3
   1 0 1 1 1 3 1 1
   2 1 1 0 0 0 0 5]
  "*skk-kana-input $B$G;2>H$9$k$+$JJ8;zJQ49$N$?$a$N(B char type $B%Y%/%?!<!#(B
$B3FMWAG$N?t;z$N0UL#$O2<5-$NDL$j!#(B

0 $B%m!<%^J8;z$h$j$+$JJ8;z$X$NJQ49$rCf;_$9$k(B ($B8=:_$N$H$3$m;HMQ$7$F$$$J$$(B)$B!#(B
1 $BB%2;$N0lItJ,$H$J$jF@$k;R2;!#(B
2 $B>e5-(B 1 $B0J30$N;R2;(B (n, x)
3 $BJl2;(B
4 skk-mode $B$G!"(Bskk-set-henkan-point $B$K3d$jIU$1$i$l$F$$$kJ8;z!#(B
5 $B%W%l%U%#%C%/%9$r>C5n$9$k(B" )

;;;###skk-autoload
(defvar skk-standard-rom-kana-rule-list
  '(("b" "b" nil) ("by" "by" nil)
    ("c" "c" nil) ("ch" "ch" nil) ("cy" "cy" nil)
    ("d" "d" nil) ("dh" "dh" nil)
    ("dy" "dy" nil)
    ("f" "f" nil) ("fy" "fy" nil)
    ("g" "g" nil) ("gy" "gy" nil)
    ("h" "h" nil) ("hy" "hy" nil)
    ("j" "j" nil) ("jy" "jy" nil)
    ("k" "k" nil) ("ky" "ky" nil)
    ("m" "m" nil) ("my" "my" nil)
    ("n" "n" nil) ("ny" "ny" nil)
    ("p" "p" nil) ("py" "py" nil)
    ("r" "r" nil) ("ry" "ry" nil)
    ("s" "s" nil) ("sh" "sh" nil)
    ("sy" "sy" nil)
    ("t" "t" nil) ("th" "th" nil)
    ("ts" "ts" nil) ("ty" "ty" nil)
    ("v" "v" nil) ("w" "w" nil)
    ("x" "x" nil) ("xk" "xk" nil) ("xt" "xt" nil)
    ("xw" "xw" nil) ("xy" "xy" nil)
    ("y" "y" nil)
    ("z" "z" nil) ("zy" "zy" nil)

    ("bb" "b" ("$B%C(B" . "$B$C(B"))
    ("cc" "c" ("$B%C(B" . "$B$C(B"))
    ("dd" "d" ("$B%C(B" . "$B$C(B"))
    ("ff" "f" ("$B%C(B" . "$B$C(B"))
    ("gg" "g" ("$B%C(B" . "$B$C(B"))
    ("hh" "h" ("$B%C(B" . "$B$C(B"))
    ("jj" "j" ("$B%C(B" . "$B$C(B"))
    ("kk" "k" ("$B%C(B" . "$B$C(B"))
    ("mm" "m" ("$B%C(B" . "$B$C(B"))
    ;;("nn" "n" ("$B%C(B" . "$B$C(B"))
    ("pp" "p" ("$B%C(B" . "$B$C(B"))
    ("rr" "r" ("$B%C(B" . "$B$C(B"))
    ("ss" "s" ("$B%C(B" . "$B$C(B"))
    ("tt" "t" ("$B%C(B" . "$B$C(B"))
    ("vv" "v" ("$B%C(B" . "$B$C(B"))
    ("ww" "w" ("$B%C(B" . "$B$C(B"))
    ("xx" "x" ("$B%C(B" . "$B$C(B"))
    ("yy" "y" ("$B%C(B" . "$B$C(B"))
    ("zz" "z" ("$B%C(B" . "$B$C(B"))

    ("a" nil ("$B%"(B" . "$B$"(B"))
    ("ba" nil ("$B%P(B" . "$B$P(B")) ("bya" nil ("$B%S%c(B" . "$B$S$c(B"))
    ("cha" nil ("$B%A%c(B" . "$B$A$c(B")) ("cya" nil ("$B%A%c(B" . "$B$A$c(B"))
    ("da" nil ("$B%@(B" . "$B$@(B")) ("dha" nil ("$B%G%c(B" . "$B$G$c(B"))
    ("dya" nil ("$B%B%c(B" . "$B$B$c(B"))
    ("fa" nil ("$B%U%!(B" . "$B$U$!(B")) ("fya" nil ("$B%U%c(B" . "$B$U$c(B"))
    ("ga" nil ("$B%,(B" . "$B$,(B")) ("gya" nil ("$B%.%c(B" . "$B$.$c(B"))
    ("ha" nil ("$B%O(B" . "$B$O(B")) ("hya" nil ("$B%R%c(B" . "$B$R$c(B"))
    ("ja" nil ("$B%8%c(B" . "$B$8$c(B")) ("jya" nil ("$B%8%c(B" . "$B$8$c(B"))
    ("ka" nil ("$B%+(B" . "$B$+(B")) ("kya" nil ("$B%-%c(B" . "$B$-$c(B"))
    ("ma" nil ("$B%^(B" . "$B$^(B")) ("mya" nil ("$B%_%c(B" . "$B$_$c(B"))
    ("na" nil ("$B%J(B" . "$B$J(B")) ("nya" nil ("$B%K%c(B" . "$B$K$c(B"))
    ("pa" nil ("$B%Q(B" . "$B$Q(B")) ("pya" nil ("$B%T%c(B" . "$B$T$c(B"))
    ("ra" nil ("$B%i(B" . "$B$i(B")) ("rya" nil ("$B%j%c(B" . "$B$j$c(B"))
    ("sa" nil ("$B%5(B" . "$B$5(B")) ("sha" nil ("$B%7%c(B" . "$B$7$c(B"))
    ("sya" nil ("$B%7%c(B" . "$B$7$c(B"))
    ("ta" nil ("$B%?(B" . "$B$?(B")) ("tha" nil ("$B%F%!(B" . "$B$F$!(B"))
    ("tya" nil ("$B%A%c(B" . "$B$A$c(B"))
    ("va" nil ("$B%t%!(B" . "$B$&!+$!(B")) ("wa" nil ("$B%o(B" . "$B$o(B"))
    ("xa" nil ("$B%!(B" . "$B$!(B")) ("xka" nil ("$B%u(B" . "$B$+(B"))
    ("xwa" nil ("$B%n(B" . "$B$n(B")) ("xya" nil ("$B%c(B" . "$B$c(B"))
    ("ya" nil ("$B%d(B" . "$B$d(B"))
    ("za" nil ("$B%6(B" . "$B$6(B")) ("zya" nil ("$B%8%c(B" . "$B$8$c(B"))

    ("i" nil ("$B%$(B" . "$B$$(B"))
    ("bi" nil ("$B%S(B" . "$B$S(B")) ("byi" nil ("$B%S%#(B" . "$B$S$#(B"))
    ("chi" nil ("$B%A(B" . "$B$A(B")) ("cyi" nil ("$B%A%#(B" . "$B$A$#(B"))
    ("di" nil ("$B%B(B" . "$B$B(B")) ("dhi" nil ("$B%G%#(B" . "$B$G$#(B"))
    ("dyi" nil ("$B%B%#(B" . "$B$B$#(B"))
    ("fi" nil ("$B%U%#(B" . "$B$U$#(B")) ("fyi" nil ("$B%U%#(B" . "$B$U$#(B"))
    ("gi" nil ("$B%.(B" . "$B$.(B")) ("gyi" nil ("$B%.%#(B" . "$B$.$#(B"))
    ("hi" nil ("$B%R(B" . "$B$R(B")) ("hyi" nil ("$B%R%#(B" . "$B$R$#(B"))
    ("ji" nil ("$B%8(B" . "$B$8(B")) ("jyi" nil ("$B%8%#(B" . "$B$8$#(B"))
    ("ki" nil ("$B%-(B" . "$B$-(B")) ("kyi" nil ("$B%-%#(B" . "$B$-$#(B"))
    ("mi" nil ("$B%_(B" . "$B$_(B")) ("myi" nil ("$B%_%#(B" . "$B$_$#(B"))
    ("ni" nil ("$B%K(B" . "$B$K(B")) ("nyi" nil ("$B%K%#(B" . "$B$K$#(B"))
    ("pi" nil ("$B%T(B" . "$B$T(B")) ("pyi" nil ("$B%T%#(B" . "$B$T$#(B"))
    ("ri" nil ("$B%j(B" . "$B$j(B")) ("ryi" nil ("$B%j%#(B" . "$B$j$#(B"))
    ("si" nil ("$B%7(B" . "$B$7(B")) ("shi" nil ("$B%7(B" . "$B$7(B"))
    ("syi" nil ("$B%7%#(B" . "$B$7$#(B"))
    ("ti" nil ("$B%A(B" . "$B$A(B")) ("thi" nil ("$B%F%#(B" . "$B$F$#(B"))
    ("tyi" nil ("$B%A%#(B" . "$B$A$#(B"))
    ("vi" nil ("$B%t%#(B" . "$B$&!+$#(B")) ("wi" nil ("$B%&%#(B" . "$B$&$#(B"))
    ("xi" nil ("$B%#(B" . "$B$#(B")) ("xwi" nil ("$B%p(B" . "$B$p(B"))
    ("zi" nil ("$B%8(B" . "$B$8(B")) ("zyi" nil ("$B%8%#(B" . "$B$8$#(B"))

    ("u" nil ("$B%&(B" . "$B$&(B"))
    ("bu" nil ("$B%V(B" . "$B$V(B")) ("byu" nil ("$B%S%e(B" . "$B$S$e(B"))
    ("chu" nil ("$B%A%e(B" . "$B$A$e(B")) ("cyu" nil ("$B%A%e(B" . "$B$A$e(B"))
    ("du" nil ("$B%E(B" . "$B$E(B")) ("dhu" nil ("$B%G%e(B" . "$B$G$e(B"))
    ("dyu" nil ("$B%B%e(B" . "$B$B$e(B"))
    ("fu" nil ("$B%U(B" . "$B$U(B")) ("fyu" nil ("$B%U%e(B" . "$B$U$e(B"))
    ("gu" nil ("$B%0(B" . "$B$0(B")) ("gyu" nil ("$B%.%e(B" . "$B$.$e(B"))
    ("hu" nil ("$B%U(B" . "$B$U(B")) ("hyu" nil ("$B%R%e(B" . "$B$R$e(B"))
    ("ju" nil ("$B%8%e(B" . "$B$8$e(B")) ("jyu" nil ("$B%8%e(B" . "$B$8$e(B"))
    ("ku" nil ("$B%/(B" . "$B$/(B")) ("kyu" nil ("$B%-%e(B" . "$B$-$e(B"))
    ("mu" nil ("$B%`(B" . "$B$`(B")) ("myu" nil ("$B%_%e(B" . "$B$_$e(B"))
    ("nu" nil ("$B%L(B" . "$B$L(B")) ("nyu" nil ("$B%K%e(B" . "$B$K$e(B"))
    ("pu" nil ("$B%W(B" . "$B$W(B")) ("pyu" nil ("$B%T%e(B" . "$B$T$e(B"))
    ("ru" nil ("$B%k(B" . "$B$k(B")) ("ryu" nil ("$B%j%e(B" . "$B$j$e(B"))
    ("su" nil ("$B%9(B" . "$B$9(B")) ("shu" nil ("$B%7%e(B" . "$B$7$e(B"))
    ("syu" nil ("$B%7%e(B" . "$B$7$e(B"))
    ("tu" nil ("$B%D(B" . "$B$D(B")) ("thu" nil ("$B%F%e(B" . "$B$F$e(B"))
    ("tsu" nil ("$B%D(B" . "$B$D(B")) ("tyu" nil ("$B%A%e(B" . "$B$A$e(B"))
    ("vu" nil ("$B%t(B" . "$B$&!+(B")) ("wu" nil ("$B%&(B" . "$B$&(B"))
    ("xu" nil ("$B%%(B" . "$B$%(B")) ("xtu" nil ("$B%C(B" . "$B$C(B"))
    ("xtsu" nil ("$B%C(B" . "$B$C(B")) ("xyu" nil ("$B%e(B" . "$B$e(B"))
    ("yu" nil ("$B%f(B" . "$B$f(B"))
    ("zu" nil ("$B%:(B" . "$B$:(B")) ("zyu" nil ("$B%8%e(B" . "$B$8$e(B"))

    ("e" nil ("$B%((B" . "$B$((B"))
    ("be" nil ("$B%Y(B" . "$B$Y(B")) ("bye" nil ("$B%S%'(B" . "$B$S$'(B"))
    ("che" nil ("$B%A%'(B" . "$B$A$'(B")) ("cye" nil ("$B%A%'(B" . "$B$A$'(B"))
    ("de" nil ("$B%G(B" . "$B$G(B")) ("dhe" nil ("$B%G%'(B" . "$B$G$'(B"))
    ("dye" nil ("$B%B%'(B" . "$B$B$'(B"))
    ("fe" nil ("$B%U%'(B" . "$B$U$'(B")) ("fye" nil ("$B%U%'(B" . "$B$U$'(B"))
    ("ge" nil ("$B%2(B" . "$B$2(B")) ("gye" nil ("$B%.%'(B" . "$B$.$'(B"))
    ("he" nil ("$B%X(B" . "$B$X(B")) ("hye" nil ("$B%R%'(B" . "$B$R$'(B"))
    ("je" nil ("$B%8%'(B" . "$B$8$'(B")) ("jye" nil ("$B%8%'(B" . "$B$8$'(B"))
    ("ke" nil ("$B%1(B" . "$B$1(B")) ("kye" nil ("$B%-%'(B" . "$B$-$'(B"))
    ("me" nil ("$B%a(B" . "$B$a(B")) ("mye" nil ("$B%_%'(B" . "$B$_$'(B"))
    ("ne" nil ("$B%M(B" . "$B$M(B")) ("nye" nil ("$B%K%'(B" . "$B$K$'(B"))
    ("pe" nil ("$B%Z(B" . "$B$Z(B")) ("pye" nil ("$B%T%'(B" . "$B$T$'(B"))
    ("re" nil ("$B%l(B" . "$B$l(B")) ("rye" nil ("$B%j%'(B" . "$B$j$'(B"))
    ("se" nil ("$B%;(B" . "$B$;(B")) ("she" nil ("$B%7%'(B" . "$B$7$'(B"))
    ("sye" nil ("$B%7%'(B" . "$B$7$'(B"))
    ("te" nil ("$B%F(B" . "$B$F(B")) ("the" nil ("$B%F%'(B" . "$B$F$'(B"))
    ("tye" nil ("$B%A%'(B" . "$B$A$'(B"))
    ("ve" nil ("$B%t%'(B" . "$B$&!+$'(B")) ("we" nil ("$B%&%'(B" . "$B$&$'(B"))
    ("xe" nil ("$B%'(B" . "$B$'(B")) ("xke" nil ("$B%v(B" . "$B$1(B"))
    ("xwe" nil ("$B%q(B" . "$B$q(B"))
    ("ye" nil ("$B%$%'(B" . "$B$$$'(B"))
    ("ze" nil ("$B%<(B" . "$B$<(B")) ("zye" nil ("$B%8%'(B" . "$B$8$'(B"))

    ("o" nil ("$B%*(B" . "$B$*(B"))
    ("bo" nil ("$B%\(B" . "$B$\(B")) ("byo" nil ("$B%S%g(B" . "$B$S$g(B"))
    ("cho" nil ("$B%A%g(B" . "$B$A$g(B")) ("cyo" nil ("$B%A%g(B" . "$B$A$g(B"))
    ("do" nil ("$B%I(B" . "$B$I(B")) ("dho" nil ("$B%G%g(B" . "$B$G$g(B"))
    ("dyo" nil ("$B%B%g(B" . "$B$B$g(B"))
    ("fo" nil ("$B%U%)(B" . "$B$U$)(B")) ("fyo" nil ("$B%U%g(B" . "$B$U$g(B"))
    ("go" nil ("$B%4(B" . "$B$4(B")) ("gyo" nil ("$B%.%g(B" . "$B$.$g(B"))
    ("ho" nil ("$B%[(B" . "$B$[(B")) ("hyo" nil ("$B%R%g(B" . "$B$R$g(B"))
    ("jo" nil ("$B%8%g(B" . "$B$8$g(B")) ("jyo" nil ("$B%8%g(B" . "$B$8$g(B"))
    ("ko" nil ("$B%3(B" . "$B$3(B")) ("kyo" nil ("$B%-%g(B" . "$B$-$g(B"))
    ("mo" nil ("$B%b(B" . "$B$b(B")) ("myo" nil ("$B%_%g(B" . "$B$_$g(B"))
    ("no" nil ("$B%N(B" . "$B$N(B")) ("nyo" nil ("$B%K%g(B" . "$B$K$g(B"))
    ("po" nil ("$B%](B" . "$B$](B")) ("pyo" nil ("$B%T%g(B" . "$B$T$g(B"))
    ("ro" nil ("$B%m(B" . "$B$m(B")) ("ryo" nil ("$B%j%g(B" . "$B$j$g(B"))
    ("so" nil ("$B%=(B" . "$B$=(B")) ("sho" nil ("$B%7%g(B" . "$B$7$g(B"))
    ("syo" nil ("$B%7%g(B" . "$B$7$g(B"))
    ("to" nil ("$B%H(B" . "$B$H(B")) ("tho" nil ("$B%F%g(B" . "$B$F$g(B"))
    ("tyo" nil ("$B%A%g(B" . "$B$A$g(B"))
    ("vo" nil ("$B%t%)(B" . "$B$&!+$)(B")) ("wo" nil ("$B%r(B" . "$B$r(B"))
    ("xo" nil ("$B%)(B" . "$B$)(B")) ("xyo" nil ("$B%g(B" . "$B$g(B"))
    ("yo" nil ("$B%h(B" . "$B$h(B"))
    ("zo" nil ("$B%>(B" . "$B$>(B")) ("zyo" nil ("$B%8%g(B" . "$B$8$g(B"))

    ("nn" nil ("$B%s(B" . "$B$s(B"))
    ("n'" nil ("$B%s(B" . "$B$s(B"))

    ("z/" nil ("$B!&(B" . "$B!&(B")) ("z," nil ("$B!E(B" . "$B!E(B"))
    ("z." nil ("$B!D(B" . "$B!D(B")) ("z-" nil ("$B!A(B" . "$B!A(B"))
    ("zh" nil ("$B"+(B" . "$B"+(B")) ("zj" nil ("$B"-(B" . "$B"-(B"))
    ("zk" nil ("$B",(B" . "$B",(B")) ("zl" nil ("$B"*(B" . "$B"*(B"))
    ("z[" nil ("$B!X(B" . "$B!X(B")) ("z]" nil ("$B!Y(B" . "$B!Y(B")) )
  "SKK $B$NI8=`$N%m!<%^;z$+$JJQ49$N%*!<%H%^%H%s$N>uBVA+0\5,B'!#(B
$B%j%9%H$N3FMWAG$O!"(B\($B8=:_$N>uBV(B@$BF~NO(B $B<!$N>uBV(B $B=PNO(B\) \($BC"$7!"(B\"@\" $B$OO"@\(B\) $B$r0UL#(B
$B$9$k!#(B
$B%7%9%F%`MQ$J$N$G%+%9%?%^%$%:$K$O(B skk-rom-kana-rule-list $B$rMxMQ$7$F$/$@$5$$!#(B" )

;;;###skk-autoload
(defvar skk-rom-kana-rule-list
  nil
  "*$B%m!<%^;z$+$JJQ49$N%*!<%H%^%H%s$N>uBVA+0\5,B'!#(B
$B%j%9%H$N3FMWAG$O!"(B\($B8=:_$N>uBV(B@$BF~NO(B $B<!$N>uBV(B $B=PNO(B\) \($BC"$7!"(B\"@\" $B$OO"@\(B\) $B$r0UL#(B
$B$9$k!#%+%9%?%^%$%:$K$O(B skk-standard-rom-kana-rule-list $B$G$OL5$/!"(B
$B$3$A$i$rMxMQ$7$F$/$@$5$$!#(B" )

;;;###skk-autoload
(defvar skk-fallback-rule-alist
  '(("n" "$B%s(B" . "$B$s(B"))
  "*$B%m!<%^;z$+$JJQ49;~$K!"(Bskk-rom-kana-rule-list, skk-standard-rom-kana-rule-list $B$N(B
$B$"$H$K;2>H$5$l$k5,B'!#(B
$B%j%9%H$N3FMWAG$O!"(B\($B8=:_$N>uBV(B $B=PNO(B\) $B$r0UL#$9$k!#(B
$B$3$N5,B'$,E,MQ$5$l$?>l9g!"F~NO$O%9%H%j!<%`$KJV$5$l$k!#(B" )

;;;###skk-autoload
(defvar skk-postfix-rule-alist
  '(("oh" "$B%*(B" . "$B$*(B"))
  "*$B%m!<%^;z$+$JJQ49;~$K!"D>A0$N$+$JJ8;z$r:n$k$N$KMQ$$$i$l$?:G8e$NF~NO$H(B
$B8=:_$NF~NO$+$i$+$JJ8;z$r:n$j$@$9$?$a$N5,B'!#(B
$B%j%9%H$N3FMWAG$O!"(B\($BD>A0$NF~NO(B@$BF~NO(B $B=PNO(B\) \($BC"$7!"(B\"@\" $B$OO"@\(B\) $B$r0UL#$9$k!#(B" )

;;;###skk-autoload
(defvar skk-previous-candidate-char
  ?x
  "*skk-previous-candidate $B$r3dEv$F$?%-%c%i%/%?!#(B" )

;;;###skk-autoload
(defvar skk-okuri-char-alist
  nil
  "*" )

;;;###skk-autoload
(defvar skk-downcase-alist
  nil
  "*" )

;;;###skk-autoload
(defvar skk-input-vector
  [nil  nil  nil  nil  nil  nil  nil  nil  ;7
   nil  nil  nil  nil  nil  nil  nil  nil  ;15
   nil  nil  nil  nil  nil  nil  nil  nil  ;23
   nil  nil  nil  nil  nil  nil  nil  nil  ;31
   nil  "$B!*(B" nil  nil  nil  nil  nil  nil  ;39
   nil  nil  nil  nil  "$B!"(B" "$B!<(B" "$B!#(B" nil  ;47
   nil  nil  nil  nil  nil  nil  nil  nil  ;55
   nil  nil  "$B!'(B" "$B!((B" nil  nil  nil  "$B!)(B" ;63
   nil  nil  nil  nil  nil  nil  nil  nil  ;71
   nil  nil  nil  nil  nil  nil  nil  nil  ;79
   nil  nil  nil  nil  nil  nil  nil  nil  ;87
   nil  nil  nil  "$B!V(B" nil  "$B!W(B" nil  nil  ;95
   nil  nil  nil  nil  nil  nil  nil  nil  ;103
   nil  nil  nil  nil  nil  nil  nil  nil  ;111
   nil  nil  nil  nil  nil  nil  nil  nil  ;119
   nil  nil  nil  nil  nil  nil  nil  nil] ;127
  "*skk-self-insert $B$G;2>H$5$l$kJ8;z%F!<%V%k!#(B
$B%-!<$KBP1~$9$k0LCV$KJ8;zNs$,$"$l$P!"$R$i$,$J%b!<%I$b$7$/$O%+%?%+%J%b!<%I$G!"3:(B
$BEv$N%-!<$r2!$9$3$H$G!"BP1~$9$kJ8;z$,A^F~$5$l$k!#(B
$BNc$($P!"(B\"~\" $B%-!<$KBP1~$7$F!"(B\"$B!A(B\" $B$rA^F~$5$;$k$h$&$KJQ99$7$?$1$l$P!"(Bskk.el 
$B$N%m!<%I8e(B ($B$b$7$/$O(B skk-load-hook $B$rMxMQ$7$F(B)$B!"(B

  \(aset skk-input-vector 126 \"$B!A(B\"\)

$B$H$9$k$+!"$b$7$/$O!"(Bskk-input-vector $B$N(B 126 $BHVL\(B (0 $BHV$+$i?t$($F(B) $B$NCM$r(B
\"$B!A(B\" $B$H$9$k$h$&$J(B skk-input-vector $B$rD>@\=q$-!"(Bsetq $B$GBeF~$9$k(B \(126 $B$O!"(B?
{ $B$rI>2A$7$?$H$-$NCM(B\)$B!#(B" )

;;;###skk-autoload
(defvar skk-zenkaku-vector
  [nil  nil  nil  nil  nil  nil  nil  nil
   nil  nil  nil  nil  nil  nil  nil  nil
   nil  nil  nil  nil  nil  nil  nil  nil
   nil  nil  nil  nil  nil  nil  nil  nil
   "$B!!(B"  "$B!*(B" "$B!I(B" "$B!t(B" "$B!p(B" "$B!s(B" "$B!u(B" "$B!G(B"
   "$B!J(B" "$B!K(B" "$B!v(B" "$B!\(B" "$B!$(B" "$B!](B" "$B!%(B" "$B!?(B"
   "$B#0(B" "$B#1(B" "$B#2(B" "$B#3(B" "$B#4(B" "$B#5(B" "$B#6(B" "$B#7(B"
   "$B#8(B" "$B#9(B" "$B!'(B" "$B!((B" "$B!c(B" "$B!a(B" "$B!d(B" "$B!)(B"
   "$B!w(B" "$B#A(B" "$B#B(B" "$B#C(B" "$B#D(B" "$B#E(B" "$B#F(B" "$B#G(B"
   "$B#H(B" "$B#I(B" "$B#J(B" "$B#K(B" "$B#L(B" "$B#M(B" "$B#N(B" "$B#O(B"
   "$B#P(B" "$B#Q(B" "$B#R(B" "$B#S(B" "$B#T(B" "$B#U(B" "$B#V(B" "$B#W(B"
   "$B#X(B" "$B#Y(B" "$B#Z(B" "$B!N(B" "$B!@(B" "$B!O(B" "$B!0(B" "$B!2(B"
   "$B!F(B" "$B#a(B" "$B#b(B" "$B#c(B" "$B#d(B" "$B#e(B" "$B#f(B" "$B#g(B"
   "$B#h(B" "$B#i(B" "$B#j(B" "$B#k(B" "$B#l(B" "$B#m(B" "$B#n(B" "$B#o(B"
   "$B#p(B" "$B#q(B" "$B#r(B" "$B#s(B" "$B#t(B" "$B#u(B" "$B#v(B" "$B#w(B"
   "$B#x(B" "$B#y(B" "$B#z(B" "$B!P(B" "$B!C(B" "$B!Q(B" "$B!A(B" nil]
  "*skk-zenkaku-insert $B$G;2>H$5$l$kJ8;z%F!<%V%k!#(B
$B%-!<$KBP1~$9$k0LCV$KJ8;zNs$,$"$l$P!"A41Q%b!<%I$G3:Ev$N%-!<$r2!$9$3$H$G!"BP1~$9(B
$B$kJ8;z$,A^F~$5$l$k!#(B
$BCM$NJQ99J}K!$K$D$$$F$O!"(Bskk-input-vector $B$r;2>H$N$3$H!#(B" )

;;;###skk-autoload
(defvar skk-use-face (or window-system (skk-terminal-face-p))
  "*Non-nil $B$G$"$l$P!"(BEmacs 19 $B$N(B face $B$N5!G=$r;HMQ$7$FJQ49I=<($J$I$r9T$J$&!#(B" )

;;;###skk-autoload
(defvar skk-henkan-face
  (if (and (or window-system (skk-terminal-face-p))
           (or (and (fboundp 'frame-face-alist)
		    (assq 'highlight (frame-face-alist (selected-frame))))
	       (and (fboundp 'face-list)
		    (memq 'highlight (face-list)))) )
      'highlight )
  "*$BJQ498uJd$N(B face $BB0@-!#(Bskk-use-face $B$,(B non-nil $B$N$H$-$N$_M-8z!#(B
Emacs $BI8=`%U%'%$%9$N(B default, modeline, region, secondary-selection,
highlight, underline, bold, italic, bold-italic $B$NB>!"?7$?$K(B face $B$r:n$j;XDj$9(B
$B$k$3$H$b2DG=!#(B
$B?7$?$J(B face $B$r:n$j;XDj$9$k$K$O(B skk-make-face $B$rMxMQ$7$F!"(B

      \(skk-make-face 'DimGray/PeachPuff1\)
      \(setq skk-henkan-face 'DimGray/PeachPuff1\)

$B$N$h$&$K$9$k$N$,<j7Z!#(Bforeground $B$H(B background $B$N?';XDj$@$1$G$J$$6E$C$?(B face
$B$r:n$k>l9g$O!"(Bskk-make-face $B$G$OBP1~$G$-$J$$$N$G!"(BEmacs $B$N(B hilit19.el $B$N(B
hilit-lookup-face-create $B$J$I$rMxMQ$9$k!#?'$rIU$1$k>l9g$NG[?'$O!"(Bcanna.el $B$N(B
canna:attribute-alist $B$,NI$$Nc$+$b$7$l$J$$!#(B" )

;;;###skk-autoload
(defvar skk-use-color-cursor (and window-system
                                      (fboundp 'x-display-color-p)
                                      (x-display-color-p) )
  "*Non-nil $B$G$"$l$P!"(BSKK $B%b!<%I$NF~NO%b!<%I$K1~$8$F%+!<%=%k$K?'$rIU$1$k!#(B")

(defvar skk-default-cursor-color
  (if skk-xemacs
      (frame-property (selected-frame) 'cursor-color)
    (cdr (assq 'cursor-color (frame-parameters (selected-frame)))))
  "*SKK $B$N%*%U$r<($9%+!<%=%k?'!#(B" )

;; $BGX7J?'$r9u$K$7$F;HMQ$5$l$F$$$kJ}$G!"NI$$G[?'$,$"$l$P$*CN$i$;2<$5$$!#(B
;;;###skk-autoload
(defvar skk-hirakana-cursor-color (if (eq skk-background-mode 'light)
                                      "coral4"
                                    "pink" )
  "*$B$+$J%b!<%I$r<($9%+!<%=%k?'!#(B" )

;;;###skk-autoload
(defvar skk-katakana-cursor-color (if (eq skk-background-mode 'light)
                                          "forestgreen"
                                        "green" )
  "*$B%+%?%+%J%b!<%I$r<($9%+!<%=%k?'!#(B" )

;;;###skk-autoload
(defvar skk-zenkaku-cursor-color "gold"
  "*$BA43Q1Q;z%b!<%I$r<($9%+!<%=%k?'!#(B" )

;;;###skk-autoload
(defvar skk-ascii-cursor-color (if (eq skk-background-mode 'light)
                                       "ivory4"
                                     "gray" )
  "*$B%"%9%-!<%b!<%I$r<($9%+!<%=%k?'!#(B" )

;;;###skk-autoload
(defvar skk-abbrev-cursor-color "royalblue"
  "*$B%"%9%-!<%b!<%I$r<($9%+!<%=%k?'!#(B" )

;;;###skk-autoload
(defvar skk-report-set-cursor-error t
  "*Non-nil $B$G$"$l$P!"%+%i!<%^%C%W@Z$l$,5/$-$?>l9g!"%(%i!<%a%C%;!<%8$rI=<($9$k!#(B
nil $B$G$"$l$P!"I=<($7$J$$!#(B" )

;;;###skk-autoload
(defvar skk-use-cursor-change t
  "*Non-nil $B$G$"$l$P!"(BOvwrt $B%^%$%J!<%b!<%I;~$K%+!<%=%k$NI}$r=L$a$k!#(B" )

;;;###skk-autoload
(defvar skk-auto-insert-paren nil
  "*Non-nil $B$G$"$l$P!"(B2 $B$D$NJ8;zNs$r$^$H$a$FA^F~$7!"$=$NJ8;zNs$N4V$K%+!<%=%k$r0\F0$9$k!#(B
$BNc$($P!"(B\"$B!V(B\" $B$rF~NO$7$?$H$-$K(B \"$B!W(B\" $B$r<+F0E*$KA^F~$7!"N>$+$.$+$C$3$N4V$K(B
$B%+!<%=%k$r0\F0$9$k!#(B
$BA^F~$9$kJ8;zNs$O!"(Bskk-auto-paren-string-alist $B$G;XDj$9$k!#(B" )

;;;###skk-autoload
(defvar skk-auto-paren-string-alist
  '(("$B!V(B" . "$B!W(B") ("$B!X(B" . "$B!Y(B") ("(" . ")") ("$B!J(B" . "$B!K(B")
    ("{" . "}")("$B!P(B" . "$B!Q(B") ("$B!R(B" . "$B!S(B") ("$B!T(B" . "$B!U(B")
    ("[" . "]") ("$B!N(B" . "$B!O(B") ("$B!L(B" . "$B!M(B") ("$B!Z(B" . "$B![(B")
    ("\"" . "\"")("$B!H(B" . "$B!I(B")
    ;; skk-special-midashi-char-list $B$NMWAG$K$J$C$F$$$kJ8;z$O!"(B
    ;; skk-auto-paren-string-alist $B$K4^$a$F$b:o=|$5$l$k!#(B
    ;;("<" . ">")
    )
  "*$B<+F0E*$KBP$K$J$kJ8;zNs$rF~NO$9$k$?$a$NO"A[%j%9%H!#(B
car $B$NJ8;zNs$,A^F~$5$l$?$H$-$K(B cdr $B$NJ8;zNs$r<+F0E*$KA^F~$9$k!#(B" )

;;;###skk-autoload
(defvar skk-japanese-message-and-error nil
  "*Non-nil $B$G$"$l$P!"(BSKK $B$N%a%C%;!<%8$H%(%i!<$rF|K\8l$GI=<($9$k!#(B
nil $B$G$"$l$P!"1Q8l$GI=<($9$k!#(B" )

;;;###skk-autoload
(defvar skk-ascii-mode-map nil "*ASCII $B%b!<%I$N%-!<%^%C%W!#(B" )
(or skk-ascii-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map skk-kakutei-key 'skk-kakutei)
    (skk-define-menu-bar-map map)
    (setq skk-ascii-mode-map map)))

;;;###skk-autoload
(defvar skk-j-mode-map nil "*$B$+$J%b!<%I$N%-!<%^%C%W!#(B" )
(or skk-j-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "!" 'skk-self-insert)
    (define-key map "#" 'skk-self-insert)
    (define-key map "$" 'skk-display-code-for-char-at-point)
    (define-key map "%" 'skk-self-insert)
    (define-key map "&" 'skk-self-insert)
    (define-key map "'" 'skk-self-insert)
    (define-key map "*" 'skk-self-insert)
    (define-key map "+" 'skk-self-insert)
    (define-key map "," 'skk-insert-comma)
    (define-key map "-" 'skk-self-insert)
    (define-key map "." 'skk-insert-period)
    (define-key map "/" 'skk-abbrev-mode)
    (define-key map "0" 'skk-self-insert)
    (define-key map "1" 'skk-self-insert)
    (define-key map "2" 'skk-self-insert)
    (define-key map "3" 'skk-self-insert)
    (define-key map "4" 'skk-self-insert)
    (define-key map "5" 'skk-self-insert)
    (define-key map "6" 'skk-self-insert)
    (define-key map "7" 'skk-self-insert)
    (define-key map "8" 'skk-self-insert)
    (define-key map "9" 'skk-self-insert)
    (define-key map ":" 'skk-self-insert)
    (define-key map ";" 'skk-self-insert)
    ;; "<", ">", "?" $B$N(B 3 $BJ8;z$O!"(Bskk-special-midashi-char-list $B$NCM$,%G%#%U%)%k(B
    ;; $B%H$N$^$^$G$"$l$P!"(Bskk-setup-special-midashi-char $B$K$h$j(B
    ;; skk-set-henkan-point $B$K:F3d$jIU$1$5$l$k$,!"@_Dj$K$h$j$3$l$i$NJ8;z$r;XDj$7(B
    ;; $B$J$$>l9g$O!"(Bskk-self-insert $B$H$7$FF0$/$N$,K>$^$7$$!#(B
    (define-key map "<" 'skk-self-insert)
    (define-key map "=" 'skk-self-insert)
    (define-key map ">" 'skk-self-insert)
    (define-key map "?" 'skk-self-insert)
    (define-key map "@" 'skk-today)
    (define-key map "A" 'skk-set-henkan-point)
    (define-key map "B" 'skk-set-henkan-point)
    (define-key map "C" 'skk-set-henkan-point)
    (define-key map "D" 'skk-set-henkan-point)
    (define-key map "E" 'skk-set-henkan-point)
    (define-key map "F" 'skk-set-henkan-point)
    (define-key map "G" 'skk-set-henkan-point)
    (define-key map "H" 'skk-set-henkan-point)
    (define-key map "I" 'skk-set-henkan-point)
    (define-key map "J" 'skk-set-henkan-point)
    (define-key map "K" 'skk-set-henkan-point)
    (define-key map "L" 'skk-zenkaku-mode)
    (define-key map "M" 'skk-set-henkan-point)
    (define-key map "N" 'skk-set-henkan-point)
    (define-key map "O" 'skk-set-henkan-point)
    (define-key map "P" 'skk-set-henkan-point)
    (define-key map "Q" 'skk-set-henkan-point-subr)
    (define-key map "R" 'skk-set-henkan-point)
    (define-key map "S" 'skk-set-henkan-point)
    (define-key map "T" 'skk-set-henkan-point)
    (define-key map "U" 'skk-set-henkan-point)
    (define-key map "V" 'skk-set-henkan-point)
    (define-key map "W" 'skk-set-henkan-point)
    (define-key map "X" 'skk-purge-from-jisyo)
    (define-key map "Y" 'skk-set-henkan-point)
    (define-key map "Z" 'skk-set-henkan-point)
    (define-key map "\ " 'skk-start-henkan)
    (define-key map "\"" 'skk-self-insert)
    (define-key map "\(" 'skk-self-insert)
    (define-key map "\)" 'skk-self-insert)
    ;;(define-key map "\177" 'skk-delete-backward-char)
    ;;(define-key map "\C-g" 'skk-keyboard-quit)
    ;;(define-key map "\C-m" 'skk-newline)
    (define-key map "\[" 'skk-self-insert)
    (define-key map "\\" 'skk-input-by-code-or-menu)
    (define-key map "\]" 'skk-self-insert)
    (or skk-use-vip
        (define-key map "\M-\ " 'skk-start-henkan-with-completion) )
    (or skk-use-vip
        (define-key map "\M-Q" 'skk-backward-and-set-henkan-point) )
    (define-key map "\t" 'skk-try-completion)
    (define-key map "\{" 'skk-self-insert)
    (define-key map "\}" 'skk-self-insert)
    (define-key map "^" 'skk-self-insert)
    (define-key map "_" 'skk-self-insert)
    (define-key map "`" 'skk-self-insert)
    (define-key map "a" 'skk-kana-input)
    (define-key map "b" 'skk-kana-input)
    (define-key map "c" 'skk-kana-input)
    (define-key map "d" 'skk-kana-input)
    (define-key map "e" 'skk-kana-input)
    (define-key map "f" 'skk-kana-input)
    (define-key map "g" 'skk-kana-input)
    (define-key map "h" 'skk-kana-input)
    (define-key map "i" 'skk-kana-input)
    (define-key map "j" 'skk-kana-input)
    (define-key map "k" 'skk-kana-input)
    (define-key map "l" 'skk-ascii-mode)
    (define-key map "m" 'skk-kana-input)
    (define-key map "n" 'skk-kana-input)
    (define-key map "o" 'skk-kana-input)
    (define-key map "p" 'skk-kana-input)
    (define-key map "q" 'skk-toggle-kana)
    (define-key map "r" 'skk-kana-input)
    (define-key map "s" 'skk-kana-input)
    (define-key map "t" 'skk-kana-input)
    (define-key map "u" 'skk-kana-input)
    (define-key map "v" 'skk-kana-input)
    (define-key map "w" 'skk-kana-input)
    (define-key map "x" 'skk-previous-candidate)
    (define-key map "y" 'skk-kana-input)
    (define-key map "z" 'skk-kana-input)
    (define-key map "|" 'skk-self-insert)
    (define-key map "~" 'skk-self-insert)
    (define-key map skk-kakutei-key 'skk-kakutei)
    (skk-define-menu-bar-map map)
    (setq skk-j-mode-map map)))

;;;###skk-autoload
(defvar skk-zenkaku-mode-map nil "*$BA43Q%b!<%I$N%-!<%^%C%W!#(B" )
(or skk-zenkaku-mode-map
  (let ((map (make-sparse-keymap))
        (i 0) )
    (while (< i 128)
      (if (aref skk-zenkaku-vector i)
          (define-key map (char-to-string i) 'skk-zenkaku-insert) )
      (setq i (1+ i)) )
    (define-key map skk-kakutei-key 'skk-kakutei)
    (or skk-use-vip
        (define-key map "\M-Q" 'skk-backward-and-set-henkan-point) )
    (define-key map "\C-q" 'skk-ascii-henkan)
    (skk-define-menu-bar-map map)
    (setq skk-zenkaku-mode-map map)))

;;;###skk-autoload
(defvar skk-abbrev-mode-map nil "*SKK abbrev $B%b!<%I$N%-!<%^%C%W!#(B" )
(or skk-abbrev-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "," 'skk-abbrev-comma)
    (define-key map "." 'skk-abbrev-period)
    (define-key map "\ " 'skk-start-henkan)
    ;;(define-key map "\177" 'skk-delete-backward-char)
    ;;(define-key map "\C-g" 'skk-keyboard-quit)
    ;;(define-key map "\C-m" 'skk-newline)
    (define-key map "\C-q" 'skk-zenkaku-henkan)
    (or skk-use-vip
        (define-key map "\M-\ " 'skk-start-henkan-with-completion) )
    (define-key map "\t" 'skk-try-completion)
    (define-key map skk-kakutei-key 'skk-kakutei)
    (skk-define-menu-bar-map map)
    (setq skk-abbrev-mode-map map)))

;;;###skk-autoload
(defvar skk-jisyo-save-count 50
  "*$B?tCM$G$"$l$P!"$=$N2s?t<-=q$,99?7$5$l$?$H$-$K<-=q$r<+F0E*$K%;!<%V$9$k!#(B
  nil $B$G$"$l$P!"<-=q$N%*!<%H%;!<%V$r9T$J$o$J$$!#(B" )

;;;###skk-autoload
(defvar skk-byte-compile-init-file t
  "*Non-nil $B$G$"$l$P!"(Bskk-mode $B5/F0;~$K(B skk-init-file $B$r%P%$%H%3%s%Q%$%k$9$k!#(B
$B@53N$K8@$&$H!"(B

  (1)skk-init-file $B$r%P%$%H%3%s%Q%$%k$7$?%U%!%$%k$,$J$$$+!"(B
  (2)skk-init-file $B$H$=$N%P%$%H%3%s%Q%$%k:Q%U%!%$%k$rHf3S$7$F!"A0<T$NJ}$,?7$7(B
     $B$$$H$-(B

$B$K(B skk-init-file $B$r%P%$%H%3%s%Q%$%k$9$k!#(B
nil $B$G$"$l$P!"(Bskk-init-file $B$H$=$N%P%$%H%3%s%Q%$%k:Q$_%U%!%$%k$rHf3S$7$F(B 
skk-init-file $B$NJ}$,?7$7$$$H$-$O!"$=$N%P%$%H%3%s%Q%$%k:Q%U%!%$%k$r>C$9!#(B" )

;;;###skk-autoload
(defvar skk-count-private-jisyo-candidates-exactly nil
  "*Non-nil $B$G$"$l$P!"(BEmacs $B$r=*N;$9$k$H$-$K@53N$K8D?M<-=q$N8uJd?t$r?t$($k!#(B
nil $B$G$"$l$P!"(B1 $B9T$KJ#?t$N8uJd$,$"$C$F$b(B 1 $B8uJd$H$7$F?t$($k!#(B
$B7W;;7k2L$O!"(Bskk-record-file $B$KJ]B8$5$l$k!#(B" )

;;;###skk-autoload
(defvar skk-compare-jisyo-size-when-saving t
  "*Non-nil $B$G$"$l$P!"(Bskk-jisyo $B$N%;!<%V;~$K%U%!%$%k%5%$%:$N%A%'%C%/$r9T$J$&!#(B
$BA02s%;!<%V$7$?(B skk-jisyo $B$H:#2s%;!<%V$7$h$&$H$9$k<-=q$H$N%5%$%:Hf3S$r9T$J$$!"(B
$B8e<T$NJ}$,Bg$-$$$H$-$K%f!<%6!<$K%;!<%V$rB3$1$k$+$I$&$+$N3NG'$r5a$a$k!#(B" )

;;;###skk-autoload
(defvar skk-auto-start-henkan t
  "$BC18l$dJ8@a$N6h@Z$j$r<($9J8;z$NBG80$K$h$j<+F0E*$KJQ49$r3+;O$9$k!#(B
skk-auto-start-henkan-keyword-list $B$K$h$jC18l$dJ8@a$N6h@Z$j$r<($9J8;z$r;XDj$9$k!#(B" )

;;;###skk-autoload
(defvar skk-auto-start-henkan-keyword-list
  '("$B$r(B" "$B!"(B" "$B!#(B" "$B!%(B" "$B!$(B" "$B!)(B" "$B!W(B" "$B!*(B"
    "$B!((B" "$B!'(B" ")" ";" ":" "$B!K(B" "$B!I(B" "$B![(B" "$B!Y(B"
    "$B!U(B" "$B!S(B" "$B!Q(B" "$B!O(B" "$B!M(B" "}" "]" "?" "."
    "," "!" )
;; $B$"$^$j%-!<%o!<%I$,B?$/$J$k$H!"DL>o$NJQ49$r:$Fq$K$9$k!)(B
  "$B<+F0JQ49$r3+;O$9$k%-!<%o!<%I!#(B
$B$3$N%j%9%H$NMWAG$NJ8;z$rA^F~$9$k$H!"(BSPC $B$r2!$9$3$H$J$/<+F0E*$KJQ49$r3+;O$9$k!#(B" )

;;;###skk-autoload
(defvar skk-search-excluding-word-pattern-function nil
  "*$B8D?M<-=q$K<h$j9~$^$J$$J8;zNs$N%Q%?!<%s$r8!:w$9$k4X?t$r;XDj$9$k!#(B
$B3NDj$7$?J8;zNs$r0z?t$KEO$7$F(B funcall $B$5$l$k!#(B

SKK $B$G$OJQ49!"3NDj$r9T$J$C$?J8;zNs$OA4$F8D?M<-=q$K<h$j9~$^$l$k$,!"$3$NJQ?t$G;X(B
$BDj$5$l$?4X?t$,(B non-nil $B$rJV$9$H$=$NJ8;zNs$O8D?M<-=q$K<h$j9~$^$l$J$$!#Nc$($P!"(B
$B$3$NJQ?t$K2<5-$N$h$&$J;XDj$9$k$H!"(BSKK abbrev mode $B$G$NJQ49$r=|$-!"%+%?%+%J$N$_(B
$B$+$i$J$kJ8;zNs$rJQ49$K$h$jF@$F3NDj$7$F$b!"$=$l$r8D?M<-=q$K<h$j9~$^$J$$!#(B

$B%+%?%+%J$rJQ49$K$h$j5a$a$?$$$,!"8D?M<-=q$K$O%+%?%+%J$N$_$N8uJd$r<h$j9~$_$?$/$J(B
$B$$!"$J$I!"8D?M<-=q$,I,MW0J>e$KKD$l$k$N$rM^$($kL\E*$K;HMQ$G$-$k!#(B

$B8D?M<-=q$K<h$j9~$^$J$$J8;zNs$K$D$$$F$OJd40$,8z$+$J$$$N$G!"Cm0U$9$k$3$H!#(B

  \(setq skk-search-excluding-word-pattern-function
        \(function
         \(lambda \(kakutei-word\)
         ;; $B$3$N4X?t$,(B t $B$rJV$7$?$H$-$O!"$=$NJ8;zNs$O8D?M<-=q$K<h$j9~$^$l$J$$!#(B
           \(save-match-data
             \(and
            ;; $BAw$j$J$7JQ49$G!"(B
              \(not skk-okuri-char\)
            ;; $B3NDj8l$,%+%?%+%J$N$_$+$i9=@.$5$l$F$$$F!"(B
              \(string-match \"^[$B!<%!(B-$B%s(B]+$\" kakutei-word\)
            ;; SKK abbrev mode $B0J30$G$NJQ49$+!"(B
              \(or \(not skk-abbrev-mode\)
                ;; $B8+=P$78l$,%+%?%+%J!"$R$i$,$J0J30$N$H$-!#(B
                ;; \($B8e$G"&%^!<%/$rIU$1$?$H$-$O!"8+=P$78l$,1QJ8;z$G$b!"(B
                ;; skk-abbrev-mode$B$,(B t $B$K$J$C$F$$$J$$(B\)$B!#(B
                  \(not \(string-match \"^[^$B!<%!(B-$B%s$!(B-$B$s(B]+$\" skk-henkan-key\)\) \)\)\)\)\)\) ")

;;; -- internal variables
;; ---- global variables
(defconst skk-ml-address "skk-develop@kuis.kyoto-u.ac.jp")

(defconst skk-coding-system-alist
  (if (or skk-mule3 skk-xemacs)
      '(("euc" . euc-japan)
        ("ujis" . euc-japan)
        ("sjis". sjis)
        ("jis" . junet) )
    '(("euc" . *euc-japan*)
      ("ujis" . *euc-japan*)
      ("sjis". *sjis*)
      ("jis" . *junet*) ))
  "coding-system $B$NJ8;zNsI=8=$H!"%7%s%\%kI=8=$NO"A[%j%9%H!#(B" )

(defconst skk-default-zenkaku-vector
  ;; note that skk-zenkaku-vector is a user variable.
  ;; skk.el $B%m!<%IA0$K(B .emacs $B$J$I$G!"(Bskk-zenkaku-vector $B$NJL$NCM$r%f!<%6!<$,(B
  ;; $BD>@\=q$$$?$j!"(Bskk.el $B%m!<%I8e$K$3$NCM$r(B aset $B$GD>@\$$$8$C$?$j$7$J$1$l$P(B
  ;; default-value $B$G(B skk-zenkaku-vector $B$K%"%/%;%9$9$k$3$H$G(B
  ;; skk-default-zenkaku-vector $B$NCM$rJ];}$9$k$3$H$b$G$-$h$&$,!"$=$l$OK>$a$J(B
  ;; $B$$(B...$B!#(B
  [nil  nil  nil  nil  nil  nil  nil  nil
   nil  nil  nil  nil  nil  nil  nil  nil
   nil  nil  nil  nil  nil  nil  nil  nil
   nil  nil  nil  nil  nil  nil  nil  nil
   "$B!!(B"  "$B!*(B" "$B!I(B" "$B!t(B" "$B!p(B" "$B!s(B" "$B!u(B" "$B!G(B"
   "$B!J(B" "$B!K(B" "$B!v(B" "$B!\(B" "$B!$(B" "$B!](B" "$B!%(B" "$B!?(B"
   "$B#0(B" "$B#1(B" "$B#2(B" "$B#3(B" "$B#4(B" "$B#5(B" "$B#6(B" "$B#7(B"
   "$B#8(B" "$B#9(B" "$B!'(B" "$B!((B" "$B!c(B" "$B!a(B" "$B!d(B" "$B!)(B"
   "$B!w(B" "$B#A(B" "$B#B(B" "$B#C(B" "$B#D(B" "$B#E(B" "$B#F(B" "$B#G(B"
   "$B#H(B" "$B#I(B" "$B#J(B" "$B#K(B" "$B#L(B" "$B#M(B" "$B#N(B" "$B#O(B"
   "$B#P(B" "$B#Q(B" "$B#R(B" "$B#S(B" "$B#T(B" "$B#U(B" "$B#V(B" "$B#W(B"
   "$B#X(B" "$B#Y(B" "$B#Z(B" "$B!N(B" "$B!@(B" "$B!O(B" "$B!0(B" "$B!2(B"
   "$B!F(B" "$B#a(B" "$B#b(B" "$B#c(B" "$B#d(B" "$B#e(B" "$B#f(B" "$B#g(B"
   "$B#h(B" "$B#i(B" "$B#j(B" "$B#k(B" "$B#l(B" "$B#m(B" "$B#n(B" "$B#o(B"
   "$B#p(B" "$B#q(B" "$B#r(B" "$B#s(B" "$B#t(B" "$B#u(B" "$B#v(B" "$B#w(B"
   "$B#x(B" "$B#y(B" "$B#z(B" "$B!P(B" "$B!C(B" "$B!Q(B" "$B!A(B" nil]
  "skk-zenkaku-region $B$G;2>H$9$kJ8;z%F!<%V%k!#(B
\"ascii\" -> \"$B#a#s#c#i#i(B\" $B$N$h$&$JA43QJ8;z$X$NJQ49$r9T$&:]$KMxMQ$9$k!#(B" )

;;;###skk-autoload
(defconst skk-kanji-len (length "$B$"(B")
  "$B4A;z0lJ8;z$ND9$5!#(BMule $B$G$O(B 3 $B$K$J$k!#(BXEmacs $B$G$O(B 1$B!#(B" )

(defconst skk-hankaku-alist
  '((161 . 32) ; ?\ 
    (170 . 33) ;?\!
    (201 . 34) ;?\"
    (244 . 35) ;?\#
    (240 . 36) ;?\$
    (243 . 37) ;?\%
    (245 . 38) ;?\&
    (199 . 39) ;?\'
    (202 . 40) ;?\(
    (203 . 41) ;?\)
    (246 . 42) ;?\*
    (220 . 43) ;?\+
    (164 . 44) ;?\,
    (221 . 45) ;?\-
    (165 . 46) ;?\.
    (191 . 47) ;?\/
    (167 . 58) ;?\:
    (168 . 59) ;?\;
    (227 . 60) ;?\<
    (225 . 61) ;?\=
    (228 . 62) ;?\>
    (169 . 63) ;?\?
    (247 . 64) ;?\@
    (206 . 91) ;?\[
    (239 . 92) ;?\\
    (207 . 93) ;?\]
    (176 . 94) ;?^ 
    (178 . 95) ;?\_
    (208 . 123) ;?\{
    (195 . 124) ;?\|
    (209 . 125) ;?\}
    (177 . 126) ;?\~
    (198 . 96)) ;?` 
  "$BJ8;z%3!<%I$N(B 2 $BHVL\$N%P%$%H$H$=$NJ8;z$KBP1~$9$k(B ascii $BJ8;z(B \(char\) $B$H$NO"A[%j%9%H!#(B
skk-ascii-region $B$G;2>H$9$k!#(BMule-2.3 $BE:IU$N(B egg.el $B$h$j%3%T!<$7$?!#(B" )

;;;###skk-autoload
(defvar skk-insert-new-word-function nil
  "$B8uJd$rA^F~$7$?$H$-$K(B funcall $B$5$l$k4X?t$rJ]B8$9$kJQ?t!#(B" )

;;;###skk-autoload
(defvar skk-input-mode-string skk-hirakana-mode-string
  "SKK $B$NF~NO%b!<%I$r<($9J8;zNs!#(Bskk-mode $B5/F0;~$O!"(Bskk-hirakana-mode-string$B!#(B" )

;;;###skk-autoload
(defvar skk-isearch-message nil
  "skk-isearch $B4X?t$r%3!<%k$9$k$?$a$N%U%i%0!#(B
Non-nil $B$G$"$l$P!"(Bskk-isearch-message $B4X?t$r%3!<%k$9$k!#(B" )

;;;###skk-autoload
(defvar skk-mode-invoked nil
  "Non-nil $B$G$"$l$P!"(BEmacs $B$r5/F08e4{$K(B skk-mode $B$r5/F0$7$?$3$H$r<($9!#(B" )

(defvar skk-kakutei-count 0
  "$BJQ498uJd$r3NDj$7$?%+%&%s%H$rJ];}$9$kJQ?t!#(B
skk-record-file $B$N(B \"$B3NDj(B:\" $B9`L\$N%+%&%s%?!<!#(B" )

(defvar skk-touroku-count 0
  "$B<-=qEPO?$7$?%+%&%s%H$rJ];}$9$kJQ?t!#(B
skk-record-file $B$N(B \"$BEPO?(B:\" $B9`L\$N%+%&%s%?!<!#(B" )

(defvar skk-update-jisyo-count 0
  "$B<-=q$r99?7$7$?2s?t!#(B
$B$3$N%+%&%s%?!<$N?t;z$,(B skk-jisyo-save-count $B0J>e$H$J$C$?$H$-$K%f!<%6!<<-=q$N%*!<(B
$B%H%;!<%V$,9T$J$o$l$k!#(B" )

(defvar skk-use-relation nil
  "*skk-relation $B$r;HMQ$9$k!#$3$l$OD>A0$NJQ49$r21$($F$*$/$3$H$G!"(B
$BJQ498zN($rNI$/$7$h$&$H$$$&;n$_!#(B" )

(defvar skk-relation-length (* skk-kanji-len 10)
  "skk-relation $B;HMQ;~$K!"2?J8;zA0$NJQ49$^$G21$($F$*$/$+$r;XDj$9$kJQ?t!#(B" )

(defvar skk-relation-record-num 100
  "skk-relation $B;HMQ;~$K!"2?%(%s%H%j$^$G%U%!%$%k$K5-21$9$k$+$r<($9!#(B" )

;; ---- buffer local variables
;; <$B%U%i%0N`(B>
;;;###skk-autoload
(skk-deflocalvar skk-mode nil
  "Non-nil $B$G$"$l$P!"%+%l%s%H%P%C%U%!$G8=:_(B skk-mode $B$r5/F0$7$F$$$k$3$H$r<($9!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-ascii-mode nil
  "Non-nil $B$G$"$l$P!"F~NO%b!<%I$,(B ASCII $B%b!<%I$G$"$k$3$H$r<($9!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-j-mode nil
  "Non-nil $B$G$"$l$P!"F~NO%b!<%I$,$+$J!&%+%J%b!<%I$G$"$k$3$H$r<($9!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-katakana nil
  "Non-nil $B$G$"$l$P!"F~NO%b!<%I$,%+%J%b!<%I$G$"$k$3$H$r<($9!#(B
\"(and (not skk-katakana) skk-j-mode))\" $B$,(B t $B$G$"$l$P!"$+$J%b!<%I$G$"$k$3$H$r(B
$B<($9!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-zenkaku-mode nil
  "Non-nil $B$G$"$l$P!"F~NO%b!<%I$,A41Q%b!<%I$G$"$k$3$H$r<($9!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-abbrev-mode nil
  "Non-nil $B$G$"$l$P!"F~NO%b!<%I$,(B SKK abbrev $B%b!<%I$G$"$k$3$H$r<($9!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-okurigana nil
  "Non-nil $B$G$"$l$P!"Aw$j2>L>ItJ,$,F~NOCf$G$"$k$3$H$r<($9!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-henkan-on nil
  "Non-nil $B$G$"$l$P!""&%b!<%I(B ($BJQ49BP>]$NJ8;zNs7hDj$N$?$a$N%b!<%I(B) $B$G$"$k$3$H$r<($9!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-henkan-active nil
  "Non-nil $B$G$"$l$P!""'%b!<%I(B ($BJQ49Cf(B) $B$G$"$k$3$H$r<($9!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-kakutei-flag nil
  "Non-nil $B$J$i3NDj$7$FNI$$8uJd$r8+$D$1$?>uBV$G$"$k$3$H$r;X$9!#(B
skk-henkan, skk-search-kakutei-jisyo-file, skk-henkan-show-candidates,
skk-henkan-in-minibuff $B$H(B skk-kakutei-save-and-init-variables $B$GJQ99!";2>H$5$l(B
$B$k!#(B" )

(skk-deflocalvar skk-exit-show-candidates nil
  "$B%_%K%P%C%U%!$G8uJd$r<!!9$KI=<($7$F!"8uJd$,?T$-$?$H$-$K(B non-nil $B$H$J$k!#(B
$B$=$NCM$O%j%9%H$G!"(Bcar $B$K(B skk-henkan-show-candidate $B4X?t$G(B while $B%k!<%W$r2s$C(B
$B$?2s?t$r<($90l;~JQ?t(B loop $B$NCM$r!"(Bcdr $BIt$K:G8e$K%_%K%P%C%U%!$KI=<($7$?(B 1 $B$DA0(B
$B$N8uJd72$N:G8e$NMWAG$r;X$9%$%s%G%/%9$,BeF~$5$l$k!#(B
skk-henkan-show-candidates, skk-henkan-in-minibuff $B$H(B
skk-kakutei-save-and-init-variables $B$GJQ99!";2>H$5$l$k!#(B" )

(skk-deflocalvar skk-last-henkan-result nil
  "" )

(skk-deflocalvar skk-last-henkan-point nil
  "" )

;; <$B%-!<%^%C%W4XO"(B>

;; <$B<-=q4XO"$NJQ?t(B>
(skk-deflocalvar skk-okuri-ari-min nil
  "SKK $B<-=q$NAw$jM-$j%(%s%H%j$N3+;OE@$r<($9%P%C%U%!%]%$%s%H!#(B")

(skk-deflocalvar skk-okuri-ari-max nil
  "SKK $B<-=q$NAw$jM-$j%(%s%H%j$N=*N;E@$r<($9%P%C%U%!%]%$%s%H!#(B
skk-jisyo $B$N%P%C%U%!$G$O<-=q$N99?7$NI,MW$,$"$k$?$a$K%^!<%+!<$,BeF~$5$l$k!#(B" )

(skk-deflocalvar skk-okuri-nasi-min nil
  "SKK $B<-=q$NAw$j$J$7%(%s%H%j$N3+;OE@$r<($9%P%C%U%!%]%$%s%H!#(B
skk-jisyo $B$N%P%C%U%!$G$O<-=q$N99?7$NI,MW$,$"$k$?$a$K%^!<%+!<$,BeF~$5$l$k!#(B" )

;; <$B$=$NB>(B>
(skk-deflocalvar skk-mode-line nil
  "SKK $B$N%b!<%I$r<($9%b!<%I%i%$%s$NJ8;zNs!#(B
skk-mode-string, skk-hirakana-mode-string, skk-katakana-mode-string
and skk-zenkaku-mode-string $B$N$$$:$l$+$,BeF~$5$l$k!#(B" )

;; "" $B$KBP1~$7$?%(%s%H%j$,(B skk-roma-kana-[aiue] $B$K$"$k$?$a!"(B"" $B$r(B nil $B$GBeMQ(B
;; $B$G$-$J$$!#(B
;;;###skk-autoload
(skk-deflocalvar skk-prefix ""
  "$BF~NO$9$k$+$J$r7hDj$9$k$?$a$N%W%l%U%#%C%/%9!#(B
$B8e$GF~NO$5$l$kJl2;$KBP1~$7$?(B skk-roma-kana-[aiue] $BO"A[%j%9%H$G!"$=$N(B
skk-prefix $B$r%-!<$K$7$FF~NO$9$Y$-$+$JJ8;z$,7hDj$5$l$k!#(B
$BNc$($P!"(B\"$B$+(B\" $B$N$h$&$K(B \"k\" $B$+$i;O$^$k;R2;$rF~NO$7$F$$$k$H$-$O!"(Bskk-prefix
$B$O!"(B\"k\" $B$G!"$=$N<!$KF~NO$5$l$?Jl2;(B \"a\" $B$KBP1~$9$k(B skk-roma-kana-a $B$NCf$N(B
\"k\" $B$r%-!<$K;}$DCM!"(B\"$B$+(B\" $B$b$7$/$O(B \"$B%+(B\" $B$,F~NO$9$Y$-$+$JJ8;z$H$J$k!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-henkan-start-point nil
  "$BJQ493+;O%]%$%s%H$r<($9%^!<%+!<!#(B" )

(skk-deflocalvar skk-henkan-end-point nil
  "$BJQ49=*N;%]%$%s%H$r<($9%^!<%+!<!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-kana-start-point nil
  "$B$+$JJ8;z$N3+;O%]%$%s%H$r<($9%^!<%+!<!#(B" )

(skk-deflocalvar skk-okurigana-start-point nil
  "$BAw$j2>L>$N3+;O%]%$%s%H$r<($9%^!<%+!<!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-henkan-key nil
  "$BJQ49$9$Y$-8+=P$78l!#(B
$BNc$($P!"(B\"$B"&$+$J(B\" $B$rJQ49$9$l$P!"(Bskk-henkan-key $B$K$O(B \"$B$+$J(B\" $B$,BeF~$5$l$k!#(B
\"$B"&$o$i(B*$B$&(B\" $B$N$h$&$JAw$j$"$j$NJQ49$N>l9g$K$O!"(B\"$B$o$i(Bu\" $B$N$h$&$K!"4A;zItJ,$N(B
$BFI$_$,$J(B + $BAw$j2>L>$N:G=i$NJ8;z$N%m!<%^;z$N%W%l%U%#%C%/%9$,BeF~$5$l$k!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-okuri-char nil
  "$BJQ49$9$Y$-8l$NAw$j2>L>$NItJ,$N%W%l%U%#%C%/%9!#(B
$BNc$($P!"(B\"$B$*$/(B*$B$j(B\" $B$rJQ49$9$k$H$-$O!"(Bskk-okuri-char $B$O(B \"r\"$B!#(B
skk-okuri-char $B$,(B non-nil $B$G$"$l$P!"Aw$j$"$j$NJQ49$G$"$k$3$H$r<($9!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-henkan-okurigana nil
  "$B8=:_$NJQ49$NAw$j2>L>ItJ,!#(B
$BNc$($P!"(B\"$B"&$&$^$l(B*$B$k(B\" $B$rJQ49$9$l$P!"(Bskk-henkan-okurigana $B$K$O(B \"$B$k(B\" $B$,BeF~(B
$B$5$l$k!#(B" )

(skk-deflocalvar skk-last-kakutei-henkan-key nil
  "$B3NDj<-=q$K$h$j:G8e$K3NDj$7$?$H$-$N8+=P$78l!#(B
$B3NDj<-=q$K$h$k3NDj$ND>8e$K(B x $B%-!<$r2!$9$H3NDj$,%"%s%I%%$5$l$F!"3NDjA0$N>uBV$G(B
$B$3$N8+=P$78l$,%+%l%s%H%P%C%U%!$KA^F~$5$l$k!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-henkan-list nil
  "$BJQ497k2L$N8uJd$N%j%9%H!#(B
$BNc$($P!"(B\"$B"&$J(B*$B$/(B\" $B$H$$$&JQ49$9$l$P!"(Bskk-henkan-list $B$O(B
(\"$BLD(B\" \"$B5c(B\" \"$BL5(B\" \"$BK4(B\") $B$N$h$&$K$J$k!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-henkan-count -1
  "skk-henkan-list $B$N%j%9%H$N%$%s%G%/%9$G8=:_$N8uJd$r:9$9$b$N!#(B" )

(skk-deflocalvar skk-self-insert-non-undo-count 1
  "skk-self-insert $B$J$I$GO"B3F~NO$7$?J8;z?t$rI=$o$9%+%&%s%?!<!#(B
Emacs $B$N%*%j%8%J%k$NF0:n$G$O!"(Bself-insert-command $B$K%P%$%s%I$5$l$?%-!<F~NO$O!"(B
$BO"B3(B 20 $B2s$^$G$,(B 1 $B$D$N%"%s%I%%$NBP>]$H$J$k!#$3$NF0:n$r%(%_%e%l!<%H$9$k$?$a$N(B
$B%+%&%s%?!<!#(B
skk-self-insert $B0J30$G$O!"(Bskk-abbrev-comma, skk-abbrev-period, skk-insert-a,
skk-insert-comma, skk-insert-e, skk-insert-i, skk-insert-period, skk-insert-u,
skk-kana-input, skk-set-henkan-point, skk-zenkaku-insert $B$N$$$:$l$+$N%3%^%s%I(B
$B$GF~NO$5$l$?>l9g$bO"B3$7$?F~NO$H$7$F07$o$l$k!#(B
$B$3$N%+%&%s%?!<$,!"(B20 $B0J2<$G$"$k$H$-$O!"F~NO$N$?$S$K(B cancel-undo-boundary $B$,%3!<(B
$B%k$5$l$k!#(B" )

;;;###skk-autoload
(skk-deflocalvar skk-current-search-prog-list nil
  "skk-search-prog-list $B$N8=:_$NCM$rJ]B8$9$k%j%9%H!#(B
$B:G=i$NJQ49;~$O(B skk-search-prog-list $B$NA4$F$NCM$rJ];}$7!"JQ49$r7+$jJV$9$?$S$K(B 1
$B$D$E$DC;$/$J$C$F$f$/!#(B" )

;; for skk-undo-kakutei
(skk-deflocalvar skk-last-henkan-key nil
  "skk-henkan-key $B$N:G8e$NCM!#(Bskk-undo-kakutei $B$G;2>H$5$l$k!#(B" )

(skk-deflocalvar skk-last-henkan-okurigana nil
  "skk-henkan-okurigana $B$N:G8e$NCM!#(Bskk-undo-kakutei $B$G;2>H$5$l$k!#(B" )

(skk-deflocalvar skk-last-henkan-list nil
  "skk-henkan-list $B$N:G8e$NCM!#(Bskk-undo-kakutei $B$G;2>H$5$l$k!#(B" )

(skk-deflocalvar skk-last-okuri-char nil
  "skk-okuri-char $B$N:G8e$NCM!#(Bskk-undo-kakutei $B$G;2>H$5$l$k!#(B" )

(skk-deflocalvar skk-henkan-overlay nil
  "$B8uJd$rI=<($9$k$H$-$K;HMQ$9$k(B Overlay$B!#(B" )

;;;###skk-autoload
(defvar skk-menu-modified-user-option nil
  "SKK $B%a%K%e!<%3%^%s%I$GJQ99$5$l$?%f!<%6!<JQ?tJ];}$9$k%j%9%H!#(B"  )

(or (assq 'skk-mode minor-mode-alist)
    (setq minor-mode-alist
          (cons '(skk-mode skk-input-mode-string) minor-mode-alist) ))

;;      +----------------------+-------- skk-mode -----+----------------------+
;;      |                      |                       |                      |
;;      |                      |                       |                      |
;;  skk-j-mode           skk-ascii-mode          skk-zenkaku-mode      skk-abbrev-mode
;;                           ASCII                ZENKAKU EIMOJI          ABBREVIATION
;;                  (C-j wakes up skk-j-mode)
;;
;;  skk-j-mode-map       skk-ascii-mode-map      skk-zenkaku-mode-map  skk-abbrev-mode-map
;;   skk-katakana: nil 
;;    HIRAKANA
;;
;;  skk-j-mode-map
;;   skk-katakana: t
;;    KATAKANA

;; sub minor mode
;;(cond ((and skk-xemacs (local-variable-p 'minor-mode-map-alist nil t)))
;;      ((local-variable-p 'minor-mode-map-alist)
;;       (setq-default minor-mode-map-alist minor-mode-map-alist) ))

(or (assq 'skk-ascii-mode minor-mode-map-alist)
    (setq minor-mode-map-alist
          (cons (cons 'skk-ascii-mode skk-ascii-mode-map) minor-mode-map-alist) ))

(or (assq 'skk-abbrev-mode minor-mode-map-alist)
    (setq minor-mode-map-alist
          (cons (cons 'skk-abbrev-mode skk-abbrev-mode-map) minor-mode-map-alist) ))

(or (assq 'skk-j-mode minor-mode-map-alist)
    (setq minor-mode-map-alist
          (cons (cons 'skk-j-mode skk-j-mode-map) minor-mode-map-alist) ))

(or (assq 'skk-zenkaku-mode minor-mode-map-alist)
    (setq minor-mode-map-alist
          (cons (cons 'skk-zenkaku-mode skk-zenkaku-mode-map) minor-mode-map-alist) ))

;;;; aliases
(defalias 'skk-backward-char 'backward-char)
(defalias 'skk-eventp 'eventp)
(defalias 'skk-forward-char 'forward-char)
(defalias 'skk-insert-and-inherit 'insert-and-inherit)
(defalias 'skk-skip-chars-backward 'skip-chars-backward)

;;;; macros

;; Why I use non-intern temporary variable in the macro --- see comment in
;; save-match-data of subr.el of GNU Emacs. And should we use the same manner
;; in the save-current-buffer, with-temp-buffer and with-temp-file macro
;; definition?
;;;###skk-autoload
(defmacro skk-save-point (&rest body)
  (` (let ((skk-save-point (point-marker)))
       (unwind-protect
	   (progn (,@ body))
	 (goto-char skk-save-point)
         (skk-set-marker skk-save-point nil) ))))

;;;###skk-autoload
(defmacro skk-message (japanese english &rest arg)
  ;; skk-japanese-message-and-error $B$,(B non-nil $B$@$C$?$i(B JAPANESE $B$r(B nil $B$G$"$l(B
  ;; $B$P(B ENGLISH $B$r%(%3!<%(%j%"$KI=<($9$k!#(B
  ;; ARG $B$O(B message $B4X?t$NBh#20z?t0J9_$N0z?t$H$7$FEO$5$l$k!#(B
  (list 'let (list (list 'mc-flag t) (list 'enable-multibyte-characters t))
        (append (list 'message (list 'if 'skk-japanese-message-and-error
                                     japanese english ))
                arg )))

;;;###skk-autoload
(defmacro skk-error (japanese english &rest arg)
  ;; skk-japanese-message-and-error $B$,(B non-nil $B$@$C$?$i(B JAPANESE $B$r(B nil $B$G$"$l(B
  ;; $B$P(B ENGLISH $B$r%(%3!<%(%j%"$KI=<($7!"%(%i!<$rH/@8$5$;$k!#(B
  ;; ARG $B$O(B error $B4X?t$NBh#20z?t0J9_$N0z?t$H$7$FEO$5$l$k!#(B
  (list 'let (list (list 'mc-flag t) (list 'enable-multibyte-characters t))
        (append (list 'error (list 'if 'skk-japanese-message-and-error
                                   japanese english ))
                arg )))

;;;###skk-autoload
(defmacro skk-yes-or-no-p (japanese english)
  ;; skk-japanese-message-and-error $B$,(B non-nil $B$G$"$l$P!"(Bjapanese $B$r(B nil $B$G$"(B
  ;; $B$l$P(B english $B$r%W%m%s%W%H$H$7$F(B yes-or-no-p $B$r<B9T$9$k!#(B
  ;; yes-or-no-p $B$N0z?t$N%W%m%s%W%H$,J#;($KF~$l9~$s$G$$$k>l9g$O$3$N%^%/%m$r;H(B
  ;; $B$&$h$j%*%j%8%J%k$N(B yes-or-no-p $B$r;HMQ$7$?J}$,%3!<%I$,J#;($K$J$i$J$$>l9g$,(B
  ;; $B$"$k!#(B
  (list 'let (list (list 'mc-flag t) (list 'enable-multibyte-characters t))
        (list 'yes-or-no-p (list 'if 'skk-japanese-message-and-error
                                 japanese english ))))

;;;###skk-autoload
(defmacro skk-y-or-n-p (japanese english)
  ;; skk-japanese-message-and-error $B$,(B non-nil $B$G$"$l$P!"(Bjapanese $B$r(B nil $B$G$"(B
  ;; $B$l$P(B english $B$r%W%m%s%W%H$H$7$F(B y-or-n-p $B$r<B9T$9$k!#(B
  (list 'let (list (list 'mc-flag t) (list 'enable-multibyte-characters t))
        (list 'y-or-n-p (list 'if 'skk-japanese-message-and-error
                              japanese english ))))

;;;###skk-autoload
(defmacro skk-set-marker (marker position &optional buffer)
  ;; $B%P%C%U%!%m!<%+%kCM$G$"$k(B skk-henkan-start-point, skk-henkan-end-point,
  ;; skk-kana-start-point, $B$"$k$$$O(B skk-okurigana-start-point $B$,(B nil $B$@$C$?$i!"(B
  ;; $B?75,%^!<%+!<$r:n$C$FBeF~$9$k!#(B
  ;;
  ;; skk.el $B$N%P%C%U%!%m!<%+%kCM$N07$$$K$OCm0U$9$Y$-E@$,$"$k!#(B
  ;; $BNc$($P!"$"$k%P%C%U%!(B Buffer A $B$G2<5-$N$h$&$J%U%)!<%`$rI>2A$7$?$H$9$k!#(B
  ;; ---------- Buffer A ---------------+--------------- Buffer B ----------
  ;; (setq test (make-marker))          |
  ;;  -> #<marker in no buffer>         |
  ;;                                    |
  ;; (make-variable-buffer-local 'test) |
  ;;                                    |
  ;; test                               | test
  ;;  -> #<marker in no buffer>         |  -> #<marker in no buffer>
  ;;                                    |
  ;; (set-marker test (point))          |
  ;;                                    |
  ;; test                               | test
  ;;  -> #<marker at 122 in A>          |  -> #<marker at 122 in A>
  ;;
  ;; $B%P%C%U%!%m!<%+%kCM$H$7$F$N@k8@$r$9$kA0$K(B non-nil $BCM$rBeF~$7!"$=$N(B non-nil
  ;; $BCM$rD>@\=q$-JQ$($k$h$&$J%U%)!<%`$rI>2A$9$k$H(B Buffer B $B$+$i8+$($k%G%#%U%)%k(B
  ;; $B%HCM$^$G=q$-JQ$C$F$7$^$&!#>e5-$NNc$O%^!<%+!<$@$,!"2<5-$N$h$&$K%j%9%H$KBP$7(B
  ;; $B$FGK2uE*4X?t$GA`:n$7$?$H$-$bF1MM$N7k2L$H$J$k!#(B
  ;; ---------- Buffer A ---------------+--------------- Buffer B ----------
  ;; (setq test '(A B C))               |
  ;;  -> (A B C)                        |
  ;;                                    |
  ;; (make-variable-buffer-local 'test) |
  ;;                                    |
  ;; test                               | test
  ;;  -> (A B C)                        |  -> (A B C)
  ;;                                    |
  ;; (setcar test 'X)                   |
  ;;                                    |
  ;; test                               | test
  ;;  -> (X B C)                        |  -> (X B C)
  ;;
  ;; $B$3$N8=>]$G0lHV:$$k$N$O!"4A;zEPO?$J$I$G%_%K%P%C%U%!$KF~$C$?$H$-(B
  ;; (skk-henkan-show-candidate $B$N$h$&$KC1$K!V%(%3!<%(%j%"!W$r;HMQ$9$k4X?t$G$O(B
  ;; $B4X78$J$$(B) $B$K!"$b$H$N%P%C%U%!$H%_%K%P%C%U%!$H$G$O$=$l$>$lJL$NJQ49$r9T$J$&(B
  ;; $B$N$,IaDL$G$"$k$N$G!">e5-$N$h$&$KB>$N%P%C%U%!$N%P%C%U%!%m!<%+%kCM$^$G=q$-(B
  ;; $BJQ$($F$7$^$&$H!"JQ49$r5Y;_$7$F$$$kB>$N%P%C%U%!$G@5>o$JJQ49$,$G$-$J$/$J$k(B
  ;; $B>l9g$,$"$k$3$H$G$"$k!#(B
  ;;
  ;; $B$7$+$b(B SKK $B$G$O%j%+!<%7%V%_%K%P%C%U%!$,;HMQ$G$-$k$N$G!"(B *Minibuf-0* $B$H(B
  ;;  *Minibuf-1 $B$N4V(B ($B$"$k$$$O$b$C$H?<$$%j%+!<%7%V%_%K%P%C%U%!F1;N$N4V(B) $B$G%P%C(B
  ;; $B%U%!%m!<%+%kCM$NGK2uE*=q$-JQ$($,9T$J$o$l$F$7$^$$!">e0L$N%_%K%P%C%U%!$KLa$C(B
  ;; $B$?$H$-$K@5>o$JJQ49$,$G$-$J$/$J$k>l9g$,$"$k!#(B
  ;;
  ;; $B$H$3$m$,2<5-$N$h$&$K=i4|CM$r(B nil $B$K$7$F!"%P%C%U%!%m!<%+%kCM$H$7$F$N@k8@8e!"(B
  ;; non-nil $BCM$rBeF~$9$l$P!"0J8e$=$N%P%C%U%!%m!<%+%kCM$KGK2uE*A`:n$r$7$F$b$=$N(B
  ;; $B%P%C%U%!$K8GM-$NCM$7$+JQ2=$7$J$$!#(B
  ;; ---------- Buffer A ---------------+--------------- Buffer B ----------
  ;; (setq test nil)                    |
  ;;                                    |
  ;; (make-variable-buffer-local 'test) |
  ;;                                    |
  ;; test                               | test
  ;;  -> nil                            |  -> nil
  ;;                                    |
  ;; (setq test (make-marker))          |
  ;;  -> #<marker in no buffer>         |
  ;;                                    |
  ;; (set-marker test (point))          |
  ;;                                    |
  ;; test                               | test
  ;;  -> #<marker at 122 in A>          |  -> nil
  ;;
  ;; skk.el 9.3 $B$N;~E@$G$O!"(Bskk-henkan-start-point, skk-henkan-end-point,
  ;; skk-kana-start-point $B5Z$S(B skk-okurigana-start-point $B$N=i4|CM(B
  ;; (make-variable-buffer-local $B$,%3!<%k$5$l$kA0$NCM(B) $B$,(B make-marker $B$NJV$jCM(B
  ;; $B$G$"$k(B #<marker in no buffer> $B$G$"$C$?$N$G!"%j%+!<%7%V%_%K%P%C%U%!$KF~$C(B
  ;; $B$FJQ49$7$?$H$-$K(B "$B"'(B" $B$,>C$($J$$!"$J$I$N%H%i%V%k$,$"$C$?$,!"$3$l$i$N=i4|(B
  ;; $BCM$r(B nil $B$K$7$F;HMQ;~$K(B make-marker $B$NJV$jCM$rBeF~$9$k$h$&$K$7!"$3$NLdBj$r(B
  ;; $B2r7h$7$?!#(B
  (list 'progn
        (list 'if (list 'not marker)
              (list 'setq marker (list 'make-marker)) )
        (list 'set-marker marker position buffer) ))

;;;; inline functions
(defsubst skk-mode-off ()
  (setq skk-mode nil
        skk-abbrev-mode nil
        skk-ascii-mode nil
        skk-j-mode nil
        skk-zenkaku-mode nil
        ;; j's sub mode.
        skk-katakana nil )
  ;; initialize
  (setq skk-input-mode-string skk-hirakana-mode-string)
  (setq skk-last-henkan-result nil)
  (skk-set-marker skk-last-henkan-point nil)
  (skk-set-cursor-color skk-default-cursor-color)
  (force-mode-line-update) )

;;;###skk-autoload
(defsubst skk-j-mode-on (&optional katakana)
  (setq skk-mode t
        skk-abbrev-mode nil
        skk-ascii-mode nil
        skk-j-mode t
        skk-zenkaku-mode nil
        ;; j's sub mode.
        skk-katakana katakana )
  ;; mode line
  (if katakana
      (progn
        (setq skk-input-mode-string skk-katakana-mode-string)
        (skk-set-cursor-color skk-katakana-cursor-color) ) 
    (setq skk-input-mode-string skk-hirakana-mode-string)
    (skk-set-cursor-color skk-hirakana-cursor-color) )
  (force-mode-line-update) )
        
;;;###skk-autoload
(defsubst skk-ascii-mode-on ()
  (setq skk-mode t
        skk-abbrev-mode nil
        skk-ascii-mode t
        skk-j-mode nil
        skk-zenkaku-mode nil
        ;; j's sub mode.
        skk-katakana nil
        skk-input-mode-string skk-ascii-mode-string )
  (skk-set-cursor-color skk-ascii-cursor-color)
  (force-mode-line-update) )

;;;###skk-autoload
(defsubst skk-zenkaku-mode-on ()
  (setq skk-mode t
        skk-abbrev-mode nil
        skk-ascii-mode nil
        skk-j-mode nil
        skk-zenkaku-mode t
        ;; j's sub mode.
        skk-katakana nil
        skk-input-mode-string skk-zenkaku-mode-string )
  (skk-set-cursor-color skk-zenkaku-cursor-color)
  (force-mode-line-update) )

;;;###skk-autoload
(defsubst skk-abbrev-mode-on ()
  (setq skk-mode t
        skk-abbrev-mode t
        skk-ascii-mode nil
        skk-j-mode nil
        skk-zenkaku-mode nil
        ;; j's sub mode.
        skk-katakana nil
        skk-input-mode-string skk-abbrev-mode-string )
  (skk-set-cursor-color skk-abbrev-cursor-color)
  (force-mode-line-update) )

;;;###skk-autoload
(defsubst skk-in-minibuffer-p ()
  ;; $B%+%l%s%H%P%C%U%!$,%_%K%P%C%U%!$+$I$&$+$r%A%'%C%/$9$k!#(B
  (window-minibuffer-p (selected-window)) )

;;;###skk-autoload
(defsubst skk-insert-prefix (&optional char)
  ;; skk-echo $B$,(B non-nil $B$G$"$l$P%+%l%s%H%P%C%U%!$K(B skk-prefix $B$rA^F~$9$k!#(B
  (if skk-echo
      ;; skk-prefix $B$NA^F~$r%"%s%I%%$NBP>]$H$7$J$$!#A^F~$7$?%W%l%U%#%C%/%9$O!"(B
      ;; $B$+$JJ8;z$rA^F~$9$kA0$KA4$F>C5n$9$k$N$G!"$=$N4V!"(Bbuffer-undo-list $B$r(B
      ;; t $B$K$7$F%"%s%I%%>pJs$rC_$($J$/$H$bLdBj$,$J$$!#(B
      (let ((buffer-undo-list t))
        (insert (or char skk-prefix)) )))

;;;###skk-autoload
(defsubst skk-erase-prefix ()
  ;; skk-echo $B$,(B non-nil $B$G$"$l$P%+%l%s%H%P%C%U%!$KA^F~$5$l$?(B skk-prefix $B$r>C(B
  ;; $B$9!#(B
  (if skk-echo
      ;; skk-prefix $B$N>C5n$r%"%s%I%%$NBP>]$H$7$J$$!#(B
      (let ((buffer-undo-list t))
        (delete-region skk-kana-start-point (point) ))))

(defsubst skk-string<= (str1 str2)
  ;; str1 $B$,(B str2 $B$HHf3S$7$F!"(Bstring< $B$+(B string= $B$G$"$l$P!"(Bt $B$rJV$9!#(B
  (or (string< str1 str2) (string= str1 str2)) )

(defsubst skk-jis-char-p (char)
  ;; char $B$,(B JIS $BJ8;z$@$C$?$i(B t $B$rJV$9!#(B
  (> char 127) )

(defsubst skk-alpha-char-p (char)
  ;; char $B$,(B ascii $BJ8;z$@$C$?$i(B t $B$rJV$9!#(B
  (<= char 127) )

(defsubst skk-lower-case-p (char)
  ;; char $B$,>.J8;z$N%"%k%U%!%Y%C%H$G$"$l$P!"(Bt $B$rJV$9!#(B
  (and (<= ?a char) (>= ?z char) ))

(defsubst skk-do-auto-fill ()
  ;; auto-fill-function $B$KCM$,BeF~$5$l$F$*$l$P!"(Bdo-auto-fill $B$r%3!<%k$9$k!#(B
  (and auto-fill-function (funcall auto-fill-function)) )

;;;; from dabbrev.el.  Welcome!
;; $BH=Dj4V0c$$$rHH$9>l9g$"$j!#MW2~NI!#(B
(defsubst skk-minibuffer-origin ()
  (nth 1 (buffer-list)) )

;;;###skk-autoload
(defsubst skk-numeric-p ()
  (and skk-use-numeric-conversion (require 'skk-num)
       skk-num-list ))

(defsubst skk-substring-head-character (string)
  (char-to-string (string-to-char string)) )

(defsubst skk-get-simply-current-candidate (&optional noconv)
  (if (> skk-henkan-count -1)
      ;; (nth -1 '(A B C)) $B$O!"(BA $B$rJV$9$N$G!"Ii$G$J$$$+$I$&$+%A%'%C%/$9$k!#(B
      (let ((word (nth skk-henkan-count skk-henkan-list)))
        (and word
             (if (and (skk-numeric-p) (consp word))
                 (if noconv (car word) (cdr word))
               word )))))

(eval-after-load "font-lock"
  '(mapcar (function
            (lambda (pattern)
              (add-to-list
               'lisp-font-lock-keywords-2
               (cons pattern
                     '((1 font-lock-keyword-face)
                       (2 font-lock-variable-name-face) )))))
           '("^(\\(skk-deflocalvar\\)[ \t'\(]*\\(\\sw+\\)?"
             "^(\\(skk-defunsoft\\)[ \t'\(]*\\(\\sw+\\)?" )))

(defun skk-submit-bug-report ()
  "$B%a!<%k$G(B SKK $B$N%P%0%l%]!<%H$rAw$k!#(B
reporter-mailer $B$r@_Dj$9$k$3$H$K$h$j9%$_$N%a!<%k%$%s%?!<%U%'%$%9$r;HMQ$9$k$3$H(B
$B$,$G$-$k!#Nc$($P!"(BMew $B$r;HMQ$7$?$$>l9g$O2<5-$N$h$&$K@_Dj$9$k!#(B

    \(setq reporter-mailer '\(mew-send reporter-mail\)\)

reporter.el 3.2 $B$G$O!"JQ?t(B reporter-mailer $B$,$J$/$J$C$?!#$3$N%P!<%8%g%s$G$O!"(B

    \(setq mail-user-agent 'mew-user-agent\)

$B$H;XDj$9$k!#(B"
  (interactive)
  (require 'reporter)
  (if (and (boundp 'mail-user-agent)
           (eq mail-user-agent 'mew-user-agent) )
      (define-mail-user-agent 'mew-user-agent
        'mew-send 'mew-draft-send-letter 'mew-draft-kill ))
  (and (y-or-n-p "Do you really want to submit a report on SKK? ")
       (reporter-submit-bug-report
        skk-ml-address
        (concat "skk.el " (skk-version)
                (if (or (and (boundp 'skk-server-host) skk-server-host)
                        (and (boundp 'skk-servers-list) skk-servers-list)
                        (getenv "SKKSERVER")
                        (getenv "SKKSERV") )
                    (progn
                      (require 'skk-server)
                      (concat ", skkserv; " (skk-server-version)
                              (if (getenv "SKKSERVER")
                                  (concat ",\nSKKSERVER; "
                                          (getenv "SKKSERVER") ))
                              (if (getenv "SKKSERV")
                                  (concat ", SKKSERV; "
                                          (getenv "SKKSERV") ))))))
        (let ((base (list 'window-system
                          'skk-auto-okuri-process
                          'skk-auto-start-henkan
                          'skk-egg-like-newline
                          'skk-henkan-okuri-strictly
                          'skk-henkan-strict-okuri-precedence
                          'skk-kakutei-early
                          'skk-process-okuri-early
                          'skk-search-prog-list
                          'skk-use-face
                          'skk-use-vip )))
          (if (boundp 'skk-henkan-face)
              (nconc base '(skk-henkan-face)) )
          (if (boundp 'skk-server-host)
              (nconc base '(skk-server-host)) )
          (if (boundp 'skk-server-prog)
              (nconc base '(skk-server-prog)) )
          (if (boundp 'skk-servers-list)
              (nconc base '(skk-servers-list)) )
          base ))))

;;;; defadvices.
;; defadvice $B$GDj5A$9$k$H!"8e$G%f!<%6!<$,?75,$N5!G=$rIU$1$F99$K(B defadvice $B$7$F(B
;; $B$b$A$c$s$HF0$/!#(B

;; cover to original functions.

(defadvice keyboard-quit (around skk-ad activate)
  "$B"'%b!<%I$G$"$l$P!"8uJd$NI=<($r$d$a$F"&%b!<%I$KLa$9(B ($B8+=P$78l$O;D$9(B)$B!#(B
$B"&%b!<%I$G$"$l$P!"8+=P$78l$r:o=|$9$k!#(B
$B>e5-$N$I$A$i$N%b!<%I$G$b$J$1$l$P(B keyboard-quit $B$HF1$8F0:n$r$9$k!#(B"
  (cond ((not skk-henkan-on)
         (with-current-buffer (skk-minibuffer-origin)
           (skk-set-cursor-properly) )
         ad-do-it )
        (skk-henkan-active
         (setq skk-henkan-count 0)
         (if (and skk-delete-okuri-when-quit skk-henkan-okurigana)
             (let ((count (/ (length skk-henkan-okurigana) skk-kanji-len)))
               (skk-previous-candidate)
               ;; $B$3$3$G$O(B delete-backward-char $B$KBhFs0z?t$rEO$5$J$$J}$,%Y%?!<!)(B
               (delete-backward-char count) )
           (skk-previous-candidate) ))
        (t (if (> (point) skk-henkan-start-point)
               (delete-region (point) skk-henkan-start-point) )
           (skk-kakutei) )))

(defadvice abort-recursive-edit (around skk-ad activate)
  "$B"'%b!<%I$G$"$l$P!"8uJd$NI=<($r$d$a$F"&%b!<%I$KLa$9(B ($B8+=P$78l$O;D$9(B)$B!#(B
$B"&%b!<%I$G$"$l$P!"8+=P$78l$r:o=|$9$k!#(B
$B>e5-$N$I$A$i$N%b!<%I$G$b$J$1$l$P(B abort-recursive-edit $B$HF1$8F0:n$r$9$k!#(B"
  (cond ((not skk-henkan-on)
         (with-current-buffer (skk-minibuffer-origin)
           (skk-set-cursor-properly) )
         ad-do-it )
        (skk-henkan-active
         (setq skk-henkan-count 0)
         (if (and skk-delete-okuri-when-quit skk-henkan-okurigana)
             (let ((count (/ (length skk-henkan-okurigana) skk-kanji-len)))
               (skk-previous-candidate)
               ;; $B$3$3$G$O(B delete-backward-char $B$KBhFs0z?t$rEO$5$J$$J}$,%Y%?!<!)(B
               (delete-backward-char count) )
           (skk-previous-candidate) ))
        (t (if (> (point) skk-henkan-start-point)
               (delete-region (point) skk-henkan-start-point) )
           (skk-kakutei) )))

(defadvice newline (around skk-ad activate)
  (if (not (or skk-j-mode skk-abbrev-mode))
      ad-do-it
    (let ((arg (ad-get-arg 0))
          ;; skk-kakutei $B$r<B9T$9$k$H(B skk-henkan-on $B$NCM$,L5>r7o$K(B nil $B$K$J$k(B
          ;; $B$N$G!"J]B8$7$F$*$/I,MW$,$"$k!#(B
          (no-newline (and skk-egg-like-newline skk-henkan-on))
	  (auto-fill-function auto-fill-function) )
      (if (not (interactive-p))
	  (setq auto-fill-function nil) )
      (if (skk-kakutei)
          ;; skk-do-auto-fill $B$K$h$C$F9T$,@^$jJV$5$l$?$i(B arg $B$r(B 1 $B$D8:$i$9!#(B
	  ;; fill $B$5$l$F$b(B nil $B$,5"$C$F$/$k(B :-<
          (setq arg (1- arg)) )
      (if (not no-newline)
          (progn
            (ad-set-arg 0 arg)
            ad-do-it )))))

(defadvice newline-and-indent (around skk-ad activate)
  (if (and skk-egg-like-newline skk-henkan-on)
      (newline)
    ad-do-it))

(defadvice exit-minibuffer (around skk-ad activate)
  (if (not (or skk-j-mode skk-abbrev-mode))
      ad-do-it
    (let ((no-newline (and skk-egg-like-newline skk-henkan-on)))
      (if skk-mode (skk-kakutei))
      (or no-newline ad-do-it) )))

(defadvice delete-backward-char (around skk-ad activate)
  "$B8=:_$N%]%$%s%H$+$iLa$C$F(B COUNT $BJ8;z$r>C5n$9$k!#(B"
  (let ((count (or (prefix-numeric-value (ad-get-arg 0)) 1)))
    (cond ((and skk-henkan-on (>= skk-henkan-start-point (point)))
           (setq skk-henkan-count 0)
           (skk-kakutei) )
          (skk-henkan-active
           (if (and (not skk-delete-implies-kakutei)
                    (= skk-henkan-end-point (point)) )
               (skk-previous-candidate)
             ;;(if skk-use-face (skk-henkan-face-off))
             ;; overwrite-mode $B$GA43QJ8;zA43QJ8;z$K0O$^$l!"$+$DD>A0$NJ8;z$,A4(B
             ;; $B3QJ8;z$G$"$k%]%$%s%H$G(B delete-backward-char $B$r;H$&$H!"A43QJ8;z(B
             ;; $B$O>C$9$,H>3QJ8;zJ,$7$+(B backward $BJ}8~$K%]%$%s%H$,La$i$J$$(B
             ;; (Emacs 19.31 $B$K$F3NG'(B)$B!#JQ49Cf$N8uJd$KBP$7$F$O(B
             ;; delete-backward-char $B$GI,$:A43QJ8;z(B 1 $BJ8;zJ,(B backward $BJ}8~$KLa$C(B
             ;; $B$?J}$,NI$$!#(B
             (if overwrite-mode
                 (progn
                   (backward-char count)
                   (delete-char count) )
               ad-do-it )
             (if (>= skk-henkan-end-point (point)) (skk-kakutei)) ))
          ;; $BF~NOCf$N8+=P$78l$KBP$7$F$O(B delete-backward-char $B$GI,$:A43QJ8;z(B 1
          ;; $BJ8;zJ,(B backward $BJ}8~$KLa$C$?J}$,NI$$!#(B
          ((and skk-henkan-on overwrite-mode)
           (backward-char count)
           (delete-char count) )
          (t ad-do-it) )))

(defadvice save-buffers-kill-emacs (before skk-ad activate)
  "SKK $B<-=q$r%;!<%V$7$F!"(BEmacs $B$r=*N;$9$k!#(B
$B%;!<%V8e!"(Bskk-before-kill-emacs-hook $B$r<B9T$7$F$+$i(B Emacs $B$r%-%k$9$k!#(B"
  ;; defadvice $B$9$k:]!"Ho(B advice $B4X?t$H$O0c$&J}K!$G0z?tEO$7$r$7$?$$>l9g0J30$O!"(B
  ;; interactive + descripter $B$OMW$i$J$$$_$?$$!#(B
  ;;(interactive "P")
  (skk-save-jisyo)
  (run-hooks 'skk-before-kill-emacs-hook) )

(defadvice picture-mode-exit (before skk-ad activate)
  "SKK $B$N%P%C%U%!%m!<%+%kJQ?t$rL58z$K$7!"(Bpicture-mode-exit $B$r%3!<%k$9$k!#(B
picture-mode $B$+$i=P$?$H$-$K$=$N%P%C%U%!$G(B SKK $B$r@5>o$KF0$+$9$?$a$N=hM}!#(B"
  (if skk-mode (skk-kill-local-variables)) )

(defadvice undo (before skk-ad activate)
  "SKK $B%b!<%I$,(B on $B$J$i(B skk-self-insert-non-undo-count $B$r=i4|2=$9$k!#(B"
  (if skk-mode
      (setq skk-self-insert-non-undo-count 0) ))

(defadvice kill-buffer (around skk-ad activate)
  "SKK $B$N"'%b!<%I$@$C$?$i!"3NDj$7$F$+$i%P%C%U%!$r%-%k$9$k!#(B
  $B%P%C%U%!$N%-%k8e!"(BSKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (if skk-mode
      (and skk-henkan-on (skk-kakutei)) )
  ad-do-it
  ;; $BJL$N%P%C%U%!$XHt$V%3%^%s%I$O(B skk-mode $B$,(B nil $B$G$b%+!<%=%k?'$rD4@0$9$kI,MW(B
  ;; $B$,$"$k!#(B
  (skk-set-cursor-properly) )

(defadvice overwrite-mode (after skk-ad activate)
  (if skk-use-cursor-change
      (skk-change-cursor-when-ovwrt) ))

(defadvice eval-expression (before skk-ad activate)
  (if skk-mode (skk-mode-off)) )

(defadvice query-replace-regexp  (before skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (add-hook 'minibuffer-setup-hook 'skk-setup-minibuffer) )

(defadvice query-replace (before skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (add-hook 'minibuffer-setup-hook 'skk-setup-minibuffer) )

(defadvice goto-line (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (and skk-mode (skk-set-cursor-properly)) )

(defadvice yank (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (and skk-mode (skk-set-cursor-properly)) )

(defadvice yank-pop (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (and skk-mode (skk-set-cursor-properly)) )

(defadvice recenter (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (and skk-mode (skk-set-cursor-properly)) )

;; $BJL$N%P%C%U%!$XHt$V%3%^%s%I$O(B skk-mode $B$,(B nil $B$G$b%+!<%=%k?'$rD4@0$9$kI,MW$,(B
;; $B$"$k!#(B
(defadvice bury-buffer (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (skk-set-cursor-properly) )

(defadvice switch-to-buffer (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (skk-set-cursor-properly) ) 

;; cover to hilit19 functions.
;; forward advice $B$H(B automatic advice activation $B5!G=$,$"$k$+$i!"(Bhilit19.el 
;; $B$N%m!<%IA0$K(B defadvice $B$7$F$bBg>fIW!#(B
;;(if (not (fboundp 'hilit-add-pattern))
;;    nil
(defadvice hilit-yank (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (and skk-mode (skk-set-cursor-properly)) )

(defadvice hilit-yank-pop (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (and skk-mode (skk-set-cursor-properly)) )

(defadvice hilit-recenter (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (and skk-mode (skk-set-cursor-properly)) )

(defadvice execute-extended-command (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (skk-set-cursor-properly) )

(defadvice pop-to-buffer (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (skk-set-cursor-properly) )

;; abort-recursive-edit $B$G$O!"(Bafter original command $B$X0\9T$9$kA0$K%"%\!<%H(B
;; $B$7$F$7$^$&!#(B
;;(defadvice abort-recursive-edit (after skk-ad activate)
;;  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
;;  (skk-set-cursor-properly) )
;;
(defadvice abort-recursive-edit (before skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
   ;; $BJ#?t$N(B window $B$r3+$$$F$$$k>l9g$J$I$O!"8mF0:n$N2DG=@-$"$j!#(B
  (with-current-buffer (skk-minibuffer-origin)
    (skk-set-cursor-properly) ))

(defadvice other-window (after skk-ad activate)
  "SKK $B$N%b!<%I$K=>$$%+!<%=%k$N?'$rJQ$($k!#(B"
  (skk-set-cursor-properly) )

(if skk-xemacs
    ;; XEmacs has minibuffer-keyboard-quit that has nothing to do with delsel.
    (defadvice minibuffer-keyboard-quit (around skk-ad activate)
      (cond ((or (string= skk-henkan-key "") (not skk-henkan-on))
             (with-current-buffer (skk-minibuffer-origin)
               (skk-set-cursor-properly) )
             ad-do-it )
            (skk-henkan-active
             (setq skk-henkan-count 0)
             (if (and skk-delete-okuri-when-quit skk-henkan-okurigana)
                 (let ((count (/ (length skk-henkan-okurigana) skk-kanji-len)))
                   (skk-previous-candidate)
                   ;; $B$3$3$G$O(B delete-backward-char $B$KBhFs0z?t$rEO$5$J$$J}$,%Y%?!<!)(B
                   (delete-backward-char count) )
               (skk-previous-candidate) ))
            (t (if (> (point) skk-henkan-start-point)
                   (delete-region (point) skk-henkan-start-point) )
               (skk-kakutei) )))
    (defadvice minibuffer-keyboard-quit (around skk-ad activate)
      ;; for delsel.el
      (if (and skk-mode
               (not (and
                     delete-selection-mode transient-mark-mode mark-active )))
          (keyboard-quit)
        ad-do-it )))

;;;; mode setup

;;;###skk-autoload
(defun skk-mode (&optional arg)
  "$BF|K\8lF~NO%b!<%I!#(B
$B%^%$%J!<%b!<%I$N0l<o$G!"%*%j%8%J%k$N%b!<%I$K$O1F6A$rM?$($J$$!#(B
$BIi$N0z?t$rM?$($k$H(B SKK $B%b!<%I$+$iH4$1$k!#(B

An input mode for Japanese, converting romanized phonetic strings to kanji.

A minor mode, it should not affect the use of any major mode or
orthogonal minor modes.

In the initial SKK mode, hiragana submode, the mode line indicator is 
$B!V$+$J!W(B.  Lowercase romaji entry is automatically converted to
hiragana where possible.  The lowercase characters `q' and `l' change
submodes of SKK, and `x' is used as a prefix indicating a small kana.

`q' is used to toggle between hiragana and katakana (mode line
indicator $B!V%+%J!W(B) entry submodes.

`l' is used to enter ASCII submode (mode line indicator \"SKK\").
Uppercase `L' enters zenkaku (wide) ASCII submode (mode line indicator 
$B!VA41Q!W(B).  `\C-j' returns to hiragana submode from either ASCII submode.

Kanji conversion is complex, but the basic principle is that the user
signals the appropriate stem to be matched against dictionary keys by
the use of uppercase letters.  Because SKK does not use grammatical
information, both the beginning and the end of the stem must be marked.

For non-inflected words (eg, nouns) consisting entirely of kanji, the
simplest way to invoke conversion is to enter the reading of the kanji,
the first character only in uppercase.  A leading $B!V"&!W(B indicates that
kanji conversion is in progress.  After entering the reading, press 
space.  This invokes dictionary lookup, and the hiragana reading will be
redisplayed in kanji as the first candidate.  Pressing space again gives
the next candidate.  Further presses of space produce further candidates,
as well as a list of the next few candidates in the minibuffer.  Eg,
\"Benri\" => $B!V"&$Y$s$j!W(B, and pressing space produces $B!V"'JXMx!W(B (the solid 
triangle indicates that conversion is in progress).  Backspace steps 
through the candidate list in reverse.

A candidate can be accepted by pressing `\C-j', or by entering a
self-inserting character.  (Unlike other common Japanese input methods,
RET not only accepts the current candidate, but also inserts a line
break.)

Inflected words (verbs and adjectives), like non-inflected words, begin
entry with a capital letter.  However, for these words the end of the
kanji string is signaled by capitalizing the next mora.  Eg, \"TuyoI\"
=> $B!V"'6/$$!W(B.  If no candidate is available at that point, the inflection
point will be indicated with an asterisk \"*\", and trailing characters
will be displayed until a candidate is recognized.  It will be
immediately displayed (pressing space is not necessary).  Space and
backspace are used to step forward and backward through the list of 
candidates.

For more information, see the `skk' topic in Info.  (Japanese only.)

A tutorial is available in Japanese or English via \"M-x skk-tutorial\".
Use a prefix argument to be prompted for the language.  The default is
system-dependent.
"

  (interactive "P")
  (setq skk-mode (cond ((null arg) (not skk-mode))
                       ;; - $B$O(B -1 $B$KJQ49$5$l$k!#(B
                       ((> (prefix-numeric-value arg) 0) t) ))
  (if (not skk-mode)
      ;; exit skk-mode
      (progn
        (let ((skk-mode t)) (skk-kakutei))
        (skk-mode-off) )
    ;; enter skk-mode
    (if (not skk-mode-invoked)
        ;; enter skk-mode for the first time in this session
        (progn
          (setq skk-mode-invoked t)
          (skk-setup-init-file)
          (load skk-init-file t)
          (if skk-keep-record
              (skk-create-file
               skk-record-file
               (if skk-japanese-message-and-error
                   "SKK $B$N5-O?MQ%U%!%$%k$r:n$j$^$7$?(B"
                 "I have created an SKK record file for you" )))
          (skk-create-file
           skk-jisyo (if skk-japanese-message-and-error
                         "SKK $B$N6u<-=q$r:n$j$^$7$?(B"
                       "I have created an empty SKK Jisyo file for you" ))
          (skk-get-jisyo-buffer skk-jisyo 'nomsg) ))
    ;;$B0J2<$O(B skk-mode $B$KF~$k$?$S$KKhEY%3!<%k$5$l$k%3!<%I!#(B
    ;;(if (boundp 'disable-undo)
    ;;    (make-local-variable 'disable-undo) )
    (cond (skk-use-vip (skk-vip-mode))
          (skk-use-viper
           (require 'skk-viper)
           (funcall skk-viper-normalize-map-function) ))
    (if (and (not (featurep 'skk-server))
             (or (and (boundp 'skk-server-host) skk-server-host)
                 (and (boundp 'skk-servers-list) skk-servers-list)
                 (getenv "SKKSERVER")
                 (getenv "SKKSERV") ))
        (require 'skk-server) )
    ;; $B%f!<%6!<JQ?t$K4X$9$k$b$N$O!"%f!<%6!<$,$$$D!"$=$l$i$NJQ?t$rJQ99$9$k$+M=(B
    ;; $BB,$,IU$+$J$$$N$G!"(Bskk-mode $B$KF~$k$?$S$K@_Dj$7$J$*$7$F$$$k!#(B
    (if (featurep 'skk-server)
        ;; skk-search-server $B$O%5!<%P!<$,Mn$A$F$b;H$($k$N$G!"30$5$J$$!#(B
        (skk-adjust-search-prog-list-for-server-search 'non-del) )
    (if skk-auto-okuri-process
        (skk-adjust-search-prog-list-for-auto-okuri) )
    (if skk-use-relation
	(progn
	 (require 'skk-attr)
	 (setq skk-search-prog-list
	       (cons '(skk-search-relation) skk-search-prog-list) )))
    (skk-setup-delete-selection-mode)
    (skk-setup-special-midashi-char)
    (skk-setup-auto-paren)
    (skk-adjust-user-option)
    (define-key minibuffer-local-map skk-kakutei-key 'skk-kakutei)
    ;;(define-key minibuffer-local-map "\C-m" 'skk-newline)
    (define-key minibuffer-local-completion-map skk-kakutei-key 'skk-kakutei)
    ;;(define-key minibuffer-local-completion-map "\C-m" 'skk-newline)
    ;; XEmacs doesn't have minibuffer-local-ns-map
    (if (boundp 'minibuffer-local-ns-map)
        ;;(define-key minibuffer-local-ns-map "\C-m" 'skk-newline)
        (define-key minibuffer-local-ns-map skk-kakutei-key 'skk-kakutei) )
    (skk-j-mode-on)
    (run-hooks 'skk-mode-hook) ))

;;;###skk-autoload
(defun skk-auto-fill-mode (&optional arg)
  "$BF|K\8lF~NO%b!<%I!#<+F0@^$jJV$75!G=IU$-!#(B
$B%^%$%J!<%b!<%I$N0l<o$G!"%*%j%8%J%k$N%b!<%I$K$O1F6A$rM?$($J$$!#(B
$B@5$N0z?t$rM?$($k$H!"6/@)E*$K(B auto-fill-mode $B5Z$S(B SKK $B%b!<%I$KF~$k!#(B
$BIi$N0z?t$rM?$($k$H(B auto-fill-mode $B5Z$S(B SKK $B%b!<%I$+$iH4$1$k!#(B"
  (interactive "P")
  (let ((auto-fill
         (cond ((null arg) (not auto-fill-function))
               ((> (prefix-numeric-value arg) 0) t) )))
    (auto-fill-mode (if auto-fill 1 -1))
    (skk-mode arg)
    (skk-set-cursor-color (if skk-mode
                              skk-hirakana-cursor-color
                            skk-default-cursor-color ))
    (run-hooks 'skk-auto-fill-mode-hook) ))

(defun skk-kill-emacs-without-saving-jisyo (&optional query)
  "SKK $B<-=q$r%;!<%V$7$J$$$G!"(BEmacs $B$r=*N;$9$k!#(B
skk-before-kill-emacs-hook $B$r<B9T$7$F$+$i(B Emacs $B$r%-%k$9$k!#(B"
  (interactive "P")
  ;; format $B$r0z?t$K;}$?$;$?>l9g$O!"(Bskk-yes-or-no-p $B$r;H$&$H$+$($C$F>iD9$K$J$k!#(B
  (if (yes-or-no-p
       (format (if skk-japanese-message-and-error
                   "$B<-=q$NJ]B8$r$;$:$K(B %s $B$r=*N;$7$^$9!#NI$$$G$9$+!)(B"
                 "Do you really wish to kill %s without saving Jisyo? " )
               (cond (skk-mule "Mule")
                     (skk-xemacs "XEmacs")
                     (t "Emacs") )))
      (let ((buff (skk-get-jisyo-buffer skk-jisyo 'nomsg)))
        (if buff
            (progn (set-buffer buff)
                   (set-buffer-modified-p nil)
                   (kill-buffer buff) ))
        (run-hooks 'skk-before-kill-emacs-hook)
        (ad-remove-advice 'save-buffers-kill-emacs 'before 'skk-ad)
        (ad-activate 'save-buffers-kill-emacs)
        (save-buffers-kill-emacs query) )))

(defun skk-setup-init-file ()
  ;; skk-byte-compile-init-file $B$,(B non-nil $B$N>l9g$G!"(Bskk-init-file $B$r%P%$%H%3(B
  ;; $B%s%Q%$%k$7$?%U%!%$%k$,B8:_$7$J$$$+!"$=$N%P%$%H%3%s%Q%$%k:Q%U%!%$%k$h$j(B 
  ;; skk-init-file $B$NJ}$,?7$7$$$H$-$O!"(Bskk-init-file $B$r%P%$%H%3%s%Q%$%k$9$k!#(B
  ;;
  ;; skk-byte-compile-init-file $B$,(B nil $B$N>l9g$G!"(Bskk-init-file $B$r%P%$%H%3%s%Q(B
  ;; $B%$%k$7$?%U%!%$%k$h$j(B skk-init-file $B$NJ}$,?7$7$$$H$-$O!"$=$N%P%$%H%3%s%Q%$(B
  ;; $B%k:Q%U%!%$%k$r>C$9!#(B
  (save-match-data
    (let* ((init-file (expand-file-name skk-init-file))
           (elc (concat init-file 
                        (if (string-match "\\.el$" init-file)
                            "c"
                          ".elc" ))))
      (if skk-byte-compile-init-file
          (if (and (file-exists-p init-file)
                   (or (not (file-exists-p elc))
                       (file-newer-than-file-p init-file elc) ))
              (save-window-excursion ;; for keep window configuration.
                (skk-message "%s $B$r%P%$%H%3%s%Q%$%k$7$^$9!#(B"
                             "Byte-compile %s"
                             skk-init-file )
                (sit-for 2)
                (byte-compile-file init-file) ))
        (if (and (file-exists-p init-file)
                 (file-exists-p elc)
                 (file-newer-than-file-p init-file elc) )
            (delete-file elc) )))))

;;
;;(skk-setup-special-midashi-char skk-minibuff-map)

;;;###skk-autoload
(defun skk-emulate-original-map (arg)
  ;; $B%-!<F~NO$KBP$7$F!"(BSKK $B$N%b!<%I$G$O$J$/!"(BEmacs $B$N%*%j%8%J%k$N%-!<3d$jIU$1$G(B
  ;; $B%3%^%s%I$r<B9T$9$k!#(B
  (let ((prefix-arg arg)
        (keys (skk-command-key-sequence (this-command-keys) this-command)) )
    (if (not keys)
        ;; no alternative commands.  may be invoked by M-x.
        nil
      (let (skk-mode skk-ascii-mode skk-j-mode skk-abbrev-mode skk-zenkaku-mode
                     command )
        (setq command (key-binding keys))
        (if (eq command this-command)
            ;; avoid recursive calling of skk-emulate-original-map.
            nil
          ;; if no bindings are found, call `undefined'.  it's
          ;; original behaviour.
          (skk-cancel-undo-boundary)
          (command-execute (or command (function undefined))))))))

(defun skk-command-key-sequence (key command)
  ;; KEY $B$+$i(B universal arguments $B$r<h$j=|$-!"(BCOMMAND $B$r<B9T$9$k%-!<$rJV$9!#(B
  ;; `execute-extended-command' $B$K$h$C$F%3%^%s%I$,<B9T$5$l$?>l9g$O!"(Bnil $B$rJV$9!#(B
  (while (not (or (zerop (length key))
                  (eq command (key-binding key))))
    (setq key (vconcat (cdr (append key nil)))))
  (and (not (zerop (length key))) key))

(defun skk-setup-special-midashi-char ()
  ;; skk-special-midashi-char-list $B$K;XDj$5$l$?(B char $B$r(B skk-j-mode-map $B$N(B
  ;; skk-set-henkan-point $B$K3d$jIU$1$k!#(Bskk-special-midashi-char-list $B$K;XDj$5(B
  ;; $B$l$?(B char $B$G!"@\F,<-!"@\Hx<-$NF~NO$r2DG=$K$9$k$?$a$N=hM}!#(B
  (let ((strlist (mapcar 'char-to-string skk-special-midashi-char-list))
        ;; Use default-value for Viper.  It localizes minor-mode-map-alist.
        (map (cdr (assq 'skk-j-mode (default-value 'minor-mode-map-alist))))
        str )
    (while strlist
      (setq str (car strlist))
      (if (not (eq 'skk-set-henkan-point (lookup-key map str)))
          (define-key map str 'skk-set-henkan-point) )
      (setq strlist (cdr strlist)) )))

(defun skk-setup-delete-selection-mode ()
  ;; Delete Selection $B%b!<%I$,(B SKK $B$r;H$C$?F|K\8lF~NO$KBP$7$F$b5!G=$9$k$h$&$K(B
  ;; $B%;%C%H%"%C%W$9$k!#(B
  (if (and (featurep 'delsel)
           (not (get 'skk-insert-a 'delete-selection)) )
      (progn
        ;;(put 'skk-delete-backward-char 'delete-selection 'supersede)
        (mapcar (function (lambda (func) (put func 'delete-selection t)))
                '(skk-input-by-code-or-menu
                  skk-insert-comma
                  skk-insert-period
                  skk-kana-input
                  ;;skk-newline
                  ;;skk-set-henkan-point-subr
                  skk-set-henkan-point
                  skk-self-insert
                  skk-today )))))

(defun skk-setup-auto-paren ()
  ;; skk-auto-paren-string-alist $B$NCf$+$i!"(Bskk-special-midashi-char-list
  ;; $B$NMWAG$K4XO"$9$k$b$N$r<h$j=|$/!#(B
  ;; $B$^$?!"(Bskk-auto-paren-string-alist $B$N3FMWAG$N(B car $B$NJ8;z$,(B ascii char $B$G$"(B
  ;; $B$k>l9g$O!"(Bskk-input-vector $B$N3:Ev$N>l=j(B ($B$=$N(B ascii char $B$rI>2A$7$??t$,%$(B
  ;; $B%s%G%/%9$H$J$k(B) $B$K$=$NJ8;z$r=q$-9~$`(B ($BK\Mh$O(B ascii char $B$O(B
  ;; skk-input-vector $B$K=q$/I,MW$,$J$$$,!"(Bskk-auto-paren-string-alist $B$K;XDj$5(B
  ;; $B$l$?BP$K$J$kJ8;z$NA^F~$N$?$a$K$O!"%-!<$H$J$kJ8;z$r=q$$$F$*$/I,MW$,$"$k(B)$B!#(B
  (if (null skk-auto-paren-string-alist)
      nil
    (let ((strlist (mapcar 'char-to-string skk-special-midashi-char-list))
          cell str alist )
      (while strlist
        (setq cell (assoc (car strlist) skk-auto-paren-string-alist))
        (if cell
            ;; assoc $B$GCj=P$7$?(B cell $B$rD>@\;XDj$7$F$$$k$N$G!"(Bdelete $B$G$J$/$H$bBg(B
            ;; $B>fIW!#(B
            (setq skk-auto-paren-string-alist
                  (delq cell skk-auto-paren-string-alist) ))
        (setq strlist (cdr strlist)) )
      (setq alist skk-auto-paren-string-alist)
      (while alist
        (setq str (car (car alist)))
        (if (and (eq (string-width str) 1)
                 ;; $B4{$K%f!<%6!<$,;XDj$7$F$$$k>l9g$O!"$I$s$JJ8;z$G$"$C$F$b(B ($B%-!<(B
                 ;; $B$H$J$kJ8;z$H$O0c$C$F$$$F$b(B)$B!"2?$b$7$J$$!#(B
                 (not (aref skk-input-vector (string-to-char str))) )
            (aset skk-input-vector (string-to-char str) str) )
        (setq alist (cdr alist)) ))))

(defun skk-adjust-user-option ()
  ;; $BN>N)$G$-$J$$%*%W%7%g%s$ND4@0$r9T$J$&!#(B
  (if skk-process-okuri-early
      ;; skk-process-okuri-early $B$NCM$,(B non-nil $B$G$"$k$H$-$K2<5-$NCM$,(B non-nil
      ;; $B$G$"$l$P@5>o$KF0$+$J$$$N$G$3$NJQ?t$NM%@h=g0L$r9b$/$7$?!#(B
      (setq skk-kakutei-early nil
            skk-auto-okuri-process nil
            skk-henkan-okuri-strictly nil
	    skk-henkan-strict-okuri-precedence nil)))

(defun skk-try-completion (arg)
  "$B"&%b!<%I$G8+=P$78l$NJd40$r9T$&!#(B
$B$=$l0J30$N%b!<%I$G$O!"%*%j%8%J%k$N%-!<3d$jIU$1$N%3%^%s%I$r%(%_%e%l!<%H$9$k!#(B"
  (interactive "P")
  (if (and skk-henkan-on (not skk-henkan-active))
      (progn
        (setq this-command 'skk-completion)
        (skk-completion (not (eq last-command 'skk-completion))) )
    (skk-emulate-original-map arg) ))

(defun skk-ascii-mode ()
  "SKK $B$N%b!<%I$r(B ascii $B%b!<%I$KJQ99$9$k!#(B"
  (interactive)
  (skk-kakutei)
  (skk-ascii-mode-on) )

(defun skk-zenkaku-mode ()
  "SKK $B$N%b!<%I$rA43Q1Q;zF~NO%b!<%I$KJQ99$9$k!#(B"
  (interactive)
  (skk-kakutei)
  (skk-zenkaku-mode-on) )

(defun skk-abbrev-mode ()
  "ascii $BJ8;z$r%-!<$K$7$?JQ49$r9T$&$?$a$NF~NO%b!<%I!#(B"
  (interactive "*")
  (if (and skk-henkan-on (not skk-henkan-active))
      (skk-error "$B4{$K"&%b!<%I$KF~$C$F$$$^$9(B" "Already in $B"&(B mode") )
  (skk-kakutei)
  (skk-set-henkan-point-subr)
  (skk-abbrev-mode-on) )

(defun skk-toggle-kana (arg)
  "$B$R$i$,$J%b!<%I$H%+%?%+%J%b!<%I$r%H%0%k$G@Z$jBX$($k!#(B
$B%+%?%+%J%b!<%I$GJQ49$r9T$J$&$H$-$K!"Aw$j2>L>$r%+%?%+%J$KJQ49$7$?$/$J$$$H$-$O!"(B
skk-convert-okurigana-into-katakana $B$NCM$r(B non-nil $B$K$9$k!#(B

$B"&%b!<%I$G$O!"(Bskk-henkan-start-point ($B"&$ND>8e(B) $B$H%+!<%=%k$N4V$NJ8;zNs$r(B

    $B$R$i$,$J(B <=> $B%+%?%+%J(B
    $BA43Q1Q?t;z(B <=> ascii

$B$N$h$&$KJQ49$9$k!#(B"
  (interactive "P")
  (cond ((and skk-henkan-on (not skk-henkan-active))
         (let (char)
           (skk-save-point
             (goto-char skk-henkan-start-point)
             ;; "$B!<(B" $B$G$OJ8;z<oJL$,H=JL$G$-$J$$$N$G!"%]%$%s%H$r?J$a$k!#(B
             (while (looking-at "$B!<(B")
               (skk-forward-char 1) )
             (setq char (skk-what-char-type)) )
           (skk-set-marker skk-henkan-end-point (point))
           (cond ((eq char 'hirakana)
                  (skk-katakana-henkan arg) )
                 ((eq char 'katakana)
                  (skk-hiragana-henkan arg) )
                 ((eq char 'ascii)
                  (skk-zenkaku-henkan arg) )
                 ((eq char 'zenkaku)
                  (skk-ascii-henkan arg) ))))
        ((and (skk-in-minibuffer-p) (not skk-j-mode))
         ;; $B%_%K%P%C%U%!$X$N=iFMF~;~!#(B
         (skk-j-mode-on) )
        (t (setq skk-katakana (not skk-katakana))) )
  (skk-kakutei)
  (if skk-katakana
      (progn
        (setq skk-input-mode-string skk-katakana-mode-string)
        (skk-set-cursor-color skk-katakana-cursor-color) )
    (setq skk-input-mode-string skk-hirakana-mode-string)
    (skk-set-cursor-color skk-hirakana-cursor-color) )
  (force-mode-line-update) )

(defun skk-misc-for-picture ()
  ;; picture-mode $B$XF~$C$?$H$-$K(B SKK $B$r@5>o$KF0$+$9$?$a$KI,MW$J=hM}$r9T$J$&!#(B
  ;; edit-picture-hook $B$K(B add-hook $B$7$F;HMQ$9$k!#(B
  ;;
  ;; picture-mode $B$G(B SKK $B$r;HMQ$74A;zF~NO$r$7$?>l9g$K!"(BBS $B$GA43QJ8;z$,>C$;$J$$(B
  ;; $B$N$O!"(BSKK $B$NIT6q9g$G$O$J$/!"(Bpicture.el $B$NLdBj(B (move-to-column-force $B4X?t(B
  ;; $B$NCf$G;HMQ$7$F$$$k(B move-to-column $B$GA43QJ8;z$rL5;k$7$?%+%i%`?t$,M?$($i$l(B
  ;; $B$?$H$-$K%+!<%=%k0\F0$,$G$-$J$$$+$i(B) $B$G$"$k!#>C$7$?$$J8;z$K%]%$%s%H$r9g$o(B
  ;; $B$;!"(BC-c C-d $B$G0lJ8;z$E$D>C$9$7$+J}K!$O$J$$!#(B
  (if skk-mode
      ;; SKK $B5/F0A0$N>uBV$KLa$9!#(B
      (skk-kill-local-variables) ))

(defun skk-kill-local-variables ()
  ;; SKK $B4XO"$N%P%C%U%!%m!<%+%kJQ?t$rL58z$K$9$k!#(B
  ;; $B4{B8$N%P%C%U%!$r(B picture mode $B$K$7$?$H$-!"(Bpicture-mode $B4X?t$O(B
  ;; kill-all-local-variables $B4X?t$r8F$P$J$$$N$G!"(BSKK $B4XO"$N%P%C%U%!%m!<%+%k(B
  ;; $BJQ?t$,85$N%P%C%U%!$NCM$N$^$^$K$J$C$F$7$^$&!#$=$3$G!"(Bpicture mode $B$KF~$C$?(B
  ;; $B$H$-$K%U%C%/$rMxMQ$7$F$3$l$i$N%P%C%U%!%m!<%+%kJQ?t$r(B kill $B$9$k!#(B
  ;; RMS $B$O(B picture-mode $B$G(B kill-all-local-variables $B4X?t$r8F$P$J$$$N$O!"%P%0(B
  ;; $B$G$O$J$$!"$H8@$C$F$$$?!#(B
  (if (eq (nth 1 mode-line-format) 'skk-mode-line)
      (setq mode-line-format (delq 'skk-mode-line mode-line-format) ))
  (let ((lv (buffer-local-variables))
        v vstr )
    (while lv
      (setq v (car (car lv))
            lv (cdr lv)
            vstr (prin1-to-string v) )
      (if (and
           (> (length vstr) 3) (string= "skk-" (substring vstr 0 4)) )
          (kill-local-variable v) ))))

;;;; kana inputting functions

(defun skk-insert (table)
  ;; skk-prefix $B$r%-!<$H$7$F!"O"A[%j%9%H(B TABLE $B$+$iJ8;zNs$rC5$7$FF~NO$9$k!#(B
  (let ((char (assoc skk-prefix table)))
    (if (null char)
        (progn
          ;; skk-prefix not found in the table
          (setq skk-prefix "")
          (skk-unread-event (skk-character-to-event last-command-char)) )
      (if (and skk-henkan-active skk-kakutei-early
               (not skk-process-okuri-early) )
          (skk-kakutei) )
      (skk-insert-str (if skk-katakana (nthcdr 2 char) (nth 1 char)))
      (if skk-okurigana
          (skk-set-okurigana)
        (setq skk-prefix "") )
      (if (not skk-henkan-on) (skk-do-auto-fill)) )))

(defun skk-insert-str (str)
  ;; skk-insert $B$N%5%V%k!<%A%s!#(BSTR $B$rA^F~$9$k!#I,MW$G$"$l$P(B
  ;; self-insert-after-hook $B$r%3!<%k$9$k!#(Boverwrite-mode $B$G$"$l$P!"E,@Z$K>e=q$-(B
  ;; $B$r9T$&!#$3$N4X?t$O!"(Bskk-vip.el $B$G>e=q$-$5$l$k(B 
  (skk-cancel-undo-boundary)
  (skk-insert-and-inherit str)
  (if (and skk-henkan-on (not skk-henkan-active))
      (if (and skk-auto-start-henkan (not skk-okurigana))
          (skk-auto-start-henkan str) )
    (if (and (boundp 'self-insert-after-hook) self-insert-after-hook)
        (funcall self-insert-after-hook (- (point) (length str)) (point)) )
    (if overwrite-mode
        (skk-del-char-with-pad (skk-ovwrt-len (string-width str))) )))

(defun skk-auto-start-henkan (str)
  ;; skk-auto-start-henkan-keyword-list $B$NMWAG$NJ8;zNs$rA^F~$7$?$H$-$K<+F0E*$K(B 
  ;; ($B%9%Z!<%9$rBG80$7$J$/$H$b(B) $BJQ49$r3+;O$9$k!#%(!<!_%$%=%U%H<R$N(B MSDOS $BMQ(B $B$N(B 
  ;; FEP$B!"(BWX2+ $BIw!#(B
  (if (member str skk-auto-start-henkan-keyword-list)
      (skk-save-point
        (skk-backward-char 1)
        (if (> (point) skk-henkan-start-point)
            (let ((skk-prefix ""))
              (skk-start-henkan (prefix-numeric-value current-prefix-arg)) )))))

(defun skk-ovwrt-len (len)
  ;; $B>e=q$-$7$FNI$$D9$5$rJV$9!#(B
  ;; $B$3$N4X?t$O!"(Bskk-vip.el $B$G>e=q$-$5$l$k(B (<(skk-vip.el/skk-ovwrt-len)>)$B!#(B
  (min (string-width
        (skk-buffer-substring (point) (skk-save-point (end-of-line) (point))) )
       len ))

(defun skk-del-char-with-pad (length)
  ;; $BD9$5(B LENGTH $B$NJ8;z$r>C5n$9$k!#D4@0$N$?$a!"I,MW$G$"$l$P!"KvHx$K%9%Z!<%9$r(B
  ;; $BA^F~$9$k!#(B
  (let ((p (point)) (len 0))
    (while (< len length)
      (forward-char 1)
      (setq len (string-width (skk-buffer-substring (point) p))))
    (delete-region p (point))
    (or (eq length len)
        (progn
          (insert " ")
          (backward-char 1)))))

(defun skk-cancel-undo-boundary ()
  ;; skk-insert-[aiue], skk-insert-comma, skk-insert-period, skk-kana-input,
  ;; skk-self-insert, skk-set-henkan-point, skk-zenkaku-insert $B$GO"B3$7$FF~NO(B
  ;; $B$5$l$?(B 20 $BJ8;z$r(B 1 $B2s$N%"%s%I%%$NBP>]$H$9$k!#(B`20' $B$O(B keyboard.c $B$KDj$a$i(B
  ;; $B$l$?%^%8%C%/%J%s%P!<!#(BMule-2.3 $BE:IU$N(B egg.el $B$r;29M$K$7$?!#(B
  (if (and (< skk-self-insert-non-undo-count 20)
           (memq last-command
                 '(
                   ;; SKK abbrev $B%b!<%I$G$O!"%"%9%-!<J8;zF~NO$,(B Emacs $B%*%j%8%J(B
                   ;; $B%k$N(B self-insert-command $B$K$h$j9T$J$o$l$F$$$k$N$G!"(B
                   ;; skk-self-insert-non-undo-count $B$r%$%s%/%j%a%s%H$9$k$3$H(B
                   ;; $B$,$G$-$J$$$N$G!"%"%s%I%%$r%(%_%e%l!<%H$G$-$J$$!#(B
                   ;; $B$7$+$b!"%+%s%^$d%T%j%*%I$rA^F~$7$?;~E@$G!"(B
                   ;; skk-abbrev-comma $B$d(B skk-abbrev-period $B$r;H$&$3$H$K$J$k$N(B
                   ;; $B$G!"%*%j%8%J%k$N%"%s%I%%$N5!G=$bB;$J$C$F$7$^$&!#8=<BLdBj(B
                   ;; $B$H$7$F$O!"(BSKK abbrev $B%b!<%I$O>JN,7A$H$7$F$N8+=P$78l$rA^(B
                   ;; $BF~$9$k$?$a$N%b!<%I$G$"$k$N$G!"D9$$8+=P$78l$rA^F~$9$k$3$H(B
                   ;; $B$O$"$^$j$J$/!"LdBj$b>.$5$$$H9M$($i$l$k!#(B
                   ;;skk-abbrev-comma
                   ;;skk-abbrev-period
                   skk-insert-comma
                   skk-insert-period
                   skk-kana-input
                   skk-self-insert
                   ;;skk-set-henkan-point
                   skk-zenkaku-insert )))
      (progn
        (cancel-undo-boundary)
        (setq skk-self-insert-non-undo-count
              (1+ skk-self-insert-non-undo-count) ))
    (setq skk-self-insert-non-undo-count 1) ))

(defun skk-get-next-rule (prefix)
  (or (if (and (boundp 'skk-rom-kana-rule-tree)
	       skk-rom-kana-rule-tree )
	  (skk-assoc-tree prefix
			  skk-rom-kana-rule-tree )
	(cdr (assoc prefix skk-rom-kana-rule-list)) )
      (if (and (boundp 'skk-standard-rom-kana-rule-tree)
	       skk-standard-rom-kana-rule-tree)
	  (skk-assoc-tree prefix
			  skk-standard-rom-kana-rule-tree )
	(cdr (assoc prefix skk-standard-rom-kana-rule-list)) )))

(defun skk-get-fallback-rule (prefix)
  (cdr (assoc prefix skk-fallback-rule-alist)) )

(defun skk-check-postfix-rule (last)
  (let ((l skk-postfix-rule-alist)
	ret)
    (while l
      (if (eq (string-to-char last) (string-to-char (car (car l))))
	  (setq ret (cons (car l) ret)) )
      (setq l (cdr l)) )
    ret ))

(defun skk-get-postfix-rule (prefix &optional alist)
  (let ((alist (or alist skk-postfix-rule-alist)))
    (cdr (assoc prefix alist)) ))

(defun skk-kana-input ()
  "$B$+$JJ8;z$NF~NO$r9T$&%k!<%A%s!#(B"
  (interactive "*")
  (combine-after-change-calls
    (if (and skk-henkan-active
             skk-kakutei-early (not skk-process-okuri-early) )
        (skk-kakutei) )
    (let ((echo-keystrokes 0)
          ;; don't echo key strokes in the minibuffer.
	  last-input
	  last-kana )
      (if skk-isearch-message (skk-isearch-message))
      (setq skk-prefix "")
      (skk-set-marker skk-kana-start-point (point))
      (skk-unread-event (skk-character-to-event last-command-char))
      (condition-case nil
	  (let ((cont t)
		prev )
	    (while cont
	      (let* ((raw-event (skk-read-event))
		     ;; ascii equivallence of raw-event or nil.
		     (r-char (skk-event-to-character raw-event))
		     input
		     prefix
		     next
		     low )
		(if skk-debug (message "%S" r-char))
		(if r-char
		    (progn
		      (if (and
			   (or (and
				skk-henkan-on (not skk-henkan-active)
				(= skk-henkan-start-point
				   skk-kana-start-point ))
			       (and
				skk-okurigana
				(= (1+ skk-okurigana-start-point)
				   ;; "*"
				   skk-kana-start-point )))
			   (not (eq r-char (skk-downcase r-char))) )
			  ;; this case takes care of the rare case where
			  ;; one types two characters in upper case
			  ;; consequtively.  For example, one sometimes
			  ;; types "TE" when one should type "Te"
			  (setq r-char (skk-downcase r-char)
				raw-event (skk-character-to-event r-char) ))
		      (setq input (skk-char-to-string r-char)
			    last-input input
			    prefix (concat skk-prefix input)
			    next (skk-get-next-rule prefix) )))
		(if skk-debug (message "%S" next))
		(if skk-isearch-message (skk-isearch-message))
		(if next
		    (let ((newprefix (car next))
			  (output (nth 1 next)) )
		      (setq low (nth 2 next))
		      (skk-erase-prefix)
		      (if output
			  (progn
			    (setq last-kana 
				  (if skk-katakana (car output) (cdr output)))
			    ;; XXX for isearch
			    (skk-insert-str last-kana)
			    (if skk-okurigana (skk-set-okurigana))))
		      (if newprefix
			  (progn
			    (skk-set-marker skk-kana-start-point (point))
			    (skk-insert-prefix newprefix)
			    (setq skk-prefix newprefix))
			(setq cont nil
			      skk-prefix "" )))
		  (let ((type (skk-kana-input-char-type
			       (or r-char (skk-event-to-character raw-event)))))
		    (cond ((eq type 5)    ; delete prefix
			   (setq cont nil)
			   (if skk-okurigana
			       (progn
				 (skk-delete-okuri-mark)
				 (skk-set-marker skk-kana-start-point
						 skk-okurigana-start-point )))
			   (or (string= skk-prefix "")
			       (if skk-echo
				   (skk-erase-prefix)
				 (skk-message "$B%W%l%U%#%C%/%9(B \"%s\" $B$r>C$7$^$7$?(B"
					      "Deleted prefix \"%s\""
					      skk-prefix )))
			   (setq skk-prefix "") )
			  (t
			   (if (string= skk-prefix "")
			       (progn
				 (skk-message
				  "$BE,@Z$J%m!<%^;z$+$JJQ49%k!<%k$,$"$j$^$;$s!#(B"
				   "No suitable rule." )
				 (skk-set-marker skk-kana-start-point nil)
				 (setq cont nil) )
			     (skk-erase-prefix)
			     (let ((output (skk-get-fallback-rule skk-prefix)))
			       (if output
				   (progn
				     (setq last-kana 
					   (if skk-katakana
					       (car output) (cdr output)))
				     ;; XXX for isearch
				     (skk-insert-str last-kana)
				     (if skk-okurigana (skk-set-okurigana)) ))
			       (skk-unread-event raw-event)
			       (skk-set-marker skk-kana-start-point nil)
			       (setq skk-prefix "")
			       (setq cont nil) ))

			   )))
		  )
		)))
        (quit
	 (setq skk-prefix "")
	 (skk-erase-prefix)
	 (skk-set-marker skk-kana-start-point nil)
	 (keyboard-quit) ))
      (let ((postfix-rules (skk-check-postfix-rule last-input)))
	(if postfix-rules
	    (progn
	      (let ((prefix last-kana))
		(if skk-isearch-message (skk-isearch-message)))
	      (let* ((raw-event (skk-read-event))
		     ;; ascii equivallence of raw-event or nil.
		     (r-char (skk-event-to-character raw-event)) )
		(if r-char
		    (let ((new-char
			   (skk-get-postfix-rule
			    (concat last-input (skk-char-to-string r-char))
			    postfix-rules ))
			  prefix )
		      (if new-char
			  (progn
			    (setq skk-prefix (skk-char-to-string r-char))
			    (skk-set-marker skk-kana-start-point (point))
			    (skk-insert-prefix skk-prefix)
			  ;; XXX for isearch
			    (setq prefix (concat last-kana skk-prefix))
			    (if skk-isearch-message (skk-isearch-message))
			    (condition-case nil
				(let* ((raw-event2 (skk-read-event))
				       (r-char2 (skk-event-to-character raw-event2))
				       (type (skk-kana-input-char-type r-char2)) 
				       (prefix (concat skk-prefix
						       (skk-char-to-string r-char2)))
				       (next (skk-get-next-rule prefix) ))
				  (cond  (next
					  ;; rule $B$,$"$k!#(B
					  (setq skk-prefix "")
					  (skk-erase-prefix)
					  (skk-set-marker skk-kana-start-point nil)
					  (skk-unread-event raw-event2)
					  (skk-unread-event raw-event) )
					 ((eq type 5)
					  ;; delete
					  (setq skk-prefix "")
					  (skk-erase-prefix)
					  (skk-set-marker skk-kana-start-point nil) )
					 (t
					  (skk-erase-prefix)
					  (skk-insert-str
					   (if skk-katakana
					       (car new-char)
					     (cdr new-char)))
					  (skk-unread-event raw-event2) )))
			      (quit
			       (setq skk-prefix "")
			       (skk-erase-prefix)
			       (skk-set-marker skk-kana-start-point nil)
			       (skk-unread-event raw-event)
			       (keyboard-quit) )))
			(skk-unread-event raw-event) ))
		  (skk-unread-event raw-event) )))))
      )))

(defun skk-translate-okuri-char (okurigana)
  (if skk-okuri-char-alist
      (cdr (assoc (skk-substring-head-character okurigana) skk-okuri-char-alist)) ))

(defun skk-set-okurigana ()
  ;; $B8+=P$78l$+$i(B skk-henkan-okurigana, skk-henkan-key $B$N3FCM$r%;%C%H$9$k!#(B
  (if skk-katakana
      (skk-hiragana-region skk-henkan-start-point (point)) )
  (skk-set-marker skk-henkan-end-point skk-okurigana-start-point)
  ;; just in case
  (skk-save-point
    (goto-char skk-okurigana-start-point)
    (if (not (eq (following-char) ?*)) ;?*
        (insert "*") ))
  (setq skk-henkan-okurigana (skk-buffer-substring
                              (1+ skk-okurigana-start-point)
                              (point) ))
  (setq skk-henkan-key (concat (skk-buffer-substring skk-henkan-start-point
                                                     skk-henkan-end-point )
			       (or (skk-translate-okuri-char
				    skk-henkan-okurigana)
				   skk-okuri-char ))
        skk-prefix "" )
  (if skk-debug
      (message "%S %S %S" skk-henkan-okurigana skk-henkan-key skk-okuri-char) )
  (delete-region skk-okurigana-start-point (1+ skk-okurigana-start-point))
  (setq skk-henkan-count 0)
  (skk-henkan)
  (setq skk-okurigana nil)
  (cancel-undo-boundary) )

;;;; other inputting functions

(defun skk-insert-period (count)
  "$B8+=P$7$NJd40$r9T$C$F$$$k:GCf$G$"$l$P!"<!$N8uJd$rI=<($9$k!#(B
$BJd40$ND>8e$G$J$1$l$P!"(B\".\" $B$rA^F~$9$k!#(B
SKK abbrev $B%b!<%I$G$O!"(Bskk-abbrev-period $B4X?t$r;HMQ$9$k$3$H!#(B"
  (interactive "*P")
  (if (and (eq last-command 'skk-completion) (not skk-henkan-active))
      (progn
        (setq this-command 'skk-completion)
        (skk-completion nil) )
    (skk-self-insert count)
    (setq skk-last-henkan-result nil)
    (skk-set-marker skk-last-henkan-point nil) ))

(defun skk-insert-comma (count)
  "$B8+=P$7$NJd40$r9T$C$F$$$k:GCf$G$"$l$P!"D>A0$N8uJd$rI=<($9$k!#(B
$BJd40$ND>8e$G$J$1$l$P!"(B\",\" $B$rA^F~$9$k!#(B
SKK abbrev $B%b!<%I$G$O!"(Bskk-abbrev-comma $B4X?t$r;HMQ$9$k$3$H!#(B"
  (interactive "*P")
  (if (and (eq last-command 'skk-completion) (not skk-henkan-active))
      (skk-previous-completion)
    (skk-self-insert count) ))

(defun skk-abbrev-period (arg)
  "SKK abbrev $B%b!<%I$G8+=P$7$NJd40$r9T$C$F$$$k:GCf$G$"$l$P!"<!$N8uJd$rI=<($9$k!#(B
$BJd40$ND>8e$G$J$1$l$P!"%*%j%8%J%k$N%-!<3d$jIU$1$N%3%^%s%I$r%(%_%e%l!<%H$9$k!#(B
SKK abbrev $B%b!<%I0J30$G$O!"(Bskk-insert-period $B4X?t$r;HMQ$9$k$3$H!#(B"
  (interactive "*P")
  (if (eq last-command 'skk-completion)
      (progn
        (setq this-command 'skk-completion)
        (skk-completion nil) )
    (skk-emulate-original-map arg) ))

(defun skk-abbrev-comma (arg)
  "SKK abbrev $B%b!<%I$G8+=P$7$NJd40$r9T$C$F$$$k:GCf$G$"$l$P!"D>A0$N8uJd$rI=<($9$k!#(B
$BJd40$ND>8e$G$J$1$l$P!"%*%j%8%J%k$N%-!<3d$jIU$1$N%3%^%s%I$r%(%_%e%l!<%H$9$k!#(B
SKK abbrev $B%b!<%I0J30$G$O!"(Bskk-insert-comma $B4X?t$r;HMQ$9$k$3$H!#(B"
  (interactive "*P")
  (if (eq last-command 'skk-completion)
      (skk-previous-completion)
    (skk-emulate-original-map arg) ))

(defun skk-self-insert (arg)
  "$B$R$i$,$J!"%+%?%+%J!"$b$7$/$O(B ascii $BJ8;z$r%+%l%s%H%P%C%U%!$KA^F~$9$k!#(B
$B$R$i$,$J%b!<%I$b$7$/$O%+%?%+%J%b!<%I$G$O!"(Bskk-input-vector $B$r%F!<%V%k$H$7$F!"(B
$B:G8e$KF~NO$5$l$?%-!<$KBP1~$9$kJ8;z$rA^F~$9$k!#(B
ascii $B%b!<%I$G$O!"%-!<F~NO$r$=$N$^$^A^F~$9$k!#(B
skk-auto-insert-paren $B$NCM$,(B non-nil $B$N>l9g$G!"(Bskk-auto-paren-string-alist $B$K(B
$BBP1~$9$kJ8;zNs$,$"$k$H$-$O!"$=$NBP1~$9$kJ8;zNs(B ($B$+$C$3N`(B) $B$r<+F0E*$KA^F~$9$k!#(B"
  (interactive "*P")
  (let ((str (aref skk-input-vector last-command-char)))
    ;; Overlay $B$r>C$9$?$a$K@h$K3NDj$9$k!#(B
    (if skk-henkan-active (skk-kakutei))
    (if (not str)
        (skk-emulate-original-map arg)
      (let* ((count (prefix-numeric-value arg))
             (count2 count)
             (pair-str
              (and skk-auto-insert-paren
                   (cdr (assoc str skk-auto-paren-string-alist)) ))
             (pair-str-inserted 0) )
        (while (> count 0)
          (skk-insert-str str)
          (setq count (1- count)) )
        (if (not pair-str)
            nil
          (while (> count2 0)
            (if (not (string= pair-str (char-to-string (following-char))))
                (progn
                  (setq pair-str-inserted (1+ pair-str-inserted))
                  (skk-insert-str pair-str) ))
            (setq count2 (1- count2)) )
          (if (not (eq pair-str-inserted 0))
              (backward-char pair-str-inserted) ))))))

(defun skk-zenkaku-insert (arg)
  "$BA41QJ8;z$r%+%l%s%H%P%C%U%!$KA^F~$9$k!#(B
skk-zenkaku-vector $B$r%F!<%V%k$H$7$F!":G8e$KF~NO$5$l$?%-!<$KBP1~$9$kJ8;z$rA^F~(B
$B$9$k!#(B
skk-auto-insert-paren $B$NCM$,(B non-nil $B$N>l9g$G!"(Bskk-auto-paren-string-alist $B$K(B
$BBP1~$9$kJ8;zNs$,$"$k$H$-$O!"$=$NBP1~$9$kJ8;zNs(B ($B$+$C$3N`(B) $B$r<+F0E*$KA^F~$9$k!#(B"
  (interactive "*p")
  (let* ((str (aref skk-zenkaku-vector last-command-char))
         (arg2 arg)
         (pair-str
          (and skk-auto-insert-paren
               (cdr (assoc str skk-auto-paren-string-alist)) ))
         (pair-str-inserted 0) )
    (while (> arg 0)
      (skk-insert-str str)
      (setq arg (1- arg)) )
    (if (not pair-str)
        nil
      (while (> arg2 0)
        (if (not (string= pair-str (char-to-string (following-char))))
            (progn
              (setq pair-str-inserted (1+ pair-str-inserted))
              (skk-insert-str pair-str) ))
        (setq arg2 (1- arg2)) )
      (if (not (eq pair-str-inserted 0))
          (backward-char pair-str-inserted) ))))

;;;; henkan routines
(defun skk-henkan ()
  ;; $B%+%J$r4A;zJQ49$9$k%a%$%s%k!<%A%s!#(B
  (let (mark new-word kakutei-henkan)
    (if (string= skk-henkan-key "")
        (skk-kakutei)
      (if (not (eobp))
          ;; we use mark to go back to the correct position after henkan
          (setq mark (skk-save-point (forward-char 1) (point-marker))) )
      (if (not skk-henkan-active)
          (progn
            (skk-change-marker)
            (setq skk-current-search-prog-list skk-search-prog-list) ))
      ;; skk-henkan-1 $B$NCf$+$i%3!<%k$5$l$k(B skk-henkan-show-candidate $B$+$i(B throw
      ;; $B$5$l$k!#$3$3$G%-%c%C%A$7$?>l9g$O!"(B?x $B$,%9%H%j!<%`$KLa$5$l$F$$$k$N$G!"(B
      ;; $B$3$N4X?t$r=P$F!"(Bskk-previous-candidates $B$X$f$/!#(B
      (catch 'unread
        (setq new-word (or (skk-henkan-1) (skk-henkan-in-minibuff))
              kakutei-henkan skk-kakutei-flag )
        (if new-word
            (skk-insert-new-word new-word) ))
      (if mark
          (progn
            (goto-char mark)
            ;; $B;2>H$5$l$F$$$J$$%^!<%+!<$O!"(BGarbage Collection $B$,%3!<%k$5$l$?$H(B
            ;; $B$-$K2s<}$5$l$k$,!"$=$l$^$G$N4V!"%F%-%9%H$N$I$3$+$r;X$7$F$$$k$H!"(B
            ;; $B%F%-%9%H$N%"%C%W%G!<%H$N:]$K$=$N%^!<%+!<CM$r99?7$9$kI,MW$,$"$k(B
            ;; $B$N$G!"$I$3$b;X$5$J$$$h$&$K$9$k!#(B
            (skk-set-marker mark nil)
	    (backward-char 1) )
        (goto-char (point-max)) )
      (if kakutei-henkan
	  ;; $B3NDj$7$F$bNI$$(B ($B3NDj<-=q$K8uJd$r8+$D$1$?>l9g!"<-(B
	  ;; $B=qEPO?$r9T$C$?>l9g!"$"$k$$$O%_%K%P%C%U%!$+$i8uJd(B
	  ;; $B$rA*Br$7$?>l9g(B) $B$N$J$i!"(BOverlay $B$K$h$kI=<(JQ99$;(B
	  ;; $B$:$K$=$N$^$^3NDj!#(B
	  (skk-kakutei (if (skk-numeric-p)
			   (skk-get-simply-current-candidate 'noconv)
			 new-word )))
      )))

(defun skk-henkan-1 ()
  ;; skk-henkan $B$N%5%V%k!<%A%s!#(B
  (let (new-word)
    (if (eq skk-henkan-count 0)
        (progn
          (if (and (eq last-command 'skk-undo-kakutei-henkan)
                   (eq (car (car skk-current-search-prog-list))
                       'skk-search-kakutei-jisyo-file ))
              ;; in this case, we should not search kakutei jisyo.
              (setq skk-current-search-prog-list
                    (cdr skk-current-search-prog-list) ))
          (setq skk-henkan-list (skk-search))
          (if (null skk-henkan-list)
              nil
            (setq new-word (skk-get-current-candidate))
            (if skk-kakutei-flag
                ;; found the unique candidate in kakutei jisyo
                (setq this-command 'skk-kakutei-henkan
                      skk-last-kakutei-henkan-key skk-henkan-key ))))
      ;; $BJQ492s?t$,(B 1 $B0J>e$N$H$-!#(B
      (setq new-word (skk-get-current-candidate))
      (if (not new-word)
          ;; $B?7$7$$8uJd$r8+$D$1$k$+!"(Bskk-current-search-prog-list $B$,6u$K$J(B
          ;; $B$k$^$G(B skk-search $B$rO"B3$7$F%3!<%k$9$k!#(B
          (while (and skk-current-search-prog-list (not new-word))
            (setq skk-henkan-list (skk-nunion skk-henkan-list (skk-search))
                  new-word (skk-get-current-candidate) )))
      (if (and new-word (> skk-henkan-count 3))
          ;; show candidates in minibuffer
          (setq new-word (skk-henkan-show-candidates) )))
    new-word ))

;;;###skk-autoload
(defun skk-get-current-candidate ()
  (if (skk-numeric-p)
      (let (val)
        (skk-uniq-numerals)
        (setq val (skk-numeric-convert (skk-get-simply-current-candidate)))
        (if (not skk-recompute-numerals-key)
            val
          (skk-uniq-numerals)
          (skk-numeric-convert (skk-get-simply-current-candidate)) ))
    (skk-get-simply-current-candidate) ))

(defun skk-henkan-show-candidates ()
  ;; $B%_%K%P%C%U%!$GJQ49$7$?8uJd72$rI=<($9$k!#(B
  (skk-save-point
   (let* ((candidate-keys               ; $BI=<(MQ$N%-!<%j%9%H(B
           (mapcar (function (lambda (c) (char-to-string (upcase c))))
                   skk-henkan-show-candidates-keys ))
          key-num-alist                 ; $B8uJdA*BrMQ$NO"A[%j%9%H(B
          (key-num-alist1               ; key-num-alist $B$rAH$_N)$F$k$?$a$N:n6HMQO"A[%j%9%H!#(B
           (let ((count 6))
             (mapcar (function (lambda (key) (prog1 (cons key count)
                                               (setq count (1- count)) )))
                     ;; $B5U$5$^$K$7$F$*$$$F!"I=<($9$k8uJd$N?t$,>/$J$+$C$?$i@h(B
                     ;; $BF,$+$i4v$D$+:o$k!#(B
                     (reverse skk-henkan-show-candidates-keys) )))
          (loop 0)
          inhibit-quit
          henkan-list new-one str reverse n )
     ;; $BG0$N$?$a!#(Bskk-previous-candidate $B$r;2>H!#(B
     (if skk-use-face (skk-henkan-face-off))
     (delete-region skk-henkan-start-point skk-henkan-end-point)
     (while loop
       (if str
           (let (message-log-max)
             (message str) )
         (cond (reverse
                (setq loop (1- loop)
                      henkan-list (nthcdr (+ 4 (* loop 7)) skk-henkan-list)
                      reverse nil ))
               (skk-exit-show-candidates
                ;; $B8uJd$,?T$-$F$7$^$C$F!"(Bskk-henkan-show-candidates ->
                ;; skk-henkan-in-minibuff -> skk-henkan
                ;; -> skk-henkan-show-candidates $B$N=g$G!":F$S$3$N4X?t$,8F$P$l(B
                ;; $B$?$H$-$O!"$3$3$G(B henkan-list $B$H(B loop $B$r7W;;$9$k!#(B
                (setq henkan-list (nthcdr skk-henkan-count skk-henkan-list)
                      loop (car skk-exit-show-candidates)
                      skk-exit-show-candidates nil ))
               (t
                ;; skk-henkan-show-candidates-keys $B$N:G=*$N%-!<$KBP1~$9$k8uJd(B
                ;; $B$,=P$F$/$k$^$G%5!<%A$rB3$1$k!#(B
                (if (skk-numeric-p) (skk-uniq-numerals))
                (while (and skk-current-search-prog-list
                            (null (nthcdr (+ 11 (* loop 7)) skk-henkan-list)) )
                  (setq skk-henkan-list
                        (skk-nunion skk-henkan-list (skk-search)) )
                  (if (skk-numeric-p)
                      (skk-uniq-numerals) ))
                (if (skk-numeric-p)
                    (skk-numeric-convert*7) )
                (setq henkan-list (nthcdr (+ 4 (* loop 7))
                                          skk-henkan-list ))))
         (setq n (skk-henkan-show-candidate-subr candidate-keys henkan-list)) )
       (if (> n 0)
           (condition-case nil
               (let* ((event (skk-read-event))
                      (char (skk-event-to-character event))
                      num )
                 (if (null char)
                     (skk-unread-event event)
                   (setq key-num-alist (nthcdr (- 7 n) key-num-alist1))
                   (if (null key-num-alist)
                       nil
                     (setq num (cdr (or (assq char key-num-alist)
                                        (if (skk-lower-case-p char)
                                            (assq (upcase char) key-num-alist)
                                          (assq (downcase char) key-num-alist) )))))
                   (cond (num
                          (setq new-one (nth num henkan-list)
                                skk-henkan-count (+ 4 (* loop 7) num)
                                skk-kakutei-flag t
                                loop nil
                                str nil ))
                         ((eq char (skk-int-char 32)) ; space
                          (if (or skk-current-search-prog-list
                                  (nthcdr 7 henkan-list) )
                              (setq loop (1+ loop)
                                    str nil )
                            ;; $B8uJd$,?T$-$?!#$3$N4X?t$+$iH4$1$k!#(B
                            (let ((last-showed-index (+ 4 (* loop 7))))
                              (setq skk-exit-show-candidates
                                    ;; cdr $BIt$O!"<-=qEPO?$KF~$kA0$K:G8e$KI=<($7(B
                                    ;; $B$?8uJd72$NCf$G:G=i$N8uJd$r;X$9%$%s%G%/%9(B
                                    (cons loop last-showed-index) )
                              ;; $B<-=qEPO?$KF~$k!#(Bskk-henkan-count $B$O(B
                              ;; skk-henkan-list $B$N:G8e$N8uJd$N<!(B ($BB8:_$7$J$$(B
                              ;; --- nil )$B$r;X$9!#(B
                              (setq skk-henkan-count (+ last-showed-index n)
                                    loop nil
                                    str nil ))))
                         ((eq char skk-previous-candidate-char)  ; ?x
                          (if (eq loop 0)
                              ;; skk-henkan-show-candidates $B$r8F$VA0$N>uBV$KLa(B
                              ;; $B$9!#(B
                              (progn
                                (setq skk-henkan-count 4)
                                (skk-unread-event (skk-character-to-event
						   skk-previous-candidate-char))
                                ;; skk-henkan $B$^$G0l5$$K(B throw $B$9$k!#(B
                                (throw 'unread nil) )
                            ;; $B0l$DA0$N8uJd72$r%(%3!<%(%j%"$KI=<($9$k!#(B
                            (setq reverse t
                                  str nil )))
                         (t (skk-message "\"%c\" $B$OM-8z$J%-!<$G$O$"$j$^$;$s!*(B"
                                         "\"%c\" is not valid here!"
                                         char )
                            (sit-for 1) ))))
             (quit
              ;; skk-previous-candidate $B$X(B
              (setq skk-henkan-count 0)
              (skk-unread-event (skk-character-to-event
				 skk-previous-candidate-char))
              ;; skk-henkan $B$^$G0l5$$K(B throw $B$9$k!#(B
              (throw 'unread nil) ))))  ; end of while loop
     (if (consp new-one)
         (cdr new-one)
       new-one ))))

(defun skk-henkan-show-candidate-subr (keys candidates)
  ;; key $B$H(B candidates $B$rAH$_9g$o$;$F(B 7 $B$D0J2<$N8uJd72(B ($B8uJd?t$,B-$j$J$+$C$?$i(B
  ;; $B$=$3$GBG$A@Z$k(B) $B$NJ8;zNs$r:n$j!"%_%K%P%C%U%!$KI=<($9$k!#(B
  (let ((n 0) str cand
        message-log-max )
    (if (not (car candidates))
        nil
      (setq n 1
            ;; $B:G=i$N8uJd$NA0$K6uGr$r$/$C$D$1$J$$$h$&$K:G=i$N8uJd$@$1@h$K<h$j(B
            ;; $B=P$9!#(B
            str (concat (car keys) ":" (skk-%-to-%%
                                        (if (consp (car candidates))
                                            (cdr (car candidates))
                                          (car candidates) ))))
      ;; $B;D$j$N(B 6 $B$D$r<h$j=P$9!#8uJd$H8uJd$N4V$r6uGr$G$D$J$0!#(B
      (while (and (< n 7) (setq cand (nth n candidates)))
        (setq cand (skk-%-to-%% (if (consp cand) (cdr cand) cand))
              str (concat str "  " (nth n keys) ":" cand)
              n (1+ n) ))
      (message "%s  [$B;D$j(B %d%s]"
               str (length (nthcdr n candidates))
               (make-string (length skk-current-search-prog-list) ?+) ))
    ;; $BI=<($9$k8uJd?t$rJV$9!#(B
    n ))

(defun skk-%-to-%% (str)
  ;; STR $BCf$K(B % $B$r4^$`J8;z$,$"$C$?$i!"(B%% $B$K$7$F(B message $B$G%(%i!<$K$J$i$J$$$h$&(B
  ;; $B$K$9$k!#(B
  (let ((tail str)
        temp beg end )
    (save-match-data
      (while (string-match "%+" tail)
        (setq beg (match-beginning 0)
              end (match-end 0)
              temp (concat temp (substring tail 0 beg)
                           (make-string (* 2 (- end beg)) ?%) )
              tail (substring tail end) ))
      (concat temp tail) )))

(defun skk-henkan-in-minibuff ()
  ;; $B%_%K%P%C%U%!$G<-=qEPO?$r$7!"EPO?$7$?%(%s%H%j$NJ8;zNs$rJV$9!#(B
  (save-match-data
    (let ((enable-recursive-minibuffers t)
          ;; $BJQ49Cf$K(B isearch message $B$,=P$J$$$h$&$K$9$k!#(B
          skk-isearch-message new-one )
      (add-hook 'minibuffer-setup-hook 'skk-setup-minibuffer)
      (condition-case nil
          (setq new-one
                (read-from-minibuffer
                 (concat (or (if (skk-numeric-p)
                                 (skk-numeric-midasi-word) )
                             (if skk-okuri-char
                                 (skk-compute-henkan-key2)
                               skk-henkan-key ))
                         " " )))
        (quit
         (setq new-one "") ))
      (if (string= new-one "")
          (if skk-exit-show-candidates
              ;; $B%_%K%P%C%U%!$KI=<($7$?8uJd$,?T$-$F<-=qEPO?$KF~$C$?$,!"6uJ8;z(B
              ;; $BNs$,EPO?$5$l$?>l9g!#:G8e$K%_%K%P%C%U%!$KI=<($7$?8uJd72$r:FI=(B
              ;; $B<($9$k!#(B
              (progn
                (setq skk-henkan-count (cdr skk-exit-show-candidates))
                (skk-henkan) )
            ;; skk-henkan-show-candidates $B$KF~$kA0$K8uJd$,?T$-$?>l9g(B
            (setq skk-henkan-count (1- skk-henkan-count))
            (if (eq skk-henkan-count -1)
                (progn
                  ;; $BAw$j$"$j$NJQ49$G<-=qEPO?$KF~$j!"6uJ8;z$rEPO?$7$?8e!"$=$N(B
                  ;; $B$^$^:FEYAw$j$J$7$H$7$FJQ49$7$?>l9g$O(B 
                  ;; skk-henkan-okurigana, skk-okuri-char $B$NCM$r(B nil $B$K$7$J$1(B
                  ;; $B$l$P!"$=$l$>$l$NCM$K8E$$Aw$j2>L>$,F~$C$?$^$^$G8!:w$K<:GT(B
                  ;; $B$9$k!#(B
                  (setq skk-henkan-okurigana nil
                        skk-okurigana nil
                        skk-okuri-char nil )
                  (skk-change-marker-to-white) )
              ;; skk-henkan-count $B$,(B -1 $B$G$J$1$l$P!"%+%l%s%H%P%C%U%!$G$O:G8e$N(B
              ;; $B8uJd$rI=<($7$?$^$^$J$N$G(B ($BI=<(4XO"$G$O2?$b$7$J$/$F$b!"$b$&4{(B
              ;; $B$KK>$_$N>uBV$K$J$C$F$$$k(B) $B2?$b$7$J$$!#(B
              ))
        ;; $B%_%K%P%C%U%!$GJQ49$7$?J8;zNs$,$"$k(B ($B6uJ8;zNs$G$J$$(B) $B$H$-!#(B
        ;; $BKvHx$N6uGr$r<h$j=|$/!#(B
        (if (string-match "[ $B!!(B]+$" new-one)
            (setq new-one (substring new-one 0 (match-beginning 0))) )
        (if (skk-numeric-p)
            (setq new-one (skk-adjust-numeric-henkan-data new-one))
          ;; $B$9$4$/$?$/$5$s$N8uJd$,$"$k>l9g$K!"$=$N:G8e$K?7$7$$8uJd$r2C$($k$N$O(B
          ;; $B$1$C$3$&9|$@$,!#(B
          (setq skk-henkan-list (nconc skk-henkan-list (list new-one))
                ;; $B%U%i%0$r%*%s$K$9$k!#(B
                skk-kakutei-flag t ))
        (setq skk-henkan-in-minibuff-flag t
              skk-touroku-count (1+ skk-touroku-count) ))
      ;; (nth skk-henkan-count skk-henkan-list) $B$,(B nil $B$@$+$i<-=qEPO?$K(B
      ;; $BF~$C$F$$$k!#(Bskk-henkan-count $B$r%$%s%/%j%a%s%H$9$kI,MW$O$J$$!#(B
      ;; (setq skk-henkan-count (1+ skk-henkan-count))
      ;; new-one $B$,6uJ8;zNs$@$C$?$i(B nil $B$rJV$9!#(B
      (if (not (string= new-one "")) new-one) )))

(defun skk-compute-henkan-key2 ()
  ;; skk-henkan-okurigana $B$,(B non-nil $B$J$i(B skk-henkan-key $B$+$i!"$+$D$F(B 
  ;; skk-henkan-key2 $B$H8F$P$l$F$$$?$b$N$r:n$k!#(B
  ;; skk-henkan-key2 $B$H$O!"!V4A;zItJ,$NFI$_(B + "*" + $BAw$j2>L>!W$N7A<0$NJ8;zNs$r(B
  ;; $B8@$&!#(B
  (if skk-henkan-okurigana
      (save-match-data
        (if (string-match "[a-z]+$" skk-henkan-key)
            (concat (substring skk-henkan-key 0 (match-beginning 0))
                    "*" skk-henkan-okurigana )))))
              
(defun skk-setup-minibuffer ()
  ;; $B%+%l%s%H%P%C%U%!$NF~NO%b!<%I$K=>$$%_%K%P%C%U%!$NF~NO%b!<%I$r@_Dj$9$k!#(B
  (let ((mode (skk-spy-origin-buffer-mode)))
    (if (not mode)
        nil
      (cond ((eq mode 'hirakana) (skk-j-mode-on))
            ((eq mode 'katakana) (skk-j-mode-on t))
            ((eq mode 'abbrev) (skk-abbrev-mode-on))
            ((eq mode 'ascii) (skk-ascii-mode-on))
            ((eq mode 'zenkaku) (skk-zenkaku-mode-on))))))

(defun skk-spy-origin-buffer-mode ()
  ;; $B%_%K%P%C%U%!$K5o$k$H$-$K%*%j%8%J%k$N%+%l%s%H%P%C%U%!$NF~NO%b!<%I$rDe;!$9$k!#(B
  (with-current-buffer (skk-minibuffer-origin)
    (if skk-mode
        (cond (skk-abbrev-mode 'abbrev)
              (skk-ascii-mode 'ascii)
              (skk-zenkaku-mode 'zenkaku)
              (skk-katakana 'katakana)
              (t 'hirakana) ))))

;;;###skk-autoload
(defun skk-previous-candidate ()
  "$B"'%b!<%I$G$"$l$P!"0l$DA0$N8uJd$rI=<($9$k!#(B
$B"'%b!<%I0J30$G$O%+%l%s%H%P%C%U%!$K(B \"x\" $B$rA^F~$9$k!#(B
$B3NDj<-=q$K$h$k3NDj$ND>8e$K8F$V$H3NDj$,%"%s%I%%$5$l$F!"3NDjA0$N>uBV$G(B
skk-last-kakutei-henkan-key $B$,%+%l%s%H%P%C%U%!$KA^F~$5$l$k!#(B"
  (interactive)
  (if (not skk-henkan-active)
      (if (not (eq last-command 'skk-kakutei-henkan))
          (skk-kana-input)
        ;; restore the state just before the last kakutei henkan.
        (delete-region skk-henkan-start-point (point))
        (skk-set-henkan-point-subr)
        (insert skk-last-kakutei-henkan-key)
        (setq this-command 'skk-undo-kakutei-henkan) )
    (if (string= skk-henkan-key "")
        nil
      ;; $B6uGr$rA^F~$7$F$*$$$F!"8e$G(B delete-backward-char $B$r;H$C$F>C$9J}K!$G$O!"(B
      ;; overwrite-mode $B$N$H$-$K$=$N6uGr$r>C$;$J$$!#=>$$(B skk-henkan $B$G9T$J$C$F(B
      ;; $B$$$kJ}K!$HF1$8$b$N$r;H$&!#(B
      ;;(insert " ")
      (let ((mark
             (if (not (eobp))
                 (skk-save-point (forward-char 1) (point-marker)) )))
        (skk-save-point
          (if (eq skk-henkan-count 0)
              (progn
                (if skk-okuri-char
                    ;; roman prefix for okurigana should be removed.
                    (setq skk-henkan-key (substring skk-henkan-key 0 -1)) )
                (setq skk-henkan-count -1
                      skk-henkan-list nil
                      skk-henkan-okurigana nil
                      skk-okuri-char nil
                      skk-okurigana nil
                      skk-prefix "" )
                (if skk-auto-okuri-process
                    (skk-init-auto-okuri-variables) )
                (if (skk-numeric-p)
                    (skk-init-numeric-conversion-variables) )
                ;; Emacs 19.28 $B$@$H2?8N$+(B Overlay $B$r>C$7$F$*$+$J$$$H!"<!$K(B
                ;; insert $B$5$l$k(B skk-henkan-key Overlay $B$,$+$+$C$F$7$^$&!#(B
                (if skk-use-face (skk-henkan-face-off))
                (delete-region skk-henkan-start-point skk-henkan-end-point)
                (goto-char skk-henkan-end-point)
                (insert skk-henkan-key)
                (skk-change-marker-to-white) )
            (setq skk-henkan-count (1- skk-henkan-count))
            (skk-insert-new-word (skk-get-simply-current-candidate)) ))
        ;;(if (and (> (point) 1) (eq (char-after (1- (point))) 32))
        ;; delete-backward-char $B$G$O!"(Boverwrite-mode $B$N$H$-$KD>A0$N6uGr$r>C$;(B
        ;; $B$J$$!#(B
        ;;    (delete-backward-char 1) )
        (if mark
            (progn
              (goto-char mark)
              (skk-set-marker mark nil)
              (backward-char 1) )
          (goto-char (point-max)) )
        (if (and skk-abbrev-mode (eq skk-henkan-count -1))
            (skk-abbrev-mode-on) )))))

(defun skk-insert-new-word (word)
  ;; $B8+=P$78l$r>C$7!"$=$N>l=j$XJQ497k2L$NJ8;zNs$rA^F~$9$k!#(B
  (let (func)
    ;; $BG0$N$?$a!#2?8N$3$l$rF~$l$k$N$+$K$D$$$F$O!"(Bskk-previous-candidate $B$r;2>H(B
    (if skk-use-face (skk-henkan-face-off))
    (delete-region skk-henkan-start-point skk-henkan-end-point)
    (goto-char skk-henkan-start-point)
    ;; (^_^;) $B$N$h$&$J8+=P$78l$KBP$7!"(Bread-from-string $B$r8F$V$H%(%i!<$K$J$k$N(B
    ;; $B$G!"(Bcondition-case $B$G$=$N%(%i!<$rJa$^$($k!#(B
    (condition-case nil
        (setq func (car (read-from-string word)))
      (error (setq func word)))
    ;; symbolp $B$G(B nil $B$rJV$9$h$&$JC18l$r!"(Bsymbolp $B$G%A%'%C%/$9$k$3$HL5$/$$$-(B
    ;; $B$J$j(B fboundp $B$G%A%'%C%/$9$k$H!"%(%i!<$K$J$k!#(B
    ;; e.x. "(#0)"
    (condition-case nil
        (if (and (listp func) (symbolp (car func)) (fboundp (car func)))
            (insert (eval func))
          (insert word) )
      ;; $BJ8;zNs$rJV$5$J$$(B Lisp $B%W%m%0%i%`$rI>2A$7$F$b%(%i!<$K$J$i$J$$J}$,JXMx!)(B
      (error nil) )
    (skk-set-marker skk-henkan-end-point (point))
    (if skk-use-face (skk-henkan-face-on))
    (if skk-insert-new-word-function
        (funcall skk-insert-new-word-function) )))

;;;###skk-autoload
(defun skk-kakutei (&optional word)
  "$B8=:_I=<($5$l$F$$$k8l$G3NDj$7!"<-=q$N99?7$r9T$&!#(B
$B%*%W%7%g%J%k0z?t$N(B WORD $B$rEO$9$H!"8=:_I=<($5$l$F$$$k8uJd$H$OL54X78$K(B WORD $B$G3N(B
$BDj$9$k!#(B"
  ;; read only $B$G%(%i!<$K$J$k$h$&$K$9$k$H(B read only $B%P%C%U%!$G(B SKK $B$,5/F0$G$-(B
  ;; $B$J$/$J$k!#(B
  (interactive)
  (let ((inhibit-quit t)
        converted kakutei-word )
    (if skk-mode
        (skk-j-mode-on skk-katakana)
      ;; $B%+%l%s%H%P%C%U%!$G$^$@(B skk-mode $B$,%3!<%k$5$l$F$$$J$+$C$?$i!"%3!<%k$9(B
      ;; $B$k!#(B
      (skk-mode 1) )
    (if (not skk-henkan-on)
        nil
      (if (not skk-henkan-active)
          nil
        (setq kakutei-word
              ;; $B3NDj<-=q$N8l$G3NDj$7$?$H$-$O!"<-=q$K$=$N8l$r=q$-9~$`I,MW$b$J(B
              ;; $B$$$7!"99?7$9$kI,MW$b$J$$$H;W$C$F$$$?$,!"Jd40$r9T$J$&$H$-$O!"(B
              ;; $B8D?M<-=q$r;2>H$9$k(B ($B3NDj<-=q$O;2>H$7$J$$(B) $B$N$G!"B?>/;q8;$H;~(B
              ;; $B4V$rL5BL$K$7$F$b!"8D?M<-=q$K3NDj<-=q$N%(%s%H%j$r=q$-9~$s$G99(B
              ;; $B?7$b$7$F$*$/!#(B
              (or word (skk-get-simply-current-candidate (skk-numeric-p))) )
        (if (or
             (and (not skk-search-excluding-word-pattern-function) kakutei-word)
             (and
              kakutei-word
              skk-search-excluding-word-pattern-function
              (not
               (funcall skk-search-excluding-word-pattern-function kakutei-word) )))
            (progn
            (skk-update-jisyo kakutei-word)
	    ;; keep this order
	    (setq skk-last-henkan-result kakutei-word)
	    (skk-set-marker skk-last-henkan-point (point))
            (if (skk-numeric-p)
                (progn
                  (setq converted (skk-get-simply-current-candidate))
                  (skk-update-jisyo-for-numerals kakutei-word converted) )))))
      (skk-kakutei-cleanup-henkan-buffer) )
    (skk-kakutei-save-and-init-variables
     (if (skk-numeric-p)
         (cons kakutei-word converted)
       kakutei-word ))
    (skk-do-auto-fill)
    (skk-set-cursor-color (if skk-katakana
                              skk-katakana-cursor-color
                            skk-hirakana-cursor-color ))))

(defun skk-kakutei-cleanup-henkan-buffer ()
  ;; $B3NDjD>8e$N%P%C%U%!$N@07A$r9T$J$&!#(B
  ;; $B$3$N4X?t$O!"(Bskk-vip.el $B$G>e=q$-$5$l$k!#(B
  (if skk-okurigana
      (progn
        (skk-delete-okuri-mark)
        (if (and skk-katakana skk-convert-okurigana-into-katakana)
            (skk-katakana-region skk-henkan-end-point (point)) )))
  (skk-delete-henkan-markers)
  (if (and (boundp 'self-insert-after-hook) self-insert-after-hook)
      (funcall self-insert-after-hook skk-henkan-start-point (point)) )
  (if overwrite-mode
      (skk-del-char-with-pad
       (skk-ovwrt-len
        (string-width
         (skk-buffer-substring skk-henkan-start-point (point)) )))))

(defun skk-kakutei-save-and-init-variables (&optional kakutei-word)
  ;; $B3NDj;~$KJQ?t$N=i4|2=$H%"%s%I%%$N$?$a$NJQ?t$NJ]B8$r9T$J$&!#(B
  (if (and kakutei-word (or (consp kakutei-word)
                            (not (string= kakutei-word "")) ))
      (progn
        ;; skk-undo-kakutei $B$N$?$a$K:G8e$NJQ49$N%G!<%?!<$rJ]B8$9$k!#(B
        (setq skk-last-henkan-key skk-henkan-key
              ;; $B3NDj$7$?8l$r@hF,$K$7$F(B skk-henkan-list $B$NCM$rJ]B8$9$k!#(B
              skk-last-henkan-list (cons kakutei-word
                                         (delete kakutei-word skk-henkan-list) )
              skk-last-henkan-okurigana skk-henkan-okurigana
              skk-last-okuri-char skk-okuri-char
              skk-kakutei-count (1+ skk-kakutei-count) )
        ;;(if (boundp 'disable-undo)
        ;;    (setq disable-undo nil)
        ))
  (setq skk-abbrev-mode nil
        skk-exit-show-candidates nil
        skk-henkan-active nil
        skk-henkan-count -1
        skk-henkan-key nil
        skk-henkan-list nil
        skk-henkan-okurigana nil
        skk-henkan-on nil
        skk-kakutei-flag nil
        skk-okuri-char nil
        skk-prefix "" )
  (if skk-auto-okuri-process
      (skk-init-auto-okuri-variables) )
  (if (skk-numeric-p)
      (skk-init-numeric-conversion-variables) ))

(defun skk-undo-kakutei ()
  "$B0lHV:G8e$N3NDj$r%"%s%I%%$7!"8+=P$7$KBP$9$k8uJd$rI=<($9$k!#(B
$B:G8e$K3NDj$7$?$H$-$N8uJd$O%9%-%C%W$5$l$k!#(B
$B8uJd$,B>$K$J$$$H$-$O!"%_%K%P%C%U%!$G$N<-=qEPO?$KF~$k!#(B"
  (interactive)
  (cond ((eq last-command 'skk-undo-kakutei)
         (skk-error "$B3NDj%"%s%I%%$OO"B3;HMQ$G$-$^$;$s(B"
                    "Cannot undo kakutei repeatedly" ))
        (skk-henkan-active
         (skk-error "$B"'%b!<%I$G$O3NDj%"%s%I%%$G$-$^$;$s(B"
                    "Cannot undo kakutei in $B"'(B mode" ))
        ((or (not skk-last-henkan-key) (string= skk-last-henkan-key ""))
         ;; skk-last-henkan-key may be nil or "".
         (skk-error "$B%"%s%I%%%G!<%?!<$,$"$j$^$;$s(B" "Lost undo data") ))
  (condition-case nil
      (let ((end (if skk-last-henkan-okurigana
                     (+ (length skk-last-henkan-okurigana)
                        skk-henkan-end-point )
                   skk-henkan-end-point )))
        (setq skk-henkan-active t
              skk-henkan-key skk-last-henkan-key
              skk-henkan-list skk-last-henkan-list
              skk-henkan-on t
              skk-henkan-okurigana skk-last-henkan-okurigana
              skk-okuri-char skk-last-okuri-char
              skk-current-search-prog-list
              (if (eq (car (car skk-search-prog-list))
                      'skk-search-kakutei-jisyo-file )
                  ;; $B3NDj<-=q$OC5$7$F$bL50UL#!#(B
                  (cdr skk-search-prog-list)
                skk-search-prog-list ))
        (if (>= (point-max) end)
            ;; $B:G8e$NJQ49ItJ,$N%F%-%9%H$r>C$9!#Aw$j2>L>$rGD0.$7$F$$$k$N$J$i(B 
            ;; (skk-process-okuri-early $B$,(B non-nil $B$J$iAw$j2>L>$rGD0.$G$-$J$$(B)$B!"(B
            ;; $BAw$j2>L>$r4^$a$?ItJ,$^$G$r>C$9!#(B
            (delete-region skk-henkan-start-point end) )
        (goto-char skk-henkan-start-point)
        (cancel-undo-boundary)
        (insert "$B"'(B")
        (undo-boundary)
        (skk-set-marker skk-henkan-start-point (point))
        (if skk-okuri-char
            ;; $BAw$j$"$j(B
            (progn
              (insert (substring skk-henkan-key 0
                                 (1- (length skk-henkan-key)) ))
              (skk-set-marker skk-henkan-end-point (point))
              (if skk-henkan-okurigana (insert skk-henkan-okurigana)) )
          (insert skk-henkan-key)
          (skk-set-marker skk-henkan-end-point (point)) )
        ;; $B$5$!!"=`Hw$,@0$$$^$7$?!*(B
        (skk-message "$B3NDj%"%s%I%%!*(B" "Undo kakutei!")
        (setq skk-henkan-count 1)
        (skk-henkan) )
    ;; skk-kakutei-undo $B$+$iESCf$GH4$1$?>l9g$O!"3F<o%U%i%0$r=i4|2=$7$F$*$+$J$$(B
    ;; $B$H<!$NF0:n$r$7$h$&$H$7$?$H$-$K%(%i!<$K$J$k!#(B
    (error (skk-kakutei))
    (quit (skk-kakutei)) ))
     
(defun skk-downcase (char)
  (let ((d (cdr (assq char skk-downcase-alist))))
    (if d
	d
      (downcase char) )))

(defun skk-set-henkan-point (&optional arg)
  "$BJQ49$r3+;O$9$k%]%$%s%H$r%^!<%/$7!"BP1~$9$k(B skk-prefix $B$+!"Jl2;$rF~NO$9$k!#(B"
  (interactive "*P")
  (combine-after-change-calls
    (let* ((last-char (skk-downcase last-command-char))
	   (normal (not (eq last-char last-command-char)))
           (sokuon (and (string= skk-prefix (char-to-string last-char))
                        (/= last-char ?o)))
           (henkan-active skk-henkan-active))
      (cancel-undo-boundary)
      (if (or (not skk-henkan-on) skk-henkan-active)
          (if normal
              (skk-set-henkan-point-subr)
            (if skk-henkan-on
                (skk-set-henkan-point-subr) )
            (if henkan-active
                (skk-emulate-original-map arg)
              (skk-self-insert arg) ))
        (if (not normal)
            ;; process special char
            (progn
              (insert last-char)
              (skk-set-marker skk-henkan-end-point (point))
              (setq skk-henkan-count 0
                    skk-henkan-key (skk-buffer-substring
                                    skk-henkan-start-point (point) )
                    skk-prefix "" )
              (skk-henkan) )
          ;; prepare for the processing of okurigana if not skk-okurigana
          ;; and the preceding character is not a numeric character.
          ;; if the previous char is a special midashi char or a
          ;; numeric character, we assume that the user intended to type the
          ;; last-command-char in lower case.
          (if (and (not skk-okurigana)
                   (or (= skk-henkan-start-point (point))
                       (let ((p (char-after (1- (point)))))
                         (not
                          (or
                           ;; previous char is a special midashi char
                           (memq p skk-special-midashi-char-list)
                           ;; previous char is an ascii numeric char
                           (and (<= 48 p) ; ?0
                                (<= p 57) ) ; ?9
                           ;; previous char is a jis numeric char
                           (and (eq (char-after (- (point) 2)) 163)
                                (<= 176 p) (<= p 185) ))))))
              (if skk-process-okuri-early
                  (progn
                    (skk-set-marker skk-henkan-end-point (point))
                    (setq skk-okuri-char (char-to-string last-char))
                    (if sokuon
                        (progn
                          (setq skk-henkan-key
                                (concat (skk-buffer-substring
                                         skk-henkan-start-point
                                         skk-kana-start-point )
                                        (if skk-katakana "$B%C(B" "$B$C(B")
                                        skk-henkan-okurigana ))
                          (skk-erase-prefix)
                          (insert (if skk-katakana "$B%C(B " "$B$C(B "))
                          (setq skk-prefix ""
                                skk-henkan-count 0 )
                          (skk-henkan)
                          ;;(if skk-use-face (skk-henkan-face-off))
                          (delete-backward-char 2)
                          ;;(if skk-use-face (skk-henkan-face-on))
                          )
                      (setq skk-henkan-key (concat
                                            (skk-buffer-substring
                                             skk-henkan-start-point
                                             (point) )
					    skk-okuri-char ))
                      (insert " ")
                      (setq skk-prefix ""
                            skk-henkan-count 0 )
                      (skk-henkan)
                      ;;(if skk-use-face (skk-henkan-face-off))
                      (delete-backward-char 1)
                      ;;(if skk-use-face (skk-henkan-face-on))
                      )
                    ;; we set skk-kana-start-point here, since the marker may no
                    ;; longer point at the correct position after skk-henkan.
                    (skk-set-marker skk-kana-start-point (point)) )
                (if (= skk-henkan-start-point (point))
                    nil
                  (if sokuon
                      (progn
                        (skk-erase-prefix)
                        (insert (if skk-katakana "$B%C(B" "$B$C(B"))
                        (setq skk-prefix "") ))
                  (skk-set-marker skk-okurigana-start-point (point))
                  (insert "*")
                  (skk-set-marker skk-kana-start-point (point))
                  (setq skk-okuri-char (char-to-string last-char)
                        skk-okurigana t ))))))
      (if normal
          (skk-unread-event
           (skk-character-to-event last-char)) ))))

;;;###skk-autoload
(defun skk-start-henkan (arg)
  "$B"&%b!<%I$G$OJQ49$r3+;O$9$k!#"'%b!<%I$G$O<!$N8uJd$rI=<($9$k!#(B
  $B$=$NB>$N%b!<%I$G$O!"%*%j%8%J%k$N%-!<3d$jIU$1$N%3%^%s%I$r%(%_%e%l!<%H$9$k!#(B"
  (interactive "*p")
  (combine-after-change-calls
    (save-match-data
      (if (not skk-henkan-on)
          (skk-self-insert arg)
        (if skk-henkan-active
            (progn (setq skk-henkan-count (1+ skk-henkan-count))
                   (skk-henkan) )
          (let ((pos (point)))
            (or (string= skk-prefix "")
                (skk-error "$B%U%#%C%/%9$5$l$F$$$J$$(B skk-prefix $B$,$"$j$^$9(B"
                           "Have unfixed skk-prefix" ))
            (if (< pos skk-henkan-start-point)
                (skk-error
                 "$B%+!<%=%k$,JQ493+;OCOE@$h$jA0$K$"$j$^$9(B"
                 "Henkan end point must be after henkan start point" ))
            ;; $B8+=P$78l$,%+%?%+%J$G$"$l$P$R$i$,$J$KJQ49$9$k!#$b$78+=P$78l$NJQ49(B
            ;; $B$;$:$K$=$N$^$^(B skk-henkan $B$KEO$7$?$1$l$P!"(BC-u SPC (arg $B$,(B 4 $B$K$J(B
            ;; $B$k(B) $B$H%?%$%W$9$l$P$h$$!#(B
            (if (and skk-katakana (eq arg 1))
                (skk-hiragana-region skk-henkan-start-point pos) )
            (setq skk-henkan-key (skk-buffer-substring
                                  skk-henkan-start-point pos ))
            (if skk-allow-spaces-newlines-and-tabs
                ;; skk-henkan-key $B$NCf$N(B "[ \n\t]+" $B$r40A4$K<h$j=|$/!#(B
                (while (string-match "[ \n\t]+" skk-henkan-key)
                  (setq skk-henkan-key
                        (concat (substring skk-henkan-key 0 (match-beginning 0))
                                (substring skk-henkan-key (match-end 0)) )))
              (skk-save-point
               (beginning-of-line)
               (if (> (point) skk-henkan-start-point)
                   (skk-error
                    "$BJQ49%-!<$K2~9T$,4^$^$l$F$$$^$9(B"
                    "Henkan key may not contain a new line character" )))
              ;; $B:G=i$N%9%Z!<%9$G(B skk-henkan-key $B$r$A$g$s@Z$k$@$1!#(B
              (setq skk-henkan-key (substring skk-henkan-key 0
                                              (string-match " "
                                                            skk-henkan-key ))))
            (skk-set-marker skk-henkan-end-point pos)
            (setq skk-henkan-count 0)
            (skk-henkan)
            (if (and skk-abbrev-mode skk-henkan-active)
		(progn
		  (skk-j-mode-on)
		  (setq skk-abbrev-mode t) )))) ;; XXX
        (cancel-undo-boundary) ))))

(defun skk-backward-and-set-henkan-point (arg)
  "$B%]%$%s%H$ND>A0$K$"$kJ8;zNs$N@hF,$KJQ493+;O%]%$%s%H$r<($9(B \"$B"&(B\" $B$rIU$1$k!#(B
$B%+!<%=%k$ND>A0$K$"$kJ8;z(B \($B%9%Z!<%9J8;z!"%?%VJ8;z!"D92;$rI=$o$9!V!<!W(B $B$OL5>r7o(B
$B$K%9%-%C%W$5$l$k(B\) $B$r(B skk-what-char-type $B$K$FH=JL$7!"F1<o$NJ8;zNs$r$R$H$+$?$^(B
$B$j$H$7$F8eJ}$X%9%-%C%W$9$k!#(B
$BC"$7!"$R$i$+$J$N>l9g$O!V$r!W$ND>A0$G!"%+%?%+%J$N>l9g$O!V%r!W$ND>A0$G;_$^$k!#(B
C-u ARG $B$G(B ARG $B$rM?$($k$H!"$=$NJ8;zJ,$@$1La$C$FF1$8F0:n$r9T$J$&!#(B"
  (interactive "*P")
  (if (not skk-mode)
      (skk-emulate-original-map arg)
    (catch 'exit1
      (skk-save-point
        ;; $B$H$j$"$($::G=i$N(B SPC, TAB, $BA43Q(B SPC $B$@$1%8%c%s%W$9$k!#(B
        (skip-chars-backward " \t$B!!(B")
        ;; $B0z?t$"$j!#(B
        (if arg
            (if (not skk-allow-spaces-newlines-and-tabs)
                (skk-backward-char (prefix-numeric-value arg))
              (setq arg (prefix-numeric-value arg))
              (while (> arg 0)
                (skip-chars-backward " \t$B!!(B")
                (if (bolp)
                    ;; $B9TF,$@$C$?$i0l9TA0$N9TKv$^$GLa$k$,!"(Barg $B$O8:$i$5$J$$!#(B
                    (skk-backward-char 1)
                  (skk-backward-char 1)
                  (setq arg (1- arg)) )))
          ;; $B0z?t$J$7!#(B
          (let ((limit
                 (if (not skk-allow-spaces-newlines-and-tabs)
                     (skk-save-point (beginning-of-line) (point))
                   (point-min) ))
                ;; $B!2!1!0!/!.!-!,!+!*!)!(!'!&!%!$!#(B
                (unknown-chars-regexp
                 (if skk-allow-spaces-newlines-and-tabs
                     "[ $B!!(B\n\t$B!<!7!6!5!4!3(B]"
                   "[$B!!!<!7!6!5!4!3(B]" ))
                char p )
            (save-match-data
              (skk-save-point
                (skk-backward-char 1)
                (while (and (> (point) limit)
                            ;; unknown-chars-regexp $B$G$OJ8;z<oJL$,H=JL$G$-$J$$$N(B
                            ;; $B$G!"$=$NJ8;zNs$,B3$/8B$j%]%$%s%H$r%P%C%U%!$N@hF,(B
                            ;; $BJ}8~$XLa$9!#(B
                            (looking-at unknown-chars-regexp) )
                  (skk-backward-char 1) )
                (setq char (skk-what-char-type))
                (if (eq char 'unknown)
                    (throw 'exit1 nil)
                  (skk-backward-and-set-henkan-point-1 char)
                  (setq p (point))
                  (if skk-allow-spaces-newlines-and-tabs
                      (while (and (> (point) limit) (bolp))
                        ;; 1 $B9T>e$N9TKv$X!#(B
                        (skk-backward-char 1)
                        ;; $B%]%$%s%H$,H=JL$G$-$J$$J8;z<oJL$N>e$K$"$k4V$O(B 
                        ;; backward $BJ}8~$X%]%$%s%H$rLa$9!#(B
                        ;;(while (and (> (point) limit)
                        ;;            (looking-at unknown-chars-regexp) )
                        ;;  (skk-backward-char 1) )
                        (if ;;(or
                            (> 0 (skk-backward-and-set-henkan-point-1 char))
                            ;;(eq (skk-what-char-type) char))
                            (setq p (point)) ))))))
            (goto-char p)
            (skip-chars-forward unknown-chars-regexp) ))
        (skk-set-henkan-point-subr) ))))

(defun skk-backward-and-set-henkan-point-1 (char)
  ;; skk-backward-and-set-henkan-point $B$N%5%V%k!<%A%s!#(BCHAR $B$N<oN`$K1~$8$?J8;z(B
  ;; $B$r%9%-%C%W$7$F%P%C%U%!$N@hF,J}8~$XLa$k!#(B
  (cond ((eq char 'hirakana)
         ;; "$B$r(B" $B$NA0$G;_$^$C$?J}$,JXMx!)(B
         (skip-chars-backward "$B!3!4!5!6!7!<$s$!(B-$B$q(B") )
        ((eq char 'katakana)
         ;; "$B%r(B" $B$NA0$G;_$^$C$?J}$,JXMx!)(B
         (skip-chars-backward "$B!3!4!5!6!7!<%s%!(B-$B%q(B") )
        ((eq char 'zenkaku)
         (skip-chars-backward "$B!!(B-$B#z(B") )
        ((eq char 'ascii)
         (skip-chars-backward " -~") )))

(defun skk-what-char-type ()
  ;; $B8=:_$N%]%$%s%H$K$"$kJ8;z$,$I$s$J<oN`$+$rH=JL$9$k!#(B
  (save-match-data
    (cond ((looking-at "[$B$!(B-$B$s(B]") 'hirakana)
          ((looking-at "[$B%!(B-$B%s(B]") 'katakana)
          ;; "$B!<(B" $B$r=|30$7$F$$$k(B ("$B!<(B" $B$O(B "$B!;(B" $B$H(B "$B!=(B" $B$N4V$KF~$C$F$$$k(B)$B!#(B
          ((looking-at "[$B!!(B-$B!;!=(B-$B#z(B]") 'zenkaku)
          ((looking-at "[ -~]") 'ascii)
          (t 'unknown) )))

(defun skk-set-henkan-point-subr ()
  "$B$+$J$rF~NO$7$?8e$G!"%]%$%s%H$KJQ493+;O$N%^!<%/(B \($B"&(B\) $B$rIU$1$k!#(B
$B85!9$O$3$N4X?t$O(B skk-set-henkan-point $B$NFbIt4X?t$G$"$k!#(B"
  (interactive "*")
  (if skk-henkan-on (skk-kakutei))
  ;;(if (boundp 'disable-undo)
  ;;    (setq disable-undo t)
  (cancel-undo-boundary)
  ;;  )
  (if (string= skk-prefix "")
      (insert "$B"&(B")
    (skk-erase-prefix)
    (insert "$B"&(B")
    (skk-set-marker skk-kana-start-point (point))
    (skk-insert-prefix) )
  ;;(or (boundp 'disable-undo)
  (undo-boundary)
  ;;    )
  (setq skk-henkan-on t)
  (skk-set-marker skk-henkan-start-point (point)) )

(defun skk-change-marker ()
  ;; "$B"&(B"$B$r(B"$B"'(B"$B$KJQ$($k!#(Bskk-henkan-active $B%U%i%0$r(B t $B$K$9$k!#(B
  (combine-after-change-calls
    (skk-save-point
     (goto-char (- skk-henkan-start-point skk-kanji-len))
     (if (looking-at "$B"&(B")
         (progn
           (cancel-undo-boundary)
           (let ((buffer-undo-list t))
             (insert "$B"'(B")
             (delete-char 1)
             (setq skk-henkan-active t) )
           (undo-boundary)
           )
       (skk-kakutei)
       (skk-error "$B"&$,$"$j$^$;$s(B" "It seems that you have deleted $B"&(B") ))))

(defun skk-change-marker-to-white ()
  ;; "$B"'(B"$B$r(B"$B"&(B"$B$KJQ$($k!#(Bskk-henkan-active $B%U%i%0$r(B nil $B$K$9$k!#(B
  (combine-after-change-calls
    (skk-save-point
     (goto-char (- skk-henkan-start-point skk-kanji-len))
     (cancel-undo-boundary)
     (if (looking-at "$B"'(B")
         (let ((buffer-undo-list t))
           (insert "$B"&(B")
           (delete-char 1) )
       (goto-char skk-henkan-start-point)
       (insert "$B"&(B")
       ;;(or (boundp 'disable-undo)
       ;;(undo-boundary)
       ;;    )
       (skk-set-marker skk-henkan-start-point (point))
       (skk-message "$B"'$,$"$j$^$;$s(B" "It seems that you have deleted $B"'(B") )
     (setq skk-henkan-active nil) )))

(defun skk-delete-henkan-markers (&optional nomesg)
  ;; $BJQ49;~$K%+%l%s%H%P%C%U%!$KI=$o$l$k(B `$B"&(B', `$B"'(B' $B%^!<%/$r>C$9!#(B
  (if (not (marker-position skk-henkan-start-point))
      nil
    (combine-after-change-calls
      (save-match-data
        (skk-save-point
         (goto-char (- skk-henkan-start-point skk-kanji-len))
         (if skk-henkan-active
             (progn
               (if skk-use-face (skk-henkan-face-off))
               (if (looking-at "$B"'(B")
                   (delete-char 1)
                 (or nomesg
                     (skk-message "$B"'$,$"$j$^$;$s(B"
                                  "It seems that you have deleted $B"'(B" ))))
           (if (looking-at "$B"&(B")
               (delete-char 1)
             (or nomesg
                 (skk-message "$B"&$,$"$j$^$;$s(B"
                              "It seems that you have deleted $B"&(B" )))))))))

(defun skk-delete-okuri-mark ()
  ;; $BAw$j2>L>F~NOCf$K%+%l%s%H%P%C%U%!$KI=$o$l$k(B `*' $B%^!<%/$r>C$7!"Aw$j2>L>4XO"(B
  ;; $B%U%i%0$r(B nil $B$K%;%C%H$9$k!#(B
  (if (not (marker-position skk-okurigana-start-point))
      nil
    (skk-save-point
      (if (eq (char-after skk-okurigana-start-point) ?*) ; ?*
          (delete-region skk-okurigana-start-point
                         (1+ skk-okurigana-start-point) ))
      (setq skk-okurigana nil
            skk-okuri-char nil
            skk-henkan-okurigana nil ))))
            
;;;; jisyo related functions
(defun skk-purge-from-jisyo ()
  "$B"'%b!<%I$G8=:_$N8uJd$r<-=q%P%C%U%!$+$i>C5n$9$k!#(B"
  (interactive "*")
  (if (and skk-henkan-active (not (string= skk-henkan-key "")))
      (if (not
           (yes-or-no-p (format
                         (if skk-japanese-message-and-error
                             "%s /%s/%s$B$r<-=q$+$i:o=|$7$^$9!#NI$$$G$9$+!)(B"
                           "Really purge \"%s /%s/%s\"?" )
                         skk-henkan-key (skk-get-simply-current-candidate)
                         (if (and skk-henkan-okurigana
                                  (or skk-henkan-okuri-strictly
				      skk-henkan-strict-okuri-precedence ))
                             (concat
                              (if skk-japanese-message-and-error
                                  " ($BAw$j2>L>(B: "
                                "(okurigana: " )
                              skk-henkan-okurigana
                              ") " )
                           " " ))))
          nil
        ;; skk-henkan-start-point $B$+$i(B point $B$^$G:o=|$7$F$7$^$C$F$b!"JQ49D>8e(B
        ;; $B$K(B ($B%+!<%=%k$rF0$+$9$3$H$J$/(B) skk-purge-from-jisyo $B$r8F$Y$PLdBj$J$$(B
        ;; $B$,!"%+!<%=%k$,0c$&>l=j$X0\F0$7$F$$$?>l9g$O!":o=|$9$Y$-$G$J$$$b$N$^(B
        ;; $B$G:o=|$7$F$7$^$&2DG=@-$,$"$k!#$=$3$G!"Aw$j2>L>$,$"$l$P$=$ND9$5$r4^(B
        ;; $B$a$?(B end $B$r5a$a!":#2s$NJQ49$K4XO"$7$?8D=j$@$1$r@53N$K@Z$j<h$k$h$&$K(B
        ;; $B$9$k!#(B
        (let ((end (if skk-henkan-okurigana
                       (+ (length skk-henkan-okurigana)
                          skk-henkan-end-point )
                     skk-henkan-end-point ))
              (word (skk-get-simply-current-candidate (skk-numeric-p))) )
          ;;(if skk-use-numeric-conversion
          ;;    (skk-update-jisyo-for-numerals purge-word 'purge) )
          (skk-update-jisyo word 'purge)
          ;; $BG0$N$?$a!#(Bskk-previous-candidate $B$r;2>H!#(B 
          (if skk-use-face (skk-henkan-face-off))
          (delete-region skk-henkan-start-point end)
          (skk-change-marker-to-white)
          (skk-kakutei)
	  (if skk-use-relation
	      (skk-update-relation
               (if skk-use-numeric-conversion
                   (skk-compute-numeric-henkan-key skk-henkan-key)
		 skk-henkan-key )
               (or skk-henkan-okurigana skk-okuri-char)
	       word nil 'purge))
          ;;(if (boundp 'skk-attr-alist)
          ;;    (skk-attr-purge
          ;;     (if skk-use-numeric-conversion
          ;;         (skk-compute-numeric-henkan-key skk-henkan-key)
          ;;       skk-henkan-key )
          ;;     (or skk-henkan-okurigana skk-okuri-char)
          ;;     word ))
	  ))))

;;;###skk-autoload
(defun skk-save-jisyo (&optional quiet)
  "SKK $B$N<-=q%P%C%U%!$r%;!<%V$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B QUIET $B$,(B non-nil $B$G$"$l$P!"<-=q%;!<%V;~$N%a%C%;!<%8$r=P$5$J(B
$B$$!#(B"
  (interactive "P")
  (let* ((skk-jisyo (expand-file-name skk-jisyo))
         (jisyo-buffer (skk-get-jisyo-buffer skk-jisyo 'nomsg)) )
    (if (or (not jisyo-buffer) (not (buffer-modified-p jisyo-buffer)))
        (if (not quiet) 
            (progn
              (skk-message "SKK $B<-=q$rJ]B8$9$kI,MW$O$"$j$^$;$s(B"
                           "No need to save SKK jisyo" )
              (sit-for 1) ))
      (with-current-buffer jisyo-buffer
        (let ((inhibit-quit t)
              (tempo-file (skk-make-temp-jisyo)) )
          (if (not quiet)
              (skk-message "SKK $B<-=q$rJ]B8$7$F$$$^$9(B..."
                           "Saving SKK jisyo..." ))
          (skk-save-jisyo-1 tempo-file)
          (skk-check-jisyo-size tempo-file)
          ;; $B<-=q$N%;!<%V$K@.8y$7$F=i$a$F(B modified $B%U%i%C%0$r(B nil $B$K$9$k!#(B
          (set-buffer-modified-p nil)
          (if (not quiet)
              (progn
                (skk-message "SKK $B<-=q$rJ]B8$7$F$$$^$9(B...$B40N;!*(B"
                             "Saving SKK jisyo...done" )
                (sit-for 1) ))
          (if (eq this-command 'save-buffers-kill-emacs)
              (skk-record-jisyo-data jisyo-buffer) )))
      (skk-set-cursor-properly) )))

(defun skk-save-jisyo-1 (file)
  (save-match-data
    (let (mc-flag enable-multibyte-characters buffer-read-only)
      (goto-char (point-min))
      (if (re-search-forward "^;; okuri-ari entries.$" nil 'noerror)
          nil
        (skk-error
         "$BAw$j$"$j%(%s%H%j$N%X%C%@!<$,$"$j$^$;$s!*(B SKK $B<-=q$N%;!<%V$rCf;_$7$^$9(B"
         "Header line for okuri-ari entries is missing!  Stop saving SKK jisyo" ))
      ;; $B$*$C!"%3%a%s%H%U%'%$%9$,(B $" $B$G=*$o$i$J$$$>(B > hilit19.el
      (if (re-search-forward "^;; okuri-nasi entries.$" nil 'noerror)
          nil
        (skk-error
         "$BAw$j$J$7%(%s%H%j$N%X%C%@!<$,$"$j$^$;$s(B $B!*(B SKK $B<-=q$N%;!<%V$rCf;_$7$^$9(B"
         "Header line for okuri-nasi entries is missing!  Stop saving SKK jisyo" )))
    (write-region 1 (point-max) file nil 'nomsg) ))

(defun skk-check-jisyo-size (new-file)
  (let ((new-size (nth 7 (file-attributes new-file)))
        old-size )
    (if (eq new-size 0)
        (progn
          (delete-file new-file)
          (skk-error "SKK $B<-=q$,6u$K$J$C$F$$$^$9!*(B $B<-=q$N%;!<%V$rCf;_$7$^$9(B"
                     "Null SKK jisyo!  Stop saving jisyo" )))
    (if (or (not skk-compare-jisyo-size-when-saving)
            ;; $B5l<-=q$H$N%5%$%:Hf3S$r9T$J$o$J$$!#(B
            (progn
              ;; (1)skk-jisyo $B$,$J$$$+!"(B
              ;; (2)new-file $B$H(B skk-jisyo $B$,F10l$N%5%$%:$+(B
              ;;    (skk-(aux-)large-jisyo $B$+$i?75,$NC18l$rFI$_9~$^$J$+$C$?$j!"(B
              ;;    $B?75,C18l$NEPO?$r9T$J$o$J$+$C$?>l9g$O%5%$%:$,F1$8(B)$B!"(B
              ;; (3)new-file $B$NJ}$,Bg$-$$(B
              ;; $B>l9g(B ($B>e5-$N(B 3 $BDL$j$G$"$l$P$$$:$l$b@5>o(B)$B!#(B
              (setq old-size (nth 7 (file-attributes skk-jisyo)))
              (or (not old-size)
                  (>= new-size old-size) )))
        (skk-make-new-jisyo new-file)
      ;; yes-or-no-p $B$K2sEz$7!"(Bnewline $B$9$k$H!"(Bthis-command $B$,JQ$C$F$7$^$&!#(B
      (let (this-command this-command-char last-command last-command-char)
        (if (skk-yes-or-no-p
             (format
              "skk-jisyo $B$,(B %dbytes $B>.$5$/$J$j$^$9$,!"%;!<%V$7$FNI$$$G$9$+!)(B"
              (- old-size new-size) )
             (format
              "New %s will be %dbytes smaller.  Save anyway?"
              skk-jisyo (- old-size new-size) ))
            ;; $B$H$K$+$/%;!<%V!#(B
            (skk-make-new-jisyo new-file)
          ;; $B%;!<%V$H$j;_$a!#(B
          (delete-file new-file)
          (with-output-to-temp-buffer "*SKK warning*"
            (if skk-japanese-message-and-error
                (progn
                  (princ "$B%;!<%V$7$h$&$H$9$k<-=q$N%5%$%:$,85$N$b$N$h$j$b>.$5$J$C$F$7$^$&$N$G!"(B")
                  (terpri)
                  (princ "$B%;!<%V$rESCf$GCf;_$7$^$7$?!#<-=q$N%5%$%:$,>.$5$/$J$C$?860x$K$ONc$((B")
                  (terpri)
                  (princ "$B$P!"(B")
                  (terpri)
                  (terpri)
                  (princ "    $B!&(BM-x skk-purge-from-jisyo $B$r<B9T$7$?!#(B")
                  (terpri)
                  (terpri)
                  (princ "    $B!&(B.skk-jisyo $B$N4A;z%3!<%I$H!"(B\" *.skk-jisyo*\" $B%P%C%U%!$N4A;z%3!<%I(B")
                  (terpri)
                  (princ "      $B$,0[$J$C$F$$$k!#(B")
                  (terpri)
                  (terpri)
                  (princ "    $B!&(B\" *.skk-jisyo*\" $B%P%C%U%!$r<+J,$GJT=8$7$?!#(B")
                  (terpri)
                  (terpri)
                  (princ "$B$J$I$,9M$($i$l$^$9(B ($B:G=i$N(B 2 $B$D$,860x$G$"$l$P!"0[>o$G$O$"$j$^$;$s!#(B")
                  (terpri)
                  (princ "$B:G8e$N>l9g$O!"$"$J$?$,$I$N$h$&$JJT=8$r$7$?$+$K$h$j$^$9(B)$B!#860x$r3NG'(B")
                  (terpri)
                  (princ "$B8e!"?5=E$K<-=q$N%;!<%V$r9T$J$&$3$H$r$*4+$a$7$^$9!#(B")
                  (terpri)
                  (terpri)
                  (princ "$B85$N<-=q$r:FEYFI$_9~$`$K$O!"(B")
                  (terpri)
                  (terpri)
                  (princ "    M-x skk-reread-private-jisyo")
                  (terpri)
                  (terpri)
                  (princ "$B$r<B9T$7$F2<$5$$!#(B") )
              (princ "As size of your private JISYO to be saved is smaller than the")
              (terpri)
              (princ "original, we have stopped saving JISYO.  For example, the following")
              (terpri)
              (princ "condition makes a smaller private JISYO;")
              (terpri)
              (terpri)
              (princ "    (a)You executed M-x skk-purge-from-jisyo,")
              (terpri)
              (terpri)
              (princ "    (b)Kanji code of .skk-jisyo is different from the one of")
              (terpri)
              (princ "       \" *.skk-jisyo*\" buffer, or")
              (terpri)
              (terpri)
              (princ "    (c)You edited \" *.skk-jisyo*\" buffer manually.")
              (terpri)
              (terpri)
              (princ "The first two condition is not strange, but the last one depends on")
              (terpri)
              (princ "how you edited JISYO.  We strongly recommend to save JISYO")
              (terpri)
              (princ "carefully after checking what causes this.")
              (terpri)
              (princ "If you want to reread your original private JISYO, type")
              (terpri)
              (terpri)
              (princ "    M-x skk-reread-private-jisyo")
              (terpri) ))
          (skk-error "SKK $B<-=q$N%;!<%V$rCf;_$7$^$7$?!*(B"
                     "Stop saving SKK jisyo!" ))))))

(defun skk-make-temp-jisyo ()
  ;; SKK $B8D?M<-=qJ]B8$N$?$a$N:n6HMQ$N%U%!%$%k$r:n$j!"%U%!%$%k$N%b!<%I$r(B
  ;; skk-jisyo $B$N$b$N$HF1$8$K@_Dj$9$k!#:n$C$?:n6HMQ%U%!%$%k$NL>A0$rJV$9!#(B
  (let ((tempo-name (skk-make-temp-file "skkdic")))
    (skk-create-file tempo-name)
    (set-file-modes tempo-name  (file-modes skk-jisyo))
    tempo-name ))

(defun skk-make-temp-file (prefix)
  ;; from call-process-region of mule.el.  Welcome!
  (make-temp-name
   (if (null (memq system-type '(ms-dos windows-nt)))
       (concat "/tmp/" prefix)
     (let ((tem (or (getenv "TMP") (getenv "TEMP") "/")))
       (concat tem
               (if (memq (aref tem (1- (length tem))) '(47 92)) ;?/, ?\\
                   "" "/" )
               prefix )))))

(defun skk-make-new-jisyo (tempo-file)
  ;; TEMPO-FILE $B$r?75,$N(B skk-jisyo $B$K$9$k!#(Bskk-backup-jisyo $B$,(B non-nil $B$@$C$?(B
  ;; $B$i%P%C%/%"%C%W<-=q$r:n$k!#(B
  (if skk-backup-jisyo
      (progn
        (if (file-exists-p skk-backup-jisyo)
            (delete-file skk-backup-jisyo) )
        (rename-file skk-jisyo skk-backup-jisyo) )
    (delete-file skk-jisyo) )
  (rename-file tempo-file skk-jisyo 'ok-if-already-exists) )

(defun skk-reread-private-jisyo ()
  "$B%P%C%U%!$KFI$_9~$s$@8D?M<-=q$rGK4~$7!"%U%!%$%k$+$i%P%C%U%!$X:FFI$_9~$_$9$k!#(B"
  (interactive)
  (let ((buf (skk-get-jisyo-buffer skk-jisyo 'nomsg)))
    (if (and buf
             (skk-yes-or-no-p "$BJT=8Cf$N8D?M<-=q$rGK4~$7$^$9$+!)(B"
                              "Discard your editing private JISYO?" ))
        (progn
          (save-excursion
            (set-buffer buf)
            (set-buffer-modified-p nil)
            (kill-buffer buf) )
          (or
           (skk-get-jisyo-buffer skk-jisyo 'nomsg)
           (skk-error "$B8D?M<-=q$r:FFI$_9~$_$9$k$3$H$,$G$-$^$;$s!*(B"
                      "Cannot reread private JISYO!" ))))))

(defun skk-record-jisyo-data (jisyo-buffer)
  ;; $B<-=q%G!<%?!<$r<h$j!"(BEmacs $B$N=*N;$N:]$G$"$l$P!"$=$N%G!<%?!<$r(B 
  ;; skk-record-file $B$KJ]B8$7!"$=$l0J30$G$"$l$P!"$=$l$r%(%3!<$9$k!#(B
  (if (or (not skk-keep-record) (> 1 skk-kakutei-count))
      nil
    (with-temp-file skk-record-file
      (insert-file-contents skk-record-file)
      (goto-char (point-min))
      (insert
       (format
        "%s  $BEPO?(B: %3d  $B3NDj(B: %4d  $B3NDjN((B: %3d%%  $B8l?t(B:%6d\n"
        (current-time-string)
        skk-touroku-count skk-kakutei-count
        (/ (* 100 (- skk-kakutei-count skk-touroku-count))
           skk-kakutei-count )
        (if skk-count-private-jisyo-candidates-exactly
            (skk-count-jisyo-candidates (expand-file-name skk-jisyo))
          ;; 1 $B9T(B 1 $B8uJd$H$_$J$9!#(B
          (with-current-buffer jisyo-buffer
            (- (count-lines (point-min) (point-max)) 2) )))))
    (setq skk-touroku-count 0 skk-kakutei-count 0) ))

(defun skk-count-jisyo-candidates (file)
  "SKK $B<-=q$N8uJd?t$r?t$($k!#(B
`[' $B$H(B `]' $B$K0O$^$l$?Aw$j2>L>Kh$N%V%m%C%/Fb$O?t$($J$$!#(B"
  (interactive
   (list (read-file-name
          (format "Jisyo File: (default: %s) " skk-jisyo)
          "~/" skk-jisyo 'confirm )))
  ;; mule@emacs19.31 $B$@$H2<5-$N$h$&$K$9$k$H(B (`$B%!(B' $B$,860x$N$h$&(B) $B2?8N$+(B 
  ;; default-directory $B$NKvHx$K2~9T$,IU$/!#(B
  ;; $BDL>o$O5$$,IU$+$J$$$,!"(Brsz-mini.el $B$r;H$C$F(B resize-minibuffer-mode $B$r(B 
  ;; non-nil $B$K$7$F$$$k$HITMW$J(B 2 $B9TL\$,=P8=$9$k!#(B
  ;; (interactive "f$B<-=q%U%!%$%k(B: ")
  (with-current-buffer (find-file-noselect file)
    (save-match-data
      (let ((count 0)
            (min (point-min))
            (max (if (interactive-p) (point-max)))
            (interactive-p (interactive-p))
            mc-flag enable-multibyte-characters )
        (goto-char min)
        (if (or
             ;; $B$3$A$i$O(B skk-save-point $B$r;H$o$:!"%]%$%s%H$r0\F0$5$;$k!#(B
             (not (re-search-forward "^;; okuri-ari entries.$" nil t nil))
             (not
              (skk-save-point
                (re-search-forward "^;; okuri-nasi entries.$" nil t nil) )))
            (skk-error "$B$3$N%U%!%$%k$O(B SKK $B<-=q$G$O$"$j$^$;$s(B"
                       "This file is not a SKK dictionary") )
        (while (search-forward "/" nil t)
          (cond ((looking-at "\\[")
                 (forward-line 1)
                 (beginning-of-line) )
                ((not (eolp))
                 (setq count (1+ count)) ))
          (if interactive-p
              (message "Counting jisyo candidates...%3d%% done"
                       (/ (* 100 (- (point) min)) max) )))
        (if (interactive-p)
            (message "%d entries" count)
          count )))))

(defun skk-create-file (file &optional message)
  ;; FILE $B$,$J$1$l$P!"(BFILE $B$H$$$&L>A0$N6u%U%!%$%k$r:n$k!#(B
  ;; $B%*%W%7%g%J%k0z?t$N(B MESSAGE $B$r;XDj$9$k$H!"%U%!%$%k:n@.8e$=$N%a%C%;!<%8$r(B
  ;; $B%_%K%P%C%U%!$KI=<($9$k!#(B
  (let ((file (expand-file-name file)))
    (or (file-exists-p file)
        (progn
          (write-region 1 1 file nil 0)
          (if message
              (progn
                (message message)
                (sit-for 3) ))))))

(defun skk-get-jisyo-buffer (file &optional nomsg)
  ;; FILE $B$r3+$$$F(B SKK $B<-=q%P%C%U%!$r:n$j!"%P%C%U%!$rJV$9!#(B
  ;; $B%*%W%7%g%J%k0z?t$N(B NOMSG $B$r;XDj$9$k$H%U%!%$%kFI$_9~$_$N:]$N%a%C%;!<%8$r(B
  ;; $BI=<($7$J$$!#(B
  (if file
      (let ((inhibit-quit t)
            ;; expand-file-name $B$r8F$s$G$*$+$J$$$H!";H$C$F$$$k(B OS $B>e$"$j$($J$$(B
            ;; $B%U%!%$%k%M!<%`$G$b!"$=$N$^$^EO$5$l$F$7$^$&!#(B
            ;; ($BNc(B) MSDOS $B$N>l9g(B ~/_skk-jisyo $B$N<B:]$N%U%!%$%k%M!<%`$O!"(BOS $B>e(B
            ;; $B$N@)8B$+$i(B ~/_skk-jis $B$H$J$k!#(Bexpand-file-name $B$r8F$P$J$$$H!"(B
            ;; " *_skk-jisyo*" $B$H$$$&%P%C%U%!$,$G$-$F$7$^$$!"(Bskk-save-jisyo $B$J(B
            ;; $B$IB>$N4X?t$K1F6A$,=P$k!#(B
            (file (expand-file-name file))
            (jisyo-buf (concat " *" (file-name-nondirectory file)
                               "*" )))
        ;; $B<-=q%P%C%U%!$H$7$F%*!<%W%s$5$l$F$$$k$J$i!"2?$b$7$J$$!#(B
        (or (get-buffer jisyo-buf)
            (with-current-buffer (setq jisyo-buf (get-buffer-create jisyo-buf))
              (buffer-disable-undo jisyo-buf)
              (auto-save-mode -1)
              ;; $B%o!<%-%s%0%P%C%U%!$N%b!<%I%i%$%s$O%"%C%W%G!<%H$5$l$J$$!)(B
              ;;(make-local-variable 'line-number-mode)
              ;;(make-local-variable 'column-number-mode)
              (setq buffer-read-only nil
                    case-fold-search nil
                    ;; buffer-file-name $B$r(B nil $B$K$9$k$H!"<-=q%P%C%U%!$KF~$j9~(B
                    ;; $B$s$G(B C-x C-s $B$7$?$H$-$K%U%!%$%k%M!<%`$r?R$M$F$/$k$h$&$K(B
                    ;; $B$J$k$,!"(BM-x compile $B$J$IFbIt$G(B save-some-buffers $B$r%3!<(B
                    ;; $B%k$7$F$$$k%3%^%s%I$r;H$C$?$H$-$G$b%;!<%V$9$k$+$I$&$+$r(B
                    ;; $B?R$M$F$3$J$/$J$k!#(B
                    ;;buffer-file-name file
                    ;;cache-long-line-scans nil
                    ;;column-number-mode nil
                    ;;line-number-mode nil
                    ;; dabbrev $B$N%5!<%A$H$J$k%P%C%U%!$K$J$i$J$$$h$&$KB8:_$7$J(B
                    ;; $B$$%b!<%IL>$K$7$F$*$/!#<B32$N$"$kI{:nMQ$O$J$$$O$:!#(B
                    major-mode 'skk-jisyo-mode
                    mode-name "SKK$B<-=q(B" )
              (or nomsg
                  (skk-message "SKK $B<-=q(B %s $B$r%P%C%U%!$KFI$_9~$s$G$$$^$9(B..."
                               "Inserting contents of %s ..."
                               (file-name-nondirectory file) ))
	      (let ((coding-system-for-read 'euc-japan); XXX
		    enable-character-unification)
                 (insert-file-contents file) )
              (skk-set-jisyo-code)
              (or nomsg
                  (skk-message
                   "SKK $B<-=q(B %s $B$r%P%C%U%!$KFI$_9~$s$G$$$^$9(B...$B40N;!*(B"
                   "Inserting contents of %s ...done"
                   (file-name-nondirectory file) ))
              (skk-setup-jisyo-buffer)
              (set-buffer-modified-p nil)
              jisyo-buf )))))

(defun skk-set-jisyo-code ()
  ;; $BJ8;z%3!<%I$r(B CODE $B$K%;%C%H$9$k!#(B
  (if (not skk-jisyo-code)
      nil
    (if (stringp skk-jisyo-code)
        (setq skk-jisyo-code (cdr
                              (assoc skk-jisyo-code skk-coding-system-alist) )))
    (if (fboundp 'set-buffer-file-coding-system)
        (set-buffer-file-coding-system skk-jisyo-code)
      (set-file-coding-system skk-jisyo-code) )))

(defun skk-setup-jisyo-buffer ()
  ;; skk-jisyo $B$N<-=q%P%C%U%!$G!"(B
  ;; (1)$B6u%P%C%U%!$G$"$l$P!"?7$7$/%X%C%@!<$r:n$j!"(B
  ;; (2)$B<-=q%(%s%H%j$,$"$k4{B8$N<-=q%P%C%U%!$J$i$P!"%X%C%@!<$,@5$7$$$+$I$&$+$r(B
  ;;    $B%A%'%C%/$9$k!#(B
  ;;
  ;; skk-okuri-ari-min $B$H(B skk-okuri-nasi-min $B$N0LCV$rJQ99$7$?!#(B
  ;;                       $B"-(B $B?7$7$$(B skk-okuri-ari-min
  ;;   ;; okuri-ari entries.
  ;;   $B"+(B $B0JA0$N(B skk-okuri-ari-min
  ;;
  ;;   $B"-(B skk-okuri-ari-max $B"-(B $B?7$7$$(B skk-okuri-nasi-min
  ;;   ;; okuri-nasi entries.
  ;;   $B"+(B $B0JA0$N(B skk-okuri-nasi-min
  ;;
  ;;
  ;; $BJQ99A0$N0LCV$G$"$l$P!"2<5-$N$h$&$J6u<-=q$N>l9g!"(B
  ;;
  ;;   ;; okuri-ari entries.
  ;;   ;; okuri-nasi entries.
  ;;
  ;; skk-okuri-ari-min $B$H(B skk-okuri-ari-max $B$N%^!<%+!<$,=E$J$C$F$7$^$$!"(B
  ;; skk-okuri-ari-min $B$N0LCV$KA^F~$7$?%(%s%H%j$,(B skk-okuri-ari-max $B$N%^!<%+!<(B
  ;; $B$r8eJ}$K2!$7$d$i$J$$!#(B
  ;;
  ;; $B$3$N4X?t$N%*%j%8%J%k$NL>>N$O!"(Bj-check-jisyo $B$@$C$?$,!"(Bskk-check-jisyo $B$H(B
  ;; $B$$$&L>A0$K$9$k$H(B skk-tools.el $BFb$N4X?tL>$H=EJ#$9$k!#(B
  ;; case-fold-search $B$O!"<-=q%P%C%U%!$G$O>o$K(B nil$B!#(B
  (let (mc-flag enable-multibyte-characters)
    (save-match-data
      (if (eq (buffer-size) 0)
          ;; $B6u%P%C%U%!$@$C$?$i!"%X%C%@!<$N$_A^F~!#(B
          (insert ";; okuri-ari entries.\n" ";; okuri-nasi entries.\n") )
      (goto-char (point-min))
      (if (re-search-forward "^;; okuri-ari entries.$" nil 'noerror)
          ;; $B8GDj%]%$%s%H$J$N$G!"(B(point) $B$G==J,!#(B
          (setq skk-okuri-ari-min (point))
        (skk-error "$BAw$j$"$j%(%s%H%j$N%X%C%@!<$,$"$j$^$;$s!*(B"
                   "Header line for okuri-ari entries is missing!" ))
      (if (re-search-forward "^;; okuri-nasi entries.$" nil 'noerror)
          (progn
            (beginning-of-line)
            ;; $B6&M-<-=q$J$i8GDj%]%$%s%H$G$bNI$$$N$@$,!"<-=q%P%C%U%!$GJT=8$r9T(B
            ;; $B$J$C$?$H$-$N$3$H$rG[N8$7$F%^!<%+!<$K$7$F$*$/!#(B
            (setq skk-okuri-ari-max (point-marker))
            (forward-line 1)
            (backward-char 1)
            (setq skk-okuri-nasi-min (point-marker)) )
        (skk-error "$BAw$j$J$7%(%s%H%j$N%X%C%@!<$,$"$j$^$;$s!*(B"
                   "Header line for okuri-nasi entries is missing!" )))))

;;;###skk-autoload
(defun skk-search ()
  ;; skk-current-search-prog-list $B$NMWAG$K$J$C$F$$$k%W%m%0%i%`$rI>2A$7$F!"(B
  ;; skk-henkan-key$B$r%-!<$K$7$F8!:w$r9T$&!#(B
  (let (l)
    (while (and (null l) skk-current-search-prog-list)
      (setq l (eval (car skk-current-search-prog-list))
            skk-current-search-prog-list (cdr skk-current-search-prog-list) ))
    l ))

(defun skk-search-relation ()
  (let ((last 
	 (if (not (and
		   skk-last-henkan-result
		   (markerp skk-last-henkan-point)
		   (< skk-last-henkan-point (point))
		   (< (- (point) skk-last-henkan-point) skk-relation-length) ))
	     nil
	   skk-last-henkan-result )))
    (skk-attr-search-relation
     skk-henkan-key
     (or skk-henkan-okurigana skk-okuri-char)
     last )))

(defun skk-attr-search-relation (midasi okuri last)
  (if skk-debug (message "%S" midasi okuri last))
  (or skk-attr-alist (skk-attr-read))
  (let ((entries (cdr (skk-attr-get-table-for-midasi midasi okuri)))
	ret rest )
    (if skk-debug (message "%S" entries))
    (while entries
      (let* ((entry (car entries))
	     (rel (assq 'relation (cdr entry))))
	(if (or (null last) (member last (cdr rel)))
	    (setq ret (nconc ret (list (car entry))))
	  (setq rest (nconc rest (list (car entry)))) ) )
      (setq entries (cdr entries)) )
    (nconc ret rest) ))
	     
(defun skk-update-relation (midasi okuri word last &optional purge)
  (skk-attr-update-relation midasi okuri word last purge) )

(defun skk-attr-update-relation (midasi okuri word last &optional purge)
  (or skk-attr-alist (skk-attr-read))
  (if skk-debug (message "update %S %S %S %S" midasi okuri word last))
  (if purge
      (skk-attr-purge midasi okuri word)
    (let* ((table (skk-attr-get-table-for-midasi midasi okuri))
	   (entry (assoc word (cdr table)))
	   (oldattr (assq 'relation (cdr entry)))
	   (listlast (if last (list last) nil)) )
      (cond (oldattr
	     (if  last
		 (progn
		   (setcdr oldattr (cons last
					 (delete last (cdr oldattr)) ))
		   (let ((tail (nthcdr skk-relation-record-num oldattr)))
		     (if tail
			 (setcdr tail nil) )))))
	    (entry
	     (setcdr entry (cons (cons 'relation listlast)
				 (cdr entry))))
	    (table
	     (setcdr table (cons (list word
				       (list 'okurigana okuri)
				       (cons 'relation listlast) )
				 (cdr table) )))
	    ;; new entry
	    (t (skk-attr-put-1 midasi okuri word 'relation listlast)) ))))

(defun skk-search-jisyo-file (file limit &optional nomsg)
  ;; SKK $B<-=q%U%)!<%^%C%H$N(B FILE $B$G(B skk-henkan-key $B$r%-!<$K$7$F8!:w$r9T$&!#(B
  ;; $B8!:w%j!<%8%g%s$,(B LIMIT $B0J2<$K$J$k$^$G%P%$%J%j%5!<%A$r9T$$!"$=$N8e%j%K%"(B
  ;; $B%5!<%A$r9T$&!#(B
  ;; LIMIT $B$,(B 0 $B$G$"$l$P!"%j%K%"%5!<%A$N$_$r9T$&!#(B
  ;; $B<-=q$,%=!<%H$5$l$F$$$J$$$N$G$"$l$P!"(BLIMIT $B$r(B 0 $B$9$kI,MW$,$"$k!#(B
  ;; $B%*%W%7%g%J%k0z?t$N(B NOMSG $B$,(B non-nil $B$G$"$l$P(B skk-get-jisyo-buffer $B$N%a%C(B
  ;; $B%;!<%8$r=PNO$7$J$$$h$&$K$9$k!#(B
  (let ((jisyo-buffer (skk-get-jisyo-buffer file nomsg)))
    (if jisyo-buffer
        ;; skk-henkan-key $B$H(B skk-henkan-okurigana $B$O%+%l%s%H%P%C%U%!$N%m!<%+%k(B
        ;; $BCM!#(B
        (let ((okurigana (or skk-henkan-okurigana skk-okuri-char))
              (midasi 
               (if skk-use-numeric-conversion
		   ;; skk-henkan-key $B$,(B nil $B$N$3$H$,$"$k!#2?8N(B?
                   (skk-compute-numeric-henkan-key skk-henkan-key)
                 skk-henkan-key ))
              entry-list entry )
          (with-current-buffer jisyo-buffer
            (setq skk-henkan-key midasi
                  entry-list (skk-search-jisyo-file-1 okurigana limit) )
            (if entry-list
                (progn
                  (setq entry
                        (cond ((and okurigana skk-henkan-okuri-strictly)
                               ;; $BAw$j2>L>$,F10l$N%(%s%H%j$N$_$rJV$9!#(B
                               (nth 2 entry-list) )
                              ((and okurigana skk-henkan-strict-okuri-precedence)
                               ;; $BAw$j2>L>$,F10l$N%(%s%H%j$N$&$7$m$K!"(B
                               ;; $B$=$NB>$N%(%s%H%j$r$D$1$F$+$($9!#(B
                               (skk-nunion (nth 2 entry-list) (car entry-list)))
                              (t (car entry-list)) ))
                  (if (and (boundp 'skk-attr-search-function)
                           skk-attr-search-function )
                      (funcall skk-attr-search-function midasi okurigana entry)
                    entry ))))))))

(defun skk-search-jisyo-file-1 (okurigana limit &optional delete)
  ;; skk-search-jisyo-file $B$N%5%V%k!<%A%s!#(Bskk-compute-henkan-lists $B$r;HMQ$7!"(B
  ;; $B8+=P$78l$K$D$$$F$N%(%s%H%j$N>pJs$rJV$9!#(B
  ;; DELETE $B$,(B non-nil $B$G$"$l$P!"(BMIDASI $B$K%^%C%A$9$k%(%s%H%j$r:o=|$9$k!#(B
  (let ((key (concat "\n" skk-henkan-key " /"))
        min max size p )
    (save-match-data
      ;; skk-okuri-ari-min $B$H(B skk-okuri-ari-max $B$O<-=q%P%C%U%!$N%m!<%+%kCM!#(B
      (if okurigana
          (setq min skk-okuri-ari-min
                max skk-okuri-ari-max )
        (setq min skk-okuri-nasi-min
              max (point-max) ))
      (if (> limit 0)
          (while (progn (setq size (- max min)) (> size limit))
            (goto-char (+ min (/ size 2)))
            (beginning-of-line)
            (setq p (point))
            ;; $BAw$j$"$j$J$i5U=g$KHf3S$r9T$J$&!#(B
            (if
                (if okurigana
                    (string< (skk-buffer-substring p (1- (search-forward  " ")))
                             skk-henkan-key )
                  (string< skk-henkan-key
                           (skk-buffer-substring p (1- (search-forward " "))) ))
                (setq max p)
              (setq min p) )))
      (goto-char min)
      ;; key $B$,8!:w3+;OCOE@$K$"$C$?>l9g$G$b8!:w2DG=$J$h$&$K0lJ8;zLa$k!#(Bkey $B$,(B
      ;; $B$=$N@hF,ItJ,$K(B "\n" $B$r4^$s$G$$$k$3$H$KCm0U!#(B
      (or (bobp) (backward-char 1))
      ;; $B8zN($,NI$$$h$&$K(B kanji-flag, mc-flag, enable-multibyte-characters $B$r(B
      ;; nil $B$K$7$F$*$/!#(B
      ;; case-fold-search $B$O!"<-=q%P%C%U%!$G$O>o$K(B nil$B!#(B
      (let (mc-flag)
            ;; enable-multibyte-characters)
        (if (search-forward key max 'noerror)
            (prog1
                (skk-compute-henkan-lists okurigana)
              (if delete
                  (progn
                    (beginning-of-line)
                    (delete-region (point)
                                   (progn (forward-line 1) (point)) )))))))))


(defun skk-compute-henkan-lists (okurigana)
  ;; $B<-=q%(%s%H%j$r(B 4 $B$D$N%j%9%H$KJ,2r$9$k!#(B
  ;;
  ;; $BAw$j$J$7(B ($BNc$($P!"<-=q%(%s%H%j(B "$B$F$s$5$$(B /$BE>:\(B/$BE7:R(B/$BE7:M(B/" $B$N=hM}(B)
  ;; entry1 := ("$BE>:\(B" "$BE7:R(B" "$BE7:M(B") == $BA4%(%s%H%j(B
  ;; entry2 := nil
  ;; entry3 := nil
  ;; entry4 := nil
  ;;
  ;; $BAw$j$"$j(B ($BNc$($P!"!V5c$/!W$NJQ49$r9T$C$?>l9g$N!"<-=q%(%s%H%j(B
  ;;           "$B$J(Bk /$BK4(B/$BL5(B/$BLD(B/$B5c(B/[$B$/(B/$BL5(B/$BLD(B/$B5c(B/]/[$B$-(B/$BK4(B/]/" $B$N=hM}(B)
  ;; entry1 := ("$BK4(B" "$BL5(B" "$BLD(B" "$B5c(B")  == $B4A;zItJ,$NA4%(%s%H%j(B
  ;; entry2 := ("[$B$/(B")                == $BB>$NAw$j2>L>$r;H$&4A;z%(%s%H%j(B ($B$"$l(B
  ;;                                     $B$P(B) + $B:#2s$NJQ49$NAw$j2>L>ItJ,(B
  ;; entry3 := ("$BL5(B" "$BLD(B" "$B5c(B")       == $B:#2s$NJQ49$NAw$j2>L>$r;H$&2DG=@-$N(B
  ;;                                     $B$"$kA44A;z%(%s%H%j(B
  ;; entry4 := ("]" "[$B$-(B" "$BK4(B" "]")   == $BB>$NAw$j2>L>$r;H$&4A;z%(%s%H%j(B ($B;D(B
  ;;                                     $B$j!#$"$l$P(B)
  ;;
  ;;   * "[" $B$OD>8e$KB3$/$R$i$,$J$rAw$j2>L>$K;}$D4A;z$N%(%s%H%j$N=i$^$j$rI=$7!"(B
  ;;     "]" $B$O!"3:Ev$NAw$j2>L>%0%k!<%W$N=*$j$r<($9!#(B
  ;;
  ;; $B$3$N4X?t$O!"JQ49;~$H!"3NDjD>8e$N<-=q$N%"%C%W%G!<%H;~$N(B 2 $BEY8F$P$l$k(B
  ;; ($BJQ49;~$K8!:w$r9T$C$?<-=q$,!"(Bskk-jisyo $B$H$O8B$i$J$$$N$G!"(B2 $BEY7W;;$;$6$k(B
  ;; $B$rF@$J$$(B)$B!#(B
  ;;
  ;; $BJQ49;~$O!"(Bskk-henkan-okuri-strictly $B$,(B non-nil $B$G$"$l$P!"(B
  ;; $B7W;;7k2L$N(B entry3$B$r!"(Bskk-henkan-okuri-strictly $B$,(B nil $B$G$"$C$F(B
  ;; $B$+$D(B skk-henkan-strict-okuri-precedence $B$,(B non-nil $B$"$l$P(B
  ;; (skk-uniion entry3 entry1) $B$r<h$j=P$9!#(B
  ;; $B$U$?$D$NJQ?t$,$H$b$K(B nil $B$N>l9g$O(B entry1 $B$r<h$j=P$9!#(B
  (if (not okurigana)
      (list (string-split
             "/"
             (skk-buffer-substring (point)
                                   (progn (end-of-line) (1- (point))) ))
            nil nil nil )
    (save-match-data
      (let ((stage 1) (q1 (queue-create)) (q2 (queue-create))
            (q3 (queue-create)) (q4 (queue-create))
            (okuri-key (concat "\[" okurigana)) item headchar )
        (catch 'exit
          (while (not (eolp))
            (setq item (skk-buffer-substring (point) (1- (search-forward "/")))
                  headchar (if (string= item "") (skk-int-char 0) (aref item 0)) )
            (cond ((and (eq headchar ?\[) ; ?\[
                        (<= stage 2) )
                   (if (string= item okuri-key)
                       (progn (queue-enqueue q2 item)
                              (setq stage 3) )
                     (setq stage 2)
                     (queue-enqueue q2 item) ))
                  ((eq stage 1)
                   (queue-enqueue q1 item) )
                  ((eq stage 2)
                   (queue-enqueue q2 item) )
                  ((eq stage 3)
                   (if (eq headchar ?\]) ; ?\]
                       (progn (setq stage 4)
                              (queue-enqueue q4 item) )
                     (queue-enqueue q3 item) ))
                  ((eq stage 4)
                   (queue-enqueue q4 item) ))))
        ;;        entry1          entry2        entry3          entry4
        (list (queue-all q1) (queue-all q2) (queue-all q3) (queue-all q4)) ))))

;; $B%-%e!<4XO"$N4X?t$N;HMQ$K:]$7$F$O!"!V%W%m%0%i%`$N9=B$$H<B9T!W(B(H. $B%(!<%Y%k%=(B
;; $B%s!"(BG.J.$B%5%9%^%s!"(BJ.$B%5%9%^%sCx!"855HJ8CKLu!#%^%0%m%&%R%k=PHG(B) $B$H(B Elib (the
;; GNU emacs lisp library version 1.0) $B$r;29M$K$7$?!#>e5-$NJ88%$G2r@b$5$l$F$$(B
;; $B$k%-%e!<$NI=8=$O!"(BElib $B$N(B queue-m.el $B$K$*$$$F<B8=$5$l$F$$$k$b$N$H$[$\F1$8<B(B
;; $BAu$H$J$C$F$$$k!#(B
;;
;; $B%j%9%H$G$N%-%e!<$NI=8=$O!"6qBNE*$K$ONc$($P(B ((A B C D E F) F) $B$N$h$&$J7A$K$J$C(B
;; $B$F$*$j!"(Bcar $B$N%j%9%H(B (A B C D E F) $B$,%-%e!<$NA4BN$rI=$o$7!"%-%e!<$N(B nth 1 
;; $B$r<h$C$?$H$-$N(B F $B$,%-%e!<$N:G8eHx$rI=$o$9!#%-%e!<$N(B cdr $B$r<h$C$?$H$-$N(B (F) 
;; $B$H$$$&%j%9%H$O!"%-%e!<$N(B car $B$KBP$7(B nthcdr 5 $B$r<h$C$?$H$-$N%j%9%H(B (F) $B$HF1(B
;; $B$8$b$N$G$"$k!#=>$$!"(Bcdr $B$N%j%9%H$N8e$K?7$7$$MWAG$rDI2C$9$k$3$H$G!"(Bcar $B$GI=(B
;; $B$o$5$l$k%-%e!<$NKvHx$K?7$7$$MWAG$rDI2C$9$k$3$H$,$G$-$k!#(B
;; $B0lJ}!"(Bnconc $B$d(B append $B$G$D$J$0$K$O!"$=$l$i$N4X?t$NBh#10z?t$N%j%9%H$NA4$F$N(B
;; $BMWAG$rAv::$;$M$P$J$i$:!"(BO(n) $B$N;~4V$,$+$+$k$N$G!"D9$$%j%9%H$r$D$J$0$H$-$OHf(B
;; $B3SE*%3%9%H$,$+$+$k!#(B
;;
;; $B$5$F!"6u$N(B queue == (cons nil nil) $B$KBP$7!"?7$7$$MWAG(B A $B$rDI2C$9$kJ}K!$r@b(B
;; $BL@$9$k!#$^$:!"?7$7$$MWAG(B A $B$N$_$r4^$s$@D9$5(B 1 $B$N%j%9%H(B (A) $B$r:n$k(B ($B2>$K(B 
;; new-pair $B$H$$$&JQ?t$K<h$k(B)$B!#<!$K!"(B(setcar queue new-pair) $B$r9T$J$&$3$H$K$h(B
;; $B$j!"(Bqueue $B$,(B ((A)) $B$H$J$k(B (setcar, setcdr $B$NJV$jCM$O!"(Bnew-pair $B$G$"$k$3$H$K(B
;; $BCm0U(B)$B!#<!$K(B (setcdr queue new-pair) $B$7$F(B ((A) A) $B$H$J$C$?$H$3$m$r?^<($9$k!#(B
;; front, rear $B$NN>J}$N%]%$%s%?$,(B (A) $B$r;X$9$h$&$K$9$k(B ($B%-%e!<$NMWAG$,(B A $B$7$+(B
;; $B$J$$$N$G!"(Bfront, rear $B%]%$%s%?$H$b$KF1$8$b$N$r;X$7$F$$$k(B)$B!#(B
;;         queue
;;   +-------+-------+
;;   | Front |  Rear |
;;   +---|---+---|---+
;;       |       +---> +---------------+
;;       +------------>|   o   |  nil  |
;;                     +---|---+-------+
;;                         |      +-------+
;;                         +----> |   A   |
;;                                +-------+
;;
;; $B>e5-$N(B queue, ((A) A) $B$KBP$7!"99$K?7$7$$MWAG(B B $B$rDI2C$9$k!#Nc$K$h$j(B B $B$N$_(B
;; $B$r4^$`D9$5(B 1 $B$N%j%9%H(B (B) $B$r:n$j!"JQ?t(B new-pair $B$K<h$k!#$3$3$G(B
;; (setcdr (cdr queue) new-pair) $B$rI>2A$9$k$H(B ($BCm(B1)$B!"(B* $B$N8D=j$N%]%$%s%?A`:n$,(B
;; $B9T$J$o$l$k!#%-%e!<$N:G8eJ}$K?7$7$$MWAG$G$"$k(B B $B$,DI2C$5$l$k$3$H$K$J$k!#(B
;; queue $B$O(B ((A B) A B) $B$H$J$k!#(B
;;         queue
;;   +-------+-------+
;;   | Front |  Rear |
;;   +---|---+---|---+
;;       |       +---> +---------------+   *    +---------------+
;;       +------------>|   o   |   o --|------->|   o   |  nil  |
;;                     +---|---+-------+        +-------+-------+
;;                         |      +-------+         |      +-------+
;;                         +----> |   A   |         +----> |   B   |
;;                                +-------+                +-------+
;;
;;   $BCm(B1; $BDI2CA0$N%-%e!<$NMWAG$,(B 1 $B$D$N$H$-$O!"(Bfront $B$b(B rear $B$bF1$8$b$N$r;X$7(B
;;        $B$F$$$k$N$G(B (setcdr (car queue) new-pair) $B$G$bEy2A$@$,!"%-%e!<$NMWAG(B
;;        $B$,(B 2 $B$D0J>e$N$H$-$O(B (setcdr (cdr queue) new-pair) $B$G$J$$$H$^$:$$!#(B
;;
;; $B:G8e$K(B (setcdr queue new-pair) $B$rI>2A$9$k$3$H$K$h$j!"(Brear $B%]%$%s%?$rD%$jJQ(B
;; $B$($k(B (* $B$N8D=j$N%]%$%s%?A`:n$,9T$J$o$l$k(B)$B!#(Brear $B%]%$%s%?$,%-%e!<$N:G8eJ}$N(B
;; $BMWAG$r;X$9$h$&$K$9$k!#(Bfront $B%]%$%s%?$,;X$9%j%9%H$O%-%e!<$NA4$F$NMWAG$rI=$o(B
;; $B$9!#(B
;;         queue
;;   +-------+-------+           *
;;   | Front |  Rear |---------------------+
;;   +---|---+-------+                     |
;;       |             +---------------+   +--> +---------------+
;;       +------------>|   o   |   o --|------->|   o   |  nil  |
;;                     +---|---+-------+        +-------+-------+
;;                         |      +-------+         |      +-------+
;;                         +----> |   A   |         +----> |   B   |
;;                                +-------+                +-------+
;;
;; $B$3$N$h$&$K%-%e!<$N:G8eJ}$K?7$7$$MWAG$rDI2C$9$k$3$H(B ($B%j%9%H$N:G8eJ}$KD9$5(B 1
;; $B$N?7$7$$%j%9%H$r$D$J$2$k$3$H(B) $B$,(B 2 $B2s$N%]%$%s%?A`:n$G2DG=$H$J$k$N$G!"$I$N$h(B
;; $B$&$JD9$$%j%9%H$G$"$C$F$bO"7k$K$+$+$k%3%9%H$O0lDj(B (O(1) $B$N4X?t$G$"$k(B) $B$G$"$k!#(B
;; $B$J$*!"8=>u$G$O!"J?6Q$7$F0B2A$K%j%9%H$N:G8eJ}$KMWAG$r$D$J$2$k!"$H$$$&L\E*$K(B
;; $B$@$1%-%e!<$r;H$C$F$$$k!#%-%e!<K\Mh$NL\E*$G$O;HMQ$7$F$*$i$J$$$N$G!"Nc$($P!"(B
;; $B2<5-$N$h$&$J4X?t$O;HMQ$7$F$$$J$$!#(B
;; queue-last, queue-first, queue-nth, queue-nthcdr, queue-dequeue

;;;###skk-autoload
(defun skk-nunion (x y)
  ;; X $B$H(B Y $B$NOB=89g$r:n$k!#Ey$7$$$+$I$&$+$NHf3S$O!"(Bequal $B$G9T$o$l$k!#(BX $B$K(B Y
  ;; $B$rGK2uE*$KO"@\$9$k!#(B
  (cond ((null x) y)
        ((null y) x)
        (t (let ((e x))
             (while e
               (setq y (delete (car e) y)
                     e (cdr e) ))
             (if y
                 ;; $B>e5-$N(B while $B%k!<%W$NCf$N(B delete $B$H2<5-$N(B nconc $B$H$r9g$o$;(B
                 ;; $B$F!"A4It$G(B X $B$r(B 2 $B2s!"(BY $B$r(B X $B2sAv::$7$?$3$H$K$J$k!#%=!<(B
                 ;; $B%H$5$l$F$$$J$$=89gF1;N$+$i=89g$r:n$k0J>e(B ($B8uJd$O%=!<%H$7$F(B
                 ;; $B$O$J$i$J$$(B) $B!"C`<!Av::$K$J$k$N$G$3$l$O;_$`$rF@$J$$$+(B...$B!#(B
                 (nconc x y)
               x )))))

(defun skk-search-kakutei-jisyo-file (file limit &optional nomsg)
  ;; $B<-=q%U%!%$%k$rC5$7!"8uJd$r%j%9%H$GJV$9!#(B
  ;; $B8uJd$r8+$D$1$?>l9g$O!"Bg0hJQ?t(B skk-kakutei-flag $B$K(B non-nil $B$rBeF~$9$k!#(B
  ;; $B8uJd$,8+$D$+$i$J$+$C$?>l9g$O!"(Bnil $B$rJV$9!#(B
  (setq skk-kakutei-flag (skk-search-jisyo-file file limit nomsg)) )

;;;###skk-autoload
(defun skk-update-jisyo (word &optional purge)
  ;; WORD $B$,<!$NJQ49;~$K:G=i$N8uJd$K$J$k$h$&$K!"%W%i%$%Y!<%H<-=q$r99?7$9$k!#(B
  ;; PURGE $B$,(B non-nil $B$G(B WORD $B$,6&M-<-=q$K$"$k%(%s%H%j$J$i(B skk-ignore-dic-word
  ;; $B4X?t$G%/%)!<%H$7$?%(%s%H%j$r%W%i%$%Y!<%H<-=q$K:n$j!"<!$NJQ49$+$i=PNO$7$J(B
  ;; $B$$$h$&$K$9$k!#(B
  ;; WORD $B$,6&M-<-=q$K$J$1$l$P!"%W%i%$%Y!<%H<-=q$N<-=q%(%s%H%j$+$i:o=|$9$k!#(B
  ;;
  ;; SKK 9.x $B$h$j!"%W%i%$%Y!<%H<-=q$N%(%s%H%j$NA^F~$NJ}K!$rJQ99$7$?(B (9.3 $B$N$_(B
  ;; $B$ONc30(B)$B!#(B
  ;;
  ;; $B!ZJQ99A0![(B
  ;;         ;; okuri-ari entries.
  ;;  $B8+%-(B   $B$o$k(Bk /$B0-(B/[$B$+(B/$B0-(B/]/[$B$/(B/$B0-(B/]/
  ;;  $B=P!<(B   $B$o$k(Bi /$B0-(B/[$B$$(B/$B0-(B/]/
  ;;  $B$7$K(B   $B$o$?(Bs /$BEO(B/[$B$5(B/$BEO(B/]/[$B$;(B/$BEO(B/]/
  ;;  $B8l9_(B   $B$o$9(Br /$BK:(B/[$B$l(B/$BK:(B/]/
  ;;  $B$r=g(B   $B$o$+(Bt /$BJ,(B/$BH=(B/[$B$C$?(B/$BJ,(B/$BH=(B/]/[$B$C$F(B/$BJ,(B/]/
  ;;   $B"-(B     .....
  ;;         $B$"(Bi /$B9g(B/[$B$$(B/$B9g(B/]/
  ;;         ;; okuri-nasi entries.
  ;;  $BJQ$G(B   $B$8$g$&$?$$(B /$B>uBV(B/
  ;;  $B49>:(B   $B$=$&$K$e$&(B /$BA^F~(B/
  ;;  $B=g=g(B   $B$+$J(B /$B2>L>(B/
  ;;   $B"-(B    ...
  ;;         ...
  ;;
  ;; $B!ZJQ998e![(B
  ;;         ;; okuri-ari entries.
  ;;  $BJQ$G(B   $B$G(Bt /$B=P(B/[$B$F(B/$B=P(B/]/[$B$?(B/$B=P(B/]/
  ;;  $B49>:(B   $B$D(Bi /$BIU(B/[$B$$(B/$BIU(B/]/
  ;;  $B=g=g(B   $B$1(Bs /$B>C(B/[$B$9(B/$B>C(B/]/[$B$7(B/$B>C(B/]/[$B$;(B/$B>C(B/]/[$B$5(B/$B>C(B/]/
  ;;   $B"-(B    $B$+$((Bs /$BJV(B/[$B$7(B/$BJV(B/]/[$B$9(B/$BJV(B/]/[$B$5(B/$BJV(B/]/[$B$;(B/$BJV(B/]/
  ;;         ...
  ;;         ...
  ;;         $B$J$,(Bs /$BD9(B/$BN.(B/[$B$7(B/$BN.(B/]/[$B$5(B/$BD9(B/]/[$B$=(B/$BN.(B/]/
  ;;         ;; okuri-nasi entries.
  ;;  $BJQ$G(B   $B$8$g$&$?$$(B /$B>uBV(B/
  ;;  $B49>:(B   $B$=$&$K$e$&(B /$BA^F~(B/
  ;;  $B=g=g(B   $B$+$J(B /$B2>L>(B/
  ;;   $B"-(B    ...
  ;;         ...
  ;;
  ;; skk-auto-okuri-process $B$,(B non-nil $B$N$H$-$K!"(B(j-okuri-search $B2~$a(B)
  ;; skk-okuri-search $B$O8+=P$78l$ND9$$=g$K8uJd$rJV$9I,MW$,$"$k!#(B
  ;; SKK 8.6 $B$^$G$O!"(Bskk-okuri-search $B$,(B j-okuri-ari-min $B$+$i(B j-okuri-ari-max
  ;; $B$^$G$r=g$KC5$7!"8+$D$1$?$b$N=g$K8uJd$rJV$9$?$a$K%W%i%$%Y!<%H<-=q$,8+=P$7(B
  ;; $B8l$r%-!<$H$7$F9_=g$K%=!<%H$5$l$F$$$kI,MW$,$"$C$?!#(B
  ;; SKK 9.x $B$G$O!"(Bskk-okuri-search $B$,!"8+IU$1$?8uJd$r8+=P$78l$r%-!<$H$7$F>:=g(B
  ;; $B$K%=!<%H$7$FJV$9$?$a!"%W%i%$%Y!<%H<-=q$N%=!<%H$OI,MW$G$J$$!#$h$C$F!":G8e(B
  ;; $B$KJQ49$7$?$b$N$r(B (j-okuri-ari-min $B2~$a(B) skk-okuri-ari-min $B$N0LCV$KA^F~$9(B
  ;; $B$k!#(B
  ;;
  (let ((jisyo-buffer (skk-get-jisyo-buffer skk-jisyo 'nomsg))
	(midasi 
	 (if skk-use-numeric-conversion
	     (skk-compute-numeric-henkan-key skk-henkan-key)
	   skk-henkan-key ))
	(last skk-last-henkan-result)
	(last-point skk-last-henkan-point)
	(here (point)) )
    (if jisyo-buffer
        (let ((inhibit-quit t) buffer-read-only old-entry okurigana)
          (if skk-auto-okuri-process
              (setq word (skk-remove-common word)) )
          (setq okurigana (or skk-henkan-okurigana skk-okuri-char))
                ;; midasi skk-henkan-key )
          (with-current-buffer jisyo-buffer
            ;; $B4{B8%(%s%H%j$r8!:w8e>C5n$9$k!#A^F~$9$Y$-%(%s%H%j$,(B entry1 $B$K(B 1
            ;; $B$D$7$+$J$/!"(Bword $B$HF1$8J8;z$G$"$C$F$b!"$$$C$?$s>C$7$F$=$N%(%s%H(B
            ;; $B%j$r(B min $B%]%$%s%H$K0\F0$5$;$J$1$l$P$J$i$J$$(B ($BFI$_$NJd40$r9T$&$H(B
            ;; $B$-$O!"(Bmin $B%]%$%s%H$+$i8+=P$7$rC5$9$?$a!"?7$7$$8+=P$7$[$I!"(Bmin
            ;; $B%]%$%s%H$K6a$$$H$3$m$K$J$1$l$P$J$i$J$$(B)$B!#(B
            (setq skk-henkan-key midasi
                  old-entry (skk-search-jisyo-file-1 okurigana 0 'delete) )
            (skk-update-jisyo-1 okurigana word old-entry purge)
	    (if skk-use-relation
		(progn
		  (if (not (and
			    last
			    (markerp last-point)
			    (< last-point here)
			    (< (- here last-point) skk-relation-length) ))
		      (setq last nil) )
		  (skk-update-relation
		   midasi okurigana word last purge) ))
	    (if skk-debug (message "%S %S %S" last last-point here))
            ;;(if (featurep 'skk-attr)
            ;;    (progn
            ;;      (and skk-attr-default-update-function
            ;;           (funcall skk-attr-default-update-function midasi
            ;;                    okurigana word purge ))
            ;;      (and skk-attr-update-function
            ;;           (funcall skk-attr-update-function midasi okurigana
            ;;                    word purge ))))
            ;; auto save.
            (if skk-jisyo-save-count
                (if (> skk-jisyo-save-count skk-update-jisyo-count)
                    (setq skk-update-jisyo-count (1+ skk-update-jisyo-count))
                  (setq skk-update-jisyo-count 0)
                  (skk-save-jisyo 'quiet) ))
            ;; $B<-=q%P%C%U%!$r%*!<%W%s$7$?$H$-$K(B auto-save-mode $B$r%*%U$K$7$F$*(B
            ;; $B$1$PKhEY2<5-$N$h$&$JA`:n$r$7$J$/$F:Q$`!#(B
            ;;
            ;; $B$3$&$7$F$*$1$P!"<-=q%P%C%U%!$O%*!<%H%;!<%V$5$l$J$/$F:Q$`!#(B
            ;;(set-buffer-modified-p nil)
            )))))

(defun skk-update-jisyo-1 (okurigana word old-entry-list purge)
  ;; $B4{B8%(%s%H%j$+$i7W;;$7$?(B entry[1-4] $B$NCM$H!":#2s$NJQ49$N7k2L(B word $B$H$r%^!<(B
  ;; $B%8$7$F!"?7$?$J%(%s%H%j$r7W;;$7!"A^F~$9$k!#(B
  (let ((entry1 (car old-entry-list)) (entry2 (nth 1 old-entry-list))
        (entry3 (nth 2 old-entry-list)) (entry4 (nth 3 old-entry-list)) )
    (if (not purge)
        ;; entry1 $B$N@hF,$N%(%s%H%j$r(B word $B$K$9$k!#(B
        (setq entry1 (cons word (delete word entry1)))
      ;; $BAw$j$J$7!"$b$7$/$O(B skk-henkan-okuri-strictly $B$H(B
      ;; skk-henkan-strict-okuri-precedence $B$,(B nil $B$N>l9g!#(B
      (if (or (not okurigana) (not (or skk-henkan-okuri-strictly
				       skk-henkan-strict-okuri-precedence )))
          ;; entry1 $B$r(B purge$B!#6&MQ<-=q$K$"$k%(%s%H%j$@$C$?$i!"(B
          ;; skk-ignore-dic-word $B$G%/%)!<%H$7$F<!$NJQ49$+$i=PNO$7$J$$$h$&$K$9(B
          ;; $B$k!#6&MQ<-=q$K$J$$J8;zNs$O(B word $B$r>C$9!#(B
          (if (skk-public-jisyo-contains-p okurigana word)
              (setq entry1 (skk-compose-ignore-entry entry1 word))
            (setq entry1 (delete word entry1)) )
        ;; $BAw$j$"$j$G!"$+$D(B skk-henkan-okuri-strictly $B$+(B
	;; skk-henkan-strict-okuri-precedence $B$,(B non-nil $B$N>l9g$G!"$+$D(B
        ;; $B$3$N(B word $B$H%Z%"$K$J$kAw$j2>L>$,(B okurigana $B$7$+$J$$$H$-!#(B
        (if (and okurigana (or skk-henkan-okuri-strictly
			       skk-henkan-strict-okuri-precedence )
                 (null (member word entry2)) (null (member word entry4)) )
            (setq entry1 (delete word entry1))
          ;; $B$=$NB>$N>l9g$O2?$b$7$J$$!#(B
          )))
    (if (null entry1)
        ;; entry1 $B$,(B null $B$G$"$l$P!"$b$&2?$b$9$k$3$H$O$J$$!#(B
        nil
      (goto-char (if okurigana skk-okuri-ari-min skk-okuri-nasi-min))
      (insert "\n" skk-henkan-key " /")
      ;; entry1 -- $BA4%(%s%H%j(B ($BAw$j$J$7$N>l9g(B) or $B4A;zItJ,$NA4%(%s%H%j(B ($BAw$j$"(B
      ;; $B$j$N>l9g(B)
      (insert (mapconcat 'skk-quote-char entry1 "/") "/")
      (if (not okurigana)
          nil
        ;; entry2 $B0J9_$N%(%s%H%j$r=hM}$9$k$N$O!"Aw$j$"$j$N>l9g$N$_!#(B
        ;; $B@h$KA^F~$9$Y$-%(%s%H%j$r7W;;!"D4@0$9$k!#(B
        (if entry3
            (if (not purge)
                (setq entry3 (cons word (delete word entry3)))
              (setq entry3 (delete word entry3))
              (if (null entry3)
                  ;; entry3 $B$H$7$FA^F~$9$k$b$N$,A4$/$J$1$l$P!"(B"/[$B$/(B/]/" $B$N$h(B
                  ;; $B$&$JAw$j2>L>$N$_$N%(%s%H%j$r:n$i$J$$$h$&$K$9$k(B ($BI,MW$G(B
                  ;; $B$"$l$P!"(Bentry2 $B$N:G8eJ}$H(B) entry4 $B$N@hF,$N%(%s%H%j(B "]"
                  ;; $B$r:o=|!#(B
                  (let ((last2 (nthcdr (- (length entry2) 2) entry2)))
                    ;; entry2 $B$N:G8eJ}$O>o$K(B "[$BAw$j2>L>(B" $B$H$O8B$i$J$$!#(B
                    (if (string= (nth 1 last2) (concat "[" okurigana))
                        (setcdr last2 nil) )
                    ;; entry4 $B$N@hF,$O>o$K(B "]"$B!#(B
                    (setq entry4 (cdr entry4)) )))
          ;; entry3 $B$,(B null $B$G$"$l$P(B
          (if (or skk-process-okuri-early purge)
              ;; skk-process-okuri-early $B$,(B non-nil $B$J$iAw$j2>L>$,J,$i$J$$$N$G(B
              ;; $B2?$b$7$J$$!#(B-- $B:#2s;HMQ$7$?Aw$j2>L>$,$o$+$i$J$$$^$^JQ49$7$F$$(B
              ;; $B$k$N$G!"A4$F$N%(%s%H%j$,(B entry2 $B$KF~$C$F$$$k(B -- entry3,
              ;; entry4 $B$O(B null$B!#(B
              ;; entry3 $B$H$7$FA^F~$9$k$b$N$,A4$/$J$1$l$P!"2?$b$7$J$$(B -- entry3
              ;; $B$,(B purge $BA0$+$i(B null $B$J$i!"(Bentry2 $B$NKvHx$O(B "[" $B$G$J$$$7!"(B
              ;; entry4 $B$O(B null $B$@$+$i(B entry[234] $B$NA`:n$OITMW!#(B
              nil
            (setq entry2 (nconc entry2 (list (concat "[" okurigana)))
                  entry3 (list word)
                  ;; purge $BA0$+$i(B entry3 $B$,(B null $B$@$C$?$N$@$+$i(B entry4 $B$b(B null$B!#(B
                  entry4 (list "]") ))))
      (if entry2
          ;; entry2 -- $B:#2s;HMQ$7$J$+$C$?Aw$j2>L>$r;H$&4A;z$N8uJd72(B + "[" + $B:#(B
          ;; $B2s;HMQ$7$?Aw$j2>L>(B ($BAw$j2>L>$N$_!#$=$NAw$j2>L>$r;HMQ$9$k4A;z$N8u(B
          ;; $BJd72$O!"(Bentry3 $B$K4^$^$l$k(B)$B!#(B
          (progn
            (insert (mapconcat 'skk-quote-char entry2 "/" ) "/")
            ;; entry2 $B$,(B null $B$J$i(B entry3 $B$b(B null$B!#(B
            (if entry3
                ;; entry3 -- $B:#2s;HMQ$7$?Aw$j2>L>$r;H$&A44A;z%(%s%H%j(B
                (insert (mapconcat 'skk-quote-char entry3 "/") "/") )
            ;; purge $B$G(B entry3 $B$,(B null $B$K$J$C$?>l9g$O(B entry4 $B$,;D$C$F$$$k$H$-(B
            ;; $B$,$"$k!#(B
            (if entry4
                ;; entry4 -- "]" + $BB>$NAw$j2>L>$r;H$&A44A;z%(%s%H%j(B (entry2 $B$N(B
                ;; $B;D$j(B)$B!#(B
                (insert (mapconcat 'skk-quote-char entry4 "/") "/") ))))))

(defun skk-quote-char (word)
  ;; $B<-=q$N@)8B$+$i<-=q%(%s%H%jFb$K4^$a$F$O$J$i$J$$J8;z$,(B WORD $B$NCf$K$"$l$P!"(B
  ;; $BI>2A$7$?$H$-$K$=$NJ8;z$H$J$k$h$&$J(B Lisp $B%3!<%I$rJV$9!#(B
  (save-match-data
    (if (and word
             (string-match "[/\n\r\"]" word)
             ;; we should not quote WORD if it is a symbolic expression
             (not (skk-lisp-prog-p word)) )
        (concat "(concat \""
                (mapconcat (function (lambda (c)
                                       (cond ((eq c ?/) ; ?/
                                              "\\057" )
                                             ((eq c ?\n) ; ?\n
                                              "\\n" )
                                             ((eq c ?\r) ; ?\r
                                              "\\r" )
                                             ((eq c ?\") ; ?\"
                                              "\\\"" )
                                             ((eq c ?\\) ; ?\\
                                              "\\\\" )
                                             (t (char-to-string c)))))
                           ;; $BJ8;zNs$rBP1~$9$k(B char $B$N%j%9%H$KJ,2r$9$k!#(B
                           (append word nil) "")
                "\")")
      word )))

(defun skk-lisp-prog-p (word)
  ;; word $B$,(B Lisp $B%W%m%0%i%`$G$"$l$P!"(Bt $B$rJV$9!#(B
  (let ((l (length word)))
    (and (> l 2)
         (eq (aref word 0) ?\() ; ?\(
         (< (aref word 1) 128)
         (eq (aref word (1- l)) ?\)) ))) ; ?\)

(defun skk-public-jisyo-contains-p (okurigana word)
  ;; $B6&M-<-=q$,(B MIDASHI $B5Z$S$=$l$KBP1~$9$k(B WORDS $B%(%s%H%j$r;}$C$F$$$l$P!"(B
  ;; non-nil $B$rJV$9!#%W%i%$%Y!<%H<-=q$N%P%C%U%!$G%3!<%k$5$l$k!#(B
  (let (fn skk-henkan-okuri-strictly skk-henkan-strict-okuri-precedence)
    (if okurigana
        (setq skk-henkan-okurigana okurigana) )
    (if (and (not (featurep 'skk-server))
             (or (and (boundp 'skk-server-host) skk-server-host)
                 (and (boundp 'skk-servers-list) skk-servers-list)
                 (getenv "SKKSERVER")
                 (getenv "SKKSERV") ))
        (require 'skk-server) )
    (if (and (featurep 'skk-server)
             (or (and skk-server-host skk-server-prog)
                 skk-servers-list ))
        (setq fn (assq 'skk-search-server skk-search-prog-list)) )
    ;; skk-search-server $B$+$i;O$^$k%j%9%H$,$J$1$l$P!"$H$K$+$/Bg$-$$<-=q$r0z?t(B
    ;; $B$K$7$F$$$k(B skk-search-jisyo-file $B%W%m%0%i%`$rC5$9!#(B
    (if (and (not fn) (or skk-aux-large-jisyo skk-large-jisyo))
        (let ((spl skk-search-prog-list)
              cell )
          (while (setq cell (car spl))
            (if (and (eq (car cell) 'skk-search-jisyo-file)
                     (member (nth 1 cell)
                             '(skk-aux-large-jisyo skk-large-jisyo) ))
                (setq fn cell
                      spl nil )
              (setq spl (cdr spl)) ))))
    (and fn (member word (eval fn))) ))

(defun skk-compose-ignore-entry (entry &optional add)
  ;; ENTRY $B$NCf$K(B skk-ignore-dic-word $B4X?t$G%/%)!<%H$7$?%(%s%H%j$,$"$l(B
  ;; $B$P!"0l$D$N%(%s%H%j$K$^$H$a$k!#(B
  ;; $B%*%W%7%g%J%k0z?t$N(B ADD $B$,;XDj$5$l$F$$$?$i!"(BADD $B$r4^$a$?(B
  ;; skk-ignore-dic-word $B%(%s%H%j$r:n$k!#(B
  ;; $B?7$7$$(B skk-ignore-dic-word $B%(%s%H%j$r(B car $B$K!"$=$l0J30$N%(%s%H%j(B cdr $B$K$7(B
  ;; $B$?%j%9%H$rJV$9!#(B
  (let (l arg e)
    (if add (setq entry (delete add entry)))
    (setq l entry)
    (save-match-data
      (while l
        (setq e (car l)
              l (cdr l) )
        (if (string-match "(skk-ignore-dic-word +\\([^\)]+\\))" e)
            (setq arg (concat arg
                              (substring e (1+ (match-beginning 1))
                                         (1- (match-end 1)) )
                              "\" \"" )
                  entry (delq e entry) )))
      (if add
          (setq arg (if arg (concat arg add) add))
        ;; $BKvHx$N(B " \"" $B$r@Z$jMn$H$9!#(B
        (setq arg (substring arg 0 -2)) )
      (cons (concat "(skk-ignore-dic-word \"" arg "\")") entry) )))

(defun skk-katakana-region (start end &optional vcontract)
  "$B%j!<%8%g%s$N$R$i$,$J$r%+%?%+%J$KJQ49$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B VCONTRACT $B$,(B non-nil $B$G$"$l$P!"(B\"$B$&!+(B\" $B$r(B \"$B%t(B\" $B$KJQ49$9(B
$B$k!#(B
$B0z?t$N(B START $B$H(B END $B$O?t;z$G$b%^!<%+!<$G$bNI$$!#(B"
  (interactive "*r\nP")
  (let ((diff (if skk-mule (- ?$B%"(B ?$B$"(B)))
        ch )
    (skk-save-point
      (save-match-data
        ;;(if (and skk-henkan-active skk-use-face) (skk-henkan-face-off))
        (goto-char start)
        (while (re-search-forward  "[$B$!(B-$B$s(B]" end 'noerror)
          (setq ch (preceding-char))
          ;; firstly insert a new char, secondly delete an old char to save
          ;; the cursor position.
          (if skk-mule
              (progn
                (backward-char 1)
                (cancel-undo-boundary)
                (insert (+ ch diff)) )
            (backward-char 2)
            (cancel-undo-boundary)
            (insert ?\245 ch) )
          (cancel-undo-boundary)
          (delete-region (+ (match-beginning 0) skk-kanji-len)
                         (+ (match-end 0) skk-kanji-len) ))
        (if vcontract
            (progn
              (goto-char start)
              (while (re-search-forward  "$B%&!+(B" end 'noerror)
                (if skk-mule
                    (backward-char 2)
                  (backward-char 3) )
                (cancel-undo-boundary)
                (insert "$B%t(B")
                (cancel-undo-boundary)
                (delete-region (+ (match-beginning 0) skk-kanji-len)
                               (+ (match-end 0) skk-kanji-len) ))))
        ;;(if (and skk-henkan-active skk-use-face) (skk-henkan-face-on))
        (skk-set-cursor-properly)
        ))))

(defun skk-hiragana-region (start end &optional vexpand)
  "$B%j!<%8%g%s$N%+%?%+%J$r$R$i$,$J$KJQ49$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B VEXPAND $B$,(B non-nil $B$G$"$l$P!"(B\"$B%t(B\" $B$r(B \"$B$&!+(B\" $B$KJQ49$9$k!#(B
$B0z?t$N(B START $B$H(B END $B$O?t;z$G$b%^!<%+!<$G$bNI$$!#(B
\"$B%u(B\" $B$H(B \"$B%v(B\" $B$OJQ99$5$l$J$$!#$3$N(B 2 $B$D$NJ8;z$OBP1~$9$k$R$i$,$J$,$J$$$N$G!"%+(B
$B%?%+%J$H$7$F$O07$o$l$J$$!#(B"
  (interactive "*r\nP")
  (let ((diff (if skk-mule (- ?$B%"(B ?$B$"(B)))
        ch )
    (skk-save-point
      (save-match-data
        ;;(if (and skk-henkan-active skk-use-face) (skk-henkan-face-off))
        (goto-char start)
        (while (re-search-forward  "[$B%!(B-$B%s(B]" end 'noerror)
          (setq ch (preceding-char))
          ;; firstly insert a new char, secondly delete an old char to save
          ;; the cursor position.
          (if skk-mule
              (progn
                (backward-char 1)
                (cancel-undo-boundary)
                (insert (- ch diff)) )
            (backward-char 2)
            (cancel-undo-boundary)
            (insert ?\244 ch) )
          (cancel-undo-boundary)
          (delete-region (+ (match-beginning 0) skk-kanji-len)
                         (+ (match-end 0) skk-kanji-len) ))
        (if vexpand
            (progn
              (goto-char start)
              (while (re-search-forward "$B%t(B" end 'noerror)
                (backward-char 1)
                (cancel-undo-boundary)
                (insert "$B$&!+(B")
                (cancel-undo-boundary)
                (delete-region (+ (match-beginning 0) (* skk-kanji-len 2))
                               (+ (match-end 0) (* skk-kanji-len 2)) ))))
        ;;(if (and skk-henkan-active skk-use-face) (skk-henkan-face-on))
        (skk-set-cursor-properly)
        ))))

(defun skk-zenkaku-region (start end)
  "$B%j!<%8%g%s$N(B ascii $BJ8;z$rBP1~$9$kA43QJ8;z$KJQ49$9$k!#(B"
  (interactive "*r")
  (skk-save-point
    (save-match-data
      ;;(if (and skk-henkan-active skk-use-face) (skk-henkan-face-off))
      (goto-char end)
      (while (re-search-backward "[ -~]" start 'noerror)
        (cancel-undo-boundary)
        ;; firstly insert a new char, secondly delete an old char to save
        ;; the cursor position.
        (insert (aref skk-default-zenkaku-vector (following-char)))
        (cancel-undo-boundary)
        (delete-region (+ (match-beginning 0) skk-kanji-len)
                       (+ (match-end 0) skk-kanji-len) ))
      ;;(if (and skk-henkan-active skk-use-face) (skk-henkan-face-on))
      (skk-set-cursor-properly)
      )))

(defun skk-ascii-region (start end)
  ;; $B%j!<%8%g%s$NA43Q1Q?t;z$rBP1~$9$k(B ascii $BJ8;z$KJQ49$9$k!#(B
  ;; egg.el 3.09 $B$N(B hankaku-region $B$r;29M$K$7$?!#(B
  (interactive "*r")
  (skk-save-point
    (save-match-data
      (let (val)
        ;;(if (and skk-henkan-active skk-use-face) (skk-henkan-face-off))
        (goto-char end)
        (while (re-search-backward "\\cS\\|\\cA" start 'noerror)
          (setq val (skk-jisx0208-to-ascii (char-to-string (following-char))))
          (if val
              (progn
                (insert val)
                (delete-region (+ (match-beginning 0) 1)
                               (+ (match-end 0) 1) ))))
        ;;(if (and skk-henkan-active skk-use-face) (skk-henkan-face-on))
        (skk-set-cursor-properly)
        ))))

(defun skk-katakana-henkan (arg)
  "$B"&%b!<%I$G$"$l$P!"%j!<%8%g%s$N$R$i$,$J$r%+%?%+%J$KJQ49$9$k!#(B
$B"'%b!<%I$G$O2?$b$7$J$$!#(B
$B$=$NB>$N%b!<%I$G$O!"%*%j%8%J%k$N%-!<3d$jIU$1$G%P%$%s%I$5$l$F$$$k%3%^%s%I$r<B9T(B
$B$9$k!#(B"
  (interactive "*P")
  (if skk-henkan-on
      (if (not skk-henkan-active)
          (skk-*-henkan-1 'skk-katakana-region skk-henkan-start-point
                          skk-henkan-end-point 'vcontract ))
    (skk-emulate-original-map arg) ))

(defun skk-hiragana-henkan (arg)
  "$B"&%b!<%I$G$"$l$P!"%j!<%8%g%s$N%+%?%+%J$r$R$i$,$J$KJQ49$9$k!#(B
$B"'%b!<%I$G$O2?$b$7$J$$!#(B
$B$=$NB>$N%b!<%I$G$O!"%*%j%8%J%k$N%-!<3d$jIU$1$G%P%$%s%I$5$l$F$$$k%3%^%s%I$r<B9T(B
$B$9$k!#(B"
  (interactive "*P")
  (if skk-henkan-on
      (if (not skk-henkan-active)
          (skk-*-henkan-1 'skk-hiragana-region skk-henkan-start-point
                          skk-henkan-end-point 'vexpand ))
    (skk-emulate-original-map arg) ))

(defun skk-zenkaku-henkan (arg)
  "$B"&%b!<%I$G$"$l$P!"(Bascii $BJ8;z$rBP1~$9$kA43QJ8;z$KJQ49$9$k!#(B
$B"'%b!<%I$G$O2?$b$7$J$$!#(B
$B$=$NB>$N%b!<%I$G$O!"%*%j%8%J%k$N%-!<3d$jIU$1$G%P%$%s%I$5$l$F$$$k%3%^%s%I$r<B9T(B
$B$9$k!#(B"
  (interactive "*P")
  (if skk-henkan-on
      (if (not skk-henkan-active)
          (skk-*-henkan-1 'skk-zenkaku-region skk-henkan-start-point
                          skk-henkan-end-point ))
    (skk-emulate-original-map arg) ))

(defun skk-ascii-henkan (arg)
  "$B"&%b!<%I$G$"$l$P!"(Bascii $BJ8;z$rBP1~$9$kA43QJ8;z$KJQ49$9$k!#(B
$B"'%b!<%I$G$O2?$b$7$J$$!#(B
$B$=$NB>$N%b!<%I$G$O!"%*%j%8%J%k$N%-!<3d$jIU$1$G%P%$%s%I$5$l$F$$$k%3%^%s%I$r<B9T(B
$B$9$k!#(B"
  (interactive "*P")
  (if skk-henkan-on
      (if (not skk-henkan-active)
          (skk-*-henkan-1 'skk-ascii-region skk-henkan-start-point
                          skk-henkan-end-point ))
    (skk-emulate-original-map arg) ))

(defun skk-*-henkan-1 (func &rest args)
  ;; $BJQ492DG=$+$I$&$+$N%A%'%C%/$r$7$?8e$K(B ARGS $B$r0z?t$H$7$F(B FUNC $B$rE,MQ$7!"(B
  ;; skk-henkan-start-point $B$H(B skk-henkan-end-point $B$N4V$NJ8;zNs$rJQ49$9$k!#(B
  (let ((pos (point)))
    (cond ((not (string= skk-prefix ""))
           (skk-error "$B%U%#%C%/%9$5$l$F$$$J$$(B skk-prefix $B$,$"$j$^$9(B"
                      "Have unfixed skk-prefix" ))
          ((< pos skk-henkan-start-point)
           (skk-error "$B%+!<%=%k$,JQ493+;OCOE@$h$jA0$K$"$j$^$9(B"
                      "Henkan end point must be after henkan start point" ))
          ((and (not skk-allow-spaces-newlines-and-tabs)
                (skk-save-point (beginning-of-line)
                                (> (point) skk-henkan-start-point) ))
           (skk-error "$BJQ49%-!<$K2~9T$,4^$^$l$F$$$^$9(B"
                      "Henkan key may not contain a new line character" )))
    (skk-set-marker skk-henkan-end-point pos)
    (apply func args)
    (skk-kakutei) ))

;;;###skk-autoload
(defun skk-jisx0208-to-ascii (string)
  (let ((char
         (cond (skk-mule3
                (require 'language/japan-util)
                (get-char-code-property (string-to-char string) 'ascii) )
               (skk-mule
                (let* ((ch (string-to-char string))
                       (ch1 (char-component ch 1)) )
                  (cond ((eq 161 ch1)   ; ?\241
                         (cdr (assq (char-component ch 2) skk-hankaku-alist)) )
                        ((eq 163 ch1)   ; ?\243
                         (- (char-component ch 2) 128) ; ?\200
                         ))))
               (t (- (aref string (1- skk-kanji-len)) 128)) )))
    (if char (char-to-string char)) ))
                             
;;;###skk-autoload
(defun skk-middle-list (org offset inserted)
  ;; ORG := '(A B C), INSERTED := '(X Y), OFFSET := 1
  ;; -> '(A B X Y C)
  (let (tmp tail)
    (if (>= 0 offset)
        (error "Cannot insert!") )
    (setq tmp (nthcdr (1- offset) org)
          tail (cdr tmp) )
    (setcdr tmp nil) ;cut off
    (setcdr tmp (if tail (nconc inserted tail) inserted))
    org ))

;;(defun skk-chomp (nth list)
;;  (let ((l (nthcdr (1- nth) list)))
;;    (setcdr l nil)
;;    list ))

;;(defun skk-cutoff-list (list offset)
;;  ;; LIST := '(A B C), OFFSET := 1
;;  ;; -> '(A B)
;;  (if (< 0 offset)
;;      (setcdr (nthcdr (1- offset) list) nil) )
;;  list )
  
(defun skk-henkan-face-on ()
  ;; skk-use-face $B$,(B non-nil $B$N>l9g!"(Bskk-henkan-start-point $B$H(B
  ;; skk-henkan-end-point $B$N4V$N(B face $BB0@-$r(B skk-henkan-face $B$NCM$KJQ99$9$k!#(B
  ;;
  ;; SKK 9.4 $B$h$j(B Text Properties $B$r;HMQ$9$k$N$r;_$a$F!"(BOverlays $B$r;HMQ$9$k$h(B
  ;; $B$&$K$7$?(B (egg.el, canna.el, wnn-egg.el $B$r;29M$K$7$?(B)$B!#(B
  ;; Overlays $B$O!"%F%-%9%H$N0lIt$G$O$J$$$N$G!"%P%C%U%!$+$iJ8;z$r@Z$j=P$7$F$b%3(B
  ;; $B%T!<$NBP>]$K$J$i$J$$$7!"%"%s%I%%;~$bL5;k$5$l$k$N$G!"JQ49$5$l$?8uJd$NI=<((B
  ;; $B$r0l;~E*$KJQ99$9$k$K$O(B Text Properties $B$h$j$b9%ET9g$G$"$k!#(B
  ;;
  ;; $BC"$7!"(BOverlays $B$O(B Text Properties $B$h$j07$$$KCm0U$9$Y$-E@$,$"$k!#(B
  ;; $B%*!<%P%l%$$NCf$N%^!<%+$rD>@\JQ99$7$F$7$^$&$H!"$[$+$N=EMW$J%G!<%?9=B$$N99(B
  ;; $B?7$,9T$o$l$:!"<:$o$l$k%*!<%P%l%$$,=P$k$3$H$K$J$j$+$M$J$$(B (Overlay $B$N(B
  ;; Buffer$B$NHO0O$rJQ99$9$k$H$-$O!"I,$:(B move-overlay $B$r;HMQ$7$J$1$l$P$J$i$J$$(B)
  ;; $B$H$$$&E@$G$"$k!#(Bskk-henkan-face-on $B$GJQ497k2L$N8uJd$K4X$9$k(B
  ;; skk-henkan-overlay $B$r?75,$K:n$C$F$+$i(B ($B$"$k$$$O4{B8$N(B Overlay $B$r3:Ev8D=j(B
  ;; $B$K0\F0$7$F$+$i(B) skk-henkan-face-off $B$G>C5n$9$k$^$G$N4V$K(B
  ;; skk-henkan-start-point $B$H(B skk-henkan-end-point $BCf$N%F%-%9%H$r:o=|$9$k$H!"(B
  ;; $B7k2LE*$K(B move-overlay $B$r;HMQ$;$:$=$l$i$N%^!<%+!<CM$r99?7$9$k$3$H$K$J$C$F(B
  ;; $B$7$^$&!#=>$$!"(Bskk-henkan-start-point $B$H(B skk-henkan-end-point $B$N4V$K$"$k%F(B
  ;; $B%-%9%H$KJQ99$r2C$($k$H$-$O!"@h$K(B skk-henkan-face-off $B$G0lC6(B
  ;; skk-henkan-overlay $B$r>C$9I,MW$,$"$k(B (<(skk-e19.el/kill-region)>)$B!#(B
  ;;
  ;;From: enami tsugutomo <enami@ba2.so-net.or.jp>
  ;;Subject: overlay (was Re: SKK-9.4.15)
  ;;Date: 23 Oct 1996 16:35:53 +0900
  ;;Message-ID: <87n2xe5e06.fsf@plants-doll.enami.ba2.so-net.or.jp>
  ;;
  ;;enami> $B4X?t(B skk-henkan-face-on $B$N(B comment $B$N(B
  ;;enami> 
  ;;enami>   ;; $BC"$7!"(BOverlays $B$O(B Text Properties $B$h$j07$$$KCm0U$9$Y$-E@$,$"$k!#(B
  ;;enami>   ;; $B%*!<%P%l%$$NCf$N%^!<%+$rD>@\JQ99$7$F$7$^$&$H!"$[$+$N=EMW$J%G!<%?9=B$$N99(B
  ;;enami>   ;; $B?7$,9T$o$l$:!"<:$o$l$k%*!<%P%l%$$,=P$k$3$H$K$J$j$+$M$J$$(B
  ;;enami> 
  ;;enami>  ($B5Z$S$=$l0J9_(B) $B$NItJ,$K4X$7$F$G$9$,(B, make-overlay $B$G0LCV$N;XDj$K;H$C(B
  ;;enami> $B$?(B marker $B$,$=$N$^$^(B overlay $B$N0lIt$H$7$F;H$o$l$k$H(B, $B8m2r$7$F$$$^$;$s(B
  ;;enami> $B$G$7$g$&$+(B?
  ;;enami> 
  ;;enami> $B<B:]$K$O(B overlay $B$N0lIt$r0Y$9(B marker $B$rD>@\0\F0$5$;$k$3$H$O$G$-$^$;$s(B
  ;;enami> $B$7(B, text $B$N:o=|DI2C$K$h$k0\F0$K$OBP=h$7$F$$$^$9$+$iLdBj$J$$$H;W$$$^$9(B.
  ;;enami> 
  ;;enami> # $B$=$&$G$J$+$C$?$i(B overlay $B$C$FL5Cc6lCc;H$$$E$i$$$b$N$K$J$C$F$7$^$$$^(B
  ;;enami> # $B$9(B.
  ;;enami> $B$($J$_(B
  (let ((inhibit-quit t)
        cbuf )
    (if (and skk-henkan-face
             (setq cbuf (current-buffer))
             (eq (marker-buffer skk-henkan-start-point) cbuf)
             (eq (marker-buffer skk-henkan-end-point) cbuf)
             (marker-position skk-henkan-start-point)
             (marker-position skk-henkan-end-point) )
        (progn
          (or skk-henkan-overlay
              (setq skk-henkan-overlay (skk-make-overlay skk-henkan-start-point
							 skk-henkan-end-point
							 cbuf )))
          (skk-move-overlay skk-henkan-overlay skk-henkan-start-point
			    skk-henkan-end-point cbuf )
          ;; evaporate $BB0@-$rIU$1$k$Y$-$+(B...$B!#$G$bJQ49$r7+$jJV$9$H$-$O!":FMxMQ(B
          ;; $B$9$k$N$@$+$i!"$`$7$m!"4{$K:n$C$F$"$kJ}$,NI$$$+$b!#(B
          (skk-overlay-put skk-henkan-overlay 'face skk-henkan-face) ))))

(defun skk-henkan-face-off ()
  ;; skk-henkan-start-point $B$H(B skk-henkan-end-point $B$N4V$NI=<($rJQ99$7$F$$$k(B
  ;; skk-henkan-overlay $B$r>C$9!#(B
  (and skk-henkan-face
       ;; $B%j%+!<%7%V%_%K%P%C%U%!$KF~$C$?$H$-$O!"(Boverlayp $B$K$h$k8!::$,I,MW!)(B
       (skk-overlayp skk-henkan-overlay)
       (skk-delete-overlay skk-henkan-overlay) ))

(defun skk-set-cursor-color (color)
  ;; $B%+!<%=%k$N?'$r(B COLOR $B$KJQ99$9$k!#(B
  (if skk-use-color-cursor
      (condition-case nil
	  (set-cursor-color color)
	(error
	 (set-cursor-color skk-default-cursor-color)
	 (if skk-report-set-cursor-error
	     (skk-message
              "$B%+%i!<%^%C%W@Z$l$G$9!#%G%#%U%)%k%H$N%+%i!<$r;H$$$^$9!#(B"
              "Color map is exhausting, use default cursor color" ))))))

;;;###skk-autoload
(defun skk-set-cursor-properly ()
  ;; $B%+%l%s%H%P%C%U%!$N(B SKK $B$N%b!<%I$K=>$$!"%+!<%=%k$N?'$rJQ99$9$k!#(B
  (if skk-use-color-cursor
      (if (not skk-mode)
	  (skk-set-cursor-color skk-default-cursor-color)
	(skk-set-cursor-color (cond (skk-zenkaku-mode skk-zenkaku-cursor-color)
				    (skk-katakana skk-katakana-cursor-color)
				    (skk-j-mode skk-hirakana-cursor-color)
				    (t skk-ascii-cursor-color) ))))
  (if skk-use-cursor-change
      (skk-change-cursor-when-ovwrt) ))

;;;###skk-autoload
(defun skk-change-cursor-when-ovwrt ()
  (if skk-xemacs
      (setq bar-cursor overwrite-mode)
    (if overwrite-mode
        (modify-frame-parameters (selected-frame) '((cursor-type bar . 3)))
      (modify-frame-parameters (selected-frame) '((cursor-type . box))) )))

;;;###skk-autoload
(defun skk-make-face (face)
  ;; hilit-lookup-face-create $B$N%5%V%;%C%H!#(Btutorial $B$G?'IU$1$r9T$J$&>l9g$G$b(B
  ;; hilit19 $B$K0MB8$;$:$H$j$"$($:(B face $B$r<+A0$G:n$k$3$H$,$G$-$k$h$&$K!"$H$$$&(B
  ;; $BL\E*$G:n$C$?$b$N$G!"4JC1$J?'IU$1$7$J$G$-$J$$!#$"$^$j8-$/$O$J$$!#J#;($J(B
  ;; face $B$r:n$j$?$$?M$O(B hilit-lookup-face-create $BEy$r;H$C$F2<$5$$!#(B
  (or (car (memq face (face-list)))
      (let ((face-name (symbol-name face))
            fore back )
        (setq face (make-face face))
        (save-match-data
          (if (not (string-match "/" face-name))
              (set-face-foreground face face-name)
            (set-face-foreground
             face
             (substring face-name 0 (match-beginning 0)) )
            (set-face-background
             face
             (substring face-name (1+ (match-beginning 0))) ))
          face ))))
                        
;;(defun skk-reinvoke ()
;;  (let ((original-status
;;         (cond (skk-katakana 'katakana)
;;               (skk-zenkaku-mode 'zenkaku)
;;               (skk-j-mode 'hirakana)
;;               (skk-mode 'ascii)
;;               (t 'unkown) )))
;;    (skk-mode 1)
;;    (cond ((eq original-status 'katakana)
;;           (setq skk-katakana t) )
;;          ((eq original-status 'zenkaku)
;;           (setq skk-zenkaku-mode t) )
;;          ((eq original-status 'ascii)
;;           (setq skk-j-mode nil) )
;;          ((eq original-status 'hirakana)) )
;;    (skk-kakutei) ))

(add-hook 'edit-picture-hook 'skk-misc-for-picture 'append)
(add-hook 'skk-before-kill-emacs-hook
          (function (lambda ()
                      (if skk-menu-modified-user-option
                          (skk-menu-save-modified-user-option) ))))
(add-hook 'after-make-frame-hook 'skk-set-cursor-properly)
(add-hook 'minibuffer-setup-hook
          (function (lambda () (skk-set-cursor-properly))) )

(add-hook 'minibuffer-exit-hook
          (function
           (lambda ()
             (remove-hook 'minibuffer-setup-hook 'skk-setup-minibuffer)
             (skk-set-cursor-properly) )))

(run-hooks 'skk-load-hook)

(provide 'skk)
;;; skk.el ends here
