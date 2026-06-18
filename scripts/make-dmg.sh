#!/usr/bin/env bash
#
# Build LangTool.app and package it into a distributable .dmg with a drag-to-
# Applications layout. This is the macOS equivalent of an installer — users
# open the .dmg and drag LangTool into Applications.
#
# Usage:
#   ./scripts/make-dmg.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="LangTool"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

# Version-stamp the DMG filename so old/new builds are easy to tell apart.
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Resources/Info.plist" 2>/dev/null || echo "0")"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
STAGE="$(mktemp -d)/dmg"

# Build the .app first (without installing).
"$ROOT/scripts/build-app.sh"

echo "==> Staging DMG contents…"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating DMG…"
rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG" >/dev/null

rm -rf "$(dirname "$STAGE")"
echo "==> Done: $DMG"
echo "    Share this file. Users open it and drag LangTool to Applications."
