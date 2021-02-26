#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netdb.h>
#include <assert.h>
 
#define MAX_LEN_MSG 500
#define RECV_BUF 4096

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

char *base64_encode(char *input_str, int len_str) 
{ 
  char char_set[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"; 
  char *res_str = (char *) malloc(100 * sizeof(char)); 
  int index, no_of_bits = 0, padding = 0, val = 0, count = 0, temp; 
  int i, j, k = 0; 
  for (i = 0; i < len_str; i += 3) { 
    val = 0, count = 0, no_of_bits = 0; 
    for (j = i; j < len_str && j <= i + 2; j++) { 
      val = val << 8; 
      val = val | input_str[j]; 
      count++; 
    } 
    
    no_of_bits = count * 8; 
    padding = no_of_bits % 3; 
    while (no_of_bits != 0) { 
      if (no_of_bits >= 6) {
      temp = no_of_bits - 6; 
      index = (val >> temp) & 63; 
      no_of_bits -= 6;         
      } 
      else { 
        temp = 6 - no_of_bits; 
        index = (val << temp) & 63; 
        no_of_bits = 0; 
      } 
      res_str[k++] = char_set[index]; 
    } 
  } 
  
  for (i = 1; i <= padding; i++) { 
    res_str[k++] = '='; 
  } 
  
  res_str[k] = '\0'; 
  return res_str; 
} 

char *encode(char *username, char *password) {
  // TODO
  int len = strlen(username) + strlen(password) + 1;
  char *data = calloc(len, sizeof(char));
  sprintf(data, "%s:%s", username, password);
  return base64_encode(data, len);
}

void make_msg(char* msg, char *URL, char *username, char *password) {
  sprintf(msg, "GET http://%s HTTP/1.1\r\nHost: "
               "http://%s\r\nProxy-Authorization: Basic ", URL, URL);
  strcat(msg, encode(username, password));
  strcat(msg, "\r\n\r\n");
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
    make_msg(msg, URL, username, password);

    int sock = get_socket(host, port);
    send(sock, msg, strlen(msg), 0);
 
    FILE *html_file;

    int bytes_read;
    char buffer[RECV_BUF];
    do {
        bytes_read = recv(sock, buffer, RECV_BUF, 0);
        assert(bytes_read != -1);

        html_file = fopen(html_filename, "a");
        assert(html_file);
        fprintf(html_file, "%.*s", bytes_read, buffer);
        fclose(html_file);
    } while (bytes_read > 0);
 
    close(sock);
    return 0;
}
