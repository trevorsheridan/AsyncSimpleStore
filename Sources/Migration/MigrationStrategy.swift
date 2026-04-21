//
//  MigrationStrategy.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/20/26.
//

public protocol BaseMigrationStrategy<Outgoing>: Sendable {
    associatedtype Incoming: Sendable
    associatedtype Outgoing: Sendable
    func migrate(from: Incoming) -> Outgoing
}

public protocol MigrationStrategy<Outgoing>: BaseMigrationStrategy {
    associatedtype S: BaseMigrationStrategy<Incoming>
    var version: MigrationVersion { get }
    var prior: S { get }
}

extension MigrationStrategy {
    func migrate<F>(from: F, version: Int) throws -> Outgoing {
        if version == self.version {
            return try migrate(from: from)
        }
        
        let incoming = switch prior {
        case let prior as any MigrationStrategy<Incoming>:
            try prior.migrate(from: from, version: version)
        case let prior as RootMigrationStrategy<Incoming>:
            try prior.migrate(from: from)
        default:
            throw "No more migrations"
        }
        
        return migrate(from: incoming)
    }
}

extension BaseMigrationStrategy {
    func migrate<F>(from: F) throws -> Outgoing {
        guard let from = from as? Incoming else {
            throw "Unable to migrate because input type (\(type(of: from))) does not match expected incoming type (\(Incoming.self)) in MigrationStrategy."
        }
        return migrate(from: from)
    }
}
