;; Sj3 server interface for Egg
;; Coded by K.Ishii, Sony Corp. (kiyoji@sm.sony.co.jp)

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
;;; Mule - Sj3 server interface in elisp
;;;

(provide 'sj3-client)

;;;;  $B=$@5%a%b!(!((B

;;;   Aug-4-94 by K.Ishii
;;;   Bug fixed in sj3-put-kata.

;;;   Apr-6-94 by N.Tanaka 
;;;   Add version 2(japanese EUC) protocol

;;;   Jun-16-93 by H.Shirasaki <sirasaki@rd.ecip.osaka-u.ac.jp>
;;;   In sj3-bunsetu-yomi-equal, typo fixed.

;;;   Apr-6-93 by T.Saneto <sanewo@pdp.crl.sony.co.jp>
;;;   Bug fixed in sj3-bunsetu-yomi-equal.

;;;   Mar-19-93 by K.Ishii
;;;   Changed sj3-server-dict-info for edit-dict

;;;   Aug-6-92 by K.Ishii
;;;   $BF|K\8lH=Dj$K(B lc-jp $B$r;H$&$h$&$KJQ99(B

;;;   Jul-30-92 by K.Ishii
;;;   $BD9$$J8>O$rJQ49$9$k$H$-$K5/$3$k(B "Args out of range" $B%(%i!<$N=$@5(B
;;;   $BEPO?$7$?F0;l$N:o=|$,$G$-$k$h$&$K(B sj3-server-dict-info $B$N=$@5(B
;;;   sj3serv $B$KEO$9%W%m%0%i%`L>$NJQ99(B

;;;   Jun-2-92 by K.Ishii
;;;   Mule $BMQ$KJQ99(B

;;;   Dec-12-91 by K.Ishii
;;;   $BJ8@a3X=,$,$&$^$/$G$-$J$$$3$H$,$"$k$?$a!"(Bsj3-result-buffer $B$rJQ99(B
;;;
;;;   sj3-get-stdy $B$G(B "Count exceed." $B%(%i!<$rNI$/5/$3$9$N$G:o=|(B

;;;   Nov-26-91 by K.Ishii
;;;   sj3-server-open $B$G(B host_name $B$H(B user_name $B$rEO$9=gHV$N=$@5(B
;;;
;;;   sj3-server-henkan-next $B$r<B9T$7$F$h$/5/$3$k(B "Count exceed." $B$H$$$&(B
;;;   $B%P%0$N=$@5(B
;;;
;;;   sj3-server-henkan-next $B$G0l3gJQ49$HJ8@aJQ49$GBh0l8uJd$,0c$C$?>l9g(B
;;;   $B$K5/$3$k%P%0$N=$@5(B($B$3$l$KH<$$J8@a3X=,(B sj3-server-b-study $B$N=$@5(B)

;;;
;;;  Sj3 deamon command constants
;;;

(defconst SJ3_OPEN          1  "$BMxMQ<TEPO?(B")
(defconst SJ3_CLOSE         2  "$BMxMQ<T:o=|(B")
;;;
(defconst SJ3_DICADD       11 "$B<-=qDI2C(B")
(defconst SJ3_DICDEL       12 "$B<-=q:o=|(B")
;;;
(defconst SJ3_OPENSTDY	   21  "$B3X=,%U%!%$%k%*!<%W%s(B")
(defconst SJ3_CLOSESTDY	   22  "$B3X=,%U%!%$%k%/%m!<%:(B")
(defconst SJ3_STDYSIZE	   23  "")
;;;
(defconst SJ3_LOCK         31 "$B<-=q%m%C%/(B")
(defconst SJ3_UNLOCK       32 "$B<-=q%"%s%m%C%/(B")
;;;
(defconst SJ3_BEGIN        41 "$BJQ493+;O(B")
(defconst SJ3_BEGIN_EUC   111 "$BJQ493+;O(B")
;;;
(defconst SJ3_TANCONV      51 "$B:FJQ49!JJ8@a?-=L!K(B")
(defconst SJ3_TANCONV_EUC 112 "$B:FJQ49!JJ8@a?-=L!K(B")
(defconst SJ3_KOUHO        54 "$B8uJd(B")
(defconst SJ3_KOUHO_EUC   115 "$B8uJd(B")
(defconst SJ3_KOUHOSU      55 "$B8uJd?t(B")
(defconst SJ3_KOUHOSU_EUC 116 "$B8uJd?t(B")
;;;
(defconst SJ3_STDY         61 "$BJ8@a3X=,(B")
(defconst SJ3_END          62 "$BJ8@aD93X=,(B")
(defconst SJ3_END_EUC     117 "$BJ8@aD93X=,(B")
;;;
(defconst SJ3_WREG         71 "$BC18lEPO?(B")
(defconst SJ3_WREG_EUC    118 "$BC18lEPO?(B")
(defconst SJ3_WDEL         72 "$BC18l:o=|(B")
(defconst SJ3_WDEL_EUC    119 "$BC18l:o=|(B")
;;;
(defconst SJ3_MKDIC        81 "")
(defconst SJ3_MKSTDY       82 "")
(defconst SJ3_MKDIR        83 "")
(defconst SJ3_ACCESS       84 "")
;;;
(defconst SJ3_WSCH         91 "$BC18l8!:w(B")
(defconst SJ3_WSCH_EUC    120 "$BC18l8!:w(B")
(defconst SJ3_WNSCH        92 "")
(defconst SJ3_WNSCH_EUC   121 "")
;;;
(defconst SJ3_VERSION     103 "")

;;;  Sj3 server version error
(defconst SJ3_DifferentVersion 11 "")
(defvar *sj3-current-server-version* nil)

(defvar sj3-server-buffer nil  "Buffer associated with Sj3 server process.")

(defvar sj3-server-process nil  "Sj3 Kana Kanji hankan process.")

(defvar sj3-command-tail-position nil)
(defvar sj3-command-buffer nil)

(defvar sj3-result-buffer nil)
(defvar sj3-henkan-string nil)
(defvar sj3-bunsetu-suu   nil)

(defvar sj3-return-code nil)
(defvar sj3-error-code nil)

(defvar sj3-stdy-size nil)
(defvar sj3-user-dict-list nil)
(defvar sj3-sys-dict-list nil)
(defvar sj3-yomi-llist nil)
;;;
;;;  Put data into buffer 
;;;

(defun sj3-put-4byte (integer)
  (insert (logand 255 (ash integer -24))
	  (logand 255 (ash integer -16))
	  (logand 255 (ash integer -8))
	  (logand 255 (ash integer 0)) ))

(defun sj3-put-string (str)
  (insert str 0))

(defun sj3-put-string* (str)
  (let ((sstr (if (= *sj3-current-server-version* 2)
		  (code-convert-string str *internal* *euc-japan*)
		(code-convert-string str *internal* *sjis*))))
    (insert sstr 0)))

;;;
;;; Get data from buffer
;;;

(defun sj3-get-4byte ()

  (let ((c 0) (point (point)))
    ;;;(goto-char (point-min))
    (while (< (point-max) (+ point 4))
      (accept-process-output)
      (if (= c 10) (if t (progn (sit-for 0) (setq c 0)) (error "Count exceed.")))
      (setq c (1+ c)))
    (goto-char point))

  (let ((point (point)))
    (if (not (or (and (= (char-after point) 0)
		      (< (char-after (+ point 1)) 128))
		 (and (= (char-after point) 255)
		      (<= 128 (char-after (+ point 1))))))
	(error "sj3-get-4byte: integer range overflow."))
    (prog1
	(logior 
	 (lsh (char-after point)       24)
	 (lsh (char-after (+ point 1)) 16)
	 (lsh (char-after (+ point 2))  8)
	 (lsh (char-after (+ point 3))  0))
      (goto-char (+ (point) 4)))))

(defun sj3-get-byte ()
  (let ((c 0) (point (point)))
    (while (< (point-max) (1+ point))
      (accept-process-output)
      (if (= c 10) (if t (progn (sit-for 0) (setq c 0)) (error "Count exceed.")))
      (setq c (1+ c)))
    (goto-char point)
    (prog1
	(lsh (char-after point) 0)
      (forward-char 1))))

(defun sj3-get-string ()
  (let ((point (point)))
    (skip-chars-forward "^\0")
    (let ((c 0))
      (while (eobp)
	(accept-process-output)
	(if (= c 10) (if t (progn (sit-for 0) (setq c 0)) (error "Count exceed")))
	(setq c (1+ c))
	(skip-chars-forward "^\0")))
    (prog1 
	(buffer-substring point (point))
      (forward-char 1))))

(defun sj3-get-string* ()
  (let ((point (point)))
    (sj3-get-convert-string)
    (buffer-substring point (1- (point)))))

(defun sj3-get-convert-string ()
  (let ((point (point)) (c 0) str)
    (while (not (search-forward "\0" nil t))
      (accept-process-output)
      (goto-char point)
      (if (= c 10) (if t (progn (sit-for 0) (setq c 0)) (error "Count exceed")))
      (setq c (1+ c)))
    (setq str (buffer-substring point (1- (point))))
    (delete-region point (point))
    (insert (if (= *sj3-current-server-version* 2)
		(code-convert-string str *euc-japan* *internal*)
	      (code-convert-string str *sjis* *internal*)) 0)))

(defun sj3-get-stdy ()
  (let ((c 0) (point (point)))
    (while (< (point-max) (+ point sj3-stdy-size))
      (accept-process-output)
      (if (>= c 10) (progn (sit-for 0) (setq c 0))) ;;; delete error
      (setq c (1+ c)))
    (goto-char (+ point sj3-stdy-size))))

;;;
;;; Sj3 Server Command Primitives
;;;

(defun sj3-command-start (command)
  (set-buffer sj3-command-buffer)
  (goto-char (point-min))
  (if (not (= (point-max) (+ sj3-command-tail-position 1024)))
      (error "sj3 command start error"))
  (delete-region (point-min) sj3-command-tail-position)
  (sj3-put-4byte command))

(defun sj3-command-reset ()
  (save-excursion
    (progn  
      ;;; for Mule
      (if (fboundp 'set-process-coding-system)
	  (set-process-coding-system sj3-server-process *noconv* *noconv*))
      ;;; for Nemacs 3.0 and later
;;      (if (fboundp 'set-process-kanji-code)
;;         (set-process-kanji-code sj3-server-process 0))
      (set-buffer sj3-command-buffer)
      (setq mc-flag nil)   ;;; for Mule
;;      (setq kanji-flag nil)
;;      (setq kanji-fileio-code 0)   ;;; for Nemacs 2.1
      (buffer-disable-undo sj3-command-buffer)
      (erase-buffer)
      (setq sj3-command-tail-position (point-min))
      (let ((max 1024) (i 0))
	(while (< i max)
	  (insert 0)
	  (setq i (1+ i)))))))

(defun sj3-command-end ()
  (set-buffer sj3-server-buffer)
  (erase-buffer)
  (set-buffer sj3-command-buffer)
  (setq sj3-command-tail-position (point))
;;  (process-send-region sj3-server-process (point-min)
;;	       (+ (point-min) (lsh (1+ (lsh (- (point) (point-min)) -10)) 10)))
  (process-send-region sj3-server-process (point-min) (1+ (point)))
  )

;;;
;;; Sj3 Server Reply primitives
;;;

(defun sj3-get-result ()
  (set-buffer sj3-server-buffer)
  (condition-case ()
      (accept-process-output sj3-server-process)
    (error nil))
  (goto-char (point-min)))

(defun sj3-get-return-code ()
  (setq sj3-return-code (sj3-get-4byte))
  (setq sj3-error-code  (if (= sj3-return-code 0) nil
			  (sj3-error-symbol sj3-return-code)))
  (if sj3-error-code nil
    sj3-return-code))

;;;
;;; Sj3 Server Interface:  sj3-server-open
;;;

;(defvar *sj3-server-max-kana-string-length* 1000)
;(defvar *sj3-server-max-bunsetu-suu* 1000)

(defvar *sj3-server-version* 2)
(setq *sj3-server-version* 2)
(defvar *sj3-program-name* "sj3-egg-m")
(defvar *sj3-service-name* "sj3")

(defun sj3-server-open (server-host-name login-name)
  (if (sj3-server-active-p) t
     (let ((server_version *sj3-server-version*)
	   (sj3serv_name 
	   (if (or (null  server-host-name)
		   (equal server-host-name "")
		   (equal server-host-name "unix"))
	       (system-name)
	     server-host-name))
	  (user_name
	   (if (or (null login-name) (equal login-name ""))
	       (user-login-name)
	     login-name))
	  (host_name (system-name))
	  (program_name 
	   (format "%d.%s" 
		  (string-to-int (substring (make-temp-name "") 1 6))
		  *sj3-program-name*)))
      (setq sj3-server-process 
	    (condition-case var
		(open-network-stream "Sj3" " [Sj3 Output Buffer] "
				     sj3serv_name *sj3-service-name* )
	      (error 
	        (cond((string-match "Unknown host" (car (cdr var)))
		      (setq sj3-error-code (list ':SJ3_UNKNOWN_HOST
						 sj3serv_name)))
		     ((string-match "Unknown service" (car (cdr var)))
		      (setq sj3-error-code (list ':SJ3_UNKNOWN_SERVICE
						 *sj3-service-name*)))
		     (t ;;; "Host ... not respoding"
		      (setq sj3-error-code ':SJ3_SOCK_OPEN_FAIL)))
		     nil)))
      (if (null sj3-server-process) nil
	(process-kill-without-query sj3-server-process)
	(setq sj3-server-buffer (get-buffer " [Sj3 Output Buffer] "))
	(setq sj3-command-buffer (get-buffer-create " [Sj3 Command Buffer] "))
	(setq sj3-result-buffer (get-buffer-create " [Sj3 Result Buffer] "))

	(save-excursion 
          ;;; for Mule
	  (if (fboundp 'set-process-coding-system)
	      (set-process-coding-system 
	       sj3-server-process *noconv* *noconv*))
	  ;;; for Nemacs 3.0 
;;	  (if (fboundp 'set-process-kanji-code)
;;	      (set-process-kanji-code sj3-server-process 0))
	  (progn
	    (set-buffer sj3-server-buffer)
	    (setq mc-flag nil)   ;;; for Mule
;;	    (setq kanji-flag nil)
	    ;;; for Nemacs 2.1
;;	    (setq kanji-fileio-code 0) 
	    (buffer-disable-undo sj3-server-buffer)
	    )
	  (progn
	    (set-buffer sj3-result-buffer)
	    (setq mc-flag nil)   ;;; for Mule
;;	    (setq kanji-flag nil)
	    ;;; for Nemacs 2.1 
;;	    (setq kanji-fileio-code 0)
	    (buffer-disable-undo sj3-result-buffer))
	  (progn  
	    (set-buffer sj3-command-buffer)
	    (setq mc-flag nil)   ;;; for Mule
;;	    (setq kanji-flag nil)
	    ;;; for Nemacs 2.1
;;	    (setq kanji-fileio-code 0)
	    (buffer-disable-undo sj3-command-buffer)
	    (erase-buffer)
	    (setq sj3-command-tail-position (point-min))
	    (let ((max 1024) (i 0))
	      (while (< i max)
		(insert 0)
		(setq i (1+ i)))))
	  (sj3-clear-dict-list)
	  (sj3-command-start SJ3_OPEN)
	  (sj3-put-4byte server_version)
	  (sj3-put-string host_name)
	  (sj3-put-string user_name)
	  (sj3-put-string program_name)
	  (sj3-command-end)
	  (sj3-get-result)
	  (sj3-get-return-code)
	  (if (= sj3-return-code SJ3_DifferentVersion)
	      (progn (sj3-command-start SJ3_OPEN)
	             (sj3-put-4byte 1)
	             (sj3-put-string host_name)
	             (sj3-put-string user_name)
	             (sj3-put-string program_name)
	             (sj3-command-end)
	             (sj3-get-result)
	             (sj3-get-return-code)
	             (if (not (= sj3-return-code 0))
		         (sj3-connection-error)
		       nil)
		     )
	    nil)
	  (if (or (= sj3-return-code 0) (> -1 sj3-return-code))
	      (progn  (setq *sj3-current-server-version* 1)
	              (if (not (= sj3-return-code 0))
	                  (setq *sj3-current-server-version* (- 0 sj3-return-code))
			nil)
                      (sj3-get-stdy-size)
		      )
	    nil)
	  )))))

(defun sj3-server-active-p ()
  (and sj3-server-process
       (eq (process-status sj3-server-process) 'open)))

(defun sj3-connection-error ()
  (setq sj3-error-code ':sj3-no-connection)
  (setq sj3-return-code -1)
  nil)

(defun sj3-zero-arg-command (op)
  (if (sj3-server-active-p)
      (progn
	(sj3-command-start op)
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code))
    (sj3-connection-error)))

(defun sj3-server-close ()
  (let (dict-no)
    (while (and (sj3-server-active-p) (setq dict-no (car sj3-sys-dict-list)))
      (sj3-server-close-dict dict-no)
      (setq sj3-sys-dict-list (cdr sj3-sys-dict-list)))
    (while (and (sj3-server-active-p) (setq dict-no (car sj3-user-dict-list)))
      (sj3-server-close-dict dict-no)
      (setq sj3-user-dict-list (cdr sj3-user-dict-list)))
    (sj3-clear-dict-list))
  (sj3-server-close-stdy)
  (sj3-zero-arg-command SJ3_CLOSE)
  (if (sj3-server-active-p)
      (delete-process sj3-server-process))
  (if sj3-server-buffer
      (kill-buffer sj3-server-buffer))
  (if sj3-command-buffer
      (kill-buffer sj3-command-buffer))
  (if sj3-result-buffer
      (kill-buffer sj3-result-buffer))
  (setq sj3-server-process nil)
  (setq sj3-server-buffer nil)
  (setq sj3-command-buffer nil)
  (setq sj3-result-buffer nil))

(defun sj3-clear-dict-list ()
  (setq sj3-sys-dict-list nil)
  (setq sj3-user-dict-list nil))

(or (fboundp 'si:kill-emacs)
    (fset 'si:kill-emacs (symbol-function 'kill-emacs)))

(defun kill-emacs (&optional arg)
  (interactive "P")
  (if (sj3-server-active-p)
      (progn
	(sj3-server-close)))
  (si:kill-emacs arg))

(defun sj3-get-stdy-size ()
  (sj3-zero-arg-command SJ3_STDYSIZE)
  (if (not (= sj3-return-code 0)) nil
      (setq sj3-stdy-size (sj3-get-4byte))))

(defun sj3-put-stdy-dmy ()
  (let ((i 0))
    (while (< i sj3-stdy-size)
      (insert 0)
      (setq i (1+ i)))))

;;; Sj3 Result Buffer's layout:
;;;
;;; { length:4  kana 0 kouhoSuu:4 kouhoNo:4
;;;   {studyData kanji 0 } ...
;;; }
;;;   0 0 0 0

(defun sj3-skip-length ()
  (goto-char (+ (point) 4)))

(defun sj3-skip-4byte ()
  (goto-char (+ (point) 4)))

(defun sj3-skip-yomi ()
  (skip-chars-forward "^\0") (forward-char 1))

(defun sj3-skip-stdy ()
  (goto-char (+ (point) sj3-stdy-size)))

;;;
;;; entry function
;;;
(defun sj3-server-henkan-begin (henkan-string)
  (if (not (sj3-server-active-p)) (sj3-connection-error)
    (let ((inhibit-quit t) mb-str)
      (save-excursion
	(setq sj3-henkan-string henkan-string)
	(if (= *sj3-current-server-version* 2)
	    (setq mb-str (code-convert-string henkan-string *internal* *euc-japan*))
	    (setq mb-str (code-convert-string henkan-string *internal* *sjis*))
        )
	(set-buffer sj3-result-buffer)
	(erase-buffer)
	(setq sj3-bunsetu-suu 0)
	(setq sj3-yomi-llist nil)
	(goto-char (point-min))
	(if (= *sj3-current-server-version* 2)
	    (sj3-command-start SJ3_BEGIN_EUC)
	  (sj3-command-start SJ3_BEGIN)
	)
	(sj3-put-string mb-str)
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code)
	(if (not (= sj3-return-code 0)) nil
	  (let ((yp 0) p0 yl offset)
	    (sj3-get-4byte)
	    (set-buffer sj3-result-buffer)
	    (delete-region (point) (point-max))
	    (setq p0 (point))
	    (insert sj3-henkan-string 0 0 0 0)
	    (goto-char p0)
	    (set-buffer sj3-server-buffer)
	    (while (> (setq yl (sj3-get-byte)) 0)
	      (let ((startp (point)) 
		    (ystr (substring mb-str yp (+ yp yl)))
		    endp)
		(setq yp (+ yp yl))
		(if (= *sj3-current-server-version* 2)
		    (setq yl (length (code-convert-string ystr *euc-japan* *internal*)))
		  (setq yl (length (code-convert-string ystr *sjis* *internal*)))
		)
		(sj3-get-stdy) ;;; skip study-data
		(sj3-get-convert-string)
		(setq endp (point))
		(set-buffer sj3-result-buffer)
		(setq p0 (point))
		(forward-char yl)
		(setq sj3-yomi-llist (append sj3-yomi-llist (list yl)))
		(insert 0)  ;;; yomi
		(sj3-put-4byte 1) ;;; kouho suu
		(sj3-put-4byte 0) ;;; current kouho number
		(insert-buffer-substring sj3-server-buffer startp endp)
		                  ;;; insert study data and kanji strings
		(setq offset (- (point) p0))
		(goto-char p0) (sj3-put-4byte offset)
		(goto-char (+ (point) offset))
		(setq sj3-return-code (1+ sj3-return-code))
		(set-buffer sj3-server-buffer)))
	    (setq sj3-bunsetu-suu sj3-return-code)))))))
;;;
;;; entry function
;;;
(defun sj3-server-henkan-quit () t)

(defun sj3-get-yomi-suu-org ()
  (if (setq sj3-yomi-llist (cdr sj3-yomi-llist))
      (car sj3-yomi-llist)
    0))

;;;
;;; entry function
;;;
(defun sj3-server-henkan-end (bunsetu-no)
  (if (not (sj3-server-active-p)) (sj3-connection-error)
    (let ((inhibit-quit t))
      (save-excursion
	(let (length ystr len kouho-no kouho-suu p0 (ylist nil))
	  (set-buffer sj3-result-buffer)
	  (goto-char (point-min))
	  (let ((max (if (and (integerp bunsetu-no)
			      (<= 0 bunsetu-no)
			      (<= bunsetu-no sj3-bunsetu-suu))
			 bunsetu-no
		       sj3-bunsetu-suu))
		(i 0))
	    (while (< i max)
	      (setq length (sj3-get-4byte))
	      (setq p0 (point))
	      (setq ystr (sj3-get-string))
	      (setq len (1- (- (point) p0)))
	      (setq kouho-suu (sj3-get-4byte)) ;;; kouho suu
	      (setq kouho-no (sj3-get-4byte))
	      (if (and (> kouho-no 0)
		       (< kouho-no (- kouho-suu 2))
		       (> kouho-suu 3))
		  (sj3-server-b-study kouho-no))
	      (setq ylist (cons (list len ystr kouho-suu (point)) ylist))
	      (goto-char (+ p0 length))
	      (setq i (1+ i)))
	    (setq ylist (nreverse ylist))
	    (setq i 1)
	    (let ((yp 0) (op 0) (ydata (car ylist)) (ol (car sj3-yomi-llist)))
	      (while (< i max)
		(let ((yl (nth 0 ydata)))
		  (setq ylist (cdr ylist))
		  (if (and (= yp op) (= yl ol))
		      (let ((pp (+ yp yl)))
			(setq yp pp)
			(setq op pp)
			(setq ydata (car ylist))
			(setq ol (sj3-get-yomi-suu-org)))
		    (let ((str (nth 1 ydata))
			  (ent (nth 2 ydata)))
		      (setq ydata (car ylist))
		      (setq yp (+ yp yl))
		      (while (< op yp)
			(setq op (+ op ol))
			(setq ol (sj3-get-yomi-suu-org)))
		      (if (or (= ent 2) (= (nth 2 ydata) 2)) nil
			(let ((sub (- op yp)) (yl1 (nth 0 ydata)))
			  (set-buffer sj3-result-buffer)
			  (goto-char (nth 3 ydata))
			  (sj3-server-cl-study str (nth 1 ydata))
			  (if (and (not (= sub yl1)) (not (= sub (- yl1 ol))))
			      nil
			    (setq i (1+ i))
			    (setq ylist (cdr ylist))
			    (setq ydata (car ylist))
			    (if (= sub yl1) nil
			      (setq op (+ op ol))
			      (setq ol (sj3-get-yomi-suu-org))))))))
		      (setq i (1+ i))))
	    (if (or (null ydata) (= (nth 0 ydata) ol) (= (nth 2 ydata) 2))
		sj3-return-code
	      (goto-char (nth 3 ydata))
	      (sj3-server-cl-study (nth 1 ydata) "")))))))))

(defun sj3-server-cl-study (str1 str2)
  (if (not (sj3-server-active-p)) (sj3-connection-error)
    (save-excursion
      (if (= *sj3-current-server-version* 2)
	  (sj3-command-start SJ3_END_EUC)
	(sj3-command-start SJ3_END))
      (sj3-put-string* str1)
      (sj3-put-string* str2)
      (if (string= str2 "") (sj3-put-stdy-dmy)
	(let (p0)
	  (set-buffer sj3-result-buffer)
	  (setq p0 (point))
	  (set-buffer sj3-command-buffer)
	  (insert-buffer-substring sj3-result-buffer p0 (+ p0 sj3-stdy-size))))
      (sj3-command-end)
      (sj3-get-result)
      (sj3-get-return-code))))
    
(defun sj3-server-b-study (no)
  (if (not (sj3-server-active-p)) (sj3-connection-error)
    (save-excursion
      (let ((i 0) p0)
	(set-buffer sj3-result-buffer)
	(while (< i no)
	  (sj3-skip-stdy)
	  (sj3-skip-yomi)
	  (setq i (1+ i)))
	(setq p0 (point))
	(sj3-command-start SJ3_STDY)
	(insert-buffer-substring sj3-result-buffer p0 (+ p0 sj3-stdy-size))
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code)))))

(defun sj3-result-goto-bunsetu (bunsetu-no)
  (goto-char (point-min))
  (let (length (i 0))
    (while (< i bunsetu-no)
      (setq length (sj3-get-4byte))
      (goto-char (+ (point) length))
      (setq i (1+ i)))))
	      
;;;
;;; entry function
;;;
(defun sj3-server-henkan-kakutei (bunsetu-no jikouho-no)
  (cond((not (sj3-server-active-p)) (sj3-connection-error))
       ((or (< bunsetu-no 0) (<= sj3-bunsetu-suu bunsetu-no))
	nil)
       (t 
	(let ((inhibit-quit t))
	  (save-excursion
	    (set-buffer sj3-result-buffer)
	    (let (kouho-suu)
	      (sj3-result-goto-bunsetu bunsetu-no)
	      (sj3-skip-length)
	      (sj3-skip-yomi)
	      (setq kouho-suu (sj3-get-4byte))
	      (if (or (< jikouho-no 0) (<= kouho-suu jikouho-no)) nil
		(delete-char 4) (sj3-put-4byte jikouho-no)
		t)))))))

;;;
;;; entry function
;;;
(defun sj3-server-henkan-next (bunsetu-no)
  (if (not (sj3-server-active-p)) (sj3-connection-error)
    (let ((inhibit-quit t))
      (save-excursion
	(let (p0 p1 kouho-suu length ystr)
	  (set-buffer sj3-result-buffer)
	  (sj3-result-goto-bunsetu bunsetu-no)
	  (sj3-skip-length)
	  (setq p0 (point))
	  (setq ystr (sj3-get-string))
	  (setq p1 (point))
	  (setq kouho-suu (sj3-get-4byte))
	  (if (> kouho-suu 1) t
	    (let ((ksuu (sj3-server-henkan-kouho ystr)) (startp 0) endp)
	      (if (< ksuu 0) sj3-return-code
		(let (kanji)
		  (set-buffer sj3-result-buffer)
		  (sj3-skip-4byte)
		  (sj3-skip-stdy)
		  (setq kanji (sj3-get-string))
		  (if (> ksuu 1)
		      (let ((i 1))
			(set-buffer sj3-server-buffer)
			(sj3-get-4byte)
			(setq startp (point))
			(sj3-get-stdy)
			(let ((kkanji (sj3-get-string*)))
			  (if (equal kanji kkanji)
			      (setq startp (point))
			    (setq ksuu (1+ ksuu))
			    (setq i (1+ i))))
			(while (< i ksuu)
			  (sj3-get-4byte)
			  (delete-char -4)
			  (sj3-get-stdy)
			  (sj3-get-convert-string)
			  (setq i (1+ i)))
			(setq endp (point))))
		  (set-buffer sj3-result-buffer)
		  (if (> startp 0)
		      (insert-buffer-substring sj3-server-buffer startp endp))
		  (sj3-put-kata ystr)
		  (insert ystr 0)
		  (setq length (- (point) p0))
		  (goto-char p1)
		  (delete-char 4)
		  (if (<= ksuu 0)(sj3-put-4byte 3) ;;;
		    (sj3-put-4byte (+ ksuu 2)))    ;;; put kouho-suu 
		  (goto-char p0)
		  (delete-char -4)
		  (sj3-put-4byte length))
		t))))))))

(defun sj3-server-henkan-kouho (str)
  (if (not (sj3-server-active-p)) -1
    (let ((mb-str (if (= *sj3-current-server-version* 2)
		      (code-convert-string str *internal* *euc-japan*)
		    (code-convert-string str *internal* *sjis*)))
	  len kouho-suu)
      (setq len (length mb-str))
      (setq kouho-suu (sj3-server-henkan-kouho-suu len mb-str))
      (if (<= kouho-suu 0) nil
	(if (= *sj3-current-server-version* 2)
	    (sj3-command-start SJ3_KOUHO_EUC)
	  (sj3-command-start SJ3_KOUHO))
	(sj3-put-4byte len)
	(sj3-put-string mb-str)
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code)
	(if (not (= sj3-return-code 0)) -1))
      kouho-suu)))

(defun sj3-put-kata (str)
  (setq str (copy-sequence str))
  (let ((i 0) (len (length str)))
    (while (< i len)
      (if (/= (aref str i) lc-jp)
	  (setq i (1+ i))
	(if (= (aref str (1+ i)) ?\244)
	    (aset str (1+ i) ?\245))
	(setq i (+ i 3)))))
  (insert str 0))

(defun sj3-server-henkan-kouho-suu (yomi-length yomi)
  (if (not (sj3-server-active-p)) -1
    (save-excursion
      (if (= *sj3-current-server-version* 2)
	  (sj3-command-start SJ3_KOUHOSU_EUC)
	(sj3-command-start SJ3_KOUHOSU))
      (sj3-put-4byte yomi-length)
      (sj3-put-string yomi)
      (sj3-command-end)
      (sj3-get-result)
      (sj3-get-return-code)
      (if (not (= sj3-return-code 0)) -1
	(sj3-get-4byte)))))

;;;
;;; entry function
;;;
(defun sj3-server-bunsetu-henkou (bunsetu-no bunsetu-length)
  (cond((not (sj3-server-active-p)) (sj3-connection-error))
       ((or (< bunsetu-no 0) (<= sj3-bunsetu-suu bunsetu-no))
	nil)
       (t
	(let ((inhibit-quit t))
	  (save-excursion
	    (let (yp0 p0 p1 str len1 len2 bunsetu-suu (bno bunsetu-no))
	      (set-buffer sj3-result-buffer)
	      (setq yp0 (sj3-yomi-point bunsetu-no))
	      (setq p0 (point))
	      (setq str (sj3-get-yomi* yp0 bunsetu-length))
	      (setq len1 (length str))
	      (setq bunsetu-suu sj3-bunsetu-suu)
	      (let (point length)
		(setq len2 len1)
		(while (and (< bno sj3-bunsetu-suu) (> len2 0))
		  (setq length (sj3-get-4byte))
		  (setq point (point))
		  (skip-chars-forward "^\0")
		  (setq len2 (- len2 (- (point) point)))
		  (goto-char (+ point length))
		  (setq bno (1+ bno))))
	      (setq p1 (point))
	      (delete-region p0 p1)
	      (setq sj3-bunsetu-suu (- sj3-bunsetu-suu (- bno bunsetu-no)))
	      (if (= (sj3-put-tanconv str) 0)
		  (if (not (= len2 0))
		      (let ((len (- 0 len2)) (yp1 (+ yp0 len1))
			    ystr mb-str)
			(if (or (> bno (1+ bunsetu-no)) (= bno bunsetu-suu))
			    (setq ystr (sj3-get-yomi yp1 len))
			  (let (ll length i)
			    (set-buffer sj3-result-buffer)
			    (setq p0 (point))
			    (setq length (sj3-get-4byte))
			    (skip-chars-forward "^\0")
			    (setq ll (+ len (- (point) (+ p0 4))))
			    (setq p1 (+ p0 (+ length 4)))
			    (setq ystr (sj3-get-yomi yp1 ll))
			    (setq mb-str (if (= *sj3-current-server-version* 2)
					     (code-convert-string ystr *internal* *euc-japan*)
					   (code-convert-string ystr *internal* *sjis*)))
			    (setq i (sj3-server-henkan-kouho-suu 
				     (length mb-str) mb-str))
			    (set-buffer sj3-result-buffer)
			    (if (= i 0) (setq ystr (sj3-get-yomi yp1 len))
			      (delete-region p0 p1)
			      (setq sj3-bunsetu-suu (1- sj3-bunsetu-suu))
			      (setq len ll))
			    (goto-char p0)))
			(sj3-put-tanconv ystr))))
	      (if (= sj3-return-code -1) nil
		sj3-bunsetu-suu)))))))

(defun sj3-put-tanconv (str)
  (let ((point (point)) len ksuu
	(mb-str (if (= *sj3-current-server-version* 2)
		    (code-convert-string str *internal* *euc-japan*)
		  (code-convert-string str *internal* *sjis*))))
    (setq len (length mb-str))
    (setq ksuu (sj3-server-henkan-kouho-suu len mb-str))
    (if (>= ksuu 0)
	(let (offset)
	  (set-buffer sj3-result-buffer)
	  (insert str 0)
	  (if (or (= ksuu 0)
		  (not (sj3-server-tanconv len mb-str)))
	      (put-kata-and-hira str)
	    (let (p0 p1)
	      (set-buffer sj3-result-buffer)
	      (sj3-put-4byte 1)
	      (sj3-put-4byte 0)
	      (set-buffer sj3-server-buffer)
	      (sj3-get-4byte)
	      (setq p0 (point))
	      (sj3-get-stdy)
	      (sj3-get-convert-string)
	      (setq p1 (point))
	      (set-buffer sj3-result-buffer)
	      (insert-buffer-substring sj3-server-buffer p0 p1)))
	  (set-buffer sj3-result-buffer)
	  (setq offset (- (point) point))
	  (goto-char point) (sj3-put-4byte offset)
	  (goto-char (+ (point) offset))
	  (setq sj3-bunsetu-suu (1+ sj3-bunsetu-suu))))
    sj3-return-code))
		    
(defun sj3-server-tanconv (len str)
  (if (not (sj3-server-active-p)) (sj3-connection-error)
    (let ((inhibit-quit t))
      (if (= *sj3-current-server-version* 2)
	  (sj3-command-start SJ3_TANCONV_EUC)
	(sj3-command-start SJ3_TANCONV))
      (sj3-put-4byte len)
      (sj3-put-string str)
      (sj3-command-end)
      (sj3-get-result)
      (sj3-get-return-code))))

(defun put-kata-and-hira (str)
  (sj3-put-4byte 2)
  (sj3-put-4byte 0)
  (sj3-put-stdy-dmy)
  (sj3-put-kata str)
  (insert str 0))

(defun sj3-get-yomi (offset length)
  (substring sj3-henkan-string offset (+ offset length)))

(defun sj3-get-yomi* (offset bunsetu-length)
  (let ((i 0) (c offset))
    (while (< i bunsetu-length)
	(let ((ch (substring sj3-henkan-string c (1+ c))))
	  (if (string= ch "\222");;lc-jp
	      (setq c (+ 3 c))
	    (setq c (1+ c)))
	  (setq i (1+ i))))
    (substring sj3-henkan-string offset c)))
      
(defun sj3-bunsetu-suu () sj3-bunsetu-suu)

(defun sj3-bunsetu-kanji (bunsetu-no &optional buffer)
  (let ((savebuffer (current-buffer)))
    (unwind-protect 
	(progn
	  (set-buffer sj3-result-buffer)
	  (if (or (< bunsetu-no 0)
		  (<= sj3-bunsetu-suu bunsetu-no))
	      nil
	    (sj3-result-goto-bunsetu bunsetu-no)
	    (sj3-skip-length)
	    (sj3-skip-yomi)

	    (let ((i 0) 
		  (rksuu (- (sj3-get-4byte) 2)) ;;; real kouho-suu
		  (max (sj3-get-4byte)))       ;;; kouho-number
	      (sj3-skip-stdy)
	      (while (< i max)
		(sj3-skip-yomi)
		(setq i (1+ i))
		(if (< i rksuu)
		    (sj3-skip-stdy))))
	    
	    (let ( p1 p2 )
	      (setq p1 (point))
	      (skip-chars-forward "^\0") (setq p2 (point))
	      (forward-char 1)
	      (if (null buffer)
		  (concat (buffer-substring p1 p2))
		(set-buffer buffer)
		(insert-buffer-substring sj3-result-buffer p1 p2)
		nil))))
      (set-buffer savebuffer))))

(defun sj3-bunsetu-kanji-length (bunsetu-no)
  (save-excursion
    (set-buffer sj3-result-buffer)
    (if (or (< bunsetu-no 0)
	    (<= sj3-bunsetu-suu bunsetu-no))
	nil
      (sj3-result-goto-bunsetu bunsetu-no)
      (sj3-skip-length)
      (sj3-skip-yomi)

      (let ((i 0) 
	    (rksuu (- (sj3-get-4byte) 2)) ;;; real kouho-suu
	    (max (sj3-get-4byte)))        ;;; kouho-number
	(sj3-skip-stdy)
	(while (< i max)
	  (sj3-skip-yomi)
	  (setq i (1+ i))
	  (if (< i rksuu)
	      (sj3-skip-stdy))))
	    
      (let ( p1 p3 )
	(setq p1 (point))
	(skip-chars-forward "^\0")
	(setq p3 (point))
	(- p3 p1)))))

(defun sj3-bunsetu-yomi-moji-suu (bunsetu-no)
  (save-excursion
    (set-buffer sj3-result-buffer)
    (if (or (<  bunsetu-no 0)
	    (<= sj3-bunsetu-suu bunsetu-no))
	nil
      (sj3-result-goto-bunsetu bunsetu-no)
      (sj3-skip-length)
      (let ((c 0) ch)
	(while (not (zerop (setq ch (following-char))))
	  (if (= ch lc-jp)
	      (forward-char 3)
	    (forward-char 1))
	  (setq c (1+ c)))
	c))))

(defun sj3-yomi-point (bunsetu-no)
  (let ((i 0) (len 0) point length)
    (goto-char (point-min))
    (while (< i bunsetu-no)
      (setq length (sj3-get-4byte))
      (setq point (point))
      (skip-chars-forward "^\0")
      (setq len (+ len (- (point) point)))
      (goto-char (+ point length))
      (setq i (1+ i)))
      len))

(defun sj3-bunsetu-yomi (bunsetu-no &optional buffer)
  (let ((savebuff (current-buffer)))
    (unwind-protect 
	(progn
	  (set-buffer sj3-result-buffer)
	  (if (or (<  bunsetu-no 0)
		  (<= sj3-bunsetu-suu bunsetu-no))
	      nil
	    (sj3-result-goto-bunsetu bunsetu-no)
	    (sj3-skip-length)
	    (let (p1 p2 )
	      (setq p1 (point))
	      (skip-chars-forward "^\0")
	      (if (null buffer ) (buffer-substring p1 (point))
		(setq p2 (point))
		(set-buffer buffer)
		(insert-buffer-substring sj3-result-buffer p1 p2)
		t))))
      (set-buffer savebuff))))

(defun sj3-bunsetu-yomi-equal (bunsetu-no yomi)
  (save-excursion
    (set-buffer sj3-result-buffer)
      (if (or (<  bunsetu-no 0)
	    (<= sj3-bunsetu-suu bunsetu-no))
	nil
      (sj3-result-goto-bunsetu bunsetu-no)
      (sj3-skip-length)
      (looking-at (regexp-quote yomi))))) ;93.4.6 by T.Saneto

(defun sj3-bunsetu-kouho-suu (bunsetu-no)
  (save-excursion
    (set-buffer sj3-result-buffer)
    (if (or (<  bunsetu-no 0)
	    (<= sj3-bunsetu-suu bunsetu-no))
	nil
      (sj3-result-goto-bunsetu bunsetu-no)
      (sj3-skip-length)
      (sj3-skip-yomi)
      (sj3-get-4byte))))

(defun sj3-bunsetu-kouho-list (bunsetu-no)
  (save-excursion
    (set-buffer sj3-result-buffer)
    (if (or (<  bunsetu-no 0)
	    (<= sj3-bunsetu-suu bunsetu-no))
	nil
      (sj3-result-goto-bunsetu bunsetu-no)
      (sj3-skip-length)
      (sj3-skip-yomi)
      (let ((max (sj3-get-4byte)) (i 0) (result nil) p0)
	(sj3-skip-4byte) ;;; current kouhou number
	(sj3-skip-stdy)
	(while (< i max)
	  (setq p0 (point))
	  (skip-chars-forward "^\0")
	  (setq result
		(cons (concat (buffer-substring p0 (point)))
		      result))
	  (forward-char 1)
	  (setq i (1+ i))
	  (if (< i (- max 2))
	      (sj3-skip-stdy)))
	(nreverse result)))))

(defun sj3-bunsetu-kouho-number (bunsetu-no)
  (save-excursion
    (set-buffer sj3-result-buffer)
    (if (or (<  bunsetu-no 0)
	    (<= sj3-bunsetu-suu bunsetu-no))
	nil
      (sj3-result-goto-bunsetu bunsetu-no)
      (sj3-skip-length)
      (sj3-skip-yomi)
      (sj3-skip-4byte)
      (sj3-get-4byte)))
  )

(defun sj3-simple-command (op arg)
  (if (sj3-server-active-p)
      (let ((inhibit-quit t))
	(progn
	  (sj3-command-start op)
	  (sj3-put-4byte arg)
	  (sj3-command-end)
	  (sj3-get-result)
	  (sj3-get-return-code)))
    (sj3-connection-error)))

(defun sj3-server-open-dict (dict-file-name password)
  (if (not (sj3-server-active-p))(sj3-connection-error)
    (let ((inhibit-quit t))
      (save-excursion
        (sj3-command-start SJ3_DICADD)
	(sj3-put-string dict-file-name)
	(if (stringp password)
	    (sj3-put-string password)
	  (sj3-put-string 0))
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code)
	(if (not (= sj3-return-code 0)) nil
	  (let ((dict-no (sj3-get-4byte)))
	    (if (stringp password)
		(setq sj3-user-dict-list
		      (append sj3-user-dict-list (list dict-no)))
	      (setq sj3-sys-dict-list
		    (append sj3-sys-dict-list (list dict-no))))
	    dict-no))))))

(defun sj3-server-close-dict (dict-no)
  (if (not (sj3-server-active-p))(sj3-connection-error)
    (let ((inhibit-quit t))
      (save-excursion
	(sj3-command-start SJ3_DICDEL)
	(sj3-put-4byte dict-no)
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code)))))

(defun sj3-server-make-dict (dict-file-name)
  (if (not (sj3-server-active-p))(sj3-connection-error)
    (let ((inhibit-quit t))
      (save-excursion
	(sj3-command-start SJ3_MKDIC)
	(sj3-put-string dict-file-name)
	(sj3-put-4byte 2048)  ;;; Index length
	(sj3-put-4byte 2048)  ;;; Length
	(sj3-put-4byte 256)   ;;; Number
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code)))))

(defun sj3-server-open-stdy (stdy-file-name)
  (if (not (sj3-server-active-p))(sj3-connection-error)
    (let ((inhibit-quit t))
      (save-excursion
	(sj3-command-start SJ3_OPENSTDY)
	(sj3-put-string stdy-file-name)
	(sj3-put-string 0)
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code)))))

(defun sj3-server-close-stdy ()
  (sj3-zero-arg-command SJ3_CLOSESTDY))

(defun sj3-server-make-stdy (stdy-file-name)
  (if (not (sj3-server-active-p))(sj3-connection-error)
    (let ((inhibit-quit t))
      (save-excursion
	(sj3-command-start SJ3_MKSTDY)
	(sj3-put-string stdy-file-name)
	(sj3-put-4byte 2048)  ;;; Number
	(sj3-put-4byte 1)     ;;; Step
	(sj3-put-4byte 2048)  ;;; Length
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code)))))

(defun sj3-server-dict-add (dictno kanji yomi bunpo)
  (if (not (sj3-server-active-p))(sj3-connection-error) 
    (let ((inhibit-quit t))
      (save-excursion
	(if (= *sj3-current-server-version* 2)
	    (sj3-command-start SJ3_WREG_EUC)
	  (sj3-command-start SJ3_WREG))
	(sj3-put-4byte dictno)
	(sj3-put-string* yomi)
	(sj3-put-string* kanji)
	(sj3-put-4byte bunpo)
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code)))))

(defun sj3-server-dict-delete (dictno kanji yomi bunpo)
  (if (not (sj3-server-active-p)) (sj3-connection-error)
    (let ((inhibit-quit t))
      (save-excursion
	(if (= *sj3-current-server-version* 2)
	    (sj3-command-start SJ3_WDEL_EUC)
	  (sj3-command-start SJ3_WDEL))
	(sj3-put-4byte dictno)
	(sj3-put-string* yomi)
	(sj3-put-string* kanji)
	(sj3-put-4byte bunpo)
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code)))))

(defun sj3-server-dict-info (dict-no)
  (if (not (sj3-server-active-p)) (sj3-connection-error)
    (let ((inhibit-quit t))
      (save-excursion
	(let ((result nil))
	  (set-buffer sj3-server-buffer)
	  (if (= *sj3-current-server-version* 2)
	      (sj3-simple-command SJ3_WSCH_EUC dict-no)
	    (sj3-simple-command SJ3_WSCH dict-no))
	  (while (= sj3-return-code 0)
	    ;;; (sj3-get-4byte)
	    (setq result (cons (list (sj3-get-string*)
				    (sj3-get-string*) (sj3-get-4byte)) result))
	    (if (= *sj3-current-server-version* 2)
		(sj3-simple-command SJ3_WNSCH_EUC dict-no)
	      (sj3-simple-command SJ3_WNSCH dict-no)))
	  (if (= sj3-return-code 111)
	      (setq sj3-error-code nil))
	  (nreverse result))))))

(defun sj3-server-make-directory (dir-name)
  (if (not (sj3-server-active-p)) (sj3-connection-error)
    (let ((inhibit-quit t))
      (save-excursion
	(sj3-command-start SJ3_MKDIR)
	(sj3-put-string dir-name)
	(sj3-command-end)
	(sj3-get-result)
	(sj3-get-return-code)))))

(defun sj3-server-file-access (file-name access-mode)
  (if (not (sj3-server-active-p)) (sj3-connection-error)
    (let ((inhibit-quit t))
      (save-excursion
	(sj3-command-start SJ3_ACCESS)
	(sj3-put-string file-name)
	(sj3-put-4byte access-mode)
	(sj3-command-end)
	(sj3-get-result)
	(setq sj3-error-code nil)
	(sj3-get-4byte)))))

(defun sj3_lock ()
  (sj3-zero-arg-command SJ3_LOCK))

(defun sj3_unlock ()
  (sj3-zero-arg-command SJ3_UNLOCK))

(defun sj3_version ()
  (sj3-zero-arg-command SJ3_VERSION))

(defconst *sj3-error-alist*
  '(
    (1 :SJ3_SERVER_DEAD
       "$B%5!<%P$,;`$s$G$$$^$9!#(B")
    (2 :SJ3_SOCK_OPEN_FAIL
       "socket$B$N(Bopen$B$K<:GT$7$^$7$?!#(B")
    (6 :SJ3_ALLOC_FAIL
       "$B%a%b%j(Balloc$B$G<:GT$7$^$7$?!#(B")
    (7 :SJ3_ILLEGAL_COMMAND
       "$B%3%^%s%I$,4V0c$C$F$$$k(B")
    (12 :SJ3_BAD_HOST
	" $B%[%9%HL>$,$J$$(B ")
    (13 :SJ3_BAD_USER
	" $B%f!<%6L>$,$J$$(B ")
    (31 :SJ3_NOT_A_DICT
	"$B@5$7$$<-=q$G$O$"$j$^$;$s!#(B")
    (35 :SJ3_NO_EXIST     
	"$B%U%!%$%k$,B8:_$7$^$;$s!#(B")
    (37 :SJ3_OPENF_ERR
	"$B%U%!%$%k$,%*!<%W%s$G$-$^$;$s!#(B")
    (39 :SJ3_PARAMR
	"$B%U%!%$%k$NFI$_9~$_8"8B$,$"$j$^$;$s!#(B")
    (40 :SJ3_PARAMW
	"$B%U%!%$%k$N=q$-9~$_8"8B$,$"$j$^$;$s!#(B")
    (71 :SJ3_NOT_A_USERDICT
	"$B;XDj$5$l$F<-=q$O!"%f!<%6!<<-=q$G$O$"$j$^$;$s!#(B")
    (72 :SJ3_RDONLY
	"$B%j!<%I%*%s%j!<$N<-=q$KEPO?$7$h$&$H$7$^$7$?!#(B")
    (74 :SJ3_BAD_YOMI
	"$BFI$_$KITE,Ev$JJ8;z$,4^$^$l$F$$$^$9!#(B")
    (75 :SJ3_BAD_KANJI
	"$B4A;z$KITE,Ev$JJ8;z$,4^$^$l$F$$$^$9!#(B")
    (76 :SJ3_BAD_HINSHI
	"$B;XDj$5$l$?IJ;lHV9f$,$"$j$^$;$s!#(B")
    (82 :SJ3_WORD_ALREADY_EXIST
	"$B;XDj$5$l$?C18l$O$9$G$KB8:_$7$F$$$^$9!#(B")
    (84 :SJ3_JISHOTABLE_FULL
	"$B<-=q%F!<%V%k$,0lGU$G$9!#(B")
    (92 :SJ3_WORD_NO_EXIST
	"$B;XDj$5$l$?C18l$,B8:_$7$^$;$s!#(B")
    (102 :SJ3_MKDIR_FAIL
	" $B%G%#%l%/%H%j$r:n$jB;$J$C$?(B ")
    ))

(defun sj3-error-symbol (code)
  (let ((pair (assoc code *sj3-error-alist*)))
    (if (null pair)
	(list ':sj3-unknown-error-code code)
      (car (cdr pair)))))

