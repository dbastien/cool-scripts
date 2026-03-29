# Forwards to Instellator\Install-Full.ps1 (winget CLIs + Toasty junction + optional Instellator GUI flows).
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Instellator\Install-Full.ps1') @args
