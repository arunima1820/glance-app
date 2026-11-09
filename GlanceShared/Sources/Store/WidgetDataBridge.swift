import AppIntents
import Foundation
import SwiftData
import WidgetKit

// MARK: - Snapshots
/// What the widget knows about a list (decoded from App Group defaults, never SwiftData).
struct ThemeSnapshot: Codable, Identifiable {
    let id: UUID
    let name: String
    let colorToken: String
    let iconEmoji: String
    let steps: [StepSnapshot]
    /// SF Symbol token (ThemeIcons). Optional so snapshots written by older builds still decode.
    var iconToken: String? = nil
    /// Repeat schedule (nil in old snapshots = daily).
    var recurrence: Recurrence? = nil
    /// When the list was finished in its current period; the widget hides it until it repeats.
    var completedAt: Date? = nil
}

struct StepSnapshot: Codable, Identifiable {
    let id: UUID
    let text: String
    let iconEmoji: String?
    /// When this step was ticked in the list's current period (nil = not done).
    var completedAt: Date? = nil
}

// MARK: - WidgetDataBridge
/// Writes a lightweight snapshot of lists into the App Group's shared defaults so the widget
/// extension can read it without touching SwiftData. After any edit call `refresh(from:)`;
/// it rewrites the snapshot and reloads the widgets.
enum WidgetDataBridge {
    /// App Group key for the list snapshot the widget draws.
    static let snapshotKey = StorageKeys.widgetSnapshot
    /// App Group key for the list the user pinned to the widget (from a tile pin).
    static let pinnedKey = StorageKeys.widgetPinnedTheme
    /// When the user last pinned or unpinned (auto-pins only win if their list came round after this).
    static let pinnedAtKey = StorageKeys.widgetPinnedAt
    /// App Group key for the Settings "Title style" (so the widget uses the same fonts).
    static let fontThemeKey = StorageKeys.fontTheme
    /// App Group key for the food snapshot (written by the Food tab, milestone 3).
    static let foodKey = StorageKeys.widgetFood
    /// The App Group defaults shared by app + widget (also used by `@AppStorage(store:)`).
    /// Every reader/writer below takes a `store` so tests can pass an isolated suite.
    /// Falls back to standard defaults if the App Group is missing (misconfigured signing).
    nonisolated(unsafe) static let defaults = UserDefaults(suiteName: GlanceStore.appGroupIdentifier) ?? .standard

    // MARK: Pin

    /// The list pinned to the widget, if any.
    static var pinnedThemeID: UUID? { pinState().themeID }

    /// The user's current pin (or unpin) and when they set it.
    static var pin: WidgetPin { pinState() }

    /// Reads the pin choice from `store`.
    static func pinState(in store: UserDefaults = defaults) -> WidgetPin {
        let id = store.string(forKey: pinnedKey).flatMap(UUID.init(uuidString:))
        let stamp = store.object(forKey: pinnedAtKey) as? Double
        return WidgetPin(themeID: id, at: stamp.map(Date.init(timeIntervalSince1970:)))
    }

    /// Pins a list to the widget (nil = unpin) and asks WidgetKit to redraw. Stamping the time
    /// means a repeating list only re-pins itself when it next comes round.
    /// - Parameters:
    ///   - id: the theme to show on the widget, or nil to unpin.
    ///   - now: when the user did it.
    ///   - store: where to save it (the App Group by default).
    static func pin(_ id: UUID?, now: Date = Date(), in store: UserDefaults = defaults) {
        store.set(id?.uuidString, forKey: pinnedKey)
        store.set(now.timeIntervalSince1970, forKey: pinnedAtKey)
        reloadWidgets()
    }

    // MARK: Fonts

    /// The font theme chosen in Settings (default if unset or unknown).
    static var fontThemeID: FontThemeID { fontThemeID(in: defaults) }

    /// Reads the Settings font theme from `store` (default if unset or unknown).
    static func fontThemeID(in store: UserDefaults) -> FontThemeID {
        store.string(forKey: fontThemeKey).flatMap(FontThemeID.init(rawValue:)) ?? FontThemes.default
    }

    /// Settings → "Hide details on Lock Screen": the Lock Screen widget then shows only a count.
    /// - Parameter store: where to read it (the App Group by default).
    static func hidesLockScreenDetails(in store: UserDefaults = defaults) -> Bool {
        store.bool(forKey: StorageKeys.lockScreenHidesDetails)
    }

    /// Asks WidgetKit to redraw (e.g. after a Settings change the widget reflects).
    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: List snapshot

    /// The widget's view of one list at `now`: ticks from earlier periods are dropped.
    /// - Parameters:
    ///   - theme: the list.
    ///   - now: reference moment for "done this period".
    ///   - calendar: calendar for the period math (injectable for tests).
    static func snapshot(of theme: Theme, now: Date = Date(), calendar: Calendar = .current) -> ThemeSnapshot {
        let start = theme.currentPeriodStart(now: now, calendar: calendar)   // once, not per step
        return ThemeSnapshot(
            id: theme.id,
            name: TextLimits.clamp(theme.name, to: TextLimits.name),
            colorToken: theme.colorToken,
            iconEmoji: theme.iconEmoji,
            steps: theme.orderedSteps.map { step in
                let current = Theme.counts(step.completedAt, since: start)
                return StepSnapshot(id: step.id, text: TextLimits.clamp(step.text, to: TextLimits.step),
                                    iconEmoji: step.iconEmoji,
                                    completedAt: current ? step.completedAt : nil)
            },
            iconToken: theme.iconToken,
            recurrence: theme.recurrence,
            completedAt: theme.listCompletedAt(now: now, calendar: calendar)
        )
    }

