param(
  [string]$TargetDir = (Join-Path $env:USERPROFILE 'psbin'),
  [switch]$Force,
  [switch]$MinimalExtern,
  [switch]$WhatIf,
  [switch]$IncludeTheFuck,
  [switch]$NerdFontFiraCode,
  [switch]$GuiApps,
  [switch]$GuiAppsAuto,
  [switch]$FirefoxExtensions,
  [switch]$FirefoxExtensionsAuto,
  [switch]$ChromiumExtensions,
  [switch]$ChromiumExtensionsAuto
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$shortPs1Root = Split-Path -Parent $here
$psPow = Split-Path -Parent $shortPs1Root
$ptRoot = Join-Path $psPow 'photontoaster'
$common = Join-Path $ptRoot 'lib\ShortCommon.ps1'
if (Test-Path -LiteralPath $common) { . $common }

function Sync-PathFromRegistry {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($machine -and $user) {
    $env:Path = "$machine;$user"
  } elseif ($user) {
    $env:Path = $user
  } elseif ($machine) {
    $env:Path = $machine
  }
}

function Test-NativeProbe {
  param([string]$Name)
  if (-not $Name) { return $false }
  $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $cmd) { return $false }
  return ($cmd.Source -match '\.(exe|EXE)$')
}

$externScript = Join-Path $shortPs1Root 'cli\Install-Extern.ps1'
$installScript = Join-Path $ptRoot 'Install-PsBin.ps1'
$guiScript = Join-Path $here 'Install-GuiApps.ps1'
$firefoxScript = Join-Path $here 'Install-FirefoxExtensions.ps1'
$chromiumScript = Join-Path $here 'Install-ChromiumExtensions.ps1'

$externArgs = @{
  WhatIf             = $WhatIf
  IncludeTheFuck     = $IncludeTheFuck
  NerdFontFiraCode   = $NerdFontFiraCode
}
if ($MinimalExtern) {
  $externArgs['Minimal'] = $true
} else {
  $externArgs['Extended'] = $true
}

if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
  Write-ShortPs1Msg 'Install-Full: step 1 - native CLIs (full PT-aligned winget set; use -MinimalExtern for a smaller subset)' Accent
} else {
  Write-Host '=== Install-Full: native CLIs ==='
}
& $externScript @externArgs

if ($WhatIf) {
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg 'Install-Full: -WhatIf skips Install-PsBin.ps1 and GUI helpers (re-run without -WhatIf).' Warn
  } else {
    Write-Warning 'Install-Full: -WhatIf skips Install-PsBin.ps1.'
  }
} else {
  Sync-PathFromRegistry

  $manifestPath = Join-Path $shortPs1Root 'cli\WingetManifest.ps1'
  . $manifestPath

  $excludeScripts = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($pkg in $ShortPs1WingetPackages) {
    if (-not $pkg.ExcludeScript) { continue }
    if (Test-NativeProbe $pkg.Probe) {
      [void]$excludeScripts.Add($pkg.ExcludeScript)
      if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
        Write-ShortPs1Msg "Will skip PhotonToaster cli script (native $($pkg.Probe)): $($pkg.ExcludeScript)" Muted
      }
    }
  }

  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg 'Install-Full: step 2 - copy PhotonToaster cli to psbin' Accent
  } else {
    Write-Host '=== Install-Full: PhotonToaster cli ==='
  }

  $installArgs = @{
    TargetDir = $TargetDir
    Force     = $Force
  }
  if ($excludeScripts.Count -gt 0) {
    $installArgs['Exclude'] = @($excludeScripts)
  }

  & $installScript @installArgs

  if ($GuiAppsAuto -and (Test-Path -LiteralPath $guiScript)) {
    if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
      Write-ShortPs1Msg 'Install-Full: optional - Install-GuiApps.ps1 -AutoDefault' Accent
    }
    & $guiScript -AutoDefault
  } elseif ($GuiApps -and (Test-Path -LiteralPath $guiScript)) {
    if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
      Write-ShortPs1Msg 'Install-Full: optional - Install-GuiApps.ps1' Accent
    }
    & $guiScript
  }

  if ($FirefoxExtensionsAuto -and (Test-Path -LiteralPath $firefoxScript)) {
    if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
      Write-ShortPs1Msg 'Install-Full: optional - Install-FirefoxExtensions.ps1 -AutoDefault' Accent
    }
    & $firefoxScript -AutoDefault
  } elseif ($FirefoxExtensions -and (Test-Path -LiteralPath $firefoxScript)) {
    if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
      Write-ShortPs1Msg 'Install-Full: optional - Install-FirefoxExtensions.ps1' Accent
    }
    & $firefoxScript
  }

  if ($ChromiumExtensionsAuto -and (Test-Path -LiteralPath $chromiumScript)) {
    if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
      Write-ShortPs1Msg 'Install-Full: optional - Install-ChromiumExtensions.ps1 -AutoDefault' Accent
    }
    & $chromiumScript -AutoDefault
  } elseif ($ChromiumExtensions -and (Test-Path -LiteralPath $chromiumScript)) {
    if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
      Write-ShortPs1Msg 'Install-Full: optional - Install-ChromiumExtensions.ps1' Accent
    }
    & $chromiumScript
  }
}

Write-Host ''
if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
  Write-ShortPs1Msg 'Install-Full: done. Open a new terminal (Windows Terminal recommended) so PATH and shims apply.' Ok
  Write-ShortPs1Msg 'Optional: dot-source  . (Join-Path $env:USERPROFILE ''psbin\ShellAliases.ps1'')' Muted
  Write-ShortPs1Msg 'Optional startup quote: ..\photontoaster\shell\Install-ProfileHooks.ps1 (see README).' Muted
  Write-ShortPs1Msg 'Optional Fira Code Nerd Font: re-run with -NerdFontFiraCode or tick it in Instellator\Install-GuiApps.ps1.' Muted
  Write-ShortPs1Msg 'Optional zoxide (PowerShell):  Invoke-Expression (& { (zoxide init powershell | Out-String) })' Muted
  Write-ShortPs1Msg 'Optional fzf key bindings: see junegunn/fzf Windows section on GitHub.' Muted
  Write-ShortPs1Msg 'Instellator: Install-GuiApps.ps1  |  Firefox .xpi: Install-FirefoxExtensions.ps1  |  Chrome/Edge: Install-ChromiumExtensions.ps1' Muted
} else {
  Write-Host 'Install-Full: done.'
}
