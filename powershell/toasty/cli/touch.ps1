param(
  [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
  [string[]]$Path,

  [Alias("c")]
  [switch]$NoCreate,

  [Alias("r")]
  [string]$Reference,

  [Alias("t")]
  [string]$Time
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

function Parse-TouchTime([string]$s) {
  if ($s -match '^\d{12}(\.\d{2})?$') {
    $base = $s.Substring(0, 12)
    $dt = [datetime]::ParseExact($base, 'yyyyMMddHHmm', $null)
    if ($s -match '\.(\d{2})$') {
      $dt = $dt.AddSeconds([int]$Matches[1])
    }
    return $dt
  }
  return [datetime]::Parse($s)
}

$stamp = $null
if ($Reference) {
  if (-not (Test-Path -LiteralPath $Reference)) {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg "touch: reference file not found: $Reference" Err
    }
    throw "touch: reference file not found: $Reference"
  }
  $stamp = (Get-Item -LiteralPath $Reference).LastWriteTime
} elseif ($Time) {
  $stamp = Parse-TouchTime $Time
} else {
  $stamp = Get-Date
}

foreach ($p in $Path) {
  if (Test-Path -LiteralPath $p) {
    $item = Get-Item -LiteralPath $p -ErrorAction Stop
    $item.LastWriteTime = $stamp
  } else {
    if (-not $NoCreate) {
      [void][System.IO.File]::Create($p).Dispose()
      (Get-Item -LiteralPath $p).LastWriteTime = $stamp
    }
  }
}