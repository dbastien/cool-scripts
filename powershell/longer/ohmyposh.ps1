# Install-OhMyPosh.ps1
# PowerShell 7+: pwsh -ExecutionPolicy Bypass -File .\Install-OhMyPosh.ps1

param(
  [switch]$SkipFont,
  [switch]$SkipProfile,
  [string]$ConfigName = "my.omp.json"
)

$ErrorActionPreference = "Stop"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "WARNING: $msg" -ForegroundColor Yellow }
function Fail($msg) { throw $msg }

function IsWindowsAppsStub($path) {
  if (-not $path) { return $false }
  $p = $path.ToLowerInvariant()
  if ($p -notlike "*\appdata\local\microsoft\windowsapps\oh-my-posh.exe") { return $false }
  try { return ((Get-Item -LiteralPath $path).VersionInfo.FileVersion -eq "0.0.0.0") }
  catch { return $true }
}

function ResolveOmp() {
  Get-Command oh-my-posh -ErrorAction SilentlyContinue | Select-Object -First 1
}

function OmpVersion() {
  try { (& oh-my-posh version 2>$null | Out-String).Trim() } catch { $null }
}

function EnsureFile($path) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if (-not (Test-Path $path)) { New-Item -ItemType File -Force -Path $path | Out-Null }
}

Step "Environment"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "Host:      $($host.Name)"
Write-Host "Exe:       $((Get-Process -Id $PID).Path)"

Step "Checking current oh-my-posh resolution"
$cmd = ResolveOmp
if ($cmd) {
  Write-Host "Resolved:  $($cmd.Source)"
  if (IsWindowsAppsStub $cmd.Source) {
    Warn "You're still resolving the WindowsApps alias stub."
    Warn "Disable it: Settings -> Apps -> Advanced app settings -> App execution aliases -> toggle OFF 'oh-my-posh'"
    Fail "oh-my-posh is shadowed by the WindowsApps stub. Fix the alias toggle, restart Windows Terminal, rerun."
  }
} else {
  Write-Host "oh-my-posh not found on PATH (we'll install it)."
}

Step "Installing Oh My Posh (winget preferred)"
if (-not $cmd -or -not (OmpVersion)) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install JanDeDobbeleer.OhMyPosh --source winget --accept-package-agreements --accept-source-agreements
  } else {
    Warn "winget not found. Falling back to official install script."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("https://ohmyposh.dev/install.ps1"))
  }
}

Step "Verifying oh-my-posh is real and runnable"
$cmd = ResolveOmp
if (-not $cmd) {
  Fail "oh-my-posh still not found. Close/reopen Windows Terminal to refresh PATH, then rerun."
}
Write-Host "Resolved:  $($cmd.Source)"
if (IsWindowsAppsStub $cmd.Source) {
  Fail "oh-my-posh still resolves to WindowsApps stub. Disable the alias toggle, restart Terminal, rerun."
}
$ver = OmpVersion
if (-not $ver) { Fail "oh-my-posh runs but version could not be queried." }
Write-Host "Version:   $ver"

Step "Creating a durable config file (no POSH_THEMES_PATH required)"
$configDir  = Join-Path $HOME ".config\oh-my-posh"
$configPath = Join-Path $configDir $ConfigName
New-Item -ItemType Directory -Force -Path $configDir | Out-Null

if (-not (Test-Path $configPath)) {
  # This creates a valid config you can edit later.
  & oh-my-posh config export --output $configPath | Out-Null
  Write-Host "Created:   $configPath"
} else {
  Write-Host "Exists:    $configPath"
}

if (-not (Test-Path $configPath)) {
  Fail "Config file was not created. (oh-my-posh config export may have failed.)"
}

Step "Optional Nerd Font install (for glyphs/icons)"
if (-not $SkipFont) {
  try {
    & oh-my-posh font install "MesloLGS NF"
    Write-Host "Font install requested."
    Write-Host "Windows Terminal -> Settings -> Profile -> Appearance -> Font face -> 'MesloLGS NF'" -ForegroundColor Yellow
  } catch {
    Warn "Font install didn't complete here: $($_.Exception.Message)"
    Warn "You can install a Nerd Font manually later and just select it in Windows Terminal."
  }
} else {
  Write-Host "SkipFont set; skipping."
}

Step "Optional profile wiring (PowerShell 7 / Windows Terminal)"
if (-not $SkipProfile) {
  $profilePath = $PROFILE.CurrentUserCurrentHost
  EnsureFile $profilePath

  $initBlock = @"
# Oh My Posh
`$ompConfig = Join-Path `$HOME ".config\oh-my-posh\$ConfigName"
if (Test-Path `$ompConfig) {
  oh-my-posh init pwsh --config `$ompConfig | Invoke-Expression
} else {
  Write-Host "Oh My Posh config not found: `$ompConfig" -ForegroundColor Yellow
}
"@

  $current = Get-Content -LiteralPath $profilePath -Raw

  # Remove any previous block we added (best effort)
  $current = [regex]::Replace($current, '(?ms)^\s*#\s*Oh My Posh\s*.*?(?=^\S|\z)', '')

  Set-Content -LiteralPath $profilePath -Value ($current.TrimEnd() + "`r`n`r`n" + $initBlock + "`r`n") -Encoding UTF8
  Write-Host "Updated:   $profilePath"

  # Apply immediately for this session
  . $profilePath
  Write-Host "Profile loaded."
} else {
  Write-Host "SkipProfile set; skipping."
}

Step "Sanity checks"
Write-Host "where.exe oh-my-posh:"
where.exe oh-my-posh | ForEach-Object { "  $_" } | Write-Host
Write-Host "oh-my-posh version: $(oh-my-posh version)"
Write-Host "config path: $configPath"

Step "Next steps"
Write-Host @"
1) Close and reopen Windows Terminal.
2) If icons look wrong, pick a Nerd Font in:
   Windows Terminal -> Settings -> Profile -> Appearance -> Font face.
3) Edit your config at:
   $configPath
"@
