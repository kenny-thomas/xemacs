;;; skk-server.el --- SKK $B%5!<%P!<$N$?$a$N%W%m%0%i%`(B
;; Copyright (C) 1988, 1989, 1990, 1991, 1992, 1993, 1994, 1995, 1996, 1997
;; Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>

;; Author: Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>
;; Maintainer: Mikio Nakajima <minakaji@osaka.email.ne.jp>
;; Version: $Id: skk-server.el,v 1.1 1997/12/02 08:48:39 steve Exp $
;; Keywords: japanese
;; Last Modified: $Date: 1997/12/02 08:48:39 $

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
;; Following people contributed modifications to skk-server.el (Alphabetical
;; order):
;;
;;      Hitoshi SUZUKI <h-suzuki@ael.fujitsu.co.jp>
;;      Hideki Sakurada <sakurada@kuis.kyoto-u.ac.jp>
;;      Kenji Rikitake <kenji@reseau.toyonaka.osaka.jp>
;;      Kiyotaka Sakai <ksakai@netwk.ntt-at.co.jp>
;;      Mikio Nakajima <minakaji@osaka.email.ne.jp>
;;      TOKUYA Junichi <tokuya@crab.fuji-ric.co.jp>

;;; Change log:


;;; Code:
(require 'skk-foreword)
(require 'skk-vars)

;; user variables.
;;;###skk-autoload
(defvar skk-server-host (getenv "SKKSERVER")
  "*SKK $B<-=q%5!<%P!<$rAv$i$;$F$$$k%[%9%HL>!#(B" )

;;;###skk-autoload
(defvar skk-server-prog (getenv "SKKSERV")
  "*SKK $B<-=q%5!<%P!<%W%m%0%i%`L>!#%U%k%Q%9$G=q$/!#(B" )

(defvar skk-server-jisyo (getenv "SKK_JISYO")
  "*SKK $B<-=q%5!<%P!<%W%m%0%i%`$KEO$9<-=qL>!#%U%k%Q%9$G=q$/!#(B" )

