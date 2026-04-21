//
//  MockProvider.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 9/5/24.
//

import Synchronization
@testable import AsyncSimpleStore

final class MockProvider<Value>: BasicStorageProviding where Value: Sendable {
    private let value: Mutex<Value?>
    
    init(_ value: Value? = nil) {
        self.value = Mutex(value)
    }
    
    func read() -> Value? {
        value.withLock { v in
            v
        }
    }
    
    func write(value: Value) throws {
        self.value.withLock { v in
            v = value
        }
    }
    
    func destroy() {
        value.withLock { v in
            v = nil
        }
    }
}
