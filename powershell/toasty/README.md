# Toasty (PowerShell)

Windows hub for **CLI scripts** (`cli\`), **shared helpers** (`lib\`), and **shell profile** pieces (`shell\`). This folder does **not** run winget, Instellator, or other full-machine installers; those stay under `powershell\shortps1\`.

## Layout

| Path | Role |
|------|------|
| `cli\` | Small PowerShell tools (Unix-style helpers, Windows shortcuts); copied flat into `psbin` by `Install-PsBin.ps1`. |
| `lib\` | `ShortCommon.ps1` (color, OSC 8, icons), `ShellAliases.ps1` (installed as `psbin\ShellAliases.ps1`). |
| `shell\` | `QuoteOfDay.ps1`, `ShortPs1Prompt.ps1`, `Install-ProfileHooks.ps1`, `quotes.default.txt`, `prompt.config.default.toml`. |
| `Install-PsBin.ps1` | Copies `cli\*.ps1` plus shell helpers and `lib\ShellAliases.ps1` into `%USERPROFILE%\psbin` (default), updates User PATH, seeds quotes and prompt config when missing. |
| `config.psd1` | Static defaults (quote paths, module label). |
| `Init.ps1` | Dot-source to load `config.psd1` and dot-source `lib\ShortCommon.ps1`; sets `$ToastyRoot`, `$ToastyConfig`, `$ToastyQuotesFile`, etc. |

## Quick use

From repo (full path to this folder):

```powershell
pwsh -File .\powershell\toasty\Install-PsBin.ps1
```

Or from `powershell\shortps1` (forwarder):

```powershell
.\install.ps1
```

Optional library-style load (no copy to `psbin`):

```powershell
. (Join-Path $repo 'powershell\toasty\Init.ps1')
```

## Full Windows setup

For **winget native CLIs** plus **Toasty** in one flow, use `powershell\shortps1\Install-Full.ps1` (or `Instellator\Install-Full.ps1`).

## Profile hooks

See `shell\Install-ProfileHooks.ps1` (append quote and/or prompt blocks to your PowerShell profile).
