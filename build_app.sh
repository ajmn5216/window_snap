#!/bin/bash
#
# Builds WindowSnap and wraps the executable in a proper .app bundle with an
# LSUIElement Info.plist (menu-bar-only, no Dock icon), then ad-hoc code signs it.
#
# Usage:
#   ./build_app.sh            # release build -> ./WindowSnap.app
#   ./build_app.sh debug      # debug build
#
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="WindowSnap"
BUNDLE_ID="com.windowsnap.app"
VERSION="1.0.0"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "error: built binary not found at $BIN_PATH" >&2
  exit 1
fi

APP_DIR="$ROOT/$APP_NAME.app"
echo "==> Assembling $APP_DIR…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>         <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

cat > "$APP_DIR/Contents/PkgInfo" <<< "APPL????"

echo "==> Ad-hoc code signing…"
codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || \
  echo "    (codesign skipped/failed — app will still run unsigned)"

echo ""
echo "Done: $APP_DIR"
echo ""
echo "Run it with:   open \"$APP_DIR\""
echo "Then grant Accessibility access when prompted (System Settings ▸ Privacy & Security ▸ Accessibility)."
echo ""
echo "Note: ad-hoc signing changes identity on each rebuild, so macOS may ask you"
echo "to re-grant Accessibility access after rebuilding. Toggle WindowSnap off/on"
echo "in that list if snapping stops working after a rebuild."
