#requires -Version 7.2
# Forwards to SharedLibs\Install-DevDependencies.ps1 (Pester for tests).
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'SharedLibs\Install-DevDependencies.ps1') @args
