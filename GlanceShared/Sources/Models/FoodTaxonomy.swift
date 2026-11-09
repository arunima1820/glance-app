import Foundation

// MARK: - FoodStorage
/// Where a food lives. One per food.
enum FoodStorage: String, CaseIterable, Codable, Identifiable, Sendable {
    case fridge, freezer, pantry

    var id: String { rawValue }

    /// Short display name.
    var label: String {
        switch self {
        case .fridge: return "Fridge"
        case .freezer: return "Freezer"
        case .pantry: return "Pantry"
        }
    }

    /// SF Symbol for tiles and headers.
    var symbol: String {
        switch self {
        case .fridge: return "refrigerator"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet"
        }
    }
}

// MARK: - FoodKind
/// What sort of food it is. A food can have several.
enum FoodKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case snack, ingredient, prepared, drink, thaw, canned

    var id: String { rawValue }

    /// Short display name.
    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

// MARK: - FoodLabels
/// The "Food" labels (Chicken, Rice…): built-in ones plus any the user adds. A food has up to
/// three; the first is its main label (shown on the tile).
enum FoodLabels {
    /// Built-in labels, in picker order.
    static let builtIn = ["Fruit", "Veggie", "Juice", "Bread", "Spread", "Yogurt", "Curry",
                          "Rice", "Chicken", "Beef", "Pasta", "Eggs", "Fish", "Shrimp"]
    /// Most labels one food can have.
    static let maxPicked = 3
    /// Longest label the user can add.
    static let maxLength = 30

    /// Other words in a name that point at a built-in label.
    private static let aliases: [String: String] = [
        "egg": "Eggs", "veg": "Veggie", "veggies": "Veggie", "vegetable": "Veggie",
        "vegetables": "Veggie", "fruits": "Fruit", "prawn": "Shrimp", "prawns": "Shrimp",
        "noodles": "Pasta", "spaghetti": "Pasta", "yoghurt": "Yogurt", "salmon": "Fish",
        "tuna": "Fish", "steak": "Beef", "toast": "Bread",
    ]

    /// Labels a food's name suggests ("chicken fried rice" → Chicken, Rice), in the order
    /// the words appear, at most `maxPicked`.
    /// - Parameters:
    ///   - name: the food's name as typed.
    ///   - labels: labels to look for (built-in plus the user's own).
    static func suggested(forName name: String, among labels: [String] = builtIn) -> [String] {
        let words = name.lowercased().split { !$0.isLetter }.map(String.init)
        var found: [String] = []
        for word in words {
            guard let label = match(word, in: labels), !contains(found, label) else { continue }
            found.append(label)
        }
        return Array(found.prefix(maxPicked))
    }

    /// The label one word points at: same word, a plural either way, or an alias.
    private static func match(_ word: String, in labels: [String]) -> String? {
        if let exact = labels.first(where: {
            let l = $0.lowercased()
            return l == word || l == word + "s" || l + "s" == word
        }) { return exact }
        guard let alias = aliases[word], contains(labels, alias) else { return nil }
        return alias
    }

    /// Cleans a label the user typed: trimmed, capped, first letter capitalised.
    /// - Parameter raw: what they typed.
    /// - Returns: the label, or nil when nothing is left.
    static func normalized(_ raw: String) -> String? {
        let trimmed = TextLimits.clamp(raw, to: maxLength)
        guard let first = trimmed.first else { return nil }
        return first.uppercased() + trimmed.dropFirst()
    }

    /// Case-insensitive membership.
    static func contains(_ labels: [String], _ label: String) -> Bool {
        labels.contains { $0.caseInsensitiveCompare(label) == .orderedSame }
    }
}
