import Cocoa
import Combine

/// Manages Up/Down arrow navigation state across a list of search matches.
final class MatchNavigator: ObservableObject {

    /// The index of the currently highlighted match.
    @Published var currentIndex: Int = 0

    /// The full list of matches for the current query.
    @Published var matches: [SearchMatch] = []

    /// The total number of matches.
    var totalMatches: Int { matches.count }

    /// The match currently selected for highlighting, or `nil` when there are no matches.
    var currentMatch: SearchMatch? {
        guard !matches.isEmpty, currentIndex >= 0, currentIndex < matches.count else {
            return nil
        }
        return matches[currentIndex]
    }

    /// Replace the match list (e.g. after a new search). Resets the index to the first match.
    func updateMatches(_ newMatches: [SearchMatch]) {
        matches = newMatches
        currentIndex = 0
    }

    /// Advance to the next match, wrapping around from the last to the first.
    func navigateNext() {
        guard !matches.isEmpty else { return }
        currentIndex = (currentIndex + 1) % matches.count
    }

    /// Go back to the previous match, wrapping around from the first to the last.
    func navigatePrevious() {
        guard !matches.isEmpty else { return }
        currentIndex = (currentIndex - 1 + matches.count) % matches.count
    }
}
