#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SOURCE="$ROOT_DIR/dist/Paths.app"
APP_DEST="$HOME/Applications/Paths.app"

"$ROOT_DIR/scripts/build.sh"

mkdir -p "$HOME/Applications"
rm -rf "$APP_DEST"
cp -R "$APP_SOURCE" "$APP_DEST"

echo "Installed $APP_DEST"
