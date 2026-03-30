# cool-scripts

## Install Toasty (Windows)

**Toasty** is the PowerShell toolkit under [`powershell/toasty/`](powershell/toasty/). The default install creates a directory junction from `~/.config/toasty` to the repo, adds `cli/` to your PATH, and optionally pulls in common **native CLI tools via winget** (see [`powershell/toasty/winget/WingetManifest.ps1`](powershell/toasty/winget/WingetManifest.ps1): ripgrep, bat, fd, eza, fzf, zoxide, jq, and the Extended tier unless you opt out).

1. Install [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) (`pwsh`) if you do not already have it. You also need **winget** (App Installer from the Microsoft Store is the usual source).
2. Clone this repository and open a terminal.
3. Run:

```powershell
pwsh -File .\powershell\toasty\install.ps1
```

This creates a junction `~/.config/toasty` -> the repo, adds `cli/` to PATH, seeds config, and patches your `$PROFILE`. Open a new terminal and you're done.

Useful flags: **`-MinimalExtern`** (smaller winget set), **`-WhatIf`** (dry run), **`-Force`**, optional GUI/extension switches (see [`powershell/toasty/README.md`](powershell/toasty/README.md)).

Layout, config, and profile hooks are documented in [`powershell/toasty/README.md`](powershell/toasty/README.md).

## Linux / zsh

Zsh theme, prompts, and related files live under [`linux/photontoaster/`](linux/photontoaster/). On Ubuntu under WSL, see the installer script in that folder.

## Other folders

Other script collections (for example `directory-opus/`) are separate; each area may have its own README.
