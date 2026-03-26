param(
    [Alias("a")]
    [switch]$All
)

# A compact, readable "ps-ish" table.
# Note: CPU is cumulative seconds since process start.

$procs = Get-Process | Sort-Object -Property CPU -Descending
$procs | Select-Object `
    @{Name="PID";Expression={$_.Id}}, `
    @{Name="CPU(s)";Expression={ if ($_.CPU) { [Math]::Round($_.CPU,2) } else { 0 } }}, `
    @{Name="WS(MB)";Expression={ [Math]::Round($_.WorkingSet64/1MB,1) }}, `
    @{Name="PM(MB)";Expression={ [Math]::Round($_.PagedMemorySize64/1MB,1) }}, `
    @{Name="Start";Expression={ try { $_.StartTime.ToString("yyyy-MM-dd HH:mm") } catch { "" } }}, `
    @{Name="Name";Expression={$_.ProcessName}} `
    | Format-Table -AutoSize
