import SwiftUI

@main
struct ScreenFindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    var body: some Scene {
        MenuBarExtra("ScreenFind", systemImage: "magnifyingglass", isInserted: $showMenuBarIcon) {
            MenuBarView()
        }
    }
}
