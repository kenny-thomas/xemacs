;; Kana Kanji Conversion Protocol Package for Egg
;; Coded by K.Ishii, Sony Corp. (kiyoji@sm.sony.co.jp)

;; This file is part of Egg on Mule (Multilingal Environment)

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
;;; sj3-egg.el 
;;;
;;; $B!V$?$^$4!W$N(B sj3 $B%P!<%8%g%s(B
;;; $B$+$J4A;zJQ49%5!<%P$K(B sj3serv $B$r;H$$$^$9!#(B
;;;
;;; sj3-egg $B$K4X$9$kDs0F!"Cn>pJs$O(B kiyoji@sm.sony.co.jp $B$K$*Aw$j2<$5$$!#(B
;;;
;;;                                                $B@P0f(B $B@6<!(B

(require 'egg)
(provide 'egg-sj3)
(when (not (boundp 'SJ3))
  (require 'egg-sj3-client))

;;;;  $B=$@5%a%b!(!((B
;;;; Jul-20-93 by age@softlab.is.tsukuba.ac.jp (Eiji FURUKAWA)
;;;;  Bug fixed in diced-add, *sj3-bunpo-menu* and
;;;;  set-egg-henkan-mode-format.

;;;; Mar-19-93 by K.Ishii
;;;;  DicEd is changed, edit-dict-item -> edit-dict

;;;; Aug-6-92 by K.Ishii
;;;;  length $B$r(B string-width $B$KJQ99(B

;;;; Jul-30-92 by K.Ishii
;;;;  set-default-usr-dic-directory $B$G:n$k<-=q%G%#%l%/%H%jL>$N=$@5(B
;;;;  jserver-host-name, $B4D6-JQ?t(B JSERVER $B$N:o=|(B
;;;;  

;;;; Jul-7-92 by Y.Kawabe
;;;;  jserver-host-name $B$r%;%C%H$9$k:]$K4D6-JQ?t(B SJ3SERV $B$bD4$Y$k!#(B
;;;;  sj3fns.el $B$N%m!<%I$r$d$a$k!#(B

;;;; Jun-2-92 by K.Ishii
;;;;  sj3-egg.el $B$r(B wnn-egg.el $B$HF1MM$KJ,3d(B

;;;; May-14-92 by K.Ishii
;;;;  Mule $B$N(B wnn-egg.el $B$r(B sj3serv $B$H$NDL?.MQ$K=$@5(B

;;;----------------------------------------------------------------------
;;;
;;; Version control routine
;;;
;;;----------------------------------------------------------------------

(defvar sj3-egg-version "3.00" "Version number of this version of Egg. ")
;;; Last modified date: Thu Aug  4 21:18:11 1994

;;;----------------------------------------------------------------------
;;;
;;; KKCP package: Kana Kanji Conversion Protocol
;;;
;;; KKCP to SJ3SERV interface; 
;;;
;;;----------------------------------------------------------------------

(defvar *KKCP:error-flag* t)

(defun KKCP:error (errorCode &rest form)
  (cond((eq errorCode ':SJ3_SOCK_OPEN_FAIL)
	(notify "EGG: %s $B>e$K(B SJ3SERV $B$,$"$j$^$;$s!#(B" (or (get-sj3-host-name) "local"))
	(if debug-on-error
	    (error "EGG: No SJ3SERV on %s is running." (or (get-sj3-host-name) "local"))
	  (error  "EGG: %s $B>e$K(B SJ3SERV $B$,$"$j$^$;$s!#(B" (or (get-sj3-host-name) "local"))))
       ((eq errorCode ':SJ3_SERVER_DEAD)
	(notify "EGG: %s $B>e$N(BSJ3SERV $B$,;`$s$G$$$^$9!#(B" (or (get-sj3-host-name) "local"))
	(if debug-on-error
	    (error "EGG: SJ3SERV on %s is dead." (or (get-sj3-host-name) "local"))
	  (error  "EGG: %s $B>e$N(B SJ3SERV $B$,;`$s$G$$$^$9!#(B" (or (get-sj3-host-name) "local"))))
       ((and (consp errorCode)
	     (eq (car errorCode) ':SJ3_UNKNOWN_HOST))
	(notify "EGG: $B%[%9%H(B %s $B$,$_$D$+$j$^$;$s!#(B" (car(cdr errorCode)))
	(if debug-on-error
	    (error "EGG: Host %s is unknown." (car(cdr errorCode)))
	  (error "EGG: $B%[%9%H(B %s $B$,$_$D$+$j$^$;$s!#(B" (car(cdr errorCode)))))
       ((and (consp errorCode)
	     (eq (car errorCode) ':SJ3_UNKNOWN_SERVICE))
	(notify "EGG: Network service %s $B$,$_$D$+$j$^$;$s!#(B" (car(cdr errorCode)))
	(if debug-on-error
	    (error "EGG: Service %s is unknown." (car(cdr errorCode)))
	  (error "EGG: Network service %s $B$,$_$D$+$j$^$;$s!#(B" (cdr errorCode))))
       (t
	(notify "KKCP: $B860x(B %s $B$G(B %s $B$K<:GT$7$^$7$?!#(B" errorCode form)
	(if debug-on-error
	    (error "KKCP: %s failed because of %s." form errorCode)
	  (error  "KKCP: $B860x(B %s $B$G(B %s $B$K<:GT$7$^$7$?!#(B" errorCode form)))))

(defun KKCP:server-open (hostname loginname)
  (let ((result (sj3-server-open hostname loginname)))
    (cond((null sj3-error-code) result)
	 (t (KKCP:error sj3-error-code 'KKCP:server-open hostname loginname)))))

(defun KKCP:use-dict (dict &optional passwd)
  (let ((result (sj3-server-open-dict dict passwd)))
    (cond((null sj3-error-code) result)
	 ((eq sj3-error-code ':sj3-no-connection)
	  (EGG:open-sj3)
	  (KKCP:use-dict dict passwd))
	 ((null *KKCP:error-flag*) result)
	 (t (KKCP:error sj3-error-code 
			'kkcp:use-dict dict)))))

(defun KKCP:make-dict (dict)
  (let ((result (sj3-server-make-dict dict)))
    (cond((null sj3-error-code) result)
	 ((eq sj3-error-code ':sj3-no-connection)
	  (EGG:open-sj3)
	  (KKCP:make-dict dict))
	 ((null *KKCP:error-flag*) result)
	 (t (KKCP:error sj3-error-code 
			'kkcp:make-dict dict)))))

(defun KKCP:use-stdy (stdy)
  (let ((result (sj3-server-open-stdy stdy)))
    (cond((null sj3-error-code) result)
	 ((eq sj3-error-code ':sj3-no-connection)
	  (EGG:open-sj3)
	  (KKCP:use-stdy stdy))
	 ((null *KKCP:error-flag*) result)
	 (t (KKCP:error sj3-error-code 
			'kkcp:use-stdy stdy)))))

(defun KKCP:make-stdy (stdy)
  (let ((result (sj3-server-make-stdy stdy)))
    (cond((null sj3-error-code) result)
	 ((eq sj3-error-code ':sj3-no-connection)
	  (EGG:open-sj3)
	  (KKCP:make-stdy stdy))
	 ((null *KKCP:error-flag*) result)
	 (t (KKCP:error sj3-error-code 
			'kkcp:make-stdy stdy)))))

(defun KKCP:henkan-begin (henkan-string)
  (let ((result (sj3-server-henkan-begin henkan-string)))
    (cond((null sj3-error-code) result)
	 ((eq sj3-error-code ':sj3-no-connection)
	  (EGG:open-sj3)
	  (KKCP:henkan-begin henkan-string))
	 ((null *KKCP:error-flag*) result)
	 (t (KKCP:error sj3-error-code 'KKCP:henkan-begin henkan-string)))))

(defun KKCP:henkan-next (bunsetu-no)
  (let ((result (sj3-server-henkan-next bunsetu-no)))
    (cond ((null sj3-error-code) result)
	  ((eq sj3-error-code ':sj3-no-connection)
	   (EGG:open-sj3)
	   (KKCP:henkan-next bunsetu-no))
	  ((null *KKCP:error-flag*) result)
	  (t (KKCP:error sj3-error-code 'KKCP:henkan-next bunsetu-no)))))

(defun KKCP:henkan-kakutei (bunsetu-no jikouho-no)
  ;;; NOTE: $B<!8uJd%j%9%H$,@_Dj$5$l$F$$$k$3$H$r3NG'$7$F;HMQ$9$k$3$H!#(B
  (let ((result (sj3-server-henkan-kakutei bunsetu-no jikouho-no)))
    (cond ((null sj3-error-code) result)
	  ((eq sj3-error-code ':sj3-no-connection)
	   (EGG:open-sj3)
	   (KKCP:henkan-kakutei bunsetu-no jikouho-no))
	  ((null *KKCP:error-flag*) result)
	  (t (KKCP:error sj3-error-code 'KKCP:henkan-kakutei bunsetu-no jikouho-no)))))

(defun KKCP:bunsetu-henkou (bunsetu-no bunsetu-length)
  (let ((result (sj3-server-bunsetu-henkou bunsetu-no bunsetu-length)))
    (cond ((null sj3-error-code) result)
	  ((eq sj3-error-code ':sj3-no-connection)
	   (EGG:open-sj3)
	   (KKCP:bunsetu-henkou bunsetu-no bunsetu-length))
	  ((null *KKCP:error-flag*) result)
	  (t (KKCP:error sj3-error-code 'kkcp:bunsetu-henkou bunsetu-no bunsetu-length)))))


(defun KKCP:henkan-quit ()
  (let ((result (sj3-server-henkan-quit)))
    (cond ((null sj3-error-code) result)
	  ((eq sj3-error-code ':sj3-no-connection)
	   (EGG:open-sj3)
	   (KKCP:henkan-quit))
	  ((null *KKCP:error-flag*) result)
	  (t (KKCP:error sj3-error-code 'KKCP:henkan-quit)))))

(defun KKCP:henkan-end (&optional bunsetuno)
  (let ((result (sj3-server-henkan-end bunsetuno)))
    (cond ((null sj3-error-code) result)
	  ((eq sj3-error-code ':sj3-no-connection)
	   (EGG:open-sj3)
	   (KKCP:henkan-end bunsetuno))	  
	  ((null *KKCP:error-flag*) result)
	  (t (KKCP:error sj3-error-code 'KKCP:henkan-end)))))

(defun KKCP:dict-add (dictno kanji yomi bunpo)
  (let ((result (sj3-server-dict-add dictno kanji yomi bunpo)))
    (cond ((null sj3-error-code) result)
	  ((eq sj3-error-code ':sj3-no-connection)
	   (EGG:open-sj3)
	   (KKCP:dict-add dictno kanji yomi bunpo))
	  ((null *KKCP:error-flag*) result)
	  (t (KKCP:error sj3-error-code 'KKCP:dict-add dictno kanji yomi bunpo)))))

(defun KKCP:dict-delete (dictno kanji yomi bunpo)
  (let ((result (sj3-server-dict-delete dictno kanji yomi bunpo)))
    (cond ((null sj3-error-code) result)
	  ((eq sj3-error-code ':sj3-no-connection)
	   (EGG:open-sj3)
	   (KKCP:dict-delete dictno kanji yomi bunpo))
	  ((null *KKCP:error-flag*) result)
	  (t (KKCP:error sj3-error-code 'KKCP:dict-delete dictno kanji yomi bunpo)))))

(defun KKCP:dict-info (dictno)
  (let ((result (sj3-server-dict-info dictno)))
    (cond ((null sj3-error-code) result)
	  ((eq sj3-error-code ':sj3-no-connection)
	   (EGG:open-sj3)
	   (KKCP:dict-info dictno))
	  ((null *KKCP:error-flag*) result)
	  (t (KKCP:error sj3-error-code 'KKCP:dict-info dictno)))))

(defun KKCP:make-directory (pathname)
  (let ((result (sj3-server-make-directory pathname)))
    (cond ((null sj3-error-code) result)
	  ((eq sj3-error-code ':sj3-no-connection)
	   (EGG:open-sj3)
	   (KKCP:make-directory pathname))
	  ((null *KKCP:error-flag*) result)
	  (t (KKCP:error sj3-error-code 'kkcp:make-directory pathname)))))

(defun KKCP:file-access (pathname mode)
  (let ((result (sj3-server-file-access pathname mode)))
    (cond ((null sj3-error-code)
	   (if (= result 0) t nil))
	  ((eq sj3-error-code ':sj3-no-connection)
	   (EGG:open-sj3)
	   (KKCP:file-access pathname mode))
	  ((null *KKCP:error-flag*) result)
	  (t (KKCP:error sj3-error-code 'kkcp:file-access pathname mode)))))

(defun KKCP:server-close ()
  (let ((result (sj3-server-close)))
    (cond ((null sj3-error-code) result)
	  ((null *KKCP:error-flag*) result)
	  (t (KKCP:error sj3-error-code 'KKCP:server-close)))))

;;;----------------------------------------------------------------------
;;;
;;; Kana Kanji Henkan 
;;;
;;;----------------------------------------------------------------------

;;;
;;; Entry functions for egg-startup-file
;;;

(defvar *default-sys-dic-directory* (if (file-directory-p "/usr/sony/dict")
					"/usr/sony/dict/sj3"
				      "/usr/local/lib/sj3/dict"))

(defun set-default-sys-dic-directory (pathname)
  "$B%7%9%F%`<-=q$NI8=`(Bdirectory PATHNAME$B$r;XDj$9$k!#(B
PATHNAME$B$O4D6-JQ?t$r4^$s$G$h$$!#(B"

  (setq pathname (substitute-in-file-name pathname))

  (if (file-name-absolute-p pathname)
      (if (null (KKCP:file-access pathname 0))
	  (error
	   (format "System Default directory(%s) $B$,$"$j$^$;$s!#(B" pathname))
	(setq *default-sys-dic-directory* (file-name-as-directory pathname)))
    (error "Default directory must be absolute pathname")))

(defvar *default-usr-dic-directory*
  (if (file-directory-p "/usr/sony/dict/sj3/user")
      "/usr/sony/dict/sj3/user/$USER"
    "/usr/local/lib/sj3/dict/user/$USER"))

(defun set-default-usr-dic-directory (pathname)
  "$BMxMQ<T<-=q$NI8=`(Bdirectory PATHNAME$B$r;XDj$9$k!#(B
PATHNAME$B$O4D6-JQ?t$r4^$s$G$h$$!#(B"

  (setq pathname (file-name-as-directory (substitute-in-file-name pathname)))

  (if (file-name-absolute-p pathname)
      (if (null (KKCP:file-access pathname 0))
	  (let ((updir (file-name-directory (substring pathname 0 -1))))
	    (if (null (KKCP:file-access updir 0))
		(error
		 (format "User Default directory(%s) $B$,$"$j$^$;$s!#(B" pathname))
	      (when
		  (yes-or-no-p
		   (format "User Default directory(%s) $B$r:n$j$^$9$+!)(B"
			   pathname))
		(KKCP:make-directory (directory-file-name pathname))
		(notify "User Default directory(%s) $B$r:n$j$^$7$?!#(B"
			pathname))))
	(setq *default-usr-dic-directory* pathname))
    (error "Default directory must be absolute pathname")))

(defun setsysdic (dict)
  (egg:setsysdict (expand-file-name
		   (concat (if (file-name-absolute-p dict)
			       ""
			     *default-sys-dic-directory*)
			   dict))))

(defun setusrdic (dict)
  (egg:setusrdict (expand-file-name
		   (concat (if (file-name-absolute-p dict)
			       ""
			     *default-usr-dic-directory*)
			   dict))))

(defvar egg:*dict-list* nil)

(defun setusrstdy (stdy)
  (egg:setusrstdy (expand-file-name
		   (concat (if (file-name-absolute-p stdy)
			       ""
			     *default-usr-dic-directory*)
			   stdy))))

(defun egg:setsysdict (dict)
  (cond((assoc (file-name-nondirectory dict) egg:*dict-list*)
	(beep)
	(notify "$B4{$KF1L>$N%7%9%F%`<-=q(B %s $B$,EPO?$5$l$F$$$^$9!#(B"
		(file-name-nondirectory dict))
	)
       ((null (KKCP:file-access dict 0))
	(beep)
	(notify "$B%7%9%F%`<-=q(B %s $B$,$"$j$^$;$s!#(B" dict))
       (t(let* ((*KKCP:error-flag* nil)
		(rc (KKCP:use-dict dict)))
	   (if (null rc)
	       (error "EGG: setsysdict failed. :%s" dict)
	       (setq egg:*dict-list*
		     (cons (cons (file-name-nondirectory dict) dict)
			   egg:*dict-list*)))))))

;;; dict-no --> dict-name
(defvar egg:*usr-dict* nil)

;;; dict-name --> dict-no
(defvar egg:*dict-menu* nil)

(defmacro push-end (val loc)
  (list 'push-end-internal val (list 'quote loc)))

(defun push-end-internal (val loc)
  (set loc
       (if (eval loc)
	   (nconc (eval loc) (cons val nil))
	 (cons val nil))))

(defun egg:setusrdict (dict)
  (cond((assoc (file-name-nondirectory dict) egg:*dict-list*)
	(beep)
	(notify "$B4{$KF1L>$NMxMQ<T<-=q(B %s $B$,EPO?$5$l$F$$$^$9!#(B"
		(file-name-nondirectory dict))
	)
       ((null (KKCP:file-access dict 0))
	(notify "$BMxMQ<T<-=q(B %s $B$,$"$j$^$;$s!#(B" dict)
	(if (yes-or-no-p (format "$BMxMQ<T<-=q(B %s $B$r:n$j$^$9$+!)(B" dict))
	    (let ((*KKCP:error-flag* nil))
	      (if (KKCP:make-dict dict)
		  (progn
		    (notify "$BMxMQ<T<-=q(B %s $B$r:n$j$^$7$?!#(B" dict)
		    (let* ((*KKCP:error-flag* nil)
			   (dict-no (KKCP:use-dict dict "")))
		      (cond((numberp dict-no)
			    (setq egg:*usr-dict* 
				  (cons (cons dict-no dict) egg:*usr-dict*))
			    (push-end (cons (file-name-nondirectory dict)
					    dict-no) egg:*dict-menu*))
			   (t (error "EGG: setusrdict failed. :%s" dict)))))
		(error "EGG: setusrdict failed. : %s" dict)))))
       (t (let* ((*KKCP:error-flag* nil)
		 (dict-no (KKCP:use-dict dict "")))
	    (cond((numberp dict-no)
		  (setq egg:*usr-dict* (cons(cons dict-no dict) 
					    egg:*usr-dict*))
		  (push-end (cons (file-name-nondirectory dict) dict-no)
			    egg:*dict-menu*)
		  (setq egg:*dict-list*
			(cons (cons (file-name-nondirectory dict) dict)
			      egg:*dict-list*)))
		 (t (error "EGG: setusrdict failed. : %s" dict)))))))

(defun egg:setusrstdy (stdy)
  (cond((null (KKCP:file-access stdy 0))
	(notify "$B3X=,%U%!%$%k(B %s $B$,$"$j$^$;$s!#(B" stdy)
	(if (yes-or-no-p (format "$B3X=,%U%!%$%k(B %s $B$r:n$j$^$9$+!)(B" stdy))
	    (if (null (KKCP:make-stdy stdy))
		(error "EGG: setusrstdy failed. : %s" stdy)
	      (notify "$B3X=,%U%!%$%k(B %s $B$r:n$j$^$7$?!#(B" stdy)
	      (if (null (KKCP:use-stdy stdy))
		  (error "EGG: setusrstdy failed. : %s" stdy))
	      )))
	(t (if (null (KKCP:use-stdy stdy))
	       (error "EGG: setusrstdy failed. : %s" stdy)))))


;;;
;;; SJ3 interface
;;;

(defun get-sj3-host-name ()
  (cond((and (boundp 'sj3-host-name) (stringp sj3-host-name))
	sj3-host-name)
       ((and (boundp 'sj3serv-host-name) (stringp sj3serv-host-name))
	sj3serv-host-name)
       (t(getenv "SJ3SERV"))))				; 92.7.7 by Y.Kawabe

(fset 'get-sj3serv-host-name (symbol-function 'get-sj3-host-name))

(defun set-sj3-host-name (name)
  (interactive "sHost name: ")
  (let (*KKCP:error-flag*)
    (disconnect-sj3))
  (setq sj3-host-name name)
  )

(defvar egg-default-startup-file "eggrc"
  "*Egg startup file name (system default)")

(defvar egg-startup-file ".eggrc"
  "*Egg startup file name.")

(defvar egg-startup-file-search-path (append '("~" ".") load-path)
  "*List of directories to search for start up file to load.")

(defun egg:search-file (filename searchpath)
  (let (result)
    (if (null (file-name-directory filename))
	(let ((path searchpath))
	  (while (and path (null result ))
	    (let ((file (substitute-in-file-name
			 (expand-file-name filename (if (stringp (car path)) (car path) nil)))))
	      (if (file-exists-p file) (setq result file)
		(setq path (cdr path))))))
      (let((file (substitute-in-file-name (expand-file-name filename))))
	(if (file-exists-p file) (setq result file))))
    result))

(defun EGG:open-sj3 ()
  (KKCP:server-open (or (get-sj3-host-name) (system-name))
  		    (user-login-name))
  (setq egg:*usr-dict* nil
	egg:*dict-list* nil
	egg:*dict-menu* nil)
  (notify "$B%[%9%H(B %s $B$N(B SJ3 $B$r5/F0$7$^$7$?!#(B" (or (get-sj3-host-name) "local"))
  (let ((eggrc (or (egg:search-file egg-startup-file egg-startup-file-search-path)
		   (egg:search-file egg-default-startup-file load-path))))
    (if eggrc (load-file eggrc)
      (progn
	(KKCP:server-close)
	(error "eggrc-search-path $B>e$K(B egg-startup-file $B$,$"$j$^$;$s!#(B")))))

(defun disconnect-sj3 ()
  (interactive)
  (KKCP:server-close))

(defun close-sj3 ()
  (interactive)
  (KKCP:server-close))

;;;
;;; Kanji henkan
;;;

(defvar egg:*kanji-kanabuff* nil)

(defvar *bunsetu-number* nil)

(defun bunsetu-su ()
  (sj3-bunsetu-suu))

(defun bunsetu-length (number)
  (sj3-bunsetu-yomi-moji-suu number))

;; #### This looks like a stupid multi-byte kludge.
(defun kanji-moji-suu (str)
  "Do Not Call This."
  (length str))

(defun bunsetu-position (number)
  (let ((pos egg:*region-start*)
	(i 0))
    (while (< i number)
      (setq pos
	    (+ pos
	       (or (bunsetu-kanji-length  i) 0)
	       (length egg:*bunsetu-kugiri*)))
      (incf i))
    pos))

(defun bunsetu-kanji-length (bunsetu-no)
  (sj3-bunsetu-kanji-length bunsetu-no))

(defun bunsetu-kanji (number)
  (sj3-bunsetu-kanji number))

(defun bunsetu-kanji-insert (bunsetu-no)
  (sj3-bunsetu-kanji bunsetu-no (current-buffer)))

(defun bunsetu-set-kanji (bunsetu-no kouho-no) 
  (sj3-server-henkan-kakutei bunsetu-no kouho-no))

(defun bunsetu-yomi  (number) 
  (sj3-bunsetu-yomi number))

(defun bunsetu-yomi-insert (bunsetu-no)
  (sj3-bunsetu-yomi bunsetu-no (current-buffer)))

(defun bunsetu-yomi-equal (number yomi)
  (sj3-bunsetu-yomi-equal number yomi))

(defun bunsetu-kouho-suu (bunsetu-no)
  (let ((no (sj3-bunsetu-kouho-suu bunsetu-no)))
    (if (< 1 no) no
      (KKCP:henkan-next bunsetu-no)
      (sj3-bunsetu-kouho-suu bunsetu-no))))

(defun bunsetu-kouho-list (number) 
  (let ((no (bunsetu-kouho-suu number)))
    (if (= no 1)
	(KKCP:henkan-next number))
    (sj3-bunsetu-kouho-list number)))

(defun bunsetu-kouho-number (bunsetu-no)
  (sj3-bunsetu-kouho-number bunsetu-no))

;;;;
;;;; User entry : henkan-region, henkan-paragraph, henkan-sentence
;;;;

(defconst egg:*bunsetu-face* nil "*$BJ8@aI=<($KMQ$$$k(B face $B$^$?$O(B nil")
(make-variable-buffer-local
 (defvar egg:*bunsetu-extent* nil "$BJ8@a$NI=<($K;H$&(B extent"))

(defconst egg:*bunsetu-kugiri* " " "*$BJ8@a$N6h@Z$j$r<($9J8;zNs(B")


(defconst egg:*henkan-face* nil "*$BJQ49NN0h$rI=<($9$k(B face $B$^$?$O(B nil")
(make-variable-buffer-local
 (defvar egg:*henkan-extent* nil "$BJQ49NN0h$NI=<($K;H$&(B extent"))

(defconst egg:*henkan-open*  "|" "*$BJQ49$N;OE@$r<($9J8;zNs(B")
(defconst egg:*henkan-close* "|" "*$BJQ49$N=*E@$r<($9J8;zNs(B")
(defvar egg:henkan-mode-in-use nil)

(defun egg:henkan-face-on ()
  (when egg:*henkan-face*
    (if (extentp egg:*henkan-extent*)
	(set-extent-endpoints egg:*henkan-extent*
			      egg:*region-start* egg:*region-end*)
      (setq egg:*henkan-extent*
	    (make-extent egg:*region-start* egg:*region-end*))
      (mapcar
       (lambda (prop)
	 (set-extent-property egg:*henkan-extent* prop nil))
       '(start-open end-open detachable)))
    (set-extent-face egg:*henkan-extent* egg:*henkan-face*)))

(defun egg:henkan-face-off ()
  ;; detach henkan extent from the current buffer.
  (and egg:*henkan-face*
       (extentp egg:*henkan-extent*)
       (detach-extent egg:*henkan-extent*)))

(defun henkan-region (start end)
  (interactive "r")
  (if (interactive-p) (set-mark (point))) ;;; to be fixed
  (henkan-region-internal start end))

(defvar henkan-mode-indicator "$B4A(B")

(defun henkan-region-internal (start end)
  "region$B$r$+$J4A;zJQ49$9$k!#(B"
  (or egg:henkan-mode-in-use
      (let ((finished nil))
	(unwind-protect
	    (progn
	      (setq egg:henkan-mode-in-use t
		    egg:*kanji-kanabuff* (buffer-substring start end))
	      (setq *bunsetu-number* 0)
	      (let ((result (KKCP:henkan-begin egg:*kanji-kanabuff*)))
		(when result
		  (mode-line-egg-mode-update henkan-mode-indicator)
		  (goto-char start)
		  (or (markerp egg:*region-start*)
		      (setq egg:*region-start* (make-marker)))
		  (or (markerp egg:*region-end*)
		      (setq egg:*region-end*
			    (set-marker-insertion-type (make-marker) t)))
		  (if (null (marker-position egg:*region-start*))
		      (progn
                      ;;;(setq egg:*global-map-backup* (current-global-map))
			(setq egg:*local-map-backup* (current-local-map))
			;; XEmacs change:
			(buffer-disable-undo (current-buffer))
			(goto-char start)
			(delete-region start end)
			(insert egg:*henkan-open*)
			(set-marker egg:*region-start* (point))
			(insert egg:*henkan-close*)
			(set-marker egg:*region-end* egg:*region-start*)
			(goto-char egg:*region-start*)
			)
		    (egg:fence-face-off)
		    (delete-region
		     (- egg:*region-start* (length egg:*fence-open*))
		     egg:*region-start*)
		    (delete-region
		     egg:*region-end*
		     (+ egg:*region-end* (length egg:*fence-close*)))
		    (goto-char egg:*region-start*)
		    (insert egg:*henkan-open*)
		    (set-marker egg:*region-start* (point))
		    (goto-char egg:*region-end*)
		    (let ((point (point)))
		      (insert egg:*henkan-close*)
		      (set-marker egg:*region-end* point))
		    (goto-char start)
		    (delete-region start end)
		    (henkan-insert-kouho 0)
		    (egg:henkan-face-on)
		    (egg:bunsetu-face-on *bunsetu-number*)
		    (henkan-goto-bunsetu 0)
		    ;;(use-global-map henkan-mode-map)
		    ;;(use-local-map nil)
		    (use-local-map henkan-mode-map)))
		(setq finished t))
	      (or finished
		  (setq egg:henkan-mode-in-use nil)))))))


(defun henkan-paragraph ()
  "Kana-kanji henkan  paragraph at or after point."
  (interactive )
  (save-excursion
    (forward-paragraph)
    (let ((end (point)))
      (backward-paragraph)
      (henkan-region-internal (point) end ))))

(defun henkan-sentence ()
  "Kana-kanji henkan sentence at or after point."
  (interactive )
  (save-excursion
    (forward-sentence)
    (let ((end (point)))
      (backward-sentence)
      (henkan-region-internal (point) end ))))

(defun henkan-word ()
  "Kana-kanji henkan word at or after point."
  (interactive)
  (save-excursion
    (re-search-backward "\\b\\w" nil t)
    (let ((start (point)))
      (re-search-forward "\\w\\b" nil t)
      (henkan-region-internal start (point)))))

;;;
;;; Kana Kanji Henkan Henshuu mode
;;;

(defun set-egg-henkan-mode-format (open close kugiri &optional henkan-face bunsetu-face)
   "$BJQ49(B mode $B$NI=<(J}K!$r@_Dj$9$k!#(BOPEN $B$OJQ49$N;OE@$r<($9J8;zNs$^$?$O(B nil$B!#(B
CLOSE$B$OJQ49$N=*E@$r<($9J8;zNs$^$?$O(B nil$B!#(B
KUGIRI$B$OJ8@a$N6h@Z$j$rI=<($9$kJ8;zNs$^$?$O(B nil$B!#(B
HENKAN-FACE $B$,;XDj$5$l$F(B nil $B$G$J$1$l$P!"JQ496h4V$rI=<($9$k(B face $B$H$7$F;H$o$l$k!#(B
BUNSETU-FACE $B$,;XDj$5$l$F(B nil $B$G$J$1$l$P!"CmL\$7$F$$$kJ8@a$rI=<($9$k(B face $B$H$7$F;H$o$l$k(B"

  (interactive (list (read-string "$BJQ493+;OJ8;zNs(B: ")
		     (read-string "$BJQ49=*N;J8;zNs(B: ")
		     (read-string "$BJ8@a6h@Z$jJ8;zNs(B: ")
		     (cdr (assoc (completing-read "$BJQ496h4VI=<(B0@-(B: " egg:*face-alist*)
				 egg:*face-alist*))
		     (cdr (assoc (completing-read "$BJ8@a6h4VI=<(B0@-(B: " egg:*face-alist*)
				 egg:*face-alist*))
		     ))

  (if (and (or (stringp open)  (null open))
	   (or (stringp close) (null close))
	   (or (stringp kugiri) (null kugiri))
	   (or (null henkan-face) (memq henkan-face (face-list)))
	   (or (null bunsetu-face) (memq henkan-face (face-list))))
      (progn
	(setq egg:*henkan-open* (or open "")
	      egg:*henkan-close* (or close "")
	      egg:*bunsetu-kugiri* (or kugiri "")
	      egg:*henkan-face* henkan-face
	      egg:*bunsetu-face* bunsetu-face)
	(and (extentp egg:*henkan-extent*)
	     (set-extent-property
	      egg:*henkan-extent* 'face egg:*henkan-face*))
	(and (extentp egg:*bunsetu-extent*)
	     (set-extent-property
	      egg:*bunsetu-extent* 'face egg:*bunsetu-face*))

	t)
    (error "Wrong type of arguments: %1 %2 %3 %4 %5" open close kugiri henkan-face bunsetu-face)))

(defun henkan-insert-kouho (bunsetu-no)
  (let ((max (bunsetu-su)) (i bunsetu-no))
    (while (< i max)
      (bunsetu-kanji-insert i) 
      (insert  egg:*bunsetu-kugiri* )
      (setq i (1+ i)))
    (if (< bunsetu-no max) (delete-char (- (length egg:*bunsetu-kugiri*))))))

(defun henkan-kakutei ()
  (interactive)
  (egg:bunsetu-face-off)
  (egg:henkan-face-off)
  (delete-region (- egg:*region-start* (length egg:*henkan-open*))
		 egg:*region-start*)
  (delete-region egg:*region-start* egg:*region-end*)
  (delete-region egg:*region-end* (+ egg:*region-end* (length egg:*henkan-close*)))
  (goto-char egg:*region-start*)
  (let ((i 0) (max (bunsetu-su)))
    (while (< i max)
      ;;;(KKCP:henkan-kakutei i (bunsetu-kouho-number i))
      (bunsetu-kanji-insert i)
      (if (not overwrite-mode)
	  (undo-boundary))
      (setq i (1+ i))
      ))
  (KKCP:henkan-end)
  (setq egg:henkan-mode-in-use nil)
  (egg:quit-egg-mode)
  )

(defun henkan-kakutei-before-point ()
  (interactive)
  (egg:bunsetu-face-off)
  (egg:henkan-face-off)
  (delete-region egg:*region-start* egg:*region-end*)
  (goto-char egg:*region-start*)
  (let ((i 0) (max *bunsetu-number*))
    (while (< i max)
      ;;;(KKCP:henkan-kakutei i (bunsetu-kouho-number i))
      (bunsetu-kanji-insert i)
      (if (not overwrite-mode)
	  (undo-boundary))
      (setq i (1+ i))
      ))
  (KKCP:henkan-end *bunsetu-number*)
  (delete-region (- egg:*region-start* (length egg:*henkan-open*))
		 egg:*region-start*)
  (insert egg:*fence-open*)
  (set-marker egg:*region-start* (point))
  (delete-region egg:*region-end* (+ egg:*region-end* (length egg:*henkan-close*)))
  (goto-char egg:*region-end*)
  (let ((point (point)))
    (insert egg:*fence-close*)
    (set-marker egg:*region-end* point))
  (goto-char egg:*region-start*)
  (egg:fence-face-on)
  (let ((point (point))
	(i *bunsetu-number*) (max (bunsetu-su)))
    (while (< i max)
      (bunsetu-yomi-insert i)
      (setq i (1+ i)))
    ;;;(insert "|")
    ;;;(insert egg:*fence-close*)
    ;;;(set-marker egg:*region-end* (point))
    (goto-char point))
  (setq egg:*mode-on* t)
  ;;;(use-global-map fence-mode-map)
  ;;;(use-local-map  nil)
  (setq egg:henkan-mode-in-use nil)
  (use-local-map fence-mode-map)
  (egg:mode-line-display))

(defun egg:set-bunsetu-face (no face switch)
  (if (not switch)
      (egg:bunsetu-face-off) ;; JIC
    (unless (extentp egg:*bunsetu-extent*)
      (setq egg:*bunsetu-extent* (make-extent 1 1 nil))
      (set-extent-property egg:*bunsetu-extent* 'face egg:*bunsetu-face*))
    (set-extent-endpoints egg:*bunsetu-extent*
			  (if (eq face 'modeline)
			      (let ((point (bunsetu-position no)))
				(1+ point))
			    (bunsetu-position no))

			  (if (= no (1- (bunsetu-su)))
			      egg:*region-end*
			    (- (bunsetu-position (1+ no))
			       (length egg:*bunsetu-kugiri*)))
			  (current-buffer))))

(defun egg:bunsetu-face-on (no)
  (egg:set-bunsetu-face no egg:*bunsetu-face* t))

(defun egg:bunsetu-face-off ()
  ;; detach henkan extent from the current buffer.
  (and (extentp egg:*bunsetu-extent*)
       (detach-extent egg:*bunsetu-extent*)))

(defun henkan-goto-bunsetu (number)
  (setq *bunsetu-number*
	(check-number-range number 0 (1- (bunsetu-su))))
  (goto-char (bunsetu-position *bunsetu-number*))
  (egg:bunsetu-face-on *bunsetu-number*)
  )

(defun henkan-forward-bunsetu ()
  (interactive)
  (henkan-goto-bunsetu (1+ *bunsetu-number*))
  )

(defun henkan-backward-bunsetu ()
  (interactive)
  (henkan-goto-bunsetu (1- *bunsetu-number*))
  )

(defun henkan-first-bunsetu ()
  (interactive)
  (henkan-goto-bunsetu 0))

(defun henkan-last-bunsetu ()
  (interactive)
  (henkan-goto-bunsetu (1- (bunsetu-su)))
  )
 
(defun check-number-range (i min max)
  (cond((< i min) max)
       ((< max i) min)
       (t i)))

(defun henkan-hiragana ()
  (interactive)
  (henkan-goto-kouho (- (bunsetu-kouho-suu *bunsetu-number*) 1)))

(defun henkan-katakana ()
  (interactive)
  (henkan-goto-kouho (- (bunsetu-kouho-suu *bunsetu-number*) 2)))

(defun henkan-next-kouho ()
  (interactive)
  (henkan-goto-kouho (1+ (bunsetu-kouho-number *bunsetu-number*))))

(defun henkan-previous-kouho ()
  (interactive)
  (henkan-goto-kouho (1- (bunsetu-kouho-number *bunsetu-number*))))

(defun henkan-goto-kouho (kouho-number)
  (let ((point (point))
	(yomi  (bunsetu-yomi *bunsetu-number*))
	(i *bunsetu-number*)
	(max (bunsetu-su)))
    (setq kouho-number 
	  (check-number-range kouho-number 
			      0
			      (1- (bunsetu-kouho-suu *bunsetu-number*))))
    (while (< i max)
      (if (bunsetu-yomi-equal i yomi)
	  (let ((p1 (bunsetu-position i)))
	    (delete-region p1
			   (+ p1 (bunsetu-kanji-length i)))
	    (goto-char p1)
	    (bunsetu-set-kanji i kouho-number)
	    (bunsetu-kanji-insert i)))
      (setq i (1+ i)))
    (goto-char point))
  (egg:bunsetu-face-on *bunsetu-number*))

(defun henkan-bunsetu-chijime ()
  (interactive)
  (or (= (bunsetu-length *bunsetu-number*) 1)
      (bunsetu-length-henko (1-  (bunsetu-length *bunsetu-number*)))))

(defun henkan-bunsetu-nobasi ()
  (interactive)
  (if (not (= (1+ *bunsetu-number*) (bunsetu-su)))
      (bunsetu-length-henko (1+ (bunsetu-length *bunsetu-number*)))))

(defun henkan-saishou-bunsetu ()
  (interactive)
  (bunsetu-length-henko 1))

(defun henkan-saichou-bunsetu ()
  (interactive)
  (let ((max (bunsetu-su)) (i *bunsetu-number*)
	(l 0))
    (while (< i max)
      (setq l (+ l (bunsetu-length i)))
      (setq i (1+ i)))
    (bunsetu-length-henko l)))

(defun bunsetu-length-henko (length)
  (let ((r (KKCP:bunsetu-henkou *bunsetu-number* length)))
    (cond(r
	  (delete-region 
	   (bunsetu-position *bunsetu-number*) egg:*region-end*)
	  (goto-char (bunsetu-position *bunsetu-number*))
	  (henkan-insert-kouho *bunsetu-number*)
	  (henkan-goto-bunsetu *bunsetu-number*))
	 (t
	  (egg:bunsetu-face-on *bunsetu-number*)))))

(defun henkan-quit ()
  (interactive)
  (egg:bunsetu-face-off)
  (egg:henkan-face-off)
  (delete-region (- egg:*region-start* (length egg:*henkan-open*))
		 egg:*region-start*)
  (delete-region egg:*region-start* egg:*region-end*)
  (delete-region egg:*region-end* (+ egg:*region-end* (length egg:*henkan-close*)))
  (goto-char egg:*region-start*)
  (insert egg:*fence-open*)
  (set-marker egg:*region-start* (point))
  (insert egg:*kanji-kanabuff*)
  (let ((point (point)))
    (insert egg:*fence-close*)
    (set-marker egg:*region-end* point)
    )
  (goto-char egg:*region-end*)
  (egg:fence-face-on)
  (KKCP:henkan-quit)
  (setq egg:*mode-on* t)
  ;;;(use-global-map fence-mode-map)
  ;;;(use-local-map  nil)
  (setq egg:henkan-mode-in-use nil)
  (use-local-map fence-mode-map)
  (egg:mode-line-display)
  )

(defun henkan-select-kouho ()
  (interactive)
  (if (not (eq (selected-window) (minibuffer-window)))
      (let ((kouho-list (bunsetu-kouho-list *bunsetu-number*))
	    menu)
	(setq menu
	      (list 'menu "$B<!8uJd(B:"
		    (let ((l kouho-list) (r nil) (i 0))
		      (while l
			(setq r (cons (cons (car l) i) r))
			(setq i (1+ i))
			(setq l (cdr l)))
		      (reverse r))))
	(henkan-goto-kouho 
	 (menu:select-from-menu menu 
			       (bunsetu-kouho-number *bunsetu-number*))))
    (beep)))

(defun henkan-kakutei-and-self-insert ()
  (interactive)
  (setq unread-command-events (list last-command-event))
  (henkan-kakutei))


(defvar henkan-mode-map (make-keymap))

(defvar henkan-mode-esc-map (make-keymap))

(let ((ch 0))
  (while (<= ch 127)
    (unless (eq ch 27)
      (define-key henkan-mode-map (make-string 1 ch) 'undefined))
    (define-key henkan-mode-esc-map (make-string 1 ch) 'undefined)
    (setq ch (1+ ch))))

(let ((ch 32))
  (while (< ch 127)
    (define-key henkan-mode-map (make-string 1 ch) 'henkan-kakutei-and-self-insert)
    (setq ch (1+ ch))))

(condition-case ()
    (define-key henkan-mode-map "\e"    henkan-mode-esc-map)
  (error nil))
(define-key henkan-mode-map "\ei"  'undefined) ;; henkan-inspect-bunsetu
					       ;; not support for sj3
(define-key henkan-mode-map "\es"  'henkan-select-kouho)
(define-key henkan-mode-map "\eh"  'henkan-hiragana)
(define-key henkan-mode-map "\ek"  'henkan-katakana)
(define-key henkan-mode-map "\e<"  'henkan-saishou-bunsetu)
(define-key henkan-mode-map "\e>"  'henkan-saichou-bunsetu)
(define-key henkan-mode-map " "    'henkan-next-kouho)
(define-key henkan-mode-map "\C-@" 'henkan-next-kouho)
(define-key henkan-mode-map "\C-a" 'henkan-first-bunsetu)
(define-key henkan-mode-map "\C-b" 'henkan-backward-bunsetu)
(define-key henkan-mode-map "\C-c" 'henkan-quit)
(define-key henkan-mode-map "\C-d" 'undefined)
(define-key henkan-mode-map "\C-e" 'henkan-last-bunsetu)
(define-key henkan-mode-map "\C-f" 'henkan-forward-bunsetu)
(define-key henkan-mode-map "\C-g" 'henkan-quit)
(define-key henkan-mode-map "\C-h" 'help-command)
(define-key henkan-mode-map "\C-i" 'henkan-bunsetu-chijime)
(define-key henkan-mode-map "\C-j" 'undefined)
(define-key henkan-mode-map "\C-k" 'henkan-kakutei-before-point)
(define-key henkan-mode-map "\C-l" 'henkan-kakutei)
(define-key henkan-mode-map "\C-m" 'henkan-kakutei)
(define-key henkan-mode-map "\C-n" 'henkan-next-kouho)
(define-key henkan-mode-map "\C-o" 'henkan-bunsetu-nobasi)
(define-key henkan-mode-map "\C-p" 'henkan-previous-kouho)
(define-key henkan-mode-map "\C-q" 'undefined)
(define-key henkan-mode-map "\C-r" 'undefined)
(define-key henkan-mode-map "\C-s" 'undefined)
(define-key henkan-mode-map "\C-t" 'undefined)
(define-key henkan-mode-map "\C-u" 'undefined)
(define-key henkan-mode-map "\C-v" 'undefined)
(define-key henkan-mode-map "\C-w" 'undefined)
(define-key henkan-mode-map "\C-x" 'undefined)
(define-key henkan-mode-map "\C-y" 'undefined)
(define-key henkan-mode-map "\C-z" 'undefined)
(define-key henkan-mode-map "\177" 'henkan-quit)

(defun henkan-help-command ()
  "Display documentation fo henkan-mode."
  (interactive)
  (with-output-to-temp-buffer "*Help*"
    (princ (substitute-command-keys henkan-mode-document-string))
    (print-help-return-message)))

(defvar henkan-mode-document-string "$B4A;zJQ49%b!<%I(B:
$BJ8@a0\F0(B
  \\[henkan-first-bunsetu]\t$B@hF,J8@a(B\t\\[henkan-last-bunsetu]\t$B8eHxJ8@a(B  
  \\[henkan-backward-bunsetu]\t$BD>A0J8@a(B\t\\[henkan-forward-bunsetu]\t$BD>8eJ8@a(B
$BJQ49JQ99(B
  $B<!8uJd(B    \\[henkan-previous-kouho]  \t$BA08uJd(B    \\[henkan-next-kouho]
  $BJ8@a?-$7(B  \\[henkan-bunsetu-nobasi]  \t$BJ8@a=L$a(B  \\[henkan-bunsetu-chijime]
  $BJQ498uJdA*Br(B  \\[henkan-select-kouho]
$BJQ493NDj(B
  $BA4J8@a3NDj(B  \\[henkan-kakutei]  \t$BD>A0J8@a$^$G3NDj(B  \\[henkan-kakutei-before-point]
$BJQ49Cf;_(B    \\[henkan-quit]
")

;;;----------------------------------------------------------------------
;;;
;;; Dictionary management Facility
;;;
;;;----------------------------------------------------------------------

;;;
;;; $B<-=qEPO?(B 
;;;

;;;;
;;;; User entry: toroku-region
;;;;

(defun remove-regexp-in-string (regexp string)
  (cond((not(string-match regexp string))
	string)
       (t(let ((str nil)
	     (ostart 0)
	     (oend   (match-beginning 0))
	     (nstart (match-end 0)))
	 (setq str (concat str (substring string ostart oend)))
	 (while (string-match regexp string nstart)
	   (setq ostart nstart)
	   (setq oend   (match-beginning 0))
	   (setq nstart (match-end 0))
	   (setq str (concat str (substring string ostart oend))))
	 str))))

(defun toroku-region (start end)
  (interactive "r")
  (let*((kanji
	 (remove-regexp-in-string "[\0-\37]" (buffer-substring start end)))
	(yomi (read-hiragana-string
	       (format "$B<-=qEPO?!X(B%s$B!Y(B  $BFI$_(B :" kanji)))
	(type (menu:select-from-menu *sj3-bunpo-menu*))
	(dict-no 
	 (menu:select-from-menu (list 'menu "$BEPO?<-=qL>(B:" egg:*dict-menu*))))
    ;;;(if (string-match "[\0-\177]" kanji)
    ;;;	(error "Kanji string contains hankaku character. %s" kanji))
    ;;;(if (string-match "[\0-\177]" yomi)
    ;;;	(error "Yomi string contains hankaku character. %s" yomi))
    (KKCP:dict-add dict-no kanji yomi type)
    (let ((hinshi (nth 1 (assq type *sj3-bunpo-code*)))
	  (gobi   (nth 2 (assq type *sj3-bunpo-code*)))
	  (dict-name (cdr (assq dict-no egg:*usr-dict*))))
      (notify "$B<-=q9`L\!X(B%s$B!Y(B(%s: %s)$B$r(B%s$B$KEPO?$7$^$7$?!#(B"
	      (if gobi (concat kanji " " gobi) kanji)
	      (if gobi (concat yomi  " " gobi) yomi)
	      hinshi dict-name))))



;;; (lsh 1 18)
(defvar *sj3-bunpo-menu*
  '(menu "$BIJ;l(B:"
   (("$BL>;l(B"      .
     (menu "$BIJ;l(B:$BL>;l(B:"
	   (("$BL>;l(B"		. 1)
	    ("$BL>;l(B($B$*!D(B)"	. 2)
	    ("$BL>;l(B($B$4!D(B)"	. 3)
	    ("$BL>;l(B($B!DE*(B/$B2=(B)"	. 4)
	    ("$BL>;l(B($B$*!D$9$k(B)"	. 5)
	    ("$BL>;l(B($B!D$9$k(B)"	. 6)
	    ("$BL>;l(B($B$4!D$9$k(B)"	. 7)
	    ("$BL>;l(B($B!D$J(B/$B$K(B)"	. 8)
	    ("$BL>;l(B($B$*!D$J(B/$B$K(B)"	. 9)
	    ("$BL>;l(B($B$4!D$J(B/$B$K(B)"	. 10)
	    ("$BL>;l(B($BI{;l(B)"	. 11))))
    ("$BBeL>;l(B"    . 12)
    ("$BID;z(B"      . 21)
    ("$BL>A0(B"      . 22)
    ("$BCOL>(B"      . 24)
    ("$B8)(B/$B6hL>(B"   . 25)
    ("$BF0;l(B"      .
	  (menu "$BIJ;l(B:$BF0;l(B:"
		(("$B%5JQ8l44(B"      . 80)
		 ("$B%6JQ8l44(B"      . 81)
		 ("$B0lCJITJQ2=It(B"  . 90)
		 ("$B%+9T8^CJ8l44(B"  . 91)
		 ("$B%,9T8^CJ8l44(B"  . 92)   
		 ("$B%59T8^CJ8l44(B"  . 93)   
		 ("$B%?9T8^CJ8l44(B"  . 94)   
		 ("$B%J9T8^CJ8l44(B"  . 95)   
		 ("$B%P9T8^CJ8l44(B"  . 96)   
		 ("$B%^9T8^CJ8l44(B"  . 97)   
		 ("$B%i9T8^CJ8l44(B"  . 98)   
		 ("$B%o9T8^CJ8l44(B"  . 99))))   
    ("$BO"BN;l(B"         . 26)
    ("$B@\B3;l(B"         . 27)
    ("$B=u?t;l(B"         . 29)
    ("$B?t;l(B"           . 30)
    ("$B@\F,8l(B"         . 31)
    ("$B@\Hx8l(B"         . 36)
    ("$BI{;l(B"           . 45)
    ("$BI{;l(B2"          . 46)
    ("$B7AMF;l8l44(B"     . 60)
    ("$B7AMFF0;l8l44(B"   . 71)
    ("$BC14A;z(B"         . 189))))

(defvar *sj3-bunpo-code*
  '(
    ( 1   "$BL>;l(B" )
    ( 2   "$BL>;l(B($B$*!D(B)" )
    ( 3   "$BL>;l(B($B$4!D(B)" )
    ( 4   "$BL>;l(B($B!DE*(B/$B2=(B)" "$BE*(B" nil)
    ( 5   "$BL>;l(B($B$*!D$9$k(B)" "$B$9$k(B" nil)
    ( 6   "$BL>;l(B($B!D$9$k(B)" "$B$9$k(B" nil)
    ( 7   "$BL>;l(B($B$4!D$9$k(B)" "$B$9$k(B" nil)
    ( 8   "$BL>;l(B($B!D$J(B/$B$K(B)" "$B$J(B/$B$K(B" nil)
    ( 9   "$BL>;l(B($B$*!D$J(B/$B$K(B)" "$B$J(B/$B$K(B" nil)
    ( 10  "$BL>;l(B($B$4!D$J(B/$B$K(B)" "$B$J(B/$B$K(B" nil)
    ( 11  "$BL>;l(B($BI{;l(B)" )
    ( 12  "$BBeL>;l(B" )
    ( 21  "$BID;z(B" )
    ( 22  "$BL>A0(B" )
    ( 24  "$BCOL>(B" )
    ( 25  "$B8)(B/$B6hL>(B" )
    ( 26  "$BO"BN;l(B" )
    ( 27  "$B@\B3;l(B" )
    ( 29  "$B=u?t;l(B" )
    ( 30  "$B?t;l(B"   )
    ( 31  "$B@\F,8l(B" )
    ( 36  "$B@\Hx8l(B" )
    ( 45  "$BI{;l(B" )
    ( 46  "$BI{;l(B2" )
    ( 60  "$B7AMF;l8l44(B"           "$B$$(B" ("" "" "" "" ""))
    ( 71  "$B7AMFF0;l8l44(B"         "$B$K(B" ("" "" "" "" "") )
    ( 80  "$B%5JQ8l44(B"             "$B$9$k(B" ("" "" "" "" ""))
    ( 81  "$B%6JQ8l44(B"             "$B$:$k(B" ("" "" "" "" ""))
    ( 90  "$B0lCJITJQ2=It(B"         "$B$k(B" ("" "" "" "" ""))
    ( 91  "$B%+9T8^CJ8l44(B"         "$B$/(B" ("$B$+$J$$(B" "$B$-$^$9(B" "$B$/(B" "$B$/$H$-(B" "$B$1(B"))
    ( 92  "$B%,9T8^CJ8l44(B"         "$B$0(B" ("$B$,$J$$(B" "$B$.$^$9(B" "" "" ""))
    ( 93  "$B%59T8^CJ8l44(B"         "$B$9(B" ("" "" "" "" ""))
    ( 94  "$B%?9T8^CJ8l44(B"         "$B$D(B" ("" "" "" "" ""))
    ( 95  "$B%J9T8^CJ8l44(B"         "$B$L(B" ("" "" "" "" ""))   
    ( 96  "$B%P9T8^CJ8l44(B"         "$B$V(B" ("" "" "" "" ""))   
    ( 97  "$B%^9T8^CJ8l44(B"         "$B$`(B" ("" "" "" "" ""))   
    ( 98  "$B%i9T8^CJ8l44(B"         "$B$k(B" ("" "" "" "" ""))   
    ( 99  "$B%o9T8^CJ8l44(B"         "$B$&(B" ("" "" "" "" ""))   
    ( 189  "$BC14A;z(B"  )
    ( 190  "$BITDj(B"  )
    ( 1000  "$B$=$NB>(B"  )
    ))

;;;
;;; $B<-=qJT=87O(B DicEd
;;;

(defvar *diced-window-configuration* nil)

(defvar *diced-dict-info* nil)

(defvar *diced-dno* nil)

;;;;;
;;;;; User entry : edit-dict
;;;;;

(defun edit-dict ()
  (interactive)
  (let*((dict-no 
	 (menu:select-from-menu (list 'menu "$B<-=qL>(B:" egg:*dict-menu*)))
	(dict-name (file-name-nondirectory 
		    (cdr (assq dict-no egg:*usr-dict*))))
	(dict-info (KKCP:dict-info dict-no)))
    (if (null dict-info)
	(message "$B<-=q(B: %s $B$KEPO?$5$l$F$$$k9`L\$O$"$j$^$;$s!#(B" dict-name)
      (progn
	(setq *diced-dno* dict-no)
	(setq *diced-window-configuration* (current-window-configuration))
	(pop-to-buffer "*Nihongo Dictionary Information*")
	(setq major-mode 'diced-mode)
	(setq mode-name "Diced")
	(setq mode-line-buffer-identification 
	      (concat "DictEd: " dict-name
		      (make-string  
		       (max 0 (- 17 (string-width dict-name))) ?  )
		      ))
	(sit-for 0) ;; will redislay.
	;;;(use-global-map diced-mode-map)
	(use-local-map diced-mode-map)
	(diced-display dict-info)
	))))

(defun diced-redisplay ()
  (let ((dict-info (KKCP:dict-info *diced-dno*)))
    (if (null dict-info)
	(progn
	  (message "$B<-=q(B: %s $B$KEPO?$5$l$F$$$k9`L\$O$"$j$^$;$s!#(B"
		   (file-name-nondirectory 
		    (cdr (assq *diced-dno* egg:*usr-dict*))))
	  (diced-quit))
      (diced-display dict-info))))

(defun diced-display (dict-info)
	;;; (values (list (record yomi kanji bunpo)))
	;;;                         0    1     2
  (setq *diced-dict-info* dict-info)
  (setq buffer-read-only nil)
  (erase-buffer)
  (let ((l-yomi
	 (apply 'max
		(mapcar (function (lambda (l) (string-width (nth 0 l))))
			dict-info)))
	(l-kanji 
	 (apply 'max
		(mapcar (function (lambda (l) (string-width (nth 1 l))))
			dict-info))))
    (while dict-info
      (let*((yomi (nth 0 (car dict-info)))
	    (kanji (nth 1 (car dict-info)))
	    (bunpo (nth 2 (car dict-info)))
	    (gobi   (nth 2 (assq bunpo *sj3-bunpo-code*)))
	    (hinshi (nth 1 (assq bunpo *sj3-bunpo-code*))))

	(insert "  " yomi)
	(if gobi (insert " " gobi))
	(insert-char ?  
		     (- (+ l-yomi 10) (string-width yomi)
			(if gobi (+ 1 (string-width gobi)) 0)))
	(insert kanji)
	(if gobi (insert " " gobi))
	(insert-char ?  
		     (- (+ l-kanji 10) (string-width kanji)
			(if gobi (+ 1 (string-width gobi)) 0)))
	(insert hinshi ?\n)
	(setq dict-info (cdr dict-info))))
    (goto-char (point-min)))
  (setq buffer-read-only t))

(defun diced-add ()
  (interactive)
  (diced-execute t)
  (let*((kanji (read-kanji-string "$B4A;z!'(B"))
	(yomi (read-hiragana-string "$BFI$_!'(B"))
	(bunpo (menu:select-from-menu *sj3-bunpo-menu*))
	(gobi   (nth 2 (assq bunpo *sj3-bunpo-code*)))
	(hinshi (nth 1 (assq bunpo *sj3-bunpo-code*)))
	(item (if gobi (concat kanji " " gobi) kanji))
	(item-yomi (if gobi (concat yomi " " gobi) yomi))
	(dict-name (cdr (assq *diced-dno* egg:*usr-dict*))))
    (if (notify-yes-or-no-p "$B<-=q9`L\!X(B%s$B!Y(B(%s: %s)$B$r(B%s$B$KEPO?$7$^$9!#(B" 
	      item item-yomi hinshi (file-name-nondirectory dict-name))
	(progn
	  (KKCP:dict-add *diced-dno* kanji yomi bunpo)
	  (notify "$B<-=q9`L\!X(B%s$B!Y(B(%s: %s)$B$r(B%s$B$KEPO?$7$^$7$?!#(B" 
		  item item-yomi hinshi dict-name)
	  (diced-redisplay)))))

(defun diced-delete ()
  (interactive)
  (beginning-of-line)
  (if (eq (char-after) ?  )
      (let ((buffer-read-only nil))
	(delete-char 1) (insert "D") (backward-char 1))))

(defun diced-undelete ()
  (interactive)
  (beginning-of-line)
  (if (eq (char-after) ?D)
      (let ((buffer-read-only nil))
	(delete-char 1) (insert " ") (backward-char 1))
    (beep)))

(defun diced-quit ()
  (interactive)
  (setq buffer-read-only nil)
  (erase-buffer)
  (setq buffer-read-only t)
  (bury-buffer (get-buffer "*Nihongo Dictionary Information*"))
  (set-window-configuration *diced-window-configuration*)
  )

(defun diced-execute (&optional display)
  (interactive)
  (goto-char (point-min))
  (let ((no  0))
    (while (not (eobp))
      (if (eq (char-after) ?D)
	  (let* ((dict-item (nth no *diced-dict-info*))
		 (yomi (nth 0 dict-item))
		 (kanji (nth 1 dict-item))
		 (bunpo (nth 2 dict-item))
		 (gobi   (nth 2 (assq bunpo *sj3-bunpo-code*)))
		 (hinshi (nth 1 (assq bunpo *sj3-bunpo-code*)))
		 (dict-name (cdr (assq *diced-dno* egg:*usr-dict*)))
		 (item (if gobi (concat kanji " " gobi) kanji))
		 (item-yomi (if gobi (concat yomi " " gobi) yomi)))
	    (if (notify-yes-or-no-p "$B<-=q9`L\!X(B%s$B!Y(B(%s: %s)$B$r(B%s$B$+$i:o=|$7$^$9!#(B"
				item item-yomi hinshi (file-name-nondirectory 
						       dict-name))
		(progn
		  (KKCP:dict-delete *diced-dno* kanji yomi bunpo)
		  (notify "$B<-=q9`L\!X(B%s$B!Y(B(%s: %s)$B$r(B%s$B$+$i:o=|$7$^$7$?!#(B"
			  item item-yomi hinshi dict-name)
		  ))))
      (setq no (1+ no))
      (forward-line 1)))
  (forward-line -1)
  (if (not display) (diced-redisplay)))

(defun diced-next-line ()
  (interactive)
  (beginning-of-line)
  (forward-line 1)
  (if (eobp) (progn (beep) (forward-line -1))))

(defun diced-end-of-buffer ()
  (interactive)
  (end-of-buffer)
  (forward-line -1))

(defun diced-scroll-down ()
  (interactive)
  (scroll-down)
  (if (eobp) (forward-line -1)))

(defun diced-mode ()
  "Mode for \"editing\" dictionaries.
In diced, you are \"editing\" a list of the entries in dictionaries.
You can move using the usual cursor motion commands.
Letters no longer insert themselves. Instead, 

Type  a to Add new entry.
Type  d to flag an entry for Deletion.
Type  n to move cursor to Next entry.
Type  p to move cursor to Previous entry.
Type  q to Quit from DicEd.
Type  u to Unflag an entry (remove its D flag).
Type  x to eXecute the deletions requested.
"
 )

(defvar diced-mode-map (let ((map (make-keymap))) (suppress-keymap map) map))

(define-key diced-mode-map "a"    'diced-add)
(define-key diced-mode-map "d"    'diced-delete)
(define-key diced-mode-map "n"    'diced-next-line)
(define-key diced-mode-map "p"    'previous-line)
(define-key diced-mode-map "q"    'diced-quit)
(define-key diced-mode-map "u"    'diced-undelete)
(define-key diced-mode-map "x"    'diced-execute)

(define-key diced-mode-map "\C-h" 'help-command)
(define-key diced-mode-map "\C-n" 'diced-next-line)
(define-key diced-mode-map "\C-p" 'previous-line)
(define-key diced-mode-map "\C-v" 'scroll-up)
(define-key diced-mode-map "\e<"  'beginning-of-buffer)
(define-key diced-mode-map "\e>"  'diced-end-of-buffer)
(define-key diced-mode-map "\ev"  'diced-scroll-down)

;;; egg-sj3.el ends here
