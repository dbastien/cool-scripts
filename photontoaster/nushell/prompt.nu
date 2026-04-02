# PhotonToaster nushell prompt
# Colors: hex equivalents of PHOTONTOASTER_C_* from shared/env.sh

const PT_BLUE = "#6e9bf5"
const PT_VIOLET = "#967dff"
const PT_OK = "#50fa78"
const PT_ERR = "#ff5a5a"
const PT_WARN = "#ffdc3c"
const PT_WHITE = "#f5f5ff"
const PT_DARK = "#181c28"
const PT_ACCENT = "#ff64ff"
const PT_SSH = "#ffa500"
const PT_VENV = "#3cb44b"

def _pt-pill [
  bg_hex: string
  fg_hex: string
  text: string
  --icon: string = ""
] {
  let cap_l = "\u{e0b6}"
  let cap_r = "\u{e0b4}"
  let body = if ($icon != "") and ($text != "") {
    $"($icon) ($text)" | str trim
  } else if $icon != "" {
    $icon
  } else {
    $text | str trim
  }
  let open = (ansi { fg: $bg_hex })
  let fill = (ansi { fg: $fg_hex, bg: $bg_hex })
  let reset = (ansi reset)
  let bridge = (ansi { fg: $bg_hex })
  $"($open)($cap_l)($fill) ($body) ($reset)($bridge)($cap_r)($reset)"
}

def _pt-path-label [] {
  let home = $nu.home-path | path expand
  let cwd = $env.PWD | path expand
  let sep = (char psep)
  let hs = ($home | into string)
  let cs = ($cwd | into string)
  if $cwd == $home {
    "~"
  } else if ($cs | str starts-with ($hs + $sep)) {
    let rel = ($cwd | path relative-to $home | into string)
    let parts = ($rel | split row $sep | where {|p| $p != ""})
    let n = ($parts | length)
    if $n <= 2 {
      $"~/($rel)"
    } else {
      $"~/(( $parts | last 2 | str join $sep ))"
    }
  } else {
    let parts = ($cs | split row $sep | where {|p| $p != ""})
    let n = ($parts | length)
    if $n <= 3 {
      $cs
    } else {
      $parts | last 2 | str join $sep
    }
  }
}

def _pt-status [] {
  let code = ($env.LAST_EXIT_CODE? | default 0)
  let ic_ok = "\u{f00c}"
  let ic_warn = "\u{f071}"
  let ic_err = "\u{f00d}"
  if $code == 0 {
    _pt-pill $PT_OK $PT_DARK "" --icon $ic_ok
  } else if $code in [130 131 148] {
    _pt-pill $PT_WARN $PT_DARK "" --icon $ic_warn
  } else {
    _pt-pill $PT_ERR $PT_WHITE ($code | into string) --icon $ic_err
  }
}

$env.PROMPT_COMMAND = {||
  let user = ($env.USER? | default ($env.USERNAME? | default "user"))
  let home = $nu.home-path | path expand
  let cwd = $env.PWD | path expand
  let path_ic = if $cwd == $home { "\u{f015}" } else { "\u{f07b}" }
  let spark = $"(ansi { fg: $PT_ACCENT })\u2726(ansi reset)"
  let seg_u = (_pt-pill $PT_BLUE $PT_DARK $user --icon "\u{f007}")
  let seg_p = (_pt-pill $PT_VIOLET $PT_DARK (_pt-path-label) --icon $path_ic)
  $"($seg_u) ($spark) ($seg_p) "
}

$env.PROMPT_COMMAND_RIGHT = {||
  let now = (date now | format date '%H:%M:%S')
  let st = (_pt-status)
  let clk = (_pt-pill $PT_VIOLET $PT_DARK $now)
  $"($st) ($clk)"
}
