<#
.SYNOPSIS
  Instellator: desktop GUI apps (GuiApps.ps1) by default; optional FirefoxExt / ChromiumExt.

.DESCRIPTION
  Does not install winget CLI tools — use `powershell\toasty\install.ps1` or `toasty\winget\Install-Extern.ps1`.
  Opens GuiApps.ps1 unless -SkipGuiApps or -WhatIf. Use -GuiAppsAuto for unattended CSV defaults.
  Toasty junction and profile: `powershell\toasty\install.ps1`.
#>
param(
  [switch]$WhatIf,
  [switch]$SkipGuiApps,
  [switch]$GuiAppsAuto,
  [switch]$FirefoxExtensions,
  [switch]$FirefoxExtensionsAuto,
  [switch]$ChromiumExtensions,
  [switch]$ChromiumExtensionsAuto
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$psPow = Split-Path -Parent $here
$ptRoot = Join-Path $psPow 'toasty'
$common = Join-Path $ptRoot 'lib\common.ps1'
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

$guiScript = Join-Path $here 'GuiApps.ps1'
$firefoxScript = Join-Path $here 'FirefoxExt.ps1'
$chromiumScript = Join-Path $here 'ChromiumExt.ps1'
$toastyInstall = Join-Path $ptRoot 'install.ps1'
$externCli = Join-Path $ptRoot 'winget\Install-Extern.ps1'

if ($WhatIf) {
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg 'instellator: -WhatIf skips GuiApps and extension helpers (re-run without -WhatIf).' Warn
    Write-ToastyMsg "Winget CLI dry-run: pwsh -File `"$toastyInstall`" -WhatIf" Muted
  } else {
    Write-Warning 'instellator: -WhatIf skips GuiApps and extension helpers.'
    Write-Host "Winget CLI dry-run: pwsh -File `"$toastyInstall`" -WhatIf"
  }
} else {
  Sync-PathFromRegistry

  if ((Test-Path -LiteralPath $guiScript) -and -not $SkipGuiApps) {
    if ($GuiAppsAuto) {
      if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
        Write-ToastyMsg 'instellator: GuiApps.ps1 -AutoDefault' Accent
      } else {
        Write-Host '=== instellator: GuiApps (-AutoDefault) ==='
      }
      & $guiScript -AutoDefault
    } else {
      if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
        Write-ToastyMsg 'instellator: GuiApps.ps1 (desktop installer)' Accent
      } else {
        Write-Host '=== instellator: GuiApps ==='
      }
      & $guiScript
    }
  }

  if ($FirefoxExtensionsAuto -and (Test-Path -LiteralPath $firefoxScript)) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'instellator: FirefoxExt.ps1 -AutoDefault' Accent
    }
    & $firefoxScript -AutoDefault
  } elseif ($FirefoxExtensions -and (Test-Path -LiteralPath $firefoxScript)) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'instellator: FirefoxExt.ps1' Accent
    }
    & $firefoxScript
  }

  if ($ChromiumExtensionsAuto -and (Test-Path -LiteralPath $chromiumScript)) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'instellator: ChromiumExt.ps1 -AutoDefault' Accent
    }
    & $chromiumScript -AutoDefault
  } elseif ($ChromiumExtensions -and (Test-Path -LiteralPath $chromiumScript)) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'instellator: ChromiumExt.ps1' Accent
    }
    & $chromiumScript
  }
}

Write-Host ''
if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
  Write-ToastyMsg 'instellator: done. Open a new terminal if installers changed PATH.' Ok
  Write-ToastyMsg "Winget CLI tools: pwsh -File `"$toastyInstall`"  (or `"$externCli`"; -Minimal, -IncludeTheFuck, -NerdFontFiraCode on install.ps1)" Muted
  Write-ToastyMsg "Toasty shell (junction, cli PATH, profile): pwsh -File `"$toastyInstall`"  (-Force if ~/.config/toasty points elsewhere)" Muted
  Write-ToastyMsg 'Optional zoxide (PowerShell): Invoke-Expression (& { (zoxide init powershell | Out-String) })' Muted
  Write-ToastyMsg 'Optional fzf key bindings: see junegunn/fzf Windows section on GitHub.' Muted
  Write-ToastyMsg 'Instellator: -SkipGuiApps for extensions-only  |  -FirefoxExtensions / -ChromiumExtensions' Muted
} else {
  Write-Host 'instellator: done.'
  Write-Host "Winget CLIs: pwsh -File `"$toastyInstall`""
  Write-Host "Toasty: pwsh -File `"$toastyInstall`"   (add -Force to replace an existing junction)"
}
