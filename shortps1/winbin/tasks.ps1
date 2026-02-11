Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 Id,ProcessName,CPU,
  @{n="WS(MB)";e={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize
