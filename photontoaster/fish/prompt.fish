# PhotonToaster fish prompt — segment-driven, theme-aware rendering
# Mirrors the zsh/bash prompt: configurable segments via prompt.left/prompt.right.

function _pt_short_path
    if test "$PWD" = "$HOME"
        echo '~'; return
    end
    if string match -q "$HOME/*" -- $PWD
        set -l tail (string replace "$HOME/" '' -- $PWD)
        set -l parts (string split / -- $tail)
        set -l n (count $parts)
        if test $n -le 2
            echo '~/'(string join / -- $parts)
        else
            echo '~/'(string join / -- $parts[-2..-1])
        end
        return
    end
    set -l raw (string split / -- $PWD)
    set -l parts $raw[2..-1]
    set -l n (count $parts)
    if test $n -eq 0
        echo /
    else if test $n -le 2
        echo /(string join / -- $parts)
    else
        echo /(string join / -- $parts[-2..-1])
    end
end

set -g __pt_seg_bg ''
set -g __pt_seg_fg ''
set -g __pt_seg_text ''

function _pt_seg_set
    set -g __pt_seg_bg $argv[1]
    set -g __pt_seg_fg $argv[2]
    set -l text $argv[3]
    set -l icon ''
    test (count $argv) -ge 4; and set icon $argv[4]
    if test -n "$icon" -a -n "$text"
        set -g __pt_seg_text "$icon $text"
    else if test -n "$icon"
        set -g __pt_seg_text "$icon"
    else
        set -g __pt_seg_text "$text"
    end
end

function _pt_segment_user
    set -l icon ''
    set -l show_icon (set -q _pt_config_prompt_icon_user; and echo $_pt_config_prompt_icon_user; or echo true)
    test "$show_icon" != false; and set icon \uF007
    set -l color $PT_BLUE
    set -l label $USER
    if test -n "$SSH_TTY" -o -n "$SSH_CONNECTION"
        set color $PT_SSH
        set label "$USER@"(hostname -s)
    end
    _pt_seg_set $color $PT_DARK "$label" "$icon"
end

function _pt_segment_ssh
    test -n "$SSH_TTY" -o -n "$SSH_CONNECTION"; or return 1
    _pt_seg_set $PT_SSH $PT_DARK ssh \uF0C2
end

function _pt_segment_path
    set -l icon ''
    set -l show_icon (set -q _pt_config_prompt_icon_path; and echo $_pt_config_prompt_icon_path; or echo true)
    if test "$show_icon" != false
        test "$PWD" = "$HOME"; and set icon \uF015; or set icon \uF07B
    end
    _pt_seg_set $PT_VIOLET $PT_DARK (_pt_short_path) "$icon"
end

function _pt_segment_git
    set -l branch (git rev-parse --abbrev-ref HEAD 2>/dev/null); or return 1
    set -l color $PT_BLUE
    set -l label $branch
    if not git diff --quiet HEAD 2>/dev/null
        set label "$label*"
        set color $PT_WARN
    end
    _pt_seg_set $color $PT_DARK "$label" \uE0A0
end

function _pt_segment_venv
    test -n "$VIRTUAL_ENV"; or return 1
    set -l name (basename $VIRTUAL_ENV)
    _pt_seg_set $PT_VENV $PT_DARK "$name" \uE73C
end

function _pt_segment_jobs
    set -l njobs (count (jobs -p 2>/dev/null))
    test $njobs -gt 0; or return 1
    _pt_seg_set $PT_WARN $PT_DARK "$njobs" \uF013
end

function _pt_segment_status
    set -l code $__pt_status
    if test $code -eq 0
        _pt_seg_set $PT_OK $PT_DARK \uF00C
    else if contains $code 130 131 148
        _pt_seg_set $PT_WARN $PT_DARK \uF071
    else
        _pt_seg_set $PT_ERR $PT_WHITE "\uF00D $code"
    end
end

function _pt_segment_duration
    test -n "$CMD_DURATION"; or return 1
    set -l threshold (set -q _pt_config_prompt_duration_threshold; and echo $_pt_config_prompt_duration_threshold; or echo 3000)
    test $CMD_DURATION -ge $threshold; or return 1
    set -l s (math "floor($CMD_DURATION / 1000)")
    set -l label
    if test $s -ge 3600
        set label (math "floor($s / 3600)")"h"(math "floor($s % 3600 / 60)")"m"
    else if test $s -ge 60
        set label (math "floor($s / 60)")"m"(math "$s % 60")"s"
    else
        set label "$s""s"
    end
    _pt_seg_set $PT_ACCENT $PT_DARK "$label" \uF017
end

function _pt_segment_time
    _pt_seg_set $PT_VIOLET $PT_DARK (date '+%H:%M:%S')
end

function _pt_render_segments --argument-names side
    set -l cfg_var "_pt_config_prompt_$side"
    set -l cfg ''
    if set -q $cfg_var
        set cfg $$cfg_var
    else
        test "$side" = left; and set cfg 'user,path,git,venv,jobs'; or set cfg 'status,duration,time'
    end

    set -l seg_bgs
    set -l seg_fgs
    set -l seg_texts
    for seg in (string split , -- $cfg)
        if functions -q _pt_segment_$seg
            if _pt_segment_$seg
                set -a seg_bgs $__pt_seg_bg
                set -a seg_fgs $__pt_seg_fg
                set -a seg_texts $__pt_seg_text
            end
        end
    end

    set -l n (count $seg_bgs)
    test $n -eq 0; and return

    set -l theme (set -q _pt_config_prompt_style; and echo $_pt_config_prompt_style; or echo pills)
    switch $theme
        case pills-merged
            for i in (seq $n)
                set -l bg $seg_bgs[$i]; set -l fg $seg_fgs[$i]; set -l text $seg_texts[$i]
                if test $i -eq 1
                    set_color $bg -b normal; printf '%s' \uE0B6
                end
                set_color $fg -b $bg
                test $i -gt 1; and printf ' '
                printf '%s' $text
                test $i -lt $n; and printf ' '
                if test $i -eq $n
                    set_color $bg -b normal; printf '%s' \uE0B4
                end
            end
        case plain
            for i in (seq $n)
                set -l bg $seg_bgs[$i]; set -l fg $seg_fgs[$i]; set -l text $seg_texts[$i]
                test $i -gt 1; and printf ' '
                set_color $fg -b $bg
                printf '%s' $text
                set_color normal
            end
        case minimal
            for i in (seq $n)
                set_color $seg_bgs[$i]
                printf '%s ' $seg_texts[$i]
                set_color normal
            end
        case '*'
            for i in (seq $n)
                set -l bg $seg_bgs[$i]; set -l fg $seg_fgs[$i]; set -l text $seg_texts[$i]
                set_color $bg -b normal; printf '%s' \uE0B6
                set_color $fg -b $bg; printf '%s' $text
                set_color $bg -b normal; printf '%s' \uE0B4
                set_color normal
            end
    end
    set_color normal
end

function fish_prompt
    set -g __pt_status $status
    _pt_render_segments left
    printf ' '
end

function fish_right_prompt
    _pt_render_segments right
end
