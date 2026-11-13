#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
 
CURRENT_HOST="$(hostname -s)"
if [ "$CURRENT_HOST" = "gisi" ] || [ "$CURRENT_HOST" = "debian" ] || [ "$CURRENT_HOST" = "localhost" ]; then
  echo "Setting Hostname to user1"
  hostnamectl set-hostname user1
  grep -q "user1" /etc/hosts || echo "127.0.1.1 user1" >> /etc/hosts
fi

echo "Setting up networking"
bash "${PROJECT_ROOT}/networking/client.sh"
dhclient -r 2>/dev/null || true
dhclient 2>/dev/null || true

echo "Setting up ldap client"
bash "${PROJECT_ROOT}/ldap/ldap_client.sh"

echo "Setting up ssh config"
bash "${PROJECT_ROOT}/ssh/client/client_ssh.sh"

echo "Client Machine deployed!"