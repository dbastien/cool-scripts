# Adds a single Toasty init line to your PowerShell profile.
# Run:  pwsh -File .\powershell\toasty\shell\install-profile.ps1
# Remove:  .\powershell\toasty\shell\install-profile.ps1 -Remove
# WhatIf:  .\powershell\toasty\shell\install-profile.ps1 -WhatIf

param(
  [string]$ProfilePath = $PROFILE,
  [switch]$WhatIf,
  [switch]$Remove
)

$ErrorActionPreference = 'Stop'

$startMarker = '# >>> toasty >>>'
$endMarker = '# <<< toasty <<<'

$configDir = if ($env:TOASTY_CONFIG_DIR) { $env:TOASTY_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.config\toasty' }
$initPath = Join-Path $configDir 'shell\init.ps1'

$block = @"
$startMarker
`$__toastyInit = '$($initPath.Replace("'", "''"))'
if (Test-Path -LiteralPath `$__toastyInit) { . `$__toastyInit }
Remove-Variable __toastyInit -ErrorAction SilentlyContinue
$endMarker
"@

# Also strip legacy marker blocks from previous installs
$legacyMarkers = @(
  @('# >>> shortps1-quote >>>', '# <<< shortps1-quote <<<'),
  @('# >>> shortps1-dope-prompt >>>', '# <<< shortps1-dope-prompt <<<'),
  @('# >>> shortps1-pt-prompt >>>', '# <<< shortps1-pt-prompt <<<')
)

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

function Strip-Block([string]$Text, [string]$Start, [string]$End) {
  $pattern = '(?ms)^\s*' + [regex]::Escape($Start) + '\s*.*?' + [regex]::Escape($End) + '\s*'
  return ([regex]::Replace($Text, $pattern, '')).TrimEnd()
}

$current = Read-ProfileText $ProfilePath

# Strip legacy blocks
foreach ($pair in $legacyMarkers) {
  $current = Strip-Block $current $pair[0] $pair[1]
}

if ($Remove) {
  $stripped = Strip-Block $current $startMarker $endMarker
  if ($WhatIf) {
    Write-Host "WhatIf: would strip toasty block from: $ProfilePath"
    exit 0
  }
  Write-ProfileText $ProfilePath $stripped
  Write-Host "Removed toasty block from: $ProfilePath"
  exit 0
}

if ($current -match [regex]::Escape($startMarker)) {
  Write-Host "Profile already contains toasty block: $ProfilePath"
  exit 0
}

$base = $current.TrimEnd()
$next = if ($base) { $base + "`r`n`r`n" + $block + "`r`n" } else { $block + "`r`n" }
if ($WhatIf) {
  Write-Host "WhatIf: would append toasty init block to: $ProfilePath"
  exit 0
}
Write-ProfileText $ProfilePath $next
Write-Host "Appended toasty init block to: $ProfilePath"
Write-Host "Config: $configDir\config.toml (or edit config.toml.default in the repo)."
