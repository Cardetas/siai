# SIAI 2026/2027 - Practical Assignment #1

Automated infrastructure and network service deployment on Debian Linux across 5 VirtualBox Virtual Machines for the domain `dom.pt`.

---

## Network Architecture & Addressing

| VM | Hostname | Interfaces / Subnets | Primary Roles & Services |
| :--- | :--- | :--- | :--- |
| **VM 1** | `gw.port.dom.pt`<br>`(ssh.dom.pt)` | `enp0s3`: `10.10.254.1/24` (Router link)<br>`enp0s8`: `10.10.20.1/24` (PORT LAN)<br>`enp0s9`: `172.16.20.1/24` (PORT DMZ)<br>`enp0s10`: Hypervisor NAT (Internet) | • NAT Masquerading & IPv4 Forwarding<br>• Kea DHCP Server (PORT LAN & DMZ)<br>• BIND9 Master DNS (`dom.pt`, `port.dom.pt`)<br>• OpenSSH Jump Gateway (`ssh.dom.pt`) |
| **VM 2** | `gw.usa.dom.pt` | `enp0s3`: `10.10.254.2/24` (Router link)<br>`enp0s8`: `10.10.40.1/24` (USA LAN)<br>`enp0s9`: `172.16.40.1/24` (USA DMZ) | • Static Routing via `10.10.254.1`<br>• Kea DHCP Server (USA LAN & DMZ)<br>• BIND9 Slave DNS (TSIG zone transfer) |
| **VM 3** | `port-dmz.port.dom.pt` | `enp0s3`: `172.16.20.10` (DHCP static)<br>`enp0s8`: `172.16.20.20` (DHCP static) | • OpenLDAP Server (`ldap.port.dom.pt` with TLS/LDAPS)<br>• Centralized LDAP Client (NSS / PAM `pam_mkhomedir`)<br>• Hardened SSH Mail Server (`mail.port.dom.pt`) |
| **VM 4** | `usa-dmz.usa.dom.pt` | `enp0s3`: `172.16.40.10` (DHCP static)<br>`enp0s8`: `172.16.40.20` (DHCP static) | • Centralized LDAP Client (NSS / PAM `pam_mkhomedir`)<br>• Hardened SSH Backup Mail Server (`smtp2.usa.dom.pt`) |
| **VM 5** | `user1` (Client) | `enp0s3`: DHCP on PORT LAN (`10.10.20.0/24`) or USA LAN (`10.10.40.0/24`) | • Dynamic DHCP & DDNS registration<br>• Centralized LDAP Client (Login testing: `su - mgr1`)<br>• SSH Client with testing keypairs |

### VirtualBox Adapter & MAC Requirements

> [!WARNING]
> **DMZ Static Reservations**: VM 3 and VM 4 obtain fixed IPs via Kea DHCP reservations. You **must** configure these exact VirtualBox adapter attachments and MAC addresses before booting them.
> *(Note: on `siai_debian.ova`, Adapter 1 is named `enp0s17` instead of `enp0s3`; `networking/` scripts auto-detect and map it automatically.)*

| VM | Adapter 1 (`enp0s3` / `enp0s17`) | Adapter 2 (`enp0s8`) | Adapter 3 (`enp0s9`) | Adapter 4 (`enp0s10`) |
| :--- | :--- | :--- | :--- | :--- |
| **VM 1 (`gw.port`)** | Internal (`interconnect`) | Internal (`port_internal`) | Internal (`port_dmz`) | NAT (Internet) |
| **VM 2 (`gw.usa`)** | Internal (`interconnect`) | Internal (`usa_internal`) | Internal (`usa_dmz`) | — |
| **VM 3 (`port-dmz`)** | Internal (`port_dmz`)<br>MAC: `080027002010` | Internal (`port_dmz`)<br>MAC: `080027002020` | — | — |
| **VM 4 (`usa-dmz`)** | Internal (`usa_dmz`)<br>MAC: `080027004010` | Internal (`usa_dmz`)<br>MAC: `080027004020` | — | — |
| **VM 5 (Client)** | Internal (`port_internal` or `usa_internal`) | — | — | — |

