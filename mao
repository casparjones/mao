#!/usr/bin/env bash
# mao — a friendly wrapper around paru for Arch Linux.
# https://github.com/casparjones/mao

set -o pipefail

readonly MAO_VERSION="0.1.2"
readonly MAO_REPO="https://github.com/casparjones/mao"
readonly MAO_HOMEPAGE="https://casparjones.github.io/mao/"

# ---------------------------------------------------------------------------
# Colors — respect NO_COLOR and only colorize on a real TTY.
# ---------------------------------------------------------------------------
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_MAGENTA=$'\033[35m'
    C_CYAN=$'\033[36m'
else
    C_RESET='' C_BOLD='' C_DIM=''
    C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN=''
fi

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
die() {
    printf '%smaomao:%s %s\n' "${C_RED}${C_BOLD}" "${C_RESET}" "$*" >&2
    exit 1
}

warn() {
    printf '%smaomao:%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*" >&2
}

info() {
    printf '%smaomao:%s %s\n' "${C_CYAN}" "${C_RESET}" "$*" >&2
}

require_paru() {
    if ! command -v paru >/dev/null 2>&1; then
        die "paru is not installed.
  Install it from the AUR:
    sudo pacman -S --needed base-devel git
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru && makepkg -si"
    fi
}

is_garuda() {
    case "${MAO_IS_GARUDA:-}" in
        0) return 1 ;;
        1) return 0 ;;
    esac
    command -v garuda-update >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Logo, help, version
# ---------------------------------------------------------------------------
print_logo() {
    printf '%s   /\_/\   %s%smaomao%s %sv%s%s\n' \
        "${C_MAGENTA}" "${C_RESET}" "${C_BOLD}" "${C_RESET}" "${C_DIM}" "${MAO_VERSION}" "${C_RESET}"
    printf '%s  ( ^.^ )  %s%sparu, but friendlier%s\n' \
        "${C_MAGENTA}" "${C_RESET}" "${C_DIM}" "${C_RESET}"
    printf '%s   > ~ <   %s\n' "${C_MAGENTA}" "${C_RESET}"
}

print_help() {
    print_logo
    cat <<EOF

${C_BOLD}USAGE${C_RESET}
  mao <command> [args...]
  mao <paru-flags...>          ${C_DIM}# unknown args are passed to paru${C_RESET}

${C_BOLD}COMMANDS${C_RESET}
  ${C_GREEN}update${C_RESET}              Update system + AUR          ${C_DIM}(paru -Syu)${C_RESET}
  ${C_GREEN}update-db${C_RESET}           Refresh package database     ${C_DIM}(paru -Syy)${C_RESET}
  ${C_GREEN}install${C_RESET} <pkg...>    Install package(s)           ${C_DIM}(paru -S)${C_RESET}
  ${C_GREEN}remove${C_RESET} <pkg...>     Remove pkg + deps + configs  ${C_DIM}(paru -Rns)${C_RESET}
  ${C_GREEN}search${C_RESET} <query>      Search repos and AUR         ${C_DIM}(paru -Ss)${C_RESET}
  ${C_GREEN}info${C_RESET} <pkg>          Show package details         ${C_DIM}(paru -Si)${C_RESET}
  ${C_GREEN}list${C_RESET}                Explicitly installed pkgs    ${C_DIM}(paru -Qe)${C_RESET}
  ${C_GREEN}list-all${C_RESET}            All installed packages       ${C_DIM}(paru -Q)${C_RESET}
  ${C_GREEN}owns${C_RESET} <file>         Which package owns <file>    ${C_DIM}(paru -Qo)${C_RESET}
  ${C_GREEN}files${C_RESET} <pkg>         Files belonging to <pkg>     ${C_DIM}(paru -Ql)${C_RESET}
  ${C_GREEN}orphans${C_RESET}             List orphaned packages       ${C_DIM}(paru -Qtdq)${C_RESET}
  ${C_GREEN}clean${C_RESET}               Clean package cache          ${C_DIM}(paru -Sc)${C_RESET}
  ${C_GREEN}clean-all${C_RESET}           Empty package cache          ${C_DIM}(paru -Scc)${C_RESET}
  ${C_GREEN}autoremove${C_RESET} [--no-info] Remove orphans             ${C_DIM}(paru -Rns \$(paru -Qtdq))${C_RESET}
  ${C_GREEN}outdated${C_RESET}            Show available updates       ${C_DIM}(paru -Qu)${C_RESET}
  ${C_GREEN}help${C_RESET}                Show this help
  ${C_GREEN}version${C_RESET}             Show mao & paru version

${C_BOLD}PASSTHROUGH${C_RESET}
  Anything that isn't a known subcommand is forwarded to paru 1:1:
    mao -Syu            → paru -Syu
    mao -Qi firefox     → paru -Qi firefox

  The only flag mao intercepts is ${C_BOLD}-v${C_RESET}/${C_BOLD}--version${C_RESET}, which shows both
  mao's and paru's version.

${C_BOLD}MORE${C_RESET}
  Homepage: ${C_BLUE}${MAO_HOMEPAGE}${C_RESET}
  Source:   ${C_BLUE}${MAO_REPO}${C_RESET}
EOF
}

