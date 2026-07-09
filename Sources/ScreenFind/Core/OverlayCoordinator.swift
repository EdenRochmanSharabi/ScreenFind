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
    private var lastOCRResults: [OCRResult] = []
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

    /// Real-time tracking: 30fps motion estimation moves the rings between
    /// OCR passes so they stick to scrolling text.
    private let motionTracker = MotionTracker()
    private let focusedRegion = FocusedRegionStore()

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

                // 4. Start real-time motion tracking of the focused window
                focusedRegion.set(focusedWindowFrame())
                motionTracker.regionProvider = { [focusedRegion] in focusedRegion.get() }
                motionTracker.onShift = { [weak self] shift in
                    self?.applyMotionShift(shift)
                }
                if let displayID = NSScreen.main?.displayID ?? captures.first?.displayID {
                    try? await motionTracker.start(displayID: displayID)
                }
                guard isActive else {
                    motionTracker.stop()
                    return
                }

                // 5. Run OCR in background
                let ocrResults = try await ocrService.recognizeAllScreens(captures)
                guard isActive else { return }
                lastOCRResults = ocrResults
                searchEngine.loadResults(ocrResults)
                isOCRComplete = true

                // 6. If user already typed something, search now
                if !query.isEmpty {
                    performSearch(query: query)
                }

                print("[OverlayCoordinator] OCR complete: \(ocrResults.flatMap(\.textBlocks).count) text blocks")
                if ProcessInfo.processInfo.environment["SCREENFIND_LOG_OCR"] == "1" {
                    for block in ocrResults.flatMap(\.textBlocks) {
                        print("[OCR] \"\(block.text)\" conf=\(block.confidence)")
                    }
                }

                // 7. Keep re-anchoring: fresh OCR corrects the motion tracking
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
        motionTracker.stop()
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

    /// Continuously re-anchors highlights while the overlay is active.
    ///
    /// Words that move go to nearby zones, so attention goes there first:
    /// cheap *focus passes* re-OCR only inflated regions around the current
    /// matches (~5 Hz), and a *full pass* sweeps the whole screen every 4th
    /// iteration (~1 Hz) to pick up matches appearing anywhere else. The
    /// 30fps motion tracker moves the rings between these passes.
    private func startLiveRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            var iteration = 0
            while !Task.isCancelled {
                guard let self, self.isActive else { return }
                do {
                    let hasMatches = !self.matchNavigator.matches.isEmpty && !self.query.isEmpty
                    if hasMatches && iteration % 4 != 0 {
                        try await self.runFocusPass()
                    } else {
                        try await self.runFullPass()
                    }
                } catch {
                    print("[Coordinator] live refresh error: \(error)")
                }
                iteration += 1
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    /// Full-screen tiled OCR: finds matches anywhere. ~0.5s per pass.
    private func runFullPass() async throws {
        let newCaptures = try await captureService.captureAllScreens()
        guard isActive else { return }
        let ocrResults = try await ocrService.recognizeAllScreens(newCaptures)
        guard isActive else { return }
        captures = newCaptures
        lastOCRResults = ocrResults
        searchEngine.loadResults(ocrResults)
        focusedRegion.set(focusedWindowFrame())
        refreshHighlights()
    }

    /// Focus pass: re-OCR only the zones around current matches (inflated for
    /// expected motion), keeping the rest of the last full pass. ~100-150ms.
    private func runFocusPass() async throws {
        let regionsByDisplay = focusRegions(from: matchNavigator.matches)
        guard !regionsByDisplay.isEmpty else { return }
        let newCaptures = try await captureService.captureAllScreens()
        guard isActive else { return }

        var merged: [OCRResult] = []
        for capture in newCaptures {
            let imageBounds = CGRect(x: 0, y: 0, width: capture.image.width, height: capture.image.height)
            guard let previous = lastOCRResults.first(where: { $0.displayID == capture.displayID }) else { continue }
            let regions = regionsByDisplay[capture.displayID] ?? []
            guard !regions.isEmpty else {
                merged.append(previous)
                continue
            }

            // Overlay-space regions → image-pixel tile frames
            let tileFrames = regions.map { region in
                CGRect(
                    x: (region.minX - capture.frame.minX) * capture.scaleFactor,
                    y: (region.minY - capture.frame.minY) * capture.scaleFactor,
                    width: region.width * capture.scaleFactor,
                    height: region.height * capture.scaleFactor
                ).intersection(imageBounds)
            }.filter { !$0.isEmpty }

            let freshBlocks = try await ocrService.recognizeRegions(tileFrames, in: capture)
            guard isActive else { return }

            // Fresh blocks replace whatever the previous pass saw in the zones
            let keptBlocks = previous.textBlocks.filter { block in
                !regions.contains { $0.intersects(block.screenRect) }
            }
            merged.append(OCRResult(
                displayID: capture.displayID,
                textBlocks: keptBlocks + freshBlocks,
                imageSize: CGSize(width: capture.image.width, height: capture.image.height),
                screenFrame: capture.frame,
                scaleFactor: capture.scaleFactor
            ))
        }

        captures = newCaptures
        lastOCRResults = merged
        searchEngine.loadResults(merged)
        refreshHighlights()
    }

    /// Zones around the current matches, inflated for expected motion (mostly
    /// vertical: scrolling), merged when overlapping, per display.
    private func focusRegions(from matches: [SearchMatch]) -> [CGDirectDisplayID: [CGRect]] {
        var regions: [CGDirectDisplayID: [CGRect]] = [:]
        for match in matches {
            regions[match.displayID, default: []].append(
                match.screenRect.insetBy(dx: -120, dy: -300)
            )
        }
        for (display, rects) in regions {
            var mergedRects: [CGRect] = []
            for rect in rects {
                if let index = mergedRects.firstIndex(where: { $0.intersects(rect) }) {
                    mergedRects[index] = mergedRects[index].union(rect)
                } else {
                    mergedRects.append(rect)
                }
            }
            // Cap the number of separate OCR crops; beyond that, one big box
            if mergedRects.count > 3 {
                mergedRects = [mergedRects.dropFirst().reduce(mergedRects[0]) { $0.union($1) }]
            }
            regions[display] = mergedRects
        }
        return regions
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
            switch event.keyCode {
            case 53:  // Escape
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
            case 126:  // Up arrow — previous match
                Task { @MainActor [weak self] in
                    self?.navigatePrevious()
                }
                return nil
            case 125:  // Down arrow — next match
                Task { @MainActor [weak self] in
                    self?.navigateNext()
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeEscMonitor() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
    }

    // MARK: - Real-time motion shift

    /// Applies a motion-estimated shift to the matches inside the focused
    /// window, keeping rings glued to scrolling content between OCR passes.
    private func applyMotionShift(_ shift: CGVector) {
        guard isActive, !matchNavigator.matches.isEmpty else { return }
        guard let region = focusedRegion.get() else { return }

        let moved = matchNavigator.matches.map { match -> SearchMatch in
            guard let screenFrame = captures.first(where: { $0.displayID == match.displayID })?.frame else {
                return match
            }
            let overlayRegion = Self.appKitToOverlayRect(region, screenFrame: screenFrame)
            guard overlayRegion.contains(CGPoint(x: match.screenRect.midX, y: match.screenRect.midY)) else {
                return match
            }
            var rect = match.screenRect
            rect.origin.x += shift.dx
            rect.origin.y += shift.dy
            return SearchMatch(
                id: match.id,
                displayID: match.displayID,
                screenRect: rect,
                matchedText: match.matchedText,
                contextText: match.contextText,
                isOnScreen: match.isOnScreen
            )
        }
        matchNavigator.refreshMatches(moved)
        overlayController.updateHighlights(
            matches: moved,
            currentIndex: matchNavigator.currentIndex,
            animated: false
        )
    }

    /// Converts a rect from AppKit global coordinates (bottom-left origin) to
    /// the overlay's per-screen-flipped coordinate space.
    private static func appKitToOverlayRect(_ rect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: 2 * screenFrame.origin.y + screenFrame.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
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
