#!/bin/sh
# mao installer — https://casparjones.github.io/mao/
#
# Usage:
#   curl -sSL https://casparjones.github.io/mao/install.sh | sh
#
# Environment overrides:
#   MAO_BRANCH       branch or tag to install from     (default: main)
#   MAO_INSTALL_DIR  explicit install directory
#   MAO_YES=1        non-interactive; answer yes to all prompts

set -eu

MAO_BRANCH="${MAO_BRANCH:-main}"
MAO_REPO_RAW="https://raw.githubusercontent.com/casparjones/mao/${MAO_BRANCH}"
MAO_REPO="https://github.com/casparjones/mao"
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
    C_BLUE=$(printf '\033[34m')
    C_MAGENTA=$(printf '\033[35m')
    C_CYAN=$(printf '\033[36m')
else
    C_RESET=''; C_BOLD=''; C_DIM=''
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_MAGENTA=''; C_CYAN=''
fi

say()  { printf '%s▸%s %s\n' "${C_CYAN}"   "${C_RESET}" "$*"; }
ok()   { printf '%s✓%s %s\n' "${C_GREEN}"  "${C_RESET}" "$*"; }
warn() { printf '%s!%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "${C_RED}"    "${C_RESET}" "$*" >&2; exit 1; }
hr()   { printf '%s────────────────────────────────────────%s\n' \
                "${C_DIM}" "${C_RESET}"; }

# ---------------------------------------------------------------------------
# Interactive prompts — when run via `curl | sh`, stdin is the script,
# so we read from /dev/tty if available. MAO_YES=1 skips all prompts.
# ---------------------------------------------------------------------------
TTY=""
if [ -t 0 ]; then
    TTY="/dev/stdin"
elif [ -r /dev/tty ]; then
    TTY="/dev/tty"
fi

ANSWER=""

ask() {
    _q="$1"; _d="${2:-n}"
    if [ "${MAO_YES:-0}" = "1" ]; then
        printf '%s %s[auto: yes]%s\n' "$_q" "${C_DIM}" "${C_RESET}"
        return 0
    fi
    if [ -z "$TTY" ]; then
        warn "no TTY — defaulting '$_q' to '$_d'"
        if [ "$_d" = "y" ]; then return 0; else return 1; fi
    fi
    if [ "$_d" = "y" ]; then
        printf '%s [Y/n] ' "$_q"
    else
        printf '%s [y/N] ' "$_q"
    fi
    IFS= read -r _r < "$TTY" || _r=""
    [ -z "$_r" ] && _r="$_d"
    case "$_r" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *)                 return 1 ;;
    esac
}

ask_line() {
    _q="$1"; _d="${2:-}"
    if [ "${MAO_YES:-0}" = "1" ] || [ -z "$TTY" ]; then
        ANSWER="$_d"
        return 0
    fi
    printf '%s [%s] ' "$_q" "$_d"
    IFS= read -r ANSWER < "$TTY" || ANSWER=""
    [ -z "$ANSWER" ] && ANSWER="$_d"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found"
}

download() {
    _url="$1"; _out="$2"
    curl -fsSL "$_url" -o "$_out"
}

# ---------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------
install_paru() {
    say "installing paru from AUR…"
    require_cmd sudo
    sudo pacman -S --needed base-devel git
    _tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$_tmp/paru"
    ( cd "$_tmp/paru" && makepkg -si )
    rm -rf "$_tmp"
}

path_hint() {
    _dir="$1"
    _shell_name=""
    case "${SHELL:-}" in
        */fish) _shell_name=fish ;;
        */bash) _shell_name=bash ;;
        */zsh)  _shell_name=zsh  ;;
    esac
    case "$_shell_name" in
        fish) printf '  fish:  %sfish_add_path %s%s\n' \
                     "${C_BOLD}" "$_dir" "${C_RESET}" ;;
        bash) printf '  bash:  %secho '\''export PATH="%s:$PATH"'\'' >> ~/.bashrc%s\n' \
                     "${C_BOLD}" "$_dir" "${C_RESET}" ;;
        zsh)  printf '  zsh:   %secho '\''export PATH="%s:$PATH"'\'' >> ~/.zshrc%s\n' \
                     "${C_BOLD}" "$_dir" "${C_RESET}" ;;
        *)    printf '  add %s to your $PATH.\n' "$_dir" ;;
    esac
}

