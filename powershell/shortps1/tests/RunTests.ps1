#requires -Version 7.2
<#
.SYNOPSIS
    Run Pester 5 tests for dopecli scripts. Ensures dev dependencies first.
.EXAMPLE
    pwsh -NoProfile -File .\tests\RunTests.ps1
#>
$ErrorActionPreference = 'Stop'
$testsRoot = $PSScriptRoot
$shortps1Root = Split-Path $testsRoot -Parent

& (Join-Path $shortps1Root 'Install-DevDependencies.ps1')

Import-Module Pester -MinimumVersion 5.0.0 -MaximumVersion 5.99.999 -ErrorAction Stop

$config = New-PesterConfiguration
$config.Run.Path = $testsRoot
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $config
