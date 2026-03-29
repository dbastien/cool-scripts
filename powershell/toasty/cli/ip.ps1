$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\ShortCommon.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
  Write-ShortPs1Msg "IP configuration" Muted
}

Get-NetIPConfiguration | Where-Object IPv4Address |
  Select-Object InterfaceAlias,
  @{n = "IPv4"; e = { $_.IPv4Address.IPAddress } },
  @{n = "GW"; e = { $_.IPv4DefaultGateway.NextHop } },
  @{n = "DNS"; e = { ($_.DnsServer.ServerAddresses -join ",") } } |
  Format-Table -AutoSize