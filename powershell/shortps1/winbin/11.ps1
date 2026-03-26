<# 
Setup-BetterLs.ps1

- Adds "better ls/ll" to your PowerShell profile ($PROFILE)
- Features:
  - git status indicators (??, M, A, D, R, etc.)
  - icons
  - file extensions as a separate column (after name)
  - human-readable sizes with unit suffix (e.g. 30B, 1.2KB, 4.0MB)

Run:
  powershell -ExecutionPolicy Bypass -File .\Setup-BetterLs.ps1
#>

param(
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$startMarker = "# >>> better-ls >>>"
$endMarker   = "# <<< better-ls <<<"

$block = @'
# >>> better-ls >>>
# Better ls/ll with git status, icons, extensions, and human sizes.

function _bl_fsize([long]$b) {
  if ($b -lt 0) { return "" }
  if ($b -ge 1TB) { "{0:N1}TB" -f ($b/1TB) }
  elseif ($b -ge 1GB) { "{0:N1}GB" -f ($b/1GB) }
  elseif ($b -ge 1MB) { "{0:N1}MB" -f ($b/1MB) }
  elseif ($b -ge 1KB) { "{0:N1}KB" -f ($b/1KB) }
  else { "$b" + "B" }
}

function _bl_icon($item) {
  if ($item.PSIsContainer) { return "📁" }
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { return "🔗" }

  $ext = ($item.Extension ?? "").ToLowerInvariant()
  if ($ext -in ".exe",".bat",".cmd",".ps1",".sh") { return "⚙️" }
  if ($ext -in ".dll") { return "🧩" }
  if ($ext -in ".png",".jpg",".jpeg",".gif",".webp",".tga",".bmp") { return "🖼️" }
  if ($ext -in ".zip",".7z",".rar",".tar",".gz") { return "📦" }
  if ($ext -in ".md",".txt",".log") { return "📝" }
  if ($ext -in ".json",".yml",".yaml",".toml",".xml") { return "🧾" }
  if ($ext -in ".cs",".cpp",".c",".h",".hpp",".js",".ts",".py",".rs",".go") { return "💻" }
  return "📄"
}

function _bl_gitContext([string]$dir) {
  $ctx = [pscustomobject]@{ Top = ""; Map = @{} }
  try {
    $top = (& git -C $dir rev-parse --show-toplevel 2>$null).Trim()
    if (-not $top) { return $ctx }
    $ctx.Top = $top

    $map = @{}
    $lines = & git -C $dir status --porcelain 2>$null
    foreach ($ln in $lines) {
      if (-not $ln) { continue }
      $xy = $ln.Substring(0,2)
      $p = $ln.Substring(3)
      if ($p -match " -> ") { $p = ($p -split " -> " | Select-Object -Last 1) }
      $p = $p -replace "\\","/"
      $map[$p] = $xy
    }
    $ctx.Map = $map
  } catch { }
  return $ctx
}

function _bl_gitBadge([string]$xy) {
  if (-not $xy) { return "  " }
  if ($xy -match "^\?\?") { return "??" }
  if ($xy -match "R") { return "R " }
  if ($xy -match "D") { return "D " }
  if ($xy -match "A") { return "A " }
  if ($xy -match "M") { return "M " }
  return $xy
}

function _bl_relToRepo([string]$repoTop, [string]$fullPath) {
  if (-not $repoTop) { return "" }
  $repoTopNorm = ($repoTop.TrimEnd("\") + "\")
  if ($fullPath.Length -lt $repoTopNorm.Length) { return "" }
  if (-not $fullPath.StartsWith($repoTopNorm, [StringComparison]::OrdinalIgnoreCase)) { return "" }
  ($fullPath.Substring($repoTopNorm.Length) -replace "\\","/")
}

function ls {
  param([string]$Path=".")
  $dir = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  $git = _bl_gitContext $dir

  Get-ChildItem -LiteralPath $dir -Force |
    Sort-Object @{e={-not $_.PSIsContainer}}, Name |
    ForEach-Object {
      $rel = _bl_relToRepo $git.Top $_.FullName
      $badge = if ($rel) { _bl_gitBadge $git.Map[$rel] } else { "  " }
      $name = $_.BaseName
      $ext = if ($_.PSIsContainer) { "" } else { $_.Extension }
      "{0} {1} {2} {3}" -f $name, $ext, (_bl_icon $_), $badge
    }
}

function ll {
  param([string]$Path=".")
  $dir = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  $git = _bl_gitContext $dir

  Get-ChildItem -LiteralPath $dir -Force |
    Sort-Object @{e={-not $_.PSIsContainer}}, Name |
    Select-Object `
      @{n="Name";e={$_.BaseName}}, `
      @{n="Ext";e={ if ($_.PSIsContainer) { "" } else { $_.Extension } }}, `
      @{n="Icon";e={ _bl_icon $_ }}, `
      @{n="Git";e={
        $rel = _bl_relToRepo $git.Top $_.FullName
        if ($rel) { _bl_gitBadge $git.Map[$rel] } else { "  " }
      }}, `
      Mode, `
      @{n="Size";e={ if ($_.PSIsContainer) { "" } else { _bl_fsize $_.Length } }}, `
      @{n="Created";e={ $_.CreationTime.ToString("yyyy-MM-dd HH:mm") }}, `
      @{n="Modified";e={ $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm") }} |
    Format-Table -AutoSize
}
# <<< better-ls <<<
'@

function Write-ProfileBlock([string]$profilePath, [string]$newBlock) {
  $dir = Split-Path -Parent $profilePath
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

  $existing = ""
  if (Test-Path -LiteralPath $profilePath) {
    $existing = Get-Content -LiteralPath $profilePath -Raw
    if (-not $Force) {
      $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
      Copy-Item -LiteralPath $profilePath -Destination ($profilePath + ".bak." + $stamp) -Force
    }
  }

  if ($existing -match [regex]::Escape($startMarker) -and $existing -match [regex]::Escape($endMarker)) {
    $pattern = [regex]::Escape($startMarker) + ".*?" + [regex]::Escape($endMarker)
    $updated = [regex]::Replace($existing, $pattern, $newBlock, "Singleline")
    Set-Content -LiteralPath $profilePath -Value $updated -Encoding UTF8
  } else {
    $sep = if ($existing -and -not $existing.EndsWith("`n")) { "`r`n" } else { "" }
    Set-Content -LiteralPath $profilePath -Value ($existing + $sep + "`r`n" + $newBlock + "`r`n") -Encoding UTF8
  }
}

Write-ProfileBlock -profilePath $PROFILE -newBlock $block

Write-Host ""
Write-Host "Installed better ls/ll into your profile:"
Write-Host "  $PROFILE"
Write-Host ""
Write-Host "Reload now with:"
Write-Host "  . `$PROFILE"
Write-Host ""
Write-Host "Then try:"
Write-Host "  ls"
Write-Host "  ll"
