import Cocoa

extension NSScreen {

    /// Returns the NSScreen that corresponds to the given CGDirectDisplayID, or nil if not found.
    static func screenForDisplay(_ displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            return screenNumber == displayID
        }
    }

    /// The CGDirectDisplayID for this screen, extracted from deviceDescription.
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// The primary screen (the one with the menu bar, whose origin is (0,0) in global coordinates).
    static var primaryScreen: NSScreen? {
        NSScreen.screens.first
    }
}
