#requires -Version 7.2
<#
.SYNOPSIS
    Build compact JSON index of repo *.ps1 for agents; skips rebuild when path+mtime fingerprint matches.
.EXAMPLE
    pwsh -NoProfile -File .\agent-scripts\Update-RepoIndex.ps1
#>
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
. (Join-Path $here '_Common.ps1')

$repoRoot = if ($env:COOL_SCRIPTS_ROOT) { (Resolve-Path -LiteralPath $env:COOL_SCRIPTS_ROOT).Path } else { Get-AgentRepoRoot -AgentScriptsDir $here }
$cacheDir = Join-Path $here '.cache'
$outPath = Join-Path $cacheDir 'repo-index.json'
New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null

$sig = Get-AgentRepoPathSignature -RepoRoot $repoRoot
$files = @(Get-AgentRepoPs1Files -RepoRoot $repoRoot | Sort-Object -Property FullName)

if (-not $Force -and (Test-Path -LiteralPath $outPath)) {
    try {
        $prev = Get-Content -LiteralPath $outPath -Raw -Encoding utf8 | ConvertFrom-Json
        if ($prev.meta.pathSignature -eq $sig) {
            Write-Host "repo-index: cache hit ($($files.Count) files, signature $($sig.Substring(0, 12))...)"
            exit 0
        }
    } catch {
        # rebuild
    }
}

$fileRows = foreach ($f in $files) {
    $rel = Get-AgentRepoRelativePath -RepoRoot $repoRoot -FullPath $f.FullName
    [pscustomobject]@{
        path             = $rel
        lastWriteTimeUtc = $f.LastWriteTimeUtc.ToString('o')
        synopsis         = Get-AgentScriptSynopsis -Path $f.FullName
    }
}

$payload = [pscustomobject]@{
    meta = [pscustomobject]@{
        generatedUtc     = [datetime]::UtcNow.ToString('o')
        pathSignature    = $sig
        fileCount        = $fileRows.Count
        pwshVersion      = $PSVersionTable.PSVersion.ToString()
        repoRoot         = $repoRoot
    }
    files = @($fileRows)
}

$json = $payload | ConvertTo-Json -Depth 8 -Compress
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $json, $utf8)
Write-Host "repo-index: wrote $outPath ($($fileRows.Count) files)"
