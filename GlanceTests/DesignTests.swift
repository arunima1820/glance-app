import XCTest
import SwiftUI
@testable import Glance

// MARK: - DesignTests
// Covers: Palette.swift, FontTheme.swift, FeatureFlags.swift, DesignConfig.swift —
// the swappable design layer. Verifies every registry entry resolves and that the
// config exposes palette/fonts/flags so experiments can swap them wholesale.

@MainActor
final class DesignTests: XCTestCase {

    // MARK: Palette registry

    func testEveryPaletteSchemeIDResolves() {
        for id in PaletteSchemeID.allCases {
            XCTAssertEqual(Palettes.scheme(id).id, id, "Scheme \(id) must resolve to itself")
        }
    }

    func testDefaultSchemeExists() {
        XCTAssertEqual(Palettes.scheme(Palettes.default).id, .fridgeMarker)
    }

    func testLightAndDarkPalettesDiffer() {
        let scheme = Palettes.scheme(.fridgeMarker)
        XCTAssertNotEqual(scheme.palette(for: .light), scheme.palette(for: .dark),
                          "Light and dark palettes should not be identical")
    }

    func testPaletteForResolvesByColorScheme() {
        let scheme = Palettes.scheme(.fridgeMarker)
        XCTAssertEqual(scheme.palette(for: .light), scheme.light)
        XCTAssertEqual(scheme.palette(for: .dark), scheme.dark)
    }

    // MARK: Font themes

    func testEveryFontThemeIDResolves() {
        for id in FontThemeID.allCases {
            XCTAssertEqual(FontThemes.theme(id).id, id)
        }
    }

    func testEveryFontThemeProvidesAllRoles() {
        let roles: [FontRole] = [.appTitle, .screenTitle, .rowLead, .rowBody, .cardTitle, .caption, .button]
        for id in FontThemeID.allCases {
            let theme = FontThemes.theme(id)
            for role in roles {
                // Calling must not trap; Font isn't Equatable, so existence is the check.
                _ = theme.font(role)
            }
            XCTAssertFalse(theme.displayName.isEmpty)
        }
    }

    func testMarkerFamilyIsSet() {
        XCTAssertEqual(MarkerFontTheme.markerFamily, "PermanentMarker-Regular")
    }

    // MARK: Feature flags

    func testDefaultFlagsMatchLockedDecisions() {
        let f = FeatureFlags.default
        XCTAssertEqual(f.defaultCompletionStyle, .sweep)
        XCTAssertTrue(f.themeIconsOnByDefault)
        XCTAssertTrue(f.groceriesTabVisible)
        XCTAssertFalse(f.survivalRecipesEnabled, "Survival recipes are v2 — off by default")
        XCTAssertFalse(f.cameraFoodEnabled, "Camera food is v2 — off by default")
    }

    func testStaticFlagProviderPassesThrough() {
        var custom = FeatureFlags.default
        custom.survivalRecipesEnabled = true
        XCTAssertTrue(StaticFlags(custom).flags.survivalRecipesEnabled)
    }

    // MARK: DesignConfig

    func testDesignConfigDefaults() {
        let config = DesignConfig()
        XCTAssertEqual(config.paletteSchemeID, Palettes.default)
        XCTAssertEqual(config.fontThemeID, FontThemes.default)
        XCTAssertEqual(config.flags, .default)
    }

    func testDesignConfigResolvesPaletteAndFont() {
        let config = DesignConfig()
        XCTAssertEqual(config.palette(for: .dark), Palettes.scheme(.fridgeMarker).dark)
        XCTAssertEqual(config.fontTheme.id, .marker)
    }

    func testDesignConfigIsSwappable() {
        let config = DesignConfig()
        config.fontThemeID = .system
        XCTAssertEqual(config.fontTheme.id, .system, "Swapping the id must swap the resolved theme")
    }
}

// MARK: - ThemeIconTests
// Covers: ThemeIcon / ThemeIcons registry and starter themes' icon tokens.

final class ThemeIconTests: XCTestCase {

    func testEveryIconHasASymbol() {
        for icon in ThemeIcons.all {
            XCTAssertFalse(icon.systemName.isEmpty, "Icon '\(icon.id)' has no SF Symbol")
            XCTAssertFalse(icon.displayName.isEmpty)
        }
    }

    func testIconIdsAreUnique() {
        let ids = ThemeIcons.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testUnknownTokenFallsBackToList() {
        XCTAssertEqual(ThemeIcons.symbolName(for: "does-not-exist"), "list.bullet")
    }

    func testDefaultTokenResolves() {
        XCTAssertFalse(ThemeIcons.symbolName(for: ThemeIcons.default).isEmpty)
        XCTAssertTrue(ThemeIcons.all.contains { $0.id == ThemeIcons.default })
    }

    func testStarterThemesUseValidIconTokens() {
        let valid = Set(ThemeIcons.all.map(\.id))
        for theme in StarterTemplates.all() {
            XCTAssertTrue(valid.contains(theme.iconToken),
                          "Starter '\(theme.name)' has unknown iconToken '\(theme.iconToken)'")
        }
    }
}
