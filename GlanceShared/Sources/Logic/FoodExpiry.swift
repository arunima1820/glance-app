import Foundation

// MARK: - ExpiryMode
/// How the user sets a use-by date: a number of days from when it's added, or a calendar date.
enum ExpiryMode: String, CaseIterable, Identifiable, Sendable {
    case inDays, onDate

    var id: String { rawValue }

    /// The "Expires" menu wording.
    var label: String {
        switch self {
        case .inDays: return "In a few days"
        case .onDate: return "On a date"
        }
    }
}

// MARK: - FoodExpiry
/// Turns the "Expires" row into a stored use-by day (always the start of a day).
enum FoodExpiry {
    /// The days stepper's stops: every day for two weeks, then weekly to 7 weeks, then
    /// monthly, up to a year. So short dates are precise and long ones take few taps.
    static let steps: [Int] = Array(0...13) + [14, 21, 28, 35, 42, 49] + [60, 90, 120, 150, 180, 270, 365]
    /// The days a new food starts with when nothing better is known.
    static let defaultDays = 3

    /// The next stop up from `days`, or nil at the top.
    static func step(after days: Int) -> Int? { steps.first { $0 > days } }

    /// The next stop down from `days`, or nil at the bottom.
    static func step(before days: Int) -> Int? { steps.last { $0 < days } }

    /// "In N days" counts from the day the food was added.
    /// - Parameters:
    ///   - days: days after that day.
    ///   - added: when it was added.
    ///   - calendar: calendar for day math (injectable for tests).
    static func useBy(inDays days: Int, from added: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: added)
        return calendar.date(byAdding: .day, value: days, to: start) ?? start
    }

    /// A picked calendar date, as the start of that day.
    /// - Parameters:
    ///   - date: the picked date.
    ///   - calendar: calendar for day math (injectable for tests).
    static func useBy(onDate date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// The stepper's wording, in the biggest unit that's exact: "Today", "In 3 days",
    /// "In 3 weeks", "In 2 months", "In 1 year" (else days, e.g. "In 30 days").
    /// - Parameter days: days from now.
    static func daysLabel(_ days: Int) -> String {
        switch days {
        case ...0: return "Today"
        case 365: return "In 1 year"
        case 60... where days % 30 == 0: return "In \(days / 30) months"
        case 14..<60 where days % 7 == 0: return "In \(days / 7) weeks"
        case 1: return "In 1 day"
        default: return "In \(days) days"
        }
    }
}
