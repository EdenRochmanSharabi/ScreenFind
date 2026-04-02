import Cocoa

/// Checks and requests macOS permissions needed by ScreenFind.
final class PermissionManager {

    // MARK: - Screen Recording

    /// Returns true if the app has screen recording permission.
    static func checkScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Prompts the user to grant screen recording permission.
    static func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
    }

    // MARK: - Accessibility

    /// Returns true if the app is a trusted accessibility client.
    static func checkAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user to grant accessibility permission.
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Input Monitoring

    /// Returns true if the app has input monitoring permission.
    static func checkInputMonitoring() -> Bool {
        CGPreflightListenEventAccess()
    }

    /// Prompts the user to grant input monitoring permission.
    static func requestInputMonitoring() {
        CGRequestListenEventAccess()
    }

    // MARK: - Combined Check

    /// Checks all three permissions and returns their status.
    static func checkAllPermissions() -> (screenRecording: Bool, accessibility: Bool, inputMonitoring: Bool) {
        (
            screenRecording: checkScreenRecording(),
            accessibility: checkAccessibility(),
            inputMonitoring: checkInputMonitoring()
        )
    }
}
