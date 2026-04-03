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
                openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Permissions...") {
                openPermissionsWindow()
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

    private func openSettingsWindow() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "ScreenFind Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 360, height: 280))
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Bring the app to the foreground
        NSApp.activate()

        // Hold a reference so the window isn't deallocated
        SettingsWindowController.shared.window = window
    }

    private func openPermissionsWindow() {
        let permissionsView = PermissionOnboardingView()
        let hostingController = NSHostingController(rootView: permissionsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "ScreenFind Permissions"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Bring the app to the foreground
        NSApp.activate()

        // Hold a reference so the window isn't deallocated
        PermissionsWindowController.shared.window = window
    }
}

/// Holds a strong reference to the settings window so it stays alive.
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    var window: NSWindow?
}

/// Holds a strong reference to the permissions window so it stays alive.
final class PermissionsWindowController {
    static let shared = PermissionsWindowController()
    var window: NSWindow?
}
