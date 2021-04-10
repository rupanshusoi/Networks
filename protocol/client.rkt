#lang racket

(require racket/udp)
(include "globals.rkt")

(define (bstr-pkt->pkt bstr-pkt)
  (cons (extract-seq-num bstr-pkt) (list (subbytes bstr-pkt PKT-HEADER-SIZE))))

(define (add-pkt pkt pkts written-pkts)
  (if (or (assoc (first pkt) pkts)
          (member (first pkt) written-pkts))
    pkts
    (cons pkt pkts)))

(define (write-pkts pkts written-pkts output-file [final #f])
  (cond ((or final (= (length pkts) WINDOW-SIZE))
         (write-bytes (apply bytes-append (map second (sort pkts < #:key first))) output-file)
         (values '() (append (map first pkts) written-pkts)))
        (else (values pkts written-pkts))))

(define (recv pkts written-pkts sock output-file [time 0])
  (define buf (make-bytes PKT-SIZE))
  (match-define-values (num-bytes _ _) (udp-receive!* sock buf))
  (cond
    (num-bytes
      (define bstr-pkt (subbytes buf 0 num-bytes))
      (cond ((data-bstr-pkt? bstr-pkt)
             (send-to-server sock (make-header (extract-seq-num bstr-pkt) ACK))
             (call-with-values (lambda ()
                                 (write-pkts
                                   (add-pkt (bstr-pkt->pkt bstr-pkt) pkts written-pkts)
                                   written-pkts
                                   output-file))
                               (lambda (p wp) (recv p wp sock output-file))))
            (else (finalize pkts written-pkts sock output-file))))
    (else
      (cond ((and (empty? pkts) (empty? written-pkts) (< (+ TIMEOUT time) (current-seconds)))
             (send-to-server sock (make-header 0 SYN))
             (recv pkts written-pkts sock output-file (current-seconds)))
            (else (recv pkts written-pkts sock output-file time))))))

(define (finalize pkts written-pkts sock output-file)
  (write-pkts pkts written-pkts output-file #t)
  (send-to-server sock (make-header 0 ACK))
  (displayln "File saved. Shutting down client."))

(define (start)
  (define sock (udp-open-socket))
  (udp-bind! sock ADDR CLIENT-PORT)
  (udp-set-receive-buffer-size! sock (max (* 1024 1024) (* 2 PKT-SIZE WINDOW-SIZE)))
  (send-to-server sock (make-header 0 SYN))
  (define output-file (open-output-file OUTPUT-FILE #:exists 'replace))
  (recv '() '()  sock output-file (current-seconds))
  (close-output-port output-file))

(start)

