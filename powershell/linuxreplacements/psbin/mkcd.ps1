param([Parameter(Mandatory, Position=0)] [string]$Path)
New-Item -ItemType Directory -LiteralPath $Path -Force | Out-Null
$resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
Set-Location -LiteralPath $resolved
