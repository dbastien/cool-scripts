# Dot-sourced helpers for shortps1 tools (SharedLibs\ShortCommon.ps1): color, OSC 8 hyperlinks, icons.
# Not intended to be run as a standalone command.

$script:ShortPs1ColorInitialized = $false
$script:ShortPs1UseColor = $false
$script:ShortPs1UseHyperlinks = $false

function Initialize-ShortPs1Host {
    if ($script:ShortPs1ColorInitialized) { return }
    $script:ShortPs1ColorInitialized = $true
    $noColor = $env:NO_COLOR -or ($env:SHORTPS1_NO_COLOR -eq '1')
    $vt = $false
    try {
        if ($Host.UI.SupportsVirtualTerminal) { $vt = $true }
    } catch { }
    if (-not $vt -and $env:WT_SESSION) { $vt = $true }
    if (-not $vt -and $env:TERM_PROGRAM) { $vt = $true }
    if (-not $vt -and $env:ConEmuANSI -eq 'ON') { $vt = $true }
    $script:ShortPs1UseColor = (-not $noColor) -and $vt
    $script:ShortPs1UseHyperlinks = $script:ShortPs1UseColor -and ($env:SHORTPS1_NO_HYPERLINKS -ne '1')
}

function Get-ShortPs1Esc { return [string][char]0x1B }

function Format-ShortPs1FileUri {
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

function Format-ShortPs1Osc8 {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Text
    )
    Initialize-ShortPs1Host
    if (-not $script:ShortPs1UseHyperlinks) { return $Text }
    $e = Get-ShortPs1Esc
    $bel = [char]7
    return ($e + ']8;;' + $Uri + $bel + $Text + $e + ']8;;' + $bel)
}

function Format-ShortPs1PathLink {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Display
    )
    Initialize-ShortPs1Host
    $resolved = $Path
    try { $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path } catch { }
    if (-not $Display) { $Display = $resolved }
    $uri = Format-ShortPs1FileUri $resolved
    return (Format-ShortPs1Osc8 -Uri $uri -Text $Display)
}

function Format-ShortPs1UrlLink {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$Display
    )
    Initialize-ShortPs1Host
    if (-not $Display) { $Display = $Url }
    if (-not $script:ShortPs1UseHyperlinks) { return $Display }
    $e = Get-ShortPs1Esc
    $bel = [char]7
    return ($e + ']8;;' + $Url + $bel + $Display + $e + ']8;;' + $bel)
}

function Get-ShortPs1ItemIcon {
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

function Write-ShortPs1Msg {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Ok', 'Warn', 'Err', 'Muted', 'Accent')][string]$Level = 'Info'
    )
    Initialize-ShortPs1Host
    if (-not $script:ShortPs1UseColor) {
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

function Get-ShortPs1DfColor {
    param([double]$PctUsed)
    Initialize-ShortPs1Host
    if (-not $script:ShortPs1UseColor) { return $null }
    if ($PctUsed -ge 95) { return 'Red' }
    if ($PctUsed -ge 85) { return 'Yellow' }
    if ($PctUsed -ge 70) { return 'DarkYellow' }
    return 'Green'
}

function Get-ShortPs1DuColor {
    param([double]$MiB)
    Initialize-ShortPs1Host
    if (-not $script:ShortPs1UseColor) { return $null }
    if ($MiB -ge 1024) { return 'Red' }
    if ($MiB -ge 256) { return 'Yellow' }
    return 'Cyan'
}

function Write-ShortPs1PathLine {
    param(
        [Parameter(Mandatory)][string]$FullPath,
        [string]$Prefix = ''
    )
    $link = Format-ShortPs1PathLink -Path $FullPath -Display $FullPath
    try {
        $item = Get-Item -LiteralPath $FullPath -Force -ErrorAction Stop
        $ic = Get-ShortPs1ItemIcon $item
        Write-Host ($Prefix + $ic + ' ' + $link)
    } catch {
        Write-Host ($Prefix + "`u{1F4C4} " + $link)
    }
}
