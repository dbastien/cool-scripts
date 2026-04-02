# PhotonToaster PowerShell integrations

if (-not $script:PTConfig) {
  $script:PTConfig = @{}
}

function Get-PTIntegrationBool {
  param(
    [Parameter(Mandatory = $true)][string]$Key,
    [bool]$Default = $false
  )
  if (-not $script:PTConfig.ContainsKey($Key)) { return $Default }
  return ($script:PTConfig[$Key] -eq "true")
}

function Get-PTEverythingExe {
  if (Get-Command es.exe -ErrorAction SilentlyContinue) {
    return (Get-Command es.exe -ErrorAction SilentlyContinue).Source
  }

  if ($env:WSL_DISTRO_NAME) {
    $candidates = @(
      "/mnt/c/Program Files/Everything/es.exe",
      "/mnt/c/Program Files (x86)/Everything/es.exe"
    )
    foreach ($candidate in $candidates) {
      if (Test-Path -LiteralPath $candidate) {
        return $candidate
      }
    }
  }

  return $null
}

function global:fe {
  param(
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
    [string[]]$Query
  )

  $es = Get-PTEverythingExe
  if (-not $es) {
    Write-Error "Everything CLI (es.exe) not found. Disable general.everything_integration or install Everything."
    return
  }

  & $es @Query
}

function Initialize-PTIntegrations {
  if ($script:PTIntegrationsReady) { return }
  $script:PTIntegrationsReady = $true

  if (-not $global:PTZoxideEagerInit) {
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
      try {
        Invoke-Expression (& zoxide init powershell | Out-String)
      } catch {}
      $_zoxidePtPath = Join-Path $PSScriptRoot 'lib\zoxide-pt.ps1'
      if (Test-Path -LiteralPath $_zoxidePtPath) {
        . $_zoxidePtPath -Config $script:PTConfig
      }
    }
  }

  if (Get-Command atuin -ErrorAction SilentlyContinue) {
    try {
      Invoke-Expression (& atuin init powershell | Out-String)
    } catch {}
  }

  if (Get-Command thefuck -ErrorAction SilentlyContinue) {
    try {
      Invoke-Expression (& thefuck --alias | Out-String)
    } catch {}
  }
}

$script:PTLazyIntegrations = Get-PTIntegrationBool -Key "general.lazy_integrations" -Default $true
if (-not $script:PTLazyIntegrations) {
  Initialize-PTIntegrations
}

$script:PTEverythingEnabled = Get-PTIntegrationBool -Key "general.everything_integration" -Default $true
if (-not $script:PTEverythingEnabled) {
  Remove-Item function:\fe -ErrorAction SilentlyContinue
}
