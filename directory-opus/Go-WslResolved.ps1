#Requires -Version 5.1
<#
.SYNOPSIS
  Resolve WSL symlinks (readlink -f) and open the target in the active Directory Opus lister.

.DESCRIPTION
  For paths under \\wsl$\ or \\wsl.localhost\, if the item is a reparse point (symlink/junction),
  asks the distro for the canonical path, maps it to a Windows path, then runs dopusrt Go.
  For a resolved file, uses the default Windows handler (Start-Process). Non-WSL paths are
  passed through with dopusrt Go (folders) or Start-Process (files).

  Opus wiring (double-click):
  Settings -> File Types -> find "Symbolic Link" / link type (names vary in Opus 13).
  Events -> double-click: run
    powershell.exe -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "FULLPATH\Go-WslResolved.ps1" "{filepath}"
  Prefer binding this to the symlink / link type so normal folders keep default Opus behavior.

  Ref: https://docs.dopus.com/doku.php?id=reference:dopusrt_reference
#>
param(
    [Parameter(Mandatory)]
    [string] $LiteralPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DopusRtPath {
    foreach ($root in @(${env:ProgramFiles}, ${env:ProgramFiles(x86)})) {
        if ([string]::IsNullOrEmpty($root)) { continue }
        $p = Join-Path $root 'GPSoftware\Directory Opus\dopusrt.exe'
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

function Invoke-DopusGo {
    param([string] $TargetPath)
    $exe = Get-DopusRtPath
    if (-not $exe) { throw 'dopusrt.exe not found under Program Files.' }
    Start-Process -FilePath $exe -ArgumentList @('/acmd', 'Go', $TargetPath) -WindowStyle Hidden
}

function Test-WslUnc {
    param([string] $Path)
    return $Path -match '^(?i)\\\\wsl(\.localhost)?\\[^\\]+\\'
}

function Split-WslUnc {
    param([string] $Path)
    $m = [regex]::Match($Path, '^(?i)\\\\(wsl(\.localhost)?)\\([^\\]+)\\(.*)$')
    if (-not $m.Success) { return $null }
    $hostPart = $m.Groups[1].Value
    $distro = $m.Groups[3].Value
    $tail = $m.Groups[4].Value
    $unixPath = '/' + ($tail -replace '\\', '/')
    return [pscustomobject]@{
        HostPart = $hostPart
        Distro   = $distro
        UnixPath = $unixPath
    }
}

function ConvertFrom-WslUnixPath {
    param(
        [string] $Distro,
        [string] $HostPart,
        [string] $UnixPath
    )
    $trim = $UnixPath.Trim()
    if ($trim -match '^(?i)/mnt/([a-z])/(.*)$') {
        $drive = $Matches[1].ToUpperInvariant()
        $rest = $Matches[2] -replace '/', '\'
        return "$drive`:\$rest"
    }
    $rel = ($trim.TrimStart('/') -replace '/', '\')
    return "\\$HostPart\$Distro\$rel"
}

function Invoke-ReadlinkF {
    param([string] $Distro, [string] $UnixPath)
    $out = & wsl.exe -d $Distro -e readlink -f -- $UnixPath 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($out)) { return $null }
    return ($out | Select-Object -First 1).Trim()
}

$path = $LiteralPath.Trim('"')

if (-not (Test-Path -LiteralPath $path)) {
    exit 1
}

$item = Get-Item -LiteralPath $path -Force
$isReparse = [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)

if (-not (Test-WslUnc $path)) {
    if ($item.PSIsContainer) {
        Invoke-DopusGo $item.FullName
    }
    else {
        Start-Process -FilePath $item.FullName
    }
    exit 0
}

$parts = Split-WslUnc $item.FullName
if (-not $parts) {
    if ($item.PSIsContainer) { Invoke-DopusGo $item.FullName }
    else { Start-Process -FilePath $item.FullName }
    exit 0
}

if (-not $isReparse) {
    if ($item.PSIsContainer) { Invoke-DopusGo $item.FullName }
    else { Start-Process -FilePath $item.FullName }
    exit 0
}

$resolvedUnix = Invoke-ReadlinkF -Distro $parts.Distro -UnixPath $parts.UnixPath
if ([string]::IsNullOrWhiteSpace($resolvedUnix)) {
    if ($item.PSIsContainer) { Invoke-DopusGo $item.FullName }
    else { Start-Process -FilePath $item.FullName }
    exit 0
}

$resolvedWin = ConvertFrom-WslUnixPath -Distro $parts.Distro -HostPart $parts.HostPart -UnixPath $resolvedUnix

if (Test-Path -LiteralPath $resolvedWin -PathType Container) {
    Invoke-DopusGo $resolvedWin
}
elseif (Test-Path -LiteralPath $resolvedWin -PathType Leaf) {
    Start-Process -FilePath $resolvedWin
}
else {
    if ($item.PSIsContainer) { Invoke-DopusGo $item.FullName }
    else { Start-Process -FilePath $item.FullName }
}
