import XCTest
@testable import Glance

// MARK: - GlanceLinkTests
// Covers: GlanceShared/Sources/Store/GlanceLink.swift (theme(_:), food(_:), themeID(from:), route(from:)).

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

    // MARK: route(from:)

    func testRouteReadsThemeAndFoodLinks() {
        let id = UUID()
        XCTAssertEqual(GlanceLink.route(from: GlanceLink.theme(id)), .theme(id))
        XCTAssertEqual(GlanceLink.route(from: GlanceLink.food(id)), .food(id))
    }

    func testRouteReadsFoodTabAndOpen() {
        XCTAssertEqual(GlanceLink.route(from: GlanceLink.foodTab), .foodTab)
        XCTAssertEqual(GlanceLink.route(from: GlanceLink.open), .open)
    }

    func testMalformedIDsFallBackToTheirTab() {
        XCTAssertEqual(GlanceLink.route(from: URL(string: "glance://food/nope")!), .foodTab)
        XCTAssertEqual(GlanceLink.route(from: URL(string: "glance://theme/nope")!), .open)
        XCTAssertEqual(GlanceLink.route(from: URL(string: "glance://somewhere")!), .open)
    }

    func testOtherSchemeHasNoRoute() {
        XCTAssertNil(GlanceLink.route(from: URL(string: "https://food/\(UUID().uuidString)")!))
    }
}
