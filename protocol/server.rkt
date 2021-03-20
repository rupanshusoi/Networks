#lang racket

(require racket/udp)
(include "globals.rkt")

(define SEND-ME 0)
(define ACK-ME 1)

(define STATE "LISTEN")

(define SEND-BASE 0)
(define NEXT-SEQ-NUM 1)
(define MAX-SEQ-NUM 0)
(define MAX-BYTES 0)

(define (get-next-seq-num)
  (define x NEXT-SEQ-NUM)
  (set! NEXT-SEQ-NUM (add1 NEXT-SEQ-NUM))
  x)

(define (set-globals bstr)
  (set! MAX-SEQ-NUM (floor (/ (bytes-length bstr) PKT-BODY-SIZE)))
  (set! MAX-BYTES (bytes-length bstr)))

(define (sender bstr pending sema socket)
  (define (send-pkts pkts)
    (cond ((empty? pkts) '())
          ((eq? (second (car pkts)) SEND-ME)
           (cons (send-pkt (car pkts)) (send-pkts (cdr pkts))))
          (else (cons (car pkts) (send-pkts (cdr pkts))))))
  (define (send-pkt pkt)
    (udp-send-to
      socket
      ADDR
      CLIENT-PORT
      (bytes-append
        (integer->integer-bytes (get-next-seq-num) 4 #f)
        (integer->integer-bytes 0 4 #f)
        (integer->integer-bytes 0 4 #f)
        (integer->integer-bytes DATA 1 #f)
        (subbytes
          bstr
          (* (first pkt) PKT-BODY-SIZE)
          (min MAX-BYTES (* (add1 (first pkt)) PKT-BODY-SIZE)))))
    (displayln "Sent packet"))
  (displayln "Starting send-pkts")
  (send-pkts pending))

(define (init-pkts)
  (cons (list 0 SEND-ME) '()))

(define (start bstr)
  (set-globals bstr)
  (define pending (init-pkts))
  (define sema (make-semaphore 1))
  (define sender-socket (udp-open-socket))
  ;(thread (lambda () (sender bstr pending sema sender-socket)))
  (sender bstr pending sema sender-socket)
  )

(start (file->bytes "test.txt"))

