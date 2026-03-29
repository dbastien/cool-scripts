param([string]$Path = ".")

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

try {
  $full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
} catch {
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg "explore: $Path : $($_)" Err
  }
  exit 1
}

if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
  $disp = $full
  if (Get-Command Format-ToastyPathLink -ErrorAction SilentlyContinue) {
    $disp = Format-ToastyPathLink -Path $full -Display $full
  }
  Write-ToastyMsg ("Opening Explorer: " + $disp) Info
}

Start-Process explorer.exe $full