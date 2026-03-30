<#
.SYNOPSIS
  Request admin, bootstrap PowerShell 7 if needed, then run GuiApps.ps1 (Explorer-friendly).

.DESCRIPTION
  Logs to GuiAppsLauncher.log next to this script. Forwards -CsvPath, -AutoDefault, -WhatIf, and -SkipChocolateyBootstrap to GuiApps.ps1.
  -ScriptDir is applied after elevation (optional working-directory hint from the elevated relaunch).
#>
# Elevate (if needed), ensure PowerShell 7+, then run GuiApps.ps1.
# Intended for double-click from Explorer; works from Windows PowerShell 5.1 or pwsh.
param(
  [string]$ScriptDir = '',
  [string]$CsvPath = '',
  [switch]$AutoDefault,
  [switch]$WhatIf,
  [switch]$SkipChocolateyBootstrap
)

$ErrorActionPreference = 'Stop'

$mainScriptName = 'GuiApps.ps1'
$logFile = Join-Path $PSScriptRoot 'GuiAppsLauncher.log'

function Write-HostAndLog {
  param([string]$Message)
  Write-Host $Message
  Add-Content -Path $logFile -Value "$(Get-Date -Format o) - $Message"
}

function Get-InstallGuiAppsSplat {
  $bp = @{}
  if (-not [string]::IsNullOrWhiteSpace($CsvPath)) { $bp['CsvPath'] = $CsvPath }
  if ($AutoDefault.IsPresent) { $bp['AutoDefault'] = $true }
  if ($WhatIf.IsPresent) { $bp['WhatIf'] = $true }
  if ($SkipChocolateyBootstrap.IsPresent) { $bp['SkipChocolateyBootstrap'] = $true }
  return $bp
}

function Get-LatestPowerShell7Info {
  $releaseInfo = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'
  $asset = $releaseInfo.assets | Where-Object { $_.name -like '*win-x64.msi' } | Select-Object -First 1
  return @{
    Url     = $asset.browser_download_url
    Version = $releaseInfo.tag_name.TrimStart('v')
  }
}

function Install-PowerShell7 {
  $ps7Info = Get-LatestPowerShell7Info
  $installerPath = Join-Path $env:TEMP "PowerShell-7-$($ps7Info.Version).msi"

  if (-not (Test-Path -LiteralPath $installerPath)) {
    Write-HostAndLog "Downloading PowerShell $($ps7Info.Version)..."
    Invoke-WebRequest -Uri $ps7Info.Url -OutFile $installerPath
  } else {
    Write-HostAndLog "PowerShell $($ps7Info.Version) installer already exists. Skipping download."
  }

  Write-HostAndLog "Installing PowerShell $($ps7Info.Version)..."
  $msiLog = Join-Path $env:TEMP 'PS7_Install_Log.txt'
  $process = Start-Process msiexec.exe -ArgumentList @('/i', $installerPath, '/qn', '/l*v', $msiLog) -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    Write-HostAndLog "PowerShell 7 installation failed with exit code: $($process.ExitCode)"
    Write-HostAndLog "Please check the installation log at: $msiLog"
    Write-HostAndLog "You may need to install PowerShell 7 manually. The installer is located at: $installerPath"
    Write-HostAndLog 'After manual installation, please restart this script.'
    Read-Host 'Press Enter to exit'
    exit 1
  }
  Write-HostAndLog "PowerShell $($ps7Info.Version) installed successfully."
}

function Find-PowerShell7 {
  $possiblePaths = @(
    "$env:ProgramFiles\PowerShell\7\pwsh.exe",
    "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
    "$env:LocalAppData\Microsoft\PowerShell\7\pwsh.exe"
  )

  foreach ($path in $possiblePaths) {
    if (Test-Path -LiteralPath $path) {
      return $path
    }
  }

  return $null
}

function Invoke-InstallGuiAppsWithPwsh {
  param([string]$Ps7Path)

  $fullScriptPath = Join-Path $PSScriptRoot $mainScriptName
  if (-not (Test-Path -LiteralPath $fullScriptPath)) {
    Write-HostAndLog "Error: Cannot find $mainScriptName at $fullScriptPath"
    Read-Host 'Press Enter to exit'
    exit 1
  }

  $splat = Get-InstallGuiAppsSplat
  Write-HostAndLog "Launching $mainScriptName with PowerShell 7+ at: $Ps7Path"
  Write-HostAndLog "Full script path: $fullScriptPath"

  & $Ps7Path -NoProfile -ExecutionPolicy Bypass -File $fullScriptPath @splat

  if ($LASTEXITCODE -ne 0) {
    Write-HostAndLog "Error: $mainScriptName exited with code $LASTEXITCODE"
    Read-Host 'Press Enter to exit'
  }
}

# --- Admin gate ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
  Write-Host 'Requesting administrative privileges...'
  $elevArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
    '-ScriptDir', $PSScriptRoot
  )
  if (-not [string]::IsNullOrWhiteSpace($CsvPath)) {
    $elevArgs += @('-CsvPath', $CsvPath)
  }
  if ($AutoDefault.IsPresent) { $elevArgs += '-AutoDefault' }
  if ($WhatIf.IsPresent) { $elevArgs += '-WhatIf' }
  if ($SkipChocolateyBootstrap.IsPresent) { $elevArgs += '-SkipChocolateyBootstrap' }
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $elevArgs -Wait
  exit
}

if (-not [string]::IsNullOrWhiteSpace($ScriptDir)) {
  if (Test-Path -LiteralPath $ScriptDir) {
    Set-Location -LiteralPath $ScriptDir
  } else {
    Write-Warning "ScriptDir not found (ignored): $ScriptDir"
  }
}

Write-HostAndLog "PSScriptRoot: $PSScriptRoot"

try {
  if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-HostAndLog "PowerShell 7+ is required for $mainScriptName. Current version is $($PSVersionTable.PSVersion)"

    if (-not (Find-PowerShell7)) {
      Install-PowerShell7
    } else {
      Write-HostAndLog 'PowerShell 7+ is already installed.'
    }

    $ps7 = Find-PowerShell7
    if (-not $ps7) {
      $searched = @(
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
        "$env:LocalAppData\Microsoft\PowerShell\7\pwsh.exe"
      )
      Write-HostAndLog 'Unable to find PowerShell 7+ executable after install.'
      foreach ($p in $searched) { Write-HostAndLog "  $p" }
      Read-Host 'Press Enter to exit'
      exit 1
    }

    Write-HostAndLog "Launching $mainScriptName with PowerShell 7+..."
    Invoke-InstallGuiAppsWithPwsh -Ps7Path $ps7
  } else {
    Write-HostAndLog "Running $mainScriptName with PowerShell $($PSVersionTable.PSVersion)"
    $gui = Join-Path $PSScriptRoot $mainScriptName
    $splat = Get-InstallGuiAppsSplat
    & $gui @splat
    if ($LASTEXITCODE -ne 0) {
      Write-HostAndLog "Error: $mainScriptName exited with code $LASTEXITCODE"
      Read-Host 'Press Enter to exit'
    }
  }
} catch {
  Write-HostAndLog "An error occurred: $_"
  Write-HostAndLog "Stack Trace: $($_.ScriptStackTrace)"
} finally {
  Read-Host 'Press Enter to exit'
}
