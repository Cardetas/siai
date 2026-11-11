#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# SIAI Practical Assignment #1 - BIND9 Master DNS Setup (dns1 on gw.port.dom.pt)
# Deploys master forward and reverse zones, TSIG authentication, and DNSSEC
# ------------------------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || {
  echo "Error: This script must be run as root." >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Deploying BIND9 Master DNS (dns1.dom.pt) ==="

# 1. Install BIND9 Packages
echo "[1/5] Installing BIND9 and DNS utilities..."
DEBIAN_FRONTEND=noninteractive apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y bind9 bind9utils bind9-dnsutils

# 2. Deploy TSIG Key
echo "[2/5] Deploying shared TSIG key..."
install -m 640 -o root -g bind "$DIR/../tsig.key" /etc/bind/tsig.key

# 3. Deploy Configuration Files
echo "[3/5] Deploying named.conf.options and named.conf.local..."
install -m 644 "$DIR/named.conf.options" /etc/bind/named.conf.options
install -m 644 "$DIR/named.conf.local" /etc/bind/named.conf.local

# 4. Deploy Zone Files to /var/lib/bind/ (Required for dynamic updates & DNSSEC)
echo "[4/5] Deploying zone files to /var/lib/bind/..."
install -d -m 775 -o root -g bind /var/lib/bind

for zonefile in "$DIR/zones/"*; do
  filename="$(basename "$zonefile")"
  install -m 644 -o bind -g bind "$zonefile" "/var/lib/bind/$filename"
done

chown -R bind:bind /var/lib/bind

# 5. Validate Syntax and Restart
echo "[5/5] Validating configuration and zone files..."
named-checkconf /etc/bind/named.conf
named-checkzone dom.pt /var/lib/bind/db.dom.pt
named-checkzone port.dom.pt /var/lib/bind/db.port.dom.pt
named-checkzone usa.dom.pt /var/lib/bind/db.usa.dom.pt

systemctl restart named
systemctl enable named

echo
echo "=== BIND9 Master Status ==="
systemctl status named --no-pager | head -n 12
echo
echo "✔ BIND9 Master deployed on gw.port!"
