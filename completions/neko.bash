# neko completions for bash
# https://github.com/casparjones/neko
#
# Install to one of:
#   ~/.local/share/bash-completion/completions/neko
#   /usr/share/bash-completion/completions/neko

_neko() {
    local cur prev cmds subcmd
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    cmds="update update-db install remove search info list list-all owns files orphans clean clean-all autoremove outdated help version"

    # First arg: suggest sub-commands
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
        return 0
    fi

    subcmd="${COMP_WORDS[1]}"
    case "$subcmd" in
        install|info)
            if command -v pacman >/dev/null 2>&1; then
                COMPREPLY=( $(compgen -W "$(pacman -Slq 2>/dev/null)" -- "$cur") )
            fi
            ;;
        remove|files)
            if command -v pacman >/dev/null 2>&1; then
                COMPREPLY=( $(compgen -W "$(pacman -Qq 2>/dev/null)" -- "$cur") )
            fi
            ;;
        owns)
            COMPREPLY=( $(compgen -f -- "$cur") )
            ;;
        autoremove)
            COMPREPLY=( $(compgen -W "--no-info" -- "$cur") )
            ;;
    esac
}

complete -F _neko neko
