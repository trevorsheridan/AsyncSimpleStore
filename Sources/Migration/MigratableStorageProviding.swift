//
//  MigratableStorageProviding.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/20/26.
//

public protocol MigratableStorageProviding: StorageProviding {
    associatedtype M = MigrationStrategy<Value>
    @discardableResult
    func migrate() throws -> Value?
}
