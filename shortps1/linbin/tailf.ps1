param(
  [Parameter(Mandatory, Position=0)] [string]$Path,
  [Parameter(Position=1)] [int]$n = 10
)

Get-Content -LiteralPath $Path -Tail $n -Wait
