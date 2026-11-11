#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - Full Setup for VM 2: Router USA (gw.usa.dom.pt)
# Roles:
#   1. Routing, IPv4 Forwarding & Static Routes (Default GW -> 10.10.254.1)
#   2. Kea DHCP & Dynamic DNS (kea-dhcp4 + kea-dhcp-ddns)
#   3. BIND9 DNS Slave (Zone replication via TSIG from 10.10.254.1)
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================================================"
echo " Starting Full Automated Provisioning for VM 2: gw.usa.dom.pt"
echo "========================================================================"

# --- 1. Hostname Configuration ---
echo ""
echo "[*] Step 1: Setting Hostname to gw.usa.dom.pt..."
hostnamectl set-hostname gw.usa.dom.pt || hostname gw.usa.dom.pt
echo "127.0.1.1 gw.usa.dom.pt gw" >> /etc/hosts 2>/dev/null || true

# --- 2. Network Routing, Forwarding & Static Routes ---
echo ""
echo "[*] Step 2: Configuring Network Interfaces & Static Routes..."
bash "${PROJECT_ROOT}/networking/gw_usa.sh"

# --- 3. Kea DHCP & Dynamic DNS ---
echo ""
echo "[*] Step 3: Provisioning Kea DHCP4 and Kea DDNS..."
bash "${PROJECT_ROOT}/dhcp/gw-usa/setup_dhcp.sh"

# --- 4. BIND9 Slave DNS ---
echo ""
echo "[*] Step 4: Provisioning BIND9 Slave DNS..."
bash "${PROJECT_ROOT}/dns/slave/dns_slave.sh"

# --- 5. Final Status Summary ---
echo ""
echo "========================================================================"
echo " VM 2 Provisioning Finished! Service Statuses:"
echo "========================================================================"
for svc in kea-dhcp4-server kea-dhcp-ddns-server named; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "  [✓] $svc : \e[32mACTIVE (RUNNING)\e[0m"
    else
        echo -e "  [!] $svc : \e[33m$(systemctl is-active $svc 2>/dev/null || echo 'UNKNOWN')\e[0m"
    fi
done

echo ""
echo "Next step: Boot up VM 3 (port-dmz) and run vm3_setup_port_dmz.sh"
echo "========================================================================"
