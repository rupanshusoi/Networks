#lang racket

(require racket/udp)
(include "globals.rkt")

(define NEXT-SEQ-NUM 0)
(define MAX-SEQ-NUM 0)
(define MAX-BYTES 0)

(define (get-next-seq-num)
  (define x NEXT-SEQ-NUM)
  (set! NEXT-SEQ-NUM (add1 NEXT-SEQ-NUM))
  x)

(define (reset-seq-num)
  (set! NEXT-SEQ-NUM 0))

(define (set-globals bstr)
  (define len (bytes-length bstr))
  (set! MAX-SEQ-NUM (floor (/ len PKT-BODY-SIZE)))
  (set! MAX-BYTES len))

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
    (send-to-client sender-sock (make-header (first pkt) DATA) (make-body (first pkt) bstr))
    (list (first pkt) ACK-ME (current-seconds)))
  (if (empty? pending) ;; Last pkt has been acked
    (begin
      (send-to-client sender-sock (make-header 0 FIN))
      (finalize sender-sock listener-sock (current-seconds)))
    (listener bstr (send-pkts pending) sender-sock listener-sock)))

(define (rem-acked-pkt pending seq-num)
  (remove seq-num pending (lambda (seq-num pkt) (eq? seq-num (car pkt)))))

(define (queue-pkt pending)
  (if (and
        (not (empty? pending))
        (<= NEXT-SEQ-NUM MAX-SEQ-NUM)
        (< (length pending) WINDOW-SIZE))
    (cons (list (get-next-seq-num) SEND-ME) pending)
    pending))

(define (listener bstr pending sender-sock listener-sock)
  (define buf (make-bytes PKT-SIZE))
  (match-define-values (num-bytes _ _) (udp-receive!* listener-sock buf))
  (if num-bytes
    (if (syn-bstr-pkt? buf)
      (sender bstr (init-pkts) sender-sock listener-sock) ;; Restart SR from packet 0 
      (sender
        bstr
        (queue-pkt (rem-acked-pkt pending (integer-bytes->integer buf #f #f 0 4)))
        sender-sock
        listener-sock))
    (sender bstr pending sender-sock listener-sock)))

(define (finalize sender-sock listener-sock [time 0])
  (define buf (make-bytes PKT-SIZE))
  (match-define-values (num-bytes _ _) (udp-receive!* listener-sock buf))
  (if num-bytes
    (displayln "FIN acked successfully. Shutting down server.")
    (if (< (+ TIMEOUT time) (current-seconds))
      (begin
        (send-to-client sender-sock (make-header 0 FIN))
        (finalize sender-sock listener-sock (current-seconds)))
      (finalize sender-sock listener-sock time))))

(define (init-pkts)
  (reset-seq-num)
  (reverse (map (lambda (n) (list (get-next-seq-num) SEND-ME)) (range (min (add1 MAX-SEQ-NUM) WINDOW-SIZE)))))

(define (start bstr)
  (set-globals bstr)
  (define listener-sock (udp-open-socket))
  (udp-bind! listener-sock ADDR SERVER-PORT)
  (define buf (make-bytes PKT-SIZE))
  (udp-receive! listener-sock buf)
  (if (syn-bstr-pkt? buf)
    (sender bstr (init-pkts) (udp-open-socket) listener-sock)
    (raise 'failed #t))) 

(start (file->bytes "test.txt"))

