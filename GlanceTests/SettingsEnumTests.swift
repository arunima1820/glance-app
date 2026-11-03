import XCTest
import SwiftUI
@testable import Glance

// MARK: - SettingsEnumTests
// Covers: Glance/Sources/Settings/SettingsView.swift (AppAppearance)

final class SettingsEnumTests: XCTestCase {

    func testAppearanceMapsToExpectedColorScheme() {
        let expected: [(AppAppearance, ColorScheme?)] = [
            (.system, nil),
            (.light, .light),
            (.dark, .dark),
        ]
        for (mode, scheme) in expected {
            XCTAssertEqual(mode.colorScheme, scheme, "AppAppearance.\(mode.rawValue)")
        }
    }

    func testEveryAppearanceHasNonEmptyLabel() {
        for mode in AppAppearance.allCases {
            XCTAssertFalse(mode.label.isEmpty, "AppAppearance.\(mode.rawValue) has empty label")
        }
    }

    func testAppearanceIDEqualsRawValueForAppStorage() {
        for mode in AppAppearance.allCases {
            XCTAssertEqual(mode.rawValue, mode.id)
        }
    }

    func testOnlyThreeAppearancesAreOffered() {
        XCTAssertEqual(AppAppearance.allCases, [.system, .light, .dark])
    }
}