(defvar skk-server-portnum nil
  "*Non-nil $B$G$"$l$P!"$=$NCM$r(B port number $B$H$7$F(B skkserv $B$H(B TCP $B@\B3$9$k!#(B
/etc/services $B$rD>@\=q$-49$($k8"8B$,$J$$%f!<%6!<$N$?$a$NJQ?t!#(B" )

;;(defvar skk-server-debug nil
;;  "*Non-nil $B$G$"$l$P!"<-=q%5!<%P!<%W%m%0%i%`$r%G%#%P%C%0%b!<%I$G5/F0$9$k!#(B
;;$B%G%#%P%C%0!&%b!<%I$G(B skkserv $B$rAv$i$;$k$H!"$=$N$^$^(B foreground $B$GAv$j!"%a%C%;!<(B
;;$B%8$r=PNO$9$k!#%-!<%\!<%I$+$i3d$j$3$_$r$+$1$k$3$H$b$G$-$k!#(B" )

;;;###skk-autoload
(defvar skk-servers-list nil
  "*$B<-=q%5!<%P!<Kh$N>pJs%j%9%H!#(B
$BJ#?t$N%^%7!<%s$GF0$$$F$$$k%5!<%P$K%"%/%;%9$G$-$k>l9g$K$O!"0J2<$N$h$&$K!"%j%9%H(B
$B$N3FMWAG$K=g$K%[%9%HL>!"%U%k%Q%9$G$N(B SKK $B%5!<%P!<L>!"(BSKK $B%5!<%P!<$KEO$9<-=qL>!"(B
SKK $B%5!<%P!<$,;HMQ$9$k%]!<%HHV9f$r=q$-!"@_Dj$r$9$k$3$H$b$G$-$k!#(B

   (setq skk-servers-list
         '((\"mars\" \"/usr/local/soft/nemacs/etc/skkserv\" nil nil)
           (\"venus\" \"/usr/local/nemacs/etc/skkserv\" nil nil) ))

$B$3$N>l9g:G=i$K;XDj$7$?%5!<%P$K%"%/%;%9$G$-$J$/$J$k$H!"<+F0E*$K=g<!%j%9%H$K$"$k(B
$B;D$j$N%5!<%P$K%"%/%;%9$9$k$h$&$K$J$k!#$J$*(B SKK $B%5!<%P!<$KEO$9<-=q$*$h$S(B SKK $B%5!<(B
$B%P!<$,;HMQ$9$k%]!<%HHV9f$G!"(BSKK $B%5!<%P!<$r%3%s%Q%$%k;~$NCM$r;HMQ$9$k>l9g$O(B nil 
$B$r;XDj$9$k!#(B" )

(defvar skk-report-server-response nil
  "*Non-nil $B$G$"$l$P!"JQ49;~(B SKK $B%5!<%P!<$NAw=P$9$kJ8;z$r<u$1<h$k$^$G$K(B accept-process-output $B$r2?2s<B9T$7$?$+$rJs9p$9$k!#(B" )

(defvar skk-remote-shell-program
  (or (getenv "REMOTESHELL")
      (and (boundp 'remote-shell-program) remote-shell-program)
      (cond
       ((eq system-type 'berkeley-unix)
        (if (file-exists-p "/usr/ucb/rsh") "/usr/ucb/rsh" "/usr/bin/rsh") )
       ((eq system-type 'usg-unix-v)
        (if (file-exists-p "/usr/ucb/remsh") "/usr/ucb/remsh" "/bin/rsh"))
       ((eq system-type 'hpux) "/usr/bin/remsh")
       ((eq system-type 'EWS-UX/V) "/usr/ucb/remsh")
       ((eq system-type 'pcux) "/usr/bin/rcmd")
       (t "rsh") ))
  "*$B%j%b!<%H%7%'%k$N%W%m%0%i%`L>!#(B" )

(defvar skk-server-load-hook nil
  "*skk-server.el $B$r%m!<%I$7$?8e$K%3!<%k$5$l$k%U%C%/!#(B" )

;; internal variable.
(defvar skk-network-open-status 'open
  "" )

;;;###skk-autoload
(defun skk-server-version ()
  (interactive)
  (if (interactive-p)
      (message (skk-server-version))
    (let (status)
      (if (not (or skk-server-host skk-servers-list))
          (skk-error "Lack of host information of SKK server"
                     "SKK $B%5!<%P!<$N%[%9%H>pJs$,$"$j$^$;$s(B" ))
      (setq status (process-status "skkservd"))
      (if (not (eq status skk-network-open-status))
          (setq status (skk-open-server)) )
      (if (eq status skk-network-open-status)
          (let (v)
            (save-match-data
              (with-current-buffer " *skkserv*"
                (erase-buffer)
                ;; $B%5!<%P!<%P!<%8%g%s$rF@$k!#(B
                (process-send-string "skkservd" "2")
                (while (eq (buffer-size) 0)
                  (accept-process-output) )
                (setq v (buffer-string))
                (erase-buffer)
                ;; $B%[%9%HL>$rF@$k!#(B
                (process-send-string "skkservd" "3")
                (while (eq (buffer-size) 0)
                  (accept-process-output) )                  
                (goto-char (point-min))
                (format
                 (concat "SKK SERVER version %s"
                         (if skk-japanese-message-and-error
                             "($B%[%9%HL>(B %s)"
                           "running on HOST %s" ))
                 v (prog1 (buffer-string) (erase-buffer)) ))))))))

(defun skk-search-server (file limit &optional nomsg)
  ;; SKK $B<-=q%U%)!<%^%C%H$N(B FILE $B$G(B SKK $B%5!<%P!<$r;HMQ$7$F(B skk-henkan-key $B$r%-!<(B
  ;; $B$K$7$F8!:w$r9T$&!#(B
  ;; SKK $B%5!<%P!<$,;HMQ$G$-$J$$$H$-$O!"(BFILE $B$r%P%C%U%!$KFI$_9~$s$G%5!<%A$r9T(B
  ;; $B$&!#(B
  ;; LIMIT $B$H(B NOMSG $B$O(B SKK $B%5!<%P!<$r;HMQ$7$J$$$H$-$N$_;H$&!#(B
  ;; $B8!:w%j!<%8%g%s$,(B LIMIT $B0J2<$K$J$k$^$G%P%$%J%j%5!<%A$r9T$$!"$=$N8e%j%K%"(B
  ;; $B%5!<%A$r9T$&!#(B
  ;; LIMIT $B$,(B 0 $B$G$"$l$P!"%j%K%"%5!<%A$N$_$r9T$&!#(B
  ;; $B<-=q$,%=!<%H$5$l$F$$$J$$$N$G$"$l$P!"(BLIMIT $B$r(B 0 $B$9$kI,MW$,$"$k!#(B
  ;; $B%*%W%7%g%J%k0z?t$N(B NOMSG $B$,(B non-nil $B$G$"$l$P(B skk-get-jisyo-buffer $B$N%a%C(B
  ;; $B%;!<%8$r=PNO$7$J$$$h$&$K$9$k!#(B
  (if (or skk-server-host skk-servers-list)
      (skk-search-server-subr file limit)
    (skk-search-jisyo-file file limit nomsg) ))

(defun skk-search-server-subr (file limit)
  ;; skk-search-server $B$N%5%V%k!<%A%s!#(B
  (let ((key
	 (if skk-use-numeric-conversion
	     (skk-compute-numeric-henkan-key skk-henkan-key)
	   skk-henkan-key))
        ;; $B%P%C%U%!%m!<%+%kCM$N<u$1EO$7$N$?$a!"JLL>$N0l;~JQ?t$K<h$k!#(B
        (okurigana (or skk-henkan-okurigana skk-okuri-char))
        (status (process-status "skkservd")) )
    (if (or (not status) (not (eq status skk-network-open-status)))
        (setq status (skk-open-server)) )
    (if (eq status skk-network-open-status)
        (with-current-buffer " *skkserv*"
          (let ((cont t) (count 0)
                l )
            (erase-buffer)
            (process-send-string "skkservd" (concat "1" key " "))
            (while (and cont (eq (process-status "skkservd")
                                 skk-network-open-status ))
              (accept-process-output)
              (setq count (1+ count))
              (if (> (buffer-size) 0)
                  (if (eq  (char-after 1) ?1) ;?1
                      ;; found key successfully, so check if a whole line
                      ;; is received.
                      (if (eq (char-after (1- (point-max))) ?\n) ;?\n
                          (setq cont nil) )
                    ;; not found or error, so exit
                    (setq cont nil) )))
            (goto-char (point-min))
            (if skk-report-server-response
                (skk-message "%d $B2s(B SKK $B%5!<%P!<$N1~EzBT$A$r$7$^$7$?(B"
                             "Waited for server response %d times" count ))
            (if (eq (following-char) ?1) ;?1
                (progn
                  (forward-char 2)
                  (setq l (skk-compute-henkan-lists okurigana))
                  (if l
                      (cond ((and okurigana skk-henkan-okuri-strictly)
			     ;; $BAw$j2>L>$,F10l$N%(%s%H%j$N$_$rJV$9!#(B
			     (nth 2 l) )
			    ((and okurigana skk-henkan-strict-okuri-precedence)
			     (skk-nunion (nth 2 l) (car l)) )
			    (t (car l)) ))))))
      ;; server is not active, so search file instead
      (skk-search-jisyo-file file limit) )))

(defun skk-open-server ()
  ;; SKK $B%5!<%P!<$H@\B3$9$k!#%5!<%P!<%W%m%;%9$N(B status $B$rJV$9!#(B
  (let (status code)
    (if (or (skk-open-network-stream) (skk-open-server-1))
        (progn
          (setq status (process-status "skkservd"))
          (if (eq status skk-network-open-status)
              (progn
                (setq code (cdr (assoc "euc" skk-coding-system-alist)))
		(if skk-xemacs
		    (let ((proc (get-process "skkservd")))
		      (set-process-input-coding-system proc code)
		      (set-process-output-coding-system proc code))
		  (if skk-mule
		      (set-process-coding-system (get-process "skkservd")
						 code code )))))))
    status ))

(defun skk-open-server-1 ()
  ;; skk-open-server $B$N%5%V%k!<%A%s!#(B
  ;; skkserv $B%5!<%S%9$r%*!<%W%s$G$-$?$i(B t $B$rJV$9!#(B
  (let (status)
    (if (null skk-servers-list)
        (progn
          ;; Emacs $B5/F08e$K4D6-JQ?t$r@_Dj$7$?>l9g!#(B
          (if (not skk-server-host)
              (setq skk-server-host (getenv "SKKSERVER")) )
          (if (not skk-server-prog)
              (setq skk-server-prog (getenv "SKKSERV")) )
          (if (not skk-server-jisyo)
              (setq skk-server-jisyo (getenv "SKK_JISYO")) )
          (if (and skk-server-host skk-server-prog
                   ;; skkserv $B$O0z?t$K<-=q$,;XDj$5$l$F$$$J$1$l$P!"(B
                   ;; DEFAULT_JISYO $B$r;2>H$9$k!#(B
                   ;;skk-server-jisyo
                   )
              (setq skk-servers-list (list (list skk-server-host
                                                 skk-server-prog
                                                 skk-server-jisyo
                                                 skk-server-portnum )))
            ;; reset SKK-SERVER-HOST so as not to use server in this session
            (setq skk-server-host nil
                  skk-server-prog nil ))))
    (while (and (not (eq (process-status "skkservd") skk-network-open-status))
                skk-servers-list )
      (let ((elt (car skk-servers-list))
            arg )
        (setq skk-server-host (car elt)
              skk-server-prog (nth 1 elt)
              skk-server-jisyo (nth 2 elt)
              skk-server-portnum (nth 3 elt)
              skk-servers-list (cdr skk-servers-list) )
        ;; skkserv $B$N5/F0%*%W%7%g%s$O2<5-$NDL$j!#(B
        ;;     skkserv [-d] [-p NNNN] [JISHO]
        ;;     `-d'     $B%G%#%P%C%0!&%b!<%I(B
        ;;     `-p NNNN'     $BDL?.MQ$N%]!<%HHV9f$H$7$F(BNNNN$B$r;H$&(B.
        ;;     `~/JISYO'     ~/JISYO$B$r<-=q$H$7$FMxMQ(B.
        (if skk-server-jisyo
            (setq arg (list skk-server-jisyo))
          ;; skkserv $B$O0z?t$K<-=q$,;XDj$5$l$F$$$J$1$l$P!"(BDEFAULT_JISYO $B$r(B
          ;; $B;2>H$9$k!#(B
          )
        ;;(if skk-server-debug
        ;;    (setq arg (cons "-d" arg)) )
	(if (and skk-server-portnum (not (eq skk-server-portnum 1178)))
	    (setq arg
		  (nconc (list "-p" (int-to-string skk-server-portnum)) arg)))
        (or (skk-open-network-stream)
            (skk-startup-server arg) )))
    (if (not (eq (process-status "skkservd") skk-network-open-status))
        ;; reset SKK-SERVER-HOST so as not to use server in this session
        (setq skk-server-host nil
              skk-server-prog nil
              skk-servers-list nil )
      t )))

(defun skk-open-network-stream ()
  ;; skk-server-host $B$K$*$1$k(B skkserv $B%5!<%S%9$N(B TCP $B@\B3$r%*!<%W%s$7!"%W%m%;(B
  ;; $B%9$rJV$9!#(B
  ;; open-network-stream $B$GB8:_$7$J$$%P%C%U%!$,;XDj$5$l$?$i!"(Bget-buffer-create
  ;; $B$7$F$/$F$k$N$G!"ITMW!#(B
  ;;(get-buffer-create " *skkserv*")
  (condition-case nil
      (open-network-stream
       "skkservd" " *skkserv*" skk-server-host (or skk-server-portnum "skkserv"))
    (error nil) ))

(defun skk-startup-server (arg)
  ;; skkserv $B$r5/F0$G$-$?$i(B t $B$rJV$9!#(B
  (let (
        ;;(msgbuff (get-buffer-create " *skkserv-msg*"))
        (count 7) status )
    (while (> count 0)
      (skk-message
       "%s $B$N(B SKK $B%5!<%P!<$,5/F0$7$F$$$^$;$s!#5/F0$7$^$9(B%s"
       "SKK SERVER on %s is not active, I will activate it%s"
       skk-server-host (make-string count ?.) )
      (if (or (string= skk-server-host (system-name))
              (string= skk-server-host "localhost"))
          ;; server host is local machine
          (apply 'call-process skk-server-prog nil
                 ;;msgbuff
                 0 nil arg)
        (apply 'call-process
               skk-remote-shell-program nil
               ;; 0 $B$K$7$F%5%V%W%m%;%9$N=*N;$rBT$C$F$O$$$1$J$$M}M3$,$"$k!)(B
               ;; $B$J$1$l$P(B msgbuf $B$K%(%i!<=PNO$r<h$C$?J}$,7z@_E*$G$O!)(B  $B$^$?$=(B
               ;; $B$N>l9g$O$3$N(B while $B%k!<%W<+?H$,$$$i$J$$!)(B
               ;; msgbuff
               0 nil skk-server-host skk-server-prog arg ))
      (sit-for 3)
      (if (and (skk-open-network-stream)
               (eq (process-status "skkservd") skk-network-open-status) )
          (setq count 0)
        (setq count (1- count)) ))
    (if (eq (process-status "skkservd") skk-network-open-status)
        (progn
          (skk-message "$B%[%9%H(B %s $B$N(B SKK $B%5!<%P!<$,5/F0$7$^$7$?(B"
                       "SKK SERVER on %s is active now"
                       skk-server-host )
          (sit-for 1) ; return t
          t ) ; $B$G$bG0$N$?$a(B
      (skk-message "%s $B$N(B SKK $B%5!<%P!<$r5/F0$9$k$3$H$,$G$-$^$;$s$G$7$?(B"
                   "Could not activate SKK SERVER on %s"
                   skk-server-host )
      (sit-for 1)
      (ding) ;return nil
      nil ))) ; $B$G$bG0$N$?$a(B

;;;###skk-autoload
(defun skk-adjust-search-prog-list-for-server-search (&optional non-del)
  ;; skk-server-host $B$b$7$/$O(B skk-servers-list $B$,(B nil $B$G$"$l$P!"(B
  ;; skk-search-prog-list $B$+$i(B skk-search-server $B$r(B car $B$K;}$D%j%9%H$r>C$9!#(B
  ;; non-nil $B$G$"$l$P!"2C$($k!#(B
  (if (or skk-server-host skk-servers-list)
      (if (null (assq 'skk-search-server skk-search-prog-list))
          ;; skk-search-prog-list $B$,(B nil $B$H$$$&$3$H$O$^$:$J$$$@$m$&$,!"G0$N$?(B
          ;; $B$a!"(Bsetq $B$7$F$*$/!#(B          
          (setq skk-search-prog-list
                ;; $BKvHx$KIU$1$k!#KvHx$K$O(B (skk-okuri-search) $B$r;}$C$F$-$?$$?M(B
                ;; $B$b$$$k$+$b!#%*%W%7%g%s$GIU$1$k>l=j$rJQ99$9$k$h$&$K$7$?J}$,(B
                ;; $BNI$$!)(B
                (nconc skk-search-prog-list
                       (list
                        '(skk-search-server skk-aux-large-jisyo 10000) ))))
    (if (not non-del)
        ;; skk-search-prog-list $B$N@hF,$,(B skk-search-server $B$+$i;O$^$k%j%9%H$@(B
        ;; $B$H$$$&$3$H$O$^$:$J$$$@$m$&$,!"G0$N$?$a!"(Bsetq $B$7$F$*$/!#(B
        (setq skk-search-prog-list
              (delq (assq 'skk-search-server skk-search-prog-list)
                    skk-search-prog-list )))))

(defun skk-disconnect-server ()
  ;; $B%5!<%P!<$r@Z$jN%$9!#(B
  (if (and skk-server-host
           (eq (process-status "skkservd") skk-network-open-status) )
      (progn
        (process-send-string "skkservd" "0") ; disconnect server
        (accept-process-output (get-process "skkservd")) )))

;;(add-hook 'skk-mode-hook 'skk-adjust-search-prog-list-for-server-search)
(add-hook 'skk-before-kill-emacs-hook 'skk-disconnect-server)

(run-hooks 'skk-server-load-hook)

(provide 'skk-server)
;;; skk-server.el ends here
