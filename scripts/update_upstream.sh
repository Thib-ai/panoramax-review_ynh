#!/usr/bin/env bash
# Bump this YunoHost package to the latest upstream release of
# Thib-ai/panoramax-review.
#
# What it does:
#   1. Fetch the latest tag from https://github.com/Thib-ai/panoramax-review
#   2. Download the source tarball and compute its sha256
#   3. Update manifest.toml: version, source url, source sha256
#      - resets the ~ynhN suffix to ~ynh1 when the upstream version changes
#      - bumps ~ynhN when only the packaging changed (same upstream)
#   4. Append an upgrade-from test entry for the previous package version
#
# After running, review the diff and commit + push.
#
# Usage:
#   ./scripts/update_upstream.sh           # auto-detect latest tag
#   ./scripts/update_upstream.sh v1.2.3    # use a specific tag

set -euo pipefail

REPO="Thib-ai/panoramax-review"
MANIFEST="manifest.toml"
TESTS="tests.toml"

# Resolve script dir so it works from anywhere
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PKG_DIR"

# ---- 1. Resolve target tag -------------------------------------------------

if [[ $# -ge 1 ]]; then
    TAG="$1"
else
    TAG="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
            | jq -r .tag_name)"
    if [[ -z "$TAG" || "$TAG" == "null" ]]; then
        echo "Error: could not fetch latest release tag from GitHub API" >&2
        exit 1
    fi
fi

# Accept "v1.2.3" or "1.2.3"; normalize to UPSTREAM="1.2.3", TAG="v1.2.3"
UPSTREAM="${TAG#v}"
TAG="v${UPSTREAM}"

echo "Latest upstream tag:  $TAG"
echo "Upstream version:     $UPSTREAM"

# ---- 2. Download tarball + compute sha256 ----------------------------------

URL="https://github.com/${REPO}/archive/refs/tags/${TAG}.tar.gz"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

echo "Downloading:  $URL"
curl -fsSL "$URL" -o "$TMP"
SHA="$(sha256sum "$TMP" | awk '{print $1}')"
echo "sha256:        $SHA"

# ---- 3. Read current manifest values ---------------------------------------

CUR_VERSION="$(awk -F'"' '/^version = /{print $2}' "$MANIFEST")"
CUR_URL="$(awk -F'"' '/^[[:space:]]*url[[:space:]]*=/{print $2}' "$MANIFEST" | head -1)"
CUR_SHA="$(awk -F'"' '/^[[:space:]]*sha256[[:space:]]*=/{print $2}' "$MANIFEST" | head -1)"

echo "Current package version: $CUR_VERSION"
echo "Current source url:      $CUR_URL"

if [[ "$URL" == "$CUR_URL" && "$SHA" == "$CUR_SHA" ]]; then
    echo "No upstream change (url + sha256 already match). Nothing to do."
    # Still allow a packaging-only bump if explicitly requested? For now: exit.
    exit 0
fi

# Decide new package version. If the upstream version changed, reset ~ynhN to
# ~ynh1. If only packaging changed (same upstream), bump ~ynhN.
CUR_UPSTREAM="${CUR_VERSION%%~*}"
CUR_YNH="${CUR_VERSION#*~}"
CUR_YNH="${CUR_YNH%%-*}"   # strip any suffix like "-branch"

if [[ "$UPSTREAM" == "$CUR_UPSTREAM" ]]; then
    NEW_YNH=$((CUR_YNH + 1))
    NEW_VERSION="${UPSTREAM}~ynh${NEW_YNH}"
else
    NEW_VERSION="${UPSTREAM}~ynh1"
fi

echo "New package version: $NEW_VERSION"

# ---- 4. Patch manifest.toml ------------------------------------------------

# Replace version / url / sha256 using literal-string matches so we don't
# accidentally touch other lines.
perl -i -pe "s|^version = .*|version = \"${NEW_VERSION}\"|" "$MANIFEST"
perl -i -pe "s|^[[:space:]]*url = .*|    url = \"${URL}\"|" "$MANIFEST"
perl -i -pe "s|^[[:space:]]*sha256 = .*|    sha256 = \"${SHA}\"|" "$MANIFEST"

echo "Patched $MANIFEST"

# ---- 5. Append upgrade-from test for the previous package version -----------

# Only add the entry if it doesn't already exist.
if ! grep -q "test_upgrade_from.${CUR_VERSION}.name" "$TESTS"; then
    entry="    test_upgrade_from.${CUR_VERSION}.name = \"Upgrade from ${CUR_VERSION}\""
    tmpfile="$(mktemp)"
    if grep -q '^    test_upgrade_from' "$TESTS"; then
        # Insert after the last existing test_upgrade_from line.
        awk -v new="$entry" '
            /^    test_upgrade_from/ { last = NR }
            { lines[NR] = $0 }
            END {
                for (i = 1; i <= NR; i++) {
                    print lines[i]
                    if (i == last) print new
                }
            }
        ' "$TESTS" > "$tmpfile" && mv "$tmpfile" "$TESTS"
    else
        # No existing entries: insert right after "[default]"
        awk -v new="$entry" '
            /^\[default\]/ { print; print new; next }
            { print }
        ' "$TESTS" > "$tmpfile" && mv "$tmpfile" "$TESTS"
    fi
    echo "Added upgrade-from test entry for ${CUR_VERSION}"
else
    echo "Upgrade-from test entry for ${CUR_VERSION} already present"
fi

# ---- 6. Summary -------------------------------------------------------------

echo
echo "Done. Review the diff and commit + push:"
echo "  git -C \"$PKG_DIR\" diff"
echo "  git -C \"$PKG_DIR\" add -A && git -C \"$PKG_DIR\" commit -m \"Bump upstream to ${TAG}\" && git -C \"$PKG_DIR\" push"
