# PhotonToaster fish AWS SSO helpers

function _photontoaster_state_dir
    set -l base (set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo $HOME/.local/state)
    echo $base/photontoaster
end

function _photontoaster_aws_stamp_file
    set -l profile default
    set -q AWS_PROFILE; and set profile $AWS_PROFILE
    set -l dir (_photontoaster_state_dir)
    mkdir -p $dir
    echo $dir/aws-sso-$profile.stamp
end

function _photontoaster_aws_profile_has_sso
    test -f "$HOME/.aws/config"; or return 1

    set -l profile default
    set -q AWS_PROFILE; and set profile $AWS_PROFILE

    set -l header
    if test "$profile" = default
        set header '[default]'
    else
        set header "[profile $profile]"
    end

    awk -v header="$header" '
        $0 == header { in_section = 1; next }
        in_section && /^\[/ { exit }
        in_section && $1 ~ /^(sso_session|sso_start_url)$/ { found = 1; exit }
        END { exit !found }
    ' "$HOME/.aws/config"
end

function awsp
    set -q AWS_PROFILE; and echo $AWS_PROFILE; or echo default
end

function awsl
    set -l profile default
    set -q AWS_PROFILE; and set profile $AWS_PROFILE
    if command aws sso login --profile $profile $argv
        set -l stamp (_photontoaster_aws_stamp_file)
        date +%s >$stamp
    end
end

function awswho
    set -l profile default
    set -q AWS_PROFILE; and set profile $AWS_PROFILE
    command aws sts get-caller-identity --profile $profile $argv
end

function _photontoaster_aws_startup_login
    command -sq aws; or return 0
    _photontoaster_aws_profile_has_sso; or return 0

    set -l stamp_file (_photontoaster_aws_stamp_file)
    set -l last_check 0
    if test -f $stamp_file
        read -l line <"$stamp_file"
        set last_check (string trim -- $line)
        test -z "$last_check"; and set last_check 0
    end

    set -l now (date +%s)
    set -l elapsed 0
    if string match -qr '^-?[0-9]+$' -- $last_check
        set elapsed (math "$now - $last_check")
    end
    test $elapsed -gt (math '8 * 60 * 60'); or return 0

    set_color 6e9bf5
    echo -n 'aws sso login'
    set_color normal
    echo -n ' for profile '
    set_color 967dff
    echo (awsp)
    set_color normal
    awsl
end
