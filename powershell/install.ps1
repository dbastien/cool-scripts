param(
  [string]$TargetDir = (Join-Path $env:USERPROFILE "psbin"),
  [switch]$Force,
  [switch]$LinuxOnly,
  [switch]$WindowsOnly
)

$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$hereName = Split-Path -Leaf $here

# Determine repo root robustly
# If install.ps1 is inside ...\linuxreplacements\, repo root is parent of that folder.
# Otherwise, assume repo root is parent of the folder containing install.ps1.
$repoRoot = if ($hereName -ieq "linuxreplacements") { Split-Path -Parent $here } else { Split-Path -Parent $here }

function Get-Ps1Files([string]$dir) {
  if (-not (Test-Path -LiteralPath $dir)) { return @() }
  Get-ChildItem -LiteralPath $dir -Filter "*.ps1" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ine "install.ps1" }
}

function Install-From([string]$label, [string]$srcDir) {
  $files = Get-Ps1Files $srcDir
  if (-not $files -or $files.Count -eq 0) {
    Write-Host "No scripts found in $label source: $srcDir"
    return
  }

  Write-Host ""
  Write-Host "Installing $label scripts from: $srcDir"
  foreach ($f in $files) {
    $dst = Join-Path $TargetDir $f.Name
    if ((Test-Path -LiteralPath $dst) -and (-not $Force)) {
      Write-Host "Skip (exists): $($f.Name)"
    } else {
      Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
      Write-Host "Installed: $($f.Name)"
    }
  }
}

New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

$doLinux = -not $WindowsOnly
$doWin   = -not $LinuxOnly

# Linux source: the folder containing this installer (your linuxreplacements folder)
if ($doLinux) {
  Install-From "linuxreplacements" $here
}

# Windows source: under repoRoot\powershell\windows (your stated layout)
if ($doWin) {
  $winPsbin = Join-Path $repoRoot "powershell\windows\psbin"
  $winRoot  = Join-Path $repoRoot "powershell\windows"
  if (Test-Path -LiteralPath $winPsbin) { Install-From "windows" $winPsbin }
  else { Install-From "windows" $winRoot }
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
  Write-Host ""
  Write-Host "Added to User PATH: $TargetDir"
} else {
  Write-Host ""
  Write-Host "User PATH already contains: $TargetDir"
}

Write-Host ""
Write-Host "Done."
Write-Host "If scripts won't run, set:  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
Write-Host "Open a new PowerShell window so PATH changes apply everywhere."
