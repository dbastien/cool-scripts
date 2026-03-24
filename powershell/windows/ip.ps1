Get-NetIPConfiguration | Where-Object IPv4Address | Select-Object InterfaceAlias,
  @{n="IPv4";e={$_.IPv4Address.IPAddress}},
  @{n="GW";e={$_.IPv4DefaultGateway.NextHop}},
  @{n="DNS";e={($_.DnsServer.ServerAddresses -join ",")}} |
  Format-Table -AutoSize
