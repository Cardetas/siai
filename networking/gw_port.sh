#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat > /etc/sysctl.d/99-siai-forwarding.conf <<EOF
net.ipv4.ip_forward = 1
EOF
sysctl -p /etc/sysctl.d/99-siai-forwarding.conf >/dev/null

ifdown -a
if [ -f /etc/network/interfaces ]; then
  cp /etc/network/interfaces /etc/network/interfaces.bak
fi
install -m 644 "$DIR/interfaces-gw-port" /etc/network/interfaces
cat > /etc/resolv.conf.head <<EOF
nameserver 127.0.0.1
nameserver 10.10.254.2
search port.dom.pt usa.dom.pt dom.pt
EOF

systemctl restart networking 2>/dev/null

echo "Waiting for Internet connection on enp0s10..."
count=0
until ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1 || [ $count -ge 15 ]; do
    sleep 1
    count=$((count + 1))
done

DEBIAN_FRONTEND=noninteractive apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y nftables

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

echo "ip forwarding, interfaces and nat are setup!"