#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/common.sh"

cat > /etc/sysctl.d/99-siai-forwarding.conf <<EOF
net.ipv4.ip_forward = 1
EOF
sysctl -p /etc/sysctl.d/99-siai-forwarding.conf >/dev/null

install_interfaces_template "${DIR}/interfaces-gw-usa" enp0s8 enp0s9
cat > /etc/resolv.conf <<EOF
nameserver 127.0.0.1
nameserver 10.10.254.1
search usa.dom.pt port.dom.pt dom.pt
EOF

cat > /etc/apt/apt.conf.d/99force-ipv4 <<EOF
Acquire::ForceIPv4 "true";
Acquire::http::Pipeline-Depth "0";
EOF

echo "ip forwarding, interfaces, and dns resolver are setup!"