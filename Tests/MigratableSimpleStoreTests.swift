//
//  MockMigrationV1.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/20/26.
//

import Testing
import Synchronization
@testable import AsyncSimpleStore

struct MockMigrationV1ToV2: MigrationStrategy<Int?> {
    let version: Int = 1
    let prior = RootMigrationStrategy<String>()
    
    func migrate(from: String) -> Int? {
        from == "one" ? 1 : nil
    }
}

struct MockMigrationV2ToV3: MigrationStrategy<Int> {
    let version: Int = 2
    let prior = MockMigrationV1ToV2()
    
    func migrate(from: Int?) -> Int {
        from == 1 ? 100 : 0
    }
}

struct MigratableSimpleStoreTests {
    let store: SimpleStore<Int, MockMigratableProvider<Int>>
    
    init() throws {
        store = try SimpleStore(
            provider: MockMigratableProvider<Int>(
                simulatedCachedData: .init(
                    version: 1,
                    value: "one"
                ),
                migration: MockMigrationV2ToV3()
            ),
            initialValue: 1
        )
    }
    
    @Test func migration() async throws {
        #expect(store.value == 100)
    }
}
