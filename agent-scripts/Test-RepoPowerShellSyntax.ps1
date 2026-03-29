#requires -Version 7.2
<#
.SYNOPSIS
    Parse every *.ps1 under the repo (excluding .git and agent-scripts/.cache); non-zero exit on errors.
.EXAMPLE
    pwsh -NoProfile -File .\agent-scripts\Test-RepoPowerShellSyntax.ps1
#>
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
. (Join-Path $here '_Common.ps1')

$repoRoot = if ($env:COOL_SCRIPTS_ROOT) { (Resolve-Path -LiteralPath $env:COOL_SCRIPTS_ROOT).Path } else { Get-AgentRepoRoot -AgentScriptsDir $here }
$files = @(Get-AgentRepoPs1Files -RepoRoot $repoRoot | Sort-Object -Property FullName)
$bad = New-Object System.Collections.Generic.List[object]
foreach ($f in $files) {
    $tokens = $null
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) {
        $bad.Add([pscustomobject]@{ path = $f.FullName; errors = @($errs | ForEach-Object { $_.ToString() }) })
    }
}
if ($bad.Count -gt 0) {
    foreach ($b in $bad) {
        Write-Host "Parse errors: $($b.path)"
        foreach ($e in $b.errors) { Write-Host "  $e" }
    }
    exit 1
}
Write-Host "Syntax OK: $($files.Count) scripts"
