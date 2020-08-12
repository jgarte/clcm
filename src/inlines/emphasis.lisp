(defpackage :clcm/inlines/emphasis
  (:use :cl
        :clcm/utils
        :clcm/characters
        :clcm/inlines/parser)
  (:export :scan-emphasis
           :process-emphasis))
(in-package :clcm/inlines/emphasis)

(defun scan-emphasis (parser)
  (let ((type (get-type parser)))
    (when type
      (let* ((delimiter-run (get-delimiter-run type parser))
             (len (length delimiter-run))
             (close nil)
             (open nil))
        (setf open (can-open type parser))
        (setf close (can-close type parser))
        (when (or open close)
          (push-op parser (make-delimiter :type type 
                                          :start (fill-pointer (ip-queue parser))
                                          :num len
                                          :open open
                                          :close close))
          (push-string parser delimiter-run)
          (pos+ parser len))))))

;; type
(defun get-type (parser)
  (cond ((scan parser "^\\*") :*)
        ((scan parser "^_") :_)
        (t nil)))

;; delimiter-run
(defun get-delimiter-run-length (type parser)
  (length (get-delimiter-run type parser)))

(defun get-delimiter-run (type parser)
  (let ((char (case type (:* #\*) (:_ #\_))))
    (format nil "~{~A~}" 
            (loop :for n :from 0
                  :for c := (peek-c parser n)
                  :while (and c (char= c char))
                  :collect char))))

;; can-open
(defun can-open (type parser)
  (case type
    (:* (*-can-open parser))
    (:_ (_-can-open parser))))

(defun *-can-open (parser)
  (is-left-flanking-delimiter-run :* parser))

(defun _-can-open (parser)
  (and (is-left-flanking-delimiter-run :_ parser)
       (or (not (is-right-flanking-delimiter-run :_ parser))
           (is-right-flanking-delimiter-run :_ parser :preceded-by-punctuation t))))

;; can-close
(defun can-close (type parser)
  (case type
    (:* (*-can-close parser))
    (:_ (_-can-close parser))))

(defun *-can-close (parser)
  (is-right-flanking-delimiter-run :* parser))

(defun _-can-close (parser)
  (and (is-right-flanking-delimiter-run :_ parser)
       (or (not (is-left-flanking-delimiter-run :_ parser))
           (is-left-flanking-delimiter-run :_ parser :followed-by-punctuation t))))

;; delimiter run TODO
(defun is-left-flanking-delimiter-run (type parser &key followed-by-punctuation)
  ; [followed-by-punctuation] (*)
  ; t -> followed by punctuation
  ; nil -> followed by any character
  (let ((len (get-delimiter-run-length type parser)))
    (and (not (followed-by-unicode-whitespace len parser)) ; (1)
         (or (not (followed-by-punctuation-character len parser)) ; (2a)
             (and (followed-by-punctuation-character len parser) ; (2b)
                  (or (preceded-by-unicode-whitespace parser) 
                      (preceded-by-punctuation-character parser))))
         (or (null followed-by-punctuation) ; for option (*)
             (followed-by-punctuation-character len parser)))))

(defun is-right-flanking-delimiter-run (type parser &key preceded-by-punctuation)
  ; [preceded-by-punctuation]
  ; t -> preceded by punctuation
  ; nil -> preceded by any character
  (let ((len (get-delimiter-run-length type parser)))
    (and (not (preceded-by-unicode-whitespace parser)) ; (1)
         (or (not (preceded-by-punctuation-character parser)) ; (2a)
             (and (preceded-by-punctuation-character parser) ; (2b)
                  (or (followed-by-unicode-whitespace len parser) 
                      (followed-by-punctuation-character len parser))))
         (or (null preceded-by-punctuation) ; for option (*)
             (preceded-by-punctuation-character parser)))))

(defun preceded-by-unicode-whitespace (parser)
  (let ((char (peek-c parser -1)))
    (or (null char) ; the beginning and the end of the line count as Unicode whitespace
        (find char *unicode-whitespaces*))))

(defun followed-by-unicode-whitespace (len parser)
  (let ((char (peek-c parser len)))
    (or (null char) ; the beginning and the end of the line count as Unicode whitespace
        (find char *unicode-whitespaces*))))

(defun preceded-by-punctuation-character (parser)
  (find (peek-c parser -1) *punctuations*))

(defun followed-by-punctuation-character (len parser)
  (find (peek-c parser len) *punctuations*))

;; process emphasis
(defun process-emphasis (parser)
  (let ((delims (ip-stack parser))
        (offset 0) ;
        (stack nil))
    (loop :for delimiter :across delims
          :do (cond ((not (or (eq (dl-type delimiter) :*)
                              (eq (dl-type delimiter) :_)))
                     :do-nothing)
                    ((and (null stack)
                          (not (dl-open delimiter))
                          (dl-close delimiter))
                     :do-nothing)
                    ((and (dl-close delimiter)
                          (find-opener delimiter stack))
                     (shift-position delimiter offset)
                     (multiple-value-bind (new-stack new-offset)
                         (close-emphasis parser delimiter stack offset)
                       (setf stack new-stack)
                       (setf offset new-offset)))
                    ((dl-open delimiter)
                     (shift-position delimiter offset)
                     (push delimiter stack))
                    ((dl-close delimiter)
                     :do-nothing)
                    (t
                     (error "TYPE: ~A, OPEN: ~A, CLOSE: ~A, EMPTY?: ~A"
                            (dl-type delimiter)
                            (dl-open delimiter)
                            (dl-close delimiter)
                            (null stack)))))))

(defun find-opener (delimiter stack)
  (let ((type (dl-type delimiter)))
    (labels ((find-opener% (type stack)
               (when stack
                 (if (and (eq (dl-type (car stack)) type)
                          (dl-open (car stack)))
                     (values (car stack) (cdr stack))
                     (find-opener% type (cdr stack))))))
      (find-opener% type stack))))

(defun close-emphasis (parser closer stack offset)
  (multiple-value-bind (opener rest)
      (find-opener closer stack)
    (cond ((null opener)
           (values (if (dl-open closer) (cons closer stack) stack)
                   offset))
          ((< (dl-num opener) (dl-num closer))
           (let* ((len (dl-num opener))
                  (new-offset (+ offset (delimiter-run->tag parser opener closer len)))
                  (new-closer (make-delimiter :type (dl-type closer)
                                              :start (+ (dl-start closer) len offset)
                                              :num (- (dl-num closer) len)
                                              :open (dl-open closer)
                                              :close (dl-close closer))))
             (close-emphasis parser new-closer rest new-offset)))
          ((= (dl-num opener) (dl-num closer))
           (let* ((len (dl-num closer))
                  (new-offset (+ offset (delimiter-run->tag parser opener closer len))))
             (values rest new-offset)))
          ((> (dl-num opener) (dl-num closer))
           (let* ((len (dl-num closer))
                  (new-offset (+ offset (delimiter-run->tag parser opener closer len)))
                  (new-opener (make-delimiter :type (dl-type opener)
                                              :start (dl-start opener)
                                              :num (- (dl-num opener) len)
                                              :open (dl-open opener)
                                              :close (dl-close opener))))
             (values (cons new-opener rest) new-offset)))
          (t
           (error "CLOSER: ~A, OPENER ~A"
                  closer opener)))))

;;
(defun delimiter-run->tag (parser opener closer len)
  (let ((open-pos (+ (dl-start opener) (- (dl-num opener) len)))
        (close-pos (dl-start closer)))
    (multiple-value-bind (strong-num em-num) (floor len 2)
      (let* ((open-tag (format nil "~{~A~}~{~A~}" 
                               (loop :repeat strong-num :collect "<strong>")
                               (loop :repeat em-num :collect "<em>")))
             (close-tag (format nil "~{~A~}~{~A~}"
                                (loop :repeat em-num :collect "</em>")
                                (loop :repeat strong-num :collect "</strong>")))
             (new-offset 0))
        ; TODO output (replace) tag
        (replace-string parser open-tag open-pos (+ open-pos len))
        (incf new-offset (- (length open-tag) len))
        (replace-string parser close-tag (+ close-pos new-offset) (+ close-pos len new-offset))
        (incf new-offset (- (length close-tag) len))
        ; return new offset
        new-offset))))
