# cool-scripts

This repository contains assorted scripts for PowerShell and Zsh.

## Photon Toaster (Zsh)

Shell theme, prompts, aliases, and integrations live under [`photontoaster/`](photontoaster/).

On **Ubuntu inside WSL**, run once (as your normal user):

```bash
bash photontoaster/install-wsl-ubuntu-deps.sh
```

That installs apt packages (zsh, plugins, CLI tools), symlinks `~/.config/photontoaster` to this repo’s `photontoaster/` folder, seeds `config.toml` and `quotes.txt` if missing, and sets your login shell to zsh. Then wire `~/.zshrc` to source the files listed in the installer header (see top of `install-wsl-ubuntu-deps.sh`).

Photon Toaster does not duplicate a second prompt/alias stack: configure behavior in `photontoaster/config.toml` (copy from `config.toml.default` if needed).
