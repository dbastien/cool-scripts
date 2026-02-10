function ps { Get-Process | Sort-Object CPU -Desc | Select-Object -First 25 Name,Id,CPU,WS }
