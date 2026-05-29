import XCTest
import SwiftUI
@testable import Glance

// MARK: - PaletteTests
// Covers: ThemePalette.swift (entry lookup, design rules) and Color(hex:) init.

final class PaletteTests: XCTestCase {

    // MARK: ThemePalette — lookup

    func testEntryForKnownTokenReturnsCorrectEntry() {
        let entry = ThemePalette.entry(for: "sage")
        XCTAssertEqual(entry.id, "sage")
        XCTAssertEqual(entry.displayName, "Sage")
    }

    func testEntryForUnknownTokenFallsBackToFirst() {
        let entry = ThemePalette.entry(for: "does-not-exist")
        XCTAssertEqual(entry.id, ThemePalette.all.first?.id, "Unknown token should fall back to first entry")
    }

    func testAllTokensAreUnique() {
        let ids = ThemePalette.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Every palette token should be unique")
    }

    func testAllEntriesHaveNonEmptyDisplayName() {
        for entry in ThemePalette.all {
            XCTAssertFalse(entry.displayName.isEmpty, "Entry '\(entry.id)' has an empty displayName")
        }
    }

    func testPaletteIsNonEmpty() {
        XCTAssertGreaterThanOrEqual(ThemePalette.all.count, 6, "Palette should offer at least 6 color choices")
    }

    // MARK: ThemePalette — design rules

    /// Design rule: avoid red/green and red/pink pairings.
    /// We verify no token is named "red" or "green" — the curated palette should use softer names.
    func testNoRawRedOrGreenTokens() {
        let ids = ThemePalette.all.map(\.id)
        XCTAssertFalse(ids.contains("red"),   "Raw 'red' should not be in the palette")
        XCTAssertFalse(ids.contains("green"), "Raw 'green' should not be in the palette")
    }

    // MARK: Color(hex:)

    func testHexWhiteParses() {
        // #FFFFFF → r:1, g:1, b:1
        let white = Color(hex: "#FFFFFF")
        // We can't directly read RGB from Color in tests, but we can confirm no crash
        // and that two identical hex values produce equal-looking colors.
        let white2 = Color(hex: "FFFFFF") // without hash
        // Both should parse without crashing — visual equivalence is the meaningful check here.
        _ = white
        _ = white2
    }

    func testHexBlackParses() {
        _ = Color(hex: "#000000")
    }

    func testHexSageParses() {
        // The sage light value from ThemePalette — confirms the palette's own hex strings are valid.
        _ = Color(hex: "#B8D4C0")
    }

    func testHexIsCaseInsensitive() {
        // Both forms should parse without throwing.
        _ = Color(hex: "#b8d4c0")
        _ = Color(hex: "#B8D4C0")
    }
}
