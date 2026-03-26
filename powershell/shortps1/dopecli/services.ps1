param([string]$Pattern = ".")

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'SharedLibs\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
  Write-ShortPs1Msg "Services (filter: $Pattern)" Muted
}

Get-Service -ErrorAction SilentlyContinue |
  Where-Object Name -match $Pattern |
  Sort-Object Status, Name |
  Format-Table -AutoSize