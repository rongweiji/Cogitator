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
    @Published private(set) var llmPrediction: String?
    @Published private(set) var llmError: String?
    @Published private(set) var isGeneratingPrediction = false
    @Published private(set) var lastPredictionDuration: TimeInterval?
    @Published private(set) var lastPredictionRunAt: Date?

    private let screenRecorder = ScreenRecorderService()
    private let ocrService = OCRService()
    private var storage: CaptureStorage?
    private let llmService = LLMPipelineService()
    private let xaiService = XAIService()
    private let embeddingService = EmbeddingService()
    private let autoClearsRecords: Bool
    private let isoFormatter: ISO8601DateFormatter
    private let logger = Logger(subsystem: "Cogitator", category: "CaptureViewModel")
    private var lastCapturedText = ""

    init(autoClearsRecords: Bool = true) {
        self.autoClearsRecords = autoClearsRecords
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
            if autoClearsRecords {
                await clearStoredRecords()
            }
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
                let text = record.content.replacingOccurrences(of: "\n", with: " ")
                let description = record.screenDescription ?? "<none>"
                let embeddingState = record.embeddingData != nil ? "Y" : "N"
                print("\(timestamp) | content: \(text)")
                print("   description: \(description)")
                print("   embedding stored: \(embeddingState)")
            }
        } catch {
            logger.error("Failed to fetch records: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func clearStoredRecords() async {
        guard let storage else { return }
        do {
            try storage.deleteAll()
            await MainActor.run {
                lastCapturedText = ""
            }
        } catch {
            logger.error("Failed to auto-clear records: \(error.localizedDescription, privacy: .public)")
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

    func logRecordStats() {
        guard let storage else { return }
        do {
            let records = try storage.fetchAll()
            let descriptionCount = records.filter { $0.screenDescription?.isEmpty == false }.count
            let embeddingCount = records.filter { $0.embeddingData != nil }.count
            logger.log("Records stored: \(records.count, privacy: .public)")
            logger.log("Records with description: \(descriptionCount, privacy: .public)")
            logger.log("Records with embedding: \(embeddingCount, privacy: .public)")
        } catch {
            logger.error("Failed to fetch stats: \(error.localizedDescription, privacy: .public)")
        }
    }

    func debugNearestEmbeddings() {
        guard let storage else { return }
        do {
            let records = try storage.fetchAll()
            let decoded = records.compactMap { record -> (CaptureRecord, [Double])? in
                guard let data = record.embeddingData,
                      let vector = try? JSONDecoder().decode([Double].self, from: data) else {
                    return nil
                }
                return (record, vector)
            }

            guard decoded.count >= 2 else {
                logger.log("Not enough embeddings to compare.")
                return
            }

            var bestPair: ((CaptureRecord, [Double]), (CaptureRecord, [Double]))?
            var bestScore: Double = -1

            for i in 0..<(decoded.count - 1) {
                for j in (i + 1)..<decoded.count {
                    let sim = cosine(decoded[i].1, decoded[j].1)
                    if sim > bestScore {
                        bestScore = sim
                        bestPair = (decoded[i], decoded[j])
                    }
                }
            }

            guard let pair = bestPair else { return }
            let formatted = String(format: "%.3f", bestScore)
            logger.log("Closest embeddings similarity: \(formatted, privacy: .public)")
            logger.log("Record A description: \(pair.0.0.screenDescription ?? "<none>", privacy: .public)")
            logger.log("Record B description: \(pair.1.0.screenDescription ?? "<none>", privacy: .public)")
        } catch {
            logger.error("Failed to compute embedding similarity: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func cosine(_ a: [Double], _ b: [Double]) -> Double {
        let dot = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
        let magA = sqrt(a.reduce(0) { $0 + $1 * $1 })
        let magB = sqrt(b.reduce(0) { $0 + $1 * $1 })
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }

    func printEmbeddingClusters(threshold: Double = 0.85) {
        guard let storage else { return }
        do {
            let records = try storage.fetchAll()
            let decoded = records.compactMap { record -> (CaptureRecord, [Double])? in
                guard let data = record.embeddingData,
                      let vector = try? JSONDecoder().decode([Double].self, from: data) else {
                    return nil
                }
                return (record, vector)
            }

            guard !decoded.isEmpty else {
                logger.log("No embeddings stored.")
                return
            }

            var clusters: [(records: [CaptureRecord], sum: [Double])] = []

            for (record, vector) in decoded {
                var bestIndex: Int?
                var bestScore: Double = threshold

                for (index, cluster) in clusters.enumerated() {
                    let centroid = cluster.sum.map { $0 / Double(cluster.records.count) }
                    let score = cosine(vector, centroid)
                    if score >= bestScore {
                        bestScore = score
                        bestIndex = index
                    }
                }

                if let idx = bestIndex {
                    var cluster = clusters[idx]
                    cluster.records.append(record)
                    cluster.sum = zip(cluster.sum, vector).map(+)
                    clusters[idx] = cluster
                } else {
                    clusters.append((records: [record], sum: vector))
                }
            }

            logger.log("Formed \(clusters.count, privacy: .public) embedding clusters (threshold \(threshold, privacy: .public)).")
            for (i, cluster) in clusters.enumerated() {
                logger.log("Cluster \(i + 1, privacy: .public) (\(cluster.records.count, privacy: .public) items)")
                cluster.records.sorted(by: { $0.timestamp < $1.timestamp }).forEach { record in
                    let timestamp = isoFormatter.string(from: record.timestamp)
                    let description = record.screenDescription ?? "<none>"
                    logger.log("  \(timestamp, privacy: .public) -> \(description, privacy: .public)")
                }
            }
        } catch {
            logger.error("Failed to cluster embeddings: \(error.localizedDescription, privacy: .public)")
        }
    }

    func requestPrediction() {
        Task { await generatePrediction(usingRecentContext: false) }
    }

    func requestPredictionFromRecentContext() {
        Task { await generatePrediction(usingRecentContext: true) }
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
            var descriptionText: String?
            var embeddingData: Data?

            do {
                let describeStart = Date()
                descriptionText = try await xaiService.describeScreen(image: image)
                let describeDuration = Date().timeIntervalSince(describeStart)
                print("[XAI] Image description in \(String(format: "%.2fs", describeDuration))")
                if let descriptionText,
                   let vector = embeddingService.embed(descriptionText) {
                    embeddingData = try? JSONEncoder().encode(vector)
                }
            } catch {
                logger.error("Image description failed: \(error.localizedDescription, privacy: .public)")
            }

            if let storage {
                try storage.save(content: text, description: descriptionText, embeddingData: embeddingData, timestamp: timestamp)
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

    private func generatePrediction(usingRecentContext: Bool) async {
        guard !isGeneratingPrediction else { return }
        guard let storage else {
            logger.error("Storage not ready for LLM pipeline")
            return
        }
        guard KeychainService().hasKey() else {
            await MainActor.run {
                llmError = "XAI API key missing."
            }
            return
        }

        do {
            let records: [CaptureRecord]
            if usingRecentContext {
                records = try selectRecordsForRecentContext()
            } else {
                records = try storage.fetchAll()
            }
            guard !records.isEmpty else {
                await MainActor.run {
                    llmPrediction = "No OCR data captured yet."
                    llmError = nil
                    lastPredictionDuration = nil
                    lastPredictionRunAt = Date()
                }
                return
            }

            await MainActor.run {
                isGeneratingPrediction = true
                llmError = nil
            }

            do {
                let result = try await llmService.predictNext(records: records)
                await MainActor.run {
                    llmPrediction = result.text
                    lastPredictionDuration = result.duration
                    lastPredictionRunAt = Date()
                }
            } catch {
                await MainActor.run {
                    llmError = error.localizedDescription
                    logger.error("LLM pipeline failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        } catch {
            await MainActor.run {
                llmError = error.localizedDescription
                logger.error("Failed to fetch records for LLM: \(error.localizedDescription, privacy: .public)")
            }
        }

        await MainActor.run {
            isGeneratingPrediction = false
        }
    }

    private func selectRecordsForRecentContext(recentWindowSeconds: TimeInterval = 60, minRecent: Int = 5, maxRecentFallback: Int = 20, maxTotal: Int = 40, similarityThreshold: Double = 0.75) throws -> [CaptureRecord] {
        guard let storage else { return [] }
        let all = try storage.fetchAll().sorted(by: { $0.timestamp < $1.timestamp })
        guard let latestTimestamp = all.last?.timestamp else { return [] }

        let cutoff = latestTimestamp.addingTimeInterval(-recentWindowSeconds)
        var recent = all.filter { $0.timestamp >= cutoff }
        if recent.count < minRecent {
            recent = Array(all.suffix(maxRecentFallback))
        }
        var selectedSet = Set(recent.map { ObjectIdentifier($0) })
        var selected = recent

        let recentVectors: [[Double]] = recent.compactMap { record in
            guard let data = record.embeddingData else { return nil }
            return try? JSONDecoder().decode([Double].self, from: data)
        }

        if !recentVectors.isEmpty {
            var centroid = Array(recentVectors[0]).map { _ in 0.0 }
            for vector in recentVectors {
                centroid = zip(centroid, vector).map(+)
            }
            centroid = centroid.map { $0 / Double(recentVectors.count) }

            let candidates = all.filter { !selectedSet.contains(ObjectIdentifier($0)) }
            let scoredCandidates: [(CaptureRecord, Double)] = candidates.compactMap { record in
                guard let data = record.embeddingData,
                      let vector = try? JSONDecoder().decode([Double].self, from: data) else {
                    return nil
                }
                let score = cosine(vector, centroid)
                return (record, score)
            }.sorted { $0.1 > $1.1 }

            for (record, score) in scoredCandidates {
                if selected.count >= maxTotal { break }
                if score < similarityThreshold { break }
                selected.append(record)
                selectedSet.insert(ObjectIdentifier(record))
            }
        }

        if selected.count > maxTotal {
            selected = Array(selected.suffix(maxTotal))
        }

        return selected.sorted(by: { $0.timestamp < $1.timestamp })
    }
}
