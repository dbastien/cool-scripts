# .SYNOPSIS
# System-wide filename search. Uses Everything (es.exe) when available, falls back to Get-ChildItem.
param(
  [Parameter(Mandatory, Position = 0)] [string]$Pattern,
  [string]$Root,
  [Alias("type")]
  [ValidateSet("any", "f", "d")]
  [string]$FileType = "any",
  [Alias("r")]  [switch]$Regex,
  [Alias("cs")] [switch]$CaseSensitive,
  [Alias("n")]  [int]$MaxResults = 0
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

function _locateMsg([string]$m, [string]$l = 'Info') {
  if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) { Write-PTMsg $m $l }
  else { Write-Host $m }
}

function _locateOut([string]$FullPath) {
  if (Get-Command Write-PTPathLine -ErrorAction SilentlyContinue) {
    Write-PTPathLine -FullPath $FullPath
  } else {
    $FullPath
  }
}

$resolvedRoot = $null
if ($Root) {
  if (-not (Test-Path -LiteralPath $Root)) {
    _locateMsg "locate: path not found: $Root" Err
    exit 1
  }
  $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
}

# ΓöÇΓöÇ Everything (es.exe) fast path ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
$es = Get-Command es -CommandType Application -ErrorAction SilentlyContinue |
  Select-Object -First 1

if ($es) {
  $args_ = [System.Collections.Generic.List[string]]::new()

  if ($Regex)         { $args_.Add('-r') }
  if ($CaseSensitive) { $args_.Add('-case') }
  if ($MaxResults -gt 0) { $args_.Add('-max-results'); $args_.Add($MaxResults.ToString()) }

  switch ($FileType) {
    'f' { $args_.Add('-file') }
    'd' { $args_.Add('-folder') }
  }

  $query = ''
  if ($resolvedRoot) { $query += "path:$resolvedRoot\ " }
  $query += $Pattern
  $args_.Add($query)

  $results = & $es.Source @args_ 2>&1
  foreach ($line in $results) {
    $p = "$line".Trim()
    if ($p) { _locateOut $p }
  }
  return
}

# ΓöÇΓöÇ Fallback: recursive Get-ChildItem ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
if (-not $global:_toastyLocateHinted) {
  $global:_toastyLocateHinted = $true
  _locateMsg 'locate: install Everything (voidtools.com) + es.exe for instant results' Muted
}

$searchRoot = if ($resolvedRoot) { $resolvedRoot } else { $env:SystemDrive + '\' }
$count = 0

Get-ChildItem -LiteralPath $searchRoot -Recurse -Force -ErrorAction SilentlyContinue |
  Where-Object {
    if ($FileType -eq 'f' -and $_.PSIsContainer) { return $false }
    if ($FileType -eq 'd' -and -not $_.PSIsContainer) { return $false }
    if ($Regex) {
      if ($CaseSensitive) { return $_.Name -cmatch $Pattern }
      return $_.Name -match $Pattern
    }
    if ($CaseSensitive) { return $_.Name -clike $Pattern }
    return $_.Name -like $Pattern
  } |
  ForEach-Object {
    if ($MaxResults -gt 0 -and $count -ge $MaxResults) { return }
    _locateOut $_.FullName
    $count++
  }