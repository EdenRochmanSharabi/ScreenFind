import SwiftUI

struct SettingsView: View {
    @State private var isRecording = false
    @State private var currentKeyCode: Int
    @State private var currentModifiers: UInt64
    @State private var eventMonitor: Any?
    @State private var launchAtLogin: Bool

    init() {
        let keyCode = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? Int
            ?? HotkeyManager.defaultKeyCode
        let modifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt64
            ?? HotkeyManager.defaultModifiers
        _currentKeyCode = State(initialValue: keyCode)
        _currentModifiers = State(initialValue: modifiers)
        _launchAtLogin = State(initialValue: LaunchAtLoginManager.isEnabled)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            HStack {
                Text("Global Hotkey:")

                Button(action: {
                    startRecording()
                }) {
                    Text(isRecording
                         ? "Press a key combo..."
                         : hotkeyDisplayString(keyCode: currentKeyCode, modifiers: currentModifiers))
                        .frame(minWidth: 120)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
            }

            Button("Reset to Default (^F)") {
                resetToDefault()
            }
            .buttonStyle(.borderless)
            .foregroundColor(.accentColor)

            Divider()

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        try LaunchAtLoginManager.setEnabled(newValue)
                    } catch {
                        print("[Settings] Failed to set launch at login: \(error)")
                        launchAtLogin = !newValue
                    }
                }

            Spacer()
        }
        .padding(24)
        .frame(width: 360, height: 240)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = Int(event.keyCode)
            var modifiers: UInt64 = 0

            if event.modifierFlags.contains(.control) {
                modifiers |= CGEventFlags.maskControl.rawValue
            }
            if event.modifierFlags.contains(.shift) {
                modifiers |= CGEventFlags.maskShift.rawValue
            }
            if event.modifierFlags.contains(.option) {
                modifiers |= CGEventFlags.maskAlternate.rawValue
            }
            if event.modifierFlags.contains(.command) {
                modifiers |= CGEventFlags.maskCommand.rawValue
            }

            // Require at least one modifier
            guard modifiers != 0 else { return event }

            self.currentKeyCode = keyCode
            self.currentModifiers = modifiers
            saveHotkey(keyCode: keyCode, modifiers: modifiers)
            stopRecording()

            // Consume the event
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func resetToDefault() {
        currentKeyCode = HotkeyManager.defaultKeyCode
        currentModifiers = HotkeyManager.defaultModifiers
        saveHotkey(keyCode: currentKeyCode, modifiers: currentModifiers)
    }

    private func saveHotkey(keyCode: Int, modifiers: UInt64) {
        UserDefaults.standard.set(keyCode, forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(modifiers, forKey: "hotkeyModifiers")

        // Notify the HotkeyManager to re-register with new settings
        NotificationCenter.default.post(
            name: .hotkeyDidChange,
            object: nil,
            userInfo: ["keyCode": keyCode, "modifiers": modifiers]
        )
    }
}

extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
}
