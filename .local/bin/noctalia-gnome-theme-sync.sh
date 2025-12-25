#!/usr/bin/env bash
set -euo pipefail

# Noctalia passes current dark mode state as $1:
#   $1 = "true"  -> dark mode ON
#   $1 = "false" -> dark mode OFF
mode_arg="${1:-}"
mode_arg="${mode_arg,,}"  # lower-case, just in case

if [[ "$mode_arg" == "true" ]]; then
    dark=true
elif [[ "$mode_arg" == "false" ]]; then
    dark=false
else
    # Fallback: infer from current GNOME color-scheme if hook param is missing
    if command -v gsettings >/dev/null 2>&1; then
        current_scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")"
        if [[ "$current_scheme" == "prefer-dark" ]]; then
            dark=true
        else
            dark=false
        fi
    else
        # If we somehow have no gsettings *and* no param, just bail
        exit 0
    fi
fi

if ! command -v gsettings >/dev/null 2>&1; then
    echo "gsettings not found; cannot change GNOME/GTK theme" >&2
    exit 1
fi

if [[ "$dark" == true ]]; then
    # Dark: adw-gtk3-dark + prefer-dark (official combo from adw-gtk3 README)
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
else
    # Light: adw-gtk3 + default
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
    gsettings set org.gnome.desktop.interface color-scheme 'default'
fi
