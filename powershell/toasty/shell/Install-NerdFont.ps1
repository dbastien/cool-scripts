# .SYNOPSIS
# Silently installs a Nerd Font per-user and sets it as the default in Windows Terminal.
# Called by install.ps1; can also be run standalone:
#   pwsh -File Install-NerdFont.ps1 [-FontName FiraCode] [-Force]

param(
  [string]$FontName = '',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

function _msg([string]$m, [string]$l = 'Info') {
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) { Write-ToastyMsg $m $l }
  else { Write-Host $m }
}

$fontMap = @{
  FiraCode     = @{ Asset = 'FiraCode';      Face = 'FiraCode Nerd Font Mono' }
  JetBrainsMono = @{ Asset = 'JetBrainsMono'; Face = 'JetBrainsMono Nerd Font Mono' }
  CascadiaCode = @{ Asset = 'CascadiaCode';  Face = 'CaskaydiaCove Nerd Font Mono' }
  Hack         = @{ Asset = 'Hack';          Face = 'Hack Nerd Font Mono' }
  Meslo        = @{ Asset = 'Meslo';         Face = 'MesloLGS Nerd Font Mono' }
}

if (-not $FontName) { $FontName = 'FiraCode' }
if ($FontName -eq 'none') {
  _msg 'Nerd Font install skipped (nerd_font = none).' Info
  return
}

$entry = $fontMap[$FontName]
if (-not $entry) {
  _msg "Unknown nerd_font '$FontName'. Supported: $($fontMap.Keys -join ', ')" Warn
  return
}

$asset = $entry.Asset
$face  = $entry.Face

# ── Per-user font install ──────────────────────────────────────
$userFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$regPath = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

$alreadyInstalled = $false
if (-not $Force -and (Test-Path $regPath)) {
  $existing = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
  if ($existing) {
    $match = $existing.PSObject.Properties | Where-Object { $_.Value -like "*$asset*NerdFont*" }
    if ($match) { $alreadyInstalled = $true }
  }
}

if ($alreadyInstalled) {
  _msg "$face already installed." Info
} else {
  _msg "Downloading $asset Nerd Font..." Info
  try {
    $tag = (Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' -UseBasicParsing).tag_name
  } catch {
    _msg "Could not reach GitHub API: $_" Warn
    return
  }
  $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$tag/$asset.zip"
  $zip = Join-Path $env:TEMP "$asset-NerdFont-$tag.zip"
  $tmp = Join-Path $env:TEMP "$asset-NerdFont-$tag"

  try { Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing } catch {
    _msg "Download failed: $_" Warn
    return
  }
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  Expand-Archive -Path $zip -DestinationPath $tmp -Force

  if (-not (Test-Path -LiteralPath $userFontDir)) {
    New-Item -ItemType Directory -Path $userFontDir -Force | Out-Null
  }
  if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
  }

  $ttfs = Get-ChildItem -Path $tmp -Filter '*.ttf' -Recurse |
    Where-Object { $_.Name -match 'Mono' -and $_.Name -notmatch 'Propo' }
  if (-not $ttfs) {
    $ttfs = Get-ChildItem -Path $tmp -Filter '*.ttf' -Recurse
  }

  foreach ($f in $ttfs) {
    $dest = Join-Path $userFontDir $f.Name
    Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    $regName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name) + ' (TrueType)'
    New-ItemProperty -Path $regPath -Name $regName -Value $dest -PropertyType String -Force | Out-Null
  }

  Remove-Item $zip -Force -ErrorAction SilentlyContinue
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  _msg "Installed $($ttfs.Count) $face fonts (per-user)." Ok
}

# ── Patch Windows Terminal settings ────────────────────────────
$wtPaths = @(
  (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
  (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json')
)

foreach ($wtSettings in $wtPaths) {
  if (-not (Test-Path -LiteralPath $wtSettings)) { continue }
  try {
    $raw = Get-Content -LiteralPath $wtSettings -Raw -Encoding utf8
    $json = $raw | ConvertFrom-Json

    $defaults = $json.profiles.defaults
    $currentFace = $null
    if ($defaults.PSObject.Properties['font']) {
      $currentFace = $defaults.font.face
    }

    if ($currentFace -eq $face -and -not $Force) {
      _msg "Windows Terminal defaults already use $face." Info
      continue
    }

    if (-not $defaults.PSObject.Properties['font']) {
      $defaults | Add-Member -NotePropertyName 'font' -NotePropertyValue ([pscustomobject]@{ face = $face })
    } else {
      if ($defaults.font -is [string]) {
        $defaults.font = [pscustomobject]@{ face = $face }
      } elseif ($defaults.font.PSObject.Properties['face']) {
        $defaults.font.face = $face
      } else {
        $defaults.font | Add-Member -NotePropertyName 'face' -NotePropertyValue $face
      }
    }

    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $wtSettings -Encoding utf8 -NoNewline
    _msg "Set Windows Terminal default font to $face." Ok
  } catch {
    _msg "Could not patch $wtSettings`: $_" Warn
  }
}
