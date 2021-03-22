#lang racket

(require racket/udp)
(include "globals.rkt")

(define (ack-pkt bstr-pkt sock)
  (send-to-server sock (make-header (seq-num bstr-pkt) ACK))
  bstr-pkt)

(define (bstr-pkt->pkt bstr-pkt)
  (cons (seq-num bstr-pkt) (list (subbytes bstr-pkt PKT-HEADER-SIZE))))

(define (save-pkt pkt pkts)
  (if (assoc (first pkt) pkts)
    pkts
    (cons pkt pkts)))

(define (recv pkts sock [time 0])
  (define buf (make-bytes PKT-SIZE))
  (match-define-values (num-bytes _ _) (udp-receive!* sock buf))
  (cond
    (num-bytes
      (define bstr-pkt (subbytes buf 0 num-bytes))
      (cond ((data-bstr-pkt? bstr-pkt)
             (send-to-server sock (make-header (seq-num bstr-pkt) ACK))
             (recv (save-pkt (bstr-pkt->pkt bstr-pkt) pkts) sock))
            (else (finalize sock pkts))))
    (else
      (cond ((and (empty? pkts) (< (+ TIMEOUT time) (current-seconds)))
             (send-to-server sock (make-header 0 SYN))
             (recv pkts sock (current-seconds)))
            (else (recv pkts sock time))))))

(define (finalize sock pkts)
  (define file (open-output-file OUTPUT-FILE #:exists 'replace))
  (write-bytes
    (apply bytes-append (map second (sort pkts < #:key first)))
    file)
  (close-output-port file)
  (send-to-server sock (make-header 0 ACK))
  (displayln "File saved. Shutting down client."))

(define (start)
  (define sock (udp-open-socket))
  (udp-bind! sock ADDR CLIENT-PORT)
  (send-to-server sock (make-header 0 SYN))
  (recv '() sock (current-seconds)))

(start)

