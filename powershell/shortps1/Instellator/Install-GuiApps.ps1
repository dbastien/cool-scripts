#requires -Version 7.2
<#
.SYNOPSIS
  WPF picker for desktop / non-CLI apps (winget + Chocolatey), then installs selections unattended.

.DESCRIPTION
  Data file defaults to GUI-apps.csv next to this script (from references/software.csv). Tooltips: optional Tooltip column, else Notes.
  For headless installs of CSV defaults only: -AutoDefault

.EXAMPLE
  .\Instellator\Install-GuiApps.ps1

.EXAMPLE
  .\Instellator\Install-GuiApps.ps1 -AutoDefault

.EXAMPLE
  .\Instellator\Install-GuiApps.ps1 -CsvPath 'D:\my-apps.csv' -WhatIf
#>
param(
  [string]$CsvPath = '',
  [switch]$AutoDefault,
  [switch]$WhatIf,
  [switch]$SkipChocolateyBootstrap
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$shortPs1Root = Split-Path -Parent $here
$psPow = Split-Path -Parent $shortPs1Root
$ptRoot = Join-Path $psPow 'photontoaster'
if (-not $CsvPath) {
  $CsvPath = Join-Path $here 'GUI-apps.csv'
}

$common = Join-Path $ptRoot 'lib\ShortCommon.ps1'
if (Test-Path -LiteralPath $common) { . $common }

function Write-GuiAppsMsg {
  param([string]$Message, [ValidateSet('Info', 'Ok', 'Warn', 'Err', 'Muted', 'Accent')][string]$Level = 'Info')
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg $Message $Level
  } else {
    Write-Host $Message
  }
}

function Get-SoftwareFromCSV {
  param([string]$Path)
  $categories = [ordered]@{}
  Import-Csv -LiteralPath $Path | ForEach-Object {
    $category = $_.Category
    if (-not $categories.Contains($category)) {
      $categories[$category] = [System.Collections.Generic.List[object]]::new()
    }
    [void]$categories[$category].Add($_)
  }
  return $categories
}

function Ensure-Winget {
  $wg = Get-Command winget -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $wg) {
    Write-GuiAppsMsg 'winget not found. Install App Installer from the Microsoft Store, then re-run.' Err
    exit 1
  }
}

function Ensure-Chocolatey {
  if ($SkipChocolateyBootstrap) {
    Write-GuiAppsMsg 'Skipping Chocolatey bootstrap (-SkipChocolateyBootstrap).' Warn
    return
  }
  if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-GuiAppsMsg 'Chocolatey present; upgrading chocolatey package.' Muted
    if (-not $WhatIf) {
      $p = Start-Process -FilePath 'choco' -ArgumentList @('upgrade', 'chocolatey', '-y') -Wait -PassThru -NoNewWindow
      if ($p.ExitCode -ne 0) {
        Write-GuiAppsMsg "choco upgrade chocolatey exit $($p.ExitCode)" Warn
      }
    }
    return
  }
  Write-GuiAppsMsg 'Installing Chocolatey (one-time).' Accent
  if ($WhatIf) {
    Write-GuiAppsMsg 'WhatIf: bootstrap Chocolatey from chocolatey.org' Muted
    return
  }
  Set-ExecutionPolicy -Scope Process -SkipPublisherCheck -Force -ExecutionPolicy Bypass
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

