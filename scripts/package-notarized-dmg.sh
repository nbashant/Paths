#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/Paths.app"
DMG_PATH="$DIST_DIR/Paths.dmg"

: "${DEVELOPER_ID_APPLICATION:?Set this to your Developer ID Application certificate name.}"
: "${NOTARY_KEYCHAIN_PROFILE:?Set this to your notarytool keychain profile name.}"

"$ROOT_DIR/scripts/build.sh"

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" \
  "$APP_PATH"

SKIP_BUILD=1 "$ROOT_DIR/scripts/package-dmg.sh"

codesign \
  --force \
  --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" \
  "$DMG_PATH"

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -t open --context context:primary-signature -v "$DMG_PATH"

echo "Packaged notarized DMG at $DMG_PATH"
