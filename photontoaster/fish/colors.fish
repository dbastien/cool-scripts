# PhotonToaster fish colors — converts PHOTONTOASTER_C_* env vars (R;G;B) to hex

function _pt_rgb_to_hex --argument-names rgb fallback
    if test -z "$rgb"
        echo $fallback
        return
    end
    set -l parts (string split ';' -- $rgb)
    if test (count $parts) -ne 3
        echo $fallback
        return
    end
    printf '%02x%02x%02x' $parts[1] $parts[2] $parts[3]
end

set -g PT_BLUE   (_pt_rgb_to_hex "$PHOTONTOASTER_C_BLUE"   6e9bf5)
set -g PT_VIOLET (_pt_rgb_to_hex "$PHOTONTOASTER_C_VIOLET" 967dff)
set -g PT_OK     (_pt_rgb_to_hex "$PHOTONTOASTER_C_OK"     50fa78)
set -g PT_ERR    (_pt_rgb_to_hex "$PHOTONTOASTER_C_ERR"    ff5a5a)
set -g PT_WARN   (_pt_rgb_to_hex "$PHOTONTOASTER_C_WARN"   ffdc3c)
set -g PT_WHITE  (_pt_rgb_to_hex "$PHOTONTOASTER_C_WHITE"  f5f5ff)
set -g PT_DARK   (_pt_rgb_to_hex "$PHOTONTOASTER_C_DARK"   181c28)
set -g PT_ACCENT (_pt_rgb_to_hex "$PHOTONTOASTER_C_ACCENT" ff64ff)
set -g PT_SSH    (_pt_rgb_to_hex "$PHOTONTOASTER_C_SSH"    ffa500)
set -g PT_VENV   (_pt_rgb_to_hex "$PHOTONTOASTER_C_VENV"   3cb44b)
