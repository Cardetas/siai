#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "libnss-ldapd libnss-ldapd/nsswitch multiselect passwd, group, shadow" | debconf-set-selection
DEBIAN_FRONTEND=noninteractive apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y libnss-ldapd libpam-ldapd nslcd ldap-utils
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive libnss-ldapd

install -m 644 "$DIR/certs/ca.crt" /usr/local/share/ca-certificates/dom_ca.crt
update-ca-certificates

install -m 644 "$DIR/client/ldap.conf" /etc/ldap/ldap.conf
install -m 600 -o nslcd -g nslcd "$DIR/client/nslcd.conf" /etc/nslcd.conf

pam-auth-update --enable mkhomedir

systemctl restart nslcd
systemctl enable nslcd

echo "LDAP client deployed!"