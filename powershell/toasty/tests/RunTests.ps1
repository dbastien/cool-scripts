#requires -Version 7.2
<#
.SYNOPSIS
    Run Pester 5 tests for Toasty cli scripts. Ensures dev dependencies first.
.EXAMPLE
    pwsh -NoProfile -File .\tests\RunTests.ps1
#>
$ErrorActionPreference = 'Stop'
$testsRoot = $PSScriptRoot
$ptRoot = Split-Path $testsRoot -Parent

& (Join-Path $ptRoot 'dev\Install-DevDependencies.ps1')

Import-Module Pester -MinimumVersion 5.0.0 -MaximumVersion 5.99.999 -ErrorAction Stop

$config = New-PesterConfiguration
$config.Run.Path = $testsRoot
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $config
