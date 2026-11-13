#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/common.sh"

install_interfaces_template "${DIR}/interfaces-dmz" enp0s8
install -m 644 "${DIR}/dmz.conf" /etc/sysctl.d/99-siai-dmz.conf
sysctl -p /etc/sysctl.d/99-siai-dmz.conf >/dev/null

echo "interfaces are setup!"