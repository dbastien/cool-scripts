# Agents (cool-scripts)

Automation helpers for this repo live in `agent-scripts/`. They are meant for tooling and agents, not end-user setup docs.

## Scripts

- **`agent-scripts/Update-RepoIndex.ps1`** — Scans all `*.ps1` under the repo (skips `.git` and `agent-scripts/.cache`), extracts optional `.SYNOPSIS` text, writes **`agent-scripts/.cache/repo-index.json`** as **compact** UTF-8 JSON. If the path+mtime **SHA-256 fingerprint** matches the previous run, it skips rebuilding (use **`-Force`** to rebuild). Optional env: **`COOL_SCRIPTS_ROOT`** if the repo root is not the parent of `agent-scripts/`.
- **`agent-scripts/Test-RepoPowerShellSyntax.ps1`** — Parses every included script with the PowerShell AST parser; exits `1` on any error.

## Using the index

After an update (or when the cache file is missing), read `agent-scripts/.cache/repo-index.json` for a structured list of scripts. The `.cache/` directory is gitignored.
