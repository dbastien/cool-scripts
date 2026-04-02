# PhotonToaster nushell init — config loading, session startup

let _pt_config_dir = ($env.PHOTONTOASTER_CONFIG_DIR? | default ($nu.home-path | path join ".config" "photontoaster"))
let _pt_config_reader = ($_pt_config_dir | path join "shared" "pt-config-read")

# Parse config.toml into a record via pt-config-read
let _pt_config = if ($_pt_config_reader | path exists) {
  ^$_pt_config_reader
    | lines
    | where { |l| $l != "" and ($l | str contains "=") }
    | each { |l|
        let parts = ($l | split row "=" --max-splits 1)
        { key: ($parts | first), value: ($parts | last) }
      }
    | reduce -f {} { |it, acc| $acc | insert $it.key $it.value }
} else {
  {}
}

let _ls_tool = ($_pt_config | get -i "general.ls_tool" | default "eza")
match $_ls_tool {
  "lsd" => {
    def --wrapped l [...args] { ^lsd -lAh ...$args }
    def --wrapped ls [...args] { ^lsd ...$args }
    def --wrapped lsa [...args] { ^lsd -a ...$args }
    def --wrapped la [...args] { ^lsd -a ...$args }
    def --wrapped ll [...args] { ^lsd -lh ...$args }
    def --wrapped lla [...args] { ^lsd -lAh ...$args }
    def --wrapped lt [...args] { ^lsd --tree --depth=2 ...$args }
    def --wrapped tree [...args] { ^lsd --tree ...$args }
  }
  "broot" => {
    def --wrapped l [...args] { ^broot --sizes --dates --permissions ...$args }
    def --wrapped ls [...args] { ^broot --sizes --dates --permissions ...$args }
    def --wrapped lsa [...args] { ^broot --sizes --dates --permissions --hidden ...$args }
    def --wrapped la [...args] { ^broot --sizes --dates --permissions --hidden ...$args }
    def --wrapped ll [...args] { ^broot --sizes --dates --permissions ...$args }
    def --wrapped lla [...args] { ^broot --sizes --dates --permissions --hidden ...$args }
    def --wrapped lt [...args] { ^broot --sizes ...$args }
    def --wrapped tree [...args] { ^broot --sizes ...$args }
  }
  "ls" => {
    def --wrapped l [...args] { ^ls -lAH --color=auto ...$args }
    def --wrapped ls [...args] { ^ls --color=auto ...$args }
    def --wrapped lsa [...args] { ^ls -a --color=auto ...$args }
    def --wrapped la [...args] { ^ls -a --color=auto ...$args }
    def --wrapped ll [...args] { ^ls -lAh --color=auto ...$args }
    def --wrapped lla [...args] { ^ls -lAh --color=auto ...$args }
    def --wrapped lt [...args] { ^tree -L 2 ...$args }
    def --wrapped tree [...args] { ^tree ...$args }
  }
  _ => {
    def --wrapped l [...args] { ^eza -lah ...$args }
    def --wrapped ls [...args] { ^eza ...$args }
    def --wrapped lsa [...args] { ^eza -a ...$args }
    def --wrapped la [...args] { ^eza -a ...$args }
    def --wrapped ll [...args] { ^eza -lh ...$args }
    def --wrapped lla [...args] { ^eza -lah ...$args }
    def --wrapped lt [...args] { ^eza --tree --level=2 ...$args }
    def --wrapped tree [...args] { ^eza --tree ...$args }
  }
}

# Auto-ls when PWD changes (aligned with PowerShell prompt + bash PROMPT_COMMAND + zsh chpwd).
let _pt_auto_ls_enabled = ($_pt_config | get -i "general.auto_ls" | default "true")
if $_pt_auto_ls_enabled == "true" {
  let _pt_pwd_ls_hook = {|before, after|
    if ($before | is-empty) { return }
    if (which eza | is-empty | not) {
      ^eza --icons=always --group-directories-first --color=always
    } else {
      ls
    }
  }
  $env.config = ($env.config | default {} | upsert hooks {|hooks|
    let h = ($hooks | default {})
    let ec = ($h | get -i env_change | default {})
    let pwd_hooks = ($ec | get -i PWD | default [])
    let new_ec = ($ec | upsert PWD ($pwd_hooks | append $_pt_pwd_ls_hook))
    $h | upsert env_change $new_ec
  })
}

if not ($env | get -i PHOTONTOASTER_SESSION_INIT | is-empty | not) {
  $env.PHOTONTOASTER_SESSION_INIT = "1"

  let _vf = ($_pt_config_dir | path join "version")
  if ($_vf | path exists) {
    let _ver = (open $_vf | str trim)
    print $"(ansi { fg: '#ff64ff' })\u{f120} PhotonToaster v($_ver)(ansi reset)"
  }

  let _qt = ($_pt_config_dir | path join "shared" "pt-quote")
  if ($_qt | path exists) and (($_pt_config | get -i "general.quote_of_the_day" | default "true") == "true") {
    ^$_qt
  }
}
