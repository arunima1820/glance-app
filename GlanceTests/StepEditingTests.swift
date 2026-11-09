import XCTest
@testable import Glance

// MARK: - StepEditingTests
// Covers: GlanceShared/Sources/Logic/StepEditing.swift (Step.rename(to:now:), Theme.addStep(_:now:),
// Theme.moveSteps(fromOffsets:toOffset:now:), Theme.setAllDone(_:now:)).

final class StepEditingTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_793_534_400)   // 2026-11-01 12:00 UTC

    private func list(_ names: [String]) -> Theme {
        Theme(name: "List", steps: names.enumerated().map { Step(text: $1, sortOrder: $0) })
    }

    private func order(_ theme: Theme) -> [String] {
        theme.orderedSteps.map(\.text)
    }

    // MARK: rename

    func testRenameTrimsAndStamps() {
        let step = Step(text: "Keys")
        XCTAssertTrue(step.rename(to: "  Keys from the bowl ", now: now))
        XCTAssertEqual(step.text, "Keys from the bowl")
        XCTAssertEqual(step.updatedAt, now)
    }

    func testBlankOrUnchangedRenameKeepsTheText() {
        let step = Step(text: "Keys")
        XCTAssertFalse(step.rename(to: "   "))
        XCTAssertFalse(step.rename(to: "Keys"))
        XCTAssertEqual(step.text, "Keys")
    }

    func testRenameCapsLength() {
        let step = Step(text: "Keys")
        step.rename(to: String(repeating: "x", count: 999))
        XCTAssertEqual(step.text.count, TextLimits.step)
    }

    // MARK: addStep

    func testAddStepGoesLast() {
        let theme = list(["Keys", "Phone"])
        XCTAssertEqual(theme.addStep(" Wallet ", now: now)?.text, "Wallet")
        XCTAssertEqual(order(theme), ["Keys", "Phone", "Wallet"])
        XCTAssertEqual(theme.updatedAt, now)
    }

    func testFullListRefusesMoreSteps() {
        let theme = list((0..<CollectionLimits.stepsPerList).map { "Step \($0)" })
        XCTAssertNil(theme.addStep("One too many"))
        XCTAssertEqual(theme.steps.count, CollectionLimits.stepsPerList)
    }

    func testBlankStepIsNotAdded() {
        let theme = list(["Keys"])
        XCTAssertNil(theme.addStep("  "))
        XCTAssertEqual(theme.steps.count, 1)
    }

    // MARK: moveSteps

    func testMoveDownMatchesOnMove() {
        let theme = list(["A", "B", "C", "D"])
        theme.moveSteps(fromOffsets: [0], toOffset: 3)
        XCTAssertEqual(order(theme), ["B", "C", "A", "D"])
    }

    func testMoveUpAndToTheEnd() {
        let theme = list(["A", "B", "C", "D"])
        theme.moveSteps(fromOffsets: [3], toOffset: 0)
        XCTAssertEqual(order(theme), ["D", "A", "B", "C"])
        theme.moveSteps(fromOffsets: [0], toOffset: 4)
        XCTAssertEqual(order(theme), ["A", "B", "C", "D"])
    }

    func testMoveRenumbersWithoutGaps() {
        let theme = list(["A", "B", "C"])
        theme.moveSteps(fromOffsets: [0, 2], toOffset: 2)
        XCTAssertEqual(order(theme), ["B", "A", "C"])
        XCTAssertEqual(theme.orderedSteps.map(\.sortOrder), [0, 1, 2])
    }

    // MARK: setAllDone

    func testSetAllDoneTicksAndClearsEveryStep() {
        let theme = list(["A", "B"])
        theme.setAllDone(true, now: now)
        XCTAssertTrue(theme.steps.allSatisfy { $0.completedAt == now })
        theme.setAllDone(false, now: now)
        XCTAssertTrue(theme.steps.allSatisfy { $0.completedAt == nil })
    }
}

// MARK: - StepMoveByOneTests
// Covers: GlanceShared/Sources/Logic/StepEditing.swift (Theme.moveStep(_:by:now:)).

final class StepMoveByOneTests: XCTestCase {

    private func list(_ names: [String]) -> Theme {
        Theme(name: "List", steps: names.enumerated().map { Step(text: $1, sortOrder: $0) })
    }

    func testMoveUpAndDownByOne() {
        let theme = list(["A", "B", "C"])
        let b = theme.orderedSteps[1]
        XCTAssertTrue(theme.moveStep(b, by: -1))
        XCTAssertEqual(theme.orderedSteps.map(\.text), ["B", "A", "C"])
        XCTAssertTrue(theme.moveStep(b, by: 1))
        XCTAssertTrue(theme.moveStep(b, by: 1))
        XCTAssertEqual(theme.orderedSteps.map(\.text), ["A", "C", "B"])
    }

    func testCantMovePastTheEnds() {
        let theme = list(["A", "B"])
        XCTAssertFalse(theme.moveStep(theme.orderedSteps[0], by: -1))
        XCTAssertFalse(theme.moveStep(theme.orderedSteps[1], by: 1))
        XCTAssertEqual(theme.orderedSteps.map(\.text), ["A", "B"])
    }
}
