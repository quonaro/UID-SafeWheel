#!/usr/bin/env bash
# Packages build/bin/safe-wheel-linux-amd64 into a portable AppImage
# (bundles WebKitGTK helpers via linuxdeploy + the GTK plugin).
set -euo pipefail
cd "$(dirname "$0")/.."

BIN=build/bin/safe-wheel-linux-amd64
if [ ! -f "$BIN" ]; then
  echo "error: $BIN not found - run 'lota build linux' first" >&2
  exit 1
fi

# Lets the tooling run on hosts/CI containers without FUSE
export APPIMAGE_EXTRACT_AND_RUN=1
# linuxdeploy's bundled strip is too old for .relr.dyn sections on newer
# distros and aborts the build (linuxdeploy#272); the wails binary is
# already stripped via -ldflags "-s -w" anyway
export NO_STRIP=1

WORK=build/appimage
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

curl -fSL -o linuxdeploy \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20240109-1/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy

# Vendored linuxdeploy GTK plugin (scripts/linuxdeploy-plugin-gtk.sh)
cp ../../scripts/linuxdeploy-plugin-gtk.sh .
chmod +x linuxdeploy-plugin-gtk.sh

cp "../../$BIN" safe-wheel
chmod +x safe-wheel
cp ../../build/appicon.png safe-wheel.png

mkdir -p AppDir/usr/bin AppDir/usr/share/icons/hicolor/512x512/apps
cp safe-wheel AppDir/usr/bin/
cp safe-wheel.png AppDir/usr/share/icons/hicolor/512x512/apps/
cp safe-wheel.png AppDir/

# WebKitGTK helper processes are spawned by the bundled libwebkit2gtk,
# so linuxdeploy cannot find them via ldd - copy them in manually.
# cp --parents keeps the /usr/lib/... layout that the gtk plugin's
# binary path patch ("/usr" -> "./.") relies on.
pushd AppDir > /dev/null
find /usr/lib* /usr/libexec -path '*webkit2gtk-4.1/*' \
  \( -name 'WebKit*Process' -o -name 'libwebkit2gtkinjectedbundle.so' \) \
  -exec cp --parents '{}' . \; 2>/dev/null || true
popd > /dev/null

if ! find AppDir -name WebKitWebProcess | grep -q .; then
  echo "error: WebKitGTK helper processes not found under /usr/lib* - the AppImage would be broken" >&2
  exit 1
fi

# Custom AppRun gets renamed to AppRun.wrapped by linuxdeploy; the generated
# AppRun then sources apprun-hooks/ (GTK env) before exec'ing it.
# WebKitGTK's helper paths are binary-patched to "././lib/..." (relative),
# and g_spawn resolves them against the process CWD - so we must run with
# CWD=$APPDIR/usr for WebKitNetworkProcess & co. to be found.
# APP_DIR redirects safewheel.db away from the read-only AppImage mount
# (or the throwaway extract dir) into the user's data dir.
cat > AppDir/AppRun <<'EOF'
#!/bin/sh
APPDIR="${APPDIR:-$(dirname "$(readlink -f "$0")")}"
export APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/safewheel"
cd "$APPDIR/usr"
exec "$APPDIR/usr/bin/safe-wheel" "$@"
EOF
chmod +x AppDir/AppRun

# Deploy step (no --output yet): the GTK plugin sets RUNPATH=$ORIGIN on every
# ELF, but the WebKitGTK helper binaries sit in .../webkit2gtk-4.1/ (one level
# below the bundled libs) - with $ORIGIN they silently fall back to the host's
# libwebkit2gtk, whose IPC version mismatches the bundled one => blank window.
./linuxdeploy --appdir AppDir \
  --plugin=gtk \
  -e safe-wheel \
  -d ../../build/linux/safe-wheel.desktop

PATCHELF=patchelf
if ! command -v patchelf >/dev/null; then
  curl -fSL -o patchelf.tar.gz \
    https://github.com/NixOS/patchelf/releases/download/0.18.0/patchelf-0.18.0-x86_64.tar.gz
  tar -xzf patchelf.tar.gz
  PATCHELF="$(find . -name patchelf -type f -perm -u+x | head -1)"
fi

# Cover both layouts: libs may be flat in usr/lib ($ORIGIN/../..) or in the
# multiarch dir usr/lib/x86_64-linux-gnu ($ORIGIN/..); injected-bundle is one
# level deeper still.
find AppDir -path '*webkit2gtk-4.1/*' -type f \
  -exec "$PATCHELF" --set-rpath '$ORIGIN/..:$ORIGIN/../..:$ORIGIN/../../..' {} +

./linuxdeploy --appdir AppDir \
  --output=appimage \
  -e safe-wheel \
  -d ../../build/linux/safe-wheel.desktop

mv ./*.AppImage ../bin/safe-wheel-linux-amd64.AppImage
echo "Done: build/bin/safe-wheel-linux-amd64.AppImage"
