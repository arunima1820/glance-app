import XCTest
@testable import Glance

// MARK: - ThemeRestoreTests
// Covers: GlanceShared/Sources/Logic/ThemeRestore.swift (Theme.restored(from:sortOrder:now:)).

final class ThemeRestoreTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_793_534_400)   // 2026-11-01 12:00 UTC

    func testRestoreKeepsNameIconRepeatAndStepOrder() {
        let rule = Recurrence(kind: .weekly, weekdays: [6])
        let snap = ThemeSnapshot(id: UUID(), name: "Bins", colorToken: "clay", iconEmoji: "x",
                                 steps: [StepSnapshot(id: UUID(), text: "Wheel out", iconEmoji: nil),
                                         StepSnapshot(id: UUID(), text: "Recycling", iconEmoji: nil)],
                                 iconToken: "clean", recurrence: rule)
        let theme = Theme.restored(from: snap, sortOrder: 4, now: now)
        XCTAssertEqual(theme.id, snap.id)
        XCTAssertEqual(theme.name, "Bins")
        XCTAssertEqual(theme.iconToken, "clean")
        XCTAssertEqual(theme.sortOrder, 4)
        XCTAssertEqual(theme.recurrence.kind, .weekly)
        XCTAssertEqual(theme.recurrence.weekdays, [6])
        XCTAssertEqual(theme.repeatAnchor, now)
        XCTAssertEqual(theme.orderedSteps.map(\.text), ["Wheel out", "Recycling"])
    }

    func testRestoredStepsComeBackUnticked() {
        let snap = ThemeSnapshot(id: UUID(), name: "Meds", colorToken: "sage", iconEmoji: "x",
                                 steps: [StepSnapshot(id: UUID(), text: "Take", iconEmoji: nil, completedAt: now)])
        let theme = Theme.restored(from: snap, sortOrder: 0, now: now)
        XCTAssertTrue(theme.steps.allSatisfy { $0.completedAt == nil })
        XCTAssertEqual(theme.recurrence.kind, .daily, "old snapshots without a rule restore as daily")
    }
}
