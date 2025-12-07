//
//  CaptureStorage.swift
//  Cogitator
//

import Foundation
import SwiftData

@MainActor
final class CaptureStorage {
    private let context: ModelContext

    init(modelContext: ModelContext) {
        self.context = modelContext
    }

    func save(content: String, timestamp: Date) throws {
        let record = CaptureRecord(timestamp: timestamp, content: content)
        context.insert(record)
        try context.save()
    }

    func fetchAll() throws -> [CaptureRecord] {
        let descriptor = FetchDescriptor<CaptureRecord>(
            sortBy: [SortDescriptor(\CaptureRecord.timestamp, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func deleteAll() throws {
        let records = try fetchAll()
        records.forEach { context.delete($0) }
        try context.save()
    }
}
