#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - Full Setup for VM 1: Router PORT (gw.port.dom.pt)
# Roles:
#   1. Routing, IPv4 Forwarding & NAT Masquerading
#   2. Kea DHCP & Dynamic DNS (kea-dhcp4 + kea-dhcp-ddns)
#   3. BIND9 DNS Master (with DNSSEC on dom.pt)
#   4. SSH Bastion / Gateway (ssh.dom.pt)
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================================================"
echo " Starting Full Automated Provisioning for VM 1: gw.port.dom.pt"
echo "========================================================================"

# --- 1. Hostname Configuration ---
echo ""
echo "[*] Step 1: Setting Hostname to gw.port.dom.pt..."
hostnamectl set-hostname gw.port.dom.pt || hostname gw.port.dom.pt
echo "127.0.1.1 gw.port.dom.pt gw" >> /etc/hosts 2>/dev/null || true

sleep 2

# --- 2. Network Routing, Forwarding & NAT Masquerading ---
echo ""
echo "[*] Step 2: Configuring Network Interfaces, Forwarding & NAT..."
bash "${PROJECT_ROOT}/networking/gw_port.sh"

# --- 3. Kea DHCP & Dynamic DNS ---
echo ""
echo "[*] Step 3: Provisioning Kea DHCP4 and Kea DDNS..."
bash "${PROJECT_ROOT}/dhcp/gw-port/setup_dhcp.sh"

# --- 4. BIND9 Master DNS with DNSSEC ---
echo ""
echo "[*] Step 4: Provisioning BIND9 Master DNS..."
bash "${PROJECT_ROOT}/dns/master/setup_dns_master.sh"

# --- 5. SSH Gateway & Jump Host Configuration ---
echo ""
echo "[*] Step 5: Configuring SSH Gateway (ssh.dom.pt)..."
bash "${PROJECT_ROOT}/ssh/gateway/setup_gateway_ssh.sh"

# --- 6. Final Status Summary ---
echo ""
echo "========================================================================"
echo " VM 1 Provisioning Finished! Service Statuses:"
echo "========================================================================"
for svc in kea-dhcp4-server kea-dhcp-ddns-server named ssh; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "  [✓] $svc : \e[32mACTIVE (RUNNING)\e[0m"
    else
        echo -e "  [!] $svc : \e[33m$(systemctl is-active $svc 2>/dev/null || echo 'UNKNOWN')\e[0m"
    fi
done

echo ""
echo "Next step: Boot up VM 2 (gw.usa.dom.pt) and run vm2_setup_gw_usa.sh"
echo "========================================================================"
