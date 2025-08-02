format ELF64 executable

PORT equ 15012 ;; port is 42042

SYS_read   equ 0
SYS_write  equ 1
SYS_close  equ 3
SYS_socket equ 41
SYS_accept equ 43
SYS_bind   equ 49
SYS_listen equ 50
SYS_exit   equ 60

STDIN  equ 0
STDOUT equ 1
STDERR equ 2

MAX_CONN equ 10

AF_INET     equ 2
SOCK_STREAM equ 1
INADDR_ANY  equ 0

macro syscall1 name, a{
    mov rax, name
    mov rdi, a
    syscall
}
macro syscall2 name, a,b{
    mov rax, name
    mov rdi, a
    mov rsi, b
    syscall
}
macro syscall3 name, a,b,c{
    mov rax, name
    mov rdi, a
    mov rsi, b
    mov rdx, c
    syscall
}

macro write fd, buf, len{
  syscall3 SYS_write, fd, buf, len
}

macro read fd, buf, len{
  syscall3 SYS_read, fd, buf, len
}

macro socket domain, type, protocol{
  syscall3 SYS_socket, domain, type, protocol
}

macro bind sockfd, addr, size{
  syscall3 SYS_bind, sockfd, addr, size
}

macro listen sockfd, backlog{
    syscall2 SYS_listen, sockfd, backlog
}

macro accept sockfd, addr, addr_len{
  syscall3 SYS_accept, sockfd, addr, addr_len
}

macro exit code{
  syscall1 SYS_exit, code
}

macro close fd{
  syscall1 SYS_close, fd
}

segment readable executable
entry main
main:
  write STDOUT, start_msg, start_msg_len

  write STDOUT, socket_msg, socket_msg_len
  socket AF_INET, SOCK_STREAM, 0
  cmp rax, 0
  jl error
  mov qword [sockfd], rax
  mov word [servaddr.sin_family], AF_INET
  mov word [servaddr.sin_port], PORT
  mov dword [servaddr.sin_addr], INADDR_ANY

  write STDOUT, bind_msg, bind_msg_len
  bind [sockfd], servaddr.sin_family, sizeof_servaddr
  cmp rax, 0
  jl error

  write STDOUT, listen_msg, listen_msg_len
  listen [sockfd], MAX_CONN
  cmp rax, 0
  jl error

next_request:
  write STDOUT, accept_msg, accept_msg_len
  accept [sockfd], cliaddr.sin_family, cliaddr_len
  cmp rax, 0
  jl error

  mov qword [connfd], rax

  write [connfd], response, response_len
  close [connfd]

  jmp next_request

  close [sockfd]
  exit 0

error:
  write STDERR, error_msg, error_msg_len
  close [sockfd]
  close [connfd]
  exit 1


segment readable writable
sockfd dq -1
connfd dq -1

struc servaddr_in{
  .sin_family dw 0
  .sin_port   dw 0
  .sin_addr   dd 0
  .sin_zero   dq 0
}
servaddr servaddr_in
cliaddr servaddr_in
sizeof_servaddr = $ - servaddr.sin_family
cliaddr_len dd sizeof_servaddr

start_msg db "starting", 10
start_msg_len = $ - start_msg

socket_msg db "socketing", 10
socket_msg_len = $ - socket_msg

bind_msg db "binding", 10
bind_msg_len = $ - bind_msg

listen_msg db "listening", 10
listen_msg_len = $ - listen_msg

accept_msg db "accepting", 10
accept_msg_len = $ - accept_msg

error_msg db "ERROR: exitting"
error_msg_len = $ - error_msg

;; TODO: read the response from a file and not from this
response db "HTTP/1.1 200 OK", 13, 10
         db "Content-Type: text/html; charset=utf-8", 13,10
         db "Connection: close", 13, 10
         db 13, 10
         db "<p>this website is hosted by assembly</p>"
         db "<p><a href='https://flatassembler.net/'>Flat Assembler</a>, used in this small project</p>"

response_len = $ - response
