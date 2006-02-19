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
      (atest term-doc-enum-4 (and (next tde) T) T)
      ;; Document #0 has a single occurrence of "Wally".
      (atest term-doc-enum-5 (doc tde) 0)
      (atest term-doc-enum-6 (freq tde) 1)
      (atest term-doc-enum-7 (and (next tde) T) T)
      ;; Document #5 also has a single occurrence of "Wally".
      (atest term-doc-enum-8 (doc tde) 5)
      (atest term-doc-enum-9 (freq tde) 1)
      (atest term-doc-enum-10 (and (next tde) T) T)
      ;; Document #18 has three "Wally"s.
      (atest term-doc-enum-11 (doc tde) 18)
      (atest term-doc-enum-12 (freq tde) 3)
      (atest term-doc-enum-13 (and (next tde) T) T)
      ;; Document #20 has six "Wally"s.
      (atest term-doc-enum-14 (doc tde) 20)
      (atest term-doc-enum-15 (freq tde) 6)
      (atest term-doc-enum-16 (next tde) NIL)
      
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
	(do-test-term-docpos-enum-skip-to ir tde)
	(close tde))

      ;; Test term positions
      (let* ((term (make-term "body" "read"))
	     (tde (term-positions-for ir term)))
	(atest term-doc-enum-27 (and (next tde) T) T)
	(atest term-doc-enum-28 (doc tde) 1)
	(atest term-doc-enum-29 (freq tde) 1)
	(atest term-doc-enum-30 (next-position tde) 3)
	(atest term-doc-enum-31 (and (next tde) T) T)
	(atest term-doc-enum-32 (doc tde) 2)
	(atest term-doc-enum-33 (freq tde) 2)
	(atest term-doc-enum-34 (next-position tde) 1)
	(atest term-doc-enum-35 (next-position tde) 4)
	(atest term-doc-enum-36 (and (next tde) T) T)
	(atest term-doc-enum-37 (doc tde) 6)
	(atest term-doc-enum-38 (freq tde) 4)
	(atest term-doc-enum-39 (next-position tde) 3)
	(atest term-doc-enum-40 (next-position tde) 4)
	(atest term-doc-enum-41 (and (next tde) T) T)
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
	(atest term-doc-enum-59 (next tde) NIL)
	
	(do-test-term-docpos-enum-skip-to ir tde)
	(close tde)))))

(defun do-test-term-docpos-enum-skip-to (ir tde)
  (warn "do-test-term-docpos-enum-skip-to not yet implemented."))

(defun do-test-term-vectors (ir)
  (warn "do-test-term-vectors not yet implemented."))

(defun do-test-changing-field (ir)
  (warn "do-test-changing-field not yet implemented."))

(defun do-test-get-doc (ir)
  (warn "do-test-get-doc not yet implemented."))

	
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
  (:teardown
   (close (fixture-var 'ir))
   (close (fixture-var 'dir))))

