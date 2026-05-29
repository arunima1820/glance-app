import XCTest
import SwiftUI
@testable import Glance

// MARK: - AssetCatalogTests
// Verifies that every named color and image used in GlanceDesignSystem
// is present and resolvable from the main bundle's asset catalog.
// These tests catch "No color named X found" crashes at build/test time
// rather than at runtime on a user's device.

final class AssetCatalogTests: XCTestCase {

    // MARK: Named colors

    /// Every color token referenced in GlanceColors must exist in Assets.xcassets.
    func testGlanceBackgroundExists() {
        XCTAssertNotNil(
            UIColor(named: "GlanceBackground"),
            "GlanceBackground not found in asset catalog"
        )
    }

    func testGlanceSurfaceExists() {
        XCTAssertNotNil(
            UIColor(named: "GlanceSurface"),
            "GlanceSurface not found in asset catalog"
        )
    }

    func testGlancePrimaryTextExists() {
        XCTAssertNotNil(
            UIColor(named: "GlancePrimaryText"),
            "GlancePrimaryText not found in asset catalog"
        )
    }

    func testGlanceSecondaryTextExists() {
        XCTAssertNotNil(
            UIColor(named: "GlanceSecondaryText"),
            "GlanceSecondaryText not found in asset catalog"
        )
    }

    func testGlanceAccentExists() {
        XCTAssertNotNil(
            UIColor(named: "GlanceAccent"),
            "GlanceAccent not found in asset catalog"
        )
    }

    func testGlanceBulletDotExists() {
        XCTAssertNotNil(
            UIColor(named: "GlanceBulletDot"),
            "GlanceBulletDot not found in asset catalog"
        )
    }

    /// Convenience: run all color names in one loop so a single failure lists every missing name.
    func testAllGlanceColorsExist() {
        let required = [
            "GlanceBackground",
            "GlanceSurface",
            "GlancePrimaryText",
            "GlanceSecondaryText",
            "GlanceAccent",
            "GlanceBulletDot",
        ]
        for name in required {
            XCTAssertNotNil(
                UIColor(named: name),
                "Missing named color '\(name)' in asset catalog"
            )
        }
    }

    // MARK: Dark-mode variants

    /// Each color should have a dark-mode variant defined (not just fall back to light).
    func testColorsHaveDarkModeVariant() {
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)

        let names = [
            "GlanceBackground",
            "GlancePrimaryText",
            "GlanceSecondaryText",
        ]
        for name in names {
            guard let color = UIColor(named: name) else {
                XCTFail("Color '\(name)' missing entirely")
                continue
            }
            let dark  = color.resolvedColor(with: darkTraits)
            let light = color.resolvedColor(with: lightTraits)
            XCTAssertNotEqual(
                dark, light,
                "'\(name)' should differ between light and dark mode"
            )
        }
    }

    // MARK: App icon

    func testAppIconExistsInBundle() {
        // UIImage(named:"AppIcon") is blocked by iOS for the primary app icon.
        // Instead verify the icon file is declared in the bundle's Info.plist,
        // which means it was compiled from the asset catalog.
        let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let iconName = primary?["CFBundleIconName"] as? String
        XCTAssertEqual(iconName, "AppIcon", "CFBundleIconName should be 'AppIcon' in Info.plist")
    }
}
