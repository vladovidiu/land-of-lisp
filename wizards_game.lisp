(defparameter *nodes* '((living-room (you are in the living room.
									  a wizard is snoring loudly on the couch.))
						(garden (you are in a beautiful garden.
								 there is a well in front of you.))
						(attic (you are in the attic.
								there is a giant welding torch in the corner.))))

(defparameter *edges* '((living-room (garden west door)
						 (attic upstairs ladder))
						(garden (living-room east door))
						(attic (living-room downstairs ladder))))

(defparameter *objects* '(whiskey bucket frog chain))

(defparameter *object-location* '((whiskey living-room)
								  (bucket living-room)
								  (chain garden)
								  (frog garden)))

(defparameter *location* 'living-room)
(defparameter *allowed-commands* '(look walk pickup drop inventory weld dunk))
(defparameter *chain-welded* nil)
(defparameter *bucket-filled* nil)
(defparameter *chain-welded* nil)

(defun describe-location (location nodes)
  (cadr (assoc location nodes)))

(defun describe-path (edge)
  `(there is a ,(caddr edge) going ,(cadr edge) from here.))

(defun describe-paths (location edges)
  (apply #'append (mapcar #'describe-path (cdr (assoc location edges)))))

(defun object-at (location objects object-location)
  (labels ((at-location-p (object)
			 (eq (cadr (assoc object object-location)) location)))
	(remove-if-not #'at-location-p objects)))

(defun describe-objects (location objects object-location)
  (labels ((describe-object (object)
			 `(you see a ,object on the floor.)))
	(apply #'append (mapcar #'describe-object (object-at location objects object-location)))))

(defun look ()
  (append (describe-location *location* *nodes*)
		  (describe-paths *location* *edges*)
		  (describe-objects *location* *objects* *object-location*)))

(defun walk (direction)
  (let ((next (find direction
					(cdr (assoc *location* *edges*))
					:key #'cadr)))
	(if next
		(progn (setf *location* (car next))
			   (look))
		'(you cannot go that way.))))

(defun pickup (object)
  (cond ((member object
				 (object-at *location* *objects* *object-location*))
		 (push (list object 'body) *object-location*)
		 `(you are now carrying the ,object))
		(t '(you cannot get that.))))

(defun drop (object)
  (cond ((member object
				 (object-at 'body *objects* *object-location*))
		 (push (list object *location*) *object-location*)
		 `(you have dropped the ,object at ,*location*))
		 (t `(you are not carrying ,object))))

(defun inventory ()
  (cons 'items- (object-at 'body *objects* *object-location*)))

(defun game-read ()
  (let ((cmd (read-from-string
			  (concatenate 'string "(" (read-line) ")"))))
	(flet ((quote-it (x)
			 (list 'quote x)))
	  (cons (car cmd) (mapcar #'quote-it (cdr cmd))))))

(defun game-eval (sexp)
  (if (member (car sexp) *allowed-commands*)
	  (eval sexp)
	  '(command unknown - try again with "look" "walk" "pickup" "drop" "inventory")))

(defun tweak-text (lst caps lit)
  (when lst
	(let ((item (car lst))
		  (rest (cdr lst)))
	  (cond ((eq item #\space) (cons item (tweak-text rest caps lit)))
			((member item '(#\! #\? #\.)) (cons item (tweak-text rest t lit)))
			((eq item #\") (tweak-text rest caps (not lit)))
			((or caps lit) (cons (char-upcase item) (tweak-text rest nil lit)))
			(t (cons (char-downcase item) (tweak-text rest nil nil)))))))

(defun game-print (lst)
  (princ (coerce (tweak-text (coerce (string-trim "() "
												  (prin1-to-string lst))
									 'list)
							 t
							 nil)
				 'string))
  (fresh-line))

(defun game-repl ()
  (let ((cmd (game-read)))
	(unless (eq (car cmd) 'quit)
	  (game-print (game-eval cmd))
	  (game-repl))))

(defun have (object)
  (member object (inventory)))

;; (defun weld (subject object)
;;   (if (and (eq *location* 'attic)
;; 		   (eq subject 'chain)
;; 		   (eq object 'bucket)
;; 		   (have 'chain)
;; 		   (have 'bucket)
;; 		   (not *chain-welded*))
;; 	  (progn (setf *chain-welded* t)
;; 			 '(the chain is now securely welded to the bucket.))
;; 	  '(you cannot weld like that.)))

;; (defun dunk (subject object)
;;   (if (and (eq *location* 'garden)
;; 		   (eq subject 'bucket)
;; 		   (eq object 'well)
;; 		   (have 'bucket)
;; 		   *chain-welded*)
;; 	  (progn (setf *bucket-filled* 't)
;; 			 '(the bucket is now full of water))
;; 	  '(you cannot dunk like that.)))

(defmacro game-action (command subj obj place &body body)
  `(progn (defun ,command (subject object)
			(if (and (eq *location* ',place)
					 (eq subject ',subj)
					 (eq object ',obj)
					 (have ',subj))
				,@body
				'(i cant ,command like that.)))
		  (pushnew ',command *allowed-commands*)))

(game-action weld chain bucket attic
			 (if (and (have 'bucket) (not *chain-welded*))
				 (progn (setf *chain-welded* 't)
						'(the chain is now securely welded to the bucket.))
				 '(you do not have a bucket.)))

(game-action dunk bucket well garden
			 (if *chain-welded*
				 (progn (setf *bucket-filled* 't)
						'(the bucket is now full of water))
				 '(the water level is too low to reach.)))

(game-action splash bucket wizard living-room
			 (cond ((not *bucket-filled*) '(the bucket has nothing in it.))
				   ((have 'frog) '(the wizard awakens and sees that you stole his frog.
								   he is so upset he banishes you to the netherworlds-
								   you lose! the end.))
				   (t '(the wizard awakens from his slumber and greets you warmly.
						he hands you the magic low-carb donut- you win! the end.))))
