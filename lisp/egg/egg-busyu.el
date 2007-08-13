;; This file is part of Egg on Mule (Multilingual Environment)

;; Egg is distributed in the forms of patches to GNU
;; Emacs under the terms of the GNU EMACS GENERAL PUBLIC
;; LICENSE which is distributed along with GNU Emacs by the
;; Free Software Foundation.

;; Egg is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied
;; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
;; PURPOSE.  See the GNU EMACS GENERAL PUBLIC LICENSE for
;; more details.

;; You should have received a copy of the GNU EMACS GENERAL
;; PUBLIC LICENSE along with Nemacs; see the file COPYING.
;; If not, write to the Free Software Foundation, 675 Mass
;; Ave, Cambridge, MA 02139, USA.

;;;
;;;  busyu.el
;;;

;;;  Written by Toshiaki Shingu (shingu@cpr.canon.co.jp)
;;; 92.7.24 modified by T.Shingu
;;;	busyu-input and kakusuu-input is re-written.
;;; 92.8.24 modified by T.Shingu
;;;	Bub busyu-input fixed.
;;; 92.9.17 modified by K.Handa <handa@etl.go.jp>
;;;	All tables are defined directly (not by marcro).
;;; 92.9.20 modified by T.Enami <enami@sys.ptg.sony.co.jp>
;;;	In busyu-input, unnecessary mapcar avoided.
;;; 92.9.30  modified for Mule Ver.0.9.6 by T.Mitani <mit@huie.hokudai.ac.jp>
;;;	In busyu-input and kakusuu-input, bugs in kakusuu check fixed.

