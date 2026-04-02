param([string]$Root = ".")

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if (-not (Test-Path -LiteralPath $Root)) {
  if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
    Write-PTMsg "du: not found: $Root" Err
  }
  exit 1
}

if (Test-Path -LiteralPath $Root -PathType Leaf) {
  $bytes = (Get-Item -LiteralPath $Root -ErrorAction SilentlyContinue).Length
  if ($null -eq $bytes) { $bytes = 0 }
  $mib = [math]::Round(($bytes / 1MB), 2)
  $pathDisp = (Resolve-Path -LiteralPath $Root).Path
  if (Get-Command Format-PTPathLink -ErrorAction SilentlyContinue) {
    $pathDisp = Format-PTPathLink -Path $Root -Display $pathDisp
  }
  $c = $null
  if (Get-Command Get-PTDuColor -ErrorAction SilentlyContinue) { $c = Get-PTDuColor $mib }
  $line = "`u{1F4C4} {0,12} MiB  {1}" -f $mib, $pathDisp
  if ($c) { Write-Host $line -ForegroundColor $c } else { Write-Host $line }
  return
}

Get-ChildItem -LiteralPath $Root -Directory -Force -ErrorAction SilentlyContinue |
  ForEach-Object {
    $dir = $_
    $bytes = (Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
      Measure-Object Length -Sum).Sum
    if ($null -eq $bytes) { $bytes = 0 }
    [pscustomobject]@{ MiB = [math]::Round(($bytes / 1MB), 2); Path = $dir.FullName }
  } | Sort-Object MiB -Descending | ForEach-Object {
  $pathDisp = $_.Path
  if (Get-Command Format-PTPathLink -ErrorAction SilentlyContinue) {
    $pathDisp = Format-PTPathLink -Path $_.Path -Display $_.Path
  }
  $c = $null
  if (Get-Command Get-PTDuColor -ErrorAction SilentlyContinue) { $c = Get-PTDuColor $_.MiB }
  $line = "`u{1F4C1} {0,12} MiB  {1}" -f $_.MiB, $pathDisp
  if ($c) { Write-Host $line -ForegroundColor $c } else { Write-Host $line }
}