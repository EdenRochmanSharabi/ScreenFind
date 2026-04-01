import Cocoa

/// Converts a keyCode and CGEventFlags raw value into a human-readable string like "^F".
func hotkeyDisplayString(keyCode: Int, modifiers: UInt64) -> String {
    var parts: [String] = []
    let flags = CGEventFlags(rawValue: modifiers)

    if flags.contains(.maskControl) {
        parts.append("\u{2303}")  // ⌃
    }
    if flags.contains(.maskAlternate) {
        parts.append("\u{2325}")  // ⌥
    }
    if flags.contains(.maskShift) {
        parts.append("\u{21E7}")  // ⇧
    }
    if flags.contains(.maskCommand) {
        parts.append("\u{2318}")  // ⌘
    }

    parts.append(keyCodeToString(keyCode))

    return parts.joined()
}

/// Maps a macOS virtual keyCode to a readable key name.
private func keyCodeToString(_ keyCode: Int) -> String {
    // Common key codes
    let keyMap: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G",
        6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
        13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1",
        19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
        25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "Tab", 49: "Space", 50: "`", 51: "Delete",
        53: "Escape",
        96: "F5", 97: "F6", 98: "F7", 99: "F3",
        100: "F8", 101: "F9", 103: "F11", 105: "F13",
        107: "F14", 109: "F10", 111: "F12", 113: "F15",
        118: "F4", 120: "F2", 122: "F1",
        123: "\u{2190}",  // ←
        124: "\u{2192}",  // →
        125: "\u{2193}",  // ↓
        126: "\u{2191}",  // ↑
    ]

    return keyMap[keyCode] ?? "Key\(keyCode)"
}
