#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Setting Hostname to usa-dmz.port.dom.pt"
hostnamectl set-hostname usa-dmz.usa.dom.pt
echo "127.0.1.1 usa-dmz.usa.dom.pt usa-dmz" >> /etc/hosts 2>/dev/null

echo "Setting up networking"
bash "${PROJECT_ROOT}/networking/dmz.sh"

echo "Settign up ldap client"
bash "${PROJECT_ROOT}/ldap/ldap_client.sh"

echo "Setting up ssh config"
bash "${PROJECT_ROOT}/ssh/mail-servers/mail_ssh.sh"

echo "DMZ USA deployed with all services!"