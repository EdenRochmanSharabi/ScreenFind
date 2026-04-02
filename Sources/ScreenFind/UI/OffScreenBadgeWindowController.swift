import Cocoa
import SwiftUI

final class OffScreenBadgeWindowController {
    private var aboveWindow: NSWindow?
    private var belowWindow: NSWindow?

    func showBadge(result: OffScreenResult, nearAppFrame: CGRect?) {
        dismissBadge()

        let appFrame = nearAppFrame ?? (NSScreen.main?.frame ?? .zero)

        if result.matchesBelow > 0 {
            belowWindow = createBadgeWindow(
                matchCount: result.matchesBelow,
                direction: "below",
                position: CGPoint(
                    x: appFrame.midX,
                    y: appFrame.minY + 40  // near bottom of app window
                )
            )
        }

        if result.matchesAbove > 0 {
            aboveWindow = createBadgeWindow(
                matchCount: result.matchesAbove,
                direction: "above",
                position: CGPoint(
                    x: appFrame.midX,
                    y: appFrame.maxY - 40  // near top of app window
                )
            )
        }
    }

    func dismissBadge() {
        aboveWindow?.orderOut(nil)
        belowWindow?.orderOut(nil)
        aboveWindow = nil
        belowWindow = nil
    }

    private func createBadgeWindow(matchCount: Int, direction: String, position: CGPoint) -> NSWindow {
        let view = OffScreenBadgeView(matchCount: matchCount, direction: direction)
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = .borderless
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Size to fit content
        let size = hostingController.view.fittingSize
        window.setFrame(
            NSRect(x: position.x - size.width / 2, y: position.y - size.height / 2, width: size.width, height: size.height),
            display: true
        )
        window.makeKeyAndOrderFront(nil)

        return window
    }
}
