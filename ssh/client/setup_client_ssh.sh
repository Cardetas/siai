#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - Client SSH Setup Script
# Run on client machines (PORT internal or USA internal)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.ssh"

echo "[+] Setting up SSH client shortcuts for $(whoami)..."

mkdir -p "${TARGET_DIR}"
chmod 700 "${TARGET_DIR}"

# Append or install config
if [ -f "${TARGET_DIR}/config" ]; then
    echo "[+] Updating existing ${TARGET_DIR}/config..."
    # Remove older SIAI blocks if any
    sed -i '/# SIAI 2026\/2027/,+20d' "${TARGET_DIR}/config" 2>/dev/null || true
fi

cat "${SCRIPT_DIR}/config" >> "${TARGET_DIR}/config"
chmod 600 "${TARGET_DIR}/config"

echo "[+] SSH client configuration installed in ${TARGET_DIR}/config."
echo "[+] You can now connect with a single command:"
echo "    - Using config alias:  ssh mail.port.dom.pt"
echo "    - Using explicit -J:   ssh -i ~/.ssh/id_ed25519_mgr1 -J mgr1@ssh.dom.pt mgr1@mail.port.dom.pt"
echo "    - USA mail server:     ssh smtp2.usa.dom.pt"
