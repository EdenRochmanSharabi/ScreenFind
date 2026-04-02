import Cocoa
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var currentMatchIndex: Int = 0
    @Published var totalMatches: Int = 0
    @Published var isOCRComplete: Bool = false

    private weak var coordinator: OverlayCoordinator?
    private var cancellables = Set<AnyCancellable>()

    init(coordinator: OverlayCoordinator) {
        self.coordinator = coordinator

        // Sync query to coordinator
        $query
            .removeDuplicates()
            .sink { [weak coordinator] q in
                coordinator?.query = q
            }
            .store(in: &cancellables)

        // Sync match state from coordinator's navigator
        coordinator.matchNavigator.$currentIndex
            .assign(to: &$currentMatchIndex)
        coordinator.matchNavigator.$matches
            .map(\.count)
            .assign(to: &$totalMatches)
        coordinator.$isOCRComplete
            .assign(to: &$isOCRComplete)
    }

    func navigateToNext() {
        coordinator?.navigateNext()
    }

    func navigateToPrevious() {
        coordinator?.navigatePrevious()
    }

    func dismiss() {
        coordinator?.deactivate()
    }
}
