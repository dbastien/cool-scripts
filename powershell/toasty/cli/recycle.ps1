param([Parameter(Mandatory, ValueFromRemainingArguments = $true)] [string[]]$Path)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

Add-Type -AssemblyName Microsoft.VisualBasic
foreach ($p in $Path) {
  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg "recycle: $p" Muted
  }
  [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, 'OnlyErrorDialogs', 'SendToRecycleBin')
}