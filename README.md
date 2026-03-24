# cool-scripts

This repository contains assorted scripts, including a bootstrap specifically for Ubuntu running inside WSL.

## Ubuntu-on-WSL Zsh bootstrap

Run `linux/wsl-shell-setup.sh` on a fresh Ubuntu instance inside WSL to:
- install and configure Zsh only,
- add stronger completion, autosuggestions, syntax highlighting, and history search,
- install `thefuck`, `zoxide`, `fzf`, `bat`, `eza`, and other modern CLI tools,
- configure a pill-style breadcrumb prompt plus a shell-native breadcrumb jump picker,
- use RAM-backed completion caches and zcompiled completion metadata where available,
- and show a random startup quote from a bundled or custom quotes file.

This script is for the Linux side of WSL, not for PowerShell.
