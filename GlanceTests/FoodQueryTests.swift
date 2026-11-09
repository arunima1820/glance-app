import XCTest
@testable import Glance

// MARK: - FoodQueryTests
// Covers: GlanceShared/Sources/Logic/FoodQuery.swift (FoodSort, FoodQuery sorted/matches/filter/
// useSoon/pill/subtitle).

final class FoodQueryTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
    }

    private func food(_ name: String, useBy day: Int? = nil, storage: FoodStorage = .fridge,
                      kinds: [FoodKind] = [], labels: [String] = [], details: String? = nil,
                      added: Int = 1) -> FoodSnapshot {
        FoodSnapshot(id: UUID(), name: name, useBy: day.map { date($0) }, storage: storage, kinds: kinds,
                     labels: labels, details: details, addedAt: date(added))
    }

    // MARK: sorted

    func testExpirySortPutsSoonestFirstAndUndatedLast() {
        let items = [food("Beans"), food("Milk", useBy: 6), food("Eggs", useBy: 2), food("Rice", useBy: 1)]
        XCTAssertEqual(FoodQuery.sorted(items, by: .expiry).map(\.name), ["Rice", "Eggs", "Milk", "Beans"])
    }

    func testExpirySortBreaksTiesByName() {
        let items = [food("Yogurt", useBy: 3), food("apples", useBy: 3), food("Tuna"), food("corn")]
        XCTAssertEqual(FoodQuery.sorted(items, by: .expiry).map(\.name), ["apples", "Yogurt", "corn", "Tuna"])
    }

    func testRecentSortPutsNewestFirst() {
        let items = [food("Old", added: 1), food("New", added: 5), food("Mid", added: 3)]
        XCTAssertEqual(FoodQuery.sorted(items, by: .recent).map(\.name), ["New", "Mid", "Old"])
    }

    // MARK: matches / filter

    func testSearchMatchesNameDescriptionLabelsKindsAndPlace() {
        let rice = food("Fried rice", kinds: [.prepared], labels: ["Rice", "Chicken"], details: "Blue tub")
        for text in ["fried", "BLUE", "chicken", "prepared", "fridge", "rice chicken", ""] {
            XCTAssertTrue(FoodQuery.matches(rice, text: text), text)
        }
        XCTAssertFalse(FoodQuery.matches(rice, text: "beef"))
        XCTAssertFalse(FoodQuery.matches(rice, text: "rice beef"), "every word must match")
    }

    func testSearchForgivesSmallTypos() {
        let chicken = food("Chicken thighs", labels: ["Chicken"])
        XCTAssertTrue(FoodQuery.matches(chicken, text: "chiken"))
        XCTAssertTrue(FoodQuery.matches(chicken, text: "chik"), "half-typed with a typo")
        XCTAssertTrue(FoodQuery.matches(food("Greek yogurt"), text: "yoghurt"))
        XCTAssertFalse(FoodQuery.matches(chicken, text: "cat"), "short words must match exactly")
    }

    func testSearchUnderstandsRelatedWords() {
        XCTAssertTrue(FoodQuery.matches(food("Curry", kinds: [.prepared]), text: "leftovers"))
        XCTAssertTrue(FoodQuery.matches(food("Thighs", labels: ["Chicken"]), text: "meat"))
        XCTAssertTrue(FoodQuery.matches(food("Peas", storage: .freezer), text: "frozen"))
        XCTAssertFalse(FoodQuery.matches(food("Apple", labels: ["Fruit"]), text: "meat"))
    }

    func testHugeSearchTextIsCappedAndStaysFast() {
        let item = food("Chicken thighs", labels: ["Chicken"])
        let paste = String(repeating: "chicken ", count: 50_000)
        let start = Date()
        XCTAssertTrue(FoodQuery.matches(item, text: paste))
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
        XCTAssertFalse(FoodSearchWords.isClose(String(repeating: "x", count: 40), to: "chicken"))
    }

    func testSearchIgnoresAccents() {
        XCTAssertTrue(FoodQuery.matches(food("Jalapeño dip"), text: "jalapeno"))
    }

    func testFilterNarrowsByStorage() {
        let items = [food("Milk"), food("Peas", storage: .freezer), food("Pasta", storage: .pantry)]
        XCTAssertEqual(FoodQuery.filter(items, text: "", storage: .freezer).map(\.name), ["Peas"])
        XCTAssertEqual(FoodQuery.filter(items, text: "p", storage: nil).map(\.name), ["Peas", "Pasta"])
    }

    // MARK: useSoon

    func testUseSoonKeepsTheLookAheadWindowAndExpired() {
        let items = [food("Gone", useBy: 1), food("Today", useBy: 3), food("Edge", useBy: 10),
                     food("Later", useBy: 11), food("Tin", useBy: 4, kinds: [.canned]), food("Undated")]
        let soon = FoodQuery.useSoon(items, now: date(3, 15), lookAheadDays: 7, includeExpired: true,
                                     calendar: calendar)
        XCTAssertEqual(soon.map(\.name), ["Gone", "Today", "Tin", "Edge"], "a can due soon shows too")
    }

    func testCannedPillStaysQuietUntilItsClose() {
        let now = date(3)
        let farTin = food("Beans", useBy: 30, kinds: [.canned])
        let nearTin = food("Beans", useBy: 5, kinds: [.canned])
        let farMilk = food("Long-life milk", useBy: 30)
        XCTAssertEqual(FoodQuery.pill(for: farTin, now: now, calendar: calendar), .none)
        XCTAssertEqual(FoodQuery.pill(for: nearTin, now: now, calendar: calendar), .days(2))
        XCTAssertEqual(FoodQuery.pill(for: farMilk, now: now, calendar: calendar), .weeks)
    }

    func testUseSoonCanHideExpired() {
        let items = [food("Gone", useBy: 1), food("Today", useBy: 3)]
        let soon = FoodQuery.useSoon(items, now: date(3), lookAheadDays: 14, includeExpired: false,
                                     calendar: calendar)
        XCTAssertEqual(soon.map(\.name), ["Today"])
    }

    // MARK: subtitle

    func testSubtitleLeadsWithKindThenMainLabelAndExtras() {
        XCTAssertEqual(FoodQuery.subtitle(for: food("x", kinds: [.prepared], labels: ["Chicken", "Rice"])),
                       "Prepared · Chicken +1")
        XCTAssertEqual(FoodQuery.subtitle(for: food("x", kinds: [.ingredient], labels: ["Eggs"])),
                       "Ingredient · Eggs")
    }

    func testSubtitleFallsBackToWhereItLives() {
        XCTAssertEqual(FoodQuery.subtitle(for: food("x", labels: ["Eggs"])), "Fridge · Eggs")
        XCTAssertEqual(FoodQuery.subtitle(for: food("x", storage: .pantry, kinds: [.canned])), "Pantry · Canned")
        XCTAssertEqual(FoodQuery.subtitle(for: food("x", storage: .freezer)), "Freezer")
    }

    func testSortLabels() {
        XCTAssertEqual(FoodSort.allCases.map(\.label), ["Use soonest first", "Recently added"])
    }
}
