# Toasty enhanced history — atuin integration (tier 1) or PSReadLine tuning (tier 2).
# Also provides a `history` function for searching PSReadLine's history file.

param([hashtable]$Config = @{})

function _hist_cfg([string]$Key, [string]$Default) {
  if ($Config.ContainsKey($Key) -and $null -ne $Config[$Key] -and $Config[$Key] -ne '') { return [string]$Config[$Key] }
  return $Default
}

$_hasAtuin = (_hist_cfg 'general.atuin' 'true') -eq 'true' -and [bool](Get-Command atuin -ErrorAction SilentlyContinue)
$_hasFzf   = [bool](Get-Command fzf -ErrorAction SilentlyContinue)

# Tier 1: atuin takes over Ctrl+R when present
if ($_hasAtuin) {
  $env:ATUIN_NOBIND = '1'
  Invoke-Expression (& atuin init powershell | Out-String)
  Set-PSReadLineOption -PredictionSource None
}
# Tier 2: fzf handles history via fzf.ps1 (loaded separately); disable stale ghost text
elseif ($_hasFzf) {
  Set-PSReadLineOption -PredictionSource None
}
# Tier 3: no atuin, no fzf — PSReadLine history predictions are better than nothing
else {
  Set-PSReadLineOption -PredictionSource History
}

# `history` function — search PSReadLine's history file with filters
function global:history {
  param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [string[]]$Pattern,
    [Alias('n')][int]$Last = 0,
    [switch]$Unique
  )
  $histPath = (Get-PSReadLineOption).HistorySavePath
  if (-not (Test-Path -LiteralPath $histPath)) {
    Write-Warning "History file not found: $histPath"
    return
  }

  $lines = Get-Content -LiteralPath $histPath -Encoding utf8 | Where-Object { $_ -and $_.Trim() }

  if ($Pattern) {
    $pat = $Pattern -join ' '
    $lines = $lines | Where-Object { $_ -match [regex]::Escape($pat) }
  }

  if ($Unique) {
    $seen = @{}; $deduped = [System.Collections.Generic.List[string]]::new()
    foreach ($l in $lines) {
      $key = $l.Trim()
      if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $deduped.Add($l) }
    }
    $lines = $deduped
  }

  if ($Last -gt 0 -and $lines.Count -gt $Last) {
    $lines = $lines[($lines.Count - $Last)..($lines.Count - 1)]
  }

  $lines
}

Remove-Variable _hasAtuin, _hasFzf -ErrorAction SilentlyContinue
