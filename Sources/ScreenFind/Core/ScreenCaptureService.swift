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

        // Exclude our own windows (overlay rings, search bar, badges): the live
        // refresh loop would otherwise OCR our own UI and match against it.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownWindows = content.windows.filter { $0.owningApplication?.processID == ownPID }

        var captures: [ScreenCapture] = []

        for display in content.displays {
            let displayID = display.displayID

            // Find the matching NSScreen for metadata
            guard let screen = NSScreen.screenForDisplay(displayID) else {
                print("[ScreenCaptureService] No NSScreen found for display \(displayID), skipping.")
                continue
            }

            let scaleFactor = screen.backingScaleFactor

            // Capture the entire display, minus ScreenFind's own windows
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)

            let config = SCStreamConfiguration()
            config.width = Int((CGFloat(display.width) * scaleFactor).rounded())
            config.height = Int((CGFloat(display.height) * scaleFactor).rounded())
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
