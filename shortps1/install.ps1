param(
  [string]$TargetDir = (Join-Path $env:USERPROFILE "psbin"),
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$installScript = (Resolve-Path $MyInvocation.MyCommand.Path).Path

New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

$targetResolved = $null
try { $targetResolved = (Resolve-Path $TargetDir).Path } catch { }

# Find every .ps1 under the folder containing install.ps1 (any subfolder),
# excluding install.ps1 itself and excluding anything already in TargetDir.
$allPs1 = Get-ChildItem -LiteralPath $here -Filter "*.ps1" -File -Recurse | Where-Object {
  $_.FullName -ne $installScript -and
  (-not $targetResolved -or (-not $_.FullName.StartsWith($targetResolved, [System.StringComparison]::OrdinalIgnoreCase)))
}

if (-not $allPs1) {
  Write-Host "No .ps1 files found under: $here"
  exit 0
}

# Detect filename collisions (two different paths both contain same script name)
$collisions = $allPs1 | Group-Object Name | Where-Object { $_.Count -gt 1 }
if ($collisions -and (-not $Force)) {
  Write-Host "Name collisions detected (same .ps1 name in multiple folders)."
  Write-Host "Rename files or re-run with -Force (last one wins):"
  Write-Host ""
  foreach ($g in $collisions) {
    Write-Host "  $($g.Name):"
    foreach ($f in $g.Group) { Write-Host "    - $($f.FullName)" }
  }
  throw "Aborting due to collisions."
}

# Install by flattening into TargetDir (PATH-friendly)
foreach ($f in $allPs1) {
  $dst = Join-Path $TargetDir $f.Name

  if ((Test-Path $dst) -and (-not $Force)) {
    Write-Host "Skip (exists): $($f.Name)"
    continue
  }

  Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
  Write-Host ("Installed{0}: {1}" -f ($(if ($Force) { " (overwrite)" } else { "" })), $f.Name)
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
