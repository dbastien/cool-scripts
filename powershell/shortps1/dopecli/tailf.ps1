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
$__common = Join-Path $__root 'SharedLibs\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if (-not (Test-Path -LiteralPath $Path)) {
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "tailf: not found: $Path" Err
  }
  exit 1
}

if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
  $disp = $Path
  if (Get-Command Format-ShortPs1PathLink -ErrorAction SilentlyContinue) {
    try { $disp = Format-ShortPs1PathLink -Path $Path -Display ((Resolve-Path -LiteralPath $Path).Path) } catch { }
  }
  Write-ShortPs1Msg ("tailf: following last $Count lines of " + $disp) Info
}

Get-Content -LiteralPath $Path -Tail $Count -Wait