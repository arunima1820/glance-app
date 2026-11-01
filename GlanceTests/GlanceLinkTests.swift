import XCTest
@testable import Glance

// MARK: - GlanceLinkTests
// Covers: GlanceLink (theme(_:) and themeID(from:)).

final class GlanceLinkTests: XCTestCase {

    func testThemeLinkRoundTripsID() {
        let id = UUID()
        XCTAssertEqual(GlanceLink.themeID(from: GlanceLink.theme(id)), id)
    }

    func testOpenLinkHasNoThemeID() {
        XCTAssertNil(GlanceLink.themeID(from: URL(string: "glance://open")!))
    }

    func testMalformedUUIDHasNoThemeID() {
        XCTAssertNil(GlanceLink.themeID(from: URL(string: "glance://theme/not-a-uuid")!))
    }

    func testOtherSchemeHasNoThemeID() {
        XCTAssertNil(GlanceLink.themeID(from: URL(string: "https://theme/\(UUID().uuidString)")!))
    }
}
