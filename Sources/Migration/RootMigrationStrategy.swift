//
//  RootMigrationStrategy.swift
//  AsyncSimpleStore
//
//  Created by Trevor Sheridan on 4/20/26.
//

public struct RootMigrationStrategy<Outgoing>: BaseMigrationStrategy {
    public let version: MigrationVersion

    public init(version: MigrationVersion) {
        self.version = version
    }

    public func migrate(from: Outgoing) -> Outgoing {
        from
    }
}
