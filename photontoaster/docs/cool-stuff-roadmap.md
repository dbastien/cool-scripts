# PhotonToaster Cool Stuff Roadmap

This document turns the roadmap plan into an implementation guide with measurable targets.

## KPIs

- Startup mean latency:
  - zsh target: under 200ms
  - PowerShell (`-NoProfile`) target: under 220ms
  - PowerShell (profile enabled) target: under 350ms
- Prompt render overhead:
  - avoid per-prompt expensive subprocesses unless segment is enabled
- Completion responsiveness:
  - first completion after startup under 300ms
  - subsequent completions under 100ms
- Integration load strategy:
  - heavy integrations lazy-loaded by default

## Benchmark Methodology

- Run `scripts/pt-bench-startup --json docs/benchmarks/startup-latest.json --markdown docs/benchmarks/startup-latest.md`
- Run `scripts/pt-bench-powershell --json docs/benchmarks/powershell-latest.json`
- Record host, shell versions, and feature flags in the markdown benchmark notes.
- Compare against previous run before enabling new defaults.

## Implemented Workstreams

### Cross-shell Quick Wins

- Added `general.lazy_integrations` and `general.everything_integration` config keys.
- Added Everything integration command:
  - zsh: `fe`
  - PowerShell: `fe`
- Added PowerShell parity helpers:
  - `mkcd`, `extract`, `pt-sudo` (`sudo` alias when no native `sudo` is present)
- Synced auto-`ls` behavior in PowerShell via `Invoke-PTAutoLs`.

### Prompt + Theme Parity

- PowerShell prompt now uses the same color token environment variables as zsh (`PHOTONTOASTER_C_*`).
- Shared PowerShell environment now computes palette from `config.toml` (`[colors]` and `[aws]`).
- Prompt includes status, path, optional venv, optional AWS profile, and optional clock segment based on prompt config.

### Performance Pass

- zsh integrations now respect `general.lazy_integrations` for zoxide/direnv/fzf startup cost.
- zsh completion init uses safer cache compile behavior and deferred `fzf-tab` load when lazy mode is enabled.
- PowerShell integrations now support lazy initialization through `Initialize-PTIntegrations`.

### Tooling and Reliability

- Startup benchmark script now supports:
  - PowerShell benchmarking
  - markdown export
  - JSON export
- Added dedicated `scripts/pt-bench-powershell` benchmark helper.

## Next Validation Loop

1. Run benchmark scripts and capture fresh baseline in `docs/benchmarks/`.
2. Run `scripts/pt-selfcheck`.
3. Verify zsh and PowerShell startup in clean terminals.
4. Keep expensive modules behind opt-in flags until benchmarks are stable.
