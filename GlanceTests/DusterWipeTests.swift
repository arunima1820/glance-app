import XCTest
@testable import Glance

// MARK: - DusterWipeTests
// Covers: Glance/Sources/Views/DusterWipe.swift (DusterWipe.stops, duration).

final class DusterWipeTests: XCTestCase {

    func testZigzagGoesDownTheAreaAndBackAndForth() {
        let stops = DusterWipe.stops
        XCTAssertEqual(stops.map(\.y), stops.map(\.y).sorted(), "each stroke moves down")
        for i in 1..<stops.count {
            XCTAssertNotEqual(stops[i].x > 0.5, stops[i - 1].x > 0.5, "stroke \(i) changes side")
        }
    }

    func testStartsAndEndsOffTheArea() {
        XCTAssertLessThan(DusterWipe.stops.first!.x, 0)
        XCTAssertGreaterThan(DusterWipe.stops.last!.x, 1)
    }

    func testWipeIsShort() {
        XCTAssertLessThanOrEqual(DusterWipe.duration, 1.2)
    }
}
