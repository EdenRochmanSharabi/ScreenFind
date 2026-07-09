import Cocoa
import Combine
import SwiftUI
import ApplicationServices

@MainActor
final class OverlayCoordinator: ObservableObject {
    @Published var isActive = false
    @Published var isOCRComplete = false
    @Published var query = ""

    private let captureService = ScreenCaptureService()
    private let ocrService = OCRService()
    private let searchEngine = SearchEngine()
    private let accessibilityService = AccessibilityService()
    let matchNavigator = MatchNavigator()

    private var overlayController = OverlayWindowController()
    private var searchBarController: SearchBarWindowController?
    private var badgeController = OffScreenBadgeWindowController()

    private var captures: [ScreenCapture] = []
    private var offScreenResult: OffScreenResult?
    private var cancellables = Set<AnyCancellable>()

    /// Local event monitor used to intercept ESC while the overlay is active.
    private var escMonitor: Any?

    /// Global event monitor: a click in any other app dismisses the overlay
    /// (like clicking outside Spotlight). Clicks on our own windows — the
    /// search bar — don't trigger it, since global monitors only see events
    /// delivered to other applications.
    private var clickMonitor: Any?

    /// Live tracking: re-captures and re-OCRs the screen while active so
    /// highlights follow text that moves (scrolling, streaming output).
    private var refreshTask: Task<Void, Never>?

