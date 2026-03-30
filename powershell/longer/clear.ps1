function Write-Status {
    param (
        [string]$status
    )
    $color = if ($status -eq "✔") { "Green" } else { "Red" }
    Write-Host "`t$status" -ForegroundColor $color
}

function Try-Execute {
    param (
        [scriptblock]$codeBlock,
        [string]$app
    )
    Write-Host "**** $app ****"
    $global:LASTEXITCODE = 0
    try {
        & $codeBlock
        Write-Status $(if ($global:LASTEXITCODE -eq 0) { "✔" } else { "✖" })
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Status "✖"
        $global:LASTEXITCODE = 1
    }
    Write-Host ""
}

function Safe-Remove-Item {
    param ([string]$path)
    try {
        if (Test-Path $path) {
            if ((Get-Item $path).PSIsContainer) {
                Remove-Item $path -Recurse -Force -ErrorAction Stop
                Write-Host "$path recursively removed."
            } else {
                Remove-Item $path -Force -ErrorAction Stop
                Write-Host "$path removed."
            }
        } else {
            Write-Host "$path not found."
            $global:LASTEXITCODE = 1
        }
    } catch {
        Write-Host "Failed to remove $path - $($_.Exception.Message)" -ForegroundColor Red
        $global:LASTEXITCODE = 1
    }
}

# Browser Histories
Try-Execute { Safe-Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History" } "Chrome"
Try-Execute { Safe-Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History" } "Edge"
Try-Execute { Safe-Remove-Item "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\History" } "Brave"
Try-Execute { Safe-Remove-Item "$env:APPDATA\Librefox\Profiles\*\places.sqlite" } "Librefox"
Try-Execute { Safe-Remove-Item "$env:APPDATA\Floorp\Profiles\*\places.sqlite" } "Floorp"
Try-Execute { Safe-Remove-Item "$env:APPDATA\Opera Software\Opera Stable\History" } "Opera"
Try-Execute { Safe-Remove-Item "$env:APPDATA\Mozilla\Firefox\Profiles\*\places.sqlite" } "Firefox"
Try-Execute { Safe-Remove-Item "$env:APPDATA\Vivaldi\User Data\Default\History" } "Vivaldi"

# Application Data
Try-Execute { Safe-Remove-Item "$env:APPDATA\GPSoftware\Directory Opus\ConfigFiles\smartfav.osf" } "Directory Opus"
Try-Execute { Safe-Remove-Item "$env:APPDATA\Everything\Search History.csv" } "Everything"
Try-Execute { Safe-Remove-Item "$env:APPDATA\Notepad++\session.xml" } "Notepad++"
Try-Execute { Safe-Remove-Item "$env:APPDATA\FastStone Image Viewer\FSViewer.dat" } "FastStone"

# Windows Explorer Recent Files
Try-Execute { Safe-Remove-Item ([System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\Recent')) } "Windows Explorer"

# Recycle Bin
Try-Execute { Clear-RecycleBin -Force -ErrorAction Stop } "Recycle Bin"

# Temporary Files
Try-Execute { Safe-Remove-Item ([System.IO.Path]::GetTempPath()) } "Temporary Files"

# DNS Cache
Try-Execute { Clear-DnsClientCache } "DNS Cache"

# Windows Thumbnail Cache
Try-Execute { Safe-Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*" } "Windows Thumbnail Cache"