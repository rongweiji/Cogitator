//
//  EmbeddingService.swift
//  Cogitator
//

import Foundation
import NaturalLanguage

struct EmbeddingService {
    func embed(_ text: String) -> [Double]? {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            return nil
        }
        return embedding.vector(for: text.lowercased())
    }
}