    init() {
        // Watch query changes for real-time search
        $query
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)

    }

    func activate() {
        print("[Coordinator] activate() — isActive: \(isActive)")
        guard !isActive else {
            // Toggle: if already active, dismiss
            deactivate()
            return
        }

        isActive = true
        isOCRComplete = false
        query = ""

        // Install ESC key monitor and click-outside-to-dismiss monitor
        installEscMonitor()
        installClickMonitor()

        Task {
            do {
                // 1. Capture all screens
                let newCaptures = try await captureService.captureAllScreens()

                // Bail out if the overlay was dismissed while the capture was in flight,
                // otherwise we'd show an orphaned overlay with no ESC monitor installed.
                guard isActive else {
                    print("[Coordinator] capture finished but no longer active, bailing")
                    return
                }
                captures = newCaptures
                print("[Coordinator] captured \(captures.count) screen(s)")

                // 2. Show overlay (transparent, highlights only)
                overlayController.showOverlay(captures: captures)

                // 3. Show search bar
                let viewModel = SearchViewModel(coordinator: self)
                searchBarController = SearchBarWindowController(viewModel: viewModel)
                searchBarController?.show()

                // 4. Run OCR in background
                let ocrResults = try await ocrService.recognizeAllScreens(captures)
                guard isActive else { return }
                searchEngine.loadResults(ocrResults)
                isOCRComplete = true

                // 5. If user already typed something, search now
                if !query.isEmpty {
                    performSearch(query: query)
                }

                print("[OverlayCoordinator] OCR complete: \(ocrResults.flatMap(\.textBlocks).count) text blocks")
                if ProcessInfo.processInfo.environment["SCREENFIND_LOG_OCR"] == "1" {
                    for block in ocrResults.flatMap(\.textBlocks) {
                        print("[OCR] \"\(block.text)\" conf=\(block.confidence)")
                    }
                }

                // 6. Keep tracking: highlights follow text that moves
                startLiveRefresh()
            } catch {
                print("[OverlayCoordinator] Error: \(error)")
                deactivate()
            }
        }
    }

    func deactivate() {
        print("[Coordinator] deactivate()")
        isActive = false
        isOCRComplete = false
        query = ""

        refreshTask?.cancel()
        refreshTask = nil
        removeEscMonitor()
        removeClickMonitor()

        overlayController.dismissOverlay()
        searchBarController?.dismiss()
        searchBarController = nil
        badgeController.dismissBadge()

        captures = []
        offScreenResult = nil
        matchNavigator.updateMatches([])
    }

    private func performSearch(query: String) {
        guard isOCRComplete else { return }
        let matches = searchEngine.search(query: query)
        print("[Coordinator] performSearch(\"\(query)\") — \(matches.count) matches")
        matchNavigator.updateMatches(matches)
        overlayController.updateHighlights(
            matches: matches,
            currentIndex: matchNavigator.currentIndex
        )

        // Run accessibility off-screen search in parallel
        Task {
            let axResult = await accessibilityService.getOffScreenMatches(query: query)

            // Drop stale results: the overlay may have been dismissed or the query
            // changed while the AX tree walk was in flight.
            guard isActive, self.query == query else { return }

            if let axResult {
                offScreenResult = axResult
                badgeController.showBadge(result: axResult, nearAppFrame: focusedWindowFrame())
            } else {
                offScreenResult = nil
                badgeController.dismissBadge()
            }
        }
    }

    /// Continuously re-captures and re-OCRs the screen while the overlay is
    /// active, so highlight rings follow text that moves (scrolling, streaming
    /// output). OCR takes ~300-700ms per pass, so the effective refresh rate
    /// is ~1-2 Hz; the layer animation in OverlayContentView makes the rings
    /// glide between positions.
    private func startLiveRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isActive else { return }
                do {
                    let newCaptures = try await self.captureService.captureAllScreens()
                    guard self.isActive, !Task.isCancelled else { return }
                    let ocrResults = try await self.ocrService.recognizeAllScreens(newCaptures)
                    guard self.isActive, !Task.isCancelled else { return }
                    self.captures = newCaptures
                    self.searchEngine.loadResults(ocrResults)
                    self.refreshHighlights()
                } catch {
                    print("[Coordinator] live refresh error: \(error)")
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    /// Re-runs the current query against fresh OCR results without touching
    /// the off-screen badge or resetting the user's navigation position.
    private func refreshHighlights() {
        guard isOCRComplete, !query.isEmpty else { return }
        let matches = searchEngine.search(query: query)
        matchNavigator.refreshMatches(matches)
        overlayController.updateHighlights(
            matches: matches,
            currentIndex: matchNavigator.currentIndex
        )
    }

    /// Returns the frontmost app's focused-window frame in AppKit global
    /// coordinates (bottom-left origin), or nil if unavailable.
    private func focusedWindowFrame() -> CGRect? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef, CFGetTypeID(windowRef) == AXUIElementGetTypeID() else { return nil }
        let window = windowRef as! AXUIElement

        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef, CFGetTypeID(positionRef) == AXValueGetTypeID(),
              let sizeRef, CFGetTypeID(sizeRef) == AXValueGetTypeID() else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }

        // AX positions use a top-left origin with Y growing downward; convert to
        // AppKit global coordinates (bottom-left origin, Y up).
        guard let primary = NSScreen.primaryScreen else { return nil }
        let appKitY = primary.frame.height - position.y - size.height
        return CGRect(x: position.x, y: appKitY, width: size.width, height: size.height)
    }

    func navigateNext() {
        matchNavigator.navigateNext()
        overlayController.updateHighlights(
            matches: matchNavigator.matches,
            currentIndex: matchNavigator.currentIndex
        )
    }

    func navigatePrevious() {
        matchNavigator.navigatePrevious()
        overlayController.updateHighlights(
            matches: matchNavigator.matches,
            currentIndex: matchNavigator.currentIndex
        )
    }

    // MARK: - ESC handling

    private func installEscMonitor() {
        // Local monitor: ESC always reaches this app because the search panel is key.
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // keyCode 53 == Escape
            if event.keyCode == 53 {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // Like Spotlight: first ESC clears the query, second dismisses.
                    if self.query.isEmpty {
                        self.deactivate()
                    } else {
                        self.query = ""
                    }
                }
                return nil  // consume the event
            }
            return event
        }
    }

    private func removeEscMonitor() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
    }

    // MARK: - Click-outside handling

    private func installClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.deactivate()
            }
        }
    }

    private func removeClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}
