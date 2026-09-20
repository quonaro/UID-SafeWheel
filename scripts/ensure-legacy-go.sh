#!/usr/bin/env bash
# Downloads the go-legacy-win7 toolchain (a patched Go toolchain that keeps
# Windows 7/8/8.1/Server 2008R2-2012R2 support, dropped upstream in Go 1.21)
# and prints its root directory (containing bin/go) on stdout.
#
# Usage: ensure-legacy-go.sh [DEST_DIR]
#   DEST_DIR defaults to $XDG_CACHE_HOME/go-legacy-win7/<version>
#
# Override the pinned version/hash via GO_LEGACY_VERSION / GO_LEGACY_SHA256.
set -euo pipefail

VERSION="${GO_LEGACY_VERSION:-1.27.1-1}"
SHA256="${GO_LEGACY_SHA256:-1abfe94e70b8dab3351656019fb613d0fe5b24b91acbd1e20fa75556bb33cb2b}"

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) ;;
    *) echo "ensure-legacy-go.sh: only linux/amd64 hosts are supported" >&2; exit 1 ;;
esac

DEST="${1:-${XDG_CACHE_HOME:-$HOME/.cache}/go-legacy-win7/$VERSION}"

find_root() {
    for d in "$DEST" "$DEST"/*/; do
        if [ -x "$d/bin/go" ]; then
            echo "$d"
            return 0
        fi
    done
    return 1
}

if ! root="$(find_root)"; then
    mkdir -p "$DEST"
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT

    url="https://github.com/thongtech/go-legacy-win7/releases/download/v${VERSION}/go-legacy-win7-${VERSION}.linux_amd64.tar.gz"
    echo "downloading $url" >&2
    curl -fSL --retry 3 -o "$tmp" "$url"
    echo "$SHA256  $tmp" | sha256sum -c - >&2
    tar -xzf "$tmp" -C "$DEST"

    root="$(find_root)" || { echo "ensure-legacy-go.sh: bin/go not found in $DEST" >&2; exit 1; }
fi

echo "$root"
