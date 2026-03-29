param(
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

$externScript = Join-Path $shortPs1Root 'cli\Install-Extern.ps1'
$installScript = Join-Path $ptRoot 'install.ps1'
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

if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
  Write-ToastyMsg 'Install-Full: step 1 - native CLIs (full PT-aligned winget set; use -MinimalExtern for a smaller subset)' Accent
} else {
  Write-Host '=== Install-Full: native CLIs ==='
}
& $externScript @externArgs

if ($WhatIf) {
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg 'Install-Full: -WhatIf skips install.ps1 and GUI helpers (re-run without -WhatIf).' Warn
  } else {
    Write-Warning 'Install-Full: -WhatIf skips install.ps1.'
  }
} else {
  Sync-PathFromRegistry

  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg 'Install-Full: step 2 - junction Toasty into ~/.config/toasty' Accent
  } else {
    Write-Host '=== Install-Full: Toasty junction ==='
  }

  $installArgs = @{
    Force     = $Force
  }

  & $installScript @installArgs

  if ($GuiAppsAuto -and (Test-Path -LiteralPath $guiScript)) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'Install-Full: optional - Install-GuiApps.ps1 -AutoDefault' Accent
    }
    & $guiScript -AutoDefault
  } elseif ($GuiApps -and (Test-Path -LiteralPath $guiScript)) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'Install-Full: optional - Install-GuiApps.ps1' Accent
    }
    & $guiScript
  }

  if ($FirefoxExtensionsAuto -and (Test-Path -LiteralPath $firefoxScript)) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'Install-Full: optional - Install-FirefoxExtensions.ps1 -AutoDefault' Accent
    }
    & $firefoxScript -AutoDefault
  } elseif ($FirefoxExtensions -and (Test-Path -LiteralPath $firefoxScript)) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'Install-Full: optional - Install-FirefoxExtensions.ps1' Accent
    }
    & $firefoxScript
  }

  if ($ChromiumExtensionsAuto -and (Test-Path -LiteralPath $chromiumScript)) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'Install-Full: optional - Install-ChromiumExtensions.ps1 -AutoDefault' Accent
    }
    & $chromiumScript -AutoDefault
  } elseif ($ChromiumExtensions -and (Test-Path -LiteralPath $chromiumScript)) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'Install-Full: optional - Install-ChromiumExtensions.ps1' Accent
    }
    & $chromiumScript
  }
}

Write-Host ''
if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
  Write-ToastyMsg 'Install-Full: done. Open a new terminal (Windows Terminal recommended) so PATH changes apply.' Ok
  Write-ToastyMsg 'Profile was patched automatically. To re-run:  ..\toasty\shell\install-profile.ps1' Muted
  Write-ToastyMsg 'Optional Fira Code Nerd Font: re-run with -NerdFontFiraCode or tick it in Instellator\Install-GuiApps.ps1.' Muted
  Write-ToastyMsg 'Optional zoxide (PowerShell):  Invoke-Expression (& { (zoxide init powershell | Out-String) })' Muted
  Write-ToastyMsg 'Optional fzf key bindings: see junegunn/fzf Windows section on GitHub.' Muted
  Write-ToastyMsg 'Instellator: Install-GuiApps.ps1  |  Firefox .xpi: Install-FirefoxExtensions.ps1  |  Chrome/Edge: Install-ChromiumExtensions.ps1' Muted
} else {
  Write-Host 'Install-Full: done.'
}
