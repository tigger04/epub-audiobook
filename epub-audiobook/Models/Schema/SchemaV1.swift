// ABOUTME: VersionedSchema V1 for SwiftData models.
// ABOUTME: Defines the initial schema version for safe future migrations.

import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Book.self, Chapter.self, ReadingPosition.self, Bookmark.self]
    }
}
