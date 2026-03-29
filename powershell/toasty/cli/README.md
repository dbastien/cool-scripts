# Toasty CLI (PowerShell)

Single folder of small CLI helpers: Unix-style tools plus Windows-oriented shortcuts.

## Install / orchestration

- **Toasty junction** (this folder on PATH): from `powershell\toasty` run `.\install.ps1`.
- **Native CLIs (winget) + this folder**: from `powershell\shortps1` run `.\Install-Full.ps1` or `.\Instellator\Install-Full.ps1`.

Shared styling lives in `..\lib\common.ps1` (dot-sourced by each tool).

## Commands

| Command | Description |
|---------|-------------|
| `11` | Install pretty `ls`/`ll` into your profile |
| `cat` | Print file contents (with optional line numbers) |
| `clip` | Copy stdin/args to clipboard |
| `cut` | Extract fields/columns from text |
| `df` | Disk free space |
| `du` | Disk usage per subdirectory |
| `env` | List or set environment variables |
| `explore` | Open Explorer at a path |
| `find` | Recursive filename search under a directory |
| `grep` | Search file contents by pattern |
| `head` | Print the first N lines |
| `ip` | Show network adapter IPs |
| `jq` | JSON query (lightweight) |
| `killp` | Kill processes by name/pattern |
| `lns` | Create symlinks / junctions |
| `locate` | System-wide filename search — instant via Everything (`es.exe`), falls back to `Get-ChildItem` |
| `mkcd` | Create a directory and cd into it |
| `open` | Open a file with its default app |
| `paste` | Paste from clipboard |
| `pathadd` | Prepend a directory to PATH |
| `ports` | Show listening TCP/UDP ports |
| `ps` | List processes |
| `psgrep` | Search running processes by name |
| `realpath` | Resolve a path to its absolute form |
| `recycle` | Send files to the Recycle Bin |
| `reload` | Re-source your PowerShell profile |
| `sed` | Stream-edit text with regex |
| `services` | List Windows services |
| `sortu` | Sort and deduplicate lines |
| `tail` | Print the last N lines |
| `tailf` | Follow a file (like `tail -f`) |
| `tasks` | List scheduled tasks |
| `tee` | Write stdin to file and stdout |
| `top` | Live process monitor |
| `touch` | Create or update file timestamps |
| `tr` | Translate/delete characters |
| `uptime` | System uptime |
| `watch` | Repeat a command on an interval |
| `wc` | Count lines, words, chars |
| `wget` | Download a URL to a file |
| `wherep` | Show all resolutions of a command name |
| `which` | Print the path of a command |
| `xargs` | Build and execute commands from stdin |
