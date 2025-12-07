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
    
    init(timestamp: Date, content: String) {
        self.timestamp = timestamp
        self.content = content
    }
}
