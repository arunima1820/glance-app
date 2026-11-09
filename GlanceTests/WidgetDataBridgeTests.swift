import XCTest
@testable import Glance

// MARK: - WidgetDataBridgeTests
// Covers: WidgetDataBridge (readSnapshotIfWritten, writeSnapshot, snapshot(of:now:calendar:),
// pin(_:now:in:), pinState(in:), readFood(from:), writeFood(_:now:to:), widgetSnapshot(of:), capped,
// hidesLockScreenDetails(in:)), WidgetPin, FoodSnapshot.

final class WidgetDataBridgeTests: XCTestCase {

    private var suiteName = ""
    private var store: UserDefaults!

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
    }

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

    // MARK: Snapshot storage

    func testReadSnapshotIsNilWhenNeverWritten() {
        XCTAssertNil(WidgetDataBridge.readSnapshotIfWritten(from: store))
    }

    func testReadSnapshotIsEmptyWhenEmptyListWritten() {
        WidgetDataBridge.writeSnapshot([], to: store)
        XCTAssertEqual(WidgetDataBridge.readSnapshotIfWritten(from: store)?.count, 0)
    }

    func testCorruptSnapshotReadsAsEmpty() {
        store.set(Data("x".utf8), forKey: WidgetDataBridge.snapshotKey)
        XCTAssertEqual(WidgetDataBridge.readSnapshotIfWritten(from: store)?.count, 0)
    }

    func testWrittenThemeReadsBack() throws {
        let theme = Theme(name: "Leave", colorToken: "sky", iconToken: "leave", iconEmoji: "🚪")
        theme.steps = [Step(text: "Phone", sortOrder: 1), Step(text: "Keys", iconEmoji: "🔑", sortOrder: 0)]
        WidgetDataBridge.writeSnapshot([theme], to: store)

        let read = try XCTUnwrap(WidgetDataBridge.readSnapshotIfWritten(from: store))
        XCTAssertEqual(read.count, 1)
        XCTAssertEqual(read[0].id, theme.id)
        XCTAssertEqual(read[0].name, "Leave")
        XCTAssertEqual(read[0].colorToken, "sky")
        XCTAssertEqual(read[0].iconToken, "leave")
        XCTAssertEqual(read[0].iconEmoji, "🚪")
        XCTAssertEqual(read[0].recurrence?.kind, .daily)
        XCTAssertEqual(read[0].steps.map(\.text), ["Keys", "Phone"])
        XCTAssertEqual(read[0].steps.map(\.iconEmoji), ["🔑", nil])
    }

    // MARK: Pin

    func testPinRoundTripsIDAndTime() {
        let id = UUID()
        WidgetDataBridge.pin(id, now: date(2, 9), in: store)
        let state = WidgetDataBridge.pinState(in: store)
        XCTAssertEqual(state.themeID, id)
        XCTAssertEqual(state.at, date(2, 9))
    }

    func testUnpinClearsIDButStampsNewTime() {
        WidgetDataBridge.pin(UUID(), now: date(2, 9), in: store)
        WidgetDataBridge.pin(nil, now: date(3, 10), in: store)
        XCTAssertEqual(WidgetDataBridge.pinState(in: store), WidgetPin(themeID: nil, at: date(3, 10)))
    }

    func testNonUUIDPinReadsAsUnpinned() {
        store.set("not-a-uuid", forKey: WidgetDataBridge.pinnedKey)
        XCTAssertNil(WidgetDataBridge.pinState(in: store).themeID)
    }

    // MARK: Food

    func testFoodIsEmptyWhenUnset() {
        XCTAssertTrue(WidgetDataBridge.readFood(from: store).isEmpty)
    }

    func testWrittenFoodDecodes() throws {
        let milk = FoodSnapshot(id: UUID(), name: "Milk", useBy: date(4))
        store.set(try JSONEncoder().encode([milk]), forKey: WidgetDataBridge.foodKey)
        let food = WidgetDataBridge.readFood(from: store)
        XCTAssertEqual(food.map(\.id), [milk.id])
        XCTAssertEqual(food.first?.name, "Milk")
        XCTAssertEqual(food.first?.useBy, date(4))
        XCTAssertNil(food.first?.storage)
    }

    func testWriteFoodRoundTripsWithoutDescription() {
        let rice = FoodItem(name: "Rice", details: "Blue tub", storage: .fridge, kinds: [.prepared],
                            labels: ["Rice"], useBy: date(5), addedAt: date(2))
        let beans = FoodItem(name: "Beans", storage: .pantry, kinds: [.canned], useBy: date(3))
        WidgetDataBridge.writeFood([rice, beans], now: date(2), to: store)

        let food = WidgetDataBridge.readFood(from: store)
        XCTAssertEqual(food.map(\.name), ["Beans", "Rice"], "soonest first")
        XCTAssertNil(food[1].details)
        XCTAssertEqual(food[1].useBy, date(5))
        XCTAssertEqual(food[1].kindList, [.prepared])
        XCTAssertEqual(food[0].useBy, date(3), "canned food keeps its best-by date")
    }

    func testWidgetsAreOnlySentFoodTheyCanShow() {
        let far = FoodItem(name: "Far", useBy: date(2).addingTimeInterval(86_400 * 200))
        let many = (0..<200).map { FoodItem(name: "F\($0)", useBy: date(3)) }
        WidgetDataBridge.writeFood([far] + many, now: date(2), to: store)
        let food = WidgetDataBridge.readFood(from: store)
        XCTAssertEqual(food.count, WidgetDataBridge.widgetFoodLimit)
        XCTAssertFalse(food.contains { $0.name == "Far" })
    }

    func testListSnapshotIsCappedButKeepsThePinnedList() {
        let lists = (0..<30).map { i in
            ThemeSnapshot(id: UUID(), name: "L\(i)", colorToken: "sage", iconEmoji: "x",
                          steps: (0..<50).map { StepSnapshot(id: UUID(), text: "s\($0)", iconEmoji: nil) })
        }
        let capped = WidgetDataBridge.capped(lists, pinned: lists[25].id)
        XCTAssertEqual(capped.count, WidgetDataBridge.widgetListLimit + 1)
        XCTAssertEqual(capped.last?.id, lists[25].id)
        XCTAssertTrue(capped.allSatisfy { $0.steps.count == WidgetDataBridge.widgetStepLimit })
    }

    func testLockScreenDetailsShowUnlessHidden() {
        XCTAssertFalse(WidgetDataBridge.hidesLockScreenDetails(in: store))
        store.set(true, forKey: StorageKeys.lockScreenHidesDetails)
        XCTAssertTrue(WidgetDataBridge.hidesLockScreenDetails(in: store))
    }

    func testUnreadableFoodReadsAsEmpty() {
        store.set(Data("garbage".utf8), forKey: WidgetDataBridge.foodKey)
        XCTAssertTrue(WidgetDataBridge.readFood(from: store).isEmpty)
    }

    func testFoodWidgetSnapshotCapsLongName() {
        let item = FoodItem(name: String(repeating: "x", count: 500))
        XCTAssertEqual(WidgetDataBridge.widgetSnapshot(of: item).name.count, TextLimits.name)
    }

    // MARK: snapshot(of:now:calendar:)

    func testSnapshotDropsEarlierPeriodTickAndKeepsTodays() {
        let stale = Step(text: "Meds", sortOrder: 0)
        let fresh = Step(text: "Water", sortOrder: 1)
        stale.completedAt = date(1, 20)
        fresh.completedAt = date(2, 8)
        let theme = Theme(name: "Morning", steps: [stale, fresh])

        let snap = WidgetDataBridge.snapshot(of: theme, now: date(2, 12), calendar: calendar)
        XCTAssertNil(snap.steps[0].completedAt)
        XCTAssertEqual(snap.steps[1].completedAt, date(2, 8))
        XCTAssertNil(snap.completedAt)
    }

    func testSnapshotMarksListDoneOnlyWhenAllStepsDoneThisPeriod() {
        let a = Step(text: "Meds", sortOrder: 0)
        let b = Step(text: "Water", sortOrder: 1)
        a.completedAt = date(2, 8)
        b.completedAt = date(2, 9)
        let theme = Theme(name: "Morning", steps: [a, b])

        XCTAssertEqual(WidgetDataBridge.snapshot(of: theme, now: date(2, 12), calendar: calendar).completedAt,
                       date(2, 9))
        XCTAssertNil(WidgetDataBridge.snapshot(of: theme, now: date(3, 12), calendar: calendar).completedAt)
    }

    func testSnapshotCapsVeryLongText() {
        let theme = Theme(name: String(repeating: "n", count: 500),
                          steps: [Step(text: String(repeating: "s", count: 5_000), sortOrder: 0)])
        let snap = WidgetDataBridge.snapshot(of: theme, now: date(2), calendar: calendar)
        XCTAssertEqual(snap.name.count, TextLimits.name)
        XCTAssertEqual(snap.steps.first?.text.count, TextLimits.step)
    }
}
