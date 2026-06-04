#!/bin/bash
set -e

echo "Building Pepepe..."
swift build -c release

APP_NAME="Pepepe.app"
CONTENTS_DIR="$APP_NAME/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating App Bundle..."
rm -rf "$APP_NAME"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp .build/release/Pepepe "$MACOS_DIR/"
cp Resources/Info.plist "$CONTENTS_DIR/"
cp Resources/AppIcon.icns "$RESOURCES_DIR/"

echo "Signing app (ad-hoc)..."
codesign --force --deep --sign - "$APP_NAME"

echo "App bundle created at $APP_NAME"

if [[ "${1:-}" == "--release" ]]; then
  VERSION="${2:-dev}"
  ZIP="Pepepe-${VERSION}.zip"
  rm -f "$ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP_NAME" "$ZIP"
  echo "Release zip: $ZIP"
else
  echo "Running Pepepe..."
  open "$APP_NAME"
fi
