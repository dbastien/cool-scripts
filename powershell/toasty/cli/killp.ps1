[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
  [Parameter(Mandatory, Position = 0)] [string]$Pattern,
  [switch]$Force,
  [switch]$List,
  [switch]$All
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

$matches = Get-Process -ErrorAction SilentlyContinue | Where-Object {
  $_.Name -match $Pattern -or ($All -and ($_.MainWindowTitle -match $Pattern))
}

if (-not $matches) {
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "killp: no processes match pattern: $Pattern" Err
  }
  exit 1
}

if ($List) {
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "killp: candidates (no stop yet)" Info
  }
  $matches | Select-Object Id, Name, @{n = "CPU"; e = { $_.CPU } }, @{n = "WS(MB)"; e = { [math]::Round($_.WorkingSet64 / 1MB, 1) } } | Sort-Object CPU -Descending | Format-Table -AutoSize
  return
}

foreach ($p in $matches) {
  $label = "$($p.Name) (Id=$($p.Id))"
  if ($PSCmdlet.ShouldProcess($label, "Stop-Process")) {
    if ($Force) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    else { Stop-Process -Id $p.Id -ErrorAction SilentlyContinue }
  }
}

if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
  Write-ShortPs1Msg "killp: sent stop to $($matches.Count) process(es)" Ok
}