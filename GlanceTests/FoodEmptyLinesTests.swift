import XCTest
@testable import Glance

// MARK: - FoodEmptyLinesTests
// Covers: GlanceShared/Sources/Logic/FoodQuery.swift (FoodEmptyLines, EmptyLine).

final class FoodEmptyLinesTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ d: Int, _ h: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
    }

    func testWidgetLineIsCalm() {
        XCTAssertEqual(FoodEmptyLines.calm.title, "Nothing to use up")
        XCTAssertEqual(FoodEmptyLines.calm.message, "Nice. Your fridge is calm.")
    }

    func testSameLineAllDay() {
        XCTAssertEqual(FoodEmptyLines.ofTheDay(date(4, 0), calendar: calendar),
                       FoodEmptyLines.ofTheDay(date(4, 23), calendar: calendar))
    }

    func testThreeDaysShowEveryFunnyLineOnce() {
        let lines = (4...6).map { FoodEmptyLines.ofTheDay(date($0, 12), calendar: calendar) }
        XCTAssertEqual(Set(lines.map(\.title)).count, FoodEmptyLines.funny.count)
        XCTAssertEqual(FoodEmptyLines.ofTheDay(date(7, 12), calendar: calendar), lines[0])
    }
}
