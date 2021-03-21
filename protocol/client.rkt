#lang racket

(require racket/udp)
(include "globals.rkt")

(define STATE "LISTEN")
(define RCV-BASE -1)

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

(define (ack-pkt bstr sock)
  (udp-send-to
    sock
    ADDR
    SERVER-PORT
    (bytes-append (make-header (seq-num bstr) ACK) (make-bytes PKT-BODY-SIZE)))
  bstr)

(define (bstr->pkt bstr)
  (cons (seq-num bstr) (list (subbytes bstr PKT-HEADER-SIZE))))

(define (add-pkt bstr pkts)
  (cons (bstr->pkt bstr) pkts))

(define (recv pkts sender-sock listener-sock)
  (define buf (make-bytes PKT-SIZE))
  (match-define-values (num_bytes _ _) (udp-receive! listener-sock buf))
  (define bstr (subbytes buf 0 num_bytes))
  (if (data-pkt? bstr)
    (recv (add-pkt (ack-pkt bstr sender-sock) pkts) sender-sock listener-sock)
    (finalize sender-sock pkts)))

(define (finalize sock pkts)
  (define file (open-output-file "recv.txt" #:exists 'replace))
  (write-bytes
    (apply bytes-append (map second (sort pkts < #:key first)))
    file)
  (close-output-port file)
  (displayln "File saved. Shutting down client."))

(define (start)
  (define listener-sock (udp-open-socket))
  (udp-bind! listener-sock ADDR CLIENT-PORT)
  (recv '() (udp-open-socket) listener-sock))

(start)

