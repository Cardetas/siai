#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SSH_DIR="$HOME/.ssh"

install -d -m 700 "$SSH_DIR"
for key in "$DIR/../keys/id_ed25519_*"; do
  install -m 600 "$key" "$SSH_DIR/"
done

echo "Client SSH keys installed in $SSH_DIR!"