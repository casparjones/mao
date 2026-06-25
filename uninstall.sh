#!/bin/sh
# mao uninstaller — https://casparjones.github.io/mao/
#
# Usage:
#   curl -sSL https://casparjones.github.io/mao/uninstall.sh | sh
#   mao uninstall

set -eu

MAO_HOMEPAGE="https://casparjones.github.io/mao/"

# ---------------------------------------------------------------------------
# Colors (respect NO_COLOR; only colorize on a real TTY)
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
    C_RESET=$(printf '\033[0m')
    C_BOLD=$(printf '\033[1m')
    C_DIM=$(printf '\033[2m')
    C_RED=$(printf '\033[31m')
    C_GREEN=$(printf '\033[32m')
    C_YELLOW=$(printf '\033[33m')
    C_MAGENTA=$(printf '\033[35m')
    C_CYAN=$(printf '\033[36m')
else
    C_RESET=''; C_BOLD=''; C_DIM=''
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_MAGENTA=''; C_CYAN=''
fi

say()  { printf '%s▸%s %s\n'  "${C_CYAN}"    "${C_RESET}" "$*"; }
ok()   { printf '%s✓%s %s\n'  "${C_GREEN}"   "${C_RESET}" "$*"; }
skip() { printf '%s–%s %s\n'  "${C_DIM}"     "${C_RESET}" "$*"; }
warn() { printf '%s!%s %s\n'  "${C_YELLOW}"  "${C_RESET}" "$*" >&2; }
die()  { printf '%s✗%s %s\n'  "${C_RED}"     "${C_RESET}" "$*" >&2; exit 1; }
hr()   { printf '%s────────────────────────────────────────%s\n' \
                "${C_DIM}" "${C_RESET}"; }

# ---------------------------------------------------------------------------
# Interactive prompts — works both standalone and piped via curl | sh
# ---------------------------------------------------------------------------
TTY=""
if [ -t 0 ]; then
    TTY="/dev/stdin"
elif [ -r /dev/tty ]; then
    TTY="/dev/tty"
fi

