//
//  MigrationStrategy.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/20/26.
//

import Foundation

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
    
    func migrate(version: Int, decoder: (any Decodable.Type) throws -> Any) throws -> Outgoing {
        let decoded = try decode(version: version, decoder: decoder)
        return try migrate(from: decoded, version: version)
    }

    private func decode(version: Int, decoder: (any Decodable.Type) throws -> Any) throws -> Any {
        if version == self.version {
            return try decodeAsIncoming(decoder)
        }

        return switch prior {
        case let prior as any MigrationStrategy<Incoming>:
            try prior.decode(version: version, decoder: decoder)
        case _ as RootMigrationStrategy<Incoming>:
            try decodeAsIncoming(decoder)
        default:
            throw "No more migrations"
        }
    }

    private func decodeAsIncoming(_ decoder: (any Decodable.Type) throws -> Any) throws -> Any {
        guard let incomingType = Incoming.self as? any Decodable.Type else {
            throw "Incoming type \(Incoming.self) must conform to Decodable to migrate from raw data."
        }
        return try decoder(incomingType)
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
