#!/usr/bin/env bash
# test.sh — smoke tests for neko.
#
# Uses a fake `paru` stub in a temp dir on PATH so no real packages are
# touched. Verifies:
#   - help / version / logo output
#   - subcommand → paru-flag translation
#   - passthrough for unknown args
#   - the `--` separator
#   - autoremove (preview + --no-info)
#   - error paths for missing required args

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEKO="$SCRIPT_DIR/neko"

[ -x "$NEKO" ] || { echo "no executable neko at $NEKO"; exit 1; }

PASS=0
FAIL=0

pass_case() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
fail_case() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# --------------------------------------------------------------------------
# Stub paru: echoes each argument on its own line, prefixed with "ARG:".
# Special-cases `paru -Qtdq` to emit a fake orphan list.
# --------------------------------------------------------------------------
STUB_DIR="$(mktemp -d)"
trap 'rm -rf "$STUB_DIR"' EXIT

cat > "$STUB_DIR/paru" <<'STUB'
#!/usr/bin/env bash
if [ "$#" -eq 1 ] && [ "$1" = "-Qtdq" ]; then
    printf '%s\n' "fake-orphan-1" "fake-orphan-2"
    exit 0
fi
if [ "$1" = "-V" ]; then
    echo "paru v9.9.9 (test stub)"
    exit 0
fi
for a in "$@"; do
    printf 'ARG:%s\n' "$a"
done
STUB
chmod +x "$STUB_DIR/paru"

export PATH="$STUB_DIR:$PATH"
export NO_COLOR=1

# Force the Garuda detection off by default so tests behave the same on
# Garuda and non-Garuda hosts. The Garuda-specific test flips this on.
export NEKO_IS_GARUDA=0

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
expect_args() {
    # expect_args <desc> <expected-stdout> <neko-args...>
    local desc="$1" expected="$2"; shift 2
    local actual
    actual="$("$NEKO" "$@" 2>/dev/null)" || true
    if [ "$actual" = "$expected" ]; then
        pass_case "$desc"
    else
        fail_case "$desc"
        printf '    expected: %q\n' "$expected"
        printf '    actual:   %q\n' "$actual"
    fi
}

expect_contains() {
    # expect_contains <desc> <needle> <neko-args...>
    local desc="$1" needle="$2"; shift 2
    local actual
    actual="$("$NEKO" "$@" 2>&1)" || true
    if printf '%s' "$actual" | grep -qF -- "$needle"; then
        pass_case "$desc"
    else
        fail_case "$desc"
        printf '    expected to contain: %s\n' "$needle"
    fi
}

# --------------------------------------------------------------------------
# Tests
# --------------------------------------------------------------------------
echo "Running neko tests…"

# Help / version / logo
expect_contains "help mentions USAGE"              "USAGE"                 help
expect_contains "bare neko prints help"            "COMMANDS"
expect_contains "--version shows neko version"     "neko 0.1.0"            --version
expect_contains "--version shows paru version"    "paru v9.9.9"           --version
expect_contains "help mentions homepage"           "casparjones.github.io" help

# Subcommand translations
expect_args "update → -Syu"          "ARG:-Syu"                               update
expect_args "update-db → -Syy"       "ARG:-Syy"                               update-db
expect_args "install x → -S x"       "$(printf 'ARG:-S\nARG:firefox')"         install firefox
expect_args "remove x → -Rns x"      "$(printf 'ARG:-Rns\nARG:firefox')"       remove firefox
expect_args "search q → -Ss q"       "$(printf 'ARG:-Ss\nARG:vim')"            search vim
expect_args "info x → -Si x"         "$(printf 'ARG:-Si\nARG:firefox')"        info firefox
expect_args "list → -Qe"             "ARG:-Qe"                                list
expect_args "list-all → -Q"          "ARG:-Q"                                 list-all
expect_args "owns /x → -Qo /x"       "$(printf 'ARG:-Qo\nARG:/usr/bin/git')"   owns /usr/bin/git
expect_args "files x → -Ql x"        "$(printf 'ARG:-Ql\nARG:firefox')"        files firefox
expect_args "clean → -Sc"            "ARG:-Sc"                                clean
expect_args "clean-all → -Scc"       "ARG:-Scc"                               clean-all
expect_args "outdated → -Qu"         "ARG:-Qu"                                outdated

