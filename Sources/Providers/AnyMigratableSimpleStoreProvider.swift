//
//  AnyMigratableSimpleStoreProvider.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/21/26.
//

import Foundation

public final class AnyMigratableSimpleStoreProvider<Value>: MigratableStorageProviding
where Value: Sendable {
    public typealias M = AnyBaseMigrationStrategy<Value>

    public let provider: any MigratableStorageProviding
    private let reader: @Sendable () -> Value?
    private let writer: @Sendable (_ value: Value) throws -> Void
    private let destroyer: @Sendable () -> Void
    private let migrator: @Sendable () throws -> Value?

    public init<Provider>(_ provider: Provider)
    where Provider: MigratableStorageProviding, Provider.Value == Value {
        self.provider = provider
        self.reader = provider.read
        self.writer = provider.write
        self.destroyer = provider.destroy
        self.migrator = provider.migrate
    }

    public func read() -> Value? {
        reader()
    }

    public func write(value: Value) throws {
        try writer(value)
    }

    public func destroy() {
        destroyer()
    }

    @discardableResult
    public func migrate() throws -> Value? {
        try migrator()
    }
}
