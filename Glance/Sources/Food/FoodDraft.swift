import Foundation

// MARK: - FoodDraft
/// The New / Edit food form's working copy. Nothing touches the stored food until Save.
struct FoodDraft: Equatable {
    var name = ""
    var place: FoodStorage = .fridge
    /// What kind, in the order picked.
    var kinds: [FoodKind] = []
    /// Food labels, main first.
    var labels: [String] = []
    /// Once the user changes labels themselves, the name stops pre-ticking them.
    var labelsTouched = false
    /// Once the user changes Expires themselves, it stops following the food's type.
    var expiryTouched = false
    var mode: ExpiryMode = .inDays
    var days = FoodExpiry.defaultDays
    var date = Date()
    var details = ""

    init() {}

    /// A draft of an existing food. Its date shows as "On a date" (a day count would be
    /// ambiguous once days have passed). A food from an early build with no date starts on
    /// the days stepper with the typical time for it.
    /// - Parameter item: the food being edited.
    init(editing item: FoodItem) {
        name = item.name
        place = item.place
        kinds = item.kinds
        labels = item.labels
        labelsTouched = true
        expiryTouched = true
        details = item.details
        if let useBy = item.useBy {
            mode = .onDate
            date = useBy
        } else {
            expiryTouched = false
            suggestExpiry()
        }
    }

    /// Canned: the date reads as "Best by" and starts a year out.
    var isCanned: Bool { kinds.contains(.canned) }

    /// Ticks or unticks a kind chip.
    /// - Parameter title: the chip's label.
    mutating func toggleKind(titled title: String) {
        guard let kind = FoodKind.allCases.first(where: { $0.label == title }) else { return }
        if let index = kinds.firstIndex(of: kind) { kinds.remove(at: index) } else { kinds.append(kind) }
    }

    /// Pre-ticks Food labels from the name, until the user picks labels themselves.
    /// - Parameters:
    ///   - name: the name as typed.
    ///   - known: the user's own labels (built-ins are always included).
    mutating func suggestLabels(forName name: String, among known: [String]) {
        guard !labelsTouched else { return }
        let all = known + FoodLabels.builtIn.filter { !FoodLabels.contains(known, $0) }
        labels = FoodLabels.suggested(forName: name, among: all)
    }

    /// Sets the days stepper to a typical time for this food (Thaw → 2 days, Eggs → 3 weeks…),
    /// until the user sets Expires themselves.
    mutating func suggestExpiry() {
        guard !expiryTouched, mode == .inDays else { return }
        days = FoodShelfLife.suggestedDays(place: place, kinds: kinds, labels: labels) ?? FoodExpiry.defaultDays
    }

    /// The use-by day to store, always a real date: from the days stepper or the date picker.
    /// - Parameters:
    ///   - now: when it's saved ("in N days" counts from today).
    ///   - calendar: calendar for day math (injectable for tests).
    func useBy(now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch mode {
        case .inDays: return FoodExpiry.useBy(inDays: days, from: now, calendar: calendar)
        case .onDate: return FoodExpiry.useBy(onDate: date, calendar: calendar)
        }
    }

    /// Writes the draft into a food (text capped, at most three labels).
    /// - Parameters:
    ///   - item: the food to update.
    ///   - now: when it's saved.
    ///   - calendar: calendar for day math (injectable for tests).
    func apply(to item: FoodItem, now: Date = Date(), calendar: Calendar = .current) {
        item.name = TextLimits.clamp(name, to: TextLimits.name)
        item.details = TextLimits.clamp(details, to: TextLimits.note, allowsNewlines: true)
        item.place = place
        item.kinds = kinds
        item.labels = Array(labels.prefix(FoodLabels.maxPicked))
        item.useBy = useBy(now: now, calendar: calendar)
        item.updatedAt = now
    }
}
