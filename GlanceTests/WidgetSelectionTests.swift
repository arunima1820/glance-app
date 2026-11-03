import XCTest
@testable import Glance

// MARK: - WidgetSelectionTests
// Covers: WidgetSelection (isFinished, visible, autoPinned, explicitID, selectedID) and WidgetPin.

final class WidgetSelectionTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// UTC date in November 2026. 2026-11-02 is a Monday.
    private func date(_ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
    }

    private func list(_ name: String, _ rule: Recurrence? = nil, done: Date? = nil) -> ThemeSnapshot {
        ThemeSnapshot(id: UUID(), name: name, colorToken: "sage", iconEmoji: "",
                      steps: [StepSnapshot(id: UUID(), text: "Step", iconEmoji: nil)],
                      recurrence: rule, completedAt: done)
    }

    private let mondays = Recurrence(kind: .weekly, weekdays: [2])

    private func select(_ visible: [ThemeSnapshot], pin: WidgetPin, configured: String? = nil,
                        at now: Date) -> UUID? {
        WidgetSelection.selectedID(visible: visible, pin: pin, configured: configured, now: now, calendar: calendar)
    }

    // MARK: Visibility

    func testFinishedWeeklyListHiddenUntilItRepeats() {
        let bins = list("Bins", mondays, done: date(2, 8))
        XCTAssertTrue(WidgetSelection.isFinished(bins, now: date(5), calendar: calendar))
        XCTAssertTrue(WidgetSelection.visible([bins], now: date(5), calendar: calendar).isEmpty)
        XCTAssertEqual(WidgetSelection.visible([bins], now: date(9), calendar: calendar).map(\.id), [bins.id])
    }

    func testFinishedDailyListBackTomorrow() {
        let meds = list("Meds", done: date(3, 8))
        XCTAssertTrue(WidgetSelection.visible([meds], now: date(3, 20), calendar: calendar).isEmpty)
        XCTAssertEqual(WidgetSelection.visible([meds], now: date(4, 7), calendar: calendar).map(\.id), [meds.id])
    }

    func testAllFinishedMeansNothingToShow() {
        let meds = list("Meds", done: date(3, 8))
        let visible = WidgetSelection.visible([meds], now: date(3, 9), calendar: calendar)
        XCTAssertNil(select(visible, pin: WidgetPin(), at: date(3, 9)))
    }

    // MARK: Auto-pin

    func testWeeklyListAutoPinsWhenItComesRound() {
        let meds = list("Meds")
        let bins = list("Bins", mondays)
        let pin = WidgetPin(themeID: meds.id, at: date(5))
        XCTAssertEqual(select([meds, bins], pin: pin, at: date(6)), meds.id)
        XCTAssertEqual(select([meds, bins], pin: pin, at: date(9, 7)), bins.id)
    }

    func testUnpinSticksThatDayButWeeklyListAutoPinsNextMonday() {
        let meds = list("Meds")
        let bins = list("Bins", mondays)
        let unpinned = WidgetPin(themeID: nil, at: date(9, 9))
        XCTAssertEqual(select([meds, bins], pin: unpinned, at: date(9, 15)), meds.id)
        XCTAssertEqual(select([meds, bins], pin: unpinned, at: date(16, 7)), bins.id)
    }

    func testNeverPinnedPicksRepeatingList() {
        let bins = list("Bins", mondays)
        XCTAssertEqual(WidgetSelection.autoPinned([list("Meds"), bins], pin: WidgetPin(themeID: nil, at: nil),
                                                  now: date(5), calendar: calendar), bins.id)
    }

    func testMonthlyListAutoPinsOnItsDay() {
        let rent = list("Rent", Recurrence(kind: .monthly, dayOfMonth: 15))
        let pin = WidgetPin(themeID: nil, at: date(10))
        XCTAssertNil(WidgetSelection.autoPinned([rent], pin: pin, now: date(14), calendar: calendar))
        XCTAssertEqual(WidgetSelection.autoPinned([rent], pin: pin, now: date(15, 8), calendar: calendar), rent.id)
    }

    func testDailyListsNeverAutoPin() {
        let meds = list("Meds", Recurrence(kind: .daily))
        XCTAssertNil(WidgetSelection.autoPinned([meds], pin: WidgetPin(), now: date(9), calendar: calendar))
    }

    func testOneTimeListsNeverAutoPin() {
        let trip = list("Trip", Recurrence(kind: .oneTime))
        XCTAssertNil(WidgetSelection.autoPinned([trip], pin: WidgetPin(), now: date(9), calendar: calendar))
    }

    func testLatestStartingPeriodWinsAutoPin() {
        let bins = list("Bins", mondays)                                  // started Mon Nov 2
        let rent = list("Rent", Recurrence(kind: .monthly, dayOfMonth: 1)) // started Sun Nov 1
        let pin = WidgetPin()
        XCTAssertEqual(WidgetSelection.autoPinned([rent, bins], pin: pin, now: date(2), calendar: calendar), bins.id)
        XCTAssertEqual(WidgetSelection.autoPinned([bins, rent], pin: pin, now: date(2), calendar: calendar), bins.id)
    }

    // MARK: Precedence

    func testUserPinBeatsConfiguredList() {
        let meds = list("Meds")
        let water = list("Water")
        let pin = WidgetPin(themeID: water.id, at: date(1))
        XCTAssertEqual(select([meds, water], pin: pin, configured: meds.id.uuidString, at: date(2)), water.id)
    }

    func testConfiguredListUsedWhenNothingPinned() {
        let meds = list("Meds")
        let water = list("Water")
        XCTAssertEqual(select([meds, water], pin: WidgetPin(), configured: water.id.uuidString, at: date(2)),
                       water.id)
    }

    func testPinToHiddenOrUnknownListFallsThroughToConfiguredThenFirst() {
        let meds = list("Meds")
        let water = list("Water")
        let stale = WidgetPin(themeID: UUID(), at: date(1))
        XCTAssertEqual(select([meds, water], pin: stale, configured: water.id.uuidString, at: date(2)), water.id)
        XCTAssertEqual(select([meds, water], pin: stale, configured: nil, at: date(2)), meds.id)
    }

    func testMalformedConfiguredIDIsIgnored() {
        let meds = list("Meds")
        let water = list("Water")
        XCTAssertEqual(select([meds, water], pin: WidgetPin(), configured: "not-a-uuid", at: date(2)), meds.id)
    }

    // MARK: Hardening (2026-11-02 review)

    func testDailyishRulesNeverAutoPin() {
        for rule in [Recurrence(kind: .weekdays), Recurrence(kind: .weekends),
                     Recurrence(kind: .everyNDays, interval: 2), Recurrence(kind: .weekly, weekdays: [2, 4, 6])] {
            XCTAssertNil(WidgetSelection.autoPinned([list("Work", rule)], pin: WidgetPin(), now: date(10), calendar: calendar),
                         "\(rule.kind) should not grab the widget")
        }
    }

    func testEveryThreeDaysAutoPins() {
        let plants = list("Plants", Recurrence(kind: .everyNDays, interval: 3, anchor: date(1)))
        XCTAssertEqual(WidgetSelection.autoPinned([plants], pin: WidgetPin(), now: date(4), calendar: calendar), plants.id)
    }

    func testListWithNoStepsIsNeverVisible() {
        let empty = ThemeSnapshot(id: UUID(), name: "Empty", colorToken: "sage", iconEmoji: "", steps: [])
        XCTAssertTrue(WidgetSelection.visible([empty], now: date(2), calendar: calendar).isEmpty)
    }

    func testFallbackListIsNotAnExplicitPin() {
        let meds = list("Meds")
        XCTAssertNil(WidgetSelection.explicitID(visible: [meds], pin: WidgetPin(), now: date(2), calendar: calendar))
        XCTAssertEqual(select([meds], pin: WidgetPin(), at: date(2)), meds.id, "still shown as the fallback")
    }
}

