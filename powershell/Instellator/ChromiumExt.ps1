#requires -Version 7.2
<#
.SYNOPSIS
  WPF picker that opens Chrome Web Store and Microsoft Edge Add-ons pages for selected extensions.

.DESCRIPTION
  Chromium cannot install extensions silently like Firefox .xpi downloads; this script opens official
  store URLs in Chrome (if installed) and Edge (if URL provided) so you can click Add.
  Data: Chromium-extensions.csv next to this script (Category, Subcategory, Name, ...). Optional Subcategory adds GroupBoxes within a tab.
  Use -AutoDefault for CSV defaults only.

.EXAMPLE
  .\Instellator\ChromiumExt.ps1

.EXAMPLE
  .\Instellator\ChromiumExt.ps1 -AutoDefault

.EXAMPLE
  .\Instellator\ChromiumExt.ps1 -WhatIf
#>
param(
  [string]$CsvPath = '',
  [switch]$AutoDefault,
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$psPow = Split-Path -Parent $here
$ptRoot = Join-Path $psPow 'toasty'
if (-not $CsvPath) {
  $CsvPath = Join-Path $here 'Chromium-extensions.csv'
}

$common = Join-Path $ptRoot 'lib\common.ps1'
if (Test-Path -LiteralPath $common) { . $common }

function Write-CrExtMsg {
  param([string]$Message, [ValidateSet('Info', 'Ok', 'Warn', 'Err', 'Muted', 'Accent')][string]$Level = 'Info')
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg $Message $Level
  } else {
    Write-Host $Message
  }
}

function Get-ChromiumRowsFromCSV {
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

function Get-CrCheckBoxTag {
  param($Row)
  $def = if ($Row.DefaultChecked) { $Row.DefaultChecked.ToString().Trim() } else { 'FALSE' }
  $chrome = if ($Row.ChromeStoreUrl) { $Row.ChromeStoreUrl.ToString().Trim() } else { '' }
  $edge = if ($Row.EdgeStoreUrl) { $Row.EdgeStoreUrl.ToString().Trim() } else { '' }
  $id = if ($Row.Id) { $Row.Id.ToString().Trim() } else { '' }
  return "${id}|${chrome}|${edge}|${def}"
}

function Parse-CrCheckBoxTag {
  param([string]$Tag)
  if ([string]::IsNullOrWhiteSpace($Tag)) { return $null }
  $parts = $Tag.Split([char]'|', 4)
  if ($parts.Count -ne 4) { return $null }
  return [pscustomobject]@{
    Id     = $parts[0].Trim()
    Chrome = $parts[1].Trim()
    Edge   = $parts[2].Trim()
    Def    = $parts[3].Trim()
  }
}

function Get-CrCheckboxToolTip {
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

function Get-CsvSubcategoryValue {
  param($Row)
  $p = $Row.PSObject.Properties['Subcategory']
  if ($null -eq $p -or $null -eq $p.Value) { return '' }
  return [string]$p.Value.Trim()
}

function Get-CategorySubgroupModel {
  param([System.Collections.Generic.List[object]]$Rows)
  $anySub = $false
  foreach ($r in $Rows) {
    if (Get-CsvSubcategoryValue -Row $r) { $anySub = $true; break }
  }
  if (-not $anySub) {
    return [pscustomobject]@{ Flat = $true; Groups = $null }
  }
  $groups = [ordered]@{}
  foreach ($r in $Rows) {
    $sk = Get-CsvSubcategoryValue -Row $r
    if (-not $sk) { $sk = 'Other' }
    if (-not $groups.Contains($sk)) {
      $groups[$sk] = [System.Collections.Generic.List[object]]::new()
    }
    [void]$groups[$sk].Add($r)
  }
  return [pscustomobject]@{ Flat = $false; Groups = $groups }
}

function Add-CrCheckBoxesToGrid {
  param(
    [System.Collections.IEnumerable]$Rows,
    [Windows.Controls.Grid]$TargetGrid,
    [int]$ColumnCount,
    [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]$AllCheckBoxes
  )
  $counter = 0
  foreach ($row in $Rows) {
    $checkBox = New-Object Windows.Controls.CheckBox
    $checkBox.Content = $row.Name
    $checkBox.Tag = (Get-CrCheckBoxTag -Row $row)
    $checkBox.Margin = '2'
    $parsedDef = $false
    [void][bool]::TryParse($row.DefaultChecked, [ref]$parsedDef)
    $checkBox.IsChecked = $parsedDef
    $tt = Get-CrCheckboxToolTip -Row $row
    if (-not [string]::IsNullOrWhiteSpace($tt)) { $checkBox.ToolTip = $tt }

    $column = $counter % $ColumnCount
    $r = [math]::Floor($counter / $ColumnCount)
    while ($TargetGrid.RowDefinitions.Count -le $r) {
      $null = $TargetGrid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition))
    }
    [Windows.Controls.Grid]::SetColumn($checkBox, $column)
    [Windows.Controls.Grid]::SetRow($checkBox, $r)
    $null = $TargetGrid.Children.Add($checkBox)
    [void]$AllCheckBoxes.Add($checkBox)
    $counter++
  }
}

