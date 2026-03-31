# Toasty shell aliases. Dot-source into your session (init.ps1 does this automatically).
# Config-driven: ls_tool, ls_icons, ls_column_header, ls_octal_permissions, ls_binary_sizes,
# ls_size_bytes, ls_hyperlink_ctrl_click_cd, cd_to_z, typo_aliases, photon_aliases (see config.toml.default).

param([hashtable]$Config = @{})

function _toasty_cfg([string]$Key, [string]$Default) {
  if ($Config.ContainsKey($Key) -and $null -ne $Config[$Key] -and $Config[$Key] -ne '') { return [string]$Config[$Key] }
  return $Default
}

# Parent hops
function global:.. { Set-Location .. }
function global:... { Set-Location ../.. }
function global:.... { Set-Location ../../.. }
function global:..... { Set-Location ../../../.. }
function global:...... { Set-Location ../../../../.. }

function global:Up-Location {
  param([ValidateRange(1, 64)][int]$n = 1)
  for ($i = 0; $i -lt $n; $i++) { Set-Location .. }
}
Set-Alias -Name up -Value Up-Location -Scope Global -Force

function global:reload {
  if (-not $global:ToastyRoot) {
    Write-Warning 'reload: $global:ToastyRoot unset (load Toasty init first).'
    return
  }
  $r = Join-Path $global:ToastyRoot 'cli\reload.ps1'
  if (-not (Test-Path -LiteralPath $r)) {
    Write-Warning "reload: missing $r"
    return
  }
  . (Resolve-Path -LiteralPath $r)
}

# Dynamic ls aliases from general.ls_tool + general.ls_icons
$_lsTool = (_toasty_cfg 'general.ls_tool' 'eza')
$_lsIcons = (_toasty_cfg 'general.ls_icons' 'true') -eq 'true'
$_lsHeader = (_toasty_cfg 'general.ls_column_header' 'true') -eq 'true'
$_lsOctal = (_toasty_cfg 'general.ls_octal_permissions' 'false') -eq 'true'
$_lsBytes = (_toasty_cfg 'general.ls_size_bytes' 'false') -eq 'true'
$_lsBinary = ($_lsBytes) ? $false : ((_toasty_cfg 'general.ls_binary_sizes' 'false') -eq 'true')
Remove-Alias ls -Force -Scope Global -ErrorAction SilentlyContinue
$global:_toastyEzaCdLink = $false
switch ($_lsTool) {
  'eza' {
    if (Get-Command eza -ErrorAction SilentlyContinue) {
      $global:_toastyEza = @('--color=always', '--group-directories-first', '--git', '--hyperlink')
      if ($_lsIcons) { $global:_toastyEza += '--icons=always' }
      if ($_lsOctal) { $global:_toastyEza += '-o' }
      if ($_lsBytes) { $global:_toastyEza += '-B' }
      elseif ($_lsBinary) { $global:_toastyEza += '-b' }
      $_ezaLong = [System.Collections.Generic.List[string]]::new()
      [void]$_ezaLong.AddRange([string[]]@('-l', '-a'))
      if ($_lsHeader) { [void]$_ezaLong.Add('-h') }
      $global:_toastyEzaLong = @($_ezaLong)
      $global:_toastyEzaCdLink = ((_toasty_cfg 'general.ls_hyperlink_ctrl_click_cd' 'false') -eq 'true')
      if ($global:_toastyEzaCdLink) {
        function global:l   { eza @global:_toastyEza -a @args | ForEach-Object { Convert-ToastyEzaLineHyperlinksToCdProtocol $_ } }
        function global:ls  { eza @global:_toastyEza @global:_toastyEzaLong @args | ForEach-Object { Convert-ToastyEzaLineHyperlinksToCdProtocol $_ } }
        function global:la  { eza @global:_toastyEza @global:_toastyEzaLong @args | ForEach-Object { Convert-ToastyEzaLineHyperlinksToCdProtocol $_ } }
        function global:ll  { eza @global:_toastyEza @global:_toastyEzaLong @args | ForEach-Object { Convert-ToastyEzaLineHyperlinksToCdProtocol $_ } }
        function global:lla { eza @global:_toastyEza @global:_toastyEzaLong @args | ForEach-Object { Convert-ToastyEzaLineHyperlinksToCdProtocol $_ } }
        function global:lt  { eza @global:_toastyEza --tree --level=2 @args | ForEach-Object { Convert-ToastyEzaLineHyperlinksToCdProtocol $_ } }
      } else {
        function global:l   { eza @global:_toastyEza -a @args }
        function global:ls  { eza @global:_toastyEza @global:_toastyEzaLong @args }
        function global:la  { eza @global:_toastyEza @global:_toastyEzaLong @args }
        function global:ll  { eza @global:_toastyEza @global:_toastyEzaLong @args }
        function global:lla { eza @global:_toastyEza @global:_toastyEzaLong @args }
        function global:lt  { eza @global:_toastyEza --tree --level=2 @args }
      }
    }
  }
  'lsd' {
    if (Get-Command lsd -ErrorAction SilentlyContinue) {
      $global:_toastyLsd = [System.Collections.Generic.List[string]]::new()
      [void]$global:_toastyLsd.AddRange(@('--color=always'))
      if ($_lsIcons) { [void]$global:_toastyLsd.Add('--icon=always') }
      if ($_lsOctal) { [void]$global:_toastyLsd.AddRange(@('--permission', 'octal')) }
      if ($_lsBytes) { [void]$global:_toastyLsd.AddRange(@('--size', 'bytes')) }
      elseif ($_lsBinary) { [void]$global:_toastyLsd.AddRange(@('--size', 'short')) }
      if ($_lsHeader) { [void]$global:_toastyLsd.Add('--header') }
      $global:_toastyLsd = @($global:_toastyLsd)
      function global:l   { lsd @global:_toastyLsd -A @args }
      function global:ls  { lsd @global:_toastyLsd -lAh @args }
      function global:la  { lsd @global:_toastyLsd -lAh @args }
      function global:ll  { lsd @global:_toastyLsd -lAh @args }
      function global:lla { lsd @global:_toastyLsd -lAh @args }
      function global:lt  { lsd @global:_toastyLsd --tree --depth=2 @args }
    }
  }
  'ls' {
    # no override; use built-in Get-ChildItem alias
  }
}
Remove-Variable _lsTool, _lsIcons, _lsHeader, _lsOctal, _lsBytes, _lsBinary -ErrorAction SilentlyContinue

