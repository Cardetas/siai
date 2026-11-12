#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat > /etc/sysctl.d/99-siai-forwarding.conf <<EOF
net.ipv4.ip_forward = 1
EOF
sysctl -p /etc/sysctl.d/99-siai-forwarding.conf >/dev/null

ifdown -a
if [ -f /etc/network/interfaces ]; then
  cp /etc/network/interfaces /etc/network/interfaces.bak
fi
install -m 644 "$DIR/interfaces-gw-usa" /etc/network/interfaces
cat > /etc/resolv.conf <<EOF
nameserver 10.10.254.1
nameserver 127.0.0.1
search port.dom.pt usa.dom.pt dom.pt
EOF

systemctl restart networking 2>/dev/null

echo "ip forwarding, interfaces, and dns resolver are setup!"