function Resolve-ChromePath {
  foreach ($p in @(
      (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'),
      (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
      (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe')
    )) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return $null
}

function Resolve-EdgePath {
  foreach ($p in @(
      (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
      (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
    )) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return $null
}

function Start-StoreInBrowser {
  param(
    [string]$Url,
    [ValidateSet('Chrome', 'Edge', 'Default')]
    [string]$Browser
  )
  if ([string]::IsNullOrWhiteSpace($Url)) { return }

  if ($Browser -eq 'Chrome') {
    $exe = Resolve-ChromePath
    if ($exe) {
      Start-Process -FilePath $exe -ArgumentList $Url
      return
    }
  } elseif ($Browser -eq 'Edge') {
    $exe = Resolve-EdgePath
    if ($exe) {
      Start-Process -FilePath $exe -ArgumentList $Url
      return
    }
  }
  Start-Process $Url
}

function Install-SelectedChromiumStores {
  param([string[]]$Tags)

  foreach ($item in $Tags) {
    $parsed = Parse-CrCheckBoxTag -Tag $item
    if (-not $parsed) {
      Write-CrExtMsg "Skip (bad tag): $item" Warn
      continue
    }

    if ($WhatIf) {
      if ($parsed.Chrome) { Write-CrExtMsg "WhatIf: Chrome store: $($parsed.Id) -> $($parsed.Chrome)" Muted }
      if ($parsed.Edge) { Write-CrExtMsg "WhatIf: Edge add-ons: $($parsed.Id) -> $($parsed.Edge)" Muted }
      continue
    }

    if ($parsed.Chrome) {
      Write-CrExtMsg "Opening Chrome Web Store: $($parsed.Id)" Info
      Start-StoreInBrowser -Url $parsed.Chrome -Browser Chrome
      Start-Sleep -Milliseconds 400
    }
    if ($parsed.Edge) {
      Write-CrExtMsg "Opening Edge Add-ons: $($parsed.Id)" Info
      Start-StoreInBrowser -Url $parsed.Edge -Browser Edge
      Start-Sleep -Milliseconds 400
    }
  }
}

function Show-CrCategoryDialog {
  param([System.Collections.Specialized.OrderedDictionary]$Categories)

  Add-Type -AssemblyName PresentationFramework

  $allCheckBoxes = [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]::new()

  $window = New-Object Windows.Window
  $window.Title = 'Chromium extensions (store pages)'
  $window.Height = 520
  $window.Width = 760

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

    $list = $Categories[$category]
    $model = Get-CategorySubgroupModel -Rows $list
    if ($model.Flat) {
      $innerGrid = New-Object Windows.Controls.Grid
      1..2 | ForEach-Object { $null = $innerGrid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition)) }
      Add-CrCheckBoxesToGrid -Rows $list -TargetGrid $innerGrid -ColumnCount 2 -AllCheckBoxes $allCheckBoxes
      $scrollViewer.Content = $innerGrid
    } else {
      $outer = New-Object Windows.Controls.StackPanel
      $outer.Orientation = 'Vertical'
      $firstGroup = $true
      foreach ($subName in $model.Groups.Keys) {
        $gb = New-Object Windows.Controls.GroupBox
        $gb.Header = [string]$subName
        $gb.Margin = if ($firstGroup) { '0,2,0,7' } else { '0,7,0,7' }
        $firstGroup = $false
        $inner = New-Object Windows.Controls.Grid
        1..2 | ForEach-Object { $null = $inner.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition)) }
        Add-CrCheckBoxesToGrid -Rows $model.Groups[$subName] -TargetGrid $inner -ColumnCount 2 -AllCheckBoxes $allCheckBoxes
        $gb.Content = $inner
        [void]$outer.Children.Add($gb)
      }
      $scrollViewer.Content = $outer
    }
    $tabItem.Content = $scrollViewer
    $null = $tabControl.Items.Add($tabItem)
  }

  $buttonPanelLeft = New-Object Windows.Controls.StackPanel
  $buttonPanelLeft.Orientation = 'Horizontal'
  $buttonPanelLeft.HorizontalAlignment = 'Left'
  $buttonPanelLeft.Margin = '5'
  [Windows.Controls.Grid]::SetRow($buttonPanelLeft, 1)

  function New-CrActionButton {
    param([string]$Label, [scriptblock]$OnClick)
    $b = New-Object Windows.Controls.Button
    $b.Content = $Label
    $b.Width = 110
    $b.Margin = '5'
    $b.Add_Click($OnClick)
    return $b
  }

  $null = $buttonPanelLeft.Children.Add((New-CrActionButton -Label 'Select all' -OnClick {
      foreach ($cb in $allCheckBoxes) { $cb.IsChecked = $true }
    }))

  $null = $buttonPanelLeft.Children.Add((New-CrActionButton -Label 'Select none' -OnClick {
      foreach ($cb in $allCheckBoxes) { $cb.IsChecked = $false }
    }))

  $null = $buttonPanelLeft.Children.Add((New-CrActionButton -Label 'Select defaults' -OnClick {
      foreach ($cb in $allCheckBoxes) {
        $p = Parse-CrCheckBoxTag -Tag ([string]$cb.Tag)
        if (-not $p) { continue }
        $parsed = $false
        [void][bool]::TryParse($p.Def, [ref]$parsed)
        $cb.IsChecked = $parsed
      }
    }))

  $buttonPanelRight = New-Object Windows.Controls.StackPanel
  $buttonPanelRight.Orientation = 'Horizontal'
  $buttonPanelRight.HorizontalAlignment = 'Right'
  $buttonPanelRight.Margin = '5'
  [Windows.Controls.Grid]::SetRow($buttonPanelRight, 1)

  $null = $buttonPanelRight.Children.Add((New-CrActionButton -Label 'Open stores' -OnClick {
      $selected = [System.Collections.Generic.List[string]]::new()
      foreach ($cb in $allCheckBoxes) {
        if ($cb.IsChecked -eq $true) { [void]$selected.Add([string]$cb.Tag) }
      }
      if ($selected.Count -gt 0) {
        Install-SelectedChromiumStores -Tags @($selected)
      }
      $window.DialogResult = $true
      $window.Close()
    }))

  $null = $buttonPanelRight.Children.Add((New-CrActionButton -Label 'Cancel' -OnClick {
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
  Write-CrExtMsg "CSV not found: $CsvPath" Err
  exit 1
}

$categories = Get-ChromiumRowsFromCSV -Path $CsvPath

if ($AutoDefault) {
  $tags = [System.Collections.Generic.List[string]]::new()
  foreach ($cat in $categories.Keys) {
    foreach ($row in $categories[$cat]) {
      $parsed = $false
      [void][bool]::TryParse($row.DefaultChecked, [ref]$parsed)
      if ($parsed) { [void]$tags.Add((Get-CrCheckBoxTag -Row $row)) }
    }
  }
  Write-CrExtMsg "AutoDefault: $($tags.Count) store page(s) from CSV." Accent
  if ($tags.Count -gt 0) {
    Install-SelectedChromiumStores -Tags @($tags)
  }
  Write-CrExtMsg 'ChromiumExt: done.' Ok
  exit 0
}

Show-CrCategoryDialog -Categories $categories
Write-CrExtMsg 'ChromiumExt: done.' Ok
