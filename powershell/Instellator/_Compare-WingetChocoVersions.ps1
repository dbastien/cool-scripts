#requires -Version 7.2
# Memory-conscious: StreamWriter (one row at a time); streaming parse of winget/choco stdout; no report array.
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$csvPath = Join-Path $here 'GUI-apps.csv'
$outPath = Join-Path $here 'winget-choco-version-report.csv'

function Escape-CsvField {
  param([AllowNull()][string]$Text)
  if ([string]::IsNullOrEmpty($Text)) { return '' }
  if ($Text -match '["\r\n,]') { return '"' + ($Text.Replace('"', '""')) + '"' }
  $Text
}

function Get-WingetVersion {
  param([string]$Id)
  if ([string]::IsNullOrWhiteSpace($Id)) { return $null }
  $psi = [System.Diagnostics.ProcessStartInfo]@{
    FileName               = 'winget'
    Arguments              = "show --id `"$Id`" -e --accept-source-agreements"
    UseShellExecute        = $false
    RedirectStandardOutput = $true
    RedirectStandardError  = $true
    CreateNoWindow         = $true
  }
  $p = [System.Diagnostics.Process]::new()
  $p.StartInfo = $psi
  [void]$p.Start()
  $sr = $p.StandardOutput
  try {
    while (-not $sr.EndOfStream) {
      $line = $sr.ReadLine()
      if ($line -match '^\s*Version:\s*(.+)\s*$') {
        try { if (-not $p.HasExited) { $p.Kill() } } catch { }
        return $Matches[1].Trim()
      }
    }
  } finally {
    try { $p.WaitForExit(15000) } catch { }
    $p.Dispose()
  }
  $null
}

function Get-ChocoVersion {
  param([string]$Id)
  if ([string]::IsNullOrWhiteSpace($Id)) { return $null }
  $psi = [System.Diagnostics.ProcessStartInfo]@{
    FileName               = 'choco'
    Arguments              = "search `"$Id`" --exact --limit-output"
    UseShellExecute        = $false
    RedirectStandardOutput = $true
    RedirectStandardError  = $true
    CreateNoWindow         = $true
  }
  $p = [System.Diagnostics.Process]::new()
  $p.StartInfo = $psi
  [void]$p.Start()
  $sr = $p.StandardOutput
  try {
    while (-not $sr.EndOfStream) {
      $line = $sr.ReadLine()
      if ($line -match '^(\S+)\|(.+)$' -and $Matches[1] -eq $Id) { return $Matches[2].Trim() }
    }
  } finally {
    try { $p.WaitForExit(60000) } catch { }
    $p.Dispose()
  }
  $null
}

function Compare-VerStrings {
  param([string]$A, [string]$B)
  $wgNorm = ($A -replace '^v', '') -replace '[^\d\.].*$', ''
  $chNorm = ($B -replace '^v', '') -replace '[^\d\.].*$', ''
  try {
    while (($wgNorm -split '\.').Count -lt 4) { $wgNorm += '.0' }
    while (($chNorm -split '\.').Count -lt 4) { $chNorm += '.0' }
    $v1 = [version]$wgNorm
    $v2 = [version]$chNorm
    if ($v1 -gt $v2) { return 'winget newer' }
    if ($v2 -gt $v1) { return 'choco newer' }
    return 'same (numeric)'
  } catch {
    return 'incomparable'
  }
}

$WingetToChoco = [ordered]@{
  'Google.Chrome'                          = 'googlechrome'
  'Opera.Opera'                            = 'opera'
  'SumatraPDF.SumatraPDF'                  = 'sumatrapdf'
  'qBittorrent.qBittorrent.Beta'           = 'qbittorrent'
  'SoftDeluxe.FreeDownloadManager'         = 'freedownloadmanager'
  'Reshade.Setup'                          = 'reshade'
  'WerWolv.Imhex'                          = 'imhex'
  'DuongDieuPhap.ImageGlass'               = 'imageglass'
  'Microsoft.DotNet.SDK.Preview'           = 'dotnet-sdk'
  'Microsoft.VisualStudioCode'             = 'vscode'
  'voidtools.Everything.Alpha'             = 'everything'
  'Tailscale.Tailscale'                    = 'tailscale'
  'AutoHotkey.AutoHotkey'                  = 'autohotkey'
  'REALiX.HWiNFO'                          = 'hwinfo'
  'Microsoft.Sysinternals.ProcessExplorer' = 'procexp'
  'Klocman.BulkCrapUninstaller'            = 'bulk-crap-uninstaller'
  'LocalSend.LocalSend'                    = 'localsend'
  'LastPass.LastPass'                      = 'lastpass'
  'AgileBits.1Password'                    = '1password'
  'Bitwarden.Bitwarden'                    = 'bitwarden'
  'Dashlane.Dashlane'                      = 'dashlane'
  'StartIsBack.StartAllBack'               = 'startallback'
  'SomePythonThings.WingetUIStore.Pre-release' = 'wingetui'
}

$ChocoToWinget = [ordered]@{}
foreach ($kv in $WingetToChoco.GetEnumerator()) {
  if (-not $ChocoToWinget.Contains($kv.Value)) { $ChocoToWinget[$kv.Value] = $kv.Key }
}

