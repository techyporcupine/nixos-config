#!/usr/bin/env bash

# File: util/update-llama-version.sh
# Purpose: Dynamic update script to fetch and pin the llama.cpp tag and hash for a machine.

set -euo pipefail

REPO_ROOT="$(git -C "${BASH_SOURCE[0]%/*}" rev-parse --show-toplevel)"

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
fi

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 [tag] <machine-or-path>"
    echo "Example: $0 b8793 nitrogen"
    echo "Example: $0 nitrogen          # auto-fetch latest tag"
    exit 1
fi

# Determine if first arg is a tag or machine target
get_latest_tag() {
    local tag=""
    if command -v gh >/dev/null 2>&1; then
        tag=$(gh release view --repo ggml-org/llama.cpp --json tagName --jq .tagName 2>/dev/null || true)
    fi
    if [ -z "$tag" ]; then
        tag=$(git ls-remote --tags --sort='v:refname' https://github.com/ggml-org/llama.cpp.git | \
              grep -o 'refs/tags/b[0-9]*' | tail -n 1 | cut -d'/' -f3)
    fi
    echo "$tag"
}

if [ "$#" -eq 1 ]; then
    # Single arg: assume it's the machine, auto-fetch tag
    TARGET="$1"
    echo "Fetching latest llama.cpp tag..."
    TAG=$(get_latest_tag)
    if [ -z "$TAG" ]; then
        echo "Error: Could not determine latest llama.cpp tag" >&2
        exit 1
    fi
    echo "Latest tag: $TAG"
else
    TAG="$1"
    TARGET="$2"
fi

# 1. Resolve the file path
FILE=""
if [ -f "$TARGET" ]; then
    FILE="$TARGET"
elif [ -f "$REPO_ROOT/machines/${TARGET}" ]; then
    FILE="$REPO_ROOT/machines/${TARGET}"
elif [ -f "$REPO_ROOT/machines/${TARGET}.nix" ]; then
    FILE="$REPO_ROOT/machines/${TARGET}.nix"
else
    echo "Error: Could not resolve target file for '$TARGET'" >&2
    exit 1
fi

echo "Target resolved: $FILE"
echo "Fetching Nix SHA256 hash for llama.cpp tag: $TAG..."

# 2. Fetch the unpacked source SHA256 hash via Nix
PREFETCH_URL="https://github.com/ggml-org/llama.cpp/archive/refs/tags/${TAG}.tar.gz"
JSON_OUTPUT=$(nix store prefetch-file --unpack --json "$PREFETCH_URL" --extra-experimental-features "nix-command flakes" 2>/dev/null || {
    # If tag isn't a direct release tag, try as a commit hash or branch
    PREFETCH_URL_ALT="https://github.com/ggml-org/llama.cpp/archive/${TAG}.tar.gz"
    nix store prefetch-file --unpack --json "$PREFETCH_URL_ALT" --extra-experimental-features "nix-command flakes"
})

HASH=$(echo "$JSON_OUTPUT" | jq -r '.hash')

if [ -z "$HASH" ]; then
    echo "Error: Failed to fetch SHA256 hash for revision $TAG" >&2
    exit 1
fi

echo "Fetched hash: $HASH"
echo "Updating $FILE..."

# 3. Validate that the file contains the expected patterns
if ! grep -qE 'llamaCppTag[[:space:]]*=' "$FILE"; then
    echo "Error: llamaCppTag not found in $FILE" >&2
    echo "Please add 'llamaCppTag = \"...\";' to the services.franken-llama block" >&2
    exit 1
fi

if ! grep -qE 'llamaCppHash[[:space:]]*=' "$FILE"; then
    echo "Error: llamaCppHash not found in $FILE" >&2
    echo "Please add 'llamaCppHash = \"...\";' to the services.franken-llama block" >&2
    exit 1
fi

# 4. Update the file using sed (Linux-compatible regex preserving leading indentation)
sed -i -E 's|^([[:space:]]*)#?[[:space:]]*llamaCppTag[[:space:]]*=[[:space:]]*"[^"]*";|\1llamaCppTag = "'"$TAG"'";|' "$FILE"
sed -i -E 's|^([[:space:]]*)#?[[:space:]]*llamaCppHash[[:space:]]*=[[:space:]]*"[^"]*";|\1llamaCppHash = "'"$HASH"'";|' "$FILE"

echo "Successfully updated $FILE to tag $TAG with hash $HASH."
