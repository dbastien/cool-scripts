#requires -Version 7.2
<#
.SYNOPSIS
  WPF picker for open-source and free games (winget, GitHub release zips, optional official data bundles).

.DESCRIPTION
  Catalog CSV (default OSS-games.csv next to this script): Category, Subcategory (optional), Name, PackageID, DefaultChecked, PackageManager, Notes, Tooltip, ExtractTo.
  If any row in a category has a non-empty Subcategory, that tab uses GroupBoxes; blank Subcategory rows are grouped under "Other".
  PackageManager values:
  winget | choco | ghzip | zip
  - ghzip: PackageID is owner/repo|regex (regex selects release asset name; default (?i)-win\.zip$ )
  - zip: PackageID is https URL; ExtractTo is required (%ENV%\... paths expanded)
  For headless installs of CSV defaults: -AutoDefault.

.EXAMPLE
  .\powershell\Instellator\OssGames.ps1

.EXAMPLE
  .\powershell\Instellator\OssGames.ps1 -WhatIf
#>
param(
  [string]$CsvPath = '',
  [switch]$AutoDefault,
  [switch]$WhatIf,
  [switch]$SkipChocolateyBootstrap,
  [switch]$UpgradeChocolatey
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$psPow = Split-Path -Parent $here
$ptRoot = Join-Path $psPow 'toasty'
$wpfGui = Join-Path $psPow 'lib\WpfGui.ps1'
if (-not $CsvPath) { $CsvPath = Join-Path $here 'OSS-games.csv' }

if (Test-Path -LiteralPath $wpfGui) {
  . $wpfGui
  Restart-PwshScriptInStaIfNeeded
}

$common = Join-Path $ptRoot 'lib\common.ps1'
if (Test-Path -LiteralPath $common) { . $common }

function Write-OssGamesMsg {
  param([string]$Message, [ValidateSet('Info', 'Ok', 'Warn', 'Err', 'Muted', 'Accent')][string]$Level = 'Info')
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg $Message $Level
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

function Test-InstellatorWingetAvailable {
  $wingetExe = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
  if (Test-Path -LiteralPath $wingetExe) { return $true }
  return $null -ne (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Ensure-Winget {
  if (-not (Test-InstellatorWingetAvailable)) {
    Write-OssGamesMsg 'winget not found. Install App Installer from the Microsoft Store, then re-run.' Err
    exit 1
  }
}

function Ensure-Chocolatey {
  if ($SkipChocolateyBootstrap) {
    Write-OssGamesMsg 'Skipping Chocolatey bootstrap (-SkipChocolateyBootstrap).' Warn
    return
  }
  if (Get-Command choco -ErrorAction SilentlyContinue) {
    if ($UpgradeChocolatey) {
      Write-OssGamesMsg 'Chocolatey present; upgrading chocolatey package (-UpgradeChocolatey).' Muted
      if (-not $WhatIf) {
        $p = Start-Process -FilePath 'choco' -ArgumentList @('upgrade', 'chocolatey', '-r', '-y') -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -ne 0) {
          Write-OssGamesMsg "choco upgrade chocolatey exit $($p.ExitCode)" Warn
        }
      }
    }
    return
  }
  Write-OssGamesMsg 'Installing Chocolatey (one-time).' Accent
  if ($WhatIf) {
    Write-OssGamesMsg 'WhatIf: bootstrap Chocolatey from chocolatey.org' Muted
    return
  }
  Set-ExecutionPolicy -Scope Process -SkipPublisherCheck -Force -ExecutionPolicy Bypass
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

function Expand-OssInstallPath {
  param([string]$Template, [string]$FallbackDisplayName)
  if ([string]::IsNullOrWhiteSpace($Template)) {
    $safe = ($FallbackDisplayName -replace '[^\w\-\s]', '') -replace '\s+', '_'
    if (-not $safe) { $safe = 'Game' }
    return (Join-Path $env:LOCALAPPDATA (Join-Path 'OSSGames' $safe))
  }
  return [Environment]::ExpandEnvironmentVariables($Template.Trim())
}

function Copy-ExpandedZipTree {
  param(
    [Parameter(Mandatory)][string]$StageDir,
    [Parameter(Mandatory)][string]$DestDir
  )
  $items = @(Get-ChildItem -LiteralPath $StageDir -Force)
  $root = $StageDir
  if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
    $root = $items[0].FullName
  }
  New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
  Get-ChildItem -LiteralPath $root -Force | ForEach-Object {
    $target = Join-Path $DestDir $_.Name
    Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force
  }
}

function Install-ZipFromUrl {
  param(
    [Parameter(Mandatory)][string]$Url,
    [Parameter(Mandatory)][string]$DestDir,
    [string]$Label = 'download'
  )
  if ($WhatIf) {
    Write-OssGamesMsg "WhatIf: $Label -> $Url`n  extract to $DestDir" Muted
    return
  }
  $tmpZip = Join-Path $env:TEMP ("ossgames-{0}.zip" -f [Guid]::NewGuid().ToString('n'))
  $stage = Join-Path $env:TEMP ("ossgames-stg-{0}" -f [Guid]::NewGuid().ToString('n'))
  try {
    Write-OssGamesMsg "Downloading: $Label" Info
    Invoke-WebRequest -Uri $Url -OutFile $tmpZip -UseBasicParsing
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Expand-Archive -LiteralPath $tmpZip -DestinationPath $stage -Force
    Copy-ExpandedZipTree -StageDir $stage -DestDir $DestDir
    Write-OssGamesMsg "Installed: $Label -> $DestDir" Ok
  } finally {
    Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Install-GithubReleaseZip {
  param(
    [Parameter(Mandatory)][string]$OwnerRepo,
    [Parameter(Mandatory)][string]$AssetRegex,
    [Parameter(Mandatory)][string]$DestDir,
    [string]$Label
  )
  if ([string]::IsNullOrWhiteSpace($Label)) { $Label = $OwnerRepo }
  $headers = @{
    'Accept'               = 'application/vnd.github+json'
    'User-Agent'           = 'cool-scripts-oss-games'
    'X-GitHub-Api-Version' = '2022-11-28'
  }
  $api = "https://api.github.com/repos/$OwnerRepo/releases"
  if ($WhatIf) {
    Write-OssGamesMsg "WhatIf: ghzip $Label ($OwnerRepo) asset /$AssetRegex/ -> $DestDir" Muted
    return
  }
  $releases = Invoke-RestMethod -Uri "$api?per_page=10" -Headers $headers
  $asset = $null
  foreach ($rel in $releases) {
    foreach ($a in @($rel.assets)) {
      if ($a.name -match $AssetRegex) {
        $asset = $a
        break
      }
    }
    if ($asset) { break }
  }
  if (-not $asset) {
    Write-OssGamesMsg "No release asset matching /$AssetRegex/ for $OwnerRepo" Err
    return
  }
  Install-ZipFromUrl -Url $asset.browser_download_url -DestDir $DestDir -Label $Label
}

function Install-SelectedRows {
  param([object[]]$Rows)

  $needsChoco = $false
  foreach ($r in $Rows) {
    $pm = [string]$r.PackageManager
    $pm = $pm.Trim().ToLowerInvariant()
    if ($pm -eq 'choco') { $needsChoco = $true; break }
  }
  if ($needsChoco) {
    Ensure-Chocolatey
    if (-not $WhatIf -and -not (Get-Command choco -ErrorAction SilentlyContinue) -and -not $SkipChocolateyBootstrap) {
      Write-OssGamesMsg 'Chocolatey required for a selected package but is not available.' Err
      exit 1
    }
  }

  foreach ($r in $Rows) {
    $packageId = [string]$r.PackageID
    $packageId = $packageId.Trim()
    $pm = [string]$r.PackageManager
    $pm = $pm.Trim().ToLowerInvariant()
    $name = [string]$r.Name
    $name = $name.Trim()
    if (-not $packageId -or -not $pm) { continue }

    try {
      if ($pm -eq 'winget') {
        Write-OssGamesMsg "Installing (winget): $name" Info
        if ($WhatIf) {
          Write-OssGamesMsg "WhatIf: winget install -e --id $packageId ..." Muted
          continue
        }
        $argList = @('install', '-e', '--id', $packageId, '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
        $p = Start-Process -FilePath 'winget' -ArgumentList $argList -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -ne 0) {
          Write-OssGamesMsg "winget exit $($p.ExitCode) for $packageId (may already be installed)" Warn
        }
      } elseif ($pm -eq 'choco') {
        Write-OssGamesMsg "Installing (choco): $name" Info
        if ($WhatIf) {
          Write-OssGamesMsg "WhatIf: choco upgrade $packageId -r -y" Muted
          continue
        }
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
          Write-OssGamesMsg "Skipping $packageId (choco not available)" Warn
          continue
        }
        $p = Start-Process -FilePath 'choco' -ArgumentList @('upgrade', $packageId, '-r', '-y') -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -ne 0) {
          Write-OssGamesMsg "choco exit $($p.ExitCode) for $packageId" Warn
        }
      } elseif ($pm -eq 'ghzip') {
        $repo = $packageId
        $rx = '(?i)-win\.zip$'
        if ($packageId -match '^([^|]+)\|(.+)$') {
          $repo = $Matches[1].Trim()
          $rx = $Matches[2].Trim()
        }
        $dest = Expand-OssInstallPath -Template ($r.ExtractTo) -FallbackDisplayName $name
        Install-GithubReleaseZip -OwnerRepo $repo -AssetRegex $rx -DestDir $dest -Label $name
      } elseif ($pm -eq 'zip') {
        $destRaw = $r.ExtractTo
        if ([string]::IsNullOrWhiteSpace($destRaw)) {
          Write-OssGamesMsg "zip row '$name' missing ExtractTo" Err
          continue
        }
        $dest = [Environment]::ExpandEnvironmentVariables($destRaw.Trim())
        if ($packageId -notmatch '^https?://') {
          Write-OssGamesMsg "zip row '$name' needs an http(s) URL in PackageID" Err
          continue
        }
        Install-ZipFromUrl -Url $packageId -DestDir $dest -Label $name
      } else {
        Write-OssGamesMsg "Unknown PackageManager '$pm' for $name" Warn
      }
    } catch {
      Write-OssGamesMsg "${name}: $($_.Exception.Message)" Err
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

function Get-OssGamesCsvSubcategoryValue {
  param($Row)
  $p = $Row.PSObject.Properties['Subcategory']
  if ($null -eq $p -or $null -eq $p.Value) { return '' }
  return [string]$p.Value.Trim()
}

function Get-OssGamesCategorySubgroupModel {
  param([System.Collections.Generic.List[object]]$Rows)
  $anySub = $false
  foreach ($r in $Rows) {
    if (Get-OssGamesCsvSubcategoryValue -Row $r) { $anySub = $true; break }
  }
  if (-not $anySub) {
    return [pscustomobject]@{ Flat = $true; Groups = $null }
  }
  $groups = [ordered]@{}
  foreach ($r in $Rows) {
    $sk = Get-OssGamesCsvSubcategoryValue -Row $r
    if (-not $sk) { $sk = 'Other' }
    if (-not $groups.Contains($sk)) {
      $groups[$sk] = [System.Collections.Generic.List[object]]::new()
    }
    [void]$groups[$sk].Add($r)
  }
  return [pscustomobject]@{ Flat = $false; Groups = $groups }
}

function Add-OssGamesCheckBoxesToGrid {
  param(
    [System.Collections.IEnumerable]$SoftwareRows,
    [Windows.Controls.Grid]$TargetGrid,
    [int]$ColumnCount,
    [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]$AllCheckBoxes
  )
  $counter = 0
  foreach ($software in $SoftwareRows) {
    $checkBox = New-Object Windows.Controls.CheckBox
    $checkBox.Content = $software.Name
    $checkBox.Tag = (Get-CheckBoxTag -Row $software)
    $checkBox.Margin = '2'
    $parsed = $false
    [void][bool]::TryParse($software.DefaultChecked, [ref]$parsed)
    $checkBox.IsChecked = $parsed
    $tt = Get-CheckboxCsvToolTip -Row $software
    if (-not [string]::IsNullOrWhiteSpace($tt)) { $checkBox.ToolTip = $tt }

    $column = $counter % $ColumnCount
    $row = [math]::Floor($counter / $ColumnCount)
    while ($TargetGrid.RowDefinitions.Count -le $row) {
      $null = $TargetGrid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition))
    }
    [Windows.Controls.Grid]::SetColumn($checkBox, $column)
    [Windows.Controls.Grid]::SetRow($checkBox, $row)
    $null = $TargetGrid.Children.Add($checkBox)
    [void]$AllCheckBoxes.Add($checkBox)
    $counter++
  }
}

function Resolve-RowFromTag {
  param([string]$Tag, [System.Collections.Specialized.OrderedDictionary]$Categories)
  $parts = $Tag -split '\|', 3
  if ($parts.Count -lt 2) { return $null }
  $wantId = $parts[0].Trim()
  $wantPm = $parts[1].Trim().ToLowerInvariant()
  foreach ($cat in $Categories.Keys) {
    foreach ($row in $Categories[$cat]) {
      $id = ([string]$row.PackageID).Trim()
      $pm = ([string]$row.PackageManager).Trim().ToLowerInvariant()
      if ($id -eq $wantId -and $pm -eq $wantPm) { return $row }
    }
  }
  return $null
}

function New-OssGamesCategoryScrollViewer {
  param(
    [Parameter(Mandatory)][string]$CategoryKey,
    [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$Categories,
    [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[System.Windows.Controls.CheckBox]]$AllCheckBoxes
  )

  $list = $Categories[$CategoryKey]
  $model = Get-OssGamesCategorySubgroupModel -Rows $list
  $scrollViewer = New-Object Windows.Controls.ScrollViewer
  $scrollViewer.VerticalScrollBarVisibility = 'Auto'

  if ($model.Flat) {
    $groupBoxGrid = New-Object Windows.Controls.Grid
    1..3 | ForEach-Object { $null = $groupBoxGrid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition)) }
    Add-OssGamesCheckBoxesToGrid -SoftwareRows $list -TargetGrid $groupBoxGrid -ColumnCount 3 -AllCheckBoxes $AllCheckBoxes
    $scrollViewer.Content = $groupBoxGrid
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
      1..3 | ForEach-Object { $null = $inner.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition)) }
      Add-OssGamesCheckBoxesToGrid -SoftwareRows $model.Groups[$subName] -TargetGrid $inner -ColumnCount 3 -AllCheckBoxes $AllCheckBoxes
      $gb.Content = $inner
      [void]$outer.Children.Add($gb)
    }
    $scrollViewer.Content = $outer
  }
  return $scrollViewer
}

