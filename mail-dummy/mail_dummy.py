#!/usr/bin/env python3
"""
SIAI 2026/2027 - Mail Dummy Service
Runs on:
  - mail.port.dom.pt (172.16.20.20): SMTP (25), Webmail (80), POP3 (110), IMAP (143)
  - smtp2.usa.dom.pt (172.16.40.20): SMTP (25) [Backup MX]
"""

import socket
import threading
import sys
import argparse

def handle_smtp(conn, addr, hostname):
    try:
        conn.sendall(f"220 {hostname} ESMTP SIAI Mail Server ready\r\n".encode())
        while True:
            data = conn.recv(1024)
            if not data:
                break
            line = data.decode('utf-8', errors='ignore').strip()
            cmd = line.split()[0].upper() if line else ""
            if cmd in ("HELO", "EHLO"):
                conn.sendall(f"250-{hostname} Hello\r\n250-SIZE 52428800\r\n250-8BITMIME\r\n250 OK\r\n".encode())
            elif cmd == "MAIL":
                conn.sendall(b"250 2.1.0 Ok\r\n")
            elif cmd == "RCPT":
                conn.sendall(b"250 2.1.5 Ok\r\n")
            elif cmd == "DATA":
                conn.sendall(b"354 End data with <CR><LF>.<CR><LF>\r\n")
            elif cmd == "QUIT":
                conn.sendall(b"221 2.0.0 Bye\r\n")
                break
            elif cmd == "RSET":
                conn.sendall(b"250 2.0.0 Ok\r\n")
            elif cmd == "NOOP":
                conn.sendall(b"250 2.0.0 Ok\r\n")
            else:
                conn.sendall(b"502 5.5.2 Error: command not recognized\r\n")
    except Exception:
        pass
    finally:
        conn.close()

def smtp_listener(port, hostname):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', port))
        server.listen(10)
        print(f"[+] SMTP listener active on port {port} ({hostname})")
        while True:
            conn, addr = server.accept()
            threading.Thread(target=handle_smtp, args=(conn, addr, hostname), daemon=True).start()
    except Exception as e:
        print(f"[-] SMTP listener error: {e}", file=sys.stderr)

def handle_pop3(conn, addr, hostname):
    try:
        conn.sendall(f"+OK POP3 {hostname} SIAI server ready\r\n".encode())
        while True:
            data = conn.recv(1024)
            if not data:
                break
            line = data.decode('utf-8', errors='ignore').strip()
            cmd = line.split()[0].upper() if line else ""
            if cmd == "USER":
                conn.sendall(b"+OK User accepted\r\n")
            elif cmd == "PASS":
                conn.sendall(b"+OK Password accepted, 0 messages\r\n")
            elif cmd == "STAT":
                conn.sendall(b"+OK 0 0\r\n")
            elif cmd == "QUIT":
                conn.sendall(b"+OK POP3 server signing off\r\n")
                break
            else:
                conn.sendall(b"+OK\r\n")
    except Exception:
        pass
    finally:
        conn.close()

def pop3_listener(port, hostname):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', port))
        server.listen(10)
        print(f"[+] POP3 listener active on port {port} ({hostname})")
        while True:
            conn, addr = server.accept()
            threading.Thread(target=handle_pop3, args=(conn, addr, hostname), daemon=True).start()
    except Exception as e:
        print(f"[-] POP3 listener error: {e}", file=sys.stderr)

