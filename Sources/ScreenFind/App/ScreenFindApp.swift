import SwiftUI

@main
struct ScreenFindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("ScreenFind", systemImage: "magnifyingglass") {
            MenuBarView()
        }
    }
}
