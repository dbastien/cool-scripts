# PhotonToaster fish integrations

if command -sq zoxide
    zoxide init fish | source
end

# direnv — only on cd, not every prompt
if command -sq direnv
    function _photontoaster_direnv_hook --on-variable PWD
        eval (direnv export fish 2>/dev/null)
    end
    eval (direnv export fish 2>/dev/null)
end

if command -sq atuin
    atuin init fish | source
end

if command -sq thefuck
    thefuck --alias | source
end

if command -sq fzf
    fzf --fish | source
end
