# TODO: add a way to add loose xpi files not in the addons.mozilla.org list
# Directory where the script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Directory to save the extensions
$extensionsDir = Join-Path $scriptDir "extensions"
if (-not (Test-Path $extensionsDir)) {
    New-Item -Path $extensionsDir -ItemType Directory -Force | Out-Null
}

# Function to download the extension
function Download-Extension {
    param (
        [string]$addonID,
        [string]$addonUrl
    )
    $xpiPath = Join-Path $extensionsDir "$addonID.xpi"

    if (-not (Test-Path $xpiPath)) {
        Write-Host "Downloading $addonID..."
        try {
            Invoke-WebRequest -Uri $addonUrl -OutFile $xpiPath -ErrorAction Stop
            Write-Host "$addonID downloaded successfully."
        } catch {
            Write-Host "Failed to download $addonID - $($_.Exception.Message)"
        }
    } else {
        Write-Host "$addonID already downloaded. Skipping download."
    }
}

# List of extensions to download
$extensions = @(
    @{id="ublock-origin"; url="https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"},
    @{id="darkreader"; url="https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi"},
    @{id="bypass-paywalls-clean"; url="https://github.com/iamadamdev/bypass-paywalls-chrome/releases/latest/download/bypass-paywalls-firefox.xpi"},
    @{id="video-downloadhelper"; url="https://addons.mozilla.org/firefox/downloads/latest/video-downloadhelper/latest.xpi"},
    @{id="keepa"; url="https://addons.mozilla.org/firefox/downloads/latest/keepa/latest.xpi"},
    @{id="wikiwand-wikipedia-modernized"; url="https://addons.mozilla.org/firefox/downloads/latest/wikiwand-wikipedia-modernized/latest.xpi"},
    @{id="augmented-steam"; url="https://addons.mozilla.org/firefox/downloads/latest/augmented-steam/latest.xpi"},
    @{id="i-still-dont-care-about-cookies"; url="https://addons.mozilla.org/firefox/downloads/latest/i-still-dont-care-about-cookies/latest.xpi"},
    @{id="violentmonkey"; url="https://addons.mozilla.org/firefox/downloads/latest/violentmonkey/latest.xpi"}
    # archive page it's on like a russian github
    # wayback machine
    # umatrix
    # export tab urls
    # allow right-click
    # persistent pin
    # refined github
    # private bookmarks    
)

# Download each extension
foreach ($extension in $extensions) {
    Write-Host "Preparing to download $($extension.id)..."
    Download-Extension -addonID $extension.id -addonUrl $extension.url
}

Write-Host "All extensions downloaded to $extensionsDir"
Read-Host "Press Enter to exit..."
