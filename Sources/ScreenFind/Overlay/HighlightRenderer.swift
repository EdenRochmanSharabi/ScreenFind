import Cocoa

/// Draws glow highlight borders around matched regions.
struct HighlightRenderer {
    /// Draws a highlight glow for a single match rectangle.
    /// - Parameters:
    ///   - context: The Core Graphics context to draw into.
    ///   - rect: The match rectangle in view-local coordinates.
    ///   - isCurrent: Whether this is the currently focused match.
    static func drawHighlight(in context: CGContext, rect: CGRect, isCurrent: Bool) {
        let color = isCurrent
            ? NSColor.orange.withAlphaComponent(0.6)
            : NSColor.yellow.withAlphaComponent(0.4)

        // Outer glow using shadow
        context.saveGState()
        context.setShadow(offset: .zero, blur: 8, color: color.cgColor)
        context.setFillColor(color.withAlphaComponent(0.3).cgColor)
        context.fill(rect.insetBy(dx: -2, dy: -2))
        context.restoreGState()

        // Border
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0)
        context.stroke(rect.insetBy(dx: -1, dy: -1))
    }
}
