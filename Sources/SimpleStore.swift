// The Swift Programming Language
// https://docs.swift.org/swift-book

import ReAsync

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
    
    public init(provider: Provider, initialValue: Value? = nil) {
        self.provider = provider
        self.sequence.send(provider.read())
        
        if let initialValue = initialValue, value == nil {
            try? write(value: initialValue)
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
}
