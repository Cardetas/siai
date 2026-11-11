#!/bin/bash
# ==============================================================================
# SIAI 2026/2027 - Automated SSH Verification & Test Suite
# Tests all requirements from Assignment 1 (Page 3)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_DIR="${SCRIPT_DIR}/keys"

MGR_KEY="${KEYS_DIR}/id_ed25519_mgr1"
DEV_KEY="${KEYS_DIR}/id_ed25519_dev1"

GATEWAY="ssh.dom.pt"
MAIL_PORT="mail.port.dom.pt"
MAIL_USA="smtp2.usa.dom.pt"

echo "========================================================================"
echo " SIAI 2026/2027 - SSH Gateway & Access Control Verification"
echo "========================================================================"

if [ ! -f "${MGR_KEY}" ]; then
    echo "[-] Error: Manager key ${MGR_KEY} not found. Run ./keys/setup_keys.sh first."
    exit 1
fi

SSH_OPTS="-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5"

test_case() {
    local desc="$1"
    local cmd="$2"
    local expect_success="$3"

    echo -n "[*] Test: ${desc} ... "
    output=$(eval "$cmd" 2>&1)
    exit_code=$?

    if [ "$expect_success" = "true" ]; then
        if [ $exit_code -eq 0 ]; then
            echo -e "\e[32m[PASS] Success (as expected)\e[0m"
            return 0
        else
            echo -e "\e[31m[FAIL] Unexpected error (exit code $exit_code)\e[0m"
            echo "    Output: $output"
            return 1
        fi
    else
        if [ $exit_code -ne 0 ]; then
            echo -e "\e[32m[PASS] Denied/Blocked (as expected)\e[0m"
            return 0
        else
            echo -e "\e[31m[FAIL] Security vulnerability: command succeeded when it should be denied!\e[0m"
            echo "    Output: $output"
            return 1
        fi
    fi
}

echo ""
echo "--- 1. Testing Passwordless Access via Gateway (ssh -J) ---"
test_case "Manager (mgr1) -> mail.port via Gateway" \
    "ssh ${SSH_OPTS} -i ${MGR_KEY} -J mgr1@${GATEWAY} mgr1@${MAIL_PORT} 'hostname -f'" "true"

test_case "Manager (mgr1) -> smtp2.usa via Gateway" \
    "ssh ${SSH_OPTS} -i ${MGR_KEY} -J mgr1@${GATEWAY} mgr1@${MAIL_USA} 'hostname -f'" "true"

echo ""
echo "--- 2. Testing Group-Based Access Restriction (AllowGroups managers) ---"
test_case "Developer (dev1) login attempt (MUST BE REFUSED)" \
    "ssh ${SSH_OPTS} -i ${DEV_KEY} -J dev1@${GATEWAY} dev1@${MAIL_PORT} 'id'" "false"

echo ""
echo "--- 3. Testing Direct Root Login Restriction (PermitRootLogin no) ---"
test_case "Direct root login via Gateway (MUST BE REFUSED)" \
    "ssh ${SSH_OPTS} -J mgr1@${GATEWAY} root@${MAIL_PORT} 'whoami'" "false"

echo ""
echo "--- 4. Testing Password Authentication Restriction (PasswordAuthentication no) ---"
test_case "Password auth fallback attempt (MUST BE REFUSED)" \
    "ssh ${SSH_OPTS} -o PubkeyAuthentication=no -J mgr1@${GATEWAY} mgr1@${MAIL_PORT} 'whoami'" "false"

echo ""
echo "--- 5. Testing Source Restriction (Connections only from ssh.dom.pt) ---"
test_case "Direct SSH to mail.port bypassing Gateway (MUST BE REFUSED/DROPPED)" \
    "ssh ${SSH_OPTS} -i ${MGR_KEY} mgr1@172.16.20.20 'hostname'" "false"

echo ""
echo "========================================================================"
echo " Verification Complete"
echo "========================================================================"
