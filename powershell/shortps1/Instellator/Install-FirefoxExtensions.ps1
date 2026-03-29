#requires -Version 7.2
<#
.SYNOPSIS
  WPF picker for Firefox extension .xpi downloads (data-driven CSV).

.DESCRIPTION
  Defaults to Firefox-extensions.csv next to this script. Saves under .\firefox-extensions\ unless -OutDir is set.
  Install downloaded .xpi files from about:addons or drag into Firefox.

.EXAMPLE
  .\Instellator\Install-FirefoxExtensions.ps1

.EXAMPLE
  .\Instellator\Install-FirefoxExtensions.ps1 -AutoDefault
#>
param(
  [string]$CsvPath = '',
  [string]$OutDir = '',
  [switch]$AutoDefault,
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$shortPs1Root = Split-Path -Parent $here
$psPow = Split-Path -Parent $shortPs1Root
$ptRoot = Join-Path $psPow 'toasty'
if (-not $CsvPath) {
  $CsvPath = Join-Path $here 'Firefox-extensions.csv'
}
if (-not $OutDir) {
  $OutDir = Join-Path $here 'firefox-extensions'
}

$common = Join-Path $ptRoot 'lib\ShortCommon.ps1'
if (Test-Path -LiteralPath $common) { . $common }

function Write-FxExtMsg {
  param([string]$Message, [ValidateSet('Info', 'Ok', 'Warn', 'Err', 'Muted', 'Accent')][string]$Level = 'Info')
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg $Message $Level
  } else {
    Write-Host $Message
  }
}

function Get-ExtensionsFromCSV {
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

function Get-FxCheckBoxTag {
  param($Row)
  $def = if ($Row.DefaultChecked) { $Row.DefaultChecked.ToString().Trim() } else { 'FALSE' }
  return "$($Row.Id)|$($Row.Url)|$def"
}

function Get-FxCheckboxToolTip {
  param($Row)
  $tip = ''
  $pt = $Row.PSObject.Properties['Tooltip']
  if ($null -ne $pt -and $pt.Value) { $tip = $pt.Value.ToString().Trim() }
  if ([string]::IsNullOrWhiteSpace($tip)) {
    $pn = $Row.PSObject.Properties['Notes']
    if ($null -ne $pn -and $pn.Value) { $tip = $pn.Value.ToString().Trim() }
  }
  if ([string]::IsNullOrWhiteSpace($tip)) {
    $id = if ($Row.Id) { $Row.Id.ToString().Trim() } else { '' }
    if ($id) { return "Id: $id" }
  }
  return $tip
}

function Install-SelectedXpi {
  param([string[]]$Tags)

  New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

  foreach ($item in $Tags) {
    $parts = $item -split '\|', 3
    if ($parts.Count -lt 2) { continue }
    $addonId = $parts[0].Trim()
    $addonUrl = $parts[1].Trim()
    if (-not $addonId -or -not $addonUrl) { continue }

    $xpiPath = Join-Path $OutDir "$addonId.xpi"

    if ($WhatIf) {
      Write-FxExtMsg "WhatIf: download $addonId -> $xpiPath" Muted
      continue
    }

    if (Test-Path -LiteralPath $xpiPath) {
      Write-FxExtMsg "Skip (exists): $addonId.xpi" Muted
      continue
    }

    Write-FxExtMsg "Downloading: $addonId" Info
    try {
      Invoke-WebRequest -Uri $addonUrl -OutFile $xpiPath -ErrorAction Stop
      Write-FxExtMsg "Saved: $xpiPath" Ok
    } catch {
      Write-FxExtMsg "Failed $addonId : $($_.Exception.Message)" Err
    }
  }
}

function Show-FxCategoryDialog {
  param([System.Collections.Specialized.OrderedDictionary]$Categories)

  Add-Type -AssemblyName PresentationFramework

  $allCheckBoxes = [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]::new()

  $window = New-Object Windows.Window
  $window.Title = 'Firefox extensions (.xpi)'
  $window.Height = 520
  $window.Width = 720

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
    1..3 | ForEach-Object { $null = $groupBoxGrid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition)) }

    $list = $Categories[$category]
    $counter = 0
    foreach ($row in $list) {
      $checkBox = New-Object Windows.Controls.CheckBox
      $checkBox.Content = $row.Name
      $checkBox.Tag = (Get-FxCheckBoxTag -Row $row)
      $checkBox.Margin = '2'
      $parsed = $false
      [void][bool]::TryParse($row.DefaultChecked, [ref]$parsed)
      $checkBox.IsChecked = $parsed
      $tt = Get-FxCheckboxToolTip -Row $row
      if (-not [string]::IsNullOrWhiteSpace($tt)) { $checkBox.ToolTip = $tt }

      $column = $counter % 3
      $r = [math]::Floor($counter / 3)
      while ($groupBoxGrid.RowDefinitions.Count -le $r) {
        $null = $groupBoxGrid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition))
      }
      [Windows.Controls.Grid]::SetColumn($checkBox, $column)
      [Windows.Controls.Grid]::SetRow($checkBox, $r)
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

  function New-FxActionButton {
    param([string]$Label, [scriptblock]$OnClick)
    $b = New-Object Windows.Controls.Button
    $b.Content = $Label
    $b.Width = 110
    $b.Margin = '5'
    $b.Add_Click($OnClick)
    return $b
  }

  $null = $buttonPanelLeft.Children.Add((New-FxActionButton -Label 'Select all' -OnClick {
      foreach ($cb in $allCheckBoxes) { $cb.IsChecked = $true }
    }))

  $null = $buttonPanelLeft.Children.Add((New-FxActionButton -Label 'Select none' -OnClick {
      foreach ($cb in $allCheckBoxes) { $cb.IsChecked = $false }
    }))

  $null = $buttonPanelLeft.Children.Add((New-FxActionButton -Label 'Select defaults' -OnClick {
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

  $null = $buttonPanelRight.Children.Add((New-FxActionButton -Label 'Download' -OnClick {
      $selected = [System.Collections.Generic.List[string]]::new()
      foreach ($cb in $allCheckBoxes) {
        if ($cb.IsChecked -eq $true) { [void]$selected.Add([string]$cb.Tag) }
      }
      if ($selected.Count -gt 0) {
        Install-SelectedXpi -Tags @($selected)
      }
      $window.DialogResult = $true
      $window.Close()
    }))

  $null = $buttonPanelRight.Children.Add((New-FxActionButton -Label 'Cancel' -OnClick {
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
  Write-FxExtMsg "CSV not found: $CsvPath" Err
  exit 1
}

$categories = Get-ExtensionsFromCSV -Path $CsvPath

if ($AutoDefault) {
  $tags = [System.Collections.Generic.List[string]]::new()
  foreach ($cat in $categories.Keys) {
    foreach ($row in $categories[$cat]) {
      $parsed = $false
      [void][bool]::TryParse($row.DefaultChecked, [ref]$parsed)
      if ($parsed) { [void]$tags.Add((Get-FxCheckBoxTag -Row $row)) }
    }
  }
  Write-FxExtMsg "AutoDefault: $($tags.Count) extension(s) from CSV." Accent
  if ($tags.Count -gt 0) {
    Install-SelectedXpi -Tags @($tags)
  }
  Write-FxExtMsg "Output folder: $OutDir" Info
  Write-FxExtMsg 'Install-FirefoxExtensions: done.' Ok
  exit 0
}

Show-FxCategoryDialog -Categories $categories
Write-FxExtMsg "Output folder: $OutDir" Info
Write-FxExtMsg 'Install-FirefoxExtensions: done.' Ok
