;;;============================================================================

;;; File: "_repl.scm", Time-stamp: <2007-07-25 19:16:13 feeley>

;;; Copyright (c) 1994-2007 by Marc Feeley, All Rights Reserved.

;;;============================================================================

(##include "header.scm")

;;;============================================================================

;;; Decompilation of a piece of code

;;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(##define-macro (mk-degen params . def)
  `(let () (##declare (not inline)) (lambda ($code ,@params) ,@def)))

(##define-macro (degen proc . args)
  `(,proc $code ,@args))

;;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(define-prim (##extract-container $code rte)
  (let loop ((c (macro-code-cte $code)) (r rte))
    (cond ((##cte-top? c)
           #f)
          ((##cte-frame? c)
           (let ((vars (##cte-frame-vars c)))
             (if (and (##pair? vars) (##eq? (##car vars) (macro-self-var)))
               (macro-rte-ref r 1)
               (loop (##cte-parent-cte c) (macro-rte-up r)))))
          (else
           (loop (##cte-parent-cte c) r)))))

;;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(define-prim (##begin? x) (and (##pair? x) (##eq? (##car x) 'begin)))
(define-prim (##cond? x)  (and (##pair? x) (##eq? (##car x) 'cond)))
(define-prim (##and? x)   (and (##pair? x) (##eq? (##car x) 'and)))
(define-prim (##or? x)    (and (##pair? x) (##eq? (##car x) 'or)))
(define-prim (##void-constant? x)
  (and (##pair? x)
       (##eq? (##car x) 'quote)
       (##eq? (##cadr x) (##void))))

;;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(define-prim ##degen-top
  (mk-degen ()
    (##decomp (^ 0))))

(define-prim ##degen-cst
  (mk-degen ()
    (let ((val (^ 0)))
      (##inverse-eval val))))

(define-prim ##degen-loc-ref-x-y
  (mk-degen (up over)
    (degen ##degen-up-over up over)))

(define-prim ##degen-up-over
  (mk-degen (up over)
    (let loop1 ((c (macro-code-cte $code)) (up up))
      (cond ((##cte-frame? c)
             (if (##fixnum.= up 0)
               (let loop2 ((vars (##cte-frame-vars c)) (i over))
                 (if (##fixnum.< i 2)
                   (##car vars)
                   (loop2 (##cdr vars) (##fixnum.- i 1))))
               (loop1 (##cte-parent-cte c) (##fixnum.- up 1))))
            (else
             (loop1 (##cte-parent-cte c) up))))))

(define-prim ##degen-loc-ref
  (mk-degen ()
    (degen ##degen-loc-ref-x-y (^ 0) (^ 1))))

(define-prim ##degen-glo-ref
  (mk-degen ()
    (##global-var->identifier (^ 0))))

(define-prim ##degen-loc-set
  (mk-degen ()
    (##list 'set! (degen ##degen-up-over (^ 1) (^ 2))
                  (##decomp (^ 0)))))

(define-prim ##degen-glo-set
  (mk-degen ()
    (##list 'set! (##global-var->identifier (^ 1))
                  (##decomp (^ 0)))))

(define-prim ##degen-glo-def
  (mk-degen ()
    (##list 'define (##global-var->identifier (^ 1))
                    (##decomp (^ 0)))))

(define-prim ##degen-if2
  (mk-degen ()
    (##list 'if (##decomp (^ 0))
                (##decomp (^ 1)))))

(define-prim ##degen-if3
  (mk-degen ()
    (##list 'if (##decomp (^ 0))
                (##decomp (^ 1))
                (##decomp (^ 2)))))

(define-prim ##degen-seq
  (mk-degen ()
    (let ((val1 (##decomp (^ 0)))
          (val2 (##decomp (^ 1))))
      (if (##begin? val2)
        (##cons 'begin (##cons val1 (##cdr val2)))
        (##list 'begin val1 val2)))))

(define-prim ##degen-quasi-list->vector
  (mk-degen ()
    (##list 'quasiquote
            (##vector (##list 'unquote-splicing (##decomp (^ 0)))))))

(define-prim ##degen-quasi-append
  (mk-degen ()
    (##list 'quasiquote
            (##list (##list 'unquote-splicing (##decomp (^ 0)))
                    (##list 'unquote-splicing (##decomp (^ 1)))))))

(define-prim ##degen-quasi-cons
  (mk-degen ()
    (##list 'quasiquote
            (##list (##list 'unquote (##decomp (^ 0)))
                    (##list 'unquote-splicing (##decomp (^ 1)))))))

(define-prim ##degen-cond-if
  (mk-degen ()
    (let ((val1 (##decomp (^ 0)))
          (val2 (##decomp (^ 1)))
          (val3 (##decomp (^ 2))))
      (##build-cond
        (if (##begin? val2)
          (##cons val1 (##cdr val2))
          (##list val1 val2))
        val3))))

(define-prim ##degen-cond-or
  (mk-degen ()
    (let ((val1 (##decomp (^ 0)))
          (val2 (##decomp (^ 1))))
      (##build-cond (##list val1) val2))))

(define-prim ##degen-cond-send
  (mk-degen ()
    (let ((val1 (##decomp (^ 0)))
          (val2 (##decomp (^ 1)))
          (val3 (##decomp (^ 2))))
      (##build-cond (##list val1 '=> val2) val3))))

(define-prim (##build-cond clause rest)
  (cond ((##cond? rest)
         (##cons 'cond (##cons clause (##cdr rest))))
        ((##begin? rest)
         (##cons 'cond (##list clause (##cons 'else (##cdr rest)))))
        ((##void-constant? rest)
         (##list 'cond clause))
        (else
         (##list 'cond clause (##list 'else rest)))))

(define-prim ##degen-or
  (mk-degen ()
    (let ((val1 (##decomp (^ 0)))
          (val2 (##decomp (^ 1))))
      (if (##or? val2)
        (##cons 'or (##cons val1 (##cdr val2)))
        (##list 'or val1 val2)))))

(define-prim ##degen-and
  (mk-degen ()
    (let ((val1 (##decomp (^ 0)))
          (val2 (##decomp (^ 1))))
      (if (##and? val2)
        (##cons 'and (##cons val1 (##cdr val2)))
        (##list 'and val1 val2)))))

(define-prim ##degen-case
  (mk-degen ()
    (let ((val1 (##decomp (^ 0)))
          (val2 (##decomp (^ 1))))
      (##cons 'case (##cons val1 val2)))))

(define-prim ##degen-case-clause
  (mk-degen ()
    (let ((val1 (##decomp (^ 0)))
          (val2 (##decomp (^ 1))))
      (##cons (if (##begin? val1)
                (##cons (^ 2) (##cdr val1))
                (##list (^ 2) val1))
              val2))))

(define-prim ##degen-case-else
  (mk-degen ()
    (let ((val (##decomp (^ 0))))
      (if (##void-constant? val)
        '()
        (##list (if (##begin? val)
                  (##cons 'else (##cdr val))
                  (##list 'else val)))))))

(define-prim ##degen-let
  (mk-degen ()
    (let ((n (macro-code-length $code)))
      (let loop ((i (##fixnum.- n 2)) (vals '()))
        (if (##fixnum.< 0 i)
          (loop (##fixnum.- i 1)
                (##cons (##decomp (macro-code-ref $code i)) vals))
          (let ((body
                 (##decomp (^ 0)))
                (bindings
                 (##make-bindings (macro-code-ref $code (##fixnum.- n 1))
                                  vals)))
            (if (##begin? body)
              (##cons 'let (##cons bindings (##cdr body)))
              (##list 'let bindings body))))))))

(define-prim (##make-bindings l1 l2)
  (if (##pair? l1)
    (##cons (##list (##car l1) (##car l2))
            (##make-bindings (##cdr l1) (##cdr l2)))
    '()))

(define-prim ##degen-letrec
  (mk-degen ()
    (let ((n (macro-code-length $code)))
      (let loop ((i (##fixnum.- n 2)) (vals '()))
        (if (##fixnum.< 0 i)
          (loop (##fixnum.- i 1)
                (##cons (##decomp (macro-code-ref $code i)) vals))
          (let ((body
                 (##decomp (^ 0)))
                (bindings
                 (##make-bindings (macro-code-ref $code (##fixnum.- n 1))
                                  vals)))
            (if (##begin? body)
              (##cons 'letrec (##cons bindings (##cdr body)))
              (##list 'letrec bindings body))))))))

(define-prim ##degen-prc-req
  (mk-degen ()
    (let* ((n (macro-code-length $code))
           (body (##decomp (^ 0)))
           (params (macro-code-ref $code (##fixnum.- n 1))))
      (if (##begin? body)
        (##cons 'lambda (##cons params (##cdr body)))
        (##list 'lambda params body)))))

(define-prim ##degen-prc-rest
  (mk-degen ()
    (let ((body (##decomp (^ 0)))
          (params (##make-params (^ 3) #t #f '())))
      (if (##begin? body)
        (##cons 'lambda (##cons params (##cdr body)))
        (##list 'lambda params body)))))

(define-prim ##degen-prc
  (mk-degen ()
    (let ((n (macro-code-length $code)))
      (let loop ((i (##fixnum.- n 8)) (inits '()))
        (if (##not (##fixnum.< i 1))
          (loop (##fixnum.- i 1)
                (##cons (##decomp (macro-code-ref $code i)) inits))
          (let ((body
                 (##decomp (^ 0)))
                (params
                 (##make-params
                   (macro-code-ref $code (##fixnum.- n 1))
                   (macro-code-ref $code (##fixnum.- n 4))
                   (macro-code-ref $code (##fixnum.- n 3))
                   inits)))
            (if (##begin? body)
              (##cons 'lambda (##cons params (##cdr body)))
              (##list 'lambda params body))))))))

(define-prim (##make-params parms rest? keys inits)
  (let* ((nb-parms
          (##length parms))
         (nb-inits
          (##length inits))
         (nb-reqs
          (##fixnum.- nb-parms (##fixnum.+ nb-inits (if rest? 1 0))))
         (nb-opts
          (##fixnum.- nb-inits (if keys (##vector-length keys) 0))))

    (define (build-reqs)
      (let loop ((parms parms)
                 (i nb-reqs))
        (if (##fixnum.= i 0)
          (build-opts parms)
          (let ((parm (##car parms)))
            (##cons parm
                    (loop (##cdr parms)
                          (##fixnum.- i 1)))))))

    (define (build-opts parms)
      (if (##fixnum.= nb-opts 0)
        (build-rest-and-keys parms inits)
        (##cons #!optional
                (let loop ((parms parms)
                           (i nb-opts)
                           (inits inits))
                  (if (##fixnum.= i 0)
                    (build-rest-and-keys parms inits)
                    (let ((parm (##car parms))
                          (init (##car inits)))
                      (##cons (if (##eq? init #f) parm (##list parm init))
                              (loop (##cdr parms)
                                    (##fixnum.- i 1)
                                    (##cdr inits)))))))))

    (define (build-rest-and-keys parms inits)
      (if (##eq? rest? 'dsssl)
        (##cons #!rest
                (##cons (##car parms)
                        (build-keys (##cdr parms) inits)))
        (build-keys parms inits)))

    (define (build-keys parms inits)
      (if (##not keys)
        (build-rest-at-end parms)
        (##cons #!key
                (let loop ((parms parms)
                           (i (##vector-length keys))
                           (inits inits))
                  (if (##fixnum.= i 0)
                    (build-rest-at-end parms)
                    (let ((parm (##car parms))
                          (init (##car inits)))
                      (##cons (if (##eq? init #f) parm (##list parm init))
                              (loop (##cdr parms)
                                    (##fixnum.- i 1)
                                    (##cdr inits)))))))))

    (define use-dotted-rest-parameter-when-possible? #t)

    (define (build-rest-at-end parms)
      (if (##eq? rest? #t)
        (if use-dotted-rest-parameter-when-possible?
          (##car parms)
          (##cons #!rest (##cons (##car parms) '())))
        '()))

    (build-reqs)))

(define-prim ##degen-app0
  (mk-degen ()
    (##list (##decomp (^ 0)))))

(define-prim ##degen-app1
  (mk-degen ()
    (##list (##decomp (^ 0))
            (##decomp (^ 1)))))

(define-prim ##degen-app2
  (mk-degen ()
    (##list (##decomp (^ 0))
            (##decomp (^ 1))
            (##decomp (^ 2)))))

(define-prim ##degen-app3
  (mk-degen ()
    (##list (##decomp (^ 0))
            (##decomp (^ 1))
            (##decomp (^ 2))
            (##decomp (^ 3)))))

(define-prim ##degen-app4
  (mk-degen ()
    (##list (##decomp (^ 0))
            (##decomp (^ 1))
            (##decomp (^ 2))
            (##decomp (^ 3))
            (##decomp (^ 4)))))

(define-prim ##degen-app
  (mk-degen ()
    (let ((n (macro-code-length $code)))
      (let loop ((i (##fixnum.- n 1)) (vals '()))
        (if (##not (##fixnum.< i 0))
          (loop (##fixnum.- i 1)
                (##cons (##decomp (macro-code-ref $code i)) vals))
          vals)))))

(define-prim ##degen-delay
  (mk-degen ()
    (##list 'delay (##decomp (^ 0)))))

(define-prim ##degen-future
  (mk-degen ()
    (##list 'future (##decomp (^ 0)))))

(define-prim ##degen-require
  (mk-degen ()
    (##decomp (^ 1))))

;;;----------------------------------------------------------------------------

(define ##decomp-dispatch-table #f)

(define-prim (##setup-decomp-dispatch-table)
  (set! ##decomp-dispatch-table
    (##list
      (##cons ##cprc-top         ##degen-top)

      (##cons ##cprc-cst         ##degen-cst)

      (##cons ##cprc-loc-ref-0-1 (mk-degen () (degen ##degen-loc-ref-x-y 0 1)))
      (##cons ##cprc-loc-ref-0-2 (mk-degen () (degen ##degen-loc-ref-x-y 0 2)))
      (##cons ##cprc-loc-ref-0-3 (mk-degen () (degen ##degen-loc-ref-x-y 0 3)))
      (##cons ##cprc-loc-ref-1-1 (mk-degen () (degen ##degen-loc-ref-x-y 1 1)))
      (##cons ##cprc-loc-ref-1-2 (mk-degen () (degen ##degen-loc-ref-x-y 1 2)))
      (##cons ##cprc-loc-ref-1-3 (mk-degen () (degen ##degen-loc-ref-x-y 1 3)))
      (##cons ##cprc-loc-ref-2-1 (mk-degen () (degen ##degen-loc-ref-x-y 2 1)))
      (##cons ##cprc-loc-ref-2-2 (mk-degen () (degen ##degen-loc-ref-x-y 2 2)))
      (##cons ##cprc-loc-ref-2-3 (mk-degen () (degen ##degen-loc-ref-x-y 2 3)))
      (##cons ##cprc-loc-ref     ##degen-loc-ref)
      (##cons ##cprc-glo-ref     ##degen-glo-ref)

      (##cons ##cprc-loc-set     ##degen-loc-set)
      (##cons ##cprc-glo-set     ##degen-glo-set)
      (##cons ##cprc-glo-def     ##degen-glo-def)

      (##cons ##cprc-if2         ##degen-if2)
      (##cons ##cprc-if3         ##degen-if3)
      (##cons ##cprc-seq         ##degen-seq)
      (##cons ##cprc-quasi-list->vector ##degen-quasi-list->vector)
      (##cons ##cprc-quasi-append ##degen-quasi-append)
      (##cons ##cprc-quasi-cons  ##degen-quasi-cons)
      (##cons ##cprc-cond-if     ##degen-cond-if)
      (##cons ##cprc-cond-or     ##degen-cond-or)
      (##cons ##cprc-cond-send-red ##degen-cond-send)
      (##cons ##cprc-cond-send-sub ##degen-cond-send)

      (##cons ##cprc-or          ##degen-or)
      (##cons ##cprc-and         ##degen-and)

      (##cons ##cprc-case        ##degen-case)
      (##cons ##cprc-case-clause ##degen-case-clause)
      (##cons ##cprc-case-else   ##degen-case-else)

      (##cons ##cprc-let         ##degen-let)
      (##cons ##cprc-letrec      ##degen-letrec)

      (##cons ##cprc-prc-req0    ##degen-prc-req)
      (##cons ##cprc-prc-req1    ##degen-prc-req)
      (##cons ##cprc-prc-req2    ##degen-prc-req)
      (##cons ##cprc-prc-req3    ##degen-prc-req)
      (##cons ##cprc-prc-req     ##degen-prc-req)
      (##cons ##cprc-prc-rest    ##degen-prc-rest)
      (##cons ##cprc-prc         ##degen-prc)

      (##cons ##cprc-app0-red    ##degen-app0)
      (##cons ##cprc-app1-red    ##degen-app1)
      (##cons ##cprc-app2-red    ##degen-app2)
      (##cons ##cprc-app3-red    ##degen-app3)
      (##cons ##cprc-app4-red    ##degen-app4)
      (##cons ##cprc-app-red     ##degen-app)
      (##cons ##cprc-app0-sub    ##degen-app0)
      (##cons ##cprc-app1-sub    ##degen-app1)
      (##cons ##cprc-app2-sub    ##degen-app2)
      (##cons ##cprc-app3-sub    ##degen-app3)
      (##cons ##cprc-app4-sub    ##degen-app4)
      (##cons ##cprc-app-sub     ##degen-app)

      (##cons ##cprc-delay       ##degen-delay)
      (##cons ##cprc-future      ##degen-future)

      (##cons ##cprc-require     ##degen-require)
)))

(##setup-decomp-dispatch-table)

;;;----------------------------------------------------------------------------

;;; Pretty-printer that decompiles procedures.

(define-prim (pp
              obj
              #!optional
              (p (macro-absent-obj)))
  (macro-force-vars (obj p)
    (let ((port
           (if (##eq? p (macro-absent-obj))
             (##repl-output-port)
             p)))
      (macro-check-output-port port 2 (pp obj p)
        (##pretty-print
         (if (##procedure? obj)
           (##decompile obj)
           obj)
         port)))))

(define-prim (##decomp $code)
  (let ((cprc (macro-code-cprc $code)))
    (let ((x (##assq cprc ##decomp-dispatch-table)))
      (if x
        (degen (##cdr x))
        '?))))

(define-prim (##decompile proc)

  (define (decomp p)
    (let ((src (##subprocedure-source p)))
      (if src
        (source->expression src)
        proc)))

  (define (compiler-source-code src)
    (##source-code src))

  (define (source->expression src)

    (define (list->expression l)
      (cond ((##pair? l)
             (##cons (source->expression (##car l))
                     (list->expression (##cdr l))))
            ((##null? l)
             '())
            (else
             (source->expression l))))

    (define (vector->expression v)
      (let* ((len (##vector-length v))
             (x (##make-vector len 0)))
        (let loop ((i (##fixnum.- len 1)))
          (if (##not (##fixnum.< i 0))
            (begin
              (##vector-set! x i (source->expression (##vector-ref v i)))
              (loop (##fixnum.- i 1)))))
        x))

    (let ((code (compiler-source-code src)))
      (cond ((##pair? code)   (list->expression code))
            ((##vector? code) (vector->expression code))
            (else             code))))

  (let loop ((p proc))
    (cond ((##interp-procedure? p)
           (let* (($code (##interp-procedure-code p))
                  (cprc (macro-code-cprc $code)))
             (if (##eq? cprc ##interp-procedure-wrapper)
               (loop (^ 1))
               (##decomp $code))))
          ((##closure? p)
           (decomp (##closure-code p)))
          (else
           (decomp p)))))

(define-prim (##procedure-locat proc)

  (define (locat p)
    (let ((src (##subprocedure-source p)))
      (if src
        (compiler-source-locat src)
        #f)))

  (define (compiler-source-locat src)
    (##source-locat src))

  (let loop ((p proc))
    (cond ((##interp-procedure? p)
           (let* (($code (##interp-procedure-code p))
                  (cprc (macro-code-cprc $code)))
             (if (##eq? cprc ##interp-procedure-wrapper)
               (loop (^ 1))
               (##code-locat $code))))
          ((##closure? p)
           (locat (##closure-code p)))
          (else
           (locat p)))))

(define-prim (##code-locat $code)
  (let ((locat-or-position (macro-code-locat $code)))
    (if (or (##locat? locat-or-position) (##not locat-or-position))
      locat-or-position
      (let loop ((parent (macro-code-link $code)))
        (if parent
          (let ((locat-or-position-parent (macro-code-locat parent)))
            (if (##locat? locat-or-position-parent)
              (##make-locat (##locat-container locat-or-position-parent)
                            locat-or-position)
              (loop (macro-code-link parent))))
          #f)))))

(define-prim (##subprocedure-source proc)
  (let ((info (##subprocedure-info proc)))
    (if info
      (##vector-ref info 1)
      #f)))

(define-prim (##subprocedure-info proc)
  (let* ((id (##subprocedure-id proc))
         (parent-info (##subprocedure-parent-info proc)))
    (if parent-info
      (let ((v (##vector-ref parent-info 0)))
        (let loop ((i (##fixnum.- (##vector-length v) 1)))
          (if (##fixnum.< i 0)
            #f
            (let ((x (##vector-ref v i)))
              (if (##fixnum.= id (##vector-ref x 0))
                x
                (loop (##fixnum.- i 1)))))))
      #f)))

;;;============================================================================

;;; Utilities

;;;----------------------------------------------------------------------------

(define-prim (##procedure-name p)
  (or (and (##procedure? p)
           (##object->global-var->identifier p))
      p))

;;;----------------------------------------------------------------------------

;; Internal variables and parameters are uninteresting for the user.

(define-prim (##hidden-local-var? var)
  (or (##eq? var (macro-self-var))
      (##eq? var (macro-selector-var))
      (##eq? var (macro-do-loop-var))))

(define-prim (##hidden-parameter? param)
  (or (##eq? param ##trace-depth)
      (##eq? param ##current-user-interrupt-handler)))

;;;----------------------------------------------------------------------------

;;; Access to structure of closures for interpreter procedures.

;; Layout of closed variables for closures created by ##cprc-prcXXX and
;; ##interp-procedure-wrapper:
;;
;;   slot 1: $code
;;   slot 2: proc
;;   slot 3: rte

(define ##interp-procedure-code-pointers
  (let (($code (macro-make-code #f #f #f (##no-stepper) ()))
        (rte #f))
    (##list (##closure-code (##cprc-prc-req0 $code rte))
            (##closure-code (##cprc-prc-req1 $code rte))
            (##closure-code (##cprc-prc-req2 $code rte))
            (##closure-code (##cprc-prc-req3 $code rte))
            (##closure-code (##cprc-prc-req  $code rte))
            (##closure-code (##cprc-prc-rest $code rte))
            (##closure-code (##cprc-prc      $code rte))
            (##closure-code (##interp-procedure-wrapper $code rte)))))

(define-prim (##interp-procedure? x)
  (and (##procedure? x)
       (##closure? x)
       (##memq (##closure-code x) ##interp-procedure-code-pointers)))

(define-prim (##interp-procedure-code x) ;; return "$code" closed variable of x
  (##closure-ref x 1))

(define-prim (##interp-procedure-rte x) ;; return "rte" closed variable of x
  (##closure-ref x 3))

;;;----------------------------------------------------------------------------

;;; Access to continuations

(define-prim (##continuation-parent cont)
  (##subprocedure-parent (##continuation-ret cont)))

(define ##show-all-continuations? #f)
(set! ##show-all-continuations? #f)

(define-prim (##hidden-continuation? cont)
  (if ##show-all-continuations?
    #f
    (let ((parent (##continuation-parent cont)))
      (or (##eq? parent ##interp-procedure-wrapper);;;;;;;;;;;;;;;;;;
          (##eq? parent ##dynamic-wind)
          (##eq? parent ##dynamic-env-bind)
          (##eq? parent ##kernel-handlers)
          (##eq? parent ##execute-modules)
          (##eq? parent ##repl-debug)
          (##eq? parent ##repl-debug-main)
          (##eq? parent ##repl-within)
          (##eq? parent ##eval-within)
          (##eq? parent ##with-no-result-expected)
          (##eq? parent ##check-heap)
          (##eq? parent ##nontail-call-for-leap)
          (##eq? parent ##nontail-call-for-step)
          (##eq? parent ##trace-generate)))))

(define-prim (##interp-subproblem-continuation? cont)
  (let ((parent (##continuation-parent cont)))
    (or (##eq? parent ##subproblem-apply0)
        (##eq? parent ##subproblem-apply1)
        (##eq? parent ##subproblem-apply2)
        (##eq? parent ##subproblem-apply3)
        (##eq? parent ##subproblem-apply4)
        (##eq? parent ##subproblem-apply))))

(define-prim (##interp-internal-continuation? cont)
  (let ((parent (##continuation-parent cont)))
    (or (##eq? parent ##step-handler)
        (##assq parent ##decomp-dispatch-table))))

(define-prim (##interp-continuation? cont)
  (or (##interp-subproblem-continuation? cont)
      (##interp-internal-continuation? cont)))

(define-prim (##continuation-creator cont) ;; returns #f if creator is REPL
  (and cont
       (if (##interp-continuation? cont)
         (let (($code (##interp-continuation-code cont))
               (rte (##interp-continuation-rte cont)))
           (##extract-container $code rte))
         (##continuation-parent cont))))

(define-prim (##continuation-locat cont) ;; returns #f if location unknown
  (and cont
       (if (##interp-continuation? cont)
         (##code-locat (##interp-continuation-code cont))
         (##procedure-locat (##continuation-ret cont)))))

(define-prim (##interp-continuation-code cont)
  (##cdr (##continuation-locals cont '$code)))

(define-prim (##interp-continuation-rte cont)
  (##cdr (##continuation-locals cont 'rte)))

(define-prim (##interesting-continuation? cont)
  (or ##show-all-continuations?
      (##interp-subproblem-continuation? cont)
      (and (##not (##interp-internal-continuation? cont))
           (##not (##hidden-continuation? cont)))))

(define-prim (##continuation-first-interesting cont)
  (and cont
       (if (##hidden-continuation? cont)
         (##continuation-next-interesting cont)
         cont)))

(define-prim (##continuation-next-interesting cont)
  (and cont
       (let loop ((cont cont))
         (let ((next (##continuation-next cont)))
           (and next
                (if (##interesting-continuation? next)
                  next
                  (loop next)))))))

(define-prim (##continuation-count-interesting cont)
  (let loop ((cont cont) (n 0))
    (if cont
      (if (##interesting-continuation? cont)
        (loop (##continuation-next cont) (##fixnum.+ n 1))
        (loop (##continuation-next cont) n))
      n)))

(define-prim (##continuation-locals cont #!optional (var (macro-absent-obj)))
  (##subprocedure-locals (##continuation-ret cont) cont var))

(define-prim (##subprocedure-locals
              proc
              #!optional
              (cont (macro-absent-obj))
              (var (macro-absent-obj)))
  (let* ((parent-info (##subprocedure-parent-info proc))
         (info (##subprocedure-info proc)))
    (if (and parent-info info)
      (let ((var-descrs (##vector-ref parent-info 1)))
        (let loop1 ((j 2) (result '()))
          (if (##fixnum.< j (##vector-length info))
            (let* ((descr
                    (##vector-ref info j))
                   (slot-index
                    (##fixnum.quotient descr 32768))
                   (var-descr-index
                    (##fixnum.quotient (##fixnum.modulo descr 32768) 2))
                   (var-descr
                    (##vector-ref var-descrs var-descr-index))
                   (val1
                    (if (##eq? cont (macro-absent-obj))
                      #f
                      (let ((val (##continuation-ref cont slot-index)))
                        (if (##fixnum.= (##fixnum.modulo descr 2) 0)
                          val
                          (##unbox val))))))
              (if (##pair? var-descr)
                (let loop2 ((lst var-descr) (result result))
                  (if (##pair? lst)
                    (let* ((descr
                            (##car lst))
                           (slot-index
                            (##fixnum.quotient descr 32768))
                           (var-descr-index
                            (##fixnum.quotient (##fixnum.modulo descr 32768) 2))
                           (var-descr
                            (##vector-ref var-descrs var-descr-index))
                           (val2
                            (if (##eq? cont (macro-absent-obj))
                              #f
                              (let ((val (##closure-ref val1 slot-index)))
                                (if (##fixnum.= (##fixnum.modulo descr 2) 0)
                                  val
                                  (##unbox val))))))
                      (if (##eq? cont (macro-absent-obj))
                        (loop2 (##cdr lst)
                               (##cons var-descr result))
                        (if (##eq? var (macro-absent-obj))
                          (loop2 (##cdr lst)
                                 (##cons (##cons var-descr val2) result))
                          (if (##eq? var var-descr)
                            (##cons var-descr val2)
                            (loop2 (##cdr lst)
                                   result)))))
                    (loop1 (##fixnum.+ j 1)
                           result)))
                (if (##eq? cont (macro-absent-obj))
                  (loop1 (##fixnum.+ j 1)
                         (##cons var-descr result))
                  (if (##eq? var (macro-absent-obj))
                    (loop1 (##fixnum.+ j 1)
                           (##cons (##cons var-descr val1) result))
                    (if (##eq? var var-descr)
                      (##cons var-descr val1)
                      (loop1 (##fixnum.+ j 1)
                             result))))))
            result)))
      #f)))

;;;----------------------------------------------------------------------------

;;; Access to run time environments

(define-prim (##rte-shape $code)

  (define (get-shape cte)
    (cond ((##cte-top? cte)
           #f)
          ((##cte-frame? cte)
           (##list->vector
             (##cons (get-shape (##cte-parent-cte cte))
                     (##cte-frame-vars cte))))
          (else
           (get-shape (##cte-parent-cte cte)))))

  (get-shape (macro-code-cte $code)))

(define-prim (##rte-var-ref rte up over)
  (let loop ((r rte) (i up))
    (if (##fixnum.< 0 i)
      (loop (macro-rte-up r) (##fixnum.- i 1))
      (##vector-ref r over))))

(define-prim (##rte-var-set! rte up over val)
  (let loop ((r rte) (i up))
    (if (##fixnum.< 0 i)
      (loop (macro-rte-up r) (##fixnum.- i 1))
      (##vector-set! r over val))))

;;;----------------------------------------------------------------------------

(define-prim (##cmd-? port)
  (##write-string
",?                 : Summary of comma commands
,q                 : Terminate the current thread
,t                 : Jump to toplevel REPL
,d                 : Jump to enclosing REPL
,c and ,(c <expr>) : Continue the computation with stepping off
,s and ,(s <expr>) : Continue the computation with stepping on (step)
,l and ,(l <expr>) : Continue the computation with stepping on (leap)
,<n>               : Move to particular frame (<n> >= 0)
,+ and ,-          : Move to next or previous frame of continuation
,y                 : Display one-line summary of current frame
,b                 : Display summary of continuation (i.e. backtrace)
,i                 : Display procedure attached to current frame
,e                 : Display environment accessible from current frame
" port))

;;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(define-prim (##cmd-b depth cont port)

  (define max-head 10)
  (define max-tail 4)

  (let loop ((i 0)
             (j (##fixnum.- (##continuation-count-interesting cont) 1))
             (cont cont))
    (and cont
         (begin
           (cond ((or (##fixnum.< i max-head) (##fixnum.< j max-tail)
                      (and (##fixnum.= i max-head) (##fixnum.= j max-tail)))
                  (##cmd-y (##fixnum.+ depth i) cont #f port))
                 ((##fixnum.= i max-head)
                  (##write-string "..." port)
                  (##newline port)))
           (loop (##fixnum.+ i 1)
                 (##fixnum.- j 1)
                 (##continuation-next-interesting cont))))))

;;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(define-prim (##cmd-y depth cont pinpoint? port)

  (define creator-col 4)
  (define locat-col   30)
  (define call-col    54)

  (define (tab col)
    (let* ((current (##output-port-column port))
           (n (##fixnum.- col current)))
      (##display-spaces (##fixnum.max n 1) port)))

  (and cont
       (begin
         (##write depth port)
         (let ((creator (##continuation-creator cont)))
           (tab creator-col)
           (if creator
             (##write (##procedure-name creator) port)
             (##write-string "(interaction)" port)))
         (let ((locat (##continuation-locat cont)))
           (tab locat-col)
           (##display-locat locat pinpoint? port))
         (let ((call
                (if (##interp-continuation? cont)
                  (let* (($code (##interp-continuation-code cont))
                         (cprc (macro-code-cprc $code)))
                    (if (##eq? cprc ##interp-procedure-wrapper)
                      #f
                      (##decomp $code)))
                  (let* ((ret (##continuation-ret cont))
                         (call (##decompile ret)))
                    (if (##eq? call ret)
                      #f
                      call)))))
           (if call
             (begin
               (tab call-col)
               (##write-string
                (##object->string
                 call
                 (##fixnum.- (##output-port-width port)
                             (##output-port-column port)))
                port))))
         (##newline port))))

(define-prim (##display-spaces n port)
  (if (##fixnum.< 0 n)
    (let ((m (if (##fixnum.< 40 n) 40 n)))
      (##write-substring "                                        " 0 m port)
      (##display-spaces (##fixnum.- n m) port)
      n)))

(define-prim (##display-locat locat pinpoint? port)
  (if locat ;; locat is #f if location unknown
    (let* ((container (##locat-container locat))
           (file (##container->file container)))
      (if file
        (##write (##path-normalize file
                                   ##repl-location-relative
                                   ##repl-location-origin)
                 port)
        (##write-string (##container->id container) port))
      (let* ((filepos (##position->filepos (##locat-position locat)))
             (line (##fixnum.+ (##filepos-line filepos) 1))
             (col (##fixnum.+ (##filepos-col filepos) 1)))
        (##write-string "@" port)
        (##write line port)
        (##write-string (if pinpoint? "." ":") port)
        (##write col port)))))

(define ##repl-location-relative #f)
(set! ##repl-location-relative 'shortest)

(define ##repl-location-origin #f)
(set! ##repl-location-origin #f)

;;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(define-prim (##cmd-e cont port)

  (define (display-var-val var val cte)
    (##write var port)
    (##write-string " = " port)
    (##write-string
     (##object->string
      (if (##cte-top? cte)
        (##inverse-eval-in-env val cte)
        (##inverse-eval-in-env val (##cte-parent-cte cte)))
      (##fixnum.- (##output-port-width port)
                  (##output-port-column port)))
     port)
    (##newline port))

  (define (display-rte cte rte)
    (let loop1 ((c cte)
                (r rte))
      (cond ((##cte-top? c))
            ((##cte-frame? c)
             (let loop2 ((vars (##cte-frame-vars c))
                         (vals (##cdr (##vector->list r))))
               (if (##pair? vars)
                 (let ((var (##car vars)))
                   (if (##not (##hidden-local-var? var))
                     (display-var-val var (##car vals) c))
                   (loop2 (##cdr vars)
                          (##cdr vals)))
                 (loop1 (##cte-parent-cte c)
                        (macro-rte-up r)))))
            (else
             (loop1 (##cte-parent-cte c)
                    r)))))

  (define (display-vars lst cte)
    (let loop ((lst lst))
      (if (##pair? lst)
        (let* ((var-val (##car lst))
               (var (##car var-val))
               (val (##cdr var-val)))
          (display-var-val var val cte)
          (loop (##cdr lst))))))

  (define (display-locals lst cte)
    (and lst
         (display-vars lst cte)))

  (define (display-parameters lst cte)
    (let loop ((lst lst))
      (if (##pair? lst)
        (let* ((param-val (##car lst))
               (param (##car param-val))
               (val (##cdr param-val)))
          (if (##not (##hidden-parameter? param))
            (let ((x
                   (##inverse-eval-in-env param cte)))
              (display-var-val (##list x) val cte)))
          (loop (##cdr lst))))))

  (and cont
       (display-parameters
        (##dynamic-env->list (macro-continuation-denv cont))
        (if (##interp-continuation? cont)
          (let (($code (##interp-continuation-code cont))
                (rte (##interp-continuation-rte cont)))
            (display-rte (macro-code-cte $code) rte)
            (macro-code-cte $code))
          (begin
            (display-locals (##continuation-locals cont)
                            ##interaction-cte)
            ##interaction-cte)))))

(define-prim (##inverse-eval-in-env obj cte)
  (if (##procedure? obj)
    (let ((id (##object->global-var->identifier obj)))

      (define (default)
        (let ((x (##decompile obj)))
          (if (##procedure? x)
            (##inverse-eval x)
            x)))

      (if id
        (let ((ind (##cte-lookup cte id)))
          (if (##eq? (##vector-ref ind 0) 'not-found)
            id
            (default)))
        (default)))

    (##inverse-eval obj)))

(define-prim (##inverse-eval obj)
  (if (##self-eval? obj)
    obj
    (##list 'quote obj)))

;;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(define-prim (##cmd-i cont port)
  (and cont
       (let ((creator (##continuation-creator cont)))
         (if creator
           (let ((decomp-creator (##decompile creator)))
             (##write creator port)
             (if (##eq? creator decomp-creator)
               (##newline port)
               (begin
                 (##write-string " =" port)
                 (##newline port)
                 (##pretty-print decomp-creator port))))
           (begin
             (##write-string "(interaction)" port)
             (##newline port))))))

;;;----------------------------------------------------------------------------

;;; Tracing and single stepping.

(define-prim (##interp-procedure-entry-hook proc)
  (let (($code (##interp-procedure-code proc)))
    (macro-code-ref $code (##fixnum.- (macro-code-length $code) 2))))

(define-prim (##interp-procedure-entry-hook-set! proc hook)
  (let (($code (##interp-procedure-code proc)))
    (macro-code-set! $code (##fixnum.- (macro-code-length $code) 2) hook)))

(define-prim (##interp-procedure-default-entry-hook proc)
  (let ((hook (##interp-procedure-entry-hook proc)))
    (if (and hook
             (##closure? hook)
             (##eq? (##subprocedure-parent (##closure-code hook))
                    ##make-default-entry-hook))
      hook
      #f)))

(define-prim (##make-default-entry-hook)
  (let ((settings (##vector #f #f)))
    (lambda (proc args execute)
      (if (##vector-ref settings 0)
        (##step-on)) ;; turn on single-stepping
      (if (##vector-ref settings 1)
        (##trace-generate
         (##make-call-form proc
                           (##argument-list-remove-absent! args '())
                           ##max-fixnum)
         execute
         #f)
        (execute)))))

(define-prim (##make-call-form proc args max-args)

  (define (inverse-eval-args i lst)
    (if (##pair? lst)
      (if (##fixnum.< max-args i)
        '(...)
        (##cons (##inverse-eval (##car lst))
                (inverse-eval-args (##fixnum.+ i 1) (##cdr lst))))
      '()))

  (##cons (##procedure-name proc)
          (inverse-eval-args 1 args)))

(define ##trace-depth (##make-parameter 0))

(define-prim (##trace-generate form execute leap?)

  (define max-depth 10)

  (define (bars width output-port)
    (let loop ((i 0))
      (if (##fixnum.< i width)
        (begin
          (##write-string
            (if (##fixnum.= (##fixnum.remainder i 2) 0) "|" " ")
            output-port)
          (loop (##fixnum.+ i 1))))))

  (define (bars-width depth)
    (let ((d (if (##fixnum.< max-depth depth) max-depth depth)))
      (if (##fixnum.< 0 d) (##fixnum.- (##fixnum.* d 2) 1) 0)))

  (define (indent depth output-port)
    (let ((w (bars-width depth)))
      (if (##fixnum.< max-depth depth)
        (let ((depth-str (##number->string depth 10)))
          (bars (##fixnum.- w (##fixnum.+ (##string-length depth-str) 2))
                output-port)
          (##write-string "[" output-port)
          (##write-string depth-str output-port)
          (##write-string "]" output-port))
        (bars w output-port))
      w))

  (##continuation-capture
   (lambda (cont)
     (let* ((parent
             (##continuation-parent cont))
            (increase-depth?
             (and (##not (##eq? ##nontail-call-for-leap parent))
                  (##not (##eq? ##nontail-call-for-step parent))))
            (current-depth
             (##trace-depth))
            (depth
             (if increase-depth?
               (##fixnum.+ current-depth 1)
               current-depth)))

       (define (nest wrapper)
         (let ((result
                (##parameterize
                 ##trace-depth
                 depth
                 (lambda () (wrapper execute)))))

           (##repl
            (lambda (first output-port)
              (let ((width
                     (##fixnum.+ (indent depth output-port) 1)))
                (##write-string " " output-port)
                (##write-string
                 (##object->string
                  result
                  (##fixnum.- (##output-port-width output-port) width))
                 output-port)
                (##newline output-port)
                #t)))

           result))

       (##repl
        (lambda (first output-port)
          (let ((width
                 (##fixnum.+ (indent depth output-port) 3)))
            (##write-string " > " output-port)
            (##write-string
             (##object->string
              form
              (##fixnum.- (##output-port-width output-port) width))
             output-port)
            (##newline output-port)
            #t)))

       (if leap?
         (cond ((##eq? ##nontail-call-for-leap parent)
                (execute))
               ((##eq? ##nontail-call-for-step parent)
                (##nontail-call-for-leap execute))
               (else
                (nest ##nontail-call-for-leap)))
         (cond ((##eq? ##nontail-call-for-leap parent)
                (execute))
               ((##eq? ##nontail-call-for-step parent)
                (execute))
               (else
                (nest ##nontail-call-for-step))))))))

(define-prim (##nontail-call-for-leap execute)
  (let ((result (execute)))
    (##step-on)
    result))

(define-prim (##nontail-call-for-step execute)
  (##first-argument (execute)))

(define ##trace-list '())

(define-prim (##trace proc)

  (define (setup hook)
    (let ((settings (##closure-ref hook 1)))
      (##vector-set! settings 1 #t)
      (if (##not (##memq proc ##trace-list))
        (set! ##trace-list (##cons proc ##trace-list)))))

  (let ((hook (##interp-procedure-default-entry-hook proc)))
    (if hook
      (setup hook)
      (let ((new-hook (##make-default-entry-hook)))
        (##interp-procedure-entry-hook-set! proc new-hook)
        (setup new-hook)))))

(define-prim (##untrace proc)
  (let ((hook (##interp-procedure-default-entry-hook proc)))
    (if hook
      (let ((settings (##closure-ref hook 1)))
        (##vector-set! settings 1 #f)
        (if (##not (##vector-ref settings 0))
          (##interp-procedure-entry-hook-set! proc #f))))
    (set! ##trace-list (##remove proc ##trace-list))))

(define-prim (trace . args)
  (if (##pair? args)
    (##for-each-interp-procedure
     trace
     args
     ##trace
     args)
    ##trace-list))

(define-prim (untrace . args)
  (##for-each-interp-procedure
   untrace
   args
   ##untrace
   (if (##pair? args) args ##trace-list)))

(define ##break-list '())

(define-prim (##break proc)

  (define (setup hook)
    (let ((settings (##closure-ref hook 1)))
      (##vector-set! settings 0 #t)
      (if (##not (##memq proc ##break-list))
        (set! ##break-list (##cons proc ##break-list)))))

  (let ((hook (##interp-procedure-default-entry-hook proc)))
    (if hook
      (setup hook)
      (let ((new-hook (##make-default-entry-hook)))
        (##interp-procedure-entry-hook-set! proc new-hook)
        (setup new-hook)))))

(define-prim (##unbreak proc)
  (let ((hook (##interp-procedure-default-entry-hook proc)))
    (if hook
      (let ((settings (##closure-ref hook 1)))
        (##vector-set! settings 0 #f)
        (if (##not (##vector-ref settings 1))
          (##interp-procedure-entry-hook-set! proc #f))))
    (set! ##break-list (##remove proc ##break-list))))

(define-prim (break . args)
  (if (##pair? args)
    (##for-each-interp-procedure
     break
     args
     ##break
     args)
    ##break-list))

(define-prim (unbreak . args)
  (##for-each-interp-procedure
   unbreak
   args
   ##unbreak
   (if (##pair? args) args ##break-list)))

(define-prim (##step-on)
  (##declare (not interrupts-enabled))
  (let* ((stepper (##current-stepper))
         (handlers (##vector-ref stepper 0)))
    (let loop ((i (##vector-length handlers)))
      (if (##not (##fixnum.< i 1))
        (let ((i-1 (##fixnum.- i 1)))
          (##vector-set! stepper i (##vector-ref handlers i-1))
          (loop i-1))))
    (##void)))

(define-prim (##step-off)
  (##declare (not interrupts-enabled))
  (let* ((stepper (##current-stepper))
         (handlers (##vector-ref stepper 0)))
    (let loop ((i (##vector-length handlers)))
      (if (##not (##fixnum.< i 1))
        (let ((i-1 (##fixnum.- i 1)))
          (##vector-set! stepper i #f)
          (loop i-1))))
    (##void)))

(define-prim (step)
  (##step-on))

(define-prim (##step-level-set! n)
  (##declare (not interrupts-enabled))
  (let* ((stepper (##current-stepper))
         (handlers (##vector-ref stepper 0)))
    (let loop ((i (##vector-length handlers)))
      (if (##not (##fixnum.< i 1))
        (let ((i-1 (##fixnum.- i 1)))
          (##vector-set! handlers i-1
            (if (##fixnum.< i-1 n)
              (##vector-ref ##step-handlers i-1)
              #f))
          (loop i-1))))
    (##void)))

(define-prim (step-level-set! n)
  (macro-force-vars (n)
    (macro-check-fixnum-range-incl n 1 0 7 (step-level-set! n)
      (##step-level-set! n))))

(define ##step-handlers (macro-make-step-handlers))

(set! ##main-stepper (macro-make-main-stepper))

(define ##display-environment? #f)
(set! ##display-environment? #f)

(define-prim (display-environment-set! display?)
  (set! ##display-environment? (if display? #t #f))
  (##void))

(define-prim (##step-handler leapable? $code rte execute-body . other)
  (##declare (not interrupts-enabled) (environment-map))
  (##step-off) ;; turn off single-stepping
  (##step-handler-continue
   (##step-handler-get-command $code rte)
   leapable?
   $code
   rte
   execute-body
   other))

(define-prim (##step-handler-get-command $code rte)
  (##repl
   (lambda (first output-port)
     (##display-situation
      "STOPPED"
      (##extract-container $code rte)
      (##code-locat $code)
      output-port)
     (##newline output-port)
     #f)))

(define-prim (##step-handler-continue cmd leapable? $code rte execute-body other)

  ;; cmd is one of the symbols "c", "s" or "l" or a one element vector

  (define (execute)
    (##apply execute-body (##cons $code (##cons rte other))))

  (cond ((##eq? cmd 'c)
         (execute))
        ((and (##eq? cmd 'l) leapable?)
         (##trace-generate (##decomp $code) execute #t))
        ((or (##eq? cmd 'l) (##eq? cmd 's))
         (##step-on)
         (##trace-generate (##decomp $code) execute #f))
        (else
         (##vector-ref cmd 0))))

(define-prim (##for-each-interp-procedure prim args fn procs)
  (let loop ((lst1 procs) (lst2 '()) (arg-num 1))
    (if (##pair? lst1)
      (let ((proc (##car lst1)))
        (if (##procedure? proc)
          (if (##interp-procedure? proc)
            (loop (##cdr lst1)
                  (##cons proc lst2)
                  (##fixnum.+ arg-num 1))
            (let ((id (##object->global-var->identifier proc)))
              (if id ;; procedure is bound to a global variable
                (begin
                  (##repl
                   (lambda (first output-port)
                     (##write-string
                      "*** WARNING -- Rebinding global variable \""
                      output-port)
                     (##write id output-port)
                     (##write-string
                      "\" to an interpreted procedure\n"
                      output-port)
                     #t))
                  (let ((new-proc
                         (##make-interp-procedure proc)))
                    (##global-var-set! (##make-global-var id) new-proc)
                    (loop (##cdr lst1)
                          (##cons new-proc lst2)
                          (##fixnum.+ arg-num 1))))
                (##fail-check-interpreted-procedure arg-num '() prim args))))
          (##fail-check-interpreted-procedure arg-num '() prim args)))
      (begin
        (##for-each fn (##reverse lst2))
        (##void)))))

(define-fail-check-type interpreted-procedure 'interpreted-procedure)

(define-prim ##interp-procedure-wrapper
  (macro-make-cprc ;; this is never actually called to evaluate code
   (letrec ((proc
             (lambda args

               (define (execute)
                 (let (($code $code)
                       (rte (macro-make-rte rte proc args)))
;;;*********                   (break-if-stepping-level>= 0)
                   (##apply (^ 1) args)))

               (let ((entry-hook (^ 0)))
                 (if entry-hook
                   (entry-hook
                    proc
                    args
                    (lambda () (execute)))
                   (execute))))))
     proc)))

(define-prim (##make-interp-procedure proc)
  (let* ((cte
          (##cte-frame (##make-top-cte)
                       (##cons (macro-self-var) '(arguments))))
         (src
          #f)
         (stepper
          (##current-stepper))
         ($code
          (macro-make-code ##interp-procedure-wrapper cte src stepper ()
            #f
            proc))
         (rte
          #f))
    (##interp-procedure-wrapper $code rte)))

(define-prim (##remove elem lst)
  (let loop ((lst1 lst) (lst2 '()))
    (if (##pair? lst1)
      (let ((x (##car lst1)))
        (if (##eq? x elem)
          (##append (##reverse lst2) (##cdr lst1))
          (loop (##cdr lst1) (##cons x lst2))))
      lst)))

;;;============================================================================

;;; Read eval print loop channels.

(implement-type-repl-channel)

(define-prim (##thread-repl-channel-get! thread)
  (or (macro-thread-repl-channel thread)
      (let ((repl-channel
             (##thread-make-repl-channel)))
        (macro-thread-repl-channel-set! thread repl-channel)
        (macro-thread-repl-channel thread))))

(define ##thread-make-repl-channel #f)
(set! ##thread-make-repl-channel
  (lambda ()
    ##stdio/console-repl-channel))

(define ##stdio/console-repl-channel
  (let* ((settings
          (##set-debug-settings! 0 0))
         (x
          (##fixnum.arithmetic-shift-right
           (##fixnum.bitwise-and
            settings
            (macro-debug-settings-repl-mask))
           (macro-debug-settings-repl-shift))))
    (cond ((##fixnum.= x (macro-debug-settings-repl-stdio))
           (##make-repl-channel-ports ##stdin-port ##stdout-port))
          (else
           (##make-repl-channel-ports ##console-port ##console-port)))))

(define-prim (##repl-input-port)
  (let* ((ct (macro-current-thread))
         (channel (##thread-repl-channel-get! ct)))
    (macro-repl-channel-input-port channel)))

(define-prim (repl-input-port)
  (##repl-input-port))

(define-prim (##repl-output-port)
  (let* ((ct (macro-current-thread))
         (channel (##thread-repl-channel-get! ct)))
    (macro-repl-channel-output-port channel)))

(define-prim (repl-output-port)
  (##repl-output-port))

(define-prim (##repl-channel-acquire-ownership!)
  (let* ((ct (macro-current-thread))
         (channel (##thread-repl-channel-get! ct)))
    (macro-mutex-lock! (macro-repl-channel-owner-mutex channel) #f ct)
    (if (##not (##eq? (macro-repl-channel-last-owner channel) ct))
      (begin
        (macro-repl-channel-last-owner-set! channel ct)
        (##repl-channel-display-monoline-message
         (lambda (output-port)
           (##write-string "------------- REPL is now in " output-port)
           (##write ct output-port)
           (##write-string " -------------" output-port)))
        #t)
      #f)))

(define-prim (##repl-channel-release-ownership!)
  (let ((channel (##thread-repl-channel-get! (macro-current-thread))))
    (macro-mutex-unlock! (macro-repl-channel-owner-mutex channel))))

(define-prim (##repl-channel-input-port)
  (let ((channel (##thread-repl-channel-get! (macro-current-thread))))
    (macro-repl-channel-input-port channel)))

(define-prim (##repl-channel-output-port)
  (let ((channel (##thread-repl-channel-get! (macro-current-thread))))
    (macro-repl-channel-output-port channel)))

(define-prim (##repl-channel-read-command level depth)
  (let ((channel (##thread-repl-channel-get! (macro-current-thread))))
    ((macro-repl-channel-read-command channel) channel level depth)))

(define-prim (##repl-channel-write-results results)
  (let ((channel (##thread-repl-channel-get! (macro-current-thread))))
    ((macro-repl-channel-write-results channel) channel results)))

(define-prim (##repl-channel-display-monoline-message writer)
  (let ((channel (##thread-repl-channel-get! (macro-current-thread))))
    ((macro-repl-channel-display-monoline-message channel) channel writer)))

(define-prim (##repl-channel-display-multiline-message writer)
  (let ((channel (##thread-repl-channel-get! (macro-current-thread))))
    ((macro-repl-channel-display-multiline-message channel) channel writer)))

(define-prim (##repl-channel-display-continuation cont depth)
  (let ((channel (##thread-repl-channel-get! (macro-current-thread))))
    ((macro-repl-channel-display-continuation channel) channel cont depth)))

(define-prim (##repl-channel-pinpoint-continuation cont)
  (let ((channel (##thread-repl-channel-get! (macro-current-thread))))
    ((macro-repl-channel-pinpoint-continuation channel) channel cont)))

(define-prim (##repl-channel-really-exit?)
  (let ((channel (##thread-repl-channel-get! (macro-current-thread))))
    ((macro-repl-channel-really-exit? channel) channel)))

(define-prim (##repl-channel-newline)
  (let ((channel (##thread-repl-channel-get! (macro-current-thread))))
    ((macro-repl-channel-newline channel) channel)))

(implement-type-repl-channel-ports)

(define-prim (##make-repl-channel-ports input-port output-port)
  (macro-make-repl-channel-ports

   (##make-mutex #f)
   (macro-current-thread)
   input-port
   output-port

   (lambda (channel level depth) ;; read-command

     (define prompt "> ")

     (let ((output-port (macro-repl-channel-output-port channel)))
       (if (##fixnum.< 0 level)
         (##write level output-port))
       (if (##fixnum.< 0 depth)
         (begin
           (##write-string "\\" output-port)
           (##write depth output-port)))
       (##write-string prompt output-port)
       (##force-output output-port))

     (let ((input-port (macro-repl-channel-input-port channel))
           (output-port (macro-repl-channel-output-port channel)))
       (let ((result (##read-expr-from-port input-port)))
         (##output-port-column-set! output-port 1)
         result)))

   (lambda (channel results) ;; write-results
     (let ((output-port (macro-repl-channel-output-port channel)))
       (##for-each
        (lambda (obj)
          (if (##not (##eq? obj (##void)))
            (##pretty-print obj output-port)))
        results)))

   (lambda (channel writer) ;; display-monoline-message
     (let ((output-port (macro-repl-channel-output-port channel)))
       (writer output-port)
       (##newline output-port)))

   (lambda (channel writer) ;; display-multiline-message
     (let ((output-port (macro-repl-channel-output-port channel)))
       (writer output-port)))

   (lambda (channel cont depth) ;; display-continuation
     (if ##display-environment?
       (##repl-channel-display-multiline-message
        (lambda (output-port)
          (##cmd-e cont output-port)))))

   (lambda (channel cont) ;; pinpoint-continuation
     #f)

   (lambda (channel) ;; really-exit?
     (let ((input-port (macro-repl-channel-input-port channel))
           (output-port (macro-repl-channel-output-port channel)))
       (##write-string "*** EOF again to exit" output-port)
       (##newline output-port)
       (##force-output output-port)
       (##not (##char? (##peek-char input-port)))))

   (lambda (channel) ;; newline
     (let ((output-port (macro-repl-channel-output-port channel)))
       (##newline output-port)))))

;;;============================================================================

;;; Read eval print loop.

;;;----------------------------------------------------------------------------

;;; Evaluation within a specific continuation.

(implement-type-repl-context)

(define-prim (##thread-repl-context-get!)
  (or (macro-current-repl-context)
      (let ((repl-context
             (##make-initial-repl-context)))
        (macro-current-repl-context-set! repl-context)
        (macro-current-repl-context))))

(define-prim (##make-initial-repl-context)
  (macro-make-repl-context -1 0 #f #f #f #f))

(define-prim (##repl #!optional (write-reason #f))
  (##continuation-capture
   (lambda (cont)
     (##repl-within cont write-reason))))

(define-prim (##repl-debug #!optional (write-reason #f) (no-result? #f))
  (let* ((old-setting
          (##set-debug-settings!
           (macro-debug-settings-error-mask)
           (macro-debug-settings-error-repl)))
         (results
          (if no-result?
            (##with-no-result-expected (lambda () (##repl write-reason)))
            (##repl write-reason))))
    (##set-debug-settings!
     (macro-debug-settings-error-mask)
     old-setting)
    results))

(define-prim (##repl-debug-main)

  (##current-input-port (##repl-input-port))
  (##current-output-port (##repl-output-port))
  (##current-error-port (##repl-output-port))

  (##repl-debug
   (lambda (first output-port)

     (##define-macro (attrs kind)

       (define style-normal    0)
       (define style-bold      1)
       (define style-underline 2)
       (define style-reverse   4)

       (define color-black   0)
       (define color-red     1)
       (define color-green   2)
       (define color-yellow  3)
       (define color-blue    4)
       (define color-magenta 5)
       (define color-cyan    6)
       (define color-white   7)
       (define default-color 8)

       (define (make-text-attr style fg bg)
         (+ (* style 256) fg (* bg 16)))

       (case kind
         ((banner)
          (make-text-attr style-bold   default-color color-cyan))
         ((input)
          (make-text-attr style-bold   default-color default-color))
         (else
          (make-text-attr style-normal default-color default-color))))

     (if (##tty? output-port)
       (##tty-text-attributes-set! output-port (attrs input) (attrs banner)))

     (##write-string "Gambit " output-port)
     (##write-string (##system-version-string) output-port)

     (if (##tty? output-port)
       (##tty-text-attributes-set! output-port (attrs input) (attrs output)))

     (##newline output-port)
     (##newline output-port)
     #f)
   #t)

  (##exit))

(define-prim (##repl-within cont write-reason)

  (define (with-clean-exception-handling repl-context thunk)
    (##with-exception-catcher
     (lambda (exc)
       (##continuation-graft-with-winding ;; get rid of any useless continuation frames
        (macro-repl-context-cont repl-context)
        (lambda ()
          (release-ownership!)
          (macro-raise exc))))
     thunk))

  (define (acquire-ownership!)
    (##repl-channel-acquire-ownership!))

  (define (release-ownership!)
    (##repl-channel-release-ownership!))

  (define (display-continuation repl-context)
    (##repl-channel-display-continuation
     (first-interesting
      (macro-repl-context-cont repl-context))
     (macro-repl-context-depth repl-context)))

  (define (first-interesting cont)
    (##continuation-first-interesting cont))

  (define (restart repl-context)
    (restart-exec
     repl-context
     (lambda ()
       (display-continuation repl-context))))

  (define (restart-pinpointing-continuation show-frame? repl-context)
    (restart-exec
     repl-context
     (lambda ()
       (let ((cont
              (first-interesting
               (macro-repl-context-cont repl-context))))
         (if (and (##not (##repl-channel-pinpoint-continuation cont))
                  show-frame?)
           (##repl-channel-display-multiline-message
            (lambda (output-port)
              (##cmd-y (macro-repl-context-depth repl-context)
                       cont
                       #t
                       output-port))))
         (display-continuation repl-context)))))

  (define (restart-exec repl-context thunk)
    (##continuation-graft-with-winding ;; get rid of any useless continuation frames
     (macro-repl-context-cont repl-context)
     (lambda ()
       (with-clean-exception-handling
        repl-context
        (lambda ()
          (##parameterize
           ##current-user-interrupt-handler
           (lambda ()
             #f) ;; ignore user interrupts
           (lambda ()
             (macro-dynamic-bind repl-context
              repl-context
              (lambda ()
                (thunk)
                (prompt repl-context))))))))))

  (define (prompt repl-context)

    (define (cont-in-step-handler?)
      (##eq? (##continuation-parent (macro-repl-context-cont repl-context))
             ##step-handler))

    (define (cont-in-with-no-result-expected?)
      (##eq? (##continuation-parent (macro-repl-context-cont repl-context))
             ##with-no-result-expected))

    (define (continue)
      (prompt repl-context))

    (define (read-command)
      (let ((src
             (##repl-channel-read-command
              (macro-repl-context-level repl-context)
              (macro-repl-context-depth repl-context))))
        (cond ((##eof-object? src)
               src)
              (else
               (let ((code (##source-code src)))
                 (if (and (##pair? code)
                          (##eq? (##source-code (##car code)) 'six.prefix))
                   (let ((rest (##cdr code)))
                     (if (and (##pair? rest)
                              (##null? (##cdr rest)))
                       (##car rest)
                       src))
                   src))))))

    (define (write-results results)
      (##repl-channel-write-results results))

    (define (goto-depth n)
      (let loop ((context repl-context))
        (let ((depth (macro-repl-context-depth context)))
          (cond ((##fixnum.< n depth)
                 (let ((prev-depth (macro-repl-context-prev-depth context)))
                   (if prev-depth
                     (loop prev-depth)
                     (restart-pinpointing-continuation #t context))))
                ((##fixnum.< depth n)
                 (let* ((cont
                         (first-interesting (macro-repl-context-cont context)))
                        (next
                         (##continuation-next-interesting cont)))
                   (if next
                     (loop (macro-make-repl-context
                            (macro-repl-context-level context)
                            (##fixnum.+ depth 1)
                            next
                            (macro-repl-context-initial-cont context)
                            (macro-repl-context-prev-level context)
                            context))
                     (restart-pinpointing-continuation #t context))))
                (else
                 (restart-pinpointing-continuation #t context))))))

    (define (quit)
      (release-ownership!)
      (##continuation-graft-with-winding
       (macro-repl-context-cont repl-context)
       (lambda ()
         (##thread-terminate! (macro-current-thread)))))

    (define (return results)
      (release-ownership!)
      (##continuation-return-with-winding
       (macro-repl-context-cont repl-context)
       results))

    (define (cmd-d)
      (if (##fixnum.< 0 (macro-repl-context-level repl-context))
        (restart (macro-repl-context-prev-level repl-context))))

    (define (cmd-t)
      (let loop ((context repl-context))
        (if (##fixnum.< 0 (macro-repl-context-level context))
          (loop (macro-repl-context-prev-level context))
          (restart context))))

    (##step-off) ;; turn off single-stepping

    (let ((src (read-command)))

      (define (unknown-command)
        (##repl-channel-display-monoline-message
         (lambda (output-port)
           (##write (##desourcify src) output-port)
           (##write-string " is an unknown command" output-port))))

      (define (invalid-command message)
        (##repl-channel-display-monoline-message
         (lambda (output-port)
           (##write-string message output-port))))

      (define (eval-print src)
        (release-ownership!)
        (##continuation-capture
         (lambda (return)
           (##eval-within
            src
            (macro-repl-context-cont repl-context)
            repl-context
            (lambda (results)
              (##call-with-values
               (lambda ()
                 results)
               (lambda results
                 (write-results results)
                 (##continuation-return-with-winding return #f)))))))
        (acquire-ownership!))

      (cond ((##eof-object? src)
             (##repl-channel-newline)
             (cmd-d)
             (if (##repl-channel-really-exit?)
               (quit))
             (continue))
            (else
             (let ((code (##source-code src)))
               (if (and (##pair? code)
                        (##eq? (##source-code (##car code)) 'unquote)
                        (##pair? (##cdr code))
                        (##null? (##cddr code)))
                 (let* ((cmd-src (##cadr code))
                        (cmd (##source-code cmd-src)))
                   (cond
                     ((##eq? cmd '?)
                      (##repl-channel-display-multiline-message ##cmd-?)
                      (continue))
                     ((##eq? cmd '-)
                      (goto-depth
                       (##fixnum.- (macro-repl-context-depth repl-context) 1)))
                     ((##eq? cmd '+)
                      (goto-depth
                       (##fixnum.+ (macro-repl-context-depth repl-context) 1)))
                     ((##eq? cmd 'b)
                      (##repl-channel-display-multiline-message
                       (lambda (output-port)
                         (##cmd-b (macro-repl-context-depth repl-context)
                                  (first-interesting
                                   (macro-repl-context-cont repl-context))
                                  output-port)))
                      (continue))
                     ((##eq? cmd 'i)
                      (##repl-channel-display-multiline-message
                       (lambda (output-port)
                         (##cmd-i (first-interesting
                                   (macro-repl-context-cont repl-context))
                                  output-port)))
                      (continue))
                     ((##eq? cmd 'y)
                      (##repl-channel-display-multiline-message
                       (lambda (output-port)
                         (##cmd-y (macro-repl-context-depth repl-context)
                                  (first-interesting
                                   (macro-repl-context-cont repl-context))
                                  #t
                                  output-port)))
                      (continue))
                     ((##eq? cmd 'e)
                      (##repl-channel-display-multiline-message
                       (lambda (output-port)
                         (##cmd-e (first-interesting
                                   (macro-repl-context-cont repl-context))
                                  output-port)))
                      (continue))
                     ((##eq? cmd 't)
                      (cmd-t))
                     ((##eq? cmd 'd)
                      (cmd-d)
                      (continue))
                     ((##eq? cmd 'q)
                      (quit))
                     ((and (##fixnum? cmd)
                           (##not (##fixnum.< cmd 0)))
                      (goto-depth cmd))
                     ((or (##eq? cmd 'c) (##eq? cmd 's) (##eq? cmd 'l))
                      (if (or (cont-in-step-handler?)
                              (cont-in-with-no-result-expected?))
                        (return cmd)
                        (begin
                          (invalid-command
                           "Continuation expects a result -- use ,(c <expr>) or ,(s <expr>) or ,(l <expr>)")
                          (continue))))
                     ((and (##pair? cmd)
                           (##pair? (##cdr cmd))
                           (##null? (##cddr cmd)))
                      (let* ((cmd2-src (##car cmd))
                             (cmd2 (##source-code cmd2-src)))
                        (cond
                         ((or (##eq? cmd2 'c) (##eq? cmd2 's) (##eq? cmd2 'l))
                          (if (cont-in-with-no-result-expected?)
                            (begin
                              (invalid-command
                               "Continuation expects no result -- use ,c or ,s or ,l")
                              (continue))
                            (let ((src (##cadr cmd)))
                              (release-ownership!)
                              (##eval-within
                               src
                               (macro-repl-context-cont repl-context)
                               #f
                               (if (cont-in-step-handler?)
                                 (lambda (results)
                                   (acquire-ownership!)
                                   (return (##vector results)))
                                 (lambda (results)
                                   (acquire-ownership!)
                                   (return results)))))))
                         (else
                          (unknown-command)
                          (continue)))))
                     (else
                      (unknown-command)
                      (continue))))
                 (begin
                   (eval-print src)
                   (continue))))))))

  (let* ((prev-repl-context
          (##thread-repl-context-get!))
         (repl-context
          (macro-make-repl-context
           (##fixnum.+ (macro-repl-context-level prev-repl-context) 1)
           0
           cont
           cont
           prev-repl-context
           #f)))

    (acquire-ownership!)
    (if (and (##procedure? write-reason)
             (with-clean-exception-handling
              repl-context
              (lambda ()
                (##repl-channel-display-multiline-message
                 (lambda (output-port)
                   (let ((first (first-interesting cont)))
                     (##declare (not safe)) ;; avoid procedure check on the call
                     ;; write-reason returns #f if REPL is to be started
                     (write-reason first output-port)))))))
      (release-ownership!)
      (restart-pinpointing-continuation #f repl-context))))

(define-prim (##eval-within src cont repl-context receiver)

  (define (run c rte)
    (##continuation-graft-with-winding
     cont
     (lambda ()
       (macro-dynamic-bind repl-context
        repl-context
        (lambda ()
          (receiver
           (let ((rte rte))
             (macro-code-run c))))))))

  (if (##interp-continuation? cont)
    (let* (($code (##interp-continuation-code cont))
           (cte (macro-code-cte $code))
           (rte (##interp-continuation-rte cont)))
      (run (##compile-inner cte
                            (##sourcify src (##make-source #f #f)))
           rte))
    (run (##compile-top ##interaction-cte
                        (##sourcify src (##make-source #f #f)))
         #f)))

;;;----------------------------------------------------------------------------

(define-prim (##repl-exception-handler-hook exc other-handler)
  (##declare (not interrupts-enabled))
  (let ((settings (##set-debug-settings! 0 0)))
    (if (and (##not (##eq? (macro-current-thread) (macro-primordial-thread)))
             (##fixnum.= (macro-debug-settings-uncaught-primordial)
                         (macro-debug-settings-uncaught settings)))
      (other-handler exc)
      (##repl
       (lambda (first output-port)
         (let ((quit? (##fixnum.= (macro-debug-settings-error settings)
                                  (macro-debug-settings-error-quit))))
           (if (and quit?
                    (##fixnum.= (macro-debug-settings-level settings) 0))
             (##exit-with-exception exc)
             (begin
               (##display-exception-in-context exc first output-port)
               (if quit?
                 (##exit-with-exception exc)
                 #f)))))))))

(define-prim (##default-user-interrupt-handler)
  (##with-no-result-expected
   (lambda ()
     (##repl
      (lambda (first output-port)
        (let* ((settings (##set-debug-settings! 0 0))
               (quit? (##fixnum.= (macro-debug-settings-error settings)
                                  (macro-debug-settings-error-quit))))
          (if (and quit?
                   (##fixnum.= (macro-debug-settings-level settings) 0))
            (##exit-abnormally)
            (begin
              (##display-situation
               "INTERRUPTED"
               (##continuation-creator first)
               (##continuation-locat first)
               output-port)
              (##newline output-port)
              (if quit?
                (##exit-abnormally)
                #f)))))))))

(set! ##primordial-exception-handler-hook ##repl-exception-handler-hook)

(if (##fixnum.= (macro-debug-settings-error (##set-debug-settings! 0 0))
                (macro-debug-settings-error-single-step))
  (##step-on))

(##current-user-interrupt-handler ##default-user-interrupt-handler)

(define-prim (##exception->kind exc)
  (cond (#f;;;;;;;;;;;;;;
         "INTERRUPT")
        (else
         "ERROR")))

(define-prim (##exception->procedure exc cont)
  (cond ((macro-expression-parsing-exception? exc)
         #f)
        ((macro-datum-parsing-exception? exc)
         #f)
        ((and (macro-nonprocedure-operator-exception? exc)
              (macro-nonprocedure-operator-exception-code exc))
         (##extract-container
          (macro-nonprocedure-operator-exception-code exc)
          (macro-nonprocedure-operator-exception-rte exc)))
        (else
         (##continuation-creator cont))))

(define-prim (##exception->locat exc cont)

  (define (source-loc source)
    (##source-locat source))

  (define (code-loc code)
    (##code-locat code))

  (cond ((macro-expression-parsing-exception? exc)
         (source-loc (macro-expression-parsing-exception-source exc)))
        ((macro-datum-parsing-exception? exc)
         (let ((re (macro-datum-parsing-exception-readenv exc)))
           (##make-locat-from-readenv re)))
        ((and (macro-nonprocedure-operator-exception? exc)
              (macro-nonprocedure-operator-exception-code exc))
         =>
         code-loc)
        (else
         (##continuation-locat cont))))

(define-prim (##display-exception-in-context exc cont port)
  (##display-situation
   (##exception->kind exc)
   (##exception->procedure exc cont)
   (##exception->locat exc cont)
   port)
  (##write-string " -- " port)
  (##display-exception exc port))

(define-prim (##display-situation kind proc locat port)
  (##write-string "*** " port)
  (##write-string kind port)
  (if (or proc locat)
    (##write-string " IN " port))
  (if proc
    (##write (##procedure-name proc) port))
  (if locat
    (begin
      (if proc
        (##write-string ", " port))
      (##display-locat locat #t port))))

(define-prim (##display-exception exc port)

  (define max-displayed-args 15)

  (define (display-call proc args)
    (if proc
      (display-call* proc args)))

  (define (display-call* proc args)
    (let* ((call
            (##make-call-form proc args max-displayed-args))
           (width
            (##output-port-width port))
           (str
            (##object->string call width)))
      (if (##fixnum.< (##string-length str) width)
        (begin
          (##write-string str port)
          (##newline port))
        (let loop ((i 0) (lst call))
          (##write-string (if (##fixnum.= i 0) "(" " ") port)
          (let* ((last?
                  (##null? (##cdr lst)))
                 (w
                  (if last?
                    (##fixnum.- width 3)
                    (##fixnum.- width 2))))
            (##write-string (##object->string (##car lst) w) port)
            (if last?
              (begin
                (##write-string ")" port)
                (##newline port))
              (begin
                (##newline port)
                (loop (##fixnum.+ i 1) (##cdr lst)))))))))

  (define-prim (write-items items)
    (let loop ((lst items))
      (if (##pair? lst)
        (begin
          (##write-string " " port)
          (##write (##car lst) port)
          (loop (##cdr lst))))))

  (define-prim (display-arg-num arg-num)
    (if (##fixnum.< 0 arg-num)
      (begin
        (##write-string "(Argument " port)
        (##write arg-num port)
        (##write-string ") " port))))

  (define-prim (display-exception exc)

    (define (err-code->string code)
      (let ((x (##os-err-code->string code)))
        (if (##string? x)
          x
          "Error code could not be converted to a string")))

    (cond ((macro-abandoned-mutex-exception? exc)
           (##write-string "MUTEX was abandoned" port)
           (##newline port))

          ((macro-sfun-conversion-exception? exc)
           (##write-string
            (or (macro-sfun-conversion-exception-message exc)
                (err-code->string
                 (macro-sfun-conversion-exception-code exc)))
            port)
           (##newline port)
           (display-call
            (macro-sfun-conversion-exception-procedure exc)
            (macro-sfun-conversion-exception-arguments exc)))

          ((macro-cfun-conversion-exception? exc)
           (##write-string
            (or (macro-cfun-conversion-exception-message exc)
                (err-code->string
                 (macro-cfun-conversion-exception-code exc)))
            port)
           (##newline port)
           (display-call
            (macro-cfun-conversion-exception-procedure exc)
            (macro-cfun-conversion-exception-arguments exc)))

          ((macro-datum-parsing-exception? exc)
           (let ((x
                  (##assq (macro-datum-parsing-exception-kind exc)
                          ##datum-parsing-exception-names)))
             (##write-string
              (if x (##cdr x) "Unknown datum parsing exception")
              port))
           (write-items (macro-datum-parsing-exception-parameters exc))
           (##newline port))

          ((macro-deadlock-exception? exc)
           (##write-string "Deadlock detected" port)
           (##newline port))

          ((macro-divide-by-zero-exception? exc)
           (##write-string "Divide by zero" port)
           (##newline port)
           (display-call
            (macro-divide-by-zero-exception-procedure exc)
            (macro-divide-by-zero-exception-arguments exc)))

          ((macro-fixnum-overflow-exception? exc)
           (##write-string "FIXNUM overflow" port)
           (##newline port)
           (display-call
            (macro-fixnum-overflow-exception-procedure exc)
            (macro-fixnum-overflow-exception-arguments exc)))

          ((macro-error-exception? exc)
           (##display (macro-error-exception-message exc) port)
           (let* ((width
                   (##output-port-width port))
                  (sep
                   " ")
                  (params
                   (##map (lambda (p)
                            (let ((s (##object->truncated-string p width)))
                              (if (##fixnum.= (##string-length s) width)
                                (begin
                                  (set! sep "\n")
                                  (##string->limited-string
                                   s
                                   (##fixnum.- width 1)))
                                s)))
                          (macro-error-exception-parameters exc))))
             (##for-each
              (lambda (param)
                (##write-string sep port)
                (##write-string param port))
              params)
             (##newline port)))

          ((macro-invalid-hash-number-exception? exc)
           (##write-string "Invalid hash number" port)
           (##newline port)
           (display-call
            (macro-invalid-hash-number-exception-procedure exc)
            (macro-invalid-hash-number-exception-arguments exc)))

          ((macro-unbound-table-key-exception? exc)
           (##write-string "Unbound table key" port)
           (##newline port)
           (display-call
            (macro-unbound-table-key-exception-procedure exc)
            (macro-unbound-table-key-exception-arguments exc)))

          ((macro-unbound-serial-number-exception? exc)
           (##write-string "Unbound serial number" port)
           (##newline port)
           (display-call
            (macro-unbound-serial-number-exception-procedure exc)
            (macro-unbound-serial-number-exception-arguments exc)))

          ((macro-unbound-os-environment-variable-exception? exc)
           (##write-string "Unbound OS environment variable" port)
           (##newline port)
           (display-call
            (macro-unbound-os-environment-variable-exception-procedure exc)
            (macro-unbound-os-environment-variable-exception-arguments exc)))

          ((macro-unterminated-process-exception? exc)
           (##write-string "Process not terminated" port)
           (##newline port)
           (display-call
            (macro-unterminated-process-exception-procedure exc)
            (macro-unterminated-process-exception-arguments exc)))

          ((macro-nonempty-input-port-character-buffer-exception? exc)
           (##write-string "Input port character buffer is not empty" port)
           (##newline port)
           (display-call
            (macro-nonempty-input-port-character-buffer-exception-procedure exc)
            (macro-nonempty-input-port-character-buffer-exception-arguments exc)))

          ((macro-expression-parsing-exception? exc)
           (let ((x
                  (##assq (macro-expression-parsing-exception-kind exc)
                          ##expression-parsing-exception-names)))
             (##write-string
              (if x (##cdr x) "Unknown expression parsing exception")
              port))
           (write-items (macro-expression-parsing-exception-parameters exc))
           (##newline port)
           (let* ((source (macro-expression-parsing-exception-source exc))
                  (locat (##source-locat source)))
             (if (##not locat)
               (##pretty-print (##desourcify source) port))))

          ((macro-heap-overflow-exception? exc)
           (##write-string "Heap overflow" port)
           (##newline port))

          ((macro-improper-length-list-exception? exc)
           (display-arg-num (macro-improper-length-list-exception-arg-num exc))
           (##write-string "List is not of proper length" port)
           (##newline port)
           (display-call
            (macro-improper-length-list-exception-procedure exc)
            (macro-improper-length-list-exception-arguments exc)))

          ((macro-join-timeout-exception? exc)
           (##write-string "'thread-join!' timed out" port)
           (##newline port)
           (display-call
            (macro-join-timeout-exception-procedure exc)
            (macro-join-timeout-exception-arguments exc)))

          ((macro-mailbox-receive-timeout-exception? exc)
           (##write-string "mailbox receive timed out" port)
           (##newline port)
           (display-call
            (macro-mailbox-receive-timeout-exception-procedure exc)
            (macro-mailbox-receive-timeout-exception-arguments exc)))

          ((macro-keyword-expected-exception? exc)
           (##write-string
            "Keyword argument expected"
            port)
           (##newline port)
           (display-call
            (macro-keyword-expected-exception-procedure exc)
            (macro-keyword-expected-exception-arguments exc)))

          ((macro-multiple-c-return-exception? exc)
           (##write-string
            "Attempt to return to a C function that has already returned"
            port)
           (##newline port))

          ((macro-noncontinuable-exception? exc)
           (##write-string "Computation cannot be continued" port)
           (##newline port))

          ((macro-nonprocedure-operator-exception? exc)
           (##write-string
            "Operator is not a PROCEDURE"
            port)
           (##newline port)
           (display-call*
            (##inverse-eval
             (macro-nonprocedure-operator-exception-operator exc))
            (macro-nonprocedure-operator-exception-arguments exc)))

          ((macro-number-of-arguments-limit-exception? exc)
           (##write-string
            "Number of arguments exceeds implementation limit"
            port)
           (##newline port)
           (display-call
            (macro-number-of-arguments-limit-exception-procedure exc)
            (macro-number-of-arguments-limit-exception-arguments exc)))

          ((macro-os-exception? exc)
           (let ((message (macro-os-exception-message exc))
                 (code (macro-os-exception-code exc)))
             (##write-string
              (or message
                  (if code (err-code->string code) "Unknown OS exception"))
              port))
           (##newline port)
           (display-call
            (macro-os-exception-procedure exc)
            (macro-os-exception-arguments exc)))

          ((macro-no-such-file-or-directory-exception? exc)
           (##write-string "No such file or directory" port)
           (##newline port)
           (display-call
            (macro-no-such-file-or-directory-exception-procedure exc)
            (macro-no-such-file-or-directory-exception-arguments exc)))

          ((macro-range-exception? exc)
           (display-arg-num (macro-range-exception-arg-num exc))
           (##write-string "Out of range" port)
           (##newline port)
           (display-call
            (macro-range-exception-procedure exc)
            (macro-range-exception-arguments exc)))

          ((macro-scheduler-exception? exc)
           (##write-string "Scheduler reported the exception: " port)
           (##write (macro-scheduler-exception-reason exc) port)
           (##newline port))

          ((macro-stack-overflow-exception? exc)
           (##write-string "Stack overflow" port)
           (##newline port))

          ((macro-initialized-thread-exception? exc)
           (##write-string "Thread is initialized" port)
           (##newline port)
           (display-call
            (macro-initialized-thread-exception-procedure exc)
            (macro-initialized-thread-exception-arguments exc)))

          ((macro-uninitialized-thread-exception? exc)
           (##write-string "Thread is not initialized" port)
           (##newline port)
           (display-call
            (macro-uninitialized-thread-exception-procedure exc)
            (macro-uninitialized-thread-exception-arguments exc)))

          ((macro-started-thread-exception? exc)
           (##write-string "Thread is started" port)
           (##newline port)
           (display-call
            (macro-started-thread-exception-procedure exc)
            (macro-started-thread-exception-arguments exc)))

          ((macro-terminated-thread-exception? exc)
           (##write-string "Thread is terminated" port)
           (##newline port)
           (display-call
            (macro-terminated-thread-exception-procedure exc)
            (macro-terminated-thread-exception-arguments exc)))

          ((macro-type-exception? exc)
           (display-arg-num (macro-type-exception-arg-num exc))
           (let ((type-id
                  (macro-type-exception-type-id exc)))
             (if (##type? type-id)
               (begin
                 (##write-string "Instance of " port)
                 (##write type-id port))
               (let ((x
                      (##assq (macro-type-exception-type-id exc)
                              ##type-exception-names)))
                 (##write-string (if x (##cdr x) "Unknown type") port))))
           (##write-string " expected" port)
           (##newline port)
           (display-call
            (macro-type-exception-procedure exc)
            (macro-type-exception-arguments exc)))

          ((macro-unbound-global-exception? exc)
           (##write-string "Unbound variable: " port)
           (##write (macro-unbound-global-exception-variable exc) port)
           (##newline port))

          ((macro-uncaught-exception? exc)
           (##write-string "Uncaught exception: " port)
           (##write (macro-uncaught-exception-reason exc) port)
           (##newline port)
           (display-call
            (macro-uncaught-exception-procedure exc)
            (macro-uncaught-exception-arguments exc)))

          ((macro-unknown-keyword-argument-exception? exc)
           (##write-string
            "Unknown keyword argument passed to procedure"
            port)
           (##newline port)
           (display-call
            (macro-unknown-keyword-argument-exception-procedure exc)
            (macro-unknown-keyword-argument-exception-arguments exc)))

          ((macro-wrong-number-of-arguments-exception? exc)
           (##write-string
            "Wrong number of arguments passed to procedure"
            port)
           (##newline port)
           (display-call
            (macro-wrong-number-of-arguments-exception-procedure exc)
            (macro-wrong-number-of-arguments-exception-arguments exc)))

          (else
           (##write-string "This object was raised: " port)
           (##write exc port)
           (##newline port))))

  (display-exception exc))

(define ##type-exception-names #f)
(set! ##type-exception-names
  '(
    ;; from "_kernel.scm":
    (foreign                      . "FOREIGN object")

    ;; from "_system.scm":
    (hash-algorithm               . "HASH ALGORITHM")

    ;; from "_thread.scm":
    (time                         . "TIME object")
    (absrel-time                  . "REAL or TIME object")
    (absrel-time-or-false         . "#f or REAL or TIME object")
    (thread                       . "THREAD")
    (mutex                        . "MUTEX")
    (convar                       . "CONDITION VARIABLE")
    (tgroup                       . "THREAD GROUP")
    (deadlock-exception           . "DEADLOCK-EXCEPTION object")
    (join-timeout-exception       . "JOIN-TIMEOUT-EXCEPTION object")
    (mailbox-receive-timeout-exception . "MAILBOX-RECEIVE-TIMEOUT-EXCEPTION object")
    (abandoned-mutex-exception    . "ABANDONED-MUTEX-EXCEPTION object")
    (initialized-thread-exception . "INITIALIZED-THREAD-EXCEPTION object")
    (uninitialized-thread-exception . "UNINITIALIZED-THREAD-EXCEPTION object")
    (started-thread-exception     . "STARTED-THREAD-EXCEPTION object")
    (terminated-thread-exception  . "TERMINATED-THREAD-EXCEPTION object")
    (uncaught-exception           . "UNCAUGHT-EXCEPTION object")
    (scheduler-exception          . "SCHEDULER-EXCEPTION object")
    (noncontinuable-exception     . "NONCONTINUABLE-EXCEPTION object")
    (low-level-exception          . "LOW-LEVEL-EXCEPTION object")

    ;; from "_std.scm":
    (mutable                      . "MUTABLE object")
    (pair                         . "PAIR")
    (pair-list                    . "PAIR LIST")
    (char                         . "CHARACTER")
    (char-list                    . "CHARACTER LIST")
    (string                       . "STRING")
    (string-list                  . "STRING LIST")
    (list                         . "LIST")
    (symbol                       . "SYMBOL")
    (keyword                      . "KEYWORD")
    (vector                       . "VECTOR")
    (s8vector                     . "S8VECTOR")
    (u8vector                     . "U8VECTOR")
    (s16vector                    . "S16VECTOR")
    (u16vector                    . "U16VECTOR")
    (s32vector                    . "S32VECTOR")
    (u32vector                    . "U32VECTOR")
    (s64vector                    . "S64VECTOR")
    (u64vector                    . "U64VECTOR")
    (f32vector                    . "F32VECTOR")
    (f64vector                    . "F64VECTOR")
    (procedure                    . "PROCEDURE")

    ;; from "_num.scm":
    (exact-signed-int8            . "Signed 8 bit exact INTEGER")
    (exact-signed-int8-list       . "Signed 8 bit exact INTEGER LIST")
    (exact-unsigned-int8          . "Unsigned 8 bit exact INTEGER")
    (exact-unsigned-int8-list     . "Unsigned 8 bit exact INTEGER LIST")
    (exact-signed-int16           . "Signed 16 bit exact INTEGER")
    (exact-signed-int16-list      . "Signed 16 bit exact INTEGER LIST")
    (exact-unsigned-int16         . "Unsigned 16 bit exact INTEGER")
    (exact-unsigned-int16-list    . "Unsigned 16 bit exact INTEGER LIST")
    (exact-signed-int32           . "Signed 32 bit exact INTEGER")
    (exact-signed-int32-list      . "Signed 32 bit exact INTEGER LIST")
    (exact-unsigned-int32         . "Unsigned 32 bit exact INTEGER")
    (exact-unsigned-int32-list    . "Unsigned 32 bit exact INTEGER LIST")
    (exact-signed-int64           . "Signed 64 bit exact INTEGER")
    (exact-signed-int64-list      . "Signed 64 bit exact INTEGER LIST")
    (exact-unsigned-int64         . "Unsigned 64 bit exact INTEGER")
    (exact-unsigned-int64-list    . "Unsigned 64 bit exact INTEGER LIST")
    (inexact-real                 . "Inexact REAL")
    (inexact-real-list            . "Inexact REAL LIST")
    (number                       . "NUMBER")
    (real                         . "REAL")
    (finite-real                  . "Finite REAL")
    (rational                     . "RATIONAL")
    (integer                      . "INTEGER")
    (exact-integer                . "Exact INTEGER")
    (fixnum                       . "FIXNUM")
    (flonum                       . "FLONUM")
    (random-source-state          . "RANDOM-SOURCE state")

    ;; from "_nonstd.scm":
    (string-or-nonnegative-fixnum . "STRING or nonnegative fixnum")
    (will                         . "WILL")
    (box                          . "BOX")
    (unterminated-process-exception . "UNTERMINATED-PROCESS-EXCEPTION object")

    ;; from "_io.scm":
    (string-or-ip-address         . "STRING or IP address")
    (settings                     . "Port settings")
    (vector-or-settings           . "VECTOR or port settings")
    (string-or-settings           . "STRING or port settings")
    (u8vector-or-settings         . "U8VECTOR or port settings")
    (exact-integer-or-settings    . "Exact INTEGER or port settings")
    (port                         . "PORT")
    (input-port                   . "INPUT PORT")
    (output-port                  . "OUTPUT PORT")
    (character-input-port         . "Character INPUT PORT")
    (character-output-port        . "Character OUTPUT PORT")
    (byte-input-port              . "Byte INPUT PORT")
    (byte-output-port             . "Byte OUTPUT PORT")
    (device-input-port            . "Device INPUT PORT")
    (device-output-port           . "Device OUTPUT PORT")
    (vector-input-port            . "Vector INPUT PORT")
    (vector-output-port           . "Vector OUTPUT PORT")
    (string-input-port            . "String INPUT PORT")
    (string-output-port           . "String OUTPUT PORT")
    (u8vector-input-port          . "U8vector INPUT PORT")
    (u8vector-output-port         . "U8vector OUTPUT PORT")
    (file-port                    . "File PORT")
    (tty-port                     . "Tty PORT")
    (tcp-client-port              . "Tcp client PORT")
    (tcp-server-port              . "Tcp server PORT")
    (pipe-port                    . "Pipe PORT")
    (serial-port                  . "Serial PORT")
    (directory-port               . "Directory PORT")
    (event-queue-port             . "Event-queue PORT")
    (timer-port                   . "Timer PORT")
    (readtable                    . "READTABLE")
    (hostent                      . "HOSTENT")
    (datum-parsing-exception      . "DATUM PARSING EXCEPTION object")

    ;; from "_eval.scm":
    (expression-parsing-exception . "EXPRESSION PARSING EXCEPTION object")

    ;; from "_repl.scm":
    (interpreted-procedure        . "Interpreted PROCEDURE")
   ))

;;;;;;;    (psettings                    . "Invalid port settings")
;;;;;;;    (open-file                    . "Can't open file")


(define ##datum-parsing-exception-names #f)
(set! ##datum-parsing-exception-names
  '(
    (datum-or-eof-expected          . "Datum or EOF expected")
    (datum-expected                 . "Datum expected")
    (improperly-placed-dot          . "Improperly placed dot")
    (incomplete-form-eof-reached    . "Incomplete form, EOF reached")
    (incomplete-form                . "Incomplete form")
    (character-out-of-range         . "Character out of range")
    (invalid-character-name         . "Invalid '#\\' name:")
    (illegal-character              . "Illegal character:")
    (s8-expected                    . "Signed 8 bit exact integer expected")
    (u8-expected                    . "Unsigned 8 bit exact integer expected")
    (s16-expected                   . "Signed 16 bit exact integer expected")
    (u16-expected                   . "Unsigned 16 bit exact integer expected")
    (s32-expected                   . "Signed 32 bit exact integer expected")
    (u32-expected                   . "Unsigned 32 bit exact integer expected")
    (s64-expected                   . "Signed 64 bit exact integer expected")
    (u64-expected                   . "Unsigned 64 bit exact integer expected")
    (inexact-real-expected          . "Inexact real expected")
    (invalid-hex-escape             . "Invalid hexadecimal escape")
    (invalid-escaped-character      . "Invalid escaped character:")
    (open-paren-expected            . "'(' expected")
    (invalid-token                  . "Invalid token")
    (invalid-sharp-bang-name        . "Invalid '#!' name:")
    (duplicate-label-definition     . "Duplicate definition for label:")
    (missing-label-definition       . "Missing definition for label:")
    (illegal-label-definition       . "Illegal definition of label:")
    (invalid-infix-syntax-character . "Invalid infix syntax character")
    (invalid-infix-syntax-number    . "Invalid infix syntax number")
    (invalid-infix-syntax           . "Invalid infix syntax")
   ))

(define ##expression-parsing-exception-names #f)
(set! ##expression-parsing-exception-names
  '(
    (id-expected                      . "Identifier expected")
    (invalid-module-name              . "Invalid module name")
    (ill-formed-namespace             . "Ill-formed namespace")
    (ill-formed-namespace-prefix      . "Ill-formed namespace prefix")
    (namespace-prefix-must-be-string  . "Namespace prefix must be a string")
    (macro-used-as-variable           . "Macro name can't be used as a variable:")
    (ill-formed-macro-transformer     . "Macro transformer must be a lambda expression")
    (reserved-used-as-variable        . "Reserved identifier can't be used as a variable:")
    (ill-formed-special-form          . "Ill-formed special form:")
    (cannot-open-file                 . "Can't open file")
    (filename-expected                . "Filename expected")
    (ill-placed-define                . "Ill-placed 'define'")
    (ill-placed-include               . "Ill-placed 'include'")
    (ill-placed-define-macro          . "Ill-placed 'define-macro'")
    (ill-placed-define-syntax         . "Ill-placed 'define-syntax'")
    (ill-placed-declare               . "Ill-placed 'declare'")
    (ill-placed-namespace             . "Ill-placed 'namespace'")
;;    (ill-placed-library               . "Ill-placed 'library'")
;;    (ill-placed-export                . "Ill-placed 'export'")
;;    (ill-placed-import                . "Ill-placed 'import'")
    (unknown-location                 . "Unknown location")
    (ill-formed-expression            . "Ill-formed expression")
    (unsupported-special-form         . "Interpreter does not support")
    (parameter-must-be-id             . "Parameter must be an identifier")
    (parameter-must-be-id-or-default  . "Parameter must be an identifier or default binding")
    (duplicate-parameter              . "Duplicate parameter in parameter list")
    (duplicate-rest-parameter         . "Duplicate rest parameter in parameter list")
    (parameter-expected-after-rest    . "#!rest must be followed by a parameter")
    (rest-parm-must-be-last           . "Rest parameter must be last")
    (ill-formed-default               . "Ill-formed default binding")
    (ill-placed-optional              . "Ill-placed #!optional")
    (ill-placed-key                   . "Ill-placed #!key")
    (key-expected-after-rest          . "#!key expected after rest parameter")
    (ill-placed-default               . "Ill-placed default binding")
    (duplicate-variable-definition    . "Duplicate definition of a variable")
    (empty-body                       . "Body must contain at least one expression")
    (else-clause-not-last             . "Else clause must be last")
    (ill-formed-selector-list         . "Ill-formed selector list")
    (duplicate-variable-binding       . "Duplicate variable in bindings")
    (ill-formed-binding-list          . "Ill-formed binding list")
    (ill-formed-call                  . "Ill-formed procedure call")
    (ill-formed-cond-expand           . "Ill-formed 'cond-expand'")
    (unfulfilled-cond-expand          . "Unfulfilled 'cond-expand'")
   ))

;;;----------------------------------------------------------------------------

(define-runtime-macro (time expr)
  `(##time (lambda () ,expr) ',expr))

(define-prim (##time thunk expr)
  (let ((at-start (##process-statistics)))
    (let ((result (thunk)))
      (let ((at-end (##process-statistics)))

        (define (secs->msecs x)
          (##inexact->exact (##round (##* x 1000))))

        (##repl
         (lambda (first output-port)
           (let* ((user-time
                   (secs->msecs
                    (##- (##f64vector-ref at-end 0)
                         (##f64vector-ref at-start 0))))
                  (sys-time
                   (secs->msecs
                    (##- (##f64vector-ref at-end 1)
                         (##f64vector-ref at-start 1))))
                  (cpu-time
                   (##+ user-time sys-time))
                  (real-time
                   (secs->msecs
                    (##- (##f64vector-ref at-end 2)
                         (##f64vector-ref at-start 2))))
                  (gc-user-time
                   (secs->msecs
                    (##- (##f64vector-ref at-end 3)
                         (##f64vector-ref at-start 3))))
                  (gc-sys-time
                   (secs->msecs
                    (##- (##f64vector-ref at-end 4)
                         (##f64vector-ref at-start 4))))
                  (gc-real-time
                   (secs->msecs
                    (##- (##f64vector-ref at-end 5)
                         (##f64vector-ref at-start 5))))
                  (nb-gcs
                   (##flonum.->exact-int
                    (##- (##f64vector-ref at-end 6)
                         (##f64vector-ref at-start 6))))
                  (minflt
                   (##flonum.->exact-int
                    (##- (##f64vector-ref at-end 10)
                         (##f64vector-ref at-start 10))))
                  (majflt
                   (##flonum.->exact-int
                    (##- (##f64vector-ref at-end 11)
                         (##f64vector-ref at-start 11))))
                  (bytes-allocated
                   (##flonum.->exact-int
                    (##- (##- (##f64vector-ref at-end 7)
                              (##f64vector-ref at-start 7))
                         (##+ (if (##interp-procedure? thunk)
                                (##f64vector-ref at-end 8) ;; thunk call frame space
                                (macro-inexact-+0))
                              (##f64vector-ref at-end 9)))))) ;; at-end structure space

             (define (pluralize n msg)
               (##write-string "    " output-port)
               (if (##= n 0)
                 (##write-string "no" output-port)
                 (##write n output-port))
               (##write-string msg output-port)
               (if (##not (##= n 1))
                 (##write-string "s" output-port)))

             (##write (##list 'time expr) output-port)
             (##newline output-port)

             (##write-string "    " output-port)
             (##write real-time output-port)
             (##write-string " ms real time" output-port)
             (##newline output-port)

             (##write-string "    " output-port)
             (##write cpu-time output-port)
             (##write-string " ms cpu time (" output-port)
             (##write user-time output-port)
             (##write-string " user, " output-port)
             (##write sys-time output-port)
             (##write-string " system)" output-port)
             (##newline output-port)

             (pluralize nb-gcs " collection")
             (if (##not (##= nb-gcs 0))
               (begin
                 (##write-string " accounting for " output-port)
                 (##write gc-real-time output-port)
                 (##write-string " ms real time (" output-port)
                 (##write gc-user-time output-port)
                 (##write-string " user, " output-port)
                 (##write gc-sys-time output-port)
                 (##write-string " system)" output-port)))
             (##newline output-port)

             (pluralize bytes-allocated " byte")
             (##write-string " allocated" output-port)
             (##newline output-port)

             (pluralize minflt " minor fault")
             (##newline output-port)

             (pluralize majflt " major fault")
             (##newline output-port)

             #t)))

        result))))

;;;============================================================================