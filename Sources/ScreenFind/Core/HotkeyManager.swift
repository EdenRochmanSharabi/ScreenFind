import Cocoa

final class HotkeyManager {
    var onActivate: (() -> Void)?

    // Accessible to the free-function callback via Unmanaged pointer
    fileprivate(set) var eventTap: CFMachPort?
    fileprivate var keyCode: Int64
    fileprivate var modifierFlags: CGEventFlags

    private var runLoopSource: CFRunLoopSource?

    static let defaultKeyCode: Int = 3       // 'F'
    static let defaultModifiers: UInt64 = CGEventFlags.maskControl.rawValue

    init() {
        let storedKeyCode = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? Int
            ?? HotkeyManager.defaultKeyCode
        let storedModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt64
            ?? HotkeyManager.defaultModifiers

        self.keyCode = Int64(storedKeyCode)
        self.modifierFlags = CGEventFlags(rawValue: storedModifiers)
    }

    func register() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: selfPtr
        ) else {
            print("[HotkeyManager] Failed to create event tap. Check Accessibility permissions.")
            return
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("[HotkeyManager] Global hotkey registered.")
    }

    func updateHotkey(keyCode: Int, modifiers: UInt64) {
        self.keyCode = Int64(keyCode)
        self.modifierFlags = CGEventFlags(rawValue: modifiers)

        UserDefaults.standard.set(keyCode, forKey: "hotkeyKeyCode")
        UserDefaults.standard.set(modifiers, forKey: "hotkeyModifiers")

        // Re-register the tap with the new settings
        unregister()
        register()
    }

    func unregister() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    deinit {
        unregister()
    }
}

/// C-compatible callback for the CGEvent tap.
/// Accesses HotkeyManager via `Unmanaged` pointer — cannot use Swift closures.
private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

    // Re-enable the tap if it gets disabled by timeout
    if type == .tapDisabledByTimeout {
        if let tap = manager.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let eventKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let eventFlags = event.flags

    // Mask to only check modifier keys we care about (ignore caps lock, etc.)
    let relevantMask: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand]
    let pressedModifiers = eventFlags.intersection(relevantMask)
    let requiredModifiers = manager.modifierFlags.intersection(relevantMask)

    if eventKeyCode == manager.keyCode && pressedModifiers == requiredModifiers {
        DispatchQueue.main.async {
            manager.onActivate?()
        }
        // Consume the event
        return nil
    }

    return Unmanaged.passUnretained(event)
}
