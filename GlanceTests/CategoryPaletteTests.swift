import XCTest
@testable import Glance

// MARK: - CategoryPaletteTests
// Covers: GlanceShared/Sources/Models/CategoryPalette.swift (CategoryPalette)

final class CategoryPaletteTests: XCTestCase {

    func testRedTokenIsAvailableAndReturnsRedEntry() {
        XCTAssertTrue(CategoryPalette.all.contains { $0.id == "red" }, "Red (\"Urgent\") must be offered")
        let entry = CategoryPalette.entry(for: "red")
        XCTAssertEqual(entry.id, "red")
        XCTAssertEqual(entry.displayName, "Red")
    }

    func testUnknownTokenFallsBackToFirstEntry() {
        XCTAssertEqual(CategoryPalette.entry(for: "not-a-color").id, CategoryPalette.all.first?.id)
    }

    func testTokensAreUnique() {
        let ids = CategoryPalette.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryEntryHasDisplayName() {
        for entry in CategoryPalette.all {
            XCTAssertFalse(entry.displayName.isEmpty, "Entry '\(entry.id)' has an empty displayName")
        }
    }

    func testPaletteOffersAtLeastTenColors() {
        XCTAssertGreaterThanOrEqual(CategoryPalette.all.count, 10)
    }
}
