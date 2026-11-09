#if DEBUG && targetEnvironment(simulator)   // the test-data loader only exists here
import XCTest
import SwiftData
@testable import Glance

// MARK: - StressTests
// Covers: large-data behaviour across CollectionLimits, TestDataLoader caps, FoodQuery search speed,
// WidgetDataBridge snapshot size, and Theme's once-per-list period math. Timings are generous
// (simulator, Debug build); they catch accidental slowdowns of 10x, not small ones.

@MainActor
final class StressTests: XCTestCase {

    private var suiteName = ""
    private var store: UserDefaults!

    override func setUp() async throws {
        suiteName = "glance.tests.\(UUID().uuidString)"
        store = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        store.removePersistentDomain(forName: suiteName)
    }

    /// A JSON test set far over every cap, with long text.
    private func hugeSet(lists: Int, steps: Int, foods: Int) throws -> Data {
        let long = String(repeating: "lorem ipsum ", count: 40)
        let listJSON = (0..<lists).map { i in
            ["name": "List \(i) \(long)", "repeat": "monthly", "dayOfMonth": 99,
             "steps": (0..<steps).map { "Step \($0) \(long)" }] as [String: Any]
        }
        let foodJSON = (0..<foods).map { i in
            ["name": "Food \(i) \(long)", "daysFromNow": i % 60, "details": long, "labels": ["Rice", long]] as [String: Any]
        }
        return try JSONSerialization.data(withJSONObject: ["lists": listJSON, "food": foodJSON])
    }

    func testLoadingFarTooMuchStopsAtTheCaps() throws {
        let context = ModelContext(try GlanceStore.makeContainer(inMemory: true))
        try TestDataLoader.load(try hugeSet(lists: 150, steps: 150, foods: 800), into: context, defaults: store)
        let themes = try context.fetch(FetchDescriptor<Theme>())
        XCTAssertEqual(themes.count, CollectionLimits.lists)
        XCTAssertTrue(themes.allSatisfy { $0.steps.count == CollectionLimits.stepsPerList })
        XCTAssertTrue(themes.allSatisfy { $0.name.count <= TextLimits.name })
        XCTAssertTrue(themes.allSatisfy { $0.recurrence.dayOfMonth == 31 }, "impossible day clamped")
        let food = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertEqual(food.count, CollectionLimits.foods)
        XCTAssertTrue(food.allSatisfy { $0.details.count <= TextLimits.note && $0.labels.allSatisfy { $0.count <= FoodLabels.maxLength } })
    }

    func testWidgetSnapshotStaysSmallWithAFullBoard() throws {
        let context = ModelContext(try GlanceStore.makeContainer(inMemory: true))
        try TestDataLoader.load(try hugeSet(lists: 100, steps: 100, foods: 500), into: context, defaults: store)
        let themes = try context.fetch(FetchDescriptor<Theme>(sortBy: [SortDescriptor(\.sortOrder)]))
        let start = Date()
        WidgetDataBridge.writeSnapshot(themes, to: store)
        WidgetDataBridge.writeFood(try context.fetch(FetchDescriptor<FoodItem>()), to: store)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
        let bytes = (store.data(forKey: WidgetDataBridge.snapshotKey)?.count ?? 0)
            + (store.data(forKey: WidgetDataBridge.foodKey)?.count ?? 0)
        XCTAssertLessThan(bytes, 500_000, "widget data must stay well under the widget's memory budget")
    }

    func testSearchingAFullKitchenIsFast() {
        let long = String(repeating: "cooked sunday blue tub leftovers ", count: 9)
        let foods = (0..<CollectionLimits.foods).map { i in
            FoodSnapshot(id: UUID(), name: "Chicken fried rice \(i)", useBy: Date(), storage: .fridge,
                         kinds: [.prepared], labels: ["Chicken", "Rice"], details: long)
        }
        let start = Date()
        for text in ["chiken", "rice blue", "leftovers", "zzz qqq xxx yyy www vvv uuu"] {
            _ = FoodQuery.filter(foods, text: text, storage: nil)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    func testFullListDoneCheckIsFast() {
        let theme = Theme(name: "Big", steps: (0..<CollectionLimits.stepsPerList).map { Step(text: "s\($0)", sortOrder: $0) })
        theme.recurrence = Recurrence(kind: .monthly, dayOfMonth: 31)
        theme.setAllDone(true)
        let start = Date()
        for _ in 0..<100 { _ = theme.isListComplete() }
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
    }
}
#endif
