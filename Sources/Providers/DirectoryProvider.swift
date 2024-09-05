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
    
    public init(filename: String, directory: D, encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
        self.filename = filename
        self.directory = directory
        self.encoder = encoder
        self.decoder = decoder
    }
    
    public func read() -> Value? {
        guard let url = try? url(), FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(Value.self, from: data)
        } catch {
            // logger.log("unable to read data at url: \(url) reason: \(error)")
            return nil
        }
    }
    
    public func write(value: Value) throws {
        guard let url = try? url(createOptions: .createDirectory) else {
            return
        }
        
        do {
            let data = try encoder.encode(value)
            try data.write(to: url)
        } catch {
            // logger.log("unable to write data at url: \(url) reason: \(error)")
            throw error
        }
        
        // logger.log("wrote data to url: \(url)")
    }
    
    private func url(createOptions: DirectoryCreateOptions = []) throws -> URL {
        let url = try DirectorySupport.url(to: directory, createOptions: createOptions)
        return url.appendingPathComponent(filename)
    }
}
