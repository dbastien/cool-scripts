# PhotonToaster nushell integrations

let _pt_nu_dir = $nu.default-config-dir

let _pt_zoxide = ($_pt_nu_dir | path join "photontoaster-zoxide.nu")
if not ((which zoxide | is-empty)) {
  zoxide init nushell | save -f $_pt_zoxide
  source $_pt_zoxide
}

if not ((which direnv | is-empty)) {
  let pt_direnv_hook = {|_before, _after|
    direnv export json | from json | default {} | load-env
  }
  let cfg = ($env.config? | default {})
  let hooks = ($cfg.hooks? | default {})
  let ec = ($hooks.env_change? | default {})
  let pwd_hooks = ($ec.PWD? | default [] | append $pt_direnv_hook)
  let ec_new = ($ec | upsert PWD $pwd_hooks)
  let hooks_new = ($hooks | upsert env_change $ec_new)
  $env.config = ($cfg | upsert hooks $hooks_new)
}

let _pt_atuin = ($_pt_nu_dir | path join "photontoaster-atuin.nu")
if not ((which atuin | is-empty)) {
  atuin init nu | save -f $_pt_atuin
  source $_pt_atuin
}
