;; Copyright (C) 1998 Free Software Foundation, Inc.

;; Author: Martin Buchholz <martin@xemacs.org>
;; Maintainer: Martin Buchholz <martin@xemacs.org>
;; Created: 1998
;; Keywords: tests, database

;; This file is part of XEmacs.

;; XEmacs is free software: you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the
;; Free Software Foundation, either version 3 of the License, or (at your
;; option) any later version.

;; XEmacs is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.

;; You should have received a copy of the GNU General Public License
;; along with XEmacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Synched up with: Not in FSF.

;;; Commentary:

;;; Test hash tables implementation
;;; See test-harness.el

(condition-case err
    (require 'test-harness)
  (file-error
   (when (and (boundp 'load-file-name) (stringp load-file-name))
     (push (file-name-directory load-file-name) load-path)
     (require 'test-harness))))

;; Test all combinations of make-hash-table keywords
(dolist (test '(eq eql equal equalp))
  (dolist (size '(0 1 100))
    (dolist (rehash-size '(1.1 9.9))
      (dolist (rehash-threshold '(0.2 .9))
	(dolist (weakness '(nil key value key-or-value key-and-value))
	  (dolist (data '(() (1 2) (1 2 3 4)))
	    (let ((ht (make-hash-table
		       :test test
		       :size size
		       :rehash-size rehash-size
		       :rehash-threshold rehash-threshold
		       :weakness weakness)))
	      (Assert (equal ht (car (let ((print-readably t))
				       (read-from-string (prin1-to-string ht))))))
	      (Assert (eq test (hash-table-test ht)))
	      (Assert (<= size (hash-table-size ht)))
	      (Assert (eql rehash-size (hash-table-rehash-size ht)))
	      (Assert (eql rehash-threshold (hash-table-rehash-threshold ht)))
	      (Assert (eq weakness (hash-table-weakness ht))))))))))

(loop for (type weakness) in '((non-weak nil)
			       (weak key-and-value)
			       (key-weak key)
			       (value-weak value))
  do (Assert (equal (make-hash-table :type type)
		    (make-hash-table :weakness weakness))))

(Assert (not (equal (make-hash-table :weakness nil)
		    (make-hash-table :weakness t))))

(let ((ht (make-hash-table :size 20 :rehash-threshold .75 :test 'eq))
      (size 80))
  (Assert (hash-table-p ht))
  (Assert (eq 'eq (hash-table-test ht)))
  (Assert (eq 'non-weak (hash-table-type ht)))
  (Assert (eq 'nil (hash-table-weakness ht)))
  (dotimes (j size)
    (puthash j (- j) ht)
    (Assert (eq (gethash j ht) (- j)))
    (Assert (= (hash-table-count ht) (1+ j)))
    (puthash j j ht)
    (Assert (eq (gethash j ht 'foo) j))
    (Assert (= (hash-table-count ht) (1+ j)))
    (setf (gethash j ht) (- j))
    (Assert (eq (gethash j ht) (- j)))
    (Assert (= (hash-table-count ht) (1+ j))))

  (clrhash ht)
  (Assert (= 0 (hash-table-count ht)))

  (dotimes (j size)
    (puthash j (- j) ht)
    (Assert (eq (gethash j ht) (- j)))
    (Assert (= (hash-table-count ht) (1+ j))))

  (let ((k-sum 0) (v-sum 0))
    (maphash #'(lambda (k v) (incf k-sum k) (incf v-sum v)) ht)
    (Assert (= k-sum (/ (* size (- size 1)) 2)))
    (Assert (= v-sum (- k-sum))))

  (let ((count size))
    (dotimes (j size)
      (remhash j ht)
      (Assert (eq (gethash j ht) nil))
      (Assert (eq (gethash j ht 'foo) 'foo))
      (Assert (= (hash-table-count ht) (decf count))))))

(let ((ht (make-hash-table :size 30 :rehash-threshold .25 :test 'equal))
      (size 70))
  (Assert (hash-table-p ht))
  (Assert (>= (hash-table-size ht) (/ 30 .25)))
  (Assert (eql .25 (hash-table-rehash-threshold ht)))
  (Assert (eq 'equal (hash-table-test ht)))
  (Assert (eq 'non-weak (hash-table-type ht)))
  (dotimes (j size)
    (puthash (int-to-string j) (- j) ht)
    (Assert (eq (gethash (int-to-string j) ht) (- j)))
    (Assert (= (hash-table-count ht) (1+ j)))
    (puthash (int-to-string j) j ht)
    (Assert (eq (gethash (int-to-string j) ht 'foo) j))
    (Assert (= (hash-table-count ht) (1+ j))))

  (clrhash ht)
  (Assert (= 0 (hash-table-count ht)))
  (Assert (equal ht (copy-hash-table ht)))

  (dotimes (j size)
    (setf (gethash (int-to-string j) ht) (- j))
    (Assert (eq (gethash (int-to-string j) ht) (- j)))
    (Assert (= (hash-table-count ht) (1+ j))))

  (let ((count size))
    (dotimes (j size)
      (remhash (int-to-string j) ht)
      (Assert (eq (gethash (int-to-string j) ht) nil))
      (Assert (eq (gethash (int-to-string j) ht 'foo) 'foo))
      (Assert (= (hash-table-count ht) (decf count))))))

(let ((iterations 5) (one 1.0) (two 2.0))
  (labels ((check-copy
             (ht)
             (let ((copy-of-ht (copy-hash-table ht)))
               (Assert (equal ht copy-of-ht))
               (Assert (not (eq ht copy-of-ht)))
               (Assert (eq  (hash-table-count ht)
                            (hash-table-count copy-of-ht)))
               (Assert (eq  (hash-table-type  ht)
                            (hash-table-type  copy-of-ht)))
               (Assert (eq  (hash-table-size  ht)
                         (hash-table-size  copy-of-ht)))
               (Assert (eql (hash-table-rehash-size ht)
                            (hash-table-rehash-size copy-of-ht)))
               (Assert (eql (hash-table-rehash-threshold ht)
                            (hash-table-rehash-threshold copy-of-ht))))))

  (let ((ht (make-hash-table :size 100 :rehash-threshold .6 :test 'eq)))
    (dotimes (j iterations)
      (puthash (+ one 0.0) t ht)
      (puthash (+ two 0.0) t ht)
      (puthash (cons 1 2) t ht)
      (puthash (cons 3 4) t ht))
    (Assert (eq (hash-table-test ht) 'eq))
    (Assert (= (* iterations 4) (hash-table-count ht)))
    (Assert (eq nil (gethash 1.0 ht)))
    (Assert (eq nil (gethash '(1 . 2) ht)))
    (check-copy ht)
    )

  (let ((ht (make-hash-table :size 100 :rehash-threshold .6 :test 'eql)))
    (dotimes (j iterations)
      (puthash (+ one 0.0) t ht)
      (puthash (+ two 0.0) t ht)
      (puthash (cons 1 2) t ht)
      (puthash (cons 3 4) t ht))
    (Assert (eq (hash-table-test ht) 'eql))
    (Assert (= (+ 2 (* 2 iterations)) (hash-table-count ht)))
    (Assert (eq t (gethash 1.0 ht)))
    (Assert (eq nil (gethash '(1 . 2) ht)))
    (check-copy ht)
    )

  (let ((ht (make-hash-table :size 100 :rehash-threshold .6 :test 'equal)))
    (dotimes (j iterations)
      (puthash (+ one 0.0) t ht)
      (puthash (+ two 0.0) t ht)
      (puthash (cons 1 2) t ht)
      (puthash (cons 3 4) t ht))
    (Assert (eq (hash-table-test ht) 'equal))
    (Assert (= 4 (hash-table-count ht)))
    (Assert (eq t (gethash 1.0 ht)))
    (Assert (eq t (gethash '(1 . 2) ht)))
    (check-copy ht)
    )

  (let ((ht (make-hash-table :size 100 :rehash-threshold .6 :test 'equalp)))
    (dotimes (j iterations)
      (puthash (+ one 0.0) t ht)
      (puthash 1 t ht)
      (puthash (+ two 0.0) t ht)
      (puthash 2 t ht)
      (puthash (cons 1.0 2.0) (gensym) ht)
      ;; Override the previous entry.
      (puthash (cons 1 2) t ht)
      (puthash (cons 3.0 4.0) (gensym) ht)
      (puthash (cons 3 4) t ht))
    (Assert (eq (hash-table-test ht) 'equalp))
    (Assert (= 4 (hash-table-count ht)))
    (Assert (eq t (gethash 1.0 ht)))
    (Assert (eq t (gethash '(1 . 2) ht)))
    (check-copy ht)
    )

  ))

;; Test that weak hash-tables are properly handled
(loop for (weakness expected-count expected-k-sum expected-v-sum) in
  '((nil 6 38 25)
    (t 3 6 9)
    (key 4 38 9)
    (value 4 6 25))
  do
  (let* ((ht (make-hash-table :weakness weakness))
       (my-obj (cons ht ht)))
  (garbage-collect)
  (puthash my-obj 1 ht)
  (puthash 2 my-obj ht)
  (puthash 4 8 ht)
  (puthash (cons ht ht) 16 ht)
  (puthash 32 (cons ht ht) ht)
  (puthash (cons ht ht) (cons ht ht) ht)
  (let ((k-sum 0) (v-sum 0))
    (maphash #'(lambda (k v)
		 (when (integerp k) (incf k-sum k))
		 (when (integerp v) (incf v-sum v)))
	     ht)
    (Assert (eq 38 k-sum))
    (Assert (eq 25 v-sum)))
  (Assert (eq 6 (hash-table-count ht)))
  (garbage-collect)
  (Assert (eq expected-count (hash-table-count ht)))
  (let ((k-sum 0) (v-sum 0))
    (maphash #'(lambda (k v)
		 (when (integerp k) (incf k-sum k))
		 (when (integerp v) (incf v-sum v)))
	     ht)
    (Assert (eq expected-k-sum k-sum))
    (Assert (eq expected-v-sum v-sum)))))

;;; Test the ability to puthash and remhash the current elt of a maphash
(let ((ht (make-hash-table :test 'eql)))
  (dotimes (j 100) (setf (gethash j ht) (- j)))
  (maphash #'(lambda (k v)
	       (if (oddp k) (remhash k ht) (puthash k (- v) ht)))
	   ht)
  (let ((k-sum 0) (v-sum 0))
    (maphash #'(lambda (k v) (incf k-sum k) (incf v-sum v)) ht)
    (Assert (= (* 50 49) k-sum))
    (Assert (= v-sum k-sum))))

;;; Test reading and printing of hash-table objects
(let ((h1 #s(hashtable :weakness t :rehash-size 3.0 :rehash-threshold .2 :test eq :data (1 2 3 4)))
      (h2 #s(hash-table :weakness t :rehash-size 3.0 :rehash-threshold .2 :test eq :data (1 2 3 4)))
      (h3 (make-hash-table :weakness t :rehash-size 3.0 :rehash-threshold .2 :test 'eq)))
  (Assert (equal h1 h2))
  (Assert (not (equal h1 h3)))
  (puthash 1 2 h3)
  (puthash 3 4 h3)
  (Assert (equal h1 h3)))

;;; Testing equality of hash tables
(Assert (equal (make-hash-table :test 'eql :size 300 :rehash-threshold .9 :rehash-size 3.0)
	       (make-hash-table :test 'eql)))
(Assert (not (equal (make-hash-table :test 'eq)
		    (make-hash-table :test 'equal))))
(let ((h1 (make-hash-table))
      (h2 (make-hash-table)))
  (Assert (equal h1 h2))
  (Assert (not (eq h1 h2)))
  (puthash 1 2 h1)
  (Assert (not (equal h1 h2)))
  (puthash 1 2 h2)
  (Assert (equal h1 h2))
  (puthash 1 3 h2)
  (Assert (not (equal h1 h2)))
  (clrhash h1)
  (Assert (not (equal h1 h2)))
  (clrhash h2)
  (Assert (equal h1 h2))
  )

;;; Test sxhash
(Assert (= (sxhash "foo") (sxhash "foo")))
(Assert (= (sxhash '(1 2 3)) (sxhash '(1 2 3))))
(Assert (/= (sxhash '(1 2 3)) (sxhash '(3 2 1))))

;; Test #'define-hash-table-test.

(defstruct hash-table-test-structure
  number-identifier padding-zero padding-one padding-two)

(macrolet
    ((good-hash () 65599)
     (hash-modulo-figure ()
       (if (featurep 'bignum)
           (1+ (* most-positive-fixnum 2))
         most-positive-fixnum))
     (hash-table-test-structure-first-hash-figure ()
       (rem* (* 65599 (eq-hash 'hash-table-test-structure))
             (if (featurep 'bignum)
                 (1+ (* most-positive-fixnum 2))
               most-positive-fixnum))))
  (let ((hash-table-test (gensym))
        (no-entry-found (gensym))
        (two 2.0)
        (equal-function
         #'(lambda (object-one object-two)
             (or (equal object-one object-two)
                 (and (hash-table-test-structure-p object-one)
                      (hash-table-test-structure-p object-two)
                      (= (hash-table-test-structure-number-identifier
                          object-one)
                         (hash-table-test-structure-number-identifier
                          object-two))))))
        (hash-function
         #'(lambda (object)
             (if (hash-table-test-structure-p object)
                 (rem* (+ (hash-table-test-structure-first-hash-figure)
                          (equalp-hash
                           (hash-table-test-structure-number-identifier
                            object)))
                       (hash-modulo-figure))
            (equal-hash object))))
        hash-table-test-hash equal-hash)
    (Check-Error wrong-type-argument (define-hash-table-test
                                       "hi there everyone"
                                       equal-function hash-function))
    (Check-Error wrong-number-of-arguments (define-hash-table-test
                                             (gensym)
                                             hash-function hash-function))
    (Check-Error wrong-number-of-arguments (define-hash-table-test
                                             (gensym)
                                             equal-function equal-function))
    (define-hash-table-test hash-table-test equal-function hash-function)
    (Assert (valid-hash-table-test-p hash-table-test))
    (setq equal-hash (make-hash-table :test #'equal)
          hash-table-test-hash (make-hash-table :test hash-table-test))
    (Assert (hash-table-p equal-hash))
    (Assert (hash-table-p hash-table-test-hash))
    (Assert (eq hash-table-test (hash-table-test hash-table-test-hash)))
    (loop
      for ii from 200 below 300
      with structure = nil
      do 
      (setf structure (make-hash-table-test-structure
                       :number-identifier (if (oddp ii) (float (% ii 10))
                                                               (% ii 10))
                       :padding-zero (random)
                       :padding-one (random)
                       :padding-two (random))
            (gethash structure hash-table-test-hash) t
            (gethash structure equal-hash) t))
    (Assert (= (hash-table-count hash-table-test-hash) 10))
    (Assert (= (hash-table-count equal-hash) 100))
    (Assert (eq t (gethash (make-hash-table-test-structure
                            :number-identifier 1
                            :padding-zero (random)
                            :padding-one (random)
                            :padding-two (random))
                           hash-table-test-hash)))
    (Assert (eq t (gethash (make-hash-table-test-structure
                            :number-identifier 2.0
                            :padding-zero (random)
                            :padding-one (random)
                            :padding-two (random))
                           hash-table-test-hash)))
    (Assert (eq no-entry-found (gethash (make-hash-table-test-structure
                                         :number-identifier (+ two 0.0)
                                         :padding-zero (random)
                                         :padding-one (random)
                                         :padding-two (random))
                                        equal-hash
                                        no-entry-found)))))
