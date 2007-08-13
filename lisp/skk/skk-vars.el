(require 'skk-foreword)

;;;### (autoloads (skk-make-face skk-change-cursor-when-ovwrt skk-set-cursor-properly skk-middle-list skk-jisx0208-to-ascii skk-update-jisyo skk-nunion skk-search skk-save-jisyo skk-start-henkan skk-kakutei skk-previous-candidate skk-get-current-candidate skk-emulate-original-map skk-auto-fill-mode skk-mode skk-set-marker skk-y-or-n-p skk-yes-or-no-p skk-error skk-message skk-save-point skk-version) "skk" "skk/skk.el")

(defconst skk-month-alist '(("Jan" . "1") ("Feb" . "2") ("Mar" . "3") ("Apr" . "4") ("May" . "5") ("Jun" . "6") ("Jul" . "7") ("Aug" . "8") ("Sep" . "9") ("Oct" . "10") ("Nov" . "11") ("Dec" . "12")) "\
$B1Q8l$N7nL>$H;;MQ?t;z$NO"A[%j%9%H!#(B

$B;;MQ?t;z$+$i1Q8l$N7nL>$N$_$r=PNO$9$k$N$G$"$l$P!"%Y%/%?!<$r;H$C$?J}$,9bB.$@$,!"(B
$B1Q8l$N7nL>$+$i;;MQ?t;z$r=PNO$9$k$N$G$"$l$PO"A[%j%9%H$G$J$1$l$PL5M}$J$N$G!"B?(B
$BL\E*$K;HMQ$G$-$k$h$&O"A[%j%9%H$N7ABV$r<h$k!#(B

Alist of English month abbreviations and numerical values.

Although it is faster to use a vector if we only want to output
month abbreviations given the ordinal, without the alist it's
unreasonable [sic] to output the ordinal given the abbreviation,
so for multi-purpose utility we use the alist form.")

(autoload 'skk-version "skk" nil t nil)

(defvar skk-init-file (if (eq system-type 'ms-dos) "~/_skk" "~/.skk") "\
*SKK $B$N=i4|@_Dj%U%!%$%kL>!#(B
skk.el 9.x $B$h$j(B ~/.emacs $B$G$N%+%9%?%^%$%:$,2DG=$H$J$C$?!#(B

Name of the SKK initialization file.
From skk.el 9.x on all customization may be done in ~/.emacs.")

(defvar skk-special-midashi-char-list '(?\> ?\< ?\?) "\
*$B@\F,<-!"@\Hx<-$NF~NO$N$?$a$N%W%l%U%#%C%/%9%-!<!"%5%U%#%C%/%9%-!<$N%j%9%H!#(B

List of prefix and suffix keys for entering `setsutoji' and `setsuoji'.")

(defvar skk-mode-hook nil "\
*SKK $B$r5/F0$7$?$H$-$N%U%C%/!#(B
$BB>$K!"(Bskk-auto-fill-mode-hook$B!"(Bskk-load-hook, skk-init-file $B$G$b%+%9%?(B
$B%^%$%:$,2DG=!#(B

Hook run at SKK startup.

`skk-auto-fill-mode-hook', `skk-load-hook', and skk-init-file may also
be used for customization.")

(defvar skk-auto-fill-mode-hook nil "\
*skk-auto-fill-mode $B$r5/F0$7$?$H$-$N%U%C%/!#(B
$BB>$K!"(Bskk-mode-hook, skk-load-hook, skk-init-file $B$G$b%+%9%?%^%$%:$,2D(B
$BG=!#(B

Hook run at startup of skk-auto-fill-mode.

`skk-mode-hook', `skk-load-hook', and `skk-init-file' may also be
used for customization.")

(defvar skk-load-hook nil "\
*skk.el $B$r%m!<%I$7$?$H$-$N%U%C%/!#(B
$BB>$K!"(Bskk-mode-hook, skk-auto-fill-mode-hook, skk-init-file $B$G$b%+%9%?(B
$B%^%$%:$,2DG=!#(B

Hook run when SKK is loaded.

`skk-auto-fill-mode-hook', `skk-mode-hook', and `skk-init-file' may
also be used for customization.")

(defvar skk-kakutei-jisyo nil "\
*$B:G=i$K8!:w$9$k<-=q!#(B
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
searched and the order of search can be changed.")

(defvar skk-initial-search-jisyo nil "\
*$B%f!<%6!<<-=q$N8!:w$NA0$K8!:w$9$k<-=q!#(B
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
searched and the order of search can be changed.")

(defvar skk-large-jisyo nil "\
*$B%f!<%6!<<-=q$N8!:w$N8e$K8!:w$9$k<-=q!#(B
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
searched and the order of search can be changed.")

(defvar skk-aux-large-jisyo nil "\
*SKK $B%5!<%P!<$G:G8e$K8!:w$9$k<-=q!#(B
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
autoloaded.")

(defvar skk-search-prog-list '((skk-search-kakutei-jisyo-file skk-kakutei-jisyo 10000 t) (skk-search-jisyo-file skk-initial-search-jisyo 10000 t) (skk-search-jisyo-file skk-jisyo 0 t) (skk-search-jisyo-file skk-large-jisyo 10000)) "\
*$B8!:w4X?t!"8!:wBP>]$N<-=q$r7hDj$9$k$?$a$N%j%9%H!#(B
$BJQ49$7$?8uJd$rJV$9(B S $B<0$r%j%9%H$N7A$KI=5-$7$?$b$N!#(B
skk-search $B4X?t$,(B skk-search-prog-list $B$N(B car $B$+$i8eJ}8~$X=gHV$K(B S $B<0$NI>2A$r(B
$B9T$$JQ49$r9T$J$&!#(B

This list determines the search functions used and the dictionaries
searched.
A list of S-expressions returning conversion candidates.
The function `skk-search' performs conversions by evaluating each S-
expression in order, starting with the car of `skk-search-prog-list'.")

(defvar skk-jisyo (if (eq system-type 'ms-dos) "~/_skk-jisyo" "~/.skk-jisyo") "\
*SKK $B$N%f!<%6!<<-=q!#(B

SKK's dictionary of user-specified conversions.")

(defvar skk-backup-jisyo (if (eq system-type 'ms-dos) "~/_skk-jisyo.BAK" "~/.skk-jisyo.BAK") "\
*SKK $B$N%f!<%6!<<-=q$N%P%C%/%"%C%W%U%!%$%k!#(B

Name of user dictionary backup (a file name as a string).")

(defvar skk-jisyo-code nil "\
*Non-nil $B$G$"$l$P!"$=$NCM$G<-=q%P%C%U%!$N4A;z%3!<%I$r@_Dj$9$k!#(B
Mule $B$G$O!"(B*euc-japan*, *sjis*, *junet*$B!#(B
$B$^$?!"(B\"euc\", \"ujis\", \"sjis\", \"jis\" $B$J$I$NJ8;zNs$K$h$C$F$b;XDj$,(B
$B2DG=!#(B

If non-nil, the value sets the kanji code used in dictionary buffers.
In Mule, the symbols *euc-japan*, *sjis*, or *junet*.  Can also be
specified as a string such as \"euc\", \"ujis\", \"sjis\", or \"jis\".")

(defvar skk-keep-record t "\
*Non-nil $B$G$"$l$P!"JQ49$K4X$9$k5-O?$r(B skk-record-file $B$K<h$k!#(B

If non-nil, a record of conversions is kept in `skk-record-file'.")

(defvar skk-record-file (if (eq system-type 'ms-dos) "~/_skk-record" "~/.skk-record") "\
*$B%f!<%6!<<-=q$NE}7W$r<h$k%U%!%$%k!#(B
$B<-=q%;!<%V$N;~9o!"C18l$NEPO??t!"3NDj$r9T$C$?2s?t!"3NDjN(!"A4BN$N8l?t$N(B
$B>pJs$r<}$a$k!#(B

File containing statistics about the user dictionary.

At the time the dictionary is saved, the number of words registered,
number of conversions accepted, rate of acceptance, and the total
number of words are collected.")

(defvar skk-kakutei-key "\n" "\
*$B3NDjF0:n(B (\"skk-kakutei\") $B$r9T$&%-!<!#(B

The key that executes conversion confirmation (\"skk-kakutei\").")

(defvar skk-use-vip nil "\
*Non-nil $B$G$"$l$P!"(BVIP $B$KBP1~$9$k!#(B

If non-nil, VIP compatibility mode.")

(defvar skk-use-viper nil "\
*Non-nil $B$G$"$l$P!"(BVIPER $B$KBP1~$9$k!#!#(B

If non-nil, VIPER compatibility mode.")

(defvar skk-henkan-okuri-strictly nil "\
*Non-nil $B$G$"$l$P!"8+=P$78l$HAw$j2>L>$,0lCW$7$?$H$-$@$18uJd$H$7$F=PNO$9$k!#(B
$BNc$($P!"2<5-$N$h$&$J<-=q%(%s%H%j$,!"(Bskk-jisyo ($B%W%i%$%Y!<%H<-=q(B) $B$K$"$C$?>l9g$K(B

  \"$B$*$*(Bk /$BBg(B/$BB?(B/[$B$/(B/$BB?(B/]/[$B$-(B/$BBg(B/]/\"

\"$B"&$*$*(B*$B$/(B\" $B$rJQ49$7$?$H$-!"(B\"$BB?$/(B\" $B$N$_$r=PNO$7!"(B\"$BBg$/(B\" $B$r=PNO$7$J$$!#(B

SKK-JISYO.[SML] $B$NAw$j2>L>%(%s%H%j$O>e5-$N7A<0$K$J$C$F$$$J$$$N$G!"(Bskk-jisyo $B$N(B
$BAw$j$"$j$N<-=q%(%s%H%j$,$3$N7A<0$N$b$N$r$"$^$j4^$s$G$$$J$$>l9g$O!"$3$N%*%W%7%g(B
$B%s$r(B on $B$K$9$k$3$H$G!"$9$0$KC18lEPO?$KF~$C$F$7$^$&$N$GCm0U$9$k$3$H!#(B

skk-process-okuri-early $B$NCM$,(B nil $B$J$i$P>e5-$N7A<0$G(B skk-jisyo $B$,:n$i$l$k!#(B

Emacs 19 $B%Y!<%9$N(B Mule $B$J$i$P!"2<5-$N%U%)!<%`$rI>2A$9$k$3$H$G!"C18lEPO?$KF~$C(B
$B$?$H$-$@$10l;~E*$K$3$N%*%W%7%g%s$r(B nil $B$K$9$k$3$H$,$G$-$k!#(B

    (add-hook 'minibuffer-setup-hook
              (function
               (lambda ()
                 (if (and (boundp 'skk-henkan-okuri-strictly)
                          skk-henkan-okuri-strictly
                          (not (eq last-command 'skk-purge-from-jisyo)) )
                     (progn
                       (setq skk-henkan-okuri-strictly nil)
                       (put 'skk-henkan-okuri-strictly 'temporary-nil t) )))))

    (add-hook 'minibuffer-exit-hook
              (function
               (lambda ()
                 (if (get 'skk-henkan-okuri-strictly 'temporary-nil)
                     (progn
                       (put 'skk-henkan-okuri-strictly 'temporary-nil nil)
                       (setq skk-henkan-okuri-strictly t) )))))

$B$3$N%*%W%7%g%sMxMQ;~$O!"(Bskk-process-okuri-early $B$NCM$O(B nil $B$G$J$1$l$P$J$i$J$$(B
\($B%a%K%e!<%P!<(B $B$rMxMQ$7$F%+%9%?%^%$%:$7$?>l9g$O<+F0E*$KD4@0$5$l$k(B)$B!#(B

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

    (add-hook 'minibuffer-setup-hook
              (function
               (lambda ()
                 (if (and (boundp 'skk-henkan-okuri-strictly)
                          skk-henkan-okuri-strictly
                          (not (eq last-command 'skk-purge-from-jisyo)) )
                     (progn
                       (setq skk-henkan-okuri-strictly nil)
                       (put 'skk-henkan-okuri-strictly 'temporary-nil t) )))))

    (add-hook 'minibuffer-exit-hook
              (function
               (lambda ()
                 (if (get 'skk-henkan-okuri-strictly 'temporary-nil)
                     (progn
                       (put 'skk-henkan-okuri-strictly 'temporary-nil nil)
                       (setq skk-henkan-okuri-strictly t) )))))

When using this option, `skk-process-okuri-early' must be `nil'.
\(When using customize from the menubar this will automatically
temporarily be set to `nil'.)")

(defvar skk-henkan-strict-okuri-precedence nil "\
*Non-nil $B$G$"$l$P!"8+=P$78l$HAw$j2>L>$,0lCW$7$?8uJd$rM%@h$7$FI=<($9$k!#(B
$BNc$($P!"2<5-$N$h$&$J<-=q%(%s%H%j$,!"(Bskk-jisyo ($B%W%i%$%Y!<%H<-=q(B) $B$K$"$C$?>l9g$K(B

  \"$B$*$*(Bk /$BBg(B/$BB?(B/[$B$/(B/$BB?(B/]/[$B$-(B/$BBg(B/]/\"

\"$B"&$*$*(B*$B$/(B\" $B$rJQ49$7$?$H$-!"$^$:(B\"$BB?$/(B\" $B$r=PNO$7!"(B
$B<!$K(B \"$BBg$/(B\" $B$r=PNO$9$k!#(B

\"$BBg$/(B\"$B$J$I$N8uJd$O$&$C$H$&$7$$$,!"$9$0$KC18lEPO?$K$O$$$C$F$7$^$&$N$b(B
$B7y$J$R$H$K$*$9$9$a!#(B

$B$3$N%*%W%7%g%sMxMQ;~$O!"(Bskk-process-okuri-early $B$NCM$O(B nil $B$G$J$i$J$$!#(B
$B$^$?(B skk-henkan-okuri-strictly $B$,(B non-nil $B$N$H$-$O!"$3$NJQ?t$OL5;k$5$l$k!#(B
\($B%a%K%e!<%P!<(B $B$rMxMQ$7$F%+%9%?%^%$%:$7$?>l9g$O<+F0E*$KD4@0$5$l$k(B)$B!#(B")

(defvar skk-auto-okuri-process nil "\
*Non-nil $B$G$"$l$P!"Aw$j2>L>ItJ,$r<+F0G'<1$7$FJQ49$r9T$&!#(B
$BNc$($P!"(B

    \"Uresii (\"UreSii\" $B$G$O$J$/(B) -> $B4r$7$$(B\"

$B$N$h$&$KJQ49$5$l$k!#C"$7!"(Bskk-jisyo $B<-=q(B ($B%W%i%$%Y!<%H<-=q(B) $B$,!"(B

    \"$B$&$l(Bs /$B4r(B/[$B$7(B/$B4r(B/]/\"

$B$N$h$&$J7A<0$K$J$C$F$$$k$3$H$,I,MW$G$"$k(B (SKK-JISYO.[SML] $B$O$3$N7A<0$KBP1~$7(B
$B$F$$$J$$$N$G!"(Bskk-jisyo $B$K$3$N%(%s%H%j$,$J$1$l$P$J$i$J$$(B)$B!#(B

$B$3$N%*%W%7%g%sMxMQ;~$O!"(Bskk-process-okuri-early $B$NCM$O(B nil $B$G$J$1$l$P$J$i$J$$(B
\($B%a%K%e!<%P!<(B $B$rMxMQ$7$F%+%9%?%^%$%:$7$?>l9g$O<+F0E*$KD4@0$5$l$k(B)$B!#(B")

(defvar skk-process-okuri-early nil "\
*Non-nil $B$G$"$l$P!"Aw$j2>L>$N%m!<%^;z%W%l%U%#%C%/%9$NF~NO;~E@$GJQ49$r3+;O$9$k!#(B
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
$B%;%C%H$5$l$k!#(B")

(defvar skk-egg-like-newline nil "\
*Non-nil $B$G$"$l$P!""'%b!<%I$G2~9T$r%?%$%W$7$F$b3NDj$9$k$N$_$G2~9T$7$J$$!#(B")

(defvar skk-kakutei-early t "\
*Non-nil $B$G$"$l$P(B skk-kana-input $B$,8F$P$l$?$H$-$K8=:_$N8uJd$r3NDj$9$k!#(B
$BNc$($P!"(B

    \"$B"&$+$/$F$$(B -> $B"'3NDj(B -> $B3NDj(Bs -> $B3NDj$9(B\"

$B$N$h$&$KJQ498e!"!V$9!W$N(B prefix $B$G$"$k(B \"s\" $B$rF~NO$7$?;~E@$G3NDj$9$k!#(B
nil $B$G$"$l$P!"Nc$($P(B

    \"$B"&$+$/$F$$(B -> $B"'3NDj(B -> $B"'3NDj(Bs -> $B"'3NDj$9$k(B -> $B3NDj$9$k!#(B\"

$B$N$h$&$K(B skk-kakutei $B$rD>@\!"4V@\$K%3!<%k$9$k$^$G(B ($B6gFIE@$rF~NO$7$?$j!"?7$?$J(B
$B"&%b!<%I$KF~$C$?$j$9$k$H4V@\E*$K(B skk-kakutei $B$r%3!<%k$9$k(B) $B$O!"3NDj$7$J$$$N$G!"(B
$B$=$N4V$O!"JQ498uJd$rA*$S$J$*$9$3$H$J$I$,2DG=!#(B

$B$3$N%*%W%7%g%sMxMQ;~$O!"(Bskk-process-okuri-early $B$NCM$O(B nil $B$G$J$1$l$P$J$i$J$$(B
\($B%a%K%e!<%P!<(B $B$rMxMQ$7$F%+%9%?%^%$%:$7$?>l9g$O<+F0E*$KD4@0$5$l$k(B)$B!#(B")

(defvar skk-delete-implies-kakutei t "\
*Non-nil $B$G$"$l$P!""'%b!<%I$G(B BS $B$r2!$9$H!"A0$N0lJ8;z$r:o=|$73NDj$9$k!#(B
nil $B$G$"$l$P!"0l$DA0$N8uJd$rI=<($9$k!#(B")

(defvar skk-allow-spaces-newlines-and-tabs t "\
*Non-nil $B$G$"$l$P!"(Bskk-henkan-key $B$K%9%Z!<%9!"%?%V!"2~9T$,$"$C$F$bJQ492DG=!#(B
$BNc$($P!"2<5-$N$h$&$K(B skk-henkan-key $B$NCf$K2~9T$,F~$C$F$$$F$bJQ49$,2DG=$G$"$k!#(B

     \"$B"&$+(B
  $B$J(B\"
   -> \"$B2>L>(B\"

$B$3$NCM$,(B nil $B$G$"$l$P!":G=i$N%9%Z!<%9$G(B skk-henkan-key $B$r@Z$j5M$a$F$7$^$$!"(B
$B0J9_$N%9%Z!<%9!"%?%V!"2~9T$OL5;k$5$l$k!#(B
$B$3$NCM$O!"(Bskk-start-henkan, skk-ascii-henkan, skk-katakana-henkan,
skk-hiragana-henkan, skk-zenkaku-henkan $B5Z$S(B skk-backward-and-set-henkan-point
$B$NF0:n$K1F6A$9$k!#(B")

(defvar skk-convert-okurigana-into-katakana nil "\
*Non-nil $B$G$"$l$P!"%+%?%+%J%b!<%I$GJQ49$7$?$H$-$KAw$j2>L>$b%+%?%+%J$KJQ49$9$k!#(B")

(defvar skk-delete-okuri-when-quit nil "\
*Non-nil $B$G$"$l$P!"Aw$j$"$j$NJQ49Cf$K(B \"C-g\" $B$r2!$9$HAw$j2>L>$r>C$7"&%b!<%I$KF~$k!#(B
$BNc$($P!"(B

    \"$B"&$J(B*$B$/(B -> $B"'5c$/(B -> \"C-g\" ->$B"&$J(B\"

nil $B$G$"$l$P!"Aw$j2>L>$r4^$a$?8+=P$78l$r$=$N$^$^;D$7!""#%b!<%I$KF~$k!#Nc$($P!"(B

    \"$B"&$J(B*$B$/(B -> $B"'5c$/(B -> \"C-g\" -> $B$J$/(B\"")

(defvar skk-henkan-show-candidates-keys '(?a ?s ?d ?f ?j ?k ?l) "\
*$B%a%K%e!<7A<0$G8uJd$rA*Br$9$k$H$-$NA*Br%-!<$N%j%9%H!#(B
\"x\", \" \" $B5Z$S(B \"C-g\" $B0J30$N(B 7 $B$D$N%-!<(B (char type) $B$r4^$`I,MW$,$"(B
$B$k!#(B\"x\", \" \" $B5Z$S(B \"C-g\" $B$O8uJdA*Br;~$K$=$l$>$lFCJL$J;E;v$K3d$jEv(B
$B$F$i$l$F$$$k$N$G!"$3$N%j%9%H$NCf$K$O4^$a$J$$$3$H!#(B")

(defvar skk-ascii-mode-string " SKK" "\
*SKK $B$,(B ascii $B%b!<%I$G$"$k$H$-$K%b!<%I%i%$%s$KI=<($5$l$kJ8;zNs!#(B")

(defvar skk-hirakana-mode-string " $B$+$J(B" "\
*$B$R$i$,$J%b!<%I$G$"$k$H$-$K%b!<%I%i%$%s$KI=<($5$l$kJ8;zNs!#(B")

(defvar skk-katakana-mode-string " $B%+%J(B" "\
*$B%+%?%+%J%b!<%I$G$"$k$H$-$K%b!<%I%i%$%s$KI=<($5$l$kJ8;zNs!#(B")

(defvar skk-zenkaku-mode-string " $BA41Q(B" "\
*$BA41Q%b!<%I$G$"$k$H$-$K%b!<%I%i%$%s$KI=<($5$l$kJ8;zNs!#(B")

(defvar skk-abbrev-mode-string " a$B$"(B" "\
*SKK abbrev $B%b!<%I$G$"$k$H$-$K%b!<%I%i%$%s$KI=<($5$l$kJ8;zNs!#(B")

(defvar skk-echo t "\
*Non-nil $B$G$"$l$P!"2>L>J8;z$N%W%l%U%#%C%/%9$rI=<($9$k!#(B")

(defvar skk-use-numeric-conversion t "\
*Non-nil $B$G$"$l$P!"?tCMJQ49$r9T$&!#(B")

(defvar skk-char-type-vector [0 0 0 0 0 0 0 0 5 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 4 4 4 4 4 4 4 4 4 4 4 0 4 4 4 4 0 4 4 4 4 4 4 0 4 4 0 0 0 0 0 0 3 1 1 1 3 1 1 1 3 1 1 0 1 2 3 1 0 1 1 1 3 1 1 2 1 1 0 0 0 0 5] "\
*skk-kana-input $B$G;2>H$9$k$+$JJ8;zJQ49$N$?$a$N(B char type $B%Y%/%?!<!#(B
$B3FMWAG$N?t;z$N0UL#$O2<5-$NDL$j!#(B

0 $B%m!<%^J8;z$h$j$+$JJ8;z$X$NJQ49$rCf;_$9$k(B ($B8=:_$N$H$3$m;HMQ$7$F$$$J$$(B)$B!#(B
1 $BB%2;$N0lItJ,$H$J$jF@$k;R2;!#(B
2 $B>e5-(B 1 $B0J30$N;R2;(B (n, x)
3 $BJl2;(B
4 skk-mode $B$G!"(Bskk-set-henkan-point $B$K3d$jIU$1$i$l$F$$$kJ8;z!#(B
5 $B%W%l%U%#%C%/%9$r>C5n$9$k(B")

(defvar skk-standard-rom-kana-rule-list '(("b" "b" nil) ("by" "by" nil) ("c" "c" nil) ("ch" "ch" nil) ("cy" "cy" nil) ("d" "d" nil) ("dh" "dh" nil) ("dy" "dy" nil) ("f" "f" nil) ("fy" "fy" nil) ("g" "g" nil) ("gy" "gy" nil) ("h" "h" nil) ("hy" "hy" nil) ("j" "j" nil) ("jy" "jy" nil) ("k" "k" nil) ("ky" "ky" nil) ("m" "m" nil) ("my" "my" nil) ("n" "n" nil) ("ny" "ny" nil) ("p" "p" nil) ("py" "py" nil) ("r" "r" nil) ("ry" "ry" nil) ("s" "s" nil) ("sh" "sh" nil) ("sy" "sy" nil) ("t" "t" nil) ("th" "th" nil) ("ts" "ts" nil) ("ty" "ty" nil) ("v" "v" nil) ("w" "w" nil) ("x" "x" nil) ("xk" "xk" nil) ("xt" "xt" nil) ("xw" "xw" nil) ("xy" "xy" nil) ("y" "y" nil) ("z" "z" nil) ("zy" "zy" nil) ("bb" "b" ("$B%C(B" . "$B$C(B")) ("cc" "c" ("$B%C(B" . "$B$C(B")) ("dd" "d" ("$B%C(B" . "$B$C(B")) ("ff" "f" ("$B%C(B" . "$B$C(B")) ("gg" "g" ("$B%C(B" . "$B$C(B")) ("hh" "h" ("$B%C(B" . "$B$C(B")) ("jj" "j" ("$B%C(B" . "$B$C(B")) ("kk" "k" ("$B%C(B" . "$B$C(B")) ("mm" "m" ("$B%C(B" . "$B$C(B")) ("pp" "p" ("$B%C(B" . "$B$C(B")) ("rr" "r" ("$B%C(B" . "$B$C(B")) ("ss" "s" ("$B%C(B" . "$B$C(B")) ("tt" "t" ("$B%C(B" . "$B$C(B")) ("vv" "v" ("$B%C(B" . "$B$C(B")) ("ww" "w" ("$B%C(B" . "$B$C(B")) ("xx" "x" ("$B%C(B" . "$B$C(B")) ("yy" "y" ("$B%C(B" . "$B$C(B")) ("zz" "z" ("$B%C(B" . "$B$C(B")) ("a" nil ("$B%"(B" . "$B$"(B")) ("ba" nil ("$B%P(B" . "$B$P(B")) ("bya" nil ("$B%S%c(B" . "$B$S$c(B")) ("cha" nil ("$B%A%c(B" . "$B$A$c(B")) ("cya" nil ("$B%A%c(B" . "$B$A$c(B")) ("da" nil ("$B%@(B" . "$B$@(B")) ("dha" nil ("$B%G%c(B" . "$B$G$c(B")) ("dya" nil ("$B%B%c(B" . "$B$B$c(B")) ("fa" nil ("$B%U%!(B" . "$B$U$!(B")) ("fya" nil ("$B%U%c(B" . "$B$U$c(B")) ("ga" nil ("$B%,(B" . "$B$,(B")) ("gya" nil ("$B%.%c(B" . "$B$.$c(B")) ("ha" nil ("$B%O(B" . "$B$O(B")) ("hya" nil ("$B%R%c(B" . "$B$R$c(B")) ("ja" nil ("$B%8%c(B" . "$B$8$c(B")) ("jya" nil ("$B%8%c(B" . "$B$8$c(B")) ("ka" nil ("$B%+(B" . "$B$+(B")) ("kya" nil ("$B%-%c(B" . "$B$-$c(B")) ("ma" nil ("$B%^(B" . "$B$^(B")) ("mya" nil ("$B%_%c(B" . "$B$_$c(B")) ("na" nil ("$B%J(B" . "$B$J(B")) ("nya" nil ("$B%K%c(B" . "$B$K$c(B")) ("pa" nil ("$B%Q(B" . "$B$Q(B")) ("pya" nil ("$B%T%c(B" . "$B$T$c(B")) ("ra" nil ("$B%i(B" . "$B$i(B")) ("rya" nil ("$B%j%c(B" . "$B$j$c(B")) ("sa" nil ("$B%5(B" . "$B$5(B")) ("sha" nil ("$B%7%c(B" . "$B$7$c(B")) ("sya" nil ("$B%7%c(B" . "$B$7$c(B")) ("ta" nil ("$B%?(B" . "$B$?(B")) ("tha" nil ("$B%F%!(B" . "$B$F$!(B")) ("tya" nil ("$B%A%c(B" . "$B$A$c(B")) ("va" nil ("$B%t%!(B" . "$B$&!+$!(B")) ("wa" nil ("$B%o(B" . "$B$o(B")) ("xa" nil ("$B%!(B" . "$B$!(B")) ("xka" nil ("$B%u(B" . "$B$+(B")) ("xwa" nil ("$B%n(B" . "$B$n(B")) ("xya" nil ("$B%c(B" . "$B$c(B")) ("ya" nil ("$B%d(B" . "$B$d(B")) ("za" nil ("$B%6(B" . "$B$6(B")) ("zya" nil ("$B%8%c(B" . "$B$8$c(B")) ("i" nil ("$B%$(B" . "$B$$(B")) ("bi" nil ("$B%S(B" . "$B$S(B")) ("byi" nil ("$B%S%#(B" . "$B$S$#(B")) ("chi" nil ("$B%A(B" . "$B$A(B")) ("cyi" nil ("$B%A%#(B" . "$B$A$#(B")) ("di" nil ("$B%B(B" . "$B$B(B")) ("dhi" nil ("$B%G%#(B" . "$B$G$#(B")) ("dyi" nil ("$B%B%#(B" . "$B$B$#(B")) ("fi" nil ("$B%U%#(B" . "$B$U$#(B")) ("fyi" nil ("$B%U%#(B" . "$B$U$#(B")) ("gi" nil ("$B%.(B" . "$B$.(B")) ("gyi" nil ("$B%.%#(B" . "$B$.$#(B")) ("hi" nil ("$B%R(B" . "$B$R(B")) ("hyi" nil ("$B%R%#(B" . "$B$R$#(B")) ("ji" nil ("$B%8(B" . "$B$8(B")) ("jyi" nil ("$B%8%#(B" . "$B$8$#(B")) ("ki" nil ("$B%-(B" . "$B$-(B")) ("kyi" nil ("$B%-%#(B" . "$B$-$#(B")) ("mi" nil ("$B%_(B" . "$B$_(B")) ("myi" nil ("$B%_%#(B" . "$B$_$#(B")) ("ni" nil ("$B%K(B" . "$B$K(B")) ("nyi" nil ("$B%K%#(B" . "$B$K$#(B")) ("pi" nil ("$B%T(B" . "$B$T(B")) ("pyi" nil ("$B%T%#(B" . "$B$T$#(B")) ("ri" nil ("$B%j(B" . "$B$j(B")) ("ryi" nil ("$B%j%#(B" . "$B$j$#(B")) ("si" nil ("$B%7(B" . "$B$7(B")) ("shi" nil ("$B%7(B" . "$B$7(B")) ("syi" nil ("$B%7%#(B" . "$B$7$#(B")) ("ti" nil ("$B%A(B" . "$B$A(B")) ("thi" nil ("$B%F%#(B" . "$B$F$#(B")) ("tyi" nil ("$B%A%#(B" . "$B$A$#(B")) ("vi" nil ("$B%t%#(B" . "$B$&!+$#(B")) ("wi" nil ("$B%&%#(B" . "$B$&$#(B")) ("xi" nil ("$B%#(B" . "$B$#(B")) ("xwi" nil ("$B%p(B" . "$B$p(B")) ("zi" nil ("$B%8(B" . "$B$8(B")) ("zyi" nil ("$B%8%#(B" . "$B$8$#(B")) ("u" nil ("$B%&(B" . "$B$&(B")) ("bu" nil ("$B%V(B" . "$B$V(B")) ("byu" nil ("$B%S%e(B" . "$B$S$e(B")) ("chu" nil ("$B%A%e(B" . "$B$A$e(B")) ("cyu" nil ("$B%A%e(B" . "$B$A$e(B")) ("du" nil ("$B%E(B" . "$B$E(B")) ("dhu" nil ("$B%G%e(B" . "$B$G$e(B")) ("dyu" nil ("$B%B%e(B" . "$B$B$e(B")) ("fu" nil ("$B%U(B" . "$B$U(B")) ("fyu" nil ("$B%U%e(B" . "$B$U$e(B")) ("gu" nil ("$B%0(B" . "$B$0(B")) ("gyu" nil ("$B%.%e(B" . "$B$.$e(B")) ("hu" nil ("$B%U(B" . "$B$U(B")) ("hyu" nil ("$B%R%e(B" . "$B$R$e(B")) ("ju" nil ("$B%8%e(B" . "$B$8$e(B")) ("jyu" nil ("$B%8%e(B" . "$B$8$e(B")) ("ku" nil ("$B%/(B" . "$B$/(B")) ("kyu" nil ("$B%-%e(B" . "$B$-$e(B")) ("mu" nil ("$B%`(B" . "$B$`(B")) ("myu" nil ("$B%_%e(B" . "$B$_$e(B")) ("nu" nil ("$B%L(B" . "$B$L(B")) ("nyu" nil ("$B%K%e(B" . "$B$K$e(B")) ("pu" nil ("$B%W(B" . "$B$W(B")) ("pyu" nil ("$B%T%e(B" . "$B$T$e(B")) ("ru" nil ("$B%k(B" . "$B$k(B")) ("ryu" nil ("$B%j%e(B" . "$B$j$e(B")) ("su" nil ("$B%9(B" . "$B$9(B")) ("shu" nil ("$B%7%e(B" . "$B$7$e(B")) ("syu" nil ("$B%7%e(B" . "$B$7$e(B")) ("tu" nil ("$B%D(B" . "$B$D(B")) ("thu" nil ("$B%F%e(B" . "$B$F$e(B")) ("tsu" nil ("$B%D(B" . "$B$D(B")) ("tyu" nil ("$B%A%e(B" . "$B$A$e(B")) ("vu" nil ("$B%t(B" . "$B$&!+(B")) ("wu" nil ("$B%&(B" . "$B$&(B")) ("xu" nil ("$B%%(B" . "$B$%(B")) ("xtu" nil ("$B%C(B" . "$B$C(B")) ("xtsu" nil ("$B%C(B" . "$B$C(B")) ("xyu" nil ("$B%e(B" . "$B$e(B")) ("yu" nil ("$B%f(B" . "$B$f(B")) ("zu" nil ("$B%:(B" . "$B$:(B")) ("zyu" nil ("$B%8%e(B" . "$B$8$e(B")) ("e" nil ("$B%((B" . "$B$((B")) ("be" nil ("$B%Y(B" . "$B$Y(B")) ("bye" nil ("$B%S%'(B" . "$B$S$'(B")) ("che" nil ("$B%A%'(B" . "$B$A$'(B")) ("cye" nil ("$B%A%'(B" . "$B$A$'(B")) ("de" nil ("$B%G(B" . "$B$G(B")) ("dhe" nil ("$B%G%'(B" . "$B$G$'(B")) ("dye" nil ("$B%B%'(B" . "$B$B$'(B")) ("fe" nil ("$B%U%'(B" . "$B$U$'(B")) ("fye" nil ("$B%U%'(B" . "$B$U$'(B")) ("ge" nil ("$B%2(B" . "$B$2(B")) ("gye" nil ("$B%.%'(B" . "$B$.$'(B")) ("he" nil ("$B%X(B" . "$B$X(B")) ("hye" nil ("$B%R%'(B" . "$B$R$'(B")) ("je" nil ("$B%8%'(B" . "$B$8$'(B")) ("jye" nil ("$B%8%'(B" . "$B$8$'(B")) ("ke" nil ("$B%1(B" . "$B$1(B")) ("kye" nil ("$B%-%'(B" . "$B$-$'(B")) ("me" nil ("$B%a(B" . "$B$a(B")) ("mye" nil ("$B%_%'(B" . "$B$_$'(B")) ("ne" nil ("$B%M(B" . "$B$M(B")) ("nye" nil ("$B%K%'(B" . "$B$K$'(B")) ("pe" nil ("$B%Z(B" . "$B$Z(B")) ("pye" nil ("$B%T%'(B" . "$B$T$'(B")) ("re" nil ("$B%l(B" . "$B$l(B")) ("rye" nil ("$B%j%'(B" . "$B$j$'(B")) ("se" nil ("$B%;(B" . "$B$;(B")) ("she" nil ("$B%7%'(B" . "$B$7$'(B")) ("sye" nil ("$B%7%'(B" . "$B$7$'(B")) ("te" nil ("$B%F(B" . "$B$F(B")) ("the" nil ("$B%F%'(B" . "$B$F$'(B")) ("tye" nil ("$B%A%'(B" . "$B$A$'(B")) ("ve" nil ("$B%t%'(B" . "$B$&!+$'(B")) ("we" nil ("$B%&%'(B" . "$B$&$'(B")) ("xe" nil ("$B%'(B" . "$B$'(B")) ("xke" nil ("$B%v(B" . "$B$1(B")) ("xwe" nil ("$B%q(B" . "$B$q(B")) ("ye" nil ("$B%$%'(B" . "$B$$$'(B")) ("ze" nil ("$B%<(B" . "$B$<(B")) ("zye" nil ("$B%8%'(B" . "$B$8$'(B")) ("o" nil ("$B%*(B" . "$B$*(B")) ("bo" nil ("$B%\(B" . "$B$\(B")) ("byo" nil ("$B%S%g(B" . "$B$S$g(B")) ("cho" nil ("$B%A%g(B" . "$B$A$g(B")) ("cyo" nil ("$B%A%g(B" . "$B$A$g(B")) ("do" nil ("$B%I(B" . "$B$I(B")) ("dho" nil ("$B%G%g(B" . "$B$G$g(B")) ("dyo" nil ("$B%B%g(B" . "$B$B$g(B")) ("fo" nil ("$B%U%)(B" . "$B$U$)(B")) ("fyo" nil ("$B%U%g(B" . "$B$U$g(B")) ("go" nil ("$B%4(B" . "$B$4(B")) ("gyo" nil ("$B%.%g(B" . "$B$.$g(B")) ("ho" nil ("$B%[(B" . "$B$[(B")) ("hyo" nil ("$B%R%g(B" . "$B$R$g(B")) ("jo" nil ("$B%8%g(B" . "$B$8$g(B")) ("jyo" nil ("$B%8%g(B" . "$B$8$g(B")) ("ko" nil ("$B%3(B" . "$B$3(B")) ("kyo" nil ("$B%-%g(B" . "$B$-$g(B")) ("mo" nil ("$B%b(B" . "$B$b(B")) ("myo" nil ("$B%_%g(B" . "$B$_$g(B")) ("no" nil ("$B%N(B" . "$B$N(B")) ("nyo" nil ("$B%K%g(B" . "$B$K$g(B")) ("po" nil ("$B%](B" . "$B$](B")) ("pyo" nil ("$B%T%g(B" . "$B$T$g(B")) ("ro" nil ("$B%m(B" . "$B$m(B")) ("ryo" nil ("$B%j%g(B" . "$B$j$g(B")) ("so" nil ("$B%=(B" . "$B$=(B")) ("sho" nil ("$B%7%g(B" . "$B$7$g(B")) ("syo" nil ("$B%7%g(B" . "$B$7$g(B")) ("to" nil ("$B%H(B" . "$B$H(B")) ("tho" nil ("$B%F%g(B" . "$B$F$g(B")) ("tyo" nil ("$B%A%g(B" . "$B$A$g(B")) ("vo" nil ("$B%t%)(B" . "$B$&!+$)(B")) ("wo" nil ("$B%r(B" . "$B$r(B")) ("xo" nil ("$B%)(B" . "$B$)(B")) ("xyo" nil ("$B%g(B" . "$B$g(B")) ("yo" nil ("$B%h(B" . "$B$h(B")) ("zo" nil ("$B%>(B" . "$B$>(B")) ("zyo" nil ("$B%8%g(B" . "$B$8$g(B")) ("nn" nil ("$B%s(B" . "$B$s(B")) ("n'" nil ("$B%s(B" . "$B$s(B")) ("z/" nil ("$B!&(B" . "$B!&(B")) ("z," nil ("$B!E(B" . "$B!E(B")) ("z." nil ("$B!D(B" . "$B!D(B")) ("z-" nil ("$B!A(B" . "$B!A(B")) ("zh" nil ("$B"+(B" . "$B"+(B")) ("zj" nil ("$B"-(B" . "$B"-(B")) ("zk" nil ("$B",(B" . "$B",(B")) ("zl" nil ("$B"*(B" . "$B"*(B")) ("z[" nil ("$B!X(B" . "$B!X(B")) ("z]" nil ("$B!Y(B" . "$B!Y(B"))) "\
SKK $B$NI8=`$N%m!<%^;z$+$JJQ49$N%*!<%H%^%H%s$N>uBVA+0\5,B'!#(B
$B%j%9%H$N3FMWAG$O!"(B($B8=:_$N>uBV(B@$BF~NO(B $B<!$N>uBV(B $B=PNO(B) ($BC"$7!"(B\"@\" $B$OO"@\(B) $B$r0UL#(B
$B$9$k!#(B
$B%7%9%F%`MQ$J$N$G%+%9%?%^%$%:$K$O(B skk-rom-kana-rule-list $B$rMxMQ$7$F$/$@$5$$!#(B")

(defvar skk-rom-kana-rule-list nil "\
*$B%m!<%^;z$+$JJQ49$N%*!<%H%^%H%s$N>uBVA+0\5,B'!#(B
$B%j%9%H$N3FMWAG$O!"(B($B8=:_$N>uBV(B@$BF~NO(B $B<!$N>uBV(B $B=PNO(B) ($BC"$7!"(B\"@\" $B$OO"@\(B) $B$r0UL#(B
$B$9$k!#%+%9%?%^%$%:$K$O(B skk-standard-rom-kana-rule-list $B$G$OL5$/!"(B
$B$3$A$i$rMxMQ$7$F$/$@$5$$!#(B")

(defvar skk-fallback-rule-alist '(("n" "$B%s(B" . "$B$s(B")) "\
*$B%m!<%^;z$+$JJQ49;~$K!"(Bskk-rom-kana-rule-list, skk-standard-rom-kana-rule-list $B$N(B
$B$"$H$K;2>H$5$l$k5,B'!#(B
$B%j%9%H$N3FMWAG$O!"(B($B8=:_$N>uBV(B $B=PNO(B) $B$r0UL#$9$k!#(B
$B$3$N5,B'$,E,MQ$5$l$?>l9g!"F~NO$O%9%H%j!<%`$KJV$5$l$k!#(B")

(defvar skk-postfix-rule-alist '(("oh" "$B%*(B" . "$B$*(B")) "\
*$B%m!<%^;z$+$JJQ49;~$K!"D>A0$N$+$JJ8;z$r:n$k$N$KMQ$$$i$l$?:G8e$NF~NO$H(B
$B8=:_$NF~NO$+$i$+$JJ8;z$r:n$j$@$9$?$a$N5,B'!#(B
$B%j%9%H$N3FMWAG$O!"(B($BD>A0$NF~NO(B@$BF~NO(B $B=PNO(B) ($BC"$7!"(B\"@\" $B$OO"@\(B) $B$r0UL#$9$k!#(B")

(defvar skk-previous-candidate-char ?x "\
*skk-previous-candidate $B$r3dEv$F$?%-%c%i%/%?!#(B")

(defvar skk-okuri-char-alist nil "\
*")

(defvar skk-downcase-alist nil "\
*")

(defvar skk-input-vector [nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil "$B!*(B" nil nil nil nil nil nil nil nil nil nil "$B!"(B" "$B!<(B" "$B!#(B" nil nil nil nil nil nil nil nil nil nil nil "$B!'(B" "$B!((B" nil nil nil "$B!)(B" nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil "$B!V(B" nil "$B!W(B" nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil] "\
*skk-self-insert $B$G;2>H$5$l$kJ8;z%F!<%V%k!#(B
$B%-!<$KBP1~$9$k0LCV$KJ8;zNs$,$"$l$P!"$R$i$,$J%b!<%I$b$7$/$O%+%?%+%J%b!<%I$G!"3:(B
$BEv$N%-!<$r2!$9$3$H$G!"BP1~$9$kJ8;z$,A^F~$5$l$k!#(B
$BNc$($P!"(B\"~\" $B%-!<$KBP1~$7$F!"(B\"$B!A(B\" $B$rA^F~$5$;$k$h$&$KJQ99$7$?$1$l$P!"(Bskk.el 
$B$N%m!<%I8e(B ($B$b$7$/$O(B skk-load-hook $B$rMxMQ$7$F(B)$B!"(B

  (aset skk-input-vector 126 \"$B!A(B\")

$B$H$9$k$+!"$b$7$/$O!"(Bskk-input-vector $B$N(B 126 $BHVL\(B (0 $BHV$+$i?t$($F(B) $B$NCM$r(B
\"$B!A(B\" $B$H$9$k$h$&$J(B skk-input-vector $B$rD>@\=q$-!"(Bsetq $B$GBeF~$9$k(B (126 $B$O!"(B?
{ $B$rI>2A$7$?$H$-$NCM(B)$B!#(B")

(defvar skk-zenkaku-vector [nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil "$B!!(B" "$B!*(B" "$B!I(B" "$B!t(B" "$B!p(B" "$B!s(B" "$B!u(B" "$B!G(B" "$B!J(B" "$B!K(B" "$B!v(B" "$B!\(B" "$B!$(B" "$B!](B" "$B!%(B" "$B!?(B" "$B#0(B" "$B#1(B" "$B#2(B" "$B#3(B" "$B#4(B" "$B#5(B" "$B#6(B" "$B#7(B" "$B#8(B" "$B#9(B" "$B!'(B" "$B!((B" "$B!c(B" "$B!a(B" "$B!d(B" "$B!)(B" "$B!w(B" "$B#A(B" "$B#B(B" "$B#C(B" "$B#D(B" "$B#E(B" "$B#F(B" "$B#G(B" "$B#H(B" "$B#I(B" "$B#J(B" "$B#K(B" "$B#L(B" "$B#M(B" "$B#N(B" "$B#O(B" "$B#P(B" "$B#Q(B" "$B#R(B" "$B#S(B" "$B#T(B" "$B#U(B" "$B#V(B" "$B#W(B" "$B#X(B" "$B#Y(B" "$B#Z(B" "$B!N(B" "$B!@(B" "$B!O(B" "$B!0(B" "$B!2(B" "$B!F(B" "$B#a(B" "$B#b(B" "$B#c(B" "$B#d(B" "$B#e(B" "$B#f(B" "$B#g(B" "$B#h(B" "$B#i(B" "$B#j(B" "$B#k(B" "$B#l(B" "$B#m(B" "$B#n(B" "$B#o(B" "$B#p(B" "$B#q(B" "$B#r(B" "$B#s(B" "$B#t(B" "$B#u(B" "$B#v(B" "$B#w(B" "$B#x(B" "$B#y(B" "$B#z(B" "$B!P(B" "$B!C(B" "$B!Q(B" "$B!A(B" nil] "\
*skk-zenkaku-insert $B$G;2>H$5$l$kJ8;z%F!<%V%k!#(B
$B%-!<$KBP1~$9$k0LCV$KJ8;zNs$,$"$l$P!"A41Q%b!<%I$G3:Ev$N%-!<$r2!$9$3$H$G!"BP1~$9(B
$B$kJ8;z$,A^F~$5$l$k!#(B
$BCM$NJQ99J}K!$K$D$$$F$O!"(Bskk-input-vector $B$r;2>H$N$3$H!#(B")

(defvar skk-use-face (or window-system (skk-terminal-face-p)) "\
*Non-nil $B$G$"$l$P!"(BEmacs 19 $B$N(B face $B$N5!G=$r;HMQ$7$FJQ49I=<($J$I$r9T$J$&!#(B")

(defvar skk-henkan-face (if (and (or window-system (skk-terminal-face-p)) (or (and (fboundp 'frame-face-alist) (assq 'highlight (frame-face-alist (selected-frame)))) (and (fboundp 'face-list) (memq 'highlight (face-list))))) 'highlight) "\
*$BJQ498uJd$N(B face $BB0@-!#(Bskk-use-face $B$,(B non-nil $B$N$H$-$N$_M-8z!#(B
Emacs $BI8=`%U%'%$%9$N(B default, modeline, region, secondary-selection,
highlight, underline, bold, italic, bold-italic $B$NB>!"?7$?$K(B face $B$r:n$j;XDj$9(B
$B$k$3$H$b2DG=!#(B
$B?7$?$J(B face $B$r:n$j;XDj$9$k$K$O(B skk-make-face $B$rMxMQ$7$F!"(B

      (skk-make-face 'DimGray/PeachPuff1)
      (setq skk-henkan-face 'DimGray/PeachPuff1)

$B$N$h$&$K$9$k$N$,<j7Z!#(Bforeground $B$H(B background $B$N?';XDj$@$1$G$J$$6E$C$?(B face
$B$r:n$k>l9g$O!"(Bskk-make-face $B$G$OBP1~$G$-$J$$$N$G!"(BEmacs $B$N(B hilit19.el $B$N(B
hilit-lookup-face-create $B$J$I$rMxMQ$9$k!#?'$rIU$1$k>l9g$NG[?'$O!"(Bcanna.el $B$N(B
canna:attribute-alist $B$,NI$$Nc$+$b$7$l$J$$!#(B")

(defvar skk-use-color-cursor (and window-system (fboundp 'x-display-color-p) (x-display-color-p)) "\
*Non-nil $B$G$"$l$P!"(BSKK $B%b!<%I$NF~NO%b!<%I$K1~$8$F%+!<%=%k$K?'$rIU$1$k!#(B")

(defvar skk-hirakana-cursor-color (if (eq skk-background-mode 'light) "coral4" "pink") "\
*$B$+$J%b!<%I$r<($9%+!<%=%k?'!#(B")

(defvar skk-katakana-cursor-color (if (eq skk-background-mode 'light) "forestgreen" "green") "\
*$B%+%?%+%J%b!<%I$r<($9%+!<%=%k?'!#(B")

(defvar skk-zenkaku-cursor-color "gold" "\
*$BA43Q1Q;z%b!<%I$r<($9%+!<%=%k?'!#(B")

(defvar skk-ascii-cursor-color (if (eq skk-background-mode 'light) "ivory4" "gray") "\
*$B%"%9%-!<%b!<%I$r<($9%+!<%=%k?'!#(B")

(defvar skk-abbrev-cursor-color "royalblue" "\
*$B%"%9%-!<%b!<%I$r<($9%+!<%=%k?'!#(B")

(defvar skk-report-set-cursor-error t "\
*Non-nil $B$G$"$l$P!"%+%i!<%^%C%W@Z$l$,5/$-$?>l9g!"%(%i!<%a%C%;!<%8$rI=<($9$k!#(B
nil $B$G$"$l$P!"I=<($7$J$$!#(B")

(defvar skk-use-cursor-change t "\
*Non-nil $B$G$"$l$P!"(BOvwrt $B%^%$%J!<%b!<%I;~$K%+!<%=%k$NI}$r=L$a$k!#(B")

(defvar skk-auto-insert-paren nil "\
*Non-nil $B$G$"$l$P!"(B2 $B$D$NJ8;zNs$r$^$H$a$FA^F~$7!"$=$NJ8;zNs$N4V$K%+!<%=%k$r0\F0$9$k!#(B
$BNc$($P!"(B\"$B!V(B\" $B$rF~NO$7$?$H$-$K(B \"$B!W(B\" $B$r<+F0E*$KA^F~$7!"N>$+$.$+$C$3$N4V$K(B
$B%+!<%=%k$r0\F0$9$k!#(B
$BA^F~$9$kJ8;zNs$O!"(Bskk-auto-paren-string-alist $B$G;XDj$9$k!#(B")

(defvar skk-auto-paren-string-alist '(("$B!V(B" . "$B!W(B") ("$B!X(B" . "$B!Y(B") ("(" . ")") ("$B!J(B" . "$B!K(B") ("{" . "}") ("$B!P(B" . "$B!Q(B") ("$B!R(B" . "$B!S(B") ("$B!T(B" . "$B!U(B") ("[" . "]") ("$B!N(B" . "$B!O(B") ("$B!L(B" . "$B!M(B") ("$B!Z(B" . "$B![(B") ("\"" . "\"") ("$B!H(B" . "$B!I(B")) "\
*$B<+F0E*$KBP$K$J$kJ8;zNs$rF~NO$9$k$?$a$NO"A[%j%9%H!#(B
car $B$NJ8;zNs$,A^F~$5$l$?$H$-$K(B cdr $B$NJ8;zNs$r<+F0E*$KA^F~$9$k!#(B")

(defvar skk-japanese-message-and-error nil "\
*Non-nil $B$G$"$l$P!"(BSKK $B$N%a%C%;!<%8$H%(%i!<$rF|K\8l$GI=<($9$k!#(B
nil $B$G$"$l$P!"1Q8l$GI=<($9$k!#(B")

(defvar skk-ascii-mode-map nil "\
*ASCII $B%b!<%I$N%-!<%^%C%W!#(B")

(defvar skk-j-mode-map nil "\
*$B$+$J%b!<%I$N%-!<%^%C%W!#(B")

(defvar skk-zenkaku-mode-map nil "\
*$BA43Q%b!<%I$N%-!<%^%C%W!#(B")

(defvar skk-abbrev-mode-map nil "\
*SKK abbrev $B%b!<%I$N%-!<%^%C%W!#(B")

(defvar skk-jisyo-save-count 50 "\
*$B?tCM$G$"$l$P!"$=$N2s?t<-=q$,99?7$5$l$?$H$-$K<-=q$r<+F0E*$K%;!<%V$9$k!#(B
  nil $B$G$"$l$P!"<-=q$N%*!<%H%;!<%V$r9T$J$o$J$$!#(B")

(defvar skk-byte-compile-init-file t "\
*Non-nil $B$G$"$l$P!"(Bskk-mode $B5/F0;~$K(B skk-init-file $B$r%P%$%H%3%s%Q%$%k$9$k!#(B
$B@53N$K8@$&$H!"(B

  (1)skk-init-file $B$r%P%$%H%3%s%Q%$%k$7$?%U%!%$%k$,$J$$$+!"(B
  (2)skk-init-file $B$H$=$N%P%$%H%3%s%Q%$%k:Q%U%!%$%k$rHf3S$7$F!"A0<T$NJ}$,?7$7(B
     $B$$$H$-(B

$B$K(B skk-init-file $B$r%P%$%H%3%s%Q%$%k$9$k!#(B
nil $B$G$"$l$P!"(Bskk-init-file $B$H$=$N%P%$%H%3%s%Q%$%k:Q$_%U%!%$%k$rHf3S$7$F(B 
skk-init-file $B$NJ}$,?7$7$$$H$-$O!"$=$N%P%$%H%3%s%Q%$%k:Q%U%!%$%k$r>C$9!#(B")

(defvar skk-count-private-jisyo-candidates-exactly nil "\
*Non-nil $B$G$"$l$P!"(BEmacs $B$r=*N;$9$k$H$-$K@53N$K8D?M<-=q$N8uJd?t$r?t$($k!#(B
nil $B$G$"$l$P!"(B1 $B9T$KJ#?t$N8uJd$,$"$C$F$b(B 1 $B8uJd$H$7$F?t$($k!#(B
$B7W;;7k2L$O!"(Bskk-record-file $B$KJ]B8$5$l$k!#(B")

(defvar skk-compare-jisyo-size-when-saving t "\
*Non-nil $B$G$"$l$P!"(Bskk-jisyo $B$N%;!<%V;~$K%U%!%$%k%5%$%:$N%A%'%C%/$r9T$J$&!#(B
$BA02s%;!<%V$7$?(B skk-jisyo $B$H:#2s%;!<%V$7$h$&$H$9$k<-=q$H$N%5%$%:Hf3S$r9T$J$$!"(B
$B8e<T$NJ}$,Bg$-$$$H$-$K%f!<%6!<$K%;!<%V$rB3$1$k$+$I$&$+$N3NG'$r5a$a$k!#(B")

(defvar skk-auto-start-henkan t "\
$BC18l$dJ8@a$N6h@Z$j$r<($9J8;z$NBG80$K$h$j<+F0E*$KJQ49$r3+;O$9$k!#(B
skk-auto-start-henkan-keyword-list $B$K$h$jC18l$dJ8@a$N6h@Z$j$r<($9J8;z$r;XDj$9$k!#(B")

(defvar skk-auto-start-henkan-keyword-list '("$B$r(B" "$B!"(B" "$B!#(B" "$B!%(B" "$B!$(B" "$B!)(B" "$B!W(B" "$B!*(B" "$B!((B" "$B!'(B" ")" ";" ":" "$B!K(B" "$B!I(B" "$B![(B" "$B!Y(B" "$B!U(B" "$B!S(B" "$B!Q(B" "$B!O(B" "$B!M(B" "}" "]" "?" "." "," "!") "\
$B<+F0JQ49$r3+;O$9$k%-!<%o!<%I!#(B
$B$3$N%j%9%H$NMWAG$NJ8;z$rA^F~$9$k$H!"(BSPC $B$r2!$9$3$H$J$/<+F0E*$KJQ49$r3+;O$9$k!#(B")

(defvar skk-search-excluding-word-pattern-function nil "\
*$B8D?M<-=q$K<h$j9~$^$J$$J8;zNs$N%Q%?!<%s$r8!:w$9$k4X?t$r;XDj$9$k!#(B
$B3NDj$7$?J8;zNs$r0z?t$KEO$7$F(B funcall $B$5$l$k!#(B

SKK $B$G$OJQ49!"3NDj$r9T$J$C$?J8;zNs$OA4$F8D?M<-=q$K<h$j9~$^$l$k$,!"$3$NJQ?t$G;X(B
$BDj$5$l$?4X?t$,(B non-nil $B$rJV$9$H$=$NJ8;zNs$O8D?M<-=q$K<h$j9~$^$l$J$$!#Nc$($P!"(B
$B$3$NJQ?t$K2<5-$N$h$&$J;XDj$9$k$H!"(BSKK abbrev mode $B$G$NJQ49$r=|$-!"%+%?%+%J$N$_(B
$B$+$i$J$kJ8;zNs$rJQ49$K$h$jF@$F3NDj$7$F$b!"$=$l$r8D?M<-=q$K<h$j9~$^$J$$!#(B

$B%+%?%+%J$rJQ49$K$h$j5a$a$?$$$,!"8D?M<-=q$K$O%+%?%+%J$N$_$N8uJd$r<h$j9~$_$?$/$J(B
$B$$!"$J$I!"8D?M<-=q$,I,MW0J>e$KKD$l$k$N$rM^$($kL\E*$K;HMQ$G$-$k!#(B

$B8D?M<-=q$K<h$j9~$^$J$$J8;zNs$K$D$$$F$OJd40$,8z$+$J$$$N$G!"Cm0U$9$k$3$H!#(B

  (setq skk-search-excluding-word-pattern-function
        (function
         (lambda (kakutei-word)
         ;; $B$3$N4X?t$,(B t $B$rJV$7$?$H$-$O!"$=$NJ8;zNs$O8D?M<-=q$K<h$j9~$^$l$J$$!#(B
           (save-match-data
             (and
            ;; $BAw$j$J$7JQ49$G!"(B
              (not skk-okuri-char)
            ;; $B3NDj8l$,%+%?%+%J$N$_$+$i9=@.$5$l$F$$$F!"(B
              (string-match \"^[$B!<%!(B-$B%s(B]+$\" kakutei-word)
            ;; SKK abbrev mode $B0J30$G$NJQ49$+!"(B
              (or (not skk-abbrev-mode)
                ;; $B8+=P$78l$,%+%?%+%J!"$R$i$,$J0J30$N$H$-!#(B
                ;; ($B8e$G"&%^!<%/$rIU$1$?$H$-$O!"8+=P$78l$,1QJ8;z$G$b!"(B
                ;; skk-abbrev-mode$B$,(B t $B$K$J$C$F$$$J$$(B)$B!#(B
                  (not (string-match \"^[^$B!<%!(B-$B%s$!(B-$B$s(B]+$\" skk-henkan-key)) )))))) ")

(defconst skk-kanji-len (length "$B$"(B") "\
$B4A;z0lJ8;z$ND9$5!#(BMule $B$G$O(B 3 $B$K$J$k!#(BXEmacs $B$G$O(B 1$B!#(B")

(defvar skk-insert-new-word-function nil "\
$B8uJd$rA^F~$7$?$H$-$K(B funcall $B$5$l$k4X?t$rJ]B8$9$kJQ?t!#(B")

(defvar skk-input-mode-string skk-hirakana-mode-string "\
SKK $B$NF~NO%b!<%I$r<($9J8;zNs!#(Bskk-mode $B5/F0;~$O!"(Bskk-hirakana-mode-string$B!#(B")

(defvar skk-isearch-message nil "\
skk-isearch $B4X?t$r%3!<%k$9$k$?$a$N%U%i%0!#(B
Non-nil $B$G$"$l$P!"(Bskk-isearch-message $B4X?t$r%3!<%k$9$k!#(B")

(defvar skk-mode-invoked nil "\
Non-nil $B$G$"$l$P!"(BEmacs $B$r5/F08e4{$K(B skk-mode $B$r5/F0$7$?$3$H$r<($9!#(B")

(skk-deflocalvar skk-mode nil "Non-nil $B$G$"$l$P!"%+%l%s%H%P%C%U%!$G8=:_(B skk-mode $B$r5/F0$7$F$$$k$3$H$r<($9!#(B")

(skk-deflocalvar skk-ascii-mode nil "Non-nil $B$G$"$l$P!"F~NO%b!<%I$,(B ASCII $B%b!<%I$G$"$k$3$H$r<($9!#(B")

(skk-deflocalvar skk-j-mode nil "Non-nil $B$G$"$l$P!"F~NO%b!<%I$,$+$J!&%+%J%b!<%I$G$"$k$3$H$r<($9!#(B")

(skk-deflocalvar skk-katakana nil "Non-nil $B$G$"$l$P!"F~NO%b!<%I$,%+%J%b!<%I$G$"$k$3$H$r<($9!#(B\n\"(and (not skk-katakana) skk-j-mode))\" $B$,(B t $B$G$"$l$P!"$+$J%b!<%I$G$"$k$3$H$r(B\n$B<($9!#(B")

(skk-deflocalvar skk-zenkaku-mode nil "Non-nil $B$G$"$l$P!"F~NO%b!<%I$,A41Q%b!<%I$G$"$k$3$H$r<($9!#(B")

(skk-deflocalvar skk-abbrev-mode nil "Non-nil $B$G$"$l$P!"F~NO%b!<%I$,(B SKK abbrev $B%b!<%I$G$"$k$3$H$r<($9!#(B")

(skk-deflocalvar skk-okurigana nil "Non-nil $B$G$"$l$P!"Aw$j2>L>ItJ,$,F~NOCf$G$"$k$3$H$r<($9!#(B")

(skk-deflocalvar skk-henkan-on nil "Non-nil $B$G$"$l$P!""&%b!<%I(B ($BJQ49BP>]$NJ8;zNs7hDj$N$?$a$N%b!<%I(B) $B$G$"$k$3$H$r<($9!#(B")

(skk-deflocalvar skk-henkan-active nil "Non-nil $B$G$"$l$P!""'%b!<%I(B ($BJQ49Cf(B) $B$G$"$k$3$H$r<($9!#(B")

(skk-deflocalvar skk-kakutei-flag nil "Non-nil $B$J$i3NDj$7$FNI$$8uJd$r8+$D$1$?>uBV$G$"$k$3$H$r;X$9!#(B\nskk-henkan, skk-search-kakutei-jisyo-file, skk-henkan-show-candidates,\nskk-henkan-in-minibuff $B$H(B skk-kakutei-save-and-init-variables $B$GJQ99!";2>H$5$l(B\n$B$k!#(B")

(skk-deflocalvar skk-prefix "" "$BF~NO$9$k$+$J$r7hDj$9$k$?$a$N%W%l%U%#%C%/%9!#(B\n$B8e$GF~NO$5$l$kJl2;$KBP1~$7$?(B skk-roma-kana-[aiue] $BO"A[%j%9%H$G!"$=$N(B\nskk-prefix $B$r%-!<$K$7$FF~NO$9$Y$-$+$JJ8;z$,7hDj$5$l$k!#(B\n$BNc$($P!"(B\"$B$+(B\" $B$N$h$&$K(B \"k\" $B$+$i;O$^$k;R2;$rF~NO$7$F$$$k$H$-$O!"(Bskk-prefix\n$B$O!"(B\"k\" $B$G!"$=$N<!$KF~NO$5$l$?Jl2;(B \"a\" $B$KBP1~$9$k(B skk-roma-kana-a $B$NCf$N(B\n\"k\" $B$r%-!<$K;}$DCM!"(B\"$B$+(B\" $B$b$7$/$O(B \"$B%+(B\" $B$,F~NO$9$Y$-$+$JJ8;z$H$J$k!#(B")

(skk-deflocalvar skk-henkan-start-point nil "$BJQ493+;O%]%$%s%H$r<($9%^!<%+!<!#(B")

(skk-deflocalvar skk-kana-start-point nil "$B$+$JJ8;z$N3+;O%]%$%s%H$r<($9%^!<%+!<!#(B")

(skk-deflocalvar skk-henkan-key nil "$BJQ49$9$Y$-8+=P$78l!#(B\n$BNc$($P!"(B\"$B"&$+$J(B\" $B$rJQ49$9$l$P!"(Bskk-henkan-key $B$K$O(B \"$B$+$J(B\" $B$,BeF~$5$l$k!#(B\n\"$B"&$o$i(B*$B$&(B\" $B$N$h$&$JAw$j$"$j$NJQ49$N>l9g$K$O!"(B\"$B$o$i(Bu\" $B$N$h$&$K!"4A;zItJ,$N(B\n$BFI$_$,$J(B + $BAw$j2>L>$N:G=i$NJ8;z$N%m!<%^;z$N%W%l%U%#%C%/%9$,BeF~$5$l$k!#(B")

(skk-deflocalvar skk-okuri-char nil "$BJQ49$9$Y$-8l$NAw$j2>L>$NItJ,$N%W%l%U%#%C%/%9!#(B\n$BNc$($P!"(B\"$B$*$/(B*$B$j(B\" $B$rJQ49$9$k$H$-$O!"(Bskk-okuri-char $B$O(B \"r\"$B!#(B\nskk-okuri-char $B$,(B non-nil $B$G$"$l$P!"Aw$j$"$j$NJQ49$G$"$k$3$H$r<($9!#(B")

(skk-deflocalvar skk-henkan-okurigana nil "$B8=:_$NJQ49$NAw$j2>L>ItJ,!#(B\n$BNc$($P!"(B\"$B"&$&$^$l(B*$B$k(B\" $B$rJQ49$9$l$P!"(Bskk-henkan-okurigana $B$K$O(B \"$B$k(B\" $B$,BeF~(B\n$B$5$l$k!#(B")

(skk-deflocalvar skk-henkan-list nil "$BJQ497k2L$N8uJd$N%j%9%H!#(B\n$BNc$($P!"(B\"$B"&$J(B*$B$/(B\" $B$H$$$&JQ49$9$l$P!"(Bskk-henkan-list $B$O(B\n(\"$BLD(B\" \"$B5c(B\" \"$BL5(B\" \"$BK4(B\") $B$N$h$&$K$J$k!#(B")

(skk-deflocalvar skk-henkan-count -1 "skk-henkan-list $B$N%j%9%H$N%$%s%G%/%9$G8=:_$N8uJd$r:9$9$b$N!#(B")

(skk-deflocalvar skk-current-search-prog-list nil "skk-search-prog-list $B$N8=:_$NCM$rJ]B8$9$k%j%9%H!#(B\n$B:G=i$NJQ49;~$O(B skk-search-prog-list $B$NA4$F$NCM$rJ];}$7!"JQ49$r7+$jJV$9$?$S$K(B 1\n$B$D$E$DC;$/$J$C$F$f$/!#(B")

(defvar skk-menu-modified-user-option nil "\
SKK $B%a%K%e!<%3%^%s%I$GJQ99$5$l$?%f!<%6!<JQ?tJ];}$9$k%j%9%H!#(B")

(autoload 'skk-save-point "skk" nil nil 'macro)

(autoload 'skk-message "skk" nil nil 'macro)

(autoload 'skk-error "skk" nil nil 'macro)

(autoload 'skk-yes-or-no-p "skk" nil nil 'macro)

(autoload 'skk-y-or-n-p "skk" nil nil 'macro)

(autoload 'skk-set-marker "skk" nil nil 'macro)

(defsubst skk-j-mode-on (&optional katakana) (setq skk-mode t skk-abbrev-mode nil skk-ascii-mode nil skk-j-mode t skk-zenkaku-mode nil skk-katakana katakana) (if katakana (progn (setq skk-input-mode-string skk-katakana-mode-string) (skk-set-cursor-color skk-katakana-cursor-color)) (setq skk-input-mode-string skk-hirakana-mode-string) (skk-set-cursor-color skk-hirakana-cursor-color)) (force-mode-line-update))

(defsubst skk-ascii-mode-on nil (setq skk-mode t skk-abbrev-mode nil skk-ascii-mode t skk-j-mode nil skk-zenkaku-mode nil skk-katakana nil skk-input-mode-string skk-ascii-mode-string) (skk-set-cursor-color skk-ascii-cursor-color) (force-mode-line-update))

(defsubst skk-zenkaku-mode-on nil (setq skk-mode t skk-abbrev-mode nil skk-ascii-mode nil skk-j-mode nil skk-zenkaku-mode t skk-katakana nil skk-input-mode-string skk-zenkaku-mode-string) (skk-set-cursor-color skk-zenkaku-cursor-color) (force-mode-line-update))

(defsubst skk-abbrev-mode-on nil (setq skk-mode t skk-abbrev-mode t skk-ascii-mode nil skk-j-mode nil skk-zenkaku-mode nil skk-katakana nil skk-input-mode-string skk-abbrev-mode-string) (skk-set-cursor-color skk-abbrev-cursor-color) (force-mode-line-update))

(defsubst skk-in-minibuffer-p nil (window-minibuffer-p (selected-window)))

(defsubst skk-insert-prefix (&optional char) (if skk-echo (let ((buffer-undo-list t)) (insert (or char skk-prefix)))))

(defsubst skk-erase-prefix nil (if skk-echo (let ((buffer-undo-list t)) (delete-region skk-kana-start-point (point)))))

(defsubst skk-numeric-p nil (and skk-use-numeric-conversion (require 'skk-num) skk-num-list))

(autoload 'skk-mode "skk" "\
$BF|K\8lF~NO%b!<%I!#(B
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
$B!VA41Q!W(B).  `
' returns to hiragana submode from either ASCII submode.

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

A candidate can be accepted by pressing `
', or by entering a
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
" t nil)

(autoload 'skk-auto-fill-mode "skk" "\
$BF|K\8lF~NO%b!<%I!#<+F0@^$jJV$75!G=IU$-!#(B
$B%^%$%J!<%b!<%I$N0l<o$G!"%*%j%8%J%k$N%b!<%I$K$O1F6A$rM?$($J$$!#(B
$B@5$N0z?t$rM?$($k$H!"6/@)E*$K(B auto-fill-mode $B5Z$S(B SKK $B%b!<%I$KF~$k!#(B
$BIi$N0z?t$rM?$($k$H(B auto-fill-mode $B5Z$S(B SKK $B%b!<%I$+$iH4$1$k!#(B" t nil)

(autoload 'skk-emulate-original-map "skk" nil nil nil)

(autoload 'skk-get-current-candidate "skk" nil nil nil)

(autoload 'skk-previous-candidate "skk" "\
$B"'%b!<%I$G$"$l$P!"0l$DA0$N8uJd$rI=<($9$k!#(B
$B"'%b!<%I0J30$G$O%+%l%s%H%P%C%U%!$K(B \"x\" $B$rA^F~$9$k!#(B
$B3NDj<-=q$K$h$k3NDj$ND>8e$K8F$V$H3NDj$,%"%s%I%%$5$l$F!"3NDjA0$N>uBV$G(B
skk-last-kakutei-henkan-key $B$,%+%l%s%H%P%C%U%!$KA^F~$5$l$k!#(B" t nil)

(autoload 'skk-kakutei "skk" "\
$B8=:_I=<($5$l$F$$$k8l$G3NDj$7!"<-=q$N99?7$r9T$&!#(B
$B%*%W%7%g%J%k0z?t$N(B WORD $B$rEO$9$H!"8=:_I=<($5$l$F$$$k8uJd$H$OL54X78$K(B WORD $B$G3N(B
$BDj$9$k!#(B" t nil)

(autoload 'skk-start-henkan "skk" "\
$B"&%b!<%I$G$OJQ49$r3+;O$9$k!#"'%b!<%I$G$O<!$N8uJd$rI=<($9$k!#(B
  $B$=$NB>$N%b!<%I$G$O!"%*%j%8%J%k$N%-!<3d$jIU$1$N%3%^%s%I$r%(%_%e%l!<%H$9$k!#(B" t nil)

(autoload 'skk-save-jisyo "skk" "\
SKK $B$N<-=q%P%C%U%!$r%;!<%V$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B QUIET $B$,(B non-nil $B$G$"$l$P!"<-=q%;!<%V;~$N%a%C%;!<%8$r=P$5$J(B
$B$$!#(B" t nil)

(autoload 'skk-search "skk" nil nil nil)

(autoload 'skk-nunion "skk" nil nil nil)

(autoload 'skk-update-jisyo "skk" nil nil nil)

(autoload 'skk-jisx0208-to-ascii "skk" nil nil nil)

(autoload 'skk-middle-list "skk" nil nil nil)

(autoload 'skk-set-cursor-properly "skk" nil nil nil)

(autoload 'skk-change-cursor-when-ovwrt "skk" nil nil nil)

(autoload 'skk-make-face "skk" nil nil nil)

;;;***

;;;### (autoloads (skk-adjust-search-prog-list-for-auto-okuri skk-init-auto-okuri-variables skk-remove-common) "skk-auto" "skk/skk-auto.el")

(skk-deflocalvar skk-henkan-in-minibuff-flag nil "$B%_%K%P%C%U%!$G<-=qEPO?$r9T$C$?$H$-$K$3$N%U%i%0$,N)$D!#(B\nskk-remove-common $B$G;2>H$5$l$k!#(B")

(autoload 'skk-remove-common "skk-auto" nil nil nil)

(autoload 'skk-init-auto-okuri-variables "skk-auto" nil nil nil)

(autoload 'skk-adjust-search-prog-list-for-auto-okuri "skk-auto" nil nil nil)

;;;***

;;;### (autoloads (skk-previous-completion skk-completion skk-start-henkan-with-completion) "skk-comp" "skk/skk-comp.el")

(autoload 'skk-start-henkan-with-completion "skk-comp" "\
$B"&%b!<%I$GFI$_$NJd40$r9T$J$C$?8e!"JQ49$9$k!#(B
$B$=$l0J30$N%b!<%I$G$O%*%j%8%J%k$N%-!<%^%C%W$K3d$jIU$1$i$l$?%3%^%s%I$r%(%_%e%l!<(B
$B%H$9$k!#(B" t nil)

(autoload 'skk-completion "skk-comp" nil nil nil)

(autoload 'skk-previous-completion "skk-comp" nil nil nil)

;;;***

;;;### (autoloads (skk-henkan-face-off-and-remove-itself skk-ignore-dic-word skk-times skk-minus skk-plus skk-calc skk-convert-gengo-to-ad skk-convert-ad-to-gengo skk-clock skk-today skk-date) "skk-gadget" "skk/skk-gadget.el")

(defvar skk-date-ad nil "\
*Non-nil $B$G$"$l$P!"(Bskk-today, skk-clock $B$G@>NqI=<($9$k!#(B
nil $B$G$"$l$P!"859fI=<($9$k!#(B")

(defvar skk-number-style 1 "\
*nil $B$b$7$/$O(B 0 $B$G$"$l$P!"(Bskk-today, skk-clock $B$N?t;z$rH>3Q$GI=<($9$k!#(B
t $B$b$7$/$O!"(B1 $B$G$"$l$P!"A43QI=<($9$k!#(B
t, 0, 1 $B0J30$N(B non-nil $BCM$G$"$l$P!"4A?t;z$GI=<($9$k!#(B")

(autoload 'skk-date "skk-gadget" nil nil nil)

(autoload 'skk-today "skk-gadget" "\
$B%$%s%?%i%/%F%#%V$K5/F0$9$k$H8=:_$NF|;~$rF|K\8lI=5-$G%]%$%s%H$KA^F~$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B AND-TIME $B$r;XDj$9$k$H!"F|;~$K2C$(!";~4V$bA^F~$9$k!#(B
skk-date-ad $B$H(B skk-number-style $B$K$h$C$FI=<(J}K!$N%+%9%?%^%$%:$,2DG=!#(B" t nil)

(autoload 'skk-clock "skk-gadget" "\
$B%G%8%?%k;~7W$r%_%K%P%C%U%!$KI=<($9$k!#(B
quit $B$9$k$H$=$N;~E@$NF|;~$r8uJd$H$7$FA^F~$9$k!#(B
quit $B$7$?$H$-$K5/F0$7$F$+$i$N7P2a;~4V$r%_%K%P%C%U%!$KI=<($9$k!#(B
interactive $B$K5/F0$9$kB>!"(B\"clock /(skk-clock)/\" $B$J$I$N%(%s%H%j$r(B SKK $B$N<-=q(B
$B$K2C$(!"(B\"/clock\"+ SPC $B$GJQ49$9$k$3$H$K$h$C$F$b5/F02D!#(BC-g $B$G;_$^$k!#(B
$B<B9TJQ49$G5/F0$7$?>l9g$O!"(BC-g $B$7$?;~E@$N;~E@$NF|;~$rA^F~$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B KAKUTEI-WHEN-QUIT $B$,(B non-nil $B$G$"$l$P(B C-g $B$7$?$H$-$K3N(B
$BDj$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B TIME-SIGNAL $B$,(B non-nil $B$G$"$l$P!"(BNTT $B$N;~JsIw$K(B ding $B$9$k!#(B
$B$=$l$>$l!"(B\"clock /(skk-clock nil t)/\" $B$N$h$&$J%(%s%H%j$r<-=q$KA^F~$9$l$PNI$$!#(B
skk-date-ad $B$H(B skk-number-style $B$K$h$C$FI=<(J}K!$N%+%9%?%^%$%:$,2DG=!#(B" t nil)

(autoload 'skk-convert-ad-to-gengo "skk-gadget" nil nil nil)

(autoload 'skk-convert-gengo-to-ad "skk-gadget" nil nil nil)

(autoload 'skk-calc "skk-gadget" nil nil nil)

(autoload 'skk-plus "skk-gadget" nil nil nil)

(autoload 'skk-minus "skk-gadget" nil nil nil)

(autoload 'skk-times "skk-gadget" nil nil nil)

(autoload 'skk-ignore-dic-word "skk-gadget" nil nil nil)

(autoload 'skk-henkan-face-off-and-remove-itself "skk-gadget" nil nil nil)

;;;***

;;;### (autoloads nil "skk-isearch" "skk/skk-isearch.el")

(defvar skk-isearch-whitespace-regexp "\\(\\s \\|[ 	\n\^L]\\)*")

;;;***

;;;### (autoloads (skk-romaji-message skk-romaji-region skk-hurigana-katakana-message skk-hurigana-katakana-region skk-hurigana-message skk-hurigana-region skk-gyakubiki-katakana-message skk-gyakubiki-katakana-region skk-gyakubiki-message skk-gyakubiki-region) "skk-kakasi" "skk/skk-kakasi.el")

(autoload 'skk-gyakubiki-region "skk-kakasi" "\
$B%j!<%8%g%s$N4A;z!"Aw$j2>L>$rA4$F$R$i$,$J$KJQ49$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B$J$+$7$^(B|$B$J$+$8$^(B}" t nil)

(autoload 'skk-gyakubiki-message "skk-kakasi" "\
$B%j!<%8%g%s$N4A;z!"Aw$j2>L>$rA4$F$R$i$,$J$KJQ498e!"%(%3!<$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B$J$+$7$^(B|$B$J$+$8$^(B}" t nil)

(autoload 'skk-gyakubiki-katakana-region "skk-kakasi" "\
$B%j!<%8%g%s$N4A;z!"Aw$j2>L>$rA4$F%+%?%+%J$KJQ49$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B%J%+%7%^(B|$B%J%+%8%^(B}" t nil)

(autoload 'skk-gyakubiki-katakana-message "skk-kakasi" "\
$B%j!<%8%g%s$N4A;z!"Aw$j2>L>$rA4$F%+%?%+%J$KJQ498e!"%(%3!<$9$k!#(B
$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B%J%+%7%^(B|$B%J%+%8%^(B}" t nil)

(autoload 'skk-hurigana-region "skk-kakasi" "\
$B%j!<%8%g%s$N4A;z$KA4$F$U$j$,$J$rIU$1$k!#(B
$BNc$($P!"(B
   \"$BJQ49A0$N4A;z$NOF$K(B\" -> \"$BJQ49A0(B[$B$X$s$+$s$^$((B]$B$N4A;z(B[$B$+$s$8(B]$B$NOF(B[$B$o$-(B]$B$K(B\"

$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B$J$+$7$^(B|$B$J$+$8$^(B}" t nil)

(autoload 'skk-hurigana-message "skk-kakasi" "\
$B%j!<%8%g%s$N4A;z$KA4$F$U$j$,$J$rIU$1!"%(%3!<$9$k!#(B
$BNc$($P!"(B
   \"$BJQ49A0$N4A;z$NOF$K(B\" -> \"$BJQ49A0(B[$B$X$s$+$s$^$((B]$B$N4A;z(B[$B$+$s$8(B]$B$NOF(B[$B$o$-(B]$B$K(B\"

$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B$J$+$7$^(B|$B$J$+$8$^(B}" t nil)

(autoload 'skk-hurigana-katakana-region "skk-kakasi" "\
$B%j!<%8%g%s$N4A;z$KA4$F%U%j%,%J$rIU$1$k!#(B
$BNc$($P!"(B
   \"$BJQ49A0$N4A;z$NOF$K(B\" -> \"$BJQ49A0(B[$B%X%s%+%s%^%((B]$B$N4A;z(B[$B%+%s%8(B]$B$NOF(B[$B%o%-(B]$B$K(B\"

$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B%J%+%7%^(B|$B%J%+%8%^(B}" t nil)

(autoload 'skk-hurigana-katakana-message "skk-kakasi" "\
$B%j!<%8%g%s$N4A;z$KA4$F%U%j%,%J$rIU$1!"%(%3!<$9$k!#(B
$BNc$($P!"(B
   \"$BJQ49A0$N4A;z$NOF$K(B\" -> \"$BJQ49A0(B[$B%X%s%+%s%^%((B]$B$N4A;z(B[$B%+%s%8(B]$B$NOF(B[$B%o%-(B]$B$K(B\"

$B%*%W%7%g%J%k0z?t$N(B ALL $B$,(B non-nil $B$J$i$P!"J#?t$N8uJd$,$"$k>l9g$O!"(B\"{}\" $B$G$/(B
$B$/$C$FI=<($9$k!#(B
$BNc$($P!"(B
    $BCfEg(B -> {$B%J%+%7%^(B|$B%J%+%8%^(B}" t nil)

(autoload 'skk-romaji-region "skk-kakasi" "\
$B%j!<%8%g%s$N4A;z!"$R$i$,$J!"%+%?%+%J!"A41QJ8;z$rA4$F%m!<%^;z$KJQ49$9$k!#(B
$BJQ49$K$O!"%X%\%s<0$rMQ$$$k!#(B
$BNc$($P!"(B
   \"$B4A;z$+$J:.$8$jJ8$r%m!<%^;z$KJQ49(B\"
    -> \"  kan'zi  kana  ma  ziri  bun'  woro-ma  zi ni hen'kan' \"

skk-romaji-*-by-hepburn $B$,(B nil $B$G$"$l$P!"%m!<%^;z$X$NJQ49MM<0$r71Na<0$KJQ99$9(B
$B$k!#Nc$($P!"(B\"$B$7(B\" $B$O%X%\%s<0$G$O(B \"shi\" $B$@$,!"71Na<0$G$O(B \"si\" $B$H$J$k!#(B" t nil)

(autoload 'skk-romaji-message "skk-kakasi" "\
$B%j!<%8%g%s$N4A;z!"$R$i$,$J!"%+%?%+%J!"A41QJ8;z$rA4$F%m!<%^;z$KJQ49$7!"%(%3!<$9$k!#(B
$BJQ49$K$O!"%X%\%s<0$rMQ$$$k!#(B
$BNc$($P!"(B
   \"$B4A;z$+$J:.$8$jJ8$r%m!<%^;z$KJQ49(B\"
    -> \"  kan'zi  kana  ma  ziri  bun'  woro-ma  zi ni hen'kan' \"

skk-romaji-*-by-hepburn $B$,(B nil $B$G$"$l$P!"%m!<%^;z$X$NJQ49MM<0$r71Na<0$KJQ99$9(B
$B$k!#Nc$($P!"(B\"$B$7(B\" $B$O%X%\%s<0$G$O(B \"shi\" $B$@$,!"71Na<0$G$O(B \"si\" $B$H$J$k!#(B" t nil)

;;;***

;;;### (autoloads (skk-display-code-for-char-at-point skk-input-by-code-or-menu) "skk-kcode" "skk/skk-kcode.el")

(autoload 'skk-input-by-code-or-menu "skk-kcode" "\
7bit $B$b$7$/$O(B 8bit $B$b$7$/$O(B $B6hE@%3!<%I$KBP1~$9$k(B 2byte $BJ8;z$rA^F~$9$k!#(B" t nil)

(autoload 'skk-display-code-for-char-at-point "skk-kcode" "\
$B%]%$%s%H$K$"$kJ8;z$N(B EUC $B%3!<%I$H(B JIS $B%3!<%I$rI=<($9$k!#(B" t nil)

;;;***

;;;### (autoloads (skk-menu-use-color-cursor skk-menu-compare-jisyo-size-when-saving skk-menu-server-debug skk-menu-report-server-response skk-menu-numeric-conversion-float-num skk-menu-use-kakasi skk-menu-romaji-*-by-hepburn skk-menu-date-ad skk-menu-dabbrev-like-completion skk-menu-auto-henkan skk-menu-count-private-jisyo-entries-exactly skk-menu-japanese-message-and-error skk-menu-auto-insert-paren skk-menu-use-overlay skk-menu-use-numeric-conversion skk-menu-echo skk-menu-delete-okuri-when-quit skk-menu-convert-okurigana-into-katakana skk-menu-allow-spaces-newlines-and-tabs skk-menu-delete-implies-kakutei skk-menu-egg-like-newline skk-menu-kakutei-early skk-menu-auto-okuri-process skk-menu-henkan-strict-okuri-precedence skk-menu-henkan-okuri-strictly skk-menu-process-okuri-early skk-menu-save-modified-user-option) "skk-menu" "skk/skk-menu.el")

(autoload 'skk-menu-save-modified-user-option "skk-menu" nil nil nil)

(autoload 'skk-menu-process-okuri-early "skk-menu" "\
skk-process-okuri-early $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B
$BN>N)$G$-$J$$%*%W%7%g%s$NCM$rD4@0$9$k!#(B" t nil)

(autoload 'skk-menu-henkan-okuri-strictly "skk-menu" "\
skk-henkan-okuri-strictly $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B
$BN>N)$G$-$J$$%*%W%7%g%s$NCM$rD4@0$9$k!#(B" t nil)

(autoload 'skk-menu-henkan-strict-okuri-precedence "skk-menu" "\
skk-henkan-strict-okuri-precedence $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B
$BN>N)$G$-$J$$%*%W%7%g%s$NCM$rD4@0$9$k!#(B" t nil)

(autoload 'skk-menu-auto-okuri-process "skk-menu" "\
skk-auto-okuri-process $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B
$BN>N)$G$-$J$$%*%W%7%g%s$NCM$rD4@0$9$k!#(B" t nil)

(autoload 'skk-menu-kakutei-early "skk-menu" "\
skk-kakutei-early $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B
$BN>N)$G$-$J$$%*%W%7%g%s$NCM$rD4@0$9$k!#(B" t nil)

(autoload 'skk-menu-egg-like-newline "skk-menu" "\
skk-egg-like-newline $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-delete-implies-kakutei "skk-menu" "\
skk-delete-implies-kakutei $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-allow-spaces-newlines-and-tabs "skk-menu" "\
skk-allow-spaces-newlines-and-tabs $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-convert-okurigana-into-katakana "skk-menu" "\
skk-convert-okurigana-into-katakana $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-delete-okuri-when-quit "skk-menu" "\
skk-delete-okuri-when-quit $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-echo "skk-menu" "\
skk-echo $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-use-numeric-conversion "skk-menu" "\
skk-use-numeric-conversion $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-use-overlay "skk-menu" "\
skk-use-face $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-auto-insert-paren "skk-menu" "\
skk-auto-insert-paren $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-japanese-message-and-error "skk-menu" "\
skk-japanese-message-and-error $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-count-private-jisyo-entries-exactly "skk-menu" "\
skk-count-private-jisyo-candidates-exactly $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-auto-henkan "skk-menu" "\
skk-auto-start-henkan $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-dabbrev-like-completion "skk-menu" "\
skk-dabbrev-like-completion $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-date-ad "skk-menu" "\
skk-date-ad $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-romaji-*-by-hepburn "skk-menu" "\
skk-romaji-*-by-hepburn $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-use-kakasi "skk-menu" "\
skk-use-kakasi $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-numeric-conversion-float-num "skk-menu" "\
skk-numeric-conversion-float-num $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-report-server-response "skk-menu" "\
skk-report-server-response $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-server-debug "skk-menu" "\
skk-server-debug $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-compare-jisyo-size-when-saving "skk-menu" "\
skk-compare-jisyo-size-when-saving $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

(autoload 'skk-menu-use-color-cursor "skk-menu" "\
skk-use-color-cursor $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B" t nil)

;;;***

;;;### (autoloads (skk-num skk-update-jisyo-for-numerals skk-numeric-midasi-word skk-init-numeric-conversion-variables skk-adjust-numeric-henkan-data skk-uniq-numerals skk-numeric-convert*7 skk-numeric-convert skk-compute-numeric-henkan-key) "skk-num" "skk/skk-num.el")

(defvar skk-num-type-list '((?0 . identity) (?1 . skk-zenkaku-num-str) (?2 . skk-kanji-num-str) (?3 . skk-kanji-num-str2) (?4 . skk-recompute-numerals) (?9 . skk-shogi-num-str)) "\
*$B?t;z$NJQ49$N$?$a$N!"%$%s%G%/%9$HJQ49$K;HMQ$9$k4X?t$H$N%I%C%H%Z%"$N%j%9%H!#(B
$B3FMWAG$O!"(B($B?t;z$N(B char-type . $B4X?tL>(B) $B$H$$$&9=@.$K$J$C$F$$$k!#(B
car $BItJ,$O!"Nc$($P!"8+=P$78l$,(B \"$BJ?@.(B#1$BG/(B\" $B$N$H$-!"(B# $B5-9f$ND>8e$KI=<($5$l$k?t(B
$B;z(B \"1\" $B$r(B char-type $B$GI=$o$7$?$b$N$rBeF~$9$k!#(B")

(defvar skk-uniq-numerals (or (assq ?4 skk-num-type-list) (and (assq ?2 skk-num-type-list) (assq ?3 skk-num-type-list))) "\
*Non-nil $B$G$"$l$P!"0[$J$k?tCMI=8=$G$bJQ497k2L$,F1$8?tCM$r=EJ#$7$F=PNO$7$J$$!#(B")

(skk-deflocalvar skk-num-list nil "skk-henkan-key $B$NCf$K4^$^$l$k?t;z$rI=$9J8;zNs$N%j%9%H!#(B\n$BNc$($P!"(B\"$B"&$X$$$;$$(B7$B$M$s(B10$B$,$D(B\" $B$NJQ49$r9T$&$H$-!"(Bskk-henkan-key $B$O(B\n\"$B$X$$$;$$(B7$B$M$s(B10$B$,$D(B\" $B$G$"$j!"(Bskk-num-list $B$O(B (\"7\" \"10\") $B$H$J$k!#(B")

(skk-deflocalvar skk-recompute-numerals-key nil "#4 $B%?%$%W$N%-!<$K$h$j?tCM$N:F7W;;$r9T$J$C$?$H$-$N8!:w%-!<!#(B")

(autoload 'skk-compute-numeric-henkan-key "skk-num" nil nil nil)

(autoload 'skk-numeric-convert "skk-num" nil nil nil)

(autoload 'skk-numeric-convert*7 "skk-num" nil nil nil)

(autoload 'skk-uniq-numerals "skk-num" nil nil nil)

(autoload 'skk-adjust-numeric-henkan-data "skk-num" nil nil nil)

(autoload 'skk-init-numeric-conversion-variables "skk-num" nil nil nil)

(autoload 'skk-numeric-midasi-word "skk-num" nil nil nil)

(autoload 'skk-update-jisyo-for-numerals "skk-num" nil nil nil)

(autoload 'skk-num "skk-num" nil nil nil)

;;;***

;;;### (autoloads (skk-adjust-search-prog-list-for-server-search skk-server-version) "skk-server" "skk/skk-server.el")

(defvar skk-server-host (getenv "SKKSERVER") "\
*SKK $B<-=q%5!<%P!<$rAv$i$;$F$$$k%[%9%HL>!#(B")

(defvar skk-server-prog (getenv "SKKSERV") "\
*SKK $B<-=q%5!<%P!<%W%m%0%i%`L>!#%U%k%Q%9$G=q$/!#(B")

(defvar skk-servers-list nil "\
*$B<-=q%5!<%P!<Kh$N>pJs%j%9%H!#(B
$BJ#?t$N%^%7!<%s$GF0$$$F$$$k%5!<%P$K%"%/%;%9$G$-$k>l9g$K$O!"0J2<$N$h$&$K!"%j%9%H(B
$B$N3FMWAG$K=g$K%[%9%HL>!"%U%k%Q%9$G$N(B SKK $B%5!<%P!<L>!"(BSKK $B%5!<%P!<$KEO$9<-=qL>!"(B
SKK $B%5!<%P!<$,;HMQ$9$k%]!<%HHV9f$r=q$-!"@_Dj$r$9$k$3$H$b$G$-$k!#(B

   (setq skk-servers-list
         '((\"mars\" \"/usr/local/soft/nemacs/etc/skkserv\" nil nil)
           (\"venus\" \"/usr/local/nemacs/etc/skkserv\" nil nil) ))

$B$3$N>l9g:G=i$K;XDj$7$?%5!<%P$K%"%/%;%9$G$-$J$/$J$k$H!"<+F0E*$K=g<!%j%9%H$K$"$k(B
$B;D$j$N%5!<%P$K%"%/%;%9$9$k$h$&$K$J$k!#$J$*(B SKK $B%5!<%P!<$KEO$9<-=q$*$h$S(B SKK $B%5!<(B
$B%P!<$,;HMQ$9$k%]!<%HHV9f$G!"(BSKK $B%5!<%P!<$r%3%s%Q%$%k;~$NCM$r;HMQ$9$k>l9g$O(B nil 
$B$r;XDj$9$k!#(B")

(autoload 'skk-server-version "skk-server" nil t nil)

(autoload 'skk-adjust-search-prog-list-for-server-search "skk-server" nil nil nil)

;;;***

;;;### (autoloads (skk-assoc-tree) "skk-tree" "skk/skk-tree.el")

(defvar skk-rom-kana-rule-tree nil "\
*skk-rom-kana-rule-list $B$NMWAG?t$,B?$/$J$C$?$H$-$K;HMQ$9$k%D%j!<!#(B
.emacs $B$K(B
        (setq skk-rom-kana-rule-tree
              (skk-compile-rule-list skk-rom-kana-rule-list))
$B$rDI2C$9$k(B.

$B$3$N$^$^$G$O(B SKK $B$r5/F0$9$k$H$-$KKh2s(B \"skk-compile-rule-list\" $B$r7W;;$9(B
$B$k$3$H$K$J$k$N$G(B, $B$&$^$/$$$/$3$H$,$o$+$l$P(B,
        (skk-compile-rule-list skk-rom-kana-rule-list)
$B$NCM$rD>@\(B .emacs $B$K=q$$$F$*$/$H$h$$!#(B")

(defvar skk-standard-rom-kana-rule-tree nil "\
*skk-standard-rom-kana-rule-list $B$NMWAG?t$,B?$/$J$C$?$H$-$K;HMQ$9$k%D%j!<!#(B
.emacs $B$K(B
        (setq skk-standard-rom-kana-rule-tree
              (skk-compile-rule-list skk-standard-rom-kana-rule-list))
$B$rDI2C$9$k(B.

$B$3$N$^$^$G$O(B SKK $B$r5/F0$9$k$H$-$KKh2s(B \"skk-compile-rule-list\" $B$r7W;;$9(B
$B$k$3$H$K$J$k$N$G(B, $B$&$^$/$$$/$3$H$,$o$+$l$P(B,
        (skk-compile-rule-list skk-standard-rom-kana-rule-list)
$B$NCM$rD>@\(B .emacs $B$K=q$$$F$*$/$H$h$$!#(B")

(autoload 'skk-assoc-tree "skk-tree" nil nil nil)

;;;***

;;;### (autoloads (skk-vip-mode) "skk-vip" "skk/skk-vip.el")

(autoload 'skk-vip-mode "skk-vip" nil nil nil)

;;;***

;;;### (autoloads nil "skk-viper" "skk/skk-viper.el")

(defvar skk-viper-normalize-map-function nil "\
Viper $B$,(B minor-mode-map-alist $B$rD4@0$9$k$?$a$N4X?t!#(B")

;;;***
(provide 'skk-vars)
