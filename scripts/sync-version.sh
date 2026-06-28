#!/usr/bin/env bash
# Read VERSION and propagate to all files that embed the version string.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"

echo "Syncing version $VERSION …"

# mao main script
sed -i "s|^readonly MAO_VERSION=.*|readonly MAO_VERSION=\"$VERSION\"|" "$ROOT/mao"
echo "  updated mao"

# website badge
sed -i "s|<div class=\"version-badge\">v[^<]*</div>|<div class=\"version-badge\">v$VERSION</div>|" "$ROOT/docs/index.html"
echo "  updated docs/index.html"

# test suite
sed -i "s|\"[0-9]\+\.[0-9]\+\.[0-9]\+\".*--version|\"$VERSION\"                 --version|" "$ROOT/test.sh"
echo "  updated test.sh"

echo "Done — all files now at v$VERSION"
