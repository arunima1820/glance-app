import Foundation

// MARK: - Recurrence
/// How often a list wipes clean. Pure value + date math (no SwiftData/UI), fully testable.
/// A list's ticks count until its next occurrence starts; a one-time list never resets.
struct Recurrence: Codable, Equatable, Sendable {

    /// The choices offered in the Edit sheet's "Resets" menu.
    enum Kind: String, Codable, CaseIterable, Sendable {
        case oneTime, daily, weekdays, weekends, weekly, monthly, everyNDays
    }

    var kind: Kind = .daily
    /// Calendar weekday numbers (1 = Sunday … 7 = Saturday) for `.weekly`.
    var weekdays: Set<Int> = []
    /// Day of the month for `.monthly` (clamped to the month's last day).
    var dayOfMonth: Int = 1
    /// Gap in days for `.everyNDays` (≥ 1).
    var interval: Int = 2
    /// Day the cycle counts from (for `.everyNDays`, and `.weekly` with no days chosen).
    var anchor: Date = Date(timeIntervalSinceReferenceDate: 0)

    /// Furthest we search for an occurrence (covers monthly and long custom gaps).
    private static let searchLimit = 400

    /// Whether the list comes round on the calendar day containing `day`.
    /// - Parameters:
    ///   - day: any moment in the day to test.
    ///   - calendar: calendar for weekday/day math.
    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: day)
        switch kind {
        case .oneTime:    return false
        case .daily:      return true
        case .weekdays:   return (2...6).contains(weekday)
        case .weekends:   return weekday == 1 || weekday == 7
        case .weekly:
            let days = weekdays.isEmpty ? [calendar.component(.weekday, from: anchor)] : weekdays
            return days.contains(weekday)
        case .monthly:    return isMonthlyDay(day, calendar: calendar)
        case .everyNDays: return isOnInterval(day, calendar: calendar)
        }
    }

    /// Start of the current period: midnight of the latest occurrence on or before `now`.
    /// Ticks stamped before this no longer count. One-time lists: distant past (never reset).
    func periodStart(atOrBefore now: Date, calendar: Calendar = .current) -> Date {
        var day = calendar.startOfDay(for: now)
        for _ in 0..<Self.searchLimit {
            if occurs(on: day, calendar: calendar) { return day }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return .distantPast
    }

    /// Midnight of the next occurrence strictly after today, or nil (one-time / none found).
    func nextStart(after now: Date, calendar: Calendar = .current) -> Date? {
        var day = calendar.startOfDay(for: now)
        for _ in 0..<Self.searchLimit {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = next
            if occurs(on: day, calendar: calendar) { return day }
        }
        return nil
    }

    /// Whether a tick stamped at `completedAt` still counts at `now`.
    func isStillComplete(_ completedAt: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard let completedAt else { return false }
        return completedAt >= periodStart(atOrBefore: now, calendar: calendar)
    }

    /// True for rules that come round at most every few days (weekly on 1–2 days, monthly,
    /// every 3+ days). Only these auto-pin to the widget; daily-ish rules (every day, weekdays,
    /// weekends, every 2 days, weekly on 3+ days) would otherwise grab it almost every morning.
    var isInfrequent: Bool {
        switch kind {
        case .weekly:     return weekdays.count <= 2
        case .monthly:    return true
        case .everyNDays: return interval >= 3
        default:          return false
        }
    }

    /// The footer under a list: when its ticks reset, in plain words.
    /// - Parameters:
    ///   - now: the reference moment.
    ///   - calendar: calendar (and locale / time zone) for the wording.
    func resetHint(now: Date, calendar: Calendar = .current) -> String {
        guard let next = nextStart(after: now, calendar: calendar) else {
            return "One-time list: ticks stay until you delete it."
        }
        return "Tap a step to cross it off. Resets " + Self.dayLabel(next, now: now, calendar: calendar) + "."
    }

    /// "tomorrow", a weekday within the next week ("Tue"), or a date further out ("Dec 1").
    /// - Parameters:
    ///   - date: the day to describe.
    ///   - now: the reference moment.
    ///   - calendar: calendar (and locale / time zone) for the wording.
    static func dayLabel(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
        if days == 1 { return "tomorrow" }
        let style = Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar,
                                     timeZone: calendar.timeZone)
        return days <= 6
            ? date.formatted(style.weekday(.abbreviated))
            : date.formatted(style.month(.abbreviated).day())
    }

    /// Short label for a rule, e.g. "Every weekday", "Weekly on Mon, Fri" (tests, accessibility).
    func summary(calendar: Calendar = .current) -> String {
        switch kind {
        case .oneTime:    return "One time"
        case .daily:      return "Every day"
        case .weekdays:   return "Every weekday"
        case .weekends:   return "Weekends"
        case .weekly:
            let names = weekdays.sorted().map { calendar.shortWeekdaySymbols[$0 - 1] }
            return names.isEmpty ? "Weekly" : "Weekly on " + names.joined(separator: ", ")
        case .monthly:    return "Monthly on day \(dayOfMonth)"
        case .everyNDays: return "Every \(max(interval, 1)) days"
        }
    }

    // MARK: Private

    private func isMonthlyDay(_ day: Date, calendar: Calendar) -> Bool {
        let dom = calendar.component(.day, from: day)
        let last = calendar.range(of: .day, in: .month, for: day)?.count ?? 31
        return dom == min(max(dayOfMonth, 1), last)   // e.g. "31st" lands on Feb 28/29
    }

    private func isOnInterval(_ day: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: anchor)
        let gap = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: day)).day ?? -1
        return gap >= 0 && gap % max(interval, 1) == 0
    }
}
