param([Parameter(Position=0)] [string]$Path)
if ($Path) { Get-Content -LiteralPath $Path | Sort-Object -Unique }
else { $input | Sort-Object -Unique }
