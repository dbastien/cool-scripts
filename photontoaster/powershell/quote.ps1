# PhotonToaster quote of the day.
# One random quote per calendar day (stable for the day), cached under state dir.

function Show-PTQuote {
  [CmdletBinding()]
  param(
    [string]$QuotesFile,
    [switch]$ForceRefresh
  )

  if ($env:PHOTONTOASTER_NO_QUOTE -eq '1') { return }

  if (-not $QuotesFile) {
    $QuotesFile = $env:PHOTONTOASTER_QUOTES_FILE
  }
  if (-not $QuotesFile) {
    $QuotesFile = Join-Path $env:USERPROFILE '.local\share\photontoaster\quotes.txt'
  }
  if (-not (Test-Path -LiteralPath $QuotesFile)) { return }

  $stateDir = if ($env:PHOTONTOASTER_STATE_DIR) { $env:PHOTONTOASTER_STATE_DIR } else { Join-Path $env:USERPROFILE '.local\state\photontoaster' }
  $cacheFile = Join-Path $stateDir 'quote-of-the-day'
  $today = (Get-Date).ToString('yyyy-MM-dd')

  if (-not $ForceRefresh -and (Test-Path -LiteralPath $cacheFile)) {
    try {
      $lines = Get-Content -LiteralPath $cacheFile -Encoding UTF8
      if ($lines.Count -ge 2 -and $lines[0] -eq $today -and -not [string]::IsNullOrWhiteSpace($lines[1])) {
        $quote = $lines[1].TrimEnd("`r")
        Write-PTQuoteLine $quote
        return
      }
    } catch { }
  }

  $candidates = Get-Content -LiteralPath $QuotesFile -Encoding UTF8 | ForEach-Object {
    $t = $_.TrimEnd("`r")
    if ($t -match '^\s*#' -or $t -match '^\s*$') { return }
    $t
  } | Where-Object { $_ }

  if (-not $candidates -or $candidates.Count -eq 0) { return }

  $quote = $candidates | Get-Random
  $null = New-Item -ItemType Directory -Path $stateDir -Force
  Set-Content -LiteralPath $cacheFile -Encoding UTF8 -Value @($today, $quote)
  Write-PTQuoteLine $quote
}

function Write-PTQuoteLine {
  param([Parameter(Mandatory)][string]$Quote)

  $icon = [System.Text.Encoding]::UTF8.GetString([byte[]](0xEF, 0x9C, 0x8D))
  $e = [char]0x1B
  $line = ('{0}[38;2;255;100;255m{1} {0}[38;2;245;245;255m{2}{0}[0m' -f $e, $icon, $Quote)
  Write-Host $line
}
