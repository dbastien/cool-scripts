param(
  [ValidateSet('Winget')][string]$PackageManager = 'Winget',
  [switch]$Minimal,
  [switch]$Extended,
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ptRoot = Split-Path -Parent $here
$psPow = Split-Path -Parent $ptRoot
$common = Join-Path $ptRoot 'lib\common.ps1'
if (Test-Path -LiteralPath $common) { . $common }

$manifestPath = Join-Path $here 'WingetManifest.ps1'
if (-not (Test-Path -LiteralPath $manifestPath)) {
  throw "Missing WingetManifest.ps1 next to winget\Install-Extern.ps1"
}
. $manifestPath

$includeExtended = $true
if ($Minimal) { $includeExtended = $false }
if ($Extended) { $includeExtended = $true }

function Test-ProbeOnPath {
  param([string]$Name)
  if (-not $Name) { return $false }
  $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $cmd) { return $false }
  return ($cmd.Source -match '\.(exe|EXE)$')
}

function Invoke-WingetInstall {
  param([string]$Id)
  if ($WhatIf) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg "WhatIf: winget install -e --id $Id" Muted
    } else {
      Write-Host "WhatIf: winget install -e --id $Id"
    }
    return
  }
  $argList = @('install', '-e', '--id', $Id, '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
  $p = Start-Process -FilePath 'winget' -ArgumentList $argList -Wait -PassThru -NoNewWindow
  if ($p.ExitCode -ne 0) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg "winget exit $($p.ExitCode) for $Id (may already be installed)" Warn
    } else {
      Write-Warning "winget exit $($p.ExitCode) for $Id"
    }
  }
}

if ($PackageManager -eq 'Winget') {
  $wg = Get-Command winget -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $wg) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg "winget not found. Install App Installer from the Microsoft Store, then re-run." Err
    } else {
      Write-Error "winget not found."
    }
    exit 1
  }
}

# Latest Windows Terminal before other winget packages (better host for post-install shells).
$wtId = 'Microsoft.WindowsTerminal'
$wtProbe = 'wt'
if (-not (Test-ProbeOnPath $wtProbe)) {
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg "Installing: $wtId (terminal host)" Info
  } else {
    Write-Host "Installing: $wtId"
  }
  if ($PackageManager -eq 'Winget') {
    Invoke-WingetInstall -Id $wtId
  }
} else {
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg "Skip (on PATH): $wtProbe [$wtId]" Muted
  } else {
    Write-Host "Skip (on PATH): $wtProbe"
  }
}

$toInstall = $ToastyWingetPackages | Where-Object {
  ($_.Tier -eq 'Core') -or ($includeExtended -and $_.Tier -eq 'Extended')
}

foreach ($pkg in $toInstall) {
  if (Test-ProbeOnPath $pkg.Probe) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg "Skip (on PATH): $($pkg.Probe) [$($pkg.Id)]" Muted
    } else {
      Write-Host "Skip (on PATH): $($pkg.Probe)"
    }
    continue
  }
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg "Installing: $($pkg.Id)" Info
  } else {
    Write-Host "Installing: $($pkg.Id)"
  }
  if ($PackageManager -eq 'Winget') {
    Invoke-WingetInstall -Id $pkg.Id
  }
}

function Test-OhMyPoshRunnable {
  $c = Get-Command oh-my-posh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $c) { return $false }
  $p = $c.Source
  if ($p -match '\\WindowsApps\\oh-my-posh\.exe$') {
    try { return ((Get-Item -LiteralPath $p).VersionInfo.FileVersion -ne '0.0.0.0') } catch { return $false }
  }
  return $true
}

function Invoke-NerdFontFiraCodeInstall {
  if ($WhatIf) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'WhatIf: Nerd Font Fira Code (oh-my-posh font install FiraCode, else choco nerd-fonts-firacode)' Muted
    } else {
      Write-Host 'WhatIf: Nerd Font Fira Code'
    }
    return
  }
  if (Test-OhMyPoshRunnable) {
    try {
      $ompExe = (Get-Command oh-my-posh -CommandType Application | Select-Object -First 1).Source
      $p = Start-Process -FilePath $ompExe -ArgumentList @('font', 'install', 'FiraCode') -Wait -PassThru -NoNewWindow
      if ($p.ExitCode -eq 0) {
        if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
          Write-ToastyMsg 'Nerd Font: oh-my-posh installed FiraCode (pick a FiraCode Nerd face in Windows Terminal → Appearance).' Ok
        } else {
          Write-Host 'Nerd Font: FiraCode installed via oh-my-posh.'
        }
        return
      }
    } catch { }
  }
  $choco = Get-Command choco -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($choco) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'Installing nerd-fonts-firacode via Chocolatey (may need elevation)...' Info
    } else {
      Write-Host 'Installing nerd-fonts-firacode via Chocolatey...'
    }
    $cp = Start-Process -FilePath $choco.Source -ArgumentList @('install', 'nerd-fonts-firacode', '-y') -Wait -PassThru -NoNewWindow
    if ($cp.ExitCode -eq 0) {
      if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
        Write-ToastyMsg 'Nerd Font: Chocolatey installed Fira Code Nerd Font. Set Terminal font to a FiraCode Nerd face.' Ok
      }
      return
    }
  }
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg 'Nerd Font Fira Code: install manually or run Toasty shell\Install-NerdFont.ps1.' Warn
  } else {
    Write-Warning 'Nerd Font Fira Code: could not install automatically.'
  }
}

if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
  Write-ToastyMsg 'Nerd Font Fira Code (oh-my-posh / Chocolatey fallback)' Accent
} else {
  Write-Host '=== Nerd Font Fira Code ==='
}
Invoke-NerdFontFiraCodeInstall

if ($WhatIf) {
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg 'WhatIf: pip install --user thefuck' Muted
  }
} else {
  $pip = Get-Command pip -CommandType Application -ErrorAction SilentlyContinue
  $py = Get-Command python -CommandType Application -ErrorAction SilentlyContinue
  if ($pip) {
    & $pip.Source install --user thefuck
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'thefuck: add to profile:  iex (& thefuck --alias 2>$null | Out-String)' Ok
    } else {
      Write-Host 'thefuck: add to profile:  iex (& thefuck --alias 2>$null | Out-String)'
    }
  } elseif ($py) {
    & $py.Source -m pip install --user thefuck
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'thefuck: add to profile:  iex (& thefuck --alias 2>$null | Out-String)' Ok
    }
  } else {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg 'thefuck: skipped (no pip/python on PATH)' Warn
    } else {
      Write-Warning 'thefuck: skipped (no pip/python on PATH)'
    }
  }
}

Write-Host ''
if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
  Write-ToastyMsg 'Done. Open a new terminal (Windows Terminal recommended) so PATH updates apply.' Ok
  Write-ToastyMsg 'Optional zoxide (PowerShell):  Invoke-Expression (& { (zoxide init powershell | Out-String) })' Muted
  Write-ToastyMsg 'Optional fzf key bindings: see junegunn/fzf Windows section on GitHub.' Muted
} else {
  Write-Host 'Install-Extern: done. Open a new terminal so PATH updates apply.'
}
