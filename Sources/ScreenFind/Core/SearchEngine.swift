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
                // Try each candidate reading (best first): when Vision garbles
                // the top reading of low-contrast text, an alternate often has
                // the correct string. Use the first candidate that matches.
                for candidate in block.candidates {
                    let text = candidate.string
                    var searchRange = text.startIndex..<text.endIndex
                    var foundInCandidate = false

                    while let range = text.range(
                        of: query,
                        options: [.caseInsensitive, .diacriticInsensitive],
                        range: searchRange
                    ) {
                        foundInCandidate = true

                        // Attempt to get a precise sub-string bounding box via Vision.
                        let subRect: CGRect
                        if let box = try? candidate.boundingBox(for: range) {
                            // box.boundingBox is normalized within the block's
                            // tile; convert tile → image → screen coords.
                            let imageRect = CoordinateTransformer.tileRectToImageRect(
                                box.boundingBox,
                                tileFrame: block.tileFrame,
                                imageSize: result.imageSize
                            )
                            subRect = CoordinateTransformer.visionRectToScreenRect(
                                imageRect,
                                imageSize: result.imageSize,
                                screenFrame: result.screenFrame,
                                scaleFactor: result.scaleFactor
                            )
                        } else {
                            // Fallback: Vision couldn't produce a sub-range box.
                            // Estimate it from the character position within the
                            // block — far tighter than highlighting the whole block.
                            let total = max(text.count, 1)
                            let startFraction = CGFloat(text.distance(from: text.startIndex, to: range.lowerBound)) / CGFloat(total)
                            let lengthFraction = CGFloat(text.distance(from: range.lowerBound, to: range.upperBound)) / CGFloat(total)
                            let blockRect = block.screenRect
                            subRect = CGRect(
                                x: blockRect.origin.x + startFraction * blockRect.width,
                                y: blockRect.origin.y,
                                width: max(lengthFraction * blockRect.width, 8),
                                height: blockRect.height
                            )
                        }

                        let match = SearchMatch(
                            id: UUID(),
                            displayID: result.displayID,
                            screenRect: subRect,
                            matchedText: String(text[range]),
                            contextText: text,
                            isOnScreen: true
                        )
                        matches.append(match)

                        // Advance past this match to find subsequent occurrences.
                        searchRange = range.upperBound..<text.endIndex
                    }

                    if foundInCandidate { break }
                }
            }
        }

        // Text in tile-overlap strips is recognized twice; drop matches whose
        // rects mostly coincide with an already-kept one.
        matches = Self.dedupOverlapping(matches)

        // Sort top-to-bottom, then left-to-right (10 pt tolerance for same-line detection).
        // screenRect.origin.y is flipped within its own screen, so it can't be compared
        // across displays directly; convert to a desktop-global top-down key first.
        var screenFrames: [CGDirectDisplayID: CGRect] = [:]
        for result in ocrResults {
            screenFrames[result.displayID] = result.screenFrame
        }
        func topDownY(_ match: SearchMatch) -> CGFloat {
            guard let frame = screenFrames[match.displayID] else {
                return match.screenRect.origin.y
            }
            // AppKit global Y of the rect's top edge; negate so smaller = higher on screen
            return -(2 * frame.origin.y + frame.height - match.screenRect.origin.y)
        }
        matches.sort { a, b in
            let ya = topDownY(a)
            let yb = topDownY(b)
            if abs(ya - yb) > 10 {
                return ya < yb
            }
            return a.screenRect.origin.x < b.screenRect.origin.x
        }

        return matches
    }

    /// Removes matches whose rect mostly coincides with an earlier one on the
    /// same display (duplicates from tile-overlap strips).
    private static func dedupOverlapping(_ matches: [SearchMatch]) -> [SearchMatch] {
        var kept: [SearchMatch] = []
        for match in matches {
            let isDuplicate = kept.contains { existing in
                existing.displayID == match.displayID &&
                    intersectionOverUnion(existing.screenRect, match.screenRect) > 0.5
            }
            if !isDuplicate {
                kept.append(match)
            }
        }
        return kept
    }

    private static func intersectionOverUnion(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea
        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }
}
