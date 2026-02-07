param(
  [Parameter(Position=0)] [int]$s = 2,
  [switch]$NoClear,
  [Parameter(Mandatory, Position=1, ValueFromRemainingArguments=$true)]
  [string[]]$Command
)

while ($true) {
  if (-not $NoClear) { Clear-Host }
  Write-Host ("Every {0}s: {1}    {2}" -f $s, ($Command -join " "), (Get-Date))
  try { Invoke-Expression ($Command -join " ") } catch { $_ }
  Start-Sleep $s
}
