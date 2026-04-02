# PhotonToaster segment-driven prompt for PowerShell 7+.
# Uses PHOTONTOASTER_C_* env vars (set by shared/env.ps1) and $script:PTConfig from init.ps1.

if ($env:PHOTONTOASTER_NO_PROMPT -eq '1') { return }

$script:PTPromptVtInit = $false
function Initialize-PTPromptVt {
  if ($script:PTPromptVtInit) { return }
  $script:PTPromptVtInit = $true
  $noColor = $env:NO_COLOR -or ($env:PHOTONTOASTER_NO_COLOR -eq '1')
  $vt = $false
  try { if ($Host.UI.SupportsVirtualTerminal) { $vt = $true } } catch { }
  if (-not $vt -and $env:WT_SESSION) { $vt = $true }
  if (-not $vt -and $env:TERM_PROGRAM) { $vt = $true }
  if (-not $vt -and $env:ConEmuANSI -eq 'ON') { $vt = $true }
  $script:PTPromptUseColor = (-not $noColor) -and $vt
}

function _pt_esc { return [string][char]0x1B }

function _pt_cfg([string]$Key, [string]$Default) {
  if ($script:PTConfig -and $script:PTConfig.ContainsKey($Key) -and $null -ne $script:PTConfig[$Key] -and $script:PTConfig[$Key] -ne '') {
    return [string]$script:PTConfig[$Key]
  }
  return $Default
}

function _pt_palette {
  $p = @{}
  $map = @{
    Blue   = 'PHOTONTOASTER_C_BLUE';   Violet = 'PHOTONTOASTER_C_VIOLET'
    Ok     = 'PHOTONTOASTER_C_OK';     Err    = 'PHOTONTOASTER_C_ERR'
    Warn   = 'PHOTONTOASTER_C_WARN';   White  = 'PHOTONTOASTER_C_WHITE'
    Dark   = 'PHOTONTOASTER_C_DARK';   Accent = 'PHOTONTOASTER_C_ACCENT'
    Ssh    = 'PHOTONTOASTER_C_SSH';    Venv   = 'PHOTONTOASTER_C_VENV'
  }
  $defaults = @{
    Blue = '110;155;245'; Violet = '150;125;255'; Ok = '80;250;120'; Err = '255;90;90'
    Warn = '255;220;60';  White  = '245;245;255'; Dark = '24;28;40'; Accent = '255;100;255'
    Ssh  = '255;165;0';   Venv   = '60;180;75'
  }
  foreach ($k in $map.Keys) {
    $v = [Environment]::GetEnvironmentVariable($map[$k], 'Process')
    $p[$k] = if ($v) { $v } else { $defaults[$k] }
  }
  return $p
}

$script:PTPalette = _pt_palette

$script:PTRoundL    = [string][char]0xE0B6
$script:PTRoundR    = [string][char]0xE0B4
$script:PTIconUser   = [string][char]0xF007
$script:PTIconFolder = [string][char]0xF07B
$script:PTIconHome   = [string][char]0xF015
$script:PTIconOk     = [string][char]0xF00C
$script:PTIconWarn   = [string][char]0xF071
$script:PTIconErr    = [string][char]0xF00D
$script:PTIconGit    = [string][char]0xE0A0
$script:PTIconPython = [string][char]0xE73C
$script:PTIconGear   = [string][char]0xF013
$script:PTIconSsh    = [string][char]0xF0C2
$script:PTIconClock  = [string][char]0xF017

