param([string]$Path=".")
$full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
Start-Process explorer.exe $full
