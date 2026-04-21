//
//  MockDecoderMigratableProvider.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/21/26.
//

import Foundation
import Synchronization
@testable import AsyncSimpleStore

final class MockDecoderMigratableProvider<Value, M>: MigratableStorageProviding where Value: Sendable, M: BaseMigrationStrategy, M.Outgoing == Value {
    struct SimulatedCachedData {
        var version: Int
        var json: String
    }

    private let migration: M
    private let simulatedCachedData: SimulatedCachedData
    private let value: Mutex<Value?>

    init(simulatedCachedData: SimulatedCachedData, migration: M) {
        self.simulatedCachedData = simulatedCachedData
        self.value = Mutex(nil)
        self.migration = migration
    }

    func read() -> Value? {
        value.withLock { $0 }
    }

    func write(value: Value) throws {
        self.value.withLock { $0 = value }
    }

    func destroy() {
        value.withLock { $0 = nil }
    }

    @discardableResult
    func migrate() throws -> Value? {
        let data = Data(simulatedCachedData.json.utf8)
        let decoder = JSONDecoder()
        let value = try migration.migrate(version: simulatedCachedData.version) { type in
            try decodeEnvelope(type: type, from: data, decoder: decoder)
        }
        try write(value: value)
        return value
    }
}

private struct Envelope<V: Decodable>: Decodable {
    var value: V
}

private func decodeEnvelope<V: Decodable>(type: V.Type, from data: Data, decoder: JSONDecoder) throws -> V {
    try decoder.decode(Envelope<V>.self, from: data).value
}
