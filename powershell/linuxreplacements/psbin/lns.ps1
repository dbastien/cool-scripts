[CmdletBinding()]
param(
  [Parameter(Mandatory, Position=0)] [string]$Target,
  [Parameter(Mandatory, Position=1)] [string]$LinkPath,
  [switch]$Force
)

if (Test-Path -LiteralPath $LinkPath) {
  if (-not $Force) { throw "LinkPath exists: $LinkPath (use -Force to overwrite)" }
  Remove-Item -LiteralPath $LinkPath -Recurse -Force
}

New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target | Out-Null
Get-Item -LiteralPath $LinkPath
