# Toasty (PowerShell)

Windows hub for **CLI scripts** (`cli/`), **shared helpers** (`lib/`), **shell profile** pieces (`shell/`), and **native CLI installers** (`winget/`).

## Layout

| Path | Role |
|------|------|
| `cli/` | Small PowerShell tools (Unix-style helpers, Windows shortcuts); added to PATH via junction. |
| `lib/` | `common.ps1` (color, OSC 8, icons), `aliases.ps1` (parent hops, config-driven ls/cd/typo aliases). |
| `shell/` | `init.ps1` (profile entry point), `prompt.ps1` (segment prompt), `quote.ps1` (quote of the day), `install-profile.ps1` (profile helper). |
| `winget/` | `Install-Extern.ps1` + `WingetManifest.ps1` — native CLI tools via winget (rg, bat, fd, eza, fzf, zoxide, jq, and more). |
| `dev/` | `Install-DevDependencies.ps1`, `Toasty.Dev.psd1` — Pester 5 for tests. |
| `tests/` | `RunTests.ps1`, `Toasty.Tests.ps1` — Pester test suite. |
| `install.ps1` | Creates a junction `~/.config/toasty` -> this directory. Updates User PATH, seeds config/quotes, patches `$PROFILE`. |
| `config.toml.default` | Default config template (seeded to `config.toml` on first install). Sections: `[general]`, `[prompt]`, `[colors]`, `[debug]`. |
| `quotes.default.txt` | Default quotes (seeded to `~/.local/share/toasty/quotes.txt`). |

## Quick install

One shot: **Windows Terminal** (winget) if `wt` is missing, then **native CLIs** (full manifest by default), then **Toasty** junction into `~/.config/toasty`.

```powershell
pwsh -File .\powershell\toasty\install.ps1
```

Or from this folder directly:

```powershell
pwsh -File .\install.ps1
```

Options:

- **Default** — full winget manifest (Core + Extended), **thefuck** via pip when Python is available, Fira Code Nerd Font fallback (oh-my-posh / Chocolatey), then Toasty junction.
- `-MinimalExtern` — Core winget packages only; thefuck + Fira fallback still run afterward.
- `-WhatIf` — print winget actions only; **does not** finish Toasty junction/PATH/profile steps (re-run without `-WhatIf`).
- `-Force` — re-create junction if target changed.

## Profile

The installer automatically patches `$PROFILE` to source `shell/init.ps1`. Open a new terminal and the Toasty prompt, aliases, and quote of the day are active.

To re-run just the profile patch: `pwsh -File .\shell\install-profile.ps1`
To remove the profile hook: `pwsh -File .\shell\install-profile.ps1 -Remove`

Disable individual features via `config.toml` or env vars (`TOASTY_NO_PROMPT`, `TOASTY_NO_QUOTE`).

## Configuration

Edit `~/.config/toasty/config.toml` (created from `config.toml.default` on first install):

- `[general]` — `quote_of_the_day`, `typo_aliases`, `photon_aliases` (Photon Toaster–style git/tools; replaces `gc`/`gp`/`gl`/`ps` when git/procs are used), `ls_tool`, `cd_to_z`
- `[prompt]` — theme, segments, icons, duration threshold
- `[colors]` — preset scheme or individual R;G;B overrides
- `[debug]` — `profile_startup` timing

The same `[prompt]` and `[colors]` sections are shared with the zsh side (Photon Toaster).

## Updates

With junction mode, `git pull` in the repo updates Toasty immediately (no re-run needed). Edited `config.toml` and `quotes.txt` are gitignored and stay local.

### Quote of the day

Loaded automatically by `shell/init.ps1`. Disable with `$env:TOASTY_NO_QUOTE = '1'`. Custom file: `$env:TOASTY_QUOTES_FILE`.

### Toasty prompt

`prompt.ps1`: themes `pills`, `pills-merged`, `plain`, `minimal`; segments `user`, `ssh`, `path`, `git`, `venv`, `jobs`, `status`, `duration`, `time`; color presets from `[colors]` in TOML (`colors.scheme` and optional per-color keys). Resolution order: `-ConfigPath`, `$env:TOASTY_PROMPT_CONFIG`, `~/.config/toasty/config.toml` (or `$env:TOASTY_CONFIG_DIR/config.toml`), then `config.toml.default` next to the script. Optional RGB overrides: `TOASTY_C_BLUE`, `TOASTY_C_VIOLET`, etc. Nerd Font recommended (rounded pill glyphs U+E0B6 / U+E0B4). Disable: `$env:TOASTY_NO_PROMPT = '1'`. For Oh My Posh instead, see `..\longer\ohmyposh.ps1`.

```powershell
. (Join-Path $env:USERPROFILE '.config\toasty\shell\init.ps1')
# or patch profile:
.\shell\install-profile.ps1
```

## Native CLIs only

```powershell
.\winget\Install-Extern.ps1           # full winget set + thefuck + Fira fallback
.\winget\Install-Extern.ps1 -Minimal  # Core winget only + thefuck + Fira fallback
```

After install, open a **new** terminal so PATH picks up winget shims. For **zoxide** in PowerShell:

```powershell
Invoke-Expression (& { (zoxide init powershell | Out-String) })
```

## Optional: `..`, `...`, etc.

`aliases.ps1` (loaded by `shell/init.ps1`) defines parent-directory helpers (`..` through `......`) and `up` / `Up-Location` (e.g. `up 3`), plus config-driven `ls` and `cd` aliases. If you source `shell/init.ps1` in your profile these are available automatically.

## CLI commands

- sed     (regex replace; optional `-i` to edit file in place)
- sortu   (sort unique)
- jq      (JSON pretty print / select properties; use winget `jq` for full jq if you ran `.\winget\Install-Extern.ps1` or `.\install.ps1`)
- psgrep  (search processes)
- killp   (kill processes by pattern; supports -WhatIf / -Confirm)
- realpath, lns (symlink), tee, env, mkcd
- top     (refreshing process view; `-Sort cpu|mem`, `-n`, `-s`, `-Once`)

```powershell
sed "foo" "bar" .\file.txt
sed "foo" "bar" .\file.txt -i

cat .\names.txt | sortu
jq .\data.json
jq .\data.json -Property name,id

psgrep "chrome"
killp "chrome" -WhatIf
top -Sort mem -n 25
```
