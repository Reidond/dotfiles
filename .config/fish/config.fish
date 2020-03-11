set PATH "$PATH:/usr/local/go/bin"

source $HOME/.poetry/env
source $HOME/.cargo/env

starship init fish | source
zoxide init fish | source
