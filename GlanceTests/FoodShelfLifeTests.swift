import XCTest
@testable import Glance

// MARK: - FoodShelfLifeTests
// Covers: GlanceShared/Sources/Logic/FoodShelfLife.swift (suggestedDays(place:kinds:labels:)).

final class FoodShelfLifeTests: XCTestCase {

    private func days(_ place: FoodStorage = .fridge, _ kinds: [FoodKind] = [], _ labels: [String] = []) -> Int? {
        FoodShelfLife.suggestedDays(place: place, kinds: kinds, labels: labels)
    }

    func testThawIsOneDayWherever() {
        XCTAssertEqual(days(.freezer, [.thaw], ["Shrimp"]), 1)
        XCTAssertEqual(days(.fridge, [.thaw, .prepared], ["Curry"]), 1)
    }

    func testCannedIsAYearWhereverItIs() {
        XCTAssertEqual(days(.pantry, [.canned], ["Fish"]), 365)
        XCTAssertEqual(days(.fridge, [.canned]), 365)
        XCTAssertEqual(days(.pantry, [.canned, .thaw]), 1, "thaw still wins")
    }

    func testFreezerIsThreeMonthsOrTwoWhenCooked() {
        XCTAssertEqual(days(.freezer, [], ["Chicken"]), 90)
        XCTAssertEqual(days(.freezer, [.prepared], ["Rice"]), 60)
    }

    func testCookedFoodUsesTheLeftoversRule() {
        XCTAssertEqual(days(.fridge, [.prepared], ["Chicken"]), 3, "cooked chicken, not raw")
        XCTAssertEqual(days(.fridge, [.prepared], []), 3)
    }

    func testFridgeFollowsTheMainLabel() {
        XCTAssertEqual(days(.fridge, [], ["Eggs"]), 21)
        XCTAssertEqual(days(.fridge, [], ["Yogurt"]), 7)
        XCTAssertEqual(days(.fridge, [], ["Chicken", "Rice"]), 1, "main label wins; raw is shortest")
        XCTAssertEqual(days(.fridge, [], ["rice"]), 3, "case doesn't matter")
        XCTAssertEqual(days(.fridge, [], ["Shrimp"]), 3)
    }

    func testPantry() {
        XCTAssertEqual(days(.pantry, [], ["Bread"]), 3)
        XCTAssertEqual(days(.pantry, [], ["Rice"]), 28)
    }

    func testUnknownsGiveNoSuggestion() {
        XCTAssertNil(days(.fridge, [], ["Tofu"]))
        XCTAssertNil(days())
    }

    func testEverySuggestionIsAStepperStop() {
        let all = [1, 3, 7, 21, 28, 60, 90, 365]
        XCTAssertTrue(all.allSatisfy(FoodExpiry.steps.contains))
    }
}
