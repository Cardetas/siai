#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Setting Hostname to gw.usa.dom.pt"
hostnamectl set-hostname gw.usa.dom.pt
echo "127.0.1.1 gw.usa.dom.pt gw" >> /etc/hosts 2>/dev/null

echo "Setting up networking"
bash "${PROJECT_ROOT}/networking/gw_usa.sh"

echo "Setting up dhcp"
bash "${PROJECT_ROOT}/dhcp/gw-usa/dhcp.sh"

echo "Setting up Slave dns"
bash "${PROJECT_ROOT}/dns/slave/dns_slave.sh"

echo "Gateway USA deployed with all services"