(in-package #:montezuma)


(defvar *valid-index-options*
  '(:path :create-if-missing-p :create-p :default-field
    :id-field :default-search-field :analyzer :directory
    :close-directory-p :occur-default :wild-lower-p :default-slop
    :key :use-compound-file-p :handle-parse-errors-p :auto-flush-p))

(defun index-options-list-p (list)
  (do ((options list (cddr options)))
      ((endp options) T)
    (when (not (member (car options) *valid-index-options*))
      (return-from index-options-list-p NIL))))

(deftype index-option () `(member ,@*valid-index-options*))
(deftype index-options-list () '(satisfies index-options-list-p))

(defun get-index-option (options option)
  (check-type option index-option)
  (getf options option))

(define-setf-expander get-index-option (place option &environment env)
  (multiple-value-bind (vars vals store-vars writer-form reader-form)
      (get-setf-expansion place env)
    (declare (ignore writer-form))
    (let ((goption (gensym "OPTION"))
	  (gstore (if store-vars (first store-vars) (gensym "STORE"))))
      (values
       (list* goption vars)
       (list* option vals)
       (list gstore)
       `(progn
	  (check-type ,goption index-option)
	  (setf (getf ,reader-form ,goption) ,(car store-vars)))
       `(getf ,goption ,reader-form)))))


(defclass index ()
  ((key)
   (dir)
   (has-writes-p :initform NIL)
   (reader :initform nil)
   (writer)
   (close-dir-p)
   (auto-flush-p)
   (default-search-field)
   (default-field)
   (analyzer)
   (open-p :initform T)
   (options)
   (qp :initform nil)))
   

(defmethod initialize-instance :after ((self index) &rest args &key &allow-other-keys)
  (with-slots (options) self
    (check-type args index-options-list)
    (setf options (copy-list args))
    (setf (get-index-option options :default-search-field) (if (get-index-option options :default-search-field) (string (get-index-option options :default-search-field)) "")
	  (get-index-option options :default-field) (if (get-index-option options :default-field) (string (get-index-option options :default-field)) ""))
    (when (null (get-index-option options :create-if-missing-p))
      (setf (get-index-option options :create-if-missing-p) T))
    ;; FIXME: I don't flatten the :key option, I'm not sure why Ferret does.
    (with-slots (key dir options close-dir-p auto-flush-p create-p analyzer writer
		     default-search-field default-field) self
      (setf key (get-index-option options :key))
      (cond ((get-index-option options :path)
	     (setf dir (make-fs-directory (get-index-option options :path)
					  :create-p (or (get-index-option options :create-p)
							(get-index-option options :create-if-missing-p))))
	     (setf (get-index-option options :close-dir-p) T))
	    ((get-index-option options :directory)
	     (setf dir (get-index-option options :directory)))
	    (T
	     (setf (get-index-option options :create-p) T)
	     (setf dir (make-instance 'ram-directory))))
      ;; Create the index if need be
      (setf writer (apply #'make-instance 'index-writer
			  :directory dir
			  options))
      (setf (get-index-option options :analyzer) (setf analyzer (analyzer writer)))
      (close writer)
      (setf writer nil)
      ;; Only want to create the first time, if at all.
      (setf (get-index-option options :create-p) NIL)
      (setf close-dir-p (get-index-option options :close-directory-p))
      (setf (get-index-option options :close-directory-p) NIL)
      (setf auto-flush-p (get-index-option options :auto-flush-p))
      (setf default-search-field (or (get-index-option options :default-search-field)
				     (get-index-option options :default-field)
				     "*"))
      (setf default-field (or (get-index-option options :default-field) ""))
      (when (not (get-index-option options :handle-parse-errors-p))
	(setf (get-index-option options :handle-parse-errors-p) T)))))
    

(defmethod close ((self index))
  (with-slots (open-p reader writer dir) self
    (when (not open-p)
      (error "Tried to close an already closed directory."))
    (when reader (close reader))
    (when writer (close writer))
    (close dir)
    (setf open-p NIL)))

(defmethod reader ((self index))
  (ensure-reader-open self)
  (slot-value self 'reader))

(defmethod searcher ((self index))
  (ensure-searcher-open self)
  (slot-value self 'searcher))

(defmethod writer ((self index))
  (ensure-writer-open self)
  (slot-value self 'writer))


(defmethod add-document-to-index ((self index) doc &optional analyzer)
  (let ((fdoc nil)
	(default-field (slot-value self 'default-field)))
    (when (listp doc)
      ;; Turn association lists into something we can treat like any
      ;; other table (including hash tables).
      (setf doc (convert-alist-to-table doc)))
    (cond ((stringp doc)
	   (setf fdoc (make-instance 'document))
	   (add-field fdoc (make-field default-field doc
				       :stored T :index :tokenized)))
	  ((typep doc 'array)
	   (setf fdoc (make-instance 'document))
	   (dosequence (field doc)
	     (add-field fdoc (make-field default-field field
					 :stored T :index :tokenized))))
	  ((table-like-p doc)
	   (setf fdoc (make-instance 'document))
	   (dolist (field (table-keys doc))
	     (let ((text (table-value doc field)))
	       (add-field fdoc (make-field (string field) (string text)
					  :stored T :index :tokenized)))))
	  ((typep doc 'document)
	   (setf fdoc doc))
	  (T
	   (error "Unknown document type ~S" doc)))
    ;; Delete existing documents with the same key.
    (let ((key (slot-value self 'key)))
      (when key
	(let ((query (inject key (make-instance 'boolean-query)
			     #'(lambda (query field)
				 (add-query query (make-instance 'term-query
								 :term (make-term field (get-field fdoc field))
								 :options :must))))))
	  (query-delete self query))))
    (let ((writer (writer self)))
      (setf (slot-value self 'has-writes-p) T)
      (add-document-to-index-writer (slot-value self 'writer) fdoc
				    (if analyzer analyzer (analyzer writer)))
      (when (slot-value self 'auto-flush-p)
	(flush self)))))


;; The main search method for the index. You need to create a query to
;; pass to this method. You can also pass a hash with one or more of
;; the following; {filter, num_docs, first_doc, sort}
;;
;; query::      The query to run on the index
;; filter::     Filters docs from the search result
;; first_doc::  The index in the results of the first doc retrieved.
;;              Default is 0
;; num_docs::   The number of results returned. Default is 10
;; sort::       An array of SortFields describing how to sort the results.

(defmethod search ((self index) query &optional options)
  (do-search self query options))


(defmethod search-each ((self index) query &optional options)
  (let ((hits (do-search self query options)))
    (append-pipes (map-pipe #'(lambda (score-doc)
				(list (doc score-doc) (score score-doc)))
			    (score-docs hits))
		  (list (total-hits hits)))))
	 

(defmethod get-document ((self index) id)
  (let ((reader (reader self)))
    (cond ((stringp id)
	   (get-document-with-term reader (make-term "id" id)))
	  ((typep id 'term)
	   (get-document-with-term reader id))
	  (T
	   (get-document reader id)))))

(defmethod delete ((self index) id)
  (let ((reader (reader self)))
    (let ((count (cond ((stringp id)
			(delete-docs-with-term reader (make-term "id" id)))
		       ((typep id 'term)
			(delete-docs-with-term reader id))
		       ((integerp id)
			(delete reader id))
		       (T
			(error "Cann't delete for id ~S" id)))))
      (when (slot-value self 'auto-flush-p)
	(flush self))
      count)))

(defmethod query-delete ((self index) query)
  (let ((reader (reader self))
	(searcher (searcher self))
	(query (process-query self query)))
    (enumerate (search-each searcher query)
	       :key #'(lambda (pair)
			(destructuring-bind (doc score) pair
			  (declare (ignore score))
			  (delete reader doc))))
    (when (slot-value self 'auto-flush-p)
      (flush self))))

(defmethod deleted-p ((self index) n)
  (deleted-p (reader self) n))


(defmethod update ((self index) id new-val)
  (with-slots (options) self
    (cond ((stringp id)
	   ;; FIXME: how about using a pre-parsed form of query?
	   (query-update self (format nil "id:~A" id) new-val))
	  ((typep id 'term)
	   (query-update self
			 (make-instance 'term-query
					:term id)
			 new-val))
	  ((integerp id)
	   (let ((reader (reader self))
		 (document (get-document self id)))
	     (when (listp new-val)
	       (setf new-val (convert-alist-to-table new-val)))
	     (cond ((table-like-p new-val)
		    (dolist (name (table-keys new-val))
		      (let ((content (table-value new-val name)))
			(setf (aref document name) (string content)))))
		   ((typep new-val 'document)
		    (setf document new-val))
		   (T
		    (setf (aref document (get-index-option options :default-field))
			  (string new-val))))
	     (delete reader id)
	     (let ((writer (writer self)))
	       (add-document-to-index-writer writer document))))
	  (T
	   (error "Cannot update for id ~S" id)))
    (when (slot-value self 'auto-flush-p)
      (flush self))))

(defmethod query-update ((self index) query new-val)
  (let ((searcher (searcher self))
	(reader (reader self))
	(docs-to-add '())
	(query (process-query self query)))
    (let ((results (enumerate (search-each searcher query))))
      (dolist (result results)
	(destructuring-bind (id score) result
	  (declare (ignore score))
	  (let ((document (get-document self id)))
	    (when (listp new-val)
	      (setf new-val (convert-alist-to-table new-val)))
	    (cond ((table-like-p new-val)
		   (dolist (name (table-keys new-val))
		     (let ((content (table-value new-val name)))
		       (setf (get-field document name) (string content)))))
		  ((typep new-val 'document)
		   (setf document new-val))
		  (T
		   (setf (get-field document (get-index-option (slot-value self 'options) :default-field))
			 (string new-val))))
	    (push document docs-to-add)
	    (delete reader id)))))
    (let ((writer (writer self)))
      (dolist (doc (reverse docs-to-add))
	(add-document-to-index-writer writer doc))
      (when (slot-value self 'auto-flush-p)
	(flush self)))))

(defmethod has-deletions-p ((self index))
  (has-deletions-p (reader self)))

(defmethod has-writes ((self index))
  (slot-value self 'has-writes))

(defmethod flush ((self index))
  (with-slots (reader writer searcher) self
    (when reader (close reader))
    (when writer (close writer))
    (setf reader nil
	  writer nil
	  searcher nil)))

(defmethod optimize ((self index))
  (optimize (writer self))
  (flush self))

(defmethod size ((self index))
  (num-docs (reader self)))

(defmethod add-indexes ((self index) indexes)
  (when (> (length indexes) 0)
    (when (typep (elt indexes 0) 'index)
      (setf indexes (map 'array #'reader indexes)))
    (cond ((typep (elt indexes 0) 'index-reader)
	   (let ((reader (reader self)))
	     (setf indexes (remove reader indexes)))
	   (add-indexes-readers (writer self) indexes))
	  ((typep (elt indexes 0) 'directory)
	   (setf indexes (remove (slot-value self 'dir) indexes))
	   (add-indexes (writer self) indexes))
	  (T
	   (error "Unknown index type ~S when trying to merge indexes." (elt indexes 0))))))

(defmethod persist ((self index) directory &key (create-p T))
  (flush self)
  (with-slots (dir options) self
    (let ((old-dir dir))
      (cond ((stringp directory)
	     (setf dir (make-instance 'fs-directory
				      :path directory
				      :create-p create-p))
	     (setf (get-index-option options :close-directory-p) T))
	    ((typep directory 'directory)
	     (setf dir directory)))
      (add-indexes (writer self) (vector old-dir)))))



(defmethod ensure-writer-open ((self index))
  (with-slots (open-p writer reader dir options searcher) self
    (unless open-p
      (error "Tried to use a closed index."))
    (unless writer
      (when reader
	(close reader)
	(setf reader nil
	      searcher nil))
      (setf writer (make-instance 'index-writer
				  :directory dir
				  :options options)))))

(defmethod ensure-reader-open ((self index))
  (with-slots (open-p writer reader dir) self
    (unless open-p
      (error "Tried to use a closed index."))
    (if reader
	(if (not (latest-p reader))
	  (setf reader (open-index-reader dir :close-directory-p NIL))
	  NIL)
	(progn
	  (when writer
	    (close writer)
	    (setf writer nil))
	  (setf reader (open-index-reader dir :close-directory-p NIL))))))

(defmethod ensure-searcher-open ((self index))
  (with-slots (open-p searcher reader) self
    (unless open-p
      (error "Tried to use a closed index."))
    (when (or (ensure-reader-open self) (not searcher))
      (setf searcher (make-instance 'index-searcher
				    :reader reader)))))


(defmethod do-search ((self index) query options)
  (let ((searcher (searcher self))
	(query (process-query self query)))
    (search searcher query options)))


(defmethod process-query ((self index) query)
  (if (stringp query)
      (with-slots (qp default-search-field options reader) self
	(unless qp
	  (setf qp (make-instance 'query-parser
				  :field default-search-field
				  :options options)))
	;; We need to set this every time, in case a new field has
	;; been added.
	(setf (fields qp) (string (get-field-names reader)))
	(parse qp query))
      query))