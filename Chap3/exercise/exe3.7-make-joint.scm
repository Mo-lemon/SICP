;双密码机制
(define (make-account balance pswd)
    (define (withdraw amount)
        (if (>= balance amount)
            (begin (set! balance (- balance amount))
                   balance)
            "Insufficient funds"))
    (define (deposit amount)
        (set! balance (+ balance amount))
        balance)
    (lambda (x y)
            (if (eq? x pswd)
                (cond ((eq? y 'withdraw) withdraw)
                      ((eq? y 'deposit) deposit)
                      (else (error "Unknown request -- MAKE-ACCOUNT" y)))
                (lambda (m) "Incorrect password"))))

(define (make-joint account old-pwd new-pwd)
    (lambda (x y)
        (if (eq? x new-pwd)
            (account old-pwd y)
            (lambda (m) "Incorrect password"))))