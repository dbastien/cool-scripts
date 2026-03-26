param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Paths
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'SharedLibs\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

$targets = [System.Collections.Generic.List[string]]::new()
foreach ($p in $Paths) {
  if ($p) { $targets.Add($p) }
}
foreach ($x in $input) {
  if ($null -ne $x) { $targets.Add($x.ToString()) }
}
if ($targets.Count -eq 0) { $targets.Add('.') }

foreach ($p in $targets) {
  try {
    (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path
  } catch {
    if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
      Write-ShortPs1Msg "realpath: $p : $($_)" Err
    }
    exit 1
  }
}