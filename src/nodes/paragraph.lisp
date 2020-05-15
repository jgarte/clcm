(defpackage :clcm/nodes/paragraph
  (:use :cl :clcm/node)
  (:import-from :clcm/line
                :is-blank-line)
  (:export :paragraph-node))
(in-package :clcm/nodes/paragraph)

(defclass paragraph-node (node)
  ())

(defmethod close!? ((node paragraph-node) line)
  (when (is-blank-line line)
    (close-node node)))

(defmethod add!? ((node paragraph-node) line)
  (add-child node line))