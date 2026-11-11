#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "[-] Error: This script must be run as root." >&2
  exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[+] Installing DMZ network interfaces (/etc/network/interfaces)..."
if [ -f /etc/network/interfaces ]; then
  cp /etc/network/interfaces /etc/network/interfaces.bak
fi

install -m 644 "${DIR}/interfaces-dmz" /etc/network/interfaces

echo "[+] Cleaning old leases and flushing interface addresses..."
killall dhclient 2>/dev/null || true
ip addr flush dev enp0s3 2>/dev/null || true
ip addr flush dev enp0s8 2>/dev/null || true

echo "[+] Restarting networking service to acquire DHCP leases..."
systemctl restart networking 2>/dev/null || ifreload -a 2>/dev/null || ifup -a 2>/dev/null || true

# Bring up DHCP interfaces
ifup enp0s3 2>/dev/null || true
ifup enp0s8 2>/dev/null || true

# Wait briefly for DHCP lease acquisition
sleep 2

echo "[+] Current interface IP configuration:"
ip -br addr show enp0s3 2>/dev/null || true
ip -br addr show enp0s8 2>/dev/null || true
