import XCTest
@testable import Glance

// MARK: - FreshnessTests
// Covers: GlanceShared/Sources/Logic/Freshness.swift (of(useBy:now:calendar:), label, spokenLabel).

final class FreshnessTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()
    private let now = Date(timeIntervalSince1970: 1_793_534_400)   // 2026-11-01 12:00 UTC

    private func freshness(inDays n: Int) -> Freshness {
        Freshness.of(useBy: now.addingTimeInterval(Double(n) * 86_400), now: now, calendar: calendar)
    }

    func testPastDateIsExpired() {
        XCTAssertEqual(freshness(inDays: -1), .expired)
        XCTAssertEqual(freshness(inDays: -1).label, "expired")
    }

    func testLaterTodayIsToday() {
        let lateTonight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23, minute: 59))!
        let f = Freshness.of(useBy: lateTonight, now: now, calendar: calendar)
        XCTAssertEqual(f, .days(0))
        XCTAssertEqual(f.label, "today")
    }

    func testTomorrowIsOneDay() {
        XCTAssertEqual(freshness(inDays: 1), .days(1))
        XCTAssertEqual(freshness(inDays: 1).label, "1 day")
    }

    func testFewDaysCountsDays() {
        XCTAssertEqual(freshness(inDays: 3), .days(3))
        XCTAssertEqual(freshness(inDays: 3).label, "3 days")
    }

    func testThirteenDaysStillCountsDays() {
        XCTAssertEqual(freshness(inDays: 13), .days(13))
        XCTAssertEqual(freshness(inDays: 13).label, "13 days")
    }

    func testTwoWeeksIsWeeks() {
        XCTAssertEqual(freshness(inDays: 14), .weeks)
        XCTAssertEqual(freshness(inDays: 14).label, "weeks")
    }

    func testNoDateIsNoneWithNoText() {
        let f = Freshness.of(useBy: nil, now: now, calendar: calendar)
        XCTAssertEqual(f, .none)
        XCTAssertEqual(f.label, "")
        XCTAssertEqual(f.spokenLabel, "no expiry date")
    }

    func testSpokenLabelsReadNaturally() {
        XCTAssertEqual(freshness(inDays: 0).spokenLabel, "use today")
        XCTAssertEqual(freshness(inDays: 2).spokenLabel, "use within 2 days")
        XCTAssertEqual(freshness(inDays: -3).spokenLabel, "expired")
        XCTAssertEqual(freshness(inDays: 20).spokenLabel, "good for weeks")
    }
}
