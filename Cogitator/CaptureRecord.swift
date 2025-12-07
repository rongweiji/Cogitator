//
//  Item.swift
//  Cogitator
//
//  Created by Rongwei Ji on 12/6/25.
//

import Foundation
import SwiftData

@Model
final class CaptureRecord {
    var timestamp: Date
    var content: String
    var screenDescription: String?
    var embeddingData: Data?
    
    init(timestamp: Date, content: String, screenDescription: String? = nil, embeddingData: Data? = nil) {
        self.timestamp = timestamp
        self.content = content
        self.screenDescription = screenDescription
        self.embeddingData = embeddingData
    }
}
