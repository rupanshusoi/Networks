#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netdb.h>
#include <assert.h>
 
#define MAX_LEN_MSG 512
#define RECV_BUF 10000000
#define BASE64_FACTOR 4
#define TIMEOUT 2

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

    struct timeval tv;
    tv.tv_sec = TIMEOUT;
    tv.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char *)&tv, sizeof(tv));

    return sock;
}

char *base64_encode(char *input_str, int len) 
{ 
  // TODO: Obfuscate
  char *char_set = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"; 
  char *result = malloc(BASE64_FACTOR * len); 
  int idx, num_bits = 0, padding = 0, value = 0, count = 0, tmp; 

  int i, j, k = 0; 
  for (i = 0; i < len; i += 3) { 
    value = 0, count = 0, num_bits = 0; 

    for (j = i; j < len && j <= i + 2; j++) { 
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
  int len = strlen(username) + strlen(password) + 1;
  char *data = calloc(len, sizeof(char));
  sprintf(data, "%s:%s", username, password);
  return base64_encode(data, len);
}

void make_msg(char* msg, char *URL, char *server, char *username, char *password) {
  sprintf(msg, "GET http://%s HTTP/1.1\r\nHost: "
               "http://%s\r\nProxy-Authorization: Basic ", URL, server);
  strcat(msg, encode(username, password));
  strcat(msg, "\r\n\r\n");
}

int main(int argc, char **argv)
{
    char *URL            = argv[1];
    char *host           = argv[2];
    char *port           = argv[3];
    char *username       = argv[4];
    char *password       = argv[5];
    char *html_filename  = argv[6];
    char *image_filename = argv[7];

    char *msg = calloc(MAX_LEN_MSG, sizeof(char));
    make_msg(msg, URL, URL, username, password);

    int sock = get_socket(host, port);

    send(sock, msg, strlen(msg), 0);
 
    int bytes_read = 0, total_bytes_read = 0;
    char* header_ptr;
    char* buffer = malloc(RECV_BUF * sizeof(char));

    while (1) {
      if ((bytes_read = recv(sock, buffer + total_bytes_read, RECV_BUF, 0)) == -1) {
        break;
      }
      total_bytes_read += bytes_read;
    }

    FILE *html_file;
    html_file = fopen(html_filename, "w");
    assert(html_file);

    header_ptr = strstr(buffer, "\r\n\r\n");
    assert(header_ptr);
    fprintf(html_file, "%.*s", total_bytes_read - (int)(header_ptr + 4 - buffer), header_ptr + 4);
    fclose(html_file);

    if (strcmp(URL, "info.in2p3.fr") == 0) {
      char* image_URL = calloc(strlen(URL) + strlen("/cc.gif"), sizeof(char));
      strcat(image_URL, URL);
      strcat(image_URL, "/cc.gif");
      make_msg(msg, image_URL, URL, username, password);
      
      send(sock, msg, strlen(msg), 0);

      free(buffer);
      buffer = malloc(RECV_BUF * sizeof(char));

      total_bytes_read = 0;
      while (1) {
        if ((bytes_read = recv(sock, buffer + total_bytes_read, RECV_BUF, 0)) == -1) {
          break;
        }
        total_bytes_read += bytes_read;
      }

      FILE *image_file;
      image_file = fopen(image_filename, "wb");
      assert(image_file);

      header_ptr = strstr(buffer, "\r\n\r\n");
      assert(header_ptr);
      fwrite(header_ptr + 4, total_bytes_read - (int)(header_ptr + 4 - buffer), 1, image_file);
      fclose(image_file);
    }

    close(sock);
    return 0;
}
