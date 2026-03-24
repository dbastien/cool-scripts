param(
  [Parameter(Position=0)] [string]$Pattern,
  [Alias("i")] [switch]$IgnoreCase,
  [Alias("n")] [switch]$LineNumber,
  [Alias("v")] [switch]$Invert,
  [Parameter(Position=1, ValueFromRemainingArguments=$true)] [string[]]$Path
)

$caseSensitive = -not $IgnoreCase

if ($Invert) {
  function Emit-Invert([string]$text, [string]$label) {
    $ln = 0
    foreach ($line in ($text -split "`n", -1)) {
      $ln++
      $t = $line.TrimEnd("`r")
      $isMatch = $caseSensitive ? ($t -cmatch $Pattern) : ($t -match $Pattern)
      if (-not $isMatch) {
        if ($LineNumber) { if ($label) { "$label:$ln:$t" } else { "$ln:$t" } }
        else { if ($label) { "$label:$t" } else { $t } }
      }
    }
  }

  if ($Path -and $Path.Count -gt 0) {
    foreach ($p in $Path) {
      $text = Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue
      if ($null -ne $text) { Emit-Invert $text $p }
    }
  } else {
    $text = ($input | ForEach-Object { $_.ToString() }) -join "`n"
    Emit-Invert $text ""
  }
  return
}

if ($Path -and $Path.Count -gt 0) {
  Select-String -Pattern $Pattern -Path $Path -CaseSensitive:$caseSensitive
} else {
  $input | Select-String -Pattern $Pattern -CaseSensitive:$caseSensitive
}
