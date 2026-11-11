#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - SSH Key Generator & Authorized_Keys Installer
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_DIR="${SCRIPT_DIR}"

echo "[+] ==========================================================="
echo "[+] Generating and Configuring SSH Keys for SIAI"
echo "[+] ==========================================================="

# 0. Check for ssh-keygen
if ! command -v ssh-keygen >/dev/null 2>&1; then
    if [ "$EUID" -eq 0 ]; then
        echo "[+] Installing openssh-client..."
        apt-get update -qq && apt-get install -y openssh-client
    else
        echo "[-] Error: ssh-keygen is not installed. Please install openssh-client or run as root." >&2
        exit 1
    fi
fi

# 1. Generate Manager Key (mgr1) if not exists
if [ ! -f "${KEYS_DIR}/id_ed25519_mgr1" ]; then
    echo "[+] Generating Ed25519 key for mgr1..."
    ssh-keygen -t ed25519 -N "" -C "mgr1@dom.pt" -f "${KEYS_DIR}/id_ed25519_mgr1"
fi

# 2. Generate Manager Key (mgr2) if not exists
if [ ! -f "${KEYS_DIR}/id_ed25519_mgr2" ]; then
    echo "[+] Generating Ed25519 key for mgr2..."
    ssh-keygen -t ed25519 -N "" -C "mgr2@dom.pt" -f "${KEYS_DIR}/id_ed25519_mgr2"
fi

# 3. Generate Developer Key (dev1) for access rejection verification
if [ ! -f "${KEYS_DIR}/id_ed25519_dev1" ]; then
    echo "[+] Generating Ed25519 key for dev1 (to test group rejection)..."
    ssh-keygen -t ed25519 -N "" -C "dev1@dom.pt" -f "${KEYS_DIR}/id_ed25519_dev1"
fi

echo ""
echo "[+] Keys generated in ${KEYS_DIR}:"
ls -l "${KEYS_DIR}"/id_ed25519_*

# 4. If run on a target machine as root, install authorized_keys into user home directories
if [ "$EUID" -eq 0 ]; then
    echo ""
    echo "[+] Installing authorized_keys on local host for LDAP users..."
    
    install_user_key() {
        local user="$1"
        local pubkey="$2"
        local homedir="/home/${user}"
        
        # Create home directory if missing
        mkdir -p "${homedir}/.ssh"
        cat "${pubkey}" >> "${homedir}/.ssh/authorized_keys"
        # Remove duplicate lines
        sort -u "${homedir}/.ssh/authorized_keys" -o "${homedir}/.ssh/authorized_keys"
        
        # Fix permissions
        chmod 700 "${homedir}" "${homedir}/.ssh"
        chmod 600 "${homedir}/.ssh/authorized_keys"
        
        # If user exists in NSS/LDAP, fix ownership
        if id -u "${user}" >/dev/null 2>&1; then
            chown -R "${user}:$(id -gn "${user}")" "${homedir}"
            echo "    [✓] Key installed for ${user} (ownership: ${user})"
        else
            echo "    [!] User ${user} not found in NSS yet. Perms set, run 'chown -R ${user}' after LDAP client setup."
        fi
    }

    install_user_key "mgr1" "${KEYS_DIR}/id_ed25519_mgr1.pub"
    install_user_key "mgr2" "${KEYS_DIR}/id_ed25519_mgr2.pub"
    install_user_key "dev1" "${KEYS_DIR}/id_ed25519_dev1.pub"
fi
