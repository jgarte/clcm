(defpackage :clcm/inlines/special-characters
  (:use :cl
        :clcm/utils
        :clcm/characters
        :clcm/inlines/parser)
  (:import-from :cl-ppcre)
  (:export :scan-special-characters))
(in-package :clcm/inlines/special-characters)

(defun scan-special-characters (parser)
  (cond ((scan parser "^\"")
         (pos+ parser)
         (push-string parser "&quot;"))
        ((scan parser "^<")
         (pos+ parser)
         (push-string parser "&lt;"))
        ((scan parser "^>")
         (pos+ parser)
         (push-string parser "&gt;"))
        ((scan parser "^&")
         (pos+ parser)
         (push-string parser "&amp;"))
        (t nil)))