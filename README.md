# ScreenFind

Universal Ctrl+F for macOS. Search for any visible text across all your screens using OCR.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## What it does

Press **Ctrl+F** from anywhere in macOS and ScreenFind will:

1. Capture all connected screens
2. Dim the entire display with a dark overlay
3. Run OCR (Apple Vision framework) to detect all visible text
4. Show a floating search bar — type to find text in real-time
5. Highlight matches in-place with glowing rectangles (orange = current, yellow = others)
6. Navigate between matches with **Up/Down** arrows
7. Press **ESC** to dismiss

For the focused app, ScreenFind also reads off-screen text (scrolled content) via the macOS Accessibility API and shows a badge with the count of hidden matches.

## Requirements

- macOS 14.0+ (Sonoma)
- No third-party dependencies — uses only system frameworks (Vision, ScreenCaptureKit, AppKit, SwiftUI)

## Build & Run

```bash
git clone https://github.com/YOUR_USERNAME/ScreenFind.git
cd ScreenFind
swift run
```

The app appears as a magnifying glass icon in the menu bar.

## Permissions

ScreenFind needs three permissions (granted once via System Settings > Privacy & Security):

| Permission | Why |
|---|---|
| **Screen Recording** | Capture screen content for OCR |
| **Accessibility** | Read off-screen text in applications |
| **Input Monitoring** | Listen for the global hotkey |

Access the permission guide from the menu bar: **ScreenFind > Permissions...**

## Configuration

The global hotkey defaults to **Ctrl+F** and can be changed in **ScreenFind > Settings...** Press any modifier+key combination to set a new hotkey.

## Architecture

```
Sources/ScreenFind/
  App/          — Entry point, AppDelegate
  Core/         — HotkeyManager, ScreenCaptureService, OCRService,
                  SearchEngine, MatchNavigator, OverlayCoordinator,
                  AccessibilityService
  Models/       — ScreenCapture, OCRResult, SearchMatch
  Overlay/      — OverlayWindowController, OverlayContentView,
                  HighlightRenderer
  UI/           — SearchBarContentView, SettingsView, MenuBarView,
                  OffScreenBadgeView
  Permissions/  — PermissionManager, PermissionOnboardingView
  Utilities/    — CoordinateTransformer, HotkeyDisplayString
```

**Key design decisions:**
- Screenshots are taken once on activation; OCR runs in the background while the overlay is already visible (~100ms to dim, ~500ms for OCR)
- Search is real-time: OCR results are cached, text matching is sub-millisecond per keystroke
- Each screen gets its own overlay window at `.screenSaver` level
- The search bar floats above the overlay in an `NSPanel`
- Zero third-party dependencies

## License

MIT
