#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEBIAN_FRONTEND=noninteractive apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y kea-dhcp4-server kea-dhcp-ddns-server

[ -f /etc/kea/kea-dhcp4.conf ] && cp /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.bak
[ -f /etc/kea/kea-dhcp-ddns.conf ] && cp /etc/kea/kea-dhcp-ddns.conf /etc/kea/kea-dhcp-ddns.conf.bak

install -m 644 "$DIR/kea-dhcp4.conf" /etc/kea/kea-dhcp4.conf
install -m 644 "$DIR/kea-dhcp-ddns.conf" /etc/kea/kea-dhcp-ddns.conf

kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
kea-dhcp-ddns -t /etc/kea/kea-dhcp-ddns.conf

systemctl restart kea-dhcp-ddns-server
systemctl restart kea-dhcp4-server
systemctl enable kea-dhcp-ddns-server kea-dhcp4-server

echo "Kea DHCP deployed!"