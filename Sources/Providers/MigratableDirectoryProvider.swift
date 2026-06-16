//
//  MigratableDirectoryProvider.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/21/26.
//

import Foundation
import Utilities

fileprivate struct ValueEnvelope<V> {
    var schemaVersion: MigrationVersion
    var value: V
}

extension ValueEnvelope: Decodable where V: Decodable {}
extension ValueEnvelope: Encodable where V: Encodable {}

public final class MigratableDirectoryProvider<D, Value, M>: MigratableStorageProviding where D: Directory & Sendable, Value: Codable, M: BaseMigrationStrategy, M.Outgoing == Value {
    private struct SchemaVersion: Codable {
        var schemaVersion: MigrationVersion
    }

    private let directoryProvider: DirectoryProvider<D, ValueEnvelope<Value>>
    private let migration: M
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        filename: String,
        directory: D,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        fileAttributes: [FileAttributeKey: Any] = [:],
        migration: M
    ) {
        self.directoryProvider = .init(
            filename: filename,
            directory: directory,
            encoder: encoder,
            decoder: decoder,
            fileAttributes: fileAttributes
        )
        self.encoder = encoder
        self.decoder = decoder
        self.migration = migration
    }
    
    public func migrate() -> Value? {
        guard let data: Data = directoryProvider.read() else {
            return nil
        }

        guard let value = decodeMigrating(from: data) else {
            return nil
        }

        try? write(value: value)

        return value
    }

    // Decodes the stored data, migrating to the current version when needed.
    // Tagged data is placed by its version; untagged data is walked through the
    // chain by shape.
    private func decodeMigrating(from data: Data) -> Value? {
        guard let schemaVersion = try? decoder.decode(SchemaVersion.self, from: data).schemaVersion else {
            // Untagged: no version to place it, so the chain decodes by shape.
            return try? migration.migrateUntagged(decoder: { try self.decodeBare(type: $0, from: data) })
        }

        // Already current: decode straight to Value, since no chain step's prior
        // matches the top version.
        if schemaVersion == migration.schemaVersion {
            return try? decoder.decode(ValueEnvelope<Value>.self, from: data).value
        }

        return try? migration.migrate(schemaVersion: schemaVersion, decoder: { try self.decodeValue(type: $0, from: data) })
    }

    private func decodeValue<V: Decodable>(type: V.Type, from data: Data) throws -> V {
        try decoder.decode(ValueEnvelope<V>.self, from: data).value
    }

    // Decodes a bare value, as opposed to decodeValue's enveloped form. Used
    // for untagged legacy bytes, which predate the version envelope.
    private func decodeBare<V: Decodable>(type: V.Type, from data: Data) throws -> V {
        try decoder.decode(V.self, from: data)
    }
    
    public func read() -> Value? {
        directoryProvider.read()?.value
    }
    
    public func write(value: Value) throws {
        try directoryProvider.write(
            value: .init(
                schemaVersion: migration.schemaVersion,
                value: value
            )
        )
    }
    
    public func destroy() {
        directoryProvider.destroy()
    }
}