function Show-CategoryDialog {
  param([System.Collections.Specialized.OrderedDictionary]$Categories)

  Register-WpfPresentationAssemblies

  $allCheckBoxes = [System.Collections.Generic.List[System.Windows.Controls.CheckBox]]::new()

  $window = New-Object Windows.Window
  $window.Title = 'Open-source and free games'
  $window.Height = 580
  $window.Width = 820

  $grid = New-Object Windows.Controls.Grid
  $null = $grid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition))
  $null = $grid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition))
  $grid.RowDefinitions[1].Height = [Windows.GridLength]::Auto

  $tabControl = New-Object Windows.Controls.TabControl
  $tabControl.Margin = '5'
  [Windows.Controls.Grid]::SetRow($tabControl, 0)

  $dialogCtx = [pscustomobject]@{
    Categories           = $Categories
    AllCheckBoxes        = $allCheckBoxes
    TabControl           = $tabControl
    Window               = $window
    BuildCategoryScroll  = (Get-Command New-OssGamesCategoryScrollViewer -CommandType Function)
    InstallSelectedRows  = (Get-Command Install-SelectedRows -CommandType Function)
    ResolveRowFromTag    = (Get-Command Resolve-RowFromTag -CommandType Function)
  }

  $populateOssTab = {
    param([Windows.Controls.TabItem]$TabItem)
    if ($null -eq $TabItem) { return }
    $meta = $TabItem.Tag
    if ($null -eq $meta -or $meta.Populated) { return }
    $c = $dialogCtx
    $TabItem.Content = & $c.BuildCategoryScroll -CategoryKey $meta.Category -Categories $c.Categories -AllCheckBoxes $c.AllCheckBoxes
    $meta.Populated = $true
  }.GetNewClosure()

  foreach ($category in $Categories.Keys) {
    $tabItem = New-Object Windows.Controls.TabItem
    $tabItem.Header = [string]$category
    $tabItem.Tag = [pscustomobject]@{ Category = [string]$category; Populated = $false }
    $null = $tabControl.Items.Add($tabItem)
  }

  $ensureAllOssTabs = {
    $tc = $dialogCtx.TabControl
    foreach ($ti in $tc.Items) {
      & $populateOssTab ([Windows.Controls.TabItem]$ti)
    }
  }.GetNewClosure()

  $tabControl.Add_SelectionChanged( ({
    param($sender, $e)
    $sel = $sender.SelectedItem
    if ($sel -is [Windows.Controls.TabItem]) { & $populateOssTab $sel }
  }).GetNewClosure() )

  if ($dialogCtx.TabControl.Items.Count -gt 0) {
    & $populateOssTab ([Windows.Controls.TabItem]$dialogCtx.TabControl.Items[0])
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

  $null = $buttonPanelLeft.Children.Add((New-ActionButton -Label 'Select all' -OnClick ({
      & $ensureAllOssTabs
      foreach ($cb in $dialogCtx.AllCheckBoxes) { $cb.IsChecked = $true }
    }).GetNewClosure() ))

  $null = $buttonPanelLeft.Children.Add((New-ActionButton -Label 'Select none' -OnClick ({
      & $ensureAllOssTabs
      foreach ($cb in $dialogCtx.AllCheckBoxes) { $cb.IsChecked = $false }
    }).GetNewClosure() ))

  $null = $buttonPanelLeft.Children.Add((New-ActionButton -Label 'Select defaults' -OnClick ({
      & $ensureAllOssTabs
      foreach ($cb in $dialogCtx.AllCheckBoxes) {
        $parts = [string]$cb.Tag -split '\|', 3
        $defStr = if ($parts.Count -ge 3) { $parts[2] } else { 'FALSE' }
        $parsed = $false
        [void][bool]::TryParse($defStr, [ref]$parsed)
        $cb.IsChecked = $parsed
      }
    }).GetNewClosure() ))

  $buttonPanelRight = New-Object Windows.Controls.StackPanel
  $buttonPanelRight.Orientation = 'Horizontal'
  $buttonPanelRight.HorizontalAlignment = 'Right'
  $buttonPanelRight.Margin = '5'
  [Windows.Controls.Grid]::SetRow($buttonPanelRight, 1)

  $null = $buttonPanelRight.Children.Add((New-ActionButton -Label 'Install' -OnClick ({
      & $ensureAllOssTabs
      $selectedRows = [System.Collections.Generic.List[object]]::new()
      foreach ($cb in $dialogCtx.AllCheckBoxes) {
        if ($cb.IsChecked -ne $true) { continue }
        $row = & $dialogCtx.ResolveRowFromTag -Tag ([string]$cb.Tag) -Categories $dialogCtx.Categories
        if ($null -ne $row) { [void]$selectedRows.Add($row) }
      }
      if ($selectedRows.Count -gt 0) {
        & $dialogCtx.InstallSelectedRows -Rows @($selectedRows)
      }
      $dialogCtx.Window.DialogResult = $true
      $dialogCtx.Window.Close()
    }).GetNewClosure() ))

  $null = $buttonPanelRight.Children.Add((New-ActionButton -Label 'Cancel' -OnClick ({
      $dialogCtx.Window.DialogResult = $false
      $dialogCtx.Window.Close()
    }).GetNewClosure() ))

  $null = $grid.Children.Add($tabControl)
  $null = $grid.Children.Add($buttonPanelLeft)
  $null = $grid.Children.Add($buttonPanelRight)
  $window.Content = $grid
  [void]$window.ShowDialog()
}

if (-not (Test-Path -LiteralPath $CsvPath)) {
  Write-OssGamesMsg "CSV not found: $CsvPath" Err
  exit 1
}

Ensure-Winget

$categories = Get-SoftwareFromCSV -Path $CsvPath

if ($AutoDefault) {
  $rows = [System.Collections.Generic.List[object]]::new()
  foreach ($cat in $categories.Keys) {
    foreach ($row in $categories[$cat]) {
      $parsed = $false
      [void][bool]::TryParse($row.DefaultChecked, [ref]$parsed)
      if ($parsed) { [void]$rows.Add($row) }
    }
  }
  Write-OssGamesMsg "AutoDefault: $($rows.Count) item(s) from CSV." Accent
  if ($rows.Count -gt 0) {
    Install-SelectedRows -Rows @($rows)
  }
  Write-OssGamesMsg 'OssGames: done.' Ok
  exit 0
}

Show-CategoryDialog -Categories $categories
Write-OssGamesMsg 'OssGames: done.' Ok
