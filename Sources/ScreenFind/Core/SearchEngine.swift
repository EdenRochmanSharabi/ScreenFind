import Cocoa
import Vision

/// Performs real-time text matching against pre-computed OCR results.
final class SearchEngine {

    private var ocrResults: [OCRResult] = []

    /// Call once after OCR completes to load results into the engine.
    func loadResults(_ results: [OCRResult]) {
        self.ocrResults = results
    }

    /// Called on every keystroke. Returns all matches sorted by screen position
    /// (top-to-bottom, then left-to-right).
    ///
    /// Matching is case-insensitive and diacritics-insensitive.
    func search(query: String) -> [SearchMatch] {
        guard !query.isEmpty else { return [] }

        var matches: [SearchMatch] = []

        for result in ocrResults {
            for block in result.textBlocks {
                var searchRange = block.text.startIndex..<block.text.endIndex

                while let range = block.text.range(
                    of: query,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchRange
                ) {
                    // Attempt to get a precise sub-string bounding box via Vision.
                    let subRect: CGRect
                    if let box = try? block.recognizedText.boundingBox(for: range) {
                        // box.boundingBox is a normalized Vision rect; convert to screen coords.
                        subRect = CoordinateTransformer.visionRectToScreenRect(
                            box.boundingBox,
                            imageSize: result.imageSize,
                            screenFrame: result.screenFrame,
                            scaleFactor: result.scaleFactor
                        )
                    } else {
                        // Fallback: highlight the entire text block.
                        subRect = block.screenRect
                    }

                    let match = SearchMatch(
                        id: UUID(),
                        displayID: result.displayID,
                        screenRect: subRect,
                        matchedText: String(block.text[range]),
                        contextText: block.text,
                        isOnScreen: true
                    )
                    matches.append(match)

                    // Advance past this match to find overlapping / subsequent occurrences.
                    searchRange = range.upperBound..<block.text.endIndex
                }
            }
        }

        // Sort top-to-bottom, then left-to-right (10 pt tolerance for same-line detection).
        matches.sort { a, b in
            if abs(a.screenRect.origin.y - b.screenRect.origin.y) > 10 {
                return a.screenRect.origin.y < b.screenRect.origin.y
            }
            return a.screenRect.origin.x < b.screenRect.origin.x
        }

        return matches
    }
}
