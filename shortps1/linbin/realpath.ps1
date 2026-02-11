param([Parameter(Position=0, ValueFromPipeline=$true)] [string]$Path=".")
process { (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path }
