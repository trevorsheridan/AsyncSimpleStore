//
//  MigratableDirectoryProvider.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/21/26.
//

import Foundation
import Utilities

public final class MigratableDirectoryProvider<D, Value>: MigratableStorageProviding where D: Directory & Sendable, Value: Codable {
    private struct MigrationContainer: Codable {
        var version: MigrationVersion
        var value: Value
    }
    
    private let directoryProvider: DirectoryProvider<D, MigrationContainer>
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
        // TODO: We need to just ensure we have a MigrationContainer, but the actual data inside of it has to be flexible. it cant be Value.
        if let value = directoryProvider.read() {
            // data is in the correct format for migration.
            // TODO: I think "from" should take "data" since we need the migration to define the cast with the json decoder.
            let migrated = try migration.migrate(from: value, version: value.version)
            try write(value: migrated)
            return migrated
        }
        
        if let value: Value = directoryProvider.read(decoder: decoder) {
            // The data is correct, just need to wrap it in a container and set the
            // version number to that of the current migration
            try write(value: value)
        }
        
        // The data was unable to be migrated or is not able to be read as the expected value.
        return nil
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
