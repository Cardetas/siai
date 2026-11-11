#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - Setup SSH Gateway on gw.port.dom.pt (ssh.dom.pt)
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root." >&2
    exit 1
fi

echo "[+] ==========================================================="
echo "[+] Configuring SSH Gateway on $(hostname -f 2>/dev/null || hostname)"
echo "[+] ==========================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Install OpenSSH server if needed
if ! dpkg -s openssh-server >/dev/null 2>&1; then
    echo "[+] Installing openssh-server..."
    apt-get update -qq && apt-get install -y openssh-server
fi

# 2. Ensure /etc/ssh/sshd_config includes drop-ins
mkdir -p /etc/ssh/sshd_config.d
if ! grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
    echo "[+] Adding Include directive to /etc/ssh/sshd_config..."
    sed -i '1s|^|Include /etc/ssh/sshd_config.d/*.conf\n|' /etc/ssh/sshd_config
fi

# 3. Deploy gateway sshd configuration
echo "[+] Deploying /etc/ssh/sshd_config.d/siai-gateway.conf..."
cp "${SCRIPT_DIR}/sshd_config.d/siai-gateway.conf" /etc/ssh/sshd_config.d/siai-gateway.conf
chmod 644 /etc/ssh/sshd_config.d/siai-gateway.conf

# 4. Configure outgoing client shortcuts on gateway for mail servers
mkdir -p /etc/ssh/ssh_config.d
cat > /etc/ssh/ssh_config.d/siai-gateway-client.conf << 'EOF'
# SIAI Gateway shortcuts to mail servers
Host mail.port.dom.pt mail.dom.pt
    HostName 172.16.20.20
    StrictHostKeyChecking accept-new

Host smtp2.usa.dom.pt
    HostName 172.16.40.20
    StrictHostKeyChecking accept-new
EOF
chmod 644 /etc/ssh/ssh_config.d/siai-gateway-client.conf

# 5. Validate and restart sshd
echo "[+] Validating sshd configuration..."
sshd -t

systemctl restart ssh || systemctl restart sshd
echo "[+] SSH Gateway successfully configured on ssh.dom.pt (gw.port)."
echo "    - TCP Forwarding: ENABLED"
echo "    - Ready for ProxyJump (ssh -J) from client machines."
