param([Parameter(Mandatory)] [string]$Dir)
$full = (Resolve-Path -LiteralPath $Dir -ErrorAction Stop).Path
if (-not ($env:Path -split ';' | Where-Object { $_ -eq $full })) { $env:Path = "$full;$env:Path" }
