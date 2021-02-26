#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h> /* close() */
#include <sys/socket.h>
#include <netdb.h>
 
int main(void)
{
    int sock;
    char host[] = "182.75.45.22";
    char port[] = "13128";
    struct addrinfo hints, *res;
    char message[] = "GET http://info.in2p3.fr/ HTTP/1.1\r\nHost: http://info.in2p3.fr/\r\nProxy-Authorization: Basic Y3NmMzAzOmNzZjMwMw==\r\n\r\n";
    char buf[1024];
    int bytes_read;
    int status;
 
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    status = getaddrinfo(host, port, &hints, &res);
    if (status != 0) {
        perror("getaddrinfo");
        return 1;
    }

    sock = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (sock == -1) {
        perror("socket");
        return 1;
    } else {
      printf("Socket created.\n");
    }

    status = connect(sock, res->ai_addr, res->ai_addrlen);
    if (status == -1) {
        perror("connect");
        return 1;
    } else {
      printf("Connected.\n");
    }

    freeaddrinfo(res);

    int bytes_sent = send(sock, message, strlen(message), 0);
    printf("Bytes sent: %d. Total bytes: %lu.\n", bytes_sent, strlen(message));
 
    do {
        bytes_read = recv(sock, buf, 1024, 0);
        if (bytes_read == -1) {
            perror("recv");
        }
        else {
            printf("%.*s", bytes_read, buf);
        }
    } while (bytes_read > 0);
 
    close(sock);
 
    return 0;
}
