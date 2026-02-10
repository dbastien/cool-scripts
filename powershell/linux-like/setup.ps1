pwsh -NoProfile -ExecutionPolicy Bypass -File .\setup-bin.ps1

param(
  [string]$ScriptsDir = (Join-Path $HOME "bin"),
  [switch]$ForcePolicy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-ToUserEnvList {
  param(
    [Parameter(Mandatory)][string]$VarName,
    [Parameter(Mandatory)][string]$ValueToAdd,
    [string]$Separator = ";"
  )

  $currentUser = [Environment]::GetEnvironmentVariable($VarName, "User")
  $currentProc = [Environment]::GetEnvironmentVariable($VarName, "Process")

  $base = if ([string]::IsNullOrWhiteSpace($currentUser)) { $currentProc } else { $currentUser }
  if ([string]::IsNullOrWhiteSpace($base)) { $base = "" }

  $parts = $base.Split($Separator, [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Trim() }
  if ($parts -contains $ValueToAdd) { return $false }

  $newValue = if ($base.EndsWith($Separator) -or [string]::IsNullOrEmpty($base)) { "$base$ValueToAdd" } else { "$base$Separator$ValueToAdd" }
  [Environment]::SetEnvironmentVariable($VarName, $newValue, "User")
  return $true
}

function Ensure-BinFolder {
  param([Parameter(Mandatory)][string]$Dir)
  New-Item -ItemType Directory -Path $Dir -Force | Out-Null
}

function Ensure-ExecutionPolicy {
  param([switch]$Force)

  $current = Get-ExecutionPolicy -Scope CurrentUser
  if ($Force -or $current -in @("Undefined","Restricted","AllSigned")) {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    return $true
  }
  return $false
}

function New-CmdShim {
  param(
    [Parameter(Mandatory)][string]$Ps1Path
  )

  $ps1Item = Get-Item -LiteralPath $Ps1Path
  $dir = $ps1Item.Directory.FullName
  $baseName = [IO.Path]::GetFileNameWithoutExtension($ps1Item.Name)
  $cmdPath = Join-Path $dir "$baseName.cmd"

  $cmd = @"
@echo off
setlocal
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0$($ps1Item.Name)" %*
endlocal
"@

  # Write shim (overwrite if content differs)
  if (Test-Path -LiteralPath $cmdPath) {
    $existing = Get-Content -LiteralPath $cmdPath -Raw
    if ($existing -eq $cmd) { return $false }
  }
  Set-Content -LiteralPath $cmdPath -Value $cmd -Encoding ASCII
  return $true
}

function Remove-StaleCmdShims {
  param([Parameter(Mandatory)][string]$Dir)

  # Remove foo.cmd if foo.ps1 no longer exists (but only our simple wrappers)
  Get-ChildItem -LiteralPath $Dir -Filter *.cmd -File -ErrorAction SilentlyContinue | ForEach-Object {
    $cmdPath = $_.FullName
    $baseName = [IO.Path]::GetFileNameWithoutExtension($_.Name)
    $ps1Path = Join-Path $Dir "$baseName.ps1"
    if (-not (Test-Path -LiteralPath $ps1Path)) {
      # Only delete if it looks like our shim (contains pwsh -File "%~dp0<name>.ps1")
      $txt = Get-Content -LiteralPath $cmdPath -Raw -ErrorAction SilentlyContinue
      if ($txt -match 'pwsh\s+-NoLogo\s+-NoProfile\s+-ExecutionPolicy\s+Bypass\s+-File\s+"%~dp0.*\.ps1"\s+%\\\*') {
        Remove-Item -LiteralPath $cmdPath -Force
      }
    }
  }
}

# --- Do the setup ---
Ensure-BinFolder -Dir $ScriptsDir

$pathChanged   = Add-ToUserEnvList -VarName "Path"    -ValueToAdd $ScriptsDir
$pathextChanged= Add-ToUserEnvList -VarName "PATHEXT" -ValueToAdd ".PS1"
$policyChanged = Ensure-ExecutionPolicy -Force:$ForcePolicy

# Generate shims for every ps1
$shimCount = 0
Get-ChildItem -LiteralPath $ScriptsDir -Filter *.ps1 -File -ErrorAction SilentlyContinue | ForEach-Object {
  if (New-CmdShim -Ps1Path $_.FullName) { $shimCount++ }
}

Remove-StaleCmdShims -Dir $ScriptsDir

# Update current process env so the *current* shell benefits immediately
$env:Path = [Environment]::GetEnvironmentVariable("Path","User") + ";" + [Environment]::GetEnvironmentVariable("Path","Machine")
$env:PATHEXT = [Environment]::GetEnvironmentVariable("PATHEXT","User")

Write-Host ""
Write-Host "✅ Bin setup complete"
Write-Host "   Scripts dir: $ScriptsDir"
Write-Host "   PATH updated:      $pathChanged"
Write-Host "   PATHEXT updated:   $pathextChanged"
Write-Host "   Policy adjusted:   $policyChanged"
Write-Host "   CMD shims created/updated: $shimCount"
Write-Host ""
Write-Host "Try:  hello  (will run hello.ps1 via hello.cmd)"
Write-Host "Note: if you opened a new terminal earlier, you’re already good. Otherwise this session was refreshed too."
