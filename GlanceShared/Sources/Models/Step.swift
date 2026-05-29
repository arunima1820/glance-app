import Foundation
import SwiftData

// MARK: - Step
/// One small action inside a Theme (e.g. "Grab keys").
/// Steps have no completion state in v1 — they are for looking at, not checking off.
@Model
final class Step: Identifiable {
    var id: UUID
    var text: String
    var iconEmoji: String?   // optional — not every step needs an icon
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

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
}
