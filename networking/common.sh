#!/usr/bin/env bash
# Shared network interface helper for Debian VMs (supports enp0s3 and siai_debian.ova's enp0s17)

detect_adapter1() {
  if [ -d /sys/class/net/enp0s3 ]; then
    echo "enp0s3"
    return 0
  fi
  if [ -d /sys/class/net/enp0s17 ]; then
    echo "enp0s17"
    return 0
  fi
  for dev in /sys/class/net/*; do
    local name
    name="$(basename "$dev")"
    case "$name" in
      lo|enp0s8|enp0s9|enp0s10) continue ;;
      *)
        echo "$name"
        return 0
        ;;
    esac
  done
  echo "enp0s3"
}

install_interfaces_template() {
  local template="$1"
  shift
  local adapter1
  adapter1="$(detect_adapter1)"
  echo "Detected Adapter 1 interface: $adapter1"

  if [ -f /etc/network/interfaces ]; then
    cp /etc/network/interfaces /etc/network/interfaces.bak
  fi

  for iface in "$adapter1" "$@"; do
    ifdown "$iface" 2>/dev/null || true
    ip addr flush dev "$iface" 2>/dev/null || true
  done

  sed "s/enp0s3/${adapter1}/g" "$template" > /etc/network/interfaces
  chmod 644 /etc/network/interfaces

  systemctl restart networking 2>/dev/null || ifup -a 2>/dev/null || true
}
