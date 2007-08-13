;; Utility for HankakuKana (jisx0201)

;; This file is part of Egg on Mule (Japanese Environment)

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

;;; 92.9.24  created for Mule Ver.0.9.6 by K.Shibata <shibata@sgi.co.jp>
;;; 93.8.3   modified for Mule Ver.1.1 by K.Handa <handa@etl.go.jp>
;;;	Not to define regexp of Japanese word in this file.

(require 'egg)
(provide 'egg-jisx0201)

(defvar *katakana-alist*
  '(( 161 . "(I'(B" )
    ( 162 . "(I1(B" )
    ( 163 . "(I((B" )
    ( 164 . "(I2(B" )
    ( 165 . "(I)(B" )
    ( 166 . "(I3(B" )
    ( 167 . "(I*(B" )
    ( 168 . "(I4(B" )
    ( 169 . "(I+(B" )
    ( 170 . "(I5(B" )
    ( 171 . "(I6(B" )
    ( 172 . "(I6^(B" )
    ( 173 . "(I7(B" )
    ( 174 . "(I7^(B" )
    ( 175 . "(I8(B" )
    ( 176 . "(I8^(B" )
    ( 177 . "(I9(B" )
    ( 178 . "(I9^(B" )
    ( 179 . "(I:(B" )
    ( 180 . "(I:^(B" )
    ( 181 . "(I;(B" )
    ( 182 . "(I;^(B" )
    ( 183 . "(I<(B" )
    ( 184 . "(I<^(B" )
    ( 185 . "(I=(B" )
    ( 186 . "(I=^(B" )
    ( 187 . "(I>(B" )
    ( 188 . "(I>^(B" )
    ( 189 . "(I?(B" )
    ( 190 . "(I?^(B" )
    ( 191 . "(I@(B" )
    ( 192 . "(I@^(B" )
    ( 193 . "(IA(B" )
    ( 194 . "(IA^(B" )
    ( 195 . "(I/(B" )
    ( 196 . "(IB(B" )
    ( 197 . "(IB^(B" )
    ( 198 . "(IC(B" )
    ( 199 . "(IC^(B" )
    ( 200 . "(ID(B" )
    ( 201 . "(ID^(B" )
    ( 202 . "(IE(B" )
    ( 203 . "(IF(B" )
    ( 204 . "(IG(B" )
    ( 205 . "(IH(B" )
    ( 206 . "(II(B" )
    ( 207 . "(IJ(B" )
    ( 208 . "(IJ^(B" )
    ( 209 . "(IJ_(B" )
    ( 210 . "(IK(B" )
    ( 211 . "(IK^(B" )
    ( 212 . "(IK_(B" )
    ( 213 . "(IL(B" )
    ( 214 . "(IL^(B" )
    ( 215 . "(IL_(B" )
    ( 216 . "(IM(B" )
    ( 217 . "(IM^(B" )
    ( 218 . "(IM_(B" )
    ( 219 . "(IN(B" )
    ( 220 . "(IN^(B" )
    ( 221 . "(IN_(B" )
    ( 222 . "(IO(B" )
    ( 223 . "(IP(B" )
    ( 224 . "(IQ(B" )
    ( 225 . "(IR(B" )
    ( 226 . "(IS(B" )
    ( 227 . "(I,(B" )
    ( 228 . "(IT(B" )
    ( 229 . "(I-(B" )
    ( 230 . "(IU(B" )
    ( 231 . "(I.(B" )
    ( 232 . "(IV(B" )
    ( 233 . "(IW(B" )
    ( 234 . "(IX(B" )
    ( 235 . "(IY(B" )
    ( 236 . "(IZ(B" )
    ( 237 . "(I[(B" )
    ( 239 . "(I\(B" ) ; (I\(B -> $B%o(B $B$KJQ49$9$k$h$&$K(B
    ( 238 . "(I\(B" ) ; $B%o$H%n$N=gHV$,8r49$7$F$"$k!#(B
    ( 240 . "(I((B" )
    ( 241 . "(I*(B" )
    ( 242 . "(I&(B" )
    ( 243 . "(I](B" )
    ( 244 . "(I3^(B" )
    ( 245 . "(I6(B" )
    ( 246 . "(I9(B" )))

(defvar *katakana-kigou-alist*
  '(( 162 . "(I$(B" )
    ( 163 . "(I!(B" )
    ( 166 . "(I%(B" )
    ( 171 . "(I^(B" )
    ( 172 . "(I_(B" )
    ( 188 . "(I0(B" )
    ( 214 . "(I"(B" )
    ( 215 . "(I#(B" )))

(defvar *dakuon-list*
  '( ?$B%+(B ?$B%-(B ?$B%/(B ?$B%1(B ?$B%3(B
     ?$B%5(B ?$B%7(B ?$B%9(B ?$B%;(B ?$B%=(B
     ?$B%?(B ?$B%A(B ?$B%D(B ?$B%F(B ?$B%H(B
     ?$B%O(B ?$B%R(B ?$B%U(B ?$B%X(B ?$B%[(B))

(defvar *handakuon-list* (memq ?$B%O(B *dakuon-list*))

;;;
;;; $BH>3QJQ49(B
;;; 

(defun hankaku-katakana-region (start end &optional arg)
  (interactive "r\nP")
  (save-restriction
    (narrow-to-region start end)
    (goto-char (point-min))
    (let ((regexp (if arg "\\cS\\|\\cK\\|\\cH" "\\cS\\|\\cK")))
      (while (re-search-forward regexp (point-max) (point-max))
	(let* ((ch (char-to-int (char-before)))
	       (ch1 (/ ch 256))
	       (ch2 (mod ch 256)))
	  (cond ((= 208 ch1)
		 (let ((val (cdr (assq ch2 *katakana-kigou-alist*))))
		   (if val (progn
			     (delete-char -1)
			     (insert val)))))
		((or (= 209 ch1) (= 215 ch1))
		 nil)
		(t
		 (let ((val (cdr (assq ch2 *katakana-alist*))))
		   (if val (progn
			     (delete-char -1)
			     (insert val)))))))))))

(defun hankaku-katakana-paragraph ()
  "hankaku-katakana paragraph at or after point."
  (interactive )
  (save-excursion
    (forward-paragraph)
    (let ((end (point)))
      (backward-paragraph)
      (hankaku-katakana-region (point) end ))))

(defun hankaku-katakana-sentence ()
  "hankaku-katanaka sentence at or after point."
  (interactive )
  (save-excursion
    (forward-sentence)
    (let ((end (point)))
      (backward-sentence)
      (hankaku-katakana-region (point) end ))))

(defun hankaku-katakana-word (arg)
  (interactive "p")
  (let ((start (point)))
    (forward-word arg)
    (hankaku-katakana-region start (point))))

;;;
;;; $BA43QJQ49(B
;;;
(defun search-henkan-alist (ch list)
  (let ((ptr list)
	(result nil))
    (while ptr
      (if (string= ch (cdr (car ptr)))
	  (progn
	    (setq result (car (car ptr)))
	    (setq ptr nil))
	(setq ptr (cdr ptr))))
    result))

(defun zenkaku-katakana-region (start end)
  (interactive "r")
  (save-restriction
    (narrow-to-region start end)
    (goto-char (point-min))
    (while (re-search-forward "\\ck" (point-max) (point-max))
      (let ((ch (preceding-char))
	    (wk nil))
	(cond
	 ((= ch ?(I^(B)
	  (save-excursion
	    (backward-char 1)
	    (setq wk (preceding-char)))
	  (cond ((= wk ?$B%&(B)
		 (delete-char -2)
		 (insert "$B%t(B"))
		((setq wk (memq wk *dakuon-list*))
		 (delete-char -2)
		 (insert (1+ (car wk))))
		(t
		 (delete-char -1)
		 (insert "$B!+(B"))))
	 ((= ch ?(I_(B)
	  (save-excursion
	    (backward-char 1)
	    (setq wk (preceding-char)))
	  (if (setq wk (memq wk *handakuon-list*))
	      (progn
		(delete-char -2)
		(insert (+ 2 (car wk))))
	    (progn
	      (delete-char -1)
	      (insert "$B!,(B"))))
	 ((setq wk (search-henkan-alist
		    (char-to-string ch) *katakana-alist*))
	  (progn
	    (delete-char -1)
	    (insert (make-char 'japanese-jisx0208 37 (- wk 128)))))
	 ((setq wk (search-henkan-alist
		    (char-to-string ch) *katakana-kigou-alist*))
	  (progn
	    (delete-char -1)
	    (insert (make-char 'japanese-jisx0208 33 (- wk 128))))))))))

(defun zenkaku-katakana-paragraph ()
  "zenkaku-katakana paragraph at or after point."
  (interactive )
  (save-excursion
    (forward-paragraph)
    (let ((end (point)))
      (backward-paragraph)
      (zenkaku-katakana-region (point) end ))))

(defun zenkaku-katakana-sentence ()
  "zenkaku-katakana sentence at or after point."
  (interactive )
  (save-excursion
    (forward-sentence)
    (let ((end (point)))
      (backward-sentence)
      (zenkaku-katakana-region (point) end ))))

(defun zenkaku-katakana-word (arg)
  (interactive "p")
  (let ((start (point)))
    (forward-word arg)
    (zenkaku-katakana-region start (point))))

;;;
;;;  JISX 0201 fence mode
;;;

(defun fence-hankaku-katakana  ()
  (interactive)
  (hankaku-katakana-region egg:*region-start* egg:*region-end* t))

(defun fence-katakana  ()
  (interactive)
  (zenkaku-katakana-region egg:*region-start* egg:*region-end* )
  (katakana-region egg:*region-start* egg:*region-end*))

(defun fence-hiragana  ()
  (interactive)
  (zenkaku-katakana-region egg:*region-start* egg:*region-end*)
  (hiragana-region egg:*region-start* egg:*region-end*))

(define-key fence-mode-map "\ex"  'fence-hankaku-katakana)