;;;  The tables of bushu ($BIt<s(B) and kakusuu ($B2h?t(B) are copied from:
;;;	$B!X4A;z<-=q!!!V#k#a#n7/!W!!#V#e#r#1!%#0!Y(B
;;;  with slight modifications at:
;;;	("$B$\$&!JP$(B,$BCf$J$I!K(B" . "$B$\$&(B")
;;;	("$B$d$^$$$@$l!JaK(B,$BaL$J$I!K(B" . "$B$d$^$$$@$l(B")
;;;	("$B$7$s$K$e$&!Jmh(B,$BJU!K(B" . "$B$7$s$K$e$&(B")
;;;	("$B$0$&$N$"$7!Jc;(B,$Bc<(B,$B6Y!K(B" . "$B$0$&$N$"$7(B")
;;;  In addition to the notice at the head of this file (bushu.el),
;;;  you should also obey the document below to copy or destribute
;;;  these tables.  The document is the one attached to the original.
;;;
;**************************************************************************
;
;$B!!!!4A;z<-=q!!!V#k#a#n7/!W!!#V#e#r#1!%#0(B
;                                                                H3,10,20
;**************************************************************************
;
;$B!?#1!%$O$8$a$K!?(B
;
;$B!!8=:_$NF|K\8l#F#E#P$GIt<sJQ49$H$$$F$$$k$N$O!"BhFs?e=`$N$b$N$N$_$H$$$C$?$b$N$,(B
;$BB?$/!"40A4$K%+%P!<$7$F$$$k$b$N$O8+$"$?$j$^$;$s!#$=$3$G!"Bh0l?e=`!"BhFs?e=`$H$b(B
;$BIt<sJQ49$HAm2h?t$NJQ49$,$G$-$l$PJXMx$G$O$J$$;W$$:n$j>e$2$^$7$?!#(B
;$B$3$N%G!<%?$O!"B?$/$NF|K\8l%U%m%s%H%(%s%I%W%m%;%C%5$KBP1~$7$F$$$^$9!#(B
;$B$3$N%G!<%?$r:n@.$9$k$K$O!"#J#G#A#W#K$,I,MW$G$9!#(B
;
;
;$B!?#2!%=PNO7A<0!?(B
;
;$B!&F|K\8l#F#E#P!!0l3g$G<-=qEPO?$G$-$k%F%-%9%H%U%!%$%k$r=PNO$7$^$9!#(B
;
;$B!!!!#A#T#O#K#7(B          $B!J3t!K%8%c%9%H%7%9%F%`(B
;$B!!!!>>B{#V#3(B            $B!J3t!K4IM}9)3X8&5f=j(B
;$B!!!!#W#X#2!\!J#W#X#P!K(B   $B%(!<%"%$%=%U%H!J3t!K(B
;$B!!!!#V#J#E!]&B(B          $B!J3t!K%P%C%/%9(B
;$B!!!!#D#F#J(B              $B!J3t!K%G%8%?%k!&%U%!!<%`(B
;
;$B!!!!Cm0U!K(B
;$B!!!!!!!!!&#W#X#2!\$N%?%$%W$O%U%j!<%&%'%"HG$N#W#X#P$K$bBP1~$7$F$*$j$^$9!#(B
;$B!!!!!!!!!&#V#J#E!]&B$OC1BN$G$O!"EPO?$G$-$^$;$s!#(B
;$B!!!!!!!!!!F1<R$+$iHNGd$5$l$F$$$k!V#V#J#E!]#T#o#o#l#s!W$r$*;H$$2<$5$$!#(B
;
;
;$B!?#3!%%U%!%$%k$NFbMF!?(B
;
;README.DOC      $B$3$N%I%-%a%s%H(B
;KAN   .COM      $B%G!<%?:n@.MQ%W%m%0%i%`(B
;KANMAN.TXT      TEL.BAT$B$N%3%^%s%I%j%U%!%l%s%9%7!<%H(B
;KANADV.TXT      $B%"%I%P%$%9%7!<%H!J<B9TA0$KI,$:FI$s$G2<$5$$!K(B
;BUSYU .TXT      $BIt<sFI$_BP1~%7!<%H(B
;KANJI .DAT      $B4A;z<-=q%G!<%?(B
;REPORT.TXT      $B%f!<%6!<EPO?MQ;f(B
;
;
;$B!?#4!%;HMQJ}K!!?(B
;
;$B!&MQ0U$9$kJ*(B
;
;$B$3$N%G!<%?:n@.$9$k$K$O!"#J#G#A#W#K$,I,MW$G$9!#;(;o$K$b;~!9IU$$$F$$$^$9$N$G(B
;$B$*;}$A$NJ}$OB?$$$H;W$o$l$^$9!#Bg$-$J%M%C%H$G$bBgBN%"%C%W%m!<%I$5$l$F$$$^$9!#(B
;91$BG/(B10$B7n8=:_!"<g$J%M%C%H$N=j:_$O<!$N$H$*$j$G$9!#(B
;
;NIFTY-Serve     FGALAP LIB:7    53  JGAWK29.LZH GNUawk2.11.1+2.9MSDOS$B4A;zHG(B
;ASCII-NET pcs   pool   msdos  2174  JGA_EXE.ISH GNU awk 2.11.1+2 MSDOS$BHG$N(B
;                                                $B4A;zBP1~HG$N(B.exe$B$H%^%K%e%"%k(B
;                       msdos  3655  JGA_29.ISH  jgawk 2.11.1 + 2.0 $B"*(B +2.9
;                                                (JGA_EXE.LZH $B$N:9J,%U%!%$%k(B)
;$B!&;H$$J}(B
;
;A>KAN  ($B%j%?!<%s(B)
;
;$B$G!"4JC1$J%Q%i%a!<%?$N@bL@$,$G$F$-$^$9!#(B
;$B>\$7$$@bL@$O!"IUB0$N(B KANMAN.TXT$B!!$K=q$$$F$"$j$^$9!#(B
;
;$B$?$H$($P!"#A#T#O#K#7>l9g$O<!$N$h$&$K$J$j$^$9!#(B
;
;A>KAN ATOK B 1 @
;
;ATOK    $B!!!!#A#T#O#K#7MQ(B
;B     $B!!!!Am2h?tJQ49<-=q$r=PNO(B
;1       $B!!!!Bh0l?e=`$N$_$r=PNO(B
;@       $B!!!!FI$_$K(B@$B$,IU$1$i$l$k(B
;
;$B0J>e$r<B9T$9$k$H!"(BKAN.TXT$B$H$$$&%U%!%$%k$,$G$-$^$9!#(B
;$B3F#F#E#P!"%G!<%?%Y!<%9$NEPO?J}K!$O!"3F%^%K%e%"%k$r;29M2<$5$$!#(B
;$B<-=qEPO?$J$i$P!"!V0l3g<-=qEPO?!W!V<-=qJ;9g!W$J$I$N2U=j$K=q$$$F$"$j$^$9!#(B
;
;
;$B!?#5!%%f!<%6EPO?$K$D$F!JL5=~!K!?(B
;
;  $B$$$m$$$m$NJ}$K<ALd$d;XE&!"%"%$%G%$%"$$$?$@$-$"$j$,$H$&$4$6$$$^$7$?!#%G!<%?$,(B
;$B4V0c$C$F$$$?>l9g$O!"$3$A$i$^$G$*CN$i$;$/$@$5$l$P9,$$$G$9!#<ALd$J$I$bIUB0$NEPO?(B
;$BMQ;f$r$*;H$$$/$@$5$$!#%f!<%6EPO?$N%a!<%k$r<u$1<h$C$?>l9g$O!"#1!$#2=54V0JFb$K@^(B
;$B$jJV$7$4JV;v$N%a!<%k$r:9$7>e$2$^$9!#K|0l%a!<%k$,$3$J$$>l9g$O!"$*Ld$$9g$o$;2<$5(B
;$B$$!#(B
;
;$B$^$?!"<!$N;v9`$KIU$$$F$4N;2r4j$$$^$9!#(B
;
;$B!&$3$NEPO?$O!"0lHLE*$J%f!<%6EPO?$H0c$$!"$*8_$$$K8"Mx$d5AL3$OB8:_$$$?$7$^$;$s!#(B
;$B!&;d$,!"3'MMJ}$K%G!<%?:n@.$N$*<jEA$$$r$*4j$$$7$?>l9g$O!"$*K;$7$$J}$O;EJ}$,$"$j(B
;$B!!$^$;$s$,$J$k$Y$/$46(NO2<$5$k$h$&$*4j$$$$$?$7$^$9!#(B
;$B!&$3$N%G!<%?$K$h$C$F@8$8$?$$$+$J$k;v8N$K$D$$$F$O@UG$$rIi$$$+$M$^$9!#(B
;$B!&%G!<%?$N99?7$KEX$a$^$9$,!"=t=h$N;v>p$K$h$jBZ$k>l9g$,$"$j$^$9!#(B
;$B!&Ld$$9g$o$;$J$I$K$O$J$k$Y$/$4JV;v$$$?$7$^$9!#JV;v$,#1=54V0J>eL5$$>l9g$O!"K;$7(B
;$B!!$$$+K:$l$F$$$k>l9g$G$9!#?=$7Lu$4$6$$$^$;$s$,:FEY$*Aw$j2<$5$$!#(B
;
;
;$B!?#6!%E>:\!">R2p!"HNGd$J$I$K$D$$$F!?(B
;
;$B!cE>:\!d(B
;$B!!B>$N%M%C%H$X$NE>:\$O5v2D$7$^$9$,!"E>:\<T$OI,$:%f!<%6EPO?$r9T$J$C$F2<$5$$!#(B
;$B%G!<%?$N99?7;~$K$O!":G?7HG$r%"%C%W%m!<%I$9$k$h$&$K?4$,$1$F2<$5$$!#(B
;$B!!%G!<%?$NJQ99$O:.Mp$r>7$-$^$9$N$G!"$J$k$Y$/$3$N$^$^$N7A$G%"%C%W$7$F2<$5$$!#(B
;$B$b$7!"JQ99$9$k>l9g$O0lEY$4O"Mm2<$5$$!#(B
;$B!!F1;~$K%"%C%W%m!<%I$5$l$F$$$k2<5-$N%U%!%$%k$b0l=o$KEPO?$7$F$/$@$5$$!#(B
;
;$B!&M9JXHV9fJm!!(BZIP91A.LZH $B!&;T306IHVJm!!(BTEL91A.LZH $B!&4A;z<-=q!!(BKANJIDIC.LZH
;
;$B!c>R2p!d(B
;$B!!;(;oEy$N>R2p$d<}O?$KIU$$$F$O!"99?7$J$I$G?7$?$K8x3+$7$F$$$k$b$N$,>R2p$5$l$J$$(B
;$B2DG=@-$,$"$j$^$9$N$G0lEY$4O"Mm2<$5$$!#%U%m%C%T!<$J$I$N<}O?;~$K$O!"8=;~E@$G$N!"(B
;$B=$@5HG$rDs6!$$$?$7$^$9!#(B
;
;$B!cHNGd!d(B
;$B1DMxL\E*$G$3$N%G!<%?$r<h$j9~$s$@%=%U%H$NHNGd$K$D$$$F$O0lEY$4O"Mm2<$5$$!#(B
;$B4pK\E*$KN;2r$$$?$7$^$9!#>\$7$$$3$H$O!"2~$a$FLd$$9g$o$;2<$5$$!#(B
;
;
;$B!?#7!%O"Mm@h!?(B
;
;$B%a!<%k$O2<5-$^$G$*Aw$j$/$@$5$$!#(B
;
;$B#A#S#C#I#I!]#N#E#T!J#P#C#S!K(B    pcs35011
;$B#N#I#F#T#Y!]#S#e#r#v#e(B          NAG01423
;$B#P#C!]#V#A#N(B                    GLG93462
;$BF|7P#M#I#X(B                      tadashi
;$B#M#A#S#T#E#R!]#N#E#T(B            CAG741
;**************************************************************************

(defvar busyu-table
  '[0					; ignore
    (("$B0l(B" . "$B$$$A(B")			; 1
     ("$B$\$&!JP$(B,$BCf$J$I!K(B" . "$B$\$&(B")
     ("$BP&(B" . "$B$F$s(B")
     ("$BP((B" . "$B$N(B")
     ("$B25(B" . "$B$*$D(B")
     ("$BP-(B" . "$B$O$M$\$&(B")
     )
    (("$BFs(B" . "$B$K(B")			; 2
     ("$BP5(B" . "$B$J$Y$U$?(B")
     ("$B?M(B" . "$B$R$H(B")
     ("$BQ9(B" . "$B$R$H$"$7(B")
     ("$BF~(B" . "$B$$$k(B")
     ("$BH,(B" . "$B$O$A(B")
     ("$BQD(B" . "$B$($s$,$^$((B")
     ("$BQL(B" . "$B$o$+$s$`$j(B")
     ("$BQR(B" . "$B$K$9$$(B")
     ("$BQ\(B" . "$B$D$/$((B")
     ("$BQa(B" . "$B$&$1$P$3(B")
     ("$BEa(B" . "$B$+$?$J(B")
     ("$BNO(B" . "$B$A$+$i(B")
     ("$BR1(B" . "$B$D$D$_$,$^$((B")
     ("$BR8(B" . "$B$5$8$N$R(B")
     ("$BR9(B" . "$B$O$3$,$^$((B")
     ("$BR>(B" . "$B$+$/$7$,$^$((B")
     ("$B==(B" . "$B$8$e$&(B")
     ("$BKN(B" . "$B$\$/$N$H(B")
     ("$BRG(B" . "$B$U$7$E$/$j(B")
     ("$BRL(B" . "$B$,$s$@$l(B")
     ("$BRS(B" . "$B$`(B")
     ("$BKt(B" . "$B$^$?(B")
     )
    (("$B8}!J$/$A!K(B" . "$B$/$A(B")		; 3
     ("$BSx!J$/$K$,$^$(!K(B" . "$B$/$K$,$^$((B")
     ("$BEZ(B" . "$B$D$A(B")
     ("$B;N(B" . "$B$5$`$i$$(B")
     ("$BTi(B" . "$B$U$f$,$7$i(B")
     ("$BTj(B" . "$B$9$$$K$g$&(B")
     ("$BM<(B" . "$B$f$&$Y(B")
     ("$BBg(B" . "$B$@$$(B")
     ("$B=w(B" . "$B$*$s$J(B")
     ("$B;R(B" . "$B$3(B")
     ("$BU_(B" . "$B$&$+$s$`$j(B")
     ("$B@#(B" . "$B$9$s(B")
     ("$B>.(B" . "$B$A$$$5$$(B")
     ("$BUw(B" . "$B$^$2$"$7(B")
     ("$BUy(B" . "$B$7$+$P$M(B")
     ("$BV%(B" . "$B$F$D(B")
     ("$B;3(B" . "$B$d$^(B")
     ("$BV_(B" . "$B$^$,$j$,$o(B")
     ("$B9)(B" . "$B$?$/$_(B")
     ("$B8J(B" . "$B$*$N$l(B")
     ("$B6R(B" . "$B$O$P(B")
     ("$B43(B" . "$B$[$9(B")
     ("$BVv(B" . "$B$$$H$,$7$i(B")
     ("$BVx(B" . "$B$^$@$l(B")
     ("$BW.(B" . "$B$($s$K$g$&(B")
     ("$BW0(B" . "$B$K$8$e$&$"$7(B")
     ("$BW5(B" . "$B$7$-$,$^$((B")
     ("$B5](B" . "$B$f$_(B")
     ("$BW@(B" . "$B$1$$$,$7$i(B")
     ("$BWD(B" . "$B$5$s$E$/$j(B")
     ("$BWF(B" . "$B$.$g$&$K$s$Y$s(B")
     )
    (("$B?4(B" . "$B$3$3$m(B")			; 4
     ("$BXy(B" . "$B$+$N$[$3(B")
     ("$B8M(B" . "$B$H$S$i$N$H(B")
     ("$B<j(B" . "$B$F(B")
     ("$B;Y(B" . "$B$8$e$&$^$?(B")
     ("$BZ=(B" . "$B$H$^$?(B")
     ("$BJ8(B" . "$B$V$s(B")
     ("$BEM(B" . "$B$H$^$9(B")
     ("$B6T(B" . "$B$-$s(B")
     ("$BJ}(B" . "$B$[$&(B")
     ("$BZ\(B" . "$B$9$G$N$D$/$j(B")
     ("$BF|(B" . "$B$K$A(B")
     ("$B[)(B" . "$B$R$i$S(B")
     ("$B7n(B" . "$B$D$-(B")
     ("$BLZ(B" . "$B$-(B")
     ("$B7g(B" . "$B$+$1$k(B")
     ("$B;_(B" . "$B$H$a$k(B")
     ("$B]F(B" . "$B$$$A$?(B")
     ("$B]U(B" . "$B$k$^$?(B")
     ("$B]Y(B" . "$B$J$+$l(B")
     ("$BHf(B" . "$B$/$i$Y$k$R(B")
     ("$BLS(B" . "$B$1(B")
     ("$B;a(B" . "$B$&$8(B")
     ("$B]c(B" . "$B$-$,$^$((B")
     ("$B?e(B" . "$B$_$:(B")
     ("$B2P(B" . "$B$R(B")
     ("$BD^(B" . "$B$D$a(B")
     ("$BIc(B" . "$B$A$A(B")
     ("$B`+(B" . "$B$a$a(B")
     ("$B`-(B" . "$B$7$g$&$X$s(B")
     ("$BJR(B" . "$B$+$?(B")
     ("$B2g(B" . "$B$-$P(B")
     ("$B5m(B" . "$B$&$7(B")
     ("$B8$(B" . "$B$$$L(B")
     )
    (("$B8<(B" . "$B$2$s(B")			; 5
     ("$B6L(B" . "$B$?$^(B")
     ("$B1;(B" . "$B$&$j(B")
     ("$B4$(B" . "$B$+$o$i(B")
     ("$B4E(B" . "$B$"$^$$(B")
     ("$B@8(B" . "$B$&$^$l$k(B")
     ("$BMQ(B" . "$B$b$A$$$k(B")
     ("$BED(B" . "$B$?(B")
     ("$BI%(B" . "$B$R$-(B")
     ("$B$d$^$$$@$l!JaK(B,$BaL$J$I!K(B" . "$B$d$^$$$@$l(B")
     ("$Bb"(B" . "$B$O$D$,$7$i(B")
     ("$BGr(B" . "$B$7$m(B")
     ("$BHi(B" . "$B$R$N$+$o$i(B")
     ("$B;.(B" . "$B$5$i(B")
     ("$BL\(B" . "$B$a(B")
     ("$BL7(B" . "$B$`$N$[$3(B")
     ("$BLp(B" . "$B$d(B")
     ("$B@P(B" . "$B$$$7(B")
     ("$B<((B" . "$B$7$a$9(B")
     ("$B$0$&$N$"$7!Jc;(B,$Bc<(B,$B6Y!K(B" . "$B$0$&$N$"$7(B")
     ("$B2S(B" . "$B$N$.(B")
     ("$B7j(B" . "$B$"$J(B")
     ("$BN)(B" . "$B$?$D(B")
     )
    (("$BC](B" . "$B$?$1(B")			; 6
     ("$BJF(B" . "$B$3$a(B")
     ("$B;e(B" . "$B$$$H(B")
     ("$B4L(B" . "$B$[$H$.(B")
     ("$Bf&(B" . "$B$"$_$,$7$i(B")
     ("$BMS(B" . "$B$R$D$8(B")
     ("$B1)(B" . "$B$O$M(B")
     ("$BO7(B" . "$B$*$$(B")
     ("$B<)(B" . "$B$7$+$7$F(B")
     ("$BfP(B" . "$B$i$$$9$-(B")
     ("$B<*(B" . "$B$_$_(B")
     ("$Bff(B" . "$B$U$G$E$/$j(B")
     ("$BFy(B" . "$B$K$/(B")
     ("$B?C(B" . "$B$7$s(B")
     ("$B<+(B" . "$B$_$:$+$i(B")
     ("$B;j(B" . "$B$$$?$k(B")
     ("$B11(B" . "$B$&$9(B")
     ("$B@e(B" . "$B$7$?(B")
     ("$BA$(B" . "$B$^$9(B")
     ("$B=.(B" . "$B$U$M(B")
     ("$B:1(B" . "$B$3$s(B")
     ("$B?'(B" . "$B$$$m(B")
     ("$Bgg(B" . "$B$/$5(B")
     ("$BiH(B" . "$B$H$i$,$7$i(B")
     ("$BCn(B" . "$B$`$7(B")
     ("$B7l(B" . "$B$A(B")
     ("$B9T(B" . "$B$.$g$&(B")
     ("$B0a(B" . "$B$3$m$b(B")
     ("$Bk((B" . "$B$K$7(B")
     )
    (("$B8+(B" . "$B$_$k(B")			; 7
     ("$B3Q(B" . "$B$D$N(B")
     ("$B8@(B" . "$B$3$H$P(B")
     ("$BC+(B" . "$B$?$K(B")
     ("$BF&(B" . "$B$^$a(B")
     ("$Bl5(B" . "$B$$$N$3(B")
     ("$Bl8(B" . "$B$`$8$J(B")
     ("$B3-(B" . "$B$+$$(B")
     ("$B@V(B" . "$B$"$+(B")
     ("$BAv(B" . "$B$O$7$k(B")
     ("$BB-(B" . "$B$"$7(B")
     ("$B?H(B" . "$B$_(B")
     ("$B<V(B" . "$B$/$k$^(B")
     ("$B?I(B" . "$B$+$i$$(B")
     ("$BC$(B" . "$B$7$s$N$?$D(B")
     ("$B$7$s$K$e$&!Jmh(B,$BJU!K(B" . "$B$7$s$K$e$&(B")
     ("$BM8(B" . "$B$`$i(B")
     ("$BFS(B" . "$B$5$1$N$H$j(B")
     ("$BHP(B" . "$B$N$4$a(B")
     ("$BN$(B" . "$B$5$H(B")
     )
    (("$B6b(B" . "$B$+$M(B")			; 8
     ("$BD9(B" . "$B$J$,$$(B")
     ("$BLg(B" . "$B$b$s(B")
     ("$BIl(B" . "$B$.$U$N$U(B")
     ("$Bp0(B" . "$B$l$$$E$/$j(B")
     ("$Bp2(B" . "$B$U$k$H$j(B")
     ("$B1+(B" . "$B$"$a(B")
     ("$B@D(B" . "$B$"$*(B")
     ("$BHs(B" . "$B$"$i$:(B")
     )
    (("$BLL(B" . "$B$a$s(B")			; 9
     ("$B3W(B" . "$B$+$/$N$+$o(B")
     ("$Bpj(B" . "$B$J$a$7$,$o(B")
     ("$Bpl(B" . "$B$K$i(B")
     ("$B2;(B" . "$B$*$H(B")
     ("$BJG(B" . "$B$*$*$,$$(B")
     ("$BIw(B" . "$B$+$<(B")
     ("$BHt(B" . "$B$H$V(B")
     ("$B?)(B" . "$B$7$g$/(B")
     ("$B<s(B" . "$B$/$S(B")
     ("$B9a(B" . "$B$K$*$$$3$&(B")
     )
    (("$BGO(B" . "$B$&$^(B")			; 10
     ("$B9|(B" . "$B$[$M(B")
     ("$B9b(B" . "$B$?$+$$(B")
     ("$Bqu(B" . "$B$+$_$,$7$i(B")
     ("$Br((B" . "$B$H$&$,$^$((B")
     ("$Br.(B" . "$B$A$g$&(B")
     ("$Br/(B" . "$B$+$/(B")
     ("$B54(B" . "$B$*$K(B")
     )
    (("$B5{(B" . "$B$&$*(B")			; 11
     ("$BD;(B" . "$B$H$j(B")
     ("$BsC(B" . "$B$m(B")
     ("$B</(B" . "$B$7$+(B")
     ("$BG~(B" . "$B$`$.(B")
     ("$BKc(B" . "$B$"$5(B")
     )
    (("$B2+(B" . "$B$-$$$m(B")			; 12
     ("$B5P(B" . "$B$-$S(B")
     ("$B9u(B" . "$B$/$m(B")
     ("$Bsc(B" . "$B$U$D(B")
     )
    (("$Bsf(B" . "$B$Y$s(B")			; 13
     ("$BE$(B" . "$B$+$J$((B")
     ("$B8](B" . "$B$D$E$_(B")
     ("$BAM(B" . "$B$M$:$_(B")
     )
    (("$BI!(B" . "$B$O$J(B")			; 14
     ("$Bsn(B" . "$B$;$$(B")
     )
    (("$Bso(B" . "$B$O(B")			; 15
     )
    (("$BN6(B" . "$B$j$e$&(B")			; 16
     ("$Bs}(B" . "$B$+$a(B")
     )
    (("$Bs~(B" . "$B$d$/(B")			; 17
     )
    ])

(defvar busyu-kaku-alist
  '(("$B$"$*(B"
     (8 . "$B@D(B")
     (13 . "$BLw(B")
     (14 . "$B@E(B")
     (16 . "$BpP(B"))
    ("$B$"$+(B"
     (7 . "$B@V(B")
     (12 . "$Bl_(B")
     (14 . "$B3R(B")
     (16 . "$Bl`(B"))
    ("$B$"$5(B"
     (11 . "$BKc(B")
     (14 . "$BVw(B")
     (15 . "$B]`(B")
     (18 . "$BK{(B"))
    ("$B$"$7(B"
     (7 . "$BB-(B")
     (11 . "$Blelflg(B")
     (12 . "$Blh5wliljlklllm(B")
     (13 . "$Blnlo8Ylp@WA)lqD7O)(B")
     (14 . "$BlslrMYltlu(B")
     (15 . "$BlxlvlwlyF'm)(B")
     (16 . "$Bl}lzl{D}l|(B")
     (17 . "$Bl~m!m"m#m$m%(B")
     (18 . "$Bm(@Xm&m'm*m+(B")
     (19 . "$Bm,=3m-m.(B")
     (20 . "$Bm/m0m2m1(B")
     (21 . "$Bm3m4Lv(B")
     (22 . "$Bm5m6m7(B")
     (23 . "$Bm8(B")
     (25 . "$Bm:(B")
     (27 . "$Bm9(B"))
    ("$B$"$J(B"
     (5 . "$B7j(B")
     (7 . "$B5f(B")
     (8 . "$BcV6uFM(B")
     (9 . "$BcW@`@|(B")
     (10 . "$BcX(B")
     (11 . "$B:uAkCbcZ(B")
     (12 . "$BcYc[c\(B")
     (13 . "$B7"(B")
     (14 . "$B7&c](B")
     (15 . "$B5gMRc_(B")
     (16 . "$Bc`1.(B")
     (17 . "$Bcc3v(B")
     (18 . "$Bcacb(B")
     (20 . "$Bce(B")
     (21 . "$Bc^(B")
     (22 . "$Bcf(B"))
    ("$B$"$^$$(B"
     (5 . "$B4E(B")
     (9 . "$B?S(B")
     (11 . "$BE<(B")
     (13 . "$Ba3(B"))
    ("$B$"$_$,$7$i(B"
     (6 . "$Bf&(B")
     (7 . "$Bf'(B")
     (8 . "$Bf((B")
     (9 . "$Bf)(B")
     (10 . "$Bf*f+(B")
     (13 . "$Bf,7S:a=pCVf-f.(B")
     (14 . "$BH3(B")
     (15 . "$Bf/GMHm(B")
     (16 . "$BXm(B")
     (18 . "$Bf0(B")
     (19 . "$Bf2f1Me(B")
     (22 . "$Bf4(B")
     (24 . "$Bf3(B"))
    ("$B$"$a(B"
     (8 . "$B1+(B")
     (11 . "$B@c<6(B")
     (12 . "$B1@J7(B")
     (13 . "$BEEp;MkNm(B")
     (14 . "$B<{(B")
     (15 . "$Bp<?Lp=p>Nn(B")
     (16 . "$Bp9p?p@pApBpC(B")
     (17 . "$BpD2bAz(B")
     (18 . "$BpE(B")
     (19 . "$BpFL8(B")
     (20 . "$BpGO*(B")
     (21 . "$B[1pH(B")
     (22 . "$BpIpJ(B")
     (24 . "$BpMpKpLpN(B")
     (25 . "$BpO(B"))
    ("$B$"$i$:(B"
     (8 . "$BHs(B")
     (15 . "$BpQ(B")
     (19 . "$BsS(B"))
    ("$B$$$7(B"
     (5 . "$B@P(B")
     (8 . "$Bbe(B")
     (9 . "$B8&:=:Ubfbg(B")
     (10 . "$B:VEVbi5NGKK$EW9\(B")
     (11 . "$Bbk(B")
     (12 . "$B8'9E>KN2H#bm(B")
     (13 . "$BbpORbl37:l8k10Dvbobqbn(B")
     (14 . "$Bbtbr<'HjJKbubs@Y(B")
     (15 . "$Bbwbv3Nbxbybzb{HXb|b}(B")
     (16 . "$Bc"b~c!Ka(B")
     (17 . "$B0kc#>Lc$(B")
     (18 . "$Bc&ACc'c%(B")
     (19 . "$Bc((B")
     (20 . "$Bc)bjc*bh(B"))
    ("$B$$$?$k(B"
     (6 . "$B;j(B")
     (10 . "$BCW(B")
     (14 . "$BgJ(B")
     (16 . "$BgK(B"))
    ("$B$$$A$?(B"
     (4 . "$B]F(B")
     (6 . "$B;`(B")
     (8 . "$B]G]H(B")
     (9 . "$BKX]I]J(B")
     (10 . "$B;D<l=^(B")
     (11 . "$B]K(B")
     (12 . "$B]L?#]M(B")
     (14 . "$B]N(B")
     (15 . "$B]O(B")
     (16 . "$B]P]Q(B")
     (18 . "$B]R(B")
     (19 . "$B]T(B")
     (21 . "$B]S(B"))
    ("$B$$$A(B"
     (1 . "$B0l(B")
     (2 . "$B<7Cz(B")
     (3 . "$B2<;0>e>fK|M?(B")
     (4 . "$BP"1/IT(B")
     (5 . "$B5V3n@$RBP#J:(B")
     (6 . "$B>gN>(B")
     (8 . "$BJB(B"))
    ("$B$$$H$,$7$i(B"
     (3 . "$BVv(B")
     (4 . "$B88(B")
     (5 . "$BMD(B")
     (9 . "$BM)(B")
     (12 . "$B4v(B"))
    ("$B$$$H(B"
     (6 . "$B;e(B")
     (7 . "$B7Od}(B")
     (9 . "$Bd~5*5i5j9He!Ls(B")
     (10 . "$Be"9I<S:w;f=cAGI3G<e#e$J6KBLf(B")
     (11 . "$B7Pe%8>:0:Ye';g=*>R?Be(AHe)D]e*e+N_e&(B")
     (12 . "$Be/3(5k7k0<9Je,e-e.e0e1@dE}e3Mme2(B")
     (13 . "$Be47Q8(e6e7B3e8e9e5(B")
     (14 . "$B0]e:e;e<9Ke=e>e?<z=oAmAnC>eBDVeCHlLJLV0=NPeEeFN}eGe@en(B")
     (15 . "$BeMeD1o4KeH6[eIFleJ@~eKeLDyeNJTLKeO(B")
     (16 . "$B0^ePeQ<JeReS=DeUeVeWeXG{HKK%(B")
     (17 . "$Be`eAeTeYeZ=L@SA!e\e[e]e^e_ea(B")
     (18 . "$Beiecee?%A6efegebed=+(B")
     (19 . "$BejKzeh7R7+(B")
     (20 . "$Bek;<eleoepemeq(B")
     (21 . "$BetezerE;eves(B")
     (22 . "$Beu(B")
     (23 . "$Beyewex(B")
     (25 . "$Be{(B")
     (27 . "$Be|(B"))
    ("$B$$$L(B"
     (4 . "$B8$(B")
     (5 . "$BHH(B")
     (6 . "$B`<(B")
     (7 . "$B>u68`=`>`?`;(B")
     (8 . "$B8Q`@6iA@9}`A(B")
     (9 . "$B`C69`D<mFH`B(B")
     (10 . "$B`E`FC,O5Gb(B")
     (11 . "$B`G`H`I`J`K`LCvLTND(B")
     (12 . "$BG-`M`OM1`P`N(B")
     (13 . "$B8%M21n`Q;b(B")
     (14 . "$B9v`S(B")
     (15 . "$B`R`U(B")
     (16 . "$B=C`W`V3M(B")
     (17 . "$B`X(B")
     (18 . "$B`Z(B")
     (19 . "$B`Y`\(B")
     (20 . "$B`[(B"))
    ("$B$$$N$3(B"
     (7 . "$Bl5(B")
     (11 . "$BFZ(B")
     (12 . "$B>](B")
     (13 . "$Bl6(B")
     (14 . "$B9k(B")
     (16 . "$BP.l7(B"))
    ("$B$$$k(B"
     (2 . "$BF~(B")
     (6 . "$BA4(B")
     (8 . "$BQ@(B")
     (9 . "$BQA(B"))
    ("$B$$$m(B"
     (6 . "$B?'(B")
     (19 . "$B1p(B")
     (24 . "$Bgf(B"))
    ("$B$&$*(B"
     (11 . "$B5{(B")
     (15 . "$BO%r7(B")
     (16 . "$Br80>r9J+r:r<r;(B")
     (17 . "$Br=Knr>:z;-r?A/r@(B")
     (18 . "$BrArBrC8qrDrErFrG(B")
     (19 . "$BrH7_rIrJrK;*BdrLrOrPrN03(B")
     (20 . "$BrQrSrTrU3brVrWrXrYrRrZr\OL(B")
     (21 . "$Br[r]IIr^0sr_r`(B")
     (22 . "$B3orM17rdC-rcrarb(B")
     (23 . "$BKpNZre(B")
     (24 . "$Brfrg(B")
     (26 . "$Brh(B")
     (27 . "$Bri(B"))
    ("$B$&$+$s$`$j(B"
     (3 . "$BU_(B")
     (5 . "$BU`(B")
     (6 . "$B0B1'<iBp(B")
     (7 . "$B409(AW<5(B")
     (8 . "$B084159<B=!ChDjEfJu(B")
     (9 . "$B5RUa<<@kM((B")
     (10 . "$B1c2H325\:K>,UbMF(B")
     (11 . "$BUcFR4s<d=IL)Ud(B")
     (12 . "$B4(6wUfUgIY(B")
     (13 . "$B42?2(B")
     (14 . "$BUiUj2IUh;!G+UkUl\M(B")
     (15 . "$BUm?3N@(B")
     (16 . "$BUn(B")
     (19 . "$BUpC~(B")
     (20 . "$BUo(B"))
    ("$B$&$1$P$3(B"
     (2 . "$BQa(B")
     (4 . "$B6'(B")
     (5 . "$B1z=PFL(B")
     (8 . "$BH!(B")
     (9 . "$BQb(B"))
    ("$B$&$7(B"
     (4 . "$B5m(B")
     (6 . "$BLFL6(B")
     (7 . "$B24O4(B")
     (8 . "$BKRJ*(B")
     (9 . "$B@7`2(B")
     (10 . "$BFC(B")
     (11 . "$B`38#`5(B")
     (12 . "$B:T`6`4(B")
     (14 . "$B`7`8(B")
     (17 . "$B5>(B")
     (19 . "$B`9(B")
     (20 . "$B`:(B"))
    ("$B$&$8(B"
     (4 . "$B;a(B")
     (5 . "$BL1(B")
     (8 . "$B]b(B"))
    ("$B$&$9(B"
     (6 . "$B11(B")
     (9 . "$BgLgM(B")
     (11 . "$BgN(B")
     (13 . "$BgO(B")
     (14 . "$BgP(B")
     (16 . "$B6=(B")
     (17 . "$BZ*(B")
     (18 . "$BgQ(B"))
    ("$B$&$^$l$k(B"
     (5 . "$B@8(B")
     (11 . "$B;:(B")
     (12 . "$B1ya4(B"))
    ("$B$&$^(B"
     (10 . "$BGO(B")
     (12 . "$BqGqH(B")
     (13 . "$BFkCZ(B")
     (14 . "$B1X6nBLG}qI(B")
     (15 . "$B6o2o6pqJqKqLqMCsqN(B")
     (16 . "$BqOqPqQqR(B")
     (17 . "$BqS=YqTqU(B")
     (18 . "$B53qV83qWA{qX(B")
     (19 . "$BqYBM(B")
     (20 . "$Bq[qZF-(B")
     (21 . "$Bq\q]q^q_q`(B")
     (22 . "$B6Cqaqb(B")
     (23 . "$Bqcqd(B")
     (24 . "$Bqe(B")
     (26 . "$Bqf(B")
     (27 . "$Bqgqh(B")
     (28 . "$Bqi(B")
     (29 . "$Bqk(B")
     (30 . "$Bqj(B"))
    ("$B$&$j(B"
     (6 . "$B1;(B")
     (11 . "$Ba!(B")
     (16 . "$BI;(B")
     (19 . "$Ba"(B"))
    ("$B$($s$,$^$((B"
     (2 . "$BQD(B")
     (4 . "$BFb1_(B")
     (5 . "$B:}QFQGQE(B")
     (6 . "$B:F(B")
     (7 . "$BQH(B")
     (9 . "$BQIKA(B")
     (10 . "$BQJ(B")
     (11 . "$BQK(B"))
    ("$B$($s$K$g$&(B"
     (3 . "$BW.(B")
     (7 . "$BDn(B")
     (8 . "$B1dW/(B")
     (9 . "$B2v7zG6(B"))
    ("$B$*$$(B"
     (6 . "$B9MO7(B")
     (8 . "$B<T(B")
     (10 . "$BfMfN(B")
     (12 . "$BfO(B"))
    ("$B$*$*$,$$(B"
     (9 . "$BJG(B")
     (11 . "$B:"D:(B")
     (12 . "$B9`?\=g(B")
     (13 . "$B4hprpsF\HRMB(B")
     (14 . "$B?|NN7[(B")
     (15 . "$Bpupv(B")
     (16 . "$BMjpwKKptpxF,(B")
     (17 . "$BpyIQ(B")
     (18 . "$B3[3\4ipz82p{BjN`(B")
     (19 . "$B4jE?(B")
     (21 . "$B8\(B")
     (22 . "$Bp|(B")
     (23 . "$Bp}(B")
     (24 . "$Bp~(B")
     (25 . "$Bq!(B")
     (27 . "$Bq"q#(B"))
    ("$B$*$D(B"
     (1 . "$B25(B")
     (2 . "$B6e(B")
     (3 . "$B8pLi(B")
     (7 . "$BMp(B")
     (8 . "$BF}(B")
     (11 . "$B4%55(B")
     (13 . "$BP,(B"))
    ("$B$*$H(B"
     (9 . "$B2;(B")
     (13 . "$Bpq(B")
     (14 . "$Bpp(B")
     (19 . "$B1$(B")
     (20 . "$B6A(B"))
    ("$B$*$K(B"
     (10 . "$B54(B")
     (14 . "$B3!:2(B")
     (15 . "$Br0r1L%(B")
     (17 . "$B=9(B")
     (18 . "$Br2r3r4(B")
     (21 . "$Br5Kb(B")
     (24 . "$Br6(B"))
    ("$B$*$N$l(B"
     (3 . "$BVa8JL&(B")
     (4 . "$BGC(B")
     (7 . "$BVb(B")
     (9 . "$B4,9+(B")
     (12 . "$BC'(B"))
    ("$B$*$s$J(B"
     (3 . "$B=w(B")
     (5 . "$BE[(B")
     (6 . "$BG!U!9%U"H^LQ(B")
     (7 . "$B58U#BEG%U&K8L/MEU+(B")
     (8 . "$BU%0Q8H:J;O;P>*@+09U'EJU(Ke(B")
     (9 . "$BU,0#0RU)0y4/U*;QLE18U-0((B")
     (10 . "$BU3U.I1U/8dU0L<?1U1U2JZ(B")
     (11 . "$BU4U6:'U7U8>+GLU9IXO,U:U5(B")
     (12 . "$BI2L;G^U;(B")
     (13 . "$BU<2G7yU=<;U>U?U@UL(B")
     (14 . "$BUCUAUBCdUDUE(B")
     (15 . "$BUFUG4rUHUI(B")
     (16 . "$B>nUJ(B")
     (17 . "$B1ED\UKUMUN(B")
     (19 . "$BUO(B")
     (20 . "$BUPUQUR(B"))
    ("$B$+$$(B"
     (7 . "$B3-(B")
     (9 . "$BIi(B")
     (10 . "$B9W:b(B")
     (11 . "$B2_4S@UlEHNIOlIlD(B")
     (12 . "$BlF2l5.lGLcB_CyE=lHGcHqlJKGlL(B")
     (13 . "$BB1lK;qDBO(OEA(l\(B")
     (14 . "$BFx(B")
     (15 . "$B;?;r>^lM<AlNGeIPIjlO(B")
     (16 . "$B8-ER(B")
     (17 . "$B9XlPlQlR(B")
     (18 . "$BlSlTB#lV(B")
     (19 . "$BlU4f(B")
     (20 . "$BlWlX(B")
     (21 . "$BlYl[l](B")
     (22 . "$Bl^(B"))
    ("$B$+$/$7$,$^$((B"
     (2 . "$BR>(B")
     (4 . "$B6hI$(B")
     (7 . "$B0e(B")
     (10 . "$BF?(B")
     (11 . "$BR?(B"))
    ("$B$+$/$N$+$o(B"
     (9 . "$B3W(B")
     (12 . "$BpVpW?Y(B")
     (13 . "$B7$pX(B")
     (14 . "$BpYpZ3sp\p]p[(B")
     (15 . "$Bp^0Hp_p`(B")
     (16 . "$B>d(B")
     (17 . "$B5Gpa(B")
     (18 . "$BkqpcpdJ\pb(B")
     (19 . "$Bpfpe(B")
     (22 . "$Bpg(B")
     (24 . "$Bpiph(B"))
    ("$B$+$/(B"
     (10 . "$Br/(B")
     (22 . "$Bdx(B"))
    ("$B$+$1$k(B"
     (4 . "$B7g(B")
     (6 . "$B<!(B")
     (8 . "$B2$6U(B")
     (11 . "$B]7]8M_(B")
     (12 . "$B]:4>5=6V(B")
     (13 . "$B]<]=(B")
     (14 . "$B2N]>(B")
     (15 . "$B]?4?C7(B")
     (16 . "$B]@]A(B")
     (17 . "$B]B(B")
     (18 . "$B]C(B")
     (22 . "$B]D(B"))
    ("$B$+$<(B"
     (9 . "$BIw(B")
     (12 . "$Bq$(B")
     (14 . "$Bq%q&(B")
     (17 . "$Bq'(B")
     (20 . "$Bq(q)(B")
     (21 . "$Bq*(B"))
    ("$B$+$?$J(B"
     (2 . "$BEa(B")
     (3 . "$B?OQc(B")
     (4 . "$B4"@ZJ,(B")
     (5 . "$B4)Qd(B")
     (6 . "$B7:QfNsQe(B")
     (7 . "$BQh=iH=JLMxQg(B")
     (8 . "$BQi7tQj9o:~;I@)QkE~(B")
     (9 . "$BQlQmQn:oA0B'DfQo(B")
     (10 . "$BQp7u9d:^QqGmK6(B")
     (11 . "$BQ{>jQtQrI{(B")
     (12 . "$BQs3dAOQu(B")
     (13 . "$BQvQw(B")
     (14 . "$B3D(B")
     (15 . "$BQx7`Q|N-(B")
     (16 . "$BQzQyQ}(B"))
    ("$B$+$?(B"
     (4 . "$BJR(B")
     (8 . "$BHG(B")
     (12 . "$BGW`0(B")
     (13 . "$BD-(B")
     (17 . "$B`/(B")
     (19 . "$B`1(B"))
    ("$B$+$J$((B"
     (13 . "$BE$(B"))
    ("$B$+$M(B"
     (8 . "$B6b(B")
     (10 . "$Bn[?KE#3xn]n^n\(B")
     (11 . "$Bn_KUn`6|D`na(B")
     (12 . "$BnbncndF_ng3CneoO(B")
     (13 . "$Bnh1tninjnk8Z9[nlnm>`E4noH-npNknqnv(B")
     (14 . "$Bnnnr6dns=FA,A-ntnuF<KHLCD8(B")
     (15 . "$BJ_1Tnwnx={nyCrK/IFnz(B")
     (16 . "$B6So"n{n|5xn~9]:xo!>{?m;,<bo#?no$O#O?o%o&o'n}(B")
     (17 . "$BFiDW80o)7->ao*CCo+EUIEo,o((B")
     (18 . "$Bo-3;o.:?AyDCo/DJo03yo1(B")
     (19 . "$Bo5o26@o3o4o6o7E-o8o9o:o;(B")
     (20 . "$BoEo<>bo=o>F*o?oAo@(B")
     (21 . "$BoDoBoCBxoF(B")
     (22 . "$BoILzoGoH(B")
     (23 . "$BoJ4UoKoLoMoT(B")
     (24 . "$BoN(B")
     (25 . "$BoP(B")
     (26 . "$BoQoR(B")
     (27 . "$BoSoUoVoX(B")
     (28 . "$BoW(B"))
    ("$B$+$N$[$3(B"
     (4 . "$BXy(B")
     (5 . "$BXzJj(B")
     (6 . "$BX{=?X|@.(B")
     (7 . "$B2f2|(B")
     (8 . "$B0?X}(B")
     (11 . "$BX~@LlC(B")
     (12 . "$BY!7a(B")
     (13 . "$BY"@o(B")
     (14 . "$BY#(B")
     (15 . "$B5:Y$(B")
     (16 . "$BY%(B")
     (17 . "$BY&(B")
     (18 . "$BBWY'(B"))
    ("$B$+$_$,$7$i(B"
     (10 . "$Bqu(B")
     (13 . "$Bqv(B")
     (14 . "$BH1qwqx(B")
     (15 . "$Bq|qyq{I&qzq}(B")
     (16 . "$Bq~r!(B")
     (18 . "$Br"(B")
     (21 . "$Br#(B")
     (22 . "$Br$(B")
     (23 . "$Br%(B")
     (24 . "$Br&(B")
     (25 . "$Br'(B"))
    ("$B$+$a(B"
     (16 . "$Bs}(B"))
    ("$B$+$i$$(B"
     (7 . "$B?I(B")
     (12 . "$Bmc(B")
     (13 . "$Bmd(B")
     (14 . "$Bme(B")
     (16 . "$BQ~R!(B")
     (19 . "$Bmf(B")
     (21 . "$Bmg(B"))
    ("$B$+$o$i(B"
     (5 . "$B4$(B")
     (7 . "$Ba#(B")
     (8 . "$Ba$(B")
     (9 . "$Ba%a&a(a'(B")
     (11 . "$Ba*ISa)(B")
     (14 . "$Ba+a,a-(B")
     (16 . "$Ba.a/a0(B")
     (17 . "$B9y(B")
     (18 . "$Ba1a2(B"))
    ("$B$,$s$@$l(B"
     (2 . "$BRL(B")
     (4 . "$BLq(B")
     (9 . "$B8|RMNR(B")
     (10 . "$B86(B")
     (11 . "$BRN(B")
     (12 . "$BRPRO19?_(B")
     (14 . "$B1^RQRR(B")
     (17 . "$B87(B"))
    ("$B$-$$$m(B"
     (11 . "$B2+(B")
     (25 . "$BsT(B"))
    ("$B$-$,$^$((B"
     (4 . "$B]c(B")
     (6 . "$B5$(B")
     (8 . "$B]d(B")
     (10 . "$B]f]e(B"))
    ("$B$-$P(B"
     (4 . "$B2g(B"))
    ("$B$-$S(B"
     (12 . "$B5P(B")
     (15 . "$BsU(B")
     (17 . "$BsV(B")
     (23 . "$BsW(B"))
    ("$B$-$s(B"
     (4 . "$B6T(B")
     (5 . "$B@M(B")
     (8 . "$BI`(B")
     (9 . "$BZQ(B")
     (11 . "$B;BCG(B")
     (12 . "$B;[(B")
     (13 . "$B?7(B")
     (18 . "$BZR(B"))
    ("$B$-(B"
     (4 . "$BLZ(B")
     (5 . "$B;%[2K\KvL$(B")
     (6 . "$B4y5`[3<k[4KQ[6[5[7(B")
     (7 . "$BMh[80I[9:`?y>r>sB+B<EN<][;M{[<L][=[:(B")
     (8 . "$BZ^Zb[>2L9:;^5O>>[@?u@O[AKmElGUHDHz[B[C[DKgNS[FOH[?[G[EGG(B")
     (9 . "$B[V1I2M[H[I4;[K[L[M[N8O::<F:t[P3ADSI"BH[QCl[R=@K?Gp[UJA[TM.Lx(B\
$BDNFJKo[O[W[S[J(B")
     (10 . "$B3|0F:y3J3K4<[Y5K[Z[[7K[\9;7e[^:,:O;7[_3t@r@s7,Em6MG_7*[a[][b(B\
$B@4I0[c(B")
     (11 . "$B[e[jKq[`3#[d[f8h9<[g:-[h04[i>?[kDt[l233a[o[pM|[qNB[r[u[tEn[n(B")
     (12 . "$B\&\"0X[v4=4}[w[y8![~\#\%?"?9@3\'DG\(Eo\*\+C*K@LIL:OP\/?z3q\2(B\
$B\![|\,[x[}[s\1\.\0\)\-[{[z(B")
     (13 . "$BG`\$\3\43Z4~6H6K\6\7Fj=]\8A?\:DX\;\=FoIv\?\@ML\BO0FN\>\5\D\<(B\
$B\9\CBJ\A(B")
     (14 . "$B\FO11]\G359=\I\J\K\L\NMM?:\cAdDHKjt"\P\Q\R\TLO\V\W\X:g\U\E\H(B\
$B\S\O\Y(B")
     (15 . "$B\d\Z\[\l\k2#DP\\\]8"\`\a>@\bAeCtHu\hI8\i3_\g\e\_\f\n\x(B")
     (16 . "$B3r\m5!5L66<y>AFK\rC.\s\t\u\v\w\p\o\q(B")
     (17 . "$B\}\y3`\{\|8i\~CI]!\z],[X(B")
     (18 . "$B\j]#]$]%[m]&]']((B")
     (19 . "$B6{]-]+O&])]*(B")
     (20 . "$BMs].H'(B")
     (21 . "$B]/]0]2(B")
     (22 . "$B\^(B")
     (23 . "$B]3(B")
     (25 . "$B]4(B")
     (26 . "$B15(B")
     (29 . "$B]6(B"))
    ("$B$.$U$N$U(B"
     (6 . "$Bot(B")
     (7 . "$Bow:eouovKI(B")
     (8 . "$BIlox0$AKBKIm(B")
     (9 . "$B8Boyo{oz(B")
     (10 . "$B1!4Y9_=|o~?Xp!p"JEo}p#(B")
     (11 . "$Bo|1"81p$p%DDF+GfN&N4NM(B")
     (12 . "$Bg!?o3,6yp&BbM[7((B")
     (13 . "$Bp'p(p)3V(B")
     (14 . "$B7d1#:]>c(B")
     (16 . "$Bp*p+NY(B")
     (17 . "$Bp,p.p-(B")
     (19 . "$Bp/(B"))
    ("$B$.$g$&$K$s$Y$s(B"
     (3 . "$BWF(B")
     (7 . "$BLrWG(B")
     (8 . "$BWJ1}WH7B@,WIH`(B")
     (9 . "$B8eWLWNBTN'WK(B")
     (10 . "$BWM=>=yEL(B")
     (11 . "$BWRWOWPF@WQ(B")
     (12 . "$B8fWS=[I|(B")
     (13 . "$BHyWT(B")
     (14 . "$BD'FA(B")
     (15 . "$BE0(B")
     (16 . "$BWU(B")
     (17 . "$B5+(B"))
    ("$B$.$g$&(B"
     (6 . "$B9T(B")
     (9 . "$B^'(B")
     (11 . "$BjJ=Q(B")
     (12 . "$B39(B")
     (13 . "$BjK(B")
     (15 . "$B>W(B")
     (16 . "$B1RjL9U(B")
     (24 . "$BjM(B"))
    ("$B$/$5(B"
     (6 . "$Bgggh0r(B")
     (7 . "$Bgigj2V7]<GIgK'(B")
     (8 . "$B4#3)6\gkgl?DGNgn02<c1Q1q2j6l7TIDg}LP(B")
     (9 . "$B2W2XgpgqFQgrgsB]Cwgtgwgxgygz3}g{g|Njg~gogu9S0+ApAqCc(B")
     (10 . "$Bgmh!h"7U0qh$h%h&h'B{1Ah(h)h*h+h,h-h#2Y2Zh=(B")
     (11 . "$Bh.h3h7h/h04Ph1h2h5h;2.h8G|gvh<h>h6h4hOh9h:2[5F6]:ZCxJnK((B")
     (12 . "$BhHh?0`?{hA8VhBhC>ThDhEhFhGhIEQhJhKhLhNMiI)hRF:h@hMh_0*GkArMUMn(B")
     (13 . "$B01hShU3khX3~hYIxG,F!h]Irh^h`N*hThWhbhPh[hahdh\>xC_MV(B")
     (14 . "$BhZhc38hehfhgL,IGhi<,hj=/hlhmhnAsho3wLXhhhphkDUB"(B")
     (15 . "$BhyhQ0~16hqhsht>UhuhvhwhxL"JNK)<ChzO!hr(B")
     (16 . "$BF"hV6>h{OOh|>Vh}h~i!<Ii#HYIsJCi$i+Iy70?EA&GvLt(B")
     (17 . "$B1ri&i'i(i)i*i,i-Fei/i0i2i1i3Lyi%(B")
     (18 . "$BONi6;'i4=ri5i7i8F#HMMu(B")
     (19 . "$Bi:i;i9i.i<AtMv(B")
     (20 . "$Bi"=si=i>AIi?i@iBiCiDiA(B")
     (21 . "$B]"]1b<iEiF(B")
     (23 . "$BiG(B"))
    ("$B$/$A(B"
     (3 . "$B8}(B")
     (5 . "$B3pC!2D6g8E9f;J;KB~<8>$BfRZR[1&R]R\(B")
     (6 . "$B5H5I6+R^8~9!9gD_EG1%F1L>My3F(B")
     (7 . "$B5[R_R`4^Ra6c7/8b8cRbRc9p?aRdDhReF]KJH]J-RfJrO$RgRh(B")
     (8 . "$BRiRjRkRl8FRmRn:pRo<vRp<~RqRrCNRsRtRvL#L?OBRu(B")
     (9 . "$B0%Rw0v31RxRyRzR{R|R}:HR~S!:iS"S#IJS%S$S&S>(B")
     (10 . "$BS*0wS'S)S+S,S-:6>%?0E/Eb14S.KiS/S(0"(B")
     (11 . "$BS17<S4>&>'S5BCS6BoS7S8S9LdM#S:S0S3S;S2(B")
     (12 . "$B3e1DS<S=4-S?4nS@5J6,7v9"SASBA1SCASSDSEC}SFSGSHSI6tSJ(B")
     (13 . "$BSKSLSMSN;LSOSPSQC2(B")
     (14 . "$BSR2ESSST>(SUSVSXSW(B")
     (15 . "$BSY4oSZ13S\>|S]A91=S^S_J.3z2^(B")
     (16 . "$BS`SaSbScFUH8Sd(B")
     (17 . "$B3ESeSiSjSgSf(B")
     (18 . "$BSh(B")
     (19 . "$BSkSl(B")
     (20 . "$BSmSn(B")
     (21 . "$BSoSpSqSrSs(B")
     (22 . "$BStG9Su(B")
     (24 . "$BSvSw(B"))
    ("$B$/$K$,$^$((B"
     (3 . "$BSx(B")
     (5 . "$B<|;M(B")
     (6 . "$B0x2sCD(B")
     (7 . "$B0OSy:$?^(B")
     (8 . "$B8G9qSz(B")
     (9 . "$BS{S|(B")
     (10 . "$BS}J`(B")
     (11 . "$BT"S~T!(B")
     (12 . "$BT#7w(B")
     (13 . "$BT$1`T'(B")
     (14 . "$BT%T&(B")
     (16 . "$BT((B"))
    ("$B$/$S(B"
     (9 . "$B<s(B")
     (11 . "$BqD(B")
     (17 . "$BqE(B"))
    ("$B$/$i$Y$k$R(B"
     (4 . "$BHf(B")
     (9 . "$BH{(B"))
    ("$B$/$k$^(B"
     (7 . "$B<V(B")
     (8 . "$BmB(B")
     (9 . "$B5073(B")
     (10 . "$B8.(B")
     (11 . "$BmCE>FpmD(B")
     (12 . "$BmEmF7Z<4mG(B")
     (13 . "$B3S:\mHmImJmR(B")
     (14 . "$BmKmLmNJe(B")
     (15 . "$BmM51mOmPGZ(B$BmQNXmS(B")
     (16 . "$B=4mTmUM"mV(B")
     (17 . "$BmW3mmXmYMA(B")
     (18 . "$Bm[m\mZ(B")
     (19 . "$Bm]E2(B")
     (20 . "$Bm^(B")
     (21 . "$B9lm_(B")
     (22 . "$B7%m`(B")
     (23 . "$Bmamb(B"))
    ("$B$/$m(B"
     (11 . "$B9u(B")
     (15 . "$BL[(B")
     (16 . "$B`TsX(B")
     (17 . "$BBcsYsZs[(B")
     (18 . "$Bs\(B")
     (20 . "$Bs^s](B")
     (21 . "$Bs_(B")
     (23 . "$Bs`(B")
     (26 . "$Bsa(B")
     (27 . "$Bsb(B"))
    ("$B$0$&$N$"$7(B"
     (9 . "$Bc;c<(B")
     (13 . "$B6Y(B"))
    ("$B$1$$$,$7$i(B"
     (3 . "$BW@(B")
     (6 . "$BEv(B")
     (9 . "$BWA(B")
     (11 . "$BWB(B")
     (13 . "$BWC(B")
     (16 . "$BW4(B")
     (18 . "$BW3(B"))
    ("$B$1(B"
     (4 . "$BLS(B")
     (8 . "$B][(B")
     (11 . "$B]\]](B")
     (12 . "$B]^]_(B")
     (17 . "$B]a(B"))
    ("$B$2$s(B"
     (5 . "$B8<(B")
     (11 . "$BN((B"))
    ("$B$3$3$m(B"
     (4 . "$B?4(B")
     (5 . "$BI,(B")
     (6 . "$BWVK;(B")
     (7 . "$B1~4w;VG&K:2wWWWXWYWZX-(B")
     (8 . "$B9zCiW[G0W]WaW^2x61W`@-WeWfI]WgWhWiNgWjWb(B")
     (9 . "$B1e5^;WWcBUE\WdWpW_2y2zWmWo91Wq3fWr:(WtWuWvWwWx(B")
     (10 . "$BWkWl2862637CWs=zB)CQWyNxWnX&1YWzW{8gW}W~X!X"DpG:X#X%X'X$(B")
     (11 . "$B0-45<=M*0TX)X+9{;4>pX,X.@KX/X0EiFWX1W|(B")
     (12 . "$BW\X*AZHaLeOGX=X392X5X7X8X9X<BFX?L{X:X;(B")
     (13 . "$BX(0&0U466rX4;|<f=%X6A[X>L|X234XCXAXD?5XFXHXKXIXx(B")
     (14 . "$BX@XBXEXGBVJiXJXN47XLXMXPXRXTXVXXK}XYXSXU(B")
     (15 . "$B0V7D7EXOXQXWM+M]N8X\A~X]X^X_F4XbXcJ0Ny(B")
     (16 . "$BXZX[7F7{X`XaXdXe212{Xh48XjXkXn(B")
     (17 . "$BXfXi:)XlXo(B")
     (18 . "$BD(XpXs(B")
     (19 . "$BXgXq(B")
     (20 . "$B7|Xr(B")
     (21 . "$BXuXvXw(B")
     (22 . "$BXt(B"))
    ("$B$3$H$P(B"
     (7 . "$B8@(B")
     (9 . "$B7WD{k>(B")
     (10 . "$B5-k?71k@kA?VBwF$(B")
     (11 . "$B@_kBkC5v7m>YkDK,Lu(B")
     (12 . "$B1SkEkF:>;l>Z>[?GAJkGBBkHCpkII>kJ(B")
     (13 . "$BkK3:kL5M7X8XkM;m;nkN>\@?OMkOkPM@kQOCA'(B")
     (14 . "$BkRkSkT8l8mkU;okVkW@@@bFIG'kXM6(B")
     (15 . "$B1Z2]5C?[kY=tC/@AkZBzCBCLD4k[HpNJO@k\k](B")
     (16 . "$Bk`k^0bk_4Rkakbkc8Akd;pD5D|kekfKEM!kgMXkk(B")
     (17 . "$Bkhko6`8,ki9Vkj<UklF%kmknFf(B")
     (18 . "$BkpkrksktI5ku(B")
     (19 . "$Bkwkzkvkxky7Y<1k{k|k}Ih(B")
     (20 . "$Bl#5D8n>yk~l!l"(B")
     (21 . "$Bl%l$(B")
     (22 . "$Bl&;>(B")
     (23 . "$Bl'l(=2(B")
     (24 . "$Bl*l)l+(B")
     (25 . "$Bl,(B")
     (26 . "$Bl-(B"))
    ("$B$3$a(B"
     (6 . "$BJF(B")
     (8 . "$Bdb(B")
     (9 . "$B6N7)Lb(B")
     (10 . "$Bdc?hJ4L0dd(B")
     (11 . "$BAFG4GtN3(B")
     (12 . "$Bdedg4!>Q0@didjdfdh(B")
     (13 . "$Bdkdldmdn(B")
     (14 . "$Bdo@:dqdp(B")
     (15 . "$B8RdrA8ds(B")
     (16 . "$BE|dudt(B")
     (17 . "$Bdw9GAldvJ5(B")
     (18 . "$BNH(B")
     (20 . "$Bdy(B")
     (21 . "$Bdz(B")
     (22 . "$Bd{(B")
     (25 . "$Bd|(B"))
    ("$B$3$m$b(B"
     (6 . "$B0a(B")
     (8 . "$BjNI=(B")
     (9 . "$B6^jRjSCojUjV(B")
     (10 . "$BjOjPjQ?jB5jWjXjZj[Hoj\(B")
     (11 . "$B76B^j]jYj^jTj_0Aj`jajb>X(B")
     (12 . "$B:[AuNvjeJdM5N#(B")
     (13 . "$BjfjcjdN":@jh?~jijkMgjljm(B")
     (14 . "$Bjg@=jj3ljnJ#jojpj|(B")
     (15 . "$BK+jrjsjtju(B")
     (16 . "$Bjzjvjy(B")
     (17 . "$Bjqjwjxj{p7(B")
     (18 . "$B2(6_j}(B")
     (19 . "$Bj~k!k"(B")
     (20 . "$Bk#k$(B")
     (21 . "$Bk%(B")
     (22 . "$B=1k&k'(B"))
    ("$B$3$s(B"
     (6 . "$B:1(B")
     (7 . "$BNI(B")
     (17 . "$Bge(B"))
    ("$B$3(B"
     (3 . "$BUS;R(B")
     (4 . "$B9&(B")
     (5 . "$BUT(B")
     (6 . "$B;zB8(B")
     (7 . "$B9'UUUV(B")
     (8 . "$B3XUWLR8I5((B")
     (9 . "$BUX(B")
     (10 . "$BB9(B")
     (11 . "$BUY(B")
     (12 . "$BV#(B")
     (13 . "$BUZ(B")
     (14 . "$BU[(B")
     (16 . "$BU\(B")
     (17 . "$BU^(B"))
    ("$B$5$1$N$H$j(B"
     (7 . "$BFS(B")
     (9 . "$B=6nD(B")
     (10 . "$B<`<rCqG[(B")
     (11 . "$B?lnEnF(B")
     (12 . "$BnG?]nHnf(B")
     (13 . "$B=7nIMo(B")
     (14 . "$BnJ9Z9s;@nK(B")
     (15 . "$BnMnL=fnN(B")
     (16 . "$B@CBi8oH0(B")
     (17 . "$BnO(B")
     (18 . "$BnPnQ>_nR(B")
     (20 . "$BnS>znT(B")
     (21 . "$BnU(B")
     (24 . "$BnV(B")
     (25 . "$BnW(B"))
    ("$B$5$8$N$R(B"
     (2 . "$BR8(B")
     (4 . "$B2=(B")
     (5 . "$BKL(B")
     (11 . "$B:|(B"))
    ("$B$5$H(B"
     (7 . "$BN$(B")
     (9 . "$B=E(B")
     (11 . "$BLn(B")
     (12 . "$BNL(B")
     (18 . "$BnZ(B"))
    ("$B$5$`$i$$(B"
     (3 . "$B;N(B")
     (4 . "$B?Q(B")
     (6 . "$BAT(B")
     (7 . "$BTc0m@<Gd(B")
     (11 . "$BD[(B")
     (12 . "$BTeTdTf(B")
     (13 . "$BTg(B")
     (14 . "$BTh(B"))
    ("$B$5$i(B"
     (5 . "$B;.(B")
     (8 . "$Bb3(B")
     (9 . "$BGV1NK_(B")
     (10 . "$B1Wb4(B")
     (11 . "$BEpb6@9b5(B")
     (12 . "$B]9(B")
     (13 . "$Bb7LA(B")
     (14 . "$Bb8(B")
     (15 . "$B4FHW(B")
     (16 . "$Bb9b:(B")
     (17 . "$Bb;(B"))
    ("$B$5$s$E$/$j(B"
     (3 . "$BWD(B")
     (7 . "$B7A(B")
     (9 . "$BI'(B")
     (11 . "$B:LD&I7IK(B")
     (12 . "$BWE(B")
     (14 . "$B>4(B")
     (15 . "$B1F(B"))
    ("$B$7$+$7$F(B"
     (6 . "$B<)(B")
     (9 . "$BBQ(B"))
    ("$B$7$+$P$M(B"
     (3 . "$BUy(B")
     (4 . "$BUz<\(B")
     (5 . "$B?,Ft(B")
     (6 . "$B?T(B")
     (7 . "$B6IG"U{Hx(B")
     (8 . "$BFOU|5o6~(B")
     (9 . "$B20;SU}V"Ck(B")
     (10 . "$BV!6}E8U~(B")
     (12 . "$BB0EK<H(B")
     (14 . "$BAX(B")
     (15 . "$BMz(B")
     (21 . "$BV$(B"))
    ("$B$7$+(B"
     (11 . "$B</(B")
     (13 . "$BsF(B")
     (16 . "$BsG(B")
     (17 . "$BsH(B")
     (18 . "$BsI(B")
     (19 . "$BO<sKsJsLNo(B")
     (21 . "$BsM(B")
     (23 . "$BN[(B"))
    ("$B$7$-$,$^$((B"
     (3 . "$BW5(B")
     (4 . "$BP!(B")
     (5 . "$BP1(B")
     (6 . "$B<0Fu(B")
     (12 . "$BW6(B"))
    ("$B$7$?(B"
     (6 . "$B@e(B")
     (8 . "$B<KgR(B")
     (10 . "$BgS(B")
     (12 . "$BP0(B")
     (13 . "$B<-(B")
     (15 . "$BJ^gT(B")
     (16 . "$B4\(B"))
    ("$B$7$a$9(B"
     (5 . "$B<(Ni(B")
     (7 . "$B<R(B")
     (8 . "$Bc+775';c(B")
     (9 . "$B5@=K?@ADM4(B")
     (10 . "$Bc,c-c.c/c0c1G*>M(B")
     (11 . "$B:WI<Ex8S(B")
     (12 . "$BO=(B")
     (13 . "$Bc26Xc3cI2RA5DwJ!(B")
     (14 . "$Bc4(B")
     (15 . "$Bc5(B")
     (16 . "$B5z1P(B")
     (17 . "$Bc8c6(B")
     (18 . "$Bc9(B")
     (19 . "$BG)(B")
     (22 . "$Bc:(B"))
    ("$B$7$g$&$X$s(B"
     (4 . "$B`-(B")
     (8 . "$B`.(B"))
    ("$B$7$g$/(B"
     (9 . "$B?)(B")
     (10 . "$B52(B")
     (12 . "$BHS(B")
     (13 . "$BR,0{];q,q+>~;tK0(B")
     (14 . "$B0;(B")
     (15 . "$Bq-1Bq.M\L_2n(B")
     (16 . "$Bq1;Aq/q04[(B")
     (17 . "$Bq3q2q4q5q6(B")
     (18 . "$Bq7q8(B")
     (19 . "$Bq9q:q;(B")
     (20 . "$Bq<q=(B")
     (21 . "$Bq>q?q@qAqB(B")
     (22 . "$B6BqC(B"))
    ("$B$7$m(B"
     (5 . "$BGr(B")
     (6 . "$BI4(B")
     (7 . "$Bb%b&(B")
     (8 . "$BE*(B")
     (9 . "$Bb'3'9D(B")
     (10 . "$Bb((B")
     (11 . "$B;)b)(B")
     (12 . "$Bb*b+(B")
     (13 . "$Bb,(B")
     (15 . "$Bb-(B"))
    ("$B$7$s$K$e$&(B"
     (5 . "$BmhJU9~(B")
     (6 . "$BDT?W(B")
     (7 . "$B1*KxC)6a7^JV(B")
     (8 . "$Bmi=RE3Gw(B")
     (9 . "$B2`mjmkmlmmFvmn5UAwB`DIF(LB(B")
     (10 . "$Bmqmomrm~mp@BB$B.C`DLD~ESF)O"(B")
     (11 . "$BmtmsGgmumvmwmx?`my0)n%0o=5?JBa(B")
     (12 . "$Bm{m|m}1?2a6x?kC#CYF;JWM7MZ(B")
     (13 . "$Bn!n"n#n$n&F[I/n'n(0c1s8/(B")
     (14 . "$BmzALn*t#n)B=AxE,(B")
     (15 . "$Bn+<Wn,0d=eA*A+NK(B")
     (16 . "$Bn.n/n-4THr(B")
     (17 . "$Bn0n1n2n3(B")
     (18 . "$Bcd(B")
     (19 . "$Bn4(B")
     (21 . "$Bn5(B")
     (23 . "$Bn6(B"))
    ("$B$7$s$N$?$D(B"
     (7 . "$BC$(B")
     (10 . "$B?+(B")
     (13 . "$BG@(B"))
    ("$B$7$s(B"
     (7 . "$B?C(B")
     (8 . "$B2i(B")
     (14 . "$BgI(B")
     (18 . "$BNW(B"))
    ("$B$8$e$&$^$?(B"
     (4 . "$B;Y(B"))
    ("$B$8$e$&(B"
     (2 . "$B==(B")
     (3 . "$B@i(B")
     (4 . "$B8a>#RAR@(B")
     (5 . "$BRCH>(B")
     (6 . "$BRD(B")
     (8 . "$B6(B4Bn(B")
     (9 . "$BFnH\C1(B")
     (12 . "$BGn(B"))
    ("$B$9$G$N$D$/$j(B"
     (4 . "$BZ\Z[(B")
     (10 . "$B4{(B"))
    ("$B$9$s(B"
     (3 . "$B@#(B")
     (6 . "$B;{(B")
     (7 . "$B<wBP(B")
     (9 . "$B@lIu(B")
     (10 . "$BUq<M>-(B")
     (11 . "$BUsUr0S(B")
     (12 . "$B?RB:(B")
     (14 . "$BUt(B")
     (15 . "$BF3(B"))
    ("$B$;$$(B"
     (14 . "$Bsn(B")
     (17 . "$Bc7(B")
     (21 . "$BlZ(B")
     (23 . "$Bpm(B"))
    ("$B$?$+$$(B"
     (10 . "$B9b(B")
     (23 . "$Bqt(B"))
    ("$B$?$/$_(B"
     (3 . "$B9)(B")
     (5 . "$B5p9*:8(B")
     (7 . "$BV`(B")
     (10 . "$B:9(B"))
    ("$B$?$1(B"
     (6 . "$BC](B")
     (8 . "$B<3(B")
     (9 . "$B4Hcs(B")
     (10 . "$B5hct>Pcucvd$(B")
     (11 . "$Bcw?ZcxcyBhczE+Idc|3^:{c}c{(B")
     (12 . "$BH&c~6Zd":vd#d%d&C^EyEzE{H5I.d8(B")
     (13 . "$Bd!d'd(d)d*d.@ad-d+d,(B")
     (14 . "$Bd=2U4Id/L'd0d1d2d3d4;;d5d6d7Gsd9JO(B")
     (15 . "$Bd:d;H"d>@}H$d?JSd<C=HO(B")
     (16 . "$BC[d@dAdDdEO6dBFF(B")
     (17 . "$BRUdG<DdHdJdKdNdMdIdLdC(B")
     (18 . "$B4JdOdPdQdR(B")
     (19 . "$BdSdTdUHvJmN|dZ(B")
     (20 . "$B@RdVdWdY(B")
     (21 . "$Bd[d_dX(B")
     (22 . "$Bd\d]dF(B")
     (23 . "$Bd^d`(B")
     (25 . "$Bda(B"))
    ("$B$?$D(B"
     (5 . "$BN)(B")
     (7 . "$Bcg(B")
     (8 . "$Bch(B")
     (9 . "$BTtcjci(B")
     (10 . "$BclckcmN5(B")
     (11 . "$B>Ocnpo(B")
     (12 . "$Bco=WcpF8(B")
     (13 . "$BC((B")
     (14 . "$BcqC<cr(B")
     (20 . "$B6%(B")
     (22 . "$BQ?(B"))
    ("$B$?$K(B"
     (7 . "$BC+(B")
     (11 . "$Bl.(B")
     (17 . "$Bl/l0(B"))
    ("$B$?$^(B"
     (4 . "$B2&(B")
     (5 . "$B6L(B")
     (7 . "$B6j(B")
     (8 . "$B4a(B")
     (9 . "$B2Q`];9DA`_``Nh`a`^(B")
     (10 . "$B7>`b<n`cHIN0`d`~(B")
     (11 . "$B5e8=M}`f`i(B")
     (12 . "$BBv6W`hH|`kNV`jGJ(B")
     (13 . "$B1M`l8j`n?p`p`q`v`m`o(B")
     (14 . "$B`gt$`s`t:<`uN\(B")
     (15 . "$B`r`w`xM~(B")
     (16 . "$B`e`y(B")
     (17 . "$B4D(B")
     (18 . "$B`z(B")
     (19 . "$B<%`{(B")
     (20 . "$B`|(B")
     (21 . "$B`}(B"))
    ("$B$?(B"
     (5 . "$B9C?=EDM3(B")
     (7 . "$BR4CKD.a6(B")
     (8 . "$B2ha7(B")
     (9 . "$BZB0Z3&a8H*a:a<a9(B")
     (10 . "$Ba;C\HJ@&a=N1H+(B")
     (11 . "$B0[7Ma?I-N,a@a>(B")
     (12 . "$BaA>vHVaBaG(B")
     (13 . "$BaCFmaD(B")
     (15 . "$B5&(B")
     (16 . "$BaJ(B")
     (19 . "$BaEaF(B")
     (22 . "$BaHaI(B"))
    ("$B$@$$(B"
     (3 . "$BBg(B")
     (4 . "$BToB@E7IWTp(B")
     (5 . "$B1{<:Tq(B")
     (6 . "$B0PTr(B")
     (7 . "$BTs(B")
     (8 . "$B1b4qF`JtK[(B")
     (9 . "$BTuTvTw7@AU(B")
     (10 . "$BTxTyEe(B")
     (12 . "$B1|TzT{(B")
     (13 . "$BT|>)(B")
     (14 . "$BT~T}C%(B")
     (16 . "$BJ3(B"))
    ("$B$A$$$5$$(B"
     (3 . "$B>.(B")
     (4 . "$B>/(B")
     (5 . "$BUu(B")
     (6 . "$B@m(B")
     (8 . "$B>0(B")
     (13 . "$BUv(B"))
    ("$B$A$+$i(B"
     (2 . "$BNO(B")
     (5 . "$B2C8y(B")
     (6 . "$BNt(B")
     (7 . "$BR"9e=uR#EXNeO+(B")
     (8 . "$BR%3/8zR$(B")
     (9 . "$BR&D<KVM&(B")
     (10 . "$BR'JY(B")
     (11 . "$B4*F0R(L3pU(B")
     (12 . "$BR)6P>!Jg(B")
     (13 . "$B4+@*R+R-R*(B")
     (15 . "$B7.(B")
     (16 . "$BR.(B")
     (17 . "$BR/(B")
     (20 . "$BR0(B"))
    ("$B$A$A(B"
     (4 . "$BIc(B")
     (13 . "$BLl(B"))
    ("$B$A$g$&(B"
     (10 . "$Br.(B")
     (29 . "$B]5(B"))
    ("$B$A(B"
     (6 . "$B7l(B")
     (9 . "$BjI(B")
     (10 . "$BjH(B")
     (12 . "$B=0(B"))
    ("$B$D$-(B"
     (4 . "$B7n(B")
     (6 . "$BM-(B")
     (8 . "$BI~J~(B")
     (9 . "$B[,(B")
     (10 . "$B:sD?O/(B")
     (11 . "$B[-K>(B")
     (12 . "$B4|[.D+(B")
     (18 . "$B[/(B")
     (20 . "$B[0(B"))
    ("$B$D$/$((B"
     (2 . "$BQ\(B")
     (3 . "$BK^(B")
     (5 . "$B=hB|(B")
     (6 . "$BQ^Fd(B")
     (8 . "$BQ_(B")
     (11 . "$BQ`(B")
     (12 . "$B3.(B"))
    ("$B$D$A(B"
     (3 . "$BEZ(B")
     (5 . "$B05T)(B")
     (6 . "$B7=:_COT*T+(B")
     (7 . "$BT,T-6Q9#:AT.T/:dK7(B")
     (8 . "$BT0:%?bC3T3T4DZT56F(B")
     (9 . "$BT23@T6T77?9$>kT9T:T;T8(B")
     (10 . "$BTBT1T<KdT?T@T>T=(B")
     (11 . "$BTA0h4p:kKY<9>}BOF2G]IVTDTCG8(B")
     (12 . "$BTE1aTF4.7x>lBDDMDiEHEcJsTHN]J=TN:ft!(B")
     (13 . "$BTJ2tH9TMA::IE6EIEdJhTKTI1v(B")
     (14 . "$BTG6-TO=NTP?PA}KO(B")
     (15 . "$BTXTRDFJ/TSTQTW(B")
     (16 . "$BTT2u:&>mCEJITY(B")
     (17 . "$BTVTZT[9hT\(B")
     (18 . "$BT^T](B")
     (19 . "$BTUT`Tb(B")
     (20 . "$BTaT_(B"))
    ("$B$D$D$_$,$^$((B"
     (2 . "$BR1(B")
     (3 . "$B<[(B")
     (4 . "$B8{L^FwLh(B")
     (5 . "$BR2Jq(B")
     (6 . "$BR3(B")
     (9 . "$BR5(B")
     (11 . "$BR7R6(B"))
    ("$B$D$E$_(B"
     (13 . "$B8](B")
     (14 . "$Bsi(B")
     (18 . "$Bsj(B"))
    ("$B$D$N(B"
     (7 . "$B3Q(B")
     (12 . "$Bk8k9k:(B")
     (13 . "$B2r?((B")
     (15 . "$Bk;(B")
     (18 . "$Bk<(B")
     (20 . "$Bk=(B"))
    ("$B$D$a(B"
     (4 . "$BD^(B")
     (8 . "$B`'`((B")
     (9 . "$B`)(B")
     (12 . "$B`*(B")
     (17 . "$B<_(B"))
    ("$B$F$D(B"
     (3 . "$BV%(B")
     (4 . "$BFV(B"))
    ("$B$F$s(B"
     (1 . "$BP&(B")
     (3 . "$B4](B")
     (4 . "$BC0(B")
     (5 . "$B<gP'(B"))
    ("$B$F(B"
     (3 . "$B:M(B")
     (4 . "$B<jY)(B")
     (5 . "$BBGJ'(B")
     (6 . "$BY*Y+Y,Y-07BqY.(B")
     (7 . "$BY/5;Y193Y3>6Y4BrEjY5GDH4HcI^J1Y7Y8M^Y2@^Y0(B")
     (8 . "$B>5Y;YDY62!Y92}3HY:5q5r94>7@[BsY>C4CjDqY@GRGoYBHdYCYEJzYFKuYGZ-(B")
     (9 . "$BY<YA0DYH3gYI64YJYL9i;";X;}=&YN?!YOD)YK(B")
     (10 . "$BY=5sYM7}YRYQ0'YP:C?6DrA\A^B*YT;+HTJaD=(B")
     (11 . "$BYU1f3]YV5E?xYW7!7G7~95:N<N<x>9?dYY@\A<A]C5Y[Y\Y]FhG1GSJ{Y_N+(B\
$BY`YXY^DO(B")
     (12 . "$B>8YZYgIA0.1gYaYb494xYdYeYfB7DsYhYiM,MHMIYc(B")
     (13 . "$BYSEkYj7HYlYmYnYo@]A_B;YqYrYsHB:q(B")
     (14 . "$BYkYt@"YvE&LNYw(B")
     (15 . "$B7bYuK`;#@q;5F5E1YzG2GEY{IoKPY|Y}Yy3I(B")
     (16 . "$BZ$Z!Y?Y~Z"Z#A`Z%MJZ'(B")
     (17 . "$BZ&Z(5<;$Z+Z,E'Z.Z/(B")
     (18 . "$BZ)Z2>qZ3Z4Z6Z1Z9(B")
     (19 . "$BZ5(B")
     (20 . "$BZ7(B")
     (21 . "$BZ8Yp(B")
     (22 . "$BZ:(B")
     (23 . "$BZ;YxZ<(B")
     (24 . "$BZ0(B"))
    ("$B$H$&$,$^$((B"
     (10 . "$Br((B")
     (15 . "$Br)(B")
     (16 . "$Br*(B")
     (18 . "$Br+(B")
     (20 . "$Br,(B")
     (26 . "$Br-(B"))
    ("$B$H$S$i$N$H(B"
     (4 . "$B8M(B")
     (7 . "$BLa(B")
     (8 . "$BK<=j(B")
     (9 . "$BY((B")
     (10 . "$B@p(B")
     (11 . "$Bn=(B")
     (12 . "$BHb(B"))
    ("$B$H$V(B"
     (9 . "$BHt(B")
     (21 . "$BfL(B"))
    ("$B$H$^$9(B"
     (4 . "$BEM(B")
     (10 . "$BNA(B")
     (11 . "$BZO<P(B")
     (13 . "$BZP(B")
     (14 . "$B06(B"))
    ("$B$H$^$?(B"
     (4 . "$BZ=Z>(B")
     (6 . "$BZ@Z?(B")
     (7 . "$B2~96;ZZA(B")
     (8 . "$BJ|(B")
     (9 . "$B8N@/(B")
     (10 . "$BZCIR(B")
     (11 . "$B<OZEZFZG5_65ZDGT(B")
     (12 . "$B4:7I;6ZHFXZI(B")
     (13 . "$B?t(B")
     (14 . "$BZJ(B")
     (15 . "$BZKE(I_(B")
     (16 . "$B@0(B")
     (17 . "$BZL(B")
     (18 . "$BZM(B")
     (22 . "$BZN(B"))
    ("$B$H$a$k(B"
     (4 . "$B;_(B")
     (5 . "$B@5:!(B")
     (8 . "$BIpJb(B")
     (9 . "$BOD(B")
     (12 . "$B;u(B")
     (13 . "$B:P(B")
     (14 . "$BNr(B")
     (18 . "$B]E(B"))
    ("$B$H$i$,$7$i(B"
     (6 . "$BiH(B")
     (8 . "$B8W(B")
     (9 . "$B5T(B")
     (10 . "$BiJ(B")
     (11 . "$BQ]5u(B")
     (13 . "$BiK6sN:(B")
     (17 . "$BiL(B"))
    ("$B$H$j(B"
     (9 . "$Brk(B")
     (11 . "$BD;(B")
     (13 . "$BroH7rjrl(B")
     (14 . "$BFPK1LD(B")
     (15 . "$BrnrmrprqF>(B")
     (16 . "$B1u3{rvrx<2ryrurrrs2)2*rt(B")
     (17 . "$Brw9crzr{r|r}r~(B")
     (18 . "$Bs!s"s$9t1-s%L9s#s&(B")
     (19 . "$B7\s's(s)s+K2s,(B")
     (20 . "$Bs-s.s/s*(B")
     (21 . "$Bs1Das2s3s4s5s0s8s6s7(B")
     (22 . "$Bs9s:(B")
     (23 . "$Bs;OIs<s=s>:m(B")
     (24 . "$Bs?Bk(B")
     (28 . "$Bs@(B")
     (29 . "$BsA(B")
     (30 . "$BsB(B"))
    ("$B$J$+$l(B"
     (4 . "$B]Y(B")
     (5 . "$BJl(B")
     (6 . "$BKh(B")
     (8 . "$BFG(B")
     (14 . "$B]Z(B"))
    ("$B$J$,$$(B"
     (8 . "$BD9(B"))
    ("$B$J$Y$U$?(B"
     (2 . "$BP5(B")
     (3 . "$BK4(B")
     (4 . "$BP6(B")
     (6 . "$BKr0g8r(B")
     (7 . "$B5|(B")
     (8 . "$B5}5~(B")
     (9 . "$BP7DbN<(B")
     (10 . "$BP8(B")
     (13 . "$BP9(B"))
    ("$B$J$a$7$,$o(B"
     (9 . "$Bpj(B")
     (17 . "$B4Z(B")
     (19 . "$Bpk(B"))
    ("$B$K$*$$$3$&(B"
     (9 . "$B9a(B")
     (18 . "$BqF(B")
     (20 . "$B3>(B"))
    ("$B$K$/(B"
     (6 . "$BFyH)O>(B")
     (7 . "$B4Nfjfk>SI*fl(B")
     (8 . "$Bfn0i9N8*8T:h9O;hHnKCfofm(B")
     (9 . "$B0_0}8UfpfqfrB[C@fsftGXGYfufvK&fw(B")
     (10 . "$B6;6<OFfx;i@H@TF9G=L.fy(B")
     (11 . "$Bf|5Sfzf{C&G>f}(B")
     (12 . "$Bf~9P?UD1g"g#g$g%g&OS(B")
     (13 . "$Bg*g'<pg)D2J"g+9xA#g5g((B")
     (14 . "$BIeg,g-9QB\g.g/Klg0(B")
     (15 . "$Bg6g1I(g4Ifg2g3(B")
     (16 . "$Bg7A7g8KDg9(B")
     (17 . "$Bg<22g:g=G?g>g?g@g;gE(B")
     (18 . "$BgAgB(B")
     (19 . "$BB!gD(B")
     (20 . "$BgCgF(B")
     (22 . "$BgG(B")
     (25 . "$BgH(B"))
    ("$B$K$7(B"
     (6 . "$Bk(@>(B")
     (9 . "$BMW(B")
     (12 . "$Bk)(B")
     (18 . "$BJ$(B")
     (19 . "$Bk*GF(B")
     (25 . "$Bk+(B"))
    ("$B$K$8$e$&$"$7(B"
     (3 . "$BW0(B")
     (4 . "$BF{(B")
     (5 . "$BJ[(B")
     (7 . "$BO.W1(B")
     (10 . "$BW2(B")
     (15 . "$BJ@(B"))
    ("$B$K$9$$(B"
     (2 . "$BQR(B")
     (5 . "$BE_(B")
     (6 . "$BQTQVQSQU(B")
     (7 . "$B:cLjNdQW(B")
     (8 . "$BQX(B")
     (10 . "$BQY=Z@(C|E`QZ(B")
     (11 . "$BN?(B")
     (12 . "$BRE(B")
     (15 . "$BQ[(B")
     (16 . "$B6E(B"))
    ("$B$K$A(B"
     (4 . "$BF|(B")
     (5 . "$BC65l(B")
     (6 . "$B00;]=\Aa(B")
     (7 . "$BZ](B")
     (8 . "$B0W2"Z_:+:*>:>;@NZ`L@Za(B")
     (9 . "$B971G:rZc=U><@'@1ZdKfZeZf[&(B")
     (10 . "$BZg98Zh;~?8ZiZj;/(B")
     (11 . "$BZl3"ZkZmZnZoZpZq(B")
     (12 . "$B6G7J=k>=@2ZrCRHUIaZs(B")
     (13 . "$BZuZx0EZt2KZvZwCH(B")
     (14 . "$BD*JkZyNq(B")
     (15 . "$B;CK=(B")
     (16 . "$BZ|ZzZ{Z}F^[!Z~["(B")
     (17 . "$B[#(B")
     (18 . "$B=l[$MK(B")
     (19 . "$B[%Gx(B")
     (20 . "$B['(B")
     (21 . "$B[((B"))
    ("$B$K$i(B"
     (9 . "$Bpl(B")
     (13 . "$BG#(B")
     (19 . "$Bpn(B"))
    ("$B$K(B"
     (2 . "$BFs(B")
     (3 . "$BP2(B")
     (4 . "$B1>8^8_0f(B")
     (6 . "$BOJOK(B")
     (7 . "$B0!:3(B")
     (8 . "$BP3(B")
     (9 . "$BP4(B"))
    ("$B$M$:$_(B"
     (8 . "$Bsk(B")
     (13 . "$BAM(B")
     (18 . "$Bsl(B"))
    ("$B$N$.(B"
     (5 . "$B2S(B")
     (7 . "$B;d=(FE(B")
     (8 . "$Bc=(B")
     (9 . "$B2J=)c>IC(B")
     (10 . "$BHkc?c@>NGi?AAECacBcA(B")
     (11 . "$B0\(B")
     (12 . "$BcC5)@GcDDx(B")
     (13 . "$BL-CUcGI#NGcHcEcF(B")
     (14 . "$BcJ9r<o0p(B")
     (15 . "$BcK2T7N9FcLcMJfcN(B")
     (16 . "$B0,1O2:@QKT(B")
     (17 . "$BcPcO(B")
     (18 . "$BcR3O>wcQ(B")
     (19 . "$BcS(B")
     (21 . "$BcT(B")
     (22 . "$BcU(B"))
    ("$B$N$4$a(B"
     (7 . "$BHP(B")
     (8 . "$B:S(B")
     (11 . "$B<a(B")
     (12 . "$BnX(B")
     (20 . "$BnY(B"))
    ("$B$N(B"
     (1 . "$BP((B")
     (2 . "$BP)G5(B")
     (3 . "$B5W(B")
     (4 . "$BG7(B")
     (5 . "$B8CFcK3(B")
     (7 . "$BiI(B")
     (8 . "$BP*(B")
     (9 . "$B>h(B")
     (10 . "$BP+(B"))
    ("$B$O$3$,$^$((B"
     (2 . "$BR9(B")
     (6 . "$B6)>"(B")
     (7 . "$BR:(B")
     (10 . "$BH[(B")
     (13 . "$BR;(B")
     (14 . "$BR<(B")
     (15 . "$BR=(B"))
    ("$B$O$7$k(B"
     (5 . "$Bla(B")
     (7 . "$BAv(B")
     (9 . "$BIk(B")
     (10 . "$B5/lb(B")
     (12 . "$B1[D6lc(B")
     (14 . "$Bld(B")
     (15 . "$B<q(B")
     (17 . "$B?v(B"))
    ("$B$O$A(B"
     (2 . "$BH,(B")
     (4 . "$BQB8xO;(B")
     (6 . "$B6&(B")
     (7 . "$BJ<(B")
     (8 . "$BB66qE5(B")
     (10 . "$B7s(B")
     (16 . "$BQC(B"))
    ("$B$O$D$,$7$i(B"
     (5 . "$Bb"(B")
     (9 . "$Bb#H/(B")
     (12 . "$Bb$EP(B"))
    ("$B$O$J(B"
     (14 . "$BI!(B")
     (17 . "$Bsm(B"))
    ("$B$O$M$\$&(B"
     (1 . "$BP-(B")
     (2 . "$BN;(B")
     (4 . "$BM=(B")
     (6 . "$BAh(B")
     (7 "$BP/(B"))
    ("$B$O$M$\$&(B"
     (8 . "$B;v(B"))
    ("$B$O$M(B"
     (6 . "$B1)(B")
     (10 . "$B2'fBfC(B")
     (11 . "$B=,MbfD(B")
     (12 . "$BfEfF(B")
     (14 . "$B?ifG(B")
     (15 . "$B4efHfI(B")
     (16 . "$B4M(B")
     (17 . "$BfJMc(B")
     (18 . "$BfKK](B")
     (20 . "$BMT(B"))
    ("$B$O$P(B"
     (3 . "$B6R(B")
     (5 . "$BAY;TI[(B")
     (6 . "$BHA(B")
     (7 . "$B4uVc(B")
     (8 . "$BD!VdVeVfVg(B")
     (9 . "$B?cDk(B")
     (10 . "$B;U@JBS5"(B")
     (11 . "$BVhVi>oD"(B")
     (12 . "$BVjVkVlI}K9Vs(B")
     (13 . "$BKZKkVm(B")
     (14 . "$BVnVo(B")
     (15 . "$BVpVqH(J>Vr(B"))
    ("$B$O(B"
     (15 . "$Bso(B")
     (17 . "$BspNp(B")
     (20 . "$Bsqsrssst(B")
     (21 . "$Bsusv(B")
     (22 . "$Bsxsw(B")
     (24 . "$Bsyszs{(B"))
    ("$B$R$-(B"
     (5 . "$BI%(B")
     (11 . "$BAA(B")
     (12 . "$BAB(B")
     (14 . "$B5?(B"))
    ("$B$R$D$8(B"
     (6 . "$BMS(B")
     (8 . "$Bf5(B")
     (9 . "$BH~(B")
     (10 . "$Bf6(B")
     (11 . "$Bf7f8f9(B")
     (13 . "$B5A72f:A"(B")
     (15 . "$Bf;f>(B")
     (16 . "$Bf<(B")
     (19 . "$Bf=f?f@(B")
     (20 . "$BfA(B"))
    ("$B$R$H$"$7(B"
     (2 . "$BQ9(B")
     (3 . "$BQ:(B")
     (4 . "$B0t85(B")
     (5 . "$B7;(B")
     (6 . "$B6$8w=<@hC{(B")
     (7 . "$B9n;yQ<EF(B")
     (8 . "$BQ;Q=LH(B")
     (10 . "$BE^(B")
     (11 . "$B3u(B")
     (14 . "$BQ>(B"))
    ("$B$R$H(B"
     (2 . "$B?M(B")
     (4 . "$B2p5X:#=:P;?NP<P=J)P>P:(B")
     (5 . "$B0J;E;FP?P@PA@gPBB>BeIUNa(B")
     (6 . "$B0K2>2qPC4k4l5Y6D7o8`PDCgEAG$H2IzPg(B")
     (7 . "$BPG0LPE2?2@PFPH:4:n;G;w=;?-PIC"PJBNDcDQGlH<M$M>NbU$(B")
     (8 . "$B0M2A2B4&PK6!8s;HPL;xPMPNPOPPPQInJ;PRPSPTNcPU6"PVKy(B")
     (9 . "$B2d78PW8tPX=SPY?.?/B%B/PZJXP[J]P\P]P^N7P_P`Ks(B")
     (10 . "$BPaOA26Pb6fPcPd7p7q8D8u8vPePf<ZPhPiPjPkCME]GPG\PlI6PmJoJpPnPo(B\
$BNQAR=$(B")
     (11 . "$BPqPvPpPsPt566vPu7r<EPwPxB&PyDdDeJP0N(B")
     (12 . "$BPzP{;1HwP|K57f=~(B")
     (13 . "$BQ#P}6O79P~:D:E=}Q!Q"ANMCQ$F/(B")
     (14 . "$BQ&Q%6#Q'Q(Q)A|Q*KMN=(B")
     (15 . "$BQ+Q-2/57Q,Q.Q/JH(B")
     (16 . "$B<tQ1Q2Q3Q0(B")
     (17 . "$BM%Q4(B")
     (18 . "$BLY(B")
     (21 . "$BQ5Q6(B")
     (22 . "$BQ7Q8(B"))
    ("$B$R$N$+$o$i(B"
     (5 . "$BHi(B")
     (10 . "$Bb.(B")
     (12 . "$Bb/(B")
     (14 . "$Bb0b1(B")
     (15 . "$Bb2(B"))
    ("$B$R$i$S(B"
     (4 . "$B[)(B")
     (6 . "$B1H6J(B")
     (7 . "$B[*99(B")
     (9 . "$B[+(B")
     (10 . "$B=q(B")
     (11 . "$BRXAbA>(B")
     (12 . "$B:GA=BX(B")
     (13 . "$BPr(B"))
    ("$B$R(B"
     (4 . "$B2P(B")
     (6 . "$B3%Et(B")
     (7 . "$B5d:R<^(B")
     (8 . "$B1j_U?f_VO'(B")
     (9 . "$B_W_Y_ZC:_[_\0YE@_q(B")
     (10 . "$B1(__Nu_`_^_](B")
     (11 . "$B_X_aK#_b(B")
     (12 . "$B1k_c<Q>F>GA3L5J2_d(B")
     (13 . "$B1l_e_f_h_i_j>H@y_kGa_lN{HQ(B")
     (14 . "$B_g_m@z_o7'_pMP(B")
     (15 . "$B_r=OG.(B")
     (16 . "$BEu_v1m_t_u_wG3_x_yNU_s(B")
     (17 . "$BRYS[_z_{;8?$_|Ag_}(B")
     (18 . "$B_n_~`!`"(B")
     (19 . "$BGz`#(B")
     (20 . "$B`$(B")
     (21 . "$B`%(B")
     (29 . "$B`&(B"))
    ("$B$U$$$K$g$&(B"
     (3 . "$BTj(B")
     (10 . "$B2F(B")
     (14 . "$BTk(B"))
    ("$B$U$7$E$/$j(B"
     (2 . "$BRG(B")
     (5 . "$BRH1,RI(B")
     (6 . "$B0u4m(B")
     (7 . "$B5QB(Mq(B")
     (8 . "$BRK(B")
     (9 . "$BRJ27(B")
     (10 . "$B6*(B"))
    ("$B$U$D(B"
     (12 . "$Bsc(B")
     (17 . "$Bsd(B")
     (19 . "$Bse(B"))
    ("$B$U$G$E$/$j(B"
     (6 . "$Bff(B")
     (11 . "$B=M(B")
     (13 . "$Bfifgfh(B")
     (14 . "$BH%(B"))
    ("$B$U$M(B"
     (6 . "$B=.(B")
     (10 . "$B9RHLgVgUgd(B")
     (11 . "$BBIgW8?A%gXGu(B")
     (13 . "$BDzgY(B")
     (16 . "$BgZg[(B")
     (17 . "$Bg]g\(B")
     (18 . "$Bg^(B")
     (19 . "$Bg`g_(B")
     (20 . "$Bga(B")
     (21 . "$B4Ogb(B")
     (22 . "$Bgc(B"))
    ("$B$U$f$,$7$i(B"
     (3 . "$BTi(B")
     (9 . "$BJQ(B"))
    ("$B$U$k$H$j(B"
     (8 . "$Bp2(B")
     (10 . "$B@IH;(B")
     (11 . "$B?}Ue(B")
     (12 . "$B4g8[=8M:(B")
     (13 . "$B2m;sp3p4p5p6(B")
     (14 . "$B;((B")
     (16 . "$Bp:(B")
     (17 . "$Bj-(B")
     (18 . "$BRVp8?wFq(B")
     (19 . "$BN%(B"))
    ("$B$V$s(B"
     (4 . "$BJ8(B")
     (7 . "$BU](B")
     (8 . "$B@F(B")
     (11 . "$B:X(B")
     (12 . "$BHCHeIL(B"))
    ("$B$Y$s(B"
     (13 . "$Bsf(B")
     (24 . "$Bsg(B")
     (25 . "$Bsh(B"))
    ("$B$[$&(B"
     (4 . "$BJ}(B")
     (8 . "$B1w(B")
     (9 . "$B;\(B")
     (10 . "$BZSZTZUZVN9(B")
     (11 . "$BZWB2@{(B")
     (12 . "$BZX(B")
     (14 . "$B4z(B")
     (16 . "$BZZ(B")
     (18 . "$BZY(B"))
    ("$B$[$9(B"
     (3 . "$B43(B")
     (5 . "$BJ?(B")
     (6 . "$BVtG/Vu(B")
     (8 . "$B9,(B")
     (13 . "$B44(B"))
    ("$B$[$H$.(B"
     (6 . "$B4L(B")
     (9 . "$Be}(B")
     (10 . "$Be~(B")
     (17 . "$Bf!(B")
     (20 . "$Bf"(B")
     (21 . "$Bf#(B")
     (22 . "$Bf$(B")
     (24 . "$Bf%(B"))
    ("$B$[$M(B"
     (10 . "$B9|(B")
     (13 . "$Bql(B")
     (14 . "$Bqm(B")
     (16 . "$B3<qn(B")
     (18 . "$Bqo(B")
     (19 . "$B?q(B")
     (21 . "$Bqp(B")
     (23 . "$Bqsqrqq(B"))
    ("$B$\$&(B"
     (3 . "$BP$(B")
     (4 . "$BCf(B")
     (5 . "$BP%(B")
     (7 . "$B6z(B"))
    ("$B$\$/$N$H(B"
     (2 . "$BKN(B")
     (4 . "$BRF(B")
     (5 . "$B@j(B")
     (8 . "$B75(B")
     (9 . "$BDg(B"))
    ("$B$^$,$j$,$o(B"
     (3 . "$BV_@n(B")
     (6 . "$B=#=d(B")
     (11 . "$BAc(B"))
    ("$B$^$2$"$7(B"
     (3 . "$BUw(B")
     (4 . "$BL`(B")
     (7 . "$BUx(B")
     (12 . "$B="(B"))
    ("$B$^$9(B"
     (6 . "$BA$(B")
     (12 . "$B=X(B")
     (15 . "$BIq(B"))
    ("$B$^$?(B"
     (2 . "$BKt(B")
     (3 . "$B:5(B")
     (4 . "$B5ZAPH?M'(B")
     (5 . "$B<}(B")
     (8 . "$B<h<u=G(B")
     (9 . "$B=vH@(B")
     (10 . "$BRW(B")
     (16 . "$B1C(B")
     (18 . "$BAQ(B"))
    ("$B$^$@$l(B"
     (3 . "$BVx(B")
     (5 . "$B9-D#>1(B")
     (7 . "$B=x>2H_(B")
     (8 . "$B9.DlE9I\Jy(B")
     (9 . "$BEYVy(B")
     (10 . "$B8K:BDm(B")
     (11 . "$B0C9/MG=n(B")
     (12 . "$BVzV{GQO-(B")
     (13 . "$BV|Nw(B")
     (14 . "$B3GV~V}W!(B")
     (15 . "$BW"W&W#>3W$W%I@W'(B")
     (16 . "$BW(W)(B")
     (19 . "$BW*(B")
     (20 . "$BW-(B")
     (21 . "$BW+(B")
     (25 . "$BW,(B"))
    ("$B$^$a(B"
     (7 . "$BF&(B")
     (10 . "$Bl1(B")
     (13 . "$BK-(B")
     (15 . "$Bl2l3(B")
     (18 . "$Bl4(B"))
    ("$B$_$:$+$i(B"
     (6 . "$B<+(B")
     (9 . "$B=-(B"))
    ("$B$_$:(B"
     (4 . "$B?e(B")
     (5 . "$B1JI9=ADuHE(B")
     (6 . "$B1x4@9>]hFr<.CSHF]i(B")
     (7 . "$B5a]g]j5%]k5b7h]l:;]m]nBABt2-D@FY]o]p]q]r]tKW]sM`(B")
     (8 . "$B7#1K]u1h]v]w2O5c67]x]y]z]|>B]}<#CmE%]~GHGq^"Hg^#J(K!K"^$KwL}^!^%]{(B")
     (9 . "$B@t^&1L3$3h^(^)9?^*^+^,='^-MN>tDE^/@u@v@wF6GIMl^0^.(B")
     (10 . "$BBY^3^1^29@^4>C^5?;^6^7^8^:IMIb1:Ma3=N.N^O2M0EsFB(B")
     (11 . "$B^F^I0|1UJ%^<^=^;363i^>^?7L^A^B:.^C=B=J=_>D^D?<@6:Q^G^H^JC8E:(B\
$BMdEq^KNC^MNT^N^E^L^@(B")
     (12 . "$B^Y=m0/^O^P2912^R5t8:8P9A^U^V<"<>>E^W^XL+B,C9^Z^[EOEr^]^^^_K~(B\
$B^a^bM/OQ^Q^\^T^S^cH.(B")
     (13 . "$B^d0n3j4A8;9B^e^f^g^h=`^i^j^k^lBZE.^mGy^p^q^rLGMON/Bl^o(B")
     (14 . "$B^`^|1i^t^v^w^xDR<?^zA2Af^{^}E)^~I:L!_!Nz5yO39w_#4C_"(B")
     (15 . "$B^n^s^y_'_(_1DY4B_$7i_%_&=a_)3c@x_*_,@!_-D,_._/_0_3_L(B")
     (16 . "$B_7_5_2_47c_6By_8ECG;_9_:(B")
     (17 . "$B_@_;_<9jG(_=Bu^9_?_A_B_>oi(B")
     (18 . "$B_G_C_D_E_FMt_H_I(B")
     (19 . "$BFTBm_+_J_KCuIN@%_M_N(B")
     (20 . "$B_O_P_Q_R(B")
     (21 . "$B^u(B")
     (22 . "$B_SFg(B")
     (25 . "$B_T(B"))
    ("$B$_$_(B"
     (6 . "$B<*(B")
     (9 . "$BLmfW(B")
     (10 . "$BfVC?(B")
     (11 . "$BfXfY(B")
     (12 . "$BfZ(B")
     (13 . "$B@;f[(B")
     (14 . "$Bf]f\AoJ9f^(B")
     (15 . "$Bf_(B")
     (17 . "$Bfbf`faD0N~(B")
     (18 . "$Bfc?&(B")
     (20 . "$Bfd(B")
     (22 . "$BfeO8(B"))
    ("$B$_$k(B"
     (7 . "$B8+(B")
     (11 . "$B5,;kk,(B")
     (12 . "$B3PGAk-(B")
     (14 . "$Bk.(B")
     (16 . "$Bk/?Fk0(B")
     (17 . "$Bk1k2Mw(B")
     (18 . "$B4Qk3(B")
     (20 . "$Bk4(B")
     (21 . "$Bk5(B")
     (22 . "$Bk6(B")
     (25 . "$Bk7(B"))
    ("$B$_(B"
     (7 . "$B?H(B")
     (10 . "$Bm;(B")
     (11 . "$B6m(B")
     (12 . "$Bm<(B")
     (13 . "$Bm>(B")
     (16 . "$Bm?(B")
     (19 . "$Bm@(B")
     (20 . "$Bm=(B")
     (24 . "$BmA(B"))
    ("$B$`$.(B"
     (7 . "$BG~(B")
     (11 . "$BsNsP(B")
     (15 . "$BsOsQ(B")
     (16 . "$BsR(B")
     (19 . "$B9m(B")
     (20 . "$BLM(B"))
    ("$B$`$7(B"
     (6 . "$BCn(B")
     (8 . "$BiM(B")
     (9 . "$BFz0:(B")
     (10 . "$BiNiPGB;=2ciSiOiQiR(B")
     (11 . "$BiT7ViW<XCAiXi[iUiViY3B(B")
     (12 . "$B3?i\i]i^i_i`H:IHiaHZib(B")
     (13 . "$Bic2kidieB}ifigihiiijK*ilimik(B")
     (14 . "$BioipiqirCXisitL*inO9(B")
     (15 . "$Biv2\iwixiyizi{i|?*D3i}i~j!iuj"j#@fGh(B")
     (16 . "$Bj%j&j'M;(B")
     (17 . "$Bj(j)j*j.j/j0Mfj3j+j2j1j,(B")
     (18 . "$Bj5j4j6j=(B")
     (19 . "$Bj;j<3*j7j85Bj9j:j$(B")
     (20 . "$Bj>j?j@(B")
     (21 . "$BjAiZjB(B")
     (23 . "$BjCjF(B")
     (24 . "$BjDjE(B")
     (25 . "$BjG(B"))
    ("$B$`$8$J(B"
     (7 . "$Bl8(B")
     (10 . "$Bl9I?(B")
     (11 . "$BlA(B")
     (12 . "$Bl:(B")
     (13 . "$Bl;l<l=(B")
     (14 . "$Bl>KF(B")
     (15 . "$Bl?(B")
     (17 . "$Bl@(B")
     (18 . "$BlB(B"))
    ("$B$`$N$[$3(B"
     (5 . "$BL7(B")
     (9 . "$Bbb(B"))
    ("$B$`$i(B"
     (7 . "$BM8n7FaK.(B")
     (8 . "$Bn8n9n:E!<Y(B")
     (9 . "$B0j9YO:(B")
     (10 . "$Bn;74n<n>(B")
     (11 . "$B3T6?ETItM9(B")
     (12 . "$Bn?(B")
     (13 . "$Bn@(B")
     (14 . "$BnA(B")
     (15 . "$BE"nBnC(B"))
    ("$B$`(B"
     (2 . "$BRS(B")
     (5 . "$B5n(B")
     (8 . "$B;2(B")
     (11 . "$BRT(B"))
    ("$B$a$a(B"
     (4 . "$B`+(B")
     (9 . "$B`,(B")
     (11 . "$BAV(B")
     (14 . "$B<$(B"))
    ("$B$a$s(B"
     (9 . "$BLL(B")
     (14 . "$BpR(B")
     (16 . "$BpS(B")
     (23 . "$BpT(B"))
    ("$B$a(B"
     (5 . "$BL\(B")
     (8 . "$BD>LU(B")
     (9 . "$B4Gb==bAj>Jb>H}b?b@8)(B")
     (10 . "$BbA??bCbDbEbFL2bB(B")
     (11 . "$B4cbGD/bH(B")
     (12 . "$BCebI(B")
     (13 . "$BbJbKbL?gbMFDbNKS(B")
     (14 . "$BbObPbQ(B")
     (15 . "$BbRbSbT(B")
     (16 . "$BbUbV(B")
     (17 . "$BbWF7JMNFbXbY(B")
     (18 . "$BbZb[b\=Vb](B")
     (19 . "$Bb^(B")
     (20 . "$Bb_(B")
     (24 . "$Bb`(B")
     (26 . "$Bba(B"))
    ("$B$b$A$$$k(B"
     (5 . "$BMQ(B")
     (7 . "$BJca5(B"))
    ("$B$b$s(B"
     (8 . "$BLg(B")
     (9 . "$BoY(B")
     (10 . "$BA.(B")
     (11 . "$BJDoZo[(B")
     (12 . "$B3+4V4W1<o\o](B")
     (13 . "$Bo^o`o_(B")
     (14 . "$B3U4Xoa9^obH6(B")
     (15 . "$B1\oc(B")
     (16 . "$Bodoeofog(B")
     (17 . "$B0Gohojokol(B")
     (18 . "$BomonooF.(B")
     (19 . "$Bop(B")
     (20 . "$Boq(B")
     (21 . "$Boros(B"))
    ("$B$d$/(B"
     (17 . "$Bs~(B"))
    ("$B$d$^$$$@$l(B"
     (7 . "$BaK(B")
     (8 . "$BaLaM(B")
     (9 . "$B1VaNaO(B")
     (10 . "$BaPaQaRaS<@aT>I?>aUaVHhIBaW(B")
     (11 . "$BaX:/<&aYaZ(B")
     (12 . "$Ba[a\DKEwa]N!(B")
     (13 . "$Ba^a_a`aaabCTadaeac(B")
     (14 . "$Bafagah(B")
     (15 . "$BaiajakalAiaman(B")
     (16 . "$Baoapaq(B")
     (17 . "$Bar4basNEat(B")
     (18 . "$BauJJL~av(B")
     (19 . "$Baw(B")
     (20 . "$Bax(B")
     (21 . "$Bayaza{a|(B")
     (22 . "$Ba}(B")
     (23 . "$Ba~(B")
     (24 . "$Bb!(B"))
    ("$B$d$^(B"
     (3 . "$B;3(B")
     (4 . "$BV&(B")
     (5 . "$BV'(B")
     (6 . "$BV((B")
     (7 . "$B4tV)V*V,V+(B")
     (8 . "$B3Y4_2,L(V-A;BRV1V.V3V2V0V/4d(B")
     (9 . "$B6.V5F=V4(B")
     (10 . "$BV72eV6=TV9EgJvJwV;V8(B")
     (11 . "$BV>V<33V=:jV@VAVBVC?rVDJxVGVFVE(B")
     (12 . "$BVKV?VHVJMrVI?s(B")
     (13 . "$BVL:7VMVN(B")
     (14 . "$BV:EhVOVPVQ(B")
     (15 . "$BVWVRVS(B")
     (16 . "$BVUVT(B")
     (17 . "$BVVVXVYNf(B")
     (20 . "$B4`VZ(B")
     (21 . "$BV[(B")
     (22 . "$BV\V](B")
     (23 . "$BV^(B"))
    ("$B$d(B"
     (5 . "$BLp(B")
     (7 . "$Bbc(B")
     (9 . "$BGj(B")
     (10 . "$B6k(B")
     (12 . "$BC;(B")
     (13 . "$Bbd(B")
     (17 . "$B6:(B"))
    ("$B$f$&$Y(B"
     (3 . "$BM<(B")
     (5 . "$B30(B")
     (6 . "$B=HB?Tl(B")
     (8 . "$BLk(B")
     (11 . "$BTm(B")
     (13 . "$BL4(B")
     (14 . "$BTn(B"))
    ("$B$f$_(B"
     (3 . "$B5](B")
     (4 . "$B0zD$W7(B")
     (5 . "$B90J&(B")
     (6 . "$BCP(B")
     (7 . "$BDo(B")
     (8 . "$B89W8Lo(B")
     (9 . "$B8LW9W?(B")
     (10 . "$B<e(B")
     (11 . "$B6/D%W:(B")
     (12 . "$BCFI+(B")
     (13 . "$BW;(B")
     (15 . "$BW<(B")
     (16 . "$B60(B")
     (17 . "$BW=(B")
     (22 . "$BW>(B"))
    ("$B$i$$$9$-(B"
     (6 . "$BfP(B")
     (10 . "$BfQ9LfRLW(B")
     (11 . "$BfS(B")
     (13 . "$BfT(B")
     (16 . "$BfU(B"))
    ("$B$j$e$&(B"
     (16 . "$BN6(B")
     (22 . "$Bs|(B"))
    ("$B$k$^$?(B"
     (4 . "$B]U(B")
     (8 . "$B2%(B")
     (9 . "$BCJ(B")
     (10 . "$B]V;&(B")
     (11 . "$B3L(B")
     (12 . "$B]W(B")
     (13 . "$BTLEB(B")
     (15 . "$B]X5#(B"))
    ("$B$l$$$E$/$j(B"
     (8 . "$Bp0(B")
     (16 . "$BNl(B")
     (17 . "$Bp1(B"))
    ("$B$m(B"
     (11 . "$BsC(B")
     (20 . "$BsD(B")
     (24 . "$BsE84(B"))
    ("$B$o$+$s$`$j(B"
     (2 . "$BQL(B")
     (4 . "$B>i(B")
     (5 . "$B<L(B")
     (9 . "$B4'(B")
     (10 . "$BQMQOL=QN(B")
     (11 . "$BIZ(B")
     (14 . "$BQP(B")
     (16 . "$BQQ(B"))
    ))

(defvar kakusuu-table
  '[0					; ignore
    "$B0lP&P(25P-(B"			; 1
    "$B<7CzP)G56eN;FsP5?MQ9F~H,QDQLQRQ\QaEaNOR1R8R9R>==KNRGRLRSKt(B" ; 2
    "$B2<;0>e>fK|M?P$4]5W8pLiP2K4Q:K^?OQc<[@i:58}SxEZ;NTiTjM<Bg=wUS(B\
$B;RU_@#>.UwUyV%;3V_@n9)Va8JL&6R43VvVxW.W0W55]W@WDWF:M(B" ; 3
    "$BP"1/ITCfC0G7M=1>8^8_0fP62p5X:#=:P;?NP<P=J)P>P:0t85QB8xO;Fb1_(B\
$B>i6'4"@ZJ,8{L^FwLh2=6hI$8a>#RAR@RFLq5ZAPH?M'?QToB@E7IWTp9&>/(B\
$BL`Uz<\FVV&GC88F{P!0zD$W7?4Xy8M<jY);YZ=Z>J8EM6TJ}Z\Z[F|[)7nLZ(B\
$B7g;_]F]U]YHfLS;a]c?e2PD^Ic`+`-JR2g5m8$2&(B" ; 4
    "$B5V3n@$RBP#J:P%<gP'8CFcK30J;E;FP?P@PA@gPBB>BeIUNa7;:}QFQGQE<L(B\
$BE_=hB|1z=PFL4)Qd2C8yR2JqKLRCH>@jRH1,RI5n<}3pC!2D6g8E9f;J;KB~(B\
$B<8>$BfRZR[1&R]R\<|;M05T)301{<:TqE[UTU`Uu?,FtV'5p9*:8AY;TI[J?(B\
$BMD9-D#>1J[P190J&I,XzJjBGJ'@MC65l;%[2K\KvL$@5:!JlL11JI9=ADuHE(B\
$BHH8<6L4$4E@8MQ9C?=EDM3I%b"GrHi;.L\L7Lp@P<(Ni2S7jN)lamhJU9~(B" ; 5
    "$B>gN>AhOJOKKr0g8r0K2>2qPC4k4l5Y6D7o8`PDCgEAG$H2IzPg6$8w=<@hC{(B\
$BA46&:FQTQVQSQUQ^Fd7:QfNsQeNtR36)>"RD0u4m5H5I6+R^8~9!9gD_EG1%(B\
$BF1L>My3F0x2sCD7=:_COT*T+AT=HB?Tl0PTrG!U!9%U"H^LQ;zB80B1'<iBp(B\
$B;{@m?TV(=#=dHAVtG/Vu<0FuCPEvWVK;X{=?X|@.Y*Y+Y,Y-07BqY.Z@Z?00(B\
$B;]=\Aa1H6JM-4y5`[3<k[4KQ[6[5[7<!;`Kh5$1x4@9>]hFr<.CSHF]i3%Et(B\
$BLFL6`<1;I4C]JF;e4Lf&MS1)9MO7<)fP<*ffFyH)O><+;j11@eA$=.:1?'gg(B\
$Bgh0riHCn7l9T0ak(@>DT?Wot(B" ; 6
    "$B6ziIMpP/0!:35|PG0LPE2?2@PFPH:4:n;G;w=;?-PIC"PJBNDcDQGlH<M$M>(B\
$BNbU$9n;yQ<EFJ<QH:cLjNdQWQh=iH=JLMxQgR"9e=uR#EXNeO+R:0e5QB(Mq(B\
$B5[R_R`4^Ra6c7/8b8cRbRc9p?aRdDhReF]KJH]J-RfJrO$RgRh0OSy:$?^T,(B\
$BT-6Q9#:AT.T/:dK7Tc0m@<GdTs58U#BEG%U&K8L/MEU+9'UUUV409(AW<5<w(B\
$BBPUx6IG"U{Hx4tV)V*V,V+V`Vb4uVc=x>2H_DnO.W1Do7ALrWG1~4w;VG&K:(B\
$B2wWWWXWYWZX-2f2|LaY/5;Y193Y3>6Y4BrEjY5GDH4HcI^J1Y7Y8M^Y2@^Y0(B\
$B2~96;ZZAU]Z][*99Mh[80I[9:`?y>r>sB+B<EN<][;M{[<L][=[:5a]g]j5%(B\
$B]k5b7h]l:;]m]nBABt2-D@FY]o]p]q]r]tKW]sM`5d:R<^24O4>u68`=`>`?(B\
$B`;6ja#Jca5R4CKD.a6aKb%b&bc<R;d=(FE5fcg7Od}f'4Nfjfk>SI*fl?CNI(B\
$Bgigj2V7]<GIgK'8+3Q8@C+F&l5l83-@VAvB-?H<V?IC$1*KxC)6a7^JVM8n7(B\
$BFaK.FSHPN$ow:eouovKIG~(B" ; 7
    "$BJBP*F};vP35}5~0M2A2B4&PK6!8s;HPL;xPMPNPOPPPQInJ;PRPSPTNcPU6"(B\
$BPVKyQ;Q=LHQ@B66qE5QXQ_H!Qi7tQj9o:~;I@)QkE~R%3/8zR$6(B4Bn75RK(B\
$B;2<h<u=GRiRjRkRl8FRmRn:pRo<vRp<~RqRrCNRsRtRvL#L?OBRu8G9qSzT0(B\
$B:%?bC3T3T4DZT56FLk1b4qF`JtK[U%0Q8H:J;O;P>*@+09U'EJU(Ke3XUWLR(B\
$B8I5(084159<B=!ChDjEfJu>0FOU|5o6~3Y4_2,L(V-A;BRV1V.V3V2V0V/4d(B\
$BD!VdVeVfVg9,9.DlE9I\Jy1dW/89W8LoWJ1}WH7B@,WIH`9zCiW[G0W]WaW^(B\
$B2x61W`@-WeWfI]WgWhWiNgWjWb0?X}K<=j>5Y;YDY62!Y92}3HY:5q5r94>7(B\
$B@[BsY>C4CjDqY@GRGoYBHdYCYEJzYFKuYGZ-J|@FI`1w0W2"Z_:+:*>:>;@N(B\
$BZ`L@ZaI~J~Z^Zb[>2L9:;^5O>>[@?u@O[AKmElGUHDHz[B[C[DKgNS[FOH[?[G(B\
$B[EGG2$6UIpJb]G]H2%FG][]b]d7#1K]u1h]v]w2O5c67]x]y]z]|>B]}<#Cm(B\
$BE%]~GHGq^"Hg^#J(K!K"^$KwL}^!^%]{1j_U?f_VO'`'`(`.HGKRJ*8Q`@6i(B\
$BA@9}`A4aa$2ha7aLaME*b3D>LUbec+775';cc=cV6uFMch<3dbf(f5<Tfn(B\
$B0i9N8*8T:h9O;hHnKCfofm2i<KgR4#3)6\gkgl?DGNgn02<c1Q1q2j6l7TID(B\
$Bg}LP8WiMjNI=mBmi=RE3Gwn8n9n:E!<Y:S6bD9LgIlox0$AKBKImp0p21+@D(B\
$BHssk(B" ; 8
    "$B>hP4P7DbN<2d78PW8tPX=SPY?.?/B%B/PZJXP[J]P\P]P^N7P_P`KsQAQIKA(B\
$B4'QbQlQmQn:oA0B'DfQoR&D<KVM&R5FnH\C1DgRJ278|RMNR=vH@0%Rw0v31(B\
$BRxRyRzR{R|R}:HR~S!:iS"S#IJS%S$S&S>S{S|T23@T6T77?9$>kT9T:T;T8(B\
$BJQTuTvTw7@AUU,0#0RU)0y4/U*;QLE18U-0(UX5RUa<<@kM(@lIu20;SU}V"(B\
$BCk6.V5F=V44,9+?cDkM)EYVy2v7zG68LW9W?WAI'8eWLWNBTN'WK1e5^;WWc(B\
$BBUE\WdWpW_2y2zWmWo91Wq3fWr:(WtWuWvWwWxY(Y<YA0DYH3gYI64YJYL9i(B\
$B;";X;}=&YN?!YOD)YK8N@/ZQ;\971G:rZc=U><@'@1ZdKfZeZf[&[+[,[V1I(B\
$B2M[H[I4;[K[L[M[N8O::<F:t[P3ADSI"BH[QCl[R=@K?Gp[UJA[TM.LxDNFJ(B\
$BKo[O[W[S[JODKX]I]JCJH{@t^&1L3$3h^(^)9?^*^+^,='^-MN>tDE^/@u@v(B\
$B@wF6GIMl^0^._W_Y_ZC:_[_\0YE@_q`)`,@7`2`C69`D<mFH`B2Q`];9DA`_(B\
$B``Nh`a`^a%a&a(a'?SZB0Z3&a8H*a:a<a91VaNaOb#H/b'3'9DGV1NK_4Gb=(B\
$B=bAj>Jb>H}b?b@8)bbGj8&:=:Ubfbg5@=K?@ADM4c;c<2J=)c>ICcW@`@|Tt(B\
$Bcjci4Hcs6N7)Lbd~5*5i5j9He!Lse}f)H~BQLmfW0_0}8UfpfqfrB[C@fsft(B\
$BGXGYfufvK&fw=-gLgM2W2XgpgqFQgrgsB]Cwgtgwgxgygz3}g{g|Njg~gogu(B\
$B9S0+ApAqCc5TFz0:jI^'6^jRjSCojUjVMW7WD{k>IiIk50732`mjmkmlmmFv(B\
$Bmn5UAwB`DIF(LB0j9YO:=6nD=EoY8Boyo{ozLL3Wpjpl2;JGIwHt?)<s9ark(B" ; 9
    "$BP+P8PaOA26Pb6fPcPd7p7q8D8u8vPePf<ZPhPiPjPkCME]GPG\PlI6PmJoJp(B\
$BPnPoNQAR=$E^7sQJQMQOL=QNQY=Z@(C|E`QZQp7u9d:^QqGmK6R'JYH[F?6*(B\
$B86RWS*0wS'S)S+S,S-:6>%?0E/Eb14S.KiS/S(0"S}J`TBT1T<KdT?T@T>T=(B\
$B2FTxTyEeU3U.I1U/8dU0L<?1U1U2JZB91c2H325\:K>,UbMFUq<M>-V!6}E8(B\
$BU~V72eV6=TV9EgJvJwV;V8:9;U@JBS5"8K:BDmW2<eWM=>=yELWkWl286263(B\
$B7CWs=zB)CQWyNxWnX&1YWzW{8gW}W~X!X"DpG:X#X%X'X$@pY=5sYM7}YRYQ(B\
$B0'YP:C?6DrA\A^B*YT;+HTJaD=ZCIRNAZSZTZUZVN94{Zg98Zh;~?8ZiZj;/(B\
$B=q:sD?O/3|0F:y3J3K4<[Y5K[Z[[7K[\9;7e[^:,:O;7[_3t@r@s7,Em6MG_(B\
$B7*[a[][b@4I0[c;D<l=^]V;&]f]eBY^3^1^29@^4>C^5?;^6^7^8^:IMIb1:(B\
$BMa3=N.N^O2M0EsFB1(__Nu_`_^_]FC`E`FC,O5Gb7>`b<n`cHIN0`d`~a;C\(B\
$BHJ@&a=N1H+aPaQaRaS<@aT>I?>aUaVHhIBaWb(b.1Wb4bA??bCbDbEbFL2bB(B\
$B6k:VEVbi5NGKK$EW9\c,c-c.c/c0c1G*>MHkc?c@>NGi?AAECacBcAcXclck(B\
$BcmN55hct>Pcucvd$dc?hJ4L0dde"9I<S:w;f=cAGI3G<e#e$J6KBLfe~f*f+(B\
$Bf62'fBfCfMfNfQ9LfRLWfVC?6;6<OFfx;i@H@TF9G=L.fyCWgS9RHLgVgUgd(B\
$Bgmh!h"7U0qh$h%h&h'B{1Ah(h)h*h+h,h-h#2Y2Zh=iJiNiPGB;=2ciSiOiQ(B\
$BiRjHjOjPjQ?jB5jWjXjZj[Hoj\5-k?71k@kA?VBwF$l1l9I?9W:b5/lbm;8.(B\
$B?+mqmomrm~mp@BB$B.C`DLD~ESF)O"n;74n<n><`<rCqG[n[?KE#3xn]n^n\(B\
$BA.1!4Y9_=|o~?Xp!p"JEo}p#@IH;52GO9|9bqur(r.r/54(B" ; 10
    "$B4%55PqPvPpPsPt566vPu7r<EPwPxB&PyDdDeJP0N3uQKIZN?Q`Q{>jQtQrI{(B\
$B4*F0R(L3pUR7R6:|R?RNRTS17<S4>&>'S5BCS6BoS7S8S9LdM#S:S0S3S;S2(B\
$BT"S~T!TA0h4p:kKY<9>}BOF2G]IVTDTCG8D[TmU4U6:'U7U8>+GLU9IXO,U:(B\
$BU5UYUcFR4s<d=IL)UdUsUr0SV>V<33V=:jV@VAVBVC?rVDJxVGVFVEAcVhVi(B\
$B>oD"0C9/MG=n6/D%W:WB:LD&I7IKWRWOWPF@WQ0-45<=M*0TX)X+9{;4>pX,(B\
$BX.@KX/X0EiFWX1W|X~@LlCn=YU1f3]YV5E?xYW7!7G7~95:N<N<x>9?dYY@\(B\
$BA<A]C5Y[Y\Y]FhG1GSJ{Y_N+Y`YXY^DO<OZEZFZG5_65ZDGT:XZO<P;BCGZW(B\
$BB2@{Zl3"ZkZmZnZoZpZqRXAbA>[-K>[e[jKq[`3#[d[f8h9<[g:-[h04[i>?(B\
$B[kDt[l233a[o[pM|[qNB[r[u[tEn[n]7]8M_]K3L]\]]^F^I0|1UJ%^<^=^;(B\
$B363i^>^?7L^A^B:.^C=B=J=_>D^D?<@6:Q^G^H^JC8E:MdEq^KNC^MNT^N^E(B\
$B^L^@_X_aK#_bAV`38#`5`G`H`I`J`K`LCvLTNDN(5e8=M}`f`ia!a*ISa)E<(B\
$B;:0[7Ma?I-N,a@a>AAaX:/<&aYaZ;)b)Epb6@9b54cbGD/bHbk:WI<Ex0\:u(B\
$BAkCbcZ>Ocnpocw?ZcxcyBhczE+Idc|3^:{c}c{AFG4GtN37Pe%8>:0:Ye';g(B\
$B=*>R?Be(AHe)D]e*e+N_e&8Sf7f8f9=,MbfDfSfXfY=Mf|5Sfzf{C&G>f}gN(B\
$BBIgW8?A%gXGuh.h3h7h/h04Ph1h2h5h;2.h8G|gvh<h>h6h4hOh9h:2[5F6](B\
$B:ZCxJnK(Q]5uiT7ViW<XCAiXi[iUiViY3BjJ=Q76B^j]jYj^jTj_0Aj`jajb(B\
$B>X5,;kk,@_kBkC5v7m>YkDK,Lul.FZlA2_4S@UlEHNIOlIlDlelflg6mmCE>(B\
$BFpmDmtmsGgmumvmwmx?`my0)n%0o=5?JBa3T6?ETItM9?lnEnF<aLnn_KUn`(B\
$B6|D`naJDoZo[o|1"81p$p%DDF+GfN&N4NM?}Ue@c<6:"D:qD5{D;sC</sNsP(B\
$BKc2+9u(B" ; 11
    "$BPzP{;1HwP|K57f=~RE3.Qs3dAOQuR)6P>!JgGnRPRO19?_3e1DS<S=4-S?4n(B\
$BS@5J6,7v9"SASBA1SCASSDSEC}SFSGSHSI6tSJT#7wTE1aTF4.7x>lBDDMDi(B\
$BEHEcJsTHN]J=TN:ft!TeTdTf1|TzT{I2L;G^U;V#4(6wUfUgIY?RB:="B0EK(B\
$B<HVKV?VHVJMrVI?sC'VjVkVlI}K9Vs4vVzV{GQO-W6CFI+WE8fWS=[I|W\X*(B\
$BAZHaLeOGX=X392X5X7X8X9X<BFX?L{X:X;Y!7aHb>8YZYgIA0.1gYaYb494x(B\
$BYdYeYfB7DsYhYiM,MHMIYc4:7I;6ZHFXZIHCHeIL;[ZX6G7J=k>=@2ZrCRHU(B\
$BIaZs:GA=BX4|[.D+\&\"0X[v4=4}[w[y8![~\#\%?"?9@3\'DG\(Eo\*\+C*(B\
$BK@LIL:OP\/?z3q\2\![|\,[x[}[s\1\.\0\)\-[{[z]:4>5=6V;u]L?#]M]W(B\
$B]^]_^Y=m0/^O^P2912^R5t8:8P9A^U^V<"<>>E^W^XL+B,C9^Z^[EOEr^]^^(B\
$B^_K~^a^bM/OQ^Q^\^T^S^cH.1k_c<Q>F>GA3L5J2_d`*GW`0:T`6`4G-`M`O(B\
$BM1`P`NBv6W`hH|`kNV`jGJ1ya4aA>vHVaBaGABa[a\DKEwa]N!b$EPb*b+b/(B\
$B]9CebIC;8'9E>KN2H#bmO=cC5)@GcDDxcYc[c\co=WcpF8H&c~6Zd":vd#d%(B\
$Bd&C^EyEzE{H5I.d8dedg4!>Q0@didjdfdhe/3(5k7k0<9Je,e-e.e0e1@dE}(B\
$Be3Mme2fEfFfOfZf~9P?UD1g"g#g$g%g&OSP0=XhHh?0`?{hA8VhBhC>ThDhE(B\
$BhFhGhIEQhJhKhLhNMiI)hRF:h@hMh_0*GkArMUMn3?i\i]i^i_i`H:IHiaHZ(B\
$Bib=039:[AuNvjeJdM5N#k)3PGAk-k8k9k:1SkEkF:>;l>Z>[?GAJkGBBkHCp(B\
$BkII>kJ>]l:lF2l5.lGLcB_CyE=lHGcHqlJKGlLl_1[D6lclh5wliljlklllm(B\
$Bm<mEmF7Z<4mGmcm{m|m}1?2a6x?kC#CYF;JWM7MZn?nG?]nHnfnXNLnbncnd(B\
$BF_ng3CneoO3+4V4W1<o\o]g!?o3,6yp&BbM[7(4g8[=8M:1@J7pVpW?Y9`?\(B\
$B=gq$HSqGqH5Psc(B" ; 12
    "$BP,P9Q#P}6O79P~:D:E=}Q!Q"ANMCQ$F/QvQw4+@*R+R-R*R;SKSLSMSN;LSO(B\
$BSPSQC2T$1`T'TJ2tH9TMA::IE6EIEdJhTKTI1vTgL4T|>)U<2G7yU=<;U>U?(B\
$BU@ULUZ42?2UvVL:7VMVNKZKkVm44V|NwW;WCHyWTX(0&0U466rX4;|<f=%X6(B\
$BA[X>L|X234XCXAXD?5XFXHXKXIXxY"@oYSEkYj7HYlYmYnYo@]A_B;YqYrYs(B\
$BHB:q?tZP?7ZuZx0EZt2KZvZwCHPrG`\$\3\43Z4~6H6K\6\7Fj=]\8A?\:DX(B\
$B\;\=FoIv\?\@ML\BO0FN\>\5\D\<\9\CBJ\A]<]=:PTLEB^d0n3j4A8;9B^e(B\
$B^f^g^h=`^i^j^k^lBZE.^mGy^p^q^rLGMON/Bl^o1l_e_f_h_i_j>H@y_kGa(B\
$B_lN{HQLlD-8%M21n`Q;b1M`l8j`n?p`p`q`v`m`oa3aCFmaDa^a_a`aaabCT(B\
$Badaeacb,b7LAbJbKbL?gbMFDbNKSbdbpORbl37:l8k10Dvbobqbnc26Xc3cI(B\
$B2RA5DwJ!6YL-CUcGI#NGcHcEcF7"C(d!d'd(d)d*d.@ad-d+d,dkdldmdne4(B\
$B7Q8(e6e7B3e8e9e5f,7S:a=pCVf-f.5A72f:A"fT@;f[fifgfhg*g'<pg)D2(B\
$BJ"g+9xA#g5g(gO<-DzgY01hShU3khX3~hYIxG,F!h]Irh^h`N*hThWhbhPh[(B\
$Bhahdh\>xC_MViK6sN:ic2kidieB}ifigihiiijK*ilimikjKjfjcjdN":@jh(B\
$B?~jijkMgjljm2r?(kK3:kL5M7X8XkM;m;nkN>\@?OMkOkPM@kQOCA'K-l6l;(B\
$Bl<l=B1lK;qDBO(OEA(l\lnlo8Ylp@WA)lqD7O)m>3S:\mHmImJmRmdG@n!n"(B\
$Bn#n$n&F[I/n'n(0c1s8/n@=7nIMonh1tninjnk8Z9[nlnm>`E4noH-npNknq(B\
$Bnvo^o`o_p'p(p)3V2m;sp3p4p5p6EEp;MkNmLw7$pXG#pq4hprpsF\HRMBR,(B\
$B0{];q,q+>~;tK0FkCZqlqvroH7rjrlsFsfE$8]AM(B" ; 13
    "$BQ&Q%6#Q'Q(Q)A|Q*KMN=Q>QP3DR<1^RQRRSR2ESSST>(SUSVSXSWT%T&TG6-(B\
$BTO=NTP?PA}KOThTkTnT~T}C%UCUAUBCdUDUEU[UiUj2IUh;!G+UkUl\MUtAX(B\
$BV:EhVOVPVQVnVo3GV~V}W!>4D'FAX@XBXEXGBVJiXJXN47XLXMXPXRXTXVXX(B\
$BK}XYXSXUY#YkYt@"YvE&LNYwZJ064zD*JkZyNq\FO11]\G359=\I\J\K\L\N(B\
$BMM?:\cAdDHKjt"\P\Q\R\TLO\V\W\X:g\U\E\H\S\O\Y2N]>Nr]N]Z^`^|1i(B\
$B^t^v^w^xDR<?^zA2Af^{^}E)^~I:L!_!Nz5yO39w_#4C_"_g_m@z_o7'_pMP(B\
$B<$`7`89v`S`gt$`s`t:<`uN\a+a,a-5?afagahb0b1b8bObPbQbtbr<'HjJK(B\
$Bbubs@Yc4cJ9r<o0p7&c]cqC<crd=2U4Id/L'd0d1d2d3d4;;d5d6d7Gsd9JO(B\
$Bdo@:dqdp0]e:e;e<9Ke=e>e?<z=oAmAnC>eBDVeCHlLJLV0=NPeEeFN}eGe@(B\
$BenH3?ifGf]f\AoJ9f^H%Ieg,g-9QB\g.g/Klg0gIgJgPhZhc38hehfhgL,IG(B\
$Bhi<,hj=/hlhmhnAsho3wLXhhhphkDUB"ioipiqirCXisitL*inO9jg@=jj3l(B\
$BjnJ#jojpj|k.kRkSkT8l8mkU;okVkW@@@bFIG'kXM69kl>KFFx3RldlslrMY(B\
$BltlumKmLmNJememzALn*t#n)B=AxE,nAnJ9Z9s;@nKnnnr6dns=FA,A-ntnu(B\
$BF<KHLCD83U4Xoa9^obH67d1#:]>c;(<{@EpRpYpZ3sp\p]p[pp?|NN7[q%q&(B\
$B0;1X6nBLG}qIqmH1qwqx3!:2FPK1LDVwsiI!sn(B" ; 14
    "$BQ+Q-2/57Q,Q.Q/JHQ[Qx7`Q|N-7.R=SY4oSZ13S\>|S]A91=S^S_J.3z2^TX(B\
$BTRDFJ/TSTQTWUFUG4rUHUIUm?3N@F3MzVWVRVSVpVqH(J>VrW"W&W#>3W$W%(B\
$BI@W'J@W<1FE00V7D7EXOXQXWM+M]N8X\A~X]X^X_F4XbXcJ0Ny5:Y$7bYuK`(B\
$B;#@q;5F5E1YzG2GEY{IoKPY|Y}Yy3IZKE(I_;CK=\d\Z\[\l\k2#DP\\\]8"(B\
$B\`\a>@\bAeCtHu\hI8\i3_\g\e\_\f\n\x]?4?C7]O]X5#^n^s^y_'_(_1DY(B\
$B4B_$7i_%_&=a_)3c@x_*_,@!_-D,_._/_0_3_L_r=OG.`R`U`r`w`xM~5&ai(B\
$BajakalAiamanb-b24FHWbRbSbTbwbv3Nbxbybzb{HXb|b}c5cK2T7N9FcLcM(B\
$BJfcN5gMRc_d:d;H"d>@}H$d?JSd<C=HO8RdrA8dseMeD1o4KeH6[eIFleJ@~(B\
$BeKeLDyeNJTLKeOf/GMHmf;f>4efHfIf_g6g1I(g4Ifg2g3J^gTIqhyhQ0~16(B\
$Bhqhsht>UhuhvhwhxL"JNK)<ChzO!hriv2\iwixiyizi{i|?*D3i}i~j!iuj"(B\
$Bj#@fGh>WK+jrjsjtjuk;1Z2]5C?[kY=tC/@AkZBzCBCLD4k[HpNJO@k\k]l2(B\
$Bl3l?;?;r>^lM<AlNGeIPIjlO<qlxlvlwlyF'm)mM51mOmPGZmQNXmSn+<Wn,(B\
$B0d=eA*A+NKE"nBnCnMnL=fnNJ_1Tnwnx={nyCrK/IFnz1\ocp<?Lp=p>NnpQ(B\
$Bp^0Hp_p`pupvq-1Bq.M\L_2n6o2o6pqJqKqLqMCsqNq|qyq{I&qzq}r)r0r1(B\
$BL%O%r7rnrmrprqF>sOsQ]`sUL[so(B" ; 15
    "$B<tQ1Q2Q3Q0QCQQ6EQzQyQ}R.1CS`SaSbScFUH8SdT(TT2u:&>mCEJITYJ3>n(B\
$BUJU\UnVUVTW(W)60W4WUXZX[7F7{X`XaXdXe212{Xh48XjXkXnY%Z$Z!Y?Y~(B\
$BZ"Z#A`Z%MJZ'@0ZZZ|ZzZ{Z}F^[!Z~["3r\m5!5L66<y>AFK\rC.\s\t\u\v(B\
$B\w\p\o\q]@]A]P]Q_7_5_2_47c_6By_8ECG;_9_:Eu_v1m_t_u_wG3_x_yNU(B\
$B_s=C`W`V3M`e`yI;a.a/a0aJaoapaqb9b:bUbVc"b~c!Ka5z1P0,1O2:@QKT(B\
$Bc`1.C[d@dAdDdEO6dBFFE|dudt0^ePeQ<JeReS=DeUeVeWeXG{HKK%Xmf<4M(B\
$BfUg7A7g8KDg9gK6=4\gZg[F"hV6>h{OOh|>Vh}h~i!<Ii#HYIsJCi$i+Iy70(B\
$B?EA&GvLtj%j&j'M;1RjL9Ujzjvjyk/?Fk0k`k^0bk_4Rkakbkc8Akd;pD5D|(B\
$BkekfKEM!kgMXkkP.l78-ERl`l}lzl{D}l|m?=4mTmUM"mVQ~R!n.n/n-4THr(B\
$B@CBi8oH06So"n{n|5xn~9]:xo!>{?m;,<bo#?no$O#O?o%o&o'n}odoeofog(B\
$Bp*p+NYNlp:p9p?p@pApBpCpPpS>dMjpwKKptpxF,q1;Aq/q04[qOqPqQqR3<(B\
$Bqnq~r!r*r80>r9J+r:r<r;1u3{rvrx<2ryrurrrs2)2*rtsGsR`TsXN6s}(B" ; 16
    "$BM%Q4R/873ESeSiSjSgSfTVTZT[9hT\1ED\UKUMUNU^VVVXVYNfW=5+XfXi:)(B\
$BXlXoY&Z&Z(5<;$Z+Z,E'Z.Z/ZL[#\}\y3`\{\|8i\~CI]!\z],[X]B]a_@_;(B\
$B_<9jG(_=Bu^9_?_A_B_>oiRYS[_z_{;8?$_|Ag_}<_`/5>`X4D9yar4basNE(B\
$Batb;bWF7JMNFbXbY6:0kc#>Lc$c8c6cPcOcc3vRUdG<DdHdJdKdNdMdIdLdC(B\
$Bdw9GAldvJ5e`eAeTeYeZ=L@SA!e\e[e]e^e_eaf!fJMcfbf`faD0N~g<22g:(B\
$Bg=G?g>g?g@g;gEZ*g]g\ge1ri&i'i(i)i*i,i-Fei/i0i2i1i3Lyi%iLj(j)(B\
$Bj*j.j/j0Mfj3j+j2j1j,jqjwjxj{p7k1k2Mwkhko6`8,ki9Vkj<UklF%kmkn(B\
$BFfl/l0l@9XlPlQlR?vl~m!m"m#m$m%mW3mmXmYMAn0n1n2n3nOFiDW80o)7-(B\
$B>ao*CCo+EUIEo,o(0Gohojokolp,p.p-p1j-pD2bAz5Gpa4ZpyIQq'q3q2q4(B\
$Bq5q6qEqS=YqTqU=9r=Knr>:z;-r?A/r@rw9crzr{r|r}r~sHsVBcsYsZs[sd(B\
$Bsmc7spNps~(B" ; 17
    "$BLYAQShT^T]W3D(XpXsBWY'Z)Z2>qZ3Z4Z6Z1Z9ZMZRZY=l[$MK[/\j]#]$]%(B\
$B[m]&]'](]C]E]R_G_C_D_E_FMt_H_I_n_~`!`"`Z`za1a2auJJL~avbZb[b\(B\
$B=Vb]c&ACc'c%c9cR3O>wcQcacb4JdOdPdQdRNHeiecee?%A6efegebed=+f0(B\
$BfKK]fc?&gAgBNWgQg^ONi6;'i4=ri5i7i8F#HMMuj5j4j6j=2(6_j}J$4Qk3(B\
$Bk<kpkrksktI5kul4lBlSlTB#lVm(@Xm&m'm*m+m[m\mZcdnPnQ>_nRnZo-3;(B\
$Bo.:?AyDCo/DJo03yo1omonooF.RVp8?wFqpEkqpcpdJ\pb3[3\4ipz82p{Bj(B\
$BN`q7q8qF53qV83qWA{qXqor"r+r2r3r4rArBrC8qrDrErFrGs!s"s$9t1-s%(B\
$BL9s#s&sIK{s\sjsl(B" ; 18
    "$BSkSlTUT`TbUOUpC~W*XgXqZ5[%Gx6{]-]+O&])]*]TFTBm_+_J_KCuIN@%_M(B\
$B_NGz`#`1`9`Y`\<%`{a"aEaFawb^c(G)cSdSdTdUHvJmN|dZejKzeh7R7+f2(B\
$Bf1Mef=f?f@B!gDg`g_1pi:i;i9i.i<AtMvj;j<3*j7j85Bj9j:j$j~k!k"k*(B\
$BGFkwkzkvkxky7Y<1k{k|k}IhlU4fm,=3m-m.m@m]E2mfn4o5o26@o3o4o6o7(B\
$BE-o8o9o:o;opp/N%pFL8sSpfpepkpn1$4jE?q9q:q;qYBM?qrH7_rIrJrK;*(B\
$BBdrLrOrPrN037\s's(s)s+K2s,O<sKsJsLNo9mse(B" ; 19
    "$BR0SmSnTaT_UPUQURUo4`VZW-7|XrZ7['[0Ms].H'_O_P_Q_R`$`:`[`|axb_(B\
$Bc)bjc*bhce6%@RdVdWdYdyek;<eleoepemeqf"fAMTfdgCgFgai"=si=i>AI(B\
$Bi?i@iBiCiDiAj>j?j@k#k$k4k=l#5D8n>yk~l!l"lWlXm/m0m2m1m=m^nS>z(B\
$BnTnYoEo<>bo=o>F*o?oAo@oqpGO*6Aq(q)q<q=3>q[qZF-r,rQrSrTrU3brV(B\
$BrWrXrYrRrZr\OLs-s.s/s*sDLMs^s]sqsrssst(B" ; 20
    "$BQ5Q6SoSpSqSrSsV$V[W+XuXvXwZ8Yp[(]/]0]2]S^u`%`}ayaza{a|cTc^d[(B\
$Bd_dXdzetezerE;evesf#4Ogb]"]1b<iEiFjAiZjBk%k5l%l$lYl[l]m3m4Lv(B\
$B9lm_mgn5nUoDoBoCBxoForos[1pH8\q*fLq>q?q@qAqBq\q]q^q_q`qpr#r5(B\
$BKbr[r]IIr^0sr_r`s1Das2s3s4s5s0s8s6s7sMs_lZsusv(B" ; 21
    "$BQ7Q8StG9SuV\V]W>XtZ:ZN\^]D_SFgaHaIa}c:cUcfQ?d\d]dFd{euf$f4fe(B\
$BO8gGgc=1k&k'k6l&;>l^m5m6m77%m`oILzoGoHpIpJpgp|6BqC6Cqaqbr$dx(B\
$B3orM17rdC-rcrarbs9s:sxsws|(B" ; 22
    "$BV^Z;YxZ<]3a~d^d`eyewexiGjCjFl'l(=2m8mambn6oJ4UoKoLoMoTpTp}qc(B\
$Bqdqsqrqqqtr%KpNZres;OIs<s=s>:mN[sWs`pm(B" ; 23
  "$BSvSwZ0b!b`f%f3gfjDjEjMl*l)l+mAnVoNpMpKpLpNpiphp~qer&r6rfrgs?Bk(B\
$BsE84sgsyszs{(B" ; 24
  "$BW,]4_Tdad|e{gHjGk+k7l,m:nWoPpOq!r'sTsh(B" ; 25
  "$B15bal-oQoRqfr-rhsa(B"			; 26
  "$Be|m9oSoUoVoXq"q#qgqhrisb(B"		; 27
  "$BoWqis@(B"				; 28
  "$B]6`&qk]5sA(B"				; 29
  "$BqjsB(B"				; 30
  ])

;; 92.7.24 by T.Shingu -- Completely modified.
;; 92.8.24 by T.Shingu -- Bug fixed.
;; 92.9.17 by K.Handa  -- Now table contents are strings (not lists of strings)
(defun busyu-input ()
  (interactive)
  (let ((loop1 t)
	(loop2)
	(loop3)
	(val1)
	(val2)
	(busyuname)
	(nbusyu (1- (length busyu-table)))
	(kaku1)
	(kaku2))
    (while (or loop1 loop2 loop3)
      (if loop1
	  (progn
	    (setq loop1 nil)
	    (setq kaku1 (string-to-int (read-from-minibuffer
					(format "$BIt<s2h?t(B(1-%d): " nbusyu)
					(if kaku1 (int-to-string kaku1)))))
	    (and (< 0 kaku1) (<= kaku1 nbusyu) ; 92.9.30 by K.Mitani
		 (setq loop2 t))))
      (let ((inhibit-quit t))
	(if loop2
	    (progn
	      (setq loop2 nil)
	      (setq busyuname
		    (menu:select-from-menu
		     (list 'menu "$BIt<s(B:" (aref busyu-table kaku1))))
	      (if quit-flag
		  (progn
		    (setq quit-flag nil)
		    (setq loop1 t))
		(setq loop3 t)
		(setq val1 (cdr (assoc busyuname busyu-kaku-alist))))))
	(if loop3
	    (progn
	      (setq loop3 nil)
	      (setq kaku2
		    (menu:select-from-menu
		     (list 'menu "$BAm2h?t(B:"
			   (cons (cons "*" val1)
				 (mapcar (function
					  (lambda (x)
					    (cons (format " %s$B2h(B" (car x))
						  (cdr x))))
					 val1)))))
	      (if quit-flag
		  (progn
		    (setq quit-flag nil)
		    (setq loop2 t))
		(setq val2
		      (menu:select-from-menu 
		       (list 'menu "$B4A;z(B:"
			     (if (stringp kaku2)
				 (busyu-break-string kaku2)
			       (apply (function nconc)
				      (mapcar (function 
					       (lambda (x)
						 (busyu-break-string (cdr x))))
					      kaku2))))))
		(if quit-flag
		    (progn
		      (setq quit-flag nil)
		      (setq loop3 t))
		  (insert val2)))))))))

(defun kakusuu-input ()
  (interactive)
  (let ((loop t)
	(kaku nil)
	(nkakusuu (1- (length kakusuu-table)))
	(val))
    (while loop
      (setq kaku (string-to-int
		  (read-from-minibuffer (format "$B2h?t(B(1-%d): " nkakusuu)
					(if kaku (int-to-string kaku)))))
      (if (not (and (< 0 kaku) (<= kaku nkakusuu))) ; 92.9.30 by K.Mitani
	  (setq loop nil)
	(let ((inhibit-quit t))
	  (setq val 
		(menu:select-from-menu
		 (list 'menu "$B4A;z(B:"
		       (busyu-break-string (aref kakusuu-table kaku)))))
	  (if quit-flag
	      (setq quit-flag nil)
	    (insert val)
	    (setq loop nil)))))))

(defun busyu-break-string (str)
  (let ((len (length str))
	(i 0) j l)
    (while (< i len)
      (setq j (char-bytes (sref str i)))
      (setq l (cons (substring str i (+ i j)) l))
      (setq i (+ i j)))
    (nreverse l)))
