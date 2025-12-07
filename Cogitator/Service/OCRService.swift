//
//  OCRService.swift
//  Cogitator
//

import Foundation
import CoreGraphics
import Vision

struct OCRService {
    func recognizeText(in image: CGImage) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let strings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            return strings.joined(separator: "\n")
        }.value
    }
}
