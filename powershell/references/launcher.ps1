# Store the current script's directory
$scriptDir = $PSScriptRoot

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "Requesting administrative privileges..."
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -ScriptDir `"$scriptDir`""
    Start-Process powershell -Verb runAs -ArgumentList $arguments -Wait
    Exit
}

# If -ScriptDir parameter is provided, change to that directory
if ($PSBoundParameters.ContainsKey('ScriptDir')) {
    Set-Location $ScriptDir
}

$mainScriptName = "install.ps1"
$logFile = "$PSScriptRoot\install_log.txt"

function Write-HostAndLog ($message) {
    Write-Host $message
    Add-Content -Path $logFile -Value "$(Get-Date) - $message"
}

# Ensure we're in the correct directory
Write-HostAndLog "Current directory: $PSScriptRoot"

function Get-LatestPowerShell7Info {
    $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $asset = $releaseInfo.assets | Where-Object { $_.name -like "*win-x64.msi" }
    return @{
        Url = $asset.browser_download_url
        Version = $releaseInfo.tag_name.TrimStart('v')
    }
}

function Install-PowerShell7 {
    $ps7Info = Get-LatestPowerShell7Info
    $installerPath = "$env:TEMP\PowerShell-7-$($ps7Info.Version).msi"

    if (!(Test-Path $installerPath)) {
        Write-HostAndLog "Downloading PowerShell $($ps7Info.Version)..."
        Invoke-WebRequest -Uri $ps7Info.Url -OutFile $installerPath
    } else {
        Write-HostAndLog "PowerShell $($ps7Info.Version) installer already exists. Skipping download."
    }

    Write-HostAndLog "Installing PowerShell $($ps7Info.Version)..."
    $logPath = "$env:TEMP\PS7_Install_Log.txt"
    $process = Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qn /l*v `"$logPath`"" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-HostAndLog "PowerShell 7 installation failed with exit code: $($process.ExitCode)"
        Write-HostAndLog "Please check the installation log at: $logPath"
        Write-HostAndLog "You may need to install PowerShell 7 manually. The installer is located at: $installerPath"
        Write-HostAndLog "After manual installation, please restart this script."
        Read-Host "Press Enter to exit"
        exit 1
    }
    Write-HostAndLog "PowerShell $($ps7Info.Version) installed successfully."
}

function Find-PowerShell7 {
    $possiblePaths = @(
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
        "$env:LocalAppData\Microsoft\PowerShell\7\pwsh.exe"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Invoke-MainScript {
    $ps7Path = Find-PowerShell7
    if (-not $ps7Path) {
        Write-HostAndLog "Unable to find PowerShell 7+ executable. Installation may have failed."
        Write-HostAndLog "Searched paths:"
        $possiblePaths | ForEach-Object { Write-HostAndLog "  $_" }
        Read-Host "Press Enter to exit"
        exit 1
    }

    $fullScriptPath = Join-Path $PSScriptRoot $mainScriptName
    if (-not (Test-Path $fullScriptPath)) {
        Write-HostAndLog "Error: Cannot find $mainScriptName at $fullScriptPath"
        Read-Host "Press Enter to exit"
        exit 1
    }

    Write-HostAndLog "Launching $mainScriptName with PowerShell 7+ found at: $ps7Path"
    Write-HostAndLog "Full script path: $fullScriptPath"

    $launchArgs = "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$fullScriptPath`""
    Write-HostAndLog "Launch command: $ps7Path $launchArgs"

    & $ps7Path @launchArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-HostAndLog "Error: $mainScriptName exited with code $LASTEXITCODE"
        Read-Host "Press Enter to exit"
    }
}

# Main execution
try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-HostAndLog "PowerShell 7+ is required. Current version is $($PSVersionTable.PSVersion)"
        
        if (-not (Find-PowerShell7)) {
            Install-PowerShell7
        } else {
            Write-HostAndLog "PowerShell 7+ is already installed."
        }
        
        Write-HostAndLog "Launching $mainScriptName with PowerShell 7+..."
        Invoke-MainScript
    } else {
        Write-HostAndLog "Running $mainScriptName with PowerShell $($PSVersionTable.PSVersion)"
        & "$PSScriptRoot\$mainScriptName"
    }
}
catch {
    Write-HostAndLog "An error occurred: $_"
    Write-HostAndLog "Stack Trace: $($_.ScriptStackTrace)"
}
finally {
    # Pause at the end to keep the window open
    Read-Host "Press Enter to exit"
}