#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSCommandPath
$DefaultTarget = Join-Path $HOME ".config/photontoaster"
$TargetDir = if ($env:PHOTONTOASTER_CONFIG_DIR) { $env:PHOTONTOASTER_CONFIG_DIR } else { $DefaultTarget }

function Get-ToolPackageManager {
  if ($IsWindows) {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return "winget" }
    if (Get-Command scoop -ErrorAction SilentlyContinue) { return "scoop" }
    if (Get-Command choco -ErrorAction SilentlyContinue) { return "choco" }
    return $null
  }

  if (Get-Command brew -ErrorAction SilentlyContinue) { return "brew" }
  if (Get-Command pacman -ErrorAction SilentlyContinue) { return "pacman" }
  if (Get-Command dnf -ErrorAction SilentlyContinue) { return "dnf" }
  if (Get-Command apt -ErrorAction SilentlyContinue) { return "apt" }
  return $null
}

function Install-Tools {
  param(
    [Parameter(Mandatory = $true)][string]$ManifestPath
  )

  if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-Host "No tools manifest at $ManifestPath; skipping tool install."
    return
  }

  $manager = Get-ToolPackageManager
  if (-not $manager) {
    Write-Host "No supported package manager found; skipping tool install."
    return
  }

  $packages = New-Object System.Collections.Generic.List[string]
  $alreadyPresent = 0
  $unavailable = 0

  foreach ($line in Get-Content -LiteralPath $ManifestPath) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line.StartsWith("#")) { continue }

    $cols = $line -split "`t"
    if ($cols.Length -lt 8) { continue }
    if ($cols[0] -eq "binary") { continue }

    $binary = $cols[0]
    if (Get-Command $binary -ErrorAction SilentlyContinue) {
      $alreadyPresent++
      continue
    }

    $pkg = switch ($manager) {
      "brew" { $cols[1] }
      "pacman" { $cols[2] }
      "dnf" { $cols[3] }
      "apt" { $cols[4] }
      "winget" { $cols[5] }
      "scoop" { $cols[6] }
      "choco" { $cols[7] }
      default { "-" }
    }

    if ([string]::IsNullOrWhiteSpace($pkg) -or $pkg -eq "-") {
      $unavailable++
      continue
    }

    if (-not $packages.Contains($pkg)) {
      $null = $packages.Add($pkg)
    }
  }

  if ($packages.Count -eq 0) {
    Write-Host "All available tools are already installed for $manager. (present: $alreadyPresent, unavailable: $unavailable)"
    return
  }

  Write-Host "Installing $($packages.Count) missing tools using $manager..."
  switch ($manager) {
    "brew" {
      brew install @($packages.ToArray())
    }
    "pacman" {
      sudo -v
      sudo pacman -S --needed --noconfirm @($packages.ToArray())
    }
    "dnf" {
      sudo -v
      sudo dnf install -y @($packages.ToArray())
    }
    "apt" {
      sudo -v
      sudo apt install -y @($packages.ToArray())
    }
    "winget" {
      foreach ($pkg in $packages) {
        winget install --accept-source-agreements --accept-package-agreements -e --id $pkg
      }
    }
    "scoop" {
      if ($packages | Where-Object { $_ -like "extras/*" }) {
        $bucketList = scoop bucket list 2>$null
        if (-not ($bucketList -match "(?m)^extras(\s|$)")) {
          scoop bucket add extras
        }
      }
      scoop install @($packages.ToArray())
    }
    "choco" {
      choco install @($packages.ToArray()) -y
    }
  }

  Write-Host "Tool install summary: installed $($packages.Count), already present $alreadyPresent, unavailable $unavailable."
}

function Copy-PhotonToasterTree {
  param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$DestDir
  )

  New-Item -ItemType Directory -Path $DestDir -Force | Out-Null

  $runtimeDirs = @("bash", "zsh", "fish", "nushell", "powershell", "shared", "scripts")
  foreach ($dir in $runtimeDirs) {
    $src = Join-Path $SourceDir $dir
    if (-not (Test-Path -LiteralPath $src)) { continue }
    $dest = Join-Path $DestDir $dir
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
  }

  $configSrc = Join-Path $SourceDir "config"
  if (Test-Path -LiteralPath $configSrc) {
    foreach ($file in Get-ChildItem -LiteralPath $configSrc -File) {
      Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $DestDir $file.Name) -Force
    }
  }
}

