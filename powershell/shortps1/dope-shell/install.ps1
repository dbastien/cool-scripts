param(
  [string]$TargetDir = (Join-Path $env:USERPROFILE "psbin"),
  [string[]]$Exclude = @(),
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$shortPs1Root = Split-Path -Parent $here

$common = Join-Path $shortPs1Root 'SharedLibs\ShortCommon.ps1'
if (Test-Path -LiteralPath $common) { . $common }

$dopecli = Join-Path $shortPs1Root 'dopecli'
if (-not (Test-Path -LiteralPath $dopecli -PathType Container)) {
  throw "dopecli folder not found next to dope-shell: $dopecli"
}

New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

$targetResolved = $null
try { $targetResolved = (Resolve-Path $TargetDir).Path } catch { }

# Flatten dopecli/*.ps1 plus shell helpers (quote + aliases) into psbin; skip paths under TargetDir.
$dopeFiles = Get-ChildItem -LiteralPath $dopecli -Filter "*.ps1" -File -Recurse | Where-Object {
  (-not $targetResolved -or (-not $_.FullName.StartsWith($targetResolved, [System.StringComparison]::OrdinalIgnoreCase)))
}
$extraPaths = @(
  (Join-Path $here 'QuoteOfDay.ps1')
  (Join-Path $here 'ShortPs1Prompt.ps1')
  (Join-Path $shortPs1Root 'SharedLibs\ShellAliases.ps1')
)
$extraFiles = foreach ($p in $extraPaths) {
  if (Test-Path -LiteralPath $p) { Get-Item -LiteralPath $p }
}
$allPs1 = @($dopeFiles + @($extraFiles)) | Where-Object { $_ }

$skipNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($x in $Exclude) {
  if ([string]::IsNullOrWhiteSpace($x)) { continue }
  $n = $x.Trim()
  if (-not $n.EndsWith('.ps1', [StringComparison]::OrdinalIgnoreCase)) { $n = $n + '.ps1' }
  [void]$skipNames.Add($n)
}
$allPs1 = @($allPs1 | Where-Object { -not $skipNames.Contains($_.Name) })

if (-not $allPs1) {
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "No .ps1 files found under: $dopecli" Warn
  } else {
    Write-Host "No .ps1 files found under: $dopecli"
  }
  exit 0
}

# Detect filename collisions (two different paths both contain same script name)
$collisions = $allPs1 | Group-Object Name | Where-Object { $_.Count -gt 1 }
if ($collisions -and (-not $Force)) {
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "Name collisions detected (same .ps1 name in multiple folders)." Err
    Write-ShortPs1Msg "Rename files or re-run with -Force (last one wins):" Warn
  } else {
    Write-Host "Name collisions detected (same .ps1 name in multiple folders)."
    Write-Host "Rename files or re-run with -Force (last one wins):"
  }
  Write-Host ""
  foreach ($g in $collisions) {
    Write-Host "  $($g.Name):"
    foreach ($f in $g.Group) { Write-Host "    - $($f.FullName)" }
  }
  throw "Aborting due to collisions."
}

# Install by flattening into TargetDir (PATH-friendly)
foreach ($f in $allPs1) {
  $dst = Join-Path $TargetDir $f.Name

  if ((Test-Path $dst) -and (-not $Force)) {
    if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
      Write-ShortPs1Msg "Skip (exists): $($f.Name)" Muted
    } else {
      Write-Host "Skip (exists): $($f.Name)"
    }
    continue
  }

  Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    $suffix = if ($Force) { " (overwrite)" } else { "" }
    Write-ShortPs1Msg "Installed${suffix}: $($f.Name)" Ok
  } else {
    Write-Host ("Installed{0}: {1}" -f ($(if ($Force) { " (overwrite)" } else { "" })), $f.Name)
  }
}

# Add TargetDir to User PATH (HKCU:\Environment\Path) if not present
$envKey = "HKCU:\Environment"
$currentPath = (Get-ItemProperty -Path $envKey -Name Path -ErrorAction SilentlyContinue).Path
if (-not $currentPath) { $currentPath = "" }

$parts = $currentPath -split ";" | Where-Object { $_ -and $_.Trim() -ne "" }
$already = $parts | Where-Object { $_.TrimEnd("\") -ieq $TargetDir.TrimEnd("\") }

if (-not $already) {
  $newPath = ($parts + $TargetDir) -join ";"
  Set-ItemProperty -Path $envKey -Name Path -Value $newPath
  $env:Path = $newPath + ";" + $env:Path
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "Added to User PATH: $TargetDir" Ok
  } else {
    Write-Host "Added to User PATH: $TargetDir"
  }
} else {
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "User PATH already contains: $TargetDir" Info
  } else {
    Write-Host "User PATH already contains: $TargetDir"
  }
}

# Seed quotes for Show-ShortPs1QuoteOfDay if missing (dope-shell bundle only)
$quotesDataDir = Join-Path $env:USERPROFILE '.local\share\shortps1'
$quotesDest = Join-Path $quotesDataDir 'quotes.txt'
if (-not (Test-Path -LiteralPath $quotesDest)) {
  $bundledQuotes = Join-Path $here 'quotes.default.txt'
  if (Test-Path -LiteralPath $bundledQuotes) {
    New-Item -ItemType Directory -Path $quotesDataDir -Force | Out-Null
    Copy-Item -LiteralPath $bundledQuotes -Destination $quotesDest -Force
    if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
      Write-ShortPs1Msg "Seeded quotes: $quotesDest" Ok
    } else {
      Write-Host "Seeded quotes: $quotesDest"
    }
  }
}

# Sidecar prompt config for ShortPs1Prompt.ps1 (psbin\prompt.config.toml) if missing
$promptBundled = Join-Path $here 'prompt.config.default.toml'
$promptDest = Join-Path $TargetDir 'prompt.config.toml'
if ((Test-Path -LiteralPath $promptBundled) -and (-not (Test-Path -LiteralPath $promptDest))) {
  Copy-Item -LiteralPath $promptBundled -Destination $promptDest -Force
  if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
    Write-ShortPs1Msg "Seeded prompt config: $promptDest" Ok
  } else {
    Write-Host "Seeded prompt config: $promptDest"
  }
}

Write-Host ""
if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
  Write-ShortPs1Msg "Done." Ok
  Write-ShortPs1Msg "If scripts won't run, set:  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned" Info
  Write-ShortPs1Msg "Open a new PowerShell window so PATH changes apply everywhere." Muted
} else {
  Write-Host "Done."
  Write-Host "If scripts won't run, set:  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
  Write-Host "Open a new PowerShell window so PATH changes apply everywhere."
}
