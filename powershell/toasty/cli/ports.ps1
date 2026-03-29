$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
  Write-ToastyMsg "Listening TCP (LocalAddress : Port -> Process)" Muted
}

Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Select-Object LocalAddress, LocalPort, OwningProcess |
  ForEach-Object {
    $procName = ""
    try {
      $procName = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
    } catch { }
    [pscustomobject]@{
      LocalAddress = $_.LocalAddress
      LocalPort    = $_.LocalPort
      PID          = $_.OwningProcess
      Process      = $procName
    }
  } |
  Sort-Object LocalPort |
  Format-Table -AutoSize