# Segment-driven prompt for PowerShell 7+ (dope shell; TOML config). Follows Toasty layout for
# [prompt] / [colors] so the same config.toml can drive zsh and PowerShell.
# Dot-source after install:  . (Join-Path $env:USERPROFILE 'psbin\ShortPs1Prompt.ps1')
# Config (first match): -ConfigPath, DOPE_SHELL_PROMPT_CONFIG or SHORTPS1_PROMPT_CONFIG,
#   DOPE_SHELL_CONFIG_DIR\config.toml (else %USERPROFILE%\.config\dopeshell\config.toml),
#   TOASTY_CONFIG_DIR\config.toml (else %USERPROFILE%\.config\toasty\config.toml),
#   prompt.config.toml next to this script (e.g. psbin), else prompt.config.default.toml next to this script.
# RGB env overrides (first wins per key): DOPE_SHELL_C_* then TOASTY_C_* (use DOPE_SHELL_C_* for cross-platform).
# Disable: $env:SHORTPS1_NO_DOPE_PROMPT = '1' before dot-sourcing.

param(
  [string]$ConfigPath = ''
)

if ($env:SHORTPS1_NO_DOPE_PROMPT -eq '1') { return }

$ErrorActionPreference = 'Stop'

$script:ShortPs1PromptVt = $false
function Initialize-ShortPs1PromptVt {
  if ($script:ShortPs1PromptVt) { return }
  $script:ShortPs1PromptVt = $true
  $noColor = $env:NO_COLOR -or ($env:SHORTPS1_NO_COLOR -eq '1')
  $vt = $false
  try { if ($Host.UI.SupportsVirtualTerminal) { $vt = $true } } catch { }
  if (-not $vt -and $env:WT_SESSION) { $vt = $true }
  if (-not $vt -and $env:TERM_PROGRAM) { $vt = $true }
  if (-not $vt -and $env:ConEmuANSI -eq 'ON') { $vt = $true }
  $script:ShortPs1PromptUseColor = (-not $noColor) -and $vt
}

function Get-ShortPs1PtEsc { return [string][char]0x1B }

