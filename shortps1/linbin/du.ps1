param([string]$Root=".")

if (Test-Path -LiteralPath $Root -PathType Leaf) {
  $bytes = (Get-Item -LiteralPath $Root -ErrorAction SilentlyContinue).Length
  if ($null -eq $bytes) { $bytes = 0 }
  [pscustomobject]@{ Path=(Resolve-Path -LiteralPath $Root).Path; MiB=[math]::Round(($bytes/1MB),2) }
  return
}

Get-ChildItem -LiteralPath $Root -Directory -Force -ErrorAction SilentlyContinue |
  ForEach-Object {
    $bytes = (Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
      Measure-Object Length -Sum).Sum
    if ($null -eq $bytes) { $bytes = 0 }
    [pscustomobject]@{ Path=$_.FullName; MiB=[math]::Round(($bytes/1MB),2) }
  } | Sort-Object MiB -Descending
