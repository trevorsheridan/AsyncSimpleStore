//
//  MigrationStrategyTests.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/21/26.
//

import Testing
import Foundation
import Synchronization
import Utilities
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

// A type-changing chain mirroring the real Program -> [Program] migration:
// untagged legacy data is a single Int (the chain root, v1); the current shape
// is [Int] (v2).
private struct IntToArray: MigrationStrategy {
    let schemaVersion: MigrationVersion = 2
    let prior = RootMigrationStrategy<Int>(schemaVersion: 1)

    func migrate(from value: Int) -> [Int] {
        [value]
    }
}

// A single-version (root-only) chain whose current shape is already [Int].
private struct ArrayRoot: BaseMigrationStrategy {
    let schemaVersion: MigrationVersion = 1

    func migrate(from value: [Int]) -> [Int] {
        value
    }
}

// A 3-level chain to exercise the untagged walk-back: String (root, v1) ->
// Int (v2) -> [Int] (v3). Bytes at the root force the walk past two levels.
private struct StringToInt: MigrationStrategy {
    let schemaVersion: MigrationVersion = 2
    let prior = RootMigrationStrategy<String>(schemaVersion: 1)

    func migrate(from value: String) -> Int {
        Int(value) ?? -1
    }
}

private struct StringChainToArray: MigrationStrategy {
    let schemaVersion: MigrationVersion = 3
    let prior = StringToInt()

    func migrate(from value: Int) -> [Int] {
        [value]
    }
}

// The version envelope MigratableDirectoryProvider writes. Declared here so the
// tests can assert the file was (re)tagged after migration.
private struct TaggedEnvelope: Codable {
    var schemaVersion: MigrationVersion
    var value: [Int]
}

@Suite("Migration")
struct MigrationTests {
    @Suite("Pre-Decoded Value Path")
    struct ValuePath {
        struct FromOldestVersion {
            let store: SimpleStore<Int, MockMigratableProvider<Int, String, MockMigrationV2ToV3>>

