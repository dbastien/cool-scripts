# cool-scripts

## Install PhotonToaster (Windows / cross-platform)

**PhotonToaster** is the cross-shell setup toolkit under [`photontoaster/`](photontoaster/). It supports PowerShell, zsh, bash, fish, and nushell. The default install copies the runtime into `~/.config/photontoaster`, installs missing CLI tools via your system package manager, and patches your `$PROFILE`.

1. Install [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) (`pwsh`) if you do not already have it.
2. Clone this repository and open a terminal.
3. Run:

```powershell
pwsh -File .\photontoaster\install.ps1
```

This copies the PhotonToaster tree to `~/.config/photontoaster`, installs tools, seeds config, and patches your `$PROFILE`. Open a new terminal and you're done.

Features: segment-driven prompt (pills/minimal/plain), TOML-driven config with color schemes, "did you mean?" typo suggestions, fzf keybindings (Ctrl+R/T, Alt+C), atuin/PSReadLine history tiering, auto-ls, zoxide, Terminal-Icons, startup profiling, quote of the day, and more.

Layout, config, and profile hooks are documented inside `photontoaster/`.

## Other folders

Other script collections (for example `directory-opus/`) are separate; each area may have its own README.
