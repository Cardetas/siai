#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"


echo "Setting Hostname to gw.port.dom.pt"
hostnamectl set-hostname gw.port.dom.pt
grep -q "gw.port.dom.pt" /etc/hosts || echo "127.0.1.1 gw.port.dom.pt gw" >> /etc/hosts

echo "Setting up networking"
bash "${PROJECT_ROOT}/networking/gw_port.sh"

echo "Setting up dhcp"
bash "${PROJECT_ROOT}/dhcp/gw-port/dhcp.sh"

echo "Setting up Master dns"
bash "${PROJECT_ROOT}/dns/master/dns_master.sh"

echo "Setting up ssh gateway"
bash "${PROJECT_ROOT}/ssh/gateway/gateway_ssh.sh"

echo "Gateway Portugal deployed with all services"