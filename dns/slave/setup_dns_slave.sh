#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEBIAN_FRONTEND=noninteractive apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y bind9 bind9utils bind9-dnsutils


install -m 640 -o root -g bind "$DIR/../tsig.key" /etc/bind/tsig.key
install -m 644 "$DIR/named.conf.options" /etc/bind/named.conf.options
install -m 644 "$DIR/named.conf.local" /etc/bind/named.conf.local
install -d -m 775 -o bind -g bind /var/lib/bind

systemctl restart named
systemctl enable named

echo "slave dns server deployed!"
