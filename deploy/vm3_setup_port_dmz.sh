#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - Full Setup for VM 3: PORT DMZ Server (port-dmz)
# Roles:
#   1. OpenLDAP Server (ldap.port.dom.pt - 172.16.20.10) with TLS/LDAPS
#   2. Primary Mail Server (mail.port.dom.pt - 172.16.20.20)
#   3. LDAP Client (NSS/PAM for user resolution & AllowGroups managers)
#   4. Strict SSH Server (Public Key only, managers only, ssh.dom.pt only)
#   5. Mail Dummy Service (SMTP 25, Webmail 80, POP3 110, IMAP 143)
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================================================"
echo " Starting Full Automated Provisioning for VM 3: PORT DMZ Server"
echo "========================================================================"

# --- 1. Hostname & Network Setup via dmz.sh ---
echo ""
echo "[*] Step 1: Setting Hostname and configuring DHCP interfaces via networking/dmz.sh..."
hostnamectl set-hostname port-dmz.port.dom.pt || hostname port-dmz.port.dom.pt
echo "127.0.1.1 port-dmz.port.dom.pt port-dmz" >> /etc/hosts 2>/dev/null || true

# Execute dmz.sh to install /etc/network/interfaces with DHCP for enp0s3 and enp0s8
bash "${PROJECT_ROOT}/networking/dmz.sh"

# Fallback: In case the VM only has 1 NIC attached in VirtualBox, ensure secondary IP exists as alias
if ! ip addr show | grep -q "172.16.20.20"; then
    PRIMARY_IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
    if [ -n "$PRIMARY_IFACE" ]; then
        echo "[+] Adding secondary alias 172.16.20.20/24 on ${PRIMARY_IFACE}..."
        ip addr add 172.16.20.20/24 dev "${PRIMARY_IFACE}" label "${PRIMARY_IFACE}:mail" 2>/dev/null || true
    fi
fi

# --- 2. OpenLDAP Server Configuration ---
echo ""
echo "[*] Step 2: Deploying OpenLDAP Server with TLS (ldap.sh)..."
bash "${PROJECT_ROOT}/ldap/ldap.sh"

# --- 3. LDAP Client (NSS / PAM) Setup ---
echo ""
echo "[*] Step 3: Configuring Local NSS/PAM to authenticate via LDAP..."
bash "${SCRIPT_DIR}/setup_ldap_client_helper.sh"

# --- 4. SSH Server Hardening for Mail Server ---
echo ""
echo "[*] Step 4: Configuring Strict SSH Access (AllowGroups managers, Gateway only)..."
bash "${PROJECT_ROOT}/ssh/mail-servers/setup_mail_ssh.sh"
bash "${PROJECT_ROOT}/ssh/keys/setup_keys.sh"

# --- 5. Mail Dummy Service (SMTP, Webmail, POP3, IMAP) ---
echo ""
echo "[*] Step 5: Deploying Primary Mail Dummy Service..."
bash "${PROJECT_ROOT}/mail-dummy/setup_mail_dummy.sh" port

# --- 6. Final Status Summary ---
echo ""
echo "========================================================================"
echo " VM 3 Provisioning Finished! Service Statuses:"
echo "========================================================================"
for svc in slapd nslcd ssh siai-mail-dummy; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "  [✓] $svc : \e[32mACTIVE (RUNNING)\e[0m"
    else
        echo -e "  [!] $svc : \e[33m$(systemctl is-active $svc 2>/dev/null || echo 'UNKNOWN')\e[0m"
    fi
done

echo ""
echo "Next step: Boot up VM 4 (usa-dmz) and run vm4_setup_usa_dmz.sh"
echo "========================================================================"
