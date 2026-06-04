#!/bin/bash
set -e

echo "Building Pepepe..."
swift build -c release

APP_NAME="Pepepe.app"
CONTENTS_DIR="$APP_NAME/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating App Bundle..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp .build/release/Pepepe "$MACOS_DIR/"
cp Resources/Info.plist "$CONTENTS_DIR/"
cp Resources/AppIcon.icns "$RESOURCES_DIR/"

echo "App bundle created at $APP_NAME"
echo "Running Pepepe..."
open "$APP_NAME"
