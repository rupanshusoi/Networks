(define ADDR "127.0.0.1")
(define SERVER-PORT 1060)
(define CLIENT-PORT 1061)
(define PKT-BODY-SIZE 100)
(define PKT-HEADER-SIZE 13)
(define PKT-SIZE (+ PKT-HEADER-SIZE PKT-BODY-SIZE))
(define BUF-SIZE PKT-SIZE)
(define WINDOW-SIZE 10) ;; Must be > 1
(define TIMEOUT 1)

(define SYN 0)
(define DATA 1)
(define ACK 2)
(define FIN 3)

(define SEND-ME 0)
(define ACK-ME 1)

(define INPUT-FILE "test.txt")
(define OUTPUT-FILE "recv.txt")

(define (make-header seq-num type)
  (bytes-append
    (integer->integer-bytes seq-num 4 #f)
    (integer->integer-bytes 0 4 #f)
    (integer->integer-bytes 0 4 #f)
    (integer->integer-bytes type 1 #f)))

(define (type-bstr-pkt? type)
  (lambda (bstr)
    (if (eq? type (integer-bytes->integer bstr #f #f 12 13))
      #t
      #f)))

(define data-bstr-pkt? (type-bstr-pkt? DATA))
(define syn-bstr-pkt? (type-bstr-pkt? SYN))

(define (send-to port)
  (lambda (sock header [body (make-bytes PKT-BODY-SIZE)])
    (udp-send-to sock ADDR port (bytes-append header body))))

(define send-to-server (send-to SERVER-PORT))
(define send-to-client (send-to CLIENT-PORT))

