#lang racket

(require racket/udp)
(include "globals.rkt")

(define (bstr-pkt->pkt bstr-pkt)
  (cons (seq-num bstr-pkt) (list (subbytes bstr-pkt PKT-HEADER-SIZE))))

(define (add-pkt pkt pkts written-pkts)
  (if (or (assoc (first pkt) pkts)
          (member (first pkt) written-pkts))
    pkts
    (cons pkt pkts)))

(define (write-pkts pkts written-pkts [final #f])
  (cond ((or final (= (length pkts) WINDOW-SIZE))
         (define file (open-output-file OUTPUT-FILE #:exists 'append))
         (write-bytes (apply bytes-append (map second (sort pkts < #:key first))) file)
         (close-output-port file)
         (values '() (append (map first pkts) written-pkts)))
        (else (values pkts written-pkts))))

(define (recv pkts written-pkts sock [time 0])
  (define buf (make-bytes PKT-SIZE))
  (match-define-values (num-bytes _ _) (udp-receive!* sock buf))
  (cond
    (num-bytes
      (define bstr-pkt (subbytes buf 0 num-bytes))
      (cond ((data-bstr-pkt? bstr-pkt)
             (send-to-server sock (make-header (seq-num bstr-pkt) ACK))
             (call-with-values (lambda ()
                                 (write-pkts
                                   (add-pkt (bstr-pkt->pkt bstr-pkt) pkts written-pkts)
                                   written-pkts))
                               (lambda (p wp) (recv p wp sock))))
            (else (finalize pkts written-pkts sock))))
    (else
      (cond ((and (empty? pkts) (empty? written-pkts) (< (+ TIMEOUT time) (current-seconds)))
             (send-to-server sock (make-header 0 SYN))
             (recv pkts written-pkts sock (current-seconds)))
            (else (recv pkts written-pkts sock time))))))

(define (finalize pkts written-pkts sock)
  (write-pkts pkts written-pkts #t)
  (send-to-server sock (make-header 0 ACK))
  (displayln "File saved. Shutting down client."))

(define (start)
  (define sock (udp-open-socket))
  (udp-bind! sock ADDR CLIENT-PORT)
  (send-to-server sock (make-header 0 SYN))
  (recv '() '()  sock (current-seconds)))

(start)

