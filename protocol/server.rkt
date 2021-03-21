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

(define (set-globals bstr-file)
  (define len (bytes-length bstr-file))
  (set! MAX-SEQ-NUM (floor (/ len PKT-BODY-SIZE)))
  (set! MAX-BYTES len))

(define (make-body seq-num bstr-file)
  (subbytes bstr-file
            (* seq-num PKT-BODY-SIZE)
            (min MAX-BYTES (* (add1 seq-num) PKT-BODY-SIZE))))

(define (send-pkt? pkt)
    (if (or (eq? (second pkt) SEND-ME)
            (< (+ TIMEOUT (third pkt)) (current-seconds)))
      #t
      #f))

(define (sender bstr-file pkts sender-sock listener-sock)
  (define (send-pkts pkts)
    (cond ((empty? pkts) '())
          ((send-pkt? (car pkts)) (cons (send-pkt (car pkts)) (send-pkts (cdr pkts))))
          (else (cons (car pkts) (send-pkts (cdr pkts))))))
  (define (send-pkt pkt)
    (define seq-num (first pkt))
    (send-to-client sender-sock (make-header seq-num DATA) (make-body seq-num bstr-file))
    (list (first pkt) ACK-ME (current-seconds)))
  (cond ((empty? pkts) ;; Last pkt has been acked
          (send-to-client sender-sock (make-header 0 FIN))
          (finalize sender-sock listener-sock (current-seconds)))
        (else (listener bstr-file (send-pkts pkts) sender-sock listener-sock))))

(define (rem-acked-pkt pkts seq-num)
  (remove seq-num pkts (lambda (seq-num pkt) (eq? seq-num (car pkt)))))

(define (queue-next-pkt pkts)
  (if (and (not (empty? pkts))
           (<= NEXT-SEQ-NUM MAX-SEQ-NUM)
           (< (length pkts) WINDOW-SIZE))
    (cons (list (get-next-seq-num) SEND-ME) pkts)
    pkts))

(define (listener bstr-file pkts sender-sock listener-sock)
  (define buf (make-bytes PKT-SIZE))
  (match-define-values (num-bytes _ _) (udp-receive!* listener-sock buf))
  (if num-bytes
    (if (syn-bstr-pkt? buf)
      (sender bstr-file (init-pkts) sender-sock listener-sock) ;; Restart SR from packet 0 
      (sender bstr-file
              (queue-next-pkt (rem-acked-pkt pkts (seq-num buf)))
              sender-sock
              listener-sock))
    (sender bstr-file pkts sender-sock listener-sock)))

(define (finalize sender-sock listener-sock [time 0])
  (define buf (make-bytes PKT-SIZE))
  (match-define-values (num-bytes _ _) (udp-receive!* listener-sock buf))
  (if num-bytes
    (displayln "FIN acked successfully. Shutting down server.")
    (cond ((< (+ TIMEOUT time) (current-seconds))
           (send-to-client sender-sock (make-header 0 FIN))
           (finalize sender-sock listener-sock (current-seconds)))
          (else (finalize sender-sock listener-sock time)))))

(define (init-pkts)
  (reset-seq-num)
  (reverse (map (lambda (n) (list (get-next-seq-num) SEND-ME))
                (range (min (add1 MAX-SEQ-NUM) WINDOW-SIZE)))))

(define (start bstr-file)
  (define listener-sock (udp-open-socket))
  (udp-bind! listener-sock ADDR SERVER-PORT)
  (define buf (make-bytes PKT-SIZE))
  (udp-receive! listener-sock buf)
  (if (syn-bstr-pkt? buf)
    (sender bstr-file (init-pkts) (udp-open-socket) listener-sock)
    (raise 'failed #t))) 

(define bstr-file (file->bytes INPUT-FILE))
(set-globals bstr-file)
(start bstr-file)

