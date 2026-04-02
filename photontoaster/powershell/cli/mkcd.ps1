param([Parameter(Mandatory, Position = 0)] [string]$Path)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

New-Item -ItemType Directory -LiteralPath $Path -Force | Out-Null
$resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
Set-Location -LiteralPath $resolved
if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
  Write-PTMsg "mkcd: $resolved" Ok
}