$extraChoco = @{
  'firefox' = 'Mozilla.Firefox'; 'floorp' = 'AblazeFloorp.Floorp'; 'librewolf' = 'LibreWolf.LibreWolf'
  'vivaldi' = 'VivaldiTechnologies.Vivaldi'; 'discord' = 'Discord.Discord'; 'skype' = 'Microsoft.Skype'
  'slack' = 'SlackTechnologies.Slack'; 'zoom' = 'Zoom.Zoom'; 'beyondcompare' = 'ScooterSoftware.BeyondCompare4'
  'docker-desktop' = 'Docker.DockerDesktop'; 'git' = 'Git.Git'; 'gitkraken' = 'Axosoft.GitKraken'
  'jetbrainstoolbox' = 'JetBrains.Toolbox'; 'python3' = 'Python.Python.3.12'; 'unityhub' = 'Unity.UnityHub'
  'winmerge' = 'WinMerge.WinMerge'; 'adobereader' = 'Adobe.Acrobat.Reader.64-bit'; 'foxitreader' = 'Foxit.FoxitReader'
  'logseq' = 'Logseq.Logseq'; 'notepadplusplus' = 'Notepad++.Notepad++'; 'obsidian' = 'Obsidian.Obsidian'
  'yt-dlp' = 'yt-dlp.yt-dlp'; 'steam' = 'Valve.Steam'; 'hxd' = 'mh-nexus.HxD'; 'blender' = 'BlenderFoundation.Blender'
  'inkscape' = 'Inkscape.Inkscape'; 'kdenlive' = 'KDE.Kdenlive'; 'obs-studio' = 'OBSProject.OBSStudio'
  'paintdotnet' = 'dotPDNLLC.paintdotnet'; 'tenacity' = 'TenacityTeam.Tenacity'; 'spotify' = 'Spotify.Spotify'
  'calibre' = 'calibre.calibre'; 'handbrake' = 'HandBrake.HandBrake'; 'mkvtoolnix' = 'MoritzBunkus.MKVToolNix'
  'keepassxc' = 'KeePassXC.KeePassXC'; 'veracrypt' = 'IDRIX.VeraCrypt'; 'copyq' = 'hluk.CopyQ'
  'flameshot' = 'Flameshot.Flameshot'; 'flow-launcher' = 'FlowLauncher.FlowLauncher'; 'powertoys' = 'Microsoft.PowerToys'
  'sharex' = 'ShareX.ShareX'; 'cpu-z' = 'CPUID.CPU-Z'; 'crystaldiskmark' = 'CrystalDewWorld.CrystalDiskMark'
  'gpu-z' = 'TechPowerUp.GPU-Z'; 'hwmonitor' = 'CPUID.HWMonitor'; 'windirstat' = 'WinDirStat.WinDirStat'
  'googledrive' = 'Google.GoogleDrive'; 'NanaZip' = 'M2Team.NanaZip'; 'qalculate' = 'Qalculate.Qalculate'
  'rufus' = 'Rufus.Rufus'; 'terminal' = 'Microsoft.WindowsTerminal'
}
foreach ($k in $extraChoco.Keys) {
  if ($extraChoco[$k] -and -not $ChocoToWinget.Contains($k)) { $ChocoToWinget[$k] = $extraChoco[$k] }
}

$DotNetChoco = [ordered]@{
  'Microsoft.DotNet.DesktopRuntime.3_1' = 'dotnetcore-desktopruntime'
  'Microsoft.DotNet.DesktopRuntime.5'   = 'dotnet-5.0-desktopruntime'
  'Microsoft.DotNet.DesktopRuntime.6'   = 'dotnet-6.0-desktopruntime'
  'Microsoft.DotNet.DesktopRuntime.7'   = 'dotnet-7.0-desktopruntime'
  'Microsoft.DotNet.DesktopRuntime.8'   = 'dotnet-8.0-desktopruntime'
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$sw = [System.IO.StreamWriter]::new($outPath, $false, $utf8NoBom)
$sw.WriteLine('Category,Name,CSV_PM,WingetId,WingetVer,ChocoId,ChocoVer,Comparison,Note')

foreach ($r in (Import-Csv -LiteralPath $csvPath)) {
  $wgId = $null; $chId = $null; $wgVer = $null; $chVer = $null; $note = ''
  if ($r.PackageManager -eq 'winget') {
    $wgId = $r.PackageID
    $wgVer = Get-WingetVersion -Id $wgId
    if ($WingetToChoco.Contains($r.PackageID)) {
      $chId = $WingetToChoco[$r.PackageID]; $chVer = Get-ChocoVersion -Id $chId
    } elseif ($DotNetChoco.Contains($r.PackageID)) {
      $chId = $DotNetChoco[$r.PackageID]; $chVer = Get-ChocoVersion -Id $chId; $note = 'dotnet choco major pkg'
    }
  } else {
    $chId = $r.PackageID; $chVer = Get-ChocoVersion -Id $chId
    if ($ChocoToWinget.Contains($r.PackageID)) {
      $wgId = $ChocoToWinget[$r.PackageID]
      if ($wgId) { $wgVer = Get-WingetVersion -Id $wgId }
    }
  }
  if ($wgVer -and $chVer) {
    $cmp = Compare-VerStrings -A $wgVer -B $chVer
    if ($cmp -eq 'incomparable') { $note = "wg=$wgVer ch=$chVer" }
  } elseif ($wgVer -and -not $chVer) { $cmp = 'winget only / choco N/A' }
  elseif ($chVer -and -not $wgVer) { $cmp = 'choco only / winget N/A' }
  else { $cmp = 'one or both queries failed' }
  $line = @(
    (Escape-CsvField $r.Category); (Escape-CsvField $r.Name); (Escape-CsvField $r.PackageManager)
    (Escape-CsvField $wgId); (Escape-CsvField $wgVer); (Escape-CsvField $chId); (Escape-CsvField $chVer)
    (Escape-CsvField $cmp); (Escape-CsvField $note)
  ) -join ','
  $sw.WriteLine($line)
  Write-Host ($r.Name + ' -> ' + $cmp)
}
$sw.Flush(); $sw.Dispose()
Write-Host "`nWrote $outPath"
