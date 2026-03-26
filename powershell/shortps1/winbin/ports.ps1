Get-NetTCPConnection -State Listen |
  Select-Object LocalAddress, LocalPort, OwningProcess |
  Sort-Object LocalPort
