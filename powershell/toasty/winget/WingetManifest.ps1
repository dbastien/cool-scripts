# Winget package IDs for common dev CLIs (curated manifest).
# Dot-sourced by winget\Install-Extern.ps1 and Instellator\instellator.ps1.
#
# Mapping notes (Ubuntu PT `packages=(...)` vs this manifest):
# - ncdu (apt) -> gdu (dundee.gdu); same role: disk usage UI.
# - fd-find (apt) -> sharkdp.fd (probe: fd).
# - Covered here (winget): ripgrep, bat, fd, eza, fzf, zoxide, jq, delta, btop, fastfetch, duf, dust, procs, micro,
#   tldr, tree, wget, less, gdu.
# - Not in this list (install separately or WSL-only): git, curl, unzip, zip, build-essential, pkg-config — typical
#   Windows dev boxes already have git/curl; use Visual Studio / Build Tools for compilers if needed.
# - WSL / apt-only in PT script (no winget row here): wslu, zsh, command-not-found, zsh-autosuggestions,
#   zsh-syntax-highlighting, zsh-history-substring-search. thefuck: optional via Install-Extern.ps1 -IncludeTheFuck.
#
# Tiers: Core = smaller subset; Extended = rest. Default = Core + Extended (PT-style install-all); -MinimalExtern uses Core only.

$ToastyWingetPackages = @(
  @{ Id = 'BurntSushi.ripgrep.MSVC'; Probe = 'rg'; ExcludeScript = $null; Tier = 'Core' }
  @{ Id = 'sharkdp.bat'; Probe = 'bat'; ExcludeScript = $null; Tier = 'Core' }
  @{ Id = 'sharkdp.fd'; Probe = 'fd'; ExcludeScript = $null; Tier = 'Core' }
  @{ Id = 'eza-community.eza'; Probe = 'eza'; ExcludeScript = $null; Tier = 'Core' }
  @{ Id = 'junegunn.fzf'; Probe = 'fzf'; ExcludeScript = $null; Tier = 'Core' }
  @{ Id = 'ajeetdsouza.zoxide'; Probe = 'zoxide'; ExcludeScript = $null; Tier = 'Core' }
  @{ Id = 'jqlang.jq'; Probe = 'jq'; ExcludeScript = 'jq.ps1'; Tier = 'Core' }
  @{ Id = 'dandavison.delta'; Probe = 'delta'; ExcludeScript = $null; Tier = 'Extended' }
  @{ Id = 'aristocratos.btop4win'; Probe = 'btop'; ExcludeScript = $null; Tier = 'Extended' }
  @{ Id = 'Fastfetch-cli.Fastfetch'; Probe = 'fastfetch'; ExcludeScript = $null; Tier = 'Extended' }
  @{ Id = 'muesli.duf'; Probe = 'duf'; ExcludeScript = $null; Tier = 'Extended' }
  @{ Id = 'bootandy.dust'; Probe = 'dust'; ExcludeScript = $null; Tier = 'Extended' }
  @{ Id = 'dalance.procs'; Probe = 'procs'; ExcludeScript = $null; Tier = 'Extended' }
  @{ Id = 'zyedidia.micro'; Probe = 'micro'; ExcludeScript = $null; Tier = 'Extended' }
  @{ Id = 'dbrgn.tealdeer'; Probe = 'tldr'; ExcludeScript = $null; Tier = 'Extended' }
  @{ Id = 'GnuWin32.Tree'; Probe = 'tree'; ExcludeScript = $null; Tier = 'Extended' }
  @{ Id = 'JernejSimoncic.Wget'; Probe = 'wget'; ExcludeScript = 'wget.ps1'; Tier = 'Extended' }
  @{ Id = 'jftuga.less'; Probe = 'less'; ExcludeScript = $null; Tier = 'Extended' }
  @{ Id = 'dundee.gdu'; Probe = 'gdu'; ExcludeScript = $null; Tier = 'Extended' }
)
