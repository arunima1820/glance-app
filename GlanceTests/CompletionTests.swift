import XCTest
import SwiftData
@testable import Glance

// MARK: - CompletionTests
// Covers: CompletionResetPolicy.swift (pure daily-reset logic) and the Theme
// completion helpers in ThemeCompletion.swift (sweep + per-item), including the
// rule that nothing stays "done" past the calendar day it was completed on.

final class CompletionTests: XCTestCase {

    // Fixed UTC calendar so day-boundary tests are deterministic across machines.
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// Builds a UTC date at the given day/time for precise boundary tests.
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour
        return calendar.date(from: c)!
    }

    // MARK: Pure policy — isStillComplete

    func testNeverCompletedIsNotComplete() {
        XCTAssertFalse(CompletionResetPolicy.isStillComplete(completedAt: nil, now: date(2026, 10, 13), calendar: calendar))
    }

    func testCompletedSameDayIsStillComplete() {
        let completed = date(2026, 10, 13, 8)
        let now = date(2026, 10, 13, 22)
        XCTAssertTrue(CompletionResetPolicy.isStillComplete(completedAt: completed, now: now, calendar: calendar))
    }

    func testCompletedYesterdayIsReset() {
        let completed = date(2026, 10, 12, 23)
        let now = date(2026, 10, 13, 1)
        XCTAssertFalse(CompletionResetPolicy.isStillComplete(completedAt: completed, now: now, calendar: calendar),
                       "Completion from a previous day should reset")
    }

    func testSweepActiveMirrorsItemRule() {
        XCTAssertTrue(CompletionResetPolicy.isSweepActive(sweptAt: date(2026, 10, 13, 9), now: date(2026, 10, 13, 20), calendar: calendar))
        XCTAssertFalse(CompletionResetPolicy.isSweepActive(sweptAt: date(2026, 10, 12, 9), now: date(2026, 10, 13, 9), calendar: calendar))
    }

    // MARK: Step.setComplete

    func testStepSetCompleteStampsTimestamp() {
        let step = Step(text: "Grab keys")
        let now = date(2026, 10, 13)
        step.setComplete(true, now: now)
        XCTAssertTrue(step.isComplete)
        XCTAssertEqual(step.completedAt, now)

        step.setComplete(false, now: now)
        XCTAssertFalse(step.isComplete)
        XCTAssertNil(step.completedAt)
    }

    // MARK: Theme — sweep style

    func testSweepCompleteMarksWholeListAndStamps() {
        let theme = Theme(name: "Leave", colorToken: "sky", iconEmoji: "🚪", completionStyle: .sweep)
        theme.steps = [Step(text: "Keys", sortOrder: 0), Step(text: "Phone", sortOrder: 1)]
        let now = date(2026, 10, 13, 9)

        theme.sweepComplete(now: now)
        XCTAssertEqual(theme.lastSweptAt, now)
        XCTAssertTrue(theme.steps.allSatisfy(\.isComplete))
        XCTAssertTrue(theme.isListComplete(now: date(2026, 10, 13, 18), calendar: calendar))
    }

    func testSweepResetsNextDay() {
        let theme = Theme(name: "Leave", colorToken: "sky", iconEmoji: "🚪", completionStyle: .sweep)
        theme.steps = [Step(text: "Keys", sortOrder: 0)]
        theme.sweepComplete(now: date(2026, 10, 13, 9))
        XCTAssertFalse(theme.isListComplete(now: date(2026, 10, 14, 9), calendar: calendar),
                       "A sweep should not carry into the next day")
    }

    // MARK: Theme — per-item style

    func testPerItemListCompleteOnlyWhenAllDone() {
        let theme = Theme(name: "Meds", colorToken: "sage", iconEmoji: "💊", completionStyle: .perItem)
        let s0 = Step(text: "Water", sortOrder: 0)
        let s1 = Step(text: "Tablets", sortOrder: 1)
        theme.steps = [s0, s1]
        let now = date(2026, 10, 13, 9)

        s0.setComplete(true, now: now)
        XCTAssertFalse(theme.isListComplete(now: now, calendar: calendar), "One of two done → not complete")

        s1.setComplete(true, now: now)
        XCTAssertTrue(theme.isListComplete(now: now, calendar: calendar), "All done → complete")
    }

    func testPerItemEmptyThemeIsNotComplete() {
        let theme = Theme(name: "Empty", colorToken: "slate", iconEmoji: "📋", completionStyle: .perItem)
        XCTAssertFalse(theme.isListComplete(now: date(2026, 10, 13), calendar: calendar))
    }

    func testResetCompletionClearsEverything() {
        let theme = Theme(name: "Meds", colorToken: "sage", iconEmoji: "💊", completionStyle: .sweep)
        theme.steps = [Step(text: "Water", sortOrder: 0)]
        theme.sweepComplete(now: date(2026, 10, 13, 9))

        theme.resetCompletion(now: date(2026, 10, 13, 10))
        XCTAssertNil(theme.lastSweptAt)
        XCTAssertTrue(theme.steps.allSatisfy { !$0.isComplete })
    }

    // MARK: Default completion style

    func testNewThemeDefaultsToSweep() {
        // Product decision: the fridge-board "clear the whole list" gesture is the default;
        // changeable per theme in the edit screen.
        XCTAssertEqual(Theme(name: "X", colorToken: "sage", iconEmoji: "✅").completionStyle, .sweep)
    }
}
