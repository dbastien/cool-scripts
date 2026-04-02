# PhotonToaster "did you mean?" handler — suggests similar commands on typos.
# Requires PowerShell 7.4+ for CommandNotFoundAction; silently skips on older versions.

$global:_ptCmdCache = $null

function _pt_levenshtein([string]$s, [string]$t) {
  $n = $s.Length; $m = $t.Length
  if ($n -eq 0) { return $m }
  if ($m -eq 0) { return $n }
  $d = [int[,]]::new($n + 1, $m + 1)
  for ($i = 0; $i -le $n; $i++) { $d[$i, 0] = $i }
  for ($j = 0; $j -le $m; $j++) { $d[0, $j] = $j }
  for ($i = 1; $i -le $n; $i++) {
    $sc = $s[$i - 1]
    for ($j = 1; $j -le $m; $j++) {
      $cost = if ($sc -eq $t[$j - 1]) { 0 } else { 1 }
      $del = $d[($i - 1), $j] + 1
      $ins = $d[$i, ($j - 1)] + 1
      $sub = $d[($i - 1), ($j - 1)] + $cost
      $min = $del; if ($ins -lt $min) { $min = $ins }; if ($sub -lt $min) { $min = $sub }
      $d[$i, $j] = $min
    }
  }
  return $d[$n, $m]
}

function _pt_get_cmd_names {
  if ($null -eq $global:_ptCmdCache) {
    $global:_ptCmdCache = @(Get-Command -Type All -ErrorAction SilentlyContinue |
      ForEach-Object { $_.Name } | Sort-Object -Unique)
  }
  return $global:_ptCmdCache
}

function _pt_invalidate_cmd_cache {
  $global:_ptCmdCache = $null
}

function _pt_find_suggestions([string]$typo, [int]$maxResults = 6) {
  $names = _pt_get_cmd_names
  $tLen = $typo.Length
  $tLower = $typo.ToLowerInvariant()
  $tFirst = if ($tLen -gt 0) { $tLower[0] } else { $null }
  $results = [System.Collections.Generic.List[object]]::new()

  foreach ($name in $names) {
    $nLen = $name.Length
    $lenDelta = [Math]::Abs($nLen - $tLen)
    if ($lenDelta -gt 3) { continue }
    $nLower = $name.ToLowerInvariant()
    if ($nLower -eq $tLower) { continue }

    $dist = _pt_levenshtein $tLower $nLower
    $prefix = if ($tFirst -and $nLower.Length -gt 0 -and $nLower[0] -eq $tFirst) { 1 } else { 0 }
    $hasSub = ($nLower.Contains($tLower) -or $tLower.Contains($nLower))

    if ($dist -le 2 -or $hasSub -or ($prefix -and $dist -le 3)) {
      $score = $dist * 10 + $lenDelta * 2 - $prefix - $(if ($hasSub) { 2 } else { 0 })
      $results.Add([PSCustomObject]@{ Name = $name; Score = $score })
    }
  }

  return @($results | Sort-Object Score | Select-Object -First $maxResults -ExpandProperty Name)
}

if ($PSVersionTable.PSVersion -ge [version]'7.4') {
  $ExecutionContext.InvokeCommand.CommandNotFoundAction = {
    param([string]$name, [System.Management.Automation.CommandLookupEventArgs]$lookupArgs)

    $e = [char]0x1B
    $err  = "${e}[38;2;255;90;90m"
    $warn = "${e}[38;2;255;220;60m"
    $vio  = "${e}[38;2;150;125;255m"
    $rst  = "${e}[0m"
    $bold = "${e}[1m"

    $suggestions = _pt_find_suggestions $name
    Write-Host "${err}`u{F00D} command not found:${rst} ${bold}${name}${rst}" -NoNewline:$false

    if ($suggestions.Count -gt 0) {
      Write-Host "${warn}`u{F071} maybe one of these:${rst}"
      foreach ($s in $suggestions) {
        Write-Host "  ${vio}`u{E0B1}${rst} $s"
      }
    }
  }
}