install_completion() {
    _name="$1"; _target="$2"
    mkdir -p "$(dirname "$_target")"
    if download "$MAO_REPO_RAW/completions/$_name" "$_target.tmp"; then
        mv "$_target.tmp" "$_target"
        ok "installed $_target"
    else
        rm -f "$_target.tmp"
        warn "failed to download completion '$_name'"
    fi
}

install_tray() {
    _tray_dir="$1"
    _tray_path="$_tray_dir/mao-tray"

    hr
    printf '%s   /\_/\   %s%smao-tray setup%s\n' "${C_MAGENTA}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    printf '%s  ( ^.^ )  %s%ssystem tray update notifier%s\n' "${C_MAGENTA}" "${C_RESET}" "${C_DIM}" "${C_RESET}"
    hr

    # --- dependency check ---------------------------------------------------
    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 not found — cannot install mao-tray"
        return
    fi
    if ! python3 -c "import PyQt6" 2>/dev/null; then
        warn "python-pyqt6 not found (required for mao-tray)"
        if ask "  Install python-pyqt6 now? (sudo pacman -S python-pyqt6)" y; then
            sudo pacman -S --needed python-pyqt6 || {
                warn "install failed — skipping mao-tray"
                return
            }
        else
            warn "skipping mao-tray — install python-pyqt6 and re-run the installer"
            return
        fi
    fi

    # --- download mao-tray --------------------------------------------------
    if download "$MAO_REPO_RAW/mao-tray" "$_tray_path.tmp"; then
        chmod +x "$_tray_path.tmp"
        mv "$_tray_path.tmp" "$_tray_path"
        ok "mao-tray installed → $_tray_path"
    else
        rm -f "$_tray_path.tmp"
        warn "failed to download mao-tray"
        return
    fi

    # --- configure: auto-update ---------------------------------------------
    printf '\n'
    say "Configuration (saved to ${C_BOLD}~/.config/mao/tray.json${C_RESET}):"
    printf '\n'

    _auto_update="false"
    _setup_sudoers=0

    printf '  %sAuto-update%s: automatically install updates every hour in the background.\n' \
           "${C_BOLD}" "${C_RESET}"
    printf '  %sNote: requires passwordless sudo for pacman (you can set this up below).%s\n' \
           "${C_DIM}" "${C_RESET}"
    if ask "  Enable auto-update?" n; then
        _auto_update="true"
        printf '\n'
        printf '  %sSilent updates need pacman to run without a password prompt.%s\n' \
               "${C_DIM}" "${C_RESET}"
        printf '  %sThis creates: /etc/sudoers.d/mao-tray%s\n' \
               "${C_DIM}" "${C_RESET}"
        if ask "  Set up passwordless pacman via sudoers now?" y; then
            _setup_sudoers=1
        fi
    fi

    # --- write config -------------------------------------------------------
    _conf_dir="$HOME/.config/mao"
    mkdir -p "$_conf_dir"
    printf '{"auto_update": %s}\n' "$_auto_update" > "$_conf_dir/tray.json"
    ok "config saved → $_conf_dir/tray.json"

    # --- optional sudoers ---------------------------------------------------
    if [ "$_setup_sudoers" -eq 1 ]; then
        printf '%%wheel ALL=(ALL) NOPASSWD: /usr/bin/pacman\n' \
            | sudo tee /etc/sudoers.d/mao-tray >/dev/null \
            && sudo chmod 440 /etc/sudoers.d/mao-tray \
            && ok "sudoers entry created → /etc/sudoers.d/mao-tray" \
            || warn "sudoers setup failed — add it manually if needed"
    fi

    # --- XDG autostart ------------------------------------------------------
    printf '\n'
    _autostart_dir="$HOME/.config/autostart"
    if ask "  Start mao-tray automatically on login? (XDG autostart)" y; then
        mkdir -p "$_autostart_dir"
        if download "$MAO_REPO_RAW/mao-tray.desktop" "$_autostart_dir/mao-tray.desktop.tmp"; then
            mv "$_autostart_dir/mao-tray.desktop.tmp" "$_autostart_dir/mao-tray.desktop"
            ok "autostart entry installed → $_autostart_dir/mao-tray.desktop"
        else
            rm -f "$_autostart_dir/mao-tray.desktop.tmp"
            warn "could not download autostart entry"
        fi
    fi

    # --- summary ------------------------------------------------------------
    printf '\n'
    printf '  %sLog file:%s  ~/.local/share/mao/tray.log\n' "${C_DIM}" "${C_RESET}"
    printf '  %sConfig:%s    ~/.config/mao/tray.json\n' "${C_DIM}" "${C_RESET}"
    printf '\n'
    ok "start now with: ${C_BOLD}mao-tray &${C_RESET}"
}

