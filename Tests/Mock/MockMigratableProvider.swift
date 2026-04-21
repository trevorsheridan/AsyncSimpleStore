//
//  MockProvider 2.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/20/26.
//

import Synchronization
@testable import AsyncSimpleStore

final class MockMigratableProvider<Value>: MigratableStorage where Value: Sendable {
    struct SimulatedCachedData {
        var version: Int
        var value: String
    }
    
    private let migration: M
    private let simulatedCachedData: SimulatedCachedData
    private let value: Mutex<Value?>
    
    // TODO: Store version of v1 value with it.
    init(simulatedCachedData: SimulatedCachedData, v2Value: Value? = nil, migration: M) {
        self.simulatedCachedData = simulatedCachedData
        self.value = Mutex(v2Value)
        self.migration = migration
    }
    
    func read() -> Value? {
        // perform migration on read
        value.withLock { v in
            v
        }
    }
    
    func write(value: Value) throws {
        self.value.withLock { v in
            v = value
        }
    }
    
    func destroy() {
        value.withLock { v in
            v = nil
        }
    }
    
    @discardableResult
    func migrate() throws -> Value {
        // Mock reading in an initial value by using the v1Value.
        let value = try migration.migrate(from: simulatedCachedData.value, version: simulatedCachedData.version)
        // It's up to the actual provider implementation to determine how to store the version information.
        // TODO: It the held migration here should hold the current version of the data. Right now it only conveys the version to move from.
        try write(value: value)
        return value
    }
}
