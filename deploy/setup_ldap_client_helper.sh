#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - LDAP Client Setup Helper (NSS / PAM)
# Configures any machine (Mail Servers or Clients) to authenticate via OpenLDAP
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "[+] ==========================================================="
echo "[+] Configuring LDAP Client (NSS / PAM / StartTLS) on $(hostname)"
echo "[+] ==========================================================="

# 1. Install LDAP client packages non-interactively
export DEBIAN_FRONTEND=noninteractive
echo "[+] Installing libnss-ldapd, libpam-ldapd, nslcd, and ldap-utils..."
apt-get update -qq
apt-get install -y -q libnss-ldapd libpam-ldapd nslcd ldap-utils

# 2. Deploy CA Certificate
mkdir -p /etc/ssl/certs /etc/ldap
CA_SRC="${PROJECT_ROOT}/ldap/certs/ca.crt"
if [ -f "${CA_SRC}" ]; then
    echo "[+] Deploying CA certificate from project repository..."
    cp "${CA_SRC}" /etc/ssl/certs/ca.crt
    chmod 644 /etc/ssl/certs/ca.crt
elif [ ! -f /etc/ssl/certs/ca.crt ]; then
    echo "[!] Warning: ca.crt not found at ${CA_SRC}. Ensure /etc/ssl/certs/ca.crt is copied from the LDAP server."
fi

# 3. Configure /etc/ldap/ldap.conf
echo "[+] Configuring /etc/ldap/ldap.conf..."
cat > /etc/ldap/ldap.conf << 'EOF'
BASE    dc=dom,dc=pt
URI     ldap://ldap.dom.pt:389 ldaps://ldap.dom.pt:636
TLS_CACERT /etc/ssl/certs/ca.crt
TLS_REQCERT demand
EOF
chmod 644 /etc/ldap/ldap.conf

# 4. Configure /etc/nslcd.conf
echo "[+] Configuring /etc/nslcd.conf..."
cat > /etc/nslcd.conf << 'EOF'
uid nslcd
gid nslcd
uri ldap://ldap.dom.pt:389
base dc=dom,dc=pt
ssl start_tls
tls_cacertfile /etc/ssl/certs/ca.crt
tls_reqcert demand
EOF
chmod 600 /etc/nslcd.conf
chown nslcd:nslcd /etc/nslcd.conf 2>/dev/null || true

# 5. Configure /etc/nsswitch.conf
echo "[+] Updating /etc/nsswitch.conf..."
for db in passwd group shadow; do
    if ! grep -q "^${db}:.*ldap" /etc/nsswitch.conf; then
        sed -i "s/^${db}:.*/& ldap/" /etc/nsswitch.conf
    fi
done

# 6. Enable pam_mkhomedir in PAM common-session
echo "[+] Enabling pam_mkhomedir in /etc/pam.d/common-session..."
if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
    echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" >> /etc/pam.d/common-session
fi

# 7. Restart nslcd daemon
systemctl restart nslcd || service nslcd restart
echo "[+] nslcd restarted."

# 8. Test LDAP resolution
echo "[+] Testing LDAP resolution for mgr1..."
if getent passwd mgr1 >/dev/null 2>&1; then
    echo -e "\e[32m[✓] SUCCESS: LDAP user mgr1 resolved successfully:\e[0m"
    getent passwd mgr1
    getent group managers
else
    echo -e "\e[33m[!] Note: mgr1 not resolved yet. Make sure DNS (ldap.dom.pt) and LDAP server are running.\e[0m"
fi
