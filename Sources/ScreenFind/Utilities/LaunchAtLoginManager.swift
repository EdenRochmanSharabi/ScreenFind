import Foundation

/// Manages launch-at-login by installing/removing a LaunchAgent plist.
/// This is the correct approach for SPM executables (SMAppService requires .app bundles).
struct LaunchAtLoginManager {

    static let label = "com.edenrochman.screenfind"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(label).plist")
    }

    /// Whether a LaunchAgent plist exists for this app.
    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Installs a LaunchAgent so ScreenFind starts automatically at login.
    static func enable() throws {
        let executablePath = resolveExecutablePath()

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
        ]

        // Ensure LaunchAgents directory exists
        let dir = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)

        print("[LaunchAtLogin] Installed: \(plistURL.path)")
    }

    /// Removes the LaunchAgent so ScreenFind no longer starts at login.
    static func disable() throws {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }
        try FileManager.default.removeItem(at: plistURL)
        print("[LaunchAtLogin] Removed: \(plistURL.path)")
    }

    /// Toggle launch-at-login on/off.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }

    /// Resolves the path to the running executable.
    /// Follows symlinks to get the real path so the LaunchAgent survives rebuilds
    /// only if the binary is installed to a stable location.
    private static func resolveExecutablePath() -> String {
        let path = CommandLine.arguments[0]
        // Resolve symlinks
        let resolved = (path as NSString).resolvingSymlinksInPath
        return resolved
    }
}