function Install-SelectedPackages {
  param([string[]]$Tags)

  $needsChoco = $false
  foreach ($t in $Tags) {
    $parts = $t -split '\|', 3
    if ($parts.Count -ge 2 -and $parts[1].Trim().ToLowerInvariant() -eq 'choco') { $needsChoco = $true; break }
  }
  if ($needsChoco) {
    Ensure-Chocolatey
    if (-not $WhatIf -and -not (Get-Command choco -ErrorAction SilentlyContinue) -and -not $SkipChocolateyBootstrap) {
      Write-GuiAppsMsg 'Chocolatey required for selected packages but is not available.' Err
      exit 1
    }
  }

  foreach ($item in $Tags) {
    $parts = $item -split '\|', 3
    if ($parts.Count -lt 2) { continue }
    $packageId = $parts[0].Trim()
    $packageManager = $parts[1].Trim().ToLowerInvariant()
    if (-not $packageId) { continue }

    Write-GuiAppsMsg "Installing: $packageId ($packageManager)" Info

    if ($WhatIf) {
      if ($packageManager -eq 'choco') {
        Write-GuiAppsMsg "WhatIf: choco upgrade $packageId -r -y" Muted
      } elseif ($packageManager -eq 'winget') {
        Write-GuiAppsMsg "WhatIf: winget install -e --id $packageId ..." Muted
      } else {
        Write-GuiAppsMsg "WhatIf: unknown manager '$packageManager' for $packageId" Warn
      }
      continue
    }

    try {
      if ($packageManager -eq 'choco') {
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
          Write-GuiAppsMsg "Skipping $packageId (choco not available)" Warn
          continue
        }
        $p = Start-Process -FilePath 'choco' -ArgumentList @('upgrade', $packageId, '-r', '-y') -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -ne 0) {
          Write-GuiAppsMsg "choco exit $($p.ExitCode) for $packageId" Warn
        }
      } elseif ($packageManager -eq 'winget') {
        $argList = @('install', '-e', '--id', $packageId, '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
        $p = Start-Process -FilePath 'winget' -ArgumentList $argList -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -ne 0) {
          Write-GuiAppsMsg "winget exit $($p.ExitCode) for $packageId (may already be installed)" Warn
        }
      } else {
        Write-GuiAppsMsg "Unknown PackageManager '$packageManager' for $packageId" Warn
      }
    } catch {
      Write-GuiAppsMsg "Error installing ${packageId}: $($_.Exception.Message)" Err
    }
  }
}

function Get-CheckBoxTag {
  param($Row)
  $def = if ($Row.DefaultChecked) { $Row.DefaultChecked.ToString().Trim() } else { 'FALSE' }
  return "$($Row.PackageID)|$($Row.PackageManager)|$def"
}



function Get-CheckboxCsvToolTip {
  param($Row)
  $tip = ''
  $pt = $Row.PSObject.Properties['Tooltip']
  if ($null -ne $pt -and $pt.Value) { $tip = $pt.Value.ToString().Trim() }
  if ([string]::IsNullOrWhiteSpace($tip)) {
    $pn = $Row.PSObject.Properties['Notes']
    if ($null -ne $pn -and $pn.Value) { $tip = $pn.Value.ToString().Trim() }
  }
  if ([string]::IsNullOrWhiteSpace($tip)) {
    $pkgId = if ($Row.PackageID) { $Row.PackageID.ToString().Trim() } else { '' }
    $pm = if ($Row.PackageManager) { $Row.PackageManager.ToString().Trim() } else { '' }
    if ($pkgId -and $pm) { return "$pm`: $pkgId" }
    if ($pkgId) { return $pkgId }
  }
  return $tip
}

