Add-Type -AssemblyName PresentationFramework

# Common error handling function for registry operations
function Handle-RegistryOperation {
    param (
        [string]$key,
        [string]$filePath,
        [scriptblock]$operation
    )
    try {
        & $operation
    } catch {
        Write-Error "Failed to process registry key $key to/from $filePath`n$($_.Exception.Message)"
    }
}

# Function to save settings
function Save-Settings {
    $scriptPath = $PSCommandPath
    $appDirectory = Split-Path $scriptPath -Parent
    $destinationFolder = "$appDirectory\WindowsSettings"
    if (-Not (Test-Path -Path $destinationFolder)) {
        New-Item -ItemType Directory -Path $destinationFolder
    }

    $keys = @(
        "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", # Dark mode settings
        "HKCU\AppEvents\Schemes", # Sound theme
        "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Accent", # Accent colors
        "HKCU\Control Panel\Desktop", # Desktop background
        "HKCU\Control Panel\Colors", # Desktop background color
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", # Show hidden files
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" # Taskbar settings
    )

    foreach ($key in $keys) {
        Handle-RegistryOperation $key "$destinationFolder\$($key -replace '\\', '_').reg" {
            if (Test-Path "HKCU:\$($key.Substring(5))") {
                reg export $key "$destinationFolder\$($key -replace '\\', '_').reg" /y
            } else {
                Write-Warning "Registry key not found: $key"
            }
        }
    }

    Write-Host "Settings saved successfully!"
}

# Function to load settings
function Load-Settings {
    $scriptPath = $PSCommandPath
    $appDirectory = Split-Path $scriptPath -Parent
    $sourceFolder = "$appDirectory\WindowsSettings"

    if (-Not (Test-Path -Path $sourceFolder)) {
        Write-Error "No backup found in $sourceFolder"
        return
    }

    $files = Get-ChildItem -Path $sourceFolder -Filter *.reg

    foreach ($file in $files) {
        Handle-RegistryOperation $file "$file" {
            reg import "$file"
        }
    }

    Write-Host "Settings loaded successfully!"
}

# Create the WPF window
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Settings Transfer App" Height="200" Width="300">
    <Grid>
        <Button Name="SaveButton" Content="Save" HorizontalAlignment="Left" VerticalAlignment="Top" Width="100" Height="30" Margin="50,50,0,0" />
        <Button Name="LoadButton" Content="Load" HorizontalAlignment="Right" VerticalAlignment="Top" Width="100" Height="30" Margin="0,50,50,0" />
    </Grid>
</Window>
"@

# Load the XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Assign event handlers
$window.FindName("SaveButton").Add_Click({ Save-Settings })
$window.FindName("LoadButton").Add_Click({ Load-Settings })

# Show the window
$window.ShowDialog() | Out-Null
