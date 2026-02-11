param(
  [Parameter(Position=0)] [string]$Path,
  [Parameter(Position=1)] [int]$n = 10
)

if ($Path) { Get-Content -LiteralPath $Path -TotalCount $n }
else { $input | Select-Object -First $n }
