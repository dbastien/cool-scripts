# Repository Layout

This repo is organized so root stays minimal.

## Root

- `install` — single entrypoint to choose shell, install config, and optionally switch login shell.
- `install.ps1` — Windows-native PowerShell installer.

## Directories

- `bash/` — bash-specific init, prompt, integrations, completions, aws helpers.
- `zsh/` — zsh-specific init, prompt, integrations, completions, hooks, aws helpers.
- `fish/` — fish-specific init, prompt, integrations, colors, aws helpers.
- `nushell/` — nushell-specific init, prompt, integrations, aliases output.
- `powershell/` — powershell-specific init, prompt, integrations, aws helpers, aliases output.
- `shared/` — cross-shell files:
  - `env.sh`
  - `env.ps1`
  - `pt-config-read`
  - `pt-quote`
  - `aliases.sh` (generated)
- `scripts/` — maintenance tooling:
  - `generate_aliases.sh`
  - `pt-selfcheck`
  - `pt-bench-startup`
- `config/` — user-facing config sources/templates:
  - `aliases.toml` (source of truth for aliases)
  - `config.toml.default`
- `docs/` — project docs and guides.

## Generated files

- `shared/aliases.sh`
- `fish/aliases.fish`
- `nushell/aliases.nu`
- `powershell/aliases.ps1`

These are generated from `config/aliases.toml` via `scripts/generate_aliases.sh`.

## Common commands

- Regenerate aliases:
  - `./scripts/generate_aliases.sh`
- Run validation checks:
  - `./scripts/pt-selfcheck`
- Benchmark startup:
  - `./scripts/pt-bench-startup`

## Conventions

- Keep cross-shell logic in `shared/`.
- Keep shell-specific behavior in its shell folder.
- Add new docs under `docs/`.
- Avoid adding new root files unless they are true entrypoints.
