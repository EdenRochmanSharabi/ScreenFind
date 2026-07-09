# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
swift build              # Debug build
swift build -c release   # Release build
swift test               # Run all 28 tests (Swift Testing framework)
swift run                # Build and run the app
```

Install to ~/Applications (Spotlight-visible .app bundle):
```bash
./install.sh
```

## Architecture

ScreenFind is a macOS menu bar app (Swift 5.10, macOS 14+) that acts as a universal Ctrl+F. Zero third-party dependencies — uses Vision, ScreenCaptureKit, AppKit, SwiftUI, and ApplicationServices.

### Data Flow

```
Ctrl+F → HotkeyManager (CGEventTap) → AppDelegate → OverlayCoordinator.activate()
  → ScreenCaptureService (async, ~80ms; capture is OCR input only, not shown)
  → show transparent overlay + Spotlight-style search bar
  → OCRService (async TaskGroup, ~500ms) → SearchEngine.loadResults()
  → user types → SearchEngine.search() (<1ms) → OverlayContentView redraws highlight rings
  → ESC (clears query first) / Ctrl+F / click outside → OverlayCoordinator.deactivate()
```

### Key Components

- **OverlayCoordinator** (`Core/`): `@MainActor` orchestrator. Owns all services, manages activate/deactivate lifecycle, Combine-based reactive search on `$query`.
- **HotkeyManager** (`Core/`): Global hotkey via `CGEvent.tapCreate`. Uses `Unmanaged` pointer for C callback bridging. Configurable key combo in UserDefaults.
- **OverlayWindowController** (`Overlay/`): Creates one borderless `NSWindow` at `.screenSaver` level per connected display.
- **OverlayContentView** (`Overlay/`): Flipped transparent `NSView` rendering rounded highlight rings as `CAShapeLayer`s (animated, so rings glide when the live refresh relocates text). No dimming, no frozen screenshot — the capture is used solely for OCR. The overlay windows have `ignoresMouseEvents = true` so scroll/clicks pass through to the apps beneath; click-outside-to-dismiss is a global mouse-down monitor in `OverlayCoordinator` (our own windows don't trigger global monitors).
- **Live tracking**: while active, `OverlayCoordinator.startLiveRefresh()` re-captures + re-OCRs in a loop (~1-2 Hz — OCR takes 300-700ms/pass) excluding ScreenFind's own windows from the capture; `MatchNavigator.refreshMatches` preserves the user's position. OCR drops blocks with confidence < 0.45 (they're garbled and produce phantom matches) and disables language correction (it "fixes" code tokens like `launchctl`).
- **SearchBarWindowController** (`UI/`): Spotlight-style `NSPanel` at screenSaver+1 level, centered in the upper quarter of the screen. Uses `.titled` + `.fullSizeContentView` (not `.borderless`) so it can become key window and accept keyboard input. `becomesKeyOnlyIfNeeded = false`. Background blur comes from an `NSVisualEffectView` (`.popover`, behind-window) because SwiftUI materials don't render reliably on transparent non-activating panels. ESC clears the query first, then dismisses.
- **CoordinateTransformer** (`Utilities/`): Vision normalized coords (bottom-left origin) → screen points. 4-step: denormalize → scale by backingScaleFactor → flip Y → offset to global.

### Threading

- `OverlayCoordinator`: `@MainActor` — all UI coordination on main thread
- `ScreenCaptureService`, `OCRService`, `AccessibilityService`: async, run on background threads
- OCR parallelized per-screen via `withThrowingTaskGroup`
- `HotkeyManager` callback: CFRunLoop, dispatches to main via `DispatchQueue.main.async`
- `SearchEngine.search()`: runs on main thread (sub-millisecond)

### Coordinate Systems

Four coordinate systems interact — `CoordinateTransformer` is the single source of truth:
- **Vision**: normalized 0–1, origin bottom-left
- **CGImage**: pixels (Retina = 2x screen points)
- **NSScreen**: points, origin at bottom-left of primary display
- **Flipped NSView**: points, origin at top-left

## Gotchas

- **NSPanel keyboard input**: `.borderless` + `.nonactivatingPanel` prevents key window status. Must use `.titled` + `.fullSizeContentView` with transparent titlebar.
- **SwiftUI materials on panels**: `.ultraThinMaterial` and friends can render fully transparent on clear non-activating panels — use an `NSVisualEffectView` representable with `.behindWindow` blending instead.
- **Overlay windows must not steal focus**: Use `orderFrontRegardless()`, not `makeKeyAndOrderFront()`.
- **App is unsandboxed**: Required for CGEventTap + Accessibility API. Cannot distribute via Mac App Store.
- **SPM executable, not .app bundle**: `NSApp.setActivationPolicy(.accessory)` replaces `LSUIElement` for hiding from Dock. The .app bundle wrapper in ~/Applications provides Spotlight visibility.
- **Permissions required at runtime**: Screen Recording, Accessibility, Input Monitoring. App prints diagnostic if CGEventTap fails (no permissions).
