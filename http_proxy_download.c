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
  char *char_set = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"; 
  char *result = malloc(100 * sizeof(char)); 
  int idx, num_bits = 0, padding = 0, value = 0, count = 0, tmp; 

  int i, j, k = 0; 
  for (i = 0; i < len_str; i += 3) { 
    value = 0, count = 0, num_bits = 0; 

    for (j = i; j < len_str && j <= i + 2; j++) { 
      value = value << 8; 
      value = value | input_str[j]; 
      count++; 
    } 
    
    num_bits = count * 8; 
    padding = num_bits % 3; 
    while (num_bits != 0) { 
      if (num_bits >= 6) {
        tmp = num_bits - 6; 
        idx = (value >> tmp) & 63; 
        num_bits -= 6;         
      } 
      else { 
        tmp = 6 - num_bits; 
        idx = (value << tmp) & 63; 
        num_bits = 0; 
      } 
      result[k++] = char_set[idx]; 
    } 
  } 
  
  for (i = 1; i <= padding; i++) { 
    result[k++] = '='; 
  } 
  
  result[k] = '\0'; 
  return result; 
} 

char *encode(char *username, char *password) {
  // TODO: Obfuscate
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
