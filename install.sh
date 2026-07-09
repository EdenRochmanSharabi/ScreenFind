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

# Sign with the stable self-signed identity so TCC permissions (Accessibility,
# Screen Recording, Input Monitoring) survive rebuilds. Without this, each
# build gets a new adhoc hash and macOS silently invalidates the grants.
SIGN_IDENTITY="ScreenFind Dev"
if security find-identity -p codesigning -v | grep -q "$SIGN_IDENTITY"; then
    echo "Signing with '$SIGN_IDENTITY'..."
    codesign --force --sign "$SIGN_IDENTITY" --identifier com.edenrochman.screenfind "$HOME/.local/bin/ScreenFind"
    codesign --force --deep --sign "$SIGN_IDENTITY" --identifier com.edenrochman.screenfind "$HOME/Applications/ScreenFind.app"
else
    echo "WARNING: '$SIGN_IDENTITY' identity not found in keychain; leaving adhoc signature." >&2
    echo "         TCC permissions will need to be re-granted after this install." >&2
fi

echo ""
echo "Installed! Open ScreenFind from Spotlight or run:"
echo "  open ~/Applications/ScreenFind.app"