function Show-CategoryDialog {
  param([System.Collections.Specialized.OrderedDictionary]$Categories)

  Add-Type -AssemblyName PresentationFramework

  $allCheckBoxes = [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]::new()

  $window = New-Object Windows.Window
  $window.Title = 'Desktop / GUI software (shortps1)'
  $window.Height = 560
  $window.Width = 780

  $grid = New-Object Windows.Controls.Grid
  $null = $grid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition))
  $null = $grid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition))
  $grid.RowDefinitions[1].Height = [Windows.GridLength]::Auto

  $tabControl = New-Object Windows.Controls.TabControl
  $tabControl.Margin = '5'
  [Windows.Controls.Grid]::SetRow($tabControl, 0)

  foreach ($category in $Categories.Keys) {
    $tabItem = New-Object Windows.Controls.TabItem
    $tabItem.Header = [string]$category

    $scrollViewer = New-Object Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'

    $groupBoxGrid = New-Object Windows.Controls.Grid
    1..4 | ForEach-Object { $null = $groupBoxGrid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition)) }

    $list = $Categories[$category]
    $counter = 0
    foreach ($software in $list) {
      $checkBox = New-Object Windows.Controls.CheckBox
      $checkBox.Content = $software.Name
      $checkBox.Tag = (Get-CheckBoxTag -Row $software)
      $checkBox.Margin = '2'
      $parsed = $false
      [void][bool]::TryParse($software.DefaultChecked, [ref]$parsed)
      $checkBox.IsChecked = $parsed
      $tt = Get-CheckboxCsvToolTip -Row $software
      if (-not [string]::IsNullOrWhiteSpace($tt)) { $checkBox.ToolTip = $tt }

      $column = $counter % 4
      $row = [math]::Floor($counter / 4)
      while ($groupBoxGrid.RowDefinitions.Count -le $row) {
        $null = $groupBoxGrid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition))
      }
      [Windows.Controls.Grid]::SetColumn($checkBox, $column)
      [Windows.Controls.Grid]::SetRow($checkBox, $row)
      $null = $groupBoxGrid.Children.Add($checkBox)
      [void]$allCheckBoxes.Add($checkBox)
      $counter++
    }

    $scrollViewer.Content = $groupBoxGrid
    $tabItem.Content = $scrollViewer
    $null = $tabControl.Items.Add($tabItem)
  }

  $buttonPanelLeft = New-Object Windows.Controls.StackPanel
  $buttonPanelLeft.Orientation = 'Horizontal'
  $buttonPanelLeft.HorizontalAlignment = 'Left'
  $buttonPanelLeft.Margin = '5'
  [Windows.Controls.Grid]::SetRow($buttonPanelLeft, 1)

  function New-ActionButton {
    param([string]$Label, [scriptblock]$OnClick)
    $b = New-Object Windows.Controls.Button
    $b.Content = $Label
    $b.Width = 110
    $b.Margin = '5'
    $b.Add_Click($OnClick)
    return $b
  }

  $null = $buttonPanelLeft.Children.Add((New-ActionButton -Label 'Select all' -OnClick {
      foreach ($cb in $allCheckBoxes) { $cb.IsChecked = $true }
    }))

  $null = $buttonPanelLeft.Children.Add((New-ActionButton -Label 'Select none' -OnClick {
      foreach ($cb in $allCheckBoxes) { $cb.IsChecked = $false }
    }))

  $null = $buttonPanelLeft.Children.Add((New-ActionButton -Label 'Select defaults' -OnClick {
      foreach ($cb in $allCheckBoxes) {
        $parts = [string]$cb.Tag -split '\|', 3
        $defStr = if ($parts.Count -ge 3) { $parts[2] } else { 'FALSE' }
        $parsed = $false
        [void][bool]::TryParse($defStr, [ref]$parsed)
        $cb.IsChecked = $parsed
      }
    }))

  $buttonPanelRight = New-Object Windows.Controls.StackPanel
  $buttonPanelRight.Orientation = 'Horizontal'
  $buttonPanelRight.HorizontalAlignment = 'Right'
  $buttonPanelRight.Margin = '5'
  [Windows.Controls.Grid]::SetRow($buttonPanelRight, 1)

  $null = $buttonPanelRight.Children.Add((New-ActionButton -Label 'Install' -OnClick {
      $selected = [System.Collections.Generic.List[string]]::new()
      foreach ($cb in $allCheckBoxes) {
        if ($cb.IsChecked -eq $true) { [void]$selected.Add([string]$cb.Tag) }
      }
      if ($selected.Count -gt 0) {
        Install-SelectedPackages -Tags @($selected)
      }
      $window.DialogResult = $true
      $window.Close()
    }))

  $null = $buttonPanelRight.Children.Add((New-ActionButton -Label 'Cancel' -OnClick {
      $window.DialogResult = $false
      $window.Close()
    }))

  $null = $grid.Children.Add($tabControl)
  $null = $grid.Children.Add($buttonPanelLeft)
  $null = $grid.Children.Add($buttonPanelRight)
  $window.Content = $grid
  [void]$window.ShowDialog()
}

if (-not (Test-Path -LiteralPath $CsvPath)) {
  Write-GuiAppsMsg "CSV not found: $CsvPath" Err
  exit 1
}

Ensure-Winget

$categories = Get-SoftwareFromCSV -Path $CsvPath

if ($AutoDefault) {
  $tags = [System.Collections.Generic.List[string]]::new()
  foreach ($cat in $categories.Keys) {
    foreach ($row in $categories[$cat]) {
      $parsed = $false
      [void][bool]::TryParse($row.DefaultChecked, [ref]$parsed)
      if ($parsed) { [void]$tags.Add((Get-CheckBoxTag -Row $row)) }
    }
  }
  Write-GuiAppsMsg "AutoDefault: $($tags.Count) package(s) from CSV." Accent
  if ($tags.Count -gt 0) {
    Install-SelectedPackages -Tags @($tags)
  }
  Write-GuiAppsMsg 'Install-GuiApps: done.' Ok
  exit 0
}

Show-CategoryDialog -Categories $categories
Write-GuiAppsMsg 'Install-GuiApps: done.' Ok
