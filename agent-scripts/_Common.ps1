# Dot-sourced by Update-RepoIndex.ps1 and Test-RepoPowerShellSyntax.ps1 (not a standalone entrypoint).

function Get-AgentRepoRoot {
    param([string]$AgentScriptsDir)
    (Resolve-Path -LiteralPath (Join-Path $AgentScriptsDir '..')).Path
}

function Test-AgentRepoPathExcluded {
    param(
        [string]$RepoRoot,
        [string]$FullPath
    )
    $repo = $RepoRoot.TrimEnd('\')
    if (-not $FullPath.StartsWith($repo, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    $tail = $FullPath.Substring($repo.Length).TrimStart('\')
    if ($tail -match '(?i)^\.git\\' -or $tail -match '(?i)\\\.git\\') { return $true }
    if ($tail -match '(?i)^agent-scripts\\\.cache\\' -or $tail -match '(?i)\\agent-scripts\\\.cache\\') { return $true }
    $false
}

function Get-AgentRepoRelativePath {
    param(
        [string]$RepoRoot,
        [string]$FullPath
    )
    $repo = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd('\')
    $full = (Resolve-Path -LiteralPath $FullPath).Path
    if (-not $full.StartsWith($repo, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full
    }
    $rel = $full.Substring($repo.Length).TrimStart('\')
    $rel -replace '\\', '/'
}

function Get-AgentRepoPs1Files {
    param([string]$RepoRoot)
    $repo = (Resolve-Path -LiteralPath $RepoRoot).Path
    Get-ChildItem -LiteralPath $repo -Recurse -File -Filter '*.ps1' -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-AgentRepoPathExcluded -RepoRoot $repo -FullPath $_.FullName) }
}

function Get-AgentRepoPathSignature {
    param([string]$RepoRoot)
    $repo = (Resolve-Path -LiteralPath $RepoRoot).Path
    $files = @(Get-AgentRepoPs1Files -RepoRoot $repo | Sort-Object -Property FullName)
    $lines = foreach ($f in $files) {
        $rel = Get-AgentRepoRelativePath -RepoRoot $repo -FullPath $f.FullName
        "$rel|$($f.LastWriteTimeUtc.Ticks)"
    }
    $text = $lines -join "`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    [BitConverter]::ToString($hash).Replace('-', '').ToLowerInvariant()
}

function Get-AgentScriptSynopsis {
    param([string]$Path)
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if (-not $raw) { return $null }
    $snippet = if ($raw.Length -gt 8192) { $raw.Substring(0, 8192) } else { $raw }
    $m = [regex]::Match($snippet, '(?ims)\.SYNOPSIS\s*\r?\n\s*(.+?)(?=\r?\n\s*\.|\r?\n\s*#>|\z)')
    if (-not $m.Success) { return $null }
    $s = $m.Groups[1].Value -replace '\s+', ' '
    $s.Trim()
}
