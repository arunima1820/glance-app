import XCTest
@testable import Glance

// MARK: - MarkerDotsTests
// Covers: Glance/Sources/Views/MarkerDots.swift (MarkerDots.dots, duration).

final class MarkerDotsTests: XCTestCase {

    func testDotsFanOutUpAndToBothSides() {
        let dots = MarkerDots.dots
        XCTAssertGreaterThanOrEqual(dots.count, 5)
        XCTAssertTrue(dots.contains { $0.dx < 0 } && dots.contains { $0.dx > 0 }, "both sides")
        XCTAssertTrue(dots.allSatisfy { $0.dy <= 0 }, "never down over the list")
    }

    func testEveryColourIsUsedAndBurstIsShort() {
        XCTAssertEqual(Set(MarkerDots.dots.map(\.tone)).count, 4)
        XCTAssertLessThanOrEqual(MarkerDots.duration, 1)
    }
}
