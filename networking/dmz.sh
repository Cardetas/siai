#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

echo "Installing /etc/network/interfaces..."
if [ -f /etc/network/interfaces ]; then
  cp /etc/network/interfaces /etc/network/interfaces.bak
fi
install -m 644 "$DIR/interfaces-gw-port" /etc/network/interfaces

systemctl restart networking 2>/dev/null