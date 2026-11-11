#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - Setup Web & FTP Dummy Service
# Run on: USA DMZ VM (web.usa.dom.pt / 172.16.40.10)
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[+] ==========================================================="
echo "[+] Installing Web & FTP Dummy Service on web.usa.dom.pt"
echo "[+] ==========================================================="

# Ensure python3 is installed
if ! command -v python3 >/dev/null 2>&1; then
    echo "[+] Installing python3..."
    apt-get update -qq && apt-get install -y python3
fi

# Deploy files to /opt/siai/web-dummy
mkdir -p /opt/siai/web-dummy
cp "${SCRIPT_DIR}/web_dummy.py" /opt/siai/web-dummy/
chmod +x /opt/siai/web-dummy/web_dummy.py

# Install systemd service
cp "${SCRIPT_DIR}/siai-web-dummy.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now siai-web-dummy

echo "[+] Service started and enabled at boot:"
systemctl status siai-web-dummy --no-pager

echo ""
echo "[+] Test with:"
echo "    curl http://web.dom.pt"
echo "    curl http://web.usa.dom.pt"
echo "    nc ftp.dom.pt 21"