---

## Repository Structure

```text
siai/
├── deploy/                        # Main entry-point scripts (1 per VM)
│   ├── gw_port.sh                 # VM 1: Gateway Portugal
│   ├── gw_usa.sh                  # VM 2: Gateway USA
│   ├── dmz_port.sh                # VM 3: PORT DMZ Server (LDAP & Mail)
│   ├── dmz_usa.sh                 # VM 4: USA DMZ Server (Backup Mail)
│   └── client.sh                  # VM 5: Client Machine
│
├── networking/                    # Network interfaces and routing configurations
│   ├── common.sh                  # Adapter 1 auto-detection (enp0s3 / enp0s17)
│   ├── gw_port.sh                 # VM 1: IPv4 forwarding, interfaces & nftables NAT
│   ├── gw_usa.sh                  # VM 2: IPv4 forwarding & static routes
│   ├── dmz.sh                     # VM 3 & 4: Dual-NIC DHCP client interface setup
│   ├── client.sh                  # VM 5: DHCP client interface setup
│   ├── interfaces-gw-port         # Interface definitions for Gateway PORT
│   ├── interfaces-gw-usa          # Interface definitions for Gateway USA
│   ├── interfaces-dmz             # Interface definitions for DMZ VMs (Adapter 1, enp0s8)
│   └── interfaces-client          # Interface definition for Client VM (Adapter 1)
│
├── dhcp/                          # Kea DHCPv4 Server Configurations
│   ├── gw-port/
│   │   ├── dhcp.sh                # Installs and enables kea-dhcp4 & kea-dhcp-ddns on VM 1
│   │   ├── kea-dhcp4.conf         # Subnets: 10.10.20.0/24 and 172.16.20.0/24 (reservations)
│   │   └── kea-dhcp-ddns.conf     # DDNS updates to 127.0.0.1 using TSIG
│   └── gw-usa/
│       ├── dhcp.sh                # Installs and enables kea-dhcp4 & kea-dhcp-ddns on VM 2
│       ├── kea-dhcp4.conf         # Subnets: 10.10.40.0/24 and 172.16.40.0/24 (reservations)
│       └── kea-dhcp-ddns.conf     # DDNS updates to 10.10.254.1 using TSIG
│
├── dns/                           # BIND9 DNS Architecture (Authoritative, TSIG, DNSSEC)
│   ├── tsig.key                   # Shared TSIG key for master-slave zone replication
│   ├── master/
│   │   ├── dns_master.sh          # Master BIND9 installer & DNSSEC signer
│   │   ├── named.conf.local       # Master zone declarations
│   │   ├── named.conf.options     # Master options (forwarders 1.1.1.1, recursion)
│   │   └── zones/                 # Zone files (.db standard format)
│   │       ├── dom.pt.db
│   │       ├── port.dom.pt.db
│   │       ├── usa.dom.pt.db
│   │       ├── INTERNAL_PORT_rev.db
│   │       ├── DMZ_PORT_rev.db
│   │       ├── INTERNAL_USA_rev.db
│   │       └── DMZ_USA_rev.db
│   └── slave/
│       ├── dns_slave.sh           # Slave BIND9 installer
│       ├── named.conf.local       # Slave zone declarations replicating from 10.10.254.1
│       └── named.conf.options     # Slave options
│
├── ldap/                          # OpenLDAP Server & Client Integration
│   ├── ldap.sh                    # OpenLDAP installer, schemas, TLS, & LDIF loader
│   ├── ldap_client.sh             # Centralized NSS/PAM LDAP client installer
│   ├── certs/                     # TLS Certificates (CA root, server cert, private key)
│   ├── client/                    # Client configs (nslcd.conf, ldap.conf)
│   └── ldif/                      # Directory tree LDIFs (OUs, groups, users)
│
└── ssh/                           # OpenSSH Architecture (Jump Gateway & Mail Hardening)
    ├── gateway/
    │   ├── gateway.conf           # AllowTcpForwarding yes, PubkeyAuthentication yes
    │   └── gateway_ssh.sh         # Installs gateway config and public keys in /etc/ssh/authorized_keys
    ├── mail-servers/
    │   ├── mail.conf              # PermitRootLogin no, PasswordAuthentication no, AllowGroups managers
    │   └── mail_ssh.sh            # Installs 10-mail.conf, Match Address in sshd_config, and authorized_keys
    ├── client/
    │   └── client_ssh.sh          # Installs private keys into ~/.ssh (mode 600)
    └── keys/                      # Pre-generated Ed25519 keypairs (mgr1, mgr2, dev1, dev2)
```

