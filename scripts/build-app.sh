#!/usr/bin/env bash
#
# Build LangTool and package it into a proper .app bundle.
#
# A bundled, (ad-hoc) code-signed app is required so macOS attributes the
# Accessibility permission to LangTool itself rather than to your terminal.
#
# Usage:
#   ./scripts/build-app.sh            # build into ./dist/LangTool.app
#   ./scripts/build-app.sh --install  # also copy to /Applications and launch
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="LangTool"
BUILD_CONFIG="release"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "==> Building ($BUILD_CONFIG)…"
swift build -c "$BUILD_CONFIG"

BIN="$(swift build -c "$BUILD_CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN" ]]; then
    echo "Build failed: executable not found at $BIN" >&2
    exit 1
fi

echo "==> Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
if [[ -f "$ROOT/Resources/tabsworks-logo.png" ]]; then
    cp "$ROOT/Resources/tabsworks-logo.png" "$APP/Contents/Resources/tabsworks-logo.png"
fi

echo "==> Ad-hoc code signing…"
codesign --force --deep --sign - "$APP"

echo "==> Done: $APP"

if [[ "${1:-}" == "--install" ]]; then
    echo "==> Installing to /Applications…"
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" "/Applications/$APP_NAME.app"
    echo "==> Launching…"
    open "/Applications/$APP_NAME.app"
fi
