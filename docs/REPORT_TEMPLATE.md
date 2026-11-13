# SIAI 2026/2027 — Practical Assignment #1 Report
**Domain:** `dom.pt` | **Author:** Group of 2 Students

---

## 1. Executive Summary & Network Addressing

| Machine | Hostname | Subnets / Interfaces | Roles & Deployed Services |
| :--- | :--- | :--- | :--- |
| **VM 1** | `gw.port.dom.pt`<br>`(ssh.dom.pt, dns1.dom.pt)` | `enp0s3/enp0s17`: `10.10.254.1/24`<br>`enp0s8`: `10.10.20.1/24`<br>`enp0s9`: `172.16.20.1/24`<br>`enp0s10`: Hypervisor NAT (DHCP) | • IPv4 Routing & nftables NAT Masquerading<br>• Kea DHCPv4 Server (PORT Internal & DMZ)<br>• Kea DHCP-DDNS Server (TSIG authenticated)<br>• BIND9 Master DNS (`dom.pt`, `port.dom.pt`, `usa.dom.pt`)<br>• DNSSEC Inline Signer (`dom.pt`)<br>• OpenSSH Jump Gateway (`ssh.dom.pt`) |
| **VM 2** | `gw.usa.dom.pt`<br>`(dns2.dom.pt)` | `enp0s3/enp0s17`: `10.10.254.2/24`<br>`enp0s8`: `10.10.40.1/24`<br>`enp0s9`: `172.16.40.1/24` | • IPv4 Static Routing (Default GW: `10.10.254.1`)<br>• Kea DHCPv4 Server (USA Internal & DMZ)<br>• Kea DHCP-DDNS Server (Updates forwarded to Master)<br>• BIND9 Slave DNS (TSIG replicated) |
| **VM 3** | `port-dmz.port.dom.pt`<br>`(ldap / mail)` | `enp0s3/enp0s17`: `172.16.20.10`<br>`enp0s8`: `172.16.20.20` | • OpenLDAP Server (`ldap.port.dom.pt`, TLS/LDAPS)<br>• Primary Mail Server (`mail.port.dom.pt`, Hardened SSH)<br>• Centralized NSS/PAM LDAP Client |
| **VM 4** | `usa-dmz.usa.dom.pt`<br>`(web / smtp2)` | `enp0s3/enp0s17`: `172.16.40.10`<br>`enp0s8`: `172.16.40.20` | • Web Server (`web.usa.dom.pt`)<br>• Backup Mail Server (`smtp2.usa.dom.pt`, Hardened SSH)<br>• Centralized NSS/PAM LDAP Client |
| **VM 5** | `user1` (Client Machine) | `enp0s3/enp0s17`: DHCP on `10.10.20.0/24` or `10.10.40.0/24` | • Centralized LDAP Client (`mgr1`, `mgr2`, `dev1`, `dev2`)<br>• Dynamic DNS Client (auto-registered via Kea DDNS)<br>• SSH Client with test keypairs |

---

## 2. Infrastructure, Routing & NAT

### 2.1 Routing Architecture
- `gw.port.dom.pt` acts as the primary Internet gateway performing IPv4 source NAT (masquerading) on `enp0s10` for all internal networks (`10.10.20.0/24`, `172.16.20.0/24`, `10.10.40.0/24`, `172.16.40.0/24`).
- Static routes on `gw.port.dom.pt`:
  - `10.10.40.0/24 via 10.10.254.2`
  - `172.16.40.0/24 via 10.10.254.2`
- Static default route on `gw.usa.dom.pt`:
  - `default via 10.10.254.1`

### 2.2 DMZ ARP Flux Mitigation
Because DMZ servers use dual interfaces on the same subnet (`172.16.x.0/24`) to receive static reservations for two services on a single VM, Linux kernel sysctl flags are configured:
```ini
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.all.rp_filter = 0
```
This guarantees that ARP replies are only sent from the interface that owns the queried IP address, avoiding ARP flux.

---

## 3. Kea DHCP & Dynamic DNS (DDNS)

### 3.1 Lease Timers
In compliance with RFC 2131 and assignment requirements:
- **Valid lifetime:** 28,800 seconds (8 hours).
- **Renew timer ($T_1$):** 21,600 seconds (6 hours).
- **Rebind timer ($T_2$):** 25,200 seconds (7 hours).

### 3.2 Dynamic DNS Updates with TSIG
- **Kea DHCP-DDNS daemon (`kea-dhcp-ddns`)** communicates with BIND9 using an HMAC-SHA256 TSIG key (`tsig-key`).
- Dynamic clients (e.g. `user1`) sending their hostname are automatically registered in the forward zone (`port.dom.pt` or `usa.dom.pt`) and reverse zones (`in-addr.arpa`).
- `gw.usa.dom.pt` forwards DDNS update requests across the interconnection link directly to the Master DNS server at `10.10.254.1`.

---

## 4. BIND9 DNS Service & DNSSEC

### 4.1 Master / Slave Replication
- **Master:** `dns1.dom.pt` (`10.10.254.1`).
- **Slave:** `dns2.dom.pt` (`10.10.254.2`).
- Transfer of zones (`AXFR`) is protected with TSIG authentication (`allow-transfer { key "tsig-key"; };`).
- Master notifies the slave immediately upon updates via `also-notify` and `notify yes;`.

