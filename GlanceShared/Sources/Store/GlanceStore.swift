import Foundation
import SwiftData

// MARK: - GlanceStore
/// Shared SwiftData model container. CloudKit sync is off: everything stays on the device.
/// File protection is iOS's default (readable after the first unlock), on purpose: the app can
/// be opened from a widget or Shortcut while the phone is locked, and a stricter class would
/// make the store fail to open then (see REVIEW-2026-11-03 M5).
enum GlanceStore {
    static let appGroupIdentifier = "group.com.ruminate.glance"

    /// What happened when the app opened its store.
    enum Outcome: Equatable {
        /// Opened normally.
        case opened
        /// The store couldn't be opened (damaged, or a failed update), so it was set aside and a
        /// fresh one started. The old files are kept next to it.
        case reset
        /// Couldn't open any store file (e.g. the phone is still locked): running in memory,
        /// nothing typed now is kept.
        case temporary
    }

    /// Every model the store holds. GlanceCategory joins Theme and Step (many-to-many);
    /// FoodItem is the Food tab (new models migrate automatically).
    static var schema: Schema {
        Schema([Theme.self, Step.self, GlanceCategory.self, FoodItem.self])
    }

    /// Opens (or creates) the store.
    /// - Parameter inMemory: true for tests and the last-resort fallback.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
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

    /// Opens the store, recovering instead of crashing: a store that exists and can be read but
    /// won't open is set aside and a fresh one started; if nothing can be opened, the app runs
    /// in memory for this launch.
    /// - Parameters:
    ///   - fileManager: file access (injectable for tests).
    ///   - now: stamps the set-aside file name.
    static func makeContainerRecovering(fileManager: FileManager = .default,
                                        now: Date = Date()) -> (container: ModelContainer, outcome: Outcome) {
        if let container = try? makeContainer() { return (container, .opened) }
        let url = ModelConfiguration(schema: schema).url
        // Only a file we can actually read is "broken"; a locked one is left alone.
        if isReadable(url, fileManager: fileManager) {
            moveAside(url, fileManager: fileManager, now: now)
            if let fresh = try? makeContainer() { return (fresh, .reset) }
        }
        guard let memory = try? makeContainer(inMemory: true) else {
            fatalError("Glance couldn't create even an in-memory store")
        }
        return (memory, .temporary)
    }

    /// Whether the store file exists and its first bytes can be read (not missing, not locked).
    /// - Parameters:
    ///   - url: the store file.
    ///   - fileManager: file access.
    static func isReadable(_ url: URL, fileManager: FileManager = .default) -> Bool {
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)),
              let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 16)) != nil
    }

    /// Renames the store and its -wal / -shm companions to `<name>.broken-<time>` so nothing is
    /// lost and a fresh store can be created in their place.
    /// - Parameters:
    ///   - url: the store file.
    ///   - fileManager: file access.
    ///   - now: stamps the new names.
    static func moveAside(_ url: URL, fileManager: FileManager = .default, now: Date = Date()) {
        let stamp = Int(now.timeIntervalSince1970)
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: url.path(percentEncoded: false) + suffix)
            guard fileManager.fileExists(atPath: file.path(percentEncoded: false)) else { continue }
            let target = URL(fileURLWithPath: url.path(percentEncoded: false) + suffix + ".broken-\(stamp)")
            try? fileManager.moveItem(at: file, to: target)
        }
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
