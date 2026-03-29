#requires -Version 7.2
<#
.SYNOPSIS
    Installs dev dependencies declared in SharedLibs\Toasty.Dev.psd1 (Pester 5.x for tests).
#>
param(
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$dev = Import-PowerShellDataFile (Join-Path $here 'Toasty.Dev.psd1')
$minVer = [version]$dev.PesterMinimumVersion
$maxVer = [version]$dev.PesterMaximumVersion

$satisfied = Get-Module -ListAvailable -Name Pester | Where-Object {
    $_.Version -ge $minVer -and $_.Version -le $maxVer
} | Select-Object -First 1

if ($satisfied) {
    Write-Host "Pester $($satisfied.Version) already satisfies $($minVer)..$($maxVer)."
    return
}

if ($WhatIf) {
    Write-Host "Would install: Pester from PSGallery (min $minVer, max $maxVer, Scope CurrentUser)."
    return
}

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
Install-Module -Name Pester -MinimumVersion $dev.PesterMinimumVersion -MaximumVersion $dev.PesterMaximumVersion `
    -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
