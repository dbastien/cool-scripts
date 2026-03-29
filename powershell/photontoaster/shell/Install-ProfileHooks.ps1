# Appends marked blocks to your PowerShell profile (quote of the day, optional ShortPs1 prompt).
# Run from repo:  pwsh -File .\powershell\photontoaster\shell\Install-ProfileHooks.ps1
# Remove quote:    .\powershell\photontoaster\shell\Install-ProfileHooks.ps1 -Remove
# Remove prompt:   .\powershell\photontoaster\shell\Install-ProfileHooks.ps1 -RemovePrompt
# Add prompt:      .\powershell\photontoaster\shell\Install-ProfileHooks.ps1 -DopeShellPrompt
# Prompt only:     .\powershell\photontoaster\shell\Install-ProfileHooks.ps1 -DopeShellPrompt -SkipQuote

param(
  [string]$TargetDir = (Join-Path $env:USERPROFILE 'psbin'),
  [string]$ProfilePath = $PROFILE,
  [switch]$WhatIf,
  [switch]$Remove,
  [switch]$RemovePrompt,
  [switch]$DopeShellPrompt,
  [switch]$SkipQuote
)

$ErrorActionPreference = 'Stop'

$startMarker = '# >>> shortps1-quote >>>'
$endMarker = '# <<< shortps1-quote <<<'

$block = @"
$startMarker
`$__shortps1Quote = Join-Path '$($TargetDir.Replace("'", "''"))' 'QuoteOfDay.ps1'
if (Test-Path -LiteralPath `$__shortps1Quote) {
  . `$__shortps1Quote
  if (Get-Command Show-ShortPs1QuoteOfDay -ErrorAction SilentlyContinue) {
    Show-ShortPs1QuoteOfDay
  }
}
Remove-Variable __shortps1Quote -ErrorAction SilentlyContinue
$endMarker
"@

$promptStart = '# >>> shortps1-dope-prompt >>>'
$promptEnd = '# <<< shortps1-dope-prompt <<<'
$legacyPromptStart = '# >>> shortps1-pt-prompt >>>'
$legacyPromptEnd = '# <<< shortps1-pt-prompt <<<'

$promptBlock = @"
$promptStart
`$__shortps1DopePrompt = Join-Path '$($TargetDir.Replace("'", "''"))' 'ShortPs1Prompt.ps1'
if (Test-Path -LiteralPath `$__shortps1DopePrompt) { . `$__shortps1DopePrompt }
Remove-Variable __shortps1DopePrompt -ErrorAction SilentlyContinue
$promptEnd
"@

function Read-ProfileText([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return '' }
  return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8)
}

function Write-ProfileText([string]$Path, [string]$Text) {
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  Set-Content -LiteralPath $Path -Value $Text -Encoding UTF8 -NoNewline
}

function Strip-ProfileBlock([string]$Text, [string]$Start, [string]$End) {
  $pattern = '(?ms)^\s*' + [regex]::Escape($Start) + '\s*.*?' + [regex]::Escape($End) + '\s*'
  return ([regex]::Replace($Text, $pattern, '')).TrimEnd()
}

$current = Read-ProfileText $ProfilePath

if ($RemovePrompt) {
  $stripped = Strip-ProfileBlock $current $legacyPromptStart $legacyPromptEnd
  $stripped = Strip-ProfileBlock $stripped $promptStart $promptEnd
  if ($WhatIf) {
    Write-Host "WhatIf: would strip shortps1 prompt blocks from: $ProfilePath"
  } else {
    Write-ProfileText $ProfilePath $stripped
    Write-Host "Removed shortps1 prompt block(s) from: $ProfilePath"
  }
  $current = $stripped
  if (-not $Remove) { exit 0 }
}

if ($Remove) {
  $stripped = Strip-ProfileBlock $current $startMarker $endMarker
  if ($WhatIf) {
    Write-Host "WhatIf: would strip shortps1-quote block from: $ProfilePath"
    exit 0
  }
  Write-ProfileText $ProfilePath $stripped
  Write-Host "Removed shortps1-quote block from: $ProfilePath"
  exit 0
}

if (-not $SkipQuote) {
  if ($current -notmatch [regex]::Escape($startMarker)) {
    $base = $current.TrimEnd()
    $next = if ($base) { $base + "`r`n`r`n" + $block + "`r`n" } else { $block + "`r`n" }
    if ($WhatIf) {
      Write-Host "WhatIf: would append shortps1-quote block to: $ProfilePath"
    } else {
      Write-ProfileText $ProfilePath $next
      Write-Host "Appended quote-of-the-day hook to: $ProfilePath"
      Write-Host "Ensure quotes exist at ~/.local/share/shortps1/quotes.txt (photontoaster Install-PsBin.ps1 seeds when missing)."
    }
  } else {
    Write-Host "Profile already contains shortps1-quote block: $ProfilePath"
  }
}

if (-not $DopeShellPrompt) { exit 0 }

$cur = Read-ProfileText $ProfilePath
if ($cur -match [regex]::Escape($promptStart)) {
  Write-Host "Profile already contains shortps1-dope-prompt block: $ProfilePath"
  exit 0
}
$base = $cur.TrimEnd()
$add = if ($base) { $base + "`r`n`r`n" + $promptBlock + "`r`n" } else { $promptBlock + "`r`n" }
if ($WhatIf) {
  Write-Host "WhatIf: would append shortps1-dope-prompt block to: $ProfilePath"
  exit 0
}
Write-ProfileText $ProfilePath $add
Write-Host "Appended ShortPs1 prompt (ShortPs1Prompt.ps1) to: $ProfilePath"
Write-Host "Config: %USERPROFILE%\.config\dopeshell\config.toml or psbin\prompt.config.toml (see README)."
