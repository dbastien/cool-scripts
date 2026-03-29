# Dot-source to load PhotonToaster metadata and shared helpers (no installers).
# Example:  . (Join-Path $repo 'powershell\photontoaster\Init.ps1')
$ErrorActionPreference = 'Stop'

$PtRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$configPath = Join-Path $PtRoot 'config.psd1'
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Missing config: $configPath"
}

$cfg = Import-PowerShellDataFile -Path $configPath

# Unscoped: visible in the caller when this file is dot-sourced.
$PhotonToasterRoot = $PtRoot
$PhotonToasterConfig = $cfg
$PhotonToasterQuotesDir = Join-Path $env:USERPROFILE $cfg['QuotesSubPath']
$PhotonToasterQuotesFile = Join-Path $PhotonToasterQuotesDir $cfg['QuotesFileName']

$common = Join-Path $PtRoot 'lib\ShortCommon.ps1'
if (Test-Path -LiteralPath $common) { . $common }
