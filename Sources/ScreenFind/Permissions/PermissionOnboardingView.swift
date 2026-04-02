import SwiftUI

struct PermissionOnboardingView: View {
    @State private var screenRecording = PermissionManager.checkScreenRecording()
    @State private var accessibility = PermissionManager.checkAccessibility()
    @State private var inputMonitoring = PermissionManager.checkInputMonitoring()

    var body: some View {
        VStack(spacing: 20) {
            Text("ScreenFind Permissions")
                .font(.title)
                .fontWeight(.bold)

            Text("ScreenFind needs these permissions to work:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    icon: "camera.fill",
                    title: "Screen Recording",
                    description: "Capture screen content to search for text",
                    granted: screenRecording,
                    action: { PermissionManager.requestScreenRecording(); refreshPermissions() }
                )

                permissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Read off-screen text in applications",
                    granted: accessibility,
                    action: { PermissionManager.requestAccessibility(); refreshPermissions() }
                )

                permissionRow(
                    icon: "keyboard.fill",
                    title: "Input Monitoring",
                    description: "Listen for global hotkey (Ctrl+F)",
                    granted: inputMonitoring,
                    action: { PermissionManager.requestInputMonitoring(); refreshPermissions() }
                )
            }
            .padding()

            if screenRecording && accessibility && inputMonitoring {
                Text("All permissions granted!")
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }

            Button("Refresh") {
                refreshPermissions()
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(width: 450)
    }

    private func permissionRow(icon: String, title: String, description: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(granted ? .green : .orange)

            VStack(alignment: .leading) {
                Text(title).fontWeight(.medium)
                Text(description).font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant") { action() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func refreshPermissions() {
        screenRecording = PermissionManager.checkScreenRecording()
        accessibility = PermissionManager.checkAccessibility()
        inputMonitoring = PermissionManager.checkInputMonitoring()
    }
}
