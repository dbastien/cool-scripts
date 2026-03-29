# Forwards to photontoaster\Install-PsBin.ps1 (copy cli + shell helpers to psbin).
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\photontoaster\Install-PsBin.ps1') @args
