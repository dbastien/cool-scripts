param(
  [string]$Root = ".",
  [string]$Filter = "*",
  [Alias("type")]
  [ValidateSet("any", "f", "d")]
  [string]$FileType = "any",

  [int]$MaxDepth = [int]::MaxValue
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if (-not (Test-Path -LiteralPath $Root)) {
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "find: not found: $Root" Err
  }
  exit 1
}

$rootFull = (Resolve-Path -LiteralPath $Root).Path

function Walk {
  param([string]$Dir, [int]$Depth)
  if ($Depth -gt $MaxDepth) { return }
  try {
    $items = Get-ChildItem -LiteralPath $Dir -Force -ErrorAction SilentlyContinue
  } catch { return }
  foreach ($it in $items) {
    $show = $false
    if ($FileType -eq "any") { $show = $true }
    elseif ($FileType -eq "f" -and -not $it.PSIsContainer) { $show = $true }
    elseif ($FileType -eq "d" -and $it.PSIsContainer) { $show = $true }

    if ($show) {
      if ($Filter -eq "*" -or $it.Name -like $Filter) {
        if (Get-Command Write-ShortPs1PathLine -ErrorAction SilentlyContinue) {
          Write-ShortPs1PathLine -FullPath $it.FullName
        } else {
          $it.FullName
        }
      }
    }
    if ($it.PSIsContainer) {
      Walk -Dir $it.FullName -Depth ($Depth + 1)
    }
  }
}

Walk -Dir $rootFull -Depth 0