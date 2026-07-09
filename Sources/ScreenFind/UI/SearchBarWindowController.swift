import Cocoa
import SwiftUI

final class SearchBarWindowController {
    private var panel: NSPanel?
    private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        print("[SearchBar] show() called")
        let searchBarView = SearchBarContentView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: searchBarView)

        let panel = NSPanel(contentViewController: hostingController)
        // Keep our explicit frame: by default NSHostingController resizes the
        // window to fit the SwiftUI content (grew the panel to 600x84).
        hostingController.sizingOptions = []
        // Use .titled so the panel can become key window and accept keyboard input.
        // .fullSizeContentView hides the title bar visually.
        panel.styleMask = [.titled, .fullSizeContentView, .nonactivatingPanel]
        // CRITICAL: NSPanel defaults to hidesOnDeactivate = true. This app is an
        // accessory that never activates (non-activating panel), so AppKit would
        // hide the panel at the window-server level immediately after ordering it
        // in — AppKit still reports isVisible = true, but CGWindowList shows
        // onscreen = false. This is why the search bar never appeared.
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Allow the panel to become key window for keyboard input
        panel.becomesKeyOnlyIfNeeded = false

        // Position like Spotlight: centered horizontally, upper quarter of the screen
        if let screen = NSScreen.main {
            let size = SearchBarContentView.windowSize
            let margin = SearchBarContentView.windowMargin
            let x = screen.frame.midX - size.width / 2
            let y = screen.frame.maxY - screen.frame.height * 0.25 - size.height + margin
            print("[SearchBar] NSScreen.main frame: \(screen.frame), target panel frame: (\(x), \(y), \(size.width), \(size.height))")
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        } else {
            print("[SearchBar] WARNING: NSScreen.main is nil, panel keeps default frame \(panel.frame)")
        }

        // Gentle fade-in, matching system panel behavior
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        print("[SearchBar] after makeKeyAndOrderFront — isVisible: \(panel.isVisible), isKeyWindow: \(panel.isKeyWindow), frame: \(panel.frame), level: \(panel.level.rawValue), screen: \(String(describing: panel.screen?.frame))")
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }, completionHandler: {
            print("[SearchBar] fade-in complete — alphaValue: \(panel.alphaValue), isVisible: \(panel.isVisible), occlusionState visible: \(panel.occlusionState.contains(.visible))")
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak panel] in
            guard let panel else {
                print("[SearchBar] +0.5s — panel deallocated")
                return
            }
            print("[SearchBar] +0.5s — alphaValue: \(panel.alphaValue), isVisible: \(panel.isVisible), isKeyWindow: \(panel.isKeyWindow), frame: \(panel.frame), contentView frame: \(String(describing: panel.contentView?.frame))")
            print("[SearchBar] appearance — panel: \(panel.effectiveAppearance.name.rawValue), app: \(NSApp.effectiveAppearance.name.rawValue)")
        }

        self.panel = panel
    }

    func dismiss() {
        print("[SearchBar] dismiss() called")
        panel?.orderOut(nil)
        panel = nil
    }
}
