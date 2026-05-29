import Foundation
import SwiftData

// MARK: - Theme
/// A broad container for one routine or context (e.g. "Take meds", "Leave the house").
@Model
final class Theme: Identifiable {
    var id: UUID
    var name: String
    var colorToken: String   // key into ThemePalette, e.g. "sage", "lavender"
    var iconEmoji: String    // single emoji or SF Symbol name
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Step.theme)
    var steps: [Step]

    init(
        id: UUID = UUID(),
        name: String,
        colorToken: String = "sage",
        iconEmoji: String = "⭐️",
        sortOrder: Int = 0,
        steps: [Step] = []
    ) {
        self.id = id
        self.name = name
        self.colorToken = colorToken
        self.iconEmoji = iconEmoji
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
        self.steps = steps
    }

    /// Returns steps sorted by their sortOrder.
    var orderedSteps: [Step] {
        steps.sorted { $0.sortOrder < $1.sortOrder }
    }
}
