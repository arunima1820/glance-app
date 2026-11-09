import XCTest
@testable import Glance

// MARK: - FoodExpiryTests
// Covers: GlanceShared/Sources/Logic/FoodExpiry.swift (ExpiryMode, FoodExpiry).

final class FoodExpiryTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
    }

    func testInDaysCountsFromTheDayAdded() {
        XCTAssertEqual(FoodExpiry.useBy(inDays: 3, from: date(2, 22), calendar: calendar), date(5, 0))
        XCTAssertEqual(FoodExpiry.useBy(inDays: 0, from: date(2, 9), calendar: calendar), date(2, 0))
    }

    func testOnDateIsTheStartOfThatDay() {
        XCTAssertEqual(FoodExpiry.useBy(onDate: date(9, 17), calendar: calendar), date(9, 0))
    }

    func testDaysLabelsGrowFromDaysToWeeksToMonths() {
        XCTAssertEqual(FoodExpiry.daysLabel(0), "Today")
        XCTAssertEqual(FoodExpiry.daysLabel(1), "In 1 day")
        XCTAssertEqual(FoodExpiry.daysLabel(13), "In 13 days")
        XCTAssertEqual(FoodExpiry.daysLabel(14), "In 2 weeks")
        XCTAssertEqual(FoodExpiry.daysLabel(49), "In 7 weeks")
        XCTAssertEqual(FoodExpiry.daysLabel(60), "In 2 months")
        XCTAssertEqual(FoodExpiry.daysLabel(365), "In 1 year")
    }

    func testDaysThatArentWholeWeeksOrMonthsStayInDays() {
        XCTAssertEqual(FoodExpiry.daysLabel(30), "In 30 days")
        XCTAssertEqual(FoodExpiry.daysLabel(100), "In 100 days")
    }

    func testStepsGoUpAndDownThroughTheStops() {
        XCTAssertEqual(FoodExpiry.step(after: 3), 4)
        XCTAssertEqual(FoodExpiry.step(after: 13), 14)
        XCTAssertEqual(FoodExpiry.step(after: 14), 21)
        XCTAssertEqual(FoodExpiry.step(after: 49), 60)
        XCTAssertEqual(FoodExpiry.step(before: 60), 49)
        XCTAssertNil(FoodExpiry.step(after: 365))
        XCTAssertNil(FoodExpiry.step(before: 0))
    }

    func testStepsFromAnOffStopValueSnapToTheNearestStops() {
        XCTAssertEqual(FoodExpiry.step(after: 30), 35)
        XCTAssertEqual(FoodExpiry.step(before: 30), 28)
    }

    func testModeLabelsAndDefaults() {
        XCTAssertEqual(ExpiryMode.allCases.map(\.label), ["In a few days", "On a date"])
        XCTAssertTrue(FoodExpiry.steps.contains(FoodExpiry.defaultDays))
        XCTAssertEqual(FoodExpiry.steps, FoodExpiry.steps.sorted())
    }
}
