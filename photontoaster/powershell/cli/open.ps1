param([Parameter(ValueFromRemainingArguments = $true)] [string[]]$Path)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

foreach ($p in $Path) {
  if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
    Write-PTMsg "open: $p" Muted
  }
  Start-Process $p
}