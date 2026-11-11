#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEBIAN_FRONTEND=noninteractive apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y libnss-ldapd libpam-ldapd nslcd ldap-utils

install -m 644 "$DIR/certs/ca.crt" /usr/local/share/ca-certificates/dom_ca.crt
update-ca-certificates

cat > /etc/ldap/ldap.conf <<EOF
BASE    dc=dom,dc=pt
URI     ldaps://ldap.dom.pt:636 ldap://ldap.dom.pt:389
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
TLS_REQCERT demand
EOF

cat > /etc/nslcd.conf <<EOF
uid nslcd
gid nslcd
uri ldap://ldap.dom.pt:389
base dc=dom,dc=pt
ssl start_tls
tls_cacertfile /etc/ssl/certs/ca-certificates.crt
tls_reqcert demand
EOF
chmod 600 /etc/nslcd.conf
chown nslcd:nslcd /etc/nslcd.conf 2>/dev/null || true

for db in passwd group shadow; do
    if ! grep -q "^${db}:.*ldap" /etc/nsswitch.conf; then
        sed -i "s/^${db}:.*/& ldap/" /etc/nsswitch.conf
    fi
done

if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
    echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" >> /etc/pam.d/common-session
fi

systemctl restart nslcd
systemctl enable nslcd

echo "LDAP client deployed!"
