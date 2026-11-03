import Foundation
import SwiftData

// MARK: - GlanceStore
/// Shared SwiftData model container.
/// CloudKit sync is disabled during local development — re-enable once your
/// Apple Developer account is approved and YOUR_TEAM placeholders are filled in.
enum GlanceStore {
    static let appGroupIdentifier = "group.com.ruminate.glance"

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        // GlanceCategory joins Theme and Step in the schema (many-to-many grouping).
        let schema = Schema([Theme.self, Step.self, GlanceCategory.self])

        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            // Default location: with the App Group entitlement, SwiftData uses the group container.
            try ensureStoreDirectoryExists()
            config = ModelConfiguration(schema: schema)
        }

        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Creates `Library/Application Support` inside the App Group container if it's missing.
    /// A fresh group container doesn't have it, and SwiftData won't create it, so the
    /// store fails to open ("parent directory path reported as missing"). No-op if present
    /// or if the group container is unavailable (SwiftData then falls back to the app sandbox).
    static func ensureStoreDirectoryExists(fileManager: FileManager = .default) throws {
        guard let group = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return }
        let support = group.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
    }
}
