param(
  [string]$Root=".",
  [string]$Filter="*"
)

if (-not (Test-Path -LiteralPath $Root)) { return }
Get-ChildItem -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue -Filter $Filter
