;;; widget-edit.el --- Functions for creating and using widgets.
;;
;; Copyright (C) 1996 Free Software Foundation, Inc.
;;
;; Author: Per Abrahamsen <abraham@dina.kvl.dk>
;; Keywords: help, extensions, faces, hypermedia
;; Version: 0.4

;;; Commentary:
;;
;; See `widget.el'.

;;; Code:

(require 'widget)
(require 'cl)

;;; Compatibility.

(or (fboundp 'event-point)
    ;; XEmacs function missing in Emacs.
    (defun event-point (event)
      "Return the character position of the given mouse-motion, button-press,
or button-release event.  If the event did not occur over a window, or did
not occur over text, then this returns nil.  Otherwise, it returns an index
into the buffer visible in the event's window."
      (posn-point (event-start event))))

(or (fboundp 'set-keymap-parent)
    ;; Xemacs function missing in Emacs.
    ;; Definition stolen from `lucid.el'.
    (defun set-keymap-parent (keymap new-parent)
      (let ((tail keymap))
	(while (and tail (cdr tail) (not (eq (car (cdr tail)) 'keymap)))
	  (setq tail (cdr tail)))
	(if tail
	    (setcdr tail new-parent)))))

;;; Customization.
;;
;; These should be specified with the custom package.

(defvar widget-button-face 'bold)
(defvar widget-mouse-face 'highlight)
(defvar widget-field-face 'italic)

(defvar widget-motion-hook nil
  "*Hook to be run after widget traversal (via `widget-forward|backward').
The hooks will all be called with on argument - the widget that was just
selected.")

;;; Utility functions.
;;
;; These are not really widget specific.

(defun widget-plist-member (plist prop)
  ;; Return non-nil if PLIST has the property PROP.
  ;; PLIST is a property list, which is a list of the form
  ;; (PROP1 VALUE1 PROP2 VALUE2 ...).  PROP is a symbol.
  ;; Unlike `plist-get', this allows you to distinguish between a missing
  ;; property and a property with the value nil.
  ;; The value is actually the tail of PLIST whose car is PROP.
  (while (and plist (not (eq (car plist) prop)))
    (setq plist (cdr (cdr plist))))
  plist)

(defun widget-princ-to-string (object)
  ;; Return string representation of OBJECT, any Lisp object.
  ;; No quoting characters are used; no delimiters are printed around
  ;; the contents of strings.
  (save-excursion
    (set-buffer (get-buffer-create " *widget-tmp*"))
    (erase-buffer)
    (let ((standard-output (current-buffer)))
      (princ object))
    (buffer-string)))

(defun widget-clear-undo ()
  "Clear all undo information."
  (buffer-disable-undo (current-buffer))
  (buffer-enable-undo))

;;; Widget text specifications.
;; 
;; These functions are for specifying text properties. 

(defun widget-specify-none (from to)
  ;; Clear all text properties between FROM and TO.
  (set-text-properties from to nil))

(defun widget-specify-text (from to)
  ;; Default properties.
  (add-text-properties from to (list 'read-only t
				     'front-sticky t
				     'rear-nonsticky nil)))

(defun widget-specify-field (widget from to)
  ;; Specify editable button for WIDGET between FROM and TO.
  (widget-specify-field-update widget from to)
  ;; Make it possible to edit both end of the field.
  (add-text-properties (1- from) from (list 'rear-nonsticky t
					    'end-open t
					    'invisible t))
  (add-text-properties to (1+ to) (list 'font-sticky nil
					'start-open t)))

(defun widget-specify-field-update (widget from to)
  ;; Specify editable button for WIDGET between FROM and TO.
  (let ((map (widget-get widget :keymap))
	(face (or (widget-get widget :value-face)
		  widget-field-face)))
    (add-text-properties from to (list 'field widget
				       'read-only nil
				       'local-map map
				       'keymap map
				       'face widget-field-face))))

(defun widget-specify-button (widget from to)
  ;; Specify button for WIDGET between FROM and TO.
  (let ((face (or (widget-get widget :button-face)
		  widget-button-face)))
    (add-text-properties from to (list 'button widget
				       'mouse-face widget-mouse-face
				       'face face))))

(defun widget-specify-doc (widget from to)
  ;; Specify documentation for WIDGET between FROM and TO.
  (put-text-property from to 'widget-doc widget))


(defmacro widget-specify-insert (&rest form)
  ;; Execute FORM without inheriting any text properties.
  (`
   (save-restriction
     (let ((inhibit-read-only t)
	   result
	   after-change-functions)
       (insert "<>")
       (narrow-to-region (- (point) 2) (point))
       (widget-specify-none (point-min) (point-max))
       (goto-char (1+ (point-min)))
       (setq result (progn (,@ form)))
       (delete-region (point-min) (1+ (point-min)))
       (delete-region (1- (point-max)) (point-max))
       (goto-char (point-max))
       result))))

;;; Widget Properties.

(defun widget-put (widget property value)
  "In WIDGET set PROPERTY to VALUE.
The value can later be retrived with `widget-get'."
  (setcdr widget (plist-put (cdr widget) property value)))

(defun widget-get (widget property)
  "In WIDGET, get the value of PROPERTY.
The value could either be specified when the widget was created, or
later with `widget-put'."
  (cond ((widget-plist-member (cdr widget) property)
	 (plist-get (cdr widget) property))
	((car widget)
	 (widget-get (get (car widget) 'widget-type) property))
	(t nil)))

(defun widget-member (widget property)
  "Non-nil iff there is a definition in WIDGET for PROPERTY."
  (cond ((widget-plist-member (cdr widget) property)
	 t)
	((car widget)
	 (widget-member (get (car widget) 'widget-type) property))
	(t nil)))

(defun widget-apply (widget property &rest args)
  "Apply the value of WIDGET's PROPERTY to the widget itself.
ARGS are passed as extra argments to the function."
  (apply (widget-get widget property) widget args))

(defun widget-value (widget)
  "Extract the current value of WIDGET."
  (widget-apply widget
		:value-to-external (widget-apply widget :value-get)))

(defun widget-value-set (widget value)
  "Set the current value of WIDGET to VALUE."
  (widget-apply widget
		:value-set (widget-apply widget
					 :value-to-internal value)))

(defun widget-match-inline (widget values)
  ;; Match the head of values.
  (cond ((widget-get widget :inline)
	 (widget-apply widget :match-inline values))
	((widget-apply widget :match (car values))
	 (cons (list (car values)) (cdr values)))
	(t nil)))

;;; Creating Widgets.

(defun widget-create (type &rest args)
  "Create widget of TYPE.  
The optional ARGS are additional keyword arguments."
  (let ((widget (apply 'widget-convert type args)))
    (widget-apply widget :create)
    widget))

(defun widget-delete (widget)
  "Delete WIDGET."
  (widget-apply widget :delete))

(defun widget-convert (type &rest args)
  "Convert TYPE to a widget without inserting it in the buffer. 
The optional ARGS are additional keyword arguments."
  ;; Don't touch the type.
  (let* ((widget (if (symbolp type) 
		     (list type)
		   (copy-list type)))
	 (current widget)
	 (keys args))
    ;; First set the :args keyword.
    (while (cdr current)		;Look in the type.
      (let ((next (car (cdr current))))
	(if (and (symbolp next) (eq (aref (symbol-name next) 0) ?:))
	    (setq current (cdr (cdr current)))
	  (setcdr current (list :args (cdr current)))
	  (setq current nil))))
    (while args				;Look in the args.
      (let ((next (nth 0 args)))
	(if (and (symbolp next) (eq (aref (symbol-name next) 0) ?:))
	    (setq args (nthcdr 2 args))
	  (widget-put widget :args args)
	  (setq args nil))))
    ;; Then Convert the widget.
    (setq type widget)
    (while type
      (let ((convert-widget (widget-get type :convert-widget)))
	(if convert-widget
	    (setq widget (funcall convert-widget widget))))
      (setq type (get (car type) 'widget-type)))
    ;; Finally set the keyword args.
    (while keys 
      (let ((next (nth 0 keys)))
	(if (and (symbolp next) (eq (aref (symbol-name next) 0) ?:))
	    (progn 
	      (widget-put widget next (nth 1 keys))
	      (setq keys (nthcdr 2 keys)))
	  (setq keys nil))))
    ;; Return the newly create widget.
    widget))

(defun widget-insert (&rest args)
  "Call `insert' with ARGS and make the text read only."
  (let ((inhibit-read-only t)
	after-change-functions
	(from (point)))
    (apply 'insert args)
    (widget-specify-text from (point))))

;;; Keymap and Comands.

(defvar widget-keymap nil
  "Keymap containing useful binding for buffers containing widgets.
Recommended as a parent keymap for modes using widgets.")

(if widget-keymap 
    ()
  (setq widget-keymap (make-sparse-keymap))
  (set-keymap-parent widget-keymap global-map)
  (define-key widget-keymap "\t" 'widget-forward)
  (define-key widget-keymap "\M-\t" 'widget-backward)
  (define-key widget-keymap [(shift tab)] 'widget-backward)
  (if (string-match "XEmacs" (emacs-version))
      (define-key widget-keymap [button2] 'widget-button-click)
    (define-key widget-keymap [mouse-2] 'widget-button-click))
  (define-key widget-keymap "\C-m" 'widget-button-press))

(defvar widget-global-map global-map
  "Keymap used for events the widget does not handle themselves.")
(make-variable-buffer-local 'widget-global-map)

(defun widget-button-click (event)
  "Activate button below mouse pointer."
  (interactive "@e")
  (widget-button-press (event-point event) event))

(defun widget-button-press (pos &optional event)
  "Activate button at POS."
  (interactive "@d")
  (let* ((button (get-text-property pos 'button)))
    (if button
	(widget-apply button :action event)
      (call-interactively
       (lookup-key widget-global-map (this-command-keys))))))

(defun widget-forward (arg)
  "Move point to the next field or button.
With optional ARG, move across that many fields."
  (interactive "p")
  (while (> arg 0)
    (setq arg (1- arg))
    (let ((next (cond ((get-text-property (point) 'button)
		       (next-single-property-change (point) 'button))
		      ((get-text-property (point) 'field)
		       (next-single-property-change (point) 'field))
		      (t
		       (point)))))
      (if (null next)			; Widget extends to end. of buffer
	  (setq next (point-min)))
      (let ((button (next-single-property-change next 'button))
	    (field (next-single-property-change next 'field)))
	(cond ((or (get-text-property next 'button)
		   (get-text-property next 'field))
	       (goto-char next))
	      ((and button field)
	       (goto-char (min button field)))
	      (button (goto-char button))
	      (field (goto-char field))
	      (t
	       (let ((button (next-single-property-change (point-min) 'button))
		     (field (next-single-property-change (point-min) 'field)))
		 (cond ((and button field) (goto-char (min button field)))
		       (button (goto-char button))
		       (field (goto-char field))
		       (t
			(error "No buttons or fields found")))))))))
  (while (< arg 0)
    (if (= (point-min) (point))
	(forward-char 1))
    (setq arg (1+ arg))
    (let ((previous (cond ((get-text-property (1- (point)) 'button)
			   (previous-single-property-change (point) 'button))
			  ((get-text-property (1- (point)) 'field)
			   (previous-single-property-change (point) 'field))
			  (t
			   (point)))))
      (if (null previous)		; Widget extends to beg. of buffer
	  (setq previous (point-max)))
      (let ((button (previous-single-property-change previous 'button))
	    (field (previous-single-property-change previous 'field)))
	(cond ((and button field)
	       (goto-char (max button field)))
	      (button (goto-char button))
	      (field (goto-char field))
	      (t
	       (let ((button (previous-single-property-change
			      (point-max) 'button))
		     (field (previous-single-property-change
			     (point-max) 'field)))
		 (cond ((and button field) (goto-char (max button field)))
		       (button (goto-char button))
		       (field (goto-char field))
		       (t
			(error "No buttons or fields found"))))))))
    (let ((button (previous-single-property-change (point) 'button))
	  (field (previous-single-property-change (point) 'field)))
      (cond ((and button field)
	     (goto-char (max button field)))
	    (button (goto-char button))
	    (field (goto-char field)))))
  (run-hook-with-args 'widget-motion-hook (or
					   (get-text-property (point) 'button)
					   (get-text-property (point) 'field)))
  )

(defun widget-backward (arg)
  "Move point to the previous field or button.
With optional ARG, move across that many fields."
  (interactive "p")
  (widget-forward (- arg)))

;;; Setting up the buffer.

(defvar widget-field-new nil)
;; List of all newly created editable fields in the buffer.
(make-variable-buffer-local 'widget-field-new)

(defvar widget-field-list nil)
;; List of all editable fields in the buffer.
(make-variable-buffer-local 'widget-field-list)

(defun widget-setup ()
  "Setup current buffer so editing string widgets works."
  (let ((inhibit-read-only t)
	field)
    (while widget-field-new
      (setq field (car widget-field-new)
	    widget-field-new (cdr widget-field-new)
	    widget-field-list (cons field widget-field-list))
      (let ((from (widget-get field :value-from))
	    (to (widget-get field :value-to)))
	(widget-specify-field field from to)
	(move-marker from (1- from))
	(move-marker to (1+ to)))))
  (widget-clear-undo)
  ;; We need to maintain text properties and size of the editing fields.
  (make-local-variable 'after-change-functions)
  (if widget-field-list
      (setq after-change-functions '(widget-after-change))
    (setq after-change-functions nil)))

(defvar widget-field-last nil)
;; Last field containing point.
(make-variable-buffer-local 'widget-field-last)

(defvar widget-field-was nil)
;; The widget data before the change.
(make-variable-buffer-local 'widget-field-was)

(defun widget-field-find (pos)
  ;; Find widget whose editing field is located at POS.
  ;; Return nil if POS is not inside and editing field.
  ;; 
  ;; This is only used in `widget-field-modified', since ordinarily
  ;; you would just test the field property.
  (let ((fields widget-field-list)
	field found)
    (while fields
      (setq field (car fields)
	    fields (cdr fields))
      (let ((from (widget-get field :value-from))
	    (to (widget-get field :value-to)))
	(if (and from to (< from pos) (> to  pos))
	    (setq fields nil
		  found field))))
    found))

(defun widget-after-change (from to old)
  ;; Adjust field size and text properties.
  (condition-case nil
      (let ((field (widget-field-find from))
	    (inhibit-read-only t))
	(cond ((null field))
	      ((not (eq field (widget-field-find to)))
	       (message "Error: `widget-after-change' called on two fields"))
	      (t
	       (let ((size (widget-get field :size)))
		 (if size 
		     (let ((begin (1+ (widget-get field :value-from)))
			   (end (1- (widget-get field :value-to))))
		       (widget-specify-field-update field begin end)
		       (cond ((< (- end begin) size)
			      ;; Field too small.
			      (save-excursion
				(goto-char end)
				(insert-char ?\  (- (+ begin size) end))))
			     ((> (- end begin) size)
			      ;; Field too large and
			      (if (or (< (point) (+ begin size))
				      (> (point) end))
				  ;; Point is outside extra space.
				  (setq begin (+ begin size))
				;; Point is within the extra space.
				(setq begin (point)))
			      (save-excursion
				(goto-char end)
				(while (and (eq (preceding-char) ?\ )
					    (> (point) begin))
				  (delete-backward-char 1))))))
		   (widget-specify-field-update field from to)))
	       (widget-apply field :notify field))))
    (error (debug))))

;;; The `default' Widget.

(define-widget 'default nil
  "Basic widget other widgets are derived from."
  :value-to-internal (lambda (widget value) value)
  :value-to-external (lambda (widget value) value)
  :create 'widget-default-create
  :format-handler 'widget-default-format-handler
  :delete 'widget-default-delete
  :value-set 'widget-default-value-set
  :value-inline 'widget-default-value-inline
  :menu-tag-get 'widget-default-menu-tag-get
  :validate (lambda (widget) t)
  :action 'widget-default-action
  :notify 'widget-default-notify)

(defun widget-default-create (widget)
  "Create WIDGET at point in the current buffer."
  (widget-specify-insert
   (let ((from (point))
	 (tag (widget-get widget :tag))
	 (doc (widget-get widget :doc))
	 button-begin button-end
	 doc-begin doc-end
	 value-pos)
     (insert (widget-get widget :format))
     (goto-char from)
     ;; Parse % escapes in format.
     (while (re-search-forward "%\\(.\\)" nil t)
       (let ((escape (aref (match-string 1) 0)))
	 (replace-match "" t t)
	 (cond ((eq escape ?%)
		(insert "%"))
	       ((eq escape ?\[)
		(setq button-begin (point)))
	       ((eq escape ?\])
		(setq button-end (point)))
	       ((eq escape ?t)
		(if tag
		    (insert tag)
		  (let ((standard-output (current-buffer)))
		    (princ (widget-get widget :value)))))
	       ((eq escape ?d)
		(when doc
		  (setq doc-begin (point))
		  (insert doc)
		  (while (eq (preceding-char) ?\n)
		    (delete-backward-char 1))
		  (insert "\n")
		  (setq doc-end (point))))
	       ((eq escape ?v)
		(if (and button-begin (not button-end))
		    (widget-apply widget :value-create)
		  (setq value-pos (point))))
	       (t 
		(widget-apply widget :format-handler escape)))))
     ;; Specify button and doc, and insert value.
     (and button-begin button-end
	  (widget-specify-button widget button-begin button-end))
     (and doc-begin doc-end
	  (widget-specify-doc widget doc-begin doc-end))
     (when value-pos
       (goto-char value-pos)
       (widget-apply widget :value-create)))
   (let ((from (copy-marker (point-min)))
	 (to (copy-marker (point-max))))
     (widget-specify-text from to)
     (set-marker-insertion-type from t)
     (set-marker-insertion-type to nil)
     (widget-put widget :from from)
     (widget-put widget :to to))))

(defun widget-default-format-handler (widget escape)
  ;; By default unknown escapes are errors.
  (error "Unknown escape `%c'" escape))

(defun widget-default-delete (widget)
  ;; Remove widget from the buffer.
  (let ((from (widget-get widget :from))
	(to (widget-get widget :to))
	(inhibit-read-only t)
	after-change-functions)
    (widget-apply widget :value-delete)
    (delete-region from to)
    (set-marker from nil)
    (set-marker to nil)))

(defun widget-default-value-set (widget value)
  ;; Recreate widget with new value.
  (save-excursion
    (goto-char (widget-get widget :from))
    (widget-apply widget :delete)
    (widget-put widget :value value)
    (widget-apply widget :create)))

(defun widget-default-value-inline (widget)
  ;; Wrap value in a list unless it is inline.
  (if (widget-get widget :inline)
      (widget-value widget)
    (list (widget-value widget))))

(defun widget-default-menu-tag-get (widget)
  ;; Use tag or value for menus.
  (or (widget-get widget :menu-tag)
      (widget-get widget :tag)
      (widget-princ-to-string (widget-get widget :value))))

(defun widget-default-action (widget &optional event)
  ;; Notify the parent when a widget change
  (let ((parent (widget-get widget :parent)))
    (when parent
      (widget-apply parent :notify widget event))))

(defun widget-default-notify (widget child &optional event)
  ;; Pass notification to parent.
  (widget-default-action widget event))

;;; The `item' Widget.

(define-widget 'item 'default
  "Constant items for inclusion in other widgets."
  :convert-widget 'widget-item-convert-widget
  :value-create 'widget-item-value-create
  :value-delete 'ignore
  :value-get 'widget-item-value-get
  :match 'widget-item-match
  :match-inline 'widget-item-match-inline
  :action 'widget-item-action
  :format "%t\n")

(defun widget-item-convert-widget (widget)
  ;; Initialize :value and :tag from :args in WIDGET.
  (let ((args (widget-get widget :args)))
    (when args 
      (widget-put widget :value (car args))
      (widget-put widget :args nil)))
  widget)

(defun widget-item-value-create (widget)
  ;; Insert the printed representation of the value.
  (let ((standard-output (current-buffer)))
    (princ (widget-get widget :value))))

(defun widget-item-match (widget value)
  ;; Match if the value is the same.
  (equal (widget-get widget :value) value))

(defun widget-item-match-inline (widget values)
  ;; Match if the value is the same.
  (let ((value (widget-get widget :value)))
    (and (listp value)
	 (<= (length value) (length values))
	 (let ((head (subseq values 0 (length value))))
	   (and (equal head value)
		(cons head (subseq values (length value))))))))

(defun widget-item-action (widget &optional event)
  ;; Just notify itself.
  (widget-apply widget :notify widget event))

(defun widget-item-value-get (widget)
  ;; Items are simple.
  (widget-get widget :value))

;;; The `push' Widget.

(define-widget 'push 'item
  "A pushable button."
  :format "%[[%t]%]")

;;; The `link' Widget.

(define-widget 'link 'item
  "An embedded link."
  :format "%[_%t_%]")

;;; The `field' Widget.

(define-widget 'field 'default
  "An editable text field."
  :convert-widget 'widget-item-convert-widget
  :format "%v"
  :value ""
  :tag "field"
  :value-create 'widget-field-value-create
  :value-delete 'widget-field-value-delete
  :value-get 'widget-field-value-get
  :match 'widget-field-match)

(defun widget-field-value-create (widget)
  ;; Create an editable text field.
  (insert " ")
  (let ((size (widget-get widget :size))
	(value (widget-get widget :value))
	(from (point)))
    (if (null size)
	(insert value)
      (insert value)
      (if (< (length value) size)
	  (insert-char ?\  (- size (length value)))))
    (unless (memq widget widget-field-list)
      (setq widget-field-new (cons widget widget-field-new)))
    (widget-put widget :value-from (copy-marker from))
    (set-marker-insertion-type (widget-get widget :value-from) t)
    (widget-put widget :value-to (copy-marker (point)))
    (set-marker-insertion-type (widget-get widget :value-to) nil)
    (if (null size)
	(insert ?\n)
      (insert ?\ ))))

(defun widget-field-value-delete (widget)
  ;; Remove the widget from the list of active editing fields.
  (setq widget-field-list (delq widget widget-field-list))
  (set-marker (widget-get widget :value-from) nil)
  (set-marker (widget-get widget :value-to) nil))

(defun widget-field-value-get (widget)
  ;; Return current text in editing field.
  (let ((from (widget-get widget :value-from))
	(to (widget-get widget :value-to)))
    (if (and from to)
	(progn 
	  (setq from (1+ from)
		to (1- to))
	  (while (and (> to from)
		      (eq (char-after (1- to)) ?\ ))
	    (setq to (1- to)))
	  (buffer-substring-no-properties from to))
      (widget-get widget :value))))

(defun widget-field-match (widget value)
  ;; Match any string.
  (stringp value))

;;; The `choice' Widget.

(define-widget 'choice 'default
  "A menu of options."
  :convert-widget  'widget-choice-convert-widget
  :format "%[%t%]: %v"
  :tag "choice"
  :inline t
  :void '(item "void")
  :value-create 'widget-choice-value-create
  :value-delete 'widget-radio-value-delete
  :value-get 'widget-choice-value-get
  :value-inline 'widget-choice-value-inline
  :action 'widget-choice-action
  :error "Make a choice"
  :validate 'widget-choice-validate
  :match 'widget-choice-match
  :match-inline 'widget-choice-match-inline)

(defun widget-choice-convert-widget (widget)
  ;; Expand type args into widget objects.
  (widget-put widget :args (mapcar 'widget-convert (widget-get widget :args)))
  widget)

(defun widget-choice-value-create (widget)
  ;; Insert the first choice that matches the value.
  (let ((value (widget-get widget :value))
	(args (widget-get widget :args))
	current)
    (while args
      (setq current (car args)
	    args (cdr args))
      (when (widget-apply current :match value)
	(widget-put widget :children (list (widget-create current
							  :parent widget
							  :value value)))
	(widget-put widget :choice current)
	(setq args nil
	      current nil)))
    (when current
      (let ((void (widget-get widget :void)))
	(widget-put widget :children (list (widget-create void
							  :parent widget
							  :value value)))
	(widget-put widget :choice void)))))

(defun widget-choice-value-get (widget)
  ;; Get value of the child widget.
  (widget-value (car (widget-get widget :children))))

(defun widget-choice-value-inline (widget)
  ;; Get value of the child widget.
  (widget-apply (car (widget-get widget :children)) :value-inline))

(defun widget-choice-action (widget &optional event)
  ;; Make a choice.
  (let ((args (widget-get widget :args))
	(old (widget-get widget :choice))
	(tag (widget-apply widget :menu-tag-get))
	current choices)
    (setq current
	  (cond ((= (length args) 0)
		 nil)
		((= (length args) 1)
		 (nth 0 args))
		((and (= (length args) 2)
		      (memq old args))
		 (if (eq old (nth 0 args))
		     (nth 1 args)
		   (nth 0 args)))
		(t
		 (while args
		   (setq current (car args)
			 args (cdr args))
		   (setq choices
			 (cons (cons (widget-apply current :menu-tag-get)
				     current)
			       choices)))
		 (cond
		  ((and event (fboundp 'x-popup-menu) window-system)
		   ;; We are in Emacs-19, pressed by the mouse
		   (x-popup-menu event
				 (list tag (cons "" (reverse choices)))))
		  ((and event (fboundp 'popup-menu) window-system)
		   ;; We are in XEmacs, pressed by the mouse
		   (let ((val (get-popup-menu-response
			       (cons ""
				     (mapcar
				      (function
				       (lambda (x)
					 (vector (car x) (list (car x)) t)))
				      (reverse choices))))))
		     (setq val (and val
				    (listp (event-object val))
				    (stringp (car-safe (event-object val)))
				    (car (event-object val))))
		     (cdr (assoc val choices))))
		  (t
		   (cdr (assoc (completing-read (concat tag ": ")
						choices nil t)
			       choices)))))))
    (when current
      (widget-value-set widget (widget-value current))
      (widget-setup)))
  ;; Notify parent.
  (widget-apply widget :notify widget event)
  (widget-clear-undo))

(defun widget-choice-validate (widget)
  ;; Valid if we have made a valid choice.
  (let ((void (widget-get widget :void))
	(choice (widget-get widget :choice))
	(child (car (widget-get widget :children))))
    (if (eq void choice)
	widget
      (widget-apply child :validate))))

(defun widget-choice-match (widget value)
  ;; Matches if one of the choices matches.
  (let ((args (widget-get widget :args))
	current found)
    (while (and args (not found))
      (setq current (car args)
	    args (cdr args)
	    found (widget-apply current :match value)))
    found))

(defun widget-choice-match-inline (widget values)
  ;; Matches if one of the choices matches.
  (let ((args (widget-get widget :args))
	current found)
    (while (and args (null found))
      (setq current (car args)
	    args (cdr args)
	    found (widget-match-inline current values)))
    found))

;;; The `toggle' Widget.

(define-widget 'toggle 'choice
  "Toggle between two states."
  :convert-widget 'widget-toggle-convert-widget
  :format "%[%v%]"
  :on "on"
  :off "off")

(defun widget-toggle-convert-widget (widget)
  ;; Create the types representing the `on' and `off' states.
  (let ((args (widget-get widget :args))
	(on-type (widget-get widget :on-type))
	(off-type (widget-get widget :off-type)))
    (unless on-type
      (setq on-type (list 'item :value t :tag (widget-get widget :on))))
    (unless off-type
      (setq off-type (list 'item :value nil :tag (widget-get widget :off))))
    (widget-put widget :args (list on-type off-type)))
  widget)

;;; The `checkbox' Widget.

(define-widget 'checkbox 'toggle
  "A checkbox toggle."
  :convert-widget 'widget-item-convert-widget
  :on-type '(item :format "[X]" t)
  :off-type  '(item :format "[ ]" nil))

;;; The `checklist' Widget.

(define-widget 'checklist 'default
  "A multiple choice widget."
  :convert-widget 'widget-choice-convert-widget
  :format "%v"
  :entry-format "%b %v"
  :menu-tag "checklist"
  :value-create 'widget-checklist-value-create
  :value-delete 'widget-radio-value-delete
  :value-get 'widget-checklist-value-get
  :validate 'widget-checklist-validate
  :match 'widget-checklist-match
  :match-inline 'widget-checklist-match-inline)

(defun widget-checklist-value-create (widget)
  ;; Insert all values
  (let ((alist (widget-checklist-match-find widget (widget-get widget :value)))
	(args (widget-get widget :args)))
    (while args 
      (widget-checklist-add-item widget (car args) (assq (car args) alist))
      (setq args (cdr args)))
    (widget-put widget :children (nreverse (widget-get widget :children)))))

(defun widget-checklist-add-item (widget type chosen)
  ;; Create checklist item in WIDGET of type TYPE.
  ;; If the item is checked, CHOSEN is a cons whose cdr is the value.
  (widget-specify-insert 
   (let* ((children (widget-get widget :children))
	  (buttons (widget-get widget :buttons))
	  (from (point))
	  child button)
     (insert (widget-get widget :entry-format))
     (goto-char from)
     ;; Parse % escapes in format.
     (while (re-search-forward "%\\([bv%]\\)" nil t)
       (let ((escape (aref (match-string 1) 0)))
	 (replace-match "" t t)
	 (cond ((eq escape ?%)
		(insert "%"))
	       ((eq escape ?b)
		(setq button (widget-create 'checkbox
					    :parent widget
					    :value (not (null chosen)))))
	       ((eq escape ?v)
		(setq child
		      (cond ((not chosen)
			     (widget-create type :parent widget))
			    ((widget-get type :inline)
			     (widget-create type
					    :parent widget
					    :value (cdr chosen)))
			    (t
			     (widget-create type
					    :parent widget
					    :value (car (cdr chosen)))))))
	       (t 
		(error "Unknown escape `%c'" escape)))))
     ;; Update properties.
     (and button child (widget-put child :button button))
     (and button (widget-put widget :buttons (cons button buttons)))
     (and child (widget-put widget :children (cons child children))))))

(defun widget-checklist-match (widget values)
  ;; All values must match a type in the checklist.
  (and (listp values)
       (null (cdr (widget-checklist-match-inline widget values)))))

(defun widget-checklist-match-inline (widget values)
  ;; Find the values which match a type in the checklist.
  (let ((greedy (widget-get widget :greedy))
	(args (copy-list (widget-get widget :args)))
	found rest)
    (while values
      (let ((answer (widget-checklist-match-up args values)))
	(cond (answer 
	       (let ((vals (widget-match-inline answer values)))
		 (setq found (append found (car vals))
		       values (cdr vals)
		       args (delq answer args))))
	      (greedy
	       (setq rest (append rest (list (car values)))
		     values (cdr values)))
	      (t 
	       (setq rest (append rest values)
		     values nil)))))
    (cons found rest)))

(defun widget-checklist-match-find (widget values)
  ;; Find the values which match a type in the checklist.
  ;; Return an alist of (TYPE MATCH).
  (let ((greedy (widget-get widget :greedy))
	(args (copy-list (widget-get widget :args)))
	found)
    (while values
      (let ((answer (widget-checklist-match-up args values)))
	(cond (answer 
	       (let ((vals (widget-match-inline answer values)))
		 (setq found (cons (cons answer (car vals)) found)
		       values (cdr vals)
		       args (delq answer args))))
	      (greedy
	       (setq values (cdr values)))
	      (t 
	       (setq values nil)))))
    found))

(defun widget-checklist-match-up (args values)
  ;; Rerturn the first type from ARGS that matches VALUES.
  (let (current found)
    (while (and args (null found))
      (setq current (car args)
	    args (cdr args)
	    found (widget-match-inline current values)))
    (and found current)))

(defun widget-checklist-value-get (widget)
  ;; The values of all selected items.
  (let ((children (widget-get widget :children))
	child result)
    (while children 
      (setq child (car children)
	    children (cdr children))
      (if (widget-value (widget-get child :button))
	  (setq result (append result (widget-apply child :value-inline)))))
    result))

(defun widget-checklist-validate (widget)
  ;; Ticked chilren must be valid.
  (let ((children (widget-get widget :children))
	child button found)
    (while (and children (not found))
      (setq child (car children)
	    children (cdr children)
	    button (widget-get child :button)
	    found (and (widget-value button)
		       (widget-apply child :validate))))
    found))

;;; The `option' Widget

(define-widget 'option 'checklist
  "An widget with an optional item."
  :inline t)

;;; The `choice-item' Widget.

(define-widget 'choice-item 'item
  "Button items that delegate action events to their parents."
  :action 'widget-choice-item-action
  :format "%[%t%]\n")

(defun widget-choice-item-action (widget &optional event)
  ;; Tell parent what happened.
  (widget-apply (widget-get widget :parent) :action event))

;;; The `radio-button' Widget.

(define-widget 'radio-button 'toggle
  "A radio button for use in the `radio' widget."
  :format "%v"
  :notify 'widget-radio-button-notify
  :on-type '(choice-item :format "%[(*)%]" t)
  :off-type '(choice-item :format "%[( )%]" nil))

(defun widget-radio-button-notify (widget child &optional event)
  ;; Notify the parent.
  (widget-apply (widget-get widget :parent) :action widget event))

;;; The `radio' Widget.

(define-widget 'radio 'default
  "Select one of multiple options."
  :convert-widget 'widget-choice-convert-widget
  :format "%v"
  :entry-format "%b %v"
  :menu-tag "radio"
  :value-create 'widget-radio-value-create
  :value-delete 'widget-radio-value-delete
  :value-get 'widget-radio-value-get
  :value-inline 'widget-radio-value-inline
  :value-set 'widget-radio-value-set
  :error "You must push one of the buttons"
  :validate 'widget-radio-validate
  :match 'widget-choice-match
  :match-inline 'widget-choice-match-inline
  :action 'widget-radio-action)

(defun widget-radio-value-create (widget)
  ;; Insert all values
  (let ((args (widget-get widget :args))
	(indent (widget-get widget :indent))
	arg)
    (while args 
      (setq arg (car args)
	    args (cdr args))
      (widget-radio-add-item widget arg)
      (and indent args (insert-char ?\  indent)))))

(defun widget-radio-add-item (widget type)
  "Add to radio widget WIDGET a new radio button item of type TYPE."
  (setq type (widget-convert type))
  (widget-specify-insert 
   (let* ((value (widget-get widget :value))
	  (children (widget-get widget :children))
	  (buttons (widget-get widget :buttons))
	  (from (point))
	  (chosen (and (null (widget-get widget :choice))
		       (widget-apply type :match value)))
	  child button)
     (insert (widget-get widget :entry-format))
     (goto-char from)
     ;; Parse % escapes in format.
     (while (re-search-forward "%\\([bv%]\\)" nil t)
       (let ((escape (aref (match-string 1) 0)))
	 (replace-match "" t t)
	 (cond ((eq escape ?%)
		(insert "%"))
	       ((eq escape ?b)
		(setq button (widget-create 'radio-button
					    :parent widget
					    :value (not (null chosen)))))
	       ((eq escape ?v)
		(setq child (if chosen
				(widget-create type
					       :parent widget
					       :value value)
			      (widget-create type :parent widget))))
	       (t 
		(error "Unknown escape `%c'" escape)))))
     ;; Update properties.
     (when chosen
       (widget-put widget :choice type))
     (when button 
       (widget-put child :button button)
       (widget-put widget :buttons (nconc buttons (list button))))
     (when child
       (widget-put widget :children (nconc children (list child))))
     child)))

(defun widget-radio-value-delete (widget)
  ;; Delete the child widgets.
  (mapcar 'widget-delete (widget-get widget :children))
  (widget-put widget :children nil)
  (mapcar 'widget-delete (widget-get widget :buttons))
  (widget-put widget :buttons nil))

(defun widget-radio-value-get (widget)
  ;; Get value of the child widget.
  (let ((chosen (widget-radio-chosen widget)))
    (and chosen (widget-value chosen))))

(defun widget-radio-chosen (widget)
  "Return the widget representing the chosen radio button."
  (let ((children (widget-get widget :children))
	current found)
    (while children
      (setq current (car children)
	    children (cdr children))
      (let* ((button (widget-get current :button))
	     (value (widget-apply button :value-get)))
	(when value
	  (setq found current
		children nil))))
    found))

(defun widget-radio-value-inline (widget)
  ;; Get value of the child widget.
  (let ((children (widget-get widget :children))
	current found)
    (while children
      (setq current (car children)
	    children (cdr children))
      (let* ((button (widget-get current :button))
	     (value (widget-apply button :value-get)))
	(when value
	  (setq found (widget-apply current :value-inline)
		children nil))))
    found))

(defun widget-radio-value-set (widget value)
  ;; We can't just delete and recreate a radio widget, since children
  ;; can be added after the original creation and won't be recreated
  ;; by `:create'.
  (let ((children (widget-get widget :children))
	current found)
    (while children
      (setq current (car children)
	    children (cdr children))
      (let* ((button (widget-get current :button))
	     (match (and (not found)
			 (widget-apply current :match value))))
	(widget-value-set button match)
	(if match 
	    (widget-value-set current value))
	(setq found (or found match))))))

(defun widget-radio-validate (widget)
  ;; Valid if we have made a valid choice.
  (let ((children (widget-get widget :children))
	current found button)
    (while (and children (not found))
      (setq current (car children)
	    children (cdr children)
	    button (widget-get current :button)
	    found (widget-apply button :value-get)))
    (if found
	(widget-apply current :validate)
      widget)))

(defun widget-radio-action (widget child event)
  ;; Check if a radio button was pressed.
  (let ((children (widget-get widget :children))
	(buttons (widget-get widget :buttons))
	current)
    (when (memq child buttons)
      (while children
	(setq current (car children)
	      children (cdr children))
	(let* ((button (widget-get current :button)))
	  (cond ((eq child button)
		 (widget-value-set button t))
		((widget-value button)
		 (widget-value-set button nil)))))))
  ;; Pass notification to parent.
  (widget-apply widget :notify child event))

;;; The `insert-button' Widget.

(define-widget 'insert-button 'push
  "An insert button for the `repeat' widget."
  :tag "INS"
  :action 'widget-insert-button-action)

(defun widget-insert-button-action (widget &optional event)
  ;; Ask the parent to insert a new item.
  (widget-apply (widget-get widget :parent) 
		:insert-before (widget-get widget :widget)))

;;; The `delete-button' Widget.

(define-widget 'delete-button 'push
  "A delete button for the `repeat' widget."
  :tag "DEL"
  :action 'widget-delete-button-action)

(defun widget-delete-button-action (widget &optional event)
  ;; Ask the parent to insert a new item.
  (widget-apply (widget-get widget :parent) 
		:delete-at (widget-get widget :widget)))

;;; The `repeat' Widget.

(define-widget 'repeat 'default
  "A variable list of widgets of the same type."
  :convert-widget 'widget-choice-convert-widget
  :format "%v%i\n"
  :format-handler 'widget-repeat-format-handler
  :entry-format "%i %d %v"
  :menu-tag "repeat"
  :value-create 'widget-repeat-value-create
  :value-delete 'widget-radio-value-delete
  :value-get 'widget-repeat-value-get
  :validate 'widget-repeat-validate
  :match 'widget-repeat-match
  :match-inline 'widget-repeat-match-inline
  :insert-before 'widget-repeat-insert-before
  :delete-at 'widget-repeat-delete-at)

(defun widget-repeat-format-handler (widget escape)
  ;; We recognize the insert button.
  (cond ((eq escape ?i)
	 (insert " ")			
	 (backward-char 1)
	 (let* ((from (point))
		(button (widget-create (list 'insert-button 
					     :parent widget))))
	   (widget-specify-button button from (point)))
	 (forward-char 1))
	(t 
	 (widget-default-format-handler widget escape))))

(defun widget-repeat-value-create (widget)
  ;; Insert all values
  (let* ((value (widget-get widget :value))
	 (type (nth 0 (widget-get widget :args)))
	 (inlinep (widget-get type :inline))
	 children)
    (widget-put widget :value-pos (copy-marker (point)))
    (set-marker-insertion-type (widget-get widget :value-pos) t)
    (while value
      (let ((answer (widget-match-inline type value)))
	(if answer
	    (setq children (cons (widget-repeat-entry-create
				  widget (if inlinep
					     (car answer)
					   (car (car answer))))
				 children)
		  value (cdr answer))
	  (setq value nil))))
    (widget-put widget :children (nreverse children))))

(defun widget-repeat-value-get (widget)
  ;; Get value of the child widget.
  (apply 'append (mapcar (lambda (child) (widget-apply child :value-inline))
			 (widget-get widget :children))))

(defun widget-repeat-validate (widget)
  ;; All the chilren must be valid.
  (let ((children (widget-get widget :children))
	child found)
    (while (and children (not found))
      (setq child (car children)
	    children (cdr children)
	    found (widget-apply child :validate)))
    found))

(defun widget-repeat-match (widget value)
  ;; Value must be a list and all the members must match the repeat type.
  (and (listp value)
       (null (cdr (widget-repeat-match-inline widget value)))))

(defun widget-repeat-match-inline (widget value)
  (let ((type (nth 0 (widget-get widget :args)))
	(ok t)
	found)
    (while (and value ok)
      (let ((answer (widget-match-inline type value)))
	(if answer 
	    (setq found (append found (car answer))
		  value (cdr answer))
	  (setq ok nil))))
    (cons found value)))

(defun widget-repeat-insert-before (widget before)
  ;; Insert a new child in the list of children.
  (save-excursion
    (let ((children (widget-get widget :children))
	  (inhibit-read-only t)
	  after-change-functions)
      (cond (before 
	     (goto-char (widget-get before :from)))
	    (t
	     (goto-char (widget-get widget :value-pos))))
      (let ((child (widget-repeat-entry-create 
		    widget (widget-get (nth 0 (widget-get widget :args))
				       :value))))
	(widget-specify-text (widget-get child :from)
			     (widget-get child :to))
	(if (eq (car children) before)
	    (widget-put widget :children (cons child children))
	  (while (not (eq (car (cdr children)) before))
	    (setq children (cdr children)))
	  (setcdr children (cons child (cdr children)))))))
  (widget-setup)
  (widget-apply widget :notify widget))

(defun widget-repeat-delete-at (widget child)
  ;; Delete child from list of children.
  (save-excursion
    (let ((buttons (copy-list (widget-get widget :buttons)))
	  button
	  (inhibit-read-only t)
	  after-change-functions)
      (while buttons
	(setq button (car buttons)
	      buttons (cdr buttons))
	(when (eq (widget-get button :widget) child)
	  (widget-put widget
		      :buttons (delq button (widget-get widget :buttons)))
	  (widget-delete button))))
    (widget-delete child)
    (widget-put widget :children (delq child (widget-get widget :children))))
  (widget-setup)
  (widget-apply widget :notify widget))

(defun widget-repeat-entry-create (widget value)
  ;; Create a new entry to the list.
  (let ((type (nth 0 (widget-get widget :args)))
	(indent (widget-get widget :indent))
	child delete insert)
    (widget-specify-insert 
     (save-excursion
       (insert (widget-get widget :entry-format))
       (if indent
	   (insert-char ?\  indent)))
     ;; Parse % escapes in format.
     (while (re-search-forward "%\\(.\\)" nil t)
       (let ((escape (aref (match-string 1) 0)))
	 (replace-match "" t t)
	 (cond ((eq escape ?%)
		(insert "%"))
	       ((eq escape ?i)
		(setq insert (widget-create 'insert-button 
					    :parent widget)))
	       ((eq escape ?d)
		(setq delete (widget-create 'delete-button 
					    :parent widget)))
	       ((eq escape ?v)
		(setq child (widget-create type
					   :parent widget
					   :value value)))
	       (t 
		(error "Unknown escape `%c'" escape)))))
     (widget-put widget 
		 :buttons (cons delete 
				(cons insert
				      (widget-get widget :buttons))))
     (move-marker (widget-get child :from) (point-min))
     (move-marker (widget-get child :to) (point-max)))
    (widget-put insert :widget child)
    (widget-put delete :widget child)
    child))

;;; The `group' Widget.

(define-widget 'group 'default
  "A widget which group other widgets inside."
  :convert-widget 'widget-choice-convert-widget
  :format "%v"
  :value-create 'widget-group-value-create
  :value-delete 'widget-radio-value-delete
  :value-get 'widget-repeat-value-get
  :validate 'widget-repeat-validate
  :match 'widget-group-match
  :match-inline 'widget-group-match-inline)

(defun widget-group-value-create (widget)
  ;; Create each component.
  (let ((args (widget-get widget :args))
	(value (widget-get widget :value))
	(indent (widget-get widget :indent))
	arg answer children)
    (while args
      (setq arg (car args)
	    args (cdr args)
	    answer (widget-match-inline arg value)
	    value (cdr answer)
	    children (cons (cond ((null answer)
				  (widget-create arg :parent widget))
				 ((widget-get arg :inline)
				  (widget-create arg
						 :parent widget
						 :value (car answer)))
				 (t
				  (widget-create arg
						 :parent widget
						 :value (car (car answer)))))
			   children))
      (and args indent (insert-char ?\  indent)))
    (widget-put widget :children (nreverse children))))

(defun widget-group-match (widget values)
  ;; Match if the components match.
  (and (listp values)
       (null (cdr (widget-group-match-inline widget values)))))

(defun widget-group-match-inline (widget values)
  ;; Match if the components match.
  (let ((args (widget-get widget :args))
	(match t)
	arg answer found)
    (while args
      (setq arg (car args)
	    args (cdr args)
	    answer (widget-match-inline arg values))
      (if answer 
	  (setq values (cdr answer)
		found (append found (car answer)))
	(setq values nil)))
    (if answer
	(cons found values)
      nil)))

;;; The Sexp Widgets.

(define-widget 'const 'item
  nil
  :format "%t\n")

(define-widget 'string 'field
  nil)

(define-widget 'file 'string
  nil
  :format "%[%t%]:%v"
  :tag "File"
  :action 'widget-file-action)

(defun widget-file-action (widget &optional event)
  nil
  ;; Read a file name from the minibuffer.
  (widget-value-set widget
		    (read-file-name (widget-apply widget :menu-tag-get)
				    (widget-get widget :directory)
				    (widget-value widget)
				    (widget-get widget :must-match)
				    (widget-get widget :initial))))

(define-widget 'directory 'file
  nil
  :tag "Directory")

(define-widget 'symbol 'string
  nil
  :match (lambda (widget value) (symbolp value))
  :value-to-internal (lambda (widget value) (symbol-name value))
  :value-to-external (lambda (widget value) (intern value)))

(define-widget 'sexp 'string
  nil
  :validate 'widget-sexp-validate
  :match (lambda  (widget value) t)
  :value-to-internal (lambda (widget value) (pp-to-string value))
  :value-to-external (lambda (widget value) (read value)))

(defun widget-sexp-validate (widget)
  ;; Valid if we can read the string and there is no junk left after it.
  (save-excursion
    (set-buffer (get-buffer-create " *Widget Scratch*"))
    (erase-buffer)
    (insert (widget-apply :value-get widget))
    (goto-char (point-min))
    (condition-case data
	(let ((value (read (current-buffer))))
	  (if (eobp)
	      (if (widget-apply widget :match value)
		  t
		(widget-put widget :error (widget-get widget :type-error))
		nil)
	    (widget-put widget
			:error (format "Junk at end of expression: %s"
				       (buffer-substring (point) (point-max))))
	    nil))
      (error (widget-put widget :error (error-message-string data))
	     nil))))

(define-widget 'integer 'sexp
  nil
  :type-error "This field should contain an integer"
  :match (lambda (widget value) (integerp value)))

(define-widget 'number 'sexp
  nil
  :type-error "This field should contain a number"
  :match (lambda (widget value) (numberp value)))

(define-widget 'list 'group
  nil)

(define-widget 'vector 'group
  nil
  :match 'widget-vector-match
  :value-to-internal (lambda (widget value) (append value nil))
  :value-to-external (lambda (widget value) (apply 'vector value)))

(defun widget-vector-match (widget value) 
  (and (vectorp value)
       (widget-group-match widget
			   (widget-apply :value-to-internal widget value))))

(define-widget 'cons 'group
  nil
  :match 'widget-cons-match
  :value-to-internal (lambda (widget value)
		       (list (car value) (cdr value)))
  :value-to-external (lambda (widget value)
		       (cons (nth 0 value) (nth 1 value))))

(defun widget-cons-match (widget value) 
  (and (consp value)
       (widget-group-match widget
			   (widget-apply :value-to-internal widget value))))

;;; The End:

(provide 'widget-edit)

;; widget-edit.el ends here
