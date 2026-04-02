# Choosing a Shell for PhotonToaster

This guide helps you pick the best shell for your setup and explains what is supported in this repo.

## Quick recommendation

- Use **zsh** if you want the most polished day-to-day experience.
- Use **fish** if you want modern defaults and friendly UX.
- Use **bash** if you want maximum compatibility.
- Use **nushell** if you prefer structured data workflows.
- Use **powershell** if you want first-class Windows-native ergonomics.

## What PhotonToaster supports

PhotonToaster ships dedicated setup for:

- `bash/`
- `zsh/`
- `fish/`
- `nushell/`
- `powershell/`

Shared behavior (colors, config parsing, quote-of-the-day) lives in `shared/`.

Alias definitions come from `config/aliases.toml` and are generated with `scripts/generate_aliases.sh` into:

- `shared/aliases.sh`
- `fish/aliases.fish`
- `nushell/aliases.nu`
- `powershell/aliases.ps1`

## Decision matrix

### zsh (recommended default)

Pick zsh if you want:

- richest prompt + integrations in this repo
- strong plugin ecosystem
- familiar POSIX-ish scripting behavior

Trade-offs:

- configuration can get complex if you heavily customize

### fish

Pick fish if you want:

- excellent out-of-the-box UX (autosuggestions, readable syntax)
- a clean interactive experience without plugin hunting

Trade-offs:

- fish syntax is not POSIX; script snippets from bash/zsh may need rewrites

### bash

Pick bash if you want:

- broad compatibility across servers/containers
- simple, predictable baseline shell behavior

Trade-offs:

- fewer interactive niceties by default

### nushell

Pick nushell if you want:

- pipeline data as structured tables/records
- modern command composition for JSON/data-heavy workflows

Trade-offs:

- different mental model from classic POSIX shells
- some ecosystem snippets assume bash/zsh/fish

### powershell

Pick powershell if you want:

- native Windows shell experience
- object pipeline for admin/dev workflows
- strong scripting on mixed Windows + cross-platform setups

Trade-offs:

- command idioms differ a lot from POSIX shells
- some Linux-centric shell snippets may not translate directly

## Shell-specific notes in this repo

- Windows PowerShell users can install with `.\install.ps1` (from PowerShell).
- `general.ls_tool` in `config.toml` controls `l`/`ls`/`lsa`/`la`/`ll` family behavior across shells.
- `general.cd_to_z = true` enables zoxide-style `cd` replacement where configured.
- If you edit `config/aliases.toml`, run `./scripts/generate_aliases.sh`.
- If you edit shell setup, run `./scripts/pt-selfcheck`.

## Good defaults to start

If you are unsure, start with:

- shell: **zsh**
- `general.ls_tool = "eza"`
- `general.cd_to_z = true`
- `general.typo_aliases = true`

You can always switch later without losing shared config.
