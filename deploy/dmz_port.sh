#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Setting Hostname to port-dmz.port.dom.pt"
hostnamectl set-hostname port-dmz.port.dom.pt
echo "127.0.1.1 port-dmz.port.dom.pt port-dmz" >> /etc/hosts 2>/dev/null

echo "Setting up networking"
bash "${PROJECT_ROOT}/networking/dmz.sh"

echo "Setting up ldap server"
bash "${PROJECT_ROOT}/ldap/ldap.sh"

echo "Settign up ldap client"
bash "${PROJECT_ROOT}/ldap/ldap_client.sh"

echo "Setting up ssh config"
bash "${PROJECT_ROOT}/ssh/mail-servers/mail_ssh.sh"

echo "DMZ Portugal deployed with all services!"