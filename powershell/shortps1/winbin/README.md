# Windows micro-commands (PowerShell)

Tiny helpers that feel "Windows-native" and are nice to have in a psbin.

## Commands
- clip.ps1    : stdin -> clipboard
- paste.ps1   : clipboard -> stdout
- open.ps1    : open file/dir/url with default app (like xdg-open)
- explore.ps1 : open Explorer at a path
- recycle.ps1 : send files to Recycle Bin
- pathadd.ps1 : add a directory to PATH for current session
- wherep.ps1  : pipeline-friendly Get-Command source listing
- ip.ps1      : compact IP/GW/DNS table
- ports.ps1   : list listening TCP ports
- tasks.ps1   : quick top CPU snapshot
- services.ps1: grep-able service list

## Usage examples
- `echo hi | clip`
- `paste`
- `open https://example.com`
- `explore .`
- `recycle somefile.txt`
- `pathadd C:\tools\bin`
- `wherep git`
- `ip`
- `ports`
- `tasks`
- `services audio`
