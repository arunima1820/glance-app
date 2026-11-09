import XCTest
@testable import Glance

// MARK: - RecentlyRemovedTests
// Covers: GlanceShared/Sources/Store/RecentlyRemoved.swift (entries, add, take, food(in:), lists(in:)).

final class RecentlyRemovedTests: XCTestCase {

    private var suiteName = ""
    private var store: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "glance.tests.\(UUID().uuidString)"
        store = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        store.removePersistentDomain(forName: suiteName)
        store = nil
        super.tearDown()
    }

    private func food(_ name: String) -> FoodSnapshot {
        FoodSnapshot(id: UUID(), name: name)
    }

    func testStartsEmpty() {
        XCTAssertTrue(RecentlyRemoved<FoodSnapshot>.food(in: store).entries().isEmpty)
    }

    func testKeepsNewestFiveNewestFirst() {
        let bin = RecentlyRemoved<FoodSnapshot>.food(in: store)
        for (i, name) in ["a", "b", "c", "d", "e", "f"].enumerated() {
            bin.add(food(name), now: Date(timeIntervalSince1970: Double(i)))
        }
        XCTAssertEqual(bin.entries().map(\.item.name), ["f", "e", "d", "c", "b"])
    }

    func testAddingTheSameItemAgainReplacesIt() {
        let bin = RecentlyRemoved<FoodSnapshot>.food(in: store)
        let milk = food("Milk")
        bin.add(milk)
        bin.add(food("Rice"))
        bin.add(milk)
        XCTAssertEqual(bin.entries().map(\.item.name), ["Milk", "Rice"])
    }

    func testTakeReturnsAndRemovesTheItem() {
        let bin = RecentlyRemoved<FoodSnapshot>.food(in: store)
        let milk = food("Milk")
        bin.add(milk)
        XCTAssertEqual(bin.take(milk.id), milk)
        XCTAssertNil(bin.take(milk.id))
        XCTAssertTrue(bin.entries().isEmpty)
    }

    func testListsAndFoodAreKeptApart() {
        RecentlyRemoved<FoodSnapshot>.food(in: store).add(food("Milk"))
        let list = ThemeSnapshot(id: UUID(), name: "Bins", colorToken: "sage", iconEmoji: "x", steps: [])
        RecentlyRemoved<ThemeSnapshot>.lists(in: store).add(list)
        XCTAssertEqual(RecentlyRemoved<FoodSnapshot>.food(in: store).entries().count, 1)
        XCTAssertEqual(RecentlyRemoved<ThemeSnapshot>.lists(in: store).entries().map(\.item.name), ["Bins"])
    }

    func testClearForgetsEverything() {
        let bin = RecentlyRemoved<FoodSnapshot>.food(in: store)
        bin.add(food("Milk"))
        bin.clear()
        XCTAssertTrue(bin.entries().isEmpty)
    }

    func testUnreadableDataReadsAsEmpty() {
        store.set(Data("nope".utf8), forKey: StorageKeys.removedFood)
        XCTAssertTrue(RecentlyRemoved<FoodSnapshot>.food(in: store).entries().isEmpty)
    }
}
