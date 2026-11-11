#!/usr/bin/env python3
"""
SIAI 2026/2027 - Web & FTP Dummy Service
Runs on web.usa.dom.pt (172.16.40.10)
Listens on:
  - Port 80 (HTTP): Serves web.dom.pt / web.usa.dom.pt
  - Port 21 (FTP):  Serves ftp.dom.pt with FTP banner
"""

import socket
import threading
import sys

HTTP_PORT = 80
FTP_PORT = 21

def handle_http_client(conn, addr):
    try:
        request = conn.recv(1024).decode('utf-8', errors='ignore')
        # Extract Host header if present
        host_header = "web.dom.pt"
        for line in request.splitlines():
            if line.lower().startswith("host:"):
                host_header = line.split(":", 1)[1].strip()
                break

        body = (
            f"<!DOCTYPE html>\n"
            f"<html><head><title>{host_header}</title></head>\n"
            f"<body style='font-family: sans-serif; margin: 40px;'>\n"
            f"<h1>SIAI 2026/2027 - Web Server</h1>\n"
            f"<p><strong>Requested Host:</strong> {host_header}</p>\n"
            f"<p><strong>Resolved Machine:</strong> web.usa.dom.pt (172.16.40.10)</p>\n"
            f"<p><strong>Status:</strong> 200 OK (Dummy HTTP Service Active)</p>\n"
            f"</body></html>\n"
        )
        response = (
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: text/html; charset=utf-8\r\n"
            f"Content-Length: {len(body.encode('utf-8'))}\r\n"
            "Server: SIAI-Dummy-Web/1.0\r\n"
            "Connection: close\r\n\r\n" + body
        )
        conn.sendall(response.encode('utf-8'))
    except Exception as e:
        pass
    finally:
        conn.close()

def http_listener():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', HTTP_PORT))
        server.listen(10)
        print(f"[+] HTTP listener active on port {HTTP_PORT}")
        while True:
            conn, addr = server.accept()
            threading.Thread(target=handle_http_client, args=(conn, addr), daemon=True).start()
    except Exception as e:
        print(f"[-] HTTP listener error: {e}", file=sys.stderr)

def handle_ftp_client(conn, addr):
    try:
        conn.sendall(b"220 ftp.dom.pt FTP server (SIAI Dummy FTP 2026/2027) ready.\r\n")
        while True:
            data = conn.recv(1024)
            if not data:
                break
            cmd = data.decode('utf-8', errors='ignore').strip().upper()
            if cmd.startswith("USER"):
                conn.sendall(b"331 Please specify the password.\r\n")
            elif cmd.startswith("PASS"):
                conn.sendall(b"230 Login successful.\r\n")
            elif cmd.startswith("QUIT"):
                conn.sendall(b"221 Goodbye.\r\n")
                break
            elif cmd.startswith("SYST"):
                conn.sendall(b"215 UNIX Type: L8\r\n")
            else:
                conn.sendall(b"200 Command okay.\r\n")
    except Exception:
        pass
    finally:
        conn.close()

def ftp_listener():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', FTP_PORT))
        server.listen(10)
        print(f"[+] FTP listener active on port {FTP_PORT}")
        while True:
            conn, addr = server.accept()
            threading.Thread(target=handle_ftp_client, args=(conn, addr), daemon=True).start()
    except Exception as e:
        print(f"[-] FTP listener error: {e}", file=sys.stderr)

def main():
    print("=" * 60)
    print(" SIAI 2026/2027 - Web & FTP Dummy Service (USA DMZ)")
    print("=" * 60)
    t_http = threading.Thread(target=http_listener, daemon=True)
    t_ftp = threading.Thread(target=ftp_listener, daemon=True)
    t_http.start()
    t_ftp.start()
    t_http.join()
    t_ftp.join()

if __name__ == '__main__':
    main()
