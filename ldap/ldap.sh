#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN="dom.pt" # must match the suffix used in the LDIF files
SUFFIX="dc=dom,dc=pt"

read -rp "LDAP server name [ldap.dom.pt]: " HOST
HOST=${HOST:-ldap.dom.pt}
read -rsp "Admin (cn=admin) password: " ADMIN_PW
echo
read -rsp "Password for the 4 users: " USER_PW
echo

# Install (no-op if already there) and reconfigure with the right suffix
echo "slapd slapd/domain string $DOMAIN" | debconf-set-selections
echo "slapd shared/organization string $DOMAIN" | debconf-set-selections
echo "slapd slapd/password1 password $ADMIN_PW" | debconf-set-selections
echo "slapd slapd/password2 password $ADMIN_PW" | debconf-set-selections
echo "slapd slapd/backend select MDB" | debconf-set-selections
echo "slapd slapd/purge_database boolean true" | debconf-set-selections
echo "slapd slapd/move_old_database boolean true" | debconf-set-selections
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y slapd ldap-utils
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive slapd

# Certificates (01_tls.ldif expects these exact paths)
install -m 644 "$DIR/certs/ca.crt" /usr/local/share/ca-certificates/dom_ca.crt
install -m 644 "$DIR/certs/ca.crt" /etc/ssl/certs/dom_ca.crt
update-ca-certificates
install -m 644 "$DIR/certs/ldap.crt" /etc/ssl/certs/ldap.crt
install -m 600 -o openldap -g openldap "$DIR/certs/ldap.key" /etc/ssl/private/ldap.key
adduser --quiet openldap ssl-cert # lets openldap traverse /etc/ssl/private

# TLS config, then listen on ldaps too
ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f "$DIR/ldif/01_tls.ldif"
sed -i 's|^SLAPD_SERVICES=.*|SLAPD_SERVICES="ldap:/// ldaps:/// ldapi:///"|' /etc/default/slapd
systemctl restart slapd
sleep 2

# Structure: the LDIF has a __PASSWORD_HASH__ placeholder filled in at load time
HASH="$(slappasswd -s "$USER_PW")"
sed "s|__PASSWORD_HASH__|$HASH|g" "$DIR/ldif/02_structure.ldif" |
  ldapadd -x -H ldapi:/// -D "cn=admin,$SUFFIX" -w "$ADMIN_PW"

# Quick test: LDAPS with certificate validation
LDAPTLS_CACERT=/etc/ssl/certs/ca-certificates.crt \
  ldapwhoami -x -H "ldaps://$HOST" -D "uid=mgr1,ou=people,$SUFFIX" -w "$USER_PW" &&
  echo "OK: LDAPS works" ||
  echo "LDAPS test failed (does $HOST resolve? try adding it to /etc/hosts)"
