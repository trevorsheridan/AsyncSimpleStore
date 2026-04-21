//
//  MigratableStorageProviding.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/20/26.
//

public protocol MigratableStorageProviding: BaseStorageProviding {
    associatedtype M: BaseMigrationStrategy where M.Outgoing == Value
    @discardableResult
    func migrate() -> Value?
}
