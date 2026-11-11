#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# SIAI Practical Assignment #1 - Kea DHCP Setup for gw.usa.dom.pt
# Installs Kea DHCPv4 & Kea DHCP-DDNS, deploys configs, and enables services
# ------------------------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || {
  echo "Error: This script must be run as root." >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Deploying Kea DHCP on gw.usa.dom.pt ==="

# 1. Install Kea Packages
echo "[1/4] Installing Kea DHCPv4 and DDNS packages..."
DEBIAN_FRONTEND=noninteractive apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y kea-dhcp4-server kea-dhcp-ddns-server

# 2. Deploy Configuration Files
echo "[2/4] Deploying kea-dhcp4.conf and kea-dhcp-ddns.conf..."
mkdir -p /etc/kea/ /var/lib/kea/ /var/log/kea/ /run/kea/

[ -f /etc/kea/kea-dhcp4.conf ] && cp /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.bak
[ -f /etc/kea/kea-dhcp-ddns.conf ] && cp /etc/kea/kea-dhcp-ddns.conf /etc/kea/kea-dhcp-ddns.conf.bak

install -m 644 "$DIR/kea-dhcp4.conf" /etc/kea/kea-dhcp4.conf
install -m 644 "$DIR/kea-dhcp-ddns.conf" /etc/kea/kea-dhcp-ddns.conf

# Fix permissions for the _kea service user
KEA_USER="_kea"
if ! id -u "_kea" >/dev/null 2>&1; then
    if id -u "kea" >/dev/null 2>&1; then
        KEA_USER="kea"
    else
        KEA_USER="root"
    fi
fi
echo "[+] Setting directory and config ownership to ${KEA_USER}:${KEA_USER}..."
chown -R "${KEA_USER}:${KEA_USER}" /etc/kea/ /var/lib/kea/ /var/log/kea/ /run/kea/ 2>/dev/null || true
chmod 755 /etc/kea/ /var/lib/kea/ /var/log/kea/ /run/kea/
chmod 644 /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp-ddns.conf

# 3. Test Configuration Syntax
echo "[3/4] Validating Kea configuration syntax..."
kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
echo "✔ kea-dhcp4.conf syntax is valid."

# 4. Restart and Enable Services
echo "[4/4] Starting and enabling Kea services..."
systemctl restart kea-dhcp-ddns-server
systemctl restart kea-dhcp4-server
systemctl enable kea-dhcp-ddns-server kea-dhcp4-server

echo
echo "=== Kea DHCP Service Status ==="
systemctl status kea-dhcp4-server --no-pager | head -n 12
echo
echo "✔ Kea DHCP deployed on gw.usa!"
