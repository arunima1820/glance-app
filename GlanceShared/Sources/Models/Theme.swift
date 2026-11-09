import Foundation
import SwiftData

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
    var categories: [GlanceCategory] = [] // plain side of GlanceCategory.themes many-to-many

    // Repeats (stored as primitives so SwiftData migrates them; see `recurrence`).
    var repeatKind: String = Recurrence.Kind.daily.rawValue
    var repeatWeekdays: [Int] = []
    var repeatDayOfMonth: Int = 1
    var repeatInterval: Int = 2
    /// Day the cycle counts from (every-N-days / weekly-without-days); set when the rule changes.
    /// nil on lists made before this field existed: they count from `createdAt`.
    var repeatAnchor: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \Step.theme)
    var steps: [Step]

    init(
        id: UUID = UUID(),
        name: String,
        colorToken: String = "sage",
        iconToken: String = ThemeIcons.default,
        iconEmoji: String = "⭐️",
        sortOrder: Int = 0,
        steps: [Step] = []
    ) {
        self.id = id
        self.name = name
        self.colorToken = colorToken
        self.iconToken = iconToken
        self.iconEmoji = iconEmoji
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
        self.steps = steps
    }

    /// How often this list wipes clean (daily by default; `.oneTime` never resets).
    /// The cycle for "every N days" counts from `repeatAnchor` (or the creation day).
    var recurrence: Recurrence {
        get {
            // Stored values are clamped to what the editor allows, so a damaged store can't
            // produce a rule that never occurs.
            Recurrence(kind: Recurrence.Kind(rawValue: repeatKind) ?? .daily,
                       weekdays: Set(repeatWeekdays.filter { (1...7).contains($0) }),
                       dayOfMonth: min(max(repeatDayOfMonth, 1), 31),
                       interval: min(max(repeatInterval, 1), 30),
                       anchor: min(repeatAnchor ?? createdAt, Date()))   // a clock set ahead can't stall it
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
