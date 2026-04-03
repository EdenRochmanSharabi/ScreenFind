import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    var overlayCoordinator: OverlayCoordinator?  // needs to be accessible from ScreenFindApp

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (LSUIElement equivalent for SPM executables)
        NSApp.setActivationPolicy(.accessory)

        // If launched with --settings, show the settings window and re-enable menu bar icon
        if CommandLine.arguments.contains("--settings") {
            UserDefaults.standard.set(true, forKey: "showMenuBarIcon")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.openSettingsWindow()
            }
        }

        let coordinator = OverlayCoordinator()
        self.overlayCoordinator = coordinator

        hotkeyManager = HotkeyManager()
        hotkeyManager?.onActivate = { [weak coordinator] in
            Task { @MainActor in
                coordinator?.activate()
            }
        }
        hotkeyManager?.register()

        // Check permissions
        let perms = PermissionManager.checkAllPermissions()
        if !perms.screenRecording { PermissionManager.requestScreenRecording() }
        if !perms.accessibility { PermissionManager.requestAccessibility() }
        if !perms.inputMonitoring { PermissionManager.requestInputMonitoring() }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyDidChange(_:)),
            name: .hotkeyDidChange,
            object: nil
        )
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
        NSApp.activate()
        SettingsWindowController.shared.window = window
    }

    @objc private func hotkeyDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyCode = userInfo["keyCode"] as? Int,
              let modifiers = userInfo["modifiers"] as? UInt64 else { return }
        hotkeyManager?.updateHotkey(keyCode: keyCode, modifiers: modifiers)
    }
}
