import Foundation
import SwiftData

// MARK: - Step
/// One small action inside a Theme (e.g. "Grab keys") — a single "task".
/// Completion is optional and supports two styles (see ThemeCompletionStyle); a step
/// can also carry its own categories and accent color independent of its theme.
@Model
final class Step: Identifiable {
    var id: UUID
    var text: String
    var iconEmoji: String?   // optional — not every step needs an icon
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    // New in this version — defaults keep existing stored data migratable.
    var completedAt: Date? = nil          // timestamp of completion (drives daily reset)
    var colorToken: String? = nil         // optional own accent, separate from categories
    var categories: [GlanceCategory] = []       // plain side of GlanceCategory.steps many-to-many

    var theme: Theme?

    init(
        id: UUID = UUID(),
        text: String,
        iconEmoji: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.text = text
        self.iconEmoji = iconEmoji
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Marks the step complete (or not): stamps `completedAt`, which the list's repeat
    /// schedule reads to decide whether the tick still counts.
    /// - Parameters:
    ///   - complete: desired completion state.
    ///   - now: the moment to stamp (injectable for tests).
    func setComplete(_ complete: Bool, now: Date = Date()) {
        completedAt = complete ? now : nil
        updatedAt = now
    }
}

// MARK: - StepText
/// Splits a step's text into the bold lead word and the plain detail that follows,
/// so rows can render "**Pour** a full glass of water" without storing two fields.
enum StepText {
    /// Splits `text` at the first run of whitespace, trimming the ends first.
    /// - Parameter text: the raw step text.
    /// - Returns: `lead` (first word, possibly empty) and `detail` (the rest, possibly empty).
    static func split(_ text: String) -> (lead: String, detail: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let gap = trimmed.firstIndex(where: \.isWhitespace) else {
            return (trimmed, "")
        }
        let detail = trimmed[gap...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (String(trimmed[..<gap]), detail)
    }
}
