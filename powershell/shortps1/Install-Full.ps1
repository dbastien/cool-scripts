# Forwards to Instellaator\Install-Full.ps1 (CLI + dope shell + optional Instellaator GUI flows).
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Instellaator\Install-Full.ps1') @args
