import Foundation
import SwiftData

// MARK: - GlanceStore
/// Shared SwiftData model container.
/// CloudKit sync is disabled during local development — re-enable once your
/// Apple Developer account is approved and YOUR_TEAM placeholders are filled in.
enum GlanceStore {
    static let appGroupIdentifier = "group.com.glance.local"

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        // GlanceCategory joins Theme and Step in the schema (many-to-many grouping).
        let schema = Schema([Theme.self, Step.self, GlanceCategory.self])

        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            // Store in the app's own documents directory for now (no App Group needed on simulator).
            config = ModelConfiguration(schema: schema)
        }

        return try ModelContainer(for: schema, configurations: [config])
    }
}
