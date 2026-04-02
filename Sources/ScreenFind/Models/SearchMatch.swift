import Foundation
import CoreGraphics

/// Represents a single OCR match found on a screen.
struct SearchMatch: Identifiable {
    let id: UUID
    /// The display this match was found on.
    let displayID: CGDirectDisplayID
    /// The bounding rectangle of the match in global (AppKit) screen coordinates.
    let screenRect: CGRect
    /// The exact text that was matched.
    let matchedText: String
    /// Surrounding context text for display in the results list.
    let contextText: String
    /// Whether the match rect is currently visible on screen (not obscured).
    let isOnScreen: Bool
}
