# Segment-driven prompt for PowerShell 7+ (TOML config).
# The same config.toml [prompt] / [colors] sections work for both zsh (Photon Toaster) and PowerShell.
# Dot-source via init.ps1, or directly:  . ~/.config/toasty/shell/prompt.ps1
# Config (first match): -ConfigPath, TOASTY_CONFIG_DIR\config.toml (else ~/.config/toasty/config.toml),
#   config.toml.default next to this script's parent dir.
# RGB env overrides: TOASTY_C_* (e.g. TOASTY_C_BLUE = "110;155;245").
# Disable: $env:TOASTY_NO_PROMPT = '1' before dot-sourcing.

param(
  [string]$ConfigPath = ''
)

if ($env:TOASTY_NO_PROMPT -eq '1') { return }

$ErrorActionPreference = 'Stop'

$script:ToastyPromptVt = $false
function Initialize-ToastyPromptVt {
  if ($script:ToastyPromptVt) { return }
  $script:ToastyPromptVt = $true
  $noColor = $env:NO_COLOR -or ($env:TOASTY_NO_COLOR -eq '1')
  $vt = $false
  try { if ($Host.UI.SupportsVirtualTerminal) { $vt = $true } } catch { }
  if (-not $vt -and $env:WT_SESSION) { $vt = $true }
  if (-not $vt -and $env:TERM_PROGRAM) { $vt = $true }
  if (-not $vt -and $env:ConEmuANSI -eq 'ON') { $vt = $true }
  $script:ToastyPromptUseColor = (-not $noColor) -and $vt
}

function Get-ToastyPromptEsc { return [string][char]0x1B }

function Read-ToastyToml {
  param([string]$Path)
  $cfg = @{}
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $cfg }
  $section = ''
  Get-Content -LiteralPath $Path -Encoding utf8 | ForEach-Object {
    $raw = $_
    $line = $raw.Trim()
    if ($line -match '^\s*#' -or $line -eq '') { return }
    if ($line -match '^\[([^\]]+)\]\s*$') {
      $section = $Matches[1].Trim()
      return
    }
    if ($line -match '^([^=]+)=(.*)$') {
      $k = $Matches[1].Trim()
      $v = $Matches[2].Trim()
      if ($v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1, $v.Length - 2) }
      $hash = $v.IndexOf('#')
      if ($hash -ge 0) { $v = $v.Substring(0, $hash).TrimEnd() }
      $full = if ($section) { "$section.$k" } else { $k }
      $cfg[$full] = $v
    }
  }
  $cfg
}

function Get-ToastySchemeRgb {
  param([string]$Scheme)
  $builtinDefault = @{ Blue = '110;155;245'; Violet = '150;125;255'; Ok = '80;250;120'; Err = '255;90;90'; Warn = '255;220;60'; White = '245;245;255'; Dark = '24;28;40'; Accent = '255;100;255'; Ssh = '255;165;0'; Venv = '60;180;75' }
  switch ($Scheme.ToLowerInvariant()) {
    'default' { return $builtinDefault.Clone() }
    'catppuccin' { return @{ Blue = '137;180;250'; Violet = '203;166;247'; Ok = '166;227;161'; Err = '243;139;168'; Warn = '249;226;175'; White = '205;214;244'; Dark = '30;30;46'; Accent = '245;194;231'; Ssh = '250;179;135'; Venv = '148;226;213' } }
    'pastels' { return @{ Blue = '162;196;255'; Violet = '200;182;255'; Ok = '176;228;175'; Err = '255;179;186'; Warn = '255;234;167'; White = '240;240;248'; Dark = '40;42;54'; Accent = '255;182;225'; Ssh = '255;204;153'; Venv = '167;230;210' } }
    'solarized' { return @{ Blue = '38;139;210'; Violet = '108;113;196'; Ok = '133;153;0'; Err = '220;50;47'; Warn = '181;137;0'; White = '238;232;213'; Dark = '0;43;54'; Accent = '211;54;130'; Ssh = '203;75;22'; Venv = '42;161;152' } }
    'dracula' { return @{ Blue = '139;233;253'; Violet = '189;147;249'; Ok = '80;250;123'; Err = '255;85;85'; Warn = '241;250;140'; White = '248;248;242'; Dark = '40;42;54'; Accent = '255;121;198'; Ssh = '255;184;108'; Venv = '139;233;253' } }
    'astra' { return @{ Blue = '120;170;255'; Violet = '190;130;255'; Ok = '100;220;140'; Err = '255;80;100'; Warn = '255;190;70'; White = '215;220;240'; Dark = '12;12;24'; Accent = '220;100;255'; Ssh = '255;160;90'; Venv = '90;210;180' } }
    'cracktro' { return @{ Blue = '0;255;255'; Violet = '255;0;128'; Ok = '0;255;0'; Err = '255;0;0'; Warn = '255;255;0'; White = '255;255;255'; Dark = '0;0;0'; Accent = '255;0;255'; Ssh = '255;128;0'; Venv = '0;255;128' } }
    'terminal' { return @{ Blue = '0;120;255'; Violet = '160;32;240'; Ok = '0;200;0'; Err = '255;0;0'; Warn = '255;255;0'; White = '255;255;255'; Dark = '0;0;0'; Accent = '255;0;255'; Ssh = '255;165;0'; Venv = '0;128;0' } }
    default { return $builtinDefault.Clone() }
  }
}

