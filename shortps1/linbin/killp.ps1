[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
  [Parameter(Mandatory, Position=0)] [string]$Pattern,
  [switch]$Force,
  [switch]$List,
  [switch]$All
)

$matches = Get-Process -ErrorAction SilentlyContinue | Where-Object {
  $_.Name -match $Pattern -or ($All -and ($_.MainWindowTitle -match $Pattern))
}

if (-not $matches) {
  Write-Error "No processes match pattern: $Pattern"
  exit 1
}

if ($List) {
  $matches | Select-Object Id, Name, @{n="CPU";e={$_.CPU}}, @{n="WS(MB)";e={[math]::Round($_.WorkingSet64/1MB,1)}} | Sort-Object CPU -Descending
  return
}

foreach ($p in $matches) {
  $label = "$($p.Name) (Id=$($p.Id))"
  if ($PSCmdlet.ShouldProcess($label, "Stop-Process")) {
    if ($Force) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    else { Stop-Process -Id $p.Id -ErrorAction SilentlyContinue }
  }
}
