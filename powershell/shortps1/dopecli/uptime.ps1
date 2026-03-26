# Prints a GNU-ish uptime line. Load average is N/A on Windows.

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'SharedLibs\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

function Format-Up([TimeSpan]$ts) {
  if ($ts.TotalDays -ge 1) {
    $days = [int]$ts.TotalDays
    $hm = "{0}:{1:00}" -f $ts.Hours, $ts.Minutes
    return "$days day$([string]::Copy('s') * [int]($days -ne 1)), $hm"
  }
  return "{0}:{1:00}" -f $ts.Hours, $ts.Minutes
}

Initialize-ShortPs1Host
$now = Get-Date
$os = Get-CimInstance Win32_OperatingSystem
$boot = $os.LastBootUpTime
$up = $now - $boot

$userCount = 0
try {
  $q = (& quser 2>$null)
  if ($q) { $userCount = ($q | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" }).Count }
} catch { }

$timeStr = $now.ToString("HH:mm:ss")
$upStr = Format-Up $up
$line = "$timeStr up $upStr,  $userCount users,  load average: N/A"

if ($script:ShortPs1UseColor) {
  Write-Host "`u{23F1} " -NoNewline -ForegroundColor Cyan
  Write-Host $timeStr -NoNewline -ForegroundColor White
  Write-Host " up " -NoNewline -ForegroundColor DarkGray
  Write-Host $upStr -NoNewline -ForegroundColor Green
  Write-Host ",  $userCount users,  load average: " -NoNewline -ForegroundColor DarkGray
  Write-Host "N/A" -ForegroundColor Yellow
} else {
  Write-Output $line
}
