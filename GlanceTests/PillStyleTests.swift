import XCTest
import SwiftUI
@testable import Glance

// MARK: - PillStyleTests
// Covers: GlanceShared/Sources/Design/FreshnessPill.swift (PillStyle.of(_:palette:dark:), isUrgent).

final class PillStyleTests: XCTestCase {

    private let paper = Palettes.fridgeMarker.light
    private let board = Palettes.fridgeMarker.dark

    func testOnlyExpiredAndTodayAreUrgent() {
        XCTAssertTrue(PillStyle.isUrgent(.expired))
        XCTAssertTrue(PillStyle.isUrgent(.days(0)))
        XCTAssertFalse(PillStyle.isUrgent(.days(1)))
        XCTAssertFalse(PillStyle.isUrgent(.weeks))
    }

    func testChalkboardUrgentPillsAreSolid() {
        let expired = PillStyle.of(.expired, palette: board, dark: true)
        XCTAssertEqual(expired, PillStyle(text: board.paper, fill: board.marker, outline: .clear))
        let today = PillStyle.of(.days(0), palette: board, dark: true)
        XCTAssertEqual(today, PillStyle(text: board.paper, fill: board.mustard, outline: .clear))
    }

    func testChalkboardCalmPillsAreOutlines() {
        XCTAssertEqual(PillStyle.of(.days(3), palette: board, dark: true),
                       PillStyle(text: board.mustard, fill: .clear, outline: board.mustard))
        XCTAssertEqual(PillStyle.of(.weeks, palette: board, dark: true),
                       PillStyle(text: board.avocado, fill: .clear, outline: board.avocado))
    }

    func testPaperPillsKeepDarkInkOnATint() {
        let style = PillStyle.of(.weeks, palette: paper, dark: false)
        XCTAssertEqual(style.text, paper.ink)
        XCTAssertEqual(style.outline, .clear)
    }
}
