# psbin extras: more Linux-ish commands for PowerShell

Layout under `powershell\shortps1\`:

| Area | Folder | Role |
|------|--------|------|
| **Toasty** | `..\toasty\` | `cli\` (tools on PATH via junction), `lib\` (`common.ps1`, `aliases.ps1`), `shell\` (init, prompt, quote, install-profile), `install.ps1`, `config.toml.default` — see `..\toasty\README.md` |
| **Shared libs (dev)** | `SharedLibs\` | `Install-DevDependencies.ps1`, `Toasty.Dev.psd1` |
| **CLI tools** | `cli\` | `Install-Extern.ps1`, `WingetManifest.ps1` (winget native CLIs) |
| **Instellator** | `Instellator\` | Windows desktop apps, Firefox `.xpi` downloads, Chrome/Edge store links (`Install-Full.ps1` orchestration entry + CSVs) |

Runtime styling and OSC8 helpers live in `..\toasty\lib\common.ps1`. Run `..\toasty\install.ps1` to create the junction `~/.config/toasty` and add `cli/` to PATH. Under **`shortps1`**, thin wrappers forward to the folders above (`install.ps1` -> toasty `install.ps1`, plus `Install-Extern.ps1`, `Install-Full.ps1`, `Install-DevDependencies.ps1`) so `cd shortps1` one-liners stay short.

Winget package IDs for native CLIs are in `cli\WingetManifest.ps1`.

**Toasty** ships quotes and prompt defaults under `toasty\shell\` and creates the `~/.config/toasty` junction via `install.ps1`.

Disable the daily quote in PowerShell: `$env:TOASTY_NO_QUOTE = '1'`. Custom file: `$env:TOASTY_QUOTES_FILE`.

## Install (recommended)

One shot: **Windows Terminal** (winget) if `wt` is missing, then **native CLIs** (full manifest by default), then **Toasty** junction into `~/.config/toasty`.

```powershell
cd .\powershell\shortps1
.\Install-Full.ps1
```

Options:

- **Default** — full winget manifest (Core + Extended) then Toasty junction.
- `-MinimalExtern` — expert-only: Core winget set only (rg, bat, fd, eza, fzf, zoxide, jq).
- `-WhatIf` — print winget actions only; **does not** run `..\toasty\install.ps1` or Instellator GUI helpers (re-run without `-WhatIf`).
- `-IncludeTheFuck` — `pip install --user thefuck` when Python is available; add the printed profile line yourself.
- `-Force` — forwarded to `install.ps1` (re-create junction if target changed).
- `-GuiApps` — after Toasty install, run `Instellator\Install-GuiApps.ps1` (desktop apps picker).
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

## Install (Toasty junction only)

```powershell
cd .\powershell\shortps1
.\install.ps1
```

Creates the `~/.config/toasty` junction, adds `cli/` to PATH, and patches `$PROFILE`. Open a new terminal and the prompt is active. Use `-Force` to replace an existing junction that points elsewhere.

### Quote of the day (optional)

Loaded automatically by `shell/init.ps1`. Disable with `$env:TOASTY_NO_QUOTE = '1'`.

### Toasty prompt (optional)

`prompt.ps1`: themes `pills`, `pills-merged`, `plain`, `minimal`; segments `user`, `ssh`, `path`, `git`, `venv`, `jobs`, `status`, `duration`, `time`; color presets from `[colors]` in TOML (`colors.scheme` and optional per-color keys). Resolution order: `-ConfigPath`, `$env:TOASTY_PROMPT_CONFIG`, `~/.config/toasty/config.toml` (or `$env:TOASTY_CONFIG_DIR/config.toml`), then `config.toml.default` next to the script. Optional RGB overrides: `TOASTY_C_BLUE`, `TOASTY_C_VIOLET`, etc. Nerd Font recommended (rounded pill glyphs U+E0B6 / U+E0B4). Disable: `$env:TOASTY_NO_PROMPT = '1'`. For Oh My Posh instead, see `..\longer\ohmyposh.ps1`.

```powershell
. (Join-Path $env:USERPROFILE '.config\toasty\shell\init.ps1')
# or patch profile:
..\toasty\shell\install-profile.ps1
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

`aliases.ps1` (loaded by `shell/init.ps1`) defines parent-directory helpers (`..` through `......`) and `up` / `Up-Location` (e.g. `up 3`), plus config-driven `ls` and `cd` aliases. If you source `shell/init.ps1` in your profile these are available automatically.

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
