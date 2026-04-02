[CmdletBinding()]
param(
  [int]$n = 20,
  [int]$s = 2,
  [ValidateSet("cpu", "mem")] [string]$Sort = "cpu",
  [switch]$Once,
  [switch]$All
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

function Get-TopRows {
  $p = Get-Process -ErrorAction SilentlyContinue
  $p | Select-Object Id, Name,
    @{n = "CPU"; e = { $_.CPU } },
    @{n = "WS(MB)"; e = { [math]::Round($_.WorkingSet64 / 1MB, 1) } },
    @{n = "PM(MB)"; e = { [math]::Round($_.PagedMemorySize64 / 1MB, 1) } },
    @{n = "Handles"; e = { $_.Handles } },
    @{n = "Threads"; e = { $_.Threads.Count } },
    @{n = "Title"; e = { if ($All) { $_.MainWindowTitle } else { "" } } }
}

do {
  Clear-Host
  if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
    Write-PTMsg ("`u{1F4CA} top  sort=$Sort  n=$n  refresh=${s}s") Accent
  }
  Write-Host (Get-Date)
  $top = Get-TopRows
  if ($Sort -eq "mem") { $top = $top | Sort-Object "WS(MB)" -Descending | Select-Object -First $n }
  else { $top = $top | Sort-Object CPU -Descending | Select-Object -First $n }
  if ($All) { $top | Format-Table -AutoSize Id, Name, CPU, "WS(MB)", "PM(MB)", Handles, Threads, Title }
  else { $top | Format-Table -AutoSize Id, Name, CPU, "WS(MB)", "PM(MB)", Handles, Threads }
  if (-not $Once) { Start-Sleep -Seconds $s }
} while (-not $Once)