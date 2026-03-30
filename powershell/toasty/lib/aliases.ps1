# Toasty shell aliases. Dot-source into your session (init.ps1 does this automatically).
# Config-driven: reads $script:ToastyToml for ls_tool, cd_to_z, typo_aliases settings.

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
Remove-Alias ls -Force -Scope Global -ErrorAction SilentlyContinue
switch ($_lsTool) {
  'eza' {
    if (Get-Command eza -ErrorAction SilentlyContinue) {
      $global:_toastyEza = @('--color=always', '--group-directories-first', '--git', '--hyperlink'); if ($_lsIcons) { $global:_toastyEza += '--icons=always' }
      function global:l   { eza @global:_toastyEza -a @args }
      function global:ls  { eza @global:_toastyEza -lah @args }
      function global:la  { eza @global:_toastyEza -lah @args }
      function global:ll  { eza @global:_toastyEza -lah @args }
      function global:lla { eza @global:_toastyEza -lah @args }
      function global:lt  { eza @global:_toastyEza --tree --level=2 @args }
    }
  }
  'lsd' {
    if (Get-Command lsd -ErrorAction SilentlyContinue) {
      $global:_toastyLsd = @('--color=always'); if ($_lsIcons) { $global:_toastyLsd += '--icon=always' }
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
Remove-Variable _lsTool, _lsIcons -ErrorAction SilentlyContinue

# zoxide: alias cd -> z
if ((_toasty_cfg 'general.cd_to_z' 'true') -eq 'true') {
  if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& zoxide init powershell | Out-String)
    Set-Alias -Name cd -Value z -Scope Global -Force -Option AllScope
    Register-ArgumentCompleter -CommandName cd, z, Set-Location -ScriptBlock {
      param($commandName, $parameterName, $wordToComplete)
      $localDirs = Get-ChildItem -Path "$wordToComplete*" -Directory -ErrorAction SilentlyContinue
      $seen = @{}
      foreach ($d in $localDirs) {
        $n = if ($d.Name -match '\s') { "'$($d.Name)'" } else { $d.Name }
        [System.Management.Automation.CompletionResult]::new($n, $d.Name, 'ParameterValue', $d.FullName)
        $seen[$d.FullName.ToLower()] = $true
      }
      if ($wordToComplete) {
        $zResults = zoxide query -l $wordToComplete 2>$null
        foreach ($zp in $zResults) {
          if (-not $zp -or $seen[$zp.ToLower()]) { continue }
          $leaf = Split-Path $zp -Leaf
          $n = if ($zp -match '\s') { "'$zp'" } else { $zp }
          [System.Management.Automation.CompletionResult]::new($n, "$leaf  ~zoxide", 'ParameterValue', $zp)
          $seen[$zp.ToLower()] = $true
        }
      }
    }
  }
}

# winget shorthand
if (Get-Command winget -ErrorAction SilentlyContinue) {
  function global:wg { winget @args }
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
