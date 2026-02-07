<#
.SYNOPSIS
    Simple wget-like script for downloading files using PowerShell 7+.

.DESCRIPTION
    Downloads a file from a specified URL and saves it to the specified location.
    If no output file name is provided, it defaults to the name from the URL path
    (query strings like ?token=... are ignored).

.PARAMETER Url
    The URL of the file to download.

.PARAMETER Output
    Output file name or path. If a directory path is provided, the file name is taken from the URL.

.PARAMETER Resume
    Resume a partially downloaded file (like wget -c).

.PARAMETER RetryCount
    Number of retry attempts on transient failures.

.PARAMETER RetryDelaySec
    Seconds to wait between retries.

.PARAMETER ConnectTimeoutSec
    Connection timeout in seconds.

.PARAMETER TimeoutSec
    Overall operation timeout in seconds.

.PARAMETER NoProgress
    Suppress the progress display (can be faster in some hosts).

.PARAMETER Help
    Show this help and exit.

.EXAMPLE
    .\ps-wget.ps1 -Url "https://example.com/file.zip"

.EXAMPLE
    .\ps-wget.ps1 -Url "https://example.com/file.zip" -Resume

.EXAMPLE
    .\ps-wget.ps1 -Url "https://example.com/file.zip" -Output "C:\tmp\" -RetryCount 5 -RetryDelaySec 2
#>

[CmdletBinding(DefaultParameterSetName = 'Download')]
param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Download', HelpMessage = "URL of the file to download")]
    [string]$Url,

    [Parameter(Mandatory = $false, ParameterSetName = 'Download', HelpMessage = "Output file name or path")]
    [string]$Output,

    [Parameter(Mandatory = $false, ParameterSetName = 'Download', HelpMessage = "Resume a partial download")]
    [switch]$Resume,

    [Parameter(Mandatory = $false, ParameterSetName = 'Download', HelpMessage = "Retry attempts on transient failures")]
    [int]$RetryCount = 3,

    [Parameter(Mandatory = $false, ParameterSetName = 'Download', HelpMessage = "Seconds between retries")]
    [int]$RetryDelaySec = 2,

    [Parameter(Mandatory = $false, ParameterSetName = 'Download', HelpMessage = "Connection timeout in seconds")]
    [int]$ConnectTimeoutSec = 15,

    [Parameter(Mandatory = $false, ParameterSetName = 'Download', HelpMessage = "Overall operation timeout in seconds")]
    [int]$TimeoutSec = 300,

    [Parameter(Mandatory = $false, ParameterSetName = 'Download', HelpMessage = "Suppress progress display")]
    [switch]$NoProgress,

    [Parameter(ParameterSetName = 'Help')]
    [Alias('h', '?')]
    [switch]$Help
)

if ($PSCmdlet.ParameterSetName -eq 'Help') {
    Get-Help -Name $PSCommandPath -Full
    return
}

try {
    $uri = [Uri]$Url

    if (-not $Output) {
        $Output = Split-Path -Path $uri.AbsolutePath -Leaf
        if ([string]::IsNullOrWhiteSpace($Output)) { $Output = "download.bin" }
    } else {
        $looksLikeDir =
            (Test-Path -LiteralPath $Output -PathType Container) -or
            $Output.EndsWith([IO.Path]::DirectorySeparatorChar) -or
            $Output.EndsWith([IO.Path]::AltDirectorySeparatorChar)

        if ($looksLikeDir) {
            $leaf = Split-Path -Path $uri.AbsolutePath -Leaf
            if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = "download.bin" }
            $Output = Join-Path -Path $Output -ChildPath $leaf
        }
    }

    $parent = Split-Path -Path $Output -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Write-Host "Downloading from URL: $Url" -ForegroundColor Cyan
    Write-Host "Saving as: $Output" -ForegroundColor Cyan

    $oldProgress = $ProgressPreference
    if ($NoProgress) { $ProgressPreference = 'SilentlyContinue' }

    Invoke-WebRequest `
        -Uri $uri `
        -OutFile $Output `
        -Resume:$Resume `
        -MaximumRetryCount $RetryCount `
        -RetryIntervalSec $RetryDelaySec `
        -ConnectionTimeoutSeconds $ConnectTimeoutSec `
        -OperationTimeoutSeconds $TimeoutSec `
        -ErrorAction Stop | Out-Null

    if ($NoProgress) { $ProgressPreference = $oldProgress }

    Write-Host "Download complete!" -ForegroundColor Green
} catch {
    try {
        if ($NoProgress) { $ProgressPreference = $oldProgress }
    } catch { }

    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
