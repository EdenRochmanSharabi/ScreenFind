import Testing
@testable import ScreenFind

/// Tests for SearchEngine that do not require Vision framework objects.
///
/// SearchEngine.search() works against OCRResult / TextBlock values, each of which
/// embeds a VNRecognizedText that can only be obtained from a live Vision request.
/// Those paths are covered by integration tests elsewhere.  Here we exercise the
/// edge cases that are reachable with no loaded data.
struct SearchEngineTests {

    // MARK: - Empty query guard

    @Test func testEmptyQueryReturnsEmpty() {
        let engine = SearchEngine()
        let results = engine.search(query: "")
        #expect(results.isEmpty)
    }

    @Test func testWhitespaceQueryIsNotEmpty() {
        // A single space is a non-empty string — the guard passes and the engine
        // iterates over (no) OCR results, returning an empty array.
        let engine = SearchEngine()
        let results = engine.search(query: " ")
        #expect(results.isEmpty)
    }

    // MARK: - No OCR results loaded

    @Test func testSearchWithNoResultsLoadedReturnsEmpty() {
        let engine = SearchEngine()
        let results = engine.search(query: "hello")
        #expect(results.isEmpty)
    }

    @Test func testSearchWithMultipleQueriesAndNoResultsReturnsEmpty() {
        let engine = SearchEngine()
        #expect(engine.search(query: "foo").isEmpty)
        #expect(engine.search(query: "bar").isEmpty)
        #expect(engine.search(query: "baz").isEmpty)
    }

    // MARK: - loadResults with empty array

    @Test func testLoadEmptyResultsThenSearchReturnsEmpty() {
        let engine = SearchEngine()
        engine.loadResults([])
        #expect(engine.search(query: "test").isEmpty)
    }

    @Test func testLoadEmptyResultsThenEmptyQueryReturnsEmpty() {
        let engine = SearchEngine()
        engine.loadResults([])
        #expect(engine.search(query: "").isEmpty)
    }

    // MARK: - Idempotent empty reload

    @Test func testReloadingEmptyResultsRepeatedly() {
        let engine = SearchEngine()
        engine.loadResults([])
        engine.loadResults([])
        #expect(engine.search(query: "anything").isEmpty)
    }
}
