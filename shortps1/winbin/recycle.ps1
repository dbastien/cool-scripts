param([Parameter(Mandatory, ValueFromRemainingArguments=$true)] [string[]]$Path)
Add-Type -AssemblyName Microsoft.VisualBasic
foreach ($p in $Path) {
  [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p,'OnlyErrorDialogs','SendToRecycleBin')
}
