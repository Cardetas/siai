#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y slapd ldap-utils

cp "$DIR/certs/ca.crt" /etc/ssl/certs/dom_ca.crt
cp "$DIR/certs/ca.crt" /usr/local/share/ca-certificates/dom_ca.crt
update-ca-certificates

cp "$DIR/certs/ldap.crt" /etc/ssl/certs/ldap.crt
cp "$DIR/certs/ldap.key" /etc/ssl/private/ldap.key

chown openldap:openldap /etc/ssl/private/ldap.key
chmod 600 /etc/ssl/private/ldap.key

for schema in cosine nis inetorgperson; do
  ldapadd -Y EXTERNAL -H ldapi:/// -f "/etc/ldap/schema/${schema}.ldif" 2>/dev/null || true
done

ldapmodify -Y EXTERNAL -H ldapi:/// -f "$DIR/ldif/01_tls.ldif"

sed -i 's|^SLAPD_SERVICES=.*|SLAPD_SERVICES="ldap:/// ldaps:/// ldapi:///"|' /etc/default/slapd
systemctl restart slapd

ldapadd -Y EXTERNAL -H ldapi:/// -f "$DIR/ldif/02_structure.ldif" || true
