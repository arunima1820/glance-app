import XCTest
import SwiftUI
@testable import Glance

// MARK: - DesignConfigTests
// Covers: GlanceShared/Sources/Design/DesignConfig.swift, GlanceShared/Sources/Design/FeatureFlags.swift

@MainActor
final class DesignConfigTests: XCTestCase {

    func testDefaultsUseRegistryDefaultsAndDefaultFlags() {
        let config = DesignConfig()
        XCTAssertEqual(config.paletteSchemeID, Palettes.default)
        XCTAssertEqual(config.fontThemeID, FontThemes.default)
        XCTAssertEqual(config.flags, .default)
    }

    func testResolvesPaletteAndFontThemeFromIDs() {
        let config = DesignConfig()
        let scheme = Palettes.scheme(Palettes.default)
        XCTAssertEqual(config.palette(for: .light), scheme.light)
        XCTAssertEqual(config.palette(for: .dark), scheme.dark)
        XCTAssertEqual(config.fontTheme.id, FontThemes.default)
    }

    func testSwappingFontThemeIDSwapsResolvedTheme() {
        let config = DesignConfig()
        config.fontThemeID = .system
        XCTAssertEqual(config.fontTheme.id, .system)
        config.fontThemeID = .marker
        XCTAssertEqual(config.fontTheme.id, .marker)
    }

    func testInjectedFlagProviderSuppliesFlags() {
        var custom = FeatureFlags.default
        custom.defaultCompletionStyle = .perItem
        custom.survivalRecipesEnabled = true
        let config = DesignConfig(flagProvider: StaticFlags(custom))
        XCTAssertEqual(config.flags, custom)
    }

    func testDefaultFlagsMatchLockedDecisions() {
        let f = FeatureFlags.default
        XCTAssertEqual(f.defaultCompletionStyle, .sweep)
        XCTAssertTrue(f.themeIconsOnByDefault)
        XCTAssertTrue(f.groceriesTabVisible)
        XCTAssertFalse(f.survivalRecipesEnabled, "Survival recipes are v2 — off by default")
        XCTAssertFalse(f.cameraFoodEnabled, "Camera food is v2 — off by default")
    }
}
