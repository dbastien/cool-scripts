# .SYNOPSIS
# Re-sources your PowerShell profile (like `source ~/.bashrc` on Linux). Dot-source this file:  . reload.ps1

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

$p = $PROFILE.CurrentUserCurrentHost
if ([string]::IsNullOrWhiteSpace($p)) { $p = [string]$PROFILE }

if (-not (Test-Path -LiteralPath $p)) {
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) { Write-ToastyMsg "reload: no profile at $p" Warn }
  else { Write-Warning "No profile at $p" }
  return
}

. $p
if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) { Write-ToastyMsg "reload: $p" Ok }
