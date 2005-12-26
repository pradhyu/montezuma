(in-package #:montezuma)

(defclass term-doc-enum ()
  ())

(defgeneric seek (term-doc-enum pos))

(defgeneric doc (term-doc-enum))

(defgeneric freq (term-doc-enum))

(defgeneric next (term-doc-enum))

(defgeneric read (term-doc-enum docs freqs))

(defmethod skip-to ((self term-doc-enum) target)
  (while (> target (doc self))
    (unless (next self)
      (return-from skip-to NIL)))
  T)

(defgeneric close (term-doc-enum))

(defclass segment-term-doc-enum (term-doc-enum)
  ((parent :initarg :parent)
   (freq-stream)
   (deleted-docs)
   (skip-interval)
   (skip-stream :initform NIL)
   (doc :initform 0)))

(defmethod initialize-instance :after ((self segment-term-doc-enum))
  (with-slots (freq-stream deleted-docs skip-interval) self
    (let ((parent (slot-value self 'parent)))
      (setf freq-stream (clone (freq-stream parent))
	    deleted-docs (deleted-docs parent)
	    skip-interval (skip-interval (skip-infos parent))))))


;; te can be a term, term-enum or term-info object.

(defmethod seek ((self segment-term-doc-enum) (term term))
  (do-seek self (term-infos parent term)))

(defmethod seek ((self segment-term-doc-enum) (term-enum term-enum))
  (do-seek self (term-info term-enum)))

(defmethod seek ((self segment-term-doc-enum) (term-info term-info))
  (do-seek self term-info))

(defmethod do-seek ((self segment-term-doc-enum) term-info)
  (with-slots (count doc-freq  doc skip-doc skip-count num-skips freq-pointer
		     prox-pointer skip-pointer freq-stream have-skipped) self
    (setf count 0)
    (if (null term-info)
	(setf doc-freq 0)
	(progn
	  (setf doc-freq (doc-freq term-info)
		doc 0
		skip-doc 0
		skip-count 0
		num-skips (/ doc-freq skip-interval)
		freq-pointer (freq-pointer term-info)
		prox-pointer (prox-pointer term-info)
		skip-pointer (+ freq-pointer (skip-offset term-info))
		have-skipped NIL)
	  (seek freq-stream freq-pointer)))))

(defmethod close ((self segment-term-doc-enum))
  (with-slots (freq-stream skip-stream parent) self
    (close freq-stream)
    (setf freq-stream nil)
    (when skip-stream
      (close skip-stream)
      (setf skip-stream nil))
    (setf parent nil)))

(defmethod skipping-doc ((self segment-term-doc-enum))
  )

(defmethod next ((self segment-term-doc-enum))
  (with-slots (count doc-freq freq-stream) self
  (while T
    (when (eql count doc-freq)
      return NIL)
    (let ((doc-code (read-vint freq-stream)))
      (incf doc (ash doc-code -1))
      (if (logbitp 0 doc-code)
	  (setf freq 1)
	  (setf freq (read-vint freq-stream)))
      (incf count)
      (when (or (null deleted-docs) (not (aref deleted-docs doc)))
	(return T))
      (skipping-doc self)))))

(defmethod read ((self segment-term-doc-enum) docs freqs &optional (start 0))
  (with-slots (doc-freq  freq-stream doc count deleted-docs freq) self
    (let ((i start)
	  (needed (length docs)))
      (while (and (< i needed) (< count doc-freq))
	(let ((doc-code (read-vint freq-stream)))
	  (incf doc (ash doc-code -1))
	  (if (logbitp 0 doc-code)
	      (setf freq 1)
	      (setf freq (read-vint freq)))
	  (incf count)
	  (when (or (null deleted-docs) (not (aref deleted-docs doc)))
	      (setf (aref docs i) doc
		    (aref freqs i) freq)
	      (incf i))
	  (skipping-doc)))
      i)))

(defmethod skip-prox ((self segment-term-doc-enum) prox-pointer)
)

(defmethod skip-to ((self segment-term-doc-enum) target)
  (with-slots (doc-freq skip-interval skip-stream have-skipped skip-pointer) self
    (when (>= doc-freq skip-interval)
      (when (null skip-sream)
	(setf skip-stream (clone freq-stream)))
      (unless have-skipped
	(seek skip-stream skip-pointer)
	(setf have-skipped T))
      (let ((last-skip-doc skip-doc)
	    (last-freq-pointer (pos freq-stream))
	    (last-prox-pointer -1)
	    (num-skipped (- -1 (mod count skip-interval))))
	(while (> target skip-doc)
	  (setf last-skip-doc skip-doc
		last-freq-pointer freq-pointer
		last-prox-pointer prox-pointer)

	  (when (and (not (= skip-doc 0)) (>= skip-doc doc))
	    (incf num-skipped skip-interval))
	  (when (>= skip-cout num-skips)
	    (return))
	  
	  (incf skip-doc (read-vint skip-stream))
	  (incf freq-pointer (read-vint skip-stream))
	  (incf prox-pointer (read-vint skip-stream))
	  
	  (incf skip-count))
	;; If we found something to skip, then skip it.
	(when (> last-freq-pointer (pos freq-stream))
	  (seek freq-stream last-freq-pointer)
	  (skip-prox self last-prox-pointer)
	  (setf doc last-skip-doc)
	  (incf count num-skipped))))
    ;; Done skipping, now just scan.
    (do ((next (next self) (next self)))
	((or (null next) (>= doc target))
	 (if (null next)
	     NIL
	     T)))))


(defclass segment-term-doc-pos-enum (segment-term-doc-enum)
  ())

(defmethod initialize-instance :after ((self segment-term-doc-pos-enum) &key)
  (with-slots (parent prox-stream) self
    (setf prox-stream (clone (prox-stream parent)))))

(defmethod do-seek :after ((self segment-term-doc-pos-enum) ti)
  (with-slots (prox-stream prox-count)
      (unless (null ti)
	(seek prox-stream (prox-pointer ti)))
    (setf prox-count 0)))

(defmethod close :after ((self segment-term-doc-pos-enum))
  (with-slots (prox-stream) self
    (close prox-stream)))

(defmethod next-position ((self segment-term-doc-pos-enum))
  (with-slots (prox-count position prox-stream) self
    (decf prox-count)
    (incf position (read-vint prox-stream))))

(defmethod skipping-doc ((self segment-term-doc-pos-enum))
  (with-slots (freq prox-stream) self
    (dotimes (i freq)
      (read-vint prox-stream))))

(defmethod next :around ((self segment-term-doc-pos-enum))
  (with-slots (prox-count prox-stream position) self
    (dotimes (i prox-count)
      (read-vint prox-stream))
    (if (call-next-method)
	(progn
	  (setf prox-count freq
		position 0)
	  T)
	NIL)))

(defmethod read ((self segment-term-doc-pos-enum) docs freqs)
  (error "The class term-doc-pos-enum does not support processing multiple documents in one call.  Use the term-doc-enum class instead."))

(defmethod skip-prox ((self segment-term-doc-pos-enum) prox-pointer)
  (with-slots (prox-stream prox-count) self
    (seek prox-stream prox-pointer)
    (setf prox-count 0)))

				
