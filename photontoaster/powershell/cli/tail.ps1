param(
  [Parameter(Position = 0)] [string]$Path,
  [Alias("n")]
  [Parameter(Position = 1)]
  [int]$Count = 10
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if ($Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
      Write-PTMsg "tail: not found: $Path" Err
    }
    exit 1
  }
  Get-Content -LiteralPath $Path -Tail $Count
} else {
  $input | Select-Object -Last $Count
}