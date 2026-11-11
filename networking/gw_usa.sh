#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}


DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/3] Enabling permanent IPv4 forwarding..."
cat > /etc/sysctl.d/99-siai-forwarding.conf <<EOF
net.ipv4.ip_forward = 1
EOF
sysctl -p /etc/sysctl.d/99-siai-forwarding.conf >/dev/null

echo "[2/3] Installing /etc/network/interfaces..."
if [ -f /etc/network/interfaces ]; then
  cp /etc/network/interfaces /etc/network/interfaces.bak
fi
install -m 644 "$DIR/interfaces-gw-usa" /etc/network/interfaces

systemctl restart networking 2>/dev/null


echo
echo "[3/3] Deployment complete! Verification:"
echo "--------------------------------------------------"
echo "Active Routing Table:"
ip route show
echo "--------------------------------------------------"

echo "Testing Internet reachability via gw.port NAT:"
if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
  echo "Internet connection via gw.port is working!"
else
  echo "ℹ Note: Internet not reachable yet. Ensure gw.port has NAT enabled (gw_port.sh)."
fi
