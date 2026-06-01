#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/Build"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/Paths.app"
CONTENTS_DIR="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ARM_BINARY="$BUILD_DIR/Paths-arm64"
INTEL_BINARY="$BUILD_DIR/Paths-x86_64"

rm -rf "$APP_PATH"
mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

swift "$ROOT_DIR/Sources/MakeIcon.swift" "$BUILD_DIR/AppIcon.iconset"
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$BUILD_DIR/AppIcon.icns"

cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

if command -v lipo >/dev/null 2>&1; then
  swiftc \
    -parse-as-library \
    -O \
    -target arm64-apple-macos13.0 \
    "$ROOT_DIR/Sources/Paths.swift" \
    -o "$ARM_BINARY" \
    -framework AppKit

  swiftc \
    -parse-as-library \
    -O \
    -target x86_64-apple-macos13.0 \
    "$ROOT_DIR/Sources/Paths.swift" \
    -o "$INTEL_BINARY" \
    -framework AppKit

  lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$MACOS_DIR/Paths"
else
  swiftc \
    -parse-as-library \
    -O \
    "$ROOT_DIR/Sources/Paths.swift" \
    -o "$MACOS_DIR/Paths" \
    -framework AppKit
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_PATH"
fi

echo "Built $APP_PATH"
