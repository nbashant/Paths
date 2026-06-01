#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/Build"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/Paths.app"
CONTENTS_DIR="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_PATH"
mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

swift "$ROOT_DIR/Sources/MakeIcon.swift" "$BUILD_DIR/AppIcon.iconset"
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$BUILD_DIR/AppIcon.icns"

cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

swiftc \
  -parse-as-library \
  -O \
  "$ROOT_DIR/Sources/Paths.swift" \
  -o "$MACOS_DIR/Paths" \
  -framework AppKit

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_PATH"
fi

echo "Built $APP_PATH"
