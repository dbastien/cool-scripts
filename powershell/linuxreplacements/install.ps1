param(
  [string]$TargetDir = (Join-Path $env:USERPROFILE "psbin"),
  [switch]$Force
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here "psbin"

if (-not (Test-Path $src)) { throw "Missing 'psbin' folder next to install.ps1" }

New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

Get-ChildItem -LiteralPath $src -Filter "*.ps1" | ForEach-Object {
  $dst = Join-Path $TargetDir $_.Name
  if ((Test-Path $dst) -and (-not $Force)) {
    Write-Host "Skip (exists): $($_.Name)"
  } else {
    Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
    Write-Host "Installed: $($_.Name)"
  }
}

# Add TargetDir to User PATH (HKCU:\Environment\Path) if not present
$envKey = "HKCU:\Environment"
$currentPath = (Get-ItemProperty -Path $envKey -Name Path -ErrorAction SilentlyContinue).Path
if (-not $currentPath) { $currentPath = "" }

$parts = $currentPath -split ";" | Where-Object { $_ -and $_.Trim() -ne "" }
$already = $parts | Where-Object { $_.TrimEnd("\") -ieq $TargetDir.TrimEnd("\") }

if (-not $already) {
  $newPath = ($parts + $TargetDir) -join ";"
  Set-ItemProperty -Path $envKey -Name Path -Value $newPath
  $env:Path = $newPath + ";" + $env:Path
  Write-Host "Added to User PATH: $TargetDir"
} else {
  Write-Host "User PATH already contains: $TargetDir"
}

Write-Host ""
Write-Host "Done."
Write-Host "If scripts won't run, set:  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
Write-Host "Open a new PowerShell window so PATH changes apply everywhere."
