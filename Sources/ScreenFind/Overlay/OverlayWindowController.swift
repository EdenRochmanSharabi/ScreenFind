import Cocoa

/// Creates and manages one borderless, screen-covering NSWindow per connected
/// display to render the dim overlay with search-match highlights.
final class OverlayWindowController {

    // MARK: - Private state

    private var overlayWindows: [CGDirectDisplayID: NSWindow] = [:]
    private var contentViews: [CGDirectDisplayID: OverlayContentView] = [:]

    // MARK: - Public interface

    /// Shows the overlay on every screen that has a corresponding capture.
    /// - Parameter captures: One `ScreenCapture` per display to overlay.
    func showOverlay(captures: [ScreenCapture]) {
        // Tear down any previously open overlay before building fresh ones.
        dismissOverlay()

        for capture in captures {
            guard let screen = nsScreen(for: capture.displayID) else { continue }

            // Build the content view first.
            let contentView = OverlayContentView(frame: screen.frame)
            contentView.screenshotImage = capture.image
            contentView.screenOrigin = screen.frame.origin

            // Build a borderless, always-on-top window that covers the whole screen.
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.hasShadow = false
            window.contentView = contentView

            window.orderFrontRegardless()

            overlayWindows[capture.displayID] = window
            contentViews[capture.displayID] = contentView
        }
    }

    /// Closes all overlay windows and clears internal state.
    func dismissOverlay() {
        for window in overlayWindows.values {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        contentViews.removeAll()
    }

    /// Updates the highlight rectangles shown on all overlay views.
    /// - Parameters:
    ///   - matches: All current search matches (potentially spanning multiple screens).
    ///   - currentIndex: Index of the focused match in `matches`.
    func updateHighlights(matches: [SearchMatch], currentIndex: Int) {
        for (displayID, contentView) in contentViews {
            // Filter matches that belong to this display.
            let screenMatches = matches.filter { $0.displayID == displayID }
            // Remap currentIndex to the per-screen index if the current match is on this screen.
            let localCurrentIndex: Int
            if currentIndex >= 0 && currentIndex < matches.count {
                let currentMatch = matches[currentIndex]
                if currentMatch.displayID == displayID,
                   let localIdx = screenMatches.firstIndex(where: { $0.id == currentMatch.id }) {
                    localCurrentIndex = localIdx
                } else {
                    localCurrentIndex = -1
                }
            } else {
                localCurrentIndex = -1
            }

            contentView.matches = screenMatches
            contentView.currentMatchIndex = localCurrentIndex
            contentView.setNeedsDisplay(contentView.bounds)
        }
    }

    // MARK: - Helpers

    /// Finds the NSScreen whose `deviceDescription` matches the given display ID.
    private func nsScreen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let screenID = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID else { return false }
            return screenID == displayID
        }
    }
}
