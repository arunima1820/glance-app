import Foundation

// MARK: - FoodSort
/// The Food tab's sort menu.
enum FoodSort: String, CaseIterable, Identifiable, Sendable {
    case expiry, recent

    var id: String { rawValue }

    /// Menu wording.
    var label: String {
        switch self {
        case .expiry: return "Use soonest first"
        case .recent: return "Recently added"
        }
    }
}

// MARK: - FoodQuery
/// Sorting, search and "use soon" for food. Pure functions on snapshots, shared by the Food
/// tab and the widgets so both always agree.
enum FoodQuery {
    /// Most characters the search box takes.
    static let searchLimit = 60
    /// Most words of a search that are matched (the rest are ignored).
    static let searchWordLimit = 6

    /// Sorts foods. By expiry: expired and soonest first, foods with no date (canned) last,
    /// ties by name. By recent: newest first.
    /// - Parameters:
    ///   - items: the foods.
    ///   - sort: the order wanted.
    static func sorted(_ items: [FoodSnapshot], by sort: FoodSort) -> [FoodSnapshot] {
        switch sort {
        case .recent:
            return items.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
        case .expiry:
            return items.sorted(by: expiresFirst)
        }
    }

    /// The expiry order: dated before undated, then earlier date, then name.
    private static func expiresFirst(_ a: FoodSnapshot, _ b: FoodSnapshot) -> Bool {
        switch (a.useBy, b.useBy) {
        case let (x?, y?) where x != y: return x < y
        case (.some, nil): return true
        case (nil, .some): return false
        default: return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Whether every word typed matches something in the food: its name, description, labels,
    /// kinds or where it's stored. Forgiving on purpose, with no AI: case and accents are
    /// ignored, a word can be the start or part of a word ("chick"), small typos are fine in the
    /// name, labels and kinds ("chiken", "yoghurt"), and a few related words count
    /// ("leftovers" finds prepared food). Only the first `searchWordLimit` words count.
    /// Empty text matches everything.
    /// - Parameters:
    ///   - item: the food.
    ///   - text: what's in the search box.
    static func matches(_ item: FoodSnapshot, text: String) -> Bool {
        let terms = Array(words(in: String(text.prefix(searchLimit))).prefix(searchWordLimit))
        guard !terms.isEmpty else { return true }
        // Typo matching only looks at the short fields (name, labels, kinds, place); the
        // description is matched exactly. Keeps a long description from slowing every keystroke.
        let short = words(in: ([item.name, item.place.label] + item.labelList + item.kindList.map(\.label))
            .joined(separator: " "))
        let description = words(in: item.details ?? "")
        return terms.allSatisfy { term in
            ([term] + (FoodSearchWords.related[term] ?? [])).contains { candidate in
                short.contains { FoodSearchWords.isClose(candidate, to: $0) }
                    || description.contains { $0.contains(candidate) }
            }
        }
    }

    /// Lowercased, accent-free words.
    private static func words(in text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    /// The Food tab's filter: search text plus the storage switch (nil = all).
    /// - Parameters:
    ///   - items: the foods.
    ///   - text: search text.
    ///   - storage: Fridge / Freezer / Pantry, or nil for all.
    static func filter(_ items: [FoodSnapshot], text: String, storage: FoodStorage?) -> [FoodSnapshot] {
        items.filter { item in
            (storage == nil || item.place == storage) && matches(item, text: text)
        }
    }

    /// What the widgets show: dated foods due within `lookAheadDays` (today counts), plus
    /// expired ones when asked, soonest first. Canned food shows only once it's that close.
    /// - Parameters:
    ///   - items: the foods.
    ///   - now: the moment being drawn.
    ///   - lookAheadDays: how far ahead to look.
    ///   - includeExpired: whether expired food shows (at the top).
    ///   - calendar: calendar for the day count (injectable for tests).
    static func useSoon(_ items: [FoodSnapshot], now: Date, lookAheadDays: Int, includeExpired: Bool,
                        calendar: Calendar = .current) -> [FoodSnapshot] {
        let today = calendar.startOfDay(for: now)
        let due = items.filter { item in
            guard let useBy = item.useBy else { return false }
            let left = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: useBy)).day ?? 0
            return left < 0 ? includeExpired : left <= lookAheadDays
        }
        return sorted(due, by: .expiry)
    }

    /// The pill to show for a food: its freshness, except canned food stays quiet (no pill)
    /// while its best-by date is still weeks away.
    /// - Parameters:
    ///   - item: the food.
    ///   - now: the moment being drawn.
    ///   - calendar: calendar for the day count (injectable for tests).
    static func pill(for item: FoodSnapshot, now: Date, calendar: Calendar = .current) -> Freshness {
        let freshness = Freshness.of(useBy: item.useBy, now: now, calendar: calendar)
        return item.isCanned && freshness == .weeks ? .none : freshness
    }

    /// The tile's quiet line: "Prepared · Chicken +1", "Fridge · Eggs", "Pantry · Canned".
    /// The first kind leads when there are labels; otherwise where it's stored leads.
    /// - Parameter item: the food.
    static func subtitle(for item: FoodSnapshot) -> String {
        let firstKind = item.kindList.first?.label
        guard let main = item.labelList.first else {
            return [item.place.label, firstKind].compactMap { $0 }.joined(separator: " · ")
        }
        let extra = item.labelList.count > 1 ? " +\(item.labelList.count - 1)" : ""
        return "\(firstKind ?? item.place.label) · \(main)\(extra)"
    }

}

// MARK: - FoodSearchWords
/// The simple, rule-based "fuzzy" part of food search: typo tolerance and related words.
enum FoodSearchWords {
    /// Longest typed word that gets typo matching.
    static let fuzzyLimit = 20

