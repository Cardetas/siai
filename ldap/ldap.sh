#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN="dom.pt"
SUFFIX="dc=dom,dc=pt"
HOST="ldap.dom.pt"

read -rsp "Admin (cn=admin) password: " ADMIN_PW
echo
read -rsp "Password for the 4 users: " USER_PW
echo


echo "slapd slapd/domain string $DOMAIN"          | debconf-set-selections
echo "slapd shared/organization string $DOMAIN"   | debconf-set-selections
echo "slapd slapd/password1 password $ADMIN_PW"   | debconf-set-selections
echo "slapd slapd/password2 password $ADMIN_PW"   | debconf-set-selections
echo "slapd slapd/backend select MDB"             | debconf-set-selections
echo "slapd slapd/purge_database boolean true"    | debconf-set-selections
echo "slapd slapd/move_old_database boolean true" | debconf-set-selections
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y slapd ldap-utils
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive slapd

echo "Loading auxiliary schemas (cosine, nis, inetorgperson)..."
for schema in cosine nis inetorgperson; do
  ldapadd -Y EXTERNAL -H ldapi:/// -f "/etc/ldap/schema/${schema}.ldif" 2>/dev/null || true
done

install -d -m 755 -o openldap -g openldap /etc/ldap/certs
install -m 644 -o openldap -g openldap "$DIR/certs/ca.crt" /etc/ldap/certs/dom_ca.crt
install -m 644 -o openldap -g openldap "$DIR/certs/ldap.crt" /etc/ldap/certs/ldap.crt
install -m 600 -o openldap -g openldap "$DIR/certs/ldap.key" /etc/ldap/certs/ldap.key


install -m 644 "$DIR/certs/ca.crt" /usr/local/share/ca-certificates/dom_ca.crt
update-ca-certificates

ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f "$DIR/ldif/01_tls.ldif"
sed -i 's|^SLAPD_SERVICES=.*|SLAPD_SERVICES="ldap:/// ldaps:/// ldapi:///"|' /etc/default/slapd
systemctl restart slapd
sleep 2

HASH="$(slappasswd -s "$USER_PW")"
echo "Populating directory tree (OUs, groups, users)..."
sed "s|__PASSWORD_HASH__|$HASH|g" "$DIR/ldif/02_structure.ldif" |
  ldapadd -c -x -H ldapi:/// -D "cn=admin,$SUFFIX" -w "$ADMIN_PW" || true


cat > /etc/ldap/ldap.conf <<EOF
BASE    $SUFFIX
URI     ldaps://$HOST
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
TLS_REQCERT demand
EOF

echo
echo "=== Testing LDAP Configuration ==="
# Test 1: LDAPS (port 636) with certificate validation
if LDAPTLS_CACERT=/etc/ssl/certs/ca-certificates.crt \
   ldapwhoami -x -H "ldaps://$HOST" -D "uid=mgr1,ou=people,$SUFFIX" -w "$USER_PW"; then
  echo "✔ OK: LDAPS authentication and certificate validation successful"
else
  echo "✖ LDAPS test failed (does '$HOST' resolve? If DNS is not yet ready, add '$HOST' to /etc/hosts)"
fi

# Test 2: StartTLS (port 389) with certificate validation
if LDAPTLS_CACERT=/etc/ssl/certs/ca-certificates.crt \
   ldapwhoami -x -ZZ -H "ldap://$HOST" -D "uid=mgr1,ou=people,$SUFFIX" -w "$USER_PW"; then
  echo "✔ OK: StartTLS authentication and certificate validation successful"
else
  echo "✖ StartTLS test failed"
fi
