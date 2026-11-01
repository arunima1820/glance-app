import Foundation
import SwiftData

// MARK: - ThemeCompletionStyle
/// How a theme's list is completed. Both styles are offered; the user picks per theme.
/// - sweep: tap once to clear the whole list (the "wipe the fridge board" gesture).
/// - perItem: tap each step individually to mark it done.
enum ThemeCompletionStyle: String, Codable, CaseIterable, Identifiable {
    case sweep
    case perItem

    var id: String { rawValue }

    /// Human-readable label for the settings/edit UI.
    var label: String {
        switch self {
        case .sweep:   return "Clear whole list"
        case .perItem: return "Check off each step"
        }
    }
}

// MARK: - Theme
/// A broad container for one routine or context (e.g. "Take meds", "Leave the house").
@Model
final class Theme: Identifiable {
    var id: UUID
    var name: String
    var colorToken: String   // key into ThemePalette, e.g. "sage", "lavender"
    var iconToken: String    // key into ThemeIcons (SF Symbol), e.g. "meds", "leave"
    var iconEmoji: String    // legacy, still read by the widget snapshot until it migrates
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    // Defaults keep existing stored data migratable.
    var completionStyle: ThemeCompletionStyle = ThemeCompletionStyle.sweep
    var lastSweptAt: Date? = nil          // when the list was last cleared as a whole
    var categories: [GlanceCategory] = [] // plain side of GlanceCategory.themes many-to-many

    @Relationship(deleteRule: .cascade, inverse: \Step.theme)
    var steps: [Step]

    init(
        id: UUID = UUID(),
        name: String,
        colorToken: String = "sage",
        iconToken: String = ThemeIcons.default,
        iconEmoji: String = "⭐️",
        sortOrder: Int = 0,
        completionStyle: ThemeCompletionStyle = .sweep,
        steps: [Step] = []
    ) {
        self.id = id
        self.name = name
        self.colorToken = colorToken
        self.iconToken = iconToken
        self.iconEmoji = iconEmoji
        self.sortOrder = sortOrder
        self.completionStyle = completionStyle
        self.createdAt = Date()
        self.updatedAt = Date()
        self.steps = steps
    }

    /// Returns steps sorted by their sortOrder.
    var orderedSteps: [Step] {
        steps.sorted { $0.sortOrder < $1.sortOrder }
    }
}
