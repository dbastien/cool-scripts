param([string]$Pattern=".")
Get-Service | Where-Object Name -match $Pattern | Sort-Object Status,Name | Format-Table -AutoSize
