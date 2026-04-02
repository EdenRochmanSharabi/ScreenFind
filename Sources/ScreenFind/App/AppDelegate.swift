import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private let screenCaptureService = ScreenCaptureService()
    private let ocrService = OCRService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check and print permission status on launch
        checkPermissions()

        hotkeyManager = HotkeyManager()
        hotkeyManager?.onActivate = { [weak self] in
            self?.handleActivation()
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

    // MARK: - Permissions

    private func checkPermissions() {
        let permissions = PermissionManager.checkAllPermissions()
        print("[Permissions] Screen Recording: \(permissions.screenRecording ? "granted" : "NOT granted")")
        print("[Permissions] Accessibility: \(permissions.accessibility ? "granted" : "NOT granted")")
        print("[Permissions] Input Monitoring: \(permissions.inputMonitoring ? "granted" : "NOT granted")")

        if !permissions.screenRecording {
            PermissionManager.requestScreenRecording()
        }
        if !permissions.accessibility {
            PermissionManager.requestAccessibility()
        }
        if !permissions.inputMonitoring {
            PermissionManager.requestInputMonitoring()
        }
    }

    // MARK: - Activation

    private func handleActivation() {
        print("[ScreenFind] Activated! Starting capture + OCR pipeline...")
        Task {
            do {
                let captures = try await screenCaptureService.captureAllScreens()
                print("[ScreenFind] Captured \(captures.count) screen(s).")

                let ocrResults = try await ocrService.recognizeAllScreens(captures)

                for result in ocrResults {
                    print("[ScreenFind] Display \(result.displayID): \(result.textBlocks.count) text block(s)")
                    for block in result.textBlocks {
                        print("  [\(String(format: "%.0f%%", block.confidence * 100))] "
                              + "\"\(block.text)\" "
                              + "at \(formatRect(block.screenRect))")
                    }
                }

                let totalBlocks = ocrResults.reduce(0) { $0 + $1.textBlocks.count }
                print("[ScreenFind] OCR complete. Total text blocks: \(totalBlocks)")
            } catch {
                print("[ScreenFind] Error in capture/OCR pipeline: \(error)")
            }
        }
    }

    private func formatRect(_ rect: CGRect) -> String {
        String(format: "(%.0f, %.0f, %.0f x %.0f)",
               rect.origin.x, rect.origin.y, rect.width, rect.height)
    }
}
