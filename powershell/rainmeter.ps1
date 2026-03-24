#requires -version 5.1
<#
Cozy Rainmeter Widget Installer
- Rainmeter (winget)
- HWiNFO (winget) for CPU/GPU temps
- SSyl-HWiNFO skin (temps + stats)
- MinimalWeather (OpenWeatherMap)
- Sonder NextUp calendar card (Google Calendar via private ICS)
- MiniAlarm (alarms)
- Creates a simple Shortcuts skin (incl. "Add Calendar Event" link)
#>

param(
  [string]$OpenWeatherApiKey = "",
  [string]$Latitude = "",
  [string]$Longitude = "",
  [string[]]$GoogleCalendarIcsUrls = @(),  # 1+ private ICS URLs (Google Calendar -> Settings -> Integrate calendar -> Secret address in iCal format)
  [string]$GoogleCalendarCreateEventUrl = "https://calendar.google.com/calendar/u/0/r/eventedit"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run PowerShell as Administrator."
  }
}

function Assert-Winget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install App Installer from Microsoft Store, then re-run."
  }
}

function Install-WingetPackage([string]$Id) {
  $already = winget list --id $Id --source winget 2>$null
  if ($LASTEXITCODE -eq 0 -and ($already -match $Id)) { return }
  winget install --id $Id --source winget --accept-package-agreements --accept-source-agreements --silent | Out-Null
}

