import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    var overlayCoordinator: OverlayCoordinator?  // needs to be accessible from ScreenFindApp

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (LSUIElement equivalent for SPM executables)
        NSApp.setActivationPolicy(.accessory)

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

    @objc private func hotkeyDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyCode = userInfo["keyCode"] as? Int,
              let modifiers = userInfo["modifiers"] as? UInt64 else { return }
        hotkeyManager?.updateHotkey(keyCode: keyCode, modifiers: modifiers)
    }
}
