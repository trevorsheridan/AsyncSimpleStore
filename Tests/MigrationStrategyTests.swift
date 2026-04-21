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
    let schemaVersion: Int = 2
    let prior = RootMigrationStrategy<String>(schemaVersion: 1)

    func migrate(from: String) -> Int? {
        from == "one" ? 1 : nil
    }
}

struct MockMigrationV2ToV3: MigrationStrategy<Int> {
    let schemaVersion: Int = 3
    let prior = MockMigrationV1ToV2()

    func migrate(from: Int?) -> Int {
        from == 1 ? 100 : 0
    }
}

@Suite("Migration")
struct MigrationTests {
    @Suite("Pre-Decoded Value Path")
    struct ValuePath {
        struct FromOldestVersion {
            let store: SimpleStore<Int, MockMigratableProvider<Int, String, MockMigrationV2ToV3>>

            init() throws {
                store = try SimpleStore(
                    provider: MockMigratableProvider<Int, String, MockMigrationV2ToV3>(
                        simulatedCachedData: .init(
                            schemaVersion: 1,
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

        struct FromIntermediateVersion {
            let store: SimpleStore<Int, MockMigratableProvider<Int, Int?, MockMigrationV2ToV3>>

            init() throws {
                store = try SimpleStore(
                    provider: MockMigratableProvider<Int, Int?, MockMigrationV2ToV3>(
                        simulatedCachedData: .init(
                            schemaVersion: 2,
                            value: 1
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

        // Data tagged at a version that isn't in the chain should fail the
        // migration walk — every level's prior mismatches, and the chain
        // eventually hits Root without a match.
        struct UnknownVersionThrows {
            @Test func migration() async throws {
                #expect(throws: (any Error).self) {
                    try SimpleStore(
                        provider: MockMigratableProvider<Int, String, MockMigrationV2ToV3>(
                            simulatedCachedData: .init(
                                schemaVersion: 99,
                                value: "anything"
                            ),
                            migration: MockMigrationV2ToV3()
                        ),
                        initialValue: 1
                    )
                }
            }
        }

        // When introducing migration for the first time, the caller can hand
        // the provider a RootMigrationStrategy directly — no chain yet, just a
        // version marker that says "treat data tagged at this version as
        // already current".
        struct RootOnly {
            let store: SimpleStore<String, MockMigratableProvider<String, String, RootMigrationStrategy<String>>>

            init() throws {
                store = try SimpleStore(
                    provider: MockMigratableProvider<String, String, RootMigrationStrategy<String>>(
                        simulatedCachedData: .init(
                            schemaVersion: 1,
                            value: "one"
                        ),
                        migration: RootMigrationStrategy<String>(schemaVersion: 1)
                    ),
                    initialValue: "one"
                )
            }

            @Test func migration() async throws {
                #expect(store.value == "one")
            }
        }
    }

    @Suite("Decoder Path")
    struct DecoderPath {
        // Walks the chain back to V1ToV2 (matches version 1), decodes the stored
        // "value" as String, then migrates String -> Int? -> Int.
        struct FromOldestVersion {
            let store: SimpleStore<Int, MockDecoderMigratableProvider<Int, MockMigrationV2ToV3>>

            init() throws {
                store = try SimpleStore(
                    provider: MockDecoderMigratableProvider<Int, MockMigrationV2ToV3>(
                        simulatedCachedData: .init(
                            schemaVersion: 1,
                            json: #"{"schemaVersion":1,"value":"one"}"#
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

        // Version matches the top strategy's own version, so decode stops at
        // V2ToV3, decodes "value" as Int? (its Incoming), then applies only the
        // top migration.
        struct FromIntermediateVersion {
            let store: SimpleStore<Int, MockDecoderMigratableProvider<Int, MockMigrationV2ToV3>>

            init() throws {
                store = try SimpleStore(
                    provider: MockDecoderMigratableProvider<Int, MockMigrationV2ToV3>(
                        simulatedCachedData: .init(
                            schemaVersion: 2,
                            json: #"{"schemaVersion":2,"value":1}"#
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

        // Same invariant as the value-path counterpart: a version tag with
        // no corresponding level in the chain throws rather than silently
        // decoding at the wrong level.
        struct UnknownVersionThrows {
            @Test func migration() async throws {
                #expect(throws: (any Error).self) {
                    try SimpleStore(
                        provider: MockDecoderMigratableProvider<Int, MockMigrationV2ToV3>(
                            simulatedCachedData: .init(
                                schemaVersion: 99,
                                json: #"{"schemaVersion":99,"value":"anything"}"#
                            ),
                            migration: MockMigrationV2ToV3()
                        ),
                        initialValue: 1
                    )
                }
            }
        }

        // Exercises BaseMigrationStrategy's leaf default for the decoder
        // path: Root has no chain to walk, so it just decodes the value as
        // Incoming and returns identity.
        struct RootOnly {
            let store: SimpleStore<String, MockDecoderMigratableProvider<String, RootMigrationStrategy<String>>>

            init() throws {
                store = try SimpleStore(
                    provider: MockDecoderMigratableProvider<String, RootMigrationStrategy<String>>(
                        simulatedCachedData: .init(
                            schemaVersion: 1,
                            json: #"{"schemaVersion":1,"value":"one"}"#
                        ),
                        migration: RootMigrationStrategy<String>(schemaVersion: 1)
                    ),
                    initialValue: "one"
                )
            }

            @Test func migration() async throws {
                #expect(store.value == "one")
            }
        }
    }
}
