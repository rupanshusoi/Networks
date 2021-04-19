#lang racket

(require racket/udp)
(include "globals.rkt")

(define NEXT-SEQ-NUM 0)
(define MAX-SEQ-NUM 0)

(define (get-next-seq-num)
  (define x NEXT-SEQ-NUM)
  (set! NEXT-SEQ-NUM (add1 NEXT-SEQ-NUM))
  x)

(define (send-pkt? pkt)
    (if (or (eq? (second pkt) SEND-ME)
            (< (+ TIMEOUT (third pkt)) (current-seconds)))
      #t
      #f))

(define (rem-acked-pkt seq-num pkts)
  (remove seq-num pkts (lambda (seq-num pkt) (eq? seq-num (car pkt)))))

(define (queue-next-pkt pkts)
  (if (and (not (empty? pkts))
           (<= NEXT-SEQ-NUM MAX-SEQ-NUM)
           (< (length pkts) WINDOW-SIZE))
    (cons (list (get-next-seq-num) SEND-ME) pkts)
    pkts))

(define (init-pkts)
  (set! NEXT-SEQ-NUM 0)
  (reverse (map (lambda (n) (list (get-next-seq-num) SEND-ME))
                (range (min (add1 MAX-SEQ-NUM) WINDOW-SIZE)))))

(define (start bstr-file)
  (define sock (udp-open-socket))
  (define buf (make-bytes PKT-SIZE))
  (define (make-body seq-num)
    (subbytes bstr-file
              (* seq-num PKT-BODY-SIZE)
              (min (bytes-length bstr-file) (* (add1 seq-num) PKT-BODY-SIZE))))
  (define (sender pkts)
    (define (send-pkts pkts)
      (cond ((empty? pkts) '())
            ((send-pkt? (car pkts)) (cons (send-pkt (car pkts)) (send-pkts (cdr pkts))))
            (else (cons (car pkts) (send-pkts (cdr pkts))))))
    (define (send-pkt pkt)
      (send-to-client sock (make-header (first pkt) DATA) (make-body (first pkt)))
      (list (first pkt) ACK-ME (current-seconds)))
    (cond ((empty? pkts) ;; Last pkt has been acked
           (send-to-client sock (make-header 0 FIN))
           (finalize (current-seconds)))
          (else (listener (send-pkts pkts)))))
  (define (listener pkts)
    (match-define-values (num-bytes _ _) (udp-receive!* sock buf))
    (if num-bytes
      (if (syn-bstr-pkt? buf)
        (sender (init-pkts)) ;; Restart SR from packet 0 
        (sender (queue-next-pkt (rem-acked-pkt (extract-seq-num buf) pkts))))
      (sender pkts)))
  (define (finalize [time 0])
    (match-define-values (num-bytes _ _) (udp-receive!* sock buf))
    (if num-bytes
      (displayln "FIN acked successfully. Shutting down server.")
      (cond ((< (+ TIMEOUT time) (current-seconds))
             (send-to-client sock (make-header 0 FIN))
             (finalize (current-seconds)))
            (else (finalize time)))))
  (udp-bind! sock ADDR SERVER-PORT)
  (udp-set-receive-buffer-size! sock (max (* 1024 1024) (* 2 PKT-SIZE WINDOW-SIZE)))
  (udp-receive! sock buf)
  (if (syn-bstr-pkt? buf)
    (sender (init-pkts))
    (raise "unrecognized-response" #t))) 

(define bstr-file (file->bytes INPUT-FILE))
(set! MAX-SEQ-NUM (floor (/ (bytes-length bstr-file) PKT-BODY-SIZE)))
(start bstr-file)

