import Testing
import Synchronization
@testable import AsyncSimpleStore

final class TestProvider<Value>: StorageProviding where Value: Sendable {
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
}

struct Tests {
    let store: SimpleStore<Int, TestProvider> = SimpleStore(provider: TestProvider(),  initialValue: 1)
    
    @Test func initialValue() async throws {
        #expect(await store.value == 1)
    }
    
    @Test func write() async throws {
        try store.write(value: 2)
        #expect(await store.value == 2)
    }
    
    @Test func testSequence() async throws {
        Task {
            for try await value in store.stream {
                print("got value:", value)
            }
        }
    }
}
