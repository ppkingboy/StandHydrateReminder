#!/usr/bin/env zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="站立喝水提醒.app"
APP_DIR="$ROOT/build/$APP_NAME"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICONSET="$ROOT/build/AppIcon.iconset"
ICON="$RESOURCES/AppIcon.icns"
ENTITLEMENTS="$ROOT/StandHydrateReminder.entitlements"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

clang \
  -fobjc-arc \
  -mmacosx-version-min=15.0 \
  "$ROOT/Sources/main.m" \
  -o "$MACOS/StandHydrateReminder" \
  -framework Cocoa \
  -framework ServiceManagement \
  -framework QuartzCore \
  -framework UniformTypeIdentifiers

rm -rf "$ICONSET"
clang \
  -fobjc-arc \
  -mmacosx-version-min=15.0 \
  "$ROOT/Tools/make_icon.m" \
  -o "$ROOT/build/make_icon" \
  -framework Cocoa
"$ROOT/build/make_icon" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$ICON"

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
chmod +x "$MACOS/StandHydrateReminder"
# Copy to /tmp (outside file-provider fs), sign there, move back
TMP_APP="/tmp/$APP_NAME"
rm -rf "$TMP_APP"
cp -R "$APP_DIR" "$TMP_APP"
find "$TMP_APP" -exec xattr -c {} \; 2>/dev/null || true
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$TMP_APP" >/dev/null
rm -rf "$APP_DIR"
mv "$TMP_APP" "$APP_DIR"

echo "$APP_DIR"
