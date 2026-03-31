# Toasty fzf integration — PSReadLine keybindings for fuzzy search.
# Ctrl+R: fuzzy history search
# Ctrl+T: fuzzy file picker (insert path at cursor)
# Alt+C:  fuzzy cd into directory
# Gracefully no-ops if fzf is not installed.

if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { return }

$_hasFd = [bool](Get-Command fd -ErrorAction SilentlyContinue)

# Toasty-themed fzf color string from the palette
if (-not $env:FZF_DEFAULT_OPTS) {
  $env:FZF_DEFAULT_OPTS = '--color=fg:-1,bg:-1,hl:#6e9bf5,fg+:#f5f5ff,bg+:#181c28,hl+:#ff64ff,info:#50fa78,prompt:#ffdc3c,pointer:#ff64ff,marker:#50fa78,spinner:#966bff,header:#966bff --layout=reverse --height=40% --border=rounded'
}

# Ctrl+R — fuzzy history search
Set-PSReadLineKeyHandler -Key Ctrl+r -BriefDescription 'fzf-history' -ScriptBlock {
  $line = $null; $cursor = $null
  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

  $histPath = (Get-PSReadLineOption).HistorySavePath
  if (-not (Test-Path -LiteralPath $histPath)) { return }

  $query = if ($line) { $line.Substring(0, $cursor) } else { '' }
  $histLines = @(Get-Content -LiteralPath $histPath -Encoding utf8 | Where-Object { $_ -and $_.Trim() })
  [array]::Reverse($histLines)
  $selected = $histLines | Sort-Object -Unique | fzf --scheme=history --query=$query --no-sort

  if ($selected) {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected)
  }
}

# Ctrl+T — fuzzy file picker
Set-PSReadLineKeyHandler -Key Ctrl+t -BriefDescription 'fzf-file' -ScriptBlock {
  $selected = if ($script:_hasFd) {
    fd --type f --hidden --follow --color=always 2>$null | fzf --ansi
  } else {
    Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue |
      ForEach-Object { $_.FullName } | fzf
  }
  if ($selected) {
    $token = if ($selected -match '\s') { "'$selected'" } else { $selected }
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($token)
  }
}

# Alt+C — fuzzy cd
Set-PSReadLineKeyHandler -Key Alt+c -BriefDescription 'fzf-cd' -ScriptBlock {
  $selected = if ($script:_hasFd) {
    fd --type d --hidden --follow --color=always 2>$null | fzf --ansi
  } else {
    Get-ChildItem -Recurse -Directory -ErrorAction SilentlyContinue |
      ForEach-Object { $_.FullName } | fzf
  }
  if ($selected) {
    Set-Location $selected
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('')
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
  }
}
