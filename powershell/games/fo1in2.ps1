<#
Fallout et tu (Fo1in2) quick-builder
- Downloads the latest Fo1in2 release from GitHub
- Tries to locate Fallout 1 + Fallout 2 installs on disk
- Asks you for an output folder and builds a standalone “Fallout 1 in 2” folder by:
  (1) copying your Fallout 2 folder into the output
  (2) unpacking Fo1in2 into that output folder

This does NOT download any game data. You need legitimate Fallout 1 + Fallout 2 installs.
Repo: rotators/Fo1in2 (Fallout et tu / Fo1in2)  :contentReference[oaicite:0]{index=0}
Install note: Fo1in2 is unpacked into the Fallout 2 main folder  :contentReference[oaicite:1]{index=1}
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section([string]$Title) {
  Write-Host ""
  Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Ensure-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Get-SteamLibraries {
  $libs = New-Object System.Collections.Generic.List[string]
  $steamPath = $null

  foreach ($k in @(
    "HKCU:\Software\Valve\Steam",
    "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
    "HKLM:\SOFTWARE\Valve\Steam"
  )) {
    try {
      $p = (Get-ItemProperty -Path $k -Name "SteamPath" -ErrorAction Stop).SteamPath
      if ($p) { $steamPath = $p; break }
    } catch {}
  }

  if (-not $steamPath) { return $libs }

  $steamPath = $steamPath -replace "/", "\"
  $mainCommon = Join-Path $steamPath "steamapps\common"
  if (Test-Path $mainCommon) { $libs.Add($mainCommon) }

  $vdf = Join-Path $steamPath "steamapps\libraryfolders.vdf"
  if (Test-Path $vdf) {
    $lines = Get-Content -LiteralPath $vdf -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
      # Handles both old and new-ish VDF formats loosely.
      if ($line -match '"path"\s*"([^"]+)"') {
        $path = ($Matches[1] -replace "/", "\")
        $common = Join-Path $path "steamapps\common"
        if (Test-Path $common) { $libs.Add($common) }
      } elseif ($line -match '^\s*"\d+"\s*"([^"]+)"') {
        $path = ($Matches[1] -replace "/", "\")
        $common = Join-Path $path "steamapps\common"
        if (Test-Path $common) { $libs.Add($common) }
      }
    }
  }

  return $libs
}

function Get-CommonInstallRoots {
  $roots = New-Object System.Collections.Generic.List[string]

  $pf = ${env:ProgramFiles}
  $pfx86 = ${env:ProgramFiles(x86)}
  $localAppData = $env:LOCALAPPDATA

  foreach ($r in @(
    (Join-Path $pfx86 "Steam\steamapps\common"),
    (Join-Path $pf   "Steam\steamapps\common"),
    (Join-Path $pfx86 "GOG Galaxy\Games"),
    (Join-Path $pf   "GOG Galaxy\Games"),
    (Join-Path $pfx86 "GOG.com"),
    (Join-Path $pf   "GOG.com"),
    (Join-Path $localAppData "Programs")
  )) {
    if ($r -and (Test-Path $r)) { $roots.Add($r) }
  }

  foreach ($steamCommon in (Get-SteamLibraries)) {
    if ($steamCommon -and (Test-Path $steamCommon)) { $roots.Add($steamCommon) }
  }

  # Deduplicate
  return $roots | Select-Object -Unique
}

function Find-GameInstall {
  param(
    [Parameter(Mandatory=$true)][string]$GameName,
    [Parameter(Mandatory=$true)][string[]]$ExeCandidates
  )

  Write-Host "Searching for $GameName..." -ForegroundColor Gray
  $roots = Get-CommonInstallRoots

  # First pass: targeted scan of common roots, depth-limited
  foreach ($root in $roots) {
    foreach ($exe in $ExeCandidates) {
      try {
        $hit = Get-ChildItem -LiteralPath $root -Filter $exe -File -Recurse -Depth 4 -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) {
          return (Split-Path -Parent $hit.FullName)
        }
      } catch {}
    }
  }

  # Second pass: broader scan, but still not “entire disk” insanity
  $fallbackRoots = @(
    "C:\Games",
    "D:\Games",
    "C:\GOG Games",
    "D:\GOG Games"
  ) | Where-Object { Test-Path $_ }

  foreach ($root in $fallbackRoots) {
    foreach ($exe in $ExeCandidates) {
      try {
        $hit = Get-ChildItem -LiteralPath $root -Filter $exe -File -Recurse -Depth 6 -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) {
          return (Split-Path -Parent $hit.FullName)
        }
      } catch {}
    }
  }

  return $null
}

function Prompt-ForExistingFolder {
  param(
    [Parameter(Mandatory=$true)][string]$Prompt,
    [Parameter(Mandatory=$true)][ScriptBlock]$Validate
  )

  while ($true) {
    $p = Read-Host $Prompt
    $p = $p.Trim('"').Trim()
    if (-not $p) { continue }

    if (-not (Test-Path -LiteralPath $p)) {
      Write-Host "Path doesn't exist: $p" -ForegroundColor Yellow
      continue
    }
    if (& $Validate $p) { return $p }

    Write-Host "That folder doesn't look right. Try again." -ForegroundColor Yellow
  }
}

function Prompt-ForOutputFolder {
  while ($true) {
    $p = Read-Host "Enter an OUTPUT folder to build Fallout et tu into (it will be created if needed)"
    $p = $p.Trim('"').Trim()
    if (-not $p) { continue }

    Ensure-Dir $p

    # Safety: avoid copying into the original FO2 folder if user picks it
    return (Resolve-Path -LiteralPath $p).Path
  }
}

