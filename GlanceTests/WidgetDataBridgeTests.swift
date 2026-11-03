import XCTest
@testable import Glance

// MARK: - WidgetDataBridgeTests
// Covers: WidgetDataBridge (readSnapshotIfWritten, writeSnapshot, snapshot(of:now:calendar:),
// pin(_:now:in:), pinState(in:), readFood(from:)), WidgetPin, FoodSnapshot.

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
        let milk = FoodSnapshot(id: UUID(), name: "Milk", useByDate: date(4))
        store.set(try JSONEncoder().encode([milk]), forKey: WidgetDataBridge.foodKey)
        let food = WidgetDataBridge.readFood(from: store)
        XCTAssertEqual(food.map(\.id), [milk.id])
        XCTAssertEqual(food.first?.name, "Milk")
        XCTAssertEqual(food.first?.useByDate, date(4))
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
