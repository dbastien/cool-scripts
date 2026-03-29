param(
  [string]$Pattern,
  [switch]$NameOnly,
  [switch]$ValueOnly,
  [switch]$CaseSensitive
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

$items = Get-ChildItem Env:
if ($Pattern) {
  if ($CaseSensitive) {
    $items = $items | Where-Object { $_.Name -cmatch $Pattern -or $_.Value -cmatch $Pattern }
  } else {
    $items = $items | Where-Object { $_.Name -match $Pattern -or $_.Value -match $Pattern }
  }
}

Initialize-ToastyHost
$useColor = $script:ToastyUseColor

$items | Sort-Object Name | ForEach-Object {
  if ($NameOnly) {
    if ($useColor) { Write-Host $_.Name -ForegroundColor Cyan } else { $_.Name }
  } elseif ($ValueOnly) {
    Write-Output $_.Value
  } else {
    if ($useColor) {
      Write-Host -NoNewline ($_.Name + '=') -ForegroundColor Cyan
      Write-Host $_.Value
    } else {
      "$($_.Name)=$($_.Value)"
    }
  }
}
