import Cocoa

/// Full-screen transparent NSView that renders highlight rings over each
/// search match. The screen beneath stays fully visible (no dimming).
///
/// Rendering is CALayer-based so rings glide smoothly to their new positions
/// when the live refresh loop re-locates text that moved (e.g. scrolling).
final class OverlayContentView: NSView {

    // MARK: - Properties

    /// The global (AppKit) origin of the screen this view covers.
    /// Used to convert global match rects to view-local coordinates.
    var screenOrigin: CGPoint = .zero

    private var ringLayers: [CAShapeLayer] = []

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    // MARK: - Highlights

    /// Replaces the current rings with one per match, animating position
    /// changes so rings follow text that moved between refreshes.
    func updateHighlights(matches: [SearchMatch], currentIndex: Int) {
        // Grow or shrink the layer pool to one layer per match.
        let scale = window?.backingScaleFactor ?? 2.0
        while ringLayers.count < matches.count {
            let ring = CAShapeLayer()
            // New layers default to contentsScale 1.0 — blurry on Retina.
            ring.contentsScale = scale
            layer?.addSublayer(ring)
            ringLayers.append(ring)
        }
        while ringLayers.count > matches.count {
            ringLayers.removeLast().removeFromSuperlayer()
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.18)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))

        for (index, match) in matches.enumerated() {
            let isCurrent = (index == currentIndex)
            let localRect = convertFromGlobalScreenRect(match.screenRect)
            style(ringLayers[index], rect: localRect, isCurrent: isCurrent)
        }

        CATransaction.commit()
    }

    private func style(_ ring: CAShapeLayer, rect: CGRect, isCurrent: Bool) {
        let color = isCurrent ? NSColor.systemOrange : NSColor.systemYellow
        let ringRect = rect.insetBy(dx: -2, dy: -1.5)
        let cornerRadius = min(5, ringRect.height / 3)

        // Path in the layer's own coordinate space; the layer is moved via
        // frame so position changes animate smoothly.
        let pathRect = CGRect(origin: .zero, size: ringRect.size)
        ring.path = CGPath(
            roundedRect: pathRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        ring.frame = ringRect
        ring.fillColor = color.withAlphaComponent(isCurrent ? 0.18 : 0.10).cgColor
        ring.strokeColor = color.withAlphaComponent(isCurrent ? 0.95 : 0.8).cgColor
        ring.lineWidth = isCurrent ? 2.5 : 2.0

        if isCurrent {
            ring.shadowColor = color.cgColor
            ring.shadowOpacity = 0.8
            ring.shadowRadius = 6
            ring.shadowOffset = .zero
        } else {
            ring.shadowOpacity = 0
        }
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
