param(
  [Parameter(Position = 0)] [string]$Pattern,
  [Alias("i")] [switch]$IgnoreCase,
  [Alias("n")] [switch]$LineNumber,
  [Alias("v")] [switch]$Invert,
  [Alias("q")] [switch]$Quiet,
  [Alias("E")] [switch]$ExtendedRegex,
  [Alias("F")] [switch]$FixedStrings,
  [Parameter(Position = 1, ValueFromRemainingArguments = $true)] [string[]]$Path
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'SharedLibs\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

$caseSensitive = -not $IgnoreCase
$hadMatch = $false

function Test-GrepLine {
  param([string]$t)
  if ($FixedStrings) {
    if ($caseSensitive) { return $t.Contains($Pattern) }
    return $t.ToLowerInvariant().Contains($Pattern.ToLowerInvariant())
  }
  if ($caseSensitive) { return ($t -cmatch $Pattern) }
  return ($t -match $Pattern)
}

if ($Invert) {
  if ($Path -and $Path.Count -gt 0) {
    foreach ($p in $Path) {
      if (-not (Test-Path -LiteralPath $p)) {
        if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
          Write-ShortPs1Msg "grep: not found: $p" Err
        } else {
          Write-Error "grep: not found: $p"
        }
        continue
      }
      $text = Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue
      if ($null -eq $text) { continue }
      $ln = 0
      foreach ($line in ($text -split "`n", -1)) {
        $ln++
        $t = $line.TrimEnd("`r")
        if (-not (Test-GrepLine $t)) {
          $hadMatch = $true
          if (-not $Quiet) {
            $fs = [char]0x1C
            if ($LineNumber) { "$p$fs$ln$fs$t" } else { "$p$fs$t" }
          }
        }
      }
    }
  } else {
    $text = @($input | ForEach-Object { $_.ToString() }) -join "`n"
    $ln = 0
    foreach ($line in ($text -split "`n", -1)) {
      $ln++
      $t = $line.TrimEnd("`r")
      if (-not (Test-GrepLine $t)) {
        $hadMatch = $true
        if (-not $Quiet) {
          if ($LineNumber) { "$ln`:$t" } else { $t }
        }
      }
    }
  }
  if (-not $hadMatch) { exit 1 }
  return
}

if ($Path -and $Path.Count -gt 0) {
  foreach ($p in $Path) {
    if (-not (Test-Path -LiteralPath $p)) {
      if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
        Write-ShortPs1Msg "grep: not found: $p" Err
      } else {
        Write-Error "grep: not found: $p"
      }
      continue
    }
    $sel = Get-Content -LiteralPath $p -ErrorAction SilentlyContinue | Select-String -Pattern $Pattern -CaseSensitive:$caseSensitive -SimpleMatch:$FixedStrings
    if ($sel) { $hadMatch = $true }
    if (-not $Quiet) { $sel }
  }
} else {
  $sel = $input | Select-String -Pattern $Pattern -CaseSensitive:$caseSensitive -SimpleMatch:$FixedStrings
  if ($sel) { $hadMatch = $true }
  if (-not $Quiet) { $sel }
}

if (-not $hadMatch) { exit 1 }