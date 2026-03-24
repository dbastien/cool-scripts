param([Parameter(ValueFromRemainingArguments=$true)] [string[]]$Path)
foreach ($p in $Path) { Start-Process $p }
