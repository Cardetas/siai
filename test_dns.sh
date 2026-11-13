#!/usr/bin/env bash
# ==============================================================================
# SIAI 2026/2027 Practical Assignment #1 - DNS Resolution Verification Script
# ==============================================================================
# Usage:
#   ./test_dns.sh                 # Tests against default system resolver
#   ./test_dns.sh 10.10.254.1     # Tests specifically against Master DNS (VM 1)
#   ./test_dns.sh 10.10.254.2     # Tests specifically against Slave DNS (VM 2)
# ==============================================================================

set -u

DNS_SERVER="${1:-}"
SERVER_FLAG=""
if [ -n "$DNS_SERVER" ]; then
    SERVER_FLAG="@${DNS_SERVER}"
    echo "======================================================================"
    echo " Testing DNS resolution using TARGET SERVER: $DNS_SERVER"
    echo "======================================================================"
else
    echo "======================================================================"
    echo " Testing DNS resolution using DEFAULT SYSTEM RESOLVER (/etc/resolv.conf)"
    echo "======================================================================"
fi

PASSED=0
FAILED=0
TOTAL=0

# Colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

check_forward() {
    local name="$1"
    local expected_ip="$2"
    TOTAL=$((TOTAL + 1))

    # Resolve using dig (+short resolves CNAME chains automatically)
    local actual_ips
    if [ -n "$SERVER_FLAG" ]; then
        actual_ips=$(dig +short "$SERVER_FLAG" "$name" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true)
    else
        actual_ips=$(dig +short "$name" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true)
    fi

    # Check if expected IP is in the returned list
    if echo "$actual_ips" | grep -qw "$expected_ip"; then
        printf "  %-32s %-8s %-16s %b[PASS]%b\n" "$name" "A" "$expected_ip" "$GREEN" "$NC"
        PASSED=$((PASSED + 1))
    else
        local got
        got=$(echo "$actual_ips" | tr '\n' ' ' | sed 's/ $//')
        [ -z "$got" ] && got="(NXDOMAIN/no answer)"
        printf "  %-32s %-8s %-16s %b[FAIL]%b (got: %s)\n" "$name" "A" "exp: $expected_ip" "$RED" "$NC" "$got"
        FAILED=$((FAILED + 1))
    fi
}

check_reverse() {
    local ip="$1"
    local expected_name="$2"
    TOTAL=$((TOTAL + 1))

    local actual_name
    if [ -n "$SERVER_FLAG" ]; then
        actual_name=$(dig +short "$SERVER_FLAG" -x "$ip" 2>/dev/null | sed 's/\.$//' || true)
    else
        actual_name=$(dig +short -x "$ip" 2>/dev/null | sed 's/\.$//' || true)
    fi

    local clean_exp
    clean_exp=$(echo "$expected_name" | sed 's/\.$//')

    if echo "$actual_name" | grep -qw "$clean_exp"; then
        printf "  %-32s %-8s %-24s %b[PASS]%b\n" "$ip" "PTR" "$clean_exp" "$GREEN" "$NC"
        PASSED=$((PASSED + 1))
    else
        [ -z "$actual_name" ] && actual_name="(no PTR answer)"
        printf "  %-32s %-8s %-24s %b[FAIL]%b (got: %s)\n" "$ip" "PTR" "exp: $clean_exp" "$RED" "$NC" "$actual_name"
        FAILED=$((FAILED + 1))
    fi
}

check_mx() {
    local domain="$1"
    local expected_pref="$2"
    local expected_host="$3"
    TOTAL=$((TOTAL + 1))

    local mx_records
    if [ -n "$SERVER_FLAG" ]; then
        mx_records=$(dig +short "$SERVER_FLAG" "$domain" MX 2>/dev/null || true)
    else
        mx_records=$(dig +short "$domain" MX 2>/dev/null || true)
    fi

    if echo "$mx_records" | grep -i -q "${expected_pref}.*${expected_host}"; then
        printf "  %-32s %-8s %-24s %b[PASS]%b\n" "$domain" "MX" "$expected_pref $expected_host" "$GREEN" "$NC"
        PASSED=$((PASSED + 1))
    else
        local got
        got=$(echo "$mx_records" | tr '\n' ' ' | sed 's/ $//')
        [ -z "$got" ] && got="(none)"
        printf "  %-32s %-8s %-24s %b[FAIL]%b (got: %s)\n" "$domain" "MX" "exp: $expected_pref $expected_host" "$RED" "$NC" "$got"
        FAILED=$((FAILED + 1))
    fi
}

check_no_mx() {
    local domain="$1"
    TOTAL=$((TOTAL + 1))

    local mx_records
    if [ -n "$SERVER_FLAG" ]; then
        mx_records=$(dig +short "$SERVER_FLAG" "$domain" MX 2>/dev/null || true)
    else
        mx_records=$(dig +short "$domain" MX 2>/dev/null || true)
    fi

    if [ -z "$mx_records" ]; then
        printf "  %-32s %-8s %-24s %b[PASS]%b (no MX as required)\n" "$domain" "MX" "-" "$GREEN" "$NC"
        PASSED=$((PASSED + 1))
    else
        printf "  %-32s %-8s %-24s %b[FAIL]%b (unexpected MX: %s)\n" "$domain" "MX" "exp: none" "$RED" "$NC" "$mx_records"
        FAILED=$((FAILED + 1))
    fi
}

