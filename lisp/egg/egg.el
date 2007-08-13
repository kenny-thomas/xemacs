;; Japanese Character Input Package for Egg
;; Coded by S.Tomura, Electrotechnical Lab. (tomura@etl.go.jp)

;; This file is part of Egg on Mule (Multilingal Environment)

;; Egg is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; Egg is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;;==================================================================
;;;
;;; $BF|K\8l4D6-(B $B!V$?$^$4!W(B $BBh#3HG(B    
;;;
;;;=================================================================== 

;;;
;;;$B!V$?$^$4!W$O%M%C%H%o!<%/$+$J4A;zJQ49%5!<%P$rMxMQ$7!"(BMule $B$G$NF|K\(B
;;; $B8l4D6-$rDs6!$9$k%7%9%F%`$G$9!#!V$?$^$4!WBh#2HG$G$O(B Wnn V3 $B$*$h$S(B 
;;; Wnn V4 $B$N$+$J4A;zJQ49%5!<%P$r;HMQ$7$F$$$^$9!#(B
;;;

;;; $BL>A0$O(B $B!VBt;3(B/$BBT$?$;$F(B/$B$4$a$s$J$5$$!W$N3FJ8@a$N@hF,#12;$G$"$k!V$?!W(B
;;; $B$H!V$^!W$H!V$4!W$r<h$C$F!"!V$?$^$4!W$H8@$$$^$9!#EE;R5;=QAm9g8&5f=j(B
;;; $B$N6S8+(B $BH~5.;R;a$NL?L>$K0M$k$b$N$G$9!#(Begg $B$O!V$?$^$4!W$N1QLu$G$9!#(B

;;;
;;; $B;HMQK!$O(B info/egg-jp $B$r8+$F2<$5$$!#(B
;;;

;;;
;;; $B!V$?$^$4!W$K4X$9$kDs0F!"Cn>pJs$O(B tomura@etl.go.jp $B$K$*Aw$j2<$5$$!#(B
;;;

;;;
;;;                      $B")(B 305 $B0q>k8)$D$/$P;TG_1`(B1-1-4
;;;                      $BDL;:>J9)6H5;=Q1!EE;R5;=QAm9g8&5f=j(B
;;;                      $B>pJs%"!<%-%F%/%A%cIt8@8l%7%9%F%`8&5f<<(B
;;;
;;;                                                     $B8MB<(B $BE/(B  

;;;
;;; ($BCm0U(B)$B$3$N%U%!%$%k$O4A;z%3!<%I$r4^$s$G$$$^$9!#(B 
;;;
;;;   $BBh#3HG(B  $B#1#9#9#1G/#27n(B  $B#4F|(B
;;;   $BBh#2HG(B  $B#1#9#8#9G/#67n(B  $B#1F|(B
;;;   $BBh#1HG(B  $B#1#9#8#8G/#77n#1#4F|(B
;;;   $B;CDjHG(B  $B#1#9#8#8G/#67n#2#4F|(B

;;;=================================================================== 
;;;
;;; (eval-when (load) (require 'wnn-client))
;;;

; last master version
;;; (defvar egg-version "3.09" "Version number of this version of Egg. ")
;;; Last modified date: Fri Sep 25 12:59:00 1992
(defvar egg-version "3.09 xemacs" "Version number of this version of Egg. ")
;;; Last modified date: Wed Feb 05 20:45:00 1997

;;;;  $B=$@5MW5a%j%9%H(B

;;;;  read-hiragana-string, read-kanji-string $B$G;HMQ$9$kJ?2>L>F~NO%^%C%W$r(B roma-kana $B$K8GDj$7$J$$$GM_$7$$!%(B

;;;;  $B=$@5%a%b(B

;;; 97.2.05 modified by J.Hein <jhod@po.iijnet.or.jp>
;;; Lots of mods to make it XEmacs workable. Most fixes revolve around the fact that
;;; Mule/et al assumes that all events are keypress events unless specified otherwise.
;;; Also modified to work with the new charset names and API

;;; 95.6.5 modified by S.Tomura <tomura@etl.go.jp>
;;; $BJQ49D>8e$KO"B3$7$FJQ49$9$k>l9g$rG'<1$9$k$?$a$K!"(B"-in-cont" $B$K4XO"$7$?(B
;;; $BItJ,$rDI2C$7$?!#!J$3$NItJ,$O>-Mh:F=$@5$9$kM=Dj!#!K(B

;;; 93.6.19  modified by T.Shingu <shingu@cpr.canon.co.jp>
;;; egg:*in-fence-mode* should be buffer local.

;;; 93.6.4   modified by T.Shingu <shingu@cpr.canon.co.jp>
;;; In its-defrule**, length is called instead of chars-in-string.

;;; 93.3.15  modified by T.Enami <enami@sys.ptg.sony.co.jp>
;;; egg-self-insert-command simulates the original more perfectly.

;;; 92.12.20 modified by S.Tomura <tomura@etl.go.jp>
;;; In its:simulate-input, sref is called instead of aref.

;;; 92.12.20 modified by T.Enami <enami@sys.ptg.sony.co.jp>
;;; egg-self-insert-command calls cancel-undo-boundary to simulate original.

;;; 92.11.4 modified by M.Higashida <manabu@sigmath.osaka-u.ac.jp>
;;; read-hiragana-string sets minibuffer-preprompt correctly.

;;; 92.10.26, 92.10.30 modified by T.Saneto sanewo@pdp.crl.sony.co.jp
;;; typo fixed.

;;; 92.10.18 modified by K. Handa <handa@etl.go.jp>
;;; special-symbol-input $BMQ$N%F!<%V%k$r(B autoload $B$K!#(B
;;; busyu.el $B$N(B autoload $B$N;XDj$r(B mule-init.el $B$+$i(B egg.el $B$K0\$9!#(B

;;;  92.9.20 modified by S. Tomura
;;;; hiragana-region $B$NCn$N=$@5(B

;;;; 92.9.19 modified by Y. Kawabe
;;;; some typos

;;;; 92.9.19 modified by Y. Kawabe<kawabe@sramhc.sra.co.jp>
;;;; menu $B$NI=<(4X78$N(B lenght $B$r(B string-width $B$KCV$-49$($k!%(B

;;; 92.8.19 modified for Mule Ver.0.9.6 by K.Handa <handa@etl.go.jp>
;;;; menu:select-from-menu calls string-width instead of length.

;;;; 92.8.1 modified by S. Tomura
;;;; internal mode $B$rDI2C!%(Bits:*internal-mode-alist* $BDI2C!%(B

;;;; 92.7.31 modified by S. Tomura
;;;; its-mode-map $B$,(B super mode map $B$r;}$D$h$&$KJQ99$7$?!%$3$l$K$h$j(B 
;;;; mode map $B$,6&M-$G$-$k!%(B its-define-mode, get-next-map $B$J$I$rJQ99!%(B 
;;;; get-next-map-locally $B$rDI2C!%(Bits-defrule** $B$rJQ99!%(B

;;;; 92.7.31 modified by S. Tomura
;;;; its:make-kanji-buffer , its:*kanji* $B4XO"%3!<%I$r:o=|$7$?!%(B

;;;; 92.7.31 modified by S. Tomura
;;;;  egg:select-window-hook $B$r=$@5$7!$(Bminibuffer $B$+$i(B exit $B$9$k$H$-$K!$(B 
;;;; $B3F<oJQ?t$r(B default-value $B$KLa$9$h$&$K$7$?!%$3$l$K$h$C$F(B 
;;;; minibufffer $B$KF~$kA0$K3F<o@_Dj$,2DG=$H$J$k!%(B

;;; 92.7.14  modified for Mule Ver.0.9.5 by T.Ito <toshi@his.cpl.melco.co.jp>
;;;	Attribute bold can be used.
;;;	Unnecessary '*' in comments of variables deleted.
;;; 92.7.8   modified for Mule Ver.0.9.5 by Y.Kawabe <kawabe@sra.co.jp>
;;;	special-symbol-input keeps the position selected last.
;;; 92.7.8   modified for Mule Ver.0.9.5 by T.Shingu <shingu@cpr.canon.co.jp>
;;;	busyu-input and kakusuu-input are added in *symbol-input-menu*.
;;; 92.7.7   modified for Mule Ver.0.9.5 by K.Handa <handa@etl.go.jp>
;;;	In egg:quit-mode, overwrite-mode is supported correctly.
;;;	egg:*overwrite-mode-deleted-chars* is not used now.
;;; 92.6.26  modified for Mule Ver.0.9.5 by K.Handa <handa@etl.go.jp>
;;;	Funtion dump-its-mode-map gets obsolete.
;;; 92.6.26  modified for Mule Ver.0.9.5 by M.Shikida <shikida@cs.titech.ac.jp>
;;;	Backquote ` is registered in *hankaku-alist* and *zenkaku-alist*.
;;; 92.6.17  modified for Mule Ver.0.9.5 by T.Shingu <shingu@cpr.canon.co.jp>
;;;	Bug in make-jis-second-level-code-alist fixed.
;;; 92.6.14  modified for Mule Ver.0.9.5 by T.Enami <enami@sys.ptg.sony.co.jp>
;;;	menu:select-from-menu is replaced with new version.
;;; 92.5.18  modified for Mule Ver.0.9.4 by T.Shingu <shingu@cpr.canon.co.jp>
;;;	lisp/wnn-egg.el is devided into two parts: this file and wnn*-egg.el.

;;;;
;;;; Mule Ver.0.9.3 $B0JA0(B
;;;;

;;;; April-15-92 for Mule Ver.0.9.3
;;;;	by T.Enami <enami@sys.ptg.sony.co.jp> and K.Handa <handa@etl.go.jp>
;;;;	notify-internal calls 'message' with correct argument.

;;;; April-11-92 for Mule Ver.0.9.3
;;;;	by T.Enami <enami@sys.ptg.sony.co.jp> and K.Handa <handa@etl.go.jp>
;;;;	minibuffer $B$+$iH4$1$k;~(B egg:select-window-hook $B$G(B egg:*input-mode* $B$r(B
;;;;	t $B$K$9$k!#(Bhook $B$N7A$rBgI}=$@5!#(B

;;;; April-3-92 for Mule Ver.0.9.2 by T.Enami <enami@sys.ptg.sony.co.jp>
;;;; minibuffer $B$+$iH4$1$k;~(B egg:select-window-hook $B$,(B new-buffer $B$N(B
;;;; egg:*mode-on* $B$J$I$r(B nil $B$K$7$F$$$k$N$r=$@5!#(B

;;;; Mar-22-92 by K.Handa
;;;; etags $B$,:n$k(B TAGS $B$KITI,MW$J$b$N$rF~$l$J$$$h$&$K$9$k$?$a4X?tL>JQ99(B
;;;; define-its-mode -> its-define-mode, defrule -> its-defrule

;;;; Mar-16-92 by K.Handa
;;;; global-map $B$X$N(B define-key $B$r(B mule-keymap $B$KJQ99!#(B

;;;; Mar-13-92 by K.Handa
;;;; Language specific part $B$r(B japanese.el,... $B$K0\$7$?!#(B

;;;; Feb-*-92 by K. Handa
;;;; nemacs 4 $B$G$O(B minibuffer-window-selected $B$,GQ;_$K$J$j!$4XO"$9$k%3!<%I$r:o=|$7$?!%(B

;;;; Jan-13-92 by S. Tomura
;;;; mc-emacs or nemacs 4 $BBP1~:n6H3+;O!%(B

;;;; Aug-9-91 by S. Tomura
;;;; ?\^ $B$r(B ?^ $B$K=$@5!%(B

;;;;  menu $B$r(B key map $B$r8+$k$h$&$K$9$k!%(B

;;;;  Jul-6-91 by S. Tomura
;;;;  setsysdict $B$N(B error $B%a%C%;!<%8$rJQ99!%(B

;;;;  Jun-11-91 by S. Tomura
;;;;  its:*defrule-verbose* $B$rDI2C!%(B
;;;;

;;;;  Mar-25-91 by S. Tomura
;;;;  reset-its-mode $B$rGQ;_(B

;;;;  Mar-23-91 by S. Tomura
;;;;  read-hiragana-string $B$r=$@5!$(B read-kanji-string $B$rDI2C!$(B
;;;;  isearch:read-kanji-string $B$r@_Dj!%(B

;;;;  Mar-22-91 by S. Tomura
;;;;  defrule-conditional, defrule-select-mode-temporally $B$rDI2C!#(B
;;;;  for-each $B$N4J0WHG$H$7$F(B dolist $B$rDI2C!#(B
;;;;  enable-double-n-syntax $B$r3hMQ!%$[$+$K(B use-kuten-for-comma, use-touten-for-period $B$rDI2C(B

;;;;  Mar-5-91 by S. Tomura
;;;;  roma-kana-word, henkan-word, roma-kanji-word $B$rDI2C$7$?!%(B

;;;;  Jan-14-91 by S. Tomura
;;;;  $BF~NOJ8;zJQ497O(B ITS(Input character Translation System) $B$r2~B$$9$k!%(B
;;;;  $BJQ49$O:G:8:GD9JQ49$r9T$J$$!$JQ49$N$J$$$b$N$O$b$H$N$^$^$H$J$k!%(B
;;;;  $B2~B$$NF05!$ON)LZ!w7D1~$5$s$N%O%s%0%kJ8;z$NF~NOMW5a$G$"$k!%(B
;;;;  its:* $B$rDI2C$7$?!%$^$?=>Mh(B fence-self-insert-command $B$H(B roma-kana-region 
;;;;  $BFs2U=j$K$o$+$l$F$$$?%3!<%I$r(B its:translate-region $B$K$h$C$F0lK\2=$7$?!%(B

;;;;  July-30-90 by S. Tomura
;;;;  henkan-region $B$r(Boverwrite-mode $B$KBP1~$5$;$k!%JQ?t(B 
;;;;  egg:*henkan-fence-mode*, egg:*overwrite-mode-deleted-chars*
;;;;  $B$rDI2C$7!$(Bhenkan-fence-region, henkan-region-internal, 
;;;;  quit-egg-mode $B$rJQ99$9$k!%(B

;;;;  Mar-4-90 by K.Handa
;;;;  New variable alphabet-mode-indicator, transparent-mode-indicator,
;;;;  and henkan-mode-indicator.

;;;;  Feb-27-90 by enami@ptgd.sony.co.jp
;;;;  menu:select-from-menu $B$G#22U=j$"$k(B ((and (<= ?0 ch) (<= ch ?9)...
;;;;  $B$N0lJ}$r(B ((and (<= ?0 ch) (<= ch ?9)... $B$K=$@5(B

;;;;  Feb-07-89
;;;;  bunsetu-length-henko $B$NCf$N(B egg:*attribute-off $B$N0LCV$r(B KKCP $B$r8F$VA0$K(B
;;;;  $BJQ99$9$k!#(B wnn-client $B$G$O(B KKCP $B$r8F$V$HJ8@a>pJs$,JQ2=$9$k!#(B

;;;;  Feb-01-89
;;;;  henkan-goto-kouho $B$N(B egg:set-bunsetu-attribute $B$N0z?t(B
;;;;  $B$N=gHV$,4V0c$C$F$$$?$N$r=$@5$7$?!#!J(Btoshi@isvax.isl.melco.co.jp
;;;;  (Toshiyuki Ito)$B$N;XE&$K$h$k!#!K(B

;;;;  Dec-25-89
;;;;  meta-flag t $B$N>l9g$NBP1~$r:F=$@5$9$k!#(B
;;;;  overwrite-mode $B$G$N(B undo $B$r2~A1$9$k!#(B

;;;;  Dec-21-89
;;;;  bug fixed by enami@ptdg.sony.co.jp
;;;;     (fboundp 'minibuffer-window-selected )
;;;;  -->(boundp  'minibuffer-window-selected )
;;;;  self-insert-after-hook $B$r(B buffer local $B$K$7$FDj5A$r(B kanji.el $B$X0\F0!#(B

;;;;  Dec-15-89
;;;;  kill-all-local-variables $B$NDj5A$r(B kanji.el $B$X0\F0$9$k!#(B

;;;;  Dec-14-89
;;;;  meta-flag t $B$N>l9g$N=hM}$r=$@5$9$k(B
;;;;  overwrite-mode $B$KBP1~$9$k!#(B

;;;;  Dec-12-89
;;;;  egg:*henkan-open*, egg:*henkan-close* $B$rDI2C!#(B
;;;;  egg:*henkan-attribute* $B$rDI2C(B
;;;;  set-egg-fence-mode-format, set-egg-henkan-mode-format $B$rDI2C(B

;;;;  Dec-12-89
;;;;  *bunpo-code* $B$K(B 1000: "$B$=$NB>(B" $B$rDI2C(B

;;;;  Dec-11-89
;;;;  egg:*fence-attribute* $B$r?7@_(B
;;;;  egg:*bunsetu-attribute* $B$r?7@_(B

;;;;  Dec-11-89
;;;;  attribute-*-region $B$rMxMQ$9$k$h$&$KJQ99$9$k!#(B
;;;;  menu:make-selection-list $B$O(B width $B$,>.$5$$;~$K(Bloop $B$9$k!#$3$l$r=$@5$7$?!#(B

;;;;  Dec-10-89
;;;;  set-marker-type $B$rMxMQ$9$kJ}<0$KJQ99!#(B

;;;;  Dec-07-89
;;;;  egg:search-path $B$rDI2C!#(B
;;;;  egg-default-startup-file $B$rDI2C$9$k!#(B

;;;;  Nov-22-89
;;;;  egg-startup-file $B$rDI2C$9$k!#(B
;;;;  eggrc-search-path $B$r(B egg-startup-file-search-path $B$KL>A0JQ99!#(B

;;;;  Nov-21-89
;;;;  Nemacs 3.2 $B$KBP1~$9$k!#(Bkanji-load* $B$rGQ;_$9$k!#(B
;;;;  wnnfns.c $B$KBP1~$7$?=$@5$r2C$($k!#(B
;;;;  *Notification* buffer $B$r8+$($J$/$9$k!#(B

;;;;  Oct-2-89
;;;;  *zenkaku-alist* $B$N(B $BJ8;zDj?t$N=q$-J}$,4V0c$C$F$$$?!#(B

;;;;  Sep-19-89
;;;;  toggle-egg-mode $B$N=$@5!J(Bkanji-flag$B!K(B
;;;;  egg-self-insert-command $B$N=$@5(B $B!J(Bkanji-flag$B!K(B

;;;;  Sep-18-89
;;;;  self-insert-after-hook $B$NDI2C(B

;;;;  Sep-15-89
;;;;  EGG:open-wnn bug fix
;;;;  provide wnn-egg feature

;;;;  Sep-13-89
;;;;  henkan-kakutei-before-point $B$r=$@5$7$?!#(B
;;;;  enter-fence-mode $B$NDI2C!#(B
;;;;  egg-exit-hook $B$NDI2C!#(B
;;;;  henkan-region-internal $B$NDI2C!#(Bhenkan-region$B$O(B point $B$r(Bmark $B$9$k!#(B
;;;;  eggrc-search-path $B$NDI2C!#(B

;;;;  Aug-30-89
;;;;  kanji-kanji-1st $B$rD{@5$7$?!#(B

;;;;  May-30-89
;;;;  EGG:open-wnn $B$O(B get-wnn-host-name $B$,(B nil $B$N>l9g!"(B(system-name) $B$r;HMQ$9$k!#(B

;;;;  May-9-89
;;;;  KKCP:make-directory added.
;;;;  KKCP:file-access bug fixed.
;;;;  set-default-usr-dic-directory modified.

;;;;  Mar-16-89
;;;;  minibuffer-window-selected $B$r;H$C$F(B minibuffer $B$N(B egg-mode$BI=<(5!G=DI2C(B

;;;;  Mar-13-89
;;;;   mode-line-format changed. 

;;;;  Feb-27-89
;;;;  henkan-saishou-bunsetu added
;;;;  henkan-saichou-bunsetu added
;;;;  M-<    henkan-saishou-bunsetu
;;;;  M->    henkan-saichou-bunsetu

;;;;  Feb-14-89
;;;;   C-h in henkan mode: help-command added

;;;;  Feb-7-89
;;;;   egg-insert-after-hook is added.

;;;;   M-h   fence-hiragana
;;;;   M-k   fence-katakana
;;;;   M->   fence-zenkaku
;;;;   M-<   fence-hankaku

;;;;  Dec-19-88 henkan-hiragana, henkan-katakara$B$rDI2C!'(B
;;;;    M-h     henkan-hiragana
;;;;    M-k     henkan-katakana

;;;;  Ver. 2.00 kana2kanji.c $B$r;H$o$:(B wnn-client.el $B$r;HMQ$9$k$h$&$KJQ99!#(B
;;;;            $B4XO"$7$F0lIt4X?t$rJQ99(B

;;;;  Dec-2-88 special-symbol-input $B$rDI2C!((B
;;;;    C-^   special-symbol-input

;;;;  Nov-18-88 henkan-mode-map $B0lItJQ99!((B
;;;;    M-i  henkan-inspect-bunsetu
;;;;    M-s  henkan-select-kouho
;;;;    C-g  henkan-quit

;;;;  Nov-18-88 jserver-henkan-kakutei $B$N;EMMJQ99$KH<$$!"(Bkakutei $B$N%3!<(B
;;;;  $B%I$rJQ99$7$?!#(B

;;;;  Nov-17-88 kakutei-before-point $B$G(B point $B0J9_$N4V0c$C$?ItJ,$NJQ49(B
;;;;  $B$,IQEY>pJs$KEPO?$5$l$J$$$h$&$K=$@5$7$?!#$3$l$K$O(BKKCC:henkan-end 
;;;;  $B$N0lIt;EMM$HBP1~$9$k(Bkana2kanji.c$B$bJQ99$7$?!#(B

;;;;  Nov-17-88 henkan-inspect-bunsetu $B$rDI2C$7$?!#(B

;;;;  Nov-17-88 $B?7$7$$(B kana2kanji.c $B$KJQ99$9$k!#(B

;;;;  Sep-28-88 defrule$B$,CM$H$7$F(Bnil$B$rJV$9$h$&$KJQ99$7$?!#(B

;;;;  Aug-25-88 $BJQ493X=,$r@5$7$/9T$J$&$h$&$KJQ99$7$?!#(B
;;;;  KKCP:henkan-kakutei$B$O(BKKCP:jikouho-list$B$r8F$s$@J8@a$KBP$7$F$N$_E,(B
;;;;  $BMQ$G$-!"$=$l0J30$N>l9g$N7k2L$OJ]>Z$5$l$J$$!#$3$N>r7o$rK~$?$9$h$&(B
;;;;  $B$K(BKKCP:jikouho-list$B$r8F$s$G$$$J$$J8@a$KBP$7$F$O(B
;;;;  KKCP:henkan-kakutei$B$r8F$P$J$$$h$&$K$7$?!#(B

;;;;  Aug-25-88 egg:do-auto-fill $B$r=$@5$7!"J#?t9T$K$o$?$k(Bauto-fill$B$r@5(B
;;;;  $B$7$/9T$J$&$h$&$K=$@5$7$?!#(B

;;;;  Aug-25-88 menu command$B$K(B\C-l: redraw $B$rDI2C$7$?!#(B

;;;;  Aug-25-88 toroku-region$B$GEPO?$9$kJ8;zNs$+$i(Bno graphic character$B$r(B
;;;;  $B<+F0E*$K=|$/$3$H$K$7$?!#(B

(provide 'egg)

;; XEmacs addition: (and remove disable-undo variable)
;; For Emacs V18/Nemacs compatibility
(and (not (fboundp 'buffer-disable-undo))
     (fboundp 'buffer-flush-undo)
     (defalias 'buffer-disable-undo 'buffer-flush-undo))

;; 97.2.4 Created by J.Hein to simulate Mule-2.3
(defun read-event ()
  "Cheap 'n cheesy event filter to facilitate translation from Mule-2.3"
  (let ((event (make-event)))
    (while (progn
	     (next-event event)
	     (not (key-press-event-p event)))
      (dispatch-event event))
    (event-key event)))

(eval-when-compile (require 'egg-jsymbol))

;;;----------------------------------------------------------------------
;;;
;;; Version control routine
;;;
;;;----------------------------------------------------------------------

(and (equal (user-full-name) "Satoru Tomura")
     (defun egg-version-update (arg)
       (interactive "P")
       (if (equal (buffer-name (current-buffer)) "wnn-egg.el")
	   (save-excursion
	    (goto-char (point-min))
	    (re-search-forward "(defvar egg-version \"[0-9]+\\.")
	    (let ((point (point))
		  (minor))
	      (search-forward "\"")
	      (backward-char 1)
	      (setq minor (string-to-int (buffer-substring point (point))))
	      (delete-region point (point))
	      (if (<= minor 8) (insert "0"))
	      (insert  (int-to-string (1+ minor)))
	      (search-forward "Egg last modified date: ")
	      (kill-line)
	      (insert (current-time-string)))
	    (save-buffer)
	    (if arg (byte-compile-file (buffer-file-name)))
	 )))
     )
;;;
;;;----------------------------------------------------------------------
;;;
;;; Utilities
;;;
;;;----------------------------------------------------------------------

;;; 
;;;;

(defun coerce-string (form)
  (cond((stringp form) form)
       ((characterp form) (char-to-string form))))

(defun coerce-internal-string (form)
  (cond((stringp form)
	(if (= (length form) 1) 
	    (string-to-char form)
	  form))
       ((characterp form) form)))

;;; kill-all-local-variables $B$+$iJ]8n$9$k(B local variables $B$r;XDj$G$-$k(B
;;; $B$h$&$KJQ99$9$k!#(B

(put 'egg:*input-mode* 'permanent-local t)
(put 'egg:*mode-on* 'permanent-local t)
(put 'its:*current-map* 'permanent-local t)
(put 'mode-line-egg-mode 'permanent-local t)

;;;----------------------------------------------------------------------
;;;
;;; 16$B?JI=8=$N(BJIS $B4A;z%3!<%I$r(B minibuffer $B$+$iFI$_9~$`(B
;;;
;;;----------------------------------------------------------------------

;;;
;;; User entry:  jis-code-input
;;;

(defun jis-code-input ()
  (interactive)
  (insert-jis-code-from-minibuffer "JIS $B4A;z%3!<%I(B(16$B?J?tI=8=(B): "))

(defun insert-jis-code-from-minibuffer (prompt)
  (let ((str (read-from-minibuffer prompt)) val)
    (while (null (setq val (read-jis-code-from-string str)))
      (beep)
      (setq str (read-from-minibuffer prompt str)))
    (insert (make-char (find-charset 'japanese-jisx0208) (car val) (cdr val)))))

(defun hexadigit-value (ch)
  (cond((and (<= ?0 ch) (<= ch ?9))
	(- ch ?0))
       ((and (<= ?a ch) (<= ch ?f))
	(+ (- ch ?a) 10))
       ((and (<= ?A ch) (<= ch ?F))
	(+ (- ch ?A) 10))))

(defun read-jis-code-from-string (str)
  (if (and (= (length str) 4)
	   (<= 2 (hexadigit-value (aref str 0)))
	   (hexadigit-value (aref str 1))
	   (<= 2 (hexadigit-value (aref str 2)))
	   (hexadigit-value (aref str 3)))
  (cons (+ (* 16 (hexadigit-value (aref str 0)))
	       (hexadigit-value (aref str 1)))
	(+ (* 16 (hexadigit-value (aref str 2)))
	   (hexadigit-value (aref str 3))))))

;;;----------------------------------------------------------------------	
;;;
;;; $B!V$?$^$4!W(B Notification System
;;;
;;;----------------------------------------------------------------------

(defconst *notification-window* " *Notification* ")

;;;(defmacro notify (str &rest args)
;;;  (list 'notify-internal
;;;	(cons 'format (cons str args))))

(defun notify (str &rest args)
  (notify-internal (apply 'format (cons str args))))

(defun notify-internal (message &optional noerase)
  (save-excursion
    (let ((notify-buff (get-buffer-create *notification-window*)))
      (set-buffer notify-buff)
      (goto-char (point-max))
      (setq buffer-read-only nil)
      (insert (substring (current-time-string) 4 19) ":: " message ?\n )
      (setq buffer-read-only t)
      (bury-buffer notify-buff)
      (message "%s" message)		; 92.4.15 by T.Enami
      (if noerase nil
	(sleep-for 1) (message "")))))

;;;(defmacro notify-yes-or-no-p (str &rest args)
;;;  (list 'notify-yes-or-no-p-internal 
;;;	(cons 'format (cons str args))))

(defun notify-yes-or-no-p (str &rest args)
  (notify-yes-or-no-p-internal (apply 'format (cons str args))))

(defun notify-yes-or-no-p-internal (message)
  (save-window-excursion
    (pop-to-buffer *notification-window*)
    (goto-char (point-max))
    (setq buffer-read-only nil)
    (insert (substring (current-time-string) 4 19) ":: " message ?\n )
    (setq buffer-read-only t)
    (yes-or-no-p "$B$$$$$G$9$+!)(B")))

(defun notify-y-or-n-p (str &rest args)
  (notify-y-or-n-p-internal (apply 'format (cons str args))))

(defun notify-y-or-n-p-internal (message)
  (save-window-excursion
    (pop-to-buffer *notification-window*)
    (goto-char (point-max))
    (setq buffer-read-only nil)
    (insert (substring (current-time-string) 4 19) ":: " message ?\n )
    (setq buffer-read-only t)
    (y-or-n-p "$B$$$$$G$9$+!)(B")))

(defun select-notification ()
  (interactive)
  (pop-to-buffer *notification-window*)
  (setq buffer-read-only t))

;;;----------------------------------------------------------------------
;;;
;;; $B!V$?$^$4!W(B Menu System
;;;
;;;----------------------------------------------------------------------

;;;
;;;  minibuffer $B$K(B menu $B$rI=<(!&A*Br$9$k(B
;;;

;;;
;;; menu $B$N;XDjJ}K!!'(B
;;;
;;; <menu item> ::= ( menu <prompt string>  <menu-list> )
;;; <menu list> ::= ( <menu element> ... )
;;; <menu element> ::= ( <string> . <value> ) | <string>
;;;                    ( <char>   . <value> ) | <char>

;;; select-menu-in-minibuffer

(defvar menu:*select-items* nil)
(defvar menu:*select-menus* nil)
(defvar menu:*select-item-no* nil)
(defvar menu:*select-menu-no* nil)
(defvar menu:*select-menu-stack* nil)
(defvar menu:*select-start* nil)
(defvar menu:*select-positions* nil)

(defvar menu-mode-map (make-keymap))

(define-key menu-mode-map "\C-a" 'menu:begining-of-menu)
(define-key menu-mode-map "\C-e" 'menu:end-of-menu)
(define-key menu-mode-map "\C-f" 'menu:next-item)
(define-key menu-mode-map "\C-b" 'menu:previous-item)
(define-key menu-mode-map "\C-n" 'menu:next-item-old)
(define-key menu-mode-map "\C-g" 'menu:quit)
(define-key menu-mode-map "\C-p" 'menu:previous-item-old)
(define-key menu-mode-map "\C-l" 'menu:refresh)
;;; 0 .. 9 a .. z A .. z
(define-key menu-mode-map "\C-m" 'menu:select)
(define-key menu-mode-map [return] 'menu:select)
(define-key menu-mode-map [left] 'menu:previous-item)
(define-key menu-mode-map [right] 'menu:next-item)
(define-key menu-mode-map [up] 'menu:previous-item-old)
(define-key menu-mode-map [down] 'menu:next-item-old)

;; 92.6.14 by T.Enami -- This function was completely modified.
(defun menu:select-from-menu (menu &optional initial position)
  (let ((echo-keystrokes 0)
	(inhibit-quit t)
	(menubuffer (get-buffer-create " *menu*"))
	(minibuffer (window-buffer (minibuffer-window)))
	value)
    (save-window-excursion
      (if (fboundp 'redirect-frame-focus)
	  (redirect-frame-focus (selected-frame)
				(window-frame (minibuffer-window))))
      (set-window-buffer (minibuffer-window) menubuffer)
      (select-window (minibuffer-window))
      (set-buffer menubuffer)
      (delete-region (point-min) (point-max))
      (insert (nth 1 menu))
      (let* ((window-width (window-width (selected-window)))
	     (finished nil))
	(setq menu:*select-menu-stack* nil
	      menu:*select-positions* nil
	      menu:*select-start* (point)
	      menu:*select-menus*
	      (menu:make-selection-list (nth 2 menu)
					(- window-width  
					   ;;; 92.8.19 by K.Handa
					   (string-width (nth 1 menu)))))
	;; 92.7.8 by Y.Kawabe
	(cond
	 ((and (numberp initial)
	       (<= 0 initial)
	       (< initial (length (nth 2 menu))))
	  (menu:select-goto-item-position initial))
	 ((and (listp initial) (car initial)
	       (<= 0 (car initial))
	       (< (car initial) (length (nth 2 menu))))
	  (menu:select-goto-item-position (car initial))
	  (while (and (setq initial (cdr initial))
		      (setq value (menu:item-value (nth menu:*select-item-no* 
							menu:*select-items*)))
		      (listp value) (eq (car value) 'menu))
	    (setq menu:*select-positions*
		  (cons (menu:select-item-position) menu:*select-positions*))
	    (setq menu:*select-menu-stack*
		  (cons (list menu:*select-items* menu:*select-menus*
			      menu:*select-item-no* menu:*select-menu-no*
			      menu)
			menu:*select-menu-stack*))
	    (setq menu value)
	    (delete-region (point-min) (point-max)) (insert (nth 1 menu))
	    (setq menu:*select-start* (point))
	    (setq menu:*select-menus*
		  (menu:make-selection-list
		   ;;; 92.9.19 by Y. Kawabe
		   (nth 2 menu) (- window-width (string-width (nth 1 menu)))))
	    (if (and (numberp (car initial))
		     (<= 0 (car initial))
		     (< (car initial) (length (nth 2 menu))))
		(menu:select-goto-item-position (car initial))
	      (setq menu:*select-item-no* 0)
	      (menu:select-goto-menu 0)))
	  (setq value nil))
	 (t
	  (setq menu:*select-item-no* 0)
	  (menu:select-goto-menu 0))
	 )
	;; end of patch
	(while (not finished)
	  (let ((ch (read-event)))
	    (setq quit-flag nil)
	    (cond
	     ((eq ch ?\C-a)
	      (menu:select-goto-item 0))
	     ((eq ch ?\C-e)
	      (menu:select-goto-item (1- (length menu:*select-items*))))
	     ((or (eq ch ?\C-f) (eq ch 'right))
	      ;;(menu:select-goto-item (1+ menu:*select-item-no*))
	      (menu:select-next-item)
	      )
	     ((or (eq ch ?\C-b) (eq ch 'left))
	      ;;(menu:select-goto-item (1- menu:*select-item-no*))
	      (menu:select-previous-item)
	      )
	     ((or (eq ch ?\C-n) (eq ch 'down))
	      (menu:select-goto-menu (1+ menu:*select-menu-no*)))
	     ((eq ch ?\C-g)
	      (if menu:*select-menu-stack*
		  (let ((save (car menu:*select-menu-stack*)))
		    (setq menu:*select-menu-stack*
			  (cdr menu:*select-menu-stack*))
		    (setq menu:*select-items* (nth 0 save);92.10.26 by T.Saneto
			  menu:*select-menus*    (nth 1 save)
			  menu:*select-item-no*  (nth 2 save)
			  menu:*select-menu-no*  (nth 3 save)
			  menu                   (nth 4 save))
		    (setq menu:*select-positions*
			  (cdr menu:*select-positions*))
		    (delete-region (point-min) (point-max))
		    (insert (nth 1 menu))
		    (setq menu:*select-start* (point))
		    (menu:select-goto-menu menu:*select-menu-no*)
		    (menu:select-goto-item menu:*select-item-no*)
		    )
		(setq finished t
		      value nil)))
	     ((or (eq ch ?\C-p) (eq ch 'up))
	      (menu:select-goto-menu (1- menu:*select-menu-no*)))
	     ((eq ch ?\C-l)  ;;; redraw menu
	      (menu:select-goto-menu menu:*select-menu-no*))
	     ((and (numberp ch) (<= ?0 ch) (<= ch ?9)
		   (<= ch (+ ?0 (1- (length menu:*select-items*)))))
	      (menu:select-goto-item (- ch ?0)))
	     ((and (numberp ch) (<= ?a ch) (<= ch ?z)
		   (<= (+ 10 ch) (+ ?a (1- (length menu:*select-items*)))))
	      (menu:select-goto-item (+ 10 (- ch ?a))))
	     ((and (numberp ch) (<= ?A ch) (<= ch ?Z)
		   (<= (+ 10 ch) (+ ?A (1- (length menu:*select-items*)))))
	      (menu:select-goto-item (+ 10 (- ch ?A))))
	     ((or (eq ch ?\C-m) (eq ch 'return))
	      (setq value (menu:item-value (nth menu:*select-item-no* 
						menu:*select-items*)))
	      (setq menu:*select-positions* 
		    (cons (menu:select-item-position)
			  menu:*select-positions*))
	      (if (and (listp value)
		       (eq (car value) 'menu))
		  (progn
		    (setq menu:*select-menu-stack*
			  (cons
			   (list menu:*select-items* menu:*select-menus*
				 menu:*select-item-no* menu:*select-menu-no*
				 menu)
			   menu:*select-menu-stack*))
		    (setq menu value)
		    (delete-region (point-min) (point-max))
		    (insert (nth 1 menu))
		    (setq menu:*select-start* (point))
		    (setq menu:*select-menus*
			  ;;; 92.9.19 by Y. Kawabe
			  (menu:make-selection-list
			   (nth 2 menu)
			   (- window-width
			      (string-width (nth 1 menu)))))
		    (setq menu:*select-item-no* 0)
		    (menu:select-goto-menu 0)
		    (setq value nil)
		    )
		(setq finished t)))
	     (t (beep))))))
      (delete-region (point-min) (point-max))
      (setq menu:*select-positions*
	    (nreverse menu:*select-positions*))
      (set-window-buffer (minibuffer-window) minibuffer)
      (if (null value)
	  (setq quit-flag t)
	(if position
	    (cons value menu:*select-positions*)
	  value)))))

(defun menu:select-item-position ()
  (let ((p 0) (m 0))
    (while (< m menu:*select-menu-no*)
      (setq p (+ p (length (nth m menu:*select-menus*))))
      (setq m (1+ m)))
    (+ p menu:*select-item-no*)))
    
(defun menu:select-goto-item-position (pos)
  (let ((m 0) (p 0))
    (while (<= (+ p (length (nth m menu:*select-menus*))) pos)
      (setq p (+ p (length (nth m menu:*select-menus*))))
      (setq m (1+ m)))
    (setq menu:*select-item-no* (- pos p))
    (menu:select-goto-menu m)))

(defun menu:select-goto-menu (no)
  (setq menu:*select-menu-no*
	(check-number-range no 0 (1- (length menu:*select-menus*))))
  (setq menu:*select-items* (nth menu:*select-menu-no* menu:*select-menus*))
  (delete-region menu:*select-start* (point-max))
  (if (<= (length menu:*select-items*) menu:*select-item-no*)
      (setq menu:*select-item-no* (1- (length menu:*select-items*))))
  (goto-char menu:*select-start*)
  (let ((l menu:*select-items*) (i 0))
    (while l
      (insert (if (<= i 9) (format "  %d." i)
		(format "  %c." (+ (- i 10) ?a)))
	      (menu:item-string (car l)))
      (setq l (cdr l)
	    i (1+ i))))
  (menu:select-goto-item menu:*select-item-no*))

(defun menu:select-goto-item (no)
  (setq menu:*select-item-no* 
	(check-number-range no 0
			    (1- (length menu:*select-items*))))
  (let ((p (+ 2 menu:*select-start*)) (i 0))
    (while (< i menu:*select-item-no*)
      (setq p (+ p (length (menu:item-string (nth i menu:*select-items*))) 4))
      (setq i (1+ i)))
    (goto-char p)))
    
(defun menu:select-next-item ()
  (if (< menu:*select-item-no* (1- (length menu:*select-items*)))
      (menu:select-goto-item (1+ menu:*select-item-no*))
    (progn
      (setq menu:*select-item-no* 0)
      (menu:select-goto-menu (1+ menu:*select-menu-no*)))))

(defun menu:select-previous-item ()
  (if (< 0 menu:*select-item-no*)
      (menu:select-goto-item (1- menu:*select-item-no*))
    (progn 
      (setq menu:*select-item-no* 1000)
      (menu:select-goto-menu (1- menu:*select-menu-no*)))))

(defvar menu:*display-item-value* nil)

(defun menu:item-string (item)
  (cond((stringp item) item)
       ((characterp item) (char-to-string item))
       ((consp item)
	(if menu:*display-item-value*
	    (format "%s [%s]"
		    (cond ((stringp (car item)) (car item))
			  ((characterp (car item)) (char-to-string (car item)))
			  (t ""))
		    (cdr item))
	  (cond ((stringp (car item))
		 (car item))
		((characterp (car item))
		 (char-to-string (car item)))
		(t ""))))
       (t "")))

(defun menu:item-value (item)
  (cond((stringp item) item)
       (t (cdr item))))

(defun menu:make-selection-list (items width)
  (let ((whole nil) (line nil) (size 0))
    (while items
      ;;; 92.9.19 by Y. Kawabe
      (if (<= width (+ size 4 (string-width (menu:item-string(car items)))))
	  (if line
	      (setq whole (cons (reverse line) whole)
		    line nil
		    size 0)
	    (setq whole (cons (list (car items)) whole)
		  size 0
		  items (cdr items)))
	;;; 92.9.19 by Y. Kawabe
	(setq line (cons (car items) line)
	      size (+ size 4 (string-width(menu:item-string (car items))))
	      items (cdr items))))
    (if line
	(reverse (cons (reverse line) whole))
      (reverse whole))))


;;;----------------------------------------------------------------------
;;;
;;;  $B0l3g7?JQ495!G=(B
;;;
;;;----------------------------------------------------------------------


;;;
;;; $B$R$i$,$JJQ49(B
;;;

(defun hiragana-region (start end)
  (interactive "r")
    (goto-char start)
    (while (re-search-forward kanji-katakana end end)
      (let ((ch (preceding-char)))
	(cond( (<= ch ?$B%s(B)
	       (delete-char -1)
	       (insert (make-char (find-charset 'japanese-jisx0208) 36 (char-octet ch 1))))))))

(defun hiragana-paragraph ()
  "hiragana  paragraph at or after point."
  (interactive )
  (save-excursion
    (forward-paragraph)
    (let ((end (point)))
      (backward-paragraph)
      (hiragana-region (point) end ))))

(defun hiragana-sentence ()
  "hiragana  sentence at or after point."
  (interactive )
  (save-excursion
    (forward-sentence)
    (let ((end (point)))
      (backward-sentence)
      (hiragana-region (point) end ))))

;;;
;;; $B%+%?%+%JJQ49(B
;;;

(defun katakana-region (start end)
  (interactive "r")
  (goto-char start)
  (while (re-search-forward kanji-hiragana end end)
    (let ((ch (char-octet (preceding-char) 1)))
      (delete-char -1)
      (insert (make-char (find-charset 'japanese-jisx0208) 37 ch)))))

(defun katakana-paragraph ()
  "katakana  paragraph at or after point."
  (interactive )
  (save-excursion
    (forward-paragraph)
    (let ((end (point)))
      (backward-paragraph)
      (katakana-region (point) end ))))

(defun katakana-sentence ()
  "katakana  sentence at or after point."
  (interactive )
  (save-excursion
    (forward-sentence)
    (let ((end (point)))
      (backward-sentence)
      (katakana-region (point) end ))))

;;;
;;; $BH>3QJQ49(B
;;; 

(defun hankaku-region (start end)
  (interactive "r")
  (save-restriction
    (narrow-to-region start end)
    (goto-char (point-min))
    (while (re-search-forward "\\cS\\|\\cA" (point-max) (point-max))
      (let* ((ch (preceding-char))
	     (ch1 (char-octet ch 0))
	     (ch2 (char-octet ch 1)))
	(cond ((= ?\241 ch1)
	       (let ((val (cdr (assq ch2 *hankaku-alist*))))
		 (if val (progn
			   (delete-char -1)
			   (insert val)))))
	      ((= ?\243 ch1)
	       (delete-char -1)
	       (insert (- ch2 ?\200 ))))))))

(defun hankaku-paragraph ()
  "hankaku  paragraph at or after point."
  (interactive )
  (save-excursion
    (forward-paragraph)
    (let ((end (point)))
      (backward-paragraph)
      (hankaku-region (point) end ))))

(defun hankaku-sentence ()
  "hankaku  sentence at or after point."
  (interactive )
  (save-excursion
    (forward-sentence)
    (let ((end (point)))
      (backward-sentence)
      (hankaku-region (point) end ))))

(defun hankaku-word (arg)
  (interactive "p")
  (let ((start (point)))
    (forward-word arg)
    (hankaku-region start (point))))

(defvar *hankaku-alist*
  '(( 161 . ?\  ) 
    ( 170 . ?\! )
    ( 201 . ?\" )
    ( 244 . ?\# )
    ( 240 . ?\$ )
    ( 243 . ?\% )
    ( 245 . ?\& )
    ( 199 . ?\' )
    ( 202 . ?\( )
    ( 203 . ?\) )
    ( 246 . ?\* )
    ( 220 . ?\+ )
    ( 164 . ?\, )
    ( 221 . ?\- )
    ( 165 . ?\. )
    ( 191 . ?\/ )
    ( 167 . ?\: )
    ( 168 . ?\; )
    ( 227 . ?\< )
    ( 225 . ?\= )
    ( 228 . ?\> )
    ( 169 . ?\? )
    ( 247 . ?\@ )
    ( 206 . ?\[ )
    ( 239 . ?\\ )
    ( 207 . ?\] )
    ( 176 . ?^ )
    ( 178 . ?\_ )
    ( 208 . ?\{ )
    ( 195 . ?\| )
    ( 209 . ?\} )
    ( 177 . ?\~ )
    ( 198 . ?` )			; 92.6.26 by M.Shikida
    ))

;;;
;;; $BA43QJQ49(B
;;;

(defun zenkaku-region (start end)
  (interactive "r")
  (save-restriction
    (narrow-to-region start end)
    (goto-char (point-min))
    (while (re-search-forward "[ -~]" (point-max) (point-max))
      (let ((ch (preceding-char)))
	(if (and (<= ?  ch) (<= ch ?~))
	    (progn
	      (delete-char -1)
	      (let ((zen (cdr (assq ch *zenkaku-alist*))))
		(if zen (insert zen)
		  (insert (make-char (find-charset 'japanese-jisx0208) 38 ch))))))))))

(defun zenkaku-paragraph ()
  "zenkaku  paragraph at or after point."
  (interactive )
  (save-excursion
    (forward-paragraph)
    (let ((end (point)))
      (backward-paragraph)
      (zenkaku-region (point) end ))))

(defun zenkaku-sentence ()
  "zenkaku  sentence at or after point."
  (interactive )
  (save-excursion
    (forward-sentence)
    (let ((end (point)))
      (backward-sentence)
      (zenkaku-region (point) end ))))

(defun zenkaku-word (arg)
  (interactive "p")
  (let ((start (point)))
    (forward-word arg)
    (zenkaku-region start (point))))

(defvar *zenkaku-alist*
  '((?  . "$B!!(B") 
    (?! . "$B!*(B")
    (?\" . "$B!I(B")
    (?# . "$B!t(B")
    (?$ . "$B!p(B")
    (?% . "$B!s(B")
    (?& . "$B!u(B")
    (?' . "$B!G(B")
    (?( . "$B!J(B")
    (?) . "$B!K(B")
    (?* . "$B!v(B")
    (?+ . "$B!\(B")
    (?, . "$B!$(B")
    (?- . "$B!](B")
    (?. . "$B!%(B")
    (?/ . "$B!?(B")
    (?: . "$B!'(B")
    (?\; . "$B!((B")
    (?< . "$B!c(B")
    (?= . "$B!a(B")
    (?> . "$B!d(B")
    (?? . "$B!)(B")
    (?@ . "$B!w(B")
    (?[ . "$B!N(B")
    (?\\ . "$B!o(B")
    (?] . "$B!O(B")
    (?^ . "$B!0(B")
    (?_ . "$B!2(B")
    (?{ . "$B!P(B")
    (?| . "$B!C(B")
    (?} . "$B!Q(B")
    (?~ . "$B!1(B")
    (?` . "$B!F(B")))			; 92.6.26 by M.Shikida

;;;
;;; $B%m!<%^;z$+$JJQ49(B
;;;

(defun roma-kana-region (start end )
  (interactive "r")
  (its:translate-region start end nil (its:get-mode-map "roma-kana")))

(defun roma-kana-paragraph ()
  "roma-kana  paragraph at or after point."
  (interactive )
  (save-excursion
    (forward-paragraph)
    (let ((end (point)))
      (backward-paragraph)
      (roma-kana-region (point) end ))))

(defun roma-kana-sentence ()
  "roma-kana  sentence at or after point."
  (interactive )
  (save-excursion
    (forward-sentence)
    (let ((end (point)))
      (backward-sentence)
      (roma-kana-region (point) end ))))

(defun roma-kana-word ()
  "roma-kana word at or after point."
  (interactive)
  (save-excursion
    (re-search-backward "\\b\\w" nil t)
    (let ((start (point)))
      (re-search-forward "\\w\\b" nil t)
      (roma-kana-region start (point)))))

;;;
;;; $B%m!<%^;z4A;zJQ49(B
;;;

(defun roma-kanji-region (start end)
  (interactive "r")
  (roma-kana-region start end)
  (save-restriction
    (narrow-to-region start (point))
    (goto-char (point-min))
    (replace-regexp "\\($B!!(B\\| \\)" "")
    (goto-char (point-max)))
  (henkan-region-internal start (point)))

(defun roma-kanji-paragraph ()
  "roma-kanji  paragraph at or after point."
  (interactive )
  (save-excursion
    (forward-paragraph)
    (let ((end (point)))
      (backward-paragraph)
      (roma-kanji-region (point) end ))))

(defun roma-kanji-sentence ()
  "roma-kanji  sentence at or after point."
  (interactive )
  (save-excursion
    (forward-sentence)
    (let ((end (point)))
      (backward-sentence)
      (roma-kanji-region (point) end ))))

(defun roma-kanji-word ()
  "roma-kanji word at or after point."
  (interactive)
  (save-excursion
    (re-search-backward "\\b\\w" nil t)
    (let ((start (point)))
      (re-search-forward "\\w\\b" nil t)
      (roma-kanji-region start (point)))))


;;;----------------------------------------------------------------------
;;;
;;; $B!V$?$^$4!WF~NOJ8;zJQ497O(B ITS
;;; 
;;;----------------------------------------------------------------------

(defun egg:member (elt list)
  (while (not (or (null list) (equal elt (car list))))
    (setq list (cdr list)))
  list)

;;;
;;; Mode name --> map
;;;
;;; ITS mode name: string

(defvar its:*mode-alist* nil)
(defvar its:*internal-mode-alist* nil)

(defun its:get-mode-map (name)
  (or (cdr (assoc name its:*mode-alist*))
      (cdr (assoc name its:*internal-mode-alist*))))

(defun its:set-mode-map (name map &optional internalp)
  (let ((place (assoc name 
		      (if internalp its:*internal-mode-alist*
			its:*mode-alist*))))
    (if place (let ((mapplace (cdr place)))
		(setcar mapplace (car map))
		(setcdr mapplace (cdr map)))
      (progn (setq place (cons name map))
	     (if internalp
		 (setq its:*internal-mode-alist*
		       (append its:*internal-mode-alist* (list place)))
	       (setq its:*mode-alist* 
		     (append its:*mode-alist* (list place))))))))

;;;
;;; ITS mode indicators
;;; Mode name --> indicator
;;;

(defun its:get-mode-indicator (name)
  (let ((map (its:get-mode-map name)))
    (if map (map-indicator map)
      name)))

(defun its:set-mode-indicator (name indicator)
  (let ((map (its:get-mode-map name)))
    (if map
	(map-set-indicator map indicator)
      (its-define-mode name indicator))))

;;;
;;; ITS mode declaration
;;;

(defvar its:*processing-map* nil)

(defun its-define-mode (name &optional indicator reset supers internalp) 
  "its-mode NAME $B$rDj5AA*Br$9$k!%B>$N(B its-mode $B$,A*Br$5$l$k$^$G$O(B 
its-defrule $B$J$I$O(B NAME $B$KBP$7$F5,B'$rDI2C$9$k!%(BINDICATOR $B$,(B non-nil 
$B$N;~$K$O(B its-mode NAME $B$rA*Br$9$k$H(B mode-line $B$KI=<($5$l$k!%(BRESET $B$,(B 
non-nil $B$N;~$K$O(B its-mode $B$NDj5A$,6u$K$J$k!%(BSUPERS $B$O>e0L$N(B its-mode 
$BL>$r%j%9%H$G;XDj$9$k!%(BINTERNALP $B$O(B mode name $B$rFbItL>$H$9$k!%(B
its-defrule, its-defrule-conditional, defule-select-mode-temporally $B$r(B
$B;2>H(B"

  (if (null(its:get-mode-map name))
      (progn 
	(setq its:*processing-map* 
	      (make-map nil (or indicator name) nil (mapcar 'its:get-mode-map supers)))
	(its:set-mode-map name its:*processing-map* internalp)
	)
    (progn (setq its:*processing-map* (its:get-mode-map name))
	   (if indicator
	       (map-set-indicator its:*processing-map* indicator))
	   (if reset
	       (progn
		 (map-set-state its:*processing-map* nil)
		 (map-set-alist its:*processing-map* nil)
		 ))
	   (if supers
	       (progn
		 (map-set-supers its:*processing-map* (mapcar 'its:get-mode-map supers))))))
  nil)

;;;
;;; defrule related utilities
;;;

(put 'for-each 'lisp-indent-hook 1)

(defmacro for-each (vars &rest body)
  "(for-each ((VAR1 LIST1) ... (VARn LISTn)) . BODY) $B$OJQ?t(B VAR1 $B$NCM(B
$B$r%j%9%H(B LIST1 $B$NMWAG$KB+G{$7!$!%!%!%JQ?t(B VARn $B$NCM$r%j%9%H(B LISTn $B$NMW(B
$BAG$KB+G{$7$F(B BODY $B$r<B9T$9$k!%(B"

  (for-each* vars (cons 'progn body)))

(defun for-each* (vars body)
  (cond((null vars) body)
       (t (let((tvar (make-symbol "temp"))
	       (var  (car (car vars)))
	       (val  (car (cdr (car vars)))))
	    (list 'let (list (list tvar val)
			     var)
		  (list 'while tvar
			(list 'setq var (list 'car tvar))
			(for-each* (cdr vars) body)
			(list 'setq tvar (list 'cdr tvar))))))))
			     
(put 'dolist 'lisp-indent-hook 1)

(defmacro dolist (pair &rest body)
  "(dolist (VAR LISTFORM) . BODY) $B$O(BVAR $B$K=g<!(B LISTFORM $B$NMWAG$rB+G{$7(B
$B$F(B BODY $B$r<B9T$9$k(B"

  (for-each* (list pair) (cons 'progn body)))

;;;
;;; defrule
;;; 

(defun its:make-standard-action (output next)
  "OUTPUT $B$H(B NEXT $B$+$i$J$k(B standard-action $B$r:n$k!%(B"

  (if (and (stringp output) (string-equal output ""))
      (setq output nil))
  (if (and (stringp next)   (string-equal next   ""))
      (setq next nil))
  (cond((null output)
	(cond ((null next) nil)
	      (t (list nil next))))
       ((consp output)
	;;; alternative output
	(list (cons 0 output) next))
       ((null next) output)
       (t
	(list output next))))

(defun its:standard-actionp (action)
  "ACITION $B$,(B standard-action $B$G$"$k$+$I$&$+$rH=Dj$9$k!%(B"
  (or (stringp action)
      (and (consp action)
	   (or (stringp (car action))
	       (and (consp (car action))
		    (characterp (car (car action))))
	       (null (car action)))
	   (or (null (car (cdr action)))
	       (stringp (car (cdr action)))))))

(defvar its:make-terminal-state 'its:default-make-terminal-state 
  "$B=*C<$N>uBV$G$NI=<($r:n@.$9$k4X?t$r;XDj$9$k(B. $B4X?t$O(B map input
action state $B$r0z?t$H$7$F8F$P$l!$>uBVI=<($NJ8;zNs$rJV$9!%(B")

(defun its:default-make-terminal-state (map input action state)
  (cond(state state)
       (t input)))

(defun its:make-terminal-state-hangul (map input action state)
  (cond((its:standard-actionp action) (action-output action))
       (t nil)))

(defvar its:make-non-terminal-state 'its:default-make-standard-non-terminal-state
  "$BHs=*C<$N>uBV$G$NI=<($r:n@.$9$k4X?t$r;XDj$9$k!%4X?t$O(B map input $B$r(B
$B0z?t$H$7$F8F$P$l!$>uBVI=<($NJ8;zNs$rJV$9(B" )

(defun its:default-make-standard-non-terminal-state (map input)
  " ****"
  (concat
   (map-state-string map)
   (char-to-string (aref input (1- (length input))))))

(defun its-defrule (input output &optional next state map) 

  "INPUT $B$,F~NO$5$l$k$H(B OUTPUT $B$KJQ49$9$k!%(BNEXT $B$,(B nil $B$G$J$$$H$-$OJQ(B
$B49$7$?8e$K(B NEXT $B$,F~NO$5$l$?$h$&$KJQ49$rB3$1$k!%(BINPUT$B$,F~NO$5$l$?;~E@(B
$B$GJQ49$,3NDj$7$F$$$J$$;~$O(B STATE $B$r%U%'%s%9>e$KI=<($9$k!%JQ49$,3NDj$7(B
$B$F$$$J$$;~$KI=<($9$kJ8;zNs$OJQ?t(B its:make-terminal-state $B$*$h$S(B $BJQ?t(B 
its:make-non-terminal-state $B$K;X<($5$l$?4X?t$K$h$C$F@8@.$5$l$k!%JQ495,(B
$BB'$O(B MAP $B$G;XDj$5$l$?JQ49I=$KEPO?$5$l$k!%(BMAP $B$,(B nil $B$N>l9g$O$b$C$H$b:G(B
$B6a$K(B its-define-mode $B$5$l$?JQ49I=$KEPO?$5$l$k!%$J$*(B OUTPUT $B$,(B nil $B$N>l(B
$B9g$O(B INPUT $B$KBP$9$kJQ495,B'$,:o=|$5$l$k!%(B"

  (its-defrule* input
    (its:make-standard-action output next) state 
    (if (stringp map) map
      its:*processing-map*)))

(defmacro its-defrule-conditional (input &rest conds)
  "(its-defrule-conditional INPUT ((COND1 OUTPUT1) ... (CONDn OUTPUTn)))$B$O(B 
INPUT $B$,F~NO$5$l$?;~$K>r7o(B CONDi $B$r=g<!D4$Y!$@.N)$7$?;~$K$O(B OUTPUTi $B$r(B
$B=PNO$9$k!%(B"
  (list 'its-defrule* input (list 'quote (cons 'cond conds))))

(defmacro its-defrule-conditional* (input state map &rest conds)
  "(its-defrule-conditional INPUT STATE MAP ((COND1 OUTPUT1) ... (CONDn
OUTPUTn)))$B$O(B INPUT $B$,F~NO$5$l$?;~$K>uBV(B STATE $B$rI=<($7!$>r7o(B CONDi $B$r(B
$B=g<!D4$Y!$@.N)$7$?;~$K$O(B OUTPUTi $B$r=PNO$9$k!%(B"
  (list 'its-defrule* input (list 'quote (cons 'cond conds)) state map))

(defun its-defrule-select-mode-temporally (input name)
  "INPUT $B$,F~NO$5$l$k$H(B temporally-mode $B$H$7$F(B NAME $B$,A*Br$5$l$k!%(B"

  (its-defrule* input (list 'quote (list 'its:select-mode-temporally name))))

(defun its-defrule* (input action &optional state map)
  (its:resize (length input))
  (setq map (cond((stringp map) (its:get-mode-map map))
		 ((null map) its:*processing-map*)
		 (t map)))
  (its-defrule** 0 input action state map)
  map)

(defvar its:*defrule-verbose* t "nil$B$N>l9g(B, its-defrule $B$N7Y9p$rM^@)$9$k(B")

(defun its-defrule** (i input action state map)
  (cond((= (length input) i)		;93.6.4 by T.Shingu
	(map-set-state
	 map 
	 (coerce-internal-string 
	  (funcall its:make-terminal-state map input action state)))
	(if (and its:*defrule-verbose* (map-action map))
	    (if action
		(notify "(its-defrule \"%s\" \"%s\" ) $B$r:FDj5A$7$^$7$?!%(B"
			input action)
	      (notify "(its-defrule \"%s\" \"%s\" )$B$r:o=|$7$^$7$?!%(B"
		      input (map-action map))))
	(if (and (null action) (map-terminalp map)) nil
	  (progn (map-set-action map action)
		 map)))
       (t
	(let((newmap
	      (or (get-next-map-locally map (sref input i))
		  (make-map (funcall its:make-non-terminal-state
				     map
				     (substring input 0 (+ i (char-bytes (sref input i)))))))))
	  (set-next-map map (sref input i) 
			(its-defrule** (+ i (char-bytes (sref input i))) input action state newmap)))
	(if (and (null (map-action map))
		 (map-terminalp map))
	    nil
	  map))))

;;;
;;; map: 
;;;
;;; <map-alist> ::= ( ( <char> . <map> ) ... )
;;; <topmap> ::= ( nil <indicator> <map-alist>  <supers> )
;;; <supers> ::= ( <topmap> .... )
;;; <map>    ::= ( <state> <action>    <map-alist> )
;;; <action> ::= <output> | ( <output> <next> ) ....

(defun make-map (&optional state action alist supers)
  (list state action alist supers))

(defun map-topmap-p (map)
  (null (map-state map)))

(defun map-supers (map)
  (nth 3 map))

(defun map-set-supers (map val)
  (setcar (nthcdr 3 map) val))

(defun map-terminalp (map)
  (null (map-alist map)))

(defun map-state (map)
  (nth 0 map))

(defun map-state-string (map)
  (coerce-string (map-state map)))

(defun map-set-state (map val)
  (setcar (nthcdr 0 map) val))

(defun map-indicator (map)
  (map-action map))
(defun map-set-indicator (map indicator)
  (map-set-action map indicator))

(defun map-action (map)
  (nth 1 map))
(defun map-set-action (map val)
  (setcar (nthcdr 1 map) val))

(defun map-alist (map)
  (nth 2 map))

(defun map-set-alist (map alist)
  (setcar (nthcdr 2 map) alist))

(defun get-action (map)
  (if (null map) nil
    (let ((action (map-action map)))
      (cond((its:standard-actionp action)
	    action)
	   ((symbolp action) (condition-case nil
				 (funcall action)
			       (error nil)))
	   (t (condition-case nil
		  (eval action)
		(error nil)))))))

(defun action-output (action)
  (cond((stringp action) action)
       (t (car action))))

(defun action-next (action)
  (cond((stringp action) nil)
       (t (car (cdr action)))))

(defun get-next-map (map ch)
  (or (cdr (assq ch (map-alist map)))
      (if (map-topmap-p map)
	  (let ((supers (map-supers map))
		(result nil))
	    (while supers
	      (setq result (get-next-map (car supers) ch))
	      (if result
		  (setq supers nil)
		(setq supers (cdr supers))))
	    result))))

(defun get-next-map-locally (map ch)
  (cdr (assq ch (map-alist map))))
  
(defun set-next-map (map ch val)
  (let ((place (assq ch (map-alist map))))
    (if place
	(if val
	    (setcdr place val)
	  (map-set-alist map (delq place (map-alist map))))
      (if val
	  (map-set-alist map (cons (cons ch val)
				   (map-alist map)))
	val))))

(defun its:simple-actionp (action)
  (stringp action))

(defun collect-simple-action (map)
  (if (map-terminalp map)
      (if (its:simple-actionp (map-action map))
	  (list (map-action map))
	nil)
    (let ((alist (map-alist map))
	  (result nil))
      (while alist
	(setq result 
	      ;;; 92.9.19 by Y. Kawabe
	      (append (collect-simple-action (cdr (car alist)))
		      result))
	(setq alist (cdr alist)))
      result)))

;;;----------------------------------------------------------------------
;;;
;;; Runtime translators
;;;
;;;----------------------------------------------------------------------
      
(defun its:simulate-input (i j  input map)
  (while (<= i j)
    (setq map (get-next-map map (sref input i))) ;92.12.26 by S.Tomura
    (setq i (+ i (char-bytes (sref input i)))))	;92.12.26 by S.Tomura
  map)

;;; meta-flag $B$,(B on $B$N;~$K$O!"F~NO%3!<%I$K(B \200 $B$r(B or $B$7$?$b$N$,F~NO$5(B
;;; $B$l$k!#$3$NItJ,$N;XE&$OEl9)Bg$NCf@n(B $B5.G7$5$s$K$h$k!#(B
;;; pointted by nakagawa@titisa.is.titech.ac.jp Dec-11-89
;;;
;;; emacs $B$G$O(B $BJ8;z%3!<%I$O(B 0-127 $B$G07$&!#(B
;;;

(defvar its:*buff-s* (make-marker))
(defvar its:*buff-e* (make-marker))
(set-marker-insertion-type its:*buff-e* t)

;;;    STATE     unread
;;; |<-s   p->|<-    e ->|
;;; s  : ch0  state0  map0
;;;  +1: ch1  state1  map1
;;; ....
;;; (point):

;;; longest matching region : [s m]
;;; suspending region:        [m point]
;;; unread region          :  [point e]


(defvar its:*maxlevel* 10)
(defvar its:*maps*   (make-vector its:*maxlevel* nil))
(defvar its:*actions* (make-vector its:*maxlevel* nil))
(defvar its:*inputs* (make-vector its:*maxlevel* 0))
(defvar its:*level* 0)

(defun its:resize (size)
  (if (<= its:*maxlevel* size)
      (setq its:*maxlevel* size
	    its:*maps*    (make-vector size nil)
	    its:*actions* (make-vector size nil)
	    its:*inputs*  (make-vector size 0))))

(defun its:reset-maps (&optional init)
  (setq its:*level* 0)
  (if init
      (aset its:*maps* its:*level* init)))

(defun its:current-map () (aref its:*maps* its:*level*))
(defun its:previous-map () (aref its:*maps* (max 0 (1- its:*level*))))

(defun its:level () its:*level*)

(defun its:enter-newlevel (map ch output)
  (setq its:*level* (1+ its:*level*))
  (aset its:*maps* its:*level* map)
  (aset its:*inputs* its:*level* ch)
  (aset its:*actions* its:*level* output))

(defvar its:*char-from-buff* nil)
(defvar its:*interactive* t)

(defun its:reset-input ()
  (setq its:*char-from-buff* nil))

(defun its:flush-input-before-point (from)
  (save-excursion
    (while (<= from its:*level*)
      (its:insert-char (aref its:*inputs* from))
      (setq from (1+ from)))))

(defun its:peek-char ()
  (if (= (point) its:*buff-e*)
      (if its:*interactive*
	  (setq unread-command-events (list (character-to-event(read-event))))
	nil)
    (following-char)))

(defun its:read-char ()
  (if (= (point) its:*buff-e*)
      (progn 
	(setq its:*char-from-buff* nil)
	(if its:*interactive*
	    (read-event)
	  nil))
    (let ((ch (following-char)))
      (setq its:*char-from-buff* t)
      (delete-char 1)
      ch)))

(defun its:push-char (ch)
  (if its:*char-from-buff*
      (save-excursion
	(its:insert-char ch))
    (if ch (setq unread-command-events (list (character-to-event ch))))))

(defun its:insert-char (ch)
  (insert ch))

(defun its:ordinal-charp (ch)
  (and (characterp ch) (<= ch 127)
       (eq (lookup-key fence-mode-map (char-to-string ch)) 'fence-self-insert-command)))

(defun its:delete-charp (ch)
  (and (characterp ch) (<= ch 127)
       (eq (lookup-key fence-mode-map (char-to-string ch)) 'fence-backward-delete-char)))
    
(defun fence-self-insert-command ()
  (interactive)
  (let ((ch (event-to-character last-command-event)))
    (cond((or (not egg:*input-mode*)
	      (null (get-next-map its:*current-map* ch)))
	  (insert ch))
	 (t
	  (insert ch)
	  (its:translate-region (1- (point)) (point) t)))))

;;;
;;; its: completing-read system
;;;

(defun its:all-completions (string alist &optional pred)
  "A variation of all-completions.\n\
Arguments are STRING, ALIST and optional PRED. ALIST must be no obarray."
  (let ((tail alist) (allmatches nil))
    (while tail
      (let* ((elt (car tail))
	     (eltstring (car elt)))
	(setq tail (cdr tail))
	(if (and (stringp eltstring)
		 (<= (length string) (length eltstring))
		 ;;;(not (= (aref eltstring 0) ? ))
		 (string-equal string (substring eltstring 0 (length string))))
	    (if (or (and pred
			 (if (if (eq pred 'commandp)
				 (commandp elt)
			       (funcall pred elt))))
		    (null pred))
		(setq allmatches (cons elt allmatches))))))
    (nreverse allmatches)))

(defun its:temp-echo-area-contents (message)
  (let ((inhibit-quit inhibit-quit)
	(point-max (point-max)))
    (goto-char point-max)
    (insert message)
    (goto-char point-max)
    (setq inhibit-quit t)
    (sit-for 2 nil)
    ;;; 92.9.19 by Y. Kawabe, 92.10.30 by T.Saneto
    (delete-region (point) (point-max))
    (if quit-flag
	(progn
	  (setq quit-flag nil)
	  (setq unread-command-events (list (character-to-event ?\^G)))))))

(defun car-string-lessp (item1 item2)
  (string-lessp (car item1) (car item2)))

(defun its:minibuffer-completion-help ()
    "Display a list of possible completions of the current minibuffer contents."
    (interactive)
    (let ((completions))
      (message "Making completion list...")
      (setq completions (its:all-completions (buffer-string)
					 minibuffer-completion-table
					 minibuffer-completion-predicate))
      (if (null completions)
	  (progn
	    ;;; 92.9.19 by Y. Kawabe
	    (beep)
	    (its:temp-echo-area-contents " [No completions]"))
	(with-output-to-temp-buffer "*Completions*"
	  (display-completion-list
	   (sort completions 'car-string-lessp))))
      nil))

(defconst its:minibuffer-local-completion-map 
  (copy-keymap minibuffer-local-completion-map))
(define-key its:minibuffer-local-completion-map "?" 'its:minibuffer-completion-help)
(define-key its:minibuffer-local-completion-map " " 'its:minibuffer-completion-help)

(defconst its:minibuffer-local-must-match-map
  (copy-keymap minibuffer-local-must-match-map))
(define-key its:minibuffer-local-must-match-map "?" 'its:minibuffer-completion-help)
(define-key its:minibuffer-local-must-match-map " " 'its:minibuffer-completion-help)

(fset 'si:all-completions (symbol-function 'all-completions))
(fset 'si:minibuffer-completion-help (symbol-function 'minibuffer-completion-help))

(defun its:completing-read (prompt table &optional predicate require-match initial-input)
  "See completing-read"
  (let ((minibuffer-local-completion-map its:minibuffer-local-completion-map)
	(minibuffer-local-must-match-map its:minibuffer-local-must-match-map)
	(completion-auto-help nil))
    (completing-read prompt table predicate t initial-input)))

(defvar its:*completing-input-menu* '(menu "Which?" nil)) ;92.10.26 by T.Saneto

(defun its:completing-input (map)
  ;;; 
  (let ((action (get-action map)))
    (cond((and (null action)
	       (= (length (map-alist map)) 1))
	  (its:completing-input (cdr (nth 0 (map-alist map)))))
	 (t
	  (setcar (nthcdr 2 its:*completing-input-menu*)
		  (map-alist map))
	  (let ((values
		 (menu:select-from-menu its:*completing-input-menu*
					0 t)))
	    (cond((consp values)
		  ;;; get input char from menu
		  )
		 (t
		  (its:completing-input map))))))))

(defvar its:*make-menu-from-map-result* nil)

(defun its:make-menu-from-map (map)
  (let ((its:*make-menu-from-map-result* nil))
    (its:make-menu-from-map* map "")
    (list 'menu "Which?"  (reverse its:*make-menu-from-map-result*) )))

(defun its:make-menu-from-map* (map string)
  (let ((action (get-action map)))
    (if action
	(setq its:*make-menu-from-map-result*
	      (cons (format "%s[%s]" string (action-output action))
		    its:*make-menu-from-map-result*)))
    (let ((alist (map-alist map)))
      (while alist
	(its:make-menu-from-map* 
	 (cdr (car alist))
	 (concat string (char-to-string (car (car alist)))))
	(setq alist (cdr alist))))))

(defvar its:*make-alist-from-map-result* nil)

(defun its:make-alist-from-map (map &optional string)
  (let ((its:*make-alist-from-map-result* nil))
    (its:make-alist-from-map* map (or string ""))
    (reverse its:*make-alist-from-map-result*)))

(defun its:make-alist-from-map* (map string)
  (let ((action (get-action map)))
    (if action
	(setq its:*make-alist-from-map-result*
	      (cons (list string 
			  (let ((action-output (action-output action)))
			    (cond((and (consp action-output)
				       (characterp (car action-output)))
				  (format "%s..."
				  (nth (car action-output) (cdr action-output))))
				 ((stringp action-output)
				  action-output)
				 (t
				  (format "%s" action-output)))))
		    its:*make-alist-from-map-result*)))
    (let ((alist (map-alist map)))
      (while alist
	(its:make-alist-from-map* 
	 (cdr (car alist))
	 (concat string (char-to-string (car (car alist)))))
	(setq alist (cdr alist))))))

(defvar its:*select-alternative-output-menu* '(menu "Which?" nil))

(defun its:select-alternative-output (action-output)
  ;;;; action-output : (pos item1 item2 item3 ....)
  (let ((point (point))
	(output (cdr action-output))
	(ch 0))
    (while (not (eq ch ?\^L))
      (insert "<" (nth (car action-output)output) ">")
      (setq ch (read-event))
      (cond ((eq ch ?\^N)
	     (setcar action-output
		     (mod (1+ (car action-output)) (length output))))
	    ((eq ch ?\^P)
	     (setcar action-output
		     (if (= 0 (car action-output))
			 (1- (length output))
		       (1- (car action-output)))))
	    ((eq ch ?\^M)
	     (setcar (nthcdr 2 its:*select-alternative-output-menu* )
		     output)
	     (let ((values 
		    (menu:select-from-menu its:*select-alternative-output-menu*
					   (car action-output)
					   t)))
	       (cond((consp values)
		     (setcar action-output (nth 1 values))
		     (setq ch ?\^L)))))
	    ((eq ch ?\^L)
	     )
	    (t
	     (beep)
	     ))
      (delete-region point (point)))
    (if its:*insert-output-string*
	(funcall its:*insert-output-string* (nth (car action-output) output))
      (insert (nth (car action-output) output)))))
      
    

;;; translate until 
;;;      interactive --> not ordinal-charp
;;; or
;;;      not interactive  --> end of input

(defvar its:*insert-output-string* nil)
(defvar its:*display-status-string* nil)

(defun its:translate-region (start end its:*interactive* &optional topmap)
  (set-marker its:*buff-s* start)
  (set-marker its:*buff-e* end)
  (its:reset-input)
  (goto-char its:*buff-s*)
  (let ((topmap (or topmap its:*current-map*))
	(map nil)
	(ch nil)
	(action nil)
	(newmap nil)
	(inhibit-quit t)
	(its-quit-flag nil)
	(echo-keystrokes 0))
    (setq map topmap)
    (its:reset-maps topmap)
    (while (not its-quit-flag)
      (setq ch (its:read-char))
      (setq newmap (get-next-map map ch))
      (setq action (get-action newmap))

      (cond
       ((and its:*interactive* (not its:*char-from-buff*) (characterp ch) (= ch ?\^@))
	(delete-region its:*buff-s* (point))
	(let ((i 1))
	  (while (<= i its:*level*)
	    (insert (aref its:*inputs* i))
	    (setq i (1+ i))))
	(let ((inputs (its:completing-read "ITS:>" 
					   (its:make-alist-from-map topmap)
					   nil
					   t
					   (buffer-substring its:*buff-s* (point)))))
	  (delete-region its:*buff-s* (point))
	  (save-excursion (insert inputs))
	  (its:reset-maps)
	  (setq map topmap)
	  ))
       ((or (null newmap)
	    (and (map-terminalp newmap)
		 (null action)))

	(cond((and its:*interactive* (its:delete-charp ch))
	      (delete-region its:*buff-s* (point))
	      (cond((= its:*level* 0)
		    (setq its-quit-flag t))
		   ((= its:*level* 1)
		    (its:insert-char (aref its:*inputs* 1))
		    (setq its-quit-flag t))
		   (t
		    (its:flush-input-before-point (1+ its:*level*))
		    (setq its:*level* (1- its:*level*))
		    (setq map (its:current-map))
		    (if (and its:*interactive*
			     its:*display-status-string*)
			(funcall its:*display-status-string* (map-state map))
		      (insert (map-state map)))
		    )))

	     (t
	      (let ((output nil))
		(let ((i its:*level*) (newlevel (1+ its:*level*)))
		  (aset its:*inputs* newlevel ch)
		  (while (and (< 0 i) (null output))
		    (if (and (aref its:*actions* i)
			     (its:simulate-input (1+ i) newlevel its:*inputs* topmap))
			(setq output i))
		    (setq i (1- i)))
		  (if (null output)
		      (let ((i its:*level*))
			(while (and (< 0 i) (null output))
			  (if (aref its:*actions* i)
			      (setq output i))
			  (setq i (1- i)))))

		  (cond(output 
			(delete-region its:*buff-s* (point))
			(cond((its:standard-actionp (aref its:*actions* output))
			      (let ((action-output (action-output (aref its:*actions* output))))
				(if (and (not its:*interactive*)
					 (consp action-output))
				    (setq action-output (nth (car action-output) (cdr action-output))))
				(cond((stringp action-output)
				      (if (and its:*interactive* 
					       its:*insert-output-string*)
					  (funcall its:*insert-output-string* action-output)
					(insert action-output)))
				     ((consp action-output)
				      (its:select-alternative-output action-output)
				      )
				     (t
				      (beep) (beep)
				      )))
			      (set-marker its:*buff-s* (point))
			      (its:push-char ch)
			      (its:flush-input-before-point (1+ output))
			      (if (action-next (aref its:*actions* output))
				  (save-excursion
				    (insert (action-next (aref its:*actions* output)))))
			      )
			     ((symbolp (aref its:*actions* output))
			      (its:push-char ch)
			      (funcall (aref its:*actions* output))
			      (its:reset-maps its:*current-map*)
			      (setq topmap its:*current-map*)
			      (set-marker its:*buff-s* (point)))
			     (t 
			      (its:push-char ch)
					;92.10.26 by T.Saneto
			      (eval (aref its:*actions* output))
			      (its:reset-maps its:*current-map*)
			      (setq topmap its:*current-map*)
			      (set-marker its:*buff-s* (point))
			      ))
			)
		       ((= 0 its:*level*)
			(cond ((or (its:ordinal-charp ch)
				   its:*char-from-buff*)
			       (its:insert-char ch))
			      (t (setq its-quit-flag t))))

		       ((< 0 its:*level*)
			(delete-region its:*buff-s* (point))
			(its:insert-char (aref its:*inputs* 1))
			(set-marker its:*buff-s* (point))
			(its:push-char ch)
			(its:flush-input-before-point 2)))))
		    
	      (cond((null ch)
		    (setq its-quit-flag t))
		   ((not its-quit-flag)
		    (its:reset-maps)
		    (set-marker its:*buff-s* (point))
		    (setq map topmap))))))
	       
       ((map-terminalp newmap)
	(its:enter-newlevel (setq map newmap) ch action)
	(delete-region its:*buff-s* (point))
	(let ((output nil) (m nil) (i (1- its:*level*)))
	  (while (and (< 0 i) (null output))
	    (if (and (aref its:*actions* i)
		     (setq m (its:simulate-input (1+ i) its:*level* its:*inputs* topmap))
		     (not (map-terminalp m)))
		(setq output i))
	    (setq i (1- i)))

	  (cond((null output)
		(cond ((its:standard-actionp action)
		       (let ((action-output (action-output action)))
			 (if (and (not its:*interactive*)
				  (consp action-output))
			     (setq action-output (nth (car action-output) (cdr action-output))))
			 (cond((stringp action-output)
			       (if (and its:*interactive* 
					its:*insert-output-string*)
				   (funcall its:*insert-output-string* action-output)
				 (insert action-output)))
			      ((consp action-output)
			       (its:select-alternative-output action-output)
			       )
			      (t
			       (beep) (beep)
			       )))
		       (cond((null (action-next action))
			     (cond ((and (= (point) its:*buff-e*)
					 its:*interactive*
					 (its:delete-charp (its:peek-char)))
				    nil)
				   (t
				    (set-marker its:*buff-s* (point))
				    (its:reset-maps)
				    (setq map topmap)
				    )))
			    (t
			     (save-excursion (insert (action-next action)))
			     (set-marker its:*buff-s* (point))
			     (its:reset-maps)
			     (setq map topmap))))
		      ((symbolp action)
		       (funcall action)
		       (its:reset-maps its:*current-map*)
		       (setq topmap its:*current-map*)
		       (setq map topmap)
		       (set-marker its:*buff-s* (point)))
		      (t 
		       (eval action)
		       (its:reset-maps its:*current-map*)
		       (setq topmap its:*current-map*)
		       (setq map topmap)
		       (set-marker its:*buff-s* (point)))))
	       (t
		(if (and its:*interactive* 
			 its:*display-status-string*)
		    (funcall its:*display-status-string* (map-state map))
		  (insert (map-state map)))))))

       ((null action)
	(delete-region its:*buff-s* (point))
	(if (and its:*interactive* 
		 its:*display-status-string*)
	    (funcall its:*display-status-string* (map-state newmap))
	  (insert (map-state newmap)))
	(its:enter-newlevel (setq map newmap)
			    ch action))

       (t
	(its:enter-newlevel (setq map newmap) ch action)
	(delete-region its:*buff-s* (point))
	(if (and its:*interactive* 
		 its:*display-status-string*)
	    (funcall its:*display-status-string* (map-state map))
	  (insert (map-state map))))))

    (set-marker its:*buff-s* nil)
    (set-marker its:*buff-e* nil)
    (if (and its:*interactive* ch) (setq unread-command-events (list (character-to-event ch))))
    ))

;;;----------------------------------------------------------------------
;;; 
;;; ITS-map dump routine:
;;;
;;;----------------------------------------------------------------------

;;;;;
;;;;; User entry: dump-its-mode-map
;;;;;

;; 92.6.26 by K.Handa
(defun dump-its-mode-map (name filename)
  "Obsolete."
  (interactive)
  (message "This function is obsolete in the current version of Mule."))
;;;
;;; EGG mode variables
;;;

(defvar egg:*mode-on* nil "T if egg mode is on.")
(make-variable-buffer-local 'egg:*mode-on*)
(set-default 'egg:*mode-on* nil)

(defvar egg:*input-mode* t "T if egg map is active.")
(make-variable-buffer-local 'egg:*input-mode*)
(set-default 'egg:*input-mode* t)

(defvar egg:*in-fence-mode* nil "T if in fence mode.")
(make-variable-buffer-local 'egg:*in-fence-mode*)
(set-default 'egg:*in-fence-mode* nil)

;;(load-library "its-dump/roma-kana")         ;;;(define-its-mode "roma-kana"        " a$B$"(B")
;;(load-library "its-dump/roma-kata")         ;;;(define-its-mode "roma-kata"        " a$B%"(B")
;;(load-library "its-dump/downcase")          ;;;(define-its-mode "downcase"         " a a")
;;(load-library "its-dump/upcase")            ;;;(define-its-mode "upcase"           " a A")
;;(load-library "its-dump/zenkaku-downcase")  ;;;(define-its-mode "zenkaku-downcase" " a$B#a(B")
;;(load-library "its-dump/zenkaku-upcase")    ;;;(define-its-mode "zenkaku-upcase"   " a$B#A(B")
;; 92.3.13 by K.Handa
;; (load "its-hira")
;; (load-library "its-kata")
;; (load-library "its-hankaku")
;; (load-library "its-zenkaku")


(defvar its:*current-map* nil)
(make-variable-buffer-local 'its:*current-map*)
;; 92.3.13 by K.Handa
;; moved to each language specific setup files (japanese.el, ...)
;; (setq-default its:*current-map* (its:get-mode-map "roma-kana"))

(defvar its:*previous-map* nil)
(make-variable-buffer-local 'its:*previous-map*)
(setq-default its:*previous-map* nil)

;;;----------------------------------------------------------------------
;;;
;;; Mode line control functions;
;;;
;;;----------------------------------------------------------------------

(defconst mode-line-egg-mode "--")
(make-variable-buffer-local 'mode-line-egg-mode)

(defvar   mode-line-egg-mode-in-minibuffer "--" "global variable")

(defun egg:find-symbol-in-tree (item tree)
  (if (consp tree)
      (or (egg:find-symbol-in-tree item (car tree))
	  (egg:find-symbol-in-tree item (cdr tree)))
    (equal item tree)))

;;;
;;; nemacs Ver. 3.0 $B$G$O(B Fselect_window $B$,JQ99$K$J$j!"(Bminibuffer-window
;;; $BB>$N(B window $B$H$N4V$G=PF~$j$,$"$k$H!"(Bmode-line $B$N99?7$r9T$J$$!"JQ?t(B 
;;; minibuffer-window-selected $B$NCM$,99?7$5$l$k(B
;;;

;;; nemacs Ver. 4 $B$G$O(B Fselect_window $B$,JQ99$K$J$j!$(Bselect-window-hook 
;;; $B$,Dj5A$5$l$?!%$3$l$K$H$b$J$$=>Mh!$:FDj5A$7$F$$$?(B select-window,
;;; other-window, keyborad-quit, abort-recursive-edit, exit-minibuffer 
;;; $B$r:o=|$7$?!%(B

(defconst display-minibuffer-mode-in-minibuffer t)

(defvar minibuffer-window-selected nil)

(defun egg:select-window-hook (old new)
  (if (and (eq old (minibuffer-window))
           (not (eq new (minibuffer-window))))
      (save-excursion
	(set-buffer (window-buffer (minibuffer-window)))
	(set-minibuffer-preprompt nil)
	(setq egg:*mode-on* (default-value 'egg:*mode-on*)
	      egg:*input-mode* (default-value 'egg:*input-mode*)
	      egg:*in-fence-mode* (default-value 'egg:*in-fence-mode*))))
  (if (eq new (minibuffer-window))
      (setq minibuffer-window-selected t)
    (setq minibuffer-window-selected nil)))

(defun egg:minibuffer-entry-hook ()
  (setq minibuffer-window-selected t))

(defun egg:minibuffer-exit-hook ()
  "Call upon exit from minibufffer"
  (set-minibuffer-preprompt nil)
  (setq minibuffer-window-selected nil)
  (save-excursion
    (set-buffer (window-buffer (minibuffer-window)))
    (setq egg:*mode-on* (default-value 'egg:*mode-on*)
	  egg:*input-mode* (default-value 'egg:*input-mode*)
	  egg:*in-fence-mode* (default-value 'egg:*in-fence-mode*))))
  
(if (boundp 'select-window-hook)
    (add-hook 'select-window-hook 'egg:select-window-hook)
  (add-hook 'minibuffer-exit-hook 'egg:minibuffer-exit-hook)
  (add-hook 'minibuffer-entry-hook 'egg:minibuffer-entry-hook))

;;;
;;;
;;;

(defvar its:*reset-modeline-format* nil)

(if its:*reset-modeline-format*
    (setq-default modeline-format
		  (cdr modeline-format)))

(if (not (egg:find-symbol-in-tree 'mode-line-egg-mode modeline-format))
    (setq-default 
     modeline-format
     (cons (list 'display-minibuffer-mode-in-minibuffer
		 ;;; minibuffer mode in minibuffer
		 (list 
		  (list 'its:*previous-map* "<" "[")
		  'mode-line-egg-mode
		  (list 'its:*previous-map* ">" "]")
		  )
		       ;;;; minibuffer mode in mode line
		 (list 
		  (list 'minibuffer-window-selected
			(list 'display-minibuffer-mode
			      "m"
			      " ")
			" ")
		  (list 'its:*previous-map* "<" "[")
		  (list 'minibuffer-window-selected
			(list 'display-minibuffer-mode
			      'mode-line-egg-mode-in-minibuffer
			      'mode-line-egg-mode)
			'mode-line-egg-mode)
		  (list 'its:*previous-map* ">" "]")
		  ))
	   modeline-format)))

;;;
;;; minibuffer $B$G$N%b!<%II=<($r$9$k$?$a$K(B nemacs 4 $B$GDj5A$5$l$?(B 
;;; minibuffer-preprompt $B$rMxMQ$9$k!%(B
;;;

(defconst egg:minibuffer-preprompt '("[" nil "]"))

(defun mode-line-egg-mode-update (str)
  (if (eq (current-buffer) (window-buffer (minibuffer-window)))
      (if display-minibuffer-mode-in-minibuffer
	  (progn
	    (aset (nth 0 egg:minibuffer-preprompt) 0
		  (if its:*previous-map* ?\< ?\[))
	    (setcar (nthcdr 1 egg:minibuffer-preprompt)
		    str)
	    (aset (nth 2 egg:minibuffer-preprompt) 0
		  (if its:*previous-map* ?\> ?\]))
	    (set-minibuffer-preprompt (concat
				   (car egg:minibuffer-preprompt)
				   (car (nthcdr 1 egg:minibuffer-preprompt))
				   (car (nthcdr 2 egg:minibuffer-preprompt)))))
	(setq display-minibuffer-mode t
	      mode-line-egg-mode-in-minibuffer str))
    (setq display-minibuffer-mode nil
	  mode-line-egg-mode str))
  (redraw-modeline t))

(mode-line-egg-mode-update mode-line-egg-mode)

;;;
;;; egg mode line display
;;;

(defvar alphabet-mode-indicator "aA")
(defvar transparent-mode-indicator "--")

(defun egg:mode-line-display ()
  (mode-line-egg-mode-update 
   (cond((and egg:*in-fence-mode* (not egg:*input-mode*))
	 alphabet-mode-indicator)
	((and egg:*mode-on* egg:*input-mode*)
	 (map-indicator its:*current-map*))
	(t transparent-mode-indicator))))

(defun egg:toggle-egg-mode-on-off ()
  (interactive)
  (setq egg:*mode-on* (not egg:*mode-on*))
  (egg:mode-line-display))

(defun its:select-mode (name)
  (interactive (list (completing-read "ITS mode: " its:*mode-alist*)))
  (if (its:get-mode-map name)
      (progn
	(setq its:*current-map* (its:get-mode-map name))
	(egg:mode-line-display))
    (beep)))

(defvar its:*select-mode-menu* '(menu "Mode:" nil))

(defun its:select-mode-from-menu ()
  (interactive)
  (setcar (nthcdr 2 its:*select-mode-menu*) its:*mode-alist*)
  (setq its:*current-map* (menu:select-from-menu its:*select-mode-menu*))
  (egg:mode-line-display))

(defvar its:*standard-modes* nil
  "List of standard mode-map of EGG."
  ;; 92.3.13 by K.Handa
  ;; moved to each language specific setup files (japanese.el, ...)
  ;; (list (its:get-mode-map "roma-kana")
  ;;  (its:get-mode-map "roma-kata")
  ;;  (its:get-mode-map "downcase")
  ;;  (its:get-mode-map "upcase")
  ;;  (its:get-mode-map "zenkaku-downcase")
  ;;  (its:get-mode-map "zenkaku-upcase"))
  )

(defun its:find (map list)
  (let ((n 0))
    (while (and list (not (eq map (car list))))
      (setq list (cdr list)
	    n    (1+ n)))
    (if list n nil)))

(defun its:next-mode ()
  (interactive)
  (let ((pos (its:find its:*current-map* its:*standard-modes*)))
    (setq its:*current-map*
	  (nth (% (1+ pos) (length its:*standard-modes*))
	       its:*standard-modes*))
    (egg:mode-line-display)))

(defun its:previous-mode ()
  (interactive)
  (let ((pos (its:find its:*current-map* its:*standard-modes*)))
    (setq its:*current-map*
	  (nth (1- (if (= pos 0) (length its:*standard-modes*) pos))
	       its:*standard-modes*))
    (egg:mode-line-display)))

(defun its:select-hiragana () (interactive) (its:select-mode "roma-kana"))
(defun its:select-katakana () (interactive) (its:select-mode "roma-kata"))
(defun its:select-downcase () (interactive) (its:select-mode "downcase"))
(defun its:select-upcase   () (interactive) (its:select-mode "upcase"))
(defun its:select-zenkaku-downcase () (interactive) (its:select-mode "zenkaku-downcase"))
(defun its:select-zenkaku-upcase   () (interactive) (its:select-mode "zenkaku-upcase"))

(defun its:select-mode-temporally (name)
  (interactive (list (completing-read "ITS mode: " its:*mode-alist*)))
  (let ((map (its:get-mode-map name)))
    (if map
	(progn
	  (if (null its:*previous-map*)
	      (setq its:*previous-map* its:*current-map*))
	  (setq its:*current-map*  map)
	  (egg:mode-line-display))
      (beep))))

(defun its:select-previous-mode ()
  (interactive)
  (if (null its:*previous-map*)
      (beep)
    (setq its:*current-map* its:*previous-map*
	  its:*previous-map* nil)
    (egg:mode-line-display)))
	  

(defun toggle-egg-mode ()
  (interactive)
  (if egg:*mode-on* (fence-toggle-egg-mode)
    (progn
      (setq egg:*mode-on* t)
      (egg:mode-line-display))))

(defun fence-toggle-egg-mode ()
  (interactive)
  (if its:*current-map*
      (progn
	(setq egg:*input-mode* (not egg:*input-mode*))
	(egg:mode-line-display))
    (beep)))

;;;
;;; Changes on Global map 
;;;

(defvar si:*global-map* (copy-keymap global-map))

(substitute-key-definition 'self-insert-command
			   'egg-self-insert-command
			   global-map)

;;;
;;; Currently entries C-\ and C-^ at global-map are undefined.
;;;

(define-key global-map "\C-\\" 'toggle-egg-mode)
(define-key global-map "\C-x " 'henkan-region)

;; 92.3.16 by K.Handa
;; global-map => mule-keymap
(define-key mule-keymap "m" 'its:select-mode-from-menu)
(define-key mule-keymap ">" 'its:next-mode)
(define-key mule-keymap "<" 'its:previous-mode)
(define-key mule-keymap "h" 'its:select-hiragana)
(define-key mule-keymap "k" 'its:select-katakana)
(define-key mule-keymap "q" 'its:select-downcase)
(define-key mule-keymap "Q" 'its:select-upcase)
(define-key mule-keymap "z" 'its:select-zenkaku-downcase)
(define-key mule-keymap "Z" 'its:select-zenkaku-upcase)

;;;
;;; auto fill controll
;;;

(defun egg:do-auto-fill ()
  (if (and auto-fill-function (not buffer-read-only)
	   (> (current-column) fill-column))
      (let ((ocolumn (current-column)))
	(funcall auto-fill-function)
	(while (and (< fill-column (current-column))
		    (< (current-column) ocolumn))
  	  (setq ocolumn (current-column))
	  (funcall auto-fill-function)))))

;;;----------------------------------------------------------------------
;;;
;;;  Egg fence mode
;;;
;;;----------------------------------------------------------------------

(defconst egg:*fence-open*   "|" "*$B%U%'%s%9$N;OE@$r<($9J8;zNs(B")
(defconst egg:*fence-close*  "|" "*$B%U%'%s%9$N=*E@$r<($9J8;zNs(B")
(defconst egg:*fence-face* nil  "*$B%U%'%s%9I=<($KMQ$$$k(B face $B$^$?$O(B nil")
(make-variable-buffer-local
 (defvar egg:*fence-extent* nil "$B%U%'%s%9I=<(MQ(B extent"))

(defvar egg:*face-alist*
  '(("nil" . nil)
    ("highlight" . highlight) ("modeline" . modeline)
    ("inverse" . modeline) ("underline" . underline) ("bold" . bold)
    ("region" . region)))

(defun set-egg-fence-mode-format (open close &optional face)
  "fence mode $B$NI=<(J}K!$r@_Dj$9$k!#(BOPEN $B$O%U%'%s%9$N;OE@$r<($9J8;zNs$^$?$O(B nil$B!#(B\n\
CLOSE$B$O%U%'%s%9$N=*E@$r<($9J8;zNs$^$?$O(B nil$B!#(B\n\
$BBh(B3$B0z?t(B FACE $B$,;XDj$5$l$F(B nil $B$G$J$1$l$P!"%U%'%s%96h4V$NI=<($K$=$l$r;H$&!#(B"
  (interactive (list (read-string "$B%U%'%s%93+;OJ8;zNs(B: ")
		     (read-string "$B%U%'%s%9=*N;J8;zNs(B: ")
		     (cdr (assoc (completing-read "$B%U%'%s%9I=<(B0@-(B: " egg:*face-alist*)
				 egg:*face-alist*))))

  (if (and (or (stringp open) (null open))
	   (or (stringp close) (null close))
	   (or (null face) (memq face (face-list))))
      (progn
	(setq egg:*fence-open* (or open "")
	      egg:*fence-close* (or close "")
	      egg:*fence-face* face)
	(if (extentp egg:*fence-extent*)
	    (set-extent-property egg:*fence-extent* 'face egg:*fence-face*))
	t)
    (error "Wrong type of argument: %s %s %s" open close face)))

(defvar egg:*region-start* nil)
(make-variable-buffer-local 'egg:*region-start*)
(set-default 'egg:*region-start* nil)
(defvar egg:*region-end* nil)
(make-variable-buffer-local 'egg:*region-end*)
(set-default 'egg:*region-end* nil)
(defvar egg:*global-map-backup* nil)
(defvar egg:*local-map-backup*  nil)


;;; Moved to kanji.el
;;; (defvar self-insert-after-hook nil
;;;  "Hook to run when extended self insertion command exits. Should take
;;; two arguments START and END correspoding to character position.")

(defvar egg:*self-insert-non-undo-count* 0
  "counter to hold repetition of egg-self-insert-command.")

(defun egg-self-insert-command (arg)
  (interactive "p")
  (if (and (not buffer-read-only)
	   egg:*mode-on* egg:*input-mode* 
	   (not egg:*in-fence-mode*) ;;; inhibit recursive fence mode
	   (not (= (event-to-character last-command-event) ? )))
      (egg:enter-fence-mode-and-self-insert)
    (progn
      ;; treat continuous 20 self insert as a single undo chunk.
      ;; `20' is a magic number copied from keyboard.c
      (if (or				;92.12.20 by T.Enami
	   (not (eq last-command 'egg-self-insert-command))
	   (>= egg:*self-insert-non-undo-count* 20))
	  (setq egg:*self-insert-non-undo-count* 1)
	(cancel-undo-boundary)
	(setq egg:*self-insert-non-undo-count*
	      (1+ egg:*self-insert-non-undo-count*)))
      (self-insert-command arg)
      (if egg-insert-after-hook
	  (run-hooks 'egg-insert-after-hook))
      (if self-insert-after-hook
	  (if (<= 1 arg)
	      (funcall self-insert-after-hook
		       (- (point) arg) (point)))
	(if (= (event-to-character last-command-event) ? ) (egg:do-auto-fill))))))

;;
;; $BA03NDjJQ49=hM}4X?t(B 
;;
(defvar egg:*fence-open-backup* nil)
(defvar egg:*fence-close-backup* nil)
(defvar egg:*fence-face-backup* nil)

(defconst egg:*fence-open-in-cont* "+" "*$BA03NDj>uBV$G$N(B *fence-open*")
(defconst egg:*fence-close-in-cont* t "*$BA03NDj>uBV$G$N(B *fence-close*")
(defconst egg:*fence-face-in-cont* t
  "*$BA03NDj>uBV$G$N(B *fence-face*")

(defun set-egg-fence-mode-format-in-cont (open close face)
  "$BA03NDj>uBV$G$N(B fence mode $B$NI=<(J}K!$r@_Dj$9$k!#(BOPEN $B$O%U%'%s%9$N;OE@$r<($9J8(B
$B;zNs!"(Bt $B$^$?$O(B nil$B!#(B\n\
CLOSE$B$O%U%'%s%9$N=*E@$r<($9J8;zNs!"(Bt $B$^$?$O(B nil$B!#(B\n\
FACE $B$O(B nil $B$G$J$1$l$P!"%U%'%s%96h4V$NI=<($K$=$l$r;H$&!#(B\n\
$B$=$l$>$l$NCM$,(B t $B$N>l9g!"DL>o$N(B egg:*fence-open* $BEy$NCM$r0z$-7Q$0!#(B"
  (interactive (list (read-string "$B%U%'%s%93+;OJ8;zNs(B: ")
                     (read-string "$B%U%'%s%9=*N;J8;zNs(B: ")
                     (cdr (assoc (completing-read "$B%U%'%s%9I=<(B0@-(B: " egg:*face
-alist*)
                                 egg:*face-alist*))))

  (if (and (or (stringp open) (eq open t) (null open))
           (or (stringp close) (eq close t) (null close))
           (or (null face) (eq face t) (memq face (face-list))))
      (progn
        (setq egg:*fence-open-in-cont* (or open "")
              egg:*fence-close-in-cont* (or close "")
              egg:*fence-face-in-cont* face)
        (if (extentp egg:*fence-extent*)
            (set-extent-property egg:*fence-extent* 'face egg:*fence-face*))
        t)
    (error "Wrong type of argument: %s %s %s" open close face)))

(defvar *in-cont-flag* nil
 "$BD>A0$KJQ49$7$?D>8e$NF~NO$+$I$&$+$r<($9!#(B")

(defvar *in-cont-backup-flag* nil)

(defun egg:check-fence-in-cont ()
  (if *in-cont-flag*
      (progn
	(setq *in-cont-backup-flag* t)
	(setq egg:*fence-open-backup* egg:*fence-open*)
	(setq egg:*fence-close-backup* egg:*fence-close*)
	(setq egg:*fence-face-backup* egg:*fence-face*)
        (or (eq egg:*fence-open-in-cont* t)
            (setq egg:*fence-open* egg:*fence-open-in-cont*))
        (or (eq egg:*fence-close-in-cont* t)
            (setq egg:*fence-close* egg:*fence-close-in-cont*))
        (or (eq egg:*fence-face-in-cont* t)
            (setq egg:*fence-face* egg:*fence-face-in-cont*)))))

(defun egg:restore-fence-in-cont ()
  "Restore egg:*fence-open* and egg:*fence-close*"
  (if *in-cont-backup-flag* 
      (progn
	(setq egg:*fence-open* egg:*fence-open-backup*)
	(setq egg:*fence-close* egg:*fence-close-backup*)
	(setq egg:*fence-face* egg:*fence-face-backup*)))
  (setq *in-cont-backup-flag* nil)
  )

(defun egg:enter-fence-mode-and-self-insert () 
  (setq *in-cont-flag*
	(memq last-command '(henkan-kakutei henkan-kakutei-and-self-insert)))
  (enter-fence-mode)
  (setq unread-command-events (list last-command-event)))

(defun egg:fence-face-on ()
  (if egg:*fence-face*
      (progn
	(if (extentp egg:*fence-extent*)
	    nil
	  (setq egg:*fence-extent* (make-extent 1 1 nil t))
	  (if egg:*fence-face* (set-extent-property egg:*fence-extent* 'face egg:*fence-face*)))
	(set-extent-endpoints egg:*fence-extent* egg:*region-start* egg:*region-end* ) )))

(defun egg:fence-face-off ()
  (and egg:*fence-face*
       (extentp egg:*fence-extent*)
       (detach-extent egg:*fence-extent*) ))

(defun enter-fence-mode ()
  ;; XEmacs change:
  (buffer-disable-undo (current-buffer))
  (setq egg:*in-fence-mode* t)
  (egg:mode-line-display)
  ;;;(setq egg:*global-map-backup* (current-global-map))
  (setq egg:*local-map-backup*  (current-local-map))
  ;;;(use-global-map fence-mode-map)
  ;;;(use-local-map nil)
  (use-local-map fence-mode-map)
  (egg:check-fence-in-cont)            ; for Wnn6
  (insert egg:*fence-open*)
  (or (markerp egg:*region-start*) (setq egg:*region-start* (make-marker)))
  (set-marker egg:*region-start* (point))
  (insert egg:*fence-close*)
  (or (markerp egg:*region-end*) (set-marker-insertion-type (setq egg:*region-end* (make-marker)) t))
  (set-marker egg:*region-end* egg:*region-start*)
  (egg:fence-face-on)
  (goto-char egg:*region-start*)
  )

(defun henkan-fence-region-or-single-space ()
  (interactive)
  (if egg:*input-mode*   
      (henkan-fence-region)
    (insert ? )))

(defvar egg:*henkan-fence-mode* nil)

(defun henkan-fence-region ()
  (interactive)
  (setq egg:*henkan-fence-mode* t)
  (egg:fence-face-off)
  (henkan-region-internal egg:*region-start* egg:*region-end* ))

(defun fence-katakana  ()
  (interactive)
  (katakana-region egg:*region-start* egg:*region-end* ))

(defun fence-hiragana  ()
  (interactive)
  (hiragana-region egg:*region-start* egg:*region-end*))

(defun fence-hankaku  ()
  (interactive)
  (hankaku-region egg:*region-start* egg:*region-end*))

(defun fence-zenkaku  ()
  (interactive)
  (zenkaku-region egg:*region-start* egg:*region-end*))

(defun fence-backward-char ()
  (interactive)
  (if (< egg:*region-start* (point))
      (backward-char)
    (beep)))

(defun fence-forward-char ()
  (interactive)
  (if (< (point) egg:*region-end*)
      (forward-char)
    (beep)))

(defun fence-beginning-of-line ()
  (interactive)
  (goto-char egg:*region-start*))

(defun fence-end-of-line ()
  (interactive)
  (goto-char egg:*region-end*))

(defun fence-transpose-chars (arg)
  (interactive "P")
  (if (and (< egg:*region-start* (point))
	   (< (point) egg:*region-end*))
      (transpose-chars arg)
    (beep)))

(defun egg:exit-if-empty-region ()
  (if (= egg:*region-start* egg:*region-end*)
      (fence-exit-mode)))

(defun fence-delete-char ()
  (interactive)
  (if (< (point) egg:*region-end*)
      (progn
	(delete-char 1)
	(egg:exit-if-empty-region))
    (beep)))

(defun fence-backward-delete-char ()
  (interactive)
  (if (< egg:*region-start* (point))
      (progn
	(delete-char -1)
	(egg:exit-if-empty-region))
    (beep)))

(defun fence-kill-line ()
  (interactive)
  (delete-region (point) egg:*region-end*)
  (egg:exit-if-empty-region))

(defun fence-exit-mode ()
  (interactive)
  (delete-region (- egg:*region-start* (length egg:*fence-open*)) egg:*region-start*)
  (delete-region egg:*region-end* (+ egg:*region-end* (length egg:*fence-close*)))
  (egg:fence-face-off)
  (if its:*previous-map*
      (setq its:*current-map* its:*previous-map*
	    its:*previous-map* nil))
  (egg:quit-egg-mode))

(defvar egg-insert-after-hook nil)
(make-variable-buffer-local 'egg-insert-after-hook)

(defvar egg-exit-hook nil
  "Hook to run when egg exits. Should take two arguments START and END
correspoding to character position.")

(defun egg:quit-egg-mode ()
  ;;;(use-global-map egg:*global-map-backup*)
  (use-local-map egg:*local-map-backup*)
  (setq egg:*in-fence-mode* nil)
  (egg:mode-line-display)
  (if overwrite-mode
      (let ((str (buffer-substring egg:*region-end* egg:*region-start*)))
	(delete-text-in-column nil (+ (current-column) (string-width str)))))
  (egg:restore-fence-in-cont)               ; for Wnn6
  (setq egg:*henkan-fence-mode* nil)
  (if self-insert-after-hook
      (funcall self-insert-after-hook egg:*region-start* egg:*region-end*)
    (if egg-exit-hook
	(funcall egg-exit-hook egg:*region-start* egg:*region-end*)
      (if (not (= egg:*region-start* egg:*region-end*))
	  (egg:do-auto-fill))))
  (set-marker egg:*region-start* nil)
  (set-marker egg:*region-end*   nil)
  ;; XEmacs change:
  (buffer-enable-undo (current-buffer))
  (if egg-insert-after-hook
      (run-hooks 'egg-insert-after-hook))
  )

(defun fence-cancel-input ()
  (interactive)
  (delete-region egg:*region-start* egg:*region-end*)
  (fence-exit-mode))

(defun fence-mode-help-command ()
  "Display documentation for fence-mode."
  (interactive)
  (let ((buf "*Help*"))
    (if (eq (get-buffer buf) (current-buffer))
	(henkan-quit)
      (with-output-to-temp-buffer buf
	(princ (substitute-command-keys "The keys that are defined for the fence mode here are:\\{fence-mode-map}"))
	(print-help-return-message)))))

(defvar fence-mode-map (make-keymap))

(substitute-key-definition 'egg-self-insert-command
			   'fence-self-insert-command
			   fence-mode-map global-map)

(define-key fence-mode-map "\eh"  'fence-hiragana)
(define-key fence-mode-map "\ek"  'fence-katakana)
(define-key fence-mode-map "\e<"  'fence-hankaku)
(define-key fence-mode-map "\e>"  'fence-zenkaku)
(define-key fence-mode-map "\e\C-h" 'its:select-hiragana)
(define-key fence-mode-map "\e\C-k" 'its:select-katakana)
(define-key fence-mode-map "\eq"    'its:select-downcase)
(define-key fence-mode-map "\eQ"    'its:select-upcase)
(define-key fence-mode-map "\ez"    'its:select-zenkaku-downcase)
(define-key fence-mode-map "\eZ"    'its:select-zenkaku-upcase)
(define-key fence-mode-map " "    'henkan-fence-region-or-single-space)
(define-key fence-mode-map "\C-@" 'henkan-fence-region)
(define-key fence-mode-map [(control \ )] 'henkan-fence-region)
(define-key fence-mode-map "\C-a" 'fence-beginning-of-line)
(define-key fence-mode-map "\C-b" 'fence-backward-char)
(define-key fence-mode-map "\C-c" 'fence-cancel-input)
(define-key fence-mode-map "\C-d" 'fence-delete-char)
(define-key fence-mode-map "\C-e" 'fence-end-of-line)
(define-key fence-mode-map "\C-f" 'fence-forward-char)
(define-key fence-mode-map "\C-g" 'fence-cancel-input)
(define-key fence-mode-map "\C-h" 'fence-mode-help-command)
(define-key fence-mode-map "\C-k" 'fence-kill-line)
(define-key fence-mode-map "\C-l" 'fence-exit-mode)
(define-key fence-mode-map "\C-m" 'fence-exit-mode)  ;;; RET
(define-key fence-mode-map [return] 'fence-exit-mode)
(define-key fence-mode-map "\C-q" 'its:select-previous-mode)
(define-key fence-mode-map "\C-t" 'fence-transpose-chars)
(define-key fence-mode-map "\C-w" 'henkan-fence-region)
(define-key fence-mode-map "\C-z" 'eval-expression)
(define-key fence-mode-map "\C-\\" 'fence-toggle-egg-mode)
(define-key fence-mode-map "\C-_" 'jis-code-input)
(define-key fence-mode-map "\177" 'fence-backward-delete-char)
(define-key fence-mode-map [delete] 'fence-backward-delete-char)
(define-key fence-mode-map [backspace] 'fence-backward-delete-char)
(define-key fence-mode-map [right] 'fence-forward-char)
(define-key fence-mode-map [left] 'fence-backward-char)


;;;----------------------------------------------------------------------
;;;
;;; Read hiragana from minibuffer
;;;
;;;----------------------------------------------------------------------

(defvar egg:*minibuffer-local-hiragana-map* (copy-keymap minibuffer-local-map))

(substitute-key-definition 'self-insert-command
			   'fence-self-insert-command
			   egg:*minibuffer-local-hiragana-map*
			   minibuffer-local-map)

(defun read-hiragana-string (prompt &optional initial-input)
  (save-excursion
    (let ((minibuff (window-buffer (minibuffer-window))))
      (set-buffer minibuff)
      (setq egg:*input-mode* t
	    egg:*mode-on*    t
	    its:*current-map* (its:get-mode-map "roma-kana"))
      (mode-line-egg-mode-update (its:get-mode-indicator its:*current-map*))))
  (read-from-minibuffer prompt initial-input
		       egg:*minibuffer-local-hiragana-map*))

(defun read-kanji-string (prompt &optional initial-input)
  (save-excursion
    (let ((minibuff (window-buffer (minibuffer-window))))
      (set-buffer minibuff)
      (setq egg:*input-mode* t
	    egg:*mode-on*    t
	    its:*current-map* (its:get-mode-map "roma-kana"))
      (mode-line-egg-mode-update (its:get-mode-indicator "roma-kana"))))
  (read-from-minibuffer prompt initial-input))

(defconst isearch:read-kanji-string 'read-kanji-string)

;;; $B5-9fF~NO(B

(defvar special-symbol-input-point nil)

(defun special-symbol-input ()
  (interactive)
  (require 'egg-jsymbol)
  ;; 92.7.8 by Y.Kawabe
  (let ((item (menu:select-from-menu
	       *symbol-input-menu* special-symbol-input-point t))
	(code t))
    (and (listp item)
	 (setq code (car item) special-symbol-input-point (cdr item)))
    ;; end of patch
    (cond((stringp code) (insert code))
	 ((consp code) (eval code))
	 )))

(define-key global-map "\C-^"  'special-symbol-input)

(autoload 'busyu-input "busyu" nil t)	;92.10.18 by K.Handa
(autoload 'kakusuu-input "busyu" nil t)	;92.10.18 by K.Handa

;;; egg.el ends here
