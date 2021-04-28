# Selective Repeat Inspired File Transfer Protocol in Racket

## Description
As part of my computer networks course, I implemented a reliable file transfer protocol over UDP sockets using Racket.

## Usage
All configuration parameters can be set in `globals.rkt`. `ftp.rkt` imports the client implementation and should be run by doing `$ racket ftp.rkt` to start the client. The server can be started similarly.

## Protocol
The implementation is built over UDP sockets. Much of the reliability mechanism takes after the Selective Repeat protocol. We attach a header containing a sequence number and packet type with each payload. The server will keep re-transmitting a packet until the client is able to successfully ACK it. The client buffers incoming packets and periodically writes them to disk.

To close the connection, the server sends a FIN and waits for an ACK (re-transmitting the FIN periodically). The client will only send the corresponding ACK once, so if it's dropped then the server will be left waiting forever. This is fine because it's impossible to make this part of the connection reliable. Fortunately, this will not affect the actual file transmission: the client will always be able to save the file correctly.

## Adverse Network Conditions
Overall, the protocol is able to handle a variety of network conditions: packet loss, delays, reordering and jitter. Note that packet corruption is automatically handled by the UDP layer by using a checksum.

## Benchmarks

The implementation is able to achieve a max transfer speed of 2.6 Gbps with a 16 KB packet size.

| Packet size (bytes) | Throughput (Mbps) |
|---------------------|-------------------|
|                  16 |              5.41 |
|                  32 |             10.52 |
|                  64 |             21.28 |
|                 128 |             41.98 |
|                 256 |             84.40 |
|                 512 |            163.32 |
|                1024 |            333.57 |
|                2048 |            600.65 |
|                4096 |           1112.82 |
|                8192 |           1719.78 |
|               16384 |           2664.42 |
|               32786 |           1252.57 |

The following benchmark is for transmitting a 14 KB file with 1024 B packet size and a 1 sec timeout for re-transmission. Packet loss was simulated using [netem](https://wiki.linuxfoundation.org/networking/netem).

| Packet loss (%) | Elapsed time (s) |
|-----------------|------------------|
|               0 |            0.001 |
|               5 |            3.419 |
|              10 |            5.338 |
|              20 |            9.104 |
|              40 |           11.327 |
|              60 |           79.670 |
|              80 |          109.630 |

## Future Improvements
The server keeps the entire file to be transmitted in memory the entire time. This is not feasible for files that exceed the available memory on the machine.

Another nice extension to the protocol would be support for reliably sending a file the other way: from client to server.

## What is the C code?
The C program is a small exercise for downloading websites over HTTP. It exists in the same repository because it was also part of my networks course.

## Author
Rupanshu Soi, Department of Computer Science, BITS Pilani - Hyderabad Campus, India.
