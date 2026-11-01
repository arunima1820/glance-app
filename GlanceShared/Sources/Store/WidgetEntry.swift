import Foundation

// MARK: - GlanceEntry
// Shared between GlanceWidgetExtension (timeline provider) and GlanceTests.
// Lives in GlanceShared so it can be unit-tested without importing WidgetKit.

struct GlanceEntry {
    let date: Date
    let themes: [ThemeSnapshot]
    let selectedThemeID: String?

    init(date: Date, themes: [ThemeSnapshot], selectedThemeID: String?) {
        self.date = date
        self.themes = themes
        self.selectedThemeID = selectedThemeID
    }

    /// The theme to display. Matches selectedThemeID if set; falls back to first.
    var selectedTheme: ThemeSnapshot? {
        if let id = selectedThemeID,
           let match = themes.first(where: { $0.id.uuidString == id }) {
            return match
        }
        return themes.first
    }
}

// MARK: - Placeholder themes
// Used by the timeline provider when live data is unavailable (e.g. no App Group in dev).
// Also used by tests to verify the fallback always has displayable content.

enum WidgetPlaceholders {
    static let themes: [ThemeSnapshot] = [
        ThemeSnapshot(
            id: UUID(),
            name: "Take meds",
            colorToken: "sage",
            iconEmoji: "💊",
            steps: [
                StepSnapshot(id: UUID(), text: "Get water",    iconEmoji: "💧"),
                StepSnapshot(id: UUID(), text: "Take tablets", iconEmoji: "💊"),
            ]
        ),
        ThemeSnapshot(
            id: UUID(),
            name: "Leave the house",
            colorToken: "sky",
            iconEmoji: "🚪",
            steps: [
                StepSnapshot(id: UUID(), text: "Grab keys",     iconEmoji: "🔑"),
                StepSnapshot(id: UUID(), text: "Phone charged", iconEmoji: "🔋"),
                StepSnapshot(id: UUID(), text: "Lock the door", iconEmoji: nil),
            ]
        ),
        ThemeSnapshot(
            id: UUID(),
            name: "Morning",
            colorToken: "butter",
            iconEmoji: "☀️",
            steps: [
                StepSnapshot(id: UUID(), text: "Drink water", iconEmoji: "💧"),
                StepSnapshot(id: UUID(), text: "Take meds",   iconEmoji: "💊"),
                StepSnapshot(id: UUID(), text: "Get dressed", iconEmoji: nil),
            ]
        ),
    ]
}
