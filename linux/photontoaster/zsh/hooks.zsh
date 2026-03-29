# PhotonToaster zsh hooks — window title, exit code capture

autoload -Uz add-zsh-hook

# Capture exit code FIRST before any other precmd hook clobbers $?
_photontoaster_save_exit() {
  _photontoaster_last_exit=$?
}
add-zsh-hook precmd _photontoaster_save_exit

# Window title: show running command in preexec, cwd in precmd.
# Registration is deferred to init.zsh (after config is loaded) so we
# never emit an OSC 0 sequence when title is disabled — that would
# override Windows Terminal's profile name.
_photontoaster_preexec_title() {
  local cmd="${1%% *}"
  printf '\033]0;%s\007' "$cmd"
}

_photontoaster_precmd_title() {
  printf '\033]0;%s@%s: %s\007' "$USER" "${HOST%%.*}" "${PWD/#$HOME/~}"
}
