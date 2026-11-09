import Foundation

// MARK: - FoodShelfLife
/// Starting guesses for "Expires", so most foods need no thought. Always just a starting point
/// the user can change.
///
/// Rule: the **low end** of the US guidance range, and when a label could mean raw or cooked
/// ("Chicken", "Beef"), the shorter of the two. Sources (checked 2026-11-02):
/// - FoodSafety.gov Cold Food Storage Chart: raw poultry and ground meat 1–2 days; steaks
///   3–5 days; fatty fish 1–3 days; shrimp 3–5 days; eggs in shell 3–5 weeks; cooked
///   leftovers, soups and stews 3–4 days; freezer times are for quality only (food stays safe).
/// - USDA FSIS "The Big Thaw": after thawing in the fridge, ground meat, poultry and seafood
///   keep 1–2 more days before cooking (red meat cuts 3–5).
/// - FoodKeeper (via FoodSafety.gov): yogurt 1–2 weeks; cooked rice 4–6 days (we use the
///   3–4 day leftovers rule, which is shorter); opened refrigerated juice about 7–10 days.
/// - USDA FSIS "Shelf-Stable Food Safety": high-acid canned food keeps 12–18 months, low-acid
///   2–5 years (unopened, cool and dry) → canned starts at 1 year as a best-by reminder.
/// Bread, fruit, veg and spreads are about quality and vary a lot; those numbers are cautious
/// picks, not from one chart.
enum FoodShelfLife {
    /// Unopened canned food: a 1-year best-by reminder (low end of 12–18 months).
    static let cannedDays = 365
    /// Thawed in the fridge: cook within 1–2 days (low end).
    static let thawDays = 1
    /// Freezer (quality only): about 3 months; cooked food 2 months.
    static let freezerDays = 90
    /// Cooked food in the freezer.
    static let freezerPreparedDays = 60
    /// Cooked / prepared food and leftovers: 3–4 days (low end), whatever is in it.
    static let preparedDays = 3
    /// Pantry food with no better match.
    static let pantryDays = 28
    /// Bread on the counter.
    static let pantryBreadDays = 3

    /// Fridge days by Food label for raw / as-bought food (keys lowercased).
    private static let fridgeDays: [String: Int] = [
        "chicken": 1, "beef": 1, "fish": 1, "shrimp": 3,   // raw meat & seafood
        "eggs": 21, "yogurt": 7, "juice": 7,
        "rice": 3, "pasta": 3, "curry": 3,                  // usually cooked: leftovers rule
        "bread": 7, "fruit": 3, "veggie": 3, "spread": 28,  // quality, cautious picks
    ]

    /// The suggested days for a food, or nil when there's nothing better than the default.
    /// Order: Thaw, then canned, then freezer, then cooked (Prepared), then the main label,
    /// then pantry.
    /// - Parameters:
    ///   - place: where it lives.
    ///   - kinds: what kind it is.
    ///   - labels: its Food labels, main first.
    static func suggestedDays(place: FoodStorage, kinds: [FoodKind], labels: [String]) -> Int? {
        let prepared = kinds.contains(.prepared)
        if kinds.contains(.thaw) { return thawDays }
        if kinds.contains(.canned) { return cannedDays }
        if place == .freezer { return prepared ? freezerPreparedDays : freezerDays }
        if prepared { return preparedDays }
        let main = labels.first?.lowercased()
        if place == .pantry { return main == "bread" ? pantryBreadDays : pantryDays }
        return main.flatMap { fridgeDays[$0] }
    }
}