check_dnssec() {
    local domain="$1"
    TOTAL=$((TOTAL + 1))

    local rrsig
    if [ -n "$SERVER_FLAG" ]; then
        rrsig=$(dig +short "$SERVER_FLAG" "$domain" RRSIG 2>/dev/null || true)
    else
        rrsig=$(dig +short "$domain" RRSIG 2>/dev/null || true)
    fi

    if [ -n "$rrsig" ]; then
        printf "  %-32s %-8s %-24s %b[PASS]%b (RRSIG records found)\n" "$domain" "DNSSEC" "Signed" "$GREEN" "$NC"
        PASSED=$((PASSED + 1))
    else
        printf "  %-32s %-8s %-24s %b[FAIL]%b (no RRSIG records found)\n" "$domain" "DNSSEC" "exp: signed" "$RED" "$NC"
        FAILED=$((FAILED + 1))
    fi
}

# ------------------------------------------------------------------------------
# 1. Main Domain: dom.pt
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}--- 1. Main Domain: dom.pt ---${NC}"
check_forward "dom.pt"           "172.16.40.10"   # Default domain server resolves to webserver
check_forward "web.dom.pt"       "172.16.40.10"   # Alternative name for webserver
check_forward "ftp.dom.pt"       "172.16.40.10"   # Alternative name for webserver
check_forward "dns1.dom.pt"      "10.10.254.1"    # Master DNS / Router PORT
check_forward "ssh.dom.pt"       "10.10.254.1"    # SSH gateway (Router PORT)
check_forward "dns2.dom.pt"      "10.10.254.2"    # Slave DNS / Router USA
check_forward "mail.dom.pt"      "172.16.20.20"   # Mail server in dom.pt
check_forward "webmail.dom.pt"   "172.16.20.20"   # Alternative name for mail
check_forward "pop.dom.pt"       "172.16.20.20"   # Alternative name for mail
check_forward "imap.dom.pt"      "172.16.20.20"   # Alternative name for mail
check_forward "ldap.dom.pt"      "172.16.20.10"   # LDAP reachable as ldap.dom.pt

# ------------------------------------------------------------------------------
# 2. Subdomain: port.dom.pt
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}--- 2. Sub-domain: port.dom.pt ---${NC}"
check_forward "gw.port.dom.pt"   "10.10.20.1"     # Router PORT internal IP
check_forward "dns1.port.dom.pt" "10.10.254.1"    # Authoritative Master NS
check_forward "ldap.port.dom.pt" "172.16.20.10"   # LDAP server in PORT DMZ
check_forward "mail.port.dom.pt" "172.16.20.20"   # Mail server in PORT DMZ

# ------------------------------------------------------------------------------
# 3. Subdomain: usa.dom.pt
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}--- 3. Sub-domain: usa.dom.pt ---${NC}"
check_forward "gw.usa.dom.pt"    "10.10.40.1"     # Router USA internal IP
check_forward "dns2.usa.dom.pt"  "10.10.254.2"    # Authoritative Slave NS
check_forward "web.usa.dom.pt"   "172.16.40.10"   # Web server in USA DMZ
check_forward "smtp2.usa.dom.pt" "172.16.40.20"   # Backup Mail server in USA DMZ

# ------------------------------------------------------------------------------
# 4. Mail (MX) Configurations
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}--- 4. Mail (MX) Configurations ---${NC}"
check_mx "dom.pt" "10" "mail.port.dom.pt"         # Preferred mail server
check_mx "dom.pt" "20" "smtp2.usa.dom.pt"         # Backup mail server
check_no_mx "port.dom.pt"                         # Subdomains don't require MX
check_no_mx "usa.dom.pt"                          # Subdomains don't require MX

# ------------------------------------------------------------------------------
# 5. Reverse DNS (PTR)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}--- 5. Reverse DNS (PTR) Records ---${NC}"
# PORT Internal & DMZ
check_reverse "10.10.20.1"       "gw.port.dom.pt"
check_reverse "172.16.20.1"      "gw.port.dom.pt"
check_reverse "172.16.20.10"     "ldap.port.dom.pt"
check_reverse "172.16.20.20"     "mail.port.dom.pt"
# USA Internal & DMZ
check_reverse "10.10.40.1"       "gw.usa.dom.pt"
check_reverse "172.16.40.1"      "gw.usa.dom.pt"
check_reverse "172.16.40.10"     "web.usa.dom.pt"
check_reverse "172.16.40.20"     "smtp2.usa.dom.pt"

# ------------------------------------------------------------------------------
# 6. DNSSEC Verification
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}--- 6. DNSSEC Signing ---${NC}"
check_dnssec "dom.pt"

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo "======================================================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}ALL $TOTAL DNS CHECKS PASSED SUCCESSFULLY!${NC}"
    exit 0
else
    echo -e "${RED}$FAILED of $TOTAL CHECKS FAILED!${NC} (Passed: $PASSED)"
    exit 1
fi
