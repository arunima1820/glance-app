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
    var iconToken: String = ThemeIcons.default  // key into ThemeIcons (SF Symbol); default keeps old stores migratable
    var iconEmoji: String    // legacy, still read by the widget snapshot until it migrates
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    // Defaults keep existing stored data migratable.
    var completionStyle: ThemeCompletionStyle = ThemeCompletionStyle.sweep
    var lastSweptAt: Date? = nil          // when the list was last cleared as a whole
    var categories: [GlanceCategory] = [] // plain side of GlanceCategory.themes many-to-many

    // Repeats (stored as primitives so SwiftData migrates them; see `recurrence`).
    var repeatKind: String = Recurrence.Kind.daily.rawValue
    var repeatWeekdays: [Int] = []
    var repeatDayOfMonth: Int = 1
    var repeatInterval: Int = 2

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

    /// How often this list wipes clean (daily by default; `.oneTime` never resets).
    /// The cycle for "every N days" counts from the list's creation day.
    var recurrence: Recurrence {
        get {
            Recurrence(kind: Recurrence.Kind(rawValue: repeatKind) ?? .daily,
                       weekdays: Set(repeatWeekdays), dayOfMonth: repeatDayOfMonth,
                       interval: repeatInterval, anchor: createdAt)
        }
        set {
            repeatKind = newValue.kind.rawValue
            repeatWeekdays = newValue.weekdays.sorted()
            repeatDayOfMonth = newValue.dayOfMonth
            repeatInterval = newValue.interval
        }
    }

    /// Returns steps sorted by their sortOrder.
    var orderedSteps: [Step] {
        steps.sorted { $0.sortOrder < $1.sortOrder }
    }
}
