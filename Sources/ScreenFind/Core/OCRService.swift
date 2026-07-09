import Vision

/// Performs OCR on captured screen images using Apple Vision framework.
///
/// Captures are split into overlapping tiles before recognition: Vision's text
/// detector degrades badly on small text in large images (a full 3440px-wide
/// screen yields ~7x fewer text blocks than the same content in tiles).
final class OCRService {

    /// Tiles aim for roughly this size; a 3440x1440 capture becomes a 2x2 grid.
    private static let targetTileSize = CGSize(width: 1600, height: 900)

    /// Overlap between adjacent tiles, as a fraction of the capture size, so
    /// words sitting on a tile boundary appear whole in at least one tile.
    private static let tileOverlap: CGFloat = 0.04

    /// Runs text recognition on all captured screens, all tiles in parallel.
    func recognizeAllScreens(_ captures: [ScreenCapture]) async throws -> [OCRResult] {
        try await withThrowingTaskGroup(of: (CGDirectDisplayID, [TextBlock]).self) { group in
            for capture in captures {
                let imageSize = CGSize(width: capture.image.width, height: capture.image.height)
                for tileFrame in Self.tileFrames(for: imageSize) {
                    group.addTask {
                        (capture.displayID, try self.recognizeTile(tileFrame, in: capture))
                    }
                }
            }

            var blocksByDisplay: [CGDirectDisplayID: [TextBlock]] = [:]
            for try await (displayID, blocks) in group {
                blocksByDisplay[displayID, default: []].append(contentsOf: blocks)
            }

            return captures.map { capture in
                OCRResult(
                    displayID: capture.displayID,
                    textBlocks: blocksByDisplay[capture.displayID] ?? [],
                    imageSize: CGSize(width: capture.image.width, height: capture.image.height),
                    screenFrame: capture.frame,
                    scaleFactor: capture.scaleFactor
                )
            }
        }
    }

    /// Runs recognition on specific pixel regions of a capture — used by the
    /// focus passes that re-anchor zones where matches already are.
    func recognizeRegions(_ tileFrames: [CGRect], in capture: ScreenCapture) async throws -> [TextBlock] {
        try await withThrowingTaskGroup(of: [TextBlock].self) { group in
            for tileFrame in tileFrames {
                group.addTask {
                    try self.recognizeTile(tileFrame, in: capture)
                }
            }
            var blocks: [TextBlock] = []
            for try await tileBlocks in group {
                blocks.append(contentsOf: tileBlocks)
            }
            return blocks
        }
    }

    /// Runs text recognition on a single tile of a capture.
    private func recognizeTile(_ tileFrame: CGRect, in capture: ScreenCapture) throws -> [TextBlock] {
        guard let tileImage = capture.image.cropping(to: tileFrame) else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        // Screens are full of code and terminal text; language correction
        // "fixes" literal tokens (launchctl → real words), which both hides
        // real matches and invents text that isn't on screen.
        request.usesLanguageCorrection = false

        try VNImageRequestHandler(cgImage: tileImage, options: [:]).perform([request])

        let imageSize = CGSize(width: capture.image.width, height: capture.image.height)

        return (request.results ?? []).compactMap { observation in
            let candidates = observation.topCandidates(3)
            guard let candidate = candidates.first else { return nil }

            // Very-low-confidence reads are garbage ("launchctl" → "Launchetz"):
            // they produce phantom matches for text that isn't on screen while
            // their real text is misread anyway. Drop them. (Dimmed terminal
            // text sits right at ~0.3, so the threshold can't go higher without
            // losing real words — the alternate candidates cover the rest.)
            guard candidate.confidence >= 0.3 else { return nil }

            let imageRect = CoordinateTransformer.tileRectToImageRect(
                observation.boundingBox,
                tileFrame: tileFrame,
                imageSize: imageSize
            )
            let screenRect = CoordinateTransformer.visionRectToScreenRect(
                imageRect,
                imageSize: imageSize,
                screenFrame: capture.frame,
                scaleFactor: capture.scaleFactor
            )

            return TextBlock(
                text: candidate.string,
                screenRect: screenRect,
                confidence: candidate.confidence,
                recognizedText: candidate,
                candidates: candidates,
                tileFrame: tileFrame
            )
        }
    }

    /// Splits an image into a grid of overlapping tiles (top-left origin,
    /// image pixels — the space CGImage.cropping uses).
    static func tileFrames(for size: CGSize) -> [CGRect] {
        let cols = max(1, Int((size.width / targetTileSize.width).rounded()))
        let rows = max(1, Int((size.height / targetTileSize.height).rounded()))
        guard cols > 1 || rows > 1 else {
            return [CGRect(origin: .zero, size: size)]
        }

        let overlapX = size.width * tileOverlap
        let overlapY = size.height * tileOverlap
        var frames: [CGRect] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let x = max(0, CGFloat(col) * size.width / CGFloat(cols) - overlapX)
                let y = max(0, CGFloat(row) * size.height / CGFloat(rows) - overlapY)
                let width = min(size.width - x, size.width / CGFloat(cols) + 2 * overlapX)
                let height = min(size.height - y, size.height / CGFloat(rows) + 2 * overlapY)
                frames.append(CGRect(x: x, y: y, width: width, height: height))
            }
        }
        return frames
    }
}
