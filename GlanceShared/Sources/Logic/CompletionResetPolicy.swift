import Foundation

// MARK: - CompletionResetPolicy
/// Pure date logic for the "nothing stays done forever" rule: routines repeat, so a
/// completion from a previous day is considered cleared. Kept free of SwiftData/UI so
/// it is fully unit-testable in isolation.
enum CompletionResetPolicy {

    /// Whether a completion stamped at `completedAt` still counts as done relative to `now`.
    /// A completion counts only if it happened on the same calendar day as `now`.
    /// - Parameters:
    ///   - completedAt: when the item was completed, or nil if never.
    ///   - now: the reference moment.
    ///   - calendar: calendar used for the day comparison (injectable for tests).
    /// - Returns: true if still complete today; false if never completed or completed on an earlier day.
    static func isStillComplete(
        completedAt: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let completedAt else { return false }
        // Same calendar day → still counts; any earlier day → reset.
        return calendar.isDate(completedAt, inSameDayAs: now)
    }

    /// Whether a whole-list sweep stamped at `sweptAt` is still in effect relative to `now`.
    /// Same rule as items: a sweep only holds for the calendar day it happened on.
    static func isSweepActive(
        sweptAt: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        isStillComplete(completedAt: sweptAt, now: now, calendar: calendar)
    }
}
