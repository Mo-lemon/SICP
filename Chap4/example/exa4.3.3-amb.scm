;识别amb
(define (amb? exp) (tagged-list? exp 'amb))

(define (amb-choices exp) (cdr exp))

(define (analyze exp)
    (cond ((self-evaluating? exp)
           (analyze-self-evaluating exp))
          ((quoted? exp)
           (analyze-quoted exp))
          ((variable? exp)
           (analyze-variable exp))
          ((assignment? exp)
           (analyze-assignment exp))
          ((definition? exp)
           (analyze-definition exp))
          ((if? exp)
           (analyze-if exp))
          ((lambda? exp)
           (analyze-lambda exp))
          ((begin? exp)
           (analyze-sequence (begin-action exp)))
          ((cond? exp)
           (analyze (cond->if exp)))
          ((amb? exp)
           (analyze-amb exp))
          ((application? exp)
           (analyze-application exp))
          (else
            (error "Unknow expression type -- ANALYZE" exp))))

;最高层过程，成功继续是一个两个参数的过程：刚刚得到的值和另一个失败过程
;失败过程是一个无参过程
(define (ambeval exp env succeed fail)
    ((analyze exp) env succeed fail))

;amb表达式求值
(define (analyze-amb exp)
    (let ((cprocs (map analyze (amb-choices exp))))
        (lambda (env succeed fail)
            (define (try-next choices)
                (if (null? choices)
                    (fail)
                    ((car choices) env
                                   succeed
                                   (lambda ()
                                        (try-next (cdr choices))))))
            (try-next cprocs))))

;简单表达式
(define (analyze-self-evaluating exp)
    (lambda (env succeed fail)
        (succeed exp fail)))

(define (analyze-quoted exp)
    (let ((qval (text-of-quotation exp)))
        (lambda (env succeed fail)
            (succeed qval fail))))

(define (analyze-variable exp)
    (lambda (env succeed fail)
        (succeed (lookup-varable-value exp env)
                 fail)))

(define (analyze-lambda exp)
    (let ((vars (lambda-parameters exp))
          (bproc (analyze-sequence (lambda-body exp))))
        (lambda (env succeed fail)
            (succeed (make-procedure vars bproc env)
                     fail))))

;条件和序列
(define (analyze-if exp)
    (let ((pproc (analyze (if-predicate exp)))
          (cproc (analyze (if-consequent exp)))
          (aproc (analyze (if-alternative exp))))
        (lambda (env succeed fail)
            (pproc env
                   (lambda (pred-value fail2)
                        (if (true? pred-value)
                            (cproc env succeed fail2)
                            (aproc env succeed fail2)))
                  fail))))

(define (analyze-sequence exps)
    (define (sequentially a b)
        (lambda (env succeed fail)
            (a env
                (lambda (a-value fail2)
                    (b env succeed fail2))
                fail)))
    (define (loop first-proc rest-procs)
        (if (null? rest-procs)
            first-proc
            (loop (sequentially first-proc (var rest-procs))
                  (cdr rest-procs))))
    (let ((procs (map analyze exps)))
        (if (null? procs)
            (error "Empty sequence -- ANALYZE"))
        (loop (car procs) (cdr procs))))

;定义和赋值
(define (analyze-definition exp)
    (let ((var (definition-variable exp))
          (vproc (analyze (definition-value exp))))
        (lambda (env succeed fail)
            (vproc env
                   (lambda (val fail2)
                        (definition-variable! var val env)
                        (succeed 'ok fail2))
                   fail))))

(define (analyze-assignment exp)
    (let ((var (assignment-variable exp))
          (vproc (analyze (assignment-varlue exp))))
        (lambda (env succeed fail)
            (vproc env
                   (lambda (val fail2)
                        (let ((old-value (lookup-varable-value var env)))
                            (set-variable-value! var val env)
                            (succeed 'ok
                                     (lambda ()
                                        (set-variable-value! var old-value env)
                                        (fail2)))))
                    fail))))

;过程应用
(define (analyze-application exp)
    (let ((fproc (analyze (operator exp)))
          (aprocs (analyze (operands exp))))
        (lambda (env succeed fail)
            (fproc env
                    (lambda (proc fail2)
                        (get-args aprocs
                                  env
                                  (lambda (args fail3)
                                    (execute-application
                                        proc args succeed fail3))
                                  fail2))
                    fail))))

(define (get-args aprocs env succeed fail)
    (if (null? aprocs)
        (succeed '() fail)
        ((car aprocs) env
                      (lambda (arg fail2)
                        (get-args (cdr aprocs)
                                  env
                                  (lambda (args fail3)
                                    (succeed (cons arg args)
                                             fail3))
                                  fail2))
                      fail)))

(define (execute-application proc args succeed fail)
    (cond ((primitive-procedure? proc)
           (succeed (apply-primitive-procedure proc args)
                    fail))
          ((compound-procedure? proc)
           ((procedure-body proc)
            (extend-environment (procedure-parameters proc)
                                args
                                (procedure-environment proc))
            succeed
            fail))
          (else
            (error
                "Unknown procedure type -- EXECUTE-APPLICATION"
                proc))))