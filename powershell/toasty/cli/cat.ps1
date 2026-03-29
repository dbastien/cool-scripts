param(
  [Alias("n")]
  [switch]$Number,

  [Alias("A")]
  [switch]$ShowEnds,

  [Parameter(ValueFromPipeline = $true)]
  $InputObject,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Path
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

begin {
  $sawPipe = $false
  $lineNo = 1
  function Emit-Lines([string]$text) {
    $lines = $text -split "`n", -1
    foreach ($ln in $lines) {
      $out = $ln.TrimEnd("`r")
      if ($ShowEnds) { $out = $out + '$' }
      if ($Number) {
        "{0,6}  {1}" -f $lineNo, $out
        $lineNo++
      } else {
        $out
      }
    }
  }
}

process {
  if ($null -ne $InputObject) {
    $sawPipe = $true
    Emit-Lines ($InputObject.ToString())
  }
}

end {
  if ($Path -and $Path.Count -gt 0) {
    foreach ($p in $Path) {
      if (-not (Test-Path -LiteralPath $p)) {
        if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
          Write-ToastyMsg "cat: not found: $p" Err
        } else {
          Write-Error "cat: not found: $p"
        }
        continue
      }
      $text = Get-Content -LiteralPath $p -Raw -ErrorAction Stop
      Emit-Lines $text
    }
  } elseif (-not $sawPipe) {
    # No args, no pipeline: same as GNU cat with no tty (no-op here).
  }
}