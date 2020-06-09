(defpackage :clcm/nodes/bullet-list-item-methods
  (:use :cl
        :clcm/line
        :clcm/node
        :clcm/container-utils
        :clcm/nodes/thematic-break
        :clcm/nodes/atx-heading
        :clcm/nodes/indented-code-block
        :clcm/nodes/fenced-code-block
        :clcm/nodes/html-block
        :clcm/nodes/paragraph
        :clcm/nodes/block-quote
        :clcm/nodes/bullet-list
        :clcm/nodes/bullet-list-item)
  (:import-from :cl-ppcre
                :scan)
  (:export))
(in-package :clcm/nodes/bullet-list-item-methods)

;; for paragraph in block quote
(defun close-paragraph-line (line offset)
  (or (is-blank-line line)
      (is-thematic-break-line line offset)
      (is-atx-heading-line line offset)
      (is-backtick-fenced-code-block-line line offset)
      (is-tilde-fenced-code-block-line line offset)
      (is-html-block-line '(1 2 3 4 5 6) line offset)
      (is-block-quote-line line offset)))

;; close
(defmethod close!? ((node bullet-list-item-node) line offset)
  (multiple-value-bind (indent content) (get-indented-depth-and-line line offset)
    (if (or (and (has-paragraph-as-last node) (close-paragraph-line line offset))
            (and (not (has-paragraph-as-last node)) (< indent (offset node))))
        (close-node node))))

;; add
(defmethod add!? ((node bullet-list-item-node) line offset)
  (multiple-value-bind (indent content) (get-indented-depth-and-line line offset)
    (declare (ignore indent))
    (let ((trimed-line (subseq content (offset node)))
          (child-offset (offset node)))
      (or (skip-blank-line? trimed-line)
          (attach-thematic-break!? node trimed-line child-offset)
          (attach-atx-heading!? node trimed-line child-offset)
          (attach-indented-code-block!? node trimed-line child-offset)
          (attach-fenced-code-block!? node trimed-line child-offset)
          (attach-html-block!? node trimed-line child-offset)
          (attach-block-quote!? node trimed-line child-offset)
          (attach-bullet-list!? node trimed-line child-offset)
          (attach-paragraph! node trimed-line)))))

;; ->html
(defmethod ->html ((node bullet-list-item-node))
  ;; TODO
  (format nil "<li>~%~{~A~}</li>~%"
          (mapcar #'->html (children node))))
