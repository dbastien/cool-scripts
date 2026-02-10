param(
  [Parameter(Mandatory, Position=0)] [string]$Name,
  [Alias("a")] [switch]$All
)
$cmds = Get-Command $Name -ErrorAction SilentlyContinue
if (-not $cmds) { return }
if ($All) { $cmds | ForEach-Object { $_.Source } }
else { ($cmds | Select-Object -First 1).Source }
