# psbin extras: more Linux-ish commands for PowerShell

Layout under `powershell\shortps1\`:

| Area | Folder | Role |
|------|--------|------|
| **PhotonToaster** | `..\photontoaster\` | `cli\` (tools copied to `psbin`), `lib\` (`ShortCommon.ps1`, `ShellAliases.ps1`), `shell\` (quote, prompt, profile hooks, defaults), `Install-PsBin.ps1`, optional `Init.ps1` / `config.psd1` — see `..\photontoaster\README.md` |
| **Shared libs (dev)** | `SharedLibs\` | `Install-DevDependencies.ps1`, `ShortPs1.Dev.psd1`, `Quotes.txt` (sample; optional) |
| **CLI tools** | `cli\` | `Install-Extern.ps1`, `WingetManifest.ps1` (winget native CLIs) |
| **Instellator** | `Instellator\` | Windows desktop apps, Firefox `.xpi` downloads, Chrome/Edge store links (`Install-Full.ps1` orchestration entry + CSVs) |

Runtime styling and OSC8 helpers for the PhotonToaster tools live in `..\photontoaster\lib\ShortCommon.ps1`. Thin wrappers at the `shortps1` root forward to the folders above (`install.ps1` → photontoaster `Install-PsBin.ps1`, `Install-Extern.ps1`, `Install-Full.ps1`, `Install-DevDependencies.ps1`) so `cd shortps1` one-liners stay short.

Winget package IDs for native CLIs are in `cli\WingetManifest.ps1`.

**PhotonToaster** ships quotes and prompt defaults under `photontoaster\shell\` and installs into your profile data / `psbin` via `Install-PsBin.ps1`.

Disable the daily quote in PowerShell: `$env:SHORTPS1_NO_QUOTE = '1'`. Custom file: `$env:SHORTPS1_QUOTES_FILE`.

## Install (recommended)

One shot: **Windows Terminal** (winget) if `wt` is missing, then **native CLIs** (full manifest by default), then **PhotonToaster** `cli\` scripts into `~/psbin`. Skips `jq.ps1` / `wget.ps1` when real `jq.exe` / `wget.exe` are on PATH after winget (avoids shadowing).

```powershell
cd .\powershell\shortps1
.\Install-Full.ps1
```

Options:

- **Default** — full winget manifest (Core + Extended).
- `-MinimalExtern` — expert-only: Core winget set only (rg, bat, fd, eza, fzf, zoxide, jq).
- `-WhatIf` — print winget actions only; **does not** run `..\photontoaster\Install-PsBin.ps1` or Instellator GUI helpers (re-run without `-WhatIf` to copy scripts).
- `-IncludeTheFuck` — `pip install --user thefuck` when Python is available; add the printed profile line yourself.
- `-Force` — forwarded to `install.ps1` / `Install-PsBin.ps1` (overwrite existing copies in `psbin`).
- `-GuiApps` — after PhotonToaster copy, run `Instellator\Install-GuiApps.ps1` (desktop apps picker).
- `-GuiAppsAuto` — install only CSV default-checked GUI packages (no dialog).
- `-FirefoxExtensions` / `-FirefoxExtensionsAuto` — same pattern for `Instellator\Install-FirefoxExtensions.ps1` (`.xpi` downloads).
- `-ChromiumExtensions` / `-ChromiumExtensionsAuto` — opens Chrome Web Store / Edge Add-ons URLs from `Instellator\Chromium-extensions.csv` (click Add in the browser).

## Instellator — desktop apps (separate from CLI)

`Instellator\Install-GuiApps.ps1` reads `Instellator\GUI-apps.csv` (same shape as `references/software.csv`). Categories appear as **tabs**. Checkbox tooltips use the `Tooltip` column when present, otherwise `Notes`.

```powershell
cd .\powershell\shortps1
.\Instellator\Install-GuiApps.ps1
# or: .\Instellator\Install-GuiApps.ps1 -AutoDefault
```

## Instellator — Firefox extension downloads

`Instellator\Install-FirefoxExtensions.ps1` reads `Instellator\Firefox-extensions.csv` and saves `.xpi` files under `Instellator\firefox-extensions\` (install them from the browser or Add-ons UI). Categories appear as **tabs**.

```powershell
cd .\powershell\shortps1
.\Instellator\Install-FirefoxExtensions.ps1
```

## Instellator — Chrome / Edge extension store links

`Instellator\Install-ChromiumExtensions.ps1` reads `Instellator\Chromium-extensions.csv` and opens official store pages in Chrome (if installed) and Edge. You still confirm **Add** in each browser.

```powershell
cd .\powershell\shortps1
.\Instellator\Install-ChromiumExtensions.ps1
```

## Install (scripts only)

```powershell
cd .\powershell\shortps1
.\install.ps1
```

Optional: `.\install.ps1 -Exclude jq.ps1,wget.ps1` to omit named tools.

Installs into `~/psbin` by default and adds it to your **User PATH** (won't overwrite existing files unless `-Force`). Installer scripts under `Instellator\`, `cli\`, `SharedLibs\`, `photontoaster\shell\Install-ProfileHooks.ps1`, etc., are not copied to `psbin` (only PhotonToaster `cli\` tools plus `QuoteOfDay.ps1`, `ShortPs1Prompt.ps1`, seeded `prompt.config.toml` when missing, and `ShellAliases.ps1`).

### Quote of the day (optional)

After `install.ps1`, either dot-source once per session or add to your profile:

```powershell
. (Join-Path $env:USERPROFILE 'psbin\QuoteOfDay.ps1')
Show-ShortPs1QuoteOfDay
```

Or append that automatically:

```powershell
..\photontoaster\shell\Install-ProfileHooks.ps1
```

### ShortPs1 / PhotonToaster prompt (optional)

`ShortPs1Prompt.ps1`: themes `pills`, `pills-merged`, `plain`, `minimal`; segments `user`, `ssh`, `path`, `git`, `venv`, `jobs`, `status`, `duration`, `time`; color presets from `[colors]` in TOML (`colors.scheme` and optional per-color keys). Resolution order: `-ConfigPath`, `$env:DOPE_SHELL_PROMPT_CONFIG` or `$env:SHORTPS1_PROMPT_CONFIG`, `%USERPROFILE%\.config\dopeshell\config.toml` (or `$env:DOPE_SHELL_CONFIG_DIR\config.toml`), then `psbin\prompt.config.toml`, then `prompt.config.default.toml` next to the script. Optional RGB overrides: `DOPE_SHELL_C_BLUE`, `DOPE_SHELL_C_VIOLET`, etc. Nerd Font recommended (rounded pill glyphs U+E0B6 / U+E0B4). Disable: `$env:SHORTPS1_NO_DOPE_PROMPT = '1'` before dot-sourcing. For Oh My Posh instead, see `..\longer\ohmyposh.ps1`.

```powershell
. (Join-Path $env:USERPROFILE 'psbin\ShortPs1Prompt.ps1')
# or append to profile:
..\photontoaster\shell\Install-ProfileHooks.ps1 -DopeShellPrompt
# prompt only (no quote block):
..\photontoaster\shell\Install-ProfileHooks.ps1 -DopeShellPrompt -SkipQuote
```

## Native CLIs only

```powershell
.\Install-Extern.ps1                # full set (default)
.\Install-Extern.ps1 -Minimal       # Core only (expert)
.\Install-Extern.ps1 -NerdFontFiraCode   # optional: after CLIs, install Fira Code Nerd Font (oh-my-posh or choco)
```

After install, open a **new** terminal so PATH picks up winget shims. For **zoxide** in PowerShell:

```powershell
Invoke-Expression (& { (zoxide init powershell | Out-String) })
```

## Optional: `..`, `...`, etc.

`SharedLibs\ShellAliases.ps1` (installed to `psbin` as `ShellAliases.ps1`) defines parent-directory helpers (`..` through `......`) and `up` / `Up-Location` (e.g. `up 3`). Dot-source it from your profile so names land in the global scope:

```powershell
. (Join-Path $env:USERPROFILE 'psbin\ShellAliases.ps1')
```

## New commands

- sed     (regex replace; optional `-i` to edit file in place)
- sortu   (sort unique)
- jq      (JSON pretty print / select properties; use winget `jq` for full jq if you ran `Install-Full.ps1`)
- psgrep  (search processes)
- killp   (kill processes by pattern; supports -WhatIf / -Confirm)

## Honorable mentions

- realpath
- lns     (symlink)
- tee     (wrapper around Tee-Object; `-a` for append)
- env     (print env vars; optional regex filter)
- mkcd    (mkdir + cd)

## top

- top     (refreshing process view; `-Sort cpu|mem`, `-n`, `-s`, `-Once`)

Examples:

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
