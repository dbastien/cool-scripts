# zoxide + Toasty: run after shell/prompt.ps1 so zoxide wraps the Toasty prompt (pwd/prompt hook keeps working).
# Dot-sourced from init.ps1 with -Config <hashtable>.

param([hashtable]$Config = @{})

function _zoxide_toasty_cfg([string]$Key, [string]$Default) {
  if ($Config.ContainsKey($Key) -and $null -ne $Config[$Key] -and $Config[$Key] -ne '') { return [string]$Config[$Key] }
  return $Default
}

if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) { return }

try {
  Invoke-Expression (& zoxide init powershell | Out-String)
} catch {
  Write-Warning "Toasty: zoxide init failed (cd may stay Set-Location): $_"
}

if ((_zoxide_toasty_cfg 'general.cd_to_z' 'true') -ne 'true') { return }
if (-not (Get-Command z -ErrorAction SilentlyContinue)) { return }

Remove-Alias -Name cd -Scope Global -Force -ErrorAction SilentlyContinue
Set-Alias -Name cd -Value z -Scope Global -Force -Option AllScope

# Native completer: zoxide paths only. Register z, cd, and __zoxide_z — when cd still aliases
# Set-Location, PowerShell ignores a native "cd" completer; after cd -> z, "cd" must still be listed
# so completion matches the token you typed (verified: cd + alias-to-z uses native "cd").
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
