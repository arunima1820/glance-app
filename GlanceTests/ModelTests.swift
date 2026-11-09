import XCTest
@testable import Glance

// MARK: - ThemeModelTests
// Covers: Theme.swift (Theme init defaults, orderedSteps, recurrence bridge to repeat* fields).

final class ThemeModelTests: XCTestCase {

    // MARK: Initialisation

    func testNewThemeHasExpectedDefaults() {
        let theme = Theme(name: "Morning", colorToken: "butter")
        XCTAssertEqual(theme.name, "Morning")
        XCTAssertEqual(theme.colorToken, "butter")
        XCTAssertEqual(theme.iconToken, ThemeIcons.default)
        XCTAssertEqual(theme.recurrence.kind, .daily)
        XCTAssertTrue(theme.steps.isEmpty)
    }

    // MARK: orderedSteps

    func testOrderedStepsSortsBySortOrder() {
        let theme = Theme(name: "Leave the house")
        XCTAssertTrue(theme.orderedSteps.isEmpty)

        theme.steps = [Step(text: "Do the thing", sortOrder: 0)]
        XCTAssertEqual(theme.orderedSteps.map(\.text), ["Do the thing"])

        theme.steps = [
            Step(text: "Lock the door", sortOrder: 2),
            Step(text: "Grab keys", sortOrder: 0),
            Step(text: "Phone charged", sortOrder: 1),
        ]
        XCTAssertEqual(theme.orderedSteps.map(\.text), ["Grab keys", "Phone charged", "Lock the door"])
    }

    // MARK: Recurrence bridge

    func testRecurrenceRoundTripsThroughStoredFields() {
        let theme = Theme(name: "Bins")
        theme.recurrence = Recurrence(kind: .weekly, weekdays: [5, 3], dayOfMonth: 12, interval: 4)
        XCTAssertEqual(theme.repeatWeekdays, [3, 5])
        XCTAssertEqual(theme.recurrence.kind, .weekly)
        XCTAssertEqual(theme.recurrence.weekdays, [3, 5])
        XCTAssertEqual(theme.recurrence.dayOfMonth, 12)
        XCTAssertEqual(theme.recurrence.interval, 4)
    }

    func testDamagedStoredRepeatValuesAreClamped() {
        let theme = Theme(name: "x")
        theme.repeatWeekdays = [0, 3, 12]
        theme.repeatDayOfMonth = 99
        theme.repeatInterval = -4
        XCTAssertEqual(theme.recurrence.weekdays, [3])
        XCTAssertEqual(theme.recurrence.dayOfMonth, 31)
        XCTAssertEqual(theme.recurrence.interval, 1)
    }

    func testUnknownRepeatKindFallsBackToDaily() {
        let theme = Theme(name: "Bins")
        theme.repeatKind = "fortnightly"
        XCTAssertEqual(theme.recurrence.kind, .daily)
    }

    func testRecurrenceAnchorIsCreationDate() {
        let theme = Theme(name: "Plants")
        XCTAssertEqual(theme.recurrence.anchor, theme.createdAt)
    }

    func testRepeatAnchorOverridesCreationDate() {
        let theme = Theme(name: "Plants")
        let anchor = theme.createdAt.addingTimeInterval(-3 * 86_400)
        theme.repeatAnchor = anchor
        XCTAssertEqual(theme.recurrence.anchor, anchor)
    }

    func testFutureAnchorIsClampedToNow() {
        let theme = Theme(name: "Plants")
        theme.repeatAnchor = Date().addingTimeInterval(10 * 86_400)   // clock was set ahead
        XCTAssertLessThanOrEqual(theme.recurrence.anchor, Date())
    }
}

// MARK: - StepModelTests
// Covers: Step.swift (Step init defaults, Step.setComplete(_:now:)).

final class StepModelTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 815_000_000)

    // MARK: Initialisation

    func testNewStepIsIncompleteWithGivenSortOrder() {
        let step = Step(text: "Grab keys", sortOrder: 3)
        XCTAssertNil(step.completedAt)
        XCTAssertNil(step.iconEmoji)
        XCTAssertEqual(step.sortOrder, 3)
    }

    // MARK: setComplete

    func testSetCompleteTrueStampsCompletedAtAndUpdatedAt() {
        let step = Step(text: "Grab keys")
        step.setComplete(true, now: now)
        XCTAssertEqual(step.completedAt, now)
        XCTAssertEqual(step.updatedAt, now)
    }

    func testSetCompleteFalseClearsCompletedAt() {
        let step = Step(text: "Grab keys")
        step.setComplete(true, now: now)
        let later = now.addingTimeInterval(60)
        step.setComplete(false, now: later)
        XCTAssertNil(step.completedAt)
        XCTAssertEqual(step.updatedAt, later)
    }
}

// MARK: - StepTextTests
// Covers: StepText.split (bold lead word + detail for step rows).

final class StepTextTests: XCTestCase {

    func testSplitsFirstWordFromDetail() {
        let parts = StepText.split("Pour a full glass of water")
        XCTAssertEqual(parts.lead, "Pour")
        XCTAssertEqual(parts.detail, "a full glass of water")
    }

    func testSingleWordHasNoDetail() {
        let parts = StepText.split("Keys")
        XCTAssertEqual(parts.lead, "Keys")
        XCTAssertEqual(parts.detail, "")
    }

    func testTrimsAndCollapsesTheGap() {
        let parts = StepText.split("  Lock   the deadbolt \n")
        XCTAssertEqual(parts.lead, "Lock")
        XCTAssertEqual(parts.detail, "the deadbolt")
    }

    func testEmptyTextYieldsEmptyParts() {
        let parts = StepText.split("   ")
        XCTAssertEqual(parts.lead, "")
        XCTAssertEqual(parts.detail, "")
    }
}

// MARK: - TextLimitsTests
// Covers: Step.swift (TextLimits.clamp, TextLimits.clean, CollectionLimits).

final class TextLimitsTests: XCTestCase {

    func testClampTrimsAndCuts() {
        XCTAssertEqual(TextLimits.clamp("  Keys  ", to: 80), "Keys")
        XCTAssertEqual(TextLimits.clamp(String(repeating: "a", count: 500), to: 80).count, 80)
    }

    func testCleanRemovesDirectionTricksAndInvisibleCharacters() {
        XCTAssertEqual(TextLimits.clean("Meds\u{202E}gnip"), "Medsgnip")
        XCTAssertEqual(TextLimits.clean("a\u{200B}b\u{FEFF}c\u{2066}d"), "abcd")
    }

    func testLineBreaksBecomeSpacesUnlessAllowed() {
        XCTAssertEqual(TextLimits.clamp("Keys\nPhone\tBadge", to: 80), "Keys Phone Badge")
        XCTAssertEqual(TextLimits.clamp("Line one\nLine two", to: 80, allowsNewlines: true), "Line one\nLine two")
        XCTAssertEqual(TextLimits.clean("bell\u{07}"), "bell")
    }

    func testEmojiJoinersSurvive() {
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"
        XCTAssertEqual(TextLimits.clean(family), family)
    }

    func testCollectionLimits() {
        XCTAssertTrue(CollectionLimits.hasRoom(99, under: CollectionLimits.lists))
        XCTAssertFalse(CollectionLimits.hasRoom(100, under: CollectionLimits.lists))
        XCTAssertEqual([CollectionLimits.lists, CollectionLimits.stepsPerList, CollectionLimits.foods], [100, 100, 500])
    }
}

