#!/usr/bin/env bash
# Install apt dependencies for Photon Toaster on Ubuntu/WSL, set zsh as login shell,
# and link this directory to ~/.config/photontoaster (with first-run config + quotes).
#
# Usage: from the repo, run:
#   bash photontoaster/install-wsl-ubuntu-deps.sh
#
# Then add to ~/.zshrc (order matters):
#   source ~/.config/photontoaster/env.sh
#   source ~/.config/photontoaster/zsh/hooks.zsh
#   source ~/.config/photontoaster/zsh/aws.zsh
#   source ~/.config/photontoaster/zsh/init.zsh
#   source ~/.config/photontoaster/zsh/prompt.zsh
#   source ~/.config/photontoaster/zsh/integrations.zsh
#   source ~/.config/photontoaster/zsh/completions.zsh
#   source ~/.config/photontoaster/zsh/did-you-mean.zsh
#   source ~/.config/photontoaster/aliases.sh
#
# Or maintain a single snippet file that sources the above.

set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")
PT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_LINK="${HOME}/.config/photontoaster"

log() { printf '\n[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '\n[%s] WARNING: %s\n' "$SCRIPT_NAME" "$*" >&2; }

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "Run as your normal user (not root); the script will use sudo for apt."
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required for apt installs."
  exit 1
fi

packages=(
  git curl wget unzip zip ca-certificates software-properties-common
  build-essential pkg-config
  zoxide micro btop wslu ripgrep fzf bat fastfetch ncdu
  fd-find eza jq tldr tree less
  zsh command-not-found
  zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search thefuck
)

log "Updating apt package lists."
sudo apt-get update

log "Installing packages for zsh + Photon Toaster tooling."
sudo apt-get install -y "${packages[@]}"

if command -v git >/dev/null 2>&1; then
  git config --global color.ui auto 2>/dev/null || true
fi

log "Linking Photon Toaster: $TARGET_LINK -> $PT_SRC"
mkdir -p "$(dirname "$TARGET_LINK")"
if [[ -e "$TARGET_LINK" && ! -L "$TARGET_LINK" ]]; then
  warn "$TARGET_LINK exists and is not a symlink. Remove or rename it, then re-run."
  exit 1
fi
ln -sfn "$PT_SRC" "$TARGET_LINK"

if [[ ! -f "$PT_SRC/config.toml" ]]; then
  cp "$PT_SRC/config.toml.default" "$PT_SRC/config.toml"
  log "Created $PT_SRC/config.toml from config.toml.default"
fi

if [[ ! -f "$PT_SRC/quotes.txt" ]]; then
  cp "$PT_SRC/quotes.default.txt" "$PT_SRC/quotes.txt"
  log "Created $PT_SRC/quotes.txt from quotes.default.txt"
fi

shell_path=$(command -v zsh || true)
if [[ -z "$shell_path" ]]; then
  warn "zsh not found on PATH; skipping chsh."
else
  if ! grep -qxF "$shell_path" /etc/shells 2>/dev/null; then
    echo "$shell_path" | sudo tee -a /etc/shells >/dev/null
  fi
  if chsh -s "$shell_path" "$USER"; then
    log "Login shell set to $shell_path"
  else
    warn "chsh failed. Run manually: chsh -s $shell_path"
  fi
fi

cat <<EOF

Done. Photon Toaster config: $TARGET_LINK -> $PT_SRC

Next:
  1) Add the source lines at the top of this script to ~/.zshrc (or one snippet that sources them).
  2) Run: exec zsh -l
  3) Optional: set general.command_not_found_hints = true in config.toml on Debian/Ubuntu.
EOF
