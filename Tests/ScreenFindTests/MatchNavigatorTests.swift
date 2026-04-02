import Testing
import Foundation
import CoreGraphics
@testable import ScreenFind

struct MatchNavigatorTests {

    // MARK: - Helpers

    private func makeMatch(x: CGFloat = 0, y: CGFloat = 0) -> SearchMatch {
        SearchMatch(
            id: UUID(),
            displayID: 0,
            screenRect: CGRect(x: x, y: y, width: 100, height: 20),
            matchedText: "test",
            contextText: "test context",
            isOnScreen: true
        )
    }

    // MARK: - Empty state

    @Test func testEmptyInitialState() {
        let nav = MatchNavigator()
        #expect(nav.totalMatches == 0)
        #expect(nav.currentMatch == nil)
        #expect(nav.currentIndex == 0)
    }

    @Test func testNavigateNextOnEmptyDoesNothing() {
        let nav = MatchNavigator()
        nav.navigateNext()
        // Guard fires early; index stays 0
        #expect(nav.currentIndex == 0)
    }

    @Test func testNavigatePreviousOnEmptyDoesNothing() {
        let nav = MatchNavigator()
        nav.navigatePrevious()
        // Guard fires early; index stays 0
        #expect(nav.currentIndex == 0)
    }

    // MARK: - Single match

    @Test func testSingleMatchCurrentMatchIsReturned() {
        let nav = MatchNavigator()
        let match = makeMatch(x: 10, y: 20)
        nav.updateMatches([match])

        #expect(nav.totalMatches == 1)
        #expect(nav.currentMatch != nil)
        #expect(nav.currentMatch?.screenRect.origin.x == 10)
    }

    @Test func testSingleMatchNextWrapsToSelf() {
        let nav = MatchNavigator()
        nav.updateMatches([makeMatch()])
        nav.navigateNext()
        // (0 + 1) % 1 == 0
        #expect(nav.currentIndex == 0)
    }

    @Test func testSingleMatchPreviousWrapsToSelf() {
        let nav = MatchNavigator()
        nav.updateMatches([makeMatch()])
        nav.navigatePrevious()
        // (0 - 1 + 1) % 1 == 0
        #expect(nav.currentIndex == 0)
    }

    // MARK: - Forward navigation

    @Test func testNavigateForwardSequential() {
        let nav = MatchNavigator()
        nav.updateMatches([makeMatch(), makeMatch(), makeMatch()])

        #expect(nav.currentIndex == 0)
        nav.navigateNext()
        #expect(nav.currentIndex == 1)
        nav.navigateNext()
        #expect(nav.currentIndex == 2)
    }

    @Test func testWrapAroundForward() {
        let nav = MatchNavigator()
        nav.updateMatches([makeMatch(), makeMatch()])

        nav.navigateNext() // → 1
        nav.navigateNext() // (1+1) % 2 = 0
        #expect(nav.currentIndex == 0)
    }

    // MARK: - Backward navigation

    @Test func testNavigateBackwardSequential() {
        let nav = MatchNavigator()
        nav.updateMatches([makeMatch(), makeMatch(), makeMatch()])

        nav.navigateNext() // → 1
        nav.navigateNext() // → 2
        nav.navigatePrevious() // → 1
        #expect(nav.currentIndex == 1)
        nav.navigatePrevious() // → 0
        #expect(nav.currentIndex == 0)
    }

    @Test func testWrapAroundBackward() {
        let nav = MatchNavigator()
        nav.updateMatches([makeMatch(), makeMatch(), makeMatch()])

        nav.navigatePrevious() // (0 - 1 + 3) % 3 = 2
        #expect(nav.currentIndex == 2)
    }

    // MARK: - updateMatches resets index

    @Test func testUpdateMatchesResetsIndexToZero() {
        let nav = MatchNavigator()
        nav.updateMatches([makeMatch(), makeMatch(), makeMatch()])
        nav.navigateNext()
        nav.navigateNext()
        #expect(nav.currentIndex == 2)

        nav.updateMatches([makeMatch()])
        #expect(nav.currentIndex == 0)
    }

    @Test func testUpdateMatchesWithEmptyResetsToZero() {
        let nav = MatchNavigator()
        nav.updateMatches([makeMatch(), makeMatch()])
        nav.navigateNext()
        #expect(nav.currentIndex == 1)

        nav.updateMatches([])
        #expect(nav.currentIndex == 0)
        #expect(nav.currentMatch == nil)
        #expect(nav.totalMatches == 0)
    }

    // MARK: - currentMatch tracks currentIndex

    @Test func testCurrentMatchFollowsIndex() {
        let first  = makeMatch(x: 0,   y: 0)
        let second = makeMatch(x: 100, y: 0)
        let third  = makeMatch(x: 200, y: 0)

        let nav = MatchNavigator()
        nav.updateMatches([first, second, third])

        #expect(nav.currentMatch?.screenRect.origin.x == 0)
        nav.navigateNext()
        #expect(nav.currentMatch?.screenRect.origin.x == 100)
        nav.navigateNext()
        #expect(nav.currentMatch?.screenRect.origin.x == 200)
        nav.navigateNext() // wraps to 0
        #expect(nav.currentMatch?.screenRect.origin.x == 0)
    }

    // MARK: - totalMatches

    @Test func testTotalMatchesReflectsLoadedMatches() {
        let nav = MatchNavigator()
        #expect(nav.totalMatches == 0)

        nav.updateMatches([makeMatch(), makeMatch(), makeMatch(), makeMatch()])
        #expect(nav.totalMatches == 4)

        nav.updateMatches([makeMatch()])
        #expect(nav.totalMatches == 1)

        nav.updateMatches([])
        #expect(nav.totalMatches == 0)
    }
}
