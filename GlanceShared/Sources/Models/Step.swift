import Foundation
import SwiftData

// MARK: - Step
/// One small action inside a Theme (e.g. "Grab keys") — a single "task".
/// Done-ness is a `completedAt` stamp that the list's `Recurrence` reads; a step can also
/// carry its own categories and accent color independent of its theme.
@Model
final class Step: Identifiable {
    var id: UUID
    var text: String
    var iconEmoji: String?   // optional — not every step needs an icon
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    // New in this version — defaults keep existing stored data migratable.
    var completedAt: Date? = nil          // when ticked; the list's Recurrence decides if it still counts
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

// MARK: - TextLimits
/// Caps on user text, so a huge paste can't bloat the widget snapshot (the widget extension
/// has a small memory budget and decodes the whole snapshot on every refresh).
enum TextLimits {
    static let name = 80
    static let step = 200
    /// A food's description.
    static let note = 300

    /// Cleans, trims and cuts user text to `limit` characters (see `clean`).
    /// - Parameters:
    ///   - text: raw user input.
    ///   - limit: maximum characters to keep.
    ///   - allowsNewlines: keep line breaks (descriptions); otherwise they become spaces.
    static func clamp(_ text: String, to limit: Int, allowsNewlines: Bool = false) -> String {
        let cleaned = clean(text, allowsNewlines: allowsNewlines)
        return String(cleaned.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    /// Removes characters that can hide or flip text on tiles, widgets and the Lock Screen:
    /// control characters (tabs and line breaks become spaces unless allowed), right-to-left
    /// overrides / isolates, zero-width spaces and byte-order marks. Emoji joiners stay.
    /// - Parameters:
    ///   - text: raw user input.
    ///   - allowsNewlines: keep "\n" line breaks.
    static func clean(_ text: String, allowsNewlines: Bool = false) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if invisible.contains(scalar.value) { continue }
            guard scalar.properties.generalCategory == .control else { scalars.append(scalar); continue }
            if scalar == "\n" && allowsNewlines {
                scalars.append(scalar)
            } else if scalar == "\n" || scalar == "\t" || scalar == "\r" {
                scalars.append(" ")
            }
        }
        return String(scalars)
    }

    /// Direction overrides / isolates, zero-width space, word joiner, byte-order mark, and the
    /// left-to-right / right-to-left marks.
    private static let invisible: Set<UInt32> = Set<UInt32>(0x202A...0x202E)
        .union(0x2066...0x2069)
        .union([0x200B, 0x200E, 0x200F, 0x2060, 0xFEFF])
}

// MARK: - CollectionLimits
/// Most lists, steps and foods the app holds. Every way of adding stops here (buttons hide,
/// saves refuse), so nothing (a stuck key, a script driving the screen, a future import) can
/// grow the store until the app or its widgets slow down or run out of memory.
enum CollectionLimits {
    static let lists = 100
    static let stepsPerList = 100
    static let foods = 500

    /// Whether one more fits.
    /// - Parameters:
    ///   - count: how many there are now.
    ///   - limit: the cap.
    static func hasRoom(_ count: Int, under limit: Int) -> Bool { count < limit }
}
