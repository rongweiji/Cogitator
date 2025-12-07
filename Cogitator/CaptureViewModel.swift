//
//  CaptureViewModel.swift
//  Cogitator
//

import Foundation
import Combine
import SwiftData
import OSLog
import CoreGraphics

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published private(set) var isRecording = false
    @Published var fps: Double = 1.0

    private let screenRecorder = ScreenRecorderService()
    private let ocrService = OCRService()
    private var storage: CaptureStorage?
    private let isoFormatter: ISO8601DateFormatter
    private let logger = Logger(subsystem: "Cogitator", category: "CaptureViewModel")
    private var lastCapturedText = ""

    init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter = formatter
    }

    func configure(with modelContext: ModelContext) {
        if storage == nil {
            storage = CaptureStorage(modelContext: modelContext)
        }
    }

    func start() {
        guard !isRecording else { return }
        guard storage != nil else {
            logger.error("Storage not ready")
            return
        }

        lastCapturedText = ""
        Task { [weak self] in
            await self?.startRecorder()
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        Task {
            await screenRecorder.stop()
        }
    }

    func dumpRecords() {
        guard let storage else { return }
        do {
            let records = try storage.fetchAll()
            if records.isEmpty {
                logger.log("No records stored")
            } else {
                logger.log("Dumping \(records.count, privacy: .public) records")
            }
            records.forEach { record in
                let timestamp = isoFormatter.string(from: record.timestamp)
                let flattened = record.content.replacingOccurrences(of: "\n", with: " ")
                print("\(timestamp) | \(flattened)")
            }
        } catch {
            logger.error("Failed to fetch records: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clearRecords() {
        guard let storage else { return }
        do {
            try storage.deleteAll()
            logger.log("Cleared stored records")
            lastCapturedText = ""
        } catch {
            logger.error("Failed to clear records: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func processFrame(_ image: CGImage) async {
        let start = Date()
        do {
            let text = try await ocrService.recognizeText(in: image)
            let duration = Date().timeIntervalSince(start)
            let timestamp = Date()
            let formattedDuration = String(format: "%.3f", duration)
            print("[\(isoFormatter.string(from: timestamp))] OCR duration: \(formattedDuration)s")

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return
            }

            guard trimmed != lastCapturedText else {
                return
            }

            lastCapturedText = trimmed
            if let storage {
                try storage.save(content: text, timestamp: timestamp)
            }
        } catch {
            logger.error("OCR failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startRecorder() async {
        let currentFPS = fps
        do {
            try await screenRecorder.start(fps: currentFPS) { [weak self] image in
                Task { [weak self] in
                    await self?.processFrame(image)
                }
            }
            isRecording = true
        } catch {
            logger.error("Failed to start recorder: \(error.localizedDescription, privacy: .public)")
        }
    }
}
