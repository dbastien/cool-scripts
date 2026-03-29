[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline = $true)]
  $InputObject,

  [Alias("l")]
  [switch]$Lines,

  [Alias("w")]
  [switch]$Words,

  [Alias("c")]
  [switch]$Bytes,

  [Alias("m")]
  [switch]$Chars,

  [Alias("ml")]
  [switch]$MaxLineLength,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Path
)

begin {
  $__sp = $PSScriptRoot
  if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
  $__root = Split-Path $__sp -Parent
  $__common = Join-Path $__root 'lib\common.ps1'
  if (Test-Path -LiteralPath $__common) { . $__common }

  $script:ToastyWcTargets = @()
  $script:ToastyWcPiped = @()
  $script:ToastyWcAnyFlag = $Lines -or $Words -or $Bytes -or $Chars -or $MaxLineLength
}

process {
  if ($null -ne $InputObject) { $script:ToastyWcPiped += $InputObject }
}

end {
  if ($Path) { $script:ToastyWcTargets += $Path }

  function Count-Text([string]$text, [string]$label) {
    $lineCount = 0
    if ($text.Length -gt 0) {
      $lineCount = ([regex]::Matches($text, "`n")).Count
    }
    $wordCount = ([regex]::Matches($text, '\S+')).Count
    $charCount = $text.Length
    $byteCount = [System.Text.Encoding]::UTF8.GetByteCount($text)
    $maxLen = 0
    foreach ($ln in ($text -split "`n", -1)) {
      $t = $ln.TrimEnd("`r")
      if ($t.Length -gt $maxLen) { $maxLen = $t.Length }
    }

    $cols = @()
    if (-not $script:ToastyWcAnyFlag -or $Lines) { $cols += $lineCount }
    if (-not $script:ToastyWcAnyFlag -or $Words) { $cols += $wordCount }
    if (-not $script:ToastyWcAnyFlag -or $Bytes) { $cols += $byteCount }
    if ($script:ToastyWcAnyFlag -and $Chars) { $cols += $charCount }
    if ($MaxLineLength) { $cols += $maxLen }

    if ($label) { $cols += $label }
    ($cols -join " ")
  }

  if ($script:ToastyWcTargets.Count -gt 0) {
    foreach ($p in $script:ToastyWcTargets) {
      if (-not (Test-Path -LiteralPath $p)) {
        if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
          Write-ToastyMsg "wc: not found: $p" Err
        } else {
          Write-Error "wc: not found: $p"
        }
        continue
      }
      $text = Get-Content -LiteralPath $p -Raw -ErrorAction Stop
      Count-Text $text $p
    }
    return
  }

  if ($script:ToastyWcPiped.Count -gt 0) {
    $text = ($script:ToastyWcPiped | ForEach-Object { $_.ToString() }) -join "`n"
    Count-Text $text ""
  }
}