# Toasty (PowerShell)

Windows hub for **CLI scripts** (`cli/`), **shared helpers** (`lib/`), and **shell profile** pieces (`shell/`). This folder does **not** run winget, Instellator, or other full-machine installers; those stay under `powershell/shortps1/`.

## Layout

| Path | Role |
|------|------|
| `cli/` | Small PowerShell tools (Unix-style helpers, Windows shortcuts); added to PATH via junction. |
| `lib/` | `common.ps1` (color, OSC 8, icons), `aliases.ps1` (parent hops, config-driven ls/cd/typo aliases). |
| `shell/` | `init.ps1` (profile entry point), `prompt.ps1` (segment prompt), `quote.ps1` (quote of the day), `install-profile.ps1` (profile helper). |
| `install.ps1` | Creates a junction `~/.config/toasty` -> this directory. Updates User PATH, seeds config/quotes, patches `$PROFILE`. |
| `config.toml.default` | Default config template (seeded to `config.toml` on first install). Sections: `[general]`, `[prompt]`, `[colors]`, `[debug]`. |
| `quotes.default.txt` | Default quotes (seeded to `~/.local/share/toasty/quotes.txt`). |

## Quick install

From the repo (junction + winget CLIs + profile patch):

```powershell
pwsh -File .\powershell\toasty\install.ps1
```

Or from this folder directly:

```powershell
pwsh -File .\install.ps1
```

## Profile

The installer automatically patches `$PROFILE` to source `shell/init.ps1`. Open a new terminal and the Toasty prompt, aliases, and quote of the day are active.

To re-run just the profile patch: `pwsh -File .\shell\install-profile.ps1`
To remove the profile hook: `pwsh -File .\shell\install-profile.ps1 -Remove`

Disable individual features via `config.toml` or env vars (`TOASTY_NO_PROMPT`, `TOASTY_NO_QUOTE`).

## Configuration

Edit `~/.config/toasty/config.toml` (created from `config.toml.default` on first install):

- `[general]` — `quote_of_the_day`, `typo_aliases`, `ls_tool`, `cd_to_z`
- `[prompt]` — theme, segments, icons, duration threshold
- `[colors]` — preset scheme or individual R;G;B overrides
- `[debug]` — `profile_startup` timing

The same `[prompt]` and `[colors]` sections are shared with the zsh side (Photon Toaster).

## Updates

With junction mode, `git pull` in the repo updates Toasty immediately (no re-run needed). Edited `config.toml` and `quotes.txt` are gitignored and stay local.

## Full Windows setup

For **winget native CLIs** plus **Toasty** in one flow, use `powershell/shortps1/Install-Full.ps1` (or `Instellator/Install-Full.ps1`).
