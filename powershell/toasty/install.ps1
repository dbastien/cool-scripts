# Toasty installer — links this directory into ~/.config/toasty,
# adds cli/ to PATH, seeds config.toml and quotes, patches $PROFILE,
# and optionally runs winget CLI installs.
#
# Usage:  pwsh -File .\powershell\toasty\install.ps1

param(
  [switch]$Force,
  [switch]$MinimalExtern,
  [switch]$SkipFont,
  [switch]$WhatIf,
  [switch]$GuiApps,
  [switch]$FirefoxExtensions,
  [switch]$ChromiumExtensions
)

$ErrorActionPreference = 'Stop'

$toastyRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$common = Join-Path $toastyRoot 'lib\common.ps1'
if (Test-Path -LiteralPath $common) { . $common }

function _msg([string]$m, [string]$l = 'Info') {
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) { Write-ToastyMsg $m $l }
  else { Write-Host $m }
}

# --- Winget CLI installs (optional) ---
$externScript = Join-Path $toastyRoot 'winget\Install-Extern.ps1'
if (Test-Path -LiteralPath $externScript) {
  $externArgs = @{}
  if ($MinimalExtern) { $externArgs['MinimalExtern'] = $true }
  if ($WhatIf) { $externArgs['WhatIf'] = $true }
  & $externScript @externArgs
  Write-Host ''
}

if ($WhatIf) {
  _msg 'WhatIf: skipping Toasty install (junction + PATH + config seed).' Info
  exit 0
}

# --- Junction install ---
$configDir = if ($env:TOASTY_CONFIG_DIR) { $env:TOASTY_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.config\toasty' }

_msg "Linking $configDir -> $toastyRoot" Info

$parentDir = Split-Path -Parent $configDir
if (-not (Test-Path -LiteralPath $parentDir)) {
  New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

if (Test-Path -LiteralPath $configDir) {
  $item = Get-Item -LiteralPath $configDir -Force
  $isJunction = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
  if ($isJunction) {
    $existingTarget = $item.Target
    if ($existingTarget -and ($existingTarget.TrimEnd('\') -ieq $toastyRoot.TrimEnd('\'))) {
      _msg "Junction already points to repo: $configDir" Info
    } elseif ($Force) {
      $item.Delete()
      New-Item -ItemType Junction -Path $configDir -Target $toastyRoot | Out-Null
      _msg "Replaced junction: $configDir -> $toastyRoot" Ok
    } else {
      _msg "Junction exists but points elsewhere: $existingTarget" Warn
      _msg 'Re-run with -Force to replace.' Warn
    }
  } elseif ($item.PSIsContainer) {
    _msg "$configDir exists and is a regular directory (not a junction)." Warn
    _msg 'Remove or rename it, then re-run.' Warn
  } else {
    _msg "$configDir exists and is a file. Remove it, then re-run." Warn
  }
} else {
  New-Item -ItemType Junction -Path $configDir -Target $toastyRoot | Out-Null
  _msg "Created junction: $configDir -> $toastyRoot" Ok
}

# Add cli/ to PATH
$cliDir = Join-Path $configDir 'cli'
$envKey = 'HKCU:\Environment'
$currentPath = (Get-ItemProperty -Path $envKey -Name Path -ErrorAction SilentlyContinue).Path
if (-not $currentPath) { $currentPath = '' }
$parts = $currentPath -split ';' | Where-Object { $_ -and $_.Trim() -ne '' }
$already = $parts | Where-Object { $_.TrimEnd('\') -ieq $cliDir.TrimEnd('\') }
if (-not $already) {
  $newPath = ($parts + $cliDir) -join ';'
  Set-ItemProperty -Path $envKey -Name Path -Value $newPath
  $env:Path = $newPath + ';' + $env:Path
  _msg "Added to User PATH: $cliDir" Ok
} else {
  _msg "User PATH already contains: $cliDir" Info
}

# Seed quotes
$quotesDataDir = if ($env:TOASTY_DATA_DIR) { $env:TOASTY_DATA_DIR } else { Join-Path $env:USERPROFILE '.local\share\toasty' }
$quotesDest = Join-Path $quotesDataDir 'quotes.txt'
if (-not (Test-Path -LiteralPath $quotesDest)) {
  $bundledQuotes = Join-Path $toastyRoot 'quotes.default.txt'
  if (Test-Path -LiteralPath $bundledQuotes) {
    New-Item -ItemType Directory -Path $quotesDataDir -Force | Out-Null
    Copy-Item -LiteralPath $bundledQuotes -Destination $quotesDest -Force
    _msg "Seeded quotes: $quotesDest" Ok
  }
}

# Seed config.toml
$configToml = Join-Path $configDir 'config.toml'
$defaultToml = Join-Path $toastyRoot 'config.toml.default'
if (-not (Test-Path -LiteralPath $configToml) -and (Test-Path -LiteralPath $defaultToml)) {
  Copy-Item -LiteralPath $defaultToml -Destination $configToml -Force
  _msg "Seeded config: $configToml" Ok
}

# --- Nerd Font install + Windows Terminal patching ---
if (-not $SkipFont) {
  $fontScript = Join-Path $toastyRoot 'shell\Install-NerdFont.ps1'
  if (Test-Path -LiteralPath $fontScript) {
    $nfName = ''
    $configToml2 = Join-Path $configDir 'config.toml'
    if (Test-Path -LiteralPath $configToml2) {
      $cfgLines = Get-Content -LiteralPath $configToml2 -Encoding utf8
      $cfgLines | ForEach-Object {
        if ($_ -match '^\s*nerd_font\s*=\s*"?([^"#]+)"?') { $nfName = $Matches[1].Trim() }
      }
    }
    if (-not $nfName) { $nfName = 'FiraCode' }
    $fontArgs = @{ FontName = $nfName }
    if ($Force) { $fontArgs['Force'] = $true }
    & $fontScript @fontArgs
  }
}

# --- Terminal-Icons module ---
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
  _msg 'Installing Terminal-Icons module...' Info
  Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -AllowClobber
  _msg 'Terminal-Icons installed.' Ok
} else {
  _msg 'Terminal-Icons already installed.' Info
}

# --- Patch $PROFILE so init.ps1 loads on every shell ---
$profileScript = Join-Path $toastyRoot 'shell\install-profile.ps1'
if (Test-Path -LiteralPath $profileScript) {
  & $profileScript
}

# --- Instellator GUI flows (optional) ---
$psPow = Split-Path -Parent $toastyRoot
$instellator = Join-Path $psPow 'Instellator'
if ($GuiApps) {
  $s = Join-Path $instellator 'GuiApps.ps1'
  if (Test-Path -LiteralPath $s) { & $s }
}
if ($FirefoxExtensions) {
  $s = Join-Path $instellator 'FirefoxExt.ps1'
  if (Test-Path -LiteralPath $s) { & $s }
}
if ($ChromiumExtensions) {
  $s = Join-Path $instellator 'ChromiumExt.ps1'
  if (Test-Path -LiteralPath $s) { & $s }
}

Write-Host ''
_msg 'Done. Open a new PowerShell window to see your Toasty prompt.' Ok
_msg 'Customize: edit ~/.config/toasty/config.toml (themes, colors, aliases, quote).' Muted
_msg 'If scripts won''t run, set:  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned' Muted
