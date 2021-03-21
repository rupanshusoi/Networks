#lang racket

(require racket/udp)
(include "globals.rkt")

(define (seq-num bstr-pkt) (integer-bytes->integer bstr-pkt #f #f 0 4))

(define (ack-pkt bstr-pkt sock)
  (send-to-server sock (make-header (seq-num bstr-pkt) ACK))
  bstr-pkt)

(define (bstr-pkt->pkt bstr-pkt)
  (cons (seq-num bstr-pkt) (list (subbytes bstr-pkt PKT-HEADER-SIZE))))

(define (save-pkt pkt pkts)
  (if (assoc (first pkt) pkts)
    pkts
    (cons pkt pkts)))

(define (recv pkts sender-sock listener-sock [time 0])
  (define buf (make-bytes PKT-SIZE))
  (match-define-values (num-bytes _ _) (udp-receive!* listener-sock buf))
  (cond
    (num-bytes
      (define bstr-pkt (subbytes buf 0 num-bytes))
      (cond ((data-bstr-pkt? bstr-pkt)
             (send-to-server sender-sock (make-header (seq-num bstr-pkt) ACK))
             (recv (save-pkt (bstr-pkt->pkt bstr-pkt) pkts) sender-sock listener-sock))
            (else (finalize sender-sock pkts))))
    (else
      (cond ((and (empty? pkts) (< (+ TIMEOUT time) (current-seconds)))
             (send-to-server sender-sock (make-header 0 SYN))
             (recv pkts sender-sock listener-sock (current-seconds)))
            (else (recv pkts sender-sock listener-sock time))))))

(define (finalize sock pkts)
  (define file (open-output-file OUTPUT-FILE #:exists 'replace))
  (write-bytes
    (apply bytes-append (map second (sort pkts < #:key first)))
    file)
  (close-output-port file)
  (send-to-server sock (make-header 0 ACK))
  (displayln "File saved. Shutting down client."))

(define (start)
  (define sender-sock (udp-open-socket))
  (define listener-sock (udp-open-socket))
  (udp-bind! listener-sock ADDR CLIENT-PORT)
  (send-to-server sender-sock (make-header 0 SYN))
  (recv '() sender-sock listener-sock (current-seconds)))

(start)

