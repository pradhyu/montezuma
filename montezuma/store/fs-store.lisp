(in-package #:montezuma)


(defvar *directory-cache*
  (make-hash-table :test #'equal))

(defun make-fs-directory (path &key create-p)
  (setf path (cl-fad:pathname-as-directory path))
  (when create-p
    (ensure-directories-exist path))
  (let ((truename (truename path)))
    (let ((dir (gethash truename *directory-cache*)))
      (unless dir
	(setf dir (make-instance 'fs-directory :path path))
	(setf (gethash truename *directory-cache*) dir))
      (when create-p
	(refresh dir))
      dir)))

(defun clear-fs-directory-cache ()
  (setf *directory-cache* (make-hash-table :test #'equal)))


(defclass fs-directory (directory)
  ((path :initarg :path)))


(defmethod initialize-instance :after ((self fs-directory) &key)
  (with-slots (path) self
    (unless (cl-fad:directory-exists-p path)
      (error "The directory ~S does not exist."))
    ;; FIXME: do the locking
    ))


(defmethod full-path-for-file ((self fs-directory) file)
  (with-slots (path) self
    (merge-pathnames (pathname file) path)))

(defmethod refresh ((self fs-directory))
  ;; Delete all files
  (dolist (file (files self))
    (delete-file self file))
  ;; Remove all locks
  )

(defmethod files ((self fs-directory))
  (with-slots (path) self  
    (mapcar #'(lambda (file-path)
		(enough-namestring file-path path))
	    (cl-fad:list-directory path))))

(defmethod file-exists-p ((self fs-directory) file)
  (probe-file (full-path-for-file self file)))

(defmethod touch ((self fs-directory) file)
  (let ((file-path (full-path-for-file self file)))
    (if (probe-file file-path)
	;; FIXME: Set file-write-date.
	nil
	(with-open-file (f file-path :direction :output :if-does-not-exist :create)
	  (declare (ignore f))))))

(defmethod delete-file ((self fs-directory) file)
  (cl:delete-file (full-path-for-file self file)))

(defmethod rename-file ((self fs-directory) from to)
  (let ((from-path (full-path-for-file self from))
	(to-path (full-path-for-file self to)))
    (cl:rename-file from-path to-path :if-exists :error)))

(defmethod modified-time ((self fs-directory) file)
  (file-write-date (full-path-for-file self file)))

(defmethod file-size ((self fs-directory) file)
  (with-open-file (f (full-path-for-file self file)
		     :direction :input)
    (cl:file-length f)))

(defmethod create-output ((self fs-directory) file)
  (make-instance 'fs-index-output :path (full-path-for-file self file)))

(defmethod open-input ((self fs-directory) file)
  (make-instance 'fs-index-input :path (full-path-for-file self file)))



(defclass fs-index-output (buffered-index-output)
  ((file)))

(defmethod initialize-instance :after ((self fs-index-output) &key path)
  (with-slots (file) self
    (setf file (open path :direction :output :element-type '(unsigned-byte 8)))))

(defmethod close :after ((self fs-index-output))
  (with-slots (file) self
    (cl:close file)))

(defmethod seek :after ((self fs-index-output) pos)
  (with-slots (file) self
    (file-position file pos)))

(defmethod flush-buffer ((self fs-index-output) b size)
  (with-slots (file) self
    (write-sequence b file :start 0 :end size)))


(defclass fs-index-input (buffered-index-input)
  ((file)
   (is-clone-p :initform NIL)
   (size :reader size)))

(defmethod initialize-instance :after ((self fs-index-input) &key path)
  (when path
    (with-slots (file size) self
      (setf file (open path :direction :input :element-type '(unsigned-byte 8)))
      (setf size (cl:file-length file)))))

(defmethod close ((self fs-index-input))
  (with-slots (file is-clone-p) self
    (unless is-clone-p
      (cl:close file))))

(defmethod initialize-copy :after ((self fs-index-input) o)
  (with-slots (file is-clone-p size) self
    (setf file (slot-value o 'file))
    (setf size (slot-value o 'size))
    (setf is-clone-p T)))

(defmethod read-internal ((self fs-index-input) b offset length)
  (with-slots (file) self
    (let ((position (pos self)))
      (when (not (= position (file-position file)))
	(file-position file position)))
    (let* ((bytes (make-array (list length)))
	   (num-bytes-read (read-sequence bytes file)))
      (unless (= num-bytes-read length)
	(error "End of file error while reading ~S" file))
      (replace b bytes
	       :start1 offset :end1 (+ offset num-bytes-read)))))

(defmethod seek-internal ((self fs-index-input) pos)
  (with-slots (file) self
    (file-position file pos)))



