# psbin extras: more Linux-ish commands for PowerShell

Layout under `powershell\shortps1\`:

| Area | Folder | Role |
|------|--------|------|
| **Shared libs** | `SharedLibs\` | `ShortCommon.ps1` (styling / OSC8 helpers), `ShellAliases.ps1`, dev-only `Install-DevDependencies.ps1`, `ShortPs1.Dev.psd1`, `Quotes.txt` (sample; optional) |
| **Dope shell** | `dopecli\` | Linux-ish command scripts copied to `~/psbin` |
| | `dope-shell\` | `install.ps1` (copy dopecli + `QuoteOfDay.ps1` + `ShortPs1Prompt.ps1` + `SharedLibs\ShellAliases.ps1` as `psbin\ShellAliases.ps1`; seeds `quotes.txt` and `psbin\prompt.config.toml` when missing), `QuoteOfDay.ps1`, `ShortPs1Prompt.ps1`, `prompt.config.default.toml`, `quotes.default.txt`, `Install-ProfileHooks.ps1` |
| **CLI tools** | `cli\` | `Install-Extern.ps1`, `WingetManifest.ps1` (winget native CLIs) |
| **Instellaator** | `Instellaator\` | Windows desktop apps, Firefox `.xpi` downloads, Chrome/Edge store links (`Install-Full.ps1` orchestration entry + CSVs) |

Shared styling and OSC8 helpers live in `SharedLibs\ShortCommon.ps1`. Thin wrappers at the `shortps1` root forward to the folders above (`install.ps1`, `Install-Extern.ps1`, `Install-Full.ps1`, `Install-DevDependencies.ps1`) so `cd shortps1` one-liners stay short.

Winget package IDs for native CLIs are in `cli\WingetManifest.ps1`.

**Dope shell** (this tree) is self-contained: quotes and prompt config ship under `dope-shell\` and install into your profile data / `psbin` without referencing other repos.

Disable the daily quote in PowerShell: `$env:SHORTPS1_NO_QUOTE = '1'`. Custom file: `$env:SHORTPS1_QUOTES_FILE`.

## Install (recommended)

One shot: **Windows Terminal** (winget) if `wt` is missing, then **native CLIs** (full manifest by default), then **dopecli** into `~/psbin`. Skips `jq.ps1` / `wget.ps1` when real `jq.exe` / `wget.exe` are on PATH after winget (avoids shadowing).

```powershell
cd .\powershell\shortps1
.\Install-Full.ps1
```

Options:

- **Default** — full winget manifest (Core + Extended).
- `-MinimalExtern` — expert-only: Core winget set only (rg, bat, fd, eza, fzf, zoxide, jq).
- `-WhatIf` — print winget actions only; **does not** run `dope-shell\install.ps1` or Instellaator GUI helpers (re-run without `-WhatIf` to copy scripts).
- `-IncludeTheFuck` — `pip install --user thefuck` when Python is available; add the printed profile line yourself.
- `-Force` — forwarded to `dope-shell\install.ps1` (overwrite existing copies in `psbin`).
- `-GuiApps` — after dopecli, run `Instellaator\Install-GuiApps.ps1` (desktop apps picker).
- `-GuiAppsAuto` — install only CSV default-checked GUI packages (no dialog).
- `-FirefoxExtensions` / `-FirefoxExtensionsAuto` — same pattern for `Instellaator\Install-FirefoxExtensions.ps1` (`.xpi` downloads).
- `-ChromiumExtensions` / `-ChromiumExtensionsAuto` — opens Chrome Web Store / Edge Add-ons URLs from `Instellaator\Chromium-extensions.csv` (click Add in the browser).

## Instellaator — desktop apps (separate from CLI)

`Instellaator\Install-GuiApps.ps1` reads `Instellaator\GUI-apps.csv` (same shape as `references/software.csv`). Categories appear as **tabs**. Checkbox tooltips use the `Tooltip` column when present, otherwise `Notes`.

```powershell
cd .\powershell\shortps1
.\Instellaator\Install-GuiApps.ps1
# or: .\Instellaator\Install-GuiApps.ps1 -AutoDefault
```

## Instellaator — Firefox extension downloads

`Instellaator\Install-FirefoxExtensions.ps1` reads `Instellaator\Firefox-extensions.csv` and saves `.xpi` files under `Instellaator\firefox-extensions\` (install them from the browser or Add-ons UI). Categories appear as **tabs**.

```powershell
cd .\powershell\shortps1
.\Instellaator\Install-FirefoxExtensions.ps1
```

## Instellaator — Chrome / Edge extension store links

`Instellaator\Install-ChromiumExtensions.ps1` reads `Instellaator\Chromium-extensions.csv` and opens official store pages in Chrome (if installed) and Edge. You still confirm **Add** in each browser.

```powershell
cd .\powershell\shortps1
.\Instellaator\Install-ChromiumExtensions.ps1
```

## Install (scripts only)

```powershell
cd .\powershell\shortps1
.\install.ps1
```

Optional: `.\install.ps1 -Exclude jq.ps1,wget.ps1` to omit named tools.

Installs into `~/psbin` by default and adds it to your **User PATH** (won't overwrite existing files unless `-Force`). Installer scripts under `Instellaator\`, `cli\`, `SharedLibs\`, `dope-shell\Install-ProfileHooks.ps1`, etc., are not copied to `psbin` (only `dopecli\` tools plus `QuoteOfDay.ps1`, `ShortPs1Prompt.ps1`, seeded `prompt.config.toml` when missing, and `ShellAliases.ps1`).

### Quote of the day (optional)

After `install.ps1`, either dot-source once per session or add to your profile:

```powershell
. (Join-Path $env:USERPROFILE 'psbin\QuoteOfDay.ps1')
Show-ShortPs1QuoteOfDay
```

Or append that automatically:

```powershell
.\dope-shell\Install-ProfileHooks.ps1
```

### Dope shell prompt (optional)

`ShortPs1Prompt.ps1`: themes `pills`, `pills-merged`, `plain`, `minimal`; segments `user`, `ssh`, `path`, `git`, `venv`, `jobs`, `status`, `duration`, `time`; color presets from `[colors]` in TOML (`colors.scheme` and optional per-color keys). Resolution order: `-ConfigPath`, `$env:DOPE_SHELL_PROMPT_CONFIG` or `$env:SHORTPS1_PROMPT_CONFIG`, `%USERPROFILE%\.config\dopeshell\config.toml` (or `$env:DOPE_SHELL_CONFIG_DIR\config.toml`), then `psbin\prompt.config.toml`, then `prompt.config.default.toml` next to the script. Optional RGB overrides: `DOPE_SHELL_C_BLUE`, `DOPE_SHELL_C_VIOLET`, etc. Nerd Font recommended (rounded pill glyphs U+E0B6 / U+E0B4). Disable: `$env:SHORTPS1_NO_DOPE_PROMPT = '1'` before dot-sourcing. For Oh My Posh instead, see `..\longer\ohmyposh.ps1`.

```powershell
. (Join-Path $env:USERPROFILE 'psbin\ShortPs1Prompt.ps1')
# or append to profile:
.\dope-shell\Install-ProfileHooks.ps1 -DopeShellPrompt
# prompt only (no quote block):
.\dope-shell\Install-ProfileHooks.ps1 -DopeShellPrompt -SkipQuote
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