install_completions() {
    if [ "$(id -u)" -eq 0 ]; then
        fish_dir="/usr/share/fish/vendor_completions.d"
        bash_dir="/usr/share/bash-completion/completions"
        zsh_dir="/usr/share/zsh/site-functions"
    else
        fish_dir="$HOME/.config/fish/completions"
        bash_dir="$HOME/.local/share/bash-completion/completions"
        zsh_dir="$HOME/.local/share/zsh/site-functions"
    fi

    if command -v fish >/dev/null 2>&1; then
        if ask "  install fish completion → $fish_dir/mao.fish?" y; then
            install_completion mao.fish "$fish_dir/mao.fish"
        fi
    fi
    if command -v bash >/dev/null 2>&1; then
        if ask "  install bash completion → $bash_dir/mao?" y; then
            install_completion mao.bash "$bash_dir/mao"
        fi
    fi
    if command -v zsh >/dev/null 2>&1; then
        if ask "  install zsh completion  → $zsh_dir/_mao?" y; then
            install_completion _mao "$zsh_dir/_mao"
            warn "  make sure '$zsh_dir' is in your zsh \$fpath"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    hr
    printf '%s   /\_/\   %s\n' "${C_MAGENTA}" "${C_RESET}"
    printf '%s  ( ^.^ )  %s%smao installer%s\n' "${C_MAGENTA}" "${C_RESET}" "${C_BOLD}${C_MAGENTA}" "${C_RESET}"
    printf '%s   > ~ <   %s%s%s%s\n' "${C_MAGENTA}" "${C_RESET}" "${C_DIM}" "$MAO_HOMEPAGE" "${C_RESET}"
    hr

    require_cmd curl

    # 1. Arch check
    if ! command -v pacman >/dev/null 2>&1 && [ ! -f /etc/arch-release ]; then
        die "this does not look like an Arch-based system (no pacman, no /etc/arch-release)."
    fi
    ok "Arch-based system detected"

    # 2. paru check
    if command -v paru >/dev/null 2>&1; then
        ok "paru found: $(command -v paru)"
    else
        warn "paru is not installed."
        if ask "Install paru now from the AUR? (uses sudo, base-devel, git)" n; then
            install_paru
            ok "paru installed"
        else
            warn "skipping paru install — mao won't work until paru is available."
        fi
    fi

    # 3. choose install dir
    if [ -n "${MAO_INSTALL_DIR:-}" ]; then
        install_dir="$MAO_INSTALL_DIR"
    elif [ "$(id -u)" -eq 0 ]; then
        install_dir="/usr/local/bin"
    else
        ask_line "Install mao to which directory?" "$HOME/.local/bin"
        install_dir="$ANSWER"
    fi
    install_path="$install_dir/mao"

    if [ -f "$install_path" ]; then
        say "updating mao at $install_path"
    else
        say "installing mao → $install_path"
    fi
    mkdir -p "$install_dir"

    # 4. download mao
    if ! download "$MAO_REPO_RAW/mao" "$install_path.tmp"; then
        rm -f "$install_path.tmp"
        die "failed to download mao from $MAO_REPO_RAW/mao"
    fi
    chmod +x "$install_path.tmp"
    mv "$install_path.tmp" "$install_path"
    ok "mao installed at $install_path"

    # 5. PATH check
    case ":$PATH:" in
        *":$install_dir:"*)
            ok "$install_dir is already in \$PATH"
            ;;
        *)
            warn "$install_dir is not in your \$PATH yet. Add it with:"
            path_hint "$install_dir"
            ;;
    esac

    # 6. completions
    if ask "Install shell completions?" y; then
        install_completions
    fi

    # 7. mao-tray (optional)
    if ask "Install mao-tray (system tray update notifier)?" n; then
        install_tray "$install_dir"
    fi

    hr
    ok "done! try: ${C_BOLD}mao help${C_RESET}"
    printf '  homepage: %s%s%s\n' "${C_BLUE}" "$MAO_HOMEPAGE" "${C_RESET}"
    hr
}

main "$@"
