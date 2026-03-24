[CmdletBinding()]
param(
  [Parameter(Position=0)] [string]$Pattern,
  [Parameter(Position=1)] [string]$Replacement = "",
  [Parameter(Position=2)] [string]$Path,
  [switch]$i
)

function Apply-Replace([string]$s) { $s -replace $Pattern, $Replacement }

if ($Path) {
  if ($i) {
    $raw = Get-Content -LiteralPath $Path -Raw
    $out = Apply-Replace $raw
    Set-Content -LiteralPath $Path -Value $out
  } else {
    Get-Content -LiteralPath $Path | ForEach-Object { Apply-Replace $_ }
  }
} else {
  $input | ForEach-Object { Apply-Replace ($_.ToString()) }
}
