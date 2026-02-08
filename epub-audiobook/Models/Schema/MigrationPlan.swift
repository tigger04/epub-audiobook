// ABOUTME: SwiftData migration plan for schema evolution.
// ABOUTME: Currently contains only V1; new versions and migrations will be added here.

import Foundation
import SwiftData

enum BookMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
