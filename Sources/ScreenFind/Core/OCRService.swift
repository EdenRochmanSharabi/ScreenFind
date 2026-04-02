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

        try handler.perform([request])

        let imageSize = CGSize(
            width: capture.image.width,
            height: capture.image.height
        )

        guard let observations = request.results else {
            return OCRResult(displayID: capture.displayID, textBlocks: [])
        }

        let textBlocks: [TextBlock] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else {
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
                recognizedText: candidate
            )
        }

        return OCRResult(displayID: capture.displayID, textBlocks: textBlocks)
    }
}
