#!/usr/bin/env bash
# Builds the 32-bit Linux binary (linux/386) inside an i386 Debian container.
#
# `wails build` does not support linux/386 (valid targets: amd64, arm64, arm)
# and a Wails Linux binary needs CGO against GTK/WebKitGTK, so this compiles
# natively in an i386/debian container instead of cross-compiling.
#
# frontend/dist and the generated frontend/wailsjs bindings must already
# exist (frontend/dist is embedded via //go:embed); run `lota build linux`
# first if they are missing.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d frontend/dist ] || [ ! -d frontend/wailsjs ]; then
    echo "error: frontend/dist or frontend/wailsjs missing - run 'lota build linux' first" >&2
    exit 1
fi

# Same Go release line as the windows toolchain (scripts/ensure-legacy-go.sh);
# pinned sha256 for the linux/386 tarball.
GO_VERSION="${GO_386_VERSION:-1.27.1}"
GO_SHA256="${GO_386_SHA256:-3b72028095439d2bc0ce84e271cc70328a878d879020c5721eaa46df5f72fbc0}"

# Named volume: keep the module/build caches between runs.
docker run --rm \
    -v "$PWD:/src" -w /src \
    -v safewheel-linux386-gocache:/go-cache \
    -e GOCACHE=/go-cache/build \
    -e GOMODCACHE=/go-cache/mod \
    -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    i386/debian:bookworm-slim \
    bash -euo pipefail -c "
        apt-get update -qq
        apt-get install -y -qq --no-install-recommends \
            curl ca-certificates gcc pkg-config libwebkit2gtk-4.1-dev libgtk-3-dev
        curl -fsSL -o /tmp/go.tgz 'https://go.dev/dl/go${GO_VERSION}.linux-386.tar.gz'
        echo '${GO_SHA256}  /tmp/go.tgz' | sha256sum -c -
        tar -C /usr/local -xzf /tmp/go.tgz
        export PATH=/usr/local/go/bin:\$PATH
        # wails build tags are 'desktop,production,<user tags>'.
        GOTOOLCHAIN=local go build -tags 'desktop,production,webkit2_41' \
            -ldflags '-s -w' -trimpath -o build/bin/safe-wheel-linux-386 .
        chown \$HOST_UID:\$HOST_GID build/bin/safe-wheel-linux-386
    "

echo "built build/bin/safe-wheel-linux-386"
file build/bin/safe-wheel-linux-386 2>/dev/null || true
