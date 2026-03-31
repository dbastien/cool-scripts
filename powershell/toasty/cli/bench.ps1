<#
.SYNOPSIS
Benchmark PowerShell startup time (with and without Toasty profile).
.DESCRIPTION
Uses hyperfine when available; falls back to a pure PowerShell Stopwatch loop.
Shows the delta between a bare pwsh and pwsh+Toasty to quantify profile overhead.
.EXAMPLE
bench
bench -Runs 20
bench -Json results.json
#>
param(
  [int]$Runs = 10,
  [int]$Warmup = 3,
  [string]$Json
)

$ErrorActionPreference = 'Stop'
$pwsh = (Get-Process -Id $PID).Path

if (Get-Command hyperfine -ErrorAction SilentlyContinue) {
  $args_ = @(
    '--warmup', $Warmup,
    '--min-runs', $Runs,
    '-n', 'pwsh+toasty', "$pwsh -i -c exit",
    '-n', 'pwsh bare',   "$pwsh -NoProfile -c exit"
  )
  if ($Json) { $args_ += @('--export-json', $Json) }
  & hyperfine @args_
} else {
  function _bench_loop([string]$label, [string[]]$cmdArgs, [int]$runs, [int]$warmup) {
    Write-Host "Benchmarking: $label" -ForegroundColor Cyan
    for ($w = 0; $w -lt $warmup; $w++) {
      & $pwsh @cmdArgs | Out-Null
    }
    $times = [System.Collections.Generic.List[double]]::new()
    for ($i = 0; $i -lt $runs; $i++) {
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      & $pwsh @cmdArgs | Out-Null
      $sw.Stop()
      $times.Add($sw.Elapsed.TotalMilliseconds)
      Write-Host "  Run $($i+1): $([math]::Round($sw.Elapsed.TotalMilliseconds))ms" -ForegroundColor DarkGray
    }
    $mean = ($times | Measure-Object -Average).Average
    $min  = ($times | Measure-Object -Minimum).Minimum
    $max  = ($times | Measure-Object -Maximum).Maximum
    $variance = ($times | ForEach-Object { ($_ - $mean) * ($_ - $mean) } | Measure-Object -Average).Average
    $stddev = [math]::Sqrt($variance)
    [PSCustomObject]@{
      Label  = $label
      Mean   = [math]::Round($mean, 1)
      StdDev = [math]::Round($stddev, 1)
      Min    = [math]::Round($min, 1)
      Max    = [math]::Round($max, 1)
      Runs   = $runs
    }
  }

  $profile_ = _bench_loop 'pwsh+toasty' @('-i', '-c', 'exit') $Runs $Warmup
  Write-Host ''
  $bare = _bench_loop 'pwsh bare' @('-NoProfile', '-c', 'exit') $Runs $Warmup
  Write-Host ''

  $e = [char]0x1B
  Write-Host "${e}[1mResults:${e}[0m"
  @($profile_, $bare) | Format-Table -AutoSize
  $delta = [math]::Round($profile_.Mean - $bare.Mean, 1)
  $color = if ($delta -lt 200) { '80;250;120' } elseif ($delta -lt 500) { '255;220;60' } else { '255;90;90' }
  Write-Host "${e}[38;2;${color}mToasty overhead: ${delta}ms${e}[0m"

  if ($Json) {
    @{ profile = $profile_; bare = $bare; delta_ms = $delta } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $Json -Encoding utf8
    Write-Host "Saved: $Json" -ForegroundColor DarkGray
  }
}
