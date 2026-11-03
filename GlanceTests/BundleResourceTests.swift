import XCTest
@testable import Glance

// MARK: - BundleResourceTests
// Covers: Glance/Resources/Info.plist (CFBundleIcons, CFBundleURLTypes, orientations), PrivacyInfo.xcprivacy, GlanceShared/Sources/Store/WidgetDataBridge.swift (GlanceLink.scheme)

final class BundleResourceTests: XCTestCase {

    func testAppIconIsDeclaredInInfoPlist() {
        let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        XCTAssertEqual(primary?["CFBundleIconName"] as? String, "AppIcon")
    }

    func testInfoPlistRegistersGlanceURLScheme() {
        let types = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        XCTAssertTrue(schemes.contains("glance"), "Registered URL schemes: \(schemes)")
        XCTAssertEqual(GlanceLink.scheme, "glance")
    }

    func testAppIsPortraitOnlyOnEveryDevice() {
        // iOS resolves device-specific (~ipad) keys into the base key at runtime, so the base
        // key is what this device actually uses.
        let orientations = Bundle.main.infoDictionary?["UISupportedInterfaceOrientations"] as? [String]
        XCTAssertEqual(orientations, ["UIInterfaceOrientationPortrait"])
    }

    func testPrivacyManifestShipsInApp() {
        XCTAssertNotNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
                        "App Store requires PrivacyInfo.xcprivacy (UserDefaults reasons)")
    }
}

