import XCTest
import SwiftUI
@testable import Glance

// MARK: - CategoryPaletteTests
// Covers: CategoryPalette.swift — lookup behaviour and palette integrity.

final class CategoryPaletteTests: XCTestCase {

    func testEntryForKnownTokenReturnsCorrectEntry() {
        let entry = CategoryPalette.entry(for: "red")
        XCTAssertEqual(entry.id, "red")
        XCTAssertEqual(entry.displayName, "Red")
    }

    func testEntryForUnknownTokenFallsBackToFirst() {
        let entry = CategoryPalette.entry(for: "not-a-color")
        XCTAssertEqual(entry.id, CategoryPalette.all.first?.id)
    }

    func testAllTokensAreUnique() {
        let ids = CategoryPalette.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Every category color token should be unique")
    }

    func testEveryEntryHasNonEmptyDisplayName() {
        for entry in CategoryPalette.all {
            XCTAssertFalse(entry.displayName.isEmpty, "Entry '\(entry.id)' has an empty displayName")
        }
    }

    func testPaletteOffersAnElaborateRange() {
        // The user asked for "clear and elaborate" color-coding — expect a broad set.
        XCTAssertGreaterThanOrEqual(CategoryPalette.all.count, 10)
    }

    func testRedIsAvailableForUrgent() {
        // Red = "Urgent" is the user's own example; it must exist in the palette.
        XCTAssertTrue(CategoryPalette.all.contains { $0.id == "red" })
    }
}
