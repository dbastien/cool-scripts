[CmdletBinding()]
param(
  [Parameter(Mandatory, Position=0)] [string]$Pattern,
  [switch]$All
)

$procs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
  $_.Name -match $Pattern -or ($All -and ($_.MainWindowTitle -match $Pattern))
}

$procs |
  Select-Object Id, Name,
    @{n="CPU";e={$_.CPU}},
    @{n="WS(MB)";e={[math]::Round($_.WorkingSet64/1MB,1)}},
    @{n="PM(MB)";e={[math]::Round($_.PagedMemorySize64/1MB,1)}} |
  Sort-Object CPU -Descending
