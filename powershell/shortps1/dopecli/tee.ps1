param(
  [Parameter(Mandatory, Position = 0)] [string]$Path,
  [Alias("a")]
  [switch]$Append
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
param(
  [Parameter(Mandatory, Position = 0)] [string]$Path,
  [Alias("a")]
  [switch]$Append
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'SharedLibs\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

end {
  try {
    if ($Append) { $input | Tee-Object -FilePath $Path -Append }
    else { $input | Tee-Object -FilePath $Path }
  } catch {
    if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
      Write-ShortPs1Msg "tee: $Path : $($_)" Err
    }
    exit 1
  }
}