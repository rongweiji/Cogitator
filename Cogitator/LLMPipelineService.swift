//
//  LLMPipelineService.swift
//  Cogitator
//

import Foundation

struct LLMPredictionResult {
    let text: String
    let duration: TimeInterval
}

final class LLMPipelineService {
    private let xaiService = XAIService()
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func predictNext(records: [CaptureRecord]) async throws -> LLMPredictionResult {
        let start = Date()
        let log = buildLog(from: records)
        let prompt = PromptLibrary.predictorPrompt(from: log)
        let response = try await xaiService.sendChat(prompt: prompt, temperature: 0.2)
        let duration = Date().timeIntervalSince(start)
        print("[LLM] Prediction generated in \(String(format: "%.2fs", duration))")
        return LLMPredictionResult(text: response, duration: duration)
    }

    private func buildLog(from records: [CaptureRecord]) -> String {
        records.map { record in
            "[\(isoFormatter.string(from: record.timestamp))] \(record.content.replacingOccurrences(of: "\n", with: " "))"
        }
        .joined(separator: "\n")
    }
}
