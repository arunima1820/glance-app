import XCTest
@testable import Glance

// MARK: - BundleResourceTests
// Covers: Glance/Resources/Info.plist (CFBundleIcons, CFBundleURLTypes), GlanceShared/Sources/Store/WidgetDataBridge.swift (GlanceLink.scheme)

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
}