function New-PTSeg {
  param([string]$Bg, [string]$Fg, [string]$Text, [string]$Icon = '', [bool]$ColoredIcons = $false)
  $e = _pt_esc
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

function _pt_git_info {
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

function _pt_last_exit {
  $native = $global:LASTEXITCODE
  $failed = -not $?
  if ($failed -and ($null -eq $native -or $native -eq 0)) { return 1 }
  if ($null -ne $native) { return [int]$native }
  return 0
}

function _pt_cmd_duration {
  try {
    $h = Get-History -Count 1 -ErrorAction SilentlyContinue
    if (-not $h) { return 0 }
    $end = $h.EndExecutionTime
    $start = $h.StartExecutionTime
    if (-not $end -or -not $start) { return 0 }
    return [int][math]::Floor(($end - $start).TotalSeconds)
  } catch { return 0 }
}

function Invoke-PTSeg {
  param([string]$Name, [hashtable]$P)

  $iconUser = (_pt_cfg 'prompt.icon_user' 'true') -eq 'true'
  $iconPath = (_pt_cfg 'prompt.icon_path' 'true') -eq 'true'
  $coloredIcons = (_pt_cfg 'prompt.colored_icons' 'false') -eq 'true'

  switch ($Name.Trim()) {
    'user' {
      $icon = if ($iconUser) { $script:PTIconUser } else { '' }
      $color = $P.Blue
      $label = $env:USERNAME
      if ($env:SSH_CONNECTION -or $env:SSH_TTY) {
        $color = $P.Ssh
        $label = "${env:USERNAME}@${env:COMPUTERNAME}"
      }
      return (New-PTSeg $color $P.Dark $label $icon $coloredIcons)
    }
    'ssh' {
      if (-not $env:SSH_CONNECTION -and -not $env:SSH_TTY) { return $null }
      return (New-PTSeg $P.Ssh $P.Dark 'ssh' $script:PTIconSsh $coloredIcons)
    }
    'path' {
      $icon = ''
      if ($iconPath) {
        $icon = if ($PWD.Path -eq $HOME) { $script:PTIconHome } else { $script:PTIconFolder }
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
      return (New-PTSeg $P.Violet $P.Dark $pathLabel $icon $coloredIcons)
    }
    'git' {
      if (-not $script:_ptGitBranch) { return $null }
      $label = $script:_ptGitBranch
      $color = $P.Blue
      if ($script:_ptGitDirty) { $label += '*'; $color = $P.Warn }
      return (New-PTSeg $color $P.Dark $label $script:PTIconGit $coloredIcons)
    }
    'git-short' {
      if (-not $script:_ptGitBranch) { return $null }
      $label = $script:_ptGitBranch
      if ($label.Length -gt 16) { $label = $label.Substring(0, 14) + '..' }
      $color = $P.Blue
      if ($script:_ptGitDirty) { $label += '*'; $color = $P.Warn }
      return (New-PTSeg $color $P.Dark $label $script:PTIconGit $coloredIcons)
    }
    'venv' {
      if (-not $env:VIRTUAL_ENV) { return $null }
      $name = Split-Path -Leaf $env:VIRTUAL_ENV
      return (New-PTSeg $P.Venv $P.Dark $name $script:PTIconPython $coloredIcons)
    }
    'venv-short' {
      if (-not $env:VIRTUAL_ENV) { return $null }
      return (New-PTSeg $P.Venv $P.Dark '' $script:PTIconPython $coloredIcons)
    }
    'jobs' {
      $n = @(Get-Job -State Running -ErrorAction SilentlyContinue).Count
      if ($n -le 0) { return $null }
      return (New-PTSeg $P.Warn $P.Dark "$n" $script:PTIconGear $coloredIcons)
    }
    'status' {
      $code = _pt_last_exit
      if ($code -eq 0) { return (New-PTSeg $P.Ok $P.Dark '' $script:PTIconOk $coloredIcons) }
      if ($code -in 130, 131, 148) { return (New-PTSeg $P.Warn $P.Dark '' $script:PTIconWarn $coloredIcons) }
      return (New-PTSeg $P.Err $P.White "$($script:PTIconErr) $code" '' $coloredIcons)
    }
    'duration' {
      $d = _pt_cmd_duration
      $th = [int](_pt_cfg 'prompt.duration_threshold' '3')
      if ($d -lt $th) { return $null }
      $label = if ($d -ge 3600) { "$([math]::Floor($d / 3600))h$([math]::Floor(($d % 3600) / 60))m" }
      elseif ($d -ge 60) { "$([math]::Floor($d / 60))m$($d % 60)s" }
      else { "${d}s" }
      return (New-PTSeg $P.Accent $P.Dark $label $script:PTIconClock $coloredIcons)
    }
    'time' {
      return (New-PTSeg $P.Violet $P.Dark (Get-Date -Format 'HH:mm:ss') '' $false)
    }
    'time-short' {
      return (New-PTSeg $P.Violet $P.Dark (Get-Date -Format 'HH:mm') '' $false)
    }
    'aws' {
      if (-not $env:AWS_PROFILE) { return $null }
      return (New-PTSeg $P.Warn $P.Dark "aws:$($env:AWS_PROFILE)" '' $coloredIcons)
    }
    'aws-short' {
      if (-not $env:AWS_PROFILE) { return $null }
      return (New-PTSeg $P.Warn $P.Dark $env:AWS_PROFILE '' $coloredIcons)
    }
    default { return $null }
  }
}

function Format-PTRender {
  param(
    [System.Collections.Generic.List[object]]$Segs,
    [string]$Theme
  )
  if (-not $Segs -or $Segs.Count -eq 0) { return '' }
  $e = _pt_esc
  $n = $Segs.Count
  $sb = [System.Text.StringBuilder]::new()
  $reset = "${e}[0m"

  switch -Regex ($Theme) {
    '^pills-merged$' {
      for ($i = 0; $i -lt $n; $i++) {
        $s = $Segs[$i]
        $bg = $s.Bg; $fg = $s.Fg; $tx = $s.Display
        if ($i -eq 0) { [void]$sb.Append("${reset}${e}[38;2;${bg}m$($script:PTRoundL)") }
        [void]$sb.Append("${reset}${e}[48;2;${bg}m${e}[38;2;${fg}m")
        if ($i -gt 0) { [void]$sb.Append(' ') }
        [void]$sb.Append($tx)
        if ($i -lt $n - 1) { [void]$sb.Append(' ') }
        if ($i -eq $n - 1) { [void]$sb.Append("${reset}${e}[38;2;${bg}m$($script:PTRoundR)${reset}") }
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
        [void]$sb.Append("${reset}${e}[38;2;${bg}m$($script:PTRoundL)${e}[48;2;${bg}m${e}[38;2;${fg}m${tx}${reset}${e}[38;2;${bg}m$($script:PTRoundR)${reset}")
      }
    }
  }
  return $sb.ToString()
}

function _pt_strip_ansi([string]$s) {
  [regex]::Replace($s, '\x1B\[[0-9;]*m', '')
}

function global:prompt {
  Initialize-PTPromptVt

  # Lazy integrations trigger (zoxide, atuin, thefuck)
  if ($script:PTLazyIntegrations -and (Get-Command Initialize-PTIntegrations -ErrorAction SilentlyContinue)) {
    Initialize-PTIntegrations
    $script:PTLazyIntegrations = $false
  }

  # Auto-ls on directory change
  if (Get-Command Invoke-PTAutoLs -ErrorAction SilentlyContinue) {
    Invoke-PTAutoLs
  }

  $e = _pt_esc
  $P = $script:PTPalette
  $leftCfg  = _pt_cfg 'prompt.left'  'user,path,git,venv,jobs'
  $rightCfg = _pt_cfg 'prompt.right' 'status,duration,time'
  $theme    = _pt_cfg 'prompt.style' 'pills-merged'
  _pt_git_info "$leftCfg$rightCfg"

  $leftList = [System.Collections.Generic.List[object]]::new()
  foreach ($seg in ($leftCfg -split ',')) {
    $o = Invoke-PTSeg -Name $seg.Trim() -P $P
    if ($null -ne $o) { $leftList.Add($o) }
  }
  $rightList = [System.Collections.Generic.List[object]]::new()
  foreach ($seg in ($rightCfg -split ',')) {
    $o = Invoke-PTSeg -Name $seg.Trim() -P $P
    if ($null -ne $o) { $rightList.Add($o) }
  }

  $showR = (_pt_cfg 'prompt.show_rprompt' 'true') -eq 'true'

  $promptSuffix = "${e}[38;2;$($P.Violet)m>${e}[0m "
  if (-not $script:PTPromptUseColor) {
    $plainL = ($leftList | ForEach-Object { _pt_strip_ansi $_.Display }) -join ' '
    if ($showR -and $rightList.Count -gt 0) {
      $plainR = ($rightList | ForEach-Object { _pt_strip_ansi $_.Display }) -join ' '
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
    $promptSuffix = '> '
  } else {
    $L = Format-PTRender -Segs $leftList -Theme $theme
    $lVisible = (_pt_strip_ansi $L).Length
    if ($showR -and $rightList.Count -gt 0) {
      $R = Format-PTRender -Segs $rightList -Theme $theme
      $rVisible = (_pt_strip_ansi $R).Length
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
  }

  if (Get-Command __zoxide_hook -ErrorAction SilentlyContinue) { $null = __zoxide_hook }

  return $promptSuffix
}
