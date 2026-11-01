import XCTest
import UIKit
@testable import Glance

// MARK: - FontThemeTests
// Covers: GlanceShared/Sources/Design/FontTheme.swift (FontThemes, BundledFont, MarkerFontTheme faces), GlanceShared/Sources/Store/WidgetDataBridge.swift (fontThemeID(in:)),
// Glance/Resources/Info.plist and GlanceWidgetExtension/Info.plist (UIAppFonts)

final class FontThemeTests: XCTestCase {

    private var suiteName: String!
    private var store: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "glance.tests.\(UUID().uuidString)"
        store = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        store.removePersistentDomain(forName: suiteName)
        store = nil
        suiteName = nil
        super.tearDown()
    }

    func testEveryFontThemeIDResolvesWithDisplayName() {
        for id in FontThemeID.allCases {
            let theme = FontThemes.theme(id)
            XCTAssertEqual(theme.id, id)
            XCTAssertFalse(theme.displayName.isEmpty, "Font theme \(id) has no displayName")
        }
    }

    func testEveryBundledFontIsRegisteredInApp() {
        let declared = Bundle.main.infoDictionary?["UIAppFonts"] as? [String] ?? []
        for face in BundledFont.allCases {
            XCTAssertTrue(declared.contains(face.fileName), "App UIAppFonts is missing \(face.fileName)")
            XCTAssertNotNil(UIFont(name: face.postScriptName, size: 12), "\(face.postScriptName) is not registered")
        }
    }

    func testEveryBundledFontAlsoShipsInWidgetExtension() throws {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("GlanceWidgetExtension.appex"),
              let widget = Bundle(url: url) else {
            throw XCTSkip("GlanceWidgetExtension.appex not found in the host app's PlugIns")
        }
        let declared = widget.infoDictionary?["UIAppFonts"] as? [String] ?? []
        for face in BundledFont.allCases {
            XCTAssertTrue(declared.contains(face.fileName), "Widget UIAppFonts is missing \(face.fileName)")
            XCTAssertNotNil(widget.url(forResource: face.rawValue, withExtension: "ttf"), "Widget lacks \(face.fileName)")
        }
    }

    func testMarkerThemeAssignsTitleFaces() {
        for face in [MarkerFontTheme.headlineFace, MarkerFontTheme.listTitleFace, MarkerFontTheme.tileFace] {
            XCTAssertEqual(face, .cabinSketchBold, "Cabin Sketch is the one hand font")
        }
    }

    func testUnsetFontThemeReadsAsDefault() {
        XCTAssertEqual(WidgetDataBridge.fontThemeID(in: store), FontThemes.default)
    }

    func testStoredSystemFontThemeReadsAsSystem() {
        store.set("system", forKey: WidgetDataBridge.fontThemeKey)
        XCTAssertEqual(WidgetDataBridge.fontThemeID(in: store), .system)
    }

    func testUnknownFontThemeReadsAsDefault() {
        store.set("not-a-theme", forKey: WidgetDataBridge.fontThemeKey)
        XCTAssertEqual(WidgetDataBridge.fontThemeID(in: store), FontThemes.default)
    }
}
