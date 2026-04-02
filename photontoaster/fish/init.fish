# PhotonToaster fish init — config loading, session startup

set -l _pt_config_dir (set -q PHOTONTOASTER_CONFIG_DIR; and echo $PHOTONTOASTER_CONFIG_DIR; or echo $HOME/.config/photontoaster)
set -l _pt_config_reader $_pt_config_dir/shared/pt-config-read

# Parse config.toml into global variables: _pt_config_<dotted.key> = value
if test -x $_pt_config_reader
    for line in ($_pt_config_reader)
        set -l k (string split -m1 '=' -- $line)[1]
        set -l v (string split -m1 '=' -- $line)[2]
        # Fish doesn't allow dots in variable names; replace with underscore
        set -l safe_k (string replace -a '.' '_' -- $k)
        set -g _pt_config_$safe_k $v
    end
end

# Map PHOTONTOASTER_C_* env vars to fish-friendly RGB hex for set_color
function _pt_rgb_to_hex --argument-names rgb fallback
    if test -z "$rgb"
        set rgb $fallback
    end
    set -l parts (string split ';' -- $rgb)
    printf '%02x%02x%02x' $parts[1] $parts[2] $parts[3]
end
set -g PT_BLUE (_pt_rgb_to_hex "$PHOTONTOASTER_C_BLUE" "110;155;245")
set -g PT_VIOLET (_pt_rgb_to_hex "$PHOTONTOASTER_C_VIOLET" "150;125;255")
set -g PT_OK (_pt_rgb_to_hex "$PHOTONTOASTER_C_OK" "80;250;120")
set -g PT_ERR (_pt_rgb_to_hex "$PHOTONTOASTER_C_ERR" "255;90;90")
set -g PT_WARN (_pt_rgb_to_hex "$PHOTONTOASTER_C_WARN" "255;220;60")
set -g PT_WHITE (_pt_rgb_to_hex "$PHOTONTOASTER_C_WHITE" "245;245;255")
set -g PT_DARK (_pt_rgb_to_hex "$PHOTONTOASTER_C_DARK" "24;28;40")
set -g PT_ACCENT (_pt_rgb_to_hex "$PHOTONTOASTER_C_ACCENT" "255;100;255")
set -g PT_SSH (_pt_rgb_to_hex "$PHOTONTOASTER_C_SSH" "255;165;0")
set -g PT_VENV (_pt_rgb_to_hex "$PHOTONTOASTER_C_VENV" "60;180;75")

# Source the prompt
set -l _pt_prompt_fish $_pt_config_dir/fish/prompt.fish
test -r $_pt_prompt_fish; and source $_pt_prompt_fish

# zoxide: alias cd to z
set -l _cd_z_enabled (set -q _pt_config_general_cd_to_z; and echo $_pt_config_general_cd_to_z; or echo true)
if test "$_cd_z_enabled" = true; and type -q zoxide
    zoxide init fish | source
    abbr -a cd z
end

# Dynamic ls aliases based on general.ls_tool config
set -l _ls_tool (set -q _pt_config_general_ls_tool; and echo $_pt_config_general_ls_tool; or echo eza)
switch $_ls_tool
    case lsd
        abbr -a l -- 'lsd -lAh'
        abbr -a ls -- lsd
        abbr -a lsa -- 'lsd -a'
        abbr -a la -- 'lsd -a'
        abbr -a ll -- 'lsd -lh'
        abbr -a lla -- 'lsd -lAh'
        abbr -a lt -- 'lsd --tree --depth=2'
        abbr -a tree -- 'lsd --tree'
    case broot
        abbr -a l -- 'broot --sizes --dates --permissions'
        abbr -a ls -- 'broot --sizes --dates --permissions'
        abbr -a lsa -- 'broot --sizes --dates --permissions --hidden'
        abbr -a la -- 'broot --sizes --dates --permissions --hidden'
        abbr -a ll -- 'broot --sizes --dates --permissions'
        abbr -a lla -- 'broot --sizes --dates --permissions --hidden'
        abbr -a lt -- 'broot --sizes'
        abbr -a tree -- 'broot --sizes'
    case ls
        abbr -a l -- 'ls -lAH --color=auto'
        abbr -a ls -- 'ls --color=auto'
        abbr -a lsa -- 'ls -a --color=auto'
        abbr -a la -- 'ls -a --color=auto'
        abbr -a ll -- 'ls -lAh --color=auto'
        abbr -a lla -- 'ls -lAh --color=auto'
        abbr -a lt -- 'tree -L 2'
    case '*'
        abbr -a l -- 'eza -lah'
        abbr -a ls -- eza
        abbr -a lsa -- 'eza -a'
        abbr -a la -- 'eza -a'
        abbr -a ll -- 'eza -lh'
        abbr -a lla -- 'eza -lah'
        abbr -a lt -- 'eza --tree --level=2'
        abbr -a tree -- 'eza --tree'
end

if not set -q PHOTONTOASTER_SESSION_INIT
    set -gx PHOTONTOASTER_SESSION_INIT 1

    set -l _vf $_pt_config_dir/version
    if test -r $_vf
        set -l _ver (cat $_vf | string trim)
        printf '\033[38;2;255;100;255m\uf120 PhotonToaster v%s\033[0m\n' $_ver
    end

    set -l _qt $_pt_config_dir/shared/pt-quote
    set -l _qotd_enabled (set -q _pt_config_general_quote_of_the_day; and echo $_pt_config_general_quote_of_the_day; or echo true)
    if test -x $_qt; and test "$_qotd_enabled" = true
        $_qt
    end
end
