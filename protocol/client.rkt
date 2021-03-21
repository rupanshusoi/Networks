#lang racket

(require racket/udp)
(include "globals.rkt")

(define (seq-num bstr-pkt) (integer-bytes->integer bstr-pkt #f #f 0 4))

(define (ack-pkt seq-num bstr-pkt sock)
  (send-to-server sock (make-header seq-num ACK))
  bstr-pkt)

(define (bstr-pkt->pkt bstr-pkt)
  (cons (seq-num bstr-pkt) (list (subbytes bstr-pkt PKT-HEADER-SIZE))))

(define (save-pkt bstr-pkt pkts)
  (cons (bstr-pkt->pkt bstr-pkt) pkts))

(define (recv pkts sender-sock listener-sock [time 0])
  (define buf (make-bytes PKT-SIZE))
  (match-define-values (num-bytes _ _) (udp-receive!* listener-sock buf))
  (if num-bytes
    (let ([bstr-pkt (subbytes buf 0 num-bytes)])
      (if (data-bstr-pkt? bstr-pkt)
      (recv (save-pkt (ack-pkt (seq-num bstr-pkt) bstr-pkt sender-sock) pkts) sender-sock listener-sock)
      (finalize sender-sock pkts)))
    (cond ((and (empty? pkts) (< (+ TIMEOUT time) (current-seconds)))
           (begin
             (send-to-server sender-sock (make-header 0 SYN))
             (recv pkts sender-sock listener-sock (current-seconds))))
          ((and (empty? pkts) (>= (+ TIMEOUT time) (current-seconds)))
           (recv pkts sender-sock listener-sock time))
          (else (recv pkts sender-sock listener-sock)))))

(define (finalize sock pkts)
  (define file (open-output-file "recv.txt" #:exists 'replace))
  (write-bytes
    (apply bytes-append (map second (sort (remove-duplicates pkts #:key car) < #:key first)))
    file)
  (close-output-port file)
  (ack-pkt 0 0 sock)
  (displayln "File saved. Shutting down client."))

(define (start)
  (define sender-sock (udp-open-socket))
  (define listener-sock (udp-open-socket))
  (udp-bind! listener-sock ADDR CLIENT-PORT)
  (send-to-server sender-sock (make-header 0 SYN))
  (recv '() sender-sock listener-sock (current-seconds)))

(start)

