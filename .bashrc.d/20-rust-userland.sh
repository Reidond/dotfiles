# Rust-first userland for POSIX shells.
# Preference order:
#   1) Modern Rust UX tools (interactive only)
#   2) uutils/coreutils wrappers
#   3) System default (GNU/core system)

# Detect interactive shell in a portable way.
# POSIX shells typically set PS1 for interactive sessions.
if [ -n "${PS1-}" ]; then
    __interactive=1
else
    __interactive=0
fi

# Detect VSCode terminal.
# Use common environment hints without depending on shell-specific variables.
if [ -n "${VSCODE_PID-}" ] || [ "${TERM_PROGRAM-}" = "vscode" ]; then
    __vscode=1
else
    __vscode=0
fi

# Select mode.
#   full   → modern Rust UX aliases + coreutils
#   compat → coreutils only
if [ -z "${RUST_USERLAND_MODE-}" ]; then
    if [ "$__interactive" -eq 1 ] && [ "$__vscode" -eq 0 ]; then
        __mode=full
    else
        __mode=compat
    fi
else
    __mode=$RUST_USERLAND_MODE
fi

# Enable Rust coreutils wrappers if installed (Fedora location).
# This provides Rust drop-in versions of many classic coreutils names.
if [ -d /usr/libexec/uutils-coreutils ]; then
    case ":$PATH:" in
        *:/usr/libexec/uutils-coreutils:*) ;;
        *) PATH=/usr/libexec/uutils-coreutils:$PATH ;;
    esac
    export PATH
fi

# Prompt and smart cd (only when interactive AND supported shell).
# Avoid trying to init Starship/zoxide under pure POSIX shells like dash/ash.
if [ "$__interactive" -eq 1 ]; then
    if [ -n "${BASH_VERSION-}" ]; then
        command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
        command -v zoxide   >/dev/null 2>&1 && eval "$(zoxide init bash)"
    elif [ -n "${ZSH_VERSION-}" ]; then
        command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
        command -v zoxide   >/dev/null 2>&1 && eval "$(zoxide init zsh)"
    fi
fi

# Modern Rust UX aliases.
# These are not strict GNU drop-ins; keep them interactive-only.
if [ "$__interactive" -eq 1 ] && [ "$__mode" = full ]; then
    if command -v eza >/dev/null 2>&1; then
        alias ls='eza -al --group-directories-first --icons=auto'
        alias la='eza -a  --group-directories-first --icons=auto'
        alias ll='eza -l  --group-directories-first --icons=auto'
        alias lt='eza -aT --group-directories-first --icons=auto'
    fi

    if command -v bat >/dev/null 2>&1; then
        alias cat='bat --paging=never'
        alias less='bat'
    fi

    command -v fd   >/dev/null 2>&1 && alias find='fd'
    command -v rg   >/dev/null 2>&1 && alias grep='rg --no-heading --color=auto'
    command -v dust >/dev/null 2>&1 && alias du='dust'
    command -v duf  >/dev/null 2>&1 && alias df='duf'
    command -v procs >/dev/null 2>&1 && alias ps='procs'
    command -v btm  >/dev/null 2>&1 && alias top='btm'
    command -v delta >/dev/null 2>&1 && alias diff='delta'

    # Do not override sed. Provide an explicit helper if sd exists.
    command -v sd   >/dev/null 2>&1 && alias sdr='sd'
fi

# Fedora-safe helpers.
# These are benign in interactive shells and do not corrupt script expectations.
if [ "$__interactive" -eq 1 ]; then
    alias update='sudo dnf upgrade --refresh'
    alias cleanpkg='sudo dnf autoremove'
    alias fixdnf='sudo rm -f /var/cache/dnf/metadata_lock.pid'

    alias ..='cd ..'
    alias ...='cd ../..'
    alias ....='cd ../../..'
fi

unset __interactive __vscode __mode
