#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ifdown -a
if [ -f /etc/network/interfaces ]; then
  cp /etc/network/interfaces /etc/network/interfaces.bak
fi
install -m 644 "${DIR}/interfaces-dmz" /etc/network/interfaces
install -m 644 "${DIR}/dmz.conf" /etc/sysctl.d/99-siai-dmz.conf
sysctl -p /etc/sysctl.d/99-siai-dmz.conf >/dev/null

systemctl restart networking

echo "interfaces are setup!"