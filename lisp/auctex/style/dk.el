;;; dk.el - Setup AUC TeX for editing Danish text.

;; $Id: dk.el,v 1.1 1997/02/20 02:15:42 steve Exp $

;;; Code:

(TeX-add-style-hook "dk"
 (function (lambda ()
   (run-hooks 'TeX-language-dk-hook))))

;;; dk.el ends here