import CoreGraphics
import Vision

/// A single recognized text region with its screen-space bounding box.
struct TextBlock {
    /// The recognized text string.
    let text: String

    /// The bounding box in global screen coordinates (AppKit points).
    let screenRect: CGRect

    /// The OCR confidence value (0.0 to 1.0).
    let confidence: Float

    /// The underlying VNRecognizedText, preserved for sub-string bounding box queries.
    let recognizedText: VNRecognizedText
}

/// OCR results for a single display.
struct OCRResult {
    /// The display this result corresponds to.
    let displayID: CGDirectDisplayID

    /// All recognized text blocks found on this display.
    let textBlocks: [TextBlock]

    /// The pixel dimensions of the captured image (needed to convert Vision sub-string rects).
    let imageSize: CGSize

    /// The NSScreen frame in global AppKit coordinates (needed for coordinate conversion).
    let screenFrame: CGRect

    /// The display backing scale factor (needed for pixel-to-point conversion).
    let scaleFactor: CGFloat
}
