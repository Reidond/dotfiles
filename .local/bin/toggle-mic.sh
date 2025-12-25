#!/usr/bin/env bash
set -euo pipefail

# Toggle mute on the default PipeWire microphone (audio source).
# Works best with wpctl; falls back to pactl.

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Microphone" "$1"
    fi
}

if command -v wpctl >/dev/null 2>&1; then
    # PipeWire native
    DEFAULT_SRC='@DEFAULT_AUDIO_SOURCE@'
    state="$(wpctl get-volume "$DEFAULT_SRC" 2>/dev/null || true)"

    if grep -q '\[MUTED\]' <<< "$state"; then
        wpctl set-mute "$DEFAULT_SRC" 0
        notify "Unmuted"
    else
        wpctl set-mute "$DEFAULT_SRC" 1
        notify "Muted"
    fi

elif command -v pactl >/dev/null 2>&1; then
    # PulseAudio compatibility (also via PipeWire)
    DEFAULT_SRC="$(pactl get-default-source)"
    mute_state="$(pactl get-source-mute "$DEFAULT_SRC" | awk '{print $2}')"

    if [[ "$mute_state" == "yes" ]]; then
        pactl set-source-mute "$DEFAULT_SRC" 0
        notify "Unmuted"
    else
        pactl set-source-mute "$DEFAULT_SRC" 1
        notify "Muted"
    fi
else
    echo "Neither wpctl nor pactl found in PATH." >&2
    exit 1
fi