ask() {
    _q="$1"; _d="${2:-n}"
    if [ "${MAO_YES:-0}" = "1" ]; then
        printf '%s [auto: yes]\n' "$_q"
        return 0
    fi
    if [ -z "$TTY" ]; then
        warn "no TTY — skipping '$_q'"
        [ "$_d" = "y" ] && return 0 || return 1
    fi
    if [ "$_d" = "y" ]; then
        printf '%s [Y/n] ' "$_q"
    else
        printf '%s [y/N] ' "$_q"
    fi
    IFS= read -r _r < "$TTY" || _r=""
    [ -z "$_r" ] && _r="$_d"
    case "$_r" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
remove_file() {
    _f="$1"; _label="${2:-$1}"
    if [ -f "$_f" ] || [ -L "$_f" ]; then
        rm -f "$_f" && ok "removed $_label" || warn "could not remove $_label"
    else
        skip "$_label (not found)"
    fi
}

remove_file_sudo() {
    _f="$1"; _label="${2:-$1}"
    if [ -f "$_f" ] || [ -L "$_f" ]; then
        sudo rm -f "$_f" && ok "removed $_label" || warn "could not remove $_label (try manually)"
    else
        skip "$_label (not found)"
    fi
}

remove_dir() {
    _d="$1"; _label="${2:-$1}"
    if [ -d "$_d" ]; then
        rm -rf "$_d" && ok "removed $_label" || warn "could not remove $_label"
    else
        skip "$_label (not found)"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    hr
    printf '%s   /\_/\   %s\n' "${C_MAGENTA}" "${C_RESET}"
    printf '%s  ( o.o )  %s%smao uninstaller%s\n' "${C_MAGENTA}" "${C_RESET}" "${C_BOLD}${C_RED}" "${C_RESET}"
    printf '%s   > ~ <   %s%s%s%s\n' "${C_MAGENTA}" "${C_RESET}" "${C_DIM}" "$MAO_HOMEPAGE" "${C_RESET}"
    hr

    # --- detect what's installed -------------------------------------------
    MAO_BIN="$(command -v mao 2>/dev/null || true)"
    TRAY_BIN="$(command -v mao-tray 2>/dev/null || true)"

    printf '\n%sThe following items will be removed:%s\n\n' "${C_BOLD}" "${C_RESET}"

    [ -n "$MAO_BIN"  ] && printf '  %s•%s %s\n' "${C_DIM}" "${C_RESET}" "$MAO_BIN"
    [ -n "$TRAY_BIN" ] && printf '  %s•%s %s\n' "${C_DIM}" "${C_RESET}" "$TRAY_BIN"

    # completions
    for _f in \
        "$HOME/.config/fish/completions/mao.fish" \
        "/usr/share/fish/vendor_completions.d/mao.fish" \
        "$HOME/.local/share/bash-completion/completions/mao" \
        "/usr/share/bash-completion/completions/mao" \
        "$HOME/.local/share/zsh/site-functions/_mao" \
        "/usr/share/zsh/site-functions/_mao"
    do
        [ -f "$_f" ] && printf '  %s•%s %s\n' "${C_DIM}" "${C_RESET}" "$_f"
    done

    # tray extras
    for _f in \
        "$HOME/.config/autostart/mao-tray.desktop" \
        "/etc/sudoers.d/mao-tray"
    do
        [ -f "$_f" ] && printf '  %s•%s %s\n' "${C_DIM}" "${C_RESET}" "$_f"
    done

    printf '\n'

    ask "Continue with uninstall?" y || { say "Aborted."; exit 0; }
    printf '\n'

    # --- stop mao-tray if running ------------------------------------------
    if command -v pkill >/dev/null 2>&1 && pkill -0 mao-tray 2>/dev/null; then
        pkill mao-tray && ok "mao-tray process stopped" || warn "could not stop mao-tray"
    fi

    # --- binaries ----------------------------------------------------------
    say "Removing binaries…"
    [ -n "$TRAY_BIN" ] && remove_file "$TRAY_BIN" "mao-tray binary"
    # mao itself is removed last (see below)

    # --- completions -------------------------------------------------------
    say "Removing shell completions…"
    remove_file "$HOME/.config/fish/completions/mao.fish"        "fish completion"
    remove_file "$HOME/.local/share/bash-completion/completions/mao" "bash completion"
    remove_file "$HOME/.local/share/zsh/site-functions/_mao"     "zsh completion"
    # system-wide completions need sudo
    for _f in \
        "/usr/share/fish/vendor_completions.d/mao.fish" \
        "/usr/share/bash-completion/completions/mao" \
        "/usr/share/zsh/site-functions/_mao"
    do
        [ -f "$_f" ] && remove_file_sudo "$_f"
    done

    # --- tray extras -------------------------------------------------------
    say "Removing mao-tray extras…"
    remove_file "$HOME/.config/autostart/mao-tray.desktop" "autostart entry"
    [ -f "/etc/sudoers.d/mao-tray" ] && remove_file_sudo "/etc/sudoers.d/mao-tray" "sudoers entry"

    # --- optional: config & log --------------------------------------------
    printf '\n'
    if [ -d "$HOME/.config/mao" ]; then
        if ask "Remove config directory (~/.config/mao/)?" n; then
            remove_dir "$HOME/.config/mao" "~/.config/mao/"
        else
            skip "keeping ~/.config/mao/"
        fi
    fi

    if [ -d "$HOME/.local/share/mao" ]; then
        if ask "Remove log/data directory (~/.local/share/mao/)?" n; then
            remove_dir "$HOME/.local/share/mao" "~/.local/share/mao/"
        else
            skip "keeping ~/.local/share/mao/"
        fi
    fi

    # --- remove mao itself last --------------------------------------------
    printf '\n'
    say "Removing mao…"
    [ -n "$MAO_BIN" ] && remove_file "$MAO_BIN" "mao binary"

    hr
    ok "mao has been uninstalled. Goodbye! 🐱"
    hr
}

main "$@"
