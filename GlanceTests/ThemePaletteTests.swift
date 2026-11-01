import XCTest
@testable import Glance

// MARK: - ThemePaletteTests
// Covers: GlanceShared/Sources/Models/ThemePalette.swift (ThemePalette)

final class ThemePaletteTests: XCTestCase {

    func testKnownTokenReturnsMatchingEntry() {
        let entry = ThemePalette.entry(for: "sage")
        XCTAssertEqual(entry.id, "sage")
        XCTAssertEqual(entry.displayName, "Sage")
    }

    func testUnknownTokenFallsBackToFirstEntry() {
        XCTAssertEqual(ThemePalette.entry(for: "does-not-exist").id, ThemePalette.all.first?.id)
    }

    func testTokensAreUnique() {
        let ids = ThemePalette.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryEntryHasDisplayName() {
        for entry in ThemePalette.all {
            XCTAssertFalse(entry.displayName.isEmpty, "Entry '\(entry.id)' has an empty displayName")
        }
    }

    func testPaletteOffersAtLeastSixColors() {
        XCTAssertGreaterThanOrEqual(ThemePalette.all.count, 6)
    }
}
