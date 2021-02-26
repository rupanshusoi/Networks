#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netdb.h>
#include <assert.h>
 
#define MAX_LEN_MSG 500
#define RECV_BUF 4096

void make_msg(char* msg) {
  sprintf(msg, "GET http://info.in2p3.fr/ HTTP/1.1\r\nHost: http://info.in2p3.fr/\r\nProxy-Authorization: Basic Y3NmMzAzOmNzZjMwMw==\r\n\r\n");
}

int get_socket(char *host, char *port) {
    struct addrinfo hints, *res;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    int status = getaddrinfo(host, port, &hints, &res);
    assert(status == 0);

    int sock = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    assert(sock != -1);

    status = connect(sock, res->ai_addr, res->ai_addrlen);
    assert(status != -1);

    freeaddrinfo(res);

    return sock;
}

int main(int argc, char **argv)
{
    char *URL = argv[1];
    char *host = argv[2];
    char *port = argv[3];
    char *username = argv[4];
    char *password = argv[5];
    char *html_filename = argv[6];
    char *image_file = argv[7];

    char *msg = calloc(MAX_LEN_MSG, sizeof(char));
    make_msg(msg);

    int sock = get_socket(host, port);
    send(sock, msg, strlen(msg), 0);
 
    FILE *html_file;
    int bytes_read;
    char buffer[RECV_BUF];
    do {
        bytes_read = recv(sock, buffer, RECV_BUF, 0);
        assert(bytes_read != -1);

        html_file = fopen(html_filename, "w");
        assert(html_file);
        fprintf(html_file, "%.*s", bytes_read, buffer);
        fclose(html_file);
    } while (bytes_read > 0);
 
    close(sock);
    return 0;
}
