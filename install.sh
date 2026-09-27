#!/usr/bin/env bash

set -euo pipefail

CONFIG_URL="https://raw.githubusercontent.com/diaarbadeli/bindings.dr/main/bindings.lua"
TARGET="$HOME/.config/hypr/bindings.lua"
TEMP_CONFIG="$(mktemp)"

START_MARKER="-- >>> bindings.dr managed block >>>"
END_MARKER="-- <<< bindings.dr managed block <<<"

cleanup() {
    rm -f "$TEMP_CONFIG"
}

trap cleanup EXIT

curl -fsSL "$CONFIG_URL" -o "$TEMP_CONFIG"

mkdir -p "$(dirname "$TARGET")"

# First installation: bindings.lua doesn't exist yet.
if [[ ! -f "$TARGET" ]]; then
    cp "$TEMP_CONFIG" "$TARGET"
    hyprctl reload
    echo "bindings.dr installed."
    exit 0
fi

CURRENT="$(cat "$TARGET")"
MANAGED="$(cat "$TEMP_CONFIG")"

START_COUNT="$(grep -Fc "$START_MARKER" "$TARGET" || true)"
END_COUNT="$(grep -Fc "$END_MARKER" "$TARGET" || true)"

# No markers: add our managed block to the beginning.
if [[ "$START_COUNT" -eq 0 && "$END_COUNT" -eq 0 ]]; then
    NEW_CONTENT="$MANAGED
$CURRENT"

# Exactly one complete managed block: replace it.
elif [[ "$START_COUNT" -eq 1 && "$END_COUNT" -eq 1 ]]; then
    CLEANED="$(
        awk -v start="$START_MARKER" -v end="$END_MARKER" '
            $0 == start { skip=1; next }
            $0 == end   { skip=0; next }
            !skip       { print }
        ' "$TARGET"
    )"

    NEW_CONTENT="$MANAGED
$CLEANED"

# Anything else is malformed. Don't touch the user's file.
else
    echo "Error: invalid bindings.dr managed block in $TARGET."
    echo "Expected either zero markers or exactly one start/end pair."
    exit 1
fi

# Nothing changed.
if [[ "$NEW_CONTENT" == "$CURRENT" ]]; then
    echo "bindings.dr is already up to date."
    exit 0
fi

# Keep exactly one backup.
cp "$TARGET" "$TARGET.backup"

printf '%s\n' "$NEW_CONTENT" > "$TARGET"

hyprctl reload

echo "bindings.dr updated."
