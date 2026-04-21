//
//  BaseStorageProviding.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/21/26.
//

public protocol StorageProviding: Sendable {
    associatedtype Value
    func read() -> Value?
    func write(value: Value) throws
    func destroy()
}
