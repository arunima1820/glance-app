import XCTest
@testable import Glance

// MARK: - ThemeIconTests
// Covers: GlanceShared/Sources/Design/Palette.swift (ThemeIcon, ThemeIcons)

final class ThemeIconTests: XCTestCase {

    func testEveryIconHasSymbolAndName() {
        for icon in ThemeIcons.all {
            XCTAssertFalse(icon.systemName.isEmpty, "Icon '\(icon.id)' has no SF Symbol")
            XCTAssertFalse(icon.displayName.isEmpty, "Icon '\(icon.id)' has no displayName")
        }
    }

    func testIconIDsAreUnique() {
        let ids = ThemeIcons.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testUnknownTokenFallsBackToListBullet() {
        XCTAssertEqual(ThemeIcons.symbolName(for: "does-not-exist"), "list.bullet")
    }

    func testDefaultTokenIsInIconSet() {
        XCTAssertTrue(ThemeIcons.all.contains { $0.id == ThemeIcons.default })
    }
}
