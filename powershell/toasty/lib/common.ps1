# Dot-sourced helpers for Toasty CLI: color, OSC 8 hyperlinks, icons.
# Not intended to be run as a standalone command.

$script:ToastyColorInit = $false
$script:ToastyUseColor = $false
$script:ToastyUseHyperlinks = $false

function Initialize-ToastyHost {
    if ($script:ToastyColorInit) { return }
    $script:ToastyColorInit = $true
    $noColor = $env:NO_COLOR -or ($env:TOASTY_NO_COLOR -eq '1')
    $vt = $false
    try {
        if ($Host.UI.SupportsVirtualTerminal) { $vt = $true }
    } catch { }
    if (-not $vt -and $env:WT_SESSION) { $vt = $true }
    if (-not $vt -and $env:TERM_PROGRAM) { $vt = $true }
    if (-not $vt -and $env:ConEmuANSI -eq 'ON') { $vt = $true }
    $script:ToastyUseColor = (-not $noColor) -and $vt
    $script:ToastyUseHyperlinks = $script:ToastyUseColor -and ($env:TOASTY_NO_HYPERLINKS -ne '1')
}

function Get-ToastyEsc { return [string][char]0x1B }

function Format-ToastyFileUri {
    param([Parameter(Mandatory)][string]$Path)
    $full = $null
    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        $full = $item.FullName
    } catch {
        try { $full = [System.IO.Path]::GetFullPath($Path) } catch { $full = $Path }
    }
    $norm = ($full -replace '\\', '/')
    if ($norm -match '^[A-Za-z]:') {
        return ('file:///' + $norm)
    }
    if ($norm.StartsWith('\\')) {
        $rest = $norm.TrimStart('\')
        return ('file:////' + ($rest -replace '\\', '/'))
    }
    return ('file:///' + $norm.TrimStart('/'))
}

function Format-ToastyOsc8 {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Text
    )
    Initialize-ToastyHost
    if (-not $script:ToastyUseHyperlinks) { return $Text }
    $e = Get-ToastyEsc
    $bel = [char]7
    return ($e + ']8;;' + $Uri + $bel + $Text + $e + ']8;;' + $bel)
}

function Convert-ToastyEzaLineHyperlinksToCdProtocol {
  <#
  .SYNOPSIS
  Rewrites eza OSC 8 file:// links to toasty-cd: so Ctrl+click can run shell\Register-ToastyCdUrlProtocol.ps1 (copies cd line).
  #>
  [CmdletBinding()]
  param([Parameter(ValueFromPipeline)][string]$Line)
  process {
    if ([string]::IsNullOrEmpty($Line)) { return $Line }
    if ($Line.IndexOf(']8;;file://', [StringComparison]::Ordinal) -lt 0) { return $Line }
    $esc = [char]27
    $bel = [char]7
    $pat = [regex]::Escape($esc) + ']8;;(file://[^\a]+)\a'
    $rx = [regex]::new($pat)
    $me = [System.Text.RegularExpressions.MatchEvaluator] {
      param($m)
      $uriText = $m.Groups[1].Value
      try {
        $u = [Uri]$uriText
        $norm = $u.LocalPath
      } catch {
        return $m.Value
      }
      if ([string]::IsNullOrWhiteSpace($norm)) { return $m.Value }
      if ($norm -match '^/[A-Za-z]:') { $norm = $norm.Substring(1) }
      $encoded = [Uri]::EscapeDataString($norm)
      $esc + ']8;;toasty-cd:' + $encoded + $bel
    }
    $rx.Replace($Line, $me)
  }
}

function Format-ToastyPathLink {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Display
    )
    Initialize-ToastyHost
    $resolved = $Path
    try { $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path } catch { }
    if (-not $Display) { $Display = $resolved }
    $uri = Format-ToastyFileUri $resolved
    return (Format-ToastyOsc8 -Uri $uri -Text $Display)
}

function Format-ToastyUrlLink {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$Display
    )
    Initialize-ToastyHost
    if (-not $Display) { $Display = $Url }
    if (-not $script:ToastyUseHyperlinks) { return $Display }
    $e = Get-ToastyEsc
    $bel = [char]7
    return ($e + ']8;;' + $Url + $bel + $Display + $e + ']8;;' + $bel)
}

function Get-ToastyItemIcon {
    param([Parameter(Mandatory)]$Item)
    if ($Item.PSIsContainer) { return "`u{1F4C1}" }
    $attr = $Item.Attributes
    if ($attr -band [IO.FileAttributes]::ReparsePoint) { return "`u{1F517}" }
    $ext = ($Item.Extension ?? '').ToLowerInvariant()
    if ($ext -in '.exe', '.bat', '.cmd', '.ps1', '.msi', '.msix') { return "`u{2699}" }
    if ($ext -in '.dll', '.so') { return "`u{1F9E9}" }
    if ($ext -in '.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.ico') { return "`u{1F5BC}" }
    if ($ext -in '.zip', '.7z', '.rar', '.tar', '.gz', '.bz2', '.xz') { return "`u{1F4E6}" }
    if ($ext -in '.md', '.txt', '.log', '.rst') { return "`u{1F4DD}" }
    if ($ext -in '.json', '.yml', '.yaml', '.toml', '.xml', '.ini', '.cfg') { return "`u{1F4DC}" }
    if ($ext -in '.cs', '.cpp', '.c', '.h', '.hpp', '.js', '.ts', '.tsx', '.jsx', '.py', '.rs', '.go', '.java', '.rb', '.php') { return "`u{1F4BB}" }
    return "`u{1F4C4}"
}

function Write-ToastyMsg {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Ok', 'Warn', 'Err', 'Muted', 'Accent')][string]$Level = 'Info'
    )
    Initialize-ToastyHost
    if (-not $script:ToastyUseColor) {
        Write-Host $Message
        return
    }
    $icon = switch ($Level) {
        'Info' { "`u{2139} " }
        'Ok' { "`u{2713} " }
        'Warn' { "`u{26A0} " }
        'Err' { "`u{2717} " }
        'Muted' { '' }
        'Accent' { "`u{27A4} " }
        default { '' }
    }
    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Ok' { 'Green' }
        'Warn' { 'Yellow' }
        'Err' { 'Red' }
        'Muted' { 'DarkGray' }
        'Accent' { 'White' }
        default { 'Gray' }
    }
    Write-Host ($icon + $Message) -ForegroundColor $color
}

function Get-ToastyDfColor {
    param([double]$PctUsed)
    Initialize-ToastyHost
    if (-not $script:ToastyUseColor) { return $null }
    if ($PctUsed -ge 95) { return 'Red' }
    if ($PctUsed -ge 85) { return 'Yellow' }
    if ($PctUsed -ge 70) { return 'DarkYellow' }
    return 'Green'
}

function Get-ToastyDuColor {
    param([double]$MiB)
    Initialize-ToastyHost
    if (-not $script:ToastyUseColor) { return $null }
    if ($MiB -ge 1024) { return 'Red' }
    if ($MiB -ge 256) { return 'Yellow' }
    return 'Cyan'
}

function Write-ToastyPathLine {
    param(
        [Parameter(Mandatory)][string]$FullPath,
        [string]$Prefix = ''
    )
    $link = Format-ToastyPathLink -Path $FullPath -Display $FullPath
    try {
        $item = Get-Item -LiteralPath $FullPath -Force -ErrorAction Stop
        $ic = Get-ToastyItemIcon $item
        Write-Host ($Prefix + $ic + ' ' + $link)
    } catch {
        Write-Host ($Prefix + "`u{1F4C4} " + $link)
    }
}
