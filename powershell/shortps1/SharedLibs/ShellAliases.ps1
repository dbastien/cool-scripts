# Dot-source into your profile (definitions must run in your session, not as a -File script):
#   . (Join-Path $env:USERPROFILE 'psbin\ShellAliases.ps1')
# Or from a clone (under shortps1):
#   . .\SharedLibs\ShellAliases.ps1

# Parent hops: each extra dot is one more ".." segment (.. = 1 level, ... = 2 levels, etc.).
function global:.. { Set-Location .. }
function global:... { Set-Location ../.. }
function global:.... { Set-Location ../../.. }
function global:..... { Set-Location ../../../.. }
function global:...... { Set-Location ../../../../.. }

# Optional: go up N levels (default 1). Example: up 3
function global:Up-Location {
  param([ValidateRange(1, 64)][int]$n = 1)
  for ($i = 0; $i -lt $n; $i++) { Set-Location .. }
}
Set-Alias -Name up -Value Up-Location -Scope Global -Force
