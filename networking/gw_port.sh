#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/4] Enabling permanent IPv4 forwarding..."
cat > /etc/sysctl.d/99-siai-forwarding.conf <<EOF
net.ipv4.ip_forward = 1
EOF
sysctl -p /etc/sysctl.d/99-siai-forwarding.conf >/dev/null

echo "[2/4] Installing /etc/network/interfaces..."
if [ -f /etc/network/interfaces ]; then
  cp /etc/network/interfaces /etc/network/interfaces.bak
fi
install -m 644 "$DIR/interfaces-gw-port" /etc/network/interfaces

systemctl restart networking 2>/dev/null
ifup enp0s10
dhclient enp0s10

# 3. Permanent NAT Masquerading via nftables
echo "[3/4] Configuring permanent NAT masquerading with nftables..."
DEBIAN_FRONTEND=noninteractive apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y nftables

# Internet interface is Adapter 4 (enp0s10) in interfaces-gw-port
INET_IFACE="enp0s10"
echo "Configuring NAT on Internet interface: $INET_IFACE"

cat > /etc/nftables.conf <<EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy accept;
    }
    chain forward {
        type filter hook forward priority filter; policy accept;
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}

table ip nat {
    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        oifname "$INET_IFACE" masquerade
    }
}
EOF

nft -f /etc/nftables.conf
systemctl enable --now nftables

# 4. Status & Self-Test
echo
echo "[4/4] Deployment complete! Verification:"
echo "--------------------------------------------------"
echo "Active Routing Table:"
ip route show
echo
echo "Active nftables NAT ruleset:"
nft list table ip nat
echo "--------------------------------------------------"
