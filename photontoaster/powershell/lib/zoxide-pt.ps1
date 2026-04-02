# zoxide + PhotonToaster: run after zoxide init so tab completion and cd->z work.
# Dot-sourced from integrations.ps1 with -Config <hashtable>.

param([hashtable]$Config = @{})

function _zoxide_pt_cfg([string]$Key, [string]$Default) {
  if ($Config.ContainsKey($Key) -and $null -ne $Config[$Key] -and $Config[$Key] -ne '') { return [string]$Config[$Key] }
  return $Default
}

if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) { return }

if ((_zoxide_pt_cfg 'general.cd_to_z' 'true') -ne 'true') { return }
if (-not (Get-Command z -ErrorAction SilentlyContinue)) { return }

Remove-Alias -Name cd -Scope Global -Force -ErrorAction SilentlyContinue
Set-Alias -Name cd -Value z -Scope Global -Force -Option AllScope

Register-ArgumentCompleter -Native -CommandName z, cd, __zoxide_z -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'
  try {
    $tok = if ($null -eq $wordToComplete) { '' } else { $wordToComplete.Trim() }
    $lines = @(zoxide query -l $tok 2>$null)
    foreach ($zp in $lines) {
      if (-not $zp) { continue }
      $leaf = Split-Path $zp -Leaf
      $n = if ($zp -match '\s') { "'$zp'" } else { $zp }
      [System.Management.Automation.CompletionResult]::new($n, $leaf, 'ParameterValue', $zp)
    }
  } finally {
    $ErrorActionPreference = $prevEap
  }
}
