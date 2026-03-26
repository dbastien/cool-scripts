Add-Type -AssemblyName PresentationFramework

function Get-SoftwareFromCSV {
    param ([string]$csvPath)
    $categories = @{}
    Import-Csv -Path $csvPath | ForEach-Object {
        $category = $_.Category
        if (-not $categories.ContainsKey($category)) {
            $categories[$category] = @()
        }
        $categories[$category] += $_
    }
    return $categories
}

function Add-Button {
    param (
        [string]$content,
        [int]$width,
        [string]$margin,
        [scriptblock]$clickAction
    )
    $button = New-Object Windows.Controls.Button
    $button.Content = $content
    $button.Width = $width
    $button.Margin = $margin
    $button.Add_Click($clickAction)
    return $button
}

function Add-CheckBoxes {
    param (
        [Windows.Controls.Grid]$grid,
        [array]$softwareList,
        [int]$columns
    )
    $counter = 0
    foreach ($software in $softwareList) {
        $checkBox = New-Object Windows.Controls.CheckBox
        $checkBox.Content = $software.Name
        $checkBox.Tag = "$($software.PackageID)|$($software.PackageManager)"
        $checkBox.IsChecked = [System.Convert]::ToBoolean($software.DefaultChecked)

        $column = $counter % $columns
        $row = [math]::Floor($counter / $columns)

        if ($grid.RowDefinitions.Count -le $row) {
            $grid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition)) | Out-Null
        }

        [Windows.Controls.Grid]::SetColumn($checkBox, $column) | Out-Null
        [Windows.Controls.Grid]::SetRow($checkBox, $row) | Out-Null
        $grid.Children.Add($checkBox) | Out-Null
        $counter++
    }
}

function Show-CategoryDialog {
    param ([hashtable]$categories)

    $window = New-Object Windows.Window
    $window.Title = "Software Installer"
    $window.Height = 500
    $window.Width = 700

    $grid = New-Object Windows.Controls.Grid
    $grid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition)) | Out-Null
    $grid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition)) | Out-Null
    $grid.RowDefinitions[1].Height = [Windows.GridLength]::Auto

    $scrollViewer = New-Object Windows.Controls.ScrollViewer
    [Windows.Controls.Grid]::SetRow($scrollViewer, 0) | Out-Null
    $stackPanel = New-Object Windows.Controls.StackPanel

    foreach ($category in $categories.Keys) {
        $groupBox = New-Object Windows.Controls.GroupBox
        $groupBox.Header = $category
        $groupBox.Margin = "5"
        
        $groupBoxGrid = New-Object Windows.Controls.Grid
        1..4 | ForEach-Object { $groupBoxGrid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition)) | Out-Null }

        Add-CheckBoxes -grid $groupBoxGrid -softwareList $categories[$category] -columns 4

        $groupBox.Content = $groupBoxGrid
        $stackPanel.Children.Add($groupBox) | Out-Null
    }

    $scrollViewer.Content = $stackPanel

    $buttonPanelLeft = New-Object Windows.Controls.StackPanel
    $buttonPanelLeft.Orientation = "Horizontal"
    $buttonPanelLeft.HorizontalAlignment = "Left"
    $buttonPanelLeft.Margin = "5"
    [Windows.Controls.Grid]::SetRow($buttonPanelLeft, 1) | Out-Null

    $selectActions = @{
        "Select All"     = { $true }
        "Select None"    = { $false }
        "Select Default" = { param ($checkBox) [System.Convert]::ToBoolean(($checkBox.Tag -split '\|')[2]) }
    }

    foreach ($action in $selectActions.Keys) {
        $currentAction = $action
        $buttonPanelLeft.Children.Add((Add-Button -content $currentAction -width 100 -margin "5" -clickAction {
            foreach ($groupBox in $stackPanel.Children) {
                foreach ($checkBox in $groupBox.Content.Children) {
                    if ($currentAction -eq "Select Default") {
                        $checkBox.IsChecked = $selectActions[$currentAction].Invoke($checkBox)
                    } else {
                        $checkBox.IsChecked = $selectActions[$currentAction].Invoke()
                    }
                }
            }
        }.GetNewClosure())) | Out-Null
    }

    $buttonPanelRight = New-Object Windows.Controls.StackPanel
    $buttonPanelRight.Orientation = "Horizontal"
    $buttonPanelRight.HorizontalAlignment = "Right"
    $buttonPanelRight.Margin = "5"
    [Windows.Controls.Grid]::SetRow($buttonPanelRight, 1) | Out-Null

    $buttonPanelRight.Children.Add((Add-Button -content "OK" -width 75 -margin "5" -clickAction {
        $selectedItems = @()
        foreach ($groupBox in $stackPanel.Children) {
            foreach ($checkBox in $groupBox.Content.Children) {
                if ($checkBox.IsChecked -eq $true) {
                    $selectedItems += $checkBox.Tag
                }
            }
        }
        if ($selectedItems.Count -gt 0) {
            Install-Update-Software $selectedItems
        }
        $window.Close()
    })) | Out-Null

    $buttonPanelRight.Children.Add((Add-Button -content "Cancel" -width 75 -margin "5" -clickAction {
        $window.Close()
    })) | Out-Null

    $container = New-Object Windows.Controls.Grid

    $container.Children.Add($scrollViewer) | Out-Null

    $grid.Children.Add($container) | Out-Null
    $grid.Children.Add($buttonPanelLeft) | Out-Null
    $grid.Children.Add($buttonPanelRight) | Out-Null

    $window.Content = $grid
    $window.ShowDialog() | Out-Null
}

function Install-Update-Software {
    param ([array]$selectedItems)
    foreach ($item in $selectedItems) {
        $parts = $item -split '\|'
        $packageId = $parts[0]
        $packageManager = $parts[1]
        
        Write-Host "Installing/Updating $packageId using $packageManager"
        try {
            if ($packageManager -eq "choco") {
                Start-Process -FilePath "choco" -ArgumentList "upgrade $packageId -r -y" -NoNewWindow -Wait -PassThru
            } elseif ($packageManager -eq "winget") {
                Start-Process -FilePath "winget" -ArgumentList "install --id=$packageId --silent --accept-source-agreements --accept-package-agreements" -NoNewWindow -Wait -PassThru
            }
        } catch {
            Write-Host "Error installing $packageId - $($_.Exception.Message)"
        }
    }
}

function Ensure-Chocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey not installed, installing."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    } else {
        Write-Host "Chocolatey already installed, updating."
        choco upgrade chocolatey -y
    }
}

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "Winget not installed, please install Winget manually."
    } else {
        Write-Host "Winget already installed."
    }
}

# Directory where the script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Ensure Chocolatey and Winget are installed and up to date
Ensure-Chocolatey
Ensure-Winget

# Read the CSV and get software categories
$csvPath = Join-Path $scriptDir "software.csv"
$categories = Get-SoftwareFromCSV -csvPath $csvPath

# Show the dialog for user to select software
Show-CategoryDialog -categories $categories
