#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# SIAI Practical Assignment #1 - BIND9 Slave DNS Setup (dns2 on gw.usa.dom.pt)
# Deploys slave forward and reverse zones and TSIG authenticated transfers
# ------------------------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || {
  echo "Error: This script must be run as root." >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Deploying BIND9 Slave DNS (dns2.dom.pt) ==="

# 1. Install BIND9 Packages
echo "[1/4] Installing BIND9 and DNS utilities..."
DEBIAN_FRONTEND=noninteractive apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y bind9 bind9utils bind9-dnsutils

# 2. Deploy TSIG Key
echo "[2/4] Deploying shared TSIG key..."
install -m 640 -o root -g bind "$DIR/../tsig.key" /etc/bind/tsig.key

# 3. Deploy Configuration Files
echo "[3/4] Deploying named.conf.options and named.conf.local..."
install -m 644 "$DIR/named.conf.options" /etc/bind/named.conf.options
install -m 644 "$DIR/named.conf.local" /etc/bind/named.conf.local

# Ensure /var/lib/bind is writable by bind for slave zone files
install -d -m 775 -o bind -g bind /var/lib/bind

# 4. Validate Syntax and Restart
echo "[4/4] Validating configuration and starting BIND9..."
named-checkconf /etc/bind/named.conf

systemctl restart named
systemctl enable named

echo
echo "=== BIND9 Slave Status ==="
systemctl status named --no-pager | head -n 12
echo
echo "✔ BIND9 Slave deployed on gw.usa!"
