import Vision

/// Performs OCR on captured screen images using Apple Vision framework.
final class OCRService {

    /// Runs text recognition on all captured screens in parallel.
    func recognizeAllScreens(_ captures: [ScreenCapture]) async throws -> [OCRResult] {
        try await withThrowingTaskGroup(of: OCRResult.self) { group in
            for capture in captures {
                group.addTask {
                    try self.recognizeText(in: capture)
                }
            }

            var results: [OCRResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }

    /// Runs text recognition on a single screen capture.
    private func recognizeText(in capture: ScreenCapture) throws -> OCRResult {
        let handler = VNImageRequestHandler(cgImage: capture.image, options: [:])

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        // Screens are full of code and terminal text; language correction
        // "fixes" literal tokens (launchctl → real words), which both hides
        // real matches and invents text that isn't on screen.
        request.usesLanguageCorrection = false

        try handler.perform([request])

        let imageSize = CGSize(
            width: capture.image.width,
            height: capture.image.height
        )

        guard let observations = request.results else {
            return OCRResult(
                displayID: capture.displayID,
                textBlocks: [],
                imageSize: imageSize,
                screenFrame: capture.frame,
                scaleFactor: capture.scaleFactor
            )
        }

        let textBlocks: [TextBlock] = observations.compactMap { observation in
            let candidates = observation.topCandidates(3)
            guard let candidate = candidates.first else {
                return nil
            }

            // Very-low-confidence reads are garbage ("launchctl" → "Launchetz"):
            // they produce phantom matches for text that isn't on screen while
            // their real text is misread anyway. Drop them. (Dimmed terminal
            // text sits right at ~0.3, so the threshold can't go higher without
            // losing real words — the alternate candidates cover the rest.)
            guard candidate.confidence >= 0.3 else {
                return nil
            }

            let visionRect = observation.boundingBox

            let screenRect = CoordinateTransformer.visionRectToScreenRect(
                visionRect,
                imageSize: imageSize,
                screenFrame: capture.frame,
                scaleFactor: capture.scaleFactor
            )

            return TextBlock(
                text: candidate.string,
                screenRect: screenRect,
                confidence: candidate.confidence,
                recognizedText: candidate,
                candidates: candidates
            )
        }

        return OCRResult(
            displayID: capture.displayID,
            textBlocks: textBlocks,
            imageSize: imageSize,
            screenFrame: capture.frame,
            scaleFactor: capture.scaleFactor
        )
    }
}
