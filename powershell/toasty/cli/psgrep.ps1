[CmdletBinding()]
param(
  [Parameter(Mandatory, Position = 0)] [string]$Pattern,
  [switch]$All
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
  Write-ToastyMsg "Matching processes" Muted
}

$procs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
  $_.Name -match $Pattern -or ($All -and ($_.MainWindowTitle -match $Pattern))
}

$procs |
  Select-Object Id, Name,
  @{n = "CPU"; e = { $_.CPU } },
  @{n = "WS(MB)"; e = { [math]::Round($_.WorkingSet64 / 1MB, 1) } },
  @{n = "PM(MB)"; e = { [math]::Round($_.PagedMemorySize64 / 1MB, 1) } } |
  Sort-Object CPU -Descending |
  Format-Table -AutoSize