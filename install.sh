#!/bin/bash
set -e

echo "Building ScreenFind (release)..."
swift build -c release

APP_DIR="$HOME/Applications/ScreenFind.app/Contents/MacOS"
mkdir -p "$APP_DIR"
mkdir -p "$HOME/Applications/ScreenFind.app/Contents/Resources"

echo "Installing to ~/Applications/ScreenFind.app..."
cp .build/release/ScreenFind "$APP_DIR/ScreenFind"
cp -n Sources/ScreenFind/App/Info.plist "$HOME/Applications/ScreenFind.app/Contents/Info.plist" 2>/dev/null || true

# Also keep a copy in ~/.local/bin for CLI usage
mkdir -p "$HOME/.local/bin"
cp .build/release/ScreenFind "$HOME/.local/bin/ScreenFind"

echo ""
echo "Installed! Open ScreenFind from Spotlight or run:"
echo "  open ~/Applications/ScreenFind.app"
