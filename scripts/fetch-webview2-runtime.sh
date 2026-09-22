#!/usr/bin/env bash
# Fetches the fixed-version WebView2 runtime v109 (the last release compatible
# with Windows 7/8.1) into build/windows/installer/webview2/<arch>/. The NSIS
# installer unpacks it next to the executable when the target machine has no
# WebView2 runtime - deployment machines usually have no internet access, so
# the evergreen bootstrapper cannot be used there.
#
# Usage: fetch-webview2-runtime.sh [x64|x86]   (default: x64)
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH="${1:-x64}"
case "$ARCH" in
    x64) SHA256="7622281cf83de1a35e3a471f432f7a897d65f0a7d3975df08512b7b253dd45c7" ;;
    x86) SHA256="c507e0df03fe941f6669b74faf713545708653d568d1dce1e683cbe707382253" ;;
    *) echo "usage: $0 [x64|x86]" >&2; exit 1 ;;
esac

VERSION="109.0.1518.78"
CAB="Microsoft.WebView2.FixedVersionRuntime.${VERSION}.${ARCH}.cab"
URL="https://github.com/westinyang/WebView2RuntimeArchive/releases/download/${VERSION}/${CAB}"
DEST="build/windows/installer/webview2/$ARCH"

if [ -f "$DEST/msedgewebview2.exe" ]; then
    echo "WebView2 runtime $VERSION ($ARCH) already present in $DEST"
    exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading $CAB"
curl -fSL --retry 3 -o "$tmp/$CAB" "$URL"
echo "$SHA256  $tmp/$CAB" | sha256sum -c -

mkdir -p "$tmp/x"
if command -v cabextract >/dev/null 2>&1; then
    cabextract -q -d "$tmp/x" "$tmp/$CAB"
elif command -v 7z >/dev/null 2>&1; then
    7z x -o"$tmp/x" "$tmp/$CAB" >/dev/null
elif command -v 7zz >/dev/null 2>&1; then
    7zz x -o"$tmp/x" "$tmp/$CAB" >/dev/null
else
    echo "error: cabextract or 7z is required to unpack $CAB" >&2
    exit 1
fi

mkdir -p "$DEST"
mv "$tmp/x/Microsoft.WebView2.FixedVersionRuntime.${VERSION}.${ARCH}"/* "$DEST/"
echo "WebView2 fixed runtime $VERSION ($ARCH) -> $DEST"
