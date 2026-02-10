[CmdletBinding(DefaultParameterSetName = "ScriptBlock")]
param(
  [Parameter(Position=0)]
  [int]$s = 2,

  [Parameter(ParameterSetName="ScriptBlock", Position=1, Mandatory=$true)]
  [scriptblock]$Do,

  [Parameter(ParameterSetName="String", Position=1, Mandatory=$true, ValueFromRemainingArguments=$true)]
  [string[]]$Command
)

function Invoke-Watched {
  param([scriptblock]$Do, [string[]]$Command, [string]$ParameterSetName)

  if ($ParameterSetName -eq "ScriptBlock") {
    & $Do
  } else {
    # Old mode: treat the rest of the args as one expression
    Invoke-Expression ($Command -join " ")
  }
}

while ($true) {
  Clear-Host
  Get-Date
  try {
    Invoke-Watched -Do $Do -Command $Command -ParameterSetName $PSCmdlet.ParameterSetName
  } catch {
    Write-Host ""
    Write-Host $_
  }
  Start-Sleep -Seconds $s
}
