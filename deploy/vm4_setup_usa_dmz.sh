#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - Full Setup for VM 4: USA DMZ Server (usa-dmz)
# Roles:
#   1. Web & FTP Server (web.usa.dom.pt - 172.16.40.10)
#   2. Backup Mail Server (smtp2.usa.dom.pt - 172.16.40.20)
#   3. LDAP Client (NSS/PAM for user resolution & AllowGroups managers)
#   4. Strict SSH Server (Public Key only, managers only, ssh.dom.pt only)
#   5. Web & FTP Dummy Service (HTTP 80, FTP 21)
#   6. Backup Mail Dummy Service (SMTP 25)
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================================================"
echo " Starting Full Automated Provisioning for VM 4: USA DMZ Server"
echo "========================================================================"

# --- 1. Hostname & Network Setup via dmz.sh ---
echo ""
echo "[*] Step 1: Setting Hostname and configuring DHCP interfaces via networking/dmz.sh..."
hostnamectl set-hostname usa-dmz.usa.dom.pt || hostname usa-dmz.usa.dom.pt
echo "127.0.1.1 usa-dmz.usa.dom.pt usa-dmz" >> /etc/hosts 2>/dev/null || true

# Execute dmz.sh to install /etc/network/interfaces with DHCP for enp0s3 and enp0s8
bash "${PROJECT_ROOT}/networking/dmz.sh"

# Fallback: In case the VM only has 1 NIC attached in VirtualBox, ensure secondary IP exists as alias
if ! ip addr show | grep -q "172.16.40.20"; then
    PRIMARY_IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
    if [ -n "$PRIMARY_IFACE" ]; then
        echo "[+] Adding secondary alias 172.16.40.20/24 on ${PRIMARY_IFACE}..."
        ip addr add 172.16.40.20/24 dev "${PRIMARY_IFACE}" label "${PRIMARY_IFACE}:smtp2" 2>/dev/null || true
    fi
fi

# --- 2. LDAP Client (NSS / PAM) Setup ---
echo ""
echo "[*] Step 2: Configuring Local NSS/PAM to authenticate via LDAP..."
bash "${SCRIPT_DIR}/setup_ldap_client_helper.sh"

# --- 3. SSH Server Hardening for Backup Mail Server ---
echo ""
echo "[*] Step 3: Configuring Strict SSH Access (AllowGroups managers, Gateway only)..."
bash "${PROJECT_ROOT}/ssh/mail-servers/setup_mail_ssh.sh"
bash "${PROJECT_ROOT}/ssh/keys/setup_keys.sh"

# --- 4. Web & FTP Dummy Service (HTTP 80, FTP 21) ---
echo ""
echo "[*] Step 4: Deploying Web & FTP Dummy Service..."
bash "${PROJECT_ROOT}/web-dummy/setup_web_dummy.sh"

# --- 5. Backup Mail Dummy Service (SMTP 25) ---
echo ""
echo "[*] Step 5: Deploying Backup Mail Dummy Service (smtp2.usa)..."
bash "${PROJECT_ROOT}/mail-dummy/setup_mail_dummy.sh" usa

# --- 6. Final Status Summary ---
echo ""
echo "========================================================================"
echo " VM 4 Provisioning Finished! Service Statuses:"
echo "========================================================================"
for svc in nslcd ssh siai-web-dummy siai-mail-dummy; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "  [✓] $svc : \e[32mACTIVE (RUNNING)\e[0m"
    else
        echo -e "  [!] $svc : \e[33m$(systemctl is-active $svc 2>/dev/null || echo 'UNKNOWN')\e[0m"
    fi
done

echo ""
echo "All 4 Server & Gateway VMs are fully configured!"
echo "========================================================================"
