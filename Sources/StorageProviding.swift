//
//  Provider.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 9/4/24.
//

public protocol StorageProviding: Sendable {
    associatedtype Value
    func read() -> Value?
    func write(value: Value) throws
    func destroy()
}
