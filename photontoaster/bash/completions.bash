# PhotonToaster bash completions

if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  # shellcheck source=/dev/null
  . /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
  # shellcheck source=/dev/null
  . /etc/bash_completion
fi

shopt -s progcomp

if [[ -d /usr/local/etc/bash_completion.d ]]; then
  shopt -s nullglob
  for f in /usr/local/etc/bash_completion.d/*; do
    [[ -r "$f" ]] || continue
    # shellcheck source=/dev/null
    . "$f"
  done
  shopt -u nullglob
fi
