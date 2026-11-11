#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - Setup Mail Dummy Service
# Run on: mail.port.dom.pt (172.16.20.20) OR smtp2.usa.dom.pt (172.16.40.20)
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLE="${1:-auto}"

echo "[+] ==========================================================="
echo "[+] Installing Mail Dummy Service (Role: ${ROLE}) on $(hostname)"
echo "[+] ==========================================================="

# Ensure python3 is installed
if ! command -v python3 >/dev/null 2>&1; then
    echo "[+] Installing python3..."
    apt-get update -qq && apt-get install -y python3
fi

# Deploy files to /opt/siai/mail-dummy
mkdir -p /opt/siai/mail-dummy
cp "${SCRIPT_DIR}/mail_dummy.py" /opt/siai/mail-dummy/
chmod +x /opt/siai/mail-dummy/mail_dummy.py

# Configure systemd service
sed "s/--role auto/--role ${ROLE}/" "${SCRIPT_DIR}/siai-mail-dummy.service" > /etc/systemd/system/siai-mail-dummy.service
systemctl daemon-reload
systemctl enable --now siai-mail-dummy

echo "[+] Service started and enabled at boot:"
systemctl status siai-mail-dummy --no-pager

echo ""
echo "[+] Test with:"
echo "    nc mail.dom.pt 25"
echo "    nc pop.dom.pt 110"
echo "    nc imap.dom.pt 143"
echo "    curl http://webmail.dom.pt"
