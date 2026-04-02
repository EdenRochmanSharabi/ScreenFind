import Cocoa

/// Full-screen NSView that renders a frozen screenshot with a dim overlay
/// and highlight cutouts for each search match.
final class OverlayContentView: NSView {

    // MARK: - Properties

    /// The captured screenshot for this screen.
    var screenshotImage: CGImage?

    /// All matches that belong to this screen.
    var matches: [SearchMatch] = []

    /// Index into `matches` that is the currently focused result (-1 = none).
    var currentMatchIndex: Int = -1

    /// The global (AppKit) origin of the screen this view covers.
    /// Used to convert global match rects to view-local coordinates.
    var screenOrigin: CGPoint = .zero

    // MARK: - NSView overrides

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw the captured screenshot (frozen state).
        //    CGContext.draw(image:in:) always renders bottom-to-top, but this view
        //    is flipped (origin at top-left). We must counter-flip the context so
        //    the screenshot appears right-side-up.
        drawScreenshot(in: context)

        // 2. Draw semi-transparent black dim over the entire view.
        context.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(bounds)

        // 3. For each match, punch a hole through the dim and draw a highlight border.
        for (index, match) in matches.enumerated() {
            let isCurrent = (index == currentMatchIndex)
            let localRect = convertFromGlobalScreenRect(match.screenRect)

            // Punch through: clip to a slightly enlarged match rect, then redraw
            // the screenshot so the matched region appears at full brightness.
            context.saveGState()
            context.clip(to: localRect.insetBy(dx: -4, dy: -4))
            drawScreenshot(in: context)
            context.restoreGState()

            // Draw the glow highlight border on top.
            HighlightRenderer.drawHighlight(in: context, rect: localRect, isCurrent: isCurrent)
        }
    }

    /// Draws the screenshot CGImage right-side-up in a flipped view context.
    private func drawScreenshot(in context: CGContext) {
        guard let image = screenshotImage else { return }
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: bounds.size))
        context.restoreGState()
    }

    // MARK: - Coordinate conversion

    /// Converts a rectangle from global AppKit screen coordinates to the
    /// view-local coordinate space by subtracting this screen's origin.
    private func convertFromGlobalScreenRect(_ globalRect: CGRect) -> CGRect {
        CGRect(
            x: globalRect.origin.x - screenOrigin.x,
            y: globalRect.origin.y - screenOrigin.y,
            width: globalRect.width,
            height: globalRect.height
        )
    }
}
