param(
  [Parameter(Mandatory, Position=0)] [string]$Path,
  [switch]$a
)
if ($a) { $input | Tee-Object -FilePath $Path -Append }
else { $input | Tee-Object -FilePath $Path }
