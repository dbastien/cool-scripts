# Release Notes: Cool Stuff Pass

## Highlights

- Added cross-shell lazy integration toggle (`general.lazy_integrations`).
- Added Everything integration toggle (`general.everything_integration`) with `fe` helper in zsh and PowerShell.
- Upgraded PowerShell prompt to use PhotonToaster color tokens and segment-style rendering.
- Added PowerShell quick-win helpers: `mkcd`, `extract`, `pt-sudo`.
- Extended startup benchmark tooling with JSON + markdown export and PowerShell coverage.

## Operational Notes

- New defaults are safe and can be disabled in `config.toml`.
- Expensive integrations are now lazy by default where possible.
- Benchmark artifacts can be generated into `docs/benchmarks/` for before/after tracking.

## Validation Checklist

- `scripts/pt-selfcheck`
- `scripts/pt-bench-startup --json docs/benchmarks/startup-latest.json --markdown docs/benchmarks/startup-latest.md`
- `scripts/pt-bench-powershell --json docs/benchmarks/powershell-latest.json`
