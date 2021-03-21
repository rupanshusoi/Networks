#lang racket

(require racket/udp)
(include "globals.rkt")

(define SEND-ME 0)
(define ACK-ME 1)

(define STATE "LISTEN")

(define NEXT-SEQ-NUM 0)
(define MAX-SEQ-NUM 0)
(define MAX-BYTES 0)

(define (get-next-seq-num)
  (define x NEXT-SEQ-NUM)
  (set! NEXT-SEQ-NUM (add1 NEXT-SEQ-NUM))
  x)

(define (set-globals bstr)
  (define len (bytes-length bstr))
  (set! MAX-SEQ-NUM (floor (/ len PKT-BODY-SIZE)))
  (set! MAX-BYTES len))

(define (make-header seq-num type)
  (bytes-append
    (integer->integer-bytes seq-num 4 #f)
    (integer->integer-bytes 0 4 #f)
    (integer->integer-bytes 0 4 #f)
    (integer->integer-bytes type 1 #f)))

(define (make-body seq-num bstr)
  (subbytes
    bstr
    (* seq-num PKT-BODY-SIZE)
    (min MAX-BYTES (* (add1 seq-num) PKT-BODY-SIZE))))

(define (sender bstr pending sender-sock listener-sock)
  (define (send-pkt? pkt)
    (if (or
          (eq? (second pkt) SEND-ME)
          (and (eq? (second pkt) ACK-ME)
               (< (+ TIMEOUT (third pkt)) (current-seconds))))
      #t
      #f))
  (define (send-pkts pkts)
    (cond ((empty? pkts) '())
          ((send-pkt? (car pkts)) (cons (send-pkt (car pkts)) (send-pkts (cdr pkts))))
          (else (cons (car pkts) (send-pkts (cdr pkts))))))
  (define (send-pkt pkt)
    (udp-send-to
      sender-sock
      ADDR
      CLIENT-PORT
      (bytes-append (make-header (first pkt) DATA) (make-body (first pkt) bstr)))
    (list (first pkt) ACK-ME (current-seconds)))
  (if (empty? pending) ;; Last pkt has been acked
    (finalize sender-sock)
    (listener bstr (send-pkts pending) sender-sock listener-sock)))

(define (rem-acked-pkt pending seq-num)
  (remove seq-num pending (lambda (seq-num pkt) (eq? seq-num (car pkt)))))

(define (queue-pkt pending)
  (if (and
        (not (empty? pending))
        (< (caar pending) MAX-SEQ-NUM)
        (< (- (caar pending) (car (last pending))) WINDOW-SIZE))
    (cons (list (get-next-seq-num) SEND-ME) pending)
    pending))

(define (listener bstr pending sender-sock listener-sock)
  (define buffer (make-bytes PKT-SIZE))
  (match-define-values (num-bytes _ _) (udp-receive!* listener-sock buffer))
  (if num-bytes
    (sender
      bstr
      (queue-pkt (rem-acked-pkt pending (integer-bytes->integer buffer #f #f 0 4)))
      sender-sock
      listener-sock)
    (sender bstr pending sender-sock listener-sock)))

(define (finalize sock)
  (udp-send-to
    sock
    ADDR
    CLIENT-PORT
    (bytes-append (make-header 0 FIN) (make-bytes PKT-BODY-SIZE)))
  (displayln "FIN sent. Shutting down server."))

(define (init-pkts)
  (map (lambda (n) (list (get-next-seq-num) SEND-ME)) (reverse (range (min (add1 MAX-SEQ-NUM) WINDOW-SIZE)))))

(define (start bstr)
  (set-globals bstr)
  (define listener-sock (udp-open-socket))
  (udp-bind! listener-sock ADDR SERVER-PORT)
  (sender bstr (init-pkts) (udp-open-socket) listener-sock))

(start (file->bytes "test.txt"))

