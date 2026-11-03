import XCTest
@testable import Glance

// MARK: - ThemeCompletionTests
// Covers: ThemeCompletion.swift (Theme.isDone, isListComplete, allStepsDone, listCompletedAt,
// toggle, sweepComplete, resetCompletion, changeRecurrence) on top of the Theme.recurrence schedule.

final class ThemeCompletionTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }()

    /// UTC date helper. 2026-11-02 is a Monday.
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func twoStepTheme() -> (Theme, [Step]) {
        let steps = [Step(text: "Keys", sortOrder: 0), Step(text: "Phone", sortOrder: 1)]
        return (Theme(name: "Leave", colorToken: "sky", steps: steps), steps)
    }

    // MARK: isListComplete

    func testListCompleteOnlyWhenEveryStepTickedThisPeriod() {
        let (theme, steps) = twoStepTheme()
        let now = date(2026, 11, 1, 9)
        steps[0].setComplete(true, now: now)
        XCTAssertFalse(theme.isListComplete(now: now, calendar: calendar))
        steps[1].setComplete(true, now: now)
        XCTAssertTrue(theme.isListComplete(now: now, calendar: calendar))
    }

    func testEmptyListIsNotComplete() {
        let theme = Theme(name: "Empty")
        XCTAssertFalse(theme.isListComplete(now: date(2026, 11, 1), calendar: calendar))
    }

    // MARK: sweepComplete / resetCompletion

    func testSweepTicksEveryStepAndCompletesList() {
        let (theme, steps) = twoStepTheme()
        let now = date(2026, 11, 1, 9)
        theme.sweepComplete(now: now)
        XCTAssertEqual(theme.lastSweptAt, now)
        XCTAssertTrue(steps.allSatisfy { $0.completedAt == now })
        XCTAssertTrue(theme.isListComplete(now: date(2026, 11, 1, 18), calendar: calendar))
    }

    func testStepAddedAfterSweepMakesListIncomplete() {
        let (theme, _) = twoStepTheme()
        theme.sweepComplete(now: date(2026, 11, 1, 9))
        theme.steps.append(Step(text: "Wallet", sortOrder: 2))
        XCTAssertFalse(theme.isListComplete(now: date(2026, 11, 1, 10), calendar: calendar))
    }

    func testDailySweepResetsNextDay() {
        let (theme, _) = twoStepTheme()
        theme.sweepComplete(now: date(2026, 11, 1, 9))
        XCTAssertFalse(theme.isListComplete(now: date(2026, 11, 2, 9), calendar: calendar))
    }

    func testResetCompletionClearsTicksAndSweep() {
        let (theme, steps) = twoStepTheme()
        theme.sweepComplete(now: date(2026, 11, 1, 9))
        theme.resetCompletion(now: date(2026, 11, 1, 10))
        XCTAssertNil(theme.lastSweptAt)
        XCTAssertTrue(steps.allSatisfy { $0.completedAt == nil })
    }

    // MARK: toggle

    func testToggleChecksThenUnchecksAStep() {
        let (theme, steps) = twoStepTheme()
        let now = date(2026, 11, 1)
        theme.toggle(steps[0], now: now, calendar: calendar)
        XCTAssertTrue(theme.isDone(steps[0].completedAt, now: now, calendar: calendar))
        theme.toggle(steps[0], now: now, calendar: calendar)
        XCTAssertNil(steps[0].completedAt)
    }

    func testToggleOnYesterdaysTickChecksItAgain() {
        let (theme, steps) = twoStepTheme()
        steps[0].setComplete(true, now: date(2026, 10, 31))
        theme.toggle(steps[0], now: date(2026, 11, 1), calendar: calendar)
        XCTAssertEqual(steps[0].completedAt, date(2026, 11, 1))
    }

    func testUncheckingAStepLiftsTheSweep() {
        let (theme, steps) = twoStepTheme()
        let now = date(2026, 11, 1)
        theme.sweepComplete(now: now)
        theme.toggle(steps[0], now: now, calendar: calendar)
        XCTAssertNil(theme.lastSweptAt)
        XCTAssertFalse(theme.isListComplete(now: now, calendar: calendar))
    }

    func testOneTimeTickStillCountsAYearLater() {
        let step = Step(text: "Renew passport", sortOrder: 0)
        let theme = Theme(name: "Passport", steps: [step])
        theme.recurrence = Recurrence(kind: .oneTime)
        theme.toggle(step, now: date(2026, 11, 1), calendar: calendar)
        XCTAssertTrue(theme.isDone(step.completedAt, now: date(2027, 11, 1), calendar: calendar))
        XCTAssertTrue(theme.isListComplete(now: date(2027, 11, 1), calendar: calendar))
    }

    func testWeeklyTapOnTuesdayUnchecksMondaysTick() {
        let step = Step(text: "Bins out", sortOrder: 0)
        let theme = Theme(name: "Bins", steps: [step])
        theme.recurrence = Recurrence(kind: .weekly, weekdays: [2])
        theme.toggle(step, now: date(2026, 11, 2, 8), calendar: calendar)
        theme.toggle(step, now: date(2026, 11, 3, 8), calendar: calendar)
        XCTAssertNil(step.completedAt)
    }

    // MARK: allStepsDone

    func testAllStepsDoneIsFalseWithAStaleTick() {
        let (theme, steps) = twoStepTheme()
        steps[0].setComplete(true, now: date(2026, 10, 31))
        steps[1].setComplete(true, now: date(2026, 11, 1))
        XCTAssertFalse(theme.allStepsDone(now: date(2026, 11, 1), calendar: calendar))
    }

    // MARK: listCompletedAt

    func testListCompletedAtIsNilWhenNotComplete() {
        let (theme, steps) = twoStepTheme()
        steps[0].setComplete(true, now: date(2026, 11, 1, 8))
        XCTAssertNil(theme.listCompletedAt(now: date(2026, 11, 1, 9), calendar: calendar))
    }

    func testListCompletedAtIsLatestCurrentTick() {
        let (theme, steps) = twoStepTheme()
        steps[0].setComplete(true, now: date(2026, 11, 1, 10))
        steps[1].setComplete(true, now: date(2026, 11, 1, 8))
        XCTAssertEqual(theme.listCompletedAt(now: date(2026, 11, 1, 12), calendar: calendar), date(2026, 11, 1, 10))
    }

    func testListCompletedAtIgnoresStaleTicks() {
        let (theme, _) = twoStepTheme()
        theme.sweepComplete(now: date(2026, 10, 31, 9))
        XCTAssertNil(theme.listCompletedAt(now: date(2026, 11, 1, 9), calendar: calendar))
    }

    func testWeeklyListStaysDoneAndReportsCompletion() {
        let step = Step(text: "Bins out", sortOrder: 0)
        let theme = Theme(name: "Bins", colorToken: "sky", steps: [step])
        theme.recurrence = Recurrence(kind: .weekly, weekdays: [2])
        theme.toggle(step, now: date(2026, 11, 2, 8), calendar: calendar)
        XCTAssertTrue(theme.isListComplete(now: date(2026, 11, 5), calendar: calendar))
        XCTAssertEqual(theme.listCompletedAt(now: date(2026, 11, 5), calendar: calendar), date(2026, 11, 2, 8))
        XCTAssertNil(theme.listCompletedAt(now: date(2026, 11, 9), calendar: calendar), "New week: not finished")
    }

    func testOneTimeListReportsOriginalCompletion() {
        let step = Step(text: "Renew passport", sortOrder: 0)
        let theme = Theme(name: "Passport", steps: [step])
        theme.recurrence = Recurrence(kind: .oneTime)
        theme.toggle(step, now: date(2026, 11, 1, 8), calendar: calendar)
        XCTAssertEqual(theme.listCompletedAt(now: date(2027, 6, 1), calendar: calendar), date(2026, 11, 1, 8))
    }

    // MARK: Changing the repeat rule

    func testSwitchingToOneTimeDoesNotReviveOldTicks() {
        let (theme, steps) = twoStepTheme()
        steps.forEach { $0.setComplete(true, now: date(2026, 11, 1, 9)) }   // done yesterday (daily)
        theme.changeRecurrence(to: Recurrence(kind: .oneTime), now: date(2026, 11, 2), calendar: calendar)
        XCTAssertTrue(steps.allSatisfy { $0.completedAt == nil })
        XCTAssertFalse(theme.isListComplete(now: date(2026, 11, 2), calendar: calendar))
    }

    func testChangingRuleKeepsTicksThatStillCountAndRestartsCycle() {
        let (theme, steps) = twoStepTheme()
        steps[0].setComplete(true, now: date(2026, 11, 2, 8))               // today
        let now = date(2026, 11, 2)
        theme.changeRecurrence(to: Recurrence(kind: .weekly, weekdays: [2]), now: now, calendar: calendar)
        XCTAssertEqual(steps[0].completedAt, date(2026, 11, 2, 8))
        XCTAssertEqual(theme.repeatAnchor, now)
    }

    func testSameRuleIsANoOp() {
        let (theme, steps) = twoStepTheme()
        steps[0].setComplete(true, now: date(2026, 11, 1, 9))
        theme.changeRecurrence(to: Recurrence(kind: .daily), now: date(2026, 11, 2), calendar: calendar)
        XCTAssertNotNil(steps[0].completedAt)
        XCTAssertNil(theme.repeatAnchor)
    }
}
