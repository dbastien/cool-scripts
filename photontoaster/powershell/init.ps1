# PhotonToaster PowerShell init — single entry point for config, features, and keybindings.

$env:POWERSHELL_UPDATECHECK = 'Off'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

function Get-PTConfig {
  param(
    [string]$Path = (Join-Path $env:PHOTONTOASTER_CONFIG_DIR "config.toml")
  )
  $cfg = @{}
  if (-not (Test-Path $Path)) { return $cfg }
  $section = ""
  foreach ($lineRaw in Get-Content -Path $Path) {
    $line = $lineRaw.Trim()
    if (-not $line -or $line.StartsWith("#")) { continue }
    if ($line -match '^\[(.+)\]$') {
      $section = $Matches[1].Trim()
      continue
    }
    if ($line -match '^([^=]+)=(.+)$') {
      $key = $Matches[1].Trim()
      $val = $Matches[2].Trim()
      $val = ($val -replace '\s+#.*$', '').Trim()
      if ($val.StartsWith('"') -and $val.EndsWith('"') -and $val.Length -ge 2) {
        $val = $val.Substring(1, $val.Length - 2)
      }
      $fullKey = if ($section) { "$section.$key" } else { $key }
      $cfg[$fullKey] = $val
    }
  }
  return $cfg
}

if (-not $script:PTConfig) {
  $script:PTConfig = Get-PTConfig
}

# zoxide + cd→z early (matches bash/zsh/fish init) so cd works before first prompt.
# Use global: so integrations.ps1 (separate dot-sourced script scope) can skip duplicate init.
$global:PTZoxideEagerInit = $false
if (Get-PTBool -Key 'general.cd_to_z' -Default $true) {
  if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    try {
      Invoke-Expression (& zoxide init powershell | Out-String)
      $_zoxidePtPathEarly = Join-Path $PSScriptRoot 'lib\zoxide-pt.ps1'
      if (Test-Path -LiteralPath $_zoxidePtPathEarly) {
        . $_zoxidePtPathEarly -Config $script:PTConfig
      }
      $global:PTZoxideEagerInit = $true
    } catch { }
  }
}

function Get-PTBool {
  param(
    [Parameter(Mandatory = $true)][string]$Key,
    [bool]$Default = $false
  )
  if (-not $script:PTConfig.ContainsKey($Key)) { return $Default }
  return ($script:PTConfig[$Key] -eq "true")
}

function Get-PTString {
  param(
    [Parameter(Mandatory = $true)][string]$Key,
    [string]$Default = ""
  )
  if (-not $script:PTConfig.ContainsKey($Key)) { return $Default }
  return [string]$script:PTConfig[$Key]
}

# ---------------------------------------------------------------------------
# Startup profiling (gated)
# ---------------------------------------------------------------------------

$_ptProfile = Get-PTBool -Key 'debug.profile_startup'
$_ptSw = $null
if ($_ptProfile) {
  $_ptSw = [System.Diagnostics.Stopwatch]::StartNew()
}

# ---------------------------------------------------------------------------
# Terminal-Icons (if available)
# ---------------------------------------------------------------------------

