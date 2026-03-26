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
  $__common = Join-Path $__root 'SharedLibs\ShortCommon.ps1'
  if (Test-Path -LiteralPath $__common) { . $__common }

  $script:ShortPs1WcTargets = @()
  $script:ShortPs1WcPiped = @()
  $script:ShortPs1WcAnyFlag = $Lines -or $Words -or $Bytes -or $Chars -or $MaxLineLength
}

process {
  if ($null -ne $InputObject) { $script:ShortPs1WcPiped += $InputObject }
}

end {
  if ($Path) { $script:ShortPs1WcTargets += $Path }

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
    if (-not $script:ShortPs1WcAnyFlag -or $Lines) { $cols += $lineCount }
    if (-not $script:ShortPs1WcAnyFlag -or $Words) { $cols += $wordCount }
    if (-not $script:ShortPs1WcAnyFlag -or $Bytes) { $cols += $byteCount }
    if ($script:ShortPs1WcAnyFlag -and $Chars) { $cols += $charCount }
    if ($MaxLineLength) { $cols += $maxLen }

    if ($label) { $cols += $label }
    ($cols -join " ")
  }

  if ($script:ShortPs1WcTargets.Count -gt 0) {
    foreach ($p in $script:ShortPs1WcTargets) {
      if (-not (Test-Path -LiteralPath $p)) {
        if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
          Write-ShortPs1Msg "wc: not found: $p" Err
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

  if ($script:ShortPs1WcPiped.Count -gt 0) {
    $text = ($script:ShortPs1WcPiped | ForEach-Object { $_.ToString() }) -join "`n"
    Count-Text $text ""
  }
}