    /// Most lists the widgets are sent (the pinned one is always included).
    static let widgetListLimit = 20
    /// Most steps per list the widgets are sent (the large widget shows 14).
    static let widgetStepLimit = 30
    /// Most foods the widgets are sent.
    static let widgetFoodLimit = 60
    /// Foods further out than this aren't sent (widgets look at most a month ahead, plus the
    /// 8 days their timeline covers).
    static let widgetFoodDays = 40

    /// Saves snapshots of `themes` (in the order given) and asks the widget to redraw. Only
    /// what a widget can show is sent, so a huge list can't push the widget past its small
    /// memory limit.
    /// - Parameters:
    ///   - themes: every list, in display order.
    ///   - store: where to save it (the App Group by default).
    static func writeSnapshot(_ themes: [Theme], to store: UserDefaults = defaults) {
        if let data = try? JSONEncoder().encode(capped(themes.map { snapshot(of: $0) }, pinned: pinState(in: store).themeID)) {
            store.set(data, forKey: snapshotKey)
        }
        reloadWidgets()
    }

    /// The first `widgetListLimit` lists (plus the pinned one if it's further down), each
    /// trimmed to `widgetStepLimit` steps.
    /// - Parameters:
    ///   - snapshots: every list's snapshot, in order.
    ///   - pinned: the pinned list, if any.
    static func capped(_ snapshots: [ThemeSnapshot], pinned: UUID?) -> [ThemeSnapshot] {
        var kept = Array(snapshots.prefix(widgetListLimit))
        if let pinned, !kept.contains(where: { $0.id == pinned }),
           let pinnedList = snapshots.first(where: { $0.id == pinned }) {
            kept.append(pinnedList)
        }
        return kept.map { list in
            ThemeSnapshot(id: list.id, name: list.name, colorToken: list.colorToken,
                                    iconEmoji: list.iconEmoji, steps: Array(list.steps.prefix(widgetStepLimit)),
                                    iconToken: list.iconToken, recurrence: list.recurrence,
                                    completedAt: list.completedAt)
        }
    }

    /// Re-reads every theme from `context` (in display order) and rewrites the snapshot.
    /// Call after any edit that the widget should reflect.
    /// - Parameter context: the app's model context.
    static func refresh(from context: ModelContext) {
        let descriptor = FetchDescriptor<Theme>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let themes = try? context.fetch(descriptor) else { return }
        writeSnapshot(themes)
    }

    /// The saved snapshot, or nil if the app has never written one (fresh install).
    /// An empty array means the user really has no lists, so the widget says so instead
    /// of showing placeholders. Unreadable data also reads as empty.
    static func readSnapshotIfWritten(from store: UserDefaults = defaults) -> [ThemeSnapshot]? {
        guard let data = store.data(forKey: snapshotKey) else { return nil }
        return (try? JSONDecoder().decode([ThemeSnapshot].self, from: data)) ?? []
    }

    // MARK: Food

    /// The widget's copy of one food: name capped, no description (the widget never shows it).
    /// - Parameter item: the food.
    static func widgetSnapshot(of item: FoodItem) -> FoodSnapshot {
        let snap = item.snapshot
        return FoodSnapshot(id: snap.id, name: TextLimits.clamp(snap.name, to: TextLimits.name),
                            useBy: snap.useBy, storage: snap.storage, kinds: snap.kinds,
                            labels: snap.labels, details: nil, addedAt: snap.addedAt)
    }

    /// Saves snapshots of the foods widgets can show (due within `widgetFoodDays` or expired,
    /// soonest first, at most `widgetFoodLimit`) and asks them to redraw.
    /// - Parameters:
    ///   - items: every food.
    ///   - now: the moment of writing.
    ///   - store: where to save it (the App Group by default).
    static func writeFood(_ items: [FoodItem], now: Date = Date(), to store: UserDefaults = defaults) {
        let due = FoodQuery.useSoon(items.map(widgetSnapshot(of:)), now: now,
                                    lookAheadDays: widgetFoodDays, includeExpired: true)
        if let data = try? JSONEncoder().encode(Array(due.prefix(widgetFoodLimit))) {
            store.set(data, forKey: foodKey)
        }
        reloadWidgets()
    }

    /// Re-reads every food from `context` and rewrites the food snapshot.
    /// Call after any food edit.
    /// - Parameter context: the app's model context.
    static func refreshFood(from context: ModelContext) {
        guard let items = try? context.fetch(FetchDescriptor<FoodItem>()) else { return }
        writeFood(items)
    }

    /// Foods for the widgets. Empty until the Food tab writes them; unreadable data reads as empty.
    static func readFood(from store: UserDefaults = defaults) -> [FoodSnapshot] {
        guard let data = store.data(forKey: foodKey),
              let items = try? JSONDecoder().decode([FoodSnapshot].self, from: data)
        else { return [] }
        return items
    }
}

// MARK: - PinThemeIntent
/// "Show this list on the widget", as an App Intent (for Shortcuts). Shares state with the
/// app's tile pins via the App Group; the tile pin is the main way to switch.
struct PinThemeIntent: AppIntent {
    static let title: LocalizedStringResource = "Show List on Widget"
    static let isDiscoverable = false

    @Parameter(title: "List ID")
    var themeID: String

    init() {}
    /// - Parameter themeID: the theme's UUID string.
    init(themeID: String) { self.themeID = themeID }

    func perform() async throws -> some IntentResult {
        // A malformed id (stale or hand-made shortcut) must not silently unpin.
        guard let id = UUID(uuidString: themeID) else { return .result() }
        WidgetDataBridge.pin(id)
        return .result()
    }
}
