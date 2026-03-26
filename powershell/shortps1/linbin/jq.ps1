[CmdletBinding()]
param(
  [Parameter(Position=0)] [string]$Path,
  [string[]]$Property,
  [int]$Depth = 99,
  [switch]$Raw,
  [switch]$Compress
)

function Read-JsonText {
  if ($Path) { return (Get-Content -LiteralPath $Path -Raw) }
  return ($input | Out-String)
}

$jsonText = Read-JsonText
if ([string]::IsNullOrWhiteSpace($jsonText)) { return }

$obj = $jsonText | ConvertFrom-Json -ErrorAction Stop

if ($Property -and $Property.Count -gt 0) {
  $obj = $obj | Select-Object -Property $Property
}

if ($Raw) {
  $obj
} else {
  if ($Compress) { $obj | ConvertTo-Json -Depth $Depth -Compress }
  else { $obj | ConvertTo-Json -Depth $Depth }
}
