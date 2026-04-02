import Testing
import CoreGraphics
@testable import ScreenFind

struct CoordinateTransformerTests {

    // MARK: - Basic conversion

    @Test func testBasicConversion() {
        // Vision rect: normalized, bottom-left origin — text block occupying the center half.
        let visionRect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let imageSize = CGSize(width: 2000, height: 1000)   // Retina 2x capture
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 500)
        let scaleFactor: CGFloat = 2.0

        let result = CoordinateTransformer.visionRectToScreenRect(
            visionRect,
            imageSize: imageSize,
            screenFrame: screenFrame,
            scaleFactor: scaleFactor
        )

        // Step-by-step expected values:
        // 1. Denormalize: pixelX=500, pixelY=250, pixelW=1000, pixelH=500
        // 2. Scale (/2): pointX=250, pointY=125, pointW=500, pointH=250
        // 3. Flip Y: flippedY = 500 - 125 - 250 = 125
        // 4. Offset (screenFrame at origin): globalX=250, globalY=125
        #expect(result.origin.x == 250)
        #expect(result.origin.y == 125)
        #expect(result.width == 500)
        #expect(result.height == 250)
    }

    // MARK: - Full-image rect

    @Test func testFullImageRect() {
        // A Vision rect covering the entire image should map to the entire screen.
        let visionRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let imageSize = CGSize(width: 3840, height: 2160)
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let scaleFactor: CGFloat = 2.0

        let result = CoordinateTransformer.visionRectToScreenRect(
            visionRect,
            imageSize: imageSize,
            screenFrame: screenFrame,
            scaleFactor: scaleFactor
        )

        // Denormalize: 3840×2160 pixels → scale (/2): 1920×1080 points
        // Flip Y: 1080 - 0 - 1080 = 0 → offset (0,0)
        #expect(result.origin.x == 0)
        #expect(result.origin.y == 0)
        #expect(result.width == 1920)
        #expect(result.height == 1080)
    }

    // MARK: - Secondary screen offset

    @Test func testSecondaryScreenOffset() {
        // A screen positioned to the right of the primary display.
        // A Vision rect in the bottom-left quarter of that screen.
        let visionRect = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        let imageSize = CGSize(width: 2560, height: 1440)
        let screenFrame = CGRect(x: 1920, y: 0, width: 1280, height: 720)
        let scaleFactor: CGFloat = 2.0

        let result = CoordinateTransformer.visionRectToScreenRect(
            visionRect,
            imageSize: imageSize,
            screenFrame: screenFrame,
            scaleFactor: scaleFactor
        )

        // Denormalize: pixelX=0, pixelY=0, pixelW=1280, pixelH=720
        // Scale (/2): pointX=0, pointY=0, pointW=640, pointH=360
        // Flip Y: 720 - 0 - 360 = 360
        // Offset: globalX = 1920 + 0 = 1920, globalY = 0 + 360 = 360
        #expect(result.origin.x == 1920)
        #expect(result.origin.y == 360)
        #expect(result.width == 640)
        #expect(result.height == 360)
    }

    // MARK: - Non-Retina display (scale factor 1.0)

    @Test func testNonRetinaDisplay() {
        // On a non-Retina screen, image pixels == screen points.
        let visionRect = CGRect(x: 0.5, y: 0.5, width: 0.25, height: 0.25)
        let imageSize = CGSize(width: 1920, height: 1080)
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let scaleFactor: CGFloat = 1.0

        let result = CoordinateTransformer.visionRectToScreenRect(
            visionRect,
            imageSize: imageSize,
            screenFrame: screenFrame,
            scaleFactor: scaleFactor
        )

        // Denormalize: pixelX=960, pixelY=540, pixelW=480, pixelH=270
        // Scale (/1): same
        // Flip Y: 1080 - 540 - 270 = 270
        // Offset (origin 0,0): globalX=960, globalY=270
        #expect(result.width == 480)
        #expect(result.height == 270)
        #expect(result.origin.x == 960)
        #expect(result.origin.y == 270)
    }

    // MARK: - Top-left corner (Vision bottom-right)

    @Test func testVisionTopEdgeMapsToScreenBottom() {
        // Vision Y=1 is the top of the image, which should become Y near 0
        // after flipping (bottom of the NSScreen frame area when origin is 0).
        let visionRect = CGRect(x: 0, y: 0.75, width: 0.5, height: 0.25)
        let imageSize = CGSize(width: 2000, height: 1000)
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 500)
        let scaleFactor: CGFloat = 2.0

        let result = CoordinateTransformer.visionRectToScreenRect(
            visionRect,
            imageSize: imageSize,
            screenFrame: screenFrame,
            scaleFactor: scaleFactor
        )

        // Denormalize: pixelY=750, pixelH=250
        // Scale (/2): pointY=375, pointH=125
        // Flip Y: 500 - 375 - 125 = 0
        // Offset: globalY = 0 + 0 = 0
        #expect(result.origin.y == 0)
    }

    // MARK: - Zero-size rect passthrough

    @Test func testZeroSizeRect() {
        let visionRect = CGRect(x: 0.5, y: 0.5, width: 0, height: 0)
        let imageSize = CGSize(width: 2000, height: 1000)
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 500)
        let scaleFactor: CGFloat = 2.0

        let result = CoordinateTransformer.visionRectToScreenRect(
            visionRect,
            imageSize: imageSize,
            screenFrame: screenFrame,
            scaleFactor: scaleFactor
        )

        #expect(result.width == 0)
        #expect(result.height == 0)
    }
}