# orphans: stub returns the fake list
expect_contains "orphans uses -Qtdq via stub" "fake-orphan-1" orphans

# Passthrough (unknown → forwarded to paru verbatim)
expect_args "passthrough -Syu"       "ARG:-Syu"                               -Syu
expect_args "passthrough -Qi pkg"    "$(printf 'ARG:-Qi\nARG:firefox')"        -Qi firefox

# `--` separator: reaches paru's own -v
expect_args "-- -v → paru -v"        "ARG:-v"                                 -- -v

# autoremove with --no-info: no preview, just -Rns on stubbed orphans
expect_args "autoremove --no-info"   "$(printf 'ARG:-Rns\nARG:fake-orphan-1\nARG:fake-orphan-2')" autoremove --no-info

# autoremove WITHOUT --no-info: preview goes to stderr
preview="$("$NEKO" autoremove 2>&1 >/dev/null)" || true
if printf '%s' "$preview" | grep -q "fake-orphan-1"; then
    pass_case "autoremove preview lists orphans on stderr"
else
    fail_case "autoremove preview lists orphans on stderr"
fi

# Garuda flow: with NEKO_IS_GARUDA=1 and a garuda-update stub, `neko update`
# should run garuda-update first, then paru -Syu. Non-interactive stdin ⇒
# default answer is Y.
GARUDA_MARKER="$STUB_DIR/garuda-update.called"
cat > "$STUB_DIR/garuda-update" <<STUB
#!/usr/bin/env bash
printf 'garuda-update ran\n' > "$GARUDA_MARKER"
STUB
chmod +x "$STUB_DIR/garuda-update"

garuda_out="$(NEKO_IS_GARUDA=1 "$NEKO" update </dev/null 2>/dev/null)" || true
if [ "$garuda_out" = "ARG:-Syu" ] && [ -f "$GARUDA_MARKER" ]; then
    pass_case "garuda: default-Y runs garuda-update then paru -Syu"
else
    fail_case "garuda: default-Y runs garuda-update then paru -Syu"
    printf '    stdout:  %q\n' "$garuda_out"
    printf '    marker:  %s\n' "$([ -f "$GARUDA_MARKER" ] && echo present || echo missing)"
fi
rm -f "$GARUDA_MARKER"

# Declining the prompt should skip garuda-update and still run paru -Syu.
garuda_out="$(printf 'n\n' | NEKO_IS_GARUDA=1 "$NEKO" update 2>/dev/null)" || true
if [ "$garuda_out" = "ARG:-Syu" ] && [ ! -f "$GARUDA_MARKER" ]; then
    pass_case "garuda: answering n skips garuda-update"
else
    fail_case "garuda: answering n skips garuda-update"
    printf '    stdout:  %q\n' "$garuda_out"
    printf '    marker:  %s\n' "$([ -f "$GARUDA_MARKER" ] && echo present || echo missing)"
fi
rm -f "$GARUDA_MARKER"

# Error paths: missing required args (capture first — neko exits non-zero on die)
out="$("$NEKO" install 2>&1)" || true
if printf '%s' "$out" | grep -q "package name required"; then
    pass_case "install without args errors out"
else
    fail_case "install without args errors out"
fi

# Paru-missing behaviour: build a minimal PATH with bash+env only (no paru),
# independent of whether a real paru exists on the system.
minimal_path="$(mktemp -d)"
for cmd in env bash; do
    src="$(PATH=/usr/bin:/bin command -v "$cmd" 2>/dev/null || true)"
    [ -n "$src" ] && ln -s "$src" "$minimal_path/$cmd"
done
out="$(PATH="$minimal_path" "$NEKO" install firefox 2>&1)" || true
if printf '%s' "$out" | grep -q "paru is not installed"; then
    pass_case "missing paru produces a helpful error"
else
    fail_case "missing paru produces a helpful error"
    printf '    actual: %s\n' "$out"
fi
rm -rf "$minimal_path"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
