import XCTest
@testable import Glance

// MARK: - FoodSearchWordsTests
// Covers: GlanceShared/Sources/Logic/FoodQuery.swift (FoodSearchWords.distance, isClose, related).

final class FoodSearchWordsTests: XCTestCase {

    func testDistanceCountsEdits() {
        XCTAssertEqual(FoodSearchWords.distance("rice", "rice"), 0)
        XCTAssertEqual(FoodSearchWords.distance("chiken", "chicken"), 1)
        XCTAssertEqual(FoodSearchWords.distance("", "egg"), 3)
        XCTAssertEqual(FoodSearchWords.distance("kitten", "sitting"), 3)
    }

    func testSwappedLettersCountOnce() {
        XCTAssertEqual(FoodSearchWords.distance("rcie", "rice"), 1)
    }

    func testIsCloseAllowsMoreTyposForLongerWords() {
        XCTAssertTrue(FoodSearchWords.isClose("ric", to: "rice"), "part of the word")
        XCTAssertFalse(FoodSearchWords.isClose("rce", to: "rice"), "3 letters: exact only")
        XCTAssertTrue(FoodSearchWords.isClose("rcie", to: "rice"))
        XCTAssertTrue(FoodSearchWords.isClose("spinnach", to: "spinach"))
        XCTAssertFalse(FoodSearchWords.isClose("bread", to: "beef"))
    }

    func testRelatedWordsAreLowercasedKeys() {
        XCTAssertTrue(FoodSearchWords.related.keys.allSatisfy { $0 == $0.lowercased() })
        XCTAssertEqual(FoodSearchWords.related["meat"], ["chicken", "beef"])
    }
}