function Get-ToastyPalette {
  param([hashtable]$Toml)
  $scheme = if ($Toml['colors.scheme']) { $Toml['colors.scheme'] } else { 'default' }
  $p = Get-ToastySchemeRgb $scheme
  foreach ($key in @('blue', 'violet', 'ok', 'err', 'warn', 'white', 'dark', 'accent', 'ssh', 'venv')) {
    $k = "colors.$key"
    if ($Toml.ContainsKey($k) -and $Toml[$k]) { $p[(Get-Culture).TextInfo.ToTitleCase($key)] = $Toml[$k] }
  }
  foreach ($key in @('Blue', 'Violet', 'Ok', 'Err', 'Warn', 'White', 'Dark', 'Accent', 'Ssh', 'Venv')) {
    $evName = "TOASTY_C_$($key.ToUpperInvariant())"
    $ev = [Environment]::GetEnvironmentVariable($evName, 'Process')
    if (-not $ev) { $ev = [Environment]::GetEnvironmentVariable($evName, 'User') }
    if (-not $ev) { $ev = [Environment]::GetEnvironmentVariable($evName, 'Machine') }
    if ($ev) { $p[$key] = $ev }
  }
  $p
}

function Resolve-ToastyConfigPath {
  param([string]$Explicit)
  if ($Explicit -and (Test-Path -LiteralPath $Explicit)) { return (Resolve-Path -LiteralPath $Explicit).Path }
  $dir = if ($env:TOASTY_CONFIG_DIR) { $env:TOASTY_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.config\toasty' }
  $p = Join-Path $dir 'config.toml'
  if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
  $here = $PSScriptRoot
  if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
  if ($here) {
    $parentDir = Split-Path -Parent $here
    if ($parentDir) {
      $defaultToml = Join-Path $parentDir 'config.toml.default'
      if (Test-Path -LiteralPath $defaultToml) { return (Resolve-Path -LiteralPath $defaultToml).Path }
    }
  }
  return $null
}

$script:ToastyToml = Read-ToastyToml (Resolve-ToastyConfigPath $ConfigPath)
$script:ToastyPalette = Get-ToastyPalette $script:ToastyToml

$script:ToastyRoundL = [string][char]0xE0B6
$script:ToastyRoundR = [string][char]0xE0B4
$script:ToastyIconUser = [string][char]0xF007
$script:ToastyIconFolder = [string][char]0xF07B
$script:ToastyIconHome = [string][char]0xF015
$script:ToastyIconOk = [string][char]0xF00C
$script:ToastyIconWarn = [string][char]0xF071
$script:ToastyIconErr = [string][char]0xF00D
$script:ToastyIconGit = [string][char]0xE0A0
$script:ToastyIconPython = [string][char]0xE73C
$script:ToastyIconGear = [string][char]0xF013
$script:ToastyIconSsh = [string][char]0xF0C2
$script:ToastyIconClock = [string][char]0xF017

function Get-ToastyCfg {
  param([string]$Key, [string]$Default)
  $t = $script:ToastyToml
  if ($t.ContainsKey($Key) -and $null -ne $t[$Key] -and $t[$Key] -ne '') { return [string]$t[$Key] }
  return $Default
}

function New-ToastySeg {
  param([string]$Bg, [string]$Fg, [string]$Text, [string]$Icon = '', [bool]$ColoredIcons = $false)
  $e = Get-ToastyPromptEsc
  $display = $Text -replace '%', '%%'
  if ($ColoredIcons -and $Icon) {
    $parts = $Bg -split ';'
    $r1 = [int]$parts[0]; $g1 = [int]$parts[1]; $b1 = [int]$parts[2]
    $iconFg = "$((($r1 + 128) % 256));$((($g1 + 128) % 256));$((($b1 + 128) % 256))"
    if ($display) {
      $display = "${e}[38;2;${iconFg}m${Icon}${e}[38;2;${Fg}m ${display}"
    } else {
      $display = "${e}[38;2;${iconFg}m${Icon}${e}[38;2;${Fg}m"
    }
  } elseif ($Icon -and $display) {
    $display = "${Icon} ${display}"
  } elseif ($Icon) {
    $display = $Icon
  }
  return [pscustomobject]@{ Bg = $Bg; Fg = $Fg; Display = $display }
}

function Get-ToastyGitInfo {
  param([string]$NeedGit)
  $script:_toastyGitBranch = ''
  $script:_toastyGitDirty = $false
  if ($NeedGit -notmatch 'git') { return }
  $savedExit = $global:LASTEXITCODE
  try {
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (-not $branch) { return }
    $script:_toastyGitBranch = $branch.Trim()
    git diff --quiet HEAD 2>$null
    $script:_toastyGitDirty = ($global:LASTEXITCODE -ne 0)
  } catch { }
  finally {
    $global:LASTEXITCODE = $savedExit
  }
}

function Get-ToastyLastExit {
  $native = $global:LASTEXITCODE
  $failed = -not $?
  if ($failed -and ($null -eq $native -or $native -eq 0)) { return 1 }
  if ($null -ne $native) { return [int]$native }
  return 0
}

function Get-ToastyCmdDuration {
  try {
    $h = Get-History -Count 1 -ErrorAction SilentlyContinue
    if (-not $h) { return 0 }
    $end = $h.EndExecutionTime
    $start = $h.StartExecutionTime
    if (-not $end -or -not $start) { return 0 }
    return [int][math]::Floor(($end - $start).TotalSeconds)
  } catch { return 0 }
}

function Invoke-ToastySeg {
  param([string]$Name, [hashtable]$P, [hashtable]$Cfg)

  $iconUser = (Get-ToastyCfg 'prompt.icon_user' 'true') -eq 'true'
  $iconPath = (Get-ToastyCfg 'prompt.icon_path' 'true') -eq 'true'
  $coloredIcons = (Get-ToastyCfg 'prompt.colored_icons' 'false') -eq 'true'

  switch ($Name.Trim()) {
    'user' {
      $icon = if ($iconUser) { $script:ToastyIconUser } else { '' }
      $color = $P.Blue
      $label = $env:USERNAME
      if ($env:SSH_CONNECTION -or $env:SSH_TTY) {
        $color = $P.Ssh
        $hn = $env:COMPUTERNAME
        $label = "${env:USERNAME}@${hn}"
      }
      return (New-ToastySeg $color $P.Dark $label $icon $coloredIcons)
    }
    'ssh' {
      if (-not $env:SSH_CONNECTION -and -not $env:SSH_TTY) { return $null }
      return (New-ToastySeg $P.Ssh $P.Dark 'ssh' $script:ToastyIconSsh $coloredIcons)
    }
    'path' {
      $icon = ''
      if ($iconPath) {
        $icon = if ($PWD.Path -eq $HOME) { $script:ToastyIconHome } else { $script:ToastyIconFolder }
      }
      $collapsed = $PWD.Path
      if ($HOME -and $collapsed.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) {
        $collapsed = '~' + $collapsed.Substring($HOME.Length)
      }
      $pathLabel = $collapsed
      if ($collapsed -ne '~') {
        $parts = [regex]::Split($collapsed, '[/\\]+') | Where-Object { $_ }
        if ($parts.Count -gt 3) {
          if ($collapsed.StartsWith('~')) { $pathLabel = "~/$($parts[-2])/$($parts[-1])" }
          else { $pathLabel = "$($parts[-2])/$($parts[-1])" }
        }
      }
      return (New-ToastySeg $P.Violet $P.Dark $pathLabel $icon $coloredIcons)
    }
    'git' {
      if (-not $script:_toastyGitBranch) { return $null }
      $label = $script:_toastyGitBranch
      $color = $P.Blue
      if ($script:_toastyGitDirty) { $label += '*'; $color = $P.Warn }
      return (New-ToastySeg $color $P.Dark $label $script:ToastyIconGit $coloredIcons)
    }
    'venv' {
      if (-not $env:VIRTUAL_ENV) { return $null }
      $name = Split-Path -Leaf $env:VIRTUAL_ENV
      return (New-ToastySeg $P.Venv $P.Dark $name $script:ToastyIconPython $coloredIcons)
    }
    'jobs' {
      $n = @(Get-Job -State Running -ErrorAction SilentlyContinue).Count
      if ($n -le 0) { return $null }
      return (New-ToastySeg $P.Warn $P.Dark "$n" $script:ToastyIconGear $coloredIcons)
    }
    'status' {
      $code = Get-ToastyLastExit
      if ($code -eq 0) { return (New-ToastySeg $P.Ok $P.Dark '' $script:ToastyIconOk $coloredIcons) }
      if ($code -in 130, 131, 148) { return (New-ToastySeg $P.Warn $P.Dark '' $script:ToastyIconWarn $coloredIcons) }
      return (New-ToastySeg $P.Err $P.White "$($script:ToastyIconErr) $code" '' $coloredIcons)
    }
    'duration' {
      $d = Get-ToastyCmdDuration
      $th = [int](Get-ToastyCfg 'prompt.duration_threshold' '3')
      if ($d -lt $th) { return $null }
      $label = if ($d -ge 3600) { "$([math]::Floor($d / 3600))h$([math]::Floor(($d % 3600) / 60))m" }
      elseif ($d -ge 60) { "$([math]::Floor($d / 60))m$($d % 60)s" }
      else { "${d}s" }
      return (New-ToastySeg $P.Accent $P.Dark $label $script:ToastyIconClock $coloredIcons)
    }
    'time' {
      $t = (Get-Date).ToString('HH:mm:ss')
      return (New-ToastySeg $P.Violet $P.Dark $t '' $false)
    }
    default { return $null }
  }
}

function Format-ToastyRender {
  param(
    [System.Collections.Generic.List[object]]$Segs,
    [string]$Theme
  )
  if (-not $Segs -or $Segs.Count -eq 0) { return '' }
  $e = Get-ToastyPromptEsc
  $n = $Segs.Count
  $sb = [System.Text.StringBuilder]::new()
  $reset = "${e}[0m"

  switch -Regex ($Theme) {
    '^pills-merged$' {
      for ($i = 0; $i -lt $n; $i++) {
        $s = $Segs[$i]
        $bg = $s.Bg; $fg = $s.Fg; $tx = $s.Display
        if ($i -eq 0) { [void]$sb.Append("${reset}${e}[38;2;${bg}m$($script:ToastyRoundL)") }
        [void]$sb.Append("${reset}${e}[48;2;${bg}m${e}[38;2;${fg}m")
        if ($i -gt 0) { [void]$sb.Append(' ') }
        [void]$sb.Append($tx)
        if ($i -lt $n - 1) { [void]$sb.Append(' ') }
        if ($i -eq $n - 1) { [void]$sb.Append("${reset}${e}[38;2;${bg}m$($script:ToastyRoundR)${reset}") }
      }
    }
    '^plain$' {
      for ($i = 0; $i -lt $n; $i++) {
        $s = $Segs[$i]
        if ($i -gt 0) { [void]$sb.Append(' ') }
        [void]$sb.Append("${reset}${e}[48;2;$( $s.Bg )m${e}[38;2;$( $s.Fg )m$( $s.Display )${reset}")
      }
    }
    '^minimal$' {
      for ($i = 0; $i -lt $n; $i++) {
        $s = $Segs[$i]
        [void]$sb.Append("${reset}${e}[38;2;$( $s.Bg )m$( $s.Display )${reset} ")
      }
    }
    default {
      for ($i = 0; $i -lt $n; $i++) {
        $s = $Segs[$i]
        $bg = $s.Bg; $fg = $s.Fg; $tx = $s.Display
        [void]$sb.Append("${reset}${e}[38;2;${bg}m$($script:ToastyRoundL)${e}[48;2;${bg}m${e}[38;2;${fg}m${tx}${reset}${e}[38;2;${bg}m$($script:ToastyRoundR)${reset}")
      }
    }
  }
  return $sb.ToString()
}

function _ToastyStripAnsi([string]$s) {
  [regex]::Replace($s, '\x1B\[[0-9;]*m', '')
}

function global:prompt {
  Initialize-ToastyPromptVt
  $e = Get-ToastyPromptEsc
  $P = $script:ToastyPalette
  $leftCfg = Get-ToastyCfg 'prompt.left' 'user,path,git,venv,jobs'
  $rightCfg = Get-ToastyCfg 'prompt.right' 'status,duration,time'
  $theme = Get-ToastyCfg 'prompt.style' 'pills-merged'
  Get-ToastyGitInfo "$leftCfg$rightCfg"

  $leftList = [System.Collections.Generic.List[object]]::new()
  foreach ($seg in ($leftCfg -split ',')) {
    $o = Invoke-ToastySeg -Name $seg.Trim() -P $P -Cfg @{}
    if ($null -ne $o) { $leftList.Add($o) }
  }
  $rightList = [System.Collections.Generic.List[object]]::new()
  foreach ($seg in ($rightCfg -split ',')) {
    $o = Invoke-ToastySeg -Name $seg.Trim() -P $P -Cfg @{}
    if ($null -ne $o) { $rightList.Add($o) }
  }

  $showR = (Get-ToastyCfg 'prompt.show_rprompt' 'true') -eq 'true'

  if (-not $script:ToastyPromptUseColor) {
    $plainL = ($leftList | ForEach-Object { _ToastyStripAnsi $_.Display }) -join ' '
    if ($showR -and $rightList.Count -gt 0) {
      $plainR = ($rightList | ForEach-Object { _ToastyStripAnsi $_.Display }) -join ' '
      $cols = 80
      try { $cols = $Host.UI.RawUI.WindowSize.Width } catch { }
      $rPos = $cols - $plainR.Length
      if ($rPos -gt ($plainL.Length + 4)) {
        $lCol = $plainL.Length + 1
        Write-Host "${plainL}${e}[${rPos}G${plainR}${e}[${lCol}G" -NoNewline
      } else {
        Write-Host $plainL -NoNewline
      }
    } else {
      Write-Host $plainL -NoNewline
    }
    return '> '
  }

  $L = Format-ToastyRender -Segs $leftList -Theme $theme
  $lVisible = (_ToastyStripAnsi $L).Length
  if ($showR -and $rightList.Count -gt 0) {
    $R = Format-ToastyRender -Segs $rightList -Theme $theme
    $rVisible = (_ToastyStripAnsi $R).Length
    $cols = 80
    try { $cols = $Host.UI.RawUI.WindowSize.Width } catch { }
    $pos = $cols - $rVisible
    if ($pos -gt ($lVisible + 4)) {
      $lCol = $lVisible + 1
      Write-Host "${L}${e}[${pos}G${R}${e}[0m${e}[${lCol}G" -NoNewline
    } else {
      Write-Host "${L}${e}[0m" -NoNewline
    }
  } else {
    Write-Host "${L}${e}[0m" -NoNewline
  }
  return "${e}[38;2;$($P.Violet)m>${e}[0m "
}
