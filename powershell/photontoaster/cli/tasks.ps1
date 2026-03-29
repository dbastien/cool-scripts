$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
  Write-ShortPs1Msg "Top processes by CPU" Muted
}

Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 Id, ProcessName, CPU,
  @{n = "WS(MB)"; e = { [math]::Round($_.WorkingSet64 / 1MB, 1) } } | Format-Table -AutoSize