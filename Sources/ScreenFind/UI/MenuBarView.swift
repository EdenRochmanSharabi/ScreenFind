import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack {
            Text("ScreenFind")
                .font(.headline)

            Text("Hotkey: \(currentHotkeyDisplayString())")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            Button("Settings...") {
                SettingsWindowController.shared.show()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Permissions...") {
                PermissionsWindowController.shared.show()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private func currentHotkeyDisplayString() -> String {
        let keyCode = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? Int
            ?? HotkeyManager.defaultKeyCode
        let modifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt64
            ?? HotkeyManager.defaultModifiers
        return hotkeyDisplayString(keyCode: keyCode, modifiers: modifiers)
    }

}

/// Creates the settings window on first use and re-fronts it afterwards.
/// Holds a strong reference so the window stays alive.
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    var window: NSWindow?

    func show() {
        if window == nil {
            let hostingController = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "ScreenFind Settings"
            window.styleMask = [.titled, .closable]
            // We keep a strong reference; letting AppKit also release on close
            // would over-release the window.
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 360, height: 280))
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

/// Creates the permissions window on first use and re-fronts it afterwards.
/// Holds a strong reference so the window stays alive.
final class PermissionsWindowController {
    static let shared = PermissionsWindowController()
    var window: NSWindow?

    func show() {
        if window == nil {
            let hostingController = NSHostingController(rootView: PermissionOnboardingView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "ScreenFind Permissions"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