# zoxide + cd -> z: loaded from init.ps1 *after* prompt.ps1 (see lib\zoxide-toasty.ps1).

# winget shorthand
if (Get-Command winget -ErrorAction SilentlyContinue) {
  function global:wg { winget @args }
}

# --- Photon Toaster–style (linux/photontoaster/aliases.toml); gated so you can keep default gc/gp/gl/ps ---
if ((_toasty_cfg 'general.photon_aliases' 'true') -eq 'true') {

  function global:cls { Clear-Host }

  function global:mkd {
    foreach ($p in $args) {
      if ($p) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    }
  }
  function global:cd.. { Set-Location .. }
  function global:v {
    $ed = $env:EDITOR
    if (-not $ed) {
      foreach ($c in @('code', 'codium', 'nvim', 'vim', 'notepad')) {
        if (Get-Command $c -CommandType Application -ErrorAction SilentlyContinue) { $ed = $c; break }
      }
    }
    if (-not $ed) { $ed = 'notepad' }
    & $ed @args
  }

  if (Get-Command git -CommandType Application -ErrorAction SilentlyContinue) {
    Remove-Item alias:gc -Force -ErrorAction SilentlyContinue
    Remove-Item alias:gp -Force -ErrorAction SilentlyContinue
    Remove-Item alias:gl -Force -ErrorAction SilentlyContinue
    function global:gs { git -c color.ui=auto status @args }
    function global:ga { git add @args }
    function global:gc { git commit @args }
    function global:gp { git pull @args }
    function global:gd { git -c color.ui=auto diff @args }
    function global:gl { git -c color.ui=auto log --oneline --decorate --graph -20 @args }
    function global:gst { git status -sb @args }
    function global:gco { git checkout @args }
    function global:gcb { git checkout -b @args }
    function global:gcm { git commit -m ($args -join ' ') }
  }

  function global:j {
    if (Get-Command z -ErrorAction SilentlyContinue) { z @args }
    elseif (Get-Command zoxide -ErrorAction SilentlyContinue) { zoxide @args }
    else { Write-Warning 'j: zoxide not loaded yet (reload after init).' }
  }

  function _photonCmd([string]$Name) {
    return $null -ne (Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
  }

  if (_photonCmd 'lazygit') { function global:lg { lazygit @args } }
  if (_photonCmd 'qalc') { function global:calc { qalc @args } }
  if (_photonCmd 'delta') { function global:d { delta @args } }
  if (_photonCmd 'nvtop') { function global:gpu { nvtop @args } }
  if (_photonCmd 'television') { function global:tv { television @args } }
  if (_photonCmd 'mcp-probe') { function global:mcpp { mcp-probe @args } }
  if (_photonCmd 'bandwhich') { function global:bw { bandwhich @args } }
  if (_photonCmd 'sampler') { function global:samp { sampler @args } }
  if (_photonCmd 'task') { function global:todo { task @args } }
  if (_photonCmd 'pet') { function global:snippets { pet @args } }
  if (_photonCmd 'eget') { function global:getgh { eget @args } }
  if (_photonCmd 'tldr') {
    function global:kb { tldr @args }
    function global:tl { tldr @args }
  }
  if (_photonCmd 'jless') { function global:jl { jless @args } }
  if (_photonCmd 'glow') { function global:mdcat { glow @args } }
  if (_photonCmd 'helix') { function global:hx { helix @args } }
  if (_photonCmd 'yazi') { function global:fm { yazi @args } }
  if (_photonCmd 'xplr') { function global:xp { xplr @args } }
  if (_photonCmd 'broot') { function global:br { broot @args } }
  if (_photonCmd 'hyperfine') { function global:bench { hyperfine @args } }
  if (_photonCmd 'xh') { function global:http { xh @args } }
  if (_photonCmd 'hexyl') { function global:hex { hexyl @args } }

  if (_photonCmd 'btop') { function global:top { btop @args } }
  if (_photonCmd 'duf') { function global:df { duf @args } }
  if (_photonCmd 'dust') { function global:du { dust @args } }
  if (_photonCmd 'procs') {
    Remove-Item alias:ps -Force -ErrorAction SilentlyContinue
    function global:ps { procs @args }
  }
  if (_photonCmd 'doggo') { function global:dig { doggo @args } }
  if (_photonCmd 'ouch') { function global:x { ouch decompress @args } }

  if (_photonCmd 'jq') { function global:jqp { jq -C . @args } }
  if (_photonCmd 'fd') { function global:fda { fd -HI --color=always --hyperlink @args } }
  if (_photonCmd 'bat') { function global:ccat { bat --color=always --hyperlink=auto --paging=never --style=header,grid,numbers,changes @args } }
  if (_photonCmd 'rg') { function global:rgf { rg -n --color=always --hyperlink-format=default @args } }
  if (_photonCmd 'cronboard') { function global:cronview { cronboard @args } }
  if (_photonCmd 'plocate') { function global:ff { plocate @args } }
  elseif (_photonCmd 'locate') { function global:ff { locate @args } }

  if (_photonCmd 'tmux') {
    function global:t { tmux -2 @args }
    function global:ta { if ($args.Count -gt 0) { tmux attach -t @args } else { tmux attach } }
    function global:tls { tmux ls @args }
    function global:tn { if ($args.Count -gt 0) { tmux new -s @args } else { tmux new } }
  }

  function global:ipbrief {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Where-Object { $_.IPAddress -notlike '127.*' } |
      Sort-Object InterfaceIndex |
      Format-Table -AutoSize InterfaceAlias, IPAddress, PrefixLength
  }

  function global:ports {
    Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
      Select-Object LocalAddress, LocalPort, OwningProcess,
      @{ Name = 'Process'; Expression = { try { (Get-Process -Id $_.OwningProcess -ErrorAction Stop).ProcessName } catch { '?' } } } |
      Sort-Object LocalPort |
      Format-Table -AutoSize
  }

  Remove-Item function:_photonCmd -Force -ErrorAction SilentlyContinue
}

# Typo aliases
if ((_toasty_cfg 'general.typo_aliases' 'true') -eq 'true') {
  if (Get-Command git -ErrorAction SilentlyContinue) {
    function global:gti { git @args }
    function global:got { git @args }
    function global:gi { git @args }
  }
  function global:claer { Clear-Host }
  function global:clera { Clear-Host }
  function global:clare { Clear-Host }
  function global:cler { Clear-Host }
  function global:clr { Clear-Host }
}

# TOML-driven aliases (aliases.toml)
if ((_toasty_cfg 'general.toml_aliases' 'true') -eq 'true') {
  $_tomlPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'aliases.toml'
  if (-not (Test-Path -LiteralPath $_tomlPath)) {
    $_cfgDir = if ($env:TOASTY_CONFIG_DIR) { $env:TOASTY_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.config\toasty' }
    $_tomlPath = Join-Path $_cfgDir 'aliases.toml'
  }
  if (Test-Path -LiteralPath $_tomlPath) {
    $_existingCmds = @{}
    Get-Command -Type Function, Alias -ErrorAction SilentlyContinue | ForEach-Object { $_existingCmds[$_.Name] = $true }

    Get-Content -LiteralPath $_tomlPath -Encoding utf8 | ForEach-Object {
      $line = $_.Trim()
      if ($line -match '^\s*#' -or $line -eq '' -or $line -match '^\[') { return }
      if ($line -match '^([^=]+)=\s*"(.+)"') {
        $_aliasName = $Matches[1].Trim()
        $_aliasCmd = $Matches[2].Trim()
        if ($_existingCmds.ContainsKey($_aliasName)) { return }
        $_parts = $_aliasCmd -split '\s+', 2
        $_base = $_parts[0]
        if (-not (Get-Command $_base -ErrorAction SilentlyContinue)) { return }
        $_flagStr = if ($_parts.Count -gt 1) { $_parts[1] } else { '' }
        $_flags = if ($_flagStr) { @($_flagStr -split '\s+') } else { @() }
        $global:_toastyTomlAliases = @{} + ($global:_toastyTomlAliases ?? @{})
        $global:_toastyTomlAliases[$_aliasName] = @{ Base = $_base; Flags = $_flags }
        Set-Item -Path "function:global:$_aliasName" -Value ([scriptblock]::Create(
          "& '$_base' $($_flags -join ' ') @args"
        )) -Force
      }
    }
    Remove-Variable _tomlPath, _existingCmds, _aliasName, _aliasCmd, _parts, _base, _flagStr, _flags -ErrorAction SilentlyContinue
  }
}
