#lang racket

(require racket/udp)
(include "globals.rkt")

(define (seq-num bstr) (integer-bytes->integer bstr #f #f 0 4))

(define (data-pkt? bstr)
  (if (eq? DATA (integer-bytes->integer bstr #f #f 12 13))
    #t
    #f))

(define (make-header seq-num type)
  (bytes-append
    (integer->integer-bytes seq-num 4 #f)
    (integer->integer-bytes 0 4 #f)
    (integer->integer-bytes 0 4 #f)
    (integer->integer-bytes type 1 #f)))

(define (ack-pkt seq-num bstr sock)
  (udp-send-to
    sock
    ADDR
    SERVER-PORT
    (bytes-append (make-header seq-num ACK) (make-bytes PKT-BODY-SIZE)))
  bstr)

(define (bstr->pkt bstr)
  (cons (seq-num bstr) (list (subbytes bstr PKT-HEADER-SIZE))))

(define (add-pkt bstr pkts)
  (cons (bstr->pkt bstr) pkts))

(define (send-syn sock)
  (udp-send-to
    sock
    ADDR
    SERVER-PORT
    (bytes-append (make-header 0 SYN) (make-bytes PKT-BODY-SIZE))))

(define (recv pkts sender-sock listener-sock [time 0])
  (define buf (make-bytes PKT-SIZE))
  (match-define-values (num-bytes _ _) (udp-receive!* listener-sock buf))
  (if num-bytes
    (begin
      (if (data-pkt? (subbytes buf 0 num-bytes))
        (recv (add-pkt (ack-pkt (seq-num (subbytes buf 0 num-bytes)) (subbytes buf 0 num-bytes) sender-sock) pkts) sender-sock listener-sock)
        (finalize sender-sock pkts)))
    (cond ((and (empty? pkts) (< (+ TIMEOUT time) (current-seconds)))
           (begin
             (send-syn sender-sock)
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
  (send-syn sender-sock)
  (recv '() sender-sock listener-sock) (current-seconds))

(start)