---

## Deployment Instructions

> [!IMPORTANT]
> **Deployment Order**: Boot and configure the routers first (VM 1 then VM 2) so DHCP, DNS, and Internet NAT routing are active before provisioning the DMZ servers and clients.

### Step 1: Gateway Portugal (VM 1)
1. On VM 1, clone the repository and run as `root`:
   ```bash
   git clone https://github.com/Cardetas/siai.git
   cd siai
   sudo bash deploy/gw_port.sh
   ```
2. **What this deploys**: Sets hostname `gw.port.dom.pt`, sets up NAT masquerading on `enp0s10`, starts Kea DHCP for the Portugal subnets, initializes BIND9 Master DNS with DNSSEC, and configures the OpenSSH Jump Gateway on `ssh.dom.pt`.

---

### Step 2: Gateway USA (VM 2)
1. On VM 2, clone the repository and run as `root`:
   ```bash
   git clone https://github.com/Cardetas/siai.git
   cd siai
   sudo bash deploy/gw_usa.sh
   ```
2. **What this deploys**: Sets hostname `gw.usa.dom.pt`, configures static routing across the inter-router link (`10.10.254.1`), starts Kea DHCP for the USA subnets, and initializes BIND9 Slave DNS (replicating zones from master via TSIG).

---

### Step 3: PORT DMZ Server (VM 3)
1. Boot VM 3. It automatically obtains `172.16.20.10` and `172.16.20.20` via DHCP reservations from VM 1.
2. Run as `root`:
   ```bash
   git clone https://github.com/Cardetas/siai.git
   cd siai
   sudo bash deploy/dmz_port.sh
   ```
3. **What this deploys**: Configures DMZ dual-NIC interfaces, installs OpenLDAP (`ldap.port.dom.pt`) with TLS/LDAPS and directory structure, configures NSS/PAM LDAP authentication with `pam_mkhomedir`, and secures OpenSSH for `mail.port.dom.pt`.

---

### Step 4: USA DMZ Server (VM 4)
1. Boot VM 4. It automatically obtains `172.16.40.10` and `172.16.40.20` via DHCP reservations from VM 2.
2. Run as `root`:
   ```bash
   git clone https://github.com/Cardetas/siai.git
   cd siai
   sudo bash deploy/dmz_usa.sh
   ```
3. **What this deploys**: Configures DMZ dual-NIC interfaces, configures NSS/PAM LDAP client authentication against `ldap.port.dom.pt` over TLS, and secures OpenSSH for `smtp2.usa.dom.pt`.

---

### Step 5: Client Machine (VM 5)
1. Connect VM 5's network adapter to either the PORT Internal Network or USA Internal Network.
2. Boot VM 5 (it receives an IP via DHCP).
3. Run as `root`:
   ```bash
   git clone https://github.com/Cardetas/siai.git
   cd siai
   sudo bash deploy/client.sh
   ```
