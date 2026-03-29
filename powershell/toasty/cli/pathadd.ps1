param([Parameter(Mandatory)] [string]$Dir)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

try {
  $full = (Resolve-Path -LiteralPath $Dir -ErrorAction Stop).Path
} catch {
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "pathadd: $Dir : $($_)" Err
  }
  exit 1
}

if (-not ($env:Path -split ';' | Where-Object { $_ -eq $full })) {
  $env:Path = "$full;$env:Path"
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "Prepended PATH: $full" Ok
  }
} elseif (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
  Write-ShortPs1Msg "PATH already contains: $full" Info
}