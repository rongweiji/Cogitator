//
//  XAIService.swift
//  Cogitator
//

import Foundation

struct XAIApiMessage: Codable {
    let role: String
    let content: String
}

struct XAIApiRequest: Codable {
    let messages: [XAIApiMessage]
    let model: String
    let stream: Bool
    let temperature: Double
}

struct XAIApiChoice: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }
    let message: Message
}

struct XAIApiResponse: Codable {
    let choices: [XAIApiChoice]
}

final class XAIService {
    private let baseURL = URL(string: "https://api.x.ai/v1/chat/completions")!
    private let keychain = KeychainService()

    func sendChat(
        prompt: String,
        model: String = "grok-4-1-fast-non-reasoning",
        stream: Bool = false,
        temperature: Double = 0.7
    ) async throws -> String {
        let messages = [XAIApiMessage(role: "user", content: prompt)]
        return try await sendChat(messages: messages, model: model, stream: stream, temperature: temperature)
    }

    func sendChat(
        messages: [XAIApiMessage],
        model: String = "grok-4-1-fast-non-reasoning",
        stream: Bool = false,
        temperature: Double = 0.7
    ) async throws -> String {
        let start = Date()
        let apiKey = try keychain.fetchKey()

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = XAIApiRequest(
            messages: messages,
            model: model,
            stream: stream,
            temperature: temperature
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw NSError(domain: "XAIService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "API error: \(body)"])
        }

        let decoded = try JSONDecoder().decode(XAIApiResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw NSError(domain: "XAIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Empty response"])
        }
        let elapsed = Date().timeIntervalSince(start)
        print("[XAI] Response in \(String(format: "%.2fs", elapsed)): \(content.prefix(120))")
        return content
    }

    func sanityCheck() async -> Result<String, Error> {
        do {
            let response = try await sendChat(
                prompt: "Reply with the word 'ACK' if you received this message.",
                temperature: 0.0
            )
            return .success(response)
        } catch {
            return .failure(error)
        }
    }
}
