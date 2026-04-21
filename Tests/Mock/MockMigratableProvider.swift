//
//  MockProvider 2.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/20/26.
//

import Synchronization
@testable import AsyncSimpleStore

final class MockMigratableProvider<Value, V, M>: MigratableStorageProviding where Value: Sendable, V: Sendable, M: BaseMigrationStrategy, M.Outgoing == Value {
    struct SimulatedCachedData {
        var version: Int
        var value: V
    }

    private let migration: M
    private let simulatedCachedData: SimulatedCachedData
    private let value: Mutex<Value?>

    init(simulatedCachedData: SimulatedCachedData, v2Value: Value? = nil, migration: M) {
        self.simulatedCachedData = simulatedCachedData
        self.value = Mutex(v2Value)
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
        let migrated = try migration.migrate(from: simulatedCachedData.value, version: simulatedCachedData.version)
        try write(value: migrated)
        return migrated
    }
}
