//
//  MigrationStrategyTests.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/21/26.
//

import Testing
import Foundation
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

// Walks the chain back to V1ToV2 (matches version 1), decodes the stored
// "value" as String, then migrates String -> Int? -> Int.
struct MigrationStrategyFromOldestVersionTests {
    let store: SimpleStore<Int, MockDecoderMigratableProvider<Int>>

    init() throws {
        store = try SimpleStore(
            provider: MockDecoderMigratableProvider<Int>(
                simulatedCachedData: .init(
                    version: 1,
                    json: #"{"version":1,"value":"one"}"#
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

// Version matches the top strategy's own version, so decode stops at V2ToV3,
// decodes "value" as Int? (its Incoming), then applies only the top migration.
struct MigrationStrategyFromIntermediateVersionTests {
    let store: SimpleStore<Int, MockDecoderMigratableProvider<Int>>

    init() throws {
        store = try SimpleStore(
            provider: MockDecoderMigratableProvider<Int>(
                simulatedCachedData: .init(
                    version: 2,
                    json: #"{"version":2,"value":1}"#
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

// Input whose decoded value doesn't survive the migration logic should still
// flow through without throwing — V1ToV2 maps any non-"one" String to nil,
// and V2ToV3 maps nil to 0.
struct MigrationStrategyNonMatchingValueTests {
    let store: SimpleStore<Int, MockDecoderMigratableProvider<Int>>

    init() throws {
        store = try SimpleStore(
            provider: MockDecoderMigratableProvider<Int>(
                simulatedCachedData: .init(
                    version: 1,
                    json: #"{"version":1,"value":"two"}"#
                ),
                migration: MockMigrationV2ToV3()
            ),
            initialValue: 1
        )
    }

    @Test func migration() async throws {
        #expect(store.value == 0)
    }
}
