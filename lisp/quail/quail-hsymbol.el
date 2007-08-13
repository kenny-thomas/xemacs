;; Copyright (C) 1992,1994 Free Software Foundation, Inc.
;; This file is part of Mule (MULtilingual Enhancement of GNU Emacs).
;; This file contains Korean symbol characters from KSC5601 code table
;; for use in Korean documents.

;; Mule is free software distributed in the form of patches to GNU Emacs.
;; You can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 1, or (at your option)
;; any later version.

;; Mule is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;; 94.10.24   Written for Mule Ver.2.0 (K.Un.)
;;;	<zraun01@hpserv.zdv.uni-tuebingen.de>
;;; 94.11.04   Updated for Mule Ver.2.1 (K.Un.)
;;;	<zraun01@hpserv.zdv.uni-tuebingen.de>

;; # Hangul symbol input table for Mule to be used in hangul document.
;; ENCODE:	KSC
;; MULTICHOICE:	YES
;; PROMPT:	::$(C"^(B::
;; #
;; COMMENT
;; COMMENT	$(CGQ1[(B $(C=I:<(B $(C1[@Z(B
;; COMMENT
;; # define keys
;; VALIDINPUTKEY:	(_)abcdefghijklmnopqrstuvwxyzCDEGKMNOPQRSTUW
;; SELECTKEY:	1\040
;; SELECTKEY:	2
;; SELECTKEY:	3
;; SELECTKEY:	4
;; SELECTKEY:	5
;; SELECTKEY:	6
;; SELECTKEY:	7
;; SELECTKEY:	8
;; SELECTKEY:	9
;; SELECTKEY:	0
;; BACKSPACE:	\010\177
;; DELETEALL:	\015\025
;; MOVERIGHT:	.>
;; MOVELEFT:	,<
;; REPEATKEY:	\020\022
;; # the following line must not be removed
;; BEGINDICTIONARY
;; #

(require 'quail)

(quail-define-package
 "hsymbol" "$(C"^(B" t
 "$(CGQ1[=I:<@T7BG%(B:
  $(C!<(B($(C!=0}H#?-1b!<(B)$(C!=0}H#4]1b(B $(C!<(Bwon$(C!=57(B  $(C!<(Bpic$(C!=;sG|9.@Z(B $(C!<(Bxtext$(C!=!W!X"R"."/(B
  $(C!<(Bmusic$(C!=@=>G!<(Bquot$(C!=5{?HG%!<(Bdot$(C!=A!(B  $(C!<(Barrow$(C!=H-;l(B   $(C!<(Bmath$(C!=<vGP1bH#(B
  $(C!<(Bindex$(C!=C7@Z!<(Bunit$(C!=4\@'(B  $(C!<(Bsex$(C!=!N!O!<(Baccent$(C!=>G<>F.!<(BUnit$(C!=!I!J!K"5(B
  $(C!<(Bwn$(C!="_!<(Bks$(C!="^!<(BNo$(C!="`!<"a!="a(B $(C!<(Bpercent$(C!="6!<(Bline$(C!=<19.@Z(B
  $(C!<(Bam$(C!="c!<(Bpm$(C!="d!<"b!="b!<(BTel$(C!="e!<(Bdag$(C!="S"T(B  $(C!<(Bfrac$(C!=:P<v(B
  $(C!<(Btextline$(C!=!)!*!+!,!-(B          $(C!<(BScan$(C!=("(#($!&(B $(C!<(Bscan$(C!=)")#)$!&(B
  $(C!<(Benum$(C!=#0#1#2!&!<(BEng$(C!=#A#B#C!&(B $(C!<(Beng$(C!=#a#b#c!&(B  $(C!<(Beasc$(C!=?5>n(BASCII
  $(C!<(BRom$(C!=%0%1%2!&(B $(C!<(Brom$(C!=%!%"%#!&(B $(C!<(BGreek$(C!=%A%B%C!&!<(Bgreek$(C!=%a%b%c!&(B
  $(C!<(Bojaso$(C!=(1!-(>(B $(C!<(Bogana$(C!=(?!-(L(B $(C!<(Boeng$(C!=(M!-(f(B   $(C!<(Bonum$(C!=(g!-(u(B
  $(C!<(Bpjaso$(C!=)1!-)>(B $(C!<(Bpgana$(C!=)?!-)L(B $(C!<(Bpeng$(C!=)M!-)f(B   $(C!<(Bpnum$(C!=)g!-)u(B
  $(C!<(Bhira$(C!=*"*#*$(B  $(C!<(Bkata$(C!=+"+#+$(B  $(C!<(BRuss$(C!=,",#,$!&(B $(C!<(Bruss$(C!=,Q,R,S!&(B
  $(C!<@Z<R!=(B2$(C9z=D(B + $(C$U(B(S) $(C$o(B(t_) $(C$p(B(DD) $(C$q(B(D) $(C$v(B(G) $(C$u(B(GG) $(C$}(B(uk)"
 '(
   ("," . quail-prev-candidate-block)
   ("<" . quail-prev-candidate-block)
   ("." . quail-next-candidate-block)
   (">" . quail-next-candidate-block)
   (" " . quail-select-current)
   )
 )

(qdv "("	"$(C!2!4!6!8!:!<(B")
(qdv ")"	"$(C!3!5!7!9!;!=(B")
(qdv "math"	"$(C!>!?!@!A!B!C!D!E!P!Q!R!S!T!U!V!k!l!m!n!o!p!q!r!s!t!u!v!w!x!y!z!{!|!}!~"""#"$"1"2"3(B")
(qdv "pic"	"$(C!Y![!Z!\!]!^!_!`!a!b!c!d!e"7"8"9":";"<"=">"?"@"A"B"C"D"E"F"G"H"I"J"K"L"M"N"O"P"Q"4(B")
(qdv "arrow"	"$(C!f!g!h!i!j"U"V"W"X"Y(B")
(qdv "music"	"$(C"["Z"\"](B")
(qdv "won"	"$(C#\!M!L(B")
(qdv "xtext"	"$(C!W!X"R"."/(B")
(qdv "dot"	"$(C!$!%!&!'"0(B")
(qdv "quot"	"$(C!"!#!(!.!/!0!1!F!G!H"%")(B")
(qdv "textline"	"$(C!)!*!+!,!-(B")
(qdv "Unit"	"$(C!I!J!K"5(B")
(qdv "sex"	"$(C!N!O(B")
(qdv "accent"	"$(C"&"'"("*"+","-(B")
(qdv "percent"	"$(C"6(B")
(qdv "dag"	"$(C"S"T(B")
(qdv "wn"	"$(C"_(B")
(qdv "ks"	"$(C"^(B")
(qdv "No"	"$(C"`(B")
(qdv "Co"	"$(C"a(B")
(qdv "TM"	"$(C"b(B")
(qdv "am"	"$(C"c(B")
(qdv "pm"	"$(C"d(B")
(qdv "Tel"	"$(C"e(B")
(qdv "easc"	"$(C#"###$#%#&#'#(#)#*#+#,#-#.#/#:#;#<#=#>#?#@#[#]#^#_#`#{#|#}#~(B")
(qdv "enum"	"$(C#0#1#2#3#4#5#6#7#8#9(B")
(qdv "Eng"	"$(C#A#B#C#D#E#F#G#H#I#J#K#L#M#N#O#P#Q#R#S#T#U#V#W#X#Y#Z(B")
(qdv "eng"	"$(C#a#b#c#d#e#f#g#h#i#j#k#l#m#n#o#p#q#r#s#t#u#v#w#x#y#z(B")
(qdv "r"	"$(C$!(B")
(qdv "R"	"$(C$"(B")
(qdv "rt"	"$(C$#(B")
(qdv "s"	"$(C$$(B")
(qdv "sw"	"$(C$%(B")
(qdv "sg"	"$(C$&(B")
(qdv "e"	"$(C$'(B")
(qdv "E"	"$(C$((B")
(qdv "f"	"$(C$)(B")
(qdv "fr"	"$(C$*(B")
(qdv "fa"	"$(C$+(B")
(qdv "fq"	"$(C$,(B")
(qdv "ft"	"$(C$-(B")
(qdv "fx"	"$(C$.(B")
(qdv "fv"	"$(C$/(B")
(qdv "fg"	"$(C$0(B")
(qdv "a"	"$(C$1(B")
(qdv "q"	"$(C$2(B")
(qdv "Q"	"$(C$3(B")
(qdv "qt"	"$(C$4(B")
(qdv "t"	"$(C$5(B")
(qdv "T"	"$(C$6(B")
(qdv "d"	"$(C$7(B")
(qdv "w"	"$(C$8(B")
(qdv "W"	"$(C$9(B")
(qdv "c"	"$(C$:(B")
(qdv "z"	"$(C$;(B")
(qdv "x"	"$(C$<(B")
(qdv "v"	"$(C$=(B")
(qdv "g"	"$(C$>(B")
(qdv "k"	"$(C$?(B")
(qdv "o"	"$(C$@(B")
(qdv "i"	"$(C$A(B")
(qdv "I"	"$(C$B(B")
(qdv "j"	"$(C$C(B")
(qdv "p"	"$(C$D(B")
(qdv "u"	"$(C$E(B")
(qdv "P"	"$(C$F(B")
(qdv "h"	"$(C$G(B")
(qdv "hk"	"$(C$H(B")
(qdv "ho"	"$(C$I(B")
(qdv "hl"	"$(C$J(B")
(qdv "y"	"$(C$K(B")
(qdv "n"	"$(C$L(B")
(qdv "nh"	"$(C$M(B")
(qdv "np"	"$(C$N(B")
(qdv "nl"	"$(C$O(B")
(qdv "b"	"$(C$P(B")
(qdv "m"	"$(C$Q(B")
(qdv "ml"	"$(C$R(B")
(qdv "l"	"$(C$S(B")
(qdv "S"	"$(C$U(B")
(qdv "se"	"$(C$V(B")
(qdv "st"	"$(C$W(B")
(qdv "st_"	"$(C$X(B")
(qdv "frt"	"$(C$Y(B")
(qdv "fqt"	"$(C$[(B")
(qdv "fe"	"$(C$Z(B")
(qdv "ft_"	"$(C$\(B")
(qdv "fG"	"$(C$](B")
(qdv "aq"	"$(C$^(B")
(qdv "at"	"$(C$_(B")
(qdv "at_"	"$(C$`(B")
(qdv "aD"	"$(C$a(B")
(qdv "qr"	"$(C$b(B")
(qdv "qe"	"$(C$c(B")
(qdv "qtr"	"$(C$d(B")
(qdv "qte"	"$(C$e(B")
(qdv "qw"	"$(C$f(B")
(qdv "qx"	"$(C$g(B")
(qdv "qD"	"$(C$h(B")
(qdv "QD"	"$(C$i(B")
(qdv "tr"	"$(C$j(B")
(qdv "ts"	"$(C$k(B")
(qdv "te"	"$(C$l(B")
(qdv "tq"	"$(C$m(B")
(qdv "tw"	"$(C$n(B")
(qdv "t_"	"$(C$o(B")
(qdv "DD"	"$(C$p(B")
(qdv "D"	"$(C$q(B")
(qdv "Dw"	"$(C$r(B")
(qdv "Dt_"	"$(C$s(B")
(qdv "vD"	"$(C$t(B")
(qdv "GG"	"$(C$u(B")
(qdv "G"	"$(C$v(B")
(qdv "yi"	"$(C$w(B")
(qdv "yO"	"$(C$x(B")
(qdv "yl"	"$(C$y(B")
(qdv "bu"	"$(C$z(B")
(qdv "bP"	"$(C${(B")
(qdv "bl"	"$(C$|(B")
(qdv "uk"	"$(C$}(B")
(qdv "ukl"	"$(C$~(B")
(qdv "Rom"	"$(C%0%1%2%3%4%5%6%7%8%9(B")
(qdv "rom"	"$(C%!%"%#%$%%%&%'%(%)%*(B")
(qdv "Greek"	"$(C%A%B%C%D%E%F%G%H%I%J%K%L%M%N%O%P%Q%R%S%T%U%V%W%X(B")
(qdv "greek"	"$(C%a%b%c%d%e%f%g%h%i%j%k%l%m%n%o%p%q%r%s%t%u%v%w%x(B")
(qdv "line"	"$(C&"&#&$&%&&&'&(&)&*&+&,&-&.&/&0&1&2&3&4&5&6&7&8&9&:&;&<&=&>&?&@&A&B&C&D&E&F&G&H&I&J&K&L&M&N&O&P&Q&R&S&T&U&V&W&X&Y&[&Z&\&]&^&_&`&a&b&c&d(B")
(qdv "unit"	"$(C'"'#'$'%'&'''(')'*'+','-'.'/'0'1'2'3'4'5'6'7'8'9':';'<'='>'?'@'A'B'C'D'E'F'G'H'I'J'K'L'M'N'O'P'Q'R'S'T'U'V'W'X'Y'['Z'\']'^'_'`'a'b'c'd'e'f'g'h'i'j'k'l'm'n'o(B")
(qdv "Scan"	"$(C("(#($(&((()(*(+(,(-(.(/(B")
(qdv "ojaso"	"$(C(1(2(3(4(5(6(7(8(9(:(;(<(=(>(B")
(qdv "ogana"	"$(C(?(@(A(B(C(D(E(F(G(H(I(J(K(L(B")
(qdv "oeng"	"$(C(M(N(O(P(Q(R(S(T(U(V(W(X(Y([(Z(\(](^(_(`(a(b(c(d(e(f(B")
(qdv "onum"	"$(C(g(h(i(j(k(l(m(n(o(p(q(r(s(t(u(B")
(qdv "frac"	"$(C(v(w(x(y(z({(|(}(~(B")
(qdv "scan"	"$(C)")#)$)%)&)')()))*)+),)-).)/)0(B")
(qdv "pjaso"	"$(C)1)2)3)4)5)6)7)8)9):);)<)=)>(B>")
(qdv "pgana"	"$(C)?)@)A)B)C)D)E)F)G)H)I)J)K)L(B")
(qdv "peng"	"$(C)M)N)O)P)Q)R)S)T)U)V)W)X)Y)[)Z)\)])^)_)`)a)b)c)d)e)f(B")
(qdv "pnum"	"$(C)g)h)i)j)k)l)m)n)o)p)q)r)s)t)u(B")
(qdv "index"	"$(C)v)w)x)y)z){)|)})~(B")
(qdv "hira"	"$(C*"*#*$*%*&*'*(*)***+*,*-*.*/*0*1*2*3*4*5*6*7*8*9*:*;*<*=*>*?*@*A*B*C*D*E*F*G*H*I*J*K*L*M*N*O*P*Q*R*S*T*U*V*W*X*Y*[*Z*\*]*^*_*`*a*b*c*d*e*f*g*h*i*j*k*l*m*n*o*p*q*r*s(B")
(qdv "kata"	"$(C+"+#+$+%+&+'+(+)+*+++,+-+.+/+0+1+2+3+4+5+6+7+8+9+:+;+<+=+>+?+@+A+B+C+D+E+F+G+H+I+J+K+L+M+N+O+P+Q+R+S+T+U+V+W+X+Y+[+Z+\+]+^+_+`+a+b+c+d+e+f+g+h+i+j+k+l+m+n+o+p+q+r+s+t+u+v(B")
(qdv "Russ"	"$(C,",#,$,%,&,',(,),*,+,,,-,.,/,0,1,2,3,4,5,6,7,8,9,:,;,<,=,>,?,@,A(B")
(qdv "russ"	"$(C,Q,R,S,T,U,V,W,X,Y,[,Z,\,],^,_,`,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q(B")

(quail-setup-current-package)
