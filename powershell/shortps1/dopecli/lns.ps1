[CmdletBinding()]
param(
  [Parameter(Mandatory, Position = 0)] [string]$Target,
  [Parameter(Mandatory, Position = 1)] [string]$LinkPath,
  [switch]$Force
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'SharedLibs\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if (Test-Path -LiteralPath $LinkPath) {
  if (-not $Force) {
    if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
      Write-ShortPs1Msg "lns: LinkPath exists: $LinkPath (use -Force to overwrite)" Err
    }
    throw "LinkPath exists: $LinkPath (use -Force to overwrite)"
  }
  Remove-Item -LiteralPath $LinkPath -Recurse -Force
}

New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target | Out-Null
$item = Get-Item -LiteralPath $LinkPath
if (Get-Command Write-ShortPs1PathLine -ErrorAction SilentlyContinue) {
  Write-ShortPs1PathLine -FullPath $item.FullName
} else {
  $item
}