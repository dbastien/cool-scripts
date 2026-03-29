# PhotonToaster CLI (PowerShell)

Single folder of small CLI helpers: Unix-style tools plus Windows-oriented shortcuts.

## Install / orchestration

- **Scripts only** (this folder → `psbin`): from `powershell\shortps1` run `.\install.ps1`, or run `..\photontoaster\Install-PsBin.ps1` directly.
- **Native CLIs (winget) + this folder**: from `powershell\shortps1` run `.\Install-Full.ps1` or `.\Instellator\Install-Full.ps1`.

Shared styling lives in `..\lib\ShortCommon.ps1` (dot-sourced by each tool).
