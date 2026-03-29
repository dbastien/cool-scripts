$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

$t = Get-Clipboard -ErrorAction SilentlyContinue
if ([string]::IsNullOrWhiteSpace([string]$t) -and (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue)) {
  Write-ShortPs1Msg "paste: clipboard empty or unavailable" Warn
}
$t