function Download-LatestFo1in2Release([string]$DestinationZipPath) {
  Write-Host "Fetching latest release metadata from GitHub..." -ForegroundColor Gray
  $api = "https://api.github.com/repos/rotators/Fo1in2/releases/latest"

  $headers = @{
    "User-Agent" = "Fo1in2Builder/1.0 (PowerShell)"
    "Accept"     = "application/vnd.github+json"
  }

  $release = Invoke-RestMethod -Uri $api -Headers $headers

  if (-not $release.assets -or $release.assets.Count -lt 1) {
    throw "No release assets found. GitHub release metadata didn't include downloadable files."
  }

  # Prefer a .zip asset if available, else first asset.
  $asset = $release.assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
  if (-not $asset) { $asset = $release.assets | Select-Object -First 1 }

  Write-Host "Downloading: $($asset.name)" -ForegroundColor Gray
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $DestinationZipPath -Headers @{
    "User-Agent" = "Fo1in2Builder/1.0 (PowerShell)"
  }
}

function Find-PackageRoot([string]$ExtractedDir) {
  # We want the directory whose *children* look like “to be unpacked into Fallout 2 folder”.
  # Heuristic: find a directory that contains a subdir named "Fallout1in2".
  $candidates = Get-ChildItem -LiteralPath $ExtractedDir -Directory -Recurse -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName "Fallout1in2") }

  $best = $candidates | Select-Object -First 1
  if ($best) { return $best.FullName }

  throw "Couldn't find a package root containing a 'Fallout1in2' folder inside the extracted release."
}

function Copy-DirRobust([string]$Source, [string]$Dest) {
  Ensure-Dir $Dest
  $null = & robocopy $Source $Dest /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
  # Robocopy returns “success with extra info” codes > 0, so we don't treat that as failure.
}

function Copy-DirMerge([string]$Source, [string]$Dest) {
  Ensure-Dir $Dest
  $null = & robocopy $Source $Dest /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
}

Write-Section "Step 1: Locate Fallout 1 + Fallout 2 installs"
$fo1 = Find-GameInstall -GameName "Fallout 1" -ExeCandidates @("falloutw.exe","fallout.exe")
$fo2 = Find-GameInstall -GameName "Fallout 2" -ExeCandidates @("fallout2.exe")

if (-not $fo1) {
  Write-Host "Auto-detect failed for Fallout 1." -ForegroundColor Yellow
  $fo1 = Prompt-ForExistingFolder -Prompt "Enter your Fallout 1 install folder" -Validate {
    param($p) (Test-Path (Join-Path $p "falloutw.exe")) -or (Test-Path (Join-Path $p "fallout.exe"))
  }
}

if (-not $fo2) {
  Write-Host "Auto-detect failed for Fallout 2." -ForegroundColor Yellow
  $fo2 = Prompt-ForExistingFolder -Prompt "Enter your Fallout 2 install folder" -Validate {
    param($p) (Test-Path (Join-Path $p "fallout2.exe"))
  }
}

Write-Host "Fallout 1: $fo1" -ForegroundColor Green
Write-Host "Fallout 2: $fo2" -ForegroundColor Green

Write-Section "Step 2: Ask for output folder"
$outDir = Prompt-ForOutputFolder
if ($outDir -eq (Resolve-Path -LiteralPath $fo2).Path) {
  throw "Output folder must be different from your Fallout 2 install folder (safety)."
}

Write-Host "Output: $outDir" -ForegroundColor Green

Write-Section "Step 3: Download + extract latest Fallout et tu (Fo1in2)"
$tempRoot = Join-Path $env:TEMP ("Fo1in2Builder_" + [guid]::NewGuid().ToString("N"))
$zipPath  = Join-Path $tempRoot "Fo1in2_latest.zip"
$extract  = Join-Path $tempRoot "extracted"

Ensure-Dir $tempRoot
Ensure-Dir $extract

Download-LatestFo1in2Release -DestinationZipPath $zipPath
Expand-Archive -LiteralPath $zipPath -DestinationPath $extract -Force

$packageRoot = Find-PackageRoot -ExtractedDir $extract
Write-Host "Found Fo1in2 package root: $packageRoot" -ForegroundColor Green

Write-Section "Step 4: Build output folder"
Write-Host "Copying Fallout 2 -> output (mirror)..." -ForegroundColor Gray
Copy-DirRobust -Source $fo2 -Dest $outDir

Write-Host "Merging Fo1in2 files into output (like 'unpack into Fallout 2 main folder')..." -ForegroundColor Gray
# Merge the *contents* of the packageRoot into output
Get-ChildItem -LiteralPath $packageRoot | ForEach-Object {
  $src = $_.FullName
  $dst = Join-Path $outDir $_.Name
  if ($_.PSIsContainer) {
    Copy-DirMerge -Source $src -Dest $dst
  } else {
    Copy-Item -LiteralPath $src -Destination $dst -Force
  }
}

Write-Section "Done"
Write-Host "Built Fallout et tu in: $outDir" -ForegroundColor Green
Write-Host ""
Write-Host "Notes:" -ForegroundColor Cyan
Write-Host "- Fo1in2 requires Fallout 1 + Fallout 2 to be installed (you already have them)." -ForegroundColor Gray
Write-Host "- If you use a non-English Fallout 2, you may need to adjust the mod's config/language folder per the readme." -ForegroundColor Gray
Write-Host "- Launch method varies by release; look in '$outDir\Fallout1in2' for the included launcher/readme." -ForegroundColor Gray

# Optional cleanup:
# Remove-Item -LiteralPath $tempRoot -Recurse -Force
