import CoreGraphics

/// Represents a captured screen image with metadata needed for coordinate mapping.
struct ScreenCapture {
    /// The Core Graphics display ID for this screen.
    let displayID: CGDirectDisplayID

    /// The captured screen image.
    let image: CGImage

    /// The screen frame in global (AppKit) coordinates.
    let frame: CGRect

    /// The NSScreen backing scale factor (e.g. 2.0 for Retina).
    let scaleFactor: CGFloat
}
