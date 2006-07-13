(in-package #:montezuma)

(defun test-index-reader (ir)
  (do-test-term-doc-enum ir)
  (do-test-term-vectors ir)
  (do-test-changing-field ir)
  (do-test-get-doc ir))

(defun do-test-term-doc-enum (ir)
  (atest term-doc-enum-1 *index-test-helper-ir-test-doc-count* (num-docs ir))
  (atest term-doc-enum-2 *index-test-helper-ir-test-doc-count* (max-doc ir))
  (let ((term (make-term "body" "Wally")))
    (atest term-doc-enum-3 (term-doc-freq ir term) 4)
    (let ((tde (term-docs-for ir term)))
      (atest term-doc-enum-4 (and (next? tde) T) T)
      ;; Document #0 has a single occurrence of "Wally".
      (atest term-doc-enum-5 (doc tde) 0)
      (atest term-doc-enum-6 (freq tde) 1)
      (atest term-doc-enum-7 (and (next? tde) T) T)
      ;; Document #5 also has a single occurrence of "Wally".
      (atest term-doc-enum-8 (doc tde) 5)
      (atest term-doc-enum-9 (freq tde) 1)
      (atest term-doc-enum-10 (and (next? tde) T) T)
      ;; Document #18 has three "Wally"s.
      (atest term-doc-enum-11 (doc tde) 18)
      (atest term-doc-enum-12 (freq tde) 3)
      (atest term-doc-enum-13 (and (next? tde) T) T)
      ;; Document #20 has six "Wally"s.
      (atest term-doc-enum-14 (doc tde) 20)
      (atest term-doc-enum-15 (freq tde) 6)
      (atest term-doc-enum-16 (next? tde) NIL)
      
      ;; Test fast read.  Use a small array to exercise repeat read.
      (let ((docs (make-array 3))
	    (freqs (make-array 3))
	    (term (make-term "body" "read")))
	(seek tde term)
	(atest term-doc-enum-17 (read-segment-term-doc-enum tde docs freqs) 3)
	(atest term-doc-enum-18 docs #(1 2 6) #'equalp)
	(atest term-doc-enum-19 freqs #(1 2 4) #'equalp)
	(atest term-doc-enum-20 (read-segment-term-doc-enum tde docs freqs) 3)
	(atest term-doc-enum-21 docs #(9 10 15) #'equalp)
	(atest term-doc-enum-22 freqs #(3 1 1) #'equalp)
	(atest term-doc-enum-22.1 (read-segment-term-doc-enum tde docs freqs) 3)
	(atest term-doc-enum-22.2 docs #(16 17 20) #'equalp)
	(atest term-doc-enum-22.3 freqs #(2 1 1) #'equalp)
	(atest term-doc-enum-23 (read-segment-term-doc-enum tde docs freqs) 1)
	(atest term-doc-enum-24 (subseq docs 0 1) #(21) #'equalp)
	(atest term-doc-enum-25 (subseq freqs 0 1) #(6) #'equalp)
	(atest term-doc-enum-26 (read-segment-term-doc-enum tde docs freqs) 0)
	(do-test-term-docpos-enum-skip-to tde)
	(close tde))

      ;; Test term positions
      (let* ((term (make-term "body" "read"))
	     (tde (term-positions-for ir term)))
	(atest term-doc-enum-27 (and (next? tde) T) T)
	(atest term-doc-enum-28 (doc tde) 1)
	(atest term-doc-enum-29 (freq tde) 1)
	(atest term-doc-enum-30 (next-position tde) 3)
	(atest term-doc-enum-31 (and (next? tde) T) T)
	(atest term-doc-enum-32 (doc tde) 2)
	(atest term-doc-enum-33 (freq tde) 2)
	(atest term-doc-enum-34 (next-position tde) 1)
	(atest term-doc-enum-35 (next-position tde) 4)
	(atest term-doc-enum-36 (and (next? tde) T) T)
	(atest term-doc-enum-37 (doc tde) 6)
	(atest term-doc-enum-38 (freq tde) 4)
	(atest term-doc-enum-39 (next-position tde) 3)
	(atest term-doc-enum-40 (next-position tde) 4)
	(atest term-doc-enum-41 (and (next? tde) T) T)
	(atest term-doc-enum-42 (doc tde) 9)
	(atest term-doc-enum-43 (freq tde) 3)
	(atest term-doc-enum-44 (next-position tde) 0)
	(atest term-doc-enum-45 (next-position tde) 4)
	(atest term-doc-enum-46 (and (skip-to tde 16) T) T)
	(atest term-doc-enum-47 (doc tde) 16)
	(atest term-doc-enum-48 (freq tde) 2)
	(atest term-doc-enum-49 (next-position tde) 2)
	(atest term-doc-enum-50 (and (skip-to tde 21) T) T)
	(atest term-doc-enum-51 (doc tde) 21)
	(atest term-doc-enum-52 (freq tde) 6)
	(atest term-doc-enum-53 (next-position tde) 3)
	(atest term-doc-enum-54 (next-position tde) 4)
	(atest term-doc-enum-55 (next-position tde) 5)
	(atest term-doc-enum-56 (next-position tde) 8)
	(atest term-doc-enum-57 (next-position tde) 9)
	(atest term-doc-enum-58 (next-position tde) 10)
	(atest term-doc-enum-59 (next? tde) NIL)
	
	(do-test-term-docpos-enum-skip-to tde)
	(close tde)))))

(defun do-test-term-docpos-enum-skip-to (tde)
  (let ((term (make-term "text" "skip")))
    (seek tde term)
    (atest term-docpos-enum-skip-to-1 (and (skip-to tde 10) T) T)
    (atest term-docpos-enum-skip-to-2 (doc tde) 22)
    (atest term-docpos-enum-skip-to-3 (freq tde) 22)
    (atest term-docpos-enum-skip-to-4 (and (skip-to tde 60) T) T)
    (atest term-docpos-enum-skip-to-5 (doc tde) 60)
    (atest term-docpos-enum-skip-to-6 (freq tde) 60)
    (seek tde term)
    (atest term-docpos-enum-skip-to-7 (and (skip-to tde 45) T) T)
    (atest term-docpos-enum-skip-to-8 (doc tde) 45)
    (atest term-docpos-enum-skip-to-9 (freq tde) 45)
    (atest term-docpos-enum-skip-to-10 (and (skip-to tde 62) T) T)
    (atest term-docpos-enum-skip-to-11 (doc tde) 62)
    (atest term-docpos-enum-skip-to-12 (freq tde) 62)
    (atest term-docpos-enum-skip-to-13 (and (skip-to tde 63) T) T)
    (atest term-docpos-enum-skip-to-14 (doc tde) 63)
    (atest term-docpos-enum-skip-to-15 (freq tde) 63)
    (atest term-docpos-enum-skip-to-16 (skip-to tde 64) NIL)
    (seek tde term)
    (atest term-docpos-enum-skip-to-17 (skip-to tde 64) NIL)))
    

(defun do-test-term-vectors (ir)
  (flet ((tvo (start-offset end-offset)
	   (make-instance 'term-vector-offset-info
			  :start-offset start-offset
			  :end-offset end-offset)))
    (let ((tv (get-term-vector ir 3 "body")))
      (atest term-vectors-1 (field tv) "body" #'equal)
      (atest term-vectors-2 (terms tv) #("word1" "word2" "word3" "word4") #'equalp)
      (atest term-vectors-3 (term-frequencies tv) #(3 1 4 2) #'equalp)
      (atest term-vectors-4 (positions tv) #(#(2 4 7) #(3) #(0 5 8 9) #(1 6)) #'equalp)
      (atest term-vectors-5
	     (offsets tv)
	     (vector (vector (tvo 12 17) (tvo 24 29) (tvo 42 47))
		     (vector (tvo 18 23))
		     (vector (tvo 0 5) (tvo 30 35) (tvo 48 53) (tvo 54 59))
		     (vector (tvo 6 11) (tvo 36 41)))
	     #'(lambda (tvov1 tvov2)
		 (flet ((tvov= (tvov1 tvov2)
			  (and (= (length tvov1) (length tvov2))
			       (every #'term-vector-offset-info= tvov1 tvov2))))
		   (and (= (length tvov1) (length tvov2))
			(every #'tvov= tvov1 tvov2)))))
      (setf tv nil)
      (let ((tvs (get-term-vectors ir 3)))
	(atest term-vectors-6 (length tvs) 3)
	(let ((tv (aref tvs 0)))
	  (atest term-vectors-7 (field tv) "author")
	  (atest term-vectors-8 (terms tv) #("Leo" "Tolstoy") #'equalp)
	  (atest term-vectors-9 (offsets tv) nil))
	(let ((tv (aref tvs 1)))
	  (atest term-vectors-10 (field tv) "body")
	  (atest term-vectors-11 (terms tv) #("word1" "word2" "word3" "word4") #'equalp)
	(let ((tv (aref tvs 2)))
	  (atest term-vectors-12 (field tv) "title")
	  (atest term-vectors-13 (terms tv) #("War and Peace") #'equalp)
	  (atest term-vectors-14 (positions tv) nil)
	  (atest term-vectors-15
		 (aref (aref (offsets tv) 0) 0)
		 (tvo 0 13)
		 #'term-vector-offset-info=)))))))

(defun do-test-changing-field (ir)
  (let ((tv (get-term-vector ir 0 "changing_field")))
    (atest changing-field-1 tv nil))
  (let ((tv (get-term-vector ir 10 "changing_field")))
    (atest changing-field-2 (positions tv) nil)
    (atest changing-field-3 (offsets tv) nil))
  (let ((tv (get-term-vector ir 17 "changing_field")))
    (atest changing-field-4 (and (positions tv) T) T)
    (atest changing-field-5 (offsets tv) nil))
  (let ((tv (get-term-vector ir 19 "changing_field")))
    (atest changing-field-6 (positions tv) nil)
    (atest changing-field-7 (and (offsets tv) T) T))
  (let ((tv (get-term-vector ir 20 "changing_field")))
    (atest changing-field-8 (and (positions tv) T) T)
    (atest changing-field-9 (and (offsets tv) T) T))
  (let ((tv (get-term-vector ir 21 "changing_field")))
    (atest changing-field-1 tv nil)))
  


(defun do-test-get-doc (ir)
  (let ((doc (get-document ir 3)))
    (atest get-doc-1 (field-count doc) 4)
    (let ((df (document-field doc "author")))
      (atest get-doc-2 (field-name df) "author" #'equal)
      (atest get-doc-3 (field-data df) "Leo Tolstoy" #'equal)
      (atest get-doc-4 (boost df) 1.0)
      (atest get-doc-5 (field-stored-p df)            T   #'bool=)
      (atest get-doc-6 (field-compressed-p df)        NIL #'bool=)
      (atest get-doc-7 (field-indexed-p df)           T   #'bool=)
      (atest get-doc-8 (field-tokenized-p df)         T   #'bool=)
      (atest get-doc-9 (field-store-term-vector-p df) T   #'bool=)
      (atest get-doc-10 (field-store-positions-p df)  T   #'bool=)
      (atest get-doc-11 (field-store-offsets-p df)    NIL #'bool=)
      (atest get-doc-12 (field-binary-p df)           NIL #'bool=))
    (let ((df (document-field doc "body")))
      (atest get-doc-13 (field-name df) "body" #'equal)
      (atest get-doc-14 (field-data df) "word3 word4 word1 word2 word1 word3 word4 word1 word3 word3" #'equal)
      (atest get-doc-15 (boost df) 1.0)
      (atest get-doc-16 (field-stored-p df)            T   #'bool=)
      (atest get-doc-17 (field-compressed-p df)        NIL #'bool=)
      (atest get-doc-18 (field-indexed-p df)           T   #'bool=)
      (atest get-doc-19 (field-tokenized-p df)         T   #'bool=)
      (atest get-doc-20 (field-store-term-vector-p df) T   #'bool=)
      (atest get-doc-21 (field-store-positions-p df)   T   #'bool=)
      (atest get-doc-22 (field-store-offsets-p df)     T   #'bool=)
      (atest get-doc-23 (field-binary-p df)            NIL #'bool=))
    (let ((df (document-field doc "title")))
      (atest get-doc-24 (field-name df) "title" #'equal)
      (atest get-doc-25 (field-data df) "War And Peace" #'equal)
      (atest get-doc-26 (boost df) 1.0)
      (atest get-doc-27 (field-stored-p df)            T   #'bool=)
      (atest get-doc-28 (field-compressed-p df)        NIL #'bool=)
      (atest get-doc-29 (field-indexed-p df)           T   #'bool=)
      (atest get-doc-30 (field-tokenized-p df)         NIL   #'bool=)
      (atest get-doc-31 (field-store-term-vector-p df) T   #'bool=)
      (atest get-doc-32 (field-store-positions-p df)   NIL   #'bool=)
      (atest get-doc-33 (field-store-offsets-p df)     T   #'bool=)
      (atest get-doc-34 (field-binary-p df)            NIL #'bool=))
    (let ((df (document-field doc "year")))
      (atest get-doc-35 (field-name df) "year" #'equal)
      (atest get-doc-36 (field-data df) "1865" #'equal)
      (atest get-doc-37 (boost df) 1.0)
      (atest get-doc-38 (field-stored-p df)            T   #'bool=)
      (atest get-doc-39 (field-compressed-p df)        NIL #'bool=)
      (atest get-doc-40 (field-indexed-p df)           NIL   #'bool=)
      (atest get-doc-41 (field-tokenized-p df)         NIL   #'bool=)
      (atest get-doc-42 (field-store-term-vector-p df) NIL   #'bool=)
      (atest get-doc-43 (field-store-positions-p df)   NIL   #'bool=)
      (atest get-doc-44 (field-store-offsets-p df)     NIL   #'bool=)
      (atest get-doc-45 (field-binary-p df)            NIL #'bool=))
    (let ((df (document-field doc "text")))
      (atest get-doc-46 df nil))))


(defun test-ir-norms (ir dir)
  (set-norm ir 3 "title" 1)
  (set-norm ir 3 "body" 12)
  (set-norm ir 3 "author" 145)
  (set-norm ir 3 "year" 31)
  (set-norm ir 3 "text" 202)
  (set-norm ir 25 "text" 20)
  (set-norm ir 50 "text" 200)
  (set-norm ir 63 "text" 155)
  (let ((norms (get-norms ir "text")))
    (atest ir-norms-1 (aref norms 3) 202)
    (atest ir-norms-2 (aref norms 25) 20)
    (atest ir-norms-3 (aref norms 50) 200)
    (atest ir-norms-4 (aref norms 63) 155))
  (let ((norms (get-norms ir "title")))
    (atest ir-norms-5 (aref norms 3) 1))
  (let ((norms (get-norms ir "body")))
    (atest ir-norms-6 (aref norms 3) 12))
  (let ((norms (get-norms ir "author")))
    (atest ir-norms-7 (aref norms 3) 145))
  (let ((norms (get-norms ir "author")))
    (atest ir-norms-8 (aref norms 3) 145))
  ;; TODO: this returns two possible results depending on whether it
  ;; is a multi reader or a segment reader. If it is a multi reader it
  ;; will always return an empty set of norms, otherwise it will
  ;; return nil. I'm not sure what to do here just yet or if this is
  ;; even an issue. assert(norms.nil?)
  (let ((norms (make-array 164)))
    (get-norms-into ir "text" norms 100)
    (atest ir-norms-9 (aref norms 103) 202)
    (atest ir-norms-10 (aref norms 125) 20)
    (atest ir-norms-11 (aref norms 150) 200)
    (atest ir-norms-12 (aref norms 163) 155))
  (commit ir)
  (let ((iw (make-instance 'index-writer
			   :directory dir
			   :analyzer (make-instance 'whitespace-analyzer))))
    (optimize iw)
    (close iw))
  (let ((ir2 (open-index-reader dir :close-directory-p NIL)))
    (let ((norms (make-array 164)))
      (get-norms-into ir2 "text" norms 100)
      (atest ir-norms-13 (aref norms 103) 202)
      (atest ir-norms-14 (aref norms 125) 20)
      (atest ir-norms-15 (aref norms 150) 200)
      (atest ir-norms-16 (aref norms 163) 155))
    (close ir2)))


(defun test-ir-delete (ir dir)
  (let ((doc-count *index-test-helper-ir-test-doc-count*))
    (atest ir-delete-1 (has-deletions-p ir) NIL #'bool=)
    (atest ir-delete-2 (max-doc ir) doc-count)
    (atest ir-delete-3 (num-docs ir) doc-count)
    (atest ir-delete-4 (deleted-p ir 10) NIL #'bool=)
    (delete-document ir 10)
    (atest ir-delete-5 (has-deletions-p ir) T #'bool=)
    (atest ir-delete-6 (max-doc ir) doc-count)
    (atest ir-delete-7 (num-docs ir) (- doc-count 1))
    (atest ir-delete-8 (deleted-p ir 10) T #'bool=)
    (delete-document ir 10)
    (atest ir-delete-9 (has-deletions-p ir) T #'bool=)
    (atest ir-delete-10 (max-doc ir) doc-count)
    (atest ir-delete-11 (num-docs ir) (- doc-count 1))
    (atest ir-delete-12 (deleted-p ir 10) T #'bool=)
    (delete-document ir (- doc-count 1))
    (atest ir-delete-13 (has-deletions-p ir) T #'bool=)
    (atest ir-delete-14 (max-doc ir) doc-count)
    (atest ir-delete-15 (num-docs ir) (- doc-count 2))
    (atest ir-delete-16 (deleted-p ir (- doc-count 1)) T #'bool=)
    (delete-document ir (- doc-count 2))
    (atest ir-delete-17 (has-deletions-p ir) T #'bool=)
    (atest ir-delete-18 (max-doc ir) doc-count)
    (atest ir-delete-19 (num-docs ir) (- doc-count 3))
    (atest ir-delete-20 (deleted-p ir (- doc-count 2)) T #'bool=)
    (undelete-all ir)
    (atest ir-delete-21 (has-deletions-p ir) NIL #'bool=)
    (atest ir-delete-22 (max-doc ir) doc-count)
    (atest ir-delete-23 (num-docs ir) doc-count)
    (atest ir-delete-24 (deleted-p ir 10) NIL #'bool=)
    (atest ir-delete-25 (deleted-p ir (- doc-count 2)) NIL #'bool=)
    (atest ir-delete-26 (deleted-p ir (- doc-count 1)) NIL #'bool=)
    (delete-document ir 10)
    (delete-document ir 20)
    (delete-document ir 30)
    (delete-document ir 40)
    (delete-document ir 50)
    (delete-document ir (- doc-count 1))
    (atest ir-delete-27 (has-deletions-p ir) T #'bool=)
    (atest ir-delete-28 (max-doc ir) doc-count)
    (atest ir-delete-29 (num-docs ir) (- doc-count 6))
    (commit ir)
    (let ((ir2 (open-index-reader dir :close-directory-p NIL)))
      (atest ir-delete-30 (has-deletions-p ir2) T #'bool=)
      (atest ir-delete-31 (max-doc ir2) doc-count)
      (atest ir-delete-32 (num-docs ir2) (- doc-count 6))
      (atest ir-delete-33 (deleted-p ir2 10) T #'bool=)
      (atest ir-delete-34 (deleted-p ir2 20) T #'bool=)
      (atest ir-delete-35 (deleted-p ir2 30) T #'bool=)
      (atest ir-delete-36 (deleted-p ir2 40) T #'bool=)
      (atest ir-delete-37 (deleted-p ir2 50) T #'bool=)
      (atest ir-delete-38 (deleted-p ir2 (- doc-count 1)) T #'bool=)
      (undelete-all ir2)
      (atest ir-delete-39 (has-deletions-p ir2) NIL #'bool=)
      (atest ir-delete-40 (max-doc ir2) doc-count)
      (atest ir-delete-41 (num-docs ir2) doc-count)
      (atest ir-delete-42 (deleted-p ir2 10) NIL #'bool=)
      (atest ir-delete-43 (deleted-p ir2 20) NIL #'bool=)
      (atest ir-delete-44 (deleted-p ir2 30) NIL #'bool=)
      (atest ir-delete-45 (deleted-p ir2 40) NIL #'bool=)
      (atest ir-delete-46 (deleted-p ir2 50) NIL #'bool=)
      (atest ir-delete-47 (deleted-p ir2 (- doc-count 1)) NIL #'bool=)
      (delete-document ir2 10)
      (delete-document ir2 20)
      (delete-document ir2 30)
      (delete-document ir2 40)
      (delete-document ir2 50)
      (delete-document ir2 (- doc-count 1))
      (commit ir2))
    (let ((iw (make-instance 'index-writer
			     :directory dir
			     :analyzer (make-instance 'whitespace-analyzer))))
      (optimize iw)
      (close iw))
    (let ((ir3 (open-index-reader dir :close-directory-p NIL)))
      (atest ir-delete-48 (has-deletions-p ir3) NIL #'bool=)
      (atest ir-delete-49 (max-doc ir3) (- doc-count 6))
      (atest ir-delete-50 (num-docs ir3) (- doc-count 6))
      (close ir3))))
		     
	
(deftestfixture segment-reader-test
  (:vars dir ir)
  (:setup
   (setf (fixture-var 'dir) (make-instance 'ram-directory))
   (let ((iw (make-instance 'index-writer
			    :directory (fixture-var 'dir)
			    :analyzer (make-instance 'whitespace-analyzer)
			    :create-p T))
	 (docs (index-test-helper-prepare-ir-test-docs)))
     (dotimes (i *index-test-helper-ir-test-doc-count*)
       (add-document-to-index-writer iw (aref docs i)))
     (optimize iw)
     (close iw)
     (setf (fixture-var 'ir)
	   (open-index-reader (fixture-var 'dir) :close-directory-p NIL))))
  (:testfun test-segment-reader
   (test-index-reader (fixture-var 'ir)))
  (:testfun test-segment-delete
   (test-ir-delete (fixture-var 'ir) (fixture-var 'dir)))
  (:testfun test-segment-reader-norms
   (test-ir-norms (fixture-var 'ir) (fixture-var 'dir)))
  (:teardown
   (close (fixture-var 'ir))
   (close (fixture-var 'dir))))

(deftestfixture multi-reader-test
  (:vars dir ir)
  (:setup
   (setf (fixture-var 'dir) (make-instance 'ram-directory))
   (let ((iw (make-instance 'index-writer
			    :directory (fixture-var 'dir)
			    :analyzer (make-instance 'whitespace-analyzer)
			    :create-p T))
	 (docs (index-test-helper-prepare-ir-test-docs)))
     (dotimes (i *index-test-helper-ir-test-doc-count*)
       (add-document-to-index-writer iw (aref docs i)))
     ;; If we optimize, we won't use the multi-reader
     ;; (optimize iw)
     (close iw)
     (setf (fixture-var 'ir)
	   (open-index-reader (fixture-var 'dir) :close-directory-p NIL))))
  (:testfun test-multi-reader
   (test-index-reader (fixture-var 'ir)))
  (:testfun test-multi-delete
   (test-ir-delete (fixture-var 'ir) (fixture-var 'dir)))
  (:testfun test-multi-reader-norms
   (test-ir-norms (fixture-var 'ir) (fixture-var 'dir)))
  (:teardown
   (close (fixture-var 'ir))
   (close (fixture-var 'dir))))

(deftestfixture index-reader-test
  (:vars dir)
  (:setup
   (setf (fixture-var 'dir) (make-instance 'ram-directory)))
  (:teardown
   (close (fixture-var 'dir)))
  (:testfun test-ir-multivalue-fields
   (let* ((dir (fixture-var 'dir))
	  (iw (make-instance 'index-writer
			     :directory dir
			     :analyzer (make-instance 'whitespace-analyzer)
			     :create-p T))
	  (doc (make-instance 'document)))
     (add-field doc (make-field "tag" "Ruby"
				:stored T :index NIL
				:store-term-vector NIL))
     (add-field doc (make-field "tag" "C"
				:stored T :index :untokenized
				:store-term-vector NIL))
     (add-field doc (make-field "body" "this is the body Document Field"
				:stored T :index :untokenized
				:store-term-vector :with-positions-offsets))
     (add-field doc (make-field "tag" "Lucene"
				:stored T :index :tokenized
				:store-term-vector :with-positions))
     (add-field doc (make-field "tag" "Ferret"
				:stored T :index :untokenized
				:store-term-vector :with-offsets))
     (add-field doc (make-field "title" "this is the title DocField"
				:stored T :index :untokenized
				:store-term-vector :with-positions-offsets))
     (add-field doc (make-field "author" "this is the author field"
				:stored T :index :untokenized
				:store-term-vector :with-positions-offsets))
     (let ((fis (make-instance 'field-infos)))
       (add-doc-fields fis doc)
       (test index-reader-1 (size fis) 4)
       (let ((fi (get-field fis "tag")))
	 (test index-reader-2 (field-indexed-p fi) T #'bool=)
	 (test index-reader-3 (field-store-term-vector-p fi) T #'bool=)
	 (test index-reader-4 (field-store-positions-p fi) T #'bool=)
	 (test index-reader-5 (field-store-offsets-p fi) T #'bool=)
	 (add-document-to-index-writer iw doc)
	 (close iw)))
     (let ((ir (open-index-reader dir :close-directory-p NIL)))
       (let ((doc (get-document ir 0)))
	 (test index-reader-6 (field-count doc) 4)
	 (test index-reader-7 (entry-count doc) 7)
	 (let ((entries (document-fields doc "tag")))
	   (test index-reader-8 (length entries) 4)
	   (test index-reader-9 (field-data (elt entries 0)) "Ruby" #'equal)
	   (test index-reader-10 (field-data (elt entries 1)) "C" #'equal)
	   (test index-reader-11 (field-data (elt entries 2)) "Lucene" #'equal)
	   (test index-reader-12 (field-data (elt entries 3)) "Ferret" #'equal)
	   (remove-field doc "tag")
	   (test index-reader-13 (field-count doc) 4)
	   (test index-reader-14 (entry-count doc) 6)
	   (test index-reader-15 (field-data (document-field doc "tag")) "C" #'equal)
	   (remove-fields doc "tag")
	   (test index-reader-16 (field-count doc) 3)
	   (test index-reader-17 (entry-count doc) 3))
	 (delete-document ir 0)
	 (close ir)
	 (let ((iw (make-instance 'index-writer
				  :directory dir
				  :analyzer (make-instance 'whitespace-analyzer))))
	   (add-document-to-index-writer iw doc)
	   (optimize iw)
	   (close iw))
	 (let ((ir (open-index-reader dir :close-directory-p NIL)))
	   (let ((doc (get-document ir 0)))
	     (test index-reader-18 (field-count doc) 3)
	     (test index-reader-19 (entry-count doc) 3))
	   (close ir))))))
  (:testfun test-ir-read-while-optimizing
   (let ((iw (make-instance 'index-writer
			    :directory (fixture-var 'dir)
			    :analyzer (make-instance 'whitespace-analyzer)
			    :create-p T))
	 (docs (index-test-helper-prepare-ir-test-docs)))
     (dotimes (i *index-test-helper-ir-test-doc-count*)
       (add-document-to-index-writer iw (aref docs i)))
     (close iw))
   (let ((ir (open-index-reader (fixture-var 'dir) :close-directory-p NIL)))
     (do-test-term-vectors ir)
     (let ((iw (make-instance 'index-writer
			      :directory (fixture-var 'dir)
			      :analyzer (make-instance 'whitespace-analyzer))))
       (optimize iw)
       (close iw)
       (do-test-term-vectors ir)
       (close ir))))
  (:testfun test-ir-read-while-optimizing-on-disk
   (let* ((fs-dir (make-fs-directory *test-directory-path* :create-p T))
	  (iw (make-instance 'index-writer
			     :directory fs-dir
			     :analyzer (make-instance 'whitespace-analyzer)
			     :create-p T))
	  (docs (index-test-helper-prepare-ir-test-docs)))
     (dotimes (i *index-test-helper-ir-test-doc-count*)
       (add-document-to-index-writer iw (elt docs i)))
     (close iw)
     (let ((ir (open-index-reader fs-dir :close-directory-p NIL)))
       (do-test-term-vectors ir)
       (let ((iw (make-instance 'index-writer
				:directory fs-dir
				:analyzer (make-instance 'whitespace-analyzer))))
	 (optimize iw)
	 (close iw)
	 (do-test-term-vectors ir)
	 (close ir)
	 (close fs-dir)))))
  (:testfun test-ir-latest
   (let* ((fs-dir (make-fs-directory *test-directory-path* :create-p T))
	  (iw (make-instance 'index-writer
			     :directory fs-dir
			     :analyzer (make-instance 'whitespace-analyzer)
			     :create-p T))
	  (doc (make-instance 'document)))
     (add-field doc (make-field "field" "content"
				:stored T :index :tokenized))
     (add-document-to-index-writer iw doc)
     (close iw)
     (let ((ir (open-index-reader fs-dir :close-directory-p NIL)))
       (test ir-latest-1 (and (latest-p ir) T) T)
       (let ((iw (make-instance 'index-writer
				:directory fs-dir
				:analyzer (make-instance 'whitespace-analyzer)))
	     (doc (make-instance 'document)))
	 (add-field doc (make-field "field" "content2"
				    :stored T :index :tokenized))
	 (add-document-to-index-writer iw doc)
	 (close iw))
       (test ir-latest-2 (latest-p ir) NIL)
       (close ir)
       (let ((ir (open-index-reader fs-dir :close-directory-p NIL)))
	 (test ir-latest-3 (and (latest-p ir) T) T)
	 (close ir))))))