### 4.2 DNSSEC Technical Explanation

#### Why signed zones must be stored in `/var/lib/bind` instead of `/etc/bind`
1. **FHS & Debian Security Policy (AppArmor):** Under Debian's AppArmor profile for BIND9 (`usr.sbin.named`), `/etc/bind` is strictly read-only to prevent malicious code execution or configuration tampering.
2. **Dynamic Signing & Journaling:** BIND9's automated DNSSEC policy (`inline-signing yes;` / `dnssec-policy default;`) generates dynamic signatures, updates keys, and maintains `.signed` and `.jnl` journal files directly on disk. Because named runs as the non-root `bind:bind` user, it requires write permissions to the zone storage directory. `/var/lib/bind` is specifically designated with `775 bind:bind` permissions for dynamically modified and signed zone files.

#### Explanation of DNSSEC Record Types
- **DNSKEY (DNS Key Record):** Holds the public cryptographic keys used to verify signatures in the zone. Contains both the Zone Signing Key (ZSK, flags 256) used to sign zone records, and the Key Signing Key (KSK, flags 257) used to sign the DNSKEY RRset and establish the chain of trust to parent zones.
- **RRSIG (Resource Record Signature):** Contains the cryptographic signature for a specific RRset (e.g., A, MX, NS). Validating resolvers use the public key in the DNSKEY record to verify that the RRSIG signature is mathematically valid and has not expired or been altered.
- **NSEC (Next Secure Record):** Provides authenticated denial of existence for non-existent domain names (proof of non-existence). It links existing names in alphabetical order, proving that no record exists between two authenticated names, and lists the record types that exist for that name.

---

## 5. OpenLDAP Directory & Centralized Authentication

- **Directory Base:** `dc=dom,dc=pt`
- **Organizational Units:**
  - `ou=people,dc=dom,dc=pt`: contains 4 users (`mgr1`, `mgr2`, `dev1`, `dev2`) with attributes `uidNumber`, `gidNumber`, `homeDirectory`, `loginShell`, `userPassword`.
  - `ou=group,dc=dom,dc=pt`: contains groups `managers` (gid `10001`, members `mgr1`, `mgr2`) and `developers` (gid `10002`, members `dev1`, `dev2`).
- **TLS Security:**
  - Custom Root CA (`dom-RootCA`).
  - Server certificate with SAN for `ldap.port.dom.pt`, `ldap.dom.pt`, and IP `172.16.20.10`.
  - Clients enforce `start_tls` and `tls_reqcert demand` validating against `/usr/local/share/ca-certificates/dom_ca.crt`.
- **PAM Integration:** `pam_mkhomedir.so` automatically provisions `/home/<user>` upon initial user login.

---

## 6. OpenSSH Hardening & Jump Gateway

- **Gateway:** `ssh.dom.pt` (`gw.port.dom.pt`) allows TCP forwarding (`AllowTcpForwarding yes`, `AllowAgentForwarding yes`) and public-key authentication for Jump Host usage (`ssh -J`).
- **Mail Server Hardening (`mail.port.dom.pt` and `smtp2.usa.dom.pt`):**
  - Direct root login disabled: `PermitRootLogin no`.
  - Password authentication disabled: `PasswordAuthentication no`.
  - Access restricted to members of the LDAP `managers` group: `AllowGroups managers`.
  - Network-level access restriction: `Match Address *,!172.16.20.1,!10.10.254.1 DenyUsers *` ensures connections are accepted exclusively from the SSH gateway.

---

## 7. Verification Test Log

*(Insert real command outputs and terminal captures below)*

### 7.1 DNS Resolution & DNSSEC Verification
```bash
dig @10.10.20.1 mail.port.dom.pt +short
dig @10.10.20.1 webmail.dom.pt +short
dig @10.10.20.1 dom.pt MX +short
dig @10.10.20.1 dom.pt +dnssec +multiline
```

### 7.2 Kea DHCP-DDNS Registration
```bash
ip a
dig @10.10.20.1 user1.port.dom.pt +short
```

### 7.3 LDAP Authentication & Home Creation
```bash
ldapsearch -x -ZZ -H ldap://ldap.dom.pt -b dc=dom,dc=pt "(uid=mgr1)"
getent passwd mgr1
getent group managers
su - mgr1
pwd
exit
```

### 7.4 SSH Access Control Tests
```bash
# 1. Manager access via Gateway (Success expected)
ssh -i ~/.ssh/id_ed25519_mgr1 -J mgr1@ssh.dom.pt mgr1@mail.port.dom.pt 'hostname -f'

# 2. Developer access attempt (Permission denied expected)
ssh -i ~/.ssh/id_ed25519_dev1 -J dev1@ssh.dom.pt dev1@mail.port.dom.pt

# 3. Direct access bypassing gateway (Rejected expected)
ssh -i ~/.ssh/id_ed25519_mgr1 mgr1@172.16.20.20

# 4. Direct root login attempt (Rejected expected)
ssh -J mgr1@ssh.dom.pt root@mail.port.dom.pt
```