    /// Words that also search for others ("meat" finds chicken and beef). Keys lowercased.
    static let related: [String: [String]] = [
        "leftover": ["prepared"], "leftovers": ["prepared"], "cooked": ["prepared"],
        "frozen": ["freezer"], "cupboard": ["pantry"], "tin": ["canned"], "tinned": ["canned"],
        "can": ["canned"], "veg": ["veggie"], "vegetable": ["veggie"], "vegetables": ["veggie"],
        "prawn": ["shrimp"], "prawns": ["shrimp"], "noodle": ["pasta"], "noodles": ["pasta"],
        "beverage": ["drink"], "drinks": ["drink"], "milk": ["drink"],
        "meat": ["chicken", "beef"], "seafood": ["fish", "shrimp"], "dairy": ["yogurt"],
        "protein": ["chicken", "beef", "fish", "shrimp", "eggs"], "carbs": ["rice", "pasta", "bread"],
    ]

    /// Whether a typed word matches a word in the food: part of it, or a near miss.
    /// Short words must be exact (too many false hits otherwise); 4–6 letters allow one
    /// typo, 7+ allow two. A near miss is checked against the whole word and against its
    /// start, so a half-typed word with a typo still finds it ("chik" → chicken).
    /// - Parameters:
    ///   - term: one typed word (lowercased).
    ///   - word: one word in the food (lowercased).
    static func isClose(_ term: String, to word: String) -> Bool {
        if word.contains(term) { return true }
        guard term.count <= fuzzyLimit else { return false }   // long words: exact only (keeps it fast)
        let allowed = term.count >= 7 ? 2 : (term.count >= 4 ? 1 : 0)
        guard allowed > 0 else { return false }
        return distance(term, word) <= allowed || distance(term, String(word.prefix(term.count))) <= allowed
    }

    /// Edit distance: how many letters to add, remove, change or swap to get from a to b.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var grid = (0...a.count).map { row in (0...b.count).map { row == 0 ? $0 : ($0 == 0 ? row : 0) } }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                grid[i][j] = min(grid[i - 1][j] + 1, grid[i][j - 1] + 1, grid[i - 1][j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    grid[i][j] = min(grid[i][j], grid[i - 2][j - 2] + 1)   // swapped letters count once
                }
            }
        }
        return grid[a.count][b.count]
    }
}

// MARK: - EmptyLine
/// A two-line empty state: a short title and one line under it.
struct EmptyLine: Equatable, Sendable {
    let title: String
    let message: String
}

// MARK: - FoodEmptyLines
/// What to say when there's no food. Widgets stay calm; the Food tab rotates a funny
/// "go grocery shopping" line, a different one each day.
enum FoodEmptyLines {
    /// The widgets' line.
    static let calm = EmptyLine(title: "Nothing to use up", message: "Nice. Your fridge is calm.")

    /// The Food tab's lines, one per day in turn.
    static let funny = [
        EmptyLine(title: "Suspiciously fresh", message: "Nothing's about to go off. Time to buy something that can."),
        EmptyLine(title: "Fridge on holiday", message: "Zero deadlines in there. A grocery run would fix that."),
        EmptyLine(title: "All quiet in the crisper", message: "Go buy some spinach and give this page a job."),
    ]

    /// The funny line for a given day (the same all day, the next one tomorrow).
    /// - Parameters:
    ///   - date: the day.
    ///   - calendar: calendar for the day number (injectable for tests).
    static func ofTheDay(_ date: Date, calendar: Calendar = .current) -> EmptyLine {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return funny[day % funny.count]
    }
}
