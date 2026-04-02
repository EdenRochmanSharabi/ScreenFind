import CoreGraphics

/// Converts between Vision framework normalized coordinates and AppKit screen coordinates.
struct CoordinateTransformer {

    /// Converts a Vision bounding box (normalized, origin at bottom-left) to
    /// global AppKit screen coordinates suitable for overlay drawing on a flipped NSView.
    ///
    /// Steps:
    /// 1. Denormalize: multiply by image pixel dimensions
    /// 2. Scale: divide by scaleFactor to convert pixels to points
    /// 3. Flip Y: Vision Y=0 is at bottom; for overlay drawing (flipped NSView),
    ///    flip Y within the screen so Y=0 is at top
    /// 4. Offset to global: add the screen's frame origin
    ///
    /// - Parameters:
    ///   - visionRect: Normalized bounding box from VNRecognizedTextObservation (0..1)
    ///   - imageSize: The captured image size in pixels
    ///   - screenFrame: The NSScreen frame in global AppKit coordinates
    ///   - scaleFactor: The NSScreen backing scale factor
    /// - Returns: A CGRect in global screen coordinates (with Y flipped for overlay use)
    static func visionRectToScreenRect(
        _ visionRect: CGRect,
        imageSize: CGSize,
        screenFrame: CGRect,
        scaleFactor: CGFloat
    ) -> CGRect {
        // 1. Denormalize: vision coordinates (0..1) -> pixel coordinates
        let pixelX = visionRect.origin.x * imageSize.width
        let pixelY = visionRect.origin.y * imageSize.height
        let pixelWidth = visionRect.size.width * imageSize.width
        let pixelHeight = visionRect.size.height * imageSize.height

        // 2. Scale: pixels -> points
        let pointX = pixelX / scaleFactor
        let pointY = pixelY / scaleFactor
        let pointWidth = pixelWidth / scaleFactor
        let pointHeight = pixelHeight / scaleFactor

        // 3. Flip Y: Vision origin is bottom-left, flip so Y=0 is at top of screen
        let flippedY = screenFrame.height - pointY - pointHeight

        // 4. Offset to global screen coordinates
        let globalX = screenFrame.origin.x + pointX
        let globalY = screenFrame.origin.y + flippedY

        return CGRect(x: globalX, y: globalY, width: pointWidth, height: pointHeight)
    }
}
