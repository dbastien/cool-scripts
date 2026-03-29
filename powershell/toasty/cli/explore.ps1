param([string]$Path = ".")

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

try {
  $full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
} catch {
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "explore: $Path : $($_)" Err
  }
  exit 1
}

if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
  $disp = $full
  if (Get-Command Format-ShortPs1PathLink -ErrorAction SilentlyContinue) {
    $disp = Format-ShortPs1PathLink -Path $full -Display $full
  }
  Write-ShortPs1Msg ("Opening Explorer: " + $disp) Info
}

Start-Process explorer.exe $full