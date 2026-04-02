import Cocoa
import ScreenCaptureKit

/// Captures all connected screens using ScreenCaptureKit.
final class ScreenCaptureService {

    /// Captures every display and returns an array of `ScreenCapture` values.
    func captureAllScreens() async throws -> [ScreenCapture] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        var captures: [ScreenCapture] = []

        for display in content.displays {
            let displayID = display.displayID

            // Find the matching NSScreen for metadata
            guard let screen = NSScreen.screenForDisplay(displayID) else {
                print("[ScreenCaptureService] No NSScreen found for display \(displayID), skipping.")
                continue
            }

            let scaleFactor = screen.backingScaleFactor

            // Create a filter that captures the entire display (excluding no windows)
            let filter = SCContentFilter(display: display, excludingWindows: [])

            let config = SCStreamConfiguration()
            config.width = Int(display.width) * Int(scaleFactor)
            config.height = Int(display.height) * Int(scaleFactor)
            config.showsCursor = false
            config.captureResolution = .best

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            let capture = ScreenCapture(
                displayID: displayID,
                image: image,
                frame: screen.frame,
                scaleFactor: scaleFactor
            )
            captures.append(capture)
        }

        return captures
    }
}
