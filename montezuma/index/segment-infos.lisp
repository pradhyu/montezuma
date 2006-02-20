(in-package #:montezuma)

(defclass segment-info ()
  ((name :initarg :name :accessor segment-info-name)
   (doc-count :initarg :doc-count :accessor doc-count)
   (directory :initarg :directory :accessor directory)))

(defmethod segment-info= ((self segment-info) other)
  (with-slots (name doc-count) self
    (and (typep other 'segment-info)
	 (string= name (slot-value other 'name))
	 (eql doc-count (slot-value other 'doc-count)))))

(defparameter *segment-format* -1)
(defparameter *segment-filename* "segments")
(defparameter *temporary-segment-filename* "segments.new")


(defclass segment-infos ()
  ((format)
   (version :initform (get-universal-time) :reader version)
   (counter :initform 0 :accessor counter)
   (elements :initform (make-array 0 :adjustable T :fill-pointer T))))

(defmethod size ((self segment-infos))
  (with-slots (elements) self
    (length elements)))

(defmethod delete-at ((self segment-infos) index)
  (with-slots (elements) self
    ;; FIXME truly atrocious
    (let ((new-elements (concatenate 'vector (subseq elements 0 index) (subseq elements (+ index 1)))))
    (setf elements (make-array (length new-elements) :adjustable T :fill-pointer T :initial-contents new-elements)))))

(defmethod add-segment-info ((self segment-infos) si)
  (with-slots (elements) self
    (vector-push-extend si elements)))

(defmethod segment-info ((self segment-infos) index)
  (with-slots (elements) self
    (elt elements index)))

(defmethod (setf segment-info) (value (self segment-infos) index)
  (with-slots (elements) self
    (assert (< index (length elements)))
    (setf (elt elements index) value)))

(defmethod initialize-copy :after ((self segment-infos) other)
  (dotimes (i (size other))
    (setf (segment-info self i) (clone (segment-info other i)))))

(defmethod read-current-version-segment-infos ((self segment-infos) directory)
  (if (not (file-exists-p directory *segment-filename*))
      0
      (with-slots (format version) self
	(let ((input (open-input directory *segment-filename*)))
	  (unwind-protect
	       (progn
		 (setf format 0)
		 (setf version 0)
		 (setf format (read-int input))
		 (when (< format 0)
		   (when (< format *segment-format*)
		     (error "Unknown format version ~S" format))
		   (setf version (read-long input))))
	    (close input)))
	(let ((sis (make-instance 'segment-infos)))
	  (read-segment-infos sis directory)
	  (version sis)))))
	
(defmethod read-segment-infos ((self segment-infos) directory)
  (let ((input (open-input directory *segment-filename*)))
    (unwind-protect
	 (with-slots (format counter version elements) self
	   (setf format (read-int input))
	   (if (< format 0)
	       (progn
		 (when (< format *segment-format*)
		   (error "Unknown format version ~S" format))
		 (setf version (read-long input))
		 (setf counter (read-int input)))
	       (setf counter format))
	   (let ((seg-count (read-int input)))
	     (dotimes (i seg-count)
	       (add-segment-info self
				 (make-instance 'segment-info
						:name (read-string input)
						:doc-count (read-int input)
						:directory directory))))
	   (when (>= format 0)
	     (if (>= (pos input) (size input))
		 (setf version 0)
		 (setf version (read-long input)))))
      (close input))))

(defmethod write-segment-infos ((self segment-infos) directory)
  (let ((output (create-output directory *temporary-segment-filename*)))
    (unwind-protect
	 (with-slots (version counter elements) self
	   (write-int output *segment-format*)
	   (write-long output (incf version))
	   (write-int output counter)
	   (write-int output (size self))
	   (dotimes (i (length elements))
	     (let ((si (segment-info self i)))
	       (write-string output (segment-info-name si))
	       (write-int output (doc-count si)))))
      (close output)))
  (rename-file directory *temporary-segment-filename* *segment-filename*))