import Foundation
import SwiftData

// MARK: - GlanceCategory
/// A named, colored grouping that can be applied to many Themes and many Steps.
/// Example: a category named "Urgent" with the "red" color token.
/// A Theme or Step may belong to several categories at once (many-to-many).
/// Color is always paired with the category's name — never relied upon alone (design rule).
@Model
final class GlanceCategory: Identifiable {
    var id: UUID
    var name: String
    var colorToken: String   // key into CategoryPalette, e.g. "red", "blue"
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    // Inverse relationships live here; Theme.categories and Step.categories are the plain sides.
    @Relationship(inverse: \Theme.categories)
    var themes: [Theme]

    @Relationship(inverse: \Step.categories)
    var steps: [Step]

    /// Creates a category. `themes`/`steps` start empty and are linked by assignment later.
    init(
        id: UUID = UUID(),
        name: String,
        colorToken: String = "blue",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorToken = colorToken
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
        self.themes = []
        self.steps = []
    }
}