if (Get-Module -ListAvailable -Name Terminal-Icons -ErrorAction SilentlyContinue) {
  Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Dynamic ls aliases based on config
# ---------------------------------------------------------------------------

$lsTool = if ($script:PTConfig.ContainsKey("general.ls_tool")) {
  $script:PTConfig["general.ls_tool"]
} else {
  "eza"
}

switch ($lsTool) {
  "lsd" {
    function global:l { & lsd -lAh @args }
    function global:ls { & lsd @args }
    function global:lsa { & lsd -a @args }
    function global:la { & lsd -a @args }
    function global:ll { & lsd -lh @args }
    function global:lla { & lsd -lAh @args }
    function global:lt { & lsd --tree --depth=2 @args }
    function global:tree { & lsd --tree @args }
  }
  "broot" {
    function global:l { & broot --sizes --dates --permissions @args }
    function global:ls { & broot --sizes --dates --permissions @args }
    function global:lsa { & broot --sizes --dates --permissions --hidden @args }
    function global:la { & broot --sizes --dates --permissions --hidden @args }
    function global:ll { & broot --sizes --dates --permissions @args }
    function global:lla { & broot --sizes --dates --permissions --hidden @args }
    function global:lt { & broot --sizes @args }
    function global:tree { & broot --sizes @args }
  }
  "ls" {
    function global:l { & ls -lAH @args }
    function global:ls { & ls @args }
    function global:lsa { & ls -a @args }
    function global:la { & ls -a @args }
    function global:ll { & ls -lAh @args }
    function global:lla { & ls -lAh @args }
    function global:lt { & tree -L 2 @args }
  }
  default {
    function global:l { & eza -lah @args }
    function global:ls { & eza @args }
    function global:lsa { & eza -a @args }
    function global:la { & eza -a @args }
    function global:ll { & eza -lh @args }
    function global:lla { & eza -lah @args }
    function global:lt { & eza --tree --level=2 @args }
    function global:tree { & eza --tree @args }
  }
}

# ---------------------------------------------------------------------------
# Typo aliases
# ---------------------------------------------------------------------------

if (Get-PTBool -Key 'general.typo_aliases' -Default $true) {
  function global:gti { & git @args }
  function global:got { & git @args }
  function global:gi { & git @args }
  function global:sl { & ls @args }
  function global:sls { & ls @args }
  function global:lss { & ls @args }
}

# ---------------------------------------------------------------------------
# Windows-native overrides for aliases that the generator can't handle cross-platform
# ---------------------------------------------------------------------------

if ($IsWindows) {
  function global:ipbrief {
    Get-NetIPAddress -ErrorAction SilentlyContinue |
      Format-Table InterfaceAlias, AddressFamily, IPAddress, PrefixLength -AutoSize
  }
  function global:ports {
    Get-NetTCPConnection -ErrorAction SilentlyContinue |
      Where-Object { $_.State -eq 'Listen' } |
      Format-Table LocalAddress, LocalPort, OwningProcess -AutoSize
  }
}

# Clear typos
function global:claer { Clear-Host }
function global:clera { Clear-Host }
function global:clare { Clear-Host }
function global:cler  { Clear-Host }
function global:clr   { Clear-Host }

# Navigate N directories up
function global:up {
  param([int]$n = 1)
  $path = '.' + ('/..') * $n
  Set-Location $path
}

# Winget shorthand
if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
  function global:wg { & winget @args }
}

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

function global:mkcd {
  param([Parameter(Mandatory = $true)][string]$Path)
  New-Item -ItemType Directory -Path $Path -Force | Out-Null
  Set-Location -Path $Path
}

function global:extract {
  param([Parameter(Mandatory = $true)][string]$Archive)
  if (-not (Test-Path -LiteralPath $Archive)) {
    Write-Error "Archive not found: $Archive"
    return
  }
  $lower = $Archive.ToLowerInvariant()
  if ($lower.EndsWith(".zip")) {
    Expand-Archive -LiteralPath $Archive -DestinationPath . -Force
    return
  }
  if (Get-Command tar -ErrorAction SilentlyContinue) {
    & tar -xf $Archive
    return
  }
  Write-Error "No extractor found for $Archive (install tar or use zip archives)."
}

function global:pt-sudo {
  if (Get-Command gsudo -ErrorAction SilentlyContinue) {
    & gsudo @args
    return
  }
  if (Get-Command sudo -ErrorAction SilentlyContinue) {
    & sudo @args
    return
  }
  Write-Error "No sudo/gsudo executable found."
}

if (-not (Get-Command sudo -ErrorAction SilentlyContinue)) {
  Set-Alias -Name sudo -Value pt-sudo -Scope Global
}

# ---------------------------------------------------------------------------
# Auto-ls on directory change
# ---------------------------------------------------------------------------

$script:PTAutoLsEnabled = Get-PTBool -Key "general.auto_ls" -Default $true
$script:PTLastPath = (Get-Location).Path

