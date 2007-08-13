;; SKK tutorial for SKK version 9.4 and later versions
;; Copyright (C) 1988, 1989, 1990, 1991, 1992, 1993, 1994, 1995, 1996, 1997
;; Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>

;; Author: Masahiko Sato <masahiko@kuis.kyoto-u.ac.jp>
;; Maintainer: Mikio Nakajima <minakaji@osaka.email.ne.jp>
;; Version: $Id: skk-tut.el,v 1.1 1997/12/02 08:48:39 steve Exp $
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

;; Following people contributed modifications to skk-tut.el
;; (Alphabetical order):
;;      Haru'yasu Ueda <hal@sics.se>
;;      Hideki Sakurada <sakurada@kusm.kyoto-u.ac.jp>
;;      Hitoshi SUZUKI <h-suzuki@ael.fujitsu.co.jp>
;;      IIDA Yosiaki <iida@sayla.secom-sis.co.jp>
;;      Koji Uchida <uchida@cfd.tytlabs.co.jp>
;;      Mikio Nakajima <minakaji@osaka.email.ne.jp>
;;      Shuhei KOBAYASHI <shuhei-k@jaist.ac.jp>
;;      Toyonobu Yoshida <toyono-y@is.aist-nara.ac.jp>
;;      Wataru Matsui <matsui@gf.hm.rd.sanyo.co.jp>
;;      $BD@;VM&(B <jshen@cas.org>

;;; Change log:
;; version 4.10 released 1997.2.4
;; version 3.9 released 1996.2.7
;; version 3.8 released 1995.5.13
;; version 3.7 released 1993.5.20
;; version 3.6 released 1992.9.19
;; version 3.5 released 1992.5.31
;; version 3.4 released 1992.4.12
;; version 3.3 released 1991.4.20
;; version 3.2 released 1990.4.15
;; version 2.2 released 1989.4.15

;;; Code:
(require 'skk-foreword)
(require 'skk-vars)
(require 'advice)

;#SJT# This should be adjusted to XEmacs convention.
;      And patches to Murata-san should be SKK convention.
(defvar skk-tut-file-alist
  '(("Japanese" . (expand-file-name "skk/SKK.tut" data-directory))
    ("English" . (expand-file-name "skk/SKK.tut.E" data-directory)))
  "*
Alist of `(LANGUAGE . TUTORIAL-FILE)' pairs."
)

(defvar skk-tut-file "/usr/local/share/skk/SKK.tut"
  "*SKK $B%A%e!<%H%j%"%k$N%U%!%$%kL>!#(B
The English version is SKK.tut.E." )

(defvar skktut-japanese-tut
  (string= (file-name-nondirectory skk-tut-file) "SKK.tut")
  "Non-nil $B$G$"$l$P!"%A%e!<%H%j%"%k$,F|K\8l$G$"$k$3$H$r<($9!#(B" )

(defvar skktut-use-face t
  "*Non-nil $B$G$"$l$P!"%A%e!<%H%j%"%k$G(B face $B$rMxMQ$7$?I=<($r9T$J$&!#(B" )

(defvar skktut-section-face
  (and skktut-use-face
       (cond ((and (eq skk-background-mode 'mono) (skk-terminal-face-p))
              'bold-italic )
             ((eq skk-background-mode 'light)
              (skk-make-face 'yellow/dodgerblue) )
             (t (skk-make-face 'yellow/slateblue)) ))
  "*$B%A%e!<%H%j%"%kCf$N%;%/%7%g%s$NI=<(ItJ,$N(B face$B!#(B" )

(defvar skktut-do-it-face
  (and skktut-use-face
       (cond ((and (eq skk-background-mode 'mono) (skk-terminal-face-p))
              'bold )
             ((eq skk-background-mode 'light)
              (skk-make-face 'DarkGoldenrod) )
             (t (skk-make-face 'LightGoldenrod)) ))
  "*$B%A%e!<%H%j%"%kCf$N;X<(9`L\$NI=<(ItJ,$N(B face$B!#(B" )

(defvar skktut-question-face
  (and skktut-use-face
       (cond ((and (eq skk-background-mode 'mono) (skk-terminal-face-p))
              'underline )
             ((eq skk-background-mode 'light)
              (skk-make-face 'Blue) )
             (t (skk-make-face 'LightSkyBlue)) ))
  "*$B%A%e!<%H%j%"%kCf$NLdBj$NI=<(ItJ,$N(B face$B!#(B" )

(defvar skktut-key-bind-face
  (and skktut-use-face
       (cond ((and (eq skk-background-mode 'mono) (skk-terminal-face-p))
              'bold )
             ((eq skk-background-mode 'light)
              (skk-make-face 'Firebrick) )
             (t (skk-make-face 'OrangeRed)) ))
  "*$B%A%e!<%H%j%"%kCf$N%-!<%P%$%s%I$NI=<(ItJ,$N(B face$B!#(B" )

(defvar skktut-hint-face
  (and skktut-use-face
       (cond ((and (eq skk-background-mode 'mono) (skk-terminal-face-p))
              'italic )
             ((eq skk-background-mode 'light)
              (skk-make-face 'CadetBlue) )
             (t (skk-make-face 'Aquamarine)) ))
  "*$B%A%e!<%H%j%"%kCf$N%R%s%H$NI=<(ItJ,$N(B face$B!#(B
$B8=:_$N$H$3$m!"(BSKK.tut.E $B$G$7$+;HMQ$5$l$F$$$J$$!#(B" )

(defconst skktut-problem-numbers 37 "SKK $B%A%e!<%H%j%"%k$NLdBj?t!#(B")

(defconst skktut-tut-jisyo "~/skk-tut-jisyo"
  "SKK $B%A%e!<%H%j%"%kMQ$N%@%_!<<-=q!#(B" )

(defconst skktut-init-variables-alist
  '((skk-init-file . "")
    (skk-special-midashi-char-list . (?> ?< ??))
    (skk-mode-hook . nil)
    (skk-auto-fill-mode-hook . nil)
    (skk-load-hook . nil)
    (skk-search-prog-list . ((skk-search-jisyo-file skktut-tut-jisyo 0 t)))
    (skk-jisyo . "~/skk-tut-jisyo")
    (skk-keep-record . nil)
    (skk-kakutei-key . "\C-j")
    (skk-use-vip . nil)
    (skk-use-viper . nil)
    (skk-henkan-okuri-strictly . nil)
    (skk-henkan-strict-okuri-precedence . nil)
    (skk-auto-okuri-process . nil)
    (skk-process-okuri-early . nil)
    (skk-egg-like-newline . nil)
    (skk-kakutei-early . t)
    (skk-delete-implies-kakutei . t)
    (skk-allow-spaces-newlines-and-tabs . t)
    (skk-convert-okurigana-into-katakana . nil)
    (skk-delete-okuri-when-quit . nil)
    (skk-henkan-show-candidates-keys . (?a ?s ?d ?f ?j ?k ?l))
    (skk-ascii-mode-string . " SKK")
    (skk-hirakana-mode-string . " $B$+$J(B")
    (skk-katakana-mode-string . " $B%+%J(B")
    (skk-zenkaku-mode-string . " $BA41Q(B")
    (skk-abbrev-mode-string . " a$B$"(B")
    (skk-echo . t)
    (skk-use-numeric-conversion . t)
    ;;(skk-char-type-vector . nil)
    ;;(skk-standard-rom-kana-rule-list . nil)
    (skk-rom-kana-rule-list . nil)
    (skk-postfix-rule-alist . (("oh" "$B%*(B" . "$B$*(B")))
    (skk-previous-candidate-char . nil)
    ;;(skk-input-vector . nil)
    ;;(skk-zenkaku-vector . nil)
    ;;(skk-use-face . t)
    ;;(skk-henkan-face)
    ;;(skk-use-color-cursor . t)
    ;;(skk-default-cursor-color . "Black")
    ;;(skk-hirakana-cursor-color . t)
    ;;(skk-katakana-cursor-color . t)
    (skk-zenkaku-cursor-color . "gold") 
    (skk-ascii-cursor-color . "ivory4")
    (skk-abbrev-cursor-color . "royalblue")
    (skk-report-set-cursor-error . t)
    (skk-auto-insert-paren . nil)
    (skk-japanese-message-and-error . nil)
    (skk-ascii-mode-map . nil)
    (skk-j-mode-map . nil)
    (skk-zenkaku-mode-map . nil)
    (skk-abbrev-mode-map . nil)
    (skk-jisyo-save-count . nil)
    (skk-byte-compile-init-file . nil)
    (skk-count-private-jisyo-candidates-exactly . nil)
    (skk-compare-jisyo-size-when-saving . nil)
    (skk-auto-start-henkan . nil)
    (skk-insert-new-word-function . nil)
    
    (skk-date-ad . 1)
    (skk-number-style . 1)
    (skk-gadget-load-hook . nil)
    
    (skk-input-by-code-menu-keys1 . (?a ?s ?d ?f ?g ?h ?q ?w ?e ?r ?t ?y))
    (skk-input-by-code-menu-keys2 . (?a ?s ?d ?f ?g ?h ?j ?k ?l ?q ?w ?e ?r ?t ?y ?u))
    (skk-kcode-load-hook . nil)
    
    ;;(skk-num-type-list . nil)
    (skk-numeric-conversion-float-num . nil)
    (skk-uniq-numerals . t)
    (skk-num-load-hook . nil)
    
    (skk-dabbrev-like-completion . nil)
    (skk-comp-load-hook . nil))
  "skk.el $B$N%f!<%6!<JQ?t$N%j%9%H!#(B" )

(defvar skktut-right-answer nil "$BLdBj$N@52r$NJ8;zNs!#(B")
(defvar skktut-problem-count 0 "SKK $B%A%e!<%H%j%"%k$N8=:_$NLdBjHV9f!#(B")
(defvar skktut-tutorial-end nil "SKK $B%A%e!<%H%j%"%k$N=*N;$r<($9%U%i%0!#(B")
(defvar skktut-tutorial-map nil "SKK $B%A%e!<%H%j%"%k$N$?$a$N%-!<%^%C%W!#(B")

(defvar skktut-original-buffer nil
  "skk-tutorial $B$r8F$s$@$H$-$N%P%C%U%!L>!#(B" )

(defvar skktut-skk-on nil
  "Non-nil $B$G$"$l$P!"(Bskk-tutorial $B$r5/F0$7$?$H$-$K(B SKK $B$,4{$K5/F0$5$l$F$$$?$3$H$r<($9!#(B" )

;; -- macros
(defmacro skktut-message (japanese english &rest arg)
  ;; skktut-japanese-tut $B$,(B non-nil $B$@$C$?$i(B JAPANESE $B$r(B nil $B$G$"$l$P(B ENGLISH 
  ;; $B$r%(%3!<%(%j%"$KI=<($9$k!#(B
  ;; ARG $B$O(B message $B4X?t$NBh#20z?t0J9_$N0z?t$H$7$FEO$5$l$k!#(B
  (append (list 'message (list 'if 'skktut-japanese-tut japanese english))
          arg ))
      
(defmacro skktut-error (japanese english &rest arg)
  ;; skktut-japanese-tut $B$,(B non-nil $B$@$C$?$i(B JAPANESE $B$r(B nil $B$G$"$l$P(B ENGLISH 
  ;; $B$r%(%3!<%(%j%"$KI=<($7!"%(%i!<$rH/@8$5$;$k!#(B
  ;; ARG $B$O(B error $B4X?t$NBh#20z?t0J9_$N0z?t$H$7$FEO$5$l$k!#(B
  (append (list 'error (list 'if 'skktut-japanese-tut japanese english))
          arg ))

(defmacro skktut-yes-or-no-p (japanese english)
  (list 'yes-or-no-p (list 'if 'skktut-japanese-tut japanese english)) )

;;;###autoload
(defun skk-tutorial (&optional query-language)
  "SKK $B%A%e!<%H%j%"%k$r5/F0$9$k!#(B"
  (interactive "P")
  (if query-language
      (let ((lang
	     (completing-read "Language: " skk-tut-file-alist)))
	(setq skk-tut-file (cdr (assoc lang skk-tut-file-alist)))
	(message "SKK tutorial language set to %s until you exit Emacs."
                 lang)))
  (let ((inhibit-quit t))
    (if (not (< 9.4 (string-to-number (skk-version))))
        (error "skk.el version 9.4 or later is required")
      (skktut-pre-setup-tutorial)
      (skktut-setup-jisyo-buffer)
      (skktut-setup-working-buffer)
      (skktut-setup-problem-buffer)
      (skktut-setup-answer-buffer) )))

(defun skktut-save-buffers-kill-emacs (&optional query)
  (interactive "P")
  (if (skktut-yes-or-no-p "Tutorial $B$b(B Emacs $B$b=*N;$7$^$9!#$h$m$7$$$G$9$M!)(B "
                          "Quit tutorial and kill emacs? " )
      (progn (skktut-quit-tutorial 'now)
             (save-buffers-kill-emacs query) )))

(defun skktut-tutorial-again ()
  (interactive)
  (if (skktut-yes-or-no-p "$B:G=i$+$i(B Tutorial $B$r$d$jD>$7$^$9!#$h$m$7$$$G$9$M!)(B "
                          "Quit tutorial and start from question 1 again? " )
      (progn (skktut-quit-tutorial 'now)
             (skk-tutorial) )))

(defun skktut-mode ()
  (interactive)
  (if (eq skktut-problem-count 1)
      (skktut-error "$B$3$N%-!<$O$^$@;H$($^$;$s(B"
                    "Cannot use this key yet" )
    (if skk-mode
        (skk-j-mode-on)
      (add-hook 'before-make-frame-hook 'skktut-before-move-to-other-frame)
      (skk-j-mode-on)
      (define-key minibuffer-local-map "\C-j" 'skk-mode)
      ;;(define-key minibuffer-local-map "\C-m" 'skk-newline)
      )))

(defun skktut-kakutei (&optional word)
  (interactive)
  (if (eq skktut-problem-count 1)
      (skktut-error "$B$3$N%-!<$O$^$@;H$($^$;$s(B"
                    "Cannot use this key yet" )
    (skk-kakutei word) ))

(defun skktut-error-command ()
  (interactive)
  (switch-to-buffer-other-window "*$BEz(B*") )

(defun skktut-quit-tutorial (&optional now)
  (interactive)
  (if (or now (skktut-yes-or-no-p "$BK\Ev$K%A%e!<%H%j%"%k$r$d$a$^$9$+(B? "
                                  "Quit tutorial? " ))
      (let ((inhibit-quit t))
        (delete-other-windows)
        ;; $B:FEY%A%e!<%H%j%"%k$r;H$($k$h$&$K!"FbItJQ?t$r=i4|2=$7$F$*$/!#(B
        (setq skktut-japanese-tut nil
              skktut-problem-count 0
              skktut-right-answer nil
              skktut-tutorial-end nil
              skktut-tutorial-map nil )
        (remove-hook 'minibuffer-setup-hook 'skktut-localize-and-init-variables)
        (remove-hook 'before-make-frame-hook
                     'skktut-before-move-to-other-frame )
        (ad-remove-advice 'other-frame 'before 'skktut-ad)
        (ad-remove-advice 'select-frame 'before 'skktut-ad)
        (ad-activate 'other-frame)
        (ad-activate 'select-frame)
        (if (featurep 'mule)
            (if (fboundp 'skktut-save-set-henkan-point)
                (skktut-change-func-def 'skk-set-henkan-point
                                        'skktut-save-set-henkan-point ))
          (if (fboundp 'skktut-nemacs-set-henkan-point)
              (skktut-change-func-def 'skk-set-henkan-point
                                      'skktut-nemacs-set-henkan-point )))
        (if (fboundp 'skktut-save-abbrev-mode)
            (skktut-change-func-def 'skk-abbrev-mode
                                    'skktut-save-abbrev-mode ))
        (fmakunbound 'skktut-save-set-henkan-point)
        (fmakunbound 'skktut-save-abbrev-mode)
        (fmakunbound 'skktut-nemacs-set-henkan-point)
        ;; skk-jisyo ;; for debugging
        (let ((buff (get-file-buffer skktut-tut-jisyo)))
          (if buff
              (progn
                (set-buffer buff)
                (set-buffer-modified-p nil)
                (kill-buffer buff))))
        (kill-buffer " *skk-tutorial*")
        (kill-buffer "*$BEz(B*")
        (kill-buffer "*$BLd(B*")
        ;;(skk-kill-local-variables)
        (switch-to-buffer skktut-original-buffer)
        ;; SKK $B$r5/F0$;$:$K$$$-$J$j(B 
        ;; skk-tutorial $B$r<B9T$7$?$H$-$K(B skk-jisyo $B%P%C%U%!$,:n$i$l$J$$$N$G(B 
        ;; skk-setup-jisyo-buffer $B$G%(%i!<$H$J$j!"(BEmacs $B$N=*N;$,$G$-$J$/(B
        ;; $B$J$k$N$G(B SKK $B%b!<%I$r0lEY5/$3$7$F$*$/!#(B
        (skk-mode 1)
        ;; $B%A%e!<%H%j%"%k5/F0D>A0$K3+$$$F$$$?%P%C%U%!$G!"(Bskk-mode $B$r5/F0$7$F(B
        ;; $B$$$?$i!"$=$N>uBV$K$7$F!"%A%e!<%H%j%"%k$r=*N;$9$k!#(B
        ;; skk-jisyo  ;; for debugging
        (or skktut-skk-on
            (skk-mode -1) ))))

(defun skktut-answer-window ()
  (interactive)
  (let (p)
    (save-match-data
      (goto-char (point-max))
      (search-backward "\n>>")
      (forward-char 1)
      (setq skktut-right-answer
            (skk-buffer-substring (+ 3 (point))
                                  (skk-save-point (end-of-line) (point)) ))
      (switch-to-buffer-other-window "*$BEz(B*")
      (insert ">> \n\n")
      (setq p (point))
      (if skktut-japanese-tut
          (insert "* $BEz$,$G$-$?$i!X(BC-x n$B!Y(B; $BESCf$G$d$a$k$K$O!X(BC-x q$B!Y(B; "
                  "$B%9%-%C%W$9$k$K$O!X(BC-x s$B!Y(B *" )
        (insert "* For next question `C-x n'; to quit `C-x q'; "
                "to skip this question `C-x s' *" ))
      (if skktut-use-face
          (put-text-property p (point) 'face skktut-key-bind-face) )
      (put-text-property p (point) 'read-only t)
      (goto-char (+ (point-min) 3)) )))

(defun skktut-next-window ()
  (interactive)
  (save-match-data
    (let (user-ans)
      (skk-save-point
        (goto-char (point-min))
        (end-of-line)
        (skip-chars-backward " \t")
        (setq user-ans (skk-buffer-substring (+ 3 (point-min)) (point))) )
      (if (not (string= skktut-right-answer user-ans))
          (progn
            (skktut-message "$BEz$,0c$$$^$9!#$b$&0lEY$d$C$F$_$F2<$5$$(B"
                            "Wrong.  Try again")
            (ding) )
        (skktut-erase-buffer)
        (message "")
        (other-window 1)
        (setq skktut-problem-count (1+ skktut-problem-count))
        (skktut-get-page skktut-problem-count)
        (if (>= skktut-problem-count (1+ skktut-problem-numbers))
            (skktut-quit-tutorial t)
          (skktut-answer-window) )))))

(defun skktut-skip-problem (arg)
  (interactive "p")
  (skktut-erase-buffer)
  (setq skktut-problem-count (+ skktut-problem-count arg))
  (if (< skktut-problem-count 1) (setq skktut-problem-count 1))
  (if (> skktut-problem-count skktut-problem-numbers)
      (setq skktut-problem-count skktut-problem-numbers))
  (if (and (>= skktut-problem-count 3) (not skk-j-mode))
      (skktut-mode) )
  (other-window 1)
  (skktut-get-page skktut-problem-count)
  (if skktut-tutorial-end (skktut-quit-tutorial 'now) (skktut-answer-window)) )

(defun skktut-set-henkan-point-tmp ()
  (interactive)
  (if skk-j-mode
      (skktut-error "$B$+$J(B/$B%+%J%b!<%I$G$O!"1QBgJ8;z$O$^$@;H$($^$;$s(B"
                    "Cannot use upper case character in kana/katakana mode" )
    (insert (if skk-zenkaku-mode
                (concat (char-to-string 163)
                        (char-to-string (+ last-command-char 128)))
              last-command-char))))

(defun skktut-abbrev-mode-tmp ()
  (interactive)
  (if skk-j-mode
      (skktut-error "$B$3$N%-!<$O$^$@;H$($^$;$s(B"
                    "Cannot use this key yet" )
    (insert last-command-char)))

(defun skktut-get-page (page)
  (save-match-data
    (with-current-buffer " *skk-tutorial*"
      (let (pos)
        (goto-char (point-min))
        (search-forward "--\n" nil t page)
        (if (looking-at ";")
            (progn (forward-char 3)
                   (setq pos (point))
                   (end-of-line)
                   (save-excursion
                     (eval-region pos (point) nil) )
                   (forward-char 1) ))
        (if (not skktut-tutorial-end)
            (progn
              (setq pos (point))
              (search-forward "\n>>")
              (end-of-line)
              (copy-to-buffer "*$BLd(B*" pos (point)) ))))
    (if (>= page 12)
        (skktut-enable) )
    (setq mode-line-buffer-identification
          (concat "$B#S#K#K%A%e!<%H%j%"%k(B: $B!NLd(B "
                  (int-to-string page)
                  "$B!O(B $B!J;D$j(B "
                  (int-to-string (- skktut-problem-numbers page))
                  "$BLd!K(B"))
    (set-buffer-modified-p nil)
    (sit-for 0) ))

(defun skktut-disable ()
  (if (not (fboundp 'skktut-save-set-henkan-point))
      (progn
        (skktut-change-func-def 'skktut-save-set-henkan-point
                                'skk-set-henkan-point )
        (skktut-change-func-def 'skk-set-henkan-point
                                'skktut-set-henkan-point-tmp )))
  (if (not (fboundp 'skktut-save-abbrev-mode))
      (progn
        (skktut-change-func-def 'skktut-save-abbrev-mode 'skk-abbrev-mode)
        (skktut-change-func-def 'skk-abbrev-mode 'skktut-abbrev-mode-tmp) )))

(defun skktut-enable ()
  (if (fboundp 'skktut-save-abbrev-mode)
      (progn (skktut-change-func-def 'skk-abbrev-mode 'skktut-save-abbrev-mode)
             (fmakunbound 'skktut-save-abbrev-mode) ))
  (if (fboundp 'skktut-save-set-henkan-point)
      (progn (skktut-change-func-def 'skk-set-henkan-point
                                     'skktut-save-set-henkan-point )
             (fmakunbound 'skktut-save-set-henkan-point) )))

(defun skktut-pre-setup-tutorial ()
  (setq skktut-original-buffer (current-buffer)
        skktut-skk-on skk-mode
        skktut-problem-count 1 ))
  
(defadvice other-frame (before skktut-ad activate)
  (skktut-before-move-to-other-frame) )
  
(defadvice select-frame (before skktut-ad activate)
  (skktut-before-move-to-other-frame) )
  
(add-hook 'minibuffer-setup-hook 'skktut-localize-and-init-variables)

(defun skktut-setup-jisyo-buffer ()
  ;; setup skktut-tut-jisyo buffer.
  (set-buffer (get-buffer-create " *skk-tut-jisyo*"))
  (setq case-fold-search nil
        buffer-file-name (expand-file-name skktut-tut-jisyo) )
  (buffer-disable-undo (current-buffer))
  (insert (concat ";; okuri-ari entries.\n"
                  "$B$[$C(Bs /$BM_(B/\n"
                  "$B$D$+(Bt /$B;H(B/\n"
                  "$B$?$C(Bs /$BC#(B/\n"
                  "$B$7(Bt /$BCN(B/\n"
                  "$B$&$4(Bk /$BF0(B/\n"
                  ";; okuri-nasi entries.\n"
                  "Greek /$B&!(B/$B&"(B/$B&#(B/$B&$(B/$B&%(B/$B&&(B/$B&'(B/$B&((B/$B&)(B/$B&*(B/$B&+(B/$B&,(B/$B&-(B/$B&.(B/$B&/(B/$B&0(B/"
                  "$B&1(B/$B&2(B/$B&3(B/$B&4(B/$B&5(B/$B&6(B/$B&7(B/$B&8(B/\n"
                  "Russia /$B'!(B/$B'"(B/$B'#(B/$B'$(B/$B'%(B/$B'&(B/$B''(B/$B'((B/$B')(B/$B'*(B/$B'+(B/$B',(B/$B'-(B/$B'.(B/$B'/(B/$B'0(B/"
                  "$B'1(B/$B'2(B/$B'3(B/$B'4(B/$B'5(B/$B'6(B/$B'7(B/$B'8(B/$B'9(B/$B':(B/$B';(B/$B'<(B/$B'=(B/$B'>(B/$B'?(B/$B'@(B/$B'A(B/\n"
                  "greek /$B&A(B/$B&B(B/$B&C(B/$B&D(B/$B&E(B/$B&F(B/$B&G(B/$B&H(B/$B&I(B/$B&J(B/$B&K(B/$B&L(B/$B&M(B/$B&N(B/$B&O(B/$B&P(B/"
                  "$B&Q(B/$B&R(B/$B&S(B/$B&T(B/$B&U(B/$B&V(B/$B&W(B/$B&X(B/\n"
                  "russia /$B'Q(B/$B'R(B/$B'S(B/$B'T(B/$B'U(B/$B'V(B/$B'W(B/$B'X(B/$B'Y(B/$B'Z(B/$B'[(B/$B'\(B/$B'](B/$B'^(B/$B'_(B/$B'`(B/"
                  "$B'a(B/$B'b(B/$B'c(B/$B'd(B/$B'e(B/$B'f(B/$B'g(B/$B'h(B/$B'i(B/$B'j(B/$B'k(B/$B'l(B/$B'm(B/$B'n(B/$B'o(B/$B'p(B/$B'q(B/\n"
                  "$B$$$A$*$/(B /$B0l2/(B/\n"
                  "$B$*$*$5$+(B /$BBg:e(B/\n"
                  "$B$+$J(B /$B2>L>(B/\n"
                  "$B$+$s$8(B /$B4A;z(B/$B44;v(B/$B4F;v(B/\n"
                  "$B$,$/$7$e$&(B /$B3X=,(B/\n"
                  "$B$-(B /$B4p(B/$B5-(B/$B5$(B/$BLZ(B/$B5"(B/\n"
                  "$B$-$4$&(B /$B5-9f(B/$B!"(B/$B!#(B/$B!$(B/$B!%(B/$B!&(B/$B!'(B/$B!((B/$B!)(B/$B!*(B/$B!+(B/$B!,(B/$B!-(B/$B!.(B/$B!/(B/"
                  "$B!0(B/$B!1(B/$B!2(B/$B!3(B/$B!4(B/$B!5(B/$B!6(B/$B!7(B/$B!8(B/$B!9(B/$B!:(B/$B!;(B/$B!<(B/$B!=(B/$B!>(B/$B!?(B/$B!@(B/$B!A(B/"
                  "$B!B(B/$B!C(B/$B!D(B/$B!E(B/$B!F(B/$B!G(B/$B!H(B/$B!I(B/$B!J(B/$B!K(B/$B!L(B/$B!M(B/$B!N(B/$B!O(B/$B!P(B/$B!Q(B/$B!R(B/$B!S(B/"
                  "$B!T(B/$B!U(B/$B!V(B/$B![(B/$B!X(B/$B!Y(B/$B!Z(B/$B![(B/$B!\(B/$B!](B/$B!^(B/$B!_(B/$B!`(B/$B!a(B/$B!b(B/$B!c(B/$B!d(B/$B!e(B/$B!f(B/"
                  "$B!g(B/$B!h(B/$B!i(B/$B!j(B/$B!k(B/$B!l(B/$B!m(B/$B!n(B/$B!o(B/$B!p(B/$B!q(B/$B!r(B/$B!s(B/$B!t(B/$B!u(B/$B!v(B/$B!w(B/$B!x(B/$B!y(B/"
                  "$B!z(B/$B!{(B/$B!|(B/$B!}(B/$B!~(B/$B"!(B/$B""(B/$B"#(B/$B"$(B/$B"%(B/$B"&(B/$B"'(B/$B"((B/$B")(B/$B"*(B/$B"+(B/$B",(B/$B"-(B/"
                  "$B".(B/\n"
                  "$B$-$g$&$H(B /$B5~ET(B/\n"
                  "$B$3$&$Y(B /$B?@8M(B/\n"
                  "$B$4(B /$B8^(B/$B8_(B/$B8`(B/$B8a(B/$B8b(B/$B8c(B/$B8d(B/$B8e(B/$B8f(B/$B8g(B/$B8h(B/$B8i(B/$B8j(B/$B8k(B/$B8l(B/$B8m(B/$B8n(B/"
                  "$B8o(B/\n"
                  "$B$5$$(B /$B:Y(B/$B:G(B/$B:F(B/\n"
                  "$B$5$$$7$g(B /$B:G=i(B/\n"
                  "$B$5$$$H$&(B /$B:XF#(B/\n"
                  "$B$5$H$&(B /$B:4F#(B/\n"
                  "$B$7$e$&$j$g$&(B /$B=*N;(B/\n"
                  "$B$8$7$g(B /$B<-=q(B/$BCO=j(B/\n"
                  "$B$8$s$3$&(B /$B?M8}(B/\n"
                  "$B$;$s$?$/(B /$BA*Br(B/$B@vBu(B/\n"
                  "$B$=$&(B /$BAv(B/\n"
                  "$B$@$$(B /$BBg(B/$BBh(B/$BBe(B/\n"
                  "$B$F$-(B /$BE*(B/$BE((B/$BE)(B/$BE,(B/$BE&(B/\n"
                  "$B$H$&(B /$BEl(B/\n"
                  "$B$H$&$[$/(B /$BElKL(B/\n"
                  "$B$H$&$m$/(B /$BEPO?(B/\n"
                  "$B$H$&$m$/(B /$BEPO?(B/\n"
                  "$B$I$&(B /$BF0(B/\n"
                  "$B$K$e$&$j$g$/(B /$BF~NO(B/\n"
                  "$B$R$3$&$-(B /$BHt9T5!(B/\n"
                  "$B$X$s$+$s(B /$BJQ49(B/\n"
                  "$B$[$/(B /$BKL(B/\n"
                  "$B$_$g$&$8(B /$BL>;z(B/\n"
                  "$B$h$&$$(B /$BMF0W(B/$BMQ0U(B/\n" ))
  (skk-setup-jisyo-buffer)
  (skktut-localize-and-init-variables) )

(defun skktut-setup-working-buffer ()
  (save-match-data
    (let (sexp)
      (set-buffer (get-buffer-create " *skk-tutorial*"))
      ;; " *skk-tut-jisyo*" $B%P%C%U%!$N(B skk.el $B$NJQ?t$r%P%C%U%!%m!<%+%k2=$7!"(B
      ;; $B=i4|2=$9$k!#(B
      (skktut-localize-and-init-variables)
      (erase-buffer)
      (insert-file-contents skk-tut-file)
      (goto-char (point-min))
      ;; $B%A%e!<%H%j%"%k$,F|K\8l$+1Q8l$+$r%A%'%C%/!#(B
      (setq skktut-japanese-tut (looking-at ";; SKK Japanese"))
      (while (re-search-forward "^>> \\((.+)\\)$" nil t nil)
        (setq sexp (skk-buffer-substring (match-beginning 1) (match-end 1)))
        (delete-region (match-beginning 1) (match-end 1))
        (insert (eval (car (read-from-string sexp)))) )
      (goto-char (point-min))
      (if skktut-use-face
          (skktut-colored) ))))

(defun skktut-setup-problem-buffer ()
  (switch-to-buffer (get-buffer-create "*$BLd(B*"))
  (erase-buffer)
  (setq skktut-tutorial-map (make-keymap))
  (if (featurep 'xemacs)
      (map-keymap
       #'(lambda (key ignored)
	   (define-key skktut-tutorial-map key 'skktut-error-command))
       skktut-tutorial-map)
    (fillarray (nth 1 skktut-tutorial-map) 'skktut-error-command))
  (use-local-map skktut-tutorial-map)
  (skktut-get-page skktut-problem-count)
  (delete-other-windows)
  (split-window-vertically nil)
  (other-window 1)
  (enlarge-window (- (window-height (selected-window)) 20)) )

(defun skktut-setup-answer-buffer ()
  (switch-to-buffer (get-buffer-create "*$BEz(B*"))
  ;; "*$BEz(B*" $B%P%C%U%!$N(B skk.el $B$NJQ?t$r%P%C%U%!%m!<%+%k2=$7!"=i4|2=$9$k!#(B
  (skktut-localize-and-init-variables)
  (local-set-key "\C-j" 'skktut-kakutei)
  (local-set-key "\C-x\C-c" 'skktut-save-buffers-kill-emacs)
  (local-set-key "\C-x\C-j" 'skktut-mode)
  (local-set-key "\C-xj" 'skktut-error-command)
  (local-set-key "\C-xn" 'skktut-next-window)
  (local-set-key "\C-xq" 'skktut-quit-tutorial)
  (local-set-key "\C-xs" 'skktut-skip-problem)
  (local-set-key "\C-xt" 'skktut-tutorial-again)
  (skktut-disable)
  (auto-fill-mode -1)
  (switch-to-buffer-other-window "*$BLd(B*")
  (goto-char (point-max))
  (beginning-of-line)
  (skktut-answer-window)
  (message "") )

(defun skktut-localize-and-init-variables ()
  ;; $B%f!<%6!<$,(B skk.el $B$NJQ?t$r%+%9%?%^%$%:$7$F$$$k2DG=@-$,$"$k$N$G!"%+%l%s%H(B
  ;; $B%P%C%U%!$N(B skk.el $B$NJQ?t$r%P%C%U%!%m!<%+%k2=$7!"=i4|2=$9$k!#(B
  (mapcar
   (function
    (lambda (alist)
      (let ((v (car alist)))
	(make-local-variable v)
	(set v (cdr alist)))))
   skktut-init-variables-alist)
  (if (string= (buffer-name) "*$BEz(B*")
      (load-library "skk"))
  (make-local-variable 'skk-mode-invoked)
  (setq skk-mode-invoked 'invoked))

(defun skktut-erase-buffer ()
  (let ((inhibit-read-only t))
    (set-text-properties (point-min) (point-max) nil) )
  (erase-buffer) )

(defun skktut-before-move-to-other-frame ()
  (if (skktut-yes-or-no-p "Tutorial $B$r=*N;$7$^$9!#$h$m$7$$$G$9$M!)(B "
                          "Quit tutorial?" )
      (skktut-quit-tutorial 'now)
    (skktut-error "Tutorial $B$r=*N;$;$:$KB>$N%U%l!<%`$K0\$k$3$H$O$G$-$^$;$s!#(B"
                  "Quit tutorial or you cannot move to other frame" )))

(defun skktut-colored ()
  (while (re-search-forward "$B"'(B\\([^$B![(B $B$!(B-$B$s%!(B-$B%s(B]+\\)" nil t nil)
    (put-text-property (match-beginning 1) (match-end 1) 'face
                       'highlight ))
  (goto-char (point-min))
  (while (re-search-forward "^==.+==$" nil t nil)
    (put-text-property (match-beginning 0) (match-end 0)
                       'face skktut-section-face ))
  (goto-char (point-min))
  (while (re-search-forward "^!!.+" nil t nil)
    (put-text-property (match-beginning 0) (match-end 0)
                       'face skktut-do-it-face ))
  (goto-char (point-min))
  (while (re-search-forward "^>> \\(.+\\)$" nil t nil)
    (put-text-property (match-beginning 1) (match-end 1)
                       'face skktut-question-face ))
  (if skktut-japanese-tut
      nil
    (goto-char (point-min))
    (while (re-search-forward "Hint: .*$" nil t nil)
      (put-text-property (match-beginning 0) (match-end 0)
                         'face skktut-hint-face ))))

(defun skktut-change-func-def (old new &optional save)
  ;; $B4X?t(B OLD $B$NDj5A$r(B NEW $B$GCV$-JQ$($k!#(B
  ;; $B%*%W%7%g%J%k0z?t$N(B SAVE $B$r;XDj$9$k$H!"(BOLD $B$NDj5A$r(B SAVE $B$KJ]B8$9$k!#(B
  (if save (defalias save (symbol-function old)))
  (defalias old (symbol-function new)) )

;; The following function is tricky, since they are executed by "eval-region".

(defun skktut-today ()
  (save-match-data
    (let (str p)
      (widen)
      (search-forward "\n>> ")
      (if (re-search-forward "$B!V(B.*$B!W(B" (skk-save-point (end-of-line) (point)) t)
          (delete-region (match-beginning 0) (match-end 0)) )
      (setq p (point)
            str (concat "$B!V$-$g$&$O!"(B" (skk-date) "$B$G$9!#!W(B") )
      (insert str)
      (narrow-to-region (point-min) (point))
      (if skktut-use-face
          (put-text-property p (point) 'face skktut-question-face) ))))

(defun skktut-end-tutorial ()
  (message "")
  (switch-to-buffer "*$BLd(B*")
  (delete-other-windows)
  (erase-buffer)
  (goto-char (point-min))
  (if skktut-japanese-tut
      (insert
       (concat "SKK $B%A%e!<%H%j%"%k$O$3$l$G=*$j$G$9!#(B\n\n"
               "SKK $B$K4X$9$k<ALd!"%3%a%s%H!"(Bbug report $BEy$O(B\n\n"
               "\tskk@kuis.kyoto-u.ac.jp\n\n"
               "$BKx$*Aw$j2<$5$$!#$J$*!"$3$N%"%I%l%9$O(B SKK $B%a%$%j%s%0%j%9%H$N(B"
               "$B%"%I%l%9$G$9!#(B\n"
               "$B2sEz$ODL>o$3$N%"%I%l%9$KBP$7$F$J$5$l$k$N$G!"%a%s%P!<$G$J$$(B"
               "$BJ}$O$=$N;]$rL@(B\n"
               "$B5-$7$F%a!<%k$r$*Aw$j$/$@$5$$!#(B SKK $B%a%$%j%s%0%j%9%H$X;22C4u(B"
               "$BK>$N>l9g$O(B\n\n"
               "\tskk-join@kuis.kyoto-u.ac.jp\n\n"
               "$B$X%a!<%k$r$*Aw$j$/$@$5$$(B\n\n"
               "!! $B:G8e$K(B <return> $B%-!<$r2!$7$F$/$@$5$$!#(B" ))
    (insert
     (concat "Now we end the SKK tutorial.\n\n"
             "Please send comments, questions and bug reports on SKK to:\n\n"
             "\tskk@kuis.kyoto-u.ac.jp\n\n"
             "This is the address of the SKK mailing list, and normally the "
             "responces\n"
             "will be sent only to the ML members.  So, if you are not a ML "
             "member,\n"
             "please say so in your mail.  If you are interested in joining "
             "the SKK ML,\n"
             "send a mail to:\n\n"
             "\tskk-join@kuis.kyoto-u.ac.jp\n\n"
             "!! Hit <return> key when you are ready." )))
  (if skktut-use-face
      (save-match-data
        (goto-char (point-min))
        (re-search-forward "^!!.+" nil t nil)
        (put-text-property (match-beginning 0) (match-end 0)
                           'face skktut-do-it-face )))
  (while (not (= ?\C-m (read-char)))
    (skktut-message "<return> $B%-!<$r2!$7$F$/$@$5$$(B" "Hit <return> key")
    (ding) )
  (setq skktut-tutorial-end t) )

(provide 'skk-tut)
;;; skk-tut.el ends here
