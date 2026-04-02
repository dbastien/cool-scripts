# PhotonToaster shared PowerShell environment

$env:PATH = "$HOME/.local/bin$([IO.Path]::PathSeparator)$($env:PATH)"

# Editor / pager
$env:EDITOR = "micro"
$env:VISUAL = "micro"
$env:PAGER = "less"
$env:LESS = "-FRX"
$env:CLICOLOR = "1"
$env:COLORTERM = "truecolor"

$env:VIRTUAL_ENV_DISABLE_PROMPT = "1"
$env:ATUIN_NOBIND = "true"
$env:HOMEBREW_NO_ENV_HINTS = "1"

# Git colors and pager without touching ~/.gitconfig
$env:GIT_CONFIG_COUNT = "2"
$env:GIT_CONFIG_KEY_0 = "color.ui"
$env:GIT_CONFIG_VALUE_0 = "always"
$env:GIT_CONFIG_KEY_1 = "core.pager"
$env:GIT_CONFIG_VALUE_1 = "delta --dark 2>/dev/null || less -FRX"

$env:PHOTONTOASTER_CONFIG_DIR = if ($env:PHOTONTOASTER_CONFIG_DIR) {
  $env:PHOTONTOASTER_CONFIG_DIR
} else {
  Join-Path $HOME ".config/photontoaster"
}

$env:PHOTONTOASTER_STATE_DIR = if ($env:PHOTONTOASTER_STATE_DIR) {
  $env:PHOTONTOASTER_STATE_DIR
} else {
  Join-Path $HOME ".local/state/photontoaster"
}

$env:PHOTONTOASTER_QUOTES_FILE = if ($env:PHOTONTOASTER_QUOTES_FILE) {
  $env:PHOTONTOASTER_QUOTES_FILE
} else {
  Join-Path $env:PHOTONTOASTER_CONFIG_DIR "quotes.txt"
}

function Get-PTEnvConfig {
  param(
    [string]$Path = (Join-Path $env:PHOTONTOASTER_CONFIG_DIR "config.toml")
  )

  $cfg = @{}
  if (-not (Test-Path -LiteralPath $Path)) { return $cfg }

  $section = ""
  foreach ($lineRaw in Get-Content -LiteralPath $Path) {
    $line = $lineRaw.Trim()
    if (-not $line -or $line.StartsWith("#")) { continue }
    if ($line -match '^\[(.+)\]$') {
      $section = $Matches[1].Trim()
      continue
    }
    if ($line -match '^([^=]+)=(.+)$') {
      $key = $Matches[1].Trim()
      $val = ($Matches[2].Trim() -replace '\s+#.*$', '').Trim()
      if ($val.StartsWith('"') -and $val.EndsWith('"') -and $val.Length -ge 2) {
        $val = $val.Substring(1, $val.Length - 2)
      }
      $fullKey = if ($section) { "$section.$key" } else { $key }
      $cfg[$fullKey] = $val
    }
  }
  return $cfg
}

function Set-PTColorEnv {
  $cfg = Get-PTEnvConfig
  $scheme = if ($cfg.ContainsKey("colors.scheme")) { $cfg["colors.scheme"] } else { "default" }

  $palette = switch ($scheme) {
    "catppuccin" { @{
      blue = "137;180;250"; violet = "203;166;247"; ok = "166;227;161"; err = "243;139;168"; warn = "249;226;175";
      white = "205;214;244"; dark = "30;30;46"; accent = "245;194;231"; ssh = "250;179;135"; venv = "148;226;213"
    } }
    "pastels" { @{
      blue = "162;196;255"; violet = "200;182;255"; ok = "176;228;175"; err = "255;179;186"; warn = "255;234;167";
      white = "240;240;248"; dark = "40;42;54"; accent = "255;182;225"; ssh = "255;204;153"; venv = "167;230;210"
    } }
    "solarized" { @{
      blue = "38;139;210"; violet = "108;113;196"; ok = "133;153;0"; err = "220;50;47"; warn = "181;137;0";
      white = "238;232;213"; dark = "0;43;54"; accent = "211;54;130"; ssh = "203;75;22"; venv = "42;161;152"
    } }
    "dracula" { @{
      blue = "139;233;253"; violet = "189;147;249"; ok = "80;250;123"; err = "255;85;85"; warn = "241;250;140";
      white = "248;248;242"; dark = "40;42;54"; accent = "255;121;198"; ssh = "255;184;108"; venv = "139;233;253"
    } }
    "astra" { @{
      blue = "120;170;255"; violet = "190;130;255"; ok = "100;220;140"; err = "255;80;100"; warn = "255;190;70";
      white = "215;220;240"; dark = "12;12;24"; accent = "220;100;255"; ssh = "255;160;90"; venv = "90;210;180"
    } }
    "cracktro" { @{
      blue = "0;255;255"; violet = "255;0;128"; ok = "0;255;0"; err = "255;0;0"; warn = "255;255;0";
      white = "255;255;255"; dark = "0;0;0"; accent = "255;0;255"; ssh = "255;128;0"; venv = "0;255;128"
    } }
    "terminal" { @{
      blue = "0;120;255"; violet = "160;32;240"; ok = "0;200;0"; err = "255;0;0"; warn = "255;255;0";
      white = "255;255;255"; dark = "0;0;0"; accent = "255;0;255"; ssh = "255;165;0"; venv = "0;128;0"
    } }
    default { @{
      blue = "110;155;245"; violet = "150;125;255"; ok = "80;250;120"; err = "255;90;90"; warn = "255;220;60";
      white = "245;245;255"; dark = "24;28;40"; accent = "255;100;255"; ssh = "255;165;0"; venv = "60;180;75"
    } }
  }

  foreach ($k in @("blue", "violet", "ok", "err", "warn", "white", "dark", "accent", "ssh", "venv")) {
    $cfgKey = "colors.$k"
    if ($cfg.ContainsKey($cfgKey) -and $cfg[$cfgKey]) {
      $palette[$k] = $cfg[$cfgKey]
    }
  }

  $env:PHOTONTOASTER_C_BLUE = $palette.blue
  $env:PHOTONTOASTER_C_VIOLET = $palette.violet
  $env:PHOTONTOASTER_C_OK = $palette.ok
  $env:PHOTONTOASTER_C_ERR = $palette.err
  $env:PHOTONTOASTER_C_WARN = $palette.warn
  $env:PHOTONTOASTER_C_WHITE = $palette.white
  $env:PHOTONTOASTER_C_DARK = $palette.dark
  $env:PHOTONTOASTER_C_ACCENT = $palette.accent
  $env:PHOTONTOASTER_C_SSH = $palette.ssh
  $env:PHOTONTOASTER_C_VENV = $palette.venv

  if ($cfg.ContainsKey("aws.profile") -and $cfg["aws.profile"]) {
    $env:AWS_PROFILE = $cfg["aws.profile"]
  }
}

Set-PTColorEnv
