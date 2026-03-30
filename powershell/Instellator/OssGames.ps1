#requires -Version 7.2
<#
.SYNOPSIS
  WPF picker for open-source and free games (winget, GitHub release zips, optional official data bundles).

.DESCRIPTION
  Catalog CSV (default OSS-games.csv next to this script). PackageManager values:
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
  [switch]$SkipChocolateyBootstrap
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

function Ensure-Winget {
  $wg = Get-Command winget -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $wg) {
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
    Write-OssGamesMsg 'Chocolatey present; upgrading chocolatey package.' Muted
    if (-not $WhatIf) {
      $p = Start-Process -FilePath 'choco' -ArgumentList @('upgrade', 'chocolatey', '-y') -Wait -PassThru -NoNewWindow
      if ($p.ExitCode -ne 0) {
        Write-OssGamesMsg "choco upgrade chocolatey exit $($p.ExitCode)" Warn
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

  foreach ($category in $Categories.Keys) {
    $tabItem = New-Object Windows.Controls.TabItem
    $tabItem.Header = [string]$category

    $scrollViewer = New-Object Windows.Controls.ScrollViewer
    $scrollViewer.VerticalScrollBarVisibility = 'Auto'

    $groupBoxGrid = New-Object Windows.Controls.Grid
    1..3 | ForEach-Object { $null = $groupBoxGrid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition)) }

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

      $column = $counter % 3
      $row = [math]::Floor($counter / 3)
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
      $selectedRows = [System.Collections.Generic.List[object]]::new()
      foreach ($cb in $allCheckBoxes) {
        if ($cb.IsChecked -ne $true) { continue }
        $row = Resolve-RowFromTag -Tag ([string]$cb.Tag) -Categories $Categories
        if ($null -ne $row) { [void]$selectedRows.Add($row) }
      }
      if ($selectedRows.Count -gt 0) {
        Install-SelectedRows -Rows @($selectedRows)
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
