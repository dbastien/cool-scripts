param(
  [Parameter(Mandatory, Position = 0)] [string]$Name,
  [Alias("a")] [switch]$All
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

$cmds = Get-Command $Name -ErrorAction SilentlyContinue
if (-not $cmds) {
  if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
    Write-PTMsg "which: no $Name in PATH" Err
  } else {
    Write-Error "which: no $Name in PATH"
  }
  exit 1
}

# Plain paths on stdout for $(which ...) / piping.
if ($All) {
  $cmds | ForEach-Object { $_.Source }
} else {
  ($cmds | Select-Object -First 1).Source
}