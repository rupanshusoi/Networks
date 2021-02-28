/* f20180294@hyderabad.bits-pilani.ac.in Rupanshu Soi */

/* A C program to download the raw HTML of a webpage over HTTP. */
/* We recv the entire response data into a large buffer, find out where the HTTP header ends and write out the rest to file. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netdb.h>
#include <assert.h>
 
#define MAX_LEN_MSG 1024
#define RECV_BUF 10000000
#define BASE64_FACTOR 4
#define TIMEOUT 2
#define CRLF "\r\n\r\n"

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
  int len = strlen(username) + strlen(password) + 2;
  char *data = calloc(len, sizeof(char));
  sprintf(data, "%s:%s", username, password);
  return base64_encode(data, len);
}


void make_msg(char* msg, char *URL, char *host, char *username, char *password) {
  sprintf(msg, "GET %s HTTP/1.1\r\nHost: %s\r\nProxy-Authorization: Basic %s"CRLF,
      URL, host, encode(username, password));
}

char *make_absolute_URL(char *URL) {
  if (URL != strstr(URL, "http://")) {
    char *abs = calloc((strlen(URL) + strlen("http://") + 1), sizeof(char));
    sprintf(abs, "http://%s", URL);
    return abs;
  }
  return URL;
}

char *get_redirect_addr(char *buffer){
  char *start = strstr(buffer, "Location: ");
  assert(start);
  start += 10;

  char *end = strstr(start, "\r\n");
  assert(start);

  *end = '\0';
  return start;
}

char *get_image_name(char *buffer) {
  char *start = strstr(buffer, "<IMG SRC=\"");
  assert(start);
  start += 10;

  char *end = strstr(start, "\"");
  assert(end);

  *end = '\0';
  return start;
}

int main(int argc, char **argv) {
    char *URL            = make_absolute_URL(argv[1]);
    char *host           = argv[2];
    char *port           = argv[3];
    char *username       = argv[4];
    char *password       = argv[5];
    char *html_filename  = argv[6];
    char *image_filename = argv[7];

    int sock = get_socket(host, port);
    char *buffer = malloc(RECV_BUF * sizeof(char));

    do {
      char *msg = calloc(MAX_LEN_MSG, sizeof(char));
      make_msg(msg, URL, URL, username, password);

      send(sock, msg, strlen(msg), 0);
  
      int bytes_read = 0, total_bytes_read = 0;
      char *header_ptr;

      while (1) {
        if ((bytes_read = recv(sock, buffer + total_bytes_read, RECV_BUF, 0)) <= 0) {
          break;
        }
        total_bytes_read += bytes_read;
      }
      *(buffer + total_bytes_read) = '\0';

      if (strstr(buffer, "HTTP/1.1 30") && (strstr(buffer, "HTTP/1.1 30") < strstr(buffer, CRLF))) {
        free(msg);
        URL = get_redirect_addr(buffer);
        continue;
      }

      FILE *html_file = fopen(html_filename, "w");
      assert(html_file);
      header_ptr = strstr(buffer, CRLF);
      assert(header_ptr);
      fprintf(html_file, "%.*s", total_bytes_read - (int)(header_ptr + 4 - buffer), header_ptr + 4);
      fclose(html_file);

      if (strcmp(URL, "http://info.in2p3.fr") == 0) {
        char *image_name = get_image_name(buffer);
        char *image_URL = calloc(strlen(URL) + strlen(image_name) + 1, sizeof(char));
        sprintf(image_URL, "%s/%s", URL, image_name);
        make_msg(msg, image_URL, URL, username, password);
        
        send(sock, msg, strlen(msg), 0);

        total_bytes_read = 0;
        while (1) {
          if ((bytes_read = recv(sock, buffer + total_bytes_read, RECV_BUF, 0)) <= 0) {
            break;
          }
          total_bytes_read += bytes_read;
        }

        FILE *image_file = fopen(image_filename, "wb");
        assert(image_file);
        header_ptr = strstr(buffer, CRLF);
        assert(header_ptr);
        fwrite(header_ptr + 4, total_bytes_read - (int)(header_ptr + 4 - buffer), 1, image_file);
        fclose(image_file);
      }

      break;
    } while (1);

    close(sock);
    return 0;
}
