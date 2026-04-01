import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkeyManager = HotkeyManager()
        hotkeyManager?.onActivate = {
            print("ScreenFind activated!")
        }
        hotkeyManager?.register()

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
