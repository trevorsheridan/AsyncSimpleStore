//
//  AnySimpleStoreProvider.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 9/4/24.
//

import Foundation

public final class AnySimpleStoreProvider<Value>: StorageProviding
where Value: Sendable {
    public let provider: any StorageProviding
    private let reader: @Sendable () -> Value?
    private let writer: @Sendable (_ value: Value) throws -> Void
    
    public init<Provider>(_ provider: Provider)
    where Provider: StorageProviding, Provider.Value == Value {
        self.provider = provider
        self.reader = provider.read
        self.writer = provider.write
    }
    
    public func read() -> Value? {
        reader()
    }
    
    public func write(value: Value) throws {
        try writer(value)
    }
}
