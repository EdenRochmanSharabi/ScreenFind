import AppKit
import ScreenCaptureKit
import Vision
import CoreImage

/// Thread-safe box for the focused-window frame: written on the main actor,
/// read from the motion tracker's sample queue at 30fps.
final class FocusedRegionStore: @unchecked Sendable {
    private let lock = NSLock()
    private var frame: CGRect?

    func get() -> CGRect? {
        lock.lock()
        defer { lock.unlock() }
        return frame
    }

    func set(_ newFrame: CGRect?) {
        lock.lock()
        defer { lock.unlock() }
        frame = newFrame
    }
}

/// Streams low-resolution frames of one display at 30fps and estimates how the
/// focused-window content translated between consecutive frames, so highlight
/// rings can follow scrolling text in real time between OCR passes.
///
/// OCR (slow, ~0.5s) finds the text; this (fast, ~5ms/frame) moves it.
final class MotionTracker: NSObject, SCStreamOutput {

    private let sampleQueue = DispatchQueue(label: "com.edenrochman.screenfind.motion", qos: .userInteractive)
    private var stream: SCStream?
    private var previousImage: CIImage?
    private var displayFrame: CGRect = .zero   // AppKit points, global
    private var bufferScale: CGFloat = 1       // buffer pixels per screen point

    /// Region of interest in global AppKit coordinates (bottom-left origin),
    /// typically the focused window. nil tracks the whole display.
    /// Called on the sample queue — must be cheap and thread-safe.
    var regionProvider: (@Sendable () -> CGRect?)?

    /// Called on the main queue with the estimated content shift in screen
    /// points, in top-left-origin (overlay) coordinates.
    var onShift: ((CGVector) -> Void)?

    /// Starts streaming the given display. Excludes ScreenFind's own windows
    /// so the rings themselves don't pollute the motion estimate.
    func start(displayID: CGDirectDisplayID) async throws {
        stop()

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }),
              let screen = NSScreen.screenForDisplay(displayID) else { return }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownWindows = content.windows.filter { $0.owningApplication?.processID == ownPID }

        displayFrame = screen.frame

        // Quarter resolution is plenty for translation estimation and keeps
        // per-frame registration around ~5ms.
        let downscale: CGFloat = 4
        bufferScale = CGFloat(display.width) / downscale / screen.frame.width

        let config = SCStreamConfiguration()
        config.width = Int(CGFloat(display.width) / downscale)
        config.height = Int(CGFloat(display.height) / downscale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.showsCursor = false
        config.queueDepth = 3

        let stream = SCStream(
            filter: SCContentFilter(display: display, excludingWindows: ownWindows),
            configuration: config,
            delegate: nil
        )
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
        print("[MotionTracker] streaming display \(displayID) at \(config.width)x\(config.height)")
    }

    func stop() {
        guard let stream else { return }
        self.stream = nil
        sampleQueue.async { [weak self] in self?.previousImage = nil }
        Task { try? await stream.stopCapture() }
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }

        var image = CIImage(cvPixelBuffer: pixelBuffer)

        // Crop to the focused window: registration over the whole display is
        // dominated by static regions and would report no motion.
        if let region = regionProvider?() {
            let local = CGRect(
                x: (region.minX - displayFrame.minX) * bufferScale,
                y: (region.minY - displayFrame.minY) * bufferScale,
                width: region.width * bufferScale,
                height: region.height * bufferScale
            ).intersection(image.extent)
            guard !local.isEmpty else { return }
            image = image.cropped(to: local)
        }

        defer { previousImage = image }
        guard let previous = previousImage, previous.extent == image.extent else { return }

        let request = VNTranslationalImageRegistrationRequest(targetedCIImage: image, options: [:])
        let handler = VNImageRequestHandler(ciImage: previous, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first as? VNImageTranslationAlignmentObservation else {
            return
        }

        // alignmentTransform warps the current frame onto the previous one, so
        // the content's own motion is the inverse. Buffer Y is bottom-up while
        // overlay rects are top-down: both inversions fold into these signs.
        let dx = -observation.alignmentTransform.tx / bufferScale
        let dy = observation.alignmentTransform.ty / bufferScale
        guard abs(dx) >= 1 || abs(dy) >= 1 else { return }

        let shift = CGVector(dx: dx, dy: dy)
        DispatchQueue.main.async { [weak self] in
            self?.onShift?(shift)
        }
    }
}
