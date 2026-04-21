//
//  MigrationStrategy.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/20/26.
//

import Foundation

/// A single node in a migration chain.
///
/// A strategy transforms an `Incoming` value into an `Outgoing` value. The
/// `version` it exposes is the version of data this step **produces** — i.e.
/// after `migrate(from:)` returns, the resulting value is tagged with
/// `self.version`. A data tag matches a given strategy when the strategy's
/// *prior* produced that version (see ``MigrationStrategy``).
///
/// Concrete strategies almost always conform via ``MigrationStrategy`` (which
/// adds a `prior`). A bare `BaseMigrationStrategy` is a leaf: it has no prior
/// to walk back to, so the only version it can handle is its own. The
/// canonical leaf is ``RootMigrationStrategy``.
public protocol BaseMigrationStrategy<Outgoing>: Sendable {
    associatedtype Incoming: Sendable
    associatedtype Outgoing: Sendable

    /// The version of data this strategy produces. After `migrate(from:)`
    /// runs, storage tagged with this version is in `Outgoing` form.
    var version: MigrationVersion { get }

    /// The primitive migration step. Conformers implement this; it's the
    /// business logic for a single version bump.
    func migrate(from: Incoming) -> Outgoing

    /// Dispatch entry point for callers that already have a decoded value
    /// tagged at `version`. Walks back through the chain (for
    /// ``MigrationStrategy`` conformers) or handles it in place (for leaves).
    ///
    /// This is a protocol requirement so dispatch goes through the witness
    /// table — ``MigrationStrategy``'s extension supplies a chain-walk
    /// override, and leaves fall through to the trivial default below.
    func migrate(from: Any, version: MigrationVersion) throws -> Outgoing

    /// Dispatch entry point for callers that have raw bytes tagged at
    /// `version`. The chain picks the correct `Decodable` type for that
    /// version and asks the closure to produce the decoded value.
    ///
    /// Like the entry above, this is a protocol requirement so
    /// ``MigrationStrategy`` can override with a chain-walk decoder and
    /// leaves get the trivial default.
    func migrate(version: MigrationVersion, decoder: (any Decodable.Type) throws -> Any) throws -> Outgoing
}

/// A migration step that has a `prior`, forming a chain.
///
/// The chain invariant: `prior.Outgoing == Self.Incoming`. So a strategy
/// consumes data at its prior's version and produces data at its own. The
/// bottom of the chain is a ``RootMigrationStrategy`` (a leaf
/// ``BaseMigrationStrategy``) whose `version` is the initial data version.
///
/// Example: `V3 <- V2ToV3(version: 3) <- V1ToV2(version: 2) <- Root<V1>(version: 1)`.
public protocol MigrationStrategy<Outgoing>: BaseMigrationStrategy {
    associatedtype S: BaseMigrationStrategy<Incoming>
    var prior: S { get }
}

extension BaseMigrationStrategy {
    /// Generic adapter: cast an arbitrary input to `Incoming` and migrate.
    /// Throws if the runtime type doesn't match.
    func migrate<F>(from: F) throws -> Outgoing {
        guard let from = from as? Incoming else {
            throw "Unable to migrate because input type (\(type(of: from))) does not match expected incoming type (\(Incoming.self)) in MigrationStrategy."
        }
        return migrate(from: from)
    }

    // MARK: - Leaf defaults
    //
    // These are the witnesses for non-chained strategies (Root). They trust
    // that the caller has the right shape already — there's no prior to walk
    // back to. `MigrationStrategy`'s extension below overrides both for
    // conformers that do have a chain.

    public func migrate(from: Any, version: MigrationVersion) throws -> Outgoing {
        try migrate(from: from)
    }

    public func migrate(version: MigrationVersion, decoder: (any Decodable.Type) throws -> Any) throws -> Outgoing {
        guard let incomingType = Incoming.self as? any Decodable.Type else {
            throw "Incoming type \(Incoming.self) must conform to Decodable to migrate from raw data."
        }
        return try migrate(from: try decoder(incomingType))
    }
}

extension MigrationStrategy {
    // Chain walk for pre-decoded values. The match condition —
    // `prior.version == version` — means "my prior produced this version, so
    // the data is in my Incoming form; apply me." Everything above this
    // level then applies in sequence as the recursion unwinds.
    public func migrate(from: Any, version: MigrationVersion) throws -> Outgoing {
        if prior.version == version {
            return try migrate(from: from)
        }

        guard let prior = prior as? any MigrationStrategy<Incoming> else {
            throw "No migration for version \(version)"
        }

        let incoming = try prior.migrate(from: from, version: version)
        return migrate(from: incoming)
    }

    // Chain walk for raw bytes. Split into two passes: first find the
    // matching level and decode there, then migrate forward via the
    // `migrate(from:version:)` chain above.
    public func migrate(version: MigrationVersion, decoder: (any Decodable.Type) throws -> Any) throws -> Outgoing {
        let decoded = try decode(version: version, decoder: decoder)
        return try migrate(from: decoded, version: version)
    }

    // Walks priors looking for the level whose input matches `version`, then
    // decodes the bytes as that level's `Incoming`. Returns type-erased
    // because each level of the chain has a different Incoming.
    private func decode(version: MigrationVersion, decoder: (any Decodable.Type) throws -> Any) throws -> Any {
        if prior.version == version {
            return try decodeAsIncoming(decoder)
        }

        guard let prior = prior as? any MigrationStrategy<Incoming> else {
            throw "No migration for version \(version)"
        }

        return try prior.decode(version: version, decoder: decoder)
    }

    private func decodeAsIncoming(_ decoder: (any Decodable.Type) throws -> Any) throws -> Any {
        guard let incomingType = Incoming.self as? any Decodable.Type else {
            throw "Incoming type \(Incoming.self) must conform to Decodable to migrate from raw data."
        }
        return try decoder(incomingType)
    }
}