4. **What this deploys**: Configures Adapter 1 (`enp0s3`/`enp0s17`) via DHCP, configures the machine as an LDAP client (allowing `mgr1`, `mgr2`, `dev1`, `dev2` logins with automatic home directory creation), and copies the test SSH private keys to `~/.ssh/`.

---

## Verification & Testing

### 1. Networking, DHCP & DDNS Verification
Check routing, NAT, lease timers (8h valid / 6h renew), and dynamic DNS registration:
```bash
# Verify client IP, lease timers, and Internet NAT
ip a
ping -c 2 172.16.40.10
ping -c 2 8.8.8.8

# Verify Kea DDNS dynamic registration (forward & reverse)
dig @10.10.20.1 user1.port.dom.pt +short
dig @10.10.20.1 -x <CLIENT_IP> +short
```

### 2. DNS Verification
Test name resolution, slave replication, and DNSSEC from the client:
```bash
# Test Master and Slave DNS resolution
dig @10.10.20.1 mail.port.dom.pt +short
dig @10.10.254.2 mail.port.dom.pt +short

# Test CNAME and MX resolution
dig @10.10.20.1 webmail.dom.pt +short
dig @10.10.20.1 dom.pt MX +short

# Test DNSSEC validation
dig @10.10.20.1 dom.pt +dnssec +multiline
```

### 3. LDAP Authentication Verification
On VM 5 (or any client machine), verify StartTLS/LDAPS certificate validation, NSS lookup, and automatic home directory creation:
```bash
# Verify StartTLS & LDAPS against custom Root CA
ldapsearch -x -ZZ -H ldap://ldap.dom.pt -b dc=dom,dc=pt "(uid=mgr1)"
ldapsearch -x -H ldaps://ldap.dom.pt -b dc=dom,dc=pt "(uid=mgr1)"

# Verify user lookup via NSS
getent passwd mgr1
getent group managers

# Verify interactive login & pam_mkhomedir
su - mgr1
# Type password (set during ldap.sh)
pwd
# Expected output: /home/mgr1 (automatically created)
exit
```

### 4. SSH Access Control & Gateway Jump Verification
From the client machine (logged in as `mgr1` via `su - mgr1` or as `root`), run standard OpenSSH commands using `-J` (Jump Host).
*(Note: Each user's `.ssh/id_ed25519` is automatically configured by `client_ssh.sh`, so you can run with or without `-i`)*:

* **Manager access via Gateway (MUST SUCCEED)**:
  ```bash
  # Inside 'su - mgr1':
  ssh -J mgr1@ssh.dom.pt mgr1@mail.port.dom.pt 'hostname -f'
  ssh -J mgr1@ssh.dom.pt mgr1@smtp2.usa.dom.pt 'hostname -f'

  # Or explicitly passing identity file:
  ssh -i ~/.ssh/id_ed25519_mgr1 -J mgr1@ssh.dom.pt mgr1@mail.port.dom.pt 'hostname -f'
  ```

* **Developer access attempt (MUST BE REFUSED by `AllowGroups managers`)**:
  ```bash
  ssh -i ~/.ssh/id_ed25519_dev1 -J dev1@ssh.dom.pt dev1@mail.port.dom.pt
  # Expected: Permission denied (publickey)
  ```

* **Direct access bypassing Gateway (MUST BE REJECTED by `Match Address`)**:
  ```bash
  ssh -i ~/.ssh/id_ed25519_mgr1 mgr1@172.16.20.20
  # Expected: Connection refused or Permission denied
  ```

* **Password authentication attempt (MUST BE REFUSED)**:
  ```bash
  ssh -o PubkeyAuthentication=no -J mgr1@ssh.dom.pt mgr1@mail.port.dom.pt
  # Expected: Permission denied (publickey)
  ```

* **Direct root login attempt via Gateway (MUST BE REFUSED by `PermitRootLogin no`)**:
  ```bash
  ssh -J mgr1@ssh.dom.pt root@mail.port.dom.pt
  # Expected: Permission denied (publickey)
  ```
