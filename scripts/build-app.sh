#!/bin/bash
# 构建 Moxia.app 到 build/ 目录
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/Moxia.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/Moxia" "$APP/Contents/MacOS/Moxia"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp -R Sources/Moxia/Resources/Renderer "$APP/Contents/Resources/Renderer"
cp -R Examples "$APP/Contents/Resources/Examples"

ICONSET="build/AppIcon.iconset"
if [ ! -f build/AppIcon.icns ]; then
  rm -rf "$ICONSET"
  swift scripts/make-icon.swift "$ICONSET"
  iconutil -c icns "$ICONSET" -o build/AppIcon.icns
  rm -rf "$ICONSET"
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" >/dev/null
echo "✓ $APP"
