import Foundation

// MARK: - Freshness
/// The freshness pill: "expired" / "today" / "N days" / "weeks", or nothing (canned, no date).
/// Text is always shown with the colour, so colour is never the only signal.
enum Freshness: Equatable, Sendable {
    case expired
    case days(Int)
    case weeks
    /// No use-by date (e.g. canned): no pill at all.
    case none

    /// Classifies a use-by date relative to today (calendar days, not hours).
    /// - Parameters:
    ///   - useBy: the item's use-by date, or nil when it has none.
    ///   - now: the reference moment.
    ///   - calendar: calendar for the day count (injectable for tests).
    static func of(useBy: Date?, now: Date = Date(), calendar: Calendar = .current) -> Freshness {
        guard let useBy else { return .none }
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: useBy)
        let left = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        if left < 0 { return .expired }
        return left >= 14 ? .weeks : .days(left)
    }

    /// Pill text (empty for `.none`).
    var label: String {
        switch self {
        case .expired: return "expired"
        case .days(0): return "today"
        case .days(1): return "1 day"
        case .days(let n): return "\(n) days"
        case .weeks: return "weeks"
        case .none: return ""
        }
    }

    /// What VoiceOver says for the pill.
    var spokenLabel: String {
        switch self {
        case .expired: return "expired"
        case .days(0): return "use today"
        case .days(1): return "use within 1 day"
        case .days(let n): return "use within \(n) days"
        case .weeks: return "good for weeks"
        case .none: return "no expiry date"
        }
    }
}
