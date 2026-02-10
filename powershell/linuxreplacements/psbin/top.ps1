[CmdletBinding()]
param(
  [int]$n = 20,
  [int]$s = 2,
  [ValidateSet("cpu","mem")] [string]$Sort = "cpu",
  [switch]$Once,
  [switch]$All
)

function Get-TopRows {
  $p = Get-Process -ErrorAction SilentlyContinue
  $rows = $p | Select-Object Id, Name,
    @{n="CPU";e={$_.CPU}},
    @{n="WS(MB)";e={[math]::Round($_.WorkingSet64/1MB,1)}},
    @{n="PM(MB)";e={[math]::Round($_.PagedMemorySize64/1MB,1)}},
    @{n="Handles";e={$_.Handles}},
    @{n="Threads";e={$_.Threads.Count}},
    @{n="Title";e={ if($All){$_.MainWindowTitle}else{""} }}

  if ($Sort -eq "mem") { $rows | Sort-Object "WS(MB)" -Descending | Select-Object -First $n }
  else { $rows | Sort-Object CPU -Descending | Select-Object -First $n }
}

do {
  Clear-Host
  Get-Date
  $top = Get-TopRows
  if ($All) { $top | Format-Table -AutoSize Id,Name,CPU,"WS(MB)","PM(MB)",Handles,Threads,Title }
  else { $top | Format-Table -AutoSize Id,Name,CPU,"WS(MB)","PM(MB)",Handles,Threads }
  if (-not $Once) { Start-Sleep -Seconds $s }
} while (-not $Once)
