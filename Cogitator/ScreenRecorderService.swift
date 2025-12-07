//
//  ScreenRecorderService.swift
//  Cogitator
//

import Foundation
import OSLog
import CoreGraphics

#if os(macOS)
import AppKit
import ScreenCaptureKit
import CoreImage
import CoreMedia

final class ScreenRecorderService {
    enum RecorderError: Error {
        case permissionDenied
        case displayUnavailable
    }

    private let displayID: CGDirectDisplayID
    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private let captureQueue = DispatchQueue(label: "ScreenRecorderService.capture")
    private let logger = Logger(subsystem: "Cogitator", category: "ScreenRecorder")

    init(displayID: CGDirectDisplayID = CGMainDisplayID()) {
        self.displayID = displayID
    }

    func start(
        fps: Double,
        frameHandler: @escaping @Sendable (CGImage) -> Void
    ) async throws {
        try ensurePermission()
        await stop()

        let sanitizedFPS = max(fps, 0.2)
        let intervalSeconds = max(1.0 / sanitizedFPS, 0.1)

        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw RecorderError.displayUnavailable
        }

        logger.log("Starting capture at \(sanitizedFPS, privacy: .public) fps for display \(display.displayID)")
        
        
        let pixelWidth = Int(CGDisplayPixelsWide(displayID))
        let pixelHeight = Int(CGDisplayPixelsHigh(displayID))

        let configuration = SCStreamConfiguration()
        configuration.width = pixelWidth  // ✅ Explicitly set native pixels
        configuration.height = pixelHeight // ✅ Explicitly set native pixels
        configuration.minimumFrameInterval = CMTime(seconds: intervalSeconds, preferredTimescale: 1_000)
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.capturesAudio = false


        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let output = StreamOutput(
            handler: frameHandler,
            logger: logger,
            screenSize: CGSize(width: display.width, height: display.height)
        )
        output.resetState()
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)

        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: captureQueue)
        try await stream.startCapture()

        self.stream = stream
        self.streamOutput = output
    }

    func stop() async {
        guard let stream else { return }
        logger.log("Stopping capture")
        self.streamOutput?.resetState()
        self.stream = nil
        self.streamOutput = nil
        do {
            try await stream.stopCapture()
        } catch {
            logger.error("Failed to stop screen capture: \(error.localizedDescription, privacy: .public)")
        }
    }

    func isRunning() -> Bool {
        stream != nil
    }

    private func ensurePermission() throws {
        if !CGPreflightScreenCaptureAccess() {
            let granted = CGRequestScreenCaptureAccess()
            guard granted else {
                logger.error("Screen capture permission denied")
                throw RecorderError.permissionDenied
            }
        }
    }
}

private final class StreamOutput: NSObject, SCStreamOutput {
    private let handler: @Sendable (CGImage) -> Void
    private let logger: Logger
    private let ciContext = CIContext()
    private let screenArea: Double
    private let minChangeRatio: Double = 0.02
    private let debugLogging = true
    private let signatureDimension = 16
    private var lastSignature: [UInt8]?

    init(handler: @escaping @Sendable (CGImage) -> Void, logger: Logger, screenSize: CGSize) {
        self.handler = handler
        self.logger = logger
        self.screenArea = Double(max(screenSize.width, 1) * max(screenSize.height, 1))
    }

    func resetState() {
        lastSignature = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen else { return }
        let decision = evaluate(sampleBuffer: sampleBuffer)
        guard decision.shouldProcess else { return }

        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            logger.error("Sample buffer missing image buffer")
            return
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            logger.error("Failed to convert pixel buffer into CGImage")
            return
        }

        if let ratio = decision.metadataRatio {
            if debugLogging {
                logger.debug("Dirty ratio (metadata): \(ratio, privacy: .public)")
            }
        } else if let diffRatio = imageDifferenceRatio(for: cgImage) {
            if debugLogging {
                logger.debug("Fallback diff ratio: \(diffRatio, privacy: .public)")
            }
            if diffRatio < minChangeRatio {
                return
            }
        } else if debugLogging {
            logger.debug("Fallback ratio unavailable; processing frame")
        }

        handler(cgImage)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Screen capture stream stopped with error: \(error.localizedDescription, privacy: .public)")
    }

    private func evaluate(sampleBuffer: CMSampleBuffer) -> FrameDecision {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first else {
            if debugLogging {
                logger.debug("No attachments on sample buffer; processing by default")
            }
            return FrameDecision(shouldProcess: true, metadataRatio: nil)
        }

        if let statusRaw = attachments[.status] as? Int,
           let status = SCFrameStatus(rawValue: statusRaw),
           status == .idle {
            if debugLogging {
                logger.debug("Skipping idle frame")
            }
            return FrameDecision(shouldProcess: false, metadataRatio: nil)
        }

        if screenArea > 0,
           let dirtyValues = attachments[.dirtyRects] as? [NSValue] {
            let dirtyRects = dirtyValues.map { $0.rectValue }
            let totalChangedArea = dirtyRects.reduce(0.0) { $0 + Double($1.width * $1.height) }
            let ratio = totalChangedArea / screenArea
            if debugLogging {
                logger.debug("Dirty ratio (metadata): \(ratio, privacy: .public) with \(dirtyRects.count, privacy: .public) rects")
            }
            if ratio < minChangeRatio {
                return FrameDecision(shouldProcess: false, metadataRatio: ratio)
            }
            return FrameDecision(shouldProcess: true, metadataRatio: ratio)
        }

        return FrameDecision(shouldProcess: true, metadataRatio: nil)
    }

    private func imageDifferenceRatio(for image: CGImage) -> Double? {
        guard let signature = makeSignature(from: image) else { return nil }
        defer { lastSignature = signature }

        guard let previousSignature = lastSignature, previousSignature.count == signature.count else {
            return nil
        }

        var delta: Double = 0
        for (lhs, rhs) in zip(previousSignature, signature) {
            delta += Double(abs(Int(lhs) - Int(rhs)))
        }

        let maxDelta = Double(255 * signature.count)
        return maxDelta > 0 ? delta / maxDelta : nil
    }

    private func makeSignature(from image: CGImage) -> [UInt8]? {
        let width = signatureDimension
        let height = signatureDimension
        let bytesPerRow = width
        var buffer = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var success = false

        buffer.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                return
            }

            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            success = true
        }

        return success ? buffer : nil
    }

    private struct FrameDecision {
        let shouldProcess: Bool
        let metadataRatio: Double?
    }
}
#else
final class ScreenRecorderService {
    func start(
        fps: Double,
        frameHandler: @escaping @Sendable (CGImage) -> Void
    ) async throws {
        fatalError("Screen recording is only supported on macOS.")
    }

    func stop() async {}

    func isRunning() -> Bool { false }
}
#endif
