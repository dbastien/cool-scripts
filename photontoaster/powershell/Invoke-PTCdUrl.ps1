# .SYNOPSIS
# Handler for the pt-cd: URL protocol — copies cd 'path' to the clipboard (paste into the terminal).

param(
  [Parameter(Position = 0)][string]$Url = ''
)

$ErrorActionPreference = 'Stop'
$raw = $Url.Trim().Trim('"')
if ($raw -notmatch '^pt-cd:(.+)$') { exit 0 }
$tail = $Matches[1]
try {
  $path = [Uri]::UnescapeDataString($tail)
} catch {
  exit 0
}
$path = $path -replace '/', [IO.Path]::DirectorySeparatorChar
if (-not (Test-Path -LiteralPath $path)) { exit 0 }
$item = Get-Item -LiteralPath $path -Force
$target = if ($item.PSIsContainer) { $item.FullName } else { $item.Directory.FullName }
$esc = $target.Replace("'", "''")
Set-Clipboard -Value "cd '$esc'"