print_version() {
    print_logo
    printf '\n'
    if command -v paru >/dev/null 2>&1; then
        paru -V | head -n1
    fi
}

# ---------------------------------------------------------------------------
# Commands that need a bit more than a simple paru invocation
# ---------------------------------------------------------------------------
cmd_update() {
    sudo -v || die "sudo authentication failed"
    if is_garuda; then
        local answer=""
        if [[ -t 0 ]]; then
            printf '%smaomao:%s Garuda detected. Run %sgaruda-update%s first? [Y/n] ' \
                "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}" >&2
        fi
        IFS= read -r answer 2>/dev/null || answer=""
        case "${answer,,}" in
            ""|y|yes)
                info "Running garuda-update…"
                garuda-update || die "garuda-update failed"
                ;;
        esac
    fi
    info "updating system and AUR packages → paru -Syu"
    exec paru -Syu "$@"
}

cmd_autoremove() {
    local show_info=1
    local passthrough=()
    for a in "$@"; do
        case "$a" in
            --no-info) show_info=0 ;;
            *)         passthrough+=("$a") ;;
        esac
    done

    local orphans
    orphans="$(paru -Qtdq 2>/dev/null || true)"
    if [[ -z "$orphans" ]]; then
        info "No orphaned packages. Nothing to do."
        exit 0
    fi

    if [[ $show_info -eq 1 ]]; then
        printf '%smaomao:%s the following orphaned packages will be removed:\n' \
            "${C_CYAN}" "${C_RESET}" >&2
        while IFS= read -r pkg; do
            printf '  %s- %s%s\n' "${C_DIM}" "$pkg" "${C_RESET}" >&2
        done <<<"$orphans"
        printf '%s(pass --no-info to skip this preview)%s\n' \
            "${C_DIM}" "${C_RESET}" >&2
    fi

    # shellcheck disable=SC2086
    exec paru -Rns $orphans "${passthrough[@]}"
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
main() {
    if [[ $# -eq 0 ]]; then
        print_help
        exit 0
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        help|--help|-h)        print_help ;;
        version|--version|-v)  print_version ;;

        # Explicit passthrough separator: `mao -- <anything>` → paru <anything>
        --)                    require_paru
                               info "passthrough → paru $*"
                               exec paru "$@" ;;

        update)        require_paru; cmd_update "$@" ;;
        update-db)     require_paru
                       info "refreshing package databases → paru -Syy"
                       exec paru -Syy "$@" ;;
        install)       require_paru
                       [[ $# -gt 0 ]] || die "install: at least one package name required"
                       sudo -v || die "sudo authentication failed"
                       info "installing: $* → paru -S $*"
                       exec paru -S "$@" ;;
        remove)        require_paru
                       [[ $# -gt 0 ]] || die "remove: at least one package name required"
                       info "removing: $* → paru -Rns $*"
                       exec paru -Rns "$@" ;;
        search)        require_paru
                       [[ $# -gt 0 ]] || die "search: a query is required"
                       info "searching for: $* → paru -Ss $*"
                       exec paru -Ss "$@" ;;
        info)          require_paru
                       [[ $# -gt 0 ]] || die "info: package name required"
                       info "package info: $* → paru -Si $*"
                       exec paru -Si "$@" ;;
        list)          require_paru
                       info "explicitly installed packages → paru -Qe"
                       exec paru -Qe "$@" ;;
        list-all)      require_paru
                       info "all installed packages → paru -Q"
                       exec paru -Q "$@" ;;
        owns)          require_paru
                       [[ $# -gt 0 ]] || die "owns: file path required"
                       info "owner of $* → paru -Qo $*"
                       exec paru -Qo "$@" ;;
        files)         require_paru
                       [[ $# -gt 0 ]] || die "files: package name required"
                       info "files in $* → paru -Ql $*"
                       exec paru -Ql "$@" ;;
        orphans)       require_paru
                       info "listing orphaned packages → paru -Qtdq"
                       exec paru -Qtdq "$@" ;;
        clean)         require_paru
                       info "cleaning package cache → paru -Sc"
                       exec paru -Sc "$@" ;;
        clean-all)     require_paru
                       info "emptying package cache → paru -Scc"
                       exec paru -Scc "$@" ;;
        autoremove)    require_paru; cmd_autoremove "$@" ;;
        outdated)      require_paru
                       info "checking for available updates → paru -Qu"
                       exec paru -Qu "$@" ;;

        *)             # Everything else is passthrough.
                       require_paru
                       info "passthrough → paru $cmd${*:+ $*}"
                       exec paru "$cmd" "$@" ;;
    esac
}

main "$@"
