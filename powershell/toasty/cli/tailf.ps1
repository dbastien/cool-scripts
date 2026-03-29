param(
  [Parameter(Mandatory, Position = 0)] [string]$Path,
  [Alias("n")]
  [Parameter(Position = 1)]
  [int]$Count = 10
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
param(
  [Parameter(Mandatory, Position = 0)] [string]$Path,
  [Alias("n")]
  [Parameter(Position = 1)]
  [int]$Count = 10
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if (-not (Test-Path -LiteralPath $Path)) {
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg "tailf: not found: $Path" Err
  }
  exit 1
}

if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
  $disp = $Path
  if (Get-Command Format-ToastyPathLink -ErrorAction SilentlyContinue) {
    try { $disp = Format-ToastyPathLink -Path $Path -Display ((Resolve-Path -LiteralPath $Path).Path) } catch { }
  }
  Write-ToastyMsg ("tailf: following last $Count lines of " + $disp) Info
}

Get-Content -LiteralPath $Path -Tail $Count -Wait