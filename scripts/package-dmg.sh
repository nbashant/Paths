#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/Paths.dmg"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  "$ROOT_DIR/scripts/build.sh"
fi

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$DIST_DIR/Paths.app" "$STAGING_DIR/Paths.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "Paths" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Packaged $DMG_PATH"
