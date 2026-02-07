param(
  [string]$Pattern,
  [switch]$NameOnly,
  [switch]$ValueOnly,
  [switch]$CaseSensitive
)
$items = Get-ChildItem Env:
if ($Pattern) {
  if ($CaseSensitive) { $items = $items | Where-Object { $_.Name -cmatch $Pattern -or $_.Value -cmatch $Pattern } }
  else { $items = $items | Where-Object { $_.Name -match $Pattern -or $_.Value -match $Pattern } }
}
$items | Sort-Object Name | ForEach-Object {
  if ($NameOnly) { $_.Name }
  elseif ($ValueOnly) { $_.Value }
  else { "$($_.Name)=$($_.Value)" }
}
