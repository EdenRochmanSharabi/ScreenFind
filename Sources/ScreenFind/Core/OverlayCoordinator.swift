import Cocoa
import Combine
import SwiftUI

@MainActor
final class OverlayCoordinator: ObservableObject {
    @Published var isActive = false
    @Published var isOCRComplete = false
    @Published var query = ""

    private let captureService = ScreenCaptureService()
    private let ocrService = OCRService()
    private let searchEngine = SearchEngine()
    let matchNavigator = MatchNavigator()

    private var overlayController = OverlayWindowController()
    private var searchBarController: SearchBarWindowController?

    private var captures: [ScreenCapture] = []
    private var cancellables = Set<AnyCancellable>()

    /// Local event monitor used to intercept ESC while the overlay is active.
    private var escMonitor: Any?

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
        guard !isActive else {
            // Toggle: if already active, dismiss
            deactivate()
            return
        }

        isActive = true
        isOCRComplete = false
        query = ""

        // Install ESC key monitor
        installEscMonitor()

        Task {
            do {
                // 1. Capture all screens
                captures = try await captureService.captureAllScreens()

                // 2. Show overlay immediately (dim + frozen screenshot)
                overlayController.showOverlay(captures: captures)

                // 3. Show search bar
                let viewModel = SearchViewModel(coordinator: self)
                searchBarController = SearchBarWindowController(viewModel: viewModel)
                searchBarController?.show()

                // 4. Run OCR in background
                let ocrResults = try await ocrService.recognizeAllScreens(captures)
                searchEngine.loadResults(ocrResults)
                isOCRComplete = true

                // 5. If user already typed something, search now
                if !query.isEmpty {
                    performSearch(query: query)
                }

                print("[OverlayCoordinator] OCR complete: \(ocrResults.flatMap(\.textBlocks).count) text blocks")
            } catch {
                print("[OverlayCoordinator] Error: \(error)")
                deactivate()
            }
        }
    }

    func deactivate() {
        isActive = false
        isOCRComplete = false
        query = ""

        removeEscMonitor()

        overlayController.dismissOverlay()
        searchBarController?.dismiss()
        searchBarController = nil

        captures = []
        matchNavigator.updateMatches([])
    }

    private func performSearch(query: String) {
        guard isOCRComplete else { return }
        let matches = searchEngine.search(query: query)
        matchNavigator.updateMatches(matches)
        overlayController.updateHighlights(
            matches: matches,
            currentIndex: matchNavigator.currentIndex
        )
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
        // Use a global monitor so it fires even when the panel is key.
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // keyCode 53 == Escape
            if event.keyCode == 53 {
                Task { @MainActor [weak self] in
                    self?.deactivate()
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
}