function Download-File([string]$Url, [string]$OutFile) {
  New-Item -ItemType Directory -Path (Split-Path $OutFile) -Force | Out-Null
  Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Expand-Zip([string]$Zip, [string]$Dest) {
  New-Item -ItemType Directory -Path $Dest -Force | Out-Null
  Expand-Archive -Path $Zip -DestinationPath $Dest -Force
}

function Install-Rmskin([string]$RmskinPath) {
  # Rainmeter .rmskin installs by just opening it (uses Rainmeter Skin Installer)
  Start-Process -FilePath $RmskinPath -Verb Open
}

function Get-DocumentsPath {
  [Environment]::GetFolderPath("MyDocuments")
}

function Get-RainmeterSkinsPath {
  Join-Path (Get-DocumentsPath) "Rainmeter\Skins"
}

function Ensure-ShortcutsSkin([string]$SkinsRoot, [string]$CreateEventUrl) {
  $skinDir = Join-Path $SkinsRoot "CozyShortcuts"
  New-Item -ItemType Directory -Path $skinDir -Force | Out-Null

  $ini = @"
[Rainmeter]
Update=1000
AccurateText=1
DynamicWindowSize=1

[Variables]
FontName=Segoe UI
FontSize=12
Color=255,255,255,220

[StyleText]
FontFace=#FontName#
FontSize=#FontSize#
FontColor=#Color#
AntiAlias=1

[MeasureAddEvent]
Measure=String
String=$CreateEventUrl

[MeterTitle]
Meter=String
MeterStyle=StyleText
Text=Shortcuts
X=0
Y=0
FontSize=14

[MeterAddEvent]
Meter=String
MeterStyle=StyleText
Text=+ Add Calendar Event
X=0
Y=28
LeftMouseUpAction=[""$CreateEventUrl""]

[MeterExplorer]
Meter=String
MeterStyle=StyleText
Text=File Explorer
X=0
Y=52
LeftMouseUpAction=[""explorer.exe""]

[MeterTaskMgr]
Meter=String
MeterStyle=StyleText
Text=Task Manager
X=0
Y=76
LeftMouseUpAction=[""taskmgr.exe""]
"@

  Set-Content -Path (Join-Path $skinDir "CozyShortcuts.ini") -Value $ini -Encoding UTF8
}

function Patch-MinimalWeather([string]$SkinsRoot, [string]$ApiKey, [string]$Lat, [string]$Lon) {
  if ([string]::IsNullOrWhiteSpace($ApiKey) -or [string]::IsNullOrWhiteSpace($Lat) -or [string]::IsNullOrWhiteSpace($Lon)) { return }

  # MinimalWeather structure may vary; we try to locate a settings variables file
  $mw = Get-ChildItem -Path $SkinsRoot -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "MinimalWeather" } |
        Select-Object -First 1

  if (-not $mw) { return }

  $candidates = Get-ChildItem -Path $mw.FullName -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "Variables\.inc|Settings\.inc|Config\.inc|UserVariables\.inc|Weather.*\.inc" }

  foreach ($f in $candidates) {
    $txt = Get-Content $f.FullName -Raw
    $txt2 = $txt `
      -replace "(?im)^\s*ApiKey\s*=\s*.*$","ApiKey=$ApiKey" `
      -replace "(?im)^\s*Latitude\s*=\s*.*$","Latitude=$Lat" `
      -replace "(?im)^\s*Longitude\s*=\s*.*$","Longitude=$Lon"
    if ($txt2 -ne $txt) {
      Set-Content -Path $f.FullName -Value $txt2 -Encoding UTF8
      break
    }
  }
}

function Patch-SonderNextUp([string]$SkinsRoot, [string[]]$IcsUrls) {
  if (-not $IcsUrls -or $IcsUrls.Count -eq 0) { return }

  $sonder = Get-ChildItem -Path $SkinsRoot -Directory -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "sonder|nextup" } |
            Select-Object -First 1
  if (-not $sonder) { return }

  $vars = Get-ChildItem -Path $sonder.FullName -File -Recurse -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -match "Variables\.inc|Settings\.inc|Config\.inc|UserVariables\.inc" } |
          Select-Object -First 1
  if (-not $vars) { return }

  $txt = Get-Content $vars.FullName -Raw
  # Common pattern: CalendarUrl1=..., CalendarUrl2=...
  for ($i=0; $i -lt [Math]::Min(5, $IcsUrls.Count); $i++) {
    $n = $i + 1
    $url = $IcsUrls[$i]
    if ($txt -match "(?im)^\s*CalendarUrl$n\s*=") {
      $txt = $txt -replace "(?im)^\s*CalendarUrl$n\s*=.*$","CalendarUrl$n=$url"
    } else {
      $txt += "`r`nCalendarUrl$n=$url"
    }
  }
  Set-Content -Path $vars.FullName -Value $txt -Encoding UTF8
}

Assert-Admin
Assert-Winget

Write-Host "Installing Rainmeter + HWiNFO..."
Install-WingetPackage "Rainmeter.Rainmeter"
Install-WingetPackage "REALiX.HWiNFO"   # HWiNFO (name may appear as HWiNFO64 in Start Menu)

$dlRoot = Join-Path $env:TEMP "cozy-rainmeter"
New-Item -ItemType Directory -Path $dlRoot -Force | Out-Null

Write-Host "Downloading skins..."
# SSyl-HWiNFO (rmskin is stored in repo)
$ssylRmskin = Join-Path $dlRoot "SSyl-HWiNFO_1.0.rmskin"
Download-File "https://github.com/SSyl/Rainmeter-SSyl-HWiNFO/raw/master/SSyl-HWiNFO_1.0.rmskin" $ssylRmskin

# MinimalWeather (repo zip)
$mwZip = Join-Path $dlRoot "MinimalWeather.zip"
Download-File "https://github.com/leonidasIIV/MinimalWeather/archive/refs/heads/master.zip" $mwZip

# Sonder NextUp calendar card (repo zip)
$sonderZip = Join-Path $dlRoot "sonder-nextup.zip"
Download-File "https://github.com/gavinjudd/sonder-nextup-rainmeter/archive/refs/heads/master.zip" $sonderZip

# MiniAlarm (repo zip)
$alarmZip = Join-Path $dlRoot "MiniAlarm.zip"
Download-File "https://github.com/NSTechBytes/MiniAlarm/archive/refs/heads/main.zip" $alarmZip

Write-Host "Installing SSyl-HWiNFO (rmskin installer will pop up)..."
Install-Rmskin $ssylRmskin

$skinsRoot = Get-RainmeterSkinsPath
New-Item -ItemType Directory -Path $skinsRoot -Force | Out-Null

Write-Host "Unpacking repo-based skins into $skinsRoot ..."
$mwTmp = Join-Path $dlRoot "mw"
$sonderTmp = Join-Path $dlRoot "sonder"
$alarmTmp = Join-Path $dlRoot "alarm"

Expand-Zip $mwZip $mwTmp
Expand-Zip $sonderZip $sonderTmp
Expand-Zip $alarmZip $alarmTmp

# Copy extracted folders (first child is the repo root folder like MinimalWeather-master)
Copy-Item -Path (Join-Path (Get-ChildItem $mwTmp | Select-Object -First 1).FullName "*") -Destination $skinsRoot -Recurse -Force
Copy-Item -Path (Join-Path (Get-ChildItem $sonderTmp | Select-Object -First 1).FullName "*") -Destination $skinsRoot -Recurse -Force
Copy-Item -Path (Join-Path (Get-ChildItem $alarmTmp | Select-Object -First 1).FullName "*") -Destination $skinsRoot -Recurse -Force

Write-Host "Creating CozyShortcuts skin..."
Ensure-ShortcutsSkin $skinsRoot $GoogleCalendarCreateEventUrl

Write-Host "Applying config hints (if you provided keys/urls)..."
Patch-MinimalWeather $skinsRoot $OpenWeatherApiKey $Latitude $Longitude
Patch-SonderNextUp $skinsRoot $GoogleCalendarIcsUrls

Write-Host ""
Write-Host "Done."
Write-Host "Next manual steps:"
Write-Host "1) Launch HWiNFO -> Settings -> enable Shared Memory Support (needed for Rainmeter temp reads)."
Write-Host "2) Start Rainmeter, then load skins:"
Write-Host "   - SSyl-HWiNFO (temps + CPU/GPU/RAM/network via HWiNFO)"
Write-Host "   - MinimalWeather (weather; confirm API key/lat/lon if not auto-patched)"
Write-Host "   - Sonder NextUp / Calendar skin (paste private ICS URLs if not auto-patched)"
Write-Host "   - MiniAlarm (click to set alarms)"
Write-Host "   - CozyShortcuts (includes +Add Calendar Event)"
Write-Host ""
Write-Host "Tip: Right-click a skin -> Edit skin / Manage skin to tweak layout."
