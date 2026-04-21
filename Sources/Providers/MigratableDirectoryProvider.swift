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
        
        if let schemaVersion = try? decoder.decode(SchemaVersion.self, from: data).schemaVersion {
            if schemaVersion == migration.schemaVersion {
                return try? decoder.decode(ValueEnvelope<Value>.self, from: data).value
            }

            guard let migrated = try? migration.migrate(schemaVersion: schemaVersion, decoder: { type in
                try decodeValue(type: type, from: data)
            }) else {
                return nil
            }
            
            try? write(value: migrated)

            return migrated
        }

        // One-shot upgrade from the non-versioned DirectoryProvider: if the
        // bytes already decode as the current Value, wrap them in the version
        // envelope on write. Older unwrapped formats cannot be migrated from
        // here — there is no tag to indicate which strategy's Incoming to
        // decode as. This is acceptable because migration starts being used at
        // the moment we switch to MigratableDirectoryProvider; the data on
        // disk at that moment is, by definition, the current Value shape.
        if let value = try? decoder.decode(Value.self, from: data) {
            try? write(value: value)
            return value
        }
        
        return nil
    }

    private func decodeValue<V: Decodable>(type: V.Type, from data: Data) throws -> V {
        try decoder.decode(ValueEnvelope<V>.self, from: data).value
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
