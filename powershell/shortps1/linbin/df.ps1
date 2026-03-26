Get-PSDrive -PSProvider FileSystem | ForEach-Object {
  $used = $_.Used; $free = $_.Free
  if ($null -eq $used -or $null -eq $free) { return }
  $total = $used + $free
  [pscustomobject]@{
    Drive=$_.Name
    UsedGiB=[math]::Round($used/1GB,2)
    FreeGiB=[math]::Round($free/1GB,2)
    PctUsed= if ($total -gt 0) { [math]::Round(($used/$total)*100,1) } else { 0 }
    Root=$_.Root
  }
} | Sort-Object PctUsed -Descending
