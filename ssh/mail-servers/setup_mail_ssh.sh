#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - Setup Mail Server SSH & Access Restrictions
# Run on: mail.port.dom.pt and smtp2.usa.dom.pt
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root." >&2
    exit 1
fi

echo "[+] ==========================================================="
echo "[+] Configuring SSH on Mail Server ($(hostname -f 2>/dev/null || hostname))"
echo "[+] ==========================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Install OpenSSH server if not installed
if ! dpkg -s openssh-server >/dev/null 2>&1; then
    echo "[+] Installing openssh-server..."
    apt-get update -qq && apt-get install -y openssh-server
fi

# 2. Ensure /etc/ssh/sshd_config includes drop-in directory
mkdir -p /etc/ssh/sshd_config.d
if ! grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
    echo "[+] Adding Include directive to /etc/ssh/sshd_config..."
    sed -i '1s|^|Include /etc/ssh/sshd_config.d/*.conf\n|' /etc/ssh/sshd_config
fi

# 3. Copy SIAI mail server SSH configuration
echo "[+] Deploying /etc/ssh/sshd_config.d/siai-mail.conf..."
cp "${SCRIPT_DIR}/sshd_config.d/siai-mail.conf" /etc/ssh/sshd_config.d/siai-mail.conf
chmod 644 /etc/ssh/sshd_config.d/siai-mail.conf

# 4. Enable pam_mkhomedir so LDAP users automatically get a home directory
echo "[+] Configuring PAM home directory creation (pam_mkhomedir)..."
if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
    echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0077" >> /etc/pam.d/common-session
fi

# 5. Configure firewall (nftables/iptables) to drop direct SSH from unauthorized IPs
echo "[+] Enforcing kernel-level network filtering for port 22..."
if command -v nft >/dev/null 2>&1; then
    nft list table inet filter >/dev/null 2>&1 || nft add table inet filter
    nft list chain inet filter input >/dev/null 2>&1 || nft add chain inet filter input { type filter hook input priority 0 \; }
    # Allow loopback, established, and SSH from gateway IPs only
    nft add rule inet filter input iif "lo" accept
    nft add rule inet filter input ct state established,related accept
    nft add rule inet filter input tcp dport 22 ip saddr { 172.16.20.1, 10.10.254.1, 10.10.20.1 } accept
    nft add rule inet filter input tcp dport 22 drop
    echo "[+] nftables rule applied: SSH accepted only from ssh.dom.pt."
elif command -v iptables >/dev/null 2>&1; then
    iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -A INPUT -i lo -j ACCEPT
    iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -C INPUT -p tcp --dport 22 -s 172.16.20.1 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport 22 -s 172.16.20.1 -j ACCEPT
    iptables -C INPUT -p tcp --dport 22 -s 10.10.254.1 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport 22 -s 10.10.254.1 -j ACCEPT
    iptables -C INPUT -p tcp --dport 22 -s 10.10.20.1 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport 22 -s 10.10.20.1 -j ACCEPT
    iptables -C INPUT -p tcp --dport 22 -j DROP 2>/dev/null || iptables -A INPUT -p tcp --dport 22 -j DROP
    echo "[+] iptables rule applied: SSH accepted only from ssh.dom.pt."
fi

# 6. Test configuration syntax and reload SSH
echo "[+] Validating sshd configuration..."
sshd -t

systemctl restart ssh || systemctl restart sshd
echo "[+] OpenSSH service reloaded successfully."
echo "[+] Mail server SSH is secured:"
echo "    - Direct root login: DISABLED"
echo "    - Password authentication: DISABLED"
echo "    - Public key authentication: ENABLED"
echo "    - Allowed groups: managers only (developers rejected)"
echo "    - Source restriction: Connections accepted only from ssh.dom.pt"
