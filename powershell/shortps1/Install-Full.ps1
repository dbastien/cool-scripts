# Forwards to Instellator\Install-Full.ps1 (winget CLIs + PhotonToaster psbin + optional Instellator GUI flows).
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Instellator\Install-Full.ps1') @args
