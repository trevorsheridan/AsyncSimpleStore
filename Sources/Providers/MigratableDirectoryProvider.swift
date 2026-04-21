//
//  MigratableDirectoryProvider.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/21/26.
//

import Foundation
import Utilities

fileprivate struct VersionedValue<V> {
    var version: MigrationVersion
    var value: V
}

extension VersionedValue: Decodable where V: Decodable {}
extension VersionedValue: Encodable where V: Encodable {}

public final class MigratableDirectoryProvider<D, Value>: MigratableStorageProviding where D: Directory & Sendable, Value: Codable {
    private struct Version: Codable {
        var version: MigrationVersion
    }

    private let directoryProvider: DirectoryProvider<D, VersionedValue<Value>>
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
    
    public func migrate() throws -> Value? {
        guard let data: Data = directoryProvider.read() else {
            return nil
        }

        if let version = try? decoder.decode(Version.self, from: data).version {
            if version == migration.version {
                return try decoder.decode(VersionedValue<Value>.self, from: data).value
            }

            let migrated = try migration.migrate(version: version) { type in
                try decodeValue(type: type, from: data)
            }
            
            try write(value: migrated)
            return migrated
        }

        if let value = try? decoder.decode(Value.self, from: data) {
            try write(value: value)
            return value
        }

        return nil
    }

    private func decodeValue<V: Decodable>(type: V.Type, from data: Data) throws -> V {
        try decoder.decode(VersionedValue<V>.self, from: data).value
    }
    
    public func read() -> Value? {
        directoryProvider.read()?.value
    }
    
    public func write(value: Value) throws {
        try directoryProvider.write(
            value: .init(
                version: migration.version,
                value: value
            )
        )
    }
    
    public func destroy() {
        directoryProvider.destroy()
    }
}
