;;; This library implements a simple neural network.
;;; Copyright 2019-2020 Guillaume Le Vaillant
;;; This library is free software released under the GNU GPL-3 license.

(defpackage :simple-neural-network/test
  (:use :cl :fiveam :simple-neural-network)
  (:import-from :simple-neural-network
                #:neural-network-layers
                #:neural-network-weights
                #:neural-network-biases
                #:neural-network-deltas))

(in-package :simple-neural-network/test)


(def-suite snn-tests
  :description "Unit tests for simple neural network.")

(in-suite snn-tests)


(test nn-xor
  (let ((inputs '(#(0.0d0 0.0d0)
                  #(0.0d0 1.0d0)
                  #(1.0d0 0.0d0)
                  #(1.0d0 1.0d0)))
        (targets '(#(0.0d0)
                   #(1.0d0)
                   #(1.0d0)
                   #(0.0d0)))
        (nn (create-neural-network 2 1 2)))
    (dotimes (i 30000)
      (train nn inputs targets 0.5d0))
    (flet ((same-value-p (output target)
             (let ((x (aref output 0))
                   (y (aref target 0)))
               (= (if (< x 1/2) 0 1) y))))
      (destructuring-bind (inputs targets)
          (loop
            repeat 10
            for x = (random 2)
            for y = (random 2)
            collect (vector (float x 1.0d0) (float y 1.0d0)) into inputs
            collect (vector (logxor x y)) into targets
            finally (return (list inputs targets)))
        (is (= 1 (accuracy nn inputs targets :test #'same-value-p)))))))

(test nn-cos
  (let* ((limit (float (/ pi 2) 1.0d0))
         (inputs (loop repeat 1000 collect (vector (random limit))))
         (targets (mapcar (lambda (input)
                            (vector (cos (aref input 0))))
                          inputs))
         (nn (create-neural-network 1 1 3 3)))
    (dotimes (i 2000)
      (train nn inputs targets 0.8d0))
    (flet ((close-enough-p (output target)
             (let ((x (aref output 0))
                   (y (aref target 0)))
               (< (abs (- x y)) 0.02))))
      (destructuring-bind (inputs targets)
          (loop
            repeat 10
            for x = (random limit)
            collect (vector x) into inputs
            collect (vector (cos x)) into targets
            finally (return (list inputs targets)))
        (is (= 1 (accuracy nn inputs targets :test #'close-enough-p)))))))

(defun mnist-file-path (filename)
  (asdf:system-relative-pathname "simple-neural-network"
                                 (concatenate 'string "tests/" filename)))

(defun mnist-read-and-normalize-image (data offset)
  (let ((image (make-array (* 28 28)
                           :element-type 'double-float
                           :initial-element 0.0d0)))
    (dotimes (i (* 28 28) image)
      (setf (aref image i) (/ (aref data (+ offset i)) 255.0d0)))))

(defun mnist-read-and-normalize-label (data offset)
  (let ((target (make-array 10
                            :element-type 'double-float
                            :initial-element 0.0d0))
        (category (aref data offset)))
    (setf (aref target category) 1.0d0)
    target))

(defun mnist-load (type)
  (destructuring-bind (n-images images-path labels-path)
      (if (eql type :train)
          (list 60000
                (mnist-file-path "train-images-idx3-ubyte.gz")
                (mnist-file-path "train-labels-idx1-ubyte.gz"))
          (list 10000
                (mnist-file-path "t10k-images-idx3-ubyte.gz")
                (mnist-file-path "t10k-labels-idx1-ubyte.gz")))
    (let ((images (with-open-file (f images-path
                                     :element-type '(unsigned-byte 8))
                    (let ((images-data (chipz:decompress nil 'chipz:gzip f)))
                      (loop for i from 0 below n-images
                            for offset = (+ 16 (* i 28 28))
                            collect (mnist-read-and-normalize-image images-data
                                                                    offset)))))
          (labels (with-open-file (f labels-path
                                     :element-type '(unsigned-byte 8))
                    (let ((labels-data (chipz:decompress nil 'chipz:gzip f)))
                      (loop for i from 0 below n-images
                            collect (mnist-read-and-normalize-label labels-data
                                                                    (+ 8 i)))))))
      (values images labels))))

(test nn-mnist
  (let ((nn (create-neural-network (* 28 28) 10 128)))
    (multiple-value-bind (inputs targets) (mnist-load :train)
      (train nn inputs targets 0.5d0))
    (multiple-value-bind (inputs targets) (mnist-load :test)
      (is (< 0.8 (accuracy nn inputs targets))))))

(test store/restore
  (let ((nn1 (create-neural-network 3 2 4))
        (input #(0.2d0 0.5d0 0.1d0))
        (target #(0.1d0 0.2d0 0.3d0 0.4d0)))
    (train nn1 (list input) (list target) 0.6d0)
    (uiop:with-temporary-file (:pathname path)
      (store nn1 path)
      (let ((nn2 (restore path)))
        (is (equalp (neural-network-layers nn1)
                    (neural-network-layers nn2)))
        (is (equalp (neural-network-weights nn1)
                    (neural-network-weights nn2)))
        (is (equalp (neural-network-biases nn1)
                    (neural-network-biases nn2)))
        (is (equalp (neural-network-deltas nn1)
                    (neural-network-deltas nn2)))))))