            init() {
                store = SimpleStore(
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

            init() {
                store = SimpleStore(
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

        // Data tagged at a version that isn't in the chain can't be migrated
        // — the provider returns nil from migrate(), and SimpleStore falls
        // back to the initialValue.
        struct UnknownVersionFallsBackToInitialValue {
            let store: SimpleStore<Int, MockMigratableProvider<Int, String, MockMigrationV2ToV3>>

            init() {
                store = SimpleStore(
                    provider: MockMigratableProvider<Int, String, MockMigrationV2ToV3>(
                        simulatedCachedData: .init(
                            schemaVersion: 99,
                            value: "anything"
                        ),
                        migration: MockMigrationV2ToV3()
                    ),
                    initialValue: 42
                )
            }

            @Test func migration() async throws {
                #expect(store.value == 42)
            }
        }

        // When introducing migration for the first time, the caller can hand
        // the provider a RootMigrationStrategy directly — no chain yet, just a
        // version marker that says "treat data tagged at this version as
        // already current".
        struct RootOnly {
            let store: SimpleStore<String, MockMigratableProvider<String, String, RootMigrationStrategy<String>>>

            init() {
                store = SimpleStore(
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

            init() {
                store = SimpleStore(
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

            init() {
                store = SimpleStore(
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
        // no corresponding level in the chain fails migration, so SimpleStore
        // falls back to the initialValue rather than silently mis-decoding.
        struct UnknownVersionFallsBackToInitialValue {
            let store: SimpleStore<Int, MockDecoderMigratableProvider<Int, MockMigrationV2ToV3>>

            init() {
                store = SimpleStore(
                    provider: MockDecoderMigratableProvider<Int, MockMigrationV2ToV3>(
                        simulatedCachedData: .init(
                            schemaVersion: 99,
                            json: #"{"schemaVersion":99,"value":"anything"}"#
                        ),
                        migration: MockMigrationV2ToV3()
                    ),
                    initialValue: 42
                )
            }

            @Test func migration() async throws {
                #expect(store.value == 42)
            }
        }

        // Exercises BaseMigrationStrategy's leaf default for the decoder
        // path: Root has no chain to walk, so it just decodes the value as
        // Incoming and returns identity.
        struct RootOnly {
            let store: SimpleStore<String, MockDecoderMigratableProvider<String, RootMigrationStrategy<String>>>

            init() {
                store = SimpleStore(
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

    // Drives the real MigratableDirectoryProvider against the filesystem, the
    // only path that exercises untagged (pre-versioning) bytes: detecting they
    // have no tag, walking the chain to decode them, and re-tagging on write.
    @Suite("Untagged Path")
    struct UntaggedPath {
        let directory: ChildDirectory<BaseDirectory>
        let filename = "untagged-migration.cache"

        init() {
            // A unique directory per test instance isolates the shared filename,
            // since Swift Testing runs the suite's tests in parallel.
            directory = ChildDirectory(
                parent: BaseDirectory(directory: .temporary),
                path: "AsyncSimpleStoreUntaggedMigrationTests/\(UUID().uuidString)"
            )
        }

        // A plain DirectoryProvider over the same file, used to seed bare (un-enveloped)
        // legacy bytes and to inspect the raw envelope after migration.
        private func bareProvider<V: Codable>() -> DirectoryProvider<ChildDirectory<BaseDirectory>, V> {
            DirectoryProvider<ChildDirectory<BaseDirectory>, V>(filename: filename, directory: directory)
        }

        @Test func migratesUntaggedLegacyValueToNewShape() async throws {
            // Seed a bare single Int — the legacy, pre-versioning format (the chain root).
            try bareProvider().write(value: 7)

            let provider = MigratableDirectoryProvider<ChildDirectory<BaseDirectory>, [Int], IntToArray>(
                filename: filename,
                directory: directory,
                migration: IntToArray()
            )

            #expect(provider.migrate() == [7])

            // The file is rewritten as a tagged envelope at the current version.
            let envelope: TaggedEnvelope? = bareProvider().read()
            #expect(envelope?.schemaVersion == 2)
            #expect(envelope?.value == [7])
        }

        @Test func adoptsUntaggedCurrentShape() async throws {
            // A root-only chain whose root is already the current shape: untagged
            // bytes in that shape are adopted and tagged.
            try bareProvider().write(value: [1, 2, 3])

            let provider = MigratableDirectoryProvider<ChildDirectory<BaseDirectory>, [Int], ArrayRoot>(
                filename: filename,
                directory: directory,
                migration: ArrayRoot()
            )

            #expect(provider.migrate() == [1, 2, 3])

            let envelope: TaggedEnvelope? = bareProvider().read()
            #expect(envelope?.schemaVersion == 1)
            #expect(envelope?.value == [1, 2, 3])
        }

        @Test func walksBackThroughTheChainForTheOldestUntaggedShape() async throws {
            // Bytes are a bare String — the root shape, two steps below the current
            // [Int]. The walk must fail to decode at v3 and v2, then succeed at the root.
            try bareProvider().write(value: "42")

            let provider = MigratableDirectoryProvider<ChildDirectory<BaseDirectory>, [Int], StringChainToArray>(
                filename: filename,
                directory: directory,
                migration: StringChainToArray()
            )

            #expect(provider.migrate() == [42])

            let envelope: TaggedEnvelope? = bareProvider().read()
            #expect(envelope?.schemaVersion == 3)
            #expect(envelope?.value == [42])
        }

        @Test func untaggedDataNotMatchingRootShapeIsDropped() async throws {
            // The root shape is [Int], but the bytes are a bare Int — they can't be
            // decoded as the root, so there's nothing to migrate and the data is dropped.
            try bareProvider().write(value: 7)

            let provider = MigratableDirectoryProvider<ChildDirectory<BaseDirectory>, [Int], ArrayRoot>(
                filename: filename,
                directory: directory,
                migration: ArrayRoot()
            )

            #expect(provider.migrate() == nil)
        }

        @Test func missingFileReturnsNil() async throws {
            let provider = MigratableDirectoryProvider<ChildDirectory<BaseDirectory>, [Int], IntToArray>(
                filename: filename,
                directory: directory,
                migration: IntToArray()
            )

            #expect(provider.migrate() == nil)
        }
    }
}
