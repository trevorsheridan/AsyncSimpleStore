//
//  AnyBaseMigrationStrategy.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/21/26.
//

import Foundation

/// A type-erased ``BaseMigrationStrategy`` whose `Outgoing` is `Value`.
///
/// Use this to hide the specific migration chain behind a uniform type — for
/// instance, as the `M` of a type-erased provider. The box delegates the
/// dispatch methods (`migrate(from:schemaVersion:)` and
/// `migrate(schemaVersion:decoder:)`) to the underlying strategy. Its own
/// `Incoming` collapses to `Value`, and the primitive
/// `migrate(from: Value) -> Value` is identity — callers migrating old data
/// must go through the dispatch methods.
public struct AnyBaseMigrationStrategy<Value>: BaseMigrationStrategy where Value: Sendable {
    public typealias Incoming = Value
    public typealias Outgoing = Value

    public let schemaVersion: MigrationVersion
    private let valueMigrator: @Sendable (Any, MigrationVersion) throws -> Value
    private let decoderMigrator: @Sendable (MigrationVersion, (any Decodable.Type) throws -> Any) throws -> Value

    public init<Strategy>(_ strategy: Strategy)
    where Strategy: BaseMigrationStrategy, Strategy.Outgoing == Value {
        self.schemaVersion = strategy.schemaVersion
        self.valueMigrator = { try strategy.migrate(from: $0, schemaVersion: $1) }
        self.decoderMigrator = { try strategy.migrate(schemaVersion: $0, decoder: $1) }
    }

    public func migrate(from: Value) -> Value {
        from
    }

    public func migrate(from: Any, schemaVersion: MigrationVersion) throws -> Value {
        try valueMigrator(from, schemaVersion)
    }

    public func migrate(schemaVersion: MigrationVersion, decoder: (any Decodable.Type) throws -> Any) throws -> Value {
        try decoderMigrator(schemaVersion, decoder)
    }
}
