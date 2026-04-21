//
//  DirectoryProvider.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 9/5/24.
//

import Foundation
import Utilities

public final class DirectoryProvider<D, Value>: StorageProviding where D: Directory & Sendable, Value: Codable {
    public let filename: String
    public let directory: D
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    nonisolated(unsafe) private let fileAttributes: [FileAttributeKey: Any]

    public init(
        filename: String,
        directory: D,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        fileAttributes: [FileAttributeKey: Any] = [:]
    ) {
        self.filename = filename
        self.directory = directory
        self.encoder = encoder
        self.decoder = decoder
        self.fileAttributes = fileAttributes
    }
    
    public func read() -> Value? {
        read(decoder: decoder)
    }
    
    internal func read<LocalValue: Codable>(decoder: JSONDecoder) -> LocalValue? {
        guard let url = try? url(), FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(LocalValue.self, from: data)
        } catch {
            return nil
        }
    }
    
    public func write(value: Value) throws {
        try write(value: value, encoder: encoder)
    }
    
    internal func write<LocalValue: Codable>(value: LocalValue, encoder: JSONEncoder) throws {
        guard let url = try? url(createOptions: .createDirectory) else {
            return
        }
        
        do {
            let data = try encoder.encode(value)
            try data.write(to: url)
            
            if !fileAttributes.isEmpty {
                try? FileManager.default.setAttributes(fileAttributes, ofItemAtPath: url.path)
            }
        } catch {
            throw error
        }
    }
    
    public func destroy() {
        guard let url = try? url(), FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // noop
        }
    }
    
    private func url(createOptions: DirectoryCreateOptions = []) throws -> URL {
        let url = try DirectorySupport.url(to: directory, createOptions: createOptions)
        return url.appendingPathComponent(filename)
    }
}
