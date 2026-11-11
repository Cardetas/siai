#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - Full Setup for VM 5: Client Machine (user1/user2)
# Roles:
#   1. LDAP Client: Authenticate LDAP users (mgr1, mgr2, dev1, dev2) via StartTLS
#   2. SSH Client: Pre-configured with ProxyJump shortcuts for single-command access
#   3. Verification: Runs automated end-to-end tests for evaluation
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================================================"
echo " Starting Full Automated Provisioning for Client Machine"
echo "========================================================================"

# --- 1. LDAP Client Configuration ---
echo ""
echo "[*] Step 1: Configuring LDAP Authentication (NSS / PAM / StartTLS)..."
bash "${SCRIPT_DIR}/setup_ldap_client_helper.sh"

# --- 2. SSH Client & Keys Setup ---
echo ""
echo "[*] Step 2: Configuring SSH Client Shortcuts..."
# Setup keys
bash "${PROJECT_ROOT}/ssh/keys/setup_keys.sh"

# Copy keys to normal user directory if run under sudo
REAL_USER="${SUDO_USER:-$(whoami)}"
REAL_HOME=$(eval echo "~${REAL_USER}")

if [ -n "${REAL_USER}" ] && [ -d "${REAL_HOME}" ]; then
    mkdir -p "${REAL_HOME}/.ssh"
    cp "${PROJECT_ROOT}/ssh/keys/id_ed25519_"* "${REAL_HOME}/.ssh/" 2>/dev/null || true
    cat "${PROJECT_ROOT}/ssh/client/config" >> "${REAL_HOME}/.ssh/config" 2>/dev/null || true
    chmod 700 "${REAL_HOME}/.ssh"
    chmod 600 "${REAL_HOME}/.ssh/"* 2>/dev/null || true
    chown -R "${REAL_USER}:${REAL_USER}" "${REAL_HOME}/.ssh"
    echo "[+] SSH keys and shortcuts installed for user ${REAL_USER} in ${REAL_HOME}/.ssh"
fi

echo ""
echo "========================================================================"
echo " Client Machine Setup Complete!"
echo " You can now:"
echo "   1. Switch to an LDAP user: su - mgr1 (password: mgr1)"
echo "   2. Run SSH verification:  ${PROJECT_ROOT}/ssh/test_ssh.sh"
echo "   3. Test Web/FTP services: curl http://web.dom.pt && nc ftp.dom.pt 21"
echo "========================================================================"
