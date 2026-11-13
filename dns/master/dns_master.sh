#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEBIAN_FRONTEND=noninteractive apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y bind9 bind9utils bind9-dnsutils

systemctl stop named 2>/dev/null || true

install -m 640 -o root -g bind "$DIR/../tsig.key" /etc/bind/tsig.key
install -m 644 "$DIR/named.conf.options" /etc/bind/named.conf.options
install -m 644 "$DIR/named.conf.local" /etc/bind/named.conf.local
install -d -m 775 -o bind -g bind /var/lib/bind
rm -f /var/lib/bind/*.jnl /var/lib/bind/*.jbk
for zonefile in "$DIR/zones/"*; do
  filename="$(basename "$zonefile")"
  install -m 644 -o bind -g bind "$zonefile" "/var/lib/bind/$filename"
done

named-checkconf
named-checkzone dom.pt /var/lib/bind/dom.pt.db
named-checkzone port.dom.pt /var/lib/bind/port.dom.pt.db
named-checkzone usa.dom.pt /var/lib/bind/usa.dom.pt.db
named-checkzone 20.10.10.in-addr.arpa /var/lib/bind/INTERNAL_PORT_rev.db
named-checkzone 20.16.172.in-addr.arpa /var/lib/bind/DMZ_PORT_rev.db
named-checkzone 40.10.10.in-addr.arpa /var/lib/bind/INTERNAL_USA_rev.db
named-checkzone 40.16.172.in-addr.arpa /var/lib/bind/DMZ_USA_rev.db

systemctl restart named
systemctl enable named

echo "Master dns server deployed!"
