param([Parameter(Mandatory)] [string]$Name)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

$cmds = @(Get-Command $Name -ErrorAction SilentlyContinue)
if ($cmds.Count -eq 0) {
  if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
    Write-PTMsg "wherep: not found: $Name" Error
  }
  exit 1
}
$cmds | ForEach-Object {
  $p = $_.Source
  if (-not $p) { $p = $_.Definition }
  $p
}