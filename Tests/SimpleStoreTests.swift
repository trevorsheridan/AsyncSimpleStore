import Testing
import Synchronization
@testable import AsyncSimpleStore

struct SimpleStoreTests {
    let store = SimpleStore(provider: MockProvider(),  initialValue: 1)
    
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
