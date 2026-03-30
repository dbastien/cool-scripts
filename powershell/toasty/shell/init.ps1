# Toasty init — single entry point for your PowerShell profile.
# Add to $PROFILE:  . (Join-Path $env:USERPROFILE '.config\toasty\shell\init.ps1')
# Or directly:  . <repo>\powershell\toasty\shell\init.ps1
#
# Loads config.toml, shared helpers, aliases, prompt, and quote of the day.
# Disable prompt:  $env:TOASTY_NO_PROMPT = '1'
# Disable quote:   $env:TOASTY_NO_QUOTE = '1'

$ErrorActionPreference = 'Stop'

# Kill the verbose built-in pwsh update banner; Toasty prints a terse hint instead.
$env:POWERSHELL_UPDATECHECK = 'Off'

# UTF-8 output encoding so external tools (eza, bat, etc.) render Unicode/Nerd Font glyphs correctly.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# PSReadLine: prediction off here; Tab + extra keybindings applied at end of init after Import-Module.
Set-PSReadLineOption -PredictionSource None

$_shellDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$_toastyRoot = Split-Path -Parent $_shellDir

# Startup profiling
$_toastyProfileStart = $null
$_toastyProfileEnabled = $false

# 1. Read config.toml
$_toastyConfigDir = if ($env:TOASTY_CONFIG_DIR) { $env:TOASTY_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.config\toasty' }

$_toastyCfgPath = Join-Path $_toastyConfigDir 'config.toml'
if (-not (Test-Path -LiteralPath $_toastyCfgPath)) {
  $_toastyCfgPath = Join-Path $_toastyRoot 'config.toml.default'
}

$_toastyCfg = @{}
if (Test-Path -LiteralPath $_toastyCfgPath) {
  $section = ''
  Get-Content -LiteralPath $_toastyCfgPath -Encoding utf8 | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^\s*#' -or $line -eq '') { return }
    if ($line -match '^\[([^\]]+)\]\s*$') { $section = $Matches[1].Trim(); return }
    if ($line -match '^([^=]+)=(.*)$') {
      $k = $Matches[1].Trim()
      $v = $Matches[2].Trim()
      if ($v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1, $v.Length - 2) }
      $hash = $v.IndexOf('#')
      if ($hash -ge 0) { $v = $v.Substring(0, $hash).TrimEnd() }
      $full = if ($section) { "$section.$k" } else { $k }
      $_toastyCfg[$full] = $v
    }
  }
}

if ($_toastyCfg.ContainsKey('debug.profile_startup') -and $_toastyCfg['debug.profile_startup'] -eq 'true') {
  $_toastyProfileEnabled = $true
  $_toastyProfileStart = [System.Diagnostics.Stopwatch]::StartNew()
}

# Export for other scripts
$global:ToastyRoot = $_toastyRoot
$global:ToastyConfig = $_toastyCfg

# Terse pwsh update hint (replaces the verbose built-in banner)
if ($_toastyCfg['general.update_check'] -ne 'false' -and $PSVersionTable.PSVersion -lt [version]'7.4') {
  Write-Host "pwsh $($PSVersionTable.PSVersion) is old -- run: winget upgrade Microsoft.Powershell" -ForegroundColor DarkYellow
}

# 2. Load shared helpers
$_common = Join-Path $_toastyRoot 'lib\common.ps1'
if (Test-Path -LiteralPath $_common) { . $_common }

# 2b. Terminal-Icons (tab-completion glyphs + Get-ChildItem formatting)
if (Get-Module -ListAvailable -Name Terminal-Icons) { Import-Module Terminal-Icons }

# 3. Load aliases (config-driven)
$_aliases = Join-Path $_toastyRoot 'lib\aliases.ps1'
if (Test-Path -LiteralPath $_aliases) { . $_aliases -Config $_toastyCfg }

# 4. Load prompt (unless disabled)
if ($env:TOASTY_NO_PROMPT -ne '1') {
  $_prompt = Join-Path $_toastyRoot 'shell\prompt.ps1'
  if (Test-Path -LiteralPath $_prompt) {
    $_cfgPath = Join-Path $_toastyConfigDir 'config.toml'
    if (-not (Test-Path -LiteralPath $_cfgPath)) { $_cfgPath = '' }
    . $_prompt -ConfigPath $_cfgPath
  }
}

# 4b. zoxide after prompt so init wraps Toasty's prompt (hook runs; cd -> z still applied)
$_zoxideToasty = Join-Path $_toastyRoot 'lib\zoxide-toasty.ps1'
if (Test-Path -LiteralPath $_zoxideToasty) { . $_zoxideToasty -Config $_toastyCfg }

# 5. Quote of the day (unless disabled via config or env)
$_quoteEnabled = $true
if ($_toastyCfg.ContainsKey('general.quote_of_the_day') -and $_toastyCfg['general.quote_of_the_day'] -eq 'false') {
  $_quoteEnabled = $false
}
if ($env:TOASTY_NO_QUOTE -eq '1') { $_quoteEnabled = $false }

if ($_quoteEnabled) {
  $_quote = Join-Path $_toastyRoot 'shell\quote.ps1'
  if (Test-Path -LiteralPath $_quote) {
    . $_quote
    if (Get-Command Show-ToastyQuote -ErrorAction SilentlyContinue) {
      Show-ToastyQuote
    }
  }
}

# 6. Startup profiling result
if ($_toastyProfileEnabled -and $_toastyProfileStart) {
  $_toastyProfileStart.Stop()
  $e = [char]0x1B
  Write-Host "${e}[38;2;200;100;255m$(([char]0x23F1)) Shell startup: $([math]::Round($_toastyProfileStart.Elapsed.TotalMilliseconds))ms${e}[0m"
}

# PSReadLine last: wins over earlier profile; keeps PredictionSource None; Tab menu + common edit keys.
if (Get-Module -ListAvailable -Name PSReadLine) {
  Import-Module PSReadLine -ErrorAction SilentlyContinue
  if (Get-Module PSReadLine) {
    Set-PSReadLineOption -PredictionSource None
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
    Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo
  }
}

# Cleanup init-only variables
Remove-Variable _shellDir, _toastyRoot, _toastyConfigDir, _toastyCfgPath, _toastyCfg -ErrorAction SilentlyContinue
Remove-Variable _common, _aliases, _prompt, _cfgPath, _zoxideToasty, _quote, _quoteEnabled -ErrorAction SilentlyContinue
Remove-Variable _toastyProfileStart, _toastyProfileEnabled -ErrorAction SilentlyContinue
