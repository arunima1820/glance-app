import XCTest
@testable import Glance

// MARK: - FoodDraftTests
// Covers: Glance/Sources/Food/FoodDraft.swift (init(editing:), toggleKind, suggestLabels,
// useBy(now:calendar:), apply(to:now:calendar:)).

final class FoodDraftTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
    }

    func testNewDraftDefaults() {
        let draft = FoodDraft()
        XCTAssertEqual(draft.place, .fridge)
        XCTAssertEqual(draft.mode, .inDays)
        XCTAssertEqual(draft.days, FoodExpiry.defaultDays)
        XCTAssertFalse(draft.labelsTouched)
    }

    func testNameSuggestsLabelsUntilTheUserPicksThemselves() {
        var draft = FoodDraft()
        draft.suggestLabels(forName: "chicken fried rice", among: [])
        XCTAssertEqual(draft.labels, ["Chicken", "Rice"])
        draft.labelsTouched = true
        draft.suggestLabels(forName: "beef stew", among: [])
        XCTAssertEqual(draft.labels, ["Chicken", "Rice"])
    }

    func testToggleKindAddsAndRemoves() {
        var draft = FoodDraft()
        draft.toggleKind(titled: "Canned")
        XCTAssertTrue(draft.isCanned)
        draft.toggleKind(titled: "Canned")
        XCTAssertFalse(draft.isCanned)
        draft.toggleKind(titled: "Nope")
        XCTAssertTrue(draft.kinds.isEmpty)
    }

    func testUseByAlwaysHasAValueEvenForCanned() {
        var draft = FoodDraft()
        draft.days = 2
        XCTAssertEqual(draft.useBy(now: date(3, 18), calendar: calendar), date(5))
        draft.mode = .onDate
        draft.date = date(9, 15)
        XCTAssertEqual(draft.useBy(now: date(3), calendar: calendar), date(9))
        draft.kinds = [.canned]
        XCTAssertEqual(draft.useBy(now: date(3), calendar: calendar), date(9), "canned keeps its date")
    }

    func testCannedStartsAYearOut() {
        var draft = FoodDraft()
        draft.kinds = [.canned]
        draft.suggestExpiry()
        XCTAssertEqual(draft.days, 365)
    }

    func testOldUndatedFoodGetsATypicalDateWhenEdited() {
        let item = FoodItem(name: "Rice", labels: ["Rice"])
        let draft = FoodDraft(editing: item)
        XCTAssertEqual(draft.mode, .inDays)
        XCTAssertEqual(draft.days, 3)
        XCTAssertFalse(draft.expiryTouched)
    }

    func testApplyCapsTextAndLabels() {
        var draft = FoodDraft()
        draft.name = "  " + String(repeating: "n", count: 200)
        draft.details = String(repeating: "d", count: 900)
        draft.labels = ["Rice", "Chicken", "Beef", "Fish"]
        let item = FoodItem(name: "")
        draft.apply(to: item, now: date(3), calendar: calendar)
        XCTAssertEqual(item.name.count, TextLimits.name)
        XCTAssertEqual(item.details.count, TextLimits.note)
        XCTAssertEqual(item.labels, ["Rice", "Chicken", "Beef"])
        XCTAssertEqual(item.useBy, date(6))
    }

    func testExpiryFollowsTheFoodUntilTheUserSetsIt() {
        var draft = FoodDraft()
        draft.labels = ["Eggs"]
        draft.suggestExpiry()
        XCTAssertEqual(draft.days, 21)
        draft.kinds = [.thaw]
        draft.suggestExpiry()
        XCTAssertEqual(draft.days, 1)
        draft.kinds = []
        draft.labels = ["Tofu"]
        draft.suggestExpiry()
        XCTAssertEqual(draft.days, FoodExpiry.defaultDays, "nothing known: back to the default")
        draft.expiryTouched = true
        draft.labels = ["Eggs"]
        draft.suggestExpiry()
        XCTAssertEqual(draft.days, FoodExpiry.defaultDays)
    }

    func testEditingNeverChangesTheStoredExpiry() {
        let item = FoodItem(name: "Rice", labels: ["Rice"], useBy: date(20))
        var draft = FoodDraft(editing: item)
        draft.kinds = [.thaw]
        draft.suggestExpiry()
        XCTAssertEqual(draft.useBy(now: date(3), calendar: calendar), date(20))
    }

    func testEditingShowsTheStoredDate() {
        let item = FoodItem(name: "Milk", kinds: [.ingredient], labels: ["Juice"], useBy: date(8))
        let draft = FoodDraft(editing: item)
        XCTAssertEqual(draft.mode, .onDate)
        XCTAssertEqual(draft.date, date(8))
        XCTAssertTrue(draft.labelsTouched)
        XCTAssertEqual(draft.kinds, [.ingredient])
    }
}
