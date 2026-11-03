import XCTest
@testable import Glance

// MARK: - RecurrenceTests
// Covers: Recurrence.swift (Recurrence.occurs, periodStart, nextStart, isStillComplete, summary).

final class RecurrenceTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }()

    private let newYork: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }()

    /// UTC date helper. 2026-11-02 is a Monday.
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func nyDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        newYork.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: Daily

    func testDailyPeriodIsToday() {
        let r = Recurrence(kind: .daily)
        XCTAssertEqual(r.periodStart(atOrBefore: date(2026, 11, 4), calendar: calendar), date(2026, 11, 4, 0))
    }

    func testDailyIsStillCompleteOnlyWithinTheSameDay() {
        let r = Recurrence(kind: .daily)
        XCTAssertFalse(r.isStillComplete(nil, now: date(2026, 11, 4), calendar: calendar))
        XCTAssertTrue(r.isStillComplete(date(2026, 11, 4, 8), now: date(2026, 11, 4, 22), calendar: calendar))
        XCTAssertFalse(r.isStillComplete(date(2026, 11, 4, 23), now: date(2026, 11, 5, 1), calendar: calendar))
    }

    func testDailyPeriodStartsAtLocalMidnightAcrossDST() {
        let r = Recurrence(kind: .daily)
        XCTAssertEqual(r.periodStart(atOrBefore: nyDate(2026, 11, 1, 15), calendar: newYork),
                       nyDate(2026, 11, 1, 0), "Fall back")
        XCTAssertTrue(r.isStillComplete(nyDate(2026, 11, 1, 0, 30), now: nyDate(2026, 11, 1, 23, 30), calendar: newYork))
        XCTAssertFalse(r.isStillComplete(nyDate(2026, 10, 31, 23, 30), now: nyDate(2026, 11, 1, 0, 30), calendar: newYork))

        XCTAssertEqual(r.periodStart(atOrBefore: nyDate(2027, 3, 14, 12), calendar: newYork),
                       nyDate(2027, 3, 14, 0), "Spring forward")
        XCTAssertTrue(r.isStillComplete(nyDate(2027, 3, 14, 0, 30), now: nyDate(2027, 3, 14, 23, 30), calendar: newYork))
        XCTAssertFalse(r.isStillComplete(nyDate(2027, 3, 14, 23, 30), now: nyDate(2027, 3, 15, 0, 30), calendar: newYork))
    }

    // MARK: Weekly

    func testWeeklyTickCarriesAllWeek() {
        let r = Recurrence(kind: .weekly, weekdays: [2])
        let monday = date(2026, 11, 2, 9)
        XCTAssertTrue(r.isStillComplete(monday, now: date(2026, 11, 6), calendar: calendar), "Friday: still done")
        XCTAssertFalse(r.isStillComplete(monday, now: date(2026, 11, 9), calendar: calendar), "Next Monday: reset")
    }

    func testWeeklyWithNoDaysFallsBackToAnchorWeekday() {
        let r = Recurrence(kind: .weekly, weekdays: [], anchor: date(2026, 11, 4))
        XCTAssertTrue(r.occurs(on: date(2026, 11, 11), calendar: calendar), "Wednesday, like the anchor")
        XCTAssertFalse(r.occurs(on: date(2026, 11, 12), calendar: calendar), "Thursday")
    }

    // MARK: Weekdays / weekends

    func testWeekdaysSkipWeekend() {
        let r = Recurrence(kind: .weekdays)
        XCTAssertTrue(r.occurs(on: date(2026, 11, 9), calendar: calendar), "Monday")
        XCTAssertFalse(r.occurs(on: date(2026, 11, 7), calendar: calendar), "Saturday")
        XCTAssertEqual(r.nextStart(after: date(2026, 11, 6), calendar: calendar), date(2026, 11, 9, 0),
                       "After Friday comes Monday")
    }

    func testWeekendsOnlyWeekend() {
        let r = Recurrence(kind: .weekends)
        XCTAssertTrue(r.occurs(on: date(2026, 11, 8), calendar: calendar), "Sunday")
        XCTAssertFalse(r.occurs(on: date(2026, 11, 9), calendar: calendar), "Monday")
    }

    // MARK: Monthly

    func testMonthlyClampsToShortMonth() {
        let r = Recurrence(kind: .monthly, dayOfMonth: 31)
        XCTAssertTrue(r.occurs(on: date(2027, 2, 28), calendar: calendar), "31st falls on Feb 28")
        XCTAssertFalse(r.occurs(on: date(2027, 3, 30), calendar: calendar))
    }

    func testMonthlyDay29HandlesLeapYears() {
        let r = Recurrence(kind: .monthly, dayOfMonth: 29)
        XCTAssertTrue(r.occurs(on: date(2028, 2, 29), calendar: calendar), "Leap year")
        XCTAssertFalse(r.occurs(on: date(2028, 2, 28), calendar: calendar))
        XCTAssertTrue(r.occurs(on: date(2027, 2, 28), calendar: calendar), "Clamped in a common year")
    }

    func testMonthlyDayZeroClampsToFirst() {
        let r = Recurrence(kind: .monthly, dayOfMonth: 0)
        XCTAssertTrue(r.occurs(on: date(2026, 12, 1), calendar: calendar))
        XCTAssertFalse(r.occurs(on: date(2026, 12, 31), calendar: calendar))
    }

    func testMonthlyNextStartIsNextMonthsDay() {
        let r = Recurrence(kind: .monthly, dayOfMonth: 15)
        XCTAssertEqual(r.nextStart(after: date(2026, 11, 20), calendar: calendar), date(2026, 12, 15, 0))
    }

    // MARK: Every N days

    func testEveryNDaysCountsFromAnchor() {
        let r = Recurrence(kind: .everyNDays, interval: 3, anchor: date(2026, 11, 1))
        XCTAssertTrue(r.occurs(on: date(2026, 11, 4), calendar: calendar))
        XCTAssertFalse(r.occurs(on: date(2026, 11, 5), calendar: calendar))
    }

    func testEveryNDaysDoesNotOccurBeforeAnchor() {
        let r = Recurrence(kind: .everyNDays, interval: 2, anchor: date(2026, 11, 10))
        XCTAssertFalse(r.occurs(on: date(2026, 11, 8), calendar: calendar))
    }

    func testEveryNDaysIntervalZeroActsAsOne() {
        let r = Recurrence(kind: .everyNDays, interval: 0, anchor: date(2026, 11, 1))
        XCTAssertTrue(r.occurs(on: date(2026, 11, 2), calendar: calendar))
        XCTAssertTrue(r.occurs(on: date(2026, 11, 3), calendar: calendar))
    }

    func testEveryNDaysNextStartSkipsToNextCycleDay() {
        let r = Recurrence(kind: .everyNDays, interval: 3, anchor: date(2026, 11, 1))
        XCTAssertEqual(r.nextStart(after: date(2026, 11, 2), calendar: calendar), date(2026, 11, 4, 0))
        XCTAssertEqual(r.nextStart(after: date(2026, 11, 4), calendar: calendar), date(2026, 11, 7, 0))
    }

    // MARK: One time

    func testOneTimeNeverResets() {
        let r = Recurrence(kind: .oneTime)
        XCTAssertTrue(r.isStillComplete(date(2026, 1, 1), now: date(2026, 12, 31), calendar: calendar))
        XCTAssertNil(r.nextStart(after: date(2026, 11, 1), calendar: calendar))
    }

    // MARK: Summary

    func testSummaryLabelsForEveryKind() {
        XCTAssertEqual(Recurrence(kind: .oneTime).summary(calendar: calendar), "One time")
        XCTAssertEqual(Recurrence(kind: .daily).summary(calendar: calendar), "Every day")
        XCTAssertEqual(Recurrence(kind: .weekdays).summary(calendar: calendar), "Every weekday")
        XCTAssertEqual(Recurrence(kind: .weekends).summary(calendar: calendar), "Weekends")
        XCTAssertEqual(Recurrence(kind: .weekly).summary(calendar: calendar), "Weekly")
        XCTAssertEqual(Recurrence(kind: .weekly, weekdays: [2, 6]).summary(calendar: calendar), "Weekly on Mon, Fri")
        XCTAssertEqual(Recurrence(kind: .monthly, dayOfMonth: 5).summary(calendar: calendar), "Monthly on day 5")
        XCTAssertEqual(Recurrence(kind: .everyNDays, interval: 3).summary(calendar: calendar), "Every 3 days")
    }

    // MARK: Auto-pin eligibility and wording

    func testInfrequentRules() {
        XCTAssertTrue(Recurrence(kind: .weekly, weekdays: [2]).isInfrequent)
        XCTAssertTrue(Recurrence(kind: .monthly).isInfrequent)
        XCTAssertTrue(Recurrence(kind: .everyNDays, interval: 3).isInfrequent)
        XCTAssertFalse(Recurrence(kind: .weekdays).isInfrequent)
        XCTAssertFalse(Recurrence(kind: .everyNDays, interval: 2).isInfrequent)
        XCTAssertFalse(Recurrence(kind: .oneTime).isInfrequent)
    }

    func testDayLabelSaysTomorrowThenWeekdayThenDate() {
        let now = date(2026, 11, 2)
        XCTAssertEqual(Recurrence.dayLabel(date(2026, 11, 3, 0), now: now, calendar: calendar), "tomorrow")
        XCTAssertEqual(Recurrence.dayLabel(date(2026, 11, 5, 0), now: now, calendar: calendar), "Thu")
        XCTAssertEqual(Recurrence.dayLabel(date(2026, 11, 20, 0), now: now, calendar: calendar), "Nov 20")
    }

    func testResetHintMatchesTheRule() {
        let now = date(2026, 11, 2)
        XCTAssertEqual(Recurrence(kind: .daily).resetHint(now: now, calendar: calendar),
                       "Tap a step to cross it off. Resets tomorrow.")
        XCTAssertEqual(Recurrence(kind: .oneTime).resetHint(now: now, calendar: calendar),
                       "One-time list: ticks stay until you delete it.")
    }
}
