param(
  [Alias("h")] [switch]$Human,
  [switch]$PassThru
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

function Format-Bytes([long]$b) {
  if ($b -lt 0) { return "" }
  if ($b -ge 1TB) { "{0:N2}T" -f ($b / 1TB) }
  elseif ($b -ge 1GB) { "{0:N2}G" -f ($b / 1GB) }
  elseif ($b -ge 1MB) { "{0:N2}M" -f ($b / 1MB) }
  elseif ($b -ge 1KB) { "{0:N2}K" -f ($b / 1KB) }
  else { "$b" }
}

$rows = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
  $used = $_.Used
  $free = $_.Free
  if ($null -eq $used -or $null -eq $free) { return }
  $total = $used + $free
  $pct = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 1) } else { 0 }
  [pscustomobject]@{
    Drive = $_.Name
    UsedGiB = [math]::Round($used / 1GB, 2)
    FreeGiB = [math]::Round($free / 1GB, 2)
    PctUsed = $pct
    Root = $_.Root
    UsedB = $used
    FreeB = $free
    TotalB = $total
  }
} | Sort-Object PctUsed -Descending

if ($PassThru) {
  $rows
  return
}

foreach ($r in $rows) {
  $color = $null
  if (Get-Command Get-ToastyDfColor -ErrorAction SilentlyContinue) {
    $color = Get-ToastyDfColor $r.PctUsed
  }
  $rootDisplay = $r.Root
  if (Get-Command Format-ToastyPathLink -ErrorAction SilentlyContinue) {
    try {
      $rp = (Resolve-Path -LiteralPath $r.Root -ErrorAction Stop).Path
      $rootDisplay = Format-ToastyPathLink -Path $rp -Display $r.Root
    } catch { }
  }
  $usedS = if ($Human) { Format-Bytes $r.UsedB } else { $r.UsedGiB }
  $freeS = if ($Human) { Format-Bytes $r.FreeB } else { $r.FreeGiB }
  $totalS = if ($Human) { Format-Bytes $r.TotalB } else { [math]::Round($r.TotalB / 1GB, 2) }
  $line = "`u{1F4BD} {0,-3}  Used {1,-10} Free {2,-10} Total {3,-10} {4,5}%  {5}" -f $r.Drive, $usedS, $freeS, $totalS, $r.PctUsed, $rootDisplay
  if ($color) {
    Write-Host $line -ForegroundColor $color
  } else {
    Write-Host $line
  }
}