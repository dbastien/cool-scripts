param([Parameter(Mandatory)] [string]$Name)
Get-Command $Name -ErrorAction SilentlyContinue | ForEach-Object { $_.Source }
