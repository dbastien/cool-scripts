# Prints a GNU-ish uptime line. Load average is N/A on Windows.

function Format-Up([TimeSpan]$ts) {
    if ($ts.TotalDays -ge 1) {
        $days = [int]$ts.TotalDays
        $hm = "{0}:{1:00}" -f $ts.Hours, $ts.Minutes
        return "$days day$([string]::Copy('s') * [int]($days -ne 1)), $hm"
    }
    return "{0}:{1:00}" -f $ts.Hours, $ts.Minutes
}

$now = Get-Date
$os = Get-CimInstance Win32_OperatingSystem
$boot = $os.LastBootUpTime
$up = $now - $boot

# User count (best effort)
$userCount = 0
try {
    $q = (& quser 2>$null)
    if ($q) { $userCount = ($q | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" }).Count }
} catch { }

$timeStr = $now.ToString("HH:mm:ss")
$upStr = Format-Up $up

"$timeStr up $upStr,  $userCount users,  load average: N/A"
