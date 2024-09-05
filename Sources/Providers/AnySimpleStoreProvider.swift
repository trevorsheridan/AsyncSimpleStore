//
//  AnySimpleStoreProvider.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 9/4/24.
//

import Foundation

final class AnySimpleStoreProvider<Value>: StorageProviding
where Value: Sendable {
    let provider: any StorageProviding
    private let reader: @Sendable () -> Value?
    private let writer: @Sendable (_ value: Value) throws -> Void
    
    init<Provider>(_ provider: Provider)
    where Provider: StorageProviding, Provider.Value == Value {
        self.provider = provider
        self.reader = provider.read
        self.writer = provider.write
    }
    
    func read() -> Value? {
        reader()
    }
    
    func write(value: Value) throws {
        try writer(value)
    }
}
