# dopecli (PowerShell)

Single folder of small CLI helpers: Unix-style tools plus Windows-oriented shortcuts. For native CLIs (winget) plus this folder, use `..\Install-Full.ps1` or `..\Instellaator\Install-Full.ps1` from the `shortps1` root; to copy scripts only, use `..\install.ps1` or `..\dope-shell\install.ps1`.

## Linux-ish / portable
- cat, head, tail, tailf, sortu, wc, cut, tr, sed, grep, find, which, realpath, env, tee, xargs, touch, du, df, wget, watch, uptime
- jq (JSON), lns (symlink), mkcd, ps, psgrep, top, killp

## Windows helpers
- clip, paste — clipboard
- open, explore — default app / Explorer
- recycle — Recycle Bin
- pathadd — prepend dir to session PATH
- wherep — resolve command to path (Source / Definition)
- ip, ports, tasks, services — network / process / service snapshots
- 11 — Windows 11–oriented shortcuts helper

## Examples
```powershell
grep foo *.txt
find . -Filter "*.log" -type f
wherep pwsh

echo hi | clip
paste
open https://example.com
explore .
services audio
```
