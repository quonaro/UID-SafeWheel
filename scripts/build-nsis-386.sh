#!/usr/bin/env bash
# Builds the 32-bit Windows executable and its NSIS installer.
#
# `wails build -nsis` only supports amd64/arm64 installers, so the 386 binary
# is built with a plain `wails build` and the installer is compiled by
# invoking makensis on build/windows/installer/project-386.nsi.
#
# wails_tools.nsh is rendered into build/windows/installer/ as a side effect
# of any `wails build -nsis` run; if it is missing, the amd64 installer build
# is run first to generate it.
set -euo pipefail
cd "$(dirname "$0")/.."

# go-legacy-win7 toolchain: keeps Windows 7 SP1/8/8.1 support that upstream
# Go dropped in 1.21. GOTOOLCHAIN=local prevents it from fetching a stock
# toolchain.
export PATH="$(./scripts/ensure-legacy-go.sh)/bin:$PATH"
export GOTOOLCHAIN=local

WAILS="${WAILS:-$HOME/.go/bin/wails}"

if [ ! -f build/windows/installer/wails_tools.nsh ]; then
    echo "wails_tools.nsh missing; running the amd64 nsis build to generate it" >&2
    ./scripts/fetch-webview2-runtime.sh x64
    "$WAILS" build -tags webkit2_41 -ldflags "-s -w" -trimpath -platform windows/amd64 -nsis -installscope user -o safe-wheel-windows-amd64.exe
fi

"$WAILS" build -tags webkit2_41 -ldflags "-s -w" -trimpath -platform windows/386 -o safe-wheel-windows-386.exe
./scripts/fetch-webview2-runtime.sh x86
(cd build/windows/installer && makensis project-386.nsi)
