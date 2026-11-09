import XCTest
@testable import Glance

// MARK: - FoodTaxonomyTests
// Covers: GlanceShared/Sources/Models/FoodTaxonomy.swift (FoodStorage, FoodKind, FoodLabels).

final class FoodTaxonomyTests: XCTestCase {

    func testStorageAndKindLabels() {
        XCTAssertEqual(FoodStorage.allCases.map(\.label), ["Fridge", "Freezer", "Pantry"])
        XCTAssertEqual(FoodKind.allCases.map(\.label), ["Snack", "Ingredient", "Prepared", "Drink", "Thaw", "Canned"])
        XCTAssertTrue(FoodStorage.allCases.allSatisfy { !$0.symbol.isEmpty })
    }

    func testBuiltInLabelsMatchTheAgreedList() {
        XCTAssertEqual(FoodLabels.builtIn, ["Fruit", "Veggie", "Juice", "Bread", "Spread", "Yogurt", "Curry",
                                            "Rice", "Chicken", "Beef", "Pasta", "Eggs", "Fish", "Shrimp"])
    }

    func testNameSuggestsLabelsInWordOrder() {
        XCTAssertEqual(FoodLabels.suggested(forName: "chicken fried rice"), ["Chicken", "Rice"])
        XCTAssertEqual(FoodLabels.suggested(forName: "Rice & chicken"), ["Rice", "Chicken"])
    }

    func testSingularPluralAndAliasesMatch() {
        XCTAssertEqual(FoodLabels.suggested(forName: "boiled egg"), ["Eggs"])
        XCTAssertEqual(FoodLabels.suggested(forName: "prawn crackers"), ["Shrimp"])
        XCTAssertEqual(FoodLabels.suggested(forName: "fruits"), ["Fruit"])
    }

    func testSuggestionsStopAtThreeAndSkipRepeats() {
        let names = FoodLabels.suggested(forName: "rice rice chicken beef pasta eggs")
        XCTAssertEqual(names, ["Rice", "Chicken", "Beef"])
    }

    func testSuggestionsIncludeTheUsersOwnLabels() {
        let labels = FoodLabels.builtIn + ["Tofu"]
        XCTAssertEqual(FoodLabels.suggested(forName: "Crispy tofu", among: labels), ["Tofu"])
    }

    func testNoMatchSuggestsNothing() {
        XCTAssertTrue(FoodLabels.suggested(forName: "oat milk").isEmpty)
        XCTAssertTrue(FoodLabels.suggested(forName: "").isEmpty)
    }

    func testNormalizedTrimsCapsAndCapitalises() {
        XCTAssertEqual(FoodLabels.normalized("  tofu "), "Tofu")
        XCTAssertNil(FoodLabels.normalized("   "))
        XCTAssertEqual(FoodLabels.normalized(String(repeating: "a", count: 99))?.count, FoodLabels.maxLength)
    }

    func testContainsIgnoresCase() {
        XCTAssertTrue(FoodLabels.contains(["Chicken"], "chicken"))
        XCTAssertFalse(FoodLabels.contains(["Chicken"], "Beef"))
    }
}
