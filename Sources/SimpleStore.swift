// The Swift Programming Language
// https://docs.swift.org/swift-book

import AsyncReactiveSequences

public final class SimpleStore<Value, Provider>: Sendable
where Value: Codable & Sendable, Provider: StorageProviding, Provider.Value == Value {
    public var value: Value? {
        sequence.value
    }
    
    public var stream: AnyAsyncSequence<Value?> {
        sequence.eraseToAnyAsyncSequence()
    }
    
    private let provider: Provider
    private let sequence = AsyncCurrentValueSequence<Value?>(nil)
    
    public init(provider: Provider, initialValue: Value? = nil, read: Bool = true) where Provider: BasicStorageProviding {
        self.provider = provider
        
        if read {
            self.sequence.send(provider.read())
        }
        
        if let initialValue = initialValue, value == nil {
            try? write(value: initialValue)
        }
    }
    
    public init(provider: Provider, initialValue: Value) where Provider: MigratableStorageProviding {
        self.provider = provider
        
        // Ask the provider to migrate the data!
        let value = provider.migrate()
        
        if value == nil {
            try? write(value: initialValue)
        } else {
            self.sequence.send(provider.read())
        }
    }
    
    @discardableResult
    public func read() -> Value? {
        sequence.send(provider.read())
        return value
    }
    
    public func write(value: Value) throws {
        try provider.write(value: value)
        sequence.send(value)
    }
    
    public func destroy() {
        provider.destroy()
        sequence.send(nil)
    }
}
