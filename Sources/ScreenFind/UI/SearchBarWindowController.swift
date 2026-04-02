import Cocoa
import SwiftUI

final class SearchBarWindowController {
    private var panel: NSPanel?
    private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        let searchBarView = SearchBarContentView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: searchBarView)

        let panel = NSPanel(contentViewController: hostingController)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position: centered horizontally on primary screen, 80pt from top
        if let screen = NSScreen.main {
            let panelWidth: CGFloat = 440
            let panelHeight: CGFloat = 52
            let x = screen.frame.midX - panelWidth / 2
            let y = screen.frame.maxY - 80 - panelHeight  // AppKit coords: Y from bottom
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}
