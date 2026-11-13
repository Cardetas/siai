#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_keys_to_dir() {
  local target_user="$1"
  local target_group="$2"
  local target_home="$3"
  local ssh_dir="${target_home}/.ssh"

  install -d -m 700 -o "$target_user" -g "$target_group" "$ssh_dir"
  for key in "$DIR/../keys"/id_ed25519_*; do
    local mode=600
    [[ "$key" == *.pub ]] && mode=644
    local dest="${ssh_dir}/$(basename "$key")"
    install -m "$mode" -o "$target_user" -g "$target_group" "$key" "$dest"
    sed -i 's/\r$//' "$dest" 2>/dev/null || true
  done
  echo "Client SSH keys installed in $ssh_dir (owner: ${target_user}:${target_group})!"
}

# 1. Install for root (default alias to mgr1 key for root tests)
install_keys_to_dir "root" "root" "/root"
cp -f /root/.ssh/id_ed25519_mgr1 /root/.ssh/id_ed25519
cp -f /root/.ssh/id_ed25519_mgr1.pub /root/.ssh/id_ed25519.pub
chmod 600 /root/.ssh/id_ed25519
chmod 644 /root/.ssh/id_ed25519.pub

# 2. Install for default skeleton so any newly created home gets ~/.ssh
install_keys_to_dir "root" "root" "/etc/skel"

# 3. Install for the deploying sudo user if applicable
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  SUDO_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  SUDO_GROUP="$(id -gn "$SUDO_USER" 2>/dev/null || echo "$SUDO_USER")"
  install_keys_to_dir "$SUDO_USER" "$SUDO_GROUP" "$SUDO_HOME"
fi

# 4. Pre-provision ~/.ssh for LDAP test users (mgr1, mgr2, dev1, dev2)
# and copy each user's specific key to the standard ~/.ssh/id_ed25519
declare -A LDAP_UIDS=( ["mgr1"]="20001:10001" ["mgr2"]="20002:10001" ["dev1"]="20003:10002" ["dev2"]="20004:10002" )

for user in mgr1 mgr2 dev1 dev2; do
  user_home="/home/${user}"
  uid_gid="${LDAP_UIDS[$user]}"
  u_id="$(id -u "$user" 2>/dev/null || echo "${uid_gid%%:*}")"
  g_id="$(id -g "$user" 2>/dev/null || echo "${uid_gid##*:}")"

  install -d -m 755 -o "$u_id" -g "$g_id" "$user_home"
  install_keys_to_dir "$u_id" "$g_id" "$user_home"

  # Standard default key name so 'ssh -J ...' works without -i
  if [ -f "${user_home}/.ssh/id_ed25519_${user}" ]; then
    cp -f "${user_home}/.ssh/id_ed25519_${user}" "${user_home}/.ssh/id_ed25519"
    cp -f "${user_home}/.ssh/id_ed25519_${user}.pub" "${user_home}/.ssh/id_ed25519.pub"
    chown "$u_id":"$g_id" "${user_home}/.ssh/id_ed25519" "${user_home}/.ssh/id_ed25519.pub"
    chmod 600 "${user_home}/.ssh/id_ed25519"
    chmod 644 "${user_home}/.ssh/id_ed25519.pub"
  fi
done
