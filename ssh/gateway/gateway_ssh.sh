#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
  echo "Run as root" >&2
  exit 1
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server

install -m 644 $DIR/gateway.conf /etc/ssh/sshd_config.d/gateway.conf
install -d -m 755 /etc/ssh/authorized_keys
for user in mgr1 mgr2 dev1 dev2; do
  install -m 644 "$DIR/../keys/id_ed25519_${user}.pub" "/etc/ssh/authorized_keys/$user"
  useradd -M -s /bin/bash "$user"
done

systemctl restart ssh
systemctl enable ssh

echo "SSH gateway deployed!"
