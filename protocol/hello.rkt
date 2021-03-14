#lang racket

(require racket/udp)

(define (server)
  (define buffer (apply bytes (map char->integer (string->list "Hello"))))
  (define socket (udp-open-socket))
  (udp-send-to socket "127.0.0.1" 1060 buffer))

(define (client)
  (define socket (udp-open-socket))
  (udp-bind! socket "127.0.0.1" 1060)
  (define buffer (make-bytes 128))
  (define-values (num_bytes hostname port) (udp-receive! socket buffer))
  (map displayln (list buffer hostname port)))