// MARK: - WidgetRowsTests
// Covers: WidgetSelection.rows(for:now:calendar:) and WidgetSelection.Row.

final class WidgetRowsTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// UTC date in November 2026. 2026-11-02 is a Monday.
    private func date(_ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))!
    }

    private func theme(_ rule: Recurrence?, ticks: [Int: Date]) -> ThemeSnapshot {
        let steps = (0..<4).map { i in
            StepSnapshot(id: UUID(), text: "Step \(i)", iconEmoji: nil, completedAt: ticks[i])
        }
        return ThemeSnapshot(id: UUID(), name: "Trip", colorToken: "sky", iconEmoji: "", steps: steps,
                             recurrence: rule)
    }

    func testDoneStepsSinkKeepingOrderForEveryRecurrenceKind() {
        let now = date(2)
        for kind in Recurrence.Kind.allCases {
            let ticked = theme(Recurrence(kind: kind), ticks: [0: date(2, 11), 2: date(2, 11)])
            let rows = WidgetSelection.rows(for: ticked, now: now, calendar: calendar)
            XCTAssertEqual(rows.map(\.step.text), ["Step 1", "Step 3", "Step 0", "Step 2"], "\(kind)")
            XCTAssertEqual(rows.map(\.isDone), [false, false, true, true], "\(kind)")
            XCTAssertEqual(rows.map(\.id), rows.map(\.step.id), "\(kind)")
        }
    }

    func testNilRecurrenceTreatedAsDaily() {
        let ticked = theme(nil, ticks: [0: date(1, 20), 1: date(2, 8)])
        let rows = WidgetSelection.rows(for: ticked, now: date(2), calendar: calendar)
        XCTAssertEqual(rows.map(\.step.text), ["Step 0", "Step 2", "Step 3", "Step 1"])
        XCTAssertEqual(rows.map(\.isDone), [false, false, false, true])
    }

    func testStaleTickShowsUndone() {
        let ticked = theme(Recurrence(kind: .weekly, weekdays: [2]), ticks: [0: date(2, 8)])
        let rows = WidgetSelection.rows(for: ticked, now: date(9), calendar: calendar)
        XCTAssertEqual(rows.map(\.step.text), ["Step 0", "Step 1", "Step 2", "Step 3"])
        XCTAssertTrue(rows.allSatisfy { !$0.isDone })
    }
}