function Invoke-PTAutoLs {
  if (-not $script:PTAutoLsEnabled) { return }
  $current = (Get-Location).Path
  if ($current -eq $script:PTLastPath) { return }
  $script:PTLastPath = $current
  try {
    if (Get-Command eza -ErrorAction SilentlyContinue) {
      & eza --icons=always --group-directories-first --color=always
    } else {
      Get-ChildItem -Force
    }
  } catch {}
}

# ---------------------------------------------------------------------------
# Did-you-mean (gated)
# ---------------------------------------------------------------------------

$_ptDir = $PSScriptRoot
if (Get-PTBool -Key 'general.did_you_mean' -Default $true) {
  $_dymPath = Join-Path $_ptDir 'did-you-mean.ps1'
  if (Test-Path -LiteralPath $_dymPath) { . $_dymPath }
}

# ---------------------------------------------------------------------------
# Fzf keybindings (gated)
# ---------------------------------------------------------------------------

if (Get-PTBool -Key 'general.fzf_bindings' -Default $true) {
  $_fzfPath = Join-Path $_ptDir 'fzf.ps1'
  if (Test-Path -LiteralPath $_fzfPath) { . $_fzfPath }
}

# ---------------------------------------------------------------------------
# History (unconditional — handles its own atuin/fzf/PSReadLine tiering)
# ---------------------------------------------------------------------------

$_histPath = Join-Path $_ptDir 'history.ps1'
if (Test-Path -LiteralPath $_histPath) {
  . $_histPath -Config $script:PTConfig
}

# ---------------------------------------------------------------------------
# PSReadLine keybindings
# ---------------------------------------------------------------------------

Set-PSReadLineKeyHandler -Key Tab            -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow        -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow      -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Ctrl+d         -Function DeleteCharOrExit
Set-PSReadLineKeyHandler -Key Ctrl+w         -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Key Alt+d          -Function DeleteWord
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
Set-PSReadLineKeyHandler -Key Ctrl+z         -Function Undo
Set-PSReadLineKeyHandler -Key Ctrl+y         -Function Redo

# ---------------------------------------------------------------------------
# Session banner
# ---------------------------------------------------------------------------

if (-not $env:PHOTONTOASTER_SESSION_INIT) {
  $env:PHOTONTOASTER_SESSION_INIT = "1"
  $verFile = Join-Path $env:PHOTONTOASTER_CONFIG_DIR "version"
  if (Test-Path $verFile) {
    $ver = (Get-Content -Path $verFile -Raw).Trim()
    Write-Host ("`e[38;2;255;100;255m PhotonToaster v{0}`e[0m" -f $ver)
  }

  # Quote of the day (gated)
  if (Get-PTBool -Key 'general.quote_of_the_day' -Default $true) {
    $_quotePath = Join-Path $_ptDir 'quote.ps1'
    if (Test-Path -LiteralPath $_quotePath) {
      . $_quotePath
      Show-PTQuote
    }
  }

  # Pwsh update check (gated)
  if (Get-PTBool -Key 'general.update_check' -Default $true) {
    try {
      $currentVer = $PSVersionTable.PSVersion
      $latest = (Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -TimeoutSec 3 -ErrorAction SilentlyContinue).tag_name -replace '^v', ''
      if ($latest -and ([version]$latest -gt $currentVer)) {
        $e = [char]0x1B
        Write-Host "${e}[38;2;255;220;60m`u{F071} pwsh $latest available (current: $currentVer) — https://github.com/PowerShell/PowerShell/releases${e}[0m"
      }
    } catch { }
  }
}

# ---------------------------------------------------------------------------
# Startup profiling result
# ---------------------------------------------------------------------------

if ($_ptProfile -and $_ptSw) {
  $_ptSw.Stop()
  $e = [char]0x1B
  Write-Host "${e}[38;2;150;125;255m`u{F017} init: $([math]::Round($_ptSw.Elapsed.TotalMilliseconds))ms${e}[0m"
}

# ---------------------------------------------------------------------------
# Cleanup init-only variables
# ---------------------------------------------------------------------------

Remove-Variable _ptProfile, _ptSw, _ptDir, lsTool -ErrorAction SilentlyContinue
