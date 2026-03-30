# PowerShell script to copy the largest Firefox profile to replace the largest profile in various Firefox-derived browsers, excluding the storage folder

# Define the source Firefox profiles directory
$firefoxProfilesDir = "C:\Users\$env:USERNAME\AppData\Roaming\Mozilla\Firefox\Profiles"

# Define the target browser profiles directories
$librewolfProfilesDir = "C:\Users\$env:USERNAME\AppData\Roaming\LibreWolf\Profiles"
$floorpProfilesDir = "C:\Users\$env:USERNAME\AppData\Roaming\Floorp\Profiles"
$waterfoxProfilesDir = "C:\Users\$env:USERNAME\AppData\Roaming\Waterfox\Profiles"
$palemoonProfilesDir = "C:\Users\$env:USERNAME\AppData\Roaming\Moonchild Productions\Pale Moon\Profiles"
$basiliskProfilesDir = "C:\Users\$env:USERNAME\AppData\Roaming\Moonchild Productions\Basilisk\Profiles"

# Function to find the largest profile directory
function Get-LargestProfile {
    param (
        [string]$profilesDir
    )

    if (Test-Path $profilesDir) {
        $profiles = Get-ChildItem -Path $profilesDir -Directory
        if ($profiles.Count -eq 0) {
            return $null
        }
        $largestProfile = $profiles | Sort-Object { (Get-ChildItem -Path $_.FullName -Recurse | Measure-Object Length -Sum).Sum } -Descending | Select-Object -First 1
        return $largestProfile
    } else {
        return $null
    }
}

# Function to copy profile, excluding the storage folder and handling errors
function Copy-Profile {
    param (
        [string]$sourceProfilePath,
        [string]$targetProfilePath
    )

    if (Test-Path $sourceProfilePath) {
        if (-not (Test-Path $targetProfilePath)) {
            New-Item -ItemType Directory -Path $targetProfilePath -Force
        }

        $itemsToCopy = Get-ChildItem -Path $sourceProfilePath -Recurse | Where-Object {
            $_.FullName -notlike "*\storage\*"
        }

        foreach ($item in $itemsToCopy) {
            try {
                $relativePath = $item.FullName.Substring($sourceProfilePath.Length + 1)
                $destinationPath = Join-Path -Path $targetProfilePath -ChildPath $relativePath
                $destinationDir = Split-Path -Path $destinationPath -Parent
                if (-not (Test-Path $destinationDir)) {
                    New-Item -ItemType Directory -Path $destinationDir -Force
                }
                Copy-Item -Path $item.FullName -Destination $destinationPath -Force -ErrorAction Stop
            } catch {
                continue
            }
        }

        Write-Host "Profile copy completed for $sourceProfilePath"
    } else {
        Write-Host "Source profile path $sourceProfilePath does not exist"
    }
}

# Find the largest Firefox profile
$largestFirefoxProfile = Get-LargestProfile -profilesDir $firefoxProfilesDir

if ($largestFirefoxProfile) {
    $largestFirefoxProfilePath = $largestFirefoxProfile.FullName

    # Replace the largest profile in LibreWolf
    $largestLibreWolfProfile = Get-LargestProfile -profilesDir $librewolfProfilesDir
    if ($largestLibreWolfProfile) {
        Remove-Item -Path $largestLibreWolfProfile.FullName -Recurse -Force
        Copy-Profile -sourceProfilePath $largestFirefoxProfilePath -targetProfilePath $largestLibreWolfProfile.FullName
    }

    # Replace the largest profile in Floorp
    $largestFloorpProfile = Get-LargestProfile -profilesDir $floorpProfilesDir
    if ($largestFloorpProfile) {
        Remove-Item -Path $largestFloorpProfile.FullName -Recurse -Force
        Copy-Profile -sourceProfilePath $largestFirefoxProfilePath -targetProfilePath $largestFloorpProfile.FullName
    }

    # Replace the largest profile in Waterfox
    $largestWaterfoxProfile = Get-LargestProfile -profilesDir $waterfoxProfilesDir
    if ($largestWaterfoxProfile) {
        Remove-Item -Path $largestWaterfoxProfile.FullName -Recurse -Force
        Copy-Profile -sourceProfilePath $largestFirefoxProfilePath -targetProfilePath $largestWaterfoxProfile.FullName
    }

    # Replace the largest profile in Pale Moon
    $largestPaleMoonProfile = Get-LargestProfile -profilesDir $palemoonProfilesDir
    if ($largestPaleMoonProfile) {
        Remove-Item -Path $largestPaleMoonProfile.FullName -Recurse -Force
        Copy-Profile -sourceProfilePath $largestFirefoxProfilePath -targetProfilePath $largestPaleMoonProfile.FullName
    }

    # Replace the largest profile in Basilisk
    $largestBasiliskProfile = Get-LargestProfile -profilesDir $basiliskProfilesDir
    if ($largestBasiliskProfile) {
        Remove-Item -Path $largestBasiliskProfile.FullName -Recurse -Force
        Copy-Profile -sourceProfilePath $largestFirefoxProfilePath -targetProfilePath $largestBasiliskProfile.FullName
    }

    Write-Host "All profiles replaced with the largest Firefox profile!"
} else {
    Write-Host "No Firefox profiles found to copy."
}
