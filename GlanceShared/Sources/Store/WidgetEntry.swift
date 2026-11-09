import Foundation

// MARK: - GlanceEntry
// Shared between GlanceWidgetExtension (timeline provider) and GlanceTests.
// Lives in GlanceShared so it can be unit-tested without importing WidgetKit.

struct GlanceEntry {
    let date: Date
    let themes: [ThemeSnapshot]
    let selectedThemeID: String?
    /// Food for the large widget's right column (already narrowed to "use soon"); the column
    /// only appears when non-empty.
    let food: [FoodSnapshot]

    init(date: Date, themes: [ThemeSnapshot], selectedThemeID: String?, food: [FoodSnapshot] = []) {
        self.date = date
        self.themes = themes
        self.selectedThemeID = selectedThemeID
        self.food = food
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
// Shown only before the app has ever written a snapshot (fresh install).
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
            ],
            iconToken: "meds"
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
            ],
            iconToken: "leave"
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
            ],
            iconToken: "morning"
        ),
    ]
}

// MARK: - FoodSnapshot
/// A food as the widgets, search and Recently removed see it. Everything after `name` is
/// optional so a snapshot from an older build still decodes.
struct FoodSnapshot: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    /// Use-by day (nil only for foods saved by early builds).
    var useBy: Date? = nil
    var storage: FoodStorage? = nil
    var kinds: [FoodKind]? = nil
    var labels: [String]? = nil
    var details: String? = nil
    var addedAt: Date? = nil

    /// Where it lives (fridge when unknown).
    var place: FoodStorage { storage ?? .fridge }
    /// Its kinds (none when unknown).
    var kindList: [FoodKind] { kinds ?? [] }
    /// Its Food labels, main first (none when unknown).
    var labelList: [String] { labels ?? [] }
    /// Canned: long best-by date, pill hidden until it's close.
    var isCanned: Bool { kindList.contains(.canned) }
}

// MARK: - WidgetPin
/// The user's pin choice: which list (nil = unpinned) and when they chose it.
struct WidgetPin: Equatable, Sendable {
    var themeID: UUID?
    var at: Date?
}

// MARK: - WidgetSelection
/// Decides what the widget shows at a moment. Shared by the widget's timeline and the app's
/// tile pins, so both always agree. (Sequences, DEV-SPEC §4.7, will extend this.)
enum WidgetSelection {

    /// Whether a list is finished for its current period (and so hidden until it repeats).
    static func isFinished(_ theme: ThemeSnapshot, now: Date, calendar: Calendar = .current) -> Bool {
        (theme.recurrence ?? Recurrence()).isStillComplete(theme.completedAt, now: now, calendar: calendar)
    }

    /// Lists the widget may show at `now`: those with steps that aren't finished.
    static func visible(_ themes: [ThemeSnapshot], now: Date, calendar: Calendar = .current) -> [ThemeSnapshot] {
        themes.filter { !$0.steps.isEmpty && !isFinished($0, now: now, calendar: calendar) }
    }

    /// A list that has come round again since the user last pinned/unpinned pins itself.
    /// Only infrequent rules do this (`Recurrence.isInfrequent`), so daily-ish lists don't grab
    /// the widget every morning. Latest-starting period wins; ties keep list order
    /// (`max(by:)` keeps the first of equal elements).
    static func autoPinned(_ visible: [ThemeSnapshot], pin: WidgetPin, now: Date,
                           calendar: Calendar = .current) -> UUID? {
        let since = pin.at ?? .distantPast
        return visible.compactMap { theme -> (UUID, Date)? in
            guard let rule = theme.recurrence, rule.isInfrequent else { return nil }
            let start = rule.periodStart(atOrBefore: now, calendar: calendar)
            return start > since ? (theme.id, start) : nil
        }
        .max { $0.1 < $1.1 }?.0
    }

    /// The list to show: auto-pin, else the user's pin, else the widget's configured list,
    /// else the first visible list. Hidden (finished) lists are never chosen.
    /// - Parameters:
    ///   - visible: lists from `visible(_:now:)`.
    ///   - pin: the user's pin state.
    ///   - configured: the widget's own configured id, if any.
    ///   - now: the moment being drawn.
    static func selectedID(visible: [ThemeSnapshot], pin: WidgetPin, configured: String?,
                           now: Date, calendar: Calendar = .current) -> UUID? {
        if let chosen = explicitID(visible: visible, pin: pin, now: now, calendar: calendar) { return chosen }
        let ids = Set(visible.map(\.id))
        if let chosen = configured.flatMap(UUID.init(uuidString:)), ids.contains(chosen) { return chosen }
        return visible.first?.id
    }

    /// The list that is pinned on purpose (auto-pin, else the user's pin if still visible), or
    /// nil when the widget is only falling back to the first list. The app fills the pin icon
    /// only for this one, so tapping a filled pin always unpins.
    static func explicitID(visible: [ThemeSnapshot], pin: WidgetPin, now: Date,
                           calendar: Calendar = .current) -> UUID? {
        if let auto = autoPinned(visible, pin: pin, now: now, calendar: calendar) { return auto }
        guard let pinned = pin.themeID, visible.contains(where: { $0.id == pinned }) else { return nil }
        return pinned
    }

    /// A step as the widget draws it.
    struct Row: Identifiable {
        let step: StepSnapshot
        let isDone: Bool
        var id: UUID { step.id }
    }

    /// Steps in widget order: done steps (this period) keep their tick and sink to the
    /// bottom, order otherwise kept. Every list, repeating or one-time. (The app never
    /// reorders; this is widget-only.)
    static func rows(for theme: ThemeSnapshot, now: Date, calendar: Calendar = .current) -> [Row] {
        let rule = theme.recurrence ?? Recurrence()
        let rows = theme.steps.map { step in
            Row(step: step, isDone: rule.isStillComplete(step.completedAt, now: now, calendar: calendar))
        }
        return rows.filter { !$0.isDone } + rows.filter(\.isDone)
    }
}