function Read-ShortPs1PtToml {
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

function Get-ShortPs1SchemeRgb {
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

function Get-ShortPs1PtPalette {
  param([hashtable]$Toml)
  $scheme = if ($Toml['colors.scheme']) { $Toml['colors.scheme'] } else { 'default' }
  $p = Get-ShortPs1SchemeRgb $scheme
  foreach ($key in @('blue', 'violet', 'ok', 'err', 'warn', 'white', 'dark', 'accent', 'ssh', 'venv')) {
    $k = "colors.$key"
    if ($Toml.ContainsKey($k) -and $Toml[$k]) { $p[(Get-Culture).TextInfo.ToTitleCase($key)] = $Toml[$k] }
  }
  $pairs = @(
    @{ Key = 'Blue'; Dope = 'DOPE_SHELL_C_BLUE'; Pt = 'TOASTY_C_BLUE' },
    @{ Key = 'Violet'; Dope = 'DOPE_SHELL_C_VIOLET'; Pt = 'TOASTY_C_VIOLET' },
    @{ Key = 'Ok'; Dope = 'DOPE_SHELL_C_OK'; Pt = 'TOASTY_C_OK' },
    @{ Key = 'Err'; Dope = 'DOPE_SHELL_C_ERR'; Pt = 'TOASTY_C_ERR' },
    @{ Key = 'Warn'; Dope = 'DOPE_SHELL_C_WARN'; Pt = 'TOASTY_C_WARN' },
    @{ Key = 'White'; Dope = 'DOPE_SHELL_C_WHITE'; Pt = 'TOASTY_C_WHITE' },
    @{ Key = 'Dark'; Dope = 'DOPE_SHELL_C_DARK'; Pt = 'TOASTY_C_DARK' },
    @{ Key = 'Accent'; Dope = 'DOPE_SHELL_C_ACCENT'; Pt = 'TOASTY_C_ACCENT' },
    @{ Key = 'Ssh'; Dope = 'DOPE_SHELL_C_SSH'; Pt = 'TOASTY_C_SSH' },
    @{ Key = 'Venv'; Dope = 'DOPE_SHELL_C_VENV'; Pt = 'TOASTY_C_VENV' }
  )
  foreach ($pair in $pairs) {
    $ev = $null
    foreach ($n in @($pair.Dope, $pair.Pt)) {
      $ev = [Environment]::GetEnvironmentVariable($n, 'Process')
      if (-not $ev) { $ev = [Environment]::GetEnvironmentVariable($n, 'User') }
      if (-not $ev) { $ev = [Environment]::GetEnvironmentVariable($n, 'Machine') }
      if ($ev) { break }
    }
    if ($ev) { $p[$pair.Key] = $ev }
  }
  $p
}

function Resolve-DopeShellPromptConfigPath {
  param([string]$Explicit)
  if ($Explicit -and (Test-Path -LiteralPath $Explicit)) { return (Resolve-Path -LiteralPath $Explicit).Path }
  foreach ($evName in @('DOPE_SHELL_PROMPT_CONFIG', 'SHORTPS1_PROMPT_CONFIG')) {
    $c = [Environment]::GetEnvironmentVariable($evName, 'Process')
    if (-not $c) { $c = [Environment]::GetEnvironmentVariable($evName, 'User') }
    if ($c -and (Test-Path -LiteralPath $c)) { return (Resolve-Path -LiteralPath $c).Path }
  }
  $dir = if ($env:DOPE_SHELL_CONFIG_DIR) { $env:DOPE_SHELL_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.config\dopeshell' }
  $p = Join-Path $dir 'config.toml'
  if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
  $ptDir = if ($env:TOASTY_CONFIG_DIR) { $env:TOASTY_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.config\toasty' }
  $ptCfg = Join-Path $ptDir 'config.toml'
  if (Test-Path -LiteralPath $ptCfg) { return (Resolve-Path -LiteralPath $ptCfg).Path }
  $here = $PSScriptRoot
  if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
  if ($here) {
    $sidecar = Join-Path $here 'prompt.config.toml'
    if (Test-Path -LiteralPath $sidecar) { return (Resolve-Path -LiteralPath $sidecar).Path }
    $defaultToml = Join-Path $here 'prompt.config.default.toml'
    if (Test-Path -LiteralPath $defaultToml) { return (Resolve-Path -LiteralPath $defaultToml).Path }
  }
  return $null
}

$script:ShortPs1PtToml = Read-ShortPs1PtToml (Resolve-DopeShellPromptConfigPath $ConfigPath)
$script:ShortPs1PtPalette = Get-ShortPs1PtPalette $script:ShortPs1PtToml

$script:PtRoundL = [string][char]0xE0B6
$script:PtRoundR = [string][char]0xE0B4
$script:PtIconUser = [string][char]0xF007
$script:PtIconFolder = [string][char]0xF07B
$script:PtIconHome = [string][char]0xF015
$script:PtIconOk = [string][char]0xF00C
$script:PtIconWarn = [string][char]0xF071
$script:PtIconErr = [string][char]0xF00D
$script:PtIconGit = [string][char]0xE0A0
$script:PtIconPython = [string][char]0xE73C
$script:PtIconGear = [string][char]0xF013
$script:PtIconSsh = [string][char]0xF0C2
$script:PtIconClock = [string][char]0xF017

function Get-ShortPs1PtCfg {
  param([string]$Key, [string]$Default)
  $t = $script:ShortPs1PtToml
  if ($t.ContainsKey($Key) -and $null -ne $t[$Key] -and $t[$Key] -ne '') { return [string]$t[$Key] }
  return $Default
}

function New-ShortPs1PtSeg {
  param([string]$Bg, [string]$Fg, [string]$Text, [string]$Icon = '', [bool]$ColoredIcons = $false)
  $e = Get-ShortPs1PtEsc
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

function Get-ShortPs1PtGitInfo {
  param([string]$NeedGit)
  $script:_ptGitBranch = ''
  $script:_ptGitDirty = $false
  if ($NeedGit -notmatch 'git') { return }
  $savedExit = $global:LASTEXITCODE
  try {
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (-not $branch) { return }
    $script:_ptGitBranch = $branch.Trim()
    git diff --quiet HEAD 2>$null
    $script:_ptGitDirty = ($global:LASTEXITCODE -ne 0)
  } catch { }
  finally {
    $global:LASTEXITCODE = $savedExit
  }
}

function Get-ShortPs1PtLastExit {
  $native = $global:LASTEXITCODE
  $failed = -not $?
  if ($failed -and ($null -eq $native -or $native -eq 0)) { return 1 }
  if ($null -ne $native) { return [int]$native }
  return 0
}

function Get-ShortPs1PtCmdDurationSec {
  try {
    $h = Get-History -Count 1 -ErrorAction SilentlyContinue
    if (-not $h) { return 0 }
    $end = $h.EndExecutionTime
    $start = $h.StartExecutionTime
    if (-not $end -or -not $start) { return 0 }
    return [int][math]::Floor(($end - $start).TotalSeconds)
  } catch { return 0 }
}

function Invoke-ShortPs1PtSeg {
  param([string]$Name, [hashtable]$P, [hashtable]$Cfg)

  $iconUser = (Get-ShortPs1PtCfg 'prompt.icon_user' 'true') -eq 'true'
  $iconPath = (Get-ShortPs1PtCfg 'prompt.icon_path' 'true') -eq 'true'
  $coloredIcons = (Get-ShortPs1PtCfg 'prompt.colored_icons' 'false') -eq 'true'

  switch ($Name.Trim()) {
    'user' {
      $icon = if ($iconUser) { $script:PtIconUser } else { '' }
      $color = $P.Blue
      $label = $env:USERNAME
      if ($env:SSH_CONNECTION -or $env:SSH_TTY) {
        $color = $P.Ssh
        $hn = $env:COMPUTERNAME
        $label = "${env:USERNAME}@${hn}"
      }
      return (New-ShortPs1PtSeg $color $P.Dark $label $icon $coloredIcons)
    }
    'ssh' {
      if (-not $env:SSH_CONNECTION -and -not $env:SSH_TTY) { return $null }
      return (New-ShortPs1PtSeg $P.Ssh $P.Dark 'ssh' $script:PtIconSsh $coloredIcons)
    }
    'path' {
      $icon = ''
      if ($iconPath) {
        $icon = if ($PWD.Path -eq $HOME) { $script:PtIconHome } else { $script:PtIconFolder }
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
      return (New-ShortPs1PtSeg $P.Violet $P.Dark $pathLabel $icon $coloredIcons)
    }
    'git' {
      if (-not $script:_ptGitBranch) { return $null }
      $label = $script:_ptGitBranch
      $color = $P.Blue
      if ($script:_ptGitDirty) { $label += '*'; $color = $P.Warn }
      return (New-ShortPs1PtSeg $color $P.Dark $label $script:PtIconGit $coloredIcons)
    }
    'venv' {
      if (-not $env:VIRTUAL_ENV) { return $null }
      $name = Split-Path -Leaf $env:VIRTUAL_ENV
      return (New-ShortPs1PtSeg $P.Venv $P.Dark $name $script:PtIconPython $coloredIcons)
    }
    'jobs' {
      $n = @(Get-Job -State Running -ErrorAction SilentlyContinue).Count
      if ($n -le 0) { return $null }
      return (New-ShortPs1PtSeg $P.Warn $P.Dark "$n" $script:PtIconGear $coloredIcons)
    }
    'status' {
      $code = Get-ShortPs1PtLastExit
      if ($code -eq 0) { return (New-ShortPs1PtSeg $P.Ok $P.Dark '' $script:PtIconOk $coloredIcons) }
      if ($code -in 130, 131, 148) { return (New-ShortPs1PtSeg $P.Warn $P.Dark '' $script:PtIconWarn $coloredIcons) }
      return (New-ShortPs1PtSeg $P.Err $P.White "$($script:PtIconErr) $code" '' $coloredIcons)
    }
    'duration' {
      $d = Get-ShortPs1PtCmdDurationSec
      $th = [int](Get-ShortPs1PtCfg 'prompt.duration_threshold' '3')
      if ($d -lt $th) { return $null }
      $label = if ($d -ge 3600) { "$([math]::Floor($d / 3600))h$([math]::Floor(($d % 3600) / 60))m" }
      elseif ($d -ge 60) { "$([math]::Floor($d / 60))m$($d % 60)s" }
      else { "${d}s" }
      return (New-ShortPs1PtSeg $P.Accent $P.Dark $label $script:PtIconClock $coloredIcons)
    }
    'time' {
      $t = (Get-Date).ToString('HH:mm:ss')
      return (New-ShortPs1PtSeg $P.Violet $P.Dark $t '' $false)
    }
    default { return $null }
  }
}

function Format-ShortPs1PtRender {
  param(
    [System.Collections.Generic.List[object]]$Segs,
    [string]$Theme
  )
  if (-not $Segs -or $Segs.Count -eq 0) { return '' }
  $e = Get-ShortPs1PtEsc
  $n = $Segs.Count
  $sb = [System.Text.StringBuilder]::new()
  $reset = "${e}[0m"

  switch -Regex ($Theme) {
    '^pills-merged$' {
      for ($i = 0; $i -lt $n; $i++) {
        $s = $Segs[$i]
        $bg = $s.Bg; $fg = $s.Fg; $tx = $s.Display
        if ($i -eq 0) { [void]$sb.Append("${reset}${e}[38;2;${bg}m$($script:PtRoundL)") }
        [void]$sb.Append("${reset}${e}[48;2;${bg}m${e}[38;2;${fg}m")
        if ($i -gt 0) { [void]$sb.Append(' ') }
        [void]$sb.Append($tx)
        if ($i -lt $n - 1) { [void]$sb.Append(' ') }
        if ($i -eq $n - 1) { [void]$sb.Append("${reset}${e}[38;2;${bg}m$($script:PtRoundR)${reset}") }
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
        [void]$sb.Append("${reset}${e}[38;2;${bg}m$($script:PtRoundL)${e}[48;2;${bg}m${e}[38;2;${fg}m${tx}${reset}${e}[38;2;${bg}m$($script:PtRoundR)${reset}")
      }
    }
  }
  return $sb.ToString()
}

function global:prompt {
  Initialize-ShortPs1PromptVt
  $P = $script:ShortPs1PtPalette
  $leftCfg = Get-ShortPs1PtCfg 'prompt.left' 'user,path,git,venv,jobs'
  $rightCfg = Get-ShortPs1PtCfg 'prompt.right' 'status,duration,time'
  $theme = Get-ShortPs1PtCfg 'prompt.style' 'pills-merged'
  Get-ShortPs1PtGitInfo "$leftCfg$rightCfg"

  $leftList = [System.Collections.Generic.List[object]]::new()
  foreach ($seg in ($leftCfg -split ',')) {
    $o = Invoke-ShortPs1PtSeg -Name $seg.Trim() -P $P -Cfg @{}
    if ($null -ne $o) { $leftList.Add($o) }
  }
  $rightList = [System.Collections.Generic.List[object]]::new()
  foreach ($seg in ($rightCfg -split ',')) {
    $o = Invoke-ShortPs1PtSeg -Name $seg.Trim() -P $P -Cfg @{}
    if ($null -ne $o) { $rightList.Add($o) }
  }

  if (-not $script:ShortPs1PromptUseColor) {
    $plainL = ($leftList | ForEach-Object { $_.Display -replace "`e\[[0-9;]*m", '' }) -join ' '
    $plainR = ''
    if ((Get-ShortPs1PtCfg 'prompt.show_rprompt' 'true') -eq 'true' -and $rightList.Count -gt 0) {
      $plainR = '  ' + (($rightList | ForEach-Object { $_.Display -replace "`e\[[0-9;]*m", '' }) -join ' ')
    }
    return "$plainL$plainR> "
  }

  $L = Format-ShortPs1PtRender -Segs $leftList -Theme $theme
  $showR = (Get-ShortPs1PtCfg 'prompt.show_rprompt' 'true') -eq 'true'
  if ($showR -and $rightList.Count -gt 0) {
    $R = Format-ShortPs1PtRender -Segs $rightList -Theme $theme
    $dim = "$(Get-ShortPs1PtEsc)[38;2;100;100;120m · $(Get-ShortPs1PtEsc)[0m"
    return "$L$dim$R "
  }
  return "$L "
}
