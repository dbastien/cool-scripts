param(
  [Alias("a")]
  [switch]$All
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'SharedLibs\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
  Write-ShortPs1Msg "Processes (CPU is cumulative seconds since start)" Muted
}

$procs = Get-Process | Sort-Object -Property CPU -Descending
$procs | Select-Object `
  @{Name = "PID"; Expression = { $_.Id } }, `
  @{Name = "CPU(s)"; Expression = { if ($_.CPU) { [Math]::Round($_.CPU, 2) } else { 0 } } }, `
  @{Name = "WS(MB)"; Expression = { [Math]::Round($_.WorkingSet64 / 1MB, 1) } }, `
  @{Name = "PM(MB)"; Expression = { [Math]::Round($_.PagedMemorySize64 / 1MB, 1) } }, `
  @{Name = "Start"; Expression = { try { $_.StartTime.ToString("yyyy-MM-dd HH:mm") } catch { "" } } }, `
  @{Name = "Name"; Expression = { $_.ProcessName } } `
| Format-Table -AutoSize