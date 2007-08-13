;; -*-byte-compile-dynamic: t;-*-
;;; skk-attr.el --- SKK $BC18lB0@-%a%s%F%J%s%9%W%m%0%i%`(B
;; Copyright (C) 1997 Mikio Nakajima <minakaji@osaka.email.ne.jp>

;; Author: Mikio Nakajima <minakaji@osaka.email.ne.jp>
;; Maintainer: Mikio Nakajima <minakaji@osaka.email.ne.jp>
;; Version: $Id: skk-attr.el,v 1.1 1997/12/02 08:48:37 steve Exp $
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

;; Following people contributed modifications to skk.el (Alphabetical order):

;;; Change log:

;;; Code:
(eval-when-compile (require 'skk))

;;;###skk-autoload
(defvar skk-attr-file (if (eq system-type 'ms-dos) "~/_skk-attr" "~/.skk-attr")
  "*SKK $B$NC18l$NB0@-$rJ]B8$9$k%U%!%$%k!#(B")

;;;###skk-autoload
(defvar skk-attr-backup-file
  (if (eq system-type 'ms-dos) "~/_skk-attr.BAK" "~/.skk-attr.BAK" )
  "*SKK $B$NC18l$NB0@-$rJ]B8$9$k%U%!%$%k!#(B")

;;;###skk-autoload
(defvar skk-attr-search-function nil
  "*skk-search-jisyo-file $B$,8uJd$r8+$D$1$?$H$-$K%3!<%k$5$l$k4X?t!#(B
$B8+=P$78l!"Aw$j2>L>!"%(%s%H%j!<$N(B 3 $B0z?t$rH<$J$C$F!"(B
skk-attr-default-update-function $B$,%3!<%k$5$l$?8e$K%3!<%k$5$l$k!#(B" )

;;;###skk-autoload
(defvar skk-attr-default-update-function
  (function (lambda (midasi okurigana word purge)
              (or skk-attr-alist (skk-attr-read))
              (if purge
                  (skk-attr-purge midasi okurigana word)
                ;; time $BB0@-$K(B current-time $B$NJV$jCM$rJ]B8$9$k!#(B                
                (skk-attr-put midasi okurigana word 'time (current-time)) )))
  "*skk-search-jisyo-file $B$,8uJd$r8+$D$1$?$H$-$K%3!<%k$5$l$k4X?t!#(B
$B8+=P$78l!"Aw$j2>L>!"%(%s%H%j!<$N(B 3 $B0z?t$rH<$J$C$F!"(B
skk-attr-default-update-function $B$,%3!<%k$5$l$kA0$K%3!<%k$5$l$k!#(B" )

;;;###skk-autoload
(defvar skk-attr-update-function nil
  "*skk-update-jisyo $B$NCf$G%3!<%k$5$l$k4X?t!#(B
$B8+=P$78l!"Aw$j2>L>!"%(%s%H%j!<!"%Q!<%8$N(B 4 $B0z?t$rH<$J$C$F%3!<%k$5$l$k!#(B" )

;;;###skk-autoload
(defvar skk-attr-alist nil
  "SKK $BB0@-$rE83+$9$k%(!<%j%9%H!#(B" )

;; data structure
;; $B$H$j$"$($:!"3FJQ49Kh$KB0@-$N99?7$r9T$J$$0W$$$h$&$K!"8+=P$78l$+$i3FB0@-$r0z(B
;; $B=P$70W$$$h$&$K$9$k!#$3$&$d$C$F$7$^$&$H!"$"$kB0@-$r;}$DC18l$rH4$-=P$9$N$,LL(B
;; $BE]$K$J$k$,!";_$`$rF@$J$$$+(B...$B!#(B
;;
;; $B9bB.2=$N$?$a$K(B 2 $B$D$N%O%C%7%e%-!<$r;}$D$h$&$K$9$k!#(B1 $B$D$O(B okuri-ari $B$+(B
;; okuri-nasi $B$+!#(B2 $B$D$a$O8+=P$78l$N@hF,$NJ8;z!#(B
;;
;; '((okuri-ari . (("$B$"(B" . ("$B$"(Bt" .
;;                          ("$BEv(B" . (okurigana . ("$B$?(B" "$B$F(B"))
;;                                  (time . (13321 10887 982100))
;;                                  (anything . ...) )
;;                          ("$B9g(B" . (okurigana . ("$B$C$F(B" "$B$C$?(B"))
;;                                  (time . (13321 10953 982323)
;;                                  (anything . ...) )
;;                          ("$B2q(B" . (okurigana . ("$B$C$F(B"))
;;                                  (time . (13321 10977 312335))
;;                                  (anything . ...) ))
;;                         ("$B$"$D$+(Bw" . ...) )
;;                 ("$B$$(B" . ...) )
;;   (okuri-nasi . (("$B$"(B" . ...) ("$B$$(B" . ...))) )
;; 
;; $B$7$+$7!"$3$&$$$&$b$N$r:n$k$H!"(B.skk-jisyo $B$H(B .skk-attr $B$NN>J}$r;}$D0UL#$,Gv(B
;; $B$l$F$7$^$&$s$@$h$M(B...$B!#>e<j$/F0$1$P(B .skk-attr $B$KE}9g$7$F$bNI$$$1$I!"<-=q$N(B
;; $B%a%s%F%J%s%9$,LLE]$K$J$k$+(B...$B!#(B

(defsubst skk-attr-get-table (okuri-ari)
  (assq (if okuri-ari 'okuri-ari 'okuri-nasi) skk-attr-alist) )

(defsubst skk-attr-get-table-for-midasi (midasi okurigana)
  ;; get all entries for MIDASI.
  ;; e.g.
  ;;  ("$B$"(Bt" . ("$BEv(B" . (okurigana . ("$B$?(B" "$B$F(B"))
  ;;                   (time . (13321 10887 982100))
  ;;                   (anything . ...) )
  ;;           ("$B9g(B" . (okurigana . ("$B$C$F(B" "$B$C$?(B"))
  ;;                   (time . (13321 10953 982323)
  ;;                   (anything . ...) )
  ;;           ("$B2q(B" . (okurigana . ("$B$C$F(B"))
  ;;                   (time . (13321 10977 312335))
  ;;                   (anything . ...) ))
  (assoc midasi (cdr (assoc (skk-substring-head-character midasi)
                            (cdr (skk-attr-get-table okurigana)) ))))

(defsubst skk-attr-get-table-for-word (midasi okurigana word)
  ;; get a table for WORD.
  ;; e.g.
  ;;  ("$BEv(B" . (okurigana . ("$B$?(B" "$B$F(B")) (time . (13321 10887 982100))
  ;;          (anything . ...) )
  (assoc word (cdr (skk-attr-get-table-for-midasi midasi okurigana))) )

(defsubst skk-attr-get-all-attrs (midasi okurigana word)
  ;; get all attributes for MIDASI and WORD.
  ;; e.g.
  ;; ((okurigana . "$B$?(B" "$B$F(B") (time . (13321 10887 982100)) (anything . ...))
  (cdr (skk-attr-get-table-for-word midasi okurigana word)) )

(defsubst skk-attr-get (midasi okurigana word name)
  (assq name (skk-attr-get-all-attrs midasi okurigana word)) )
  
(defun skk-attr-put (midasi okurigana word name attr)
  ;; add attribute ATTR for MIDASI, WORD and NAME.
  ;; e.g.
  ;; table := ("$B$"(Bt" . ("$BEv(B" . (okurigana . ("$B$?(B" "$B$F(B"))
  ;;                           (time . (13321 10887 982100))
  ;;                           (anything . ...) )
  ;;                   ("$B9g(B" . (okurigana . (("$B$C$F(B" "$B$C$?(B"))
  ;;                           (time . (13321 10953 982323))
  ;;                           (anything . ...) )
  ;;                   ("$B2q(B" . (okurigana . ("$B$C$F(B"))
  ;;                           (time . (13321 10977 312335))
  ;;                           (anything . ...) ))
  ;; entry := ("$BEv(B" . (okurigana . ("$B$?(B" "$B$F(B")) (time . (13321 10887 982100))
  ;;                  (anything . ...) )
  ;; oldattr := (time . (13321 10887 982100))
  ;;
  (let* ((table (skk-attr-get-table-for-midasi midasi okurigana))
         (entry (assoc word (cdr table)))
         (oldattr (assq name (cdr entry))) )
    (cond (oldattr
           (cond ((eq name 'okurigana) ; anything else?
                  (setcdr oldattr (cons attr (delete attr (nth 1 oldattr)))) )
                 (t (setcdr oldattr attr)) ))
          (entry (setcdr entry (cons (cons name attr) (cdr entry))))
          ;; new entry
          (t (skk-attr-put-1 midasi okurigana word name attr) ))))

(defun skk-attr-put-1 (midasi okurigana word name attr)
  ;; header := "$B$"(B"
  ;; table := ((okuri-ari . (("$B$"(B" . ("$B$"(Bt" .
  ;;                            ("$BEv(B" . (okurigana . ("$B$?(B" "$B$F(B"))
  ;;                                    (time . (13321 10887 982100))
  ;;                                    (anything . ...) )
  ;;                            ("$B9g(B" . (okurigana . ("$B$C$F(B" "$B$C$?(B"))
  ;;                                    (time . (13321 10953 982323))
  ;;                                    (anything . ...) )
  ;;                            ("$B2q(B" . (okurigana . ("$B$C$F(B"))
  ;;                                    (time . (13321 10977 312335))
  ;;                                    (anything . ...) )))
  ;; table2 := ("$B$"(B" . ("$B$"(Bt" .
  ;;                            ("$BEv(B" . (okurigana . ("$B$?(B" "$B$F(B"))
  ;;                                    (time . (13321 10887 982100))
  ;;                                    (anything . ...) )
  ;;                            ("$B9g(B" . (okurigana . ("$B$C$F(B" "$B$C$?(B"))
  ;;                                    (time . (13321 10953 982323)
  ;;                                    (anything . ...) )
  ;;                            ("$B2q(B" . (okurigana . ("$B$C$F(B"))
  ;;                                    (time . (13321 10977 312335))
  ;;                                    (anything . ...) )))
  (let* ((table (skk-attr-get-table okurigana))
         (header (skk-substring-head-character midasi))
         (table2 (assoc header (cdr table)))
         (add (cons midasi (list
                            (cons word
                                  (if okurigana
                                      ;; default attribute for okuri-ari
                                      (list (cons 'okurigana (list okurigana))
                                            ;; default attribute
                                            ;;(cons 'midasi midasi)
                                            ;; and new one
                                            (cons name attr) )
                                    (list
                                     ;; default attribute
                                     ;;(cons 'midasi midasi)
                                     ;; and new one
                                     (cons name attr) )))))))
    (cond (table2
           ;; header $B$"$j(B
           (setcdr table2 (cons add (cdr table2))) )
          ;; header $B$J$7(B
          ((cdr table)
           (setcdr table (cons (cons header (list add)) (cdr table))) )
          (t (setcdr table (list (cons header (list add))))) )))

(defun skk-attr-remove (midasi okurigana word name)
  ;; delete attribute ATTR for MIDASI, WORD and NAME.
  ;; e.g.
  ;; attrs := ((okurigana . ("$B$?(B" "$B$F(B")) (time . (13321 10887 982100))
  ;;           (anything . ...) )
  ;; del := (time . (13321 10887 982100))
  ;;
  (let* ((table (skk-attr-get-all-attrs midasi okurigana word))
         (del (assq name table)) )
    (and del (setq table (delq del table))) ))

;;;###skk-autoload
(defun skk-attr-purge (midasi okurigana word)
  ;; purge a whole entry for MIDASI and WORD.
  (let* ((table (cdr (skk-attr-get-table-for-midasi midasi okurigana)))
         (del (assoc word table)) )
    (and del (setq del (delq del table))) ))
    
;;;###skk-autoload
(defun skk-attr-read (&optional nomsg)
  "skk-attr-file $B$+$iB0@-$rFI$_9~$`!#(B"
  (interactive "P")
  (skk-create-file
   skk-attr-file
   (if (not nomsg)
       (if skk-japanese-message-and-error
           "SKK $B$NB0@-%U%!%$%k$r:n$j$^$7$?(B"
         "I have created an SKK attributes file for you" )))
  (if (or (null skk-attr-alist)
          (skk-yes-or-no-p (format "%s $B$r:FFI$_9~$_$7$^$9$+!)(B" skk-attr-file)
                           (format "Reread %s?" skk-attr-file) ))
      (let (;;(coding-system-for-read 'euc-japan)
            enable-character-unification )
        (save-excursion
          (unwind-protect
              (progn
                (set-buffer (get-buffer-create " *SKK attr*"))
                (erase-buffer)
                (if (= (nth 1 (insert-file-contents skk-attr-file)) 0)
                    ;; bare alist
                    (insert "((okuri-ari) (okuri-nasi))") )
                (goto-char (point-min))
                (or nomsg
                    (skk-message "%s $B$N(B SKK $BB0@-$rE83+$7$F$$$^$9(B..."
                                 "Expanding attributes of %s ..."
                                 (file-name-nondirectory skk-attr-file) ))
                (setq skk-attr-alist (read (current-buffer)))
                (or nomsg
                    (skk-message
                     "%s $B$N(B SKK $BB0@-$rE83+$7$F$$$^$9(B...$B40N;!*(B"
                     "Expanding attributes of %s ...done"
                     (file-name-nondirectory skk-attr-file) )))
	    (message "%S" (current-buffer))
	    ;; Why?  Without this line, Emacs 20 deletes the
	    ;; buffer other than skk-attr's buffer.
            (kill-buffer (current-buffer)) ))
        skk-attr-alist )))

;;;###skk-autoload
(defun skk-attr-save (&optional nomsg)
  "skk-attr-file $B$KB0@-$rJ]B8$9$k(B."
  (interactive "P")
  (if (and (null skk-attr-alist) (not nomsg))
      (progn
        (skk-message "SKK $BB0@-$r%;!<%V$9$kI,MW$O$"$j$^$;$s(B"
                     "No SKK attributes need saving" )
        (sit-for 1) )
    (save-excursion
      (if (not nomsg)
          (skk-message "%s $B$K(B SKK $BB0@-$r%;!<%V$7$F$$$^$9(B..."
                       "Saving SKK attributes to %s..." skk-attr-file ))
      (and skk-attr-backup-file
           (copy-file skk-attr-file skk-attr-backup-file
                      'ok-if-already-exists 'keep-date ))
      (set-buffer (find-file-noselect skk-attr-file))
      (if skk-mule3
          (progn
            (if (not (coding-system-p 'iso-2022-7bit-short))
                (make-coding-system
                 'iso-2022-7bit-short
                 2 ?J
                 "Like `iso-2022-7bit' but no ASCII designation before SPC."
                 '(ascii nil nil nil t t nil t) ))
            (set-buffer-file-coding-system 'iso-2022-7bit-short) ))
      (delete-region 1 (point-max))
      ;; This makes slow down when we have a long attributes alist, but good
      ;; for debugging.
      (if skk-debug (pp skk-attr-alist (current-buffer))
	(prin1 skk-attr-alist (current-buffer)) )
      (write-file skk-attr-file)
      (kill-buffer (current-buffer))
      (if (not nomsg)
          (skk-message "%s $B$K(B SKK $BB0@-$r%;!<%V$7$F$$$^$9(B...$B40N;!*(B"
                       "Saving attributes to %s...done" skk-attr-file )))))

;;(defun skk-attr-mapc (func seq)
;;  ;; funcall FUNC every element of SEQ.
;;  (let (e)
;;    (while (setq e (car seq))
;;      (setq seq (cdr seq))
;;      (funcall func e) )))
;;
;;(defun skk-attr-get-all-entries (okuri-ari)
;;  ;; remove hash tables of which key are headchar and midasi, and return all
;;  ;; entries.
;;  (let ((table (skk-attr-get-table okuri-ari))
;;        minitable val entry )
;;    (while table
;;      (setq minitable (cdr (car table)))
;;      (while minitable
;;        (setq val (cons (car (cdr minitable)) val)
;;              minitable (cdr minitable) ))
;;      (setq table (cdr table)) )
;;    val ))
    
;;;###skk-autoload
(defun skk-attr-purge-old-entries ()
  "$BD>6a$N(B 30 $BF|4V%"%/%;%9$,$J$+$C$?%(%s%H%j$r8D?M<-=q$+$i%Q!<%8$9$k!#(B"
  (interactive)
  (let ((table (cdr (skk-attr-get-table 'okuri-ari)))
        (oldday (skk-attr-relative-time (current-time) -2592000)) )
    (skk-attr-purge-old-entries-1 table oldday)
    (setq table (cdr (skk-attr-get-table nil)))
    (skk-attr-purge-old-entries-1 table oldday) ))

(defun skk-attr-purge-old-entries-1 (table oldday)
  ;; 30 days old
  (let (skk-henkan-okuri-strictly
        skk-henkan-strict-okuri-precedence
        skk-henkan-key
        skk-henkan-okurigana ;; have to bind it to nil
        skk-okuri-char
        skk-search-prog-list ;; not to work skk-public-jisyo-contains-p.
        minitable )
    ;; $B$3$&$$$&$N$r$b$C$H0lHLE*$K=hM}$G$-$k%^%/%m(B ($B4X?t$G$bNI$$$1$I(B) $B$G$b9M$((B
    ;; $B$J$-$c$J$i$s$J(B...
    (while table
      (setq minitable (cdr (car table)))
      (while minitable
        (setq minimini (cdr (car minitable)))
        (while minimini
          (setq e (car minimini))
          (if (skk-attr-time-lessp (cdr (assq 'time (cdr e))) oldday)
              (progn
                (setq skk-henkan-key (car (car minitable))
                      skk-okuri-char (substring skk-henkan-key -1)
                      ;; $B$3$l$8$c>C$($J$$$_$?$$$M(B...$B!#(B
                      minimini (delq e minimini) )
                (skk-update-jisyo (car e) 'purge) )
            (setq minimini (cdr minimini)) ))
        (setq minitable (cdr minitable)) )
      (setq table (cdr table)) )))

;; time utilities...
;;  from ls-lisp.el.  Welcome!
(defun skk-attr-time-lessp (time0 time1)
  (let ((hi0 (car time0))
	(hi1 (car time1))
	(lo0 (nth 1 time0))
	(lo1 (nth 1 time1)) )
    (or (< hi0 hi1) (and (= hi0 hi1) (< lo0 lo1))) ))

;; from timer.el.  Welcome!
(defun skk-attr-relative-time (time secs &optional usecs)
  ;; Advance TIME by SECS seconds and optionally USECS microseconds.
  ;; SECS may be a fraction.
  (let ((high (car time))
	(low (if (consp (cdr time)) (nth 1 time) (cdr time)))
	(micro (if (numberp (car-safe (cdr-safe (cdr time))))
		   (nth 2 time)
		 0)))
    ;; Add
    (if usecs (setq micro (+ micro usecs)))
    (if (floatp secs)
	(setq micro (+ micro (floor (* 1000000 (- secs (floor secs)))))))
    (setq low (+ low (floor secs)))

    ;; Normalize
    (setq low (+ low (/ micro 1000000)))
    (setq micro (mod micro 1000000))
    (setq high (+ high (/ low 65536)))
    (setq low (logand low 65535))

    (list high low (and (/= micro 0) micro))))

;; from type-break.el.  Welcome!
(defun skk-attr-time-difference (a b)
  ;; Compute the difference, in seconds, between a and b, two structures
  ;; similar to those returned by `current-time'.
  ;; Use addition rather than logand since that is more robust; the low 16
  ;; bits of the seconds might have been incremented, making it more than 16
  ;; bits wide.
  ;;
  ;; elp.el version...maybe more precisely.
  ;;(+ (* (- (car end) (car start)) 65536.0)
  ;;   (- (nth 1 end) (nth 1 start))
  ;;   (/ (- (nth 2 end) (nth 2 start)) 1000000.0) )
  ;;
  (+ (lsh (- (car b) (car a)) 16)
     (- (nth 1 b) (nth 1 a)) ))

(add-hook 'skk-before-kill-emacs-hook 'skk-attr-save)

(provide 'skk-attr)
;;; skk-attr.el ends here
