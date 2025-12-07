//
//  ScreenRecorderService.swift
//  Cogitator
//

import Foundation
import OSLog
import CoreGraphics

#if os(macOS)
import ScreenCaptureKit
import CoreMedia

final class ScreenRecorderService {
    enum RecorderError: Error {
        case permissionDenied
        case displayUnavailable
        case captureFailed
    }

    private let displayID: CGDirectDisplayID
    private var captureTask: Task<Void, Never>?
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

        logger.log("Starting polling capture at \(sanitizedFPS, privacy: .public) fps for display \(display.displayID)")

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.capturesAudio = false
        configuration.showsCursor = true
        configuration.minimumFrameInterval = CMTime(seconds: intervalSeconds, preferredTimescale: 1_000)

        captureTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let nanoseconds = UInt64(intervalSeconds * 1_000_000_000)

            while !Task.isCancelled {
                do {
                    let image = try await Self.captureImage(filter: filter, configuration: configuration)
                    frameHandler(image)
                } catch {
                    logger.error("Screenshot capture failed: \(error.localizedDescription, privacy: .public)")
                }

                try? await Task.sleep(nanoseconds: nanoseconds)
            }
        }
    }

    func stop() async {
        guard let captureTask else { return }
        logger.log("Stopping capture")
        captureTask.cancel()
        self.captureTask = nil
        _ = await captureTask.result
    }

    func isRunning() -> Bool {
        captureTask != nil
    }

    private static func captureImage(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: RecorderError.captureFailed)
                }
            }
        }
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