def handle_imap(conn, addr, hostname):
    try:
        conn.sendall(f"* OK [CAPABILITY IMAP4rev1] {hostname} IMAP4rev1 Service Ready\r\n".encode())
        while True:
            data = conn.recv(1024)
            if not data:
                break
            line = data.decode('utf-8', errors='ignore').strip()
            parts = line.split()
            tag = parts[0] if parts else "a001"
            cmd = parts[1].upper() if len(parts) > 1 else ""
            if cmd == "CAPABILITY":
                conn.sendall(f"* CAPABILITY IMAP4rev1\r\n{tag} OK CAPABILITY completed\r\n".encode())
            elif cmd == "LOGIN":
                conn.sendall(f"{tag} OK LOGIN completed\r\n".encode())
            elif cmd == "LOGOUT":
                conn.sendall(f"* BYE IMAP4rev1 Server logging out\r\n{tag} OK LOGOUT completed\r\n".encode())
                break
            else:
                conn.sendall(f"{tag} OK {cmd} completed\r\n".encode())
    except Exception:
        pass
    finally:
        conn.close()

def imap_listener(port, hostname):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', port))
        server.listen(10)
        print(f"[+] IMAP listener active on port {port} ({hostname})")
        while True:
            conn, addr = server.accept()
            threading.Thread(target=handle_imap, args=(conn, addr, hostname), daemon=True).start()
    except Exception as e:
        print(f"[-] IMAP listener error: {e}", file=sys.stderr)

def handle_webmail(conn, addr):
    try:
        request = conn.recv(1024).decode('utf-8', errors='ignore')
        body = (
            "<!DOCTYPE html>\n"
            "<html><head><title>SIAI Webmail</title></head>\n"
            "<body style='font-family: sans-serif; margin: 40px;'>\n"
            "<h1>SIAI 2026/2027 - Webmail Portal</h1>\n"
            "<p><strong>Host:</strong> webmail.dom.pt / mail.dom.pt</p>\n"
            "<p><strong>Server:</strong> mail.port.dom.pt (172.16.20.20)</p>\n"
            "<p><strong>Status:</strong> Ready (Dummy Webmail Service Active)</p>\n"
            "</body></html>\n"
        )
        response = (
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: text/html; charset=utf-8\r\n"
            f"Content-Length: {len(body.encode('utf-8'))}\r\n"
            "Server: SIAI-Dummy-Webmail/1.0\r\n"
            "Connection: close\r\n\r\n" + body
        )
        conn.sendall(response.encode('utf-8'))
    except Exception:
        pass
    finally:
        conn.close()

def webmail_listener(port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', port))
        server.listen(10)
        print(f"[+] Webmail HTTP listener active on port {port}")
        while True:
            conn, addr = server.accept()
            threading.Thread(target=handle_webmail, args=(conn, addr), daemon=True).start()
    except Exception as e:
        print(f"[-] Webmail listener error: {e}", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser(description="SIAI Mail Dummy Service")
    parser.add_argument("--role", choices=["port", "usa", "auto"], default="auto",
                        help="Role of the machine: port (primary mail) or usa (backup MX)")
    args = parser.parse_args()

    role = args.role
    if role == "auto":
        hostname = socket.gethostname()
        if "usa" in hostname.lower():
            role = "usa"
        else:
            role = "port"

    threads = []
    if role == "usa":
        print("=" * 60)
        print(" SIAI 2026/2027 - Backup Mail Service (smtp2.usa.dom.pt)")
        print("=" * 60)
        t_smtp = threading.Thread(target=smtp_listener, args=(25, "smtp2.usa.dom.pt"), daemon=True)
        threads.append(t_smtp)
    else:
        print("=" * 60)
        print(" SIAI 2026/2027 - Primary Mail Service (mail.port.dom.pt)")
        print("=" * 60)
        t_smtp = threading.Thread(target=smtp_listener, args=(25, "mail.port.dom.pt"), daemon=True)
        t_pop3 = threading.Thread(target=pop3_listener, args=(110, "mail.port.dom.pt"), daemon=True)
        t_imap = threading.Thread(target=imap_listener, args=(143, "mail.port.dom.pt"), daemon=True)
        t_web = threading.Thread(target=webmail_listener, args=(80,), daemon=True)
        threads.extend([t_smtp, t_pop3, t_imap, t_web])

    for t in threads:
        t.start()
    for t in threads:
        t.join()

if __name__ == '__main__':
    main()