function Remove-ManagedBlock {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$StartMarker,
    [Parameter(Mandatory = $true)][string]$EndMarker
  )

  if (-not (Test-Path -LiteralPath $Path)) { return }

  $lines = Get-Content -LiteralPath $Path
  $result = New-Object System.Collections.Generic.List[string]
  $skip = $false
  foreach ($line in $lines) {
    if ($line -eq $StartMarker) { $skip = $true; continue }
    if ($line -eq $EndMarker) { $skip = $false; continue }
    if (-not $skip) { $result.Add($line) }
  }
  Set-Content -LiteralPath $Path -Value $result
}

Write-Host "Installing PhotonToaster into: $TargetDir"
Install-Tools -ManifestPath (Join-Path $RootDir "config" "tools.tsv")
Copy-PhotonToasterTree -SourceDir $RootDir -DestDir $TargetDir

$genScript = Join-Path $TargetDir "scripts/generate_aliases.sh"
$bash = Get-Command bash -ErrorAction SilentlyContinue
if ($bash -and (Test-Path -LiteralPath $genScript)) {
  & $bash.Source $genScript
} else {
  Write-Host "bash not found; skipping alias regeneration (using bundled powershell/aliases.ps1)."
}

# Add powershell/cli to User PATH so cli tools are available as commands
$cliDir = Join-Path $TargetDir "powershell/cli"
if ($IsWindows) {
  $envKey = 'HKCU:\Environment'
  $currentPath = (Get-ItemProperty -Path $envKey -Name Path -ErrorAction SilentlyContinue).Path
  if (-not $currentPath) { $currentPath = '' }
  $parts = $currentPath -split ';' | Where-Object { $_ -and $_.Trim() -ne '' }
  $already = $parts | Where-Object { $_.TrimEnd('\') -ieq $cliDir.TrimEnd('\') }
  if (-not $already) {
    $newPath = ($parts + $cliDir) -join ';'
    Set-ItemProperty -Path $envKey -Name Path -Value $newPath
    $env:Path = $newPath + ';' + $env:Path
    Write-Host "Added to User PATH: $cliDir"
  } else {
    Write-Host "User PATH already contains: $cliDir"
  }
} else {
  $shellRc = if ($env:SHELL -match 'zsh') { Join-Path $HOME '.zshrc' } else { Join-Path $HOME '.bashrc' }
  $exportLine = 'export PATH="' + $cliDir + ':$PATH"'
  if ((Test-Path $shellRc) -and (Get-Content $shellRc -Raw) -match [regex]::Escape($cliDir)) {
    Write-Host "PATH already contains: $cliDir"
  } else {
    Write-Host "Add to your shell rc: $exportLine"
  }
}

$configFile = Join-Path $TargetDir "config.toml"
$defaultConfig = Join-Path $TargetDir "config.toml.default"
if (-not (Test-Path -LiteralPath $configFile) -and (Test-Path -LiteralPath $defaultConfig)) {
  Copy-Item -LiteralPath $defaultConfig -Destination $configFile -Force
}

$profilePath = $PROFILE
$profileDir = Split-Path -Parent $profilePath
New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $profilePath)) {
  New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$startMarker = "# >>> PhotonToaster >>>"
$endMarker = "# <<< PhotonToaster <<<"
Remove-ManagedBlock -Path $profilePath -StartMarker $startMarker -EndMarker $endMarker

$block = @(
  $startMarker
  '$env:PHOTONTOASTER_CONFIG_DIR = "' + $TargetDir + '"'
  '. "$env:PHOTONTOASTER_CONFIG_DIR/shared/env.ps1"'
  '. "$env:PHOTONTOASTER_CONFIG_DIR/powershell/aliases.ps1"'
  '. "$env:PHOTONTOASTER_CONFIG_DIR/powershell/init.ps1"'
  '. "$env:PHOTONTOASTER_CONFIG_DIR/powershell/prompt.ps1"'
  '. "$env:PHOTONTOASTER_CONFIG_DIR/powershell/integrations.ps1"'
  '. "$env:PHOTONTOASTER_CONFIG_DIR/powershell/aws.ps1"'
  $endMarker
)

Add-Content -LiteralPath $profilePath -Value ""
Add-Content -LiteralPath $profilePath -Value $block

Write-Host "Install complete for powershell."
Write-Host "Restart PowerShell (or run: . `$PROFILE) to apply changes."
