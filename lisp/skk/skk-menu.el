;;; skk-menu.el --- SKK Menul related functions.
;; Copyright (C) 1996, 1997 Mikio Nakajima <minakaji@osaka.email.ne.jp>

;; Author: Mikio Nakajima <minakaji@osaka.email.ne.jp>
;; Version: $Id: skk-menu.el,v 1.1 1997/12/02 08:48:38 steve Exp $
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

;; Following people contributed modifications to skk.el (Alphabetical order):

;;; Change log:
;;; derived from skk.el 9.6.

;;; Code:
(require 'skk-foreword)
(require 'skk-vars)

(defvar skk-menu-annotation-buffer "*SKK Menu Annotation*"
  "SKK $B%a%K%e!<$N$?$a$NCp<a$rI=<($9$k%P%C%U%!!#(B" )

(defun skk-menu-setup-annotation-buffer (annotation)
  ;; skk-menu-annotation-buffer $B$r:n$j!"(BANNOTATION $B$rI=<($9$k!#(B
  (if (and annotation (not (string= annotation "")))
      (save-current-buffer
        (delete-other-windows)
        (switch-to-buffer (get-buffer-create skk-menu-annotation-buffer))
        (delete-region (point-min) (point-max))
        (insert annotation)
        (goto-char (point-min)) )))

(defun skk-menu-change-user-option (var on-alist off-alist)
  ;; VAR $B$N%I%-%e%a%s%H$rI=<($7$F%f!<%6!<$N;X<($K=>$$$=$NCM$K(B non-nil/nil $B$rBe(B
  ;; $BF~$9$k!#(B
  ;; ON-ALIST $B$K$O!"%*%W%7%g%s(B VAR $B$NCM$r(B non-nil $B$K$9$k$H$-$K@_Dj$9$kJQ?t$r!"(B
  ;; OFF-ALIST $B$O(B VAR $B$NCM$r(B nil $B$K$9$k>l9g$N@_Dj$r(B
  ;;   '(($BJQ?tL>(B0 . $BCM(B0) ($BJQ?tL>(B1 . $BCM(B1) ... ($BJQ?tL>(Bn . $BCM(Bn))
  ;; $B$N7A$GO"A[%j%9%H$G;XDj$9$k!#(BON-ALIST, OFF-ALIST $B$K$O(B VAR $B<+?H$N@_Dj$b;XDj(B
  ;; $B$9$kI,MW$,$"$k!#(B
  (let (
        ;; $B%@%$%"%m%0%\%C%/%9$,%U%l!<%`$NCf1{$K=P$F(B annotation $B%P%C%U%!$,FI$a(B
        ;; $B$J$$$N$G!"%@%$%"%m%0%\%C%/%9$r=P$5$J$$$h$&$K$9$k!#(B
        (last-nonmenu-event t)
        (on (symbol-value var))
        answer )
    (save-window-excursion
      (skk-menu-setup-annotation-buffer
       (concat (format "$B8=:_$N(B %S $B$NCM$O!"(B%S $B$G$9!#(B\n\n" var on)
               (documentation-property var 'variable-documentation) ))
      ;; y-or-n-p $B$G$bNI$$$N$@$,!"(By-or-n-p $B$O%_%K%P%C%U%!$rMxMQ$7$F$$$F%_%K%P%C(B
      ;; $B%U%!$r;H$C$F$J$$$N$G!"(Bannotation buffer $B$K%+!<%=%k$r0\$7!"J8;zNs$r%3(B
      ;; $B%T!<$7$?$j$G$-$J$/$J$C$F$7$^$&!#(B
      (setq answer (yes-or-no-p (format
                                 (if skk-japanese-message-and-error
                                     "$B$3$N%*%W%7%g%s$r(B %S $B$K$7$^$9$+!)(B"
                                   "Turn %S this option?" )
                                 (if on "off" "on") )))
      (if answer
          (if on
              ;; turn off
              (skk-menu-change-user-option-1 off-alist)
            ;; turn on
            (skk-menu-change-user-option-1 on-alist) )))))

(defun skk-menu-change-user-option-1 (alist)
  ;; ALIST $B$r(B skk-menu-modified-user-option $B$N:G8eJ}$KO"7k$7!"(BALIST $B$NCM$NMWAG(B
  ;; $B$N(B car $B$K(B cdr $B$NCM$rBeF~$9$k!#(B
  (let ((n 0)
        cell modified )
    (while (setq cell (nth n alist))
      (setq n (1+ n)
            modified (assq (car cell) skk-menu-modified-user-option) )
      (if modified
          (setq skk-menu-modified-user-option
                ;; $B4{$KF1$8JQ?t$r%b%G%#%U%!%$$7$F$$$?$i!"8E$$$b$N$r:o=|$9$k!#(B
                (delq modified skk-menu-modified-user-option) ))
      (set (car cell) (cdr cell)) )
    (setq skk-menu-modified-user-option
          (nconc skk-menu-modified-user-option alist) )))

;;;###skk-autoload
(defun skk-menu-save-modified-user-option ()
  ;; SKK $B$N%a%K%e!<$GJQ99$5$l$?%f!<%6!<%*%W%7%g%s$r(B skk-init-file $B$NKvHx$KJ]B8(B
  ;; $B$9$k!#(B
  (if (and
       skk-menu-modified-user-option
       (skk-yes-or-no-p
        "SKK $B%*%W%7%g%s$,5/F08eJQ99$5$l$F$$$^$9!#$3$NCM$rJ]B8$7$^$9$+!)(B"
        "Changed user options after SKK invoked.  Save the variables?" ))
      (progn
        (skk-menu-save-modified-user-option-1)
        (skk-message
         "SKK $B$N%*%W%7%g%s@_Dj$r(B %s $B$KJ]B8$7$^$7$?(B"
         "Save user options of SKK in %s"
         skk-init-file )
        (sit-for 1) )))

(defun skk-menu-save-modified-user-option-1 ()
  ;; skk-menu-save-modified-user-option-1 $B$N%5%V%k!<%A%s!#(B~/.skk $B$K(B
  ;; skk-menu-modified-user-option $B$NCM$r=q$-9~$_<!$K(B skk.el $B$,5/F0$5$l$?$H$-(B
  ;; $B$G$bJQ99$5$l$?CM$rM-8z$K$9$k!#(B
  ;; $B2a5n$K4{$K$3$N4X?t$K$h$j<0$,=q$-9~$^$l$F$$$?$i!"4{DjCM$H$ND4@0$b9T$J$&!#(B
  (save-match-data
    (with-current-buffer (find-file-noselect (expand-file-name skk-init-file))
      (let (
            ;; $B%G%3%l!<%7%g%s$J$7!#(B
            (hilit-auto-highlight-maxout 0)
            (font-lock-maximum-size 0)
            (require-final-newline t)
            buffer-read-only
            start first-kiss cell )
        (goto-char (point-min))
        (setq first-kiss
              (not
               (re-search-forward
                "^;; $B2<5-$N<0$O(B SKK $B$K$h$C$F<+F0E*$K=q$-9~$^$l$?$b$N$G$9!#(B$"
                nil t )))
        (if first-kiss
            (progn
              (setq start (goto-char (point-max)))
              (insert
               ";; $B2<5-$N<0$O(B SKK $B$K$h$C$F<+F0E*$K=q$-9~$^$l$?$b$N$G$9!#(B\n"
               ))
          (let ((alist skk-menu-modified-user-option)
                var)
            (setq start (point))
            (re-search-forward
             "^;; $B>e5-$N<0$O(B SKK $B$K$h$C$F<+F0E*$K=q$-9~$^$l$?$b$N$G$9!#(B$"
             nil )
            (while (setq var (car (car alist)))
              (skk-save-point
                (and (re-search-backward (prin1-to-string var) start t)
                     (delete-region (progn (beginning-of-line) (point))
                                    (progn (forward-line 1) (point)) )))
              (setq alist (cdr alist)) )
            (beginning-of-line) ))
        ;; $B$5$F!"$3$3$+$i$O6&DL$N=hM}$G$9!#(B
        (while skk-menu-modified-user-option
          (setq cell (car skk-menu-modified-user-option)
                skk-menu-modified-user-option
                (cdr skk-menu-modified-user-option) )
          (insert "(setq " (prin1-to-string (car cell)) " "
                  (prin1-to-string (cdr cell)) ")\n" ))
        ;;(delete-char -1)
        (if first-kiss
            (insert
             ";; $B>e5-$N<0$O(B SKK $B$K$h$C$F<+F0E*$K=q$-9~$^$l$?$b$N$G$9!#(B\n"
             ))
        (save-buffer)
        (kill-buffer (current-buffer)) ))))

;;;###skk-autoload
(defun skk-menu-process-okuri-early ()
  "skk-process-okuri-early $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B
$BN>N)$G$-$J$$%*%W%7%g%s$NCM$rD4@0$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-process-okuri-early
   ;; on-alist
   '((skk-process-okuri-early . t)
     (skk-auto-okuri-process . nil)
     (skk-henkan-okuri-strictly . nil)
     (skk-henkan-strict-okuri-precedence . nil)
     (skk-kakutei-early . nil) )
   ;; off-alist
   '((skk-process-okuri-early . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-henkan-okuri-strictly ()
  "skk-henkan-okuri-strictly $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B
$BN>N)$G$-$J$$%*%W%7%g%s$NCM$rD4@0$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-henkan-okuri-strictly
   ;; on-alist
   '((skk-henkan-okuri-strictly . t)
     (skk-process-okuri-early . nil) )
   ;; off-alist
   '((skk-henkan-okuri-strictly . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-henkan-strict-okuri-precedence ()
  "skk-henkan-strict-okuri-precedence $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B
$BN>N)$G$-$J$$%*%W%7%g%s$NCM$rD4@0$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-henkan-strict-okuri-precedence
   ;; on-alist
   '((skk-henkan-strict-okuri-precedence . t)
     (skk-henkan-okuri-strictly . nil)
     (skk-process-okuri-early . nil) )
   ;; off-alist
   '((skk-henkan-strict-okuri-precedence . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-auto-okuri-process ()
  "skk-auto-okuri-process $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B
$BN>N)$G$-$J$$%*%W%7%g%s$NCM$rD4@0$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-auto-okuri-process
   ;; on-alist
   '((skk-auto-okuri-process . t)
     (skk-process-okuri-early . nil) )
   ;; off-alist
   '((skk-auto-okuri-process . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-kakutei-early ()
  "skk-kakutei-early $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B
$BN>N)$G$-$J$$%*%W%7%g%s$NCM$rD4@0$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-kakutei-early
   ;; on-alist
   '((skk-kakutei-early . t)
     (skk-process-okuri-early . nil) )
   ;; off-alist
   '((skk-kakutei-early . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-egg-like-newline ()
  "skk-egg-like-newline $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-egg-like-newline
   '((skk-egg-like-newline . t))
   '((skk-egg-like-newline . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-delete-implies-kakutei ()
  "skk-delete-implies-kakutei $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-delete-implies-kakutei
   '((skk-delete-implies-kakutei . t))
   '((skk-delete-implies-kakutei . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-allow-spaces-newlines-and-tabs ()
  "skk-allow-spaces-newlines-and-tabs $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-allow-spaces-newlines-and-tabs
   '((skk-allow-spaces-newlines-and-tabs . t))
   '((skk-allow-spaces-newlines-and-tabs . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-convert-okurigana-into-katakana ()
  "skk-convert-okurigana-into-katakana $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-convert-okurigana-into-katakana
   '((skk-convert-okurigana-into-katakana . t))
   '((skk-convert-okurigana-into-katakana . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-delete-okuri-when-quit ()
  "skk-delete-okuri-when-quit $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-delete-okuri-when-quit
   '((skk-delete-okuri-when-quit . t))
   '((skk-delete-okuri-when-quit . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-echo ()
  "skk-echo $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-echo
   '((skk-echo . t))
   '((skk-echo . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-use-numeric-conversion ()
  "skk-use-numeric-conversion $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-use-numeric-conversion
   '((skk-use-numeric-conversion . t))
   '((skk-use-numeric-conversion . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-use-overlay ()
  "skk-use-face $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-use-face
   '((skk-use-face . t))
   '((skk-use-face . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-auto-insert-paren ()
  "skk-auto-insert-paren $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-auto-insert-paren
   '((skk-auto-insert-paren . t))
   '((skk-auto-insert-paren . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-japanese-message-and-error ()
  "skk-japanese-message-and-error $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-japanese-message-and-error
   '((skk-japanese-message-and-error . t))
   '((skk-japanese-message-and-error . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
;;(defun skk-menu-byte-compile-init-file ()
;;  "skk-byte-compile-init-file $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
;;  (interactive)
;;  (skk-menu-change-user-option
;;   'skk-byte-compile-init-file
;;   '((skk-byte-compile-init-file . t))
;;   '((skk-byte-compile-init-file . nil)) )
;;  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-count-private-jisyo-entries-exactly ()
  "skk-count-private-jisyo-candidates-exactly $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-count-private-jisyo-candidates-exactly
   '((skk-count-private-jisyo-candidates-exactly . t))
   '((skk-count-private-jisyo-candidates-exactly . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-auto-henkan ()
  "skk-auto-start-henkan $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-auto-start-henkan
   '((skk-auto-start-henkan . t)
     (skk-auto-okuri-process . t) )
   '((skk-auto-start-henkan . nil)) )
  (skk-set-cursor-properly) )

;; for skk-comp.el
;;;###skk-autoload
(defun skk-menu-dabbrev-like-completion ()
  "skk-dabbrev-like-completion $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (require 'skk-comp)
  (skk-menu-change-user-option
   'skk-dabbrev-like-completion
   '((skk-dabbrev-like-completion . t))
   '((skk-dabbrev-like-completion . nil)) )
  (skk-set-cursor-properly) )

;; for skk-gadget.el
;;;###skk-autoload
(defun skk-menu-date-ad ()
  "skk-date-ad $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (require 'skk-gadget)
  (skk-menu-change-user-option
   'skk-date-ad
   '((skk-date-ad . t))
   '((skk-date-ad . nil)) )
  (skk-set-cursor-properly) )

;; for skk-kakasi.el
;;;###skk-autoload
(defun skk-menu-romaji-*-by-hepburn ()
  "skk-romaji-*-by-hepburn $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (require 'skk-kakasi)
  (skk-menu-change-user-option
   'skk-romaji-*-by-hepburn
   '((skk-romaji-*-by-hepburn . t))
   '((skk-romaji-*-by-hepburn . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-use-kakasi ()
  "skk-use-kakasi $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (require 'skk-kakasi)
  (skk-menu-change-user-option
   'skk-use-kakasi
   '((skk-use-kakasi . t))
   '((skk-use-kakasi . nil)) )
  (skk-set-cursor-properly) )

;; for skk-num.el
;;;###skk-autoload
(defun skk-menu-numeric-conversion-float-num ()
  "skk-numeric-conversion-float-num $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (require 'skk-num)
  (skk-menu-change-user-option
   'skk-numeric-conversion-float-num
   '((skk-numeric-conversion-float-num . t))
   '((skk-numeric-conversion-float-num . nil)) )
  (skk-set-cursor-properly) )

;; for skk-server.el
;;;###skk-autoload
(defun skk-menu-report-server-response ()
  "skk-report-server-response $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (require 'skk-server)
  (skk-menu-change-user-option
   'skk-report-server-response
   '((skk-report-server-response . t))
   '((skk-report-server-response . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-server-debug ()
  "skk-server-debug $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (require 'skk-server)
  (skk-menu-change-user-option
   'skk-server-debug
   '((skk-server-debug . t))
   '((skk-server-debug . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-compare-jisyo-size-when-saving ()
  "skk-compare-jisyo-size-when-saving $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-compare-jisyo-size-when-saving
   '((skk-compare-jisyo-size-when-saving . t))
   '((skk-compare-jisyo-size-when-saving . nil)) )
  (skk-set-cursor-properly) )

;;;###skk-autoload
(defun skk-menu-use-color-cursor ()
  "skk-use-color-cursor $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-use-color-cursor
   '((skk-use-color-cursor . t))
   '((skk-use-color-cursor . nil)) )
  (skk-set-cursor-properly) )

(defun skk-menu-uniq-numerals ()
  "skk-uniq-numerals $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
  (interactive)
  (skk-menu-change-user-option
   'skk-uniq-numerals
   '((skk-uniq-numerals . t))
   '((skk-uniq-numerals . nil)) ))

;;(defun skk-menu- ()
;;  "skk- $B$r%9%$%C%A%*%s(B/$B%*%U$9$k!#(B"
;;  (interactive)
;;  (skk-menu-change-user-option
;;   'skk-
;;   '((skk- . t))
;;   '((skk- . nil)) ))

;;; skk-menu.